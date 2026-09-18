import 'package:flutter/foundation.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import '../models/book_search_result.dart';
import '../models/chapter_item.dart';
import '../models/source_rule.dart';
import 'builtin_sources.dart';
import 'network_client.dart';

/// 书源与规则解析引擎 (source_parser.dart)
/// 解析 SourceRule，实现 searchBooks、fetchToc、fetchChapterContent
/// 自动清洗段落、消除广告与排版噪音，输出标准 List<String> paragraphs。
class SourceParser {
  final NetworkClient _client;

  SourceParser({NetworkClient? client}) : _client = client ?? NetworkClient();

  NetworkClient get client => _client;

  /// 从 BuiltinSources.all 中根据 URL 的 Host 自动匹配对应的 SourceRule
  static SourceRule? findRuleByUrl(String url) {
    if (url.isEmpty) return null;
    try {
      var uri = Uri.tryParse(url);
      if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
        uri = Uri.tryParse('https://$url');
      }
      var host = uri?.host.toLowerCase() ?? '';
      if (host.startsWith('www.')) {
        host = host.substring(4);
      }
      if (host.isEmpty) return null;

      for (final rule in BuiltinSources.all) {
        final baseUri = Uri.tryParse(rule.baseUrl);
        var ruleHost = baseUri?.host.toLowerCase() ?? '';
        if (ruleHost.startsWith('www.')) {
          ruleHost = ruleHost.substring(4);
        }
        if (ruleHost.isNotEmpty &&
            (host == ruleHost || host.endsWith('.$ruleHost') || ruleHost.endsWith('.$host'))) {
          return rule;
        }
      }
    } catch (_) {}
    return null;
  }

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

  /// 清洗段落、智能语义断行、过滤广告噪音并输出标准段落列表
  static List<String> cleanAndFilterParagraphs(String rawContent) {
    // 1. 扩充涵盖 40+ 种主流网文广告、防盗标记与站点牛皮癣黑名单正则
    final noisePatterns = [
      RegExp(r'请记住本书首发域名.*', caseSensitive: false),
      RegExp(r'天才一秒记住.*', caseSensitive: false),
      RegExp(r'最新网址[：:].*', caseSensitive: false),
      RegExp(r'手机站全新改版升级地址.*', caseSensitive: false),
      RegExp(r'\(本章完\)', caseSensitive: false),
      RegExp(r'（本章完）', caseSensitive: false),
      RegExp(r'点击下一页继续阅读.*', caseSensitive: false),
      RegExp(r'本章未完.*点击下一页.*', caseSensitive: false),
      RegExp(r'亲[，,]点击进去.*', caseSensitive: false),
      RegExp(r'如果您中途有事离开.*', caseSensitive: false),
      RegExp(r'加入书签.*方便阅读.*', caseSensitive: false),
      RegExp(r'请务必保存书签.*', caseSensitive: false),
      RegExp(r'章节错误.*点此举报.*', caseSensitive: false),
      RegExp(r'投推荐票.*月票.*', caseSensitive: false),
      RegExp(r'求月票.*求推荐.*', caseSensitive: false),
      RegExp(r'https?://[^\s]+', caseSensitive: false),
      RegExp(r'www\.[a-zA-Z0-9_\-]+\.[a-zA-Z0-9_\.\-]+', caseSensitive: false),
      RegExp(r'笔趣阁.*版权所有.*', caseSensitive: false),
      RegExp(r'.*(?:[0-9a-zA-Z]{3,}\.com|[0-9a-zA-Z]{3,}\.net|[0-9a-zA-Z]{3,}\.org).*', caseSensitive: false),
      RegExp(r'.*免费提供.*(?:全文阅读|在线阅读).*', caseSensitive: false),
      RegExp(r'.*(?:全文字更新|更新速度最快|最新章节更新).*', caseSensitive: false),
      RegExp(r'.*(?:无广告|无弹窗|极速阅读).*', caseSensitive: false),
      RegExp(r'.*收藏本书.*随时阅读.*', caseSensitive: false),
      RegExp(r'.*本站所有小说为转载作品.*', caseSensitive: false),
      RegExp(r'.*(?:上一页|返回目录|下一页).*', caseSensitive: false),
      RegExp(r'.*(?:思兔阅读|鬼吹灯书屋|笔趣阁|顶点小说|飘天文学|天天看).*', caseSensitive: false),
      RegExp(r'.*(?:app下载|客户端下载|下载APP).*', caseSensitive: false),
    ];

    // 2. 预处理段首标记：支持以全角空格或连续多空格切分段落
    var text = rawContent
        .replaceAll(RegExp(r'(?:\u3000{2,}|\s{4,})'), '\n')
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');

    final rawLines = text.split(RegExp(r'\r?\n'));
    final filteredLines = <String>[];

    for (var line in rawLines) {
      // 规范行内不可见字符与冗余半角空格
      line = line.replaceAll(RegExp(r'[^\S\n]+'), ' ').trim();
      if (line.isEmpty) continue;

      // 判定是否命中广告黑名单
      bool isNoise = false;
      for (final pattern in noisePatterns) {
        if (pattern.hasMatch(line)) {
          final stripped = line.replaceAll(pattern, '').trim();
          if (stripped.length < 6) {
            isNoise = true;
            break;
          } else {
            line = stripped;
          }
        }
      }

      if (isNoise || line.isEmpty) continue;
      filteredLines.add(line);
    }

    // 3. 解决“一大段不分行”：超长段落智能语义断句断段（>320字根据句末标点断段）
    final result = <String>[];
    for (final line in filteredLines) {
      if (line.length <= 320) {
        result.add(line);
        continue;
      }

      // 超长段落：按句子终结标点（。”、！”、？”、。、！、？）拆分
      final sentenceRegex = RegExp(r'''[^。！？…]*[。！？…]+[”"’']?|[^。！？…]+$''');
      final matches = sentenceRegex.allMatches(line);
      final buffer = StringBuffer();

      for (final m in matches) {
        final sentence = m.group(0) ?? '';
        buffer.write(sentence);

        // 当当前段落累积超过 180 字且以完整句末标点结尾，断为新自然段
        if (buffer.length >= 180 && RegExp(r'''[。！？…][”"’']?$''').hasMatch(buffer.toString().trim())) {
          result.add(buffer.toString().trim());
          buffer.clear();
        }
      }

      if (buffer.isNotEmpty) {
        final remaining = buffer.toString().trim();
        if (remaining.isNotEmpty) {
          result.add(remaining);
        }
      }
    }

    return result;
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

  /// 检测章节序列是否确实发生了表格分栏或奇偶列错序
  /// 仅在确认发生严格的分栏/奇偶错序时触发重排，绝不因为小说多卷章节序号重置而破坏连续章回顺序
  static bool isStrictColumnOrOddEvenMisorder(List<int> validNums) {
    if (validNums.length < 4) return false;

    // 1. 检测半区奇偶割裂（Half-split Odd-Even：前半段基本为奇数，后半段基本为偶数，或反之）
    final halfLen = validNums.length ~/ 2;
    if (halfLen >= 4) {
      final firstHalf = validNums.sublist(0, halfLen);
      final secondHalf = validNums.sublist(halfLen);

      final firstOdds = firstHalf.where((n) => n % 2 == 1).length;
      final secondOdds = secondHalf.where((n) => n % 2 == 1).length;

      final firstOddRatio = firstOdds / firstHalf.length;
      final secondOddRatio = secondOdds / secondHalf.length;

      if ((firstOddRatio >= 0.8 && secondOddRatio <= 0.2) ||
          (firstOddRatio <= 0.2 && secondOddRatio >= 0.8)) {
        return true;
      }
    }

    // 2. 检测单调递增段（Runs）结构与逆序频率
    int inversions = 0;
    int currentRunLength = 1;
    final runLengths = <int>[];

    for (int i = 0; i < validNums.length - 1; i++) {
      if (validNums[i + 1] > validNums[i]) {
        currentRunLength++;
      } else {
        inversions++;
        runLengths.add(currentRunLength);
        currentRunLength = 1;
      }
    }
    runLengths.add(currentRunLength);

    // 逆序次数少于 2 次，绝不判定为分栏错序
    if (inversions < 2) {
      return false;
    }

    // 在多卷小说中，每卷通常包含大量章节，递增段平均长度极长且逆序率极低
    final avgRunLength = validNums.length / runLengths.length;
    final inversionRate = inversions / (validNums.length - 1);

    // 3. 严格分栏特征判定：
    // - 分栏排版中，因为每行只有 2~4 列，因此递增段平均长度极短（<= 5.5）
    // - 且逆序率显著（>= 15%）
    // - 绝大多数递增段的长度均 <= 6
    if (avgRunLength <= 5.5 && inversionRate >= 0.15) {
      final shortRuns = runLengths.where((len) => len <= 6).length;
      if (shortRuns / runLengths.length >= 0.75) {
        return true;
      }
    }

    return false;
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

    // 3. 智能检测是否发生乱序（仅限严格的表格分栏或奇偶列错序，保护多卷连贯顺序）
    final chapterNumbers = unique.map((c) => extractChapterNumber(c.title)).toList();
    final numberedCount = chapterNumbers.where((n) => n != null).length;

    bool shouldSort = false;
    if (numberedCount >= unique.length * 0.5) {
      final validNums = chapterNumbers
          .whereType<int>()
          .where((n) => n > 0 && n < 999999)
          .toList();
      shouldSort = isStrictColumnOrOddEvenMisorder(validNums);
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

  /// 抓取书籍详情页真实元数据（真实简介、最新更新时间、连载/完结状态）
  Future<Map<String, dynamic>> fetchBookDetail(SourceRule rule, String bookUrl) async {
    try {
      final fullUrl = absolutizeUrl(bookUrl, rule.baseUrl);
      final html = await _client.fetchHtml(fullUrl, defaultCharset: rule.charset);
      final doc = html_parser.parse(html);

      String extractMeta(String prop) {
        final meta = doc.querySelector('meta[property="$prop"]') ??
            doc.querySelector('meta[name="$prop"]');
        return meta?.attributes['content']?.trim() ?? '';
      }

      var intro = extractMeta('og:description');
      if (intro.isEmpty) {
        final el = doc.querySelector('#intro') ??
            doc.querySelector('.intro') ??
            doc.querySelector('.book-intro') ??
            doc.querySelector('#bookintro');
        if (el != null) intro = el.text.trim();
      }

      var updateTime = extractMeta('og:novel:update_time');
      if (updateTime.isEmpty) {
        final el = doc.querySelector('.update') ??
            doc.querySelector('.uptime') ??
            doc.querySelector('.time') ??
            doc.querySelector('#info p:nth-child(5)');
        if (el != null) {
          updateTime = el.text.replaceAll(RegExp(r'最后更新[：:]\s*'), '').trim();
        }
      }

      var status = extractMeta('og:novel:status');
      if (status.isEmpty) {
        final text = doc.body?.text ?? '';
        if (text.contains('已完结') || text.contains('全本完结') || text.contains('完本')) {
          status = '已完结';
        } else if (text.contains('连载')) {
          status = '连载中';
        }
      }

      var latestChapter = extractMeta('og:novel:latest_chapter_name');

      return {
        'intro': intro.isNotEmpty ? intro : null,
        'updateTime': updateTime.isNotEmpty ? updateTime : null,
        'status': status.isNotEmpty ? status : null,
        'latestChapter': latestChapter.isNotEmpty ? latestChapter : null,
      };
    } catch (e) {
      debugPrint('拉取书籍详情元数据失败: $e');
      return {};
    }
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

