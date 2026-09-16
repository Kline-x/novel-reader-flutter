/// 书签数据模型
class Bookmark {
  final String id;
  final String bookId;
  final String bookTitle;
  final int chapterIndex;
  final String chapterTitle;
  final int charOffset;
  final String snippet;
  final DateTime createdAt;

  const Bookmark({
    required this.id,
    required this.bookId,
    required this.bookTitle,
    required this.chapterIndex,
    required this.chapterTitle,
    required this.charOffset,
    required this.snippet,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bookId': bookId,
      'bookTitle': bookTitle,
      'chapterIndex': chapterIndex,
      'chapterTitle': chapterTitle,
      'charOffset': charOffset,
      'snippet': snippet,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Bookmark.fromJson(Map<String, dynamic> json) {
    return Bookmark(
      id: json['id'] as String? ?? '',
      bookId: json['bookId'] as String? ?? '',
      bookTitle: json['bookTitle'] as String? ?? '',
      chapterIndex: json['chapterIndex'] as int? ?? 0,
      chapterTitle: json['chapterTitle'] as String? ?? '',
      charOffset: json['charOffset'] as int? ?? 0,
      snippet: json['snippet'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Bookmark copyWith({
    String? id,
    String? bookId,
    String? bookTitle,
    int? chapterIndex,
    String? chapterTitle,
    int? charOffset,
    String? snippet,
    DateTime? createdAt,
  }) {
    return Bookmark(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      bookTitle: bookTitle ?? this.bookTitle,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      charOffset: charOffset ?? this.charOffset,
      snippet: snippet ?? this.snippet,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
