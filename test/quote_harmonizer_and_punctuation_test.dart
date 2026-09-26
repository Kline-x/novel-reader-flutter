import 'package:flutter_test/flutter_test.dart';
import 'package:novel_reader_flutter/features/reader/engine/cjk_punctuation.dart';
import 'package:novel_reader_flutter/features/reader/engine/reader_layout_engine.dart';
import 'package:novel_reader_flutter/features/sources/services/pinyin_harmonizer.dart';
import 'package:novel_reader_flutter/features/sources/services/source_parser.dart';

void main() {
  group('【引号自愈与标点平衡专项测试】CjkPunctuation.harmonizeQuotes & normalizeParagraph', () {
    test('场景1：冒号引语漏开引号自愈（道：走吧。” -> 道：“走吧。”）', () {
      expect(
        CjkPunctuation.harmonizeQuotes('陈平安摇了摇头，认真道：婶子，我真的吃过了。”'),
        '陈平安摇了摇头，认真道：“婶子，我真的吃过了。”',
      );
      expect(
        CjkPunctuation.harmonizeQuotes('他冷笑一声，厉声喝道：哪里逃！”'),
        '他冷笑一声，厉声喝道：“哪里逃！”',
      );
      expect(
        CjkPunctuation.harmonizeQuotes('母亲微笑着说：饭菜已经准备好了，快来吃吧。”'),
        '母亲微笑着说：“饭菜已经准备好了，快来吃吧。”',
      );
    });

    test('场景2：纯对话段落漏段首开引号自愈（！/？/叹词/疑问等强台词语气）', () {
      expect(
        CjkPunctuation.harmonizeQuotes('快看，那边有动静！”'),
        '“快看，那边有动静！”',
      );
      expect(
        CjkPunctuation.harmonizeQuotes('这怎么可能？难道我已经死过一次了？！”'),
        '“这怎么可能？难道我已经死过一次了？！”',
      );
      expect(
        CjkPunctuation.harmonizeQuotes('好的，我知道了。”'),
        '“好的，我知道了。”',
      );
      expect(
        CjkPunctuation.harmonizeQuotes('是啊，时间过得真快。”'),
        '“是啊，时间过得真快。”',
      );
      expect(
        CjkPunctuation.harmonizeQuotes('怎么会这样？”'),
        '“怎么会这样？”',
      );
    });

    test('场景3：客观环境叙述/旁白句末尾残留孤立垃圾闭引号自愈剥离', () {
      const narrative1 =
          '窗外的绯红月光正无声地照耀着这间逼仄阴暗的简陋房间，窗台上的灰尘清晰可见，街道上一片寂静。”';
      expect(
        CjkPunctuation.harmonizeQuotes(narrative1),
        '窗外的绯红月光正无声地照耀着这间逼仄阴暗的简陋房间，窗台上的灰尘清晰可见，街道上一片寂静。',
      );

      const narrative2 =
          '天空中电闪雷鸣，暴雨如注，整座城市都笼罩在无边的黑夜之中，令人感到无比压抑。”';
      expect(
        CjkPunctuation.harmonizeQuotes(narrative2),
        '天空中电闪雷鸣，暴雨如注，整座城市都笼罩在无边的黑夜之中，令人感到无比压抑。',
      );

      // 真机走查捕获的真实第三方源单边闭引号缺陷（”在标点！前）
      const realCase = '在他手中，一道白色符箓浮现而出，正是二阶的天霜冰刃符”！';
      expect(
        CjkPunctuation.harmonizeQuotes(realCase),
        '在他手中，一道白色符箓浮现而出，正是二阶的天霜冰刃符！',
      );
    });

    test('场景4：段首倒置闭引号纠正为开引号', () {
      expect(
        CjkPunctuation.harmonizeQuotes('”大家都准备好了吗？”队长低声问道。'),
        '“大家都准备好了吗？”队长低声问道。',
      );
    });

    test('场景5：句中孤立闭引号剥离，正常配对双引号不受任何影响', () {
      expect(
        CjkPunctuation.harmonizeQuotes('周明瑞按着太阳穴”，只觉得头痛欲裂。'),
        '周明瑞按着太阳穴，只觉得头痛欲裂。',
      );
      expect(
        CjkPunctuation.harmonizeQuotes('“我不是在家里睡觉吗？怎么会在这里……”'),
        '“我不是在家里睡觉吗？怎么会在这里……”',
      );
    });

    test('场景6：英文半角成对双引号规范化为中文全角双引号', () {
      expect(
        CjkPunctuation.harmonizeQuotes('"快走吧，要来不及了！"'),
        '“快走吧，要来不及了！”',
      );
    });

    test('场景7：normalizeParagraph 段落排版缩进与引号自愈一体化', () {
      final para = CjkPunctuation.normalizeParagraph('快跑，后面有怪兽！”');
      expect(para.startsWith(CjkPunctuation.indent), isTrue);
      expect(para, '${CjkPunctuation.indent}“快跑，后面有怪兽！”');

      final narrativePara = CjkPunctuation.normalizeParagraph(
          '天空中电闪雷鸣，暴雨如注，整座城市都笼罩在无边的黑夜之中，令人感到无比压抑。”');
      expect(narrativePara,
          '${CjkPunctuation.indent}天空中电闪雷鸣，暴雨如注，整座城市都笼罩在无边的黑夜之中，令人感到无比压抑。');
    });

    test('场景8：半角标点转全角与夹带半角空格彻底剥离（防避头禁则穿透）', () {
      expect(
        CjkPunctuation.harmonizeQuotes('“怎么会这样 ! ”'),
        '“怎么会这样！”',
      );
      expect(
        CjkPunctuation.harmonizeQuotes('他笑了笑 , 说道 : “好的 .”'),
        '他笑了笑，说道：“好的。”',
      );
      expect(
        CjkPunctuation.harmonizeQuotes('真的吗 ? ”'),
        '“真的吗？”',
      );
    });
  });

  group('【书源垃圾行清洗与拼音自愈测试】SourceParser & PinyinHarmonizer', () {
    test('纯标点与Unicode符号噪点行（如 ·；、• ；、---、● 等）被彻底剔除丢弃', () {
      const input = '''
这是第一段正常文本。
• ；
这是第二段正常文本。
---
●
这是第三段正常文本。
      ''';
      final paras = SourceParser.cleanAndFilterParagraphs(input);
      expect(paras.length, 3);
      expect(paras[0], contains('第一段'));
      expect(paras[1], contains('第二段'));
      expect(paras[2], contains('第三段'));
      expect(paras.any((p) => p.contains('• ；')), isFalse);
      expect(paras.any((p) => p.contains('●')), isFalse);
    });

    test('盗版书源替换词自愈：jing戒线、sao动、黑se/白se', () {
      const input =
          '前方拉起了jing戒线，人群中引起了一阵sao动，一名穿着黑se风衣的男子走了过来。';
      final paras = SourceParser.cleanAndFilterParagraphs(input);
      expect(paras.first, '前方拉起了警戒线，人群中引起了一阵骚动，一名穿着黑色风衣的男子走了过来。');
    });

    test('带声调拼音与词尾标点敏感词自愈：贞cāo、黑sè、节cāo、放shè', () {
      expect(PinyinHarmonizer.restorePinyin('为了捍卫自己的贞cāo，她誓死不从。'),
          '为了捍卫自己的贞操，她誓死不从。');
      expect(PinyinHarmonizer.restorePinyin('这人毫无节cāo！'),
          '这人毫无节操！');
      expect(PinyinHarmonizer.restorePinyin('一袭黑sè长袍，在夜色中格外显眼。'),
          '一袭黑色长袍，在夜色中格外显眼。');
      expect(PinyinHarmonizer.restorePinyin('强烈的放shè性物质'),
          '强烈的放射性物质');
    });

    test('西方人名间隔号变异与残余分号自愈：杜维 • ； 罗林 -> 杜维·罗林', () {
      expect(
        CjkPunctuation.harmonizeQuotes('伯爵的儿子杜维 • ； 罗林出生了。'),
        '伯爵的儿子杜维·罗林出生了。',
      );
      expect(
        SourceParser.cleanAndFilterParagraphs('杜维 • ； 罗林').first,
        '杜维·罗林',
      );
      // 独立符号段落经过 normalizeParagraph 直接过滤为空
      expect(CjkPunctuation.normalizeParagraph('• ；'), isEmpty);
    });

    test('复合神态与时间拼音词自愈：脸seyin沉、脸se煞白、好脸se、凯旋之ri', () {
      expect(
        PinyinHarmonizer.restorePinyin('他的脸seyin沉的可怕，仿佛暴风雨前奏。'),
        '他的脸色阴沉的可怕，仿佛暴风雨前奏。',
      );
      expect(
        PinyinHarmonizer.restorePinyin('管家顿时吓得脸se煞白，双腿发抖。'),
        '管家顿时吓得脸色煞白，双腿发抖。',
      );
      expect(
        PinyinHarmonizer.restorePinyin('哪怕没有好脸se给他看，他也毫不在乎。'),
        '哪怕没有好脸色给他看，他也毫不在乎。',
      );
      expect(
        PinyinHarmonizer.restorePinyin('那是伯爵凯旋之ri，全城欢腾。'),
        '那是伯爵凯旋之日，全城欢腾。',
      );
    });
  });

  group('【排版引擎避头悬挂与西文Word-wrap测试】ReaderLayoutEngine', () {
    test('西文连续单词在行末不被撕裂（Word-wrap整体移到下一行）', () {
      // 构造一行接近行末时出现连续英文字母的情况
      // 假设 availWidth 仅允许容纳 10 个字符
      final lines = ReaderLayoutEngine.splitParagraphToLines(
        rawParagraph: '这是一段测试文本HelloWord',
        paragraphIndex: 0,
        availWidth: 160, // 假设每字 16px，160px 正好容纳 10 个全角字
        fontSize: 16,
        letterSpacing: 0,
        globalCharOffsetStart: 0,
      );

      // 验证 HelloWord 没有被劈成 He / lloWord，而是整体移行或保持完整
      final firstLine = lines.first.text;
      final secondLine = lines[1].text;
      expect(firstLine.endsWith('Hell') || firstLine.endsWith('Hello'), isFalse);
      expect(secondLine.contains('HelloWord') || firstLine.contains('HelloWord'),
          isTrue);
    });

    test('行首绝不出现避头标点（感叹号、闭引号等）', () {
      final lines = ReaderLayoutEngine.splitParagraphToLines(
        rawParagraph: '这是一个非常长非常长非常长非常长非常长的句子呢！”',
        paragraphIndex: 0,
        availWidth: 160,
        fontSize: 16,
        letterSpacing: 0,
        globalCharOffsetStart: 0,
      );

      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].text;
        expect(CjkPunctuation.isForbiddenStart(line[0]), isFalse,
            reason: '行首不应为避头标点: "$line"');
        expect(line.startsWith(' '), isFalse, reason: '行首不应出现半角空格');
      }
    });
  });

  group('【超长段落断句防劈开引语测试】SourceParser.cleanAndFilterParagraphs', () {
    test('长台词（超过 180 字）在引语内部不被生硬截断，断句后绝不出现只有结尾引号的残疾段落', () {
      // 构造一段包含超长台词（超过 350 字）的单段文本
      const dialoguePart1 =
          '“这是一个古老而禁忌的深渊秘密，从第三纪白银城建立伊始，太阳的神圣光辉就彻底熄灭了，黑夜与迷雾无情地笼罩了一切生灵，'
          '无数的非凡者为了探寻神明的遗留足迹前仆后继，却在疯狂、扭曲与不可逆的基因畸变中化为灰烬，那些铭刻在石板上的古老誓言，'
          '如今早已经随风飘散，只剩下绝望的低语在灰雾深处长久回荡。';
      const dialoguePart2 =
          '如果你真的执意要踏上这条九死一生的不归路，就必须做好时刻面对理智崩溃与彻底失控的严酷觉悟，任何一丝侥幸心理与片刻的犹豫，'
          '都会在转瞬之间将你与你所珍视的同伴彻底推入万劫不复的深渊深处，成为黑暗中永世不得超生的恐怖养料，你可真的想清楚了？！”';
      const trailingNarrative =
          '老者缓缓放下手中雕刻着繁复符文的黄铜烟斗，目光深邃、苍老而又无比沉重地凝视着面前稚气未脱却眼神倔强的年轻少年，屋内的煤气灯无声地跳跃着昏黄的火苗。';

      const longText = '$dialoguePart1$dialoguePart2$trailingNarrative';
      expect(longText.length, greaterThan(320));

      final paragraphs = SourceParser.cleanAndFilterParagraphs(longText);

      // 验证断开的每一段中，绝不存在“只有结尾引号而没有开头引号”的残疾段落
      for (final p in paragraphs) {
        final openCount = '“'.allMatches(p).length;
        final closeCount = '”'.allMatches(p).length;
        // 不得存在闭引号多于开引号的失衡情况
        expect(closeCount > openCount, isFalse,
            reason: '段落中不应存在未匹配的孤立结尾引号: "$p"');
      }
    });
  });

  group('【本轮真机实证专项自愈测试】she和谐词、HTML实体残留与段首裸冒号', () {
    test('1. “照she”与“she在/向/击”等敏感词精准还原为“照射/射向/射击”', () {
      const input = '当午后的阳光照she在运河宽阔的河面上，利箭she向了敌人，激光向四周辐she。';
      final paras = SourceParser.cleanAndFilterParagraphs(input);
      expect(paras.first, '当午后的阳光照射在运河宽阔的河面上，利箭射向了敌人，激光向四周辐射。');

      // 验证排版引擎自然段自愈
      final normalized = CjkPunctuation.normalizeParagraph(
          PinyinHarmonizer.restorePinyin('当午后的阳光照she在运河宽阔的河面上。'));
      expect(normalized, contains('照射在'));
    });

    test('2. HTML 实体转义残余「※#61618;」与孤立「※#」彻底过滤', () {
      const input = '''
※#第二次神话战争结束后，进入前罗兰帝国时代。
※#61618;近万年之后，进入罗兰帝国元年。
※#61618;罗兰帝国二十五年。
      ''';
      final paras = SourceParser.cleanAndFilterParagraphs(input);
      expect(paras.length, 3);
      expect(paras[0], '第二次神话战争结束后，进入前罗兰帝国时代。');
      expect(paras[1], '近万年之后，进入罗兰帝国元年。');
      expect(paras[2], '罗兰帝国二十五年。');
      expect(paras.any((p) => p.contains('61618')), isFalse);
      expect(paras.any((p) => p.contains('※#')), isFalse);

      // 验证 CjkPunctuation 对已缓存段落同样具备自愈清洗能力
      final singleCleaned = CjkPunctuation.normalizeParagraph('※#61618;近万年之后，进入帝国元年。');
      expect(singleCleaned, '${CjkPunctuation.indent}近万年之后，进入帝国元年。');
    });

    test('3. 段首残留裸冒号「：各族内讧……」自愈为标准无冒号自然段', () {
      const input = '：各族内讧，精灵族兽人族矮人族龙族等等，与人类争夺大陆掌控权。';
      final paras = SourceParser.cleanAndFilterParagraphs(input);
      expect(paras.first, '各族内讧，精灵族兽人族矮人族龙族等等，与人类争夺大陆掌控权。');
      expect(paras.first.startsWith('：'), isFalse);

      final layoutPara = CjkPunctuation.normalizeParagraph(input);
      expect(layoutPara, '${CjkPunctuation.indent}各族内讧，精灵族兽人族矮人族龙族等等，与人类争夺大陆掌控权。');
    });
  });
}
