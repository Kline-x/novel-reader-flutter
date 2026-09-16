import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:html/parser.dart' as html_parser;
import '../models/local_chapter.dart';

/// EPUB 图文精排解包与解析引擎 (epub_parser_engine.dart)
/// - 纯 Dart 解压容器与 OPF / NCX 元数据解析
/// - 解析 Spine 线性阅读顺序与目录树
/// - 提取 HTML / XHTML 正文为标准 Modern Soft UI 排版段落
class EpubBookInfo {
  final String title;
  final String author;
  final List<LocalChapter> chapters;
  final Uint8List? coverBytes;
  final Map<String, String> manifestMap; // id -> href
  final String opfBasePath; // 例如 "OEBPS/"

  const EpubBookInfo({
    required this.title,
    required this.author,
    required this.chapters,
    this.coverBytes,
    required this.manifestMap,
    required this.opfBasePath,
  });
}

class EpubParserEngine {
  /// 解析本地 EPUB 文件元数据与章节目录
  static Future<EpubBookInfo> parseEpub(File file) async {
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    // 1. 查找 container.xml 获取 OPF 路径
    String? opfPath;
    for (final f in archive.files) {
      if (f.name == 'META-INF/container.xml' && f.isFile) {
        final content = utf8.decode(f.content as List<int>);
        final match = RegExp(r'full-path\s*=\s*["' "'" r']([^"' "'" r']+)["' "'" r']').firstMatch(content);
        if (match != null) {
          opfPath = match.group(1);
        }
        break;
      }
    }

    if (opfPath == null) {
      // 备选兜底：直接查找以 .opf 结尾的文件
      for (final f in archive.files) {
        if (f.name.endsWith('.opf') && f.isFile) {
          opfPath = f.name;
          break;
        }
      }
    }

    if (opfPath == null) {
      throw const FormatException('无效的 EPUB 文件：未找到 OPF 描述清单');
    }

    // 计算 OPF 所在的基础相对目录
    final lastSlash = opfPath.lastIndexOf('/');
    final opfBase = lastSlash >= 0 ? opfPath.substring(0, lastSlash + 1) : '';

    // 2. 读取并解析 OPF XML
    String opfContent = '';
    for (final f in archive.files) {
      if (f.name == opfPath && f.isFile) {
        opfContent = utf8.decode(f.content as List<int>, allowMalformed: true);
        break;
      }
    }

    // 提取书名与作者
    String title = '未命名书籍';
    final titleMatch = RegExp(r'<dc:title[^>]*>([^<]+)</dc:title>', caseSensitive: false).firstMatch(opfContent);
    if (titleMatch != null) {
      title = titleMatch.group(1)!.trim();
    } else {
      // 从文件名推导
      title = file.uri.pathSegments.last.replaceAll(RegExp(r'\.epub$', caseSensitive: false), '');
    }

    String author = '佚名';
    final authorMatch = RegExp(r'<dc:creator[^>]*>([^<]+)</dc:creator>', caseSensitive: false).firstMatch(opfContent);
    if (authorMatch != null) {
      author = authorMatch.group(1)!.trim();
    }

    // 提取 manifest (id -> href)
    final manifestMap = <String, String>{};
    String? coverHref;
    final itemMatches = RegExp(r'<item\b([^>]+)>', caseSensitive: false).allMatches(opfContent);
    for (final m in itemMatches) {
      final attrs = m.group(1)!;
      final idMatch = RegExp(r'id\s*=\s*["' "'" r']([^"' "'" r']+)["' "'" r']').firstMatch(attrs);
      final hrefMatch = RegExp(r'href\s*=\s*["' "'" r']([^"' "'" r']+)["' "'" r']').firstMatch(attrs);
      if (idMatch != null && hrefMatch != null) {
        final id = idMatch.group(1)!;
        final href = hrefMatch.group(1)!;
        manifestMap[id] = href;

        if (id.toLowerCase().contains('cover') || attrs.contains('cover-image')) {
          coverHref = href;
        }
      }
    }

    // 提取封面图片
    Uint8List? coverBytes;
    if (coverHref != null) {
      final fullCoverPath = Uri.decodeFull('$opfBase$coverHref');
      for (final f in archive.files) {
        if (f.name == fullCoverPath && f.isFile) {
          coverBytes = Uint8List.fromList(f.content as List<int>);
          break;
        }
      }
    }

    // 提取 NCX 目录文件（如果存在）
    final ncxHref = manifestMap['ncx'] ?? manifestMap['toc'];
    final ncxTitles = <String, String>{}; // href -> title
    if (ncxHref != null) {
      final fullNcxPath = '$opfBase$ncxHref';
      for (final f in archive.files) {
        if (f.name == fullNcxPath && f.isFile) {
          final ncxXml = utf8.decode(f.content as List<int>, allowMalformed: true);
          final navPoints = RegExp(r'<navPoint[^>]*>([\s\S]*?)</navPoint>', caseSensitive: false).allMatches(ncxXml);
          for (final np in navPoints) {
            final textMatch = RegExp(r'<text>([^<]+)</text>', caseSensitive: false).firstMatch(np.group(1)!);
            final srcMatch = RegExp(r'<content\s+src\s*=\s*["' "'" r']([^"' "'" r']+)["' "'" r']', caseSensitive: false).firstMatch(np.group(1)!);
            if (textMatch != null && srcMatch != null) {
              final src = srcMatch.group(1)!.split('#').first; // 去掉锚点
              ncxTitles[src] = textMatch.group(1)!.trim();
            }
          }
          break;
        }
      }
    }

    // 提取 spine 线性章节流
    final chapters = <LocalChapter>[];
    final spineMatches = RegExp(r'<itemref\b[^>]*idref\s*=\s*["' "'" r']([^"' "'" r']+)["' "'" r']', caseSensitive: false).allMatches(opfContent);
    int chIdx = 0;

    for (final sm in spineMatches) {
      final idref = sm.group(1)!;
      final href = manifestMap[idref];
      if (href == null) continue;

      // 提取标题
      String chapterTitle = ncxTitles[href] ?? '';
      final fullHref = '$opfBase$href';

      if (chapterTitle.isEmpty) {
        // 尝试从 XHTML 中嗅探标题
        for (final f in archive.files) {
          if (f.name == fullHref && f.isFile) {
            final htmlContent = utf8.decode(f.content as List<int>, allowMalformed: true);
            final doc = html_parser.parse(htmlContent);
            final hTitle = doc.querySelector('h1, h2, h3, title')?.text.trim();
            if (hTitle != null && hTitle.isNotEmpty) {
              chapterTitle = hTitle;
            }
            break;
          }
        }
      }

      if (chapterTitle.isEmpty) {
        chapterTitle = '第 ${chIdx + 1} 章';
      }

      chapters.add(LocalChapter(
        index: chIdx,
        title: chapterTitle,
        contentHref: fullHref,
      ));
      chIdx++;
    }

    // 兜底：若 spine 为空，直接按 manifest 中的 html 文件排序
    if (chapters.isEmpty) {
      for (final entry in manifestMap.entries) {
        if (entry.value.endsWith('.html') || entry.value.endsWith('.xhtml')) {
          chapters.add(LocalChapter(
            index: chapters.length,
            title: '第 ${chapters.length + 1} 章',
            contentHref: '$opfBase${entry.value}',
          ));
        }
      }
    }

    return EpubBookInfo(
      title: title,
      author: author,
      chapters: chapters,
      coverBytes: coverBytes,
      manifestMap: manifestMap,
      opfBasePath: opfBase,
    );
  }

  /// 提取 EPUB 单章 XHTML 内容并清洗为排版段落
  static Future<List<String>> readChapterContent(File epubFile, LocalChapter chapter) async {
    if (chapter.contentHref == null) return [];

    final bytes = await epubFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    String? htmlContent;
    for (final f in archive.files) {
      if (f.name == chapter.contentHref && f.isFile) {
        htmlContent = utf8.decode(f.content as List<int>, allowMalformed: true);
        break;
      }
    }

    if (htmlContent == null) {
      return ['\u3000\u3000（未能定位该章节内容）'];
    }

    // 剥离 HTML 标签提取纯文本段落
    final doc = html_parser.parse(htmlContent);

    // 移除无用元素
    doc.querySelectorAll('script, style, header, footer, nav').forEach((e) => e.remove());

    final paragraphs = <String>[];
    final nodes = doc.body?.querySelectorAll('p, h1, h2, h3, h4, h5, div') ?? [];

    if (nodes.isNotEmpty) {
      for (final el in nodes) {
        final text = el.text.trim();
        if (text.isNotEmpty && text != chapter.title.trim()) {
          paragraphs.add('\u3000\u3000$text');
        }
      }
    }

    // 兜底直接 body text 拆分
    if (paragraphs.isEmpty) {
      final rawLines = (doc.body?.text ?? '').split(RegExp(r'\r?\n'));
      for (final line in rawLines) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty && trimmed != chapter.title.trim()) {
          paragraphs.add('\u3000\u3000$trimmed');
        }
      }
    }

    return paragraphs.isEmpty ? ['\u3000\u3000（本章暂无正文内容）'] : paragraphs;
  }
}
