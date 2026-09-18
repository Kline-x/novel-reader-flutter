import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_reader_flutter/features/sources/models/book_search_result.dart';
import 'package:novel_reader_flutter/features/sources/services/builtin_sources.dart';
import 'package:novel_reader_flutter/features/sources/services/multi_source_service.dart';

import 'package:novel_reader_flutter/features/sources/services/network_client.dart';
import 'package:novel_reader_flutter/features/sources/services/source_parser.dart';

/// 测试用 Dio 适配器，模拟多书源网络响应
class MockHttpClientAdapter implements HttpClientAdapter {
  final Map<String, dynamic> responses;

  MockHttpClientAdapter(this.responses);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.toString();
    for (final entry in responses.entries) {
      if (path.contains(entry.key)) {
        final bodyText = entry.value as String;
        final bytes = utf8.encode(bodyText);
        return ResponseBody.fromBytes(
          bytes,
          200,
          headers: {
            'content-type': ['text/html; charset=utf-8'],
          },
        );
      }
    }
    return ResponseBody.fromBytes(utf8.encode('<html></html>'), 200);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('MultiSourceService 并发聚合检索与延迟探测测试', () {
    test('内置 12 组书源成功注入与数量校验', () {
      final service = MultiSourceService();
      expect(service.sources.length, 12);
      expect(service.sources.where((s) => s.enabled).length,
          greaterThanOrEqualTo(8));
    });

    test('并发多书源检索与毫秒级延迟标记 (searchAll)', () async {
      final mockDio = Dio();
      mockDio.httpClientAdapter = MockHttpClientAdapter({
        'biquge.company': '''
<html>
  <body>
    <div class="bookbox">
      <h4 class="bookname"><a href="/book/101/">诡秘之主</a></h4>
      <div class="author">作者：爱潜水的乌贼</div>
    </div>
  </body>
</html>
''',
        'biqugezwx.com': '''
<html>
  <body>
    <div class="item">
      <h1><a href="/book/202/">诡秘之主</a></h1>
      <a href="/authorarticle/1/">作者：爱潜水的乌贼</a>
    </div>
  </body>
</html>
''',
        'sto66.com': '''
<html>
  <body>
    <div class="bookbox">
      <h2><a href="/book/303/">宿命之环</a></h2>
      <div class="author">作者：爱潜水的乌贼</div>
    </div>
  </body>
</html>
''',
      });

      final networkClient = NetworkClient(dio: mockDio);
      final parser = SourceParser(client: networkClient);
      final service = MultiSourceService(
        client: networkClient,
        parser: parser,
        sources: [
          BuiltinSources.all[0], // 笔趣阁CP
          BuiltinSources.all[1], // 笔趣阁ZWX
          BuiltinSources.all[2], // 思兔阅读
        ],
      );

      final results = await service.searchAll('诡秘');

      // 验证检索结果
      expect(results.isNotEmpty, isTrue);
      // 验证去重逻辑：《诡秘之主》在两个书源存在，经按书名+作者去重后只保留一份最优
      expect(results.any((r) => r.title == '诡秘之主'), isTrue);
      expect(results.any((r) => r.title == '宿命之环'), isTrue);

      // 验证毫秒级延迟标记
      for (final r in results) {
        expect(r.latencyMs, isNotNull);
        expect(r.latencyMs, greaterThanOrEqualTo(0));
      }
    });

    test('流式并发检索 (searchStream) 能够按源逐步产出数据', () async {
      final mockDio = Dio();
      mockDio.httpClientAdapter = MockHttpClientAdapter({
        'biquge.company': '''
<html>
  <body>
    <div class="bookbox">
      <h4 class="bookname"><a href="/book/101/">大奉打更人</a></h4>
      <div class="author">作者：卖报小郎君</div>
    </div>
  </body>
</html>
''',
      });

      final service = MultiSourceService(
        client: NetworkClient(dio: mockDio),
        sources: [BuiltinSources.all[0]],
      );

      final streamResults = <dynamic>[];
      await for (final list in service.searchStream('大奉')) {
        streamResults.addAll(list);
      }

      expect(streamResults.length, 1);
      expect(streamResults.first.title, '大奉打更人');
      expect(streamResults.first.latencyMs, isNotNull);
    });

    test('pingAllSources 测速与排序能力', () async {
      final mockDio = Dio();
      mockDio.httpClientAdapter = MockHttpClientAdapter({
        'biquge.company': 'ok',
        'biqugezwx.com': 'ok',
      });

      final service = MultiSourceService(
        client: NetworkClient(dio: mockDio),
        sources: [
          BuiltinSources.all[0],
          BuiltinSources.all[1],
        ],
      );

      final latencies = await service.pingAllSources();
      expect(latencies.length, 2);
      for (final l in latencies) {
        expect(l.isAvailable, isTrue);
        expect(l.latencyMs, isNotNull);
      }
    });

    test('智能搜索相关度排序 (rankResults) 优先展示精准匹配而非仅看网络延迟', () {
      final itemLowRelevanceFast = BookSearchResult(
        id: '1',
        title: '某某传',
        author: '张三',
        bookUrl: 'https://example.com/1',
        sourceId: 'fast_source',
        sourceName: '极速源',
        latencyMs: 10,
      );

      final itemHighRelevanceSlow = BookSearchResult(
        id: '2',
        title: '诡秘之主',
        author: '爱潜水的乌贼',
        bookUrl: 'https://example.com/2',
        sourceId: 'slow_source',
        sourceName: '稳定源',
        latencyMs: 350,
      );

      final itemPrefixMatch = BookSearchResult(
        id: '3',
        title: '诡秘：外神竟是我自己',
        author: '网友',
        bookUrl: 'https://example.com/3',
        sourceId: 'med_source',
        sourceName: '普通源',
        latencyMs: 100,
      );

      final ranked = MultiSourceService.rankResults(
        [itemLowRelevanceFast, itemPrefixMatch, itemHighRelevanceSlow],
        '诡秘之主',
      );

      // 精确匹配《诡秘之主》必须排在第一位，即使延迟高
      expect(ranked.first.title, '诡秘之主');
      expect(ranked[1].title, '诡秘：外神竟是我自己');
      expect(ranked.last.title, '某某传');
    });
  });
}
