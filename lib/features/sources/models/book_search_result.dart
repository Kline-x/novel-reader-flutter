/// 书籍搜索结果数据模型 (book_search_result.dart)
class BookSearchResult {
  final String id;
  final String title;
  final String author;
  final String bookUrl;
  final String? coverUrl;
  final String? latestChapter;
  final String? intro;
  final String sourceId;
  final String sourceName;
  int? latencyMs;

  BookSearchResult({
    required this.id,
    required this.title,
    required this.author,
    required this.bookUrl,
    this.coverUrl,
    this.latestChapter,
    this.intro,
    required this.sourceId,
    required this.sourceName,
    this.latencyMs,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'bookUrl': bookUrl,
      'coverUrl': coverUrl,
      'latestChapter': latestChapter,
      'intro': intro,
      'sourceId': sourceId,
      'sourceName': sourceName,
      'latencyMs': latencyMs,
    };
  }

  factory BookSearchResult.fromJson(Map<String, dynamic> json) {
    return BookSearchResult(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      author: json['author'] as String? ?? '',
      bookUrl: json['bookUrl'] as String? ?? '',
      coverUrl: json['coverUrl'] as String?,
      latestChapter: json['latestChapter'] as String?,
      intro: json['intro'] as String?,
      sourceId: json['sourceId'] as String? ?? '',
      sourceName: json['sourceName'] as String? ?? '',
      latencyMs: json['latencyMs'] as int?,
    );
  }

  @override
  String toString() =>
      'BookSearchResult(title: $title, author: $author, source: $sourceName, latency: ${latencyMs}ms)';
}
