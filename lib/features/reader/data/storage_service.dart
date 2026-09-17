import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../engine/page_models.dart';

/// 书架书籍元数据模型
class ShelfBook {
  final String bookId;
  final String title;
  final String author;
  final String? coverUrl;
  final String? sourceId;
  final int currentChapterIndex;
  final int currentCharOffset;
  final int totalChapters;
  final DateTime lastReadTime;
  final String? lastChapterTitle;
  final String? filePath;
  final String? bookUrl;
  final String? sourceName;

  const ShelfBook({
    required this.bookId,
    required this.title,
    required this.author,
    this.coverUrl,
    this.sourceId,
    this.currentChapterIndex = 0,
    this.currentCharOffset = 0,
    this.totalChapters = 0,
    required this.lastReadTime,
    this.lastChapterTitle,
    this.filePath,
    this.bookUrl,
    this.sourceName,
  });

  bool get isLocal => sourceId?.startsWith('local') == true || filePath != null;

  ShelfBook copyWith({
    String? bookId,
    String? title,
    String? author,
    String? coverUrl,
    String? sourceId,
    int? currentChapterIndex,
    int? currentCharOffset,
    int? totalChapters,
    DateTime? lastReadTime,
    String? lastChapterTitle,
    String? filePath,
    String? bookUrl,
    String? sourceName,
  }) {
    return ShelfBook(
      bookId: bookId ?? this.bookId,
      title: title ?? this.title,
      author: author ?? this.author,
      coverUrl: coverUrl ?? this.coverUrl,
      sourceId: sourceId ?? this.sourceId,
      currentChapterIndex: currentChapterIndex ?? this.currentChapterIndex,
      currentCharOffset: currentCharOffset ?? this.currentCharOffset,
      totalChapters: totalChapters ?? this.totalChapters,
      lastReadTime: lastReadTime ?? this.lastReadTime,
      lastChapterTitle: lastChapterTitle ?? this.lastChapterTitle,
      filePath: filePath ?? this.filePath,
      bookUrl: bookUrl ?? this.bookUrl,
      sourceName: sourceName ?? this.sourceName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bookId': bookId,
      'title': title,
      'author': author,
      'coverUrl': coverUrl,
      'sourceId': sourceId,
      'currentChapterIndex': currentChapterIndex,
      'currentCharOffset': currentCharOffset,
      'totalChapters': totalChapters,
      'lastReadTime': lastReadTime.toIso8601String(),
      'lastChapterTitle': lastChapterTitle,
      if (filePath != null) 'filePath': filePath,
      if (bookUrl != null) 'bookUrl': bookUrl,
      if (sourceName != null) 'sourceName': sourceName,
    };
  }

  factory ShelfBook.fromJson(Map<String, dynamic> json) {
    return ShelfBook(
      bookId: json['bookId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      author: json['author'] as String? ?? '',
      coverUrl: json['coverUrl'] as String?,
      sourceId: json['sourceId'] as String?,
      currentChapterIndex: json['currentChapterIndex'] as int? ?? 0,
      currentCharOffset: json['currentCharOffset'] as int? ?? 0,
      totalChapters: json['totalChapters'] as int? ?? 0,
      lastReadTime: json['lastReadTime'] != null
          ? DateTime.tryParse(json['lastReadTime'] as String) ?? DateTime.now()
          : DateTime.now(),
      lastChapterTitle: json['lastChapterTitle'] as String?,
      filePath: json['filePath'] as String?,
      bookUrl: json['bookUrl'] as String?,
      sourceName: json['sourceName'] as String?,
    );
  }
}

/// 冷热分级存储核心服务 (storage_service.dart)
/// - 热数据：元数据与阅读进度（charOffset、章索引、书架列表）持久化至 SharedPreferences；
/// - 冷数据：章节长文本正文缓存至本地沙盒文件 chapters/{bookId}/{chapterIndex}.txt（基于 path_provider）；
/// - 提供缓存大小统计与一键清理功能。
class StorageService {
  final SharedPreferences? _prefs;
  final String? _customCacheDir;

  static const String _keyShelfList = 'novel_reader_bookshelf_list';
  static const String _prefixProgress = 'novel_reader_progress_';

  StorageService({
    SharedPreferences? prefs,
    String? customCacheDir,
  })  : _prefs = prefs,
        _customCacheDir = customCacheDir;

  Future<SharedPreferences> _getPrefs() async {
    if (_prefs != null) return _prefs;
    return await SharedPreferences.getInstance();
  }

  /// 获取正文沙盒缓存根目录
  Future<Directory> getCacheDirectory() async {
    if (_customCacheDir != null) {
      final dir = Directory(_customCacheDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }
    final appDocDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${appDocDir.path}/chapters');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  // ==================== 热数据：阅读进度与书架管理 (SharedPreferences) ====================

  /// 保存书籍阅读进度（字符级锚点与章索引）
  Future<void> saveReadingProgress(
    String bookId, {
    required int chapterIndex,
    required int charOffset,
    double chapterPercent = 0.0,
  }) async {
    final prefs = await _getPrefs();
    final data = {
      'chapterIndex': chapterIndex,
      'charOffset': charOffset,
      'chapterPercent': chapterPercent,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    await prefs.setString('$_prefixProgress$bookId', jsonEncode(data));

    // 同步更新书架列表中该书进度
    await updateShelfProgress(
      bookId,
      chapterIndex: chapterIndex,
      charOffset: charOffset,
    );
  }

  /// 获取指定书籍的阅读锚点
  Future<ReadingAnchor?> getReadingProgress(String bookId) async {
    final prefs = await _getPrefs();
    final raw = prefs.getString('$_prefixProgress$bookId');
    if (raw == null) return null;

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return ReadingAnchor(
        chapterIndex: json['chapterIndex'] as int? ?? 0,
        charOffset: json['charOffset'] as int? ?? 0,
        chapterPercent: (json['chapterPercent'] as num?)?.toDouble() ?? 0.0,
      );
    } catch (_) {
      return null;
    }
  }

  /// 获取书架全部书籍列表
  Future<List<ShelfBook>> getBookshelf() async {
    final prefs = await _getPrefs();
    final rawList = prefs.getStringList(_keyShelfList);
    if (rawList == null) return [];

    final books = <ShelfBook>[];
    for (final itemStr in rawList) {
      try {
        final json = jsonDecode(itemStr) as Map<String, dynamic>;
        books.add(ShelfBook.fromJson(json));
      } catch (_) {}
    }
    return books;
  }

  /// 保存整个书架列表
  Future<void> saveBookshelf(List<ShelfBook> books) async {
    final prefs = await _getPrefs();
    final stringList = books.map((b) => jsonEncode(b.toJson())).toList();
    await prefs.setStringList(_keyShelfList, stringList);
  }

  /// 添加书籍至书架（若已存在则更新元数据）
  Future<void> addToBookshelf(ShelfBook book) async {
    final list = await getBookshelf();
    final idx = list.indexWhere((b) => b.bookId == book.bookId);
    if (idx >= 0) {
      list[idx] = book;
    } else {
      list.insert(0, book);
    }
    await saveBookshelf(list);
  }

  /// 从书架移除书籍
  Future<void> removeFromBookshelf(String bookId) async {
    final list = await getBookshelf();
    list.removeWhere((b) => b.bookId == bookId);
    await saveBookshelf(list);

    final prefs = await _getPrefs();
    await prefs.remove('$_prefixProgress$bookId');
  }

  Future<void> addBookToShelf(ShelfBook book) => addToBookshelf(book);
  Future<void> removeBookFromShelf(String bookId) => removeFromBookshelf(bookId);

  /// 更新书架上指定书籍的阅读进度
  Future<void> updateShelfProgress(
    String bookId, {
    required int chapterIndex,
    required int charOffset,
    int? totalChapters,
    String? lastChapterTitle,
  }) async {
    final list = await getBookshelf();
    final idx = list.indexWhere((b) => b.bookId == bookId);
    if (idx >= 0) {
      final old = list[idx];
      list[idx] = old.copyWith(
        currentChapterIndex: chapterIndex,
        currentCharOffset: charOffset,
        totalChapters: totalChapters ?? old.totalChapters,
        lastChapterTitle: lastChapterTitle ?? old.lastChapterTitle,
        lastReadTime: DateTime.now(),
      );
      await saveBookshelf(list);
    }
  }

  // ==================== 冷数据：章节正文文件缓存 (沙盒 chapters/{bookId}/{chapterIndex}.txt) ====================

  /// 获取指定章节文件句柄
  Future<File> _getChapterFile(String bookId, int chapterIndex) async {
    final baseDir = await getCacheDirectory();
    final bookDir = Directory('${baseDir.path}/$bookId');
    if (!await bookDir.exists()) {
      await bookDir.create(recursive: true);
    }
    return File('${bookDir.path}/$chapterIndex.txt');
  }

  /// 持久化缓存章节段落正文
  Future<void> saveChapterContent(
    String bookId,
    int chapterIndex,
    List<String> paragraphs,
  ) async {
    final file = await _getChapterFile(bookId, chapterIndex);
    final content = paragraphs.join('\n');
    await file.writeAsString(content, flush: true);
  }

  /// 读取章节缓存正文段落（自动过滤旧版本残留的假数据）
  Future<List<String>?> getChapterContent(String bookId, int chapterIndex) async {
    final file = await _getChapterFile(bookId, chapterIndex);
    if (!await file.exists()) return null;

    try {
      final content = await file.readAsString();
      if (content.isEmpty) return [];
      // 自动清除历史测试阶段产生的 mock 离线降级假文本（避免将单元测试的简短正文误杀）
      if (content.contains('欢迎阅读由 Modern Soft UI 渲染引擎驱动') || content.contains('开启你的探索之旅')) {
        await file.delete();
        return null;
      }
      return content.split(RegExp(r'\r?\n'));
    } catch (_) {
      return null;
    }
  }

  /// 持久化缓存书籍完整目录
  Future<void> saveBookToc(String bookId, List<dynamic> chapters) async {
    final baseDir = await getCacheDirectory();
    final bookDir = Directory('${baseDir.path}/$bookId');
    if (!await bookDir.exists()) {
      await bookDir.create(recursive: true);
    }
    final file = File('${bookDir.path}/toc.json');
    final list = chapters.map((c) {
      if (c is Map<String, dynamic>) return c;
      try {
        return (c as dynamic).toJson();
      } catch (_) {
        return {'index': 0, 'title': c.toString(), 'url': ''};
      }
    }).toList();
    await file.writeAsString(jsonEncode(list), flush: true);
  }

  /// 读取已持久化的书籍完整目录
  Future<List<Map<String, dynamic>>?> getBookToc(String bookId) async {
    final baseDir = await getCacheDirectory();
    final file = File('${baseDir.path}/$bookId/toc.json');
    if (!await file.exists()) return null;
    try {
      final str = await file.readAsString();
      final decoded = jsonDecode(str) as List<dynamic>;
      final list = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (list.length < 20 || list.every((c) => (c['url'] ?? '').toString().isEmpty)) {
        await file.delete();
        return null;
      }
      return list;
    } catch (_) {
      return null;
    }
  }

  /// 检查章节是否已缓存到本地
  Future<bool> hasChapterCache(String bookId, int chapterIndex) async {
    final file = await _getChapterFile(bookId, chapterIndex);
    return await file.exists();
  }

  /// 获取某本书所有已下载章节的索引集合
  Future<Set<int>> getDownloadedChapterIndices(String bookId) async {
    final baseDir = await getCacheDirectory();
    final bookDir = Directory('${baseDir.path}/$bookId');
    if (!await bookDir.exists()) return {};

    final indices = <int>{};
    try {
      await for (final entity in bookDir.list()) {
        if (entity is File && entity.path.endsWith('.txt')) {
          final fileName = entity.uri.pathSegments.last;
          final idxStr = fileName.replaceAll('.txt', '');
          final idx = int.tryParse(idxStr);
          if (idx != null) {
            indices.add(idx);
          }
        }
      }
    } catch (_) {}
    return indices;
  }

  /// 获取某本书已下载的章节总数
  Future<int> getDownloadedChaptersCount(String bookId) async {
    final indices = await getDownloadedChapterIndices(bookId);
    return indices.length;
  }

  /// 统计单本书籍正文缓存占用字节数
  Future<int> getBookCacheSize(String bookId) async {
    final baseDir = await getCacheDirectory();
    final bookDir = Directory('${baseDir.path}/$bookId');
    if (!await bookDir.exists()) return 0;

    int totalBytes = 0;
    try {
      await for (final entity in bookDir.list(recursive: true)) {
        if (entity is File) {
          totalBytes += await entity.length();
        }
      }
    } catch (_) {}
    return totalBytes;
  }

  /// 统计本地全部沙盒缓存占用总字节数
  Future<int> getTotalCacheSize() async {
    final baseDir = await getCacheDirectory();
    if (!await baseDir.exists()) return 0;

    int totalBytes = 0;
    try {
      await for (final entity in baseDir.list(recursive: true)) {
        if (entity is File) {
          totalBytes += await entity.length();
        }
      }
    } catch (_) {}
    return totalBytes;
  }

  /// 一键清理单本书籍全部离线章节缓存
  Future<void> clearBookCache(String bookId) async {
    final baseDir = await getCacheDirectory();
    final bookDir = Directory('${baseDir.path}/$bookId');
    if (await bookDir.exists()) {
      await bookDir.delete(recursive: true);
    }
  }

  /// 一键清理本地所有章节长文本缓存
  Future<void> clearAllCache() async {
    final baseDir = await getCacheDirectory();
    if (await baseDir.exists()) {
      await baseDir.delete(recursive: true);
      await baseDir.create(recursive: true);
    }
  }

  /// 格式化缓存字节数为人性化字符串 (如 "1.2 MB", "450 KB")
  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(size < 10 && i > 0 ? 1 : 0)} ${suffixes[i]}';
  }
}
