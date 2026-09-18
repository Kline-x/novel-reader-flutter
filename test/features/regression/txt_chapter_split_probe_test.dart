import 'dart:convert';
import 'dart:io';

import 'package:fast_gbk/fast_gbk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_reader_flutter/features/local_books/services/txt_parser_engine.dart';

/// 探针：用真实网文 TXT 的常见排版格式验证分章
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('txt_probe');
  });

  tearDown(() {
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {}
  });

  Future<List<String>> parse(String name, List<int> bytes) async {
    final f = File('${tmp.path}/$name');
    f.writeAsBytesSync(bytes);
    final chapters = await TxtParserEngine.parseChapters(f);
    return chapters.map((c) => c.title).toList();
  }

  test('格式A：UTF-8 + 全角缩进 + 空行分隔（最常见）', () async {
    const text = '　　第一章 意外重生\n'
        '\n'
        '　　林凡睁开眼睛，发现自己回到了十年前。\n'
        '　　窗外阳光正好。\n'
        '\n'
        '　　第二章 熟悉的校园\n'
        '\n'
        '　　他推开教室的门。\n'
        '\n'
        '　　第三章 第一次交锋\n'
        '\n'
        '　　那个人站在走廊尽头。\n';
    final titles = await parse('a.txt', utf8.encode(text));
    // ignore: avoid_print
    print('格式A -> $titles');
    expect(titles.length, greaterThanOrEqualTo(3));
  });

  test('格式B：CRLF 换行（Windows 记事本）', () async {
    const text = '第一章 序幕\r\n'
        '\r\n'
        '正文内容第一段。\r\n'
        '\r\n'
        '第二章 登场\r\n'
        '\r\n'
        '正文内容第二段。\r\n';
    final titles = await parse('b.txt', utf8.encode(text));
    // ignore: avoid_print
    print('格式B -> $titles');
    expect(titles.length, greaterThanOrEqualTo(2));
  });

  test('格式C：GBK 编码', () async {
    const text = '第一章 风起\n'
        '\n'
        '　　这是第一章的正文。\n'
        '\n'
        '第二章 云涌\n'
        '\n'
        '　　这是第二章的正文。\n';
    final titles = await parse('c.txt', gbk.encode(text));
    // ignore: avoid_print
    print('格式C -> $titles');
    expect(titles.length, greaterThanOrEqualTo(2));
  });

  test('格式D：阿拉伯数字章号 第001章 / 第 1 章', () async {
    const text = '第001章 开端\n'
        '正文一。\n'
        '第002章 发展\n'
        '正文二。\n'
        '第 3 章 高潮\n'
        '正文三。\n';
    final titles = await parse('d.txt', utf8.encode(text));
    // ignore: avoid_print
    print('格式D -> $titles');
    expect(titles.length, greaterThanOrEqualTo(3));
  });

  test('格式E：无空行紧凑排版', () async {
    const text = '第一章 相遇\n'
        '　　他们在雨里相遇。\n'
        '　　伞下只有一个人。\n'
        '第二章 别离\n'
        '　　然后她走了。\n';
    final titles = await parse('e.txt', utf8.encode(text));
    // ignore: avoid_print
    print('格式E -> $titles');
    expect(titles.length, greaterThanOrEqualTo(2));
  });

  test('格式F：末尾无换行符的最后一章', () async {
    const text = '第一章 起\n正文一。\n第二章 终\n正文二（文件末尾没有换行）。';
    final titles = await parse('f.txt', utf8.encode(text));
    // ignore: avoid_print
    print('格式F -> $titles');
    expect(titles.length, greaterThanOrEqualTo(2));
  });

  test('格式G：带 UTF-8 BOM', () async {
    const text = '第一章 开篇\n正文一。\n第二章 承接\n正文二。\n';
    final bytes = <int>[0xEF, 0xBB, 0xBF, ...utf8.encode(text)];
    final titles = await parse('g.txt', bytes);
    // ignore: avoid_print
    print('格式G -> $titles');
    expect(titles.length, greaterThanOrEqualTo(2));
  });
}
