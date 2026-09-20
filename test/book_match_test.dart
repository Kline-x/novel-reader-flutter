import 'package:flutter_test/flutter_test.dart';
import 'package:novel_reader_flutter/features/sources/models/book_search_result.dart';
import 'package:novel_reader_flutter/features/sources/services/book_match.dart';

BookSearchResult r(String title, String author, {String url = 'u', String src = 's'}) =>
    BookSearchResult(
      id: '$title-$author',
      title: title,
      author: author,
      bookUrl: url,
      sourceId: src,
      sourceName: src,
    );

void main() {
  group('搜索结果匹配：宁可空手而归，也不能串书', () {
    test('书名与作者都对上时优先选中', () {
      final results = [
        r('三体前传：球状闪电', '刘慈欣'),
        r('三体', '刘慈欣', url: 'right'),
        r('三体', '某仿写作者', url: 'wrong'),
      ];
      final m = pickBestBookMatch(results, '三体', author: '刘慈欣');
      expect(m?.bookUrl, 'right');
    });

    test('作者对不上但书名精确时仍可接受', () {
      final results = [r('三体', '佚名', url: 'only')];
      final m = pickBestBookMatch(results, '三体', author: '刘慈欣');
      expect(m?.bookUrl, 'only');
    });

    test('一条都对不上时返回 null，不得硬塞第一条', () {
      // 这正是真机上「点《三体》打开《没钱修什么仙？》」的场景
      final results = [
        r('没钱修什么仙？', '熊狼狗'),
        r('都重生了谁考公务员啊', '柳岸花又明'),
      ];
      final m = pickBestBookMatch(results, '三体', author: '刘慈欣');
      expect(m, isNull,
          reason: '返回 null 才能让调用方换个源继续找，而不是打开一本错的书');
    });

    test('空结果返回 null', () {
      expect(pickBestBookMatch([], '三体', author: '刘慈欣'), isNull);
    });

    test('作者一致且书名包含时可作为次级匹配', () {
      final results = [
        r('斗破苍穹（精校版）', '天蚕土豆', url: 'ok'),
        r('斗罗大陆', '唐家三少'),
      ];
      final m = pickBestBookMatch(results, '斗破苍穹', author: '天蚕土豆');
      expect(m?.bookUrl, 'ok');
    });

    test('不传作者时退化为按书名匹配', () {
      final results = [r('剑来', '烽火戏诸侯', url: 'ok')];
      expect(pickBestBookMatch(results, '剑来')?.bookUrl, 'ok');
      expect(pickBestBookMatch(results, '不存在的书'), isNull);
    });
  });
}
