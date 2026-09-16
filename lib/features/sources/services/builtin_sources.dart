import '../models/source_rule.dart';

/// 内置高质量书源合集 (builtin_sources.dart)
/// 严格对齐 12 组实机验证的高可用书源生态，涵盖 UTF-8 与 GBK/GB2312 编码架构。
class BuiltinSources {
  static const List<SourceRule> all = [
    // 1. 笔趣阁CP (UTF-8)
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

    // 2. 笔趣阁ZWX (UTF-8)
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

    // 3. 思兔阅读 (UTF-8)
    SourceRule(
      id: 'sto66:思兔阅读',
      name: '思兔阅读',
      baseUrl: 'https://www.sto66.com',
      charset: 'utf-8',
      search: SearchRule(
        urlTemplate: 'https://www.sto66.com/search/{key}.html',
        item: 'div.bookbox',
        title: RuleSelector(selector: 'h2 a', attr: 'text'),
        author: RuleSelector(selector: 'div.author', attr: 'text', regex: r'^作者：'),
        detailUrl: RuleSelector(selector: 'h2 a', attr: 'href'),
        coverUrl: RuleSelector(selector: 'img.thumbnail', attr: 'src'),
      ),
      detail: DetailRule(
        title: RuleSelector(selector: 'h1', attr: 'text'),
        author: RuleSelector(selector: 'p.booktag a.red', attr: 'text'),
        tocUrl: RuleSelector(selector: '#allchapter dl dd:last-child a', attr: 'href'),
      ),
      toc: TocRule(
        item: '#allchapter a',
        title: RuleSelector(selector: '', attr: 'text'),
        url: RuleSelector(selector: '', attr: 'href'),
      ),
      chapter: ChapterRule(
        content: RuleSelector(selector: '#content.readcontent', attr: 'html'),
      ),
    ),

    // 4. 天天看小说 (UTF-8)
    SourceRule(
      id: 'ttkan:天天看小说',
      name: '天天看小说',
      baseUrl: 'https://cn.ttkan.co',
      charset: 'utf-8',
      search: SearchRule(
        urlTemplate: 'https://www.ttkan.co/novel/search?language=cn&q={key}',
        item: 'div.novel_cell',
        title: RuleSelector(selector: 'h3', attr: 'text'),
        author: RuleSelector(selector: '.novel_author', attr: 'text'),
        detailUrl: RuleSelector(selector: 'a', attr: 'href'),
        coverUrl: RuleSelector(selector: 'img', attr: 'src'),
      ),
      toc: TocRule(
        item: '.full_chapters a',
        title: RuleSelector(selector: '', attr: 'text'),
        url: RuleSelector(selector: '', attr: 'href'),
      ),
      chapter: ChapterRule(
        content: RuleSelector(selector: '.content', attr: 'html'),
      ),
    ),

    // 5. 夜天连看 (UTF-8)
    SourceRule(
      id: 'yetianlian:夜天连看',
      name: '夜天连看',
      baseUrl: 'http://www.yetianlian.info',
      charset: 'utf-8',
      search: SearchRule(
        urlTemplate: 'http://www.yetianlian.info/s.php?ie=utf-8&q={key}',
        item: '.bookbox',
        title: RuleSelector(selector: '.bookname', attr: 'text'),
        author: RuleSelector(selector: '.author', attr: 'text', regex: r'^作者：'),
        detailUrl: RuleSelector(selector: 'a', attr: 'href'),
        coverUrl: RuleSelector(selector: 'img', attr: 'src'),
      ),
      toc: TocRule(
        item: '.listmain dl dt:nth-of-type(2) ~ dd a',
        title: RuleSelector(selector: '', attr: 'text'),
        url: RuleSelector(selector: '', attr: 'href'),
      ),
      chapter: ChapterRule(
        content: RuleSelector(
          selector: '#content',
          attr: 'html',
          regex: r'请记住本书首发域名[\s\S]*|http[^\s]*yetianlian[^\s]*|天才一秒记住[\s\S]*',
        ),
      ),
    ),

    // 6. 穿越小说 (GBK 编码)
    SourceRule(
      id: 'kk169:穿越小说',
      name: '穿越小说',
      baseUrl: 'http://www.kk169.net',
      charset: 'gbk',
      search: SearchRule(
        urlTemplate: 'http://www.kk169.net/modules/article/search.php?q={key}',
        item: 'div.c_row',
        title: RuleSelector(selector: '.c_subject a', attr: 'text'),
        author: RuleSelector(selector: '.c_author a', attr: 'text'),
        detailUrl: RuleSelector(selector: '.c_subject a', attr: 'href'),
        coverUrl: RuleSelector(selector: 'img', attr: 'src'),
      ),
      toc: TocRule(
        item: 'li.chapter a',
        title: RuleSelector(selector: '', attr: 'text'),
        url: RuleSelector(selector: '', attr: 'href'),
      ),
      chapter: ChapterRule(
        content: RuleSelector(
          selector: '#acontent',
          attr: 'html',
          regex: r'^[\s\S]*?\(穿越小说 www\.kk169\.la\)|穿越小说 www\.kk169\.la[\s\S]*$',
        ),
      ),
    ),

    // 7. 笔趣阁7 (UTF-8)
    SourceRule(
      id: 'biquge7:笔趣阁7',
      name: '笔趣阁7',
      baseUrl: 'https://www.biquge7.xyz',
      charset: 'utf-8',
      search: SearchRule(
        urlTemplate: 'https://www.biquge7.xyz/search?keyword={key}',
        item: '.tui_1_item',
        title: RuleSelector(selector: '.title a', attr: 'text'),
        author: RuleSelector(selector: '.author', attr: 'text'),
        detailUrl: RuleSelector(selector: '.title a', attr: 'href'),
        coverUrl: RuleSelector(selector: 'img', attr: 'src'),
      ),
      toc: TocRule(
        item: '.list ul li a',
        title: RuleSelector(selector: '', attr: 'text'),
        url: RuleSelector(selector: '', attr: 'href'),
      ),
      chapter: ChapterRule(
        content: RuleSelector(selector: '.text', attr: 'html'),
      ),
    ),

    // 8. 去读书 (GBK 编码)
    SourceRule(
      id: 'qudushu:去读书',
      name: '去读书',
      baseUrl: 'http://www.qudushu.org',
      charset: 'gbk',
      search: SearchRule(
        urlTemplate: 'http://www.qudushu.org/modules/article/search.php?q={key}',
        item: 'div.c_row',
        title: RuleSelector(selector: '.c_subject a', attr: 'text'),
        author: RuleSelector(selector: '.c_author', attr: 'text'),
        detailUrl: RuleSelector(selector: '.c_subject a', attr: 'href'),
        coverUrl: RuleSelector(selector: 'img', attr: 'src'),
      ),
      toc: TocRule(
        item: 'li.chapter a',
        title: RuleSelector(selector: '', attr: 'text'),
        url: RuleSelector(selector: '', attr: 'href'),
      ),
      chapter: ChapterRule(
        content: RuleSelector(
          selector: '#acontent',
          attr: 'html',
          regex: r'^[\s\S]*?\(去读书[^)]*\)|如果您中途有事离开[\s\S]*',
        ),
      ),
    ),

    // 9. 爱下书小说网 (GBK 编码)
    SourceRule(
      id: 'aixiawx:爱下书小说网',
      name: '爱下书小说网',
      baseUrl: 'http://www.aixiawx.com',
      charset: 'gbk',
      search: SearchRule(
        urlTemplate: 'http://www.aixiawx.com/modules/article/search.php?searchkey={key}',
        item: 'table.grid tr',
        title: RuleSelector(selector: 'a', attr: 'text'),
        author: RuleSelector(selector: 'td:nth-child(3)', attr: 'text'),
        detailUrl: RuleSelector(selector: 'a', attr: 'href'),
        coverUrl: RuleSelector(selector: 'img', attr: 'src'),
      ),
      toc: TocRule(
        item: '#list dd a',
        title: RuleSelector(selector: '', attr: 'text'),
        url: RuleSelector(selector: '', attr: 'href'),
      ),
      chapter: ChapterRule(
        content: RuleSelector(
          selector: '#content',
          attr: 'html',
          regex: r'^最新网址：[^\n]*\n|手机站全新改版升级地址[\s\S]*',
        ),
      ),
    ),

    // 10. 香书小说 (GBK 编码)
    SourceRule(
      id: 'xbiquge:香书小说',
      name: '香书小说',
      baseUrl: 'http://www.xbiquge.la',
      charset: 'gbk',
      enabled: false,
      search: SearchRule(
        urlTemplate: 'http://www.xbiquge.la/modules/article/waps.php?searchkey={key}',
        item: 'table.grid tr',
        title: RuleSelector(selector: 'a', attr: 'text'),
        author: RuleSelector(selector: 'td:nth-child(3)', attr: 'text'),
        detailUrl: RuleSelector(selector: 'a', attr: 'href'),
        coverUrl: RuleSelector(selector: 'img', attr: 'src'),
      ),
      toc: TocRule(
        item: '#list dd a',
        title: RuleSelector(selector: '', attr: 'text'),
        url: RuleSelector(selector: '', attr: 'href'),
      ),
      chapter: ChapterRule(
        content: RuleSelector(selector: '#content', attr: 'html'),
      ),
    ),

    // 11. 猪猪书网 (UTF-8)
    SourceRule(
      id: 'zzs5:猪猪书网',
      name: '猪猪书网',
      baseUrl: 'http://www.zzs5.info',
      charset: 'utf-8',
      enabled: false,
      search: SearchRule(
        urlTemplate: 'http://www.zzs5.info/index.php?m=search&c=index&a=init&typeid=2&siteid=1&q={key}',
        item: '.pages_table tr',
        title: RuleSelector(selector: 'a', attr: 'text'),
        author: RuleSelector(selector: 'td:nth-child(2)', attr: 'text'),
        detailUrl: RuleSelector(selector: 'a', attr: 'href'),
        coverUrl: RuleSelector(selector: 'img', attr: 'src'),
      ),
      toc: TocRule(
        item: '.list dd a',
        title: RuleSelector(selector: '', attr: 'text'),
        url: RuleSelector(selector: '', attr: 'href'),
      ),
      chapter: ChapterRule(
        content: RuleSelector(selector: '.content .content', attr: 'html'),
      ),
    ),

    // 12. 鬼吹灯书屋 (UTF-8)
    SourceRule(
      id: 'gdbzkz:鬼吹灯书屋',
      name: '鬼吹灯书屋',
      baseUrl: 'http://www.gdbzkz.org',
      charset: 'utf-8',
      search: SearchRule(
        urlTemplate: 'http://www.gdbzkz.org/s.php?ie=utf-8&q={key}',
        item: 'div.bookbox',
        title: RuleSelector(selector: '.bookname', attr: 'text'),
        author: RuleSelector(selector: '.author', attr: 'text', regex: r'^作者：'),
        detailUrl: RuleSelector(selector: 'a', attr: 'href'),
        coverUrl: RuleSelector(selector: 'img', attr: 'src'),
      ),
      toc: TocRule(
        item: '.listmain dl dt:nth-of-type(2) ~ dd a',
        title: RuleSelector(selector: '', attr: 'text'),
        url: RuleSelector(selector: '', attr: 'href'),
      ),
      chapter: ChapterRule(
        content: RuleSelector(
          selector: '#content',
          attr: 'html',
          regex: r'请记住本书首发域名[\s\S]*|天才一秒记住[\s\S]*|https?://[^\s]*gdbzkz[^\s]*',
        ),
      ),
    ),
  ];

  static SourceRule? findByName(String name) {
    try {
      return all.firstWhere((s) => s.name == name);
    } catch (_) {
      return null;
    }
  }
}
