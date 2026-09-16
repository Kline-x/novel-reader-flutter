import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import '../models/book_search_result.dart';
import '../models/chapter_item.dart';
import '../models/source_rule.dart';
import 'network_client.dart';

/// 书源与规则解析引擎 (source_parser.dart)
/// 解析 SourceRule，实现 searchBooks、fetchToc、fetchChapterContent
/// 自动清洗段落、消除广告与排版噪音，输出标准 List<String> paragraphs。
class SourceParser {
  final NetworkClient _client;

  SourceParser({NetworkClient? client}) : _client = client ?? NetworkClient();

  NetworkClient get client => _client;

  /// 搜索书籍
  Future<List<BookSearchResult>> searchBooks(SourceRule rule, String keyword) async {
    final search = rule.search;
    final encodedKey = NetworkClient.encodeKeyword(keyword, charset: rule.charset);
    final searchUrl = search.urlTemplate
        .replaceAll('{key}', encodedKey)
        .replaceAll('{{key}}', encodedKey)
        .replaceAll('{page}', '1')
        .replaceAll('{{page}}', '1');

    final fullUrl = absolutizeUrl(searchUrl, rule.baseUrl);
    final html = await _client.fetchHtml(fullUrl, defaultCharset: rule.charset);
    final document = html_parser.parse(html);

    final itemElements = queryAll(document, search.item);
    final results = <BookSearchResult>[];

    for (final el in itemElements) {
      final title = extractValue(el, search.title);
      final rawDetailUrl = extractValue(el, search.detailUrl);

      if (title.isEmpty || rawDetailUrl.isEmpty) continue;

      final bookUrl = absolutizeUrl(rawDetailUrl, rule.baseUrl);
      final author = extractValue(el, search.author);
      final coverUrlRaw = search.coverUrl != null ? extractValue(el, search.coverUrl!) : null;
      final coverUrl = coverUrlRaw != null && coverUrlRaw.isNotEmpty
          ? absolutizeUrl(coverUrlRaw, rule.baseUrl)
          : null;
      final latestChapter =
          search.latestChapter != null ? extractValue(el, search.latestChapter!) : null;

      results.add(
        BookSearchResult(
          id: '${rule.id}::$bookUrl',
          title: title.trim(),
          author: author.trim(),
          bookUrl: bookUrl,
          coverUrl: coverUrl,
          latestChapter: latestChapter?.trim(),
          sourceId: rule.id,
          sourceName: rule.name,
        ),
      );
    }

    return results;
  }

  /// 获取书籍目录
  Future<List<ChapterItem>> fetchToc(SourceRule rule, String bookUrl) async {
    final fullBookUrl = absolutizeUrl(bookUrl, rule.baseUrl);
    String tocHtml = await _client.fetchHtml(fullBookUrl, defaultCharset: rule.charset);
    dom.Document document = html_parser.parse(tocHtml);

    // 若详情页指定了独立的目录 URL (例如 detail.tocUrl)，先跳转到独立目录页
    if (rule.detail?.tocUrl != null) {
      final tocUrlVal = extractValue(document.body ?? document.documentElement!, rule.detail!.tocUrl!);
      if (tocUrlVal.isNotEmpty) {
        final targetTocUrl = absolutizeUrl(tocUrlVal, fullBookUrl);
        if (targetTocUrl != fullBookUrl) {
          tocHtml = await _client.fetchHtml(targetTocUrl, defaultCharset: rule.charset);
          document = html_parser.parse(tocHtml);
        }
      }
    }

    final chapterElements = queryAll(document, rule.toc.item);
    final chapters = <ChapterItem>[];

    for (int i = 0; i < chapterElements.length; i++) {
      final el = chapterElements[i];
      final title = extractValue(el, rule.toc.title);
      final urlRaw = extractValue(el, rule.toc.url);

      if (title.isEmpty || urlRaw.isEmpty) continue;

      chapters.add(
        ChapterItem(
          index: i,
          title: title.trim(),
          url: absolutizeUrl(urlRaw, fullBookUrl),
        ),
      );
    }

    return chapters;
  }

  /// 获取章节正文内容并降噪分段
  Future<List<String>> fetchChapterContent(SourceRule rule, String chapterUrl) async {
    final fullUrl = absolutizeUrl(chapterUrl, rule.baseUrl);
    final html = await _client.fetchHtml(fullUrl, defaultCharset: rule.charset);
    return parseChapterHtml(html, rule.chapter);
  }

  /// 解析 HTML 正文字符串并清洗段落
  List<String> parseChapterHtml(String html, ChapterRule chapterRule) {
    final document = html_parser.parse(html);
    final contentSelector = chapterRule.content;

    final targetElements = queryAll(document, contentSelector.selector);
    if (targetElements.isEmpty) return [];

    final rawTexts = <String>[];
    for (final el in targetElements) {
      if (contentSelector.attr == 'text') {
        rawTexts.add(el.text);
      } else {
        // 默认按 HTML 转换，保留 <br> 和 <p> 换行
        rawTexts.add(htmlToText(el.innerHtml));
      }
    }

    var combined = rawTexts.join('\n');

    // 若规则自带 regex 替换
    if (contentSelector.regex != null && contentSelector.regex!.isNotEmpty) {
      try {
        combined = combined.replaceAll(RegExp(contentSelector.regex!, multiLine: true), '');
      } catch (_) {}
    }

    return cleanAndFilterParagraphs(combined);
  }

  /// 将 HTML 片段转换为纯文本，还原换行并解码命名实体
  static String htmlToText(String html) {
    var text = html
        .replaceAll(RegExp(r'<\s*(script|style)[^>]*>[\s\S]*?<\s*/\s*\1\s*>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<\s*/\s*(p|div|li|h[1-6]|tr)\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '');

    return decodeHtmlEntities(text);
  }

  /// 解码 HTML 实体
  static String decodeHtmlEntities(String input) {
    const namedEntities = <String, String>{
      'emsp': '　', // 2em 全角首行缩进
      'ensp': ' ',
      'thinsp': ' ',
      'zwnj': '',
      'zwj': '',
      'bull': '·',
      'laquo': '«',
      'raquo': '»',
      'times': '×',
      'divide': '÷',
      'deg': '°',
      'copy': '©',
      'reg': '®',
      'trade': '™',
      'nbsp': ' ',
      'ldquo': '“',
      'rdquo': '”',
      'lsquo': '‘',
      'rsquo': '’',
      'hellip': '…',
      'mdash': '—',
      'ndash': '–',
      'middot': '·',
      'quot': '"',
      'apos': "'",
      'lt': '<',
      'gt': '>',
      'amp': '&',
    };

    return input
        .replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) {
          final code = int.tryParse(m.group(1)!, radix: 16);
          return code != null ? String.fromCharCode(code) : m.group(0)!;
        })
        .replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
          final code = int.tryParse(m.group(1)!);
          return code != null ? String.fromCharCode(code) : m.group(0)!;
        })
        .replaceAllMapped(RegExp(r'&([a-zA-Z]+);'), (m) {
          final name = m.group(1)!.toLowerCase();
          return namedEntities[name] ?? m.group(0)!;
        });
  }

  /// 清洗段落、过滤广告噪音并输出标准段落列表
  static List<String> cleanAndFilterParagraphs(String rawContent) {
    // 常见网文广告、防盗标记与站点尾缀黑名单正则
    final noisePatterns = [
      RegExp(r'请记住本书首发域名.*', caseSensitive: false),
      RegExp(r'天才一秒记住.*', caseSensitive: false),
      RegExp(r'最新网址：.*', caseSensitive: false),
      RegExp(r'手机站全新改版升级地址.*', caseSensitive: false),
      RegExp(r'\(本章完\)', caseSensitive: false),
      RegExp(r'（本章完）', caseSensitive: false),
      RegExp(r'点击下一页继续阅读.*', caseSensitive: false),
      RegExp(r'亲[，,]点击进去.*', caseSensitive: false),
      RegExp(r'如果您中途有事离开.*', caseSensitive: false),
      RegExp(r'加入书签.*方便阅读.*', caseSensitive: false),
      RegExp(r'章节错误.*点此举报.*', caseSensitive: false),
      RegExp(r'投推荐票.*月票.*', caseSensitive: false),
      RegExp(r'https?://[^\s]+', caseSensitive: false),
      RegExp(r'www\.[a-zA-Z0-9_\-]+\.[a-zA-Z0-9_\.\-]+', caseSensitive: false),
      RegExp(r'笔趣阁.*版权所有.*', caseSensitive: false),
    ];

    final lines = rawContent.split(RegExp(r'\r?\n'));
    final cleaned = <String>[];

    for (var line in lines) {
      // 规范行内不可见字符与冗余半角空格
      line = line.replaceAll(RegExp(r'[^\S\n]+'), ' ').trim();
      if (line.isEmpty) continue;

      // 判定是否命中全行广告黑名单
      bool isNoise = false;
      for (final pattern in noisePatterns) {
        if (pattern.hasMatch(line)) {
          // 如果整行主要就是广告，则剔除整行；若是行内夹带广告，剥离广告部分
          final stripped = line.replaceAll(pattern, '').trim();
          if (stripped.length < 5) {
            isNoise = true;
            break;
          } else {
            line = stripped;
          }
        }
      }

      if (isNoise || line.isEmpty) continue;

      cleaned.add(line);
    }

    return cleaned;
  }

  /// 依据 RuleSelector 提取节点对应属性或文本
  static String extractValue(dom.Element context, RuleSelector selectorRule) {
    String selector = selectorRule.selector.trim();
    String? attr = selectorRule.attr;
    String? regex = selectorRule.regex;

    // 解析类似 "h4.bookname a@href" 或 "img@src##regex"
    if (selector.contains('##')) {
      final parts = selector.split('##');
      selector = parts[0];
      if (parts.length > 1 && (regex == null || regex.isEmpty)) {
        regex = parts[1];
      }
    }

    if (selector.contains('@')) {
      final parts = selector.split('@');
      selector = parts[0];
      if (parts.length > 1 && (attr == null || attr.isEmpty)) {
        attr = parts[1];
      }
    }

    dom.Element? target;
    if (selector.isEmpty || selector == ':scope' || selector == 'text' || selector == 'href') {
      target = context;
    } else {
      final elements = queryAll(context, selector);
      if (elements.isNotEmpty) {
        target = elements.first;
      }
    }

    if (target == null) return '';

    String value = '';
    final lowerAttr = (attr ?? 'text').toLowerCase();

    if (lowerAttr == 'text') {
      value = target.text;
    } else if (lowerAttr == 'html') {
      value = htmlToText(target.innerHtml);
    } else {
      value = target.attributes[lowerAttr] ??
          target.attributes[attr!] ??
          target.attributes['data-$lowerAttr'] ??
          '';
    }

    if (regex != null && regex.isNotEmpty) {
      try {
        value = value.replaceAll(RegExp(regex), '');
      } catch (_) {}
    }

    return value.trim();
  }

  /// 支持 CSS 选择器与 Legado 常见语法（class.xxx, tag.xxx, id.xxx, a.0）
  static List<dom.Element> queryAll(dynamic root, String rawSelector) {
    if (rawSelector.isEmpty) return [];

    final normalized = normalizeSelector(rawSelector);
    try {
      if (root is dom.Document) {
        return root.querySelectorAll(normalized);
      } else if (root is dom.Element) {
        return root.querySelectorAll(normalized);
      }
    } catch (_) {}

    return [];
  }

  /// 规范化选择器字符串
  static String normalizeSelector(String selector) {
    var sel = selector.trim();
    if (sel.contains('@')) {
      sel = sel.split('@')[0];
    }
    if (sel.contains('##')) {
      sel = sel.split('##')[0];
    }

    // 处理 Legado 风格: class.xxx / id.xxx / tag.xxx
    sel = sel
        .replaceAllMapped(RegExp(r'class\.([a-zA-Z0-9_\-]+)(?:\.(-?\d+))?'), (m) => '.${m.group(1)}')
        .replaceAllMapped(RegExp(r'id\.([a-zA-Z0-9_\-]+)(?:\.(-?\d+))?'), (m) => '#${m.group(1)}')
        .replaceAllMapped(RegExp(r'tag\.([a-zA-Z0-9_\-]+)(?:\.(-?\d+))?'), (m) => m.group(1)!);

    return sel.trim();
  }

  /// 转换相对 URL 为完整绝对 URL
  static String absolutizeUrl(String relativeOrAbsolute, String base) {
    final trimmed = relativeOrAbsolute.trim();
    if (trimmed.startsWith('//')) {
      return 'https:$trimmed';
    }
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    try {
      final baseUri = Uri.parse(base);
      return baseUri.resolve(trimmed).toString();
    } catch (_) {
      return trimmed;
    }
  }
}
