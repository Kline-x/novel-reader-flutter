import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fast_gbk/fast_gbk.dart';
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

    // 关键修复：必须把原始文件复制进应用沙盒后再引用。
    // 此前只记录外部路径（常在系统缓存/分享临时目录里），
    // 一旦系统清理缓存或权限失效，整本书就永久变成"源文件已不存在"，
    // 而 TXT 的分章索引又是基于字节偏移的，强依赖该文件长期不变。
    final storedFile = await _ensureFileInSandbox(file, bookId, isEpub);

    String title =
        fileName.replaceAll(RegExp(r'\.(txt|epub)$', caseSensitive: false), '');
    String author = '本地导入';
    String? coverUrl;
    String? detectedEncoding;
    List<LocalChapter> chapters = [];

    if (isEpub) {
      final epubInfo = await EpubParserEngine.parseEpub(storedFile);
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
      chapters = await TxtParserEngine.parseChapters(storedFile);
      detectedEncoding = await _detectFileEncoding(storedFile);
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
      'filePath': storedFile.path,
      'type': isEpub ? 'epub' : 'txt',
      'encoding': detectedEncoding,
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
      filePath: storedFile.path,
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

  /// 对整份文件做一次编码嗅探并固化下来
  Future<String> _detectFileEncoding(File file) async {
    try {
      final raf = await file.open(mode: FileMode.read);
      final len = await file.length();
      final sample =
          await raf.read(len > 65536 ? 65536 : len);
      await raf.close();
      return TxtParserEngine.detectEncoding(Uint8List.fromList(sample)) == utf8
          ? 'utf-8'
          : 'gbk';
    } catch (_) {
      return 'utf-8';
    }
  }

  /// 把导入的图书复制进应用沙盒 local_books/raw/，返回沙盒内的文件句柄。
  /// 若源文件本就位于沙盒（如 WiFi 传书落盘的文件），直接复用不重复拷贝。
  Future<File> _ensureFileInSandbox(
      File source, String bookId, bool isEpub) async {
    final docDir = await getApplicationDocumentsDirectory();
    final normalizedDoc = docDir.path.replaceAll(r'\', '/');
    final normalizedSource = source.path.replaceAll(r'\', '/');
    if (normalizedSource.startsWith('$normalizedDoc/')) {
      return source;
    }

    final rawDir = Directory('${docDir.path}/local_books/raw');
    if (!await rawDir.exists()) {
      await rawDir.create(recursive: true);
    }
    final target = File('${rawDir.path}/$bookId.${isEpub ? 'epub' : 'txt'}');
    return await source.copy(target.path);
  }

  /// 获取指定本地书籍的章节目录
  Future<List<LocalChapter>> getToc(String bookId) async {
    final docDir = await getApplicationDocumentsDirectory();
    final tocFile = File('${docDir.path}/local_books/meta/${bookId}_toc.json');
    if (!await tocFile.exists()) return [];

    try {
      final content = await tocFile.readAsString();
      final list = jsonDecode(content) as List<dynamic>;
      return list
          .map((e) => LocalChapter.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// 读取指定章节正文段落
  Future<List<String>> getChapterContent(
      String bookId, int chapterIndex) async {
    final docDir = await getApplicationDocumentsDirectory();
    final metaFile =
        File('${docDir.path}/local_books/meta/${bookId}_meta.json');
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
        // 复用导入时固化的编码：按单章切片再嗅探一次，
        // 遇到刚好是合法 UTF-8 的 GBK 片段仍可能判错
        final encName = meta['encoding'] as String?;
        final enc = encName == 'gbk' ? gbk : (encName == 'utf-8' ? utf8 : null);
        return await TxtParserEngine.readChapterContent(file, chapter,
            encoding: enc);
      }
    } catch (e) {
      return ['\u3000\u3000（读取章节内容失败: $e）'];
    }
  }
}
