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
    final targetSources = enabledOnly
        ? _sources.where((s) => s.enabled).toList()
        : _sources;

    final searchFutures = targetSources.map((source) async {
      final sw = Stopwatch()..start();
      try {
        final results = await _parser.searchBooks(source, keyword).timeout(timeout);
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

    // 根据书名与作者去重，保留延迟较低的优先结果
    final Map<String, BookSearchResult> dedupeMap = {};
    for (final item in allResults) {
      final key = '${item.title.trim()}::${item.author.trim()}';
      if (!dedupeMap.containsKey(key)) {
        dedupeMap[key] = item;
      } else {
        // 若当前结果延迟更低，则择优更新
        final existing = dedupeMap[key]!;
        if ((item.latencyMs ?? 9999) < (existing.latencyMs ?? 9999)) {
          dedupeMap[key] = item;
        }
      }
    }

    final sorted = dedupeMap.values.toList();
    // 按毫秒延迟升序排列，最快响应的源排在最前
    sorted.sort((a, b) => (a.latencyMs ?? 9999).compareTo(b.latencyMs ?? 9999));
    return sorted;
  }

  /// 流式并发检索：每当一个书源返回结果，立即通过 Stream 实时发射
  Stream<List<BookSearchResult>> searchStream(
    String keyword, {
    Duration timeout = const Duration(seconds: 8),
    bool enabledOnly = true,
  }) {
    final controller = StreamController<List<BookSearchResult>>();
    final targetSources = enabledOnly
        ? _sources.where((s) => s.enabled).toList()
        : _sources;

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
    final targetSources = enabledOnly
        ? _sources.where((s) => s.enabled).toList()
        : _sources;

    final futures = targetSources.map((source) async {
      final latency = await _client.measureLatency(source.baseUrl, timeout: timeout);
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
    final latency = await _client.measureLatency(source.baseUrl, timeout: timeout);
    return SourceLatency(
      sourceId: source.id,
      sourceName: source.name,
      latencyMs: latency,
      isAvailable: latency != null,
    );
  }
}
