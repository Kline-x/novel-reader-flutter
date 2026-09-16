import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../reader/data/storage_service.dart';
import '../models/local_chapter.dart';
import 'epub_parser_engine.dart';
import 'txt_parser_engine.dart';

/// 本地图书统一管理服务 (local_book_service.dart)
/// - 整合 TXT / EPUB 解析导入、分章索引持久化与沙盒管理
/// - 纯流式快速读取正文段落
/// - 监听与书架联动
class LocalBookService {
  static final LocalBookService _instance = LocalBookService._internal();
  factory LocalBookService() => _instance;
  LocalBookService._internal();

  final StorageService _storageService = StorageService();
  final _bookImportedController = StreamController<ShelfBook>.broadcast();

  Stream<ShelfBook> get bookImportedStream => _bookImportedController.stream;

  /// 导入本地文件（TXT / EPUB）并加入书架
  Future<ShelfBook> importFile(File file) async {
    final fileName = file.uri.pathSegments.last;
    final isEpub = fileName.toLowerCase().endsWith('.epub');
    final isTxt = fileName.toLowerCase().endsWith('.txt');

    if (!isTxt && !isEpub) {
      throw UnsupportedError('仅支持导入 .txt 与 .epub 格式图书');
    }

    final docDir = await getApplicationDocumentsDirectory();
    final metaDir = Directory('${docDir.path}/local_books/meta');
    if (!await metaDir.exists()) {
      await metaDir.create(recursive: true);
    }

    final bookId = 'local_${DateTime.now().millisecondsSinceEpoch}';
    String title = fileName.replaceAll(RegExp(r'\.(txt|epub)$', caseSensitive: false), '');
    String author = '本地导入';
    String? coverUrl;
    List<LocalChapter> chapters = [];

    if (isEpub) {
      final epubInfo = await EpubParserEngine.parseEpub(file);
      title = epubInfo.title;
      author = epubInfo.author;
      chapters = epubInfo.chapters;

      if (epubInfo.coverBytes != null) {
        final coversDir = Directory('${docDir.path}/local_books/covers');
        if (!await coversDir.exists()) {
          await coversDir.create(recursive: true);
        }
        final coverFile = File('${coversDir.path}/$bookId.png');
        await coverFile.writeAsBytes(epubInfo.coverBytes!);
        coverUrl = coverFile.path;
      }
    } else {
      chapters = await TxtParserEngine.parseChapters(file);
    }

    // 保存章节目录索引至本地 meta 目录
    final tocFile = File('${metaDir.path}/${bookId}_toc.json');
    final tocJson = chapters.map((c) => c.toJson()).toList();
    await tocFile.writeAsString(jsonEncode(tocJson));

    // 保存书籍持久化配置
    final bookMetaFile = File('${metaDir.path}/${bookId}_meta.json');
    final bookMetaData = {
      'bookId': bookId,
      'title': title,
      'author': author,
      'filePath': file.path,
      'type': isEpub ? 'epub' : 'txt',
      'coverUrl': coverUrl,
      'totalChapters': chapters.length,
    };
    await bookMetaFile.writeAsString(jsonEncode(bookMetaData));

    // 构建 ShelfBook 并存入书架
    final shelfBook = ShelfBook(
      bookId: bookId,
      title: title,
      author: author,
      coverUrl: coverUrl,
      sourceId: isEpub ? 'local_epub' : 'local_txt',
      filePath: file.path,
      totalChapters: chapters.length,
      currentChapterIndex: 0,
      currentCharOffset: 0,
      lastReadTime: DateTime.now(),
      lastChapterTitle: chapters.isNotEmpty ? chapters.first.title : '第一章',
    );

    await _storageService.addToBookshelf(shelfBook);
    _bookImportedController.add(shelfBook);

    return shelfBook;
  }

  /// 获取指定本地书籍的章节目录
  Future<List<LocalChapter>> getToc(String bookId) async {
    final docDir = await getApplicationDocumentsDirectory();
    final tocFile = File('${docDir.path}/local_books/meta/${bookId}_toc.json');
    if (!await tocFile.exists()) return [];

    try {
      final content = await tocFile.readAsString();
      final list = jsonDecode(content) as List<dynamic>;
      return list.map((e) => LocalChapter.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// 读取指定章节正文段落
  Future<List<String>> getChapterContent(String bookId, int chapterIndex) async {
    final docDir = await getApplicationDocumentsDirectory();
    final metaFile = File('${docDir.path}/local_books/meta/${bookId}_meta.json');
    if (!await metaFile.exists()) return [];

    try {
      final metaContent = await metaFile.readAsString();
      final meta = jsonDecode(metaContent) as Map<String, dynamic>;
      final filePath = meta['filePath'] as String;
      final type = meta['type'] as String;
      final file = File(filePath);
      if (!await file.exists()) {
        return ['\u3000\u3000（本地源文件已不存在或已被移除）'];
      }

      final chapters = await getToc(bookId);
      if (chapterIndex < 0 || chapterIndex >= chapters.length) {
        return ['\u3000\u3000（章节索引超出范围）'];
      }

      final chapter = chapters[chapterIndex];

      if (type == 'epub') {
        return await EpubParserEngine.readChapterContent(file, chapter);
      } else {
        return await TxtParserEngine.readChapterContent(file, chapter);
      }
    } catch (e) {
      return ['\u3000\u3000（读取章节内容失败: $e）'];
    }
  }
}
