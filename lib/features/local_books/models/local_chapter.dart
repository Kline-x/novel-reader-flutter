/// 本地书籍章节索引数据模型 (local_chapter.dart)
/// 支持大文件流式字节偏移 (TXT) 与解包路径 (EPUB)
class LocalChapter {
  final int index;
  final String title;
  final int byteOffset; // 文件内起始字节位置 (用于 RandomAccessFile 毫秒定位)
  final int byteLength; // 该章字节长度 (用于局部流式读取)
  final String? contentHref; // EPUB 内相对路径 (例如 OEBPS/Text/ch01.xhtml)

  const LocalChapter({
    required this.index,
    required this.title,
    this.byteOffset = 0,
    this.byteLength = 0,
    this.contentHref,
  });

  Map<String, dynamic> toJson() => {
        'index': index,
        'title': title,
        'byteOffset': byteOffset,
        'byteLength': byteLength,
        if (contentHref != null) 'contentHref': contentHref,
      };

  factory LocalChapter.fromJson(Map<String, dynamic> json) => LocalChapter(
        index: json['index'] as int? ?? 0,
        title: json['title'] as String? ?? '',
        byteOffset: json['byteOffset'] as int? ?? 0,
        byteLength: json['byteLength'] as int? ?? 0,
        contentHref: json['contentHref'] as String?,
      );
}
