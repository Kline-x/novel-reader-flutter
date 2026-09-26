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

    // 1. 半角双引号成对规范化为中文全角双引号
    if (text.contains('"')) {
      final sb = StringBuffer();
      bool inQuote = false;
      for (int i = 0; i < text.length; i++) {
        final c = text[i];
        if (c == '"') {
          sb.write(inQuote ? '”' : '“');
          inQuote = !inQuote;
        } else {
          sb.write(c);
        }
      }
      text = sb.toString();
    }

    // 2. 段首倒置引号纠正（若段首为 ” 或 ’，纠正为标准开引号 “ 或 ‘）
    if (text.startsWith('”')) {
      text = '“${text.substring(1)}';
    } else if (text.startsWith('’')) {
      text = '‘${text.substring(1)}';
    }

    // 3. 冒号引语漏开引号自愈：例如「道：走吧。”」->「道：“走吧。”」
    text = text.replaceAllMapped(
      RegExp(r'([：:])([^“"”\r\n]+?[。！？!?…~]+[”"]+)'),
      (m) => '${m.group(1)}“${m.group(2)}',
    );

    // 4. 统计中文字符引号配对状态
    int openCount = 0;
    int closeCount = 0;
    for (int i = 0; i < text.length; i++) {
      final c = text[i];
      if (c == '“') openCount++;
      if (c == '”') closeCount++;
    }

    // 5. 解决只有结尾引号无开头引号
    if (closeCount > openCount) {
      // 判定闭引号是否位于段落结尾（支持 ！” 与 ”！ 两种标点相对顺序）
      final endsWithQuote =
          RegExp(r'[。！？!?…~—]*[”]+$|[”]+[。！？!?…~—]+$').hasMatch(text);

      if (openCount == 0 && closeCount == 1 && endsWithQuote) {
        // 整段只有一个结尾引号，且位于末尾附近
        // 提取纯净核心文本（剥除孤立闭引号，但保留末尾的标点）
        final strippedQuoteText = text.replaceAll('”', '').trim();
        final coreText =
            strippedQuoteText.replaceAll(RegExp(r'[。！？!?…~—]+$'), '').trim();

        // 强台词特征判定：
        // A. 句末为强烈对话语气标点（叹号、问号、省略号、浪线等）
        final hasDialoguePunctuation =
            RegExp(r'[！？!?…~]$').hasMatch(strippedQuoteText);

        // B. 句末带有常见口语对话助词（如 吧/呢/吗/啊/呀/啦/嘛/呐/哦/噢/哈/嘿/哼/哩/呗/咯/了/成/行/好/对/办）
        final hasModalParticleEnding = RegExp(r'[吧呢吗啊呀啦嘛呐哦噢哈嘿哼哩呗咯了成好办对]$')
            .hasMatch(coreText);

        // C. 段首带有典型台词开篇词/人称代词/叹词
        final hasDialogueLeading = RegExp(
          r'^(?:你|我|他|她|它|您|俺|我们|你们|他们|这|那|怎么|为何|为什么|难道|凭什么|谁|哪|好|行|不行|别|快|住手|放肆|等等|喂|啊|哎|哼|哈|切|嘶|嘿|嘘|师傅|师父|队长|大哥|大姐|兄弟|老三|先生|殿下|陛下|大人|道友)',
        ).hasMatch(coreText);

        // D. 极短文本（<= 16 字），在小说中单占一行末尾带引号几乎必为简短答复
        final isVeryShortReply = coreText.length <= 16;

        // E. 明确的第三人称客观叙述前缀（如“在他手中...”、“只见...”、“窗外...”），绝不误标为台词
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
          // 否则判定为客观叙述/环境描写末尾残留的孤立垃圾引号，直接剔除
          text = strippedQuoteText;
        }
      } else {
        // 其它多余闭引号场景：扫描并剥离无前置开引号对应的孤立闭引号
        final sb = StringBuffer();
        int depth = 0;
        for (int i = 0; i < text.length; i++) {
          final c = text[i];
          if (c == '“') {
            depth++;
            sb.write(c);
          } else if (c == '”') {
            if (depth > 0) {
              depth--;
              sb.write(c);
            } else {
              // 剥离孤立闭引号
            }
          } else {
            sb.write(c);
          }
        }
        text = sb.toString();
      }
    } else if (openCount > closeCount) {
      // 具有开引号但末尾遗漏闭引号：若是段首开引号且段尾是完整终止标点，自动补闭引号
      if (text.startsWith('“') && !text.endsWith('”')) {
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
    cleaned = harmonizeQuotes(cleaned);
    if (cleaned.isEmpty) return '';
    return '$indent$cleaned';
  }
}
