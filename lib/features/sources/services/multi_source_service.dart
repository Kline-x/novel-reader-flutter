import 'dart:async';
import '../models/book_search_result.dart';
import '../models/source_rule.dart';
import 'builtin_sources.dart';
import 'network_client.dart';
import 'source_parser.dart';

/// 书源测速结果结构体
class SourceLatency {
  final String sourceId;
  final String sourceName;
  final int? latencyMs;
  final bool isAvailable;

  const SourceLatency({
    required this.sourceId,
    required this.sourceName,
    required this.latencyMs,
    required this.isAvailable,
  });

  @override
  String toString() =>
      'SourceLatency($sourceName: ${isAvailable ? "${latencyMs}ms" : "不可用"})';
}

/// 多书源聚合检索与测速服务 (multi_source_service.dart)
/// 支持并发对 12 组内置书源进行关键词聚合检索，
/// 并为每组书源测速测通、精确标注毫秒级延迟。
class MultiSourceService {
  final List<SourceRule> _sources;
  final SourceParser _parser;
  final NetworkClient _client;

  MultiSourceService({
    List<SourceRule>? sources,
    SourceParser? parser,
    NetworkClient? client,
  })  : _client = client ?? NetworkClient(),
        _parser = parser ?? SourceParser(client: client),
        _sources = sources ?? BuiltinSources.all;

  List<SourceRule> get sources => List.unmodifiable(_sources);
  SourceParser get parser => _parser;
  NetworkClient get client => _client;

  /// 并发多源聚合检索
  ///
  /// [keyword] 搜索关键词
  /// [timeout] 单源超时阈值（默认 8 秒，规避慢源拖慢整体）
  /// [enabledOnly] 是否仅检索启用的书源（默认 true）
  Future<List<BookSearchResult>> searchAll(
    String keyword, {
    Duration timeout = const Duration(seconds: 8),
    bool enabledOnly = true,
  }) async {
    final targetSources =
        enabledOnly ? _sources.where((s) => s.enabled).toList() : _sources;

    final searchFutures = targetSources.map((source) async {
      final sw = Stopwatch()..start();
      try {
        final results =
            await _parser.searchBooks(source, keyword).timeout(timeout);
        sw.stop();
        final elapsed = sw.elapsedMilliseconds;
        for (final r in results) {
          r.latencyMs = elapsed;
        }
        return results;
      } catch (_) {
        // 单源异常或超时不影响其他源
        return <BookSearchResult>[];
      }
    });

    final aggregatedList = await Future.wait(searchFutures);
    final allResults = aggregatedList.expand((list) => list).toList();

    // 根据书名与作者去重，择优保留（相关度优先，相同相关度下保留低延迟源）
    final Map<String, BookSearchResult> dedupeMap = {};
    for (final item in allResults) {
      final key = '${item.title.trim()}::${item.author.trim()}';
      if (!dedupeMap.containsKey(key)) {
        dedupeMap[key] = item;
      } else {
        final existing = dedupeMap[key]!;
        final scoreExisting = calculateRelevance(existing, keyword);
        final scoreItem = calculateRelevance(item, keyword);
        if (scoreItem > scoreExisting ||
            (scoreItem == scoreExisting &&
                (item.latencyMs ?? 9999) < (existing.latencyMs ?? 9999))) {
          dedupeMap[key] = item;
        }
      }
    }

    final sorted = dedupeMap.values.toList();
    // 智能相关度优先重排，相同相关度下按毫秒延迟升序排列
    return rankResults(sorted, keyword);
  }

  /// 智能相关度打分算法
  ///
  /// - 书名完全匹配：+10000（如搜索“诡秘之主”，精准命中书名）
  /// - 书名以关键词开头：+5000（并根据多余字数做紧凑度扣分）
  /// - 书名包含关键词：+2500（并根据多余字数做紧凑度扣分）
  /// - 作者完全匹配：+4000
  /// - 作者包含关键词：+1500
  /// - 简介/最新章节提及关键词：+50 / +30
  /// - 若书名与作者完全不含关键词中任一有效字符，判定为噪点直接剔除
  static int calculateRelevance(BookSearchResult book, String keyword) {
    final q = keyword
        .replaceAll(RegExp(r'[《》【】\[\]()（）\s]'), '')
        .trim()
        .toLowerCase();
    if (q.isEmpty) return 0;

    final t = book.title
        .replaceAll(RegExp(r'[《》【】\[\]()（）\s]'), '')
        .trim()
        .toLowerCase();
    final a = book.author
        .replaceAll(RegExp(r'[《》【】\[\]()（）\s]'), '')
        .trim()
        .toLowerCase();

    int score = 0;

    // 1. 书名完全精确匹配 (+10000)
    if (t == q) {
      score += 10000;
    }
    // 2. 书名以关键词开头 (+5000，多余字符越多扣分，越简短紧凑越优先)
    else if (t.startsWith(q)) {
      score += 5000 - ((t.length - q.length) * 20).clamp(0, 2000);
    }
    // 3. 书名包含关键词 (+2500)
    else if (t.contains(q)) {
      score += 2500 - ((t.length - q.length) * 25).clamp(0, 1500);
    }

    // 4. 作者完全精确匹配 (+4000)
    if (a == q) {
      score += 4000;
    }
    // 5. 作者包含关键词 (+1500)
    else if (a.contains(q)) {
      score += 1500;
    }

    // 6. 弱匹配辅助（简介或章节）
    if (book.intro?.toLowerCase().contains(q) == true) {
      score += 50;
    }
    if (book.latestChapter?.toLowerCase().contains(q) == true) {
      score += 30;
    }

    // 7. 书源信誉评分体系 (Source Reputation Score)
    // 优质全本源加分，跳章缺章源重度惩罚，杜绝残次源霸占榜首
    final sId = book.sourceId.toLowerCase();
    final sName = book.sourceName.toLowerCase();
    if (sId.contains('biquge7') || sName.contains('笔趣阁7')) {
      score += 1000; // 笔趣阁7（全量708章真本）最高信誉加权
    } else if (sId.contains('biqugezwx') || sName.contains('zwx')) {
      score += 600;
    } else if (sId.contains('yetian') || sName.contains('夜天')) {
      score += 500;
    } else if (sId.contains('situ') ||
        sId.contains('sto66') ||
        sName.contains('思兔')) {
      score -= 4000; // 思兔阅读（严重跳章、缺几百章）执行惩罚性降权
    }

    // 8. 最新章节进度/完整度加权（通过提取章节名中的数字判定）
    if (book.latestChapter != null) {
      final match = RegExp(r'第\s*(\d+)\s*章').firstMatch(book.latestChapter!);
      int? chNum;
      if (match != null) {
        chNum = int.tryParse(match.group(1)!);
      } else {
        chNum = SourceParser.extractChapterNumber(book.latestChapter!) ??
            int.tryParse(
                RegExp(r'(\d+)').firstMatch(book.latestChapter!)?.group(1) ??
                    '');
      }
      if (chNum != null) {
        if (chNum >= 700) {
          score += 500;
        } else if (chNum >= 500) {
          score += 200;
        }
      }
    }

    // 9. 负向过滤：若书名与作者完全不含任何关键词字符，直接判为无关噪点
    final hasAnyChar =
        q.split('').any((char) => t.contains(char) || a.contains(char));
    if (!hasAnyChar) {
      score -= 50000;
    }

    return score;
  }

  /// 智能相关度优先重排，相同相关度下按网络延迟升序排列
  static List<BookSearchResult> rankResults(
      List<BookSearchResult> list, String keyword) {
    final copy = List<BookSearchResult>.from(list);
    copy.sort((a, b) {
      final scoreA = calculateRelevance(a, keyword);
      final scoreB = calculateRelevance(b, keyword);
      if (scoreA != scoreB) {
        return scoreB.compareTo(scoreA); // 相关度高的绝对排在最前
      }
      return (a.latencyMs ?? 9999).compareTo(b.latencyMs ?? 9999);
    });
    return copy;
  }

  /// 流式并发检索：每当一个书源返回结果，立即通过 Stream 实时发射
  Stream<List<BookSearchResult>> searchStream(
    String keyword, {
    Duration timeout = const Duration(seconds: 8),
    bool enabledOnly = true,
  }) {
    final controller = StreamController<List<BookSearchResult>>();
    final targetSources =
        enabledOnly ? _sources.where((s) => s.enabled).toList() : _sources;

    int pending = targetSources.length;
    if (pending == 0) {
      controller.close();
      return controller.stream;
    }

    for (final source in targetSources) {
      final sw = Stopwatch()..start();
      _parser.searchBooks(source, keyword).timeout(timeout).then((results) {
        sw.stop();
        final elapsed = sw.elapsedMilliseconds;
        for (final r in results) {
          r.latencyMs = elapsed;
        }
        if (!controller.isClosed && results.isNotEmpty) {
          controller.add(results);
        }
      }).catchError((_) {
        // 忽略单源异常
      }).whenComplete(() {
        pending--;
        if (pending == 0 && !controller.isClosed) {
          controller.close();
        }
      });
    }

    return controller.stream;
  }

  /// 对全部书源执行连通性与毫秒级延迟测速
  Future<List<SourceLatency>> pingAllSources({
    Duration timeout = const Duration(seconds: 5),
    bool enabledOnly = false,
  }) async {
    final targetSources =
        enabledOnly ? _sources.where((s) => s.enabled).toList() : _sources;

    final futures = targetSources.map((source) async {
      final latency =
          await _client.measureLatency(source.baseUrl, timeout: timeout);
      return SourceLatency(
        sourceId: source.id,
        sourceName: source.name,
        latencyMs: latency,
        isAvailable: latency != null,
      );
    });

    final results = await Future.wait(futures);
    // 按延迟升序排序，可用在前，不可用在后
    results.sort((a, b) {
      if (a.isAvailable && !b.isAvailable) return -1;
      if (!a.isAvailable && b.isAvailable) return 1;
      return (a.latencyMs ?? 9999).compareTo(b.latencyMs ?? 9999);
    });
    return results;
  }

  /// 测试单个书源连通性
  Future<SourceLatency> pingSource(
    SourceRule source, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final latency =
        await _client.measureLatency(source.baseUrl, timeout: timeout);
    return SourceLatency(
      sourceId: source.id,
      sourceName: source.name,
      latencyMs: latency,
      isAvailable: latency != null,
    );
  }
}
