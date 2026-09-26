import '../../sources/services/pinyin_harmonizer.dart';
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
  static double measureChar(
      String char, double fontSize, double letterSpacing) {
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

  static bool _isWordChar(String char) {
    if (char.isEmpty) return false;
    final code = char.codeUnitAt(0);
    return (code >= 65 && code <= 90) ||
        (code >= 97 && code <= 122) ||
        (code >= 48 && code <= 57) ||
        code == 45 ||
        code == 95;
  }

  /// 将单个段落拆解为符合可用宽度的完整行集合（含出版级避头避尾、标点悬挂与英文Word-wrap）
  static List<PageLineItem> splitParagraphToLines({
    required String rawParagraph,
    required int paragraphIndex,
    required double availWidth,
    required double fontSize,
    required double letterSpacing,
    required int globalCharOffsetStart,
  }) {
    final restored = PinyinHarmonizer.restorePinyin(rawParagraph);
    final para = CjkPunctuation.normalizeParagraph(restored);
    if (para.isEmpty) return [];

    final lines = <PageLineItem>[];
    String currentLine = '';
    double currentLineWidth = 0;
    int lineIndexInPara = 0;
    int lineStartOffset = globalCharOffsetStart;

    void commitLine(String text, {required bool isLast}) {
      final trimmed = text.trimRight();
      if (trimmed.isEmpty) return;
      lines.add(PageLineItem(
        text: trimmed,
        paragraphIndex: paragraphIndex,
        lineIndexInPara: lineIndexInPara++,
        isFirstLineOfPara: lines.isEmpty,
        isLastLineOfPara: isLast,
        charStart: lineStartOffset,
        charEnd: lineStartOffset + trimmed.length,
      ));
      lineStartOffset += trimmed.length;
    }

    double measureString(String str) {
      double w = 0;
      for (int i = 0; i < str.length; i++) {
        w += measureChar(str[i], fontSize, letterSpacing);
      }
      return w;
    }

    for (int i = 0; i < para.length; i++) {
      final char = para[i];

      // 行首吞噬西文半角空格（但段首全角空格缩进严格保留）
      if (currentLine.isEmpty && char == ' ') {
        continue;
      }

      final charW = measureChar(char, fontSize, letterSpacing);

      if (currentLineWidth + charW <= availWidth) {
        currentLine += char;
        currentLineWidth += charW;
      } else {
        // 放不下，需折行处理
        // 1. 避头标点行末悬挂（Hanging Punctuation）：
        // 若当前字符为避头标点且外突在容差范围内（<= 0.75em），优先悬挂在当前行末
        if (CjkPunctuation.isForbiddenStart(char) &&
            currentLineWidth + charW <= availWidth + fontSize * 0.75) {
          currentLine += char;
          currentLineWidth += charW;
          continue;
        }

        // 2. 避头禁则整体移行（Pull-down for Forbidden Start）：
        // 若当前字符为避头标点且无法悬挂，拉回行末连续标点及前面的汉字，确保下一行行首不为标点
        if (CjkPunctuation.isForbiddenStart(char) && currentLine.length > 1) {
          int pullCount = 0;
          while (pullCount < currentLine.length &&
              CjkPunctuation.isForbiddenStart(
                  currentLine[currentLine.length - 1 - pullCount])) {
            pullCount++;
          }
          if (pullCount < currentLine.length) {
            pullCount++; // 抓取前面的非避头字符（如汉字）
          }

          if (pullCount > 0 && pullCount < currentLine.length) {
            final carryOver =
                currentLine.substring(currentLine.length - pullCount);
            final remainingLine =
                currentLine.substring(0, currentLine.length - pullCount);
            commitLine(remainingLine, isLast: false);
            currentLine = carryOver + char;
            currentLineWidth = measureString(currentLine);
            continue;
          }
        }

        // 3. 避尾禁则（Push-down for Forbidden End）：
        // 若当前行末尾是前置标点（如前引号“、书名号《），整体移至下一行行首
        if (currentLine.isNotEmpty &&
            CjkPunctuation.isForbiddenEnd(
                currentLine.substring(currentLine.length - 1)) &&
            currentLine.length > 1) {
          int pushCount = 0;
          while (pushCount < currentLine.length &&
              CjkPunctuation.isForbiddenEnd(
                  currentLine[currentLine.length - 1 - pushCount])) {
            pushCount++;
          }
          if (pushCount > 0 && pushCount < currentLine.length) {
            final carryOver =
                currentLine.substring(currentLine.length - pushCount);
            final remainingLine =
                currentLine.substring(0, currentLine.length - pushCount);
            commitLine(remainingLine, isLast: false);
            currentLine = carryOver + char;
            currentLineWidth = measureString(currentLine);
            continue;
          }
        }

        // 4. 西文单词防撕裂（Word-wrap）：
        // 若当前字符是西文字符且行末也是西文字符，将未完结单词整体移至下一行
        if (_isWordChar(char) &&
            currentLine.isNotEmpty &&
            _isWordChar(currentLine.substring(currentLine.length - 1))) {
          int wordLen = 0;
          while (wordLen < currentLine.length &&
              _isWordChar(currentLine[currentLine.length - 1 - wordLen])) {
            wordLen++;
          }
          // 单词长度未占满整行且在合理单词长度内（<= 24字符），整体移行
          if (wordLen > 0 && wordLen < currentLine.length && wordLen <= 24) {
            final carryOver =
                currentLine.substring(currentLine.length - wordLen);
            final remainingLine =
                currentLine.substring(0, currentLine.length - wordLen);
            commitLine(remainingLine, isLast: false);
            currentLine = carryOver + char;
            currentLineWidth = measureString(currentLine);
            continue;
          }
        }

        // 5. 正常换行
        commitLine(currentLine, isLast: false);
        if (char == ' ') {
          // 折行处为空格，直接忽略空格
          currentLine = '';
          currentLineWidth = 0;
        } else {
          currentLine = char;
          currentLineWidth = charW;
        }
      }
    }

    if (currentLine.isNotEmpty) {
      commitLine(currentLine, isLast: true);
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
      final targetAvailH =
          isFirstPage ? config.firstPageAvailHeight : config.availHeight;
      final maxLines =
          isFirstPage ? config.firstPageMaxLines : config.maxLinesPerPage;

      // 段落末尾行增加段间距
      final lineCost = config.lineHeight +
          (line.isLastLineOfPara ? config.paragraphGap : 0.0);
      final isLastLineOfChapter = i == allLines.length - 1;
      final extraBottom = isLastLineOfChapter ? config.endMarkHeight : 0.0;

      final fitsHeight =
          (currentHeight + lineCost + extraBottom) <= targetAvailH;
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

  /// 根据字符级偏移量，逆向精准匹配所在新页码（解决改字号、转屏后进度跳脱）
  static int findPageByCharOffset(List<ChapterPage> pages, int charOffset) {
    if (pages.isEmpty) return 0;
    if (charOffset <= pages.first.charStart) return 0;
    if (charOffset >= pages.last.charEnd) return pages.length - 1;

    for (int i = 0; i < pages.length; i++) {
      if (pages[i].containsCharOffset(charOffset)) {
        return i;
      }
    }

    // 若因字符清洗或段间隙未完全精准命中，回退至最接近的有效页
    for (int i = pages.length - 1; i >= 0; i--) {
      if (charOffset >= pages[i].charStart) {
        return i;
      }
    }
    return 0;
  }
}
