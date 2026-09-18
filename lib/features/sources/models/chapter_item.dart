/// 章节目录项数据模型 (chapter_item.dart)
class ChapterItem {
  final int index;
  final String title;
  final String url;
  final bool isCached;

  const ChapterItem({
    required this.index,
    required this.title,
    required this.url,
    this.isCached = false,
  });

  ChapterItem copyWith({
    int? index,
    String? title,
    String? url,
    bool? isCached,
  }) {
    return ChapterItem(
      index: index ?? this.index,
      title: title ?? this.title,
      url: url ?? this.url,
      isCached: isCached ?? this.isCached,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'index': index,
      'title': title,
      'url': url,
      'isCached': isCached,
    };
  }

  factory ChapterItem.fromJson(Map<String, dynamic> json) {
    return ChapterItem(
      index: json['index'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      url: json['url'] as String? ?? '',
      isCached: json['isCached'] as bool? ?? false,
    );
  }

  @override
  String toString() =>
      'ChapterItem(index: $index, title: $title, cached: $isCached)';
}
