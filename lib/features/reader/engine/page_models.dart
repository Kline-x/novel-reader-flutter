// 阅读排版数据模型 (page_models.dart)
library;

/// 单行排版数据元
class PageLineItem {
  final String text;
  final int paragraphIndex;
  final int lineIndexInPara;
  final bool isFirstLineOfPara;
  final bool isLastLineOfPara;
  final int charStart;
  final int charEnd;

  const PageLineItem({
    required this.text,
    required this.paragraphIndex,
    required this.lineIndexInPara,
    required this.isFirstLineOfPara,
    required this.isLastLineOfPara,
    required this.charStart,
    required this.charEnd,
  });

  int get length => charEnd - charStart;
}

/// 页面聚合结构体
class ChapterPage {
  final int pageIndex;
  final List<PageLineItem> lines;
  final bool isFirstPage;
  final bool isLastPage;
  final int charStart;
  final int charEnd;

  const ChapterPage({
    required this.pageIndex,
    required this.lines,
    required this.isFirstPage,
    required this.isLastPage,
    required this.charStart,
    required this.charEnd,
  });

  int get totalChars => charEnd - charStart;

  /// 检查特定字符绝对偏移量是否落在本页内
  bool containsCharOffset(int offset) {
    return offset >= charStart && offset <= charEnd;
  }
}

/// 视口排版参数配置
class PagingConfig {
  final double viewportWidth;
  final double viewportHeight;
  final double fontSize;
  final double lineHeight;
  final double letterSpacing;
  final double paragraphGap;
  final double padTop;
  final double padBottom;
  final double hPad;
  final double titleHeight;
  final double endMarkHeight;

  const PagingConfig({
    required this.viewportWidth,
    required this.viewportHeight,
    this.fontSize = 18.0,
    double? lineHeight,
    this.letterSpacing = 0.5,
    double? paragraphGap,
    this.padTop = 12.0,
    this.padBottom = 16.0,
    this.hPad = 20.0,
    this.titleHeight = 64.0,
    this.endMarkHeight = 48.0,
  })  : lineHeight = lineHeight ?? (fontSize * 1.68),
        paragraphGap = paragraphGap ?? (fontSize * 0.75);

  /// 纯净可用内容宽度
  double get availWidth => (viewportWidth - hPad * 2).clamp(100.0, 4000.0);

  /// 纯净可用内容高度（普通正文页）
  double get availHeight => (viewportHeight - padTop - padBottom).clamp(lineHeight, 4000.0);

  /// 纯净可用内容高度（首张带大标题页）
  double get firstPageAvailHeight =>
      (availHeight - titleHeight).clamp(lineHeight, 4000.0);

  /// 单页能够容纳的最大完整行数（整数行截断，数学级规避切半行）
  int get maxLinesPerPage => (availHeight / lineHeight).floor();

  /// 首页能够容纳的最大完整行数
  int get firstPageMaxLines => (firstPageAvailHeight / lineHeight).floor();
}

/// 字符级阅读进度锚点（解决改字号、转屏后进度跳脱）
class ReadingAnchor {
  final int chapterIndex;
  final int charOffset;
  final double chapterPercent;

  const ReadingAnchor({
    required this.chapterIndex,
    required this.charOffset,
    this.chapterPercent = 0.0,
  });

  @override
  String toString() => 'ReadingAnchor(ch: $chapterIndex, offset: $charOffset, percent: ${(chapterPercent * 100).toStringAsFixed(1)}%)';
}
