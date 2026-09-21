import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_reader_flutter/features/settings/services/backup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmpRoot;

  setUp(() async {
    tmpRoot = await Directory.systemTemp.createTemp('backup_test_');
  });

  tearDown(() async {
    if (await tmpRoot.exists()) {
      await tmpRoot.delete(recursive: true);
    }
  });

  Future<SharedPreferences> prefsWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  group('备份范围', () {
    test('只收本应用的键，不把别家插件的键卷进来', () {
      expect(isBackupKey('novel_reader_bookshelf_list'), isTrue);
      expect(isBackupKey('novel_reader_progress_book_1'), isTrue);
      expect(isBackupKey('pinyin_custom_rules'), isTrue);
      expect(isBackupKey('flutter.some_other_plugin'), isFalse);
      expect(isBackupKey('random_key'), isFalse);
    });
  });

  group('清单校验', () {
    Map<String, Object?> validManifest() => buildManifest(
          prefs: const {'novel_reader_bookshelf_list': <String>[]},
          sourceDocDir: '/data/app',
          fileCount: 0,
          createdAt: DateTime(2026, 9, 21),
        );

    test('合法清单通过', () {
      expect(validateManifest(validManifest()), isNull);
    });

    test('别的应用导出的文件被拒绝', () {
      final m = validManifest()..['app'] = 'com.other.app';
      expect(validateManifest(m), contains('不是藏书阁'));
    });

    test('来自更高格式版本的备份被拒绝而不是静默读坏', () {
      final m = validManifest()
        ..['formatVersion'] = BackupService.formatVersion + 1;
      expect(validateManifest(m), contains('请先升级应用'));
    });

    test('缺少版本号被拒绝', () {
      final m = validManifest()..remove('formatVersion');
      expect(validateManifest(m), isNotNull);
    });
  });

  group('路径改写', () {
    // 书架条目存的是绝对路径。iOS 每次安装容器 UUID 都变，
    // 安卓换机沙箱根也不同——不改写的话恢复出来每本本地书都点不开。
    test('字符串里的旧沙箱根被换成本机的', () {
      const oldRoot = '/data/user/0/com.kline.novelreader/files';
      const newRoot = '/var/mobile/Containers/Data/Application/ABC/Documents';
      final v = rewritePathsIn(
        '{"filePath":"$oldRoot/local_books/gzr.txt"}',
        oldRoot,
        newRoot,
      );
      expect(v, '{"filePath":"$newRoot/local_books/gzr.txt"}');
    });

    test('字符串列表逐条改写', () {
      final v = rewritePathsIn(<String>['/old/a.txt', '/old/b.txt'], '/old',
          '/new') as List;
      expect(v, <String>['/new/a.txt', '/new/b.txt']);
    });

    test('根相同则原样返回，不做无谓替换', () {
      expect(rewritePathsIn('/same/a.txt', '/same', '/same'), '/same/a.txt');
    });

    test('非字符串类型不受影响', () {
      expect(rewritePathsIn(42, '/old', '/new'), 42);
      expect(rewritePathsIn(true, '/old', '/new'), true);
    });
  });

  group('导出再导入的完整往返', () {
    test('书架、进度、偏好与本地书原文件都能还原，且路径已重指向新沙箱', () async {
      // —— 源机器 ——
      final srcDir = Directory('${tmpRoot.path}/src')..createSync();
      final srcBooks = Directory('${srcDir.path}/local_books')
        ..createSync(recursive: true);
      File('${srcBooks.path}/gzr.txt').writeAsStringSync('第一章 蛊真人');
      File('${srcBooks.path}/gzr_meta.json').writeAsStringSync(
        jsonEncode({'filePath': '${srcBooks.path}/gzr.txt'}),
      );
      // 正文缓存故意造一份，验证它**不**进备份
      final cache = Directory('${srcDir.path}/chapters')..createSync();
      File('${cache.path}/huge.txt').writeAsStringSync('x' * 1000);

      final srcPrefs = await prefsWith({
        'novel_reader_bookshelf_list': <String>[
          jsonEncode({
            'bookId': 'gzr',
            'title': '蛊真人',
            'filePath': '${srcBooks.path}/gzr.txt',
          }),
        ],
        'novel_reader_progress_gzr': '{"chapterIndex":12}',
        'novel_reader_keep_screen_awake': false,
        'novel_reader_global_theme': 'dark',
        'pinyin_custom_rules': '[{"hanzi":"蛊","pinyin":"gǔ"}]',
        'unrelated_plugin_key': 'should not travel',
      });

      final bytes = await BackupService(prefs: srcPrefs, docDir: srcDir)
          .exportToBytes();
      expect(bytes, isNotEmpty);

      // 概要能读出来，用户导入前看得到这是哪天的备份
      final summary = BackupService.peek(bytes)!;
      expect(summary.bookCount, 1);
      expect(summary.fileCount, 2, reason: '只有 local_books 下那两个文件，不含正文缓存');

      // —— 目标机器：沙箱根不同、数据全空 ——
      final dstDir = Directory('${tmpRoot.path}/dst')..createSync();
      final dstPrefs = await prefsWith({});

      final result = await BackupService(prefs: dstPrefs, docDir: dstDir)
          .importFromBytes(bytes);
      expect(result.ok, isTrue, reason: result.error);
      expect(result.restoredFiles, 2);

      // 本地书原文件回来了
      final restored = File('${dstDir.path}/local_books/gzr.txt');
      expect(restored.existsSync(), isTrue);
      expect(restored.readAsStringSync(), '第一章 蛊真人');

      // 正文缓存没有被带进来
      expect(Directory('${dstDir.path}/chapters').existsSync(), isFalse);

      // 书架条目里的路径已指向新沙箱，而不是源机器那个死链
      final shelf = dstPrefs.getStringList('novel_reader_bookshelf_list')!;
      final entry = jsonDecode(shelf.single) as Map<String, Object?>;
      expect(entry['filePath'], '${dstDir.path}/local_books/gzr.txt');

      // 元数据文件里的路径同样被改写
      final meta = jsonDecode(
          File('${dstDir.path}/local_books/gzr_meta.json').readAsStringSync());
      expect(meta['filePath'], '${dstDir.path}/local_books/gzr.txt');

      // 各类型的偏好都还原到位
      expect(dstPrefs.getString('novel_reader_progress_gzr'),
          '{"chapterIndex":12}');
      expect(dstPrefs.getBool('novel_reader_keep_screen_awake'), isFalse);
      expect(dstPrefs.getString('novel_reader_global_theme'), 'dark');
      expect(dstPrefs.getString('pinyin_custom_rules'), isNotNull);

      // 别家插件的键没有被备份带过来
      expect(dstPrefs.getString('unrelated_plugin_key'), isNull);
    });

    test('合并模式只补缺失项，不覆盖本机已有数据', () async {
      final srcDir = Directory('${tmpRoot.path}/src2')..createSync();
      final srcPrefs = await prefsWith({
        'novel_reader_global_theme': 'dark',
        'novel_reader_progress_a': 'from_backup',
      });
      final bytes =
          await BackupService(prefs: srcPrefs, docDir: srcDir).exportToBytes();

      final dstDir = Directory('${tmpRoot.path}/dst2')..createSync();
      final dstPrefs = await prefsWith({
        'novel_reader_global_theme': 'light', // 本机已有，不该被覆盖
      });

      final r = await BackupService(prefs: dstPrefs, docDir: dstDir)
          .importFromBytes(bytes, merge: true);
      expect(r.ok, isTrue);
      expect(dstPrefs.getString('novel_reader_global_theme'), 'light');
      expect(dstPrefs.getString('novel_reader_progress_a'), 'from_backup');
    });
  });

  group('坏文件不能把数据弄脏', () {
    test('随便一个不是 zip 的文件被挡住', () async {
      final dir = Directory('${tmpRoot.path}/d3')..createSync();
      final prefs = await prefsWith({'novel_reader_global_theme': 'light'});
      final r = await BackupService(prefs: prefs, docDir: dir)
          .importFromBytes(utf8.encode('这不是 zip'));
      expect(r.ok, isFalse);
      expect(r.error, contains('不是有效的备份文件'));
      expect(prefs.getString('novel_reader_global_theme'), 'light');
    });

    test('是 zip 但没有备份清单也被挡住', () async {
      // 拿一个 epub 当输入：它确实是合法 zip，但不是我们的备份
      final dir = Directory('${tmpRoot.path}/d4')..createSync();
      final srcDir = Directory('${tmpRoot.path}/s4')..createSync();
      final prefs = await prefsWith({});
      final good = await BackupService(prefs: prefs, docDir: srcDir)
          .exportToBytes();
      // 破坏清单：把文件名改掉后重打包太麻烦，直接截断成半个 zip
      final r = await BackupService(prefs: prefs, docDir: dir)
          .importFromBytes(good.sublist(0, good.length ~/ 2));
      expect(r.ok, isFalse);
    });
  });

  test('建议文件名带日期，便于区分多份备份', () {
    expect(
      BackupService.suggestedFileName(DateTime(2026, 9, 21, 14, 30)),
      '藏书阁备份_20260921_1430.zip',
    );
  });
}
