import 'package:flutter/material.dart';

/// 划线高亮与批注笔记模型
class Annotation {
  final String id;
  final String bookId;
  final String bookTitle;
  final int chapterIndex;
  final String chapterTitle;
  final int charStart;
  final int charEnd;
  final String selectedText;
  final String? note;
  final int colorIndex;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Annotation({
    required this.id,
    required this.bookId,
    required this.bookTitle,
    required this.chapterIndex,
    required this.chapterTitle,
    required this.charStart,
    required this.charEnd,
    required this.selectedText,
    this.note,
    this.colorIndex = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 高亮色彩预设 (Modern Soft UI 4 色)
  static const List<Color> highlightColors = [
    Color(0xFFFDE68A), // 晨曦黄
    Color(0xFFA7F3D0), // 薄荷绿
    Color(0xFFBAE6FD), // 天青蓝
    Color(0xFFFBCFE8), // 茱萸粉
  ];

  static const List<String> colorNames = ['晨曦黄', '薄荷绿', '天青蓝', '茱萸粉'];

  Color get color =>
      highlightColors[colorIndex.clamp(0, highlightColors.length - 1)];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bookId': bookId,
      'bookTitle': bookTitle,
      'chapterIndex': chapterIndex,
      'chapterTitle': chapterTitle,
      'charStart': charStart,
      'charEnd': charEnd,
      'selectedText': selectedText,
      if (note != null) 'note': note,
      'colorIndex': colorIndex,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Annotation.fromJson(Map<String, dynamic> json) {
    return Annotation(
      id: json['id'] as String? ?? '',
      bookId: json['bookId'] as String? ?? '',
      bookTitle: json['bookTitle'] as String? ?? '',
      chapterIndex: json['chapterIndex'] as int? ?? 0,
      chapterTitle: json['chapterTitle'] as String? ?? '',
      charStart: json['charStart'] as int? ?? 0,
      charEnd: json['charEnd'] as int? ?? 0,
      selectedText: json['selectedText'] as String? ?? '',
      note: json['note'] as String?,
      colorIndex: json['colorIndex'] as int? ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Annotation copyWith({
    String? id,
    String? bookId,
    String? bookTitle,
    int? chapterIndex,
    String? chapterTitle,
    int? charStart,
    int? charEnd,
    String? selectedText,
    String? note,
    int? colorIndex,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Annotation(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      bookTitle: bookTitle ?? this.bookTitle,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      charStart: charStart ?? this.charStart,
      charEnd: charEnd ?? this.charEnd,
      selectedText: selectedText ?? this.selectedText,
      note: note ?? this.note,
      colorIndex: colorIndex ?? this.colorIndex,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// 划线选区维度模式
enum AnnotationSelectionMode {
  word('字/词', '🎯 选字'),
  sentence('单句', '📄 选句'),
  paragraph('整段', '📑 选段'),
  line('单行', '📏 选行');

  final String label;
  final String badgeText;
  const AnnotationSelectionMode(this.label, this.badgeText);
}

/// 某一种选区维度的候选项
class AnnotationCandidate {
  final String text;
  final int charStart;
  final int charEnd;
  final AnnotationSelectionMode mode;

  const AnnotationCandidate({
    required this.text,
    required this.charStart,
    required this.charEnd,
    required this.mode,
  });
}

/// 划线选区上下文（包含各维度的预置候选及段落全文，用于微调扩缩）
class AnnotationSelectionContext {
  final AnnotationCandidate? wordCandidate;
  final AnnotationCandidate? sentenceCandidate;
  final AnnotationCandidate? paragraphCandidate;
  final AnnotationCandidate? lineCandidate;
  final String? fullContextText;
  final int contextBaseOffset;

  const AnnotationSelectionContext({
    this.wordCandidate,
    this.sentenceCandidate,
    this.paragraphCandidate,
    this.lineCandidate,
    this.fullContextText,
    this.contextBaseOffset = 0,
  });
}
