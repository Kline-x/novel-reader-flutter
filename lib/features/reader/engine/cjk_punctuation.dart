// CJK 中文标点避头避尾与排版规范库 (cjk_punctuation.dart)
//
// 严格对齐出版级排版规范（JIS X 4051 / GB/T 15834）：
// 1. 禁止出现在行首的符号（避头）：如逗号、句号、右括号、右引号等
// 2. 禁止出现在行尾的符号（避尾）：如左括号、左引号、书名号开头等
// 3. 段首全角空格缩进（2em）

class CjkPunctuation {
  /// 段首缩进：两个全角空格（严格等于 2em）
  static const String indent = '\u3000\u3000';

  /// 避头符号集合：严禁出现在行首
  static const Set<String> forbiddenLineStartChars = {
    '，',
    '。',
    '！',
    '？',
    '：',
    '；',
    '、',
    '）',
    '》',
    '」',
    '】',
    '”',
    '’',
    ',',
    '.',
    '!',
    '?',
    ':',
    ';',
    ')',
    '>',
    '}',
    ']',
    '…',
    '~',
    '%',
    '·',
    '`',
    '—',
    '-'
  };

  /// 避尾符号集合：严禁出现在行尾
  static const Set<String> forbiddenLineEndChars = {
    '（',
    '《',
    '「',
    '【',
    '“',
    '‘',
    '(',
    '<',
    '{',
    '[',
    '@',
    '¥',
    '\$'
  };

  /// 检查字符是否为避头符号
  static bool isForbiddenStart(String char) =>
      forbiddenLineStartChars.contains(char);

  /// 检查字符是否为避尾符号
  static bool isForbiddenEnd(String char) =>
      forbiddenLineEndChars.contains(char);

  /// 对段落进行智能引号自愈与标点平衡 (解决只有结尾引号无开头引号、倒置引号、孤立垃圾引号等问题)
  static String harmonizeQuotes(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return text;

    // 0. 清洗标点周围的不当西文半角空格与半角符号
    // a. 汉字或常见标点后紧随半角感叹号、问号、分号、冒号、逗号、句号转全角
    text = text.replaceAllMapped(
      RegExp(r'([\u4e00-\u9fa5，。！？；：、”’）》」】])\s*([!?;:,.])'),
      (m) {
        final punct = m.group(2);
        String full;
        switch (punct) {
          case '!':
            full = '！';
            break;
          case '?':
            full = '？';
            break;
          case ';':
            full = '；';
            break;
          case ':':
            full = '：';
            break;
          case ',':
            full = '，';
            break;
          case '.':
            full = '。';
            break;
          default:
            full = punct!;
            break;
        }
        return '${m.group(1)}$full';
      },
    );
    // b. 闭引号前的标点转全角并剥除夹带空格（例如「! ”」->「！”」、「. "」->「。”」）
    text = text.replaceAllMapped(
      RegExp(r"""([!！？?\.。])\s*([”"’'])"""),
      (m) {
        final p = m.group(1);
        String full;
        switch (p) {
          case '!':
            full = '！';
            break;
          case '?':
            full = '？';
            break;
          case '.':
            full = '。';
            break;
          default:
            full = p!;
            break;
        }
        return '$full${m.group(2)}';
      },
    );
    // c. 汉字与标点、标点与标点、标点与汉字之间的无效半角空格剔除（杜绝半角空格穿透避头禁则）
    text = text.replaceAllMapped(
      RegExp(r'([\u4e00-\u9fa5])\s+([，。！？；：、”’）》」】…—~])'),
      (m) => '${m.group(1)}${m.group(2)}',
    );
    text = text.replaceAllMapped(
      RegExp(r'([“‘（《「【])\s+([\u4e00-\u9fa5])'),
      (m) => '${m.group(1)}${m.group(2)}',
    );
    text = text.replaceAllMapped(
      RegExp(r'([，。！？；：、”’）》」】…—~])\s+([\u4e00-\u9fa5“‘（《「【])'),
      (m) => '${m.group(1)}${m.group(2)}',
    );
    text = text.replaceAllMapped(
      RegExp(r'([，。！？；：、”’）》」】…—~])\s+([，。！？；：、”’）》」】…—~])'),
      (m) => '${m.group(1)}${m.group(2)}',
    );
    // d. 西方人名中间间隔号变异自愈（如原网页 &middot;; 或 &bull;; 转码后留下的「杜维 • ； 罗林」自愈为标准「杜维·罗林」）
    text = text.replaceAllMapped(
      RegExp(r'(?<=[\u4e00-\u9fa5a-zA-Z])\s*[•·・]\s*[;；]?\s*(?=[\u4e00-\u9fa5a-zA-Z])'),
      (m) => '·',
    );

    // e. 清洗 HTML 实体及变形实体转义残余（如「※#61618;」或「&#61618;」等源网残留噪点）
    text = text.replaceAll(RegExp(r'[※&]#[0-9a-zA-Z]+;?'), '');
    text = text.replaceAll(RegExp(r'^[※&]#\s*'), '');

    // f. 清洗段首裸冒号噪点（如「：各族内讧……」自愈为「各族内讧……」）
    if (text.startsWith('：') || text.startsWith(':')) {
      text = text.substring(1).trimLeft();
    }

    // 1. 直角引号（Corner Brackets）混配自愈与现代横排规范归一化
    // 1.1 扫描单双直角错配（如「潮生珠』或『潮生珠」）纠正为标准配对
    text = text.replaceAllMapped(
      RegExp(r'「([^「」『』\r\n]+?)』'),
      (m) => '「${m.group(1)}」',
    );
    text = text.replaceAllMapped(
      RegExp(r'『([^「」『』\r\n]+?)」'),
      (m) => '『${m.group(1)}』',
    );

    // 1.2 将繁体/竖排直角引号统一归一化为现代横排规范全角弯双引号与单引号
    text = text.replaceAll('「', '“');
    text = text.replaceAll('」', '”');
    text = text.replaceAll('『', '‘');
    text = text.replaceAll('』', '’');

    // 2. 预处理：解决前一句漏闭引号与下一句开引号粘连
    // 2.1 终止标点紧接开引号且漏闭引号（如：神性呢！“再等等 -> 神性呢！”“再等等）
    text = text.replaceAllMapped(
      RegExp(
          r'([！!？?。…~])\s*“(?=(?:这|那|我|你|他|她|再|不过|另外|第二|其二|若是|其实|只是|更|正思索|突然|倒是))'),
      (m) => '${m.group(1)}”“',
    );
    // 2.2 汉字紧接开引号且漏闭引号（如：误了孩子性“这第二么 -> 误了孩子性。”“这第二么）
    text = text.replaceAllMapped(
      RegExp(
          r'([\u4e00-\u9fa5])\s*“(?=(?:这|那|我|你|他|她|再|不过|另外|第二|其二|若是|其实|只是|更|正思索|突然|倒是))'),
      (m) => '${m.group(1)}。”“',
    );

    // 2. ASCII 半角单双引号归一化
    // 2.1 针对成对或单独的 ASCII 半角双引号 "
    if (text.contains('"')) {
      final parts = text.split('"');
      if (parts.length % 2 == 1) {
        // 偶数个双引号，完美成对交替
        final sb = StringBuffer();
        for (int i = 0; i < parts.length; i++) {
          sb.write(parts[i]);
          if (i < parts.length - 1) {
            sb.write(i % 2 == 0 ? '“' : '”');
          }
        }
        text = sb.toString();
      } else {
        // 奇数个双引号：根据上下文位置智能判定
        text = text.replaceAllMapped(
          RegExp(r'(^|[：:，,\s])"'),
          (m) => '${m.group(1)}“',
        );
        text = text.replaceAllMapped(
          RegExp(r'"([。！？!?…~—\s]|$)'),
          (m) => '”${m.group(1)}',
        );
        text = text.replaceAll('"', '”');
      }
    }

    // 2.2 成对的 ASCII 半角单引号 '...' 转换为 ‘...’（保护英文单词缩写如 don't, it's）
    text = text.replaceAllMapped(
      RegExp(r"(?<![a-zA-Z])'([^'\r\n]+?)'(?![a-zA-Z])"),
      (m) => '‘${m.group(1)}’',
    );

    // 3. 段首倒置引号纠正（若段首为 ” 或 ’，纠正为标准开引号 “ 或 ‘）
    if (text.startsWith('”')) {
      text = '“${text.substring(1)}';
    } else if (text.startsWith('’')) {
      text = '‘${text.substring(1)}';
    }

    // 4. 冒号引语漏开引号自愈：例如「道：走吧。”」->「道：“走吧。”」
    text = text.replaceAllMapped(
      RegExp(r'([：:])([^“"”\r\n]+?[。！？!?…~]+[”"]+)'),
      (m) => '${m.group(1)}“${m.group(2)}',
    );

    // 5. 单双引号混配与短语错位纠正（解决“方无尘’、‘方无咎’等严重书源缺陷）
    // 5.1 整句首尾错配：段落以 “ 开头，末尾却以 ’ 结束（如：“没有太大变化！！’）
    text = text.replaceAllMapped(
      RegExp(r'^(“[^“”\r\n]+?)’$'),
      (m) => '${m.group(1)}”',
    );
    // 冒号后整句首尾错配：如 叹息：“...。’
    text = text.replaceAllMapped(
      RegExp(r'([：:])“([^“”\r\n]+?[。！？!?…~—]+)’'),
      (m) => '${m.group(1)}“${m.group(2)}”',
    );

    // 5.2 状态机扫描重构短语引用与嵌套引用
    // 当外层未在双引号时，“xxx’ 纠正为 “xxx”
    // 当外层已在双引号时，“xxx’ 或 “xxx” 纠正为内层单引号 ‘xxx’
    final chars = text.split('');
    final n = chars.length;
    int i = 0;
    bool inDialogue = false;
    bool inSingleQuote = false;
    final result = StringBuffer();

    while (i < n) {
      final c = chars[i];

      if (c == '“') {
        int j = i + 1;
        final innerChars = StringBuffer();
        String? matchedClose;
        while (j < n && j - i <= 35) {
          if (chars[j] == '\r' || chars[j] == '\n') break;
          if (chars[j] == '“' ||
              chars[j] == '”' ||
              chars[j] == '‘' ||
              chars[j] == '’') {
            matchedClose = chars[j];
            break;
          }
          innerChars.write(chars[j]);
          j++;
        }

        final innerStr = innerChars.toString();
        if (matchedClose == '’' &&
            innerStr.isNotEmpty &&
            innerStr.length <= 30) {
          if (inDialogue) {
            result.write('‘$innerStr’');
          } else {
            result.write('“$innerStr”');
          }
          i = j + 1;
          continue;
        } else if (matchedClose == '”' &&
            inDialogue &&
            innerStr.isNotEmpty &&
            innerStr.length <= 30) {
          // 在外层双引号内部出现的短语引用，规范为单引号
          if (!innerStr.contains('。') &&
              !innerStr.contains('！') &&
              !innerStr.contains('？') &&
              !innerStr.contains('!') &&
              !innerStr.contains('?')) {
            result.write('‘$innerStr’');
            i = j + 1;
            continue;
          }
        }

        if (!inDialogue) inDialogue = true;
        result.write(c);
        i++;
      } else if (c == '”') {
        inDialogue = false;
        result.write(c);
        i++;
      } else if (c == '’') {
        if (inSingleQuote) {
          inSingleQuote = false;
          result.write(c);
        } else if (inDialogue) {
          // 仅在未匹配开单引号的纯孤立闭单引号时，视作整句对话闭合
          inDialogue = false;
          result.write('”');
        } else {
          result.write(c);
        }
        i++;
      } else if (c == '‘') {
        // 探测短语引用（配对的 ‘xxx’ 或错配的 ‘xxx”）
        int j = i + 1;
        final innerChars = StringBuffer();
        String? matchedClose;
        while (j < n && j - i <= 35) {
          if (chars[j] == '\r' || chars[j] == '\n') break;
          if (chars[j] == '“' ||
              chars[j] == '”' ||
              chars[j] == '‘' ||
              chars[j] == '’') {
            matchedClose = chars[j];
            break;
          }
          innerChars.write(chars[j]);
          j++;
        }
        final innerStr = innerChars.toString();
        if ((matchedClose == '”' || matchedClose == '’') &&
            innerStr.isNotEmpty &&
            innerStr.length <= 30 &&
            !innerStr.contains('。') &&
            !innerStr.contains('！') &&
            !innerStr.contains('？') &&
            !innerStr.contains('!') &&
            !innerStr.contains('?')) {
          if (inDialogue) {
            // 外层在双引号内部：无论书源给的是 ‘xxx’ 还是错配的 ‘xxx”，统一输出标准内层单引号
            result.write('‘$innerStr’');
          } else {
            // 外层不在双引号内部：若为错配的 ‘xxx”，规范为双引号 “xxx”；若为配对 ‘xxx’，保留为 ‘xxx’
            result.write(matchedClose == '”' ? '“$innerStr”' : '‘$innerStr’');
          }
          i = j + 1;
          continue;
        }
        inSingleQuote = true;
        result.write(c);
        i++;
      } else {
        result.write(c);
        i++;
      }
    }
    text = result.toString();

    // 6. 单引号孤立与平衡自愈
    int sOpen = '‘'.allMatches(text).length;
    int sClose = '’'.allMatches(text).length;
    if (sOpen != sClose) {
      if (sClose > sOpen) {
        // 剥离孤立闭单引号
        final sb = StringBuffer();
        int sDepth = 0;
        for (int idx = 0; idx < text.length; idx++) {
          final ch = text[idx];
          if (ch == '‘') {
            sDepth++;
            sb.write(ch);
          } else if (ch == '’') {
            if (sDepth > 0) {
              sDepth--;
              sb.write(ch);
            }
          } else {
            sb.write(ch);
          }
        }
        text = sb.toString();
      } else if (sOpen > sClose) {
        // 开单引号未闭合短语自动补闭
        text = text.replaceAllMapped(
          RegExp(r'‘([^’“”\r\n]{1,30})([，。！？；：、\s]|$)'),
          (m) => '‘${m.group(1)}’${m.group(2)}',
        );
      }
    }

    // 7. 统计中文字符双引号配对状态并执行自愈
    int openCount = '“'.allMatches(text).length;
    int closeCount = '”'.allMatches(text).length;

    // 若有冒号引语且引语后直接转为第三人称叙述（如行50实证），引语后补闭引号
    if (openCount > closeCount) {
      text = text.replaceAllMapped(
        RegExp(r'(：“[^“”]+?[。！？!?…~—]+)(?=(?:他|她|它|只见|这时|随后|旋即|接着))'),
        (m) => '${m.group(1)}”',
      );
      openCount = '“'.allMatches(text).length;
      closeCount = '”'.allMatches(text).length;
    }

    // 8. 解决只有结尾引号无开头引号或有开头无结尾引号
    if (closeCount > openCount) {
      // 判定闭引号是否位于段落结尾（支持 ！” 与 ”！ 两种标点相对顺序）
      final endsWithQuote =
          RegExp(r'[。！？!?…~—]*[”]+$|[”]+[。！？!?…~—]+$').hasMatch(text);

      if (openCount == 0 && closeCount == 1 && endsWithQuote) {
        final strippedQuoteText = text.replaceAll('”', '').trim();
        final coreText =
            strippedQuoteText.replaceAll(RegExp(r'[。！？!?…~—]+$'), '').trim();

        final hasDialoguePunctuation =
            RegExp(r'[！？!?…~]$').hasMatch(strippedQuoteText);
        final hasModalParticleEnding =
            RegExp(r'[吧呢吗啊呀啦嘛呐哦噢哈嘿哼哩呗咯了成好办对]$').hasMatch(coreText);
        final hasDialogueLeading = RegExp(
          r'^(?:你|我|他|她|它|您|俺|我们|你们|他们|这|那|怎么|为何|为什么|难道|凭什么|谁|哪|好|行|不行|别|快|住手|放肆|等等|喂|啊|哎|哼|哈|切|嘶|嘿|嘘|师傅|师父|队长|大哥|大姐|兄弟|老三|先生|殿下|陛下|大人|道友)',
        ).hasMatch(coreText);
        final isVeryShortReply = coreText.length <= 16;
        final isNarrativePrefix = RegExp(
          r'^(?:在他|在她|在它|只见|只见他|只见她|随着|正当|这时|这时他|这时她|突然|天空中?|窗外|四周|空气中|时间|整座|整个)',
        ).hasMatch(coreText);

        if ((hasDialoguePunctuation ||
                hasModalParticleEnding ||
                hasDialogueLeading ||
                isVeryShortReply) &&
            !isNarrativePrefix) {
          text = '“$text';
        } else {
          text = strippedQuoteText;
        }
      } else {
        // 其它多余闭引号场景：扫描并剥离无前置开引号对应的孤立闭引号
        final sb = StringBuffer();
        int depth = 0;
        for (int idx = 0; idx < text.length; idx++) {
          final c = text[idx];
          if (c == '“') {
            depth++;
            sb.write(c);
          } else if (c == '”') {
            if (depth > 0) {
              depth--;
              sb.write(c);
            }
          } else {
            sb.write(c);
          }
        }
        text = sb.toString();
      }
    } else if (openCount > closeCount) {
      // 具有开引号但末尾遗漏闭引号：
      // 情况 A：段首开引号且段尾是完整终止标点，自动补闭引号
      if (text.startsWith('“') && !text.endsWith('”')) {
        if (RegExp(r'[。！？!?…~—]$').hasMatch(text)) {
          text = '$text”';
        }
      } else if (text.contains('“') && !text.endsWith('”')) {
        // 情况 B：段中引语/自语（如：“……）直至段尾，且段尾为终止标点，自动补闭引号
        if (RegExp(r'[。！？!?…~—]$').hasMatch(text)) {
          text = '$text”';
        }
      }
    }

    return text;
  }

  /// 对段落进行标点自愈、清洗与段首 2em 缩进规整
  static String normalizeParagraph(String raw) {
    if (raw.trim().isEmpty) return '';
    var cleaned = raw.trim();
    // 先剥去可能已有的缩进，统一进入标点自愈管道
    if (cleaned.startsWith(indent)) {
      cleaned = cleaned.substring(indent.length).trim();
    }
    // 纯标点、纯符号、特殊 Unicode 列表符噪点行直接剔除（任何正常小说段落必须含有至少一个有效字符）
    if (!RegExp(r'[\u4e00-\u9fa5a-zA-Z0-9]').hasMatch(cleaned)) {
      return '';
    }
    // 过滤已知站点牛皮癣广告行（防止已缓存旧章节中的广告残余渲染至屏幕）
    if (RegExp(r'^(?:看最新|阅读最新|最新完整章节|精彩小说|请记住|天才一秒|本站所有|章节错误).*?(?:就上|请到|前往|登录|首发|速读|笔趣阁|小说网|免费阅读)',
            caseSensitive: false)
        .hasMatch(cleaned) ||
        RegExp(r'就上[一-龥a-zA-Z0-9]{2,8}(?:谷|网|阁|屋|吧|站|阅读)',
            caseSensitive: false)
        .hasMatch(cleaned)) {
      return '';
    }
    cleaned = healTyposAndOcr(cleaned);
    cleaned = harmonizeQuotes(cleaned);
    if (cleaned.isEmpty) return '';
    return '$indent$cleaned';
  }

  /// 中文错别字、繁简残留、OCR 识别错误及形近同音自愈引擎
  ///
  /// 解决第三方书源常见问题：
  /// 1. 繁简转换未彻底遗留（後->后、麽->么、於->于、动词/时态著->着、藉口->借口、答覆->答复、徵兆->征兆、裡->里、隻->只、幾->几、鬥->斗）
  /// 2. 形近同音混淆字（毕竞->毕竟、竞然->竟然、具都->俱都、高层陨命->高层殒命、死前发狠、语气助词阿->啊）
  /// 3. 玄幻修仙特有严重 OCR 错字（化为童粉->化为齑粉、真燕入道->真煞入道、真悉入腹->真煞入腹）
  /// 4. 异形复合标点杂质与粘连残余（【胃土。-.…….」->【胃土】……”、灵火消息·……->灵火消息……）
  static String healTyposAndOcr(String raw) {
    if (raw.isEmpty) return raw;
    var text = raw;

    // 0. 异形复合标点杂质自愈
    // a. 去除与省略号/破折号粘连的孤立中黑点（如「天地灵火消息·……显然是」->「天地灵火消息……显然是」）
    text = text.replaceAll(RegExp(r'·\s*(?=[…—]{2,})'), '');
    text = text.replaceAll(RegExp(r'(?<=[…—]{2,})\s*·'), '');
    // b. 自愈「【胃土。-.…….」」等杂糅变异标点
    text = text.replaceAllMapped(
      RegExp(r"""【([^】]+?)[。.\-_~]+[…]+[。.\-_~]*[」』”"’']*"""),
      (m) => '【${m.group(1)}】……',
    );

    // 1. 白名单保护机制（保护合法专有名词、成语、古汉语等）
    final protectedTokens = <String, String>{};
    int tokenIndex = 0;
    String protect(String word) {
      final token = '\uE000_${tokenIndex++}_\uE001';
      protectedTokens[token] = word;
      return token;
    }

    // 保护白名单库
    const protectedWords = [
      // 著（保护名词/形容词/专有动词白名单）
      '著作', '名著', '著名', '土著', '显著', '著称', '著述', '编著', '原著', '巨著',
      '拙著', '专著', '译著', '论著', '附著', '较著', '彰明较著', '昭著', '微著', '执著',
      '著有', '著书', '著作权',
      // 藉（保护成语白名单）
      '狼藉', '杯盘狼藉', '声名狼藉', '枕藉',
      // 覆（保护颠覆/覆灭等白名单）
      '颠覆', '覆灭', '覆水难收', '盖覆', '翻覆', '天翻地覆', '覆舟', '全军覆没', '覆辙', '重蹈覆辙',
      // 徵（保护古乐五音白名单）
      '宫商角徵羽', '角徵羽', '徵音', '徵调',
      // 燕（保护合法燕字词汇）
      '燕子', '燕国', '燕王', '燕京', '飞燕', '海燕', '劳燕分飞', '燕雀', '燕山', '燕尾', '燕窝',
      // 悉（保护知悉/熟悉等白名单）
      '熟悉', '知悉', '获悉', '洞悉', '悉知', '悉心', '悉数',
      // 竞（保护竞争等白名单）
      '竞争', '竞赛', '竞走', '竞选', '竞技', '物竞天择',
    ];

    for (final word in protectedWords) {
      if (text.contains(word)) {
        text = text.replaceAll(word, protect(word));
      }
    }

    // 2. 玄幻修仙特有严重 OCR 错字自愈
    // a. 「童粉」自愈为「齑粉」（玄幻经典扫描错识字）
    text = text.replaceAllMapped(
      RegExp(r'(化为|变为|碎为|碾为|化成|变成|碎成|碾成|化作|阖寺都要化为|阖寺都要变成|粉碎为)童粉'),
      (m) => '${m.group(1)}齑粉',
    );
    text = text.replaceAllMapped(
      RegExp(r'(?<=[化变碎碾])为?童粉'),
      (m) => '齑粉',
    );

    // b. 「真燕 / 真悉」自愈为「真煞」（修仙地煞之气错识）
    text = text.replaceAllMapped(
      RegExp(r'([一二三四五六七八九十\d]+阶)真燕'),
      (m) => '${m.group(1)}真煞',
    );
    text = text.replaceAll('真燕入道', '真煞入道');
    text = text.replaceAllMapped(
      RegExp(r'([一道两道三道\s]+)真悉入腹'),
      (m) => '${m.group(1)}真煞入腹',
    );
    text = text.replaceAll('真悉入道', '真煞入道');

    // 3. 通用成语与修仙高频词 OCR 混淆矩阵自愈
    // a. OCR 粘连常见形近成语（如 白->自、童->齑、头->投、急->及、错->措）
    text = text.replaceAll('当浮一大自', '当浮一大白');
    text = text.replaceAll('走头无路', '走投无路');
    text = text.replaceAll('迫不急待', '迫不及待');
    text = text.replaceAll('手足无错', '手足无措');
    text = text.replaceAll('身心具疲', '身心俱疲');
    text = text.replaceAll('面面具到', '面面俱到');
    text = text.replaceAll('神魄俱灭', '神魂俱灭');

    // b. 角色名与专有名词跨段落形近与同音漂移自愈（Entity Consistency Harmonizer）
    // 针对 OCR 笔画误识（玲 王令->蛤 虫合）与拼音打字误选（青玲->青龄）实施权威名收敛
    text = text.replaceAllMapped(
      RegExp(r'青蛤(?=见到|你入|得到|献上|交代|脸上|心中|才凑|一咬牙)'),
      (m) => '青玲',
    );
    text = text.replaceAllMapped(
      RegExp(r'(?<=孰料|这|与|看着妙善与这|看到)青蛤'),
      (m) => '青玲',
    );
    text = text.replaceAllMapped(
      RegExp(r'青龄(?=拜见|道友|一咬牙|献上|交谈|交流完毕|去办|脸上|心中)'),
      (m) => '青玲',
    );
    text = text.replaceAllMapped(
      RegExp(r'(?<=看着妙善与这|与这|这|看到)青龄'),
      (m) => '青玲',
    );
    // 语境兜底：在青鸟部/小公主/空雀度母/度子/白骨道等特定段落中，孤立出现的青蛤/青龄收敛为青玲
    if (text.contains('青鸟部') ||
        text.contains('小公主') ||
        text.contains('空雀度母') ||
        text.contains('度子') ||
        text.contains('方水') ||
        text.contains('白骨道')) {
      text = text.replaceAll('青蛤', '青玲');
      text = text.replaceAll('青龄', '青玲');
    }

    // c. 常见同音形近别字
    text = text.replaceAll('毕竞', '毕竟');
    text = text.replaceAll('竞然', '竟然');
    text = text.replaceAllMapped(
      RegExp(r'具都(?=[看感到露听笑走说望见想])'),
      (m) => '俱都',
    );
    text = text.replaceAllMapped(
      RegExp(r'(高层|直接|当场|在此|险些|不幸)陨命'),
      (m) => '${m.group(1)}殒命',
    );
    text = text.replaceAllMapped(
      RegExp(r'(死前|心中|暗暗|暗自|咬牙)发恨'),
      (m) => '${m.group(1)}发狠',
    );
    // 语气词「阿」->「啊」
    text = text.replaceAllMapped(
      RegExp(r'(不对劲|是|好|对|走|看|行|真行|快点|这不|谁|哪|怎么会)阿(?=[，。！？；：”’』」\s]|$)'),
      (m) => '${m.group(1)}啊',
    );
    text = text.replaceAll('份外', '分外');

    // 4. 繁简遗留字（假简体）高精度自愈
    // 「後」->「后」
    text = text.replaceAll('後', '后');
    // 「麽」->「么」
    text = text.replaceAll('麽', '么');
    // 「於」->「于」
    text = text.replaceAll('於', '于');

    // 「著」->「着」（动词时态助词）
    // 在白名单已被保护的前提下，将所有剩余语境下的「著」统一自愈为简体时态助词「着」
    text = text.replaceAll('著', '着');

    // 「藉」->「借」（狼藉/枕藉已受保护）
    text = text.replaceAll('好藉口', '好借口');
    text = text.replaceAll('藉口', '借口');
    text = text.replaceAll('藉助', '借助');
    text = text.replaceAll('凭藉', '凭借');
    text = text.replaceAll('藉以', '借以');
    text = text.replaceAll('藉此', '借此');
    text = text.replaceAll('藉机', '借机');
    text = text.replaceAll('托藉', '托借');

    // 「覆」->「复」（颠覆/覆灭等已受保护）
    text = text.replaceAll('答覆', '答复');
    text = text.replaceAll('回覆', '回复');
    text = text.replaceAll('反覆', '反复');
    text = text.replaceAll('覆核', '复核');
    text = text.replaceAll('覆信', '复信');

    // 「徵」->「征」（宫商角徵羽已受保护）
    text = text.replaceAll('徵兆', '征兆');
    text = text.replaceAll('特徵', '特征');
    text = text.replaceAll('象徵', '象征');
    text = text.replaceAll('徵求', '征求');
    text = text.replaceAll('徵询', '征询');
    text = text.replaceAll('徵税', '征税');
    text = text.replaceAll('徵兵', '征兵');
    text = text.replaceAll('徵集', '征集');
    text = text.replaceAll('徵辟', '征辟');
    text = text.replaceAll('徵文', '征文');

    // 「裡」->「里」
    text = text.replaceAll('裡', '里');

    // 「隻」->「只」
    text = text.replaceAll('隻身', '只身');
    text = text.replaceAll('隻手', '只手');
    text = text.replaceAll('一隻', '一只');
    text = text.replaceAll('兩隻', '两只');
    text = text.replaceAll('隻字', '只字');
    text = text.replaceAll('隻言', '只言');

    // 「幾」->「几」
    text = text.replaceAll('幾近', '几近');
    text = text.replaceAll('幾乎', '几乎');
    text = text.replaceAll('幾個', '几个');
    text = text.replaceAll('幾人', '几人');
    text = text.replaceAll('幾天', '几天');
    text = text.replaceAll('幾年', '几年');
    text = text.replaceAll('幾次', '几次');
    text = text.replaceAll('幾分', '几分');
    text = text.replaceAll('幾時', '几时');
    text = text.replaceAll('所剩無幾', '所剩无几');

    // 「鬥」->「斗」
    text = text.replaceAll('戰鬥', '战斗');
    text = text.replaceAll('鬥法', '斗法');
    text = text.replaceAll('搏鬥', '搏斗');
    text = text.replaceAll('鬥志', '斗志');
    text = text.replaceAll('爭鬥', '争斗');
    text = text.replaceAll('械鬥', '械斗');

    // 5. 还原白名单占位符
    protectedTokens.forEach((token, originalWord) {
      text = text.replaceAll(token, originalWord);
    });

    return text;
  }
}

