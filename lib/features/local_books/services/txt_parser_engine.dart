import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:fast_gbk/fast_gbk.dart';
import '../models/local_chapter.dart';

/// 大文件流式 TXT 智能分章解析引擎 (txt_parser_engine.dart)
/// - 智能嗅探 BOM 与 GBK / UTF-8 编码
/// - 纯流式字节扫描，毫秒级快速提取目录索引，不将大文件全量载入内存
/// - 基于 RandomAccessFile 局部流式读取正文，彻底消除 OOM 与卡顿
class TxtParserEngine {
  /// 章节标题识别正则
  ///
  /// 相比早期版本放宽了三处，避免常见排版整本识别不出章节、只能当"正文"一章打开：
  /// 1. `第` 与数字、数字与 `章` 之间允许空格（`第 3 章` / `第 001 章`）；
  /// 2. 允许标题前带装饰符号或"正文/卷N"前缀（`☆、第一章` / `正文 第十章`）；
  /// 3. 补齐 `话/幕/折/部/集/篇/回/节/卷` 等量词与 `Chapter/CHAPTER/Chap` 等英文写法。
  static final RegExp _chapterPattern = RegExp(
    r'^\s*'
    // 可选装饰符号前缀。含 `、·` 是因为书源导出的目录常写成「☆、第五章 夜谈」
    r'(?:[☆★◇◆●○•、·\*\-—=＝~～【\[\(（]+\s*)?'
    r'(?:正文\s*)?' // 可选"正文"前缀
    r'(?:'
    r'第\s*[0-9０-９零一二两三四五六七八九十百千万]+\s*[章回节卷集幕篇部话折]'
    r'|(?:Chapter|Chap|CH)\s*\.?\s*[0-9]+'
    r'|[0-9０-９]{1,4}\s*[、\.．：: ]'
    r'|引子|序章|序言|序幕|楔子|前言|后记|尾声|终章|番外|附录|后序|自序'
    r')'
    r'\s*(.*)$',
    caseSensitive: false,
  );

  /// 单行超过该字节数则不再当作章节标题候选（正文段落通常很长）
  static const int _maxTitleLineBytes = 300;

  /// 标题的字符数上限。300 字节约合 100 个汉字，对标题来说过于宽松，
  /// 真实章节标题极少超过 50 字。
  static const int _maxTitleChars = 50;

  /// 正文句子的特征：出现句号/分号，或以逗号、顿号收尾。
  ///
  /// 只靠 [_chapterPattern] 会把「第三章正文，用于验证章节切换。」这种
  /// 以章节号开头的**正文段落**误判成标题——实测一本 3 章的 TXT 被切成 5 章，
  /// 且真章节的内容被后面那条假标题抢走，显示「本章暂无正文内容」。
  /// 章节标题不会是一个写完的句子，以此区分。
  /// 保留 `！？` 结尾的情况，「第一章 开始了！」这类标题是合法的。
  static final RegExp _proseSentencePattern = RegExp(r'[。；]|[，、]\s*$');

  /// 这一行是否是章节标题。
  ///
  /// 公开给测试用：分章质量直接决定阅读体验，值得单独守住。
  static bool isChapterTitleLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.length > _maxTitleChars) return false;
    if (_proseSentencePattern.hasMatch(trimmed)) return false;
    return _chapterPattern.hasMatch(trimmed);
  }

  /// 整份文件都没有换行符时的保护阈值：超过该长度直接放弃逐行扫描
  static const int _maxLineBytesBeforeGiveUp = 4 * 1024 * 1024;

  /// 无法识别出章节时的兜底切分粒度（约 60KB 一段，避免整本一章导致排版卡顿）
  static const int _fallbackChunkBytes = 60 * 1024;

  /// 智能嗅探编码 (UTF-8, GBK)
  static Encoding detectEncoding(Uint8List sampleBytes) {
    if (sampleBytes.length >= 3 &&
        sampleBytes[0] == 0xEF &&
        sampleBytes[1] == 0xBB &&
        sampleBytes[2] == 0xBF) {
      return utf8;
    }
    if (sampleBytes.length >= 2) {
      if (sampleBytes[0] == 0xFF && sampleBytes[1] == 0xFE) {
        return utf8; // 回退通用
      }
    }

    // 尝试严格 UTF-8 解码
    //
    // 关键：必须先把采样窗口裁到完整的 UTF-8 字符边界再做严格解码。
    // 否则 16KB / 分章切片的结尾极大概率把一个 3 字节汉字切成两半，
    // 严格解码必然抛异常 → 整份 UTF-8 文件被误判成 GBK →
    // 通篇乱码 → 章节标题一个也匹配不上 → 整本书塞进"正文"一章。
    // 这正是 24MB 的《蛊真人》导入后无法分章的直接原因。
    final probe = _trimToUtf8Boundary(sampleBytes);
    try {
      utf8.decode(probe, allowMalformed: false);
      return utf8;
    } catch (_) {
      // 无法以 UTF-8 解码，判定为 GBK / GB2312 / GB18030
      return gbk;
    }
  }

  /// 把字节数组末尾可能被截断的半个 UTF-8 字符裁掉
  static List<int> _trimToUtf8Boundary(List<int> bytes) {
    if (bytes.isEmpty) return bytes;
    // UTF-8 字符最长 4 字节，最多回退 3 个续字节即可找到首字节
    for (var back = 0; back < 4 && back < bytes.length; back++) {
      final idx = bytes.length - 1 - back;
      final b = bytes[idx];
      if (b < 0x80) {
        // 单字节 ASCII，本身就是完整字符边界
        return back == 0 ? bytes : bytes.sublist(0, idx + 1);
      }
      if (b >= 0xC0) {
        // 找到多字节序列的首字节，推算它需要几个字节
        final need = b >= 0xF0
            ? 4
            : b >= 0xE0
                ? 3
                : 2;
        final available = bytes.length - idx;
        // 够长说明这个字符是完整的，否则把它整个裁掉
        return available >= need ? bytes : bytes.sublist(0, idx);
      }
      // 0x80~0xBF 是续字节，继续向前找首字节
    }
    return bytes;
  }

  /// 扫描大文件建立轻量章节索引表
  static Future<List<LocalChapter>> parseChapters(File file,
      {Encoding? specifiedEncoding}) async {
    final fileSize = await file.length();
    if (fileSize == 0) return [];

    // 1. 嗅探编码
    final sampleLength = fileSize > 16384 ? 16384 : fileSize;
    final raf = await file.open(mode: FileMode.read);
    final sampleBytes = await raf.read(sampleLength);
    await raf.setPosition(0);

    final encoding = specifiedEncoding ?? detectEncoding(sampleBytes);

    final chapters = <LocalChapter>[];
    int currentOffset = 0;
    int? firstChapterOffset;

    const bufferSize = 64 * 1024; // 64KB 缓冲区
    final buffer = Uint8List(bufferSize);
    final lineBuffer = <int>[];
    int lineStartOffset = 0;

    /// 将一整行交给章节识别；命中则登记为新章
    void consumeLine(List<int> rawLine, int startOffset) {
      if (rawLine.isEmpty) return;
      var line = rawLine;
      // 行尾可能残留 CR（0x0D，来自 CRLF 换行）
      while (line.isNotEmpty && line.last == 0x0D) {
        line = line.sublist(0, line.length - 1);
      }
      if (line.isEmpty || line.length > _maxTitleLineBytes) return;

      String lineStr = '';
      try {
        lineStr = encoding == utf8
            ? utf8.decode(line, allowMalformed: true)
            : gbk.decode(line, allowMalformed: true);
      } catch (_) {
        return;
      }

      final trimmed = lineStr.trim();
      if (!isChapterTitleLine(trimmed)) return;

      if (firstChapterOffset == null) {
        firstChapterOffset = startOffset;
        // 若首章前有前言/序章内容，收纳为第 0 章
        if (firstChapterOffset! > 0) {
          chapters.add(LocalChapter(
            index: 0,
            title: '序言 / 引子',
            byteOffset: 0,
            byteLength: firstChapterOffset!,
          ));
        }
      }

      // 更新上一章的长度
      if (chapters.isNotEmpty) {
        final lastIdx = chapters.length - 1;
        final prev = chapters[lastIdx];
        chapters[lastIdx] = LocalChapter(
          index: prev.index,
          title: prev.title,
          byteOffset: prev.byteOffset,
          byteLength: startOffset - prev.byteOffset,
        );
      }

      chapters.add(LocalChapter(
        index: chapters.length,
        title: trimmed,
        byteOffset: startOffset,
        byteLength: fileSize - startOffset, // 暂定至文件末尾
      ));
    }

    var gaveUpLineScan = false;
    int bytesRead = 0;
    while ((bytesRead = await raf.readInto(buffer)) > 0) {
      for (int i = 0; i < bytesRead; i++) {
        final b = buffer[i];
        final fileBytePos = currentOffset + i;

        if (b == 0x0A) {
          consumeLine(lineBuffer, lineStartOffset);
          lineBuffer.clear();
          lineStartOffset = fileBytePos + 1;
        } else {
          lineBuffer.add(b);
          // 整份文件没有任何换行符时，避免 lineBuffer 无限增长撑爆内存
          if (lineBuffer.length > _maxLineBytesBeforeGiveUp) {
            gaveUpLineScan = true;
            break;
          }
        }
      }
      if (gaveUpLineScan) break;
      currentOffset += bytesRead;
    }

    // 文件末尾没有换行符的最后一行，此前会被整个丢弃
    if (!gaveUpLineScan && lineBuffer.isNotEmpty) {
      consumeLine(lineBuffer, lineStartOffset);
    }

    await raf.close();

    if (chapters.isEmpty) {
      // 识别不到任何章节标题时，不再把整本塞进单独一章——
      // 几 MB 正文压在一页里会让排版引擎和阅读器同时卡死。
      // 大文件按固定字节切成若干段，至少保证可翻可读。
      if (fileSize > _fallbackChunkBytes * 2) {
        var offset = 0;
        var index = 0;
        while (offset < fileSize) {
          final len = (offset + _fallbackChunkBytes > fileSize)
              ? fileSize - offset
              : _fallbackChunkBytes;
          chapters.add(LocalChapter(
            index: index,
            title: '正文 ${index + 1}',
            byteOffset: offset,
            byteLength: len,
          ));
          offset += len;
          index++;
        }
      } else {
        chapters.add(LocalChapter(
          index: 0,
          title: '正文',
          byteOffset: 0,
          byteLength: fileSize,
        ));
      }
    }

    return chapters;
  }

  /// 流式提取单章正文并清洗为 Modern Soft UI 排版段落
  static Future<List<String>> readChapterContent(
    File file,
    LocalChapter chapter, {
    Encoding? encoding,
  }) async {
    final fileSize = await file.length();
    if (chapter.byteOffset >= fileSize) return [];

    final lengthToRead = (chapter.byteOffset + chapter.byteLength > fileSize)
        ? fileSize - chapter.byteOffset
        : chapter.byteLength;

    if (lengthToRead <= 0) return [];

    final raf = await file.open(mode: FileMode.read);
    await raf.setPosition(chapter.byteOffset);
    final bytes = await raf.read(lengthToRead);
    await raf.close();

    final actualEncoding = encoding ?? detectEncoding(bytes);
    String rawText;
    try {
      rawText = actualEncoding == utf8
          ? utf8.decode(bytes, allowMalformed: true)
          : gbk.decode(bytes);
    } catch (_) {
      rawText = utf8.decode(bytes, allowMalformed: true);
    }

    // 格式化为标准段落
    final lines = rawText.split(RegExp(r'\r?\n'));
    final paragraphs = <String>[];

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      // 过滤与章节标题完全相同的首行（避免与阅读器顶部标题重复）
      if (paragraphs.isEmpty && trimmed == chapter.title.trim()) {
        continue;
      }
      // 规范中文 2em 全角缩进
      paragraphs.add('\u3000\u3000$trimmed');
    }

    return paragraphs.isEmpty ? ['\u3000\u3000（本章暂无正文内容）'] : paragraphs;
  }
}
