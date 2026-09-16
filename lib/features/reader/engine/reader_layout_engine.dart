import 'dart:math' as math;
import 'cjk_punctuation.dart';
import 'page_models.dart';

/// 纯内存无缝小说排版引擎 (ReaderLayoutEngine)
///
/// 彻底解决：
/// 1. 【切半行】：以数学整数行截断（LineMetrics / maxLinesPerPage），100% 杜绝底部文字被裁剪；
/// 2. 【断句生硬】：严格执行 35 种 CJK 标点避头避尾规则，文字与标点自然流转；
/// 3. 【排版混乱】：单层完整页面上下文度量，行距、段距严密对齐；
/// 4. 【改字号跳脱】：支持字符级锚点搜索，字号微调后毫秒级精准对齐视线焦点。

class ReaderLayoutEngine {
  /// 估算单个字符的宽度（单位：px）
  /// CJK 汉字与全角标点：1.0 em = fontSize + letterSpacing
  /// ASCII 半角：0.35em ~ 0.85em
  static double measureChar(String char, double fontSize, double letterSpacing) {
    if (char == ' ') return fontSize * 0.33 + letterSpacing;
    if (char == '\u3000') return fontSize + letterSpacing;

    final code = char.codeUnitAt(0);
    if (code >= 33 && code <= 126) {
      if ('iljt1.,:;!\'|`-'.contains(char)) {
        return fontSize * 0.35 + letterSpacing;
      }
      if ('wmWM@%'.contains(char)) {
        return fontSize * 0.85 + letterSpacing;
      }
      return fontSize * 0.55 + letterSpacing;
    }

    // 绝大多数汉字及全角标点严格等宽
    return fontSize + letterSpacing;
  }

  /// 将单个段落拆解为符合可用宽度的完整行集合（含避头避尾）
  static List<PageLineItem> splitParagraphToLines({
    required String rawParagraph,
    required int paragraphIndex,
    required double availWidth,
    required double fontSize,
    required double letterSpacing,
    required int globalCharOffsetStart,
  }) {
    final para = CjkPunctuation.normalizeParagraph(rawParagraph);
    if (para.isEmpty) return [];

    final lines = <PageLineItem>[];
    String currentLine = '';
    double currentLineWidth = 0;
    int lineIndexInPara = 0;
    int lineStartOffset = globalCharOffsetStart;
    int curCharOffset = globalCharOffsetStart;

    for (int i = 0; i < para.length; i++) {
      final char = para[i];
      final charW = measureChar(char, fontSize, letterSpacing);
      curCharOffset++;

      if (currentLineWidth + charW <= availWidth) {
        currentLine += char;
        currentLineWidth += charW;
      } else {
        // 放不下，需折行
        // 1. 避头禁则：当前字符是禁止出现在行首的标点（如逗号、句号）
        if (CjkPunctuation.isForbiddenStart(char) && currentLine.length > 1) {
          final lastChar = currentLine.substring(currentLine.length - 1);
          currentLine = currentLine.substring(0, currentLine.length - 1);
          lines.add(PageLineItem(
            text: currentLine,
            paragraphIndex: paragraphIndex,
            lineIndexInPara: lineIndexInPara++,
            isFirstLineOfPara: lines.isEmpty,
            isLastLineOfPara: false,
            charStart: lineStartOffset,
            charEnd: curCharOffset - 2,
          ));
          lineStartOffset = curCharOffset - 2;
          currentLine = lastChar + char;
          currentLineWidth = measureChar(lastChar, fontSize, letterSpacing) + charW;
          continue;
        }

        // 2. 避尾禁则：当前行末尾字符是前置标点（如左书名号《、前引号“）
        final lastChar = currentLine.isNotEmpty ? currentLine.substring(currentLine.length - 1) : '';
        if (CjkPunctuation.isForbiddenEnd(lastChar) && currentLine.length > 1) {
          currentLine = currentLine.substring(0, currentLine.length - 1);
          lines.add(PageLineItem(
            text: currentLine,
            paragraphIndex: paragraphIndex,
            lineIndexInPara: lineIndexInPara++,
            isFirstLineOfPara: lines.isEmpty,
            isLastLineOfPara: false,
            charStart: lineStartOffset,
            charEnd: curCharOffset - 2,
          ));
          lineStartOffset = curCharOffset - 2;
          currentLine = lastChar + char;
          currentLineWidth = measureChar(lastChar, fontSize, letterSpacing) + charW;
          continue;
        }

        // 正常换行
        lines.add(PageLineItem(
          text: currentLine,
          paragraphIndex: paragraphIndex,
          lineIndexInPara: lineIndexInPara++,
          isFirstLineOfPara: lines.isEmpty,
          isLastLineOfPara: false,
          charStart: lineStartOffset,
          charEnd: curCharOffset - 1,
        ));
        lineStartOffset = curCharOffset - 1;
        currentLine = char;
        currentLineWidth = charW;
      }
    }

    if (currentLine.isNotEmpty) {
      lines.add(PageLineItem(
        text: currentLine,
        paragraphIndex: paragraphIndex,
        lineIndexInPara: lineIndexInPara++,
        isFirstLineOfPara: lines.isEmpty,
        isLastLineOfPara: true,
        charStart: lineStartOffset,
        charEnd: curCharOffset,
      ));
    }

    return lines;
  }

  /// 将全章所有段落编排成分页列表
  static List<ChapterPage> paginate({
    required List<String> paragraphs,
    required String title,
    required PagingConfig config,
  }) {
    if (paragraphs.isEmpty) {
      return [
        const ChapterPage(
          pageIndex: 0,
          lines: [],
          isFirstPage: true,
          isLastPage: true,
          charStart: 0,
          charEnd: 0,
        ),
      ];
    }

    // 1. 全文分行
    final allLines = <PageLineItem>[];
    int globalOffset = 0;

    for (int pIdx = 0; pIdx < paragraphs.length; pIdx++) {
      final pLines = splitParagraphToLines(
        rawParagraph: paragraphs[pIdx],
        paragraphIndex: pIdx,
        availWidth: config.availWidth,
        fontSize: config.fontSize,
        letterSpacing: config.letterSpacing,
        globalCharOffsetStart: globalOffset,
      );
      if (pLines.isNotEmpty) {
        allLines.addAll(pLines);
        globalOffset = pLines.last.charEnd;
      }
    }

    if (allLines.isEmpty) {
      return [
        const ChapterPage(
          pageIndex: 0,
          lines: [],
          isFirstPage: true,
          isLastPage: true,
          charStart: 0,
          charEnd: 0,
        ),
      ];
    }

    // 2. 整数行聚合分页（彻底解决切半行）
    final pages = <ChapterPage>[];
    var currentLines = <PageLineItem>[];
    double currentHeight = 0;
    bool isFirstPage = true;
    int pageIndex = 0;

    for (int i = 0; i < allLines.length; i++) {
      final line = allLines[i];
      final targetAvailH = isFirstPage ? config.firstPageAvailHeight : config.availHeight;
      final maxLines = isFirstPage ? config.firstPageMaxLines : config.maxLinesPerPage;

      // 段落末尾行增加段间距
      final lineCost = config.lineHeight + (line.isLastLineOfPara ? config.paragraphGap : 0.0);
      final isLastLineOfChapter = i == allLines.length - 1;
      final extraBottom = isLastLineOfChapter ? config.endMarkHeight : 0.0;

      final fitsHeight = (currentHeight + lineCost + extraBottom) <= targetAvailH;
      final fitsLines = currentLines.length < maxLines;

      if ((fitsHeight && fitsLines) || currentLines.isEmpty) {
        currentLines.add(line);
        currentHeight += lineCost;
      } else {
        // 当前页已满，封装并切下一页
        pages.add(ChapterPage(
          pageIndex: pageIndex++,
          lines: List.unmodifiable(currentLines),
          isFirstPage: isFirstPage,
          isLastPage: false,
          charStart: currentLines.first.charStart,
          charEnd: currentLines.last.charEnd,
        ));
        isFirstPage = false;
        currentLines = [line];
        currentHeight = lineCost;
      }
    }

    if (currentLines.isNotEmpty) {
      pages.add(ChapterPage(
        pageIndex: pageIndex++,
        lines: List.unmodifiable(currentLines),
        isFirstPage: isFirstPage,
        isLastPage: true,
        charStart: currentLines.first.charStart,
        charEnd: currentLines.last.charEnd,
      ));
    }

    return pages;
  }

  /// 根据字符级偏移量，逆向二分查找所在新页码（解决改字号、转屏后进度跳脱）
  static int findPageByCharOffset(List<ChapterPage> pages, int charOffset) {
    if (pages.isEmpty) return 0;
    if (charOffset <= pages.first.charStart) return 0;
    if (charOffset >= pages.last.charEnd) return pages.length - 1;

    int low = 0;
    int high = pages.length - 1;

    while (low <= high) {
      final mid = (low + high) ~/ 2;
      final page = pages[mid];

      if (page.containsCharOffset(charOffset)) {
        return mid;
      } else if (charOffset < page.charStart) {
        high = mid - 1;
      } else {
        low = mid + 1;
      }
    }

    return low.clamp(0, pages.length - 1);
  }
}
