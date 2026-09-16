import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:fast_gbk/fast_gbk.dart';

/// 智能 HTTP 请求客户端 (network_client.dart)
/// 支持自动嗅探 Content-Type 与 HTML meta charset，
/// 集成 fast_gbk 无损解码 GBK/GB2312 字节流，解决老网文站点乱码问题。
class NetworkClient {
  final Dio _dio;

  NetworkClient({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 15),
                responseType: ResponseType.bytes,
                headers: {
                  'User-Agent':
                      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
                      'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
                  'Accept':
                      'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
                  'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
                },
                followRedirects: true,
                maxRedirects: 5,
                validateStatus: (status) => status != null && status >= 200 && status < 400,
              ),
            );

  Dio get dio => _dio;

  /// 发起请求并无损解码为 HTML 文本
  Future<String> fetchHtml(
    String url, {
    String? defaultCharset,
    Map<String, dynamic>? headers,
    Duration? timeout,
    String method = 'GET',
    dynamic data,
  }) async {
    final options = Options(
      method: method.toUpperCase(),
      responseType: ResponseType.bytes,
      headers: headers,
      sendTimeout: timeout,
      receiveTimeout: timeout,
    );

    final response = await _dio.request<List<int>>(
      url,
      data: data,
      options: options,
    );

    final bytes = response.data ?? <int>[];
    final contentType = response.headers.value('content-type');
    final detectedCharset = detectCharset(
      bytes,
      contentType: contentType,
      defaultCharset: defaultCharset,
    );

    return decodeBytes(bytes, charset: detectedCharset);
  }

  /// 自动探测字节流的编码格式 ('utf-8' 或 'gbk')
  static String detectCharset(
    List<int> bytes, {
    String? contentType,
    String? defaultCharset,
  }) {
    // 1. 优先检查 HTTP Header: Content-Type 中的 charset
    if (contentType != null && contentType.isNotEmpty) {
      final headerCharset = _extractCharset(contentType);
      if (headerCharset != null) {
        return _normalizeCharset(headerCharset);
      }
    }

    // 2. 检查 HTML 前 2048 字节中的 <meta charset="..."> 或 <meta http-equiv="Content-Type" ...>
    if (bytes.isNotEmpty) {
      final headLength = bytes.length < 2048 ? bytes.length : 2048;
      // 以 Latin-1 / ASCII 方式快速转换为小写字符串扫描元标签
      final headString = String.fromCharCodes(bytes.sublist(0, headLength)).toLowerCase();

      // <meta charset="gbk">
      final metaCharsetMatch = RegExp(r'<meta[^>]+charset=["' "'" r']?([a-zA-Z0-9_\-]+)')
          .firstMatch(headString);
      if (metaCharsetMatch != null) {
        final charset = metaCharsetMatch.group(1);
        if (charset != null) {
          return _normalizeCharset(charset);
        }
      }

      // <meta http-equiv="Content-Type" content="text/html; charset=gb2312">
      final httpEquivMatch = RegExp(r'content=["' "'" r'][^"' "'" r']*charset=([a-zA-Z0-9_\-]+)')
          .firstMatch(headString);
      if (httpEquivMatch != null) {
        final charset = httpEquivMatch.group(1);
        if (charset != null) {
          return _normalizeCharset(charset);
        }
      }
    }

    // 3. 检查兜底规则指定的 charset
    if (defaultCharset != null && defaultCharset.isNotEmpty) {
      return _normalizeCharset(defaultCharset);
    }

    // 4. 启发式探测：尝试 utf-8 解码，若出现 FormatException 则降级为 gbk
    try {
      utf8.decode(bytes, allowMalformed: false);
      return 'utf-8';
    } catch (_) {
      return 'gbk';
    }
  }

  /// 标准化字符集名称
  static String _normalizeCharset(String charset) {
    final lower = charset.toLowerCase().trim();
    if (lower.contains('gbk') || lower.contains('gb2312') || lower.contains('gb18030')) {
      return 'gbk';
    }
    return 'utf-8';
  }

  static String? _extractCharset(String text) {
    final match = RegExp(r'charset=([a-zA-Z0-9_\-]+)', caseSensitive: false).firstMatch(text);
    return match?.group(1);
  }

  /// 使用 fast_gbk 或 utf8 对字节数组解码
  static String decodeBytes(List<int> bytes, {String? charset}) {
    final normalized = _normalizeCharset(charset ?? 'utf-8');
    if (normalized == 'gbk') {
      try {
        return gbk.decode(bytes, allowMalformed: true);
      } catch (_) {
        return utf8.decode(bytes, allowMalformed: true);
      }
    } else {
      try {
        return utf8.decode(bytes, allowMalformed: false);
      } catch (_) {
        // UTF-8 报错时自动兜底 GBK 解码
        try {
          return gbk.decode(bytes, allowMalformed: true);
        } catch (_) {
          return utf8.decode(bytes, allowMalformed: true);
        }
      }
    }
  }

  /// 对搜索关键词进行特定编码（GBK 站点需发送 GBK 百分号转义，如 %B9%ED%C3%D8）
  static String encodeKeyword(String keyword, {String charset = 'utf-8'}) {
    final normalized = _normalizeCharset(charset);
    if (normalized == 'gbk') {
      final bytes = gbk.encode(keyword);
      final buffer = StringBuffer();
      for (final b in bytes) {
        if (_isUnreservedUriByte(b)) {
          buffer.writeCharCode(b);
        } else {
          buffer.write('%');
          buffer.write(b.toRadixString(16).toUpperCase().padLeft(2, '0'));
        }
      }
      return buffer.toString();
    } else {
      return Uri.encodeQueryComponent(keyword);
    }
  }

  static bool _isUnreservedUriByte(int byte) {
    // 0-9, A-Z, a-z, '-', '_', '.', '~'
    return (byte >= 48 && byte <= 57) ||
        (byte >= 65 && byte <= 90) ||
        (byte >= 97 && byte <= 122) ||
        byte == 45 ||
        byte == 95 ||
        byte == 46 ||
        byte == 126;
  }

  /// 测速测通：测试 URL 响应延迟（毫秒），失败返回 null
  Future<int?> measureLatency(String url, {Duration timeout = const Duration(seconds: 5)}) async {
    final sw = Stopwatch()..start();
    try {
      final response = await _dio.request<dynamic>(
        url,
        options: Options(
          method: 'GET',
          sendTimeout: timeout,
          receiveTimeout: timeout,
          responseType: ResponseType.bytes,
        ),
      );
      sw.stop();
      if (response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 400) {
        return sw.elapsedMilliseconds;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
