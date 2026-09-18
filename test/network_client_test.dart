import 'dart:convert';
import 'package:fast_gbk/fast_gbk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_reader_flutter/features/sources/services/network_client.dart';

void main() {
  group('NetworkClient 编码嗅探与 GBK 解码测试', () {
    test('fast_gbk 编码与无损解码老牌网文站典型中文字符串', () {
      const originalText = '第一章 绯红之月：周明瑞在迷雾与枪声中苏醒。';
      final gbkBytes = gbk.encode(originalText);

      // 验证通过 fast_gbk 编码后确为双字节 GBK
      expect(gbkBytes.length, greaterThan(originalText.length));

      // 验证 NetworkClient.decodeBytes 能正确还原
      final decoded = NetworkClient.decodeBytes(gbkBytes, charset: 'gbk');
      expect(decoded, originalText);
    });

    test('HTTP Header Content-Type 自动嗅探 GBK / UTF-8', () {
      final gbkBytes = gbk.encode('武侠世界');
      final detected = NetworkClient.detectCharset(
        gbkBytes,
        contentType: 'text/html; charset=GBK',
      );
      expect(detected, 'gbk');

      final utf8Bytes = utf8.encode('诡秘之主');
      final detectedUtf8 = NetworkClient.detectCharset(
        utf8Bytes,
        contentType: 'text/html; charset=utf-8',
      );
      expect(detectedUtf8, 'utf-8');
    });

    test('HTML 前置 <meta charset> 标签嗅探 GB2312 / GBK', () {
      const htmlSnippet = '''
<!DOCTYPE html>
<html>
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=gb2312" />
  <title>穿越小说网</title>
</head>
<body><p>正文内容</p></body>
</html>
''';
      final gbkBytes = gbk.encode(htmlSnippet);
      final detected = NetworkClient.detectCharset(gbkBytes);
      expect(detected, 'gbk');

      final decoded = NetworkClient.decodeBytes(gbkBytes, charset: detected);
      expect(decoded, contains('穿越小说网'));
      expect(decoded, contains('正文内容'));
    });

    test('UTF-8 格式异常时自动启发式降级嗅探至 GBK', () {
      // 构造包含 GBK 特有双字节的非合法 UTF-8 字节流
      final rawGbk = gbk.encode('纯洁滴小龙《捞尸人》');
      // 无任何 header 与 meta，自动降级嗅探
      final detected = NetworkClient.detectCharset(rawGbk);
      expect(detected, 'gbk');

      final decoded = NetworkClient.decodeBytes(rawGbk, charset: detected);
      expect(decoded, '纯洁滴小龙《捞尸人》');
    });

    test('GBK 搜索关键词百分号编码 (encodeKeyword)', () {
      const keyword = '诡秘';
      final encodedGbk = NetworkClient.encodeKeyword(keyword, charset: 'gbk');
      // 验证 GBK 百分号转义 (例如 %B9%ED%C3%D8)
      expect(encodedGbk, startsWith('%'));
      expect(encodedGbk.contains('%'), isTrue);

      final encodedUtf8 =
          NetworkClient.encodeKeyword(keyword, charset: 'utf-8');
      expect(encodedUtf8, '%E8%AF%A1%E7%A7%98');
    });
  });
}
