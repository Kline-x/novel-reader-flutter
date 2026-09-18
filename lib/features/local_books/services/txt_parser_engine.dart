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
  static final RegExp _chapterPattern = RegExp(
    r'^\s*(第[0-9零一二两三四五六七八九十百千万]+[章回节卷集幕篇部话折篇]|Chapter\s+[0-9]+|引子|序章|序言|楔子|前言|尾声|后记|番外|附录|[0-9]{1,4}[、. ])\s*(.*)$',
    caseSensitive: false,
  );

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
    try {
      utf8.decode(sampleBytes, allowMalformed: false);
      return utf8;
    } catch (_) {
      // 无法以 UTF-8 解码，判定为 GBK / GB2312 / GB18030
      return gbk;
    }
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

    int bytesRead = 0;
    while ((bytesRead = await raf.readInto(buffer)) > 0) {
      for (int i = 0; i < bytesRead; i++) {
        final b = buffer[i];
        final fileBytePos = currentOffset + i;

        if (b == 0x0A) {
          // \n 换行符
          // 解析完整行
          if (lineBuffer.isNotEmpty && lineBuffer.last == 0x0D) {
            lineBuffer.removeLast(); // 移除 \r
          }

          if (lineBuffer.isNotEmpty) {
            // 只有当前行长度在合理章节名范围内（<= 100字符）才做正则判断
            if (lineBuffer.length <= 300) {
              String lineStr = '';
              try {
                lineStr = encoding == utf8
                    ? utf8.decode(lineBuffer, allowMalformed: true)
                    : gbk.decode(lineBuffer);
              } catch (_) {}

              final trimmed = lineStr.trim();
              if (trimmed.isNotEmpty && _chapterPattern.hasMatch(trimmed)) {
                if (firstChapterOffset == null) {
                  firstChapterOffset = lineStartOffset;
                  // 若首章前有前言/序章内容，收纳为第 0 章
                  if (firstChapterOffset > 0) {
                    chapters.add(LocalChapter(
                      index: 0,
                      title: '序言 / 引子',
                      byteOffset: 0,
                      byteLength: firstChapterOffset,
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
                    byteLength: lineStartOffset - prev.byteOffset,
                  );
                }

                // 添加新章
                chapters.add(LocalChapter(
                  index: chapters.length,
                  title: trimmed,
                  byteOffset: lineStartOffset,
                  byteLength: fileSize - lineStartOffset, // 暂定至文件末尾
                ));
              }
            }
          }

          lineBuffer.clear();
          lineStartOffset = fileBytePos + 1;
        } else {
          lineBuffer.add(b);
        }
      }
      currentOffset += bytesRead;
    }

    await raf.close();

    // 如果未识别出任何章节模式（短篇或无标准章回），作为单章全本
    if (chapters.isEmpty) {
      chapters.add(LocalChapter(
        index: 0,
        title: '正文',
        byteOffset: 0,
        byteLength: fileSize,
      ));
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
