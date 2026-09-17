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

    test('parseChineseNumber 中文大写数字正确转换', () {
      expect(SourceParser.parseChineseNumber('一'), 1);
      expect(SourceParser.parseChineseNumber('二'), 2);
      expect(SourceParser.parseChineseNumber('九'), 9);
      expect(SourceParser.parseChineseNumber('十'), 10);
      expect(SourceParser.parseChineseNumber('二十三'), 23);
      expect(SourceParser.parseChineseNumber('一百零五'), 105);
      expect(SourceParser.parseChineseNumber('一千四百三十二'), 1432);
    });

    test('extractChapterNumber 章节提取与前言/后记识别', () {
      expect(SourceParser.extractChapterNumber('楔子'), 0);
      expect(SourceParser.extractChapterNumber('第一章 绯红'), 1);
      expect(SourceParser.extractChapterNumber('第二章 魔药'), 2);
      expect(SourceParser.extractChapterNumber('第九章 笔记'), 9);
      expect(SourceParser.extractChapterNumber('第十章 命运'), 10);
      expect(SourceParser.extractChapterNumber('第二十三章 占卜'), 23);
      expect(SourceParser.extractChapterNumber('1417. 尾声'), 1417);
      expect(SourceParser.extractChapterNumber('后记'), 999999);
    });

    test('sanitizeAndOrderChapters 修复表格跨列错序与前置最新章节预览', () {
      final scrambled = [
        const ChapterItem(index: 0, title: '1417. 尾声', url: 'https://site.com/18871.html'),
        const ChapterItem(index: 1, title: '第一章 绯红', url: 'https://site.com/17455.html'),
        const ChapterItem(index: 2, title: '第八章 聚会', url: 'https://site.com/17462.html'),
        const ChapterItem(index: 3, title: '第十五章 占卜', url: 'https://site.com/17469.html'),
        const ChapterItem(index: 4, title: '第二章 魔药', url: 'https://site.com/17456.html'),
        const ChapterItem(index: 5, title: '第九章 笔记', url: 'https://site.com/17463.html'),
        const ChapterItem(index: 6, title: '第十六章 观众', url: 'https://site.com/17470.html'),
        const ChapterItem(index: 7, title: '第三章 梅丽莎', url: 'https://site.com/17457.html'),
        const ChapterItem(index: 8, title: '第十章 命运', url: 'https://site.com/17464.html'),
        const ChapterItem(index: 9, title: '第二十三章 太阳', url: 'https://site.com/17477.html'),
        const ChapterItem(index: 10, title: '1417. 尾声', url: 'https://site.com/18871.html'),
      ];

      final ordered = SourceParser.sanitizeAndOrderChapters(scrambled);
      expect(ordered.first.title, '第一章 绯红');
      expect(ordered[0].index, 0);
      expect(ordered[1].title, '第二章 魔药');
      expect(ordered[1].index, 1);
      expect(ordered[2].title, '第三章 梅丽莎');
      expect(ordered[2].index, 2);
      expect(ordered[3].title, '第八章 聚会');
      expect(ordered[4].title, '第九章 笔记');
      expect(ordered[5].title, '第十章 命运');
      expect(ordered[6].title, '第十五章 占卜');
      expect(ordered[7].title, '第十六章 观众');
      expect(ordered[8].title, '第二十三章 太阳');
      expect(ordered.last.title, '1417. 尾声');
    });
  });
}
