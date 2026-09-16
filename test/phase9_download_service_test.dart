import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_reader_flutter/features/sources/models/chapter_item.dart';
import 'package:novel_reader_flutter/features/reader/data/storage_service.dart';
import 'package:novel_reader_flutter/features/reader/services/download_service.dart';
import 'package:novel_reader_flutter/features/reader/presentation/download_sheet.dart';
import 'package:novel_reader_flutter/features/reader/presentation/reader_screen.dart';
import 'package:novel_reader_flutter/features/reader/presentation/catalog_drawer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late StorageService storage;
  late DownloadService downloadService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('novel_reader_phase9_test_');
    storage = StorageService(customCacheDir: tempDir.path);
    downloadService = DownloadService.withStorage(storage);
    DownloadService.setMockInstance(downloadService);
  });

  tearDown(() async {
    downloadService.dispose();
    DownloadService.resetInstance();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('阶段 9：离线批量下载调度引擎与分级缓存测试', () {
    test('StorageService 已下载章节索引检索与计数测试', () async {
      const bookId = 'test_book_indices';
      expect(await storage.getDownloadedChaptersCount(bookId), 0);
      expect(await storage.getDownloadedChapterIndices(bookId), isEmpty);

      // 写入 3 章
      await storage.saveChapterContent(bookId, 0, ['第一章内容']);
      await storage.saveChapterContent(bookId, 5, ['第六章内容']);
      await storage.saveChapterContent(bookId, 12, ['第十三章内容']);

      final indices = await storage.getDownloadedChapterIndices(bookId);
      expect(indices.length, 3);
      expect(indices.contains(0), isTrue);
      expect(indices.contains(5), isTrue);
      expect(indices.contains(12), isTrue);
      expect(indices.contains(1), isFalse);

      expect(await storage.getDownloadedChaptersCount(bookId), 3);
    });

    test('DownloadService 批量下载调度全生命周期与进度流测试', () async {
      const bookId = 'test_batch_book';
      const bookTitle = '《宿命之环》';
      final chapters = List.generate(
        15,
        (i) => ChapterItem(
          index: i,
          title: '第 ${i + 1} 章 旅程开始',
          url: 'https://example.com/ch/$i',
        ),
      );

      final progressEvents = <DownloadProgress>[];
      final sub = downloadService.progressStream.listen(progressEvents.add);

      // 触发下载前 10 章
      await downloadService.startBatchDownload(
        bookId: bookId,
        bookTitle: bookTitle,
        chapters: chapters,
        startIndex: 0,
        count: 10,
      );

      await Future.delayed(const Duration(milliseconds: 50));
      await sub.cancel();

      // 校验进度事件
      expect(progressEvents.isNotEmpty, isTrue);
      final lastEvent = progressEvents.last;
      expect(lastEvent.bookId, bookId);
      expect(lastEvent.total, 10);
      expect(lastEvent.completed, 10);
      expect(lastEvent.status, DownloadStatus.completed);
      expect(lastEvent.progress, 1.0);

      // 校验落盘文件
      final cachedIndices = await storage.getDownloadedChapterIndices(bookId);
      expect(cachedIndices.length, 10);
      for (var i = 0; i < 10; i++) {
        expect(cachedIndices.contains(i), isTrue);
        final content = await storage.getChapterContent(bookId, i);
        expect(content, isNotNull);
        expect(content!.isNotEmpty, isTrue);
      }
    });

    testWidgets('DownloadSheet 离线下载调度中心弹窗挂载与操作测试', (tester) async {
      const bookId = 'test_sheet_book';
      const bookTitle = '《诡秘之主》';
      final chapters = List.generate(
        25,
        (i) => ChapterItem(
          index: i,
          title: '第 ${i + 1} 章 廷根往事',
          url: 'https://example.com/ch/$i',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  DownloadSheet.show(
                    context,
                    bookId: bookId,
                    bookTitle: bookTitle,
                    chapters: chapters,
                    currentChapterIndex: 0,
                  );
                },
                child: const Text('打开下载弹窗'),
              ),
            ),
          ),
        ),
      );

      // 打开弹窗
      await tester.tap(find.text('打开下载弹窗'));
      await tester.pumpAndSettle();

      // 验证标题与选项展示
      expect(find.text('离线下载调度中心'), findsOneWidget);
      expect(find.text(bookTitle), findsOneWidget);
      expect(find.text('快捷离线方案'), findsOneWidget);
      expect(find.text('缓存后 20 章'), findsOneWidget);
      // 点击「缓存后 20 章」
      await tester.tap(find.text('缓存后 20 章'));
      await tester.pump();

      // 验证下载调度卡片即时展示（包含取消按钮与进度条）
      expect(find.text('取消下载'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      // 清理后台任务防止 Timer 泄漏
      downloadService.cancelDownload(bookId);
      await tester.pumpAndSettle();
    });

    testWidgets('ReaderScreen 离线下载按钮与目录缓存图标全链路测试', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ReaderScreen(
              bookId: 'test_reader_offline',
              bookTitle: '《道诡异仙》',
              author: '狐尾的笔',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 点击屏幕中央呼出控制菜单
      await tester.tapAt(const Offset(400, 400));
      await tester.pumpAndSettle();

      // 验证阅读器顶部栏书名、离线与换源按钮就绪
      expect(find.text('《道诡异仙》'), findsOneWidget);
      expect(find.text('离线'), findsOneWidget);
      expect(find.text('换源'), findsOneWidget);

      // 点击「离线」按钮，呼出 DownloadSheet
      await tester.tap(find.text('离线'));
      await tester.pumpAndSettle();

      expect(find.text('离线下载调度中心'), findsOneWidget);
      expect(find.text('《道诡异仙》'), findsNWidgets(2));

      // 关闭弹窗
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      // 打开目录抽屉
      await tester.tap(find.text('目录'));
      await tester.pumpAndSettle();

      // 验证目录抽屉中出现「缓存」按钮
      expect(find.text('缓存'), findsOneWidget);
    });
  });
}
