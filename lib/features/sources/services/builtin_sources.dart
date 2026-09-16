import '../models/source_rule.dart';

/// 内置高质量书源合集 (builtin_sources.dart)
/// 严格对齐 novel-reader 中经过 7 轮实机验证的高可用源

class BuiltinSources {
  static const List<SourceRule> all = [
    // 1. 笔趣阁CP
    SourceRule(
      id: 'biqugecompany:笔趣阁CP',
      name: '笔趣阁CP',
      baseUrl: 'https://www.biquge.company',
      charset: 'utf-8',
      search: SearchRule(
        urlTemplate: 'https://www.biquge.company/modules/article/search.php?searchkey={key}',
        item: 'div.bookbox',
        title: RuleSelector(selector: 'h4.bookname a', attr: 'text'),
        author: RuleSelector(selector: 'div.author', attr: 'text', regex: r'^作者：'),
        detailUrl: RuleSelector(selector: 'h4.bookname a', attr: 'href'),
        coverUrl: RuleSelector(selector: 'img', attr: 'src'),
      ),
      toc: TocRule(
        item: '#list-chapterAll a',
        title: RuleSelector(selector: '', attr: 'text'),
        url: RuleSelector(selector: '', attr: 'href'),
      ),
      chapter: ChapterRule(
        content: RuleSelector(selector: '.readcontent', attr: 'html'),
      ),
    ),

    // 2. 笔趣阁ZWX
    SourceRule(
      id: 'biqugezwx:笔趣阁ZWX',
      name: '笔趣阁ZWX',
      baseUrl: 'https://www.biqugezwx.com',
      charset: 'utf-8',
      search: SearchRule(
        urlTemplate: 'https://www.biqugezwx.com/modules/article/search.php?searchkey={key}',
        item: 'div.item',
        title: RuleSelector(selector: 'h1 a', attr: 'text'),
        author: RuleSelector(selector: 'a[href*=authorarticle]', attr: 'text', regex: r'^作者：'),
        detailUrl: RuleSelector(selector: 'h1 a', attr: 'href'),
        coverUrl: RuleSelector(selector: 'img', attr: 'src'),
      ),
      toc: TocRule(
        item: '#list a',
        title: RuleSelector(selector: '', attr: 'text'),
        url: RuleSelector(selector: '', attr: 'href'),
      ),
      chapter: ChapterRule(
        content: RuleSelector(selector: '.con', attr: 'html'),
      ),
    ),

    // 3. 思兔阅读
    SourceRule(
      id: 'sto520:思兔阅读',
      name: '思兔阅读',
      baseUrl: 'https://www.sto520.com',
      charset: 'utf-8',
      search: SearchRule(
        urlTemplate: 'https://www.sto520.com/modules/article/search.php?searchkey={key}',
        item: 'div.bookbox',
        title: RuleSelector(selector: 'h4.bookname a', attr: 'text'),
        author: RuleSelector(selector: 'div.author', attr: 'text', regex: r'^作者：'),
        detailUrl: RuleSelector(selector: 'h4.bookname a', attr: 'href'),
        coverUrl: RuleSelector(selector: 'img', attr: 'src'),
      ),
      toc: TocRule(
        item: '#list-chapterAll a',
        title: RuleSelector(selector: '', attr: 'text'),
        url: RuleSelector(selector: '', attr: 'href'),
      ),
      chapter: ChapterRule(
        content: RuleSelector(selector: '#content', attr: 'html'),
      ),
    ),
  ];
}
