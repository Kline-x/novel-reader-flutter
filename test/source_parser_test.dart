import 'package:flutter_test/flutter_test.dart';
import 'package:novel_reader_flutter/features/reader/services/chapter_helper.dart';
import 'package:novel_reader_flutter/features/sources/models/chapter_item.dart';
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

    test('夜天连看与鬼吹灯书屋 toc 选择器不包含 :nth-of-type，且笔趣阁7配置完整', () {
      final yetianlian = BuiltinSources.findByName('夜天连看')!;
      expect(yetianlian.toc.item, '.listmain dd a');
      expect(yetianlian.toc.item.contains(':nth-of-type'), isFalse);

      final gdbzkz = BuiltinSources.findByName('鬼吹灯书屋')!;
      expect(gdbzkz.toc.item, '.listmain dd a');
      expect(gdbzkz.toc.item.contains(':nth-of-type'), isFalse);

      final biquge7 = BuiltinSources.findByName('笔趣阁7')!;
      expect(biquge7.enabled, isTrue);
      expect(biquge7.baseUrl, 'https://www.biquge7.xyz');
      expect(biquge7.toc.item, '.list ul li a');
      expect(biquge7.chapter.content.selector, '.text');
    });

    test('SourceParser.findRuleByUrl 智能匹配已注册书源规则', () {
      expect(SourceParser.findRuleByUrl('https://www.biquge7.xyz/book/123')?.name, '笔趣阁7');
      expect(SourceParser.findRuleByUrl('http://www.yetianlian.info/s.php')?.name, '夜天连看');
      expect(SourceParser.findRuleByUrl('http://gdbzkz.org/book/1')?.name, '鬼吹灯书屋');
      expect(SourceParser.findRuleByUrl('cn.ttkan.co/novel/1')?.name, '天天看小说');
      expect(SourceParser.findRuleByUrl('https://unknown-domain.com/1'), isNull);
      expect(SourceParser.findRuleByUrl(''), isNull);
    });

    test('sanitizeAndOrderChapters 绝不因小说多卷章节序号重置而破坏连续章回顺序', () {
      // 模拟多卷小说：第1卷第1-20章，第2卷第1-20章，第3卷第1-20章
      final multiVolumeChapters = <ChapterItem>[];
      int globalIdx = 0;
      for (int vol = 1; vol <= 3; vol++) {
        for (int ch = 1; ch <= 20; ch++) {
          multiVolumeChapters.add(ChapterItem(
            index: globalIdx++,
            title: '第$ch章 第$vol卷之第$ch章',
            url: 'https://site.com/book/ch_${vol}_$ch.html',
          ));
        }
      }

      final result = SourceParser.sanitizeAndOrderChapters(multiVolumeChapters);

      // 总数保持 60 章
      expect(result.length, 60);
      // 第 0 章是第 1 卷第 1 章
      expect(result[0].title, '第1章 第1卷之第1章');
      // 第 20 章是第 2 卷第 1 章（绝不能被重排到最前！）
      expect(result[20].title, '第1章 第2卷之第1章');
      // 第 40 章是第 3 卷第 1 章（绝不能被重排到最前！）
      expect(result[40].title, '第1章 第3卷之第1章');
      // 整体索引单调连续 0..59
      for (int i = 0; i < result.length; i++) {
        expect(result[i].index, i);
      }
    });

    test('ChapterHelper 修复第 83 行标题为空的问题，并完美支持《恶魔法则》', () {
      // 1. 测试 getFallbackChapters 标题拼接正确（杜绝第  章没标题）
      final fallbackEmo = ChapterHelper.getFallbackChapters('恶魔法则');
      expect(fallbackEmo.length, 12);
      expect(fallbackEmo[0].title, '第1章 伯爵的儿子');
      expect(fallbackEmo[1].title, '第2章 白痴');
      expect(fallbackEmo[2].title, '第3章 文不成武不就');
      expect(fallbackEmo[11].title, '第12章 传奇家族');

      // 2. 测试 getChapterNamesForBook 支持《恶魔法则》(emofaze / 恶魔)
      final namesPinyin = ChapterHelper.getChapterNamesForBook('emofaze');
      expect(namesPinyin.first, '伯爵的儿子');
      expect(namesPinyin.last, '传奇家族');

      // 3. 测试 getParagraphsForBookAndChapter 支持杜维·罗林真实背景，绝无周明瑞或齐夏
      final paragraphs = ChapterHelper.getParagraphsForBookAndChapter('《恶魔法则》', 0);
      expect(paragraphs.isNotEmpty, isTrue);
      final combined = paragraphs.join();
      expect(combined, contains('杜维·罗林'));
      expect(combined, contains('罗林家族'));
      expect(combined.contains('周明瑞'), isFalse);
      expect(combined.contains('齐夏'), isFalse);
      expect(combined.contains('李火旺'), isFalse);
    });
  });
}
