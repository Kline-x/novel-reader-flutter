/// 智能拼音敏感词和谐脱敏还原引擎 (pinyin_harmonizer.dart)
/// 专用于自愈各大盗版/第三方书源中因规避审查而将敏感汉字替换为拼音的段落内容
/// 具备：零误伤保护（保留合法英文单词与技术术语）、多音节全拼还原、语境单字混排自愈与大小写自适应
class PinyinHarmonizer {
  PinyinHarmonizer._();

  /// 1. 网文高频被和谐的无歧义多音节拼音词库（在英语中无同形常用词）
  /// Key: 拼音小写（不带空格或带空格），Value: 对应标准汉字
  static const Map<String, String> _multiSyllableMap = {
    // 涉政 / 公职 / 机构
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

    // 暴力 / 涉案 / 涉恐
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

    // 涉黄 / 人体 / 亲密与欲望描写
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

    // 国家 / 地名和谐
    'meiguo': '美国',
    'riben': '日本',
    'faguo': '法国',
    'yingguo': '英国',
    'deguo': '德国',
    'chaoxian': '朝鲜',

    // 其他网文常见规避字
    'zhaopian': '照片',
    'chongdong': '冲动',
    'mimang': '迷茫',
    'mimi': '秘密',
    'zongjiao': '宗教',
  };

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

    // 身体与动作高频拼音单字（前缀或后缀紧随中文）
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
  /// 匹配类似：[zhengfu]、(jingcha)、【sharen】或独立的单词边界 \bzhengfu\b
  static final RegExp _wrappedPattern = RegExp(
    r'''[\[\(\<\{【（《\*]([a-zA-Z]{3,20})[\]\)\>\}】）》\*]''',
  );

  /// 智能对单行小说正文执行拼音和谐脱敏自愈
  static String restorePinyin(String text) {
    if (text.isEmpty) return text;

    // 若文本中完全不含英文字母，无需处理
    if (!RegExp(r'[a-zA-Z]').hasMatch(text)) {
      return text;
    }

    var result = text;

    // 阶段一：解包形如 [zhengfu]、(jingcha)、【sharen】、*guojia* 等被符号包围的拼音
    result = result.replaceAllMapped(_wrappedPattern, (match) {
      final inner = match.group(1)?.toLowerCase() ?? '';
      final replacement = _multiSyllableMap[inner];
      if (replacement != null) {
        return replacement;
      }
      return match.group(0)!;
    });

    // 阶段二：处理无歧义的多音节拼音词（全词边界匹配或前后紧邻中文/标点）
    // 采用字典遍历匹配，由于只有数十个高频词，耗时微秒级
    for (final entry in _multiSyllableMap.entries) {
      final pinyin = entry.key;
      final hanzi = entry.value;

      // 严格词边界或前后紧邻汉字标点，绝不误伤形如 "teaching" 或 "amazing" 的长单词
      // 允许前后为：字符串首尾、非字母字符（包括中文、标点、空白等）
      final regex = RegExp('(?<![a-zA-Z])$pinyin(?![a-zA-Z])', caseSensitive: false);
      if (regex.hasMatch(result)) {
        result = result.replaceAll(regex, hanzi);
      }
    }

    // 阶段三：语境单字/单音节混排规则自愈（如“第yi章”、“xing欲”、“rou体”）
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
