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

  /// 对段落进行清洗与段首 2em 缩进规整
  static String normalizeParagraph(String raw) {
    if (raw.trim().isEmpty) return '';
    final cleaned = raw.trim();
    if (cleaned.startsWith(indent)) return cleaned;
    return '$indent$cleaned';
  }
}
