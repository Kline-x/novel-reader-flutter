import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 整机备份 / 恢复。
///
/// 备份是一个 zip，里面两样东西：
///   backup.json   —— 所有 SharedPreferences 键值（书架、进度、书签、批注、
///                     阅读偏好、主题、书源、拼音规则、WebDAV 配置……）
///   local_books/  —— 本地导入书籍的原文件、封面与章节索引
///
/// 只备份 backup.json 是不够的：书架条目里存的是**绝对路径**，
/// 原文件不跟着走，恢复出来就是一堆点开报错的空壳。
///
/// 反过来，章节正文缓存（chapters/）**故意不备份**——那是可以从书源重新拉的
/// 冷数据，动辄几十上百兆，塞进备份只会让文件大到没法用。
class BackupService {
  /// 备份文件格式版本。日后结构有不兼容变动就 +1，导入时按版本号分流。
  static const int formatVersion = 1;

  /// zip 内的清单文件名
  static const String manifestName = 'backup.json';

  /// zip 内存放本地书籍的目录名，与沙箱里的目录同名
  static const String localBooksDirName = 'local_books';

  /// 需要纳入备份的 SharedPreferences 键前缀。
  /// 用前缀而不是写死键名，新增功能的键自动进备份，不用回头改这里。
  static const List<String> keyPrefixes = <String>[
    'novel_reader_',
    'pinyin_',
  ];

  final SharedPreferences? _injectedPrefs;
  final Directory? _injectedDocDir;

  BackupService({SharedPreferences? prefs, Directory? docDir})
      : _injectedPrefs = prefs,
        _injectedDocDir = docDir;

  Future<SharedPreferences> _prefs() async =>
      _injectedPrefs ?? await SharedPreferences.getInstance();

  Future<Directory> _docDir() async =>
      _injectedDocDir ?? await getApplicationDocumentsDirectory();

  /// 存着凭据的键。备份是个用户会随手丢进网盘、发给自己的文件，
  /// 密码明文躺在里面等于把云盘账号一起交出去。
  static const Set<String> credentialKeys = <String>{
    'novel_reader_webdav_config',
  };

  /// 这些字段导出时抹掉。服务器地址、远程路径不算凭据，抹了只会让
  /// 恢复后还得重新翻一遍网盘设置。
  static const Set<String> credentialFields = <String>{
    'username',
    'password',
  };

  /// 打包出一份完整备份
  Future<Uint8List> exportToBytes() async {
    final prefs = await _prefs();
    final docDir = await _docDir();

    final data = <String, Object?>{};
    for (final key in prefs.getKeys()) {
      if (!isBackupKey(key)) continue;
      final value = redactCredentials(key, prefs.get(key));
      if (value == null) continue; // 抹不干净的整项丢弃
      data[key] = value;
    }

    final archive = Archive();
    int fileCount = 0;

    final localBooks = Directory('${docDir.path}/$localBooksDirName');
    if (await localBooks.exists()) {
      await for (final entity in localBooks.list(recursive: true)) {
        if (entity is! File) continue;
        final bytes = await entity.readAsBytes();
        // 存相对路径，恢复时再拼到目标机器的沙箱根上
        final rel = entity.path
            .replaceAll('\\', '/')
            .substring(docDir.path.replaceAll('\\', '/').length + 1);
        archive.addFile(ArchiveFile(rel, bytes.length, bytes));
        fileCount++;
      }
    }

    final manifest = buildManifest(
      prefs: data,
      sourceDocDir: docDir.path,
      fileCount: fileCount,
      createdAt: DateTime.now(),
    );
    final manifestBytes =
        utf8.encode(const JsonEncoder.withIndent('  ').convert(manifest));
    archive.addFile(
        ArchiveFile(manifestName, manifestBytes.length, manifestBytes));

    final encoded = ZipEncoder().encode(archive);
    return Uint8List.fromList(encoded);
  }

  /// 从备份 zip 恢复。[merge] 为 true 时只补齐缺失的键，不覆盖现有数据。
  Future<BackupRestoreResult> importFromBytes(
    Uint8List bytes, {
    bool merge = false,
  }) async {
    // 注意 decodeBytes 对垃圾输入不一定抛异常，也可能安静地返回空归档，
    // 所以「解压失败」和「解出来没有清单」两条路都得堵。
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      return BackupRestoreResult.failure('不是有效的备份文件（无法解压）');
    }

    ArchiveFile? manifestFile;
    for (final f in archive.files) {
      if (f.name == manifestName) {
        manifestFile = f;
        break;
      }
    }
    if (manifestFile == null) {
      return BackupRestoreResult.failure(
          '不是有效的备份文件（找不到 $manifestName）');
    }

    final Map<String, Object?> manifest;
    try {
      manifest = jsonDecode(utf8.decode(manifestFile.content as List<int>))
          as Map<String, Object?>;
    } catch (e) {
      return BackupRestoreResult.failure('备份清单解析失败，文件可能已损坏');
    }

    final problem = validateManifest(manifest);
    if (problem != null) return BackupRestoreResult.failure(problem);

    final prefs = await _prefs();
    final docDir = await _docDir();
    final sourceDocDir = (manifest['sourceDocDir'] as String?) ?? '';

    // 先还原本地书文件，再写 prefs——反过来的话中途失败会留下
    // 「书架里有条目、文件却不在」的半吊子状态
    int restoredFiles = 0;
    for (final f in archive.files) {
      if (!f.isFile) continue;
      if (!f.name.startsWith('$localBooksDirName/')) continue;
      final dest = File('${docDir.path}/${f.name}');
      await dest.parent.create(recursive: true);
      await dest.writeAsBytes(f.content as List<int>);
      restoredFiles++;
    }

    // 书籍元数据里存的是导出那台机器的绝对路径，换台机器（甚至同机重装）
    // 沙箱根都会变，不改写的话每本本地书都是死链
    if (sourceDocDir.isNotEmpty && sourceDocDir != docDir.path) {
      await _rewriteMetaFiles(docDir, sourceDocDir);
    }

    final rawPrefs = (manifest['prefs'] as Map?)?.cast<String, Object?>() ??
        <String, Object?>{};
    int restoredKeys = 0;
    for (final entry in rawPrefs.entries) {
      if (!isBackupKey(entry.key)) continue;
      if (merge && prefs.containsKey(entry.key)) continue;
      final value = rewritePathsIn(entry.value, sourceDocDir, docDir.path);
      if (await _writePref(prefs, entry.key, value)) restoredKeys++;
    }

    return BackupRestoreResult.success(
      restoredKeys: restoredKeys,
      restoredFiles: restoredFiles,
    );
  }

  Future<void> _rewriteMetaFiles(Directory docDir, String sourceDocDir) async {
    final dir = Directory('${docDir.path}/$localBooksDirName');
    if (!await dir.exists()) return;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        final text = await entity.readAsString();
        final fixed =
            rewritePathsIn(text, sourceDocDir, docDir.path) as String;
        if (fixed != text) await entity.writeAsString(fixed);
      } catch (e) {
        debugPrint('[BackupService] 改写 ${entity.path} 失败: $e');
      }
    }
  }

  Future<bool> _writePref(
      SharedPreferences prefs, String key, Object? value) async {
    if (value is String) return prefs.setString(key, value);
    if (value is bool) return prefs.setBool(key, value);
    if (value is int) return prefs.setInt(key, value);
    if (value is double) return prefs.setDouble(key, value);
    if (value is List) {
      return prefs.setStringList(key, value.map((e) => '$e').toList());
    }
    return false;
  }

  /// 读出备份的概要信息，用于导入前让用户确认「这份备份是什么时候的、装了多少书」
  static BackupSummary? peek(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      for (final f in archive.files) {
        if (f.name != manifestName) continue;
        final m = jsonDecode(utf8.decode(f.content as List<int>))
            as Map<String, Object?>;
        if (validateManifest(m) != null) return null;
        return BackupSummary(
          createdAt: (m['createdAt'] as String?) ?? '',
          bookCount: (m['bookCount'] as num?)?.toInt() ?? 0,
          keyCount: (m['prefs'] as Map?)?.length ?? 0,
          fileCount: (m['fileCount'] as num?)?.toInt() ?? 0,
        );
      }
    } catch (_) {}
    return null;
  }

  /// 建议的备份文件名，带日期便于分辨多份备份
  static String suggestedFileName([DateTime? now]) {
    final t = now ?? DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '藏书阁备份_${t.year}${two(t.month)}${two(t.day)}_'
        '${two(t.hour)}${two(t.minute)}.zip';
  }
}

/// 导出前抹掉凭据字段。
///
/// 返回 null 表示这一项整个不要——内容解析不了就说明抹不干净，
/// 这种情况下宁可少恢复一项，也不能把看不懂的东西原样带出去。
Object? redactCredentials(String key, Object? value) {
  if (!BackupService.credentialKeys.contains(key)) return value;
  if (value is! String) return value;
  Object? decoded;
  try {
    decoded = jsonDecode(value);
  } catch (_) {
    return null;
  }
  if (decoded is! Map) return null;
  final map = Map<String, Object?>.from(decoded);
  for (final field in BackupService.credentialFields) {
    if (map.containsKey(field)) map[field] = '';
  }
  return jsonEncode(map);
}

/// 该键是否属于备份范围
bool isBackupKey(String key) =>
    BackupService.keyPrefixes.any((p) => key.startsWith(p));

/// 组装备份清单
Map<String, Object?> buildManifest({
  required Map<String, Object?> prefs,
  required String sourceDocDir,
  required int fileCount,
  required DateTime createdAt,
}) {
  // 书架列表是个 JSON 字符串数组，条数就是书本数
  final shelf = prefs['novel_reader_bookshelf_list'];
  return <String, Object?>{
    'formatVersion': BackupService.formatVersion,
    'app': 'com.kline.novelreader',
    'createdAt': createdAt.toIso8601String(),
    'sourceDocDir': sourceDocDir,
    'bookCount': shelf is List ? shelf.length : 0,
    'fileCount': fileCount,
    'prefs': prefs,
  };
}

/// 校验清单，通过返回 null，否则返回给用户看的原因
String? validateManifest(Map<String, Object?> manifest) {
  if (manifest['app'] != 'com.kline.novelreader') {
    return '这份备份不是藏书阁导出的';
  }
  final v = (manifest['formatVersion'] as num?)?.toInt();
  if (v == null) return '备份清单缺少版本号，文件可能已损坏';
  if (v > BackupService.formatVersion) {
    return '备份来自更新版本的藏书阁（格式 v$v），请先升级应用再导入';
  }
  if (manifest['prefs'] is! Map) return '备份清单里没有数据内容';
  return null;
}

/// 把值里出现的旧沙箱根替换成本机的。
///
/// 书架条目、本地书元数据里存的都是绝对路径，换台机器（甚至同机重装，
/// iOS 每次安装的容器 UUID 都不一样）沙箱根就变了，不改写就全是死链。
Object? rewritePathsIn(Object? value, String oldRoot, String newRoot) {
  if (oldRoot.isEmpty || oldRoot == newRoot) return value;
  if (value is String) {
    // 书架列表这类值本身就是一段 JSON 文本，里面的路径分隔符是**转义过**的：
    // 一个反斜杠在 JSON 文本里写作两个。只按原样替换会漏掉这一类，
    // 所以原样和转义两种写法各替换一遍。
    // （移动端路径不含反斜杠，这段对 Android / iOS / 鸿蒙都是空转。）
    var out = value.replaceAll(oldRoot, newRoot);
    const backslash = '\\';
    const escapedBackslash = r'\\';
    final escapedOld = oldRoot.replaceAll(backslash, escapedBackslash);
    if (escapedOld != oldRoot) {
      out = out.replaceAll(
          escapedOld, newRoot.replaceAll(backslash, escapedBackslash));
    }
    return out;
  }
  if (value is List) {
    return value.map((e) => rewritePathsIn(e, oldRoot, newRoot)).toList();
  }
  return value;
}

/// 导入前预览到的备份概要
class BackupSummary {
  final String createdAt;
  final int bookCount;
  final int keyCount;
  final int fileCount;

  const BackupSummary({
    required this.createdAt,
    required this.bookCount,
    required this.keyCount,
    required this.fileCount,
  });

  /// 「2026-09-21 14:30 · 12 本书 · 3 个文件」这样的一行说明
  String get display {
    final time = createdAt.length >= 16
        ? createdAt.substring(0, 16).replaceFirst('T', ' ')
        : createdAt;
    return '$time · $bookCount 本书 · $fileCount 个文件';
  }
}

/// 恢复结果
class BackupRestoreResult {
  final bool ok;
  final String? error;
  final int restoredKeys;
  final int restoredFiles;

  const BackupRestoreResult._({
    required this.ok,
    this.error,
    this.restoredKeys = 0,
    this.restoredFiles = 0,
  });

  factory BackupRestoreResult.success({
    required int restoredKeys,
    required int restoredFiles,
  }) =>
      BackupRestoreResult._(
        ok: true,
        restoredKeys: restoredKeys,
        restoredFiles: restoredFiles,
      );

  factory BackupRestoreResult.failure(String error) =>
      BackupRestoreResult._(ok: false, error: error);
}
