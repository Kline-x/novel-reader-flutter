/// 表示切分后的单个发音句子及其在章节正文中的字符坐标
class TtsSentence {
  final int index;
  final String text;
  final int startIndex;
  final int endIndex;

  const TtsSentence({
    required this.index,
    required this.text,
    required this.startIndex,
    required this.endIndex,
  });

  @override
  String toString() => 'TtsSentence($index, [$startIndex..$endIndex]: "$text")';
}

/// 中文文本智能断句分片引擎
class TtsSentenceSplitter {
  /// 中文常见句末标点集合（包含省略号与感叹号）
  static final RegExp _terminalPunctuation = RegExp(r'[。！？!?；;\n]+');

  /// 常见后置闭合标点（引号、括号等）
  static const String _closingQuotes = '"\'”’」』）)》]】';

  /// 对长篇正文进行智能断句
  static List<TtsSentence> split(String content) {
    if (content.trim().isEmpty) {
      return [];
    }

    final List<TtsSentence> result = [];
    int cursor = 0;
    final int length = content.length;

    while (cursor < length) {
      // 跳过前导空白
      while (cursor < length && _isWhitespace(content[cursor])) {
        cursor++;
      }
      if (cursor >= length) break;

      final int sentenceStart = cursor;
      int sentenceEnd = length;

      // 搜索下一个句末标点
      final match = _terminalPunctuation.firstMatch(content.substring(cursor));
      if (match != null) {
        int endCandidate = cursor + match.end;

        // 如果紧接着有右引号/闭合括号，将其归入当前句
        while (endCandidate < length &&
            _closingQuotes.contains(content[endCandidate])) {
          endCandidate++;
        }

        sentenceEnd = endCandidate;
      }

      final rawSentence = content.substring(sentenceStart, sentenceEnd).trim();
      if (rawSentence.isNotEmpty) {
        result.add(TtsSentence(
          index: result.length,
          text: rawSentence,
          startIndex: sentenceStart,
          endIndex: sentenceEnd,
        ));
      }

      cursor = sentenceEnd;
    }

    return result;
  }

  static bool _isWhitespace(String char) {
    return char == ' ' ||
        char == '\t' ||
        char == '\r' ||
        char == '\n' ||
        char == '　';
  }
}
