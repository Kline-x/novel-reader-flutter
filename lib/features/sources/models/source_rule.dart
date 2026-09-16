// 书源规则数据模型 (source_rule.dart)
// 兼容 Legado (开源阅读) 3.0 规范，统一跨平台抓取逻辑
library;

class RuleSelector {
  final String selector;
  final String? attr;
  final String? regex;
  final bool multiple;

  const RuleSelector({
    required this.selector,
    this.attr,
    this.regex,
    this.multiple = false,
  });

  factory RuleSelector.fromString(String raw) {
    if (raw.contains('@')) {
      final parts = raw.split('@');
      final sel = parts[0];
      final attrOrType = parts.length > 1 ? parts[1] : null;
      return RuleSelector(selector: sel, attr: attrOrType);
    }
    return RuleSelector(selector: raw);
  }
}

class SearchRule {
  final String urlTemplate;
  final String item;
  final RuleSelector title;
  final RuleSelector author;
  final RuleSelector detailUrl;
  final RuleSelector? latestChapter;
  final RuleSelector? coverUrl;

  const SearchRule({
    required this.urlTemplate,
    required this.item,
    required this.title,
    required this.author,
    required this.detailUrl,
    this.latestChapter,
    this.coverUrl,
  });
}

class DetailRule {
  final RuleSelector title;
  final RuleSelector author;
  final RuleSelector? description;
  final RuleSelector? tocUrl;
  final RuleSelector? coverUrl;

  const DetailRule({
    required this.title,
    required this.author,
    this.description,
    this.tocUrl,
    this.coverUrl,
  });
}

class TocRule {
  final String item;
  final RuleSelector title;
  final RuleSelector url;

  const TocRule({
    required this.item,
    required this.title,
    required this.url,
  });
}

class ChapterRule {
  final RuleSelector? title;
  final RuleSelector content;

  const ChapterRule({
    this.title,
    required this.content,
  });
}

class SourceRule {
  final String id;
  final String name;
  final String baseUrl;
  final bool enabled;
  final String group;
  final int version;
  final String charset; // 'utf-8' | 'gbk' | 'gb2312'
  final SearchRule search;
  final DetailRule? detail;
  final TocRule toc;
  final ChapterRule chapter;

  const SourceRule({
    required this.id,
    required this.name,
    required this.baseUrl,
    this.enabled = true,
    this.group = '静态源',
    this.version = 1,
    this.charset = 'utf-8',
    required this.search,
    this.detail,
    required this.toc,
    required this.chapter,
  });
}
