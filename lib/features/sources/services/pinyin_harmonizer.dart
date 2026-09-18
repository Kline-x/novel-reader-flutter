import 'pinyin_rule_service.dart';

/// 智能拼音转汉字还原自愈引擎 (pinyin_harmonizer.dart)
/// 针对第三方书源文本中常见的拼音替换字词进行智能自愈还原，保障排版纯净通畅。
/// 支持动态规则联动、云端热更规则、变异干扰符解混淆（Anti-Obfuscation）与汉字夹缝探测（Sandwich Probe）。
class PinyinHarmonizer {
  PinyinHarmonizer._();

  /// 动态临时扩展拼音词典（兼容历史接口）
  static final Map<String, String> _dynamicMap = {};

  /// 更新动态注入的拼音自愈映射规则
  static void setDynamicRules(Map<String, String> rules) {
    _dynamicMap.clear();
    _dynamicMap.addAll(rules);
  }

  /// 获取当前全部动态规则快照
  static Map<String, String> get dynamicRules => Map.unmodifiable(_dynamicMap);

  /// 常见拼音词组到标准汉字的高频映射字典（核心保底）
  static const Map<String, String> _multiSyllableMap = {
    'zhengfu': '政府',
    'jingcha': '警察',
    'guojia': '国家',
    'junshi': '军事',
    'fubai': '腐败',
    'guanliao': '官僚',
    'zhengzhi': '政治',
    'zhonggong': '中共',
    'falungong': '法轮功',
    'dageming': '大革命',
    'wenhuadageming': '文化大革命',
    'tanwu': '贪污',
    'shouhui': '受贿',
    'jianyu': '监狱',
    'shexiangtou': '摄像头',
    'sharen': '杀人',
    'siwang': '死亡',
    'fanzui': '犯罪',
    'dupin': '毒品',
    'dubo': '赌博',
    'shouqiang': '手枪',
    'zidan': '子弹',
    'baozha': '爆炸',
    'kongbu': '恐怖',
    'fadong': '发动',
    'xidu': '吸毒',
    'qiangjie': '抢劫',
    'bangjia': '绑架',
    'zisha': '自杀',
    'xidang': '洗脑',
    'gaochao': '高潮',
    'luoti': '裸体',
    'chiluoluo': '赤裸裸',
    'youhuo': '诱惑',
    'chuanxi': '喘息',
    'shenyin': '呻吟',
    'xinggan': '性感',
    'xingyu': '性欲',
    'xingai': '性爱',
    'xingjiao': '性交',
    'shengzhiqi': '生殖器',
    'zigong': '子宫',
    'yinbu': '阴部',
    'yindao': '阴道',
    'yinchun': '阴唇',
    'yinmao': '阴毛',
    'koujiao': '口交',
    'rufang': '乳房',
    'routi': '肉体',
    'rouyu': '肉欲',
    'roubang': '肉棒',
    'naizi': '奶子',
    'naitou': '奶头',
    'boqi': '勃起',
    'shejing': '射精',
    'kuaigan': '快感',
    'mihui': '密会',
    'mixue': '密穴',
    'xiati': '下体',
    'xiongbu': '胸部',
    'tunbu': '臀部',
    'datui': '大腿',
    'meiguo': '美国',
    'riben': '日本',
    'faguo': '法国',
    'yingguo': '英国',
    'deguo': '德国',
    'chaoxian': '朝鲜',
    'zhaopian': '照片',
    'chongdong': '冲动',
    'mimang': '迷茫',
    'mimi': '秘密',
    'zongjiao': '宗教',
  };

  /// 常见单字拼音音节集合（用于变异解混淆中的单字归一化判定）
  static const Set<String> _commonSyllables = {
    'zheng', 'zhi', 'xing', 'rou', 'nai', 'bo', 'cao', 'she', 'da', 'xiong',
    'tun', 'xia', 'mi', 'yin', 'kuai', 'bi', 'sha', 'si', 'du', 'qiang',
    'hei', 'chuan', 'shen', 'jing', 'guo', 'dan', 'zi', 'fu', 'cha', 'jia',
  };

  /// 获取当前所有生效的精确字典映射（内置字典 + PinyinRuleService + 动态注入）
  static Map<String, String> get _activeRulesMap {
    final map = Map<String, String>.from(_multiSyllableMap);
    map.addAll(PinyinRuleService().exactRulesMap);
    map.addAll(_dynamicMap);
    return map;
  }

  /// 2. 语境单字/单音节混排正则映射表
  /// 必须与前后中文语境紧密绑定，杜绝在纯英文语境中误伤英文单词（如 he, me, to, can 等）
  static final List<_ContextualPinyinRule> _contextualRules = [
    // 章节序号和谐：第yi章、第er章、第san节...
    _ContextualPinyinRule(
      pattern: RegExp(r'第\s*yi\s*([章节回集话卷篇])', caseSensitive: false),
      replacement: (m) => '第一${m.group(1)}',
    ),
    _ContextualPinyinRule(
      pattern: RegExp(r'第\s*er\s*([章节回集话卷篇])', caseSensitive: false),
      replacement: (m) => '第二${m.group(1)}',
    ),
    _ContextualPinyinRule(
      pattern: RegExp(r'第\s*san\s*([章节回集话卷篇])', caseSensitive: false),
      replacement: (m) => '第三${m.group(1)}',
    ),
    _ContextualPinyinRule(
      pattern: RegExp(r'第\s*si\s*([章节回集话卷篇])', caseSensitive: false),
      replacement: (m) => '第四${m.group(1)}',
    ),
    _ContextualPinyinRule(
      pattern: RegExp(r'第\s*wu\s*([章节回集话卷篇])', caseSensitive: false),
      replacement: (m) => '第五${m.group(1)}',
    ),
    _ContextualPinyinRule(
      pattern: RegExp(r'第\s*liu\s*([章节回集话卷篇])', caseSensitive: false),
      replacement: (m) => '第六${m.group(1)}',
    ),
    _ContextualPinyinRule(
      pattern: RegExp(r'第\s*qi\s*([章节回集话卷篇])', caseSensitive: false),
      replacement: (m) => '第七${m.group(1)}',
    ),
    _ContextualPinyinRule(
      pattern: RegExp(r'第\s*ba\s*([章节回集话卷篇])', caseSensitive: false),
      replacement: (m) => '第八${m.group(1)}',
    ),
    _ContextualPinyinRule(
      pattern: RegExp(r'第\s*jiu\s*([章节回集话卷篇])', caseSensitive: false),
      replacement: (m) => '第九${m.group(1)}',
    ),
    _ContextualPinyinRule(
      pattern: RegExp(r'第\s*shi\s*([章节回集话卷篇])', caseSensitive: false),
      replacement: (m) => '第十${m.group(1)}',
    ),

    // 语境单字拼音自愈（需紧邻中文）
    _ContextualPinyinRule(
      pattern: RegExp(r'zheng\s*([府治策券商务纪规纲协企党署要门部策])', caseSensitive: false),
      replacement: (m) => '政${m.group(1)}',
    ),
    _ContextualPinyinRule(
      pattern: RegExp(r'([党县市政乡省行廉执新辅朝亲宪暴涉垂])\s*zheng', caseSensitive: false),
      replacement: (m) => '${m.group(1)}政',
    ),
    _ContextualPinyinRule(
      pattern: RegExp(r'jing\s*([察界兵笛告服徽犬力报惕民卫醒鸣衔局署厅])', caseSensitive: false),
      replacement: (m) => '警${m.group(1)}',
    ),
    _ContextualPinyinRule(
      pattern: RegExp(r'([民巡特干交火网预女法刑协骑武片备狱示告提防预机])\s*jing', caseSensitive: false),
      replacement: (m) => '${m.group(1)}警',
    ),
    _ContextualPinyinRule(
      pattern: RegExp(r'guo\s*([家民防境库度旗徽歌土界难戚界政主事都])', caseSensitive: false),
      replacement: (m) => '国${m.group(1)}',
    ),
    _ContextualPinyinRule(
      pattern: RegExp(r'([中外各全大敌爱列多跨建举祖诸异邦敌列本我该])\s*guo', caseSensitive: false),
      replacement: (m) => '${m.group(1)}国',
    ),
    _ContextualPinyinRule(
      pattern: RegExp(r'guan\s*([僚员邸场局吏印司署职阶位任商绅家相爵])', caseSensitive: false),
      replacement: (m) => '官${m.group(1)}',
    ),
    _ContextualPinyinRule(
      pattern: RegExp(r'xing\s*([欲感性格命交伴奴爱])', caseSensitive: false),
      replacement: (m) => '性${m.group(1)}',
    ),
    _ContextualPinyinRule(
      pattern: RegExp(r'([男女性天理记本索异同])\s*xing', caseSensitive: false),
      replacement: (m) => '${m.group(1)}性',
    ),
    _ContextualPinyinRule(
      pattern: RegExp(r'rou\s*([体欲棒身香林块皮肉感])', caseSensitive: false),
      replacement: (m) => '肉${m.group(1)}',
    ),
    _ContextualPinyinRule(
      pattern: RegExp(r'([血骨皮精肥瘦烤白肥熟冷烂灵])\s*rou', caseSensitive: false),
      replacement: (m) => '${m.group(1)}肉',
    ),
    _ContextualPinyinRule(
      pattern: RegExp(r'nai\s*([子头液水粉娘白大])', caseSensitive: false),
      replacement: (m) => '奶${m.group(1)}',
    ),
    _ContextualPinyinRule(
      pattern: RegExp(r'bo\s*([起动客乱发的])', caseSensitive: false),
      replacement: (m) => '勃${m.group(1)}',
    ),
    _ContextualPinyinRule(
      pattern: RegExp(r'cao\s*([你他她妹娘蛋翻踏了])', caseSensitive: false),
      replacement: (m) => '操${m.group(1)}',
    ),
    _ContextualPinyinRule(
      pattern: RegExp(r'([我被把给使猛直尽情])\s*cao', caseSensitive: false),
      replacement: (m) => '${m.group(1)}操',
    ),
    _ContextualPinyinRule(
      pattern: RegExp(r'she\s*([精出入头击穿向来])', caseSensitive: false),
      replacement: (m) => '射${m.group(1)}',
    ),
    _ContextualPinyinRule(
      pattern: RegExp(r'da\s*([腿腿肚腿部胸乳])', caseSensitive: false),
      replacement: (m) => '大${m.group(1)}',
    ),
    _ContextualPinyinRule(
      pattern: RegExp(r'xiong\s*([部脯前堂口器怀])', caseSensitive: false),
      replacement: (m) => '胸${m.group(1)}',
    ),
    _ContextualPinyinRule(
      pattern: RegExp(r'tun\s*([部瓣肉围形])', caseSensitive: false),
      replacement: (m) => '臀${m.group(1)}',
    ),
    _ContextualPinyinRule(
      pattern: RegExp(r'xia\s*([体身面半部身身])', caseSensitive: false),
      replacement: (m) => '下${m.group(1)}',
    ),
    _ContextualPinyinRule(
      pattern: RegExp(r'mi\s*([穴径洞门室道缝])', caseSensitive: false),
      replacement: (m) => '密${m.group(1)}',
    ),
    _ContextualPinyinRule(
      pattern: RegExp(r'yin\s*([道唇毛部核水穴私暗乱])', caseSensitive: false),
      replacement: (m) => '阴${m.group(1)}',
    ),
    _ContextualPinyinRule(
      pattern: RegExp(r'kuai\s*([感乐门意步速])', caseSensitive: false),
      replacement: (m) => '快${m.group(1)}',
    ),
    _ContextualPinyinRule(
      pattern: RegExp(r'bi\s*([迫供人紧缝死])', caseSensitive: false),
      replacement: (m) => '逼${m.group(1)}',
    ),
    _ContextualPinyinRule(
      pattern: RegExp(r'sha\s*([人戮害手死气落伐机意光了])', caseSensitive: false),
      replacement: (m) => '杀${m.group(1)}',
    ),
    _ContextualPinyinRule(
      pattern: RegExp(r'si\s*([亡绝者掉去相地局守命穴])', caseSensitive: false),
      replacement: (m) => '死${m.group(1)}',
    ),
    _ContextualPinyinRule(
      pattern: RegExp(r'du\s*([品瘾蛇枭物贩手液刺辣囊害])', caseSensitive: false),
      replacement: (m) => '毒${m.group(1)}',
    ),
    _ContextualPinyinRule(
      pattern: RegExp(r'qiang\s*([支弹托手眼声械管发靶口子])', caseSensitive: false),
      replacement: (m) => '枪${m.group(1)}',
    ),
    _ContextualPinyinRule(
      pattern: RegExp(r'hei\s*([帮市暗恶道手旗夜水石影云洞])', caseSensitive: false),
      replacement: (m) => '黑${m.group(1)}',
    ),
    _ContextualPinyinRule(
      pattern: RegExp(r'chuan\s*([息气动声声])', caseSensitive: false),
      replacement: (m) => '喘${m.group(1)}',
    ),
    _ContextualPinyinRule(
      pattern: RegExp(r'([娇粗微痛暗急阵])\s*chuan', caseSensitive: false),
      replacement: (m) => '${m.group(1)}喘',
    ),
    _ContextualPinyinRule(
      pattern: RegExp(r'shen\s*([吟唤唤喊])', caseSensitive: false),
      replacement: (m) => '呻${m.group(1)}',
    ),
    _ContextualPinyinRule(
      pattern: RegExp(r'([痛低娇难轻凄])\s*shen', caseSensitive: false),
      replacement: (m) => '${m.group(1)}呻',
    ),
  ];

  /// 预编译多音节拼音匹配的复合正则
  /// 匹配类似：[zhengfu]、(jingcha)、【sharen】或独立的单词边界
  static final RegExp _wrappedPattern = RegExp(
    r'''[\[\(\<\{【（《\*]([a-zA-Z]{3,20})[\]\)\>\}】）》\*]''',
  );

  /// 变异干扰符解混淆模式：匹配包含 - _ . * · / 等混淆字符的字母片段
  /// 例如：z-h-e-n-g-f-u、z_h_e_n_g、s.h.a.r.e.n、z*h*e*n*g、s·h·a·r·e·n
  static final RegExp _obfuscatedPattern = RegExp(
    r'''(?<![a-zA-Z0-9])([a-zA-Z]+(?:[\-_.\*·/][a-zA-Z]+)+)(?![a-zA-Z0-9])''',
  );

  /// 汉字夹缝拼音探测模式：匹配紧贴汉字的前后夹缝纯小写字母片段
  static final RegExp _sandwichPinyinPattern = RegExp(
    r'''(?<=[\u4e00-\u9fa5])([a-z]{2,20})(?=[\u4e00-\u9fa5])''',
  );

  /// 智能对单行小说正文执行拼音和谐脱敏自愈
  static String restorePinyin(String text) {
    if (text.isEmpty) return text;

    // 若文本中完全不含英文字母，无需处理
    if (!RegExp(r'[a-zA-Z]').hasMatch(text)) {
      return text;
    }

    var result = text;
    final activeMap = _activeRulesMap;

    // 阶段一：解包形如 [zhengfu]、(jingcha)、【sharen】、*guojia* 等被符号包围的拼音
    result = result.replaceAllMapped(_wrappedPattern, (match) {
      final inner = match.group(1)?.toLowerCase() ?? '';
      final replacement = activeMap[inner];
      if (replacement != null) {
        return replacement;
      }
      return match.group(0)!;
    });

    // 阶段二：变异干扰符解混淆（Anti-Obfuscation）
    // 识别形如 z-h-e-n-g-f-u、z_h_e_n_g、s.h.a.r.e.n、s·h·a·r·e·n 等被符号插入的拼音
    result = result.replaceAllMapped(_obfuscatedPattern, (match) {
      final rawToken = match.group(1)!;
      final stripped = rawToken.replaceAll(RegExp(r'[\-_.\*·/]'), '');
      final lowerStripped = stripped.toLowerCase();

      // 1. 若剥离后直接命中字典，直接还原为汉字
      final replacement = activeMap[lowerStripped];
      if (replacement != null) {
        return replacement;
      }

      // 2. 若剥离后属于常见单字拼音音节，归一化为纯拼音以供后续阶段三/五自愈
      if (_commonSyllables.contains(lowerStripped)) {
        return lowerStripped;
      }

      // 3. 否则保留原样，避免误伤普通英文连字符词（如 self-driving）
      return match.group(0)!;
    });

    // 阶段三：汉字夹缝拼音探测（Sandwich Pinyin Probe）
    // 探测被中文字符紧密包围的小写拼音词汇（杜绝误伤全大写英文代号如 FBI, BOSS, NPC）
    result = result.replaceAllMapped(_sandwichPinyinPattern, (match) {
      final pinyin = match.group(1)!;
      final replacement = activeMap[pinyin];
      if (replacement != null) {
        return replacement;
      }
      return pinyin;
    });

    // 阶段四：处理无歧义的多音节拼音词（全词边界匹配或前后紧邻中文/标点）
    // 动态规则优先匹配
    for (final entry in activeMap.entries) {
      final pinyin = entry.key;
      final hanzi = entry.value;

      // 严格词边界或前后紧邻汉字标点，绝不误伤形如 "teaching" 或 "level" 的长单词
      final regex = RegExp('(?<![a-zA-Z])$pinyin(?![a-zA-Z])', caseSensitive: false);
      if (regex.hasMatch(result)) {
        result = result.replaceAll(regex, hanzi);
      }
    }

    // 阶段五：执行动态自定义正则规则
    for (final rule in PinyinRuleService().allRules) {
      if (rule.isRegex && rule.isEnabled) {
        try {
          final regex = RegExp(rule.pattern, caseSensitive: false);
          result = result.replaceAll(regex, rule.replacement);
        } catch (_) {}
      }
    }

    // 阶段六：语境单字/单音节混排规则自愈（如“第yi章”、“xing欲”、“rou体”）
    for (final rule in _contextualRules) {
      result = result.replaceAllMapped(rule.pattern, rule.replacement);
    }

    return result;
  }

  /// 批量对小说段落列表进行拼音脱敏自愈
  static List<String> restoreParagraphs(List<String> paragraphs) {
    if (paragraphs.isEmpty) return paragraphs;
    return paragraphs.map(restorePinyin).toList();
  }
}

/// 语境拼音规则实体
class _ContextualPinyinRule {
  final RegExp pattern;
  final String Function(Match) replacement;

  const _ContextualPinyinRule({
    required this.pattern,
    required this.replacement,
  });
}
