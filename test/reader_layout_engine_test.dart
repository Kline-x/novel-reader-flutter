
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
  });
}

