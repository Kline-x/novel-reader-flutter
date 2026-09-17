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

    return sanitizeAndOrderChapters(chapters);
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

  /// 解析中文大写数字（例如 "一千四百三十二", "二十三", "九", "一百零五"）
  static int? parseChineseNumber(String s) {
    if (s.isEmpty) return null;
    const map = {
      '零': 0, '〇': 0, '一': 1, '二': 2, '两': 2, '三': 3, '四': 4,
      '五': 5, '六': 6, '七': 7, '八': 8, '九': 9, '十': 10,
      '百': 100, '千': 1000, '万': 10000,
    };
    int total = 0;
    int curr = 0;
    for (int i = 0; i < s.length; i++) {
      final char = s[i];
      final val = map[char];
      if (val == null) continue;
      if (val >= 10) {
        if (curr == 0) curr = 1;
        total += curr * val;
        curr = 0;
      } else {
        curr = val;
      }
    }
    total += curr;
    return total > 0 ? total : null;
  }

  /// 提取章节标题中的序号数字（支持阿拉伯数字与中文大写数字）
  static int? extractChapterNumber(String title) {
    final t = title.trim();
    if (t.startsWith('序章') || t.startsWith('引子') || t.startsWith('楔子') || t.startsWith('前言')) {
      return 0;
    }
    // 匹配阿拉伯数字：第123章、第 123 节、123.
    final arMatch = RegExp(r'第\s*(\d+)\s*[章节回集卷话]').firstMatch(t);
    if (arMatch != null) {
      return int.tryParse(arMatch.group(1)!);
    }
    final dotMatch = RegExp(r'^(\d+)\s*[\.、\s]').firstMatch(t);
    if (dotMatch != null) {
      return int.tryParse(dotMatch.group(1)!);
    }
    // 匹配中文数字：第一千二百三十四章
    final cnMatch = RegExp(r'第\s*([零〇一二两三四五六七八九十百千万]+)\s*[章节回集卷话]').firstMatch(t);
    if (cnMatch != null) {
      return parseChineseNumber(cnMatch.group(1)!);
    }
    if (t.startsWith('后记') || t.startsWith('尾声') || t.startsWith('番外') || t.startsWith('完本感言')) {
      return 999999;
    }
    return null;
  }

  /// 提取章节 URL 中包含的自增数字标识（如 /50/17455.html 中的 17455）
  static int? extractUrlSequenceId(String url) {
    final match = RegExp(r'/(\d+)\.html').firstMatch(url);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
    return null;
  }

  /// 清洗并重整章节列表：智能剥离前置“最新章节”预览、消除跳章与乱序、重建单调连续索引
  static List<ChapterItem> sanitizeAndOrderChapters(List<ChapterItem> rawList) {
    if (rawList.isEmpty) return [];

    // 1. 识别并剔除前置“最新章节”预览重复项（检查前 15 项在后续是否存在）
    final lateUrls = <String>{};
    for (int i = 15; i < rawList.length; i++) {
      lateUrls.add(rawList[i].url);
    }
    final deduped = <ChapterItem>[];
    for (int i = 0; i < rawList.length; i++) {
      final item = rawList[i];
      if (i < 15 && lateUrls.contains(item.url)) {
        continue;
      }
      deduped.add(item);
    }

    // 2. 基于 URL 进行唯一去重
    final unique = <ChapterItem>[];
    final seenUrls = <String>{};
    for (final item in deduped) {
      if (seenUrls.add(item.url)) {
        unique.add(item);
      }
    }

    if (unique.length <= 2) {
      return unique;
    }

    // 3. 智能检测是否发生乱序（跳章、多列表格跨列错序等）
    final chapterNumbers = unique.map((c) => extractChapterNumber(c.title)).toList();
    final numberedCount = chapterNumbers.where((n) => n != null).length;

    bool shouldSort = false;
    if (numberedCount >= unique.length * 0.5) {
      int inversions = 0;
      int? lastNum;
      for (final num in chapterNumbers) {
        if (num != null && num < 999999) {
          if (lastNum != null && num < lastNum) {
            inversions++;
          }
          lastNum = num;
        }
      }
      // 如果发生 2 次以上逆序跳跃，判定为表格跨列或混序排版，需自动重排序
      if (inversions >= 2) {
        shouldSort = true;
      }
    }

    List<ChapterItem> sortedList = List.of(unique);
    if (shouldSort) {
      final indexed = List.generate(sortedList.length, (i) {
        final item = sortedList[i];
        final num = chapterNumbers[i];
        final urlId = extractUrlSequenceId(item.url);
        return _SortableChapter(
          originalIndex: i,
          chapter: item,
          chapterNumber: num,
          urlId: urlId,
        );
      });

      indexed.sort((a, b) {
        // 优先按提取的章节号排序
        if (a.chapterNumber != null && b.chapterNumber != null) {
          final cmp = a.chapterNumber!.compareTo(b.chapterNumber!);
          if (cmp != 0) return cmp;
        } else if (a.chapterNumber != null && b.chapterNumber == null) {
          if (a.chapterNumber! == 0) return 1;
        } else if (a.chapterNumber == null && b.chapterNumber != null) {
          if (b.chapterNumber! == 0) return -1;
        }

        // 次选：按 URL 序列号递增排序
        if (a.urlId != null && b.urlId != null) {
          final cmp = a.urlId!.compareTo(b.urlId!);
          if (cmp != 0) return cmp;
        }

        // 兜底保持原始顺序
        return a.originalIndex.compareTo(b.originalIndex);
      });

      sortedList = indexed.map((s) => s.chapter).toList();
    }

    // 4. 重建单调递增连续 index (0..N-1)
    return List.generate(sortedList.length, (i) {
      return sortedList[i].copyWith(index: i);
    });
  }
}

class _SortableChapter {
  final int originalIndex;
  final ChapterItem chapter;
  final int? chapterNumber;
  final int? urlId;

  const _SortableChapter({
    required this.originalIndex,
    required this.chapter,
    this.chapterNumber,
    this.urlId,
  });
}

