import '../models/book_search_result.dart';

/// 从搜索结果里挑出最可能是目标书的一条。
///
/// 为什么需要它：书源站的搜索会把同名、名字相近、乃至毫不相干的书一并返回，
/// 而此前各处都是 `orElse: () => results.first` 硬塞第一条——
/// 一旦目标书不在结果里，用户点《三体》就会打开《没钱修什么仙？》。
///
/// 判据按可靠性排序：书名精确 + 作者一致 > 书名精确 > 作者一致 + 书名包含 >
/// 书名包含。**全都对不上时返回 null**，让调用方换个源继续找，
/// 而不是拿一本错的书糊弄过去。
BookSearchResult? pickBestBookMatch(
  List<BookSearchResult> results,
  String cleanTitle, {
  String? author,
}) {
  if (results.isEmpty) return null;
  final wantAuthor = (author ?? '').trim();

  for (final r in results) {
    if (r.title == cleanTitle &&
        (wantAuthor.isEmpty || r.author.trim() == wantAuthor)) {
      return r;
    }
  }
  for (final r in results) {
    if (r.title == cleanTitle) return r;
  }
  if (wantAuthor.isNotEmpty) {
    for (final r in results) {
      if (r.author.trim() == wantAuthor && r.title.contains(cleanTitle)) {
        return r;
      }
    }
  }
  for (final r in results) {
    if (r.title.contains(cleanTitle)) return r;
  }
  return null;
}
