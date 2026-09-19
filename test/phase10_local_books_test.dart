import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:fast_gbk/fast_gbk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_reader_flutter/core/theme/soft_theme.dart';
import 'package:novel_reader_flutter/features/local_books/presentation/wifi_transfer_dialog.dart';
import 'package:novel_reader_flutter/features/local_books/services/epub_parser_engine.dart';
import 'package:novel_reader_flutter/features/local_books/services/txt_parser_engine.dart';
import 'package:novel_reader_flutter/features/local_books/services/wifi_transfer_server.dart';
import 'package:novel_reader_flutter/features/shelf/presentation/shelf_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('phase10_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('阶段 10：大文件流式 TXT 智能分章解析引擎测试', () {
    test('UTF-8 编码与多格式章回切分及 RandomAccessFile 流式读取验证', () async {
      const txtContent = '''
【作品前言】
这是一个波澜壮阔的世界。前言介绍了一些背景设定。

第一章 初入江湖
少年提剑走出了村庄。微风拂过麦浪，天空澄澈如洗。
他心中充满了对未来的无限向往。

第二章 奇遇深山
深山老林里有灵兽出没。
一道白光划破长夜，遗落下一本古朴的秘籍。

Chapter 3 The Heritage
传承之光洒落在少年的眉心。
他感受到了前所未有的磅礴力量。

尾声
岁月悠悠，一代传奇就此落幕。
''';

      final file = File('${tempDir.path}/test_utf8.txt');
      await file.writeAsString(txtContent, encoding: utf8);

      // 1. 扫描分章
      final chapters = await TxtParserEngine.parseChapters(file);
      expect(chapters.length, greaterThanOrEqualTo(4));
      expect(chapters.first.title, contains('序言 / 引子'));
      expect(chapters[1].title, contains('第一章 初入江湖'));
      expect(chapters[2].title, contains('第二章 奇遇深山'));
      expect(chapters[3].title, contains('Chapter 3'));

      // 2. 流式读取第二章正文
      final paras = await TxtParserEngine.readChapterContent(file, chapters[2]);
      expect(paras.isNotEmpty, isTrue);
      expect(paras.first, contains('深山老林里有灵兽出没'));
      expect(paras.first.startsWith('\u3000\u3000'), isTrue); // 2em 缩进规范
    });

    test('GBK 编码自动嗅探与分章无损解码测试', () async {
      const gbkText = '''
楔子 宿命的齿轮
天地玄黄，宇宙洪荒。

第1章 惊世觉醒
少年从梦境中猛然苏醒，额头冷汗涔涔。
这一天，命运的转折悄然到来。
''';

      final gbkBytes = gbk.encode(gbkText);
      final file = File('${tempDir.path}/test_gbk.txt');
      await file.writeAsBytes(gbkBytes);

      // 嗅探编码
      final detected = TxtParserEngine.detectEncoding(
          Uint8List.fromList(gbkBytes.sublist(0, 50)));
      expect(detected, equals(gbk));

      // 扫描分章
      final chapters = await TxtParserEngine.parseChapters(file);
      expect(chapters.length, equals(2));
      expect(chapters[0].title, contains('楔子 宿命的齿轮'));
      expect(chapters[1].title, contains('第1章 惊世觉醒'));

      // 读取正文
      final paras = await TxtParserEngine.readChapterContent(file, chapters[1],
          encoding: gbk);
      expect(paras.any((p) => p.contains('少年从梦境中猛然苏醒')), isTrue);
    });
  });

  group('阶段 10：EPUB 图文精排解包与解析引擎测试', () {
    test('纯 Dart 构造轻量 EPUB 解包 OPF/NCX 与段落提取', () async {
      // 动态构建测试 EPUB
      final archive = Archive();

      // 1. mimetype
      final mimeBytes = utf8.encode('application/epub+zip');
      archive.addFile(ArchiveFile('mimetype', mimeBytes.length, mimeBytes));

      // 2. META-INF/container.xml
      const containerXml = '''<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>''';
      final containerBytes = utf8.encode(containerXml);
      archive.addFile(ArchiveFile(
          'META-INF/container.xml', containerBytes.length, containerBytes));

      // 3. OEBPS/content.opf
      const opfXml = '''<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="BookId">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>雪中悍刀行精排版</dc:title>
    <dc:creator>烽火戏诸侯</dc:creator>
  </metadata>
  <manifest>
    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="ch01" href="text/ch01.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine toc="ncx">
    <itemref idref="ch01"/>
  </spine>
</package>''';
      final opfBytes = utf8.encode(opfXml);
      archive
          .addFile(ArchiveFile('OEBPS/content.opf', opfBytes.length, opfBytes));

      // 4. OEBPS/toc.ncx
      const ncxXml = '''<?xml version="1.0" encoding="UTF-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <navMap>
    <navPoint id="np1" playOrder="1">
      <navLabel><text>第一章 北凉刀出鞘</text></navLabel>
      <content src="text/ch01.xhtml"/>
    </navPoint>
  </navMap>
</ncx>''';
      final ncxBytes = utf8.encode(ncxXml);
      archive.addFile(ArchiveFile('OEBPS/toc.ncx', ncxBytes.length, ncxBytes));

      // 5. OEBPS/text/ch01.xhtml
      const ch01Xhtml = '''<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>第一章 北凉刀出鞘</title></head>
<body>
  <h1>第一章 北凉刀出鞘</h1>
  <p>小二，上一壶滚烫的黄酒，再切二斤上好的熟牛肉！</p>
  <p>老仆牵着一匹瘦骨嶙峋的老马，步履蹒跚地走入风雪中。</p>
</body>
</html>''';
      final ch01Bytes = utf8.encode(ch01Xhtml);
      archive.addFile(
          ArchiveFile('OEBPS/text/ch01.xhtml', ch01Bytes.length, ch01Bytes));

      final zipBytes = ZipEncoder().encode(archive);
      final epubFile = File('${tempDir.path}/test_book.epub');
      await epubFile.writeAsBytes(zipBytes);

      // 执行解析
      final epubInfo = await EpubParserEngine.parseEpub(epubFile);
      expect(epubInfo.title, equals('雪中悍刀行精排版'));
      expect(epubInfo.author, equals('烽火戏诸侯'));
      expect(epubInfo.chapters.length, equals(1));
      expect(epubInfo.chapters.first.title, contains('第一章 北凉刀出鞘'));

      // 读取 XHTML 段落
      final paras = await EpubParserEngine.readChapterContent(
          epubFile, epubInfo.chapters.first);
      expect(paras.length, equals(2));
      expect(paras[0], contains('小二，上一壶滚烫的黄酒'));
      expect(paras[1], contains('老仆牵着一匹瘦骨嶙峋的老马'));
    });
  });

  group('阶段 10：局域网 WiFi 网页传书 HTTP 服务测试', () {
    test('启动 HTTP 传书服务、请求状态及模拟文件上传', () async {
      final originalOverrides = HttpOverrides.current;
      HttpOverrides.global = null;

      try {
        final server = WifiTransferServer();
        server.customUploadDir = tempDir.path;
        const testPort = 18888;

        final started = await server.start(port: testPort);
        expect(started, isTrue);
        expect(server.status, equals(WifiServerStatus.running));

        final client = HttpClient();

        // 1. GET / 验证网页返回
        final getReq =
            await client.getUrl(Uri.parse('http://127.0.0.1:$testPort/'));
        final getRes = await getReq.close();
        expect(getRes.statusCode, equals(HttpStatus.ok));
        final html = await utf8.decodeStream(getRes);
        expect(html, contains('藏书阁 · 局域网 WiFi 极速传书'));
        expect(html, contains('拖拽 TXT 或 EPUB 文件到这里'));

        // 2. GET /api/status 验证状态 JSON
        final statusReq = await client
            .getUrl(Uri.parse('http://127.0.0.1:$testPort/api/status'));
        final statusRes = await statusReq.close();
        expect(statusRes.statusCode, equals(HttpStatus.ok));
        final statusJson = jsonDecode(await utf8.decodeStream(statusRes))
            as Map<String, dynamic>;
        expect(statusJson['status'], equals('running'));
        expect(statusJson['port'], equals(testPort));

        // 3. POST /api/upload 模拟上传
        bool fileReceivedCalled = false;
        server.onFileReceived = (file) async {
          fileReceivedCalled = true;
        };

        final uploadUri = Uri.parse(
            'http://127.0.0.1:$testPort/api/upload?filename=my_novel.txt');
        final uploadReq = await client.postUrl(uploadUri);
        uploadReq.headers.contentType = ContentType.text;
        uploadReq.write('第一章 剑起风云\n青衫少年踏雪而归。');
        final uploadRes = await uploadReq.close();
        expect(uploadRes.statusCode, equals(HttpStatus.ok));
        final uploadJson = jsonDecode(await utf8.decodeStream(uploadRes))
            as Map<String, dynamic>;
        expect(uploadJson['success'], isTrue);
        expect(uploadJson['filename'], equals('my_novel.txt'));
        expect(fileReceivedCalled, isTrue);

        client.close();
        await server.stop();
        expect(server.status, equals(WifiServerStatus.stopped));
      } finally {
        HttpOverrides.global = originalOverrides;
      }
    });
  });

  group('阶段 10：Modern Soft UI 弹窗与书架联动部件测试', () {
    testWidgets('WifiTransferDialog 弹窗渲染与网址展示测试', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: SoftTheme(
            colors: SoftColors.parchment,
            child: MaterialApp(
              home: Scaffold(
                body: WifiTransferDialog(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('WiFi 局域网极速传书'), findsOneWidget);
      expect(find.text('复制网址'), findsOneWidget);
      expect(find.textContaining('服务'), findsWidgets);
      expect(find.byIcon(Icons.wifi_tethering_rounded), findsOneWidget);
    });

    testWidgets('ShelfPage 顶部 WiFi 传书胶囊按钮挂载测试', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: SoftTheme(
            colors: SoftColors.parchment,
            child: MaterialApp(
              home: ShelfPage(
                onNavigateToDiscovery: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('shelf_wifi_transfer_btn')),
          findsOneWidget);
      expect(find.textContaining('WiFi'), findsOneWidget);

      // 点击唤起 WiFi 传书弹窗
      await tester.tap(find.byKey(const ValueKey('shelf_wifi_transfer_btn')));
      await tester.pumpAndSettle();

      expect(find.text('WiFi 局域网极速传书'), findsOneWidget);
      expect(find.text('复制网址'), findsOneWidget);
    });
  });
}
