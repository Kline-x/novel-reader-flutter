import 'package:flutter_test/flutter_test.dart';
import 'package:novel_reader_flutter/features/sources/services/pinyin_harmonizer.dart';
import 'package:novel_reader_flutter/features/sources/services/source_parser.dart';

void main() {
  group('PinyinHarmonizer 智能拼音敏感词脱敏还原引擎测试', () {
    test('【专项一】涉政/公职类高频多音节拼音还原', () {
      const dirty = '当地zhengfu派遣了大量jingcha封锁了现场，维护guojia的安宁，严查官员fubai现象。';
      final clean = PinyinHarmonizer.restorePinyin(dirty);
      expect(clean, '当地政府派遣了大量警察封锁了现场，维护国家的安宁，严查官员腐败现象。');
    });

    test('【专项二】暴力/枪械/涉案类高频多音节拼音还原', () {
      const dirty = '那个凶手犯下了sharen大罪，手里握着一把黑色的shouqiang，装填了三颗zidan，制造了恐慌。';
      final clean = PinyinHarmonizer.restorePinyin(dirty);
      expect(clean, '那个凶手犯下了杀人大罪，手里握着一把黑色的手枪，装填了三颗子弹，制造了恐慌。');
    });

    test('【专项三】人体描写与亲密感官高频单字/词汇语境混排自愈', () {
      const dirty = '她有着白皙修长的da腿和傲人的xiong部，散发着诱人的xing感魅力，抑制不住内心的rou欲。';
      final clean = PinyinHarmonizer.restorePinyin(dirty);
      expect(clean, '她有着白皙修长的大腿和傲人的胸部，散发着诱人的性感魅力，抑制不住内心的肉欲。');

      const dirty2 = '体内涌起一股前所未有的kuai感，伴随着粗重的chuan息与低沉的shenyin。';
      final clean2 = PinyinHarmonizer.restorePinyin(dirty2);
      expect(clean2, '体内涌起一股前所未有的快感，伴随着粗重的喘息与低沉的呻吟。');

      const dirty3 = '两人赤裸着rou体，xia体传来滚烫的触感，彻底陷入了xing欲的漩涡。';
      final clean3 = PinyinHarmonizer.restorePinyin(dirty3);
      expect(clean3, '两人赤裸着肉体，下体传来滚烫的触感，彻底陷入了性欲的漩涡。');
    });

    test('【专项四】章节数字序号拼音和谐自愈（第yi章、第er章、第san节）', () {
      const titles = [
        '第yi章 异界降临',
        '第er章 神秘古卷',
        '第san章 破局之策',
        '第si节 暗流涌动',
        '第wu卷 决战时刻',
        '第shi章 巅峰对决',
      ];
      final restored = PinyinHarmonizer.restoreParagraphs(titles);
      expect(restored[0], '第一章 异界降临');
      expect(restored[1], '第二章 神秘古卷');
      expect(restored[2], '第三章 破局之策');
      expect(restored[3], '第四节 暗流涌动');
      expect(restored[4], '第五卷 决战时刻');
      expect(restored[5], '第十章 巅峰对决');
    });

    test('【专项五】符号包裹解包与大小写自适应自愈', () {
      // 符号包裹：[zhengfu]、(jingcha)、【sharen】
      const wrapped = '这件事情已经惊动了[zhengfu]高层，【jingcha】正全力搜捕，防止再次发生(sharen)事件。';
      final unwrapResult = PinyinHarmonizer.restorePinyin(wrapped);
      expect(unwrapResult, '这件事情已经惊动了政府高层，警察正全力搜捕，防止再次发生杀人事件。');

      // 大小写自适应：Jingcha / JINGCHA
      const casing = 'Jingcha and ZHENGFU officials arrived on scene.';
      final casingResult = PinyinHarmonizer.restorePinyin(casing);
      expect(casingResult, '警察 and 政府 officials arrived on scene.');
    });

    test('【专项六】零误伤保护（合法英文句子与专业术语绝不破坏）', () {
      // 纯英文句子中的日常词汇（he, me, to, can, no, so）绝不被单字拼音误伤
      const englishSentence = 'He asked me to check the level of the system and report it to the BOSS.';
      final englishClean = PinyinHarmonizer.restorePinyin(englishSentence);
      expect(englishClean, englishSentence);

      // 技术术语与缩写（FBI, DNA, NPC, CPU, RAM）绝不被破坏
      const techSentence = '克莱恩与FBI调查员会合，在NPC的指引下提取了凶手的DNA样本。';
      final techClean = PinyinHarmonizer.restorePinyin(techSentence);
      expect(techClean, techSentence);
    });

    test('【专项七】SourceParser 正文清洗管道深度联动测试', () {
      const rawHtmlContent = '''
<div id="content">
　　第yi章 命运的齿轮。<br/>
　　请记住本书首发域名：www.biquge7.xyz，免费提供最新章节阅读。<br>
　　周明瑞只觉得浑身被一股强烈的rou欲所包围，脑海中浮现出当年zhengfu与jingcha的残酷博弈。<br>
　　(本章完)<br/>
</div>
''';
      final paragraphs = SourceParser.cleanAndFilterParagraphs(rawHtmlContent);

      // 广告被剔除，(本章完)被剔除
      expect(paragraphs.length, 2);
      // 第yi章 还原为 第一章
      expect(paragraphs[0], '第一章 命运的齿轮。');
      // rou欲 还原为 肉欲，zhengfu 还原为 政府，jingcha 还原为 警察
      expect(paragraphs[1], '周明瑞只觉得浑身被一股强烈的肉欲所包围，脑海中浮现出当年政府与警察的残酷博弈。');
    });
  });
}
