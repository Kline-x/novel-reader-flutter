import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_reader_flutter/features/local_books/services/txt_parser_engine.dart';

/// 用用户提供的真实 24MB 网文 TXT 验证分章与正文读取
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final realBook = File(r'C:\Users\gaore\Downloads\626.txt');

  test('真实书籍：编码识别 + 分章 + 正文读取', () async {
    if (!realBook.existsSync()) {
      // ignore: avoid_print
      print('跳过：样本文件不存在');
      return;
    }

    final sw = Stopwatch()..start();
    final chapters = await TxtParserEngine.parseChapters(realBook);
    sw.stop();

    // ignore: avoid_print
    print('文件大小: ${realBook.lengthSync()} 字节');
    // ignore: avoid_print
    print('解析耗时: ${sw.elapsedMilliseconds} ms');
    // ignore: avoid_print
    print('章节数: ${chapters.length}');
    for (final c in chapters.take(6)) {
      // ignore: avoid_print
      print('  [${c.index}] ${c.title}  @${c.byteOffset} len=${c.byteLength}');
    }

    expect(chapters.length, greaterThan(100), reason: '真实长篇应能切出大量章节');

    // 抽查中间一章的正文是否可读、无乱码
    final mid = chapters[chapters.length ~/ 2];
    final paras = await TxtParserEngine.readChapterContent(realBook, mid);
    // ignore: avoid_print
    print('抽查章节: ${mid.title} -> ${paras.length} 段');
    // ignore: avoid_print
    print('首段: ${paras.isEmpty ? "(空)" : paras.first.substring(0, paras.first.length.clamp(0, 50))}');

    expect(paras, isNotEmpty);
    // 乱码检测：正常中文正文不应出现 U+FFFD 替换字符
    final joined = paras.join();
    expect(joined.contains('\uFFFD'), isFalse, reason: '正文出现乱码替换字符');
  });

  test('编码嗅探：16KB 采样切断多字节字符时不得误判为 GBK', () {
    // 构造一段中文，使第 16384 字节正好落在一个 3 字节汉字中间
    final text = '中' * 20000;
    final bytes = utf8.encode(text);
    for (var cut = 16382; cut <= 16386; cut++) {
      final sample = Uint8ListFrom(bytes.sublist(0, cut));
      final enc = TxtParserEngine.detectEncoding(sample);
      expect(enc, utf8, reason: '截断到 $cut 字节时被误判为 $enc');
    }
  });
}

// 便捷构造 Uint8List
// ignore: non_constant_identifier_names
Uint8List Uint8ListFrom(List<int> list) => Uint8List.fromList(list);
