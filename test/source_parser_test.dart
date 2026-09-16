import 'package:flutter_test/flutter_test.dart';
import 'package:novel_reader_flutter/features/sources/models/source_rule.dart';
import 'package:novel_reader_flutter/features/sources/services/builtin_sources.dart';
import 'package:novel_reader_flutter/features/sources/services/source_parser.dart';

void main() {
  group('SourceParser 书源解析与降噪清洗测试', () {
    test('内置 12 组书源完整性与基础规则健全性校验', () {
      expect(BuiltinSources.all.length, 12);
      for (final rule in BuiltinSources.all) {
        expect(rule.id.isNotEmpty, isTrue);
        expect(rule.name.isNotEmpty, isTrue);
        expect(rule.baseUrl.isNotEmpty, isTrue);
        expect(rule.search.urlTemplate.isNotEmpty, isTrue);
        expect(rule.search.item.isNotEmpty, isTrue);
        expect(rule.toc.item.isNotEmpty, isTrue);
        expect(rule.chapter.content.selector.isNotEmpty, isTrue);
      }
    });

    test('cleanAndFilterParagraphs 广告、域名、本章完与噪音精准剔除', () {
      const dirtyHtml = '''
<div class="readcontent">
  &emsp;&emsp;痛！好痛！头好痛！<br>
  绯红的月光透过窗帘的缝隙，洒在书桌上。<br/>
  请记住本书首发域名：www.biquge.company，方便下次阅读。<br>
  周明瑞按着太阳穴，低声呻吟。<br>
  天才一秒记住本站地址：http://m.biquge.com<br>
  最新网址：www.biquge.la<br>
  (本章完)<br>
  点击下一页继续阅读<br>
</div>
''';
      final paragraphs = SourceParser.cleanAndFilterParagraphs(
        SourceParser.htmlToText(dirtyHtml),
      );

      // 广告行应全部被过滤
      expect(paragraphs.any((p) => p.contains('请记住本书首发域名')), isFalse);
      expect(paragraphs.any((p) => p.contains('天才一秒记住')), isFalse);
      expect(paragraphs.any((p) => p.contains('最新网址')), isFalse);
      expect(paragraphs.any((p) => p.contains('(本章完)')), isFalse);
      expect(paragraphs.any((p) => p.contains('点击下一页继续阅读')), isFalse);

      // 真正正文内容完整保留
      expect(paragraphs, contains('痛！好痛！头好痛！'));
      expect(paragraphs, contains('绯红的月光透过窗帘的缝隙，洒在书桌上。'));
      expect(paragraphs, contains('周明瑞按着太阳穴，低声呻吟。'));
      expect(paragraphs.length, 3);
    });

    test('decodeHtmlEntities 实体解码验证（含 &emsp; 全角缩进与标点）', () {
      const raw = '&emsp;&emsp;&ldquo;我穿&hellip;&hellip;穿越了？&rdquo;&mdash;&mdash;周明瑞。';
      final decoded = SourceParser.decodeHtmlEntities(raw);
      expect(decoded, '　　“我穿……穿越了？”——周明瑞。');
    });

    test('parseChapterHtml 段落提取与空行压缩', () {
      final parser = SourceParser();
      const html = '''
<html>
  <body>
    <div id="content">
      <p>第一段内容，关于神秘学的初步探讨。</p>
      <p></p>
      <p>   </p>
      <p>第二段内容，塔罗会的正式召开。</p>
      <p>笔趣阁版权所有，禁止转载。</p>
    </div>
  </body>
</html>
''';
      const chapterRule = ChapterRule(
        content: RuleSelector(selector: '#content p', attr: 'text'),
      );
      final paragraphs = parser.parseChapterHtml(html, chapterRule);
      expect(paragraphs.length, 2);
      expect(paragraphs[0], '第一段内容，关于神秘学的初步探讨。');
      expect(paragraphs[1], '第二段内容，塔罗会的正式召开。');
    });
  });
}
