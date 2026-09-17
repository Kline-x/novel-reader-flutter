
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_reader_flutter/features/reader/engine/cjk_punctuation.dart';
import 'package:novel_reader_flutter/features/reader/engine/page_models.dart';
import 'package:novel_reader_flutter/features/reader/engine/reader_layout_engine.dart';

void main() {
  group('ReaderLayoutEngine 核心排版引擎测试', () {
    final sampleParagraphs = [
      '痛！好痛！头好痛！',
      '绯红的月光透过窗帘的缝隙，斑驳地洒在书桌上。周明瑞只觉得脑袋里仿佛插了一根烧红的铁钎，并在不停地搅动。',
      '他挣扎着想要坐起身，却发现四肢无力，整个身体沉重得如同灌了铅一般。空气中弥漫着一股刺鼻的铁锈味与劣质火药的硝烟气息。',
      '“我不是在家里睡觉吗？怎么会在这里……”周明瑞按着太阳穴，低声呻吟，记忆如同破碎的玻璃碎片在脑海中飞速划过。',
      '桌面上散落着几张草稿纸，一支带有黄铜笔尖的羽毛笔滚落在地毯上，墨水晕染开一片深黑色的污迹。旁边还摆着一把左轮手枪，枪口隐隐散发着淡淡的青烟。',
      '镜子里映照出一张年轻但毫无血色的脸庞，黑发深褐瞳孔，额头侧面赫然有一个狰狞焦黑的血洞！',
      '“自杀？他杀？我穿越了？！”周明瑞猛地屏住了呼吸。',
    ];

    test('18px 默认排版验证：整数行截断与避头标点禁则', () {
      const config18 = PagingConfig(
        viewportWidth: 390.0,
        viewportHeight: 740.0,
        fontSize: 18.0,
        lineHeight: 30.0,
        hPad: 20.0,
      );

      final pages18 = ReaderLayoutEngine.paginate(
        paragraphs: sampleParagraphs,
        title: '第一章 绯红',
        config: config18,
      );

      expect(pages18.isNotEmpty, true, reason: '分页结果不应为空');

      for (final page in pages18) {
        final maxAllowedLines =
            page.isFirstPage ? config18.firstPageMaxLines : config18.maxLinesPerPage;
        expect(
          page.lines.length <= maxAllowedLines,
          true,
          reason: '单页真实行数严禁超过最大允许整数行，否则底部文字必被裁切半截！',
        );

        for (final line in page.lines) {
          if (line.text.isNotEmpty) {
            final firstChar = line.text[0];
            expect(
              CjkPunctuation.isForbiddenStart(firstChar),
              false,
              reason: '行首出现避头标点: $firstChar',
            );
          }
        }
      }
    });

    test('改字号字符级锚点逆向映射验证 (P2-07 痛点)', () {
      const config18 = PagingConfig(
        viewportWidth: 390.0,
        viewportHeight: 740.0,
        fontSize: 18.0,
        lineHeight: 30.0,
        hPad: 20.0,
      );

      final pages18 = ReaderLayoutEngine.paginate(
        paragraphs: sampleParagraphs,
        title: '第一章 绯红',
        config: config18,
      );

      const readingCharOffset = 220;
      final originalPage =
          ReaderLayoutEngine.findPageByCharOffset(pages18, readingCharOffset);
      expect(originalPage >= 0, true);

      // 读者将字号从 18px 调大为 24px
      const config24 = PagingConfig(
        viewportWidth: 390.0,
        viewportHeight: 740.0,
        fontSize: 24.0,
        lineHeight: 40.0,
        hPad: 20.0,
      );

      final pages24 = ReaderLayoutEngine.paginate(
        paragraphs: sampleParagraphs,
        title: '第一章 绯红',
        config: config24,
      );

      final targetPage24 =
          ReaderLayoutEngine.findPageByCharOffset(pages24, readingCharOffset);

      expect(
        pages24[targetPage24].containsCharOffset(readingCharOffset),
        true,
        reason: '新页面必须严密包含该字符偏移锚点，保证读者阅读视口精准不跳脱！',
      );
    });

    test('页面交界处字符偏移无缝映射与边界包含验证 (解决翻到第2页退出重进误判第1页缺陷)', () {
      const page0 = ChapterPage(
        pageIndex: 0,
        lines: [],
        charStart: 0,
        charEnd: 120,
        isFirstPage: true,
        isLastPage: false,
      );
      const page1 = ChapterPage(
        pageIndex: 1,
        lines: [],
        charStart: 120,
        charEnd: 250,
        isFirstPage: false,
        isLastPage: false,
      );
      const page2 = ChapterPage(
        pageIndex: 2,
        lines: [],
        charStart: 250,
        charEnd: 380,
        isFirstPage: false,
        isLastPage: true,
      );

      final pages = [page0, page1, page2];

      // 验证 page0 区间 [0, 120)
      expect(page0.containsCharOffset(0), isTrue);
      expect(page0.containsCharOffset(119), isTrue);
      expect(page0.containsCharOffset(120), isFalse,
          reason: 'charEnd 120 严禁被非末尾页 page0 包含，否则第2页首字符会被错误归类到第1页！');

      // 验证 page1 区间 [120, 250)
      expect(page1.containsCharOffset(120), isTrue);
      expect(page1.containsCharOffset(249), isTrue);
      expect(page1.containsCharOffset(250), isFalse);

      // 验证 page2 区间 [250, 380] 作为末页闭合
      expect(page2.containsCharOffset(250), isTrue);
      expect(page2.containsCharOffset(380), isTrue);

      // 验证 findPageByCharOffset 映射
      expect(ReaderLayoutEngine.findPageByCharOffset(pages, 0), 0);
      expect(ReaderLayoutEngine.findPageByCharOffset(pages, 119), 0);
      expect(ReaderLayoutEngine.findPageByCharOffset(pages, 120), 1,
          reason: '偏移 120 必须精准解析为第 2 页 (index 1)');
      expect(ReaderLayoutEngine.findPageByCharOffset(pages, 250), 2,
          reason: '偏移 250 必须精准解析为第 3 页 (index 2)');
    });
  });
}

