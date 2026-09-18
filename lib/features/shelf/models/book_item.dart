import 'package:lpinyin/lpinyin.dart';

/// 书籍核心数据模型 (book_item.dart)
class BookItem {
  final String id;
  final String title;
  final String author;
  final String? coverUrl;
  final String latestChapter;
  final int totalChapters;
  final int currentChapterIndex;
  final int currentCharOffset;
  final double progress; // 0.0 ~ 1.0
  final DateTime lastReadTime;
  final String category; // '玄幻', '仙侠', '科幻', '都市', '悬疑'
  final String sourceName; // '笔趣阁CP', etc.
  final String description;
  final bool isPinned;
  final String? sourceId;
  final String? filePath;
  final String? bookUrl;
  /// 读者评分。书源并不提供该数据，默认为 null；
  /// 此前默认写死 9.6，导致每一本书的详情页都显示"★ 9.6"。
  final double? rating;
  final String status;
  final String? wordCount;

  BookItem({
    required this.id,
    required this.title,
    required this.author,
    this.coverUrl,
    String? latestChapter,
    String? lastChapter,
    this.totalChapters = 100,
    this.currentChapterIndex = 0,
    int? currentCharOffset,
    int? charOffset,
    this.progress = 0.0,
    DateTime? lastReadTime,
    this.category = '玄幻',
    this.sourceName = '笔趣阁CP',
    this.description = '',
    this.isPinned = false,
    this.sourceId,
    this.filePath,
    this.bookUrl,
    this.rating,
    this.status = '连载中',
    this.wordCount,
  })  : latestChapter = latestChapter ?? lastChapter ?? '第一章',
        currentCharOffset = charOffset ?? currentCharOffset ?? 0,
        lastReadTime = lastReadTime ?? DateTime.now();

  bool get isLocal => sourceId?.startsWith('local') == true || filePath != null;
  bool get isEpub =>
      sourceId == 'local_epub' ||
      (filePath?.toLowerCase().endsWith('.epub') ?? false);
  String get pinyin => pinyinKey;
  String get lastChapter => latestChapter;
  int get charOffset => currentCharOffset;

  /// 过滤标点符号的书名用于拼音计算
  String get cleanTitle {
    return title.replaceAll(RegExp(r'[《》【】\[\]()（）\s]'), '');
  }

  /// 拼音全拼用于多音字/首字母精准排序
  String get pinyinKey {
    final cleaned = cleanTitle;
    if (cleaned.isEmpty) return '#';
    try {
      return PinyinHelper.getPinyinE(
        cleaned,
        separator: '',
        defPinyin: '#',
        format: PinyinFormat.WITHOUT_TONE,
      ).toLowerCase();
    } catch (_) {
      return cleaned.toLowerCase();
    }
  }

  /// 拼音首字母大写
  String get pinyinInitial {
    final key = pinyinKey;
    if (key.isEmpty) return '#';
    final firstChar = key[0].toUpperCase();
    if (RegExp(r'[A-Z]').hasMatch(firstChar)) {
      return firstChar;
    }
    return '#';
  }

  /// 阅读进度百分比格式化
  String get progressPercentageText {
    final percent = (progress * 100).clamp(0, 100).toInt();
    return '$percent%';
  }

  /// 章节进度描述
  String get progressDescription {
    if (currentChapterIndex == 0 && progress == 0.0) {
      return '未读 · 共 $totalChapters 章';
    }
    return '已读至第 ${currentChapterIndex + 1} 章 ($progressPercentageText)';
  }

  BookItem copyWith({
    String? id,
    String? title,
    String? author,
    String? coverUrl,
    String? latestChapter,
    int? totalChapters,
    int? currentChapterIndex,
    int? currentCharOffset,
    double? progress,
    DateTime? lastReadTime,
    String? category,
    String? sourceName,
    String? description,
    bool? isPinned,
    String? sourceId,
    String? filePath,
    String? bookUrl,
    double? rating,
    String? status,
    String? wordCount,
  }) {
    return BookItem(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      coverUrl: coverUrl ?? this.coverUrl,
      latestChapter: latestChapter ?? this.latestChapter,
      totalChapters: totalChapters ?? this.totalChapters,
      currentChapterIndex: currentChapterIndex ?? this.currentChapterIndex,
      currentCharOffset: currentCharOffset ?? this.currentCharOffset,
      progress: progress ?? this.progress,
      lastReadTime: lastReadTime ?? this.lastReadTime,
      category: category ?? this.category,
      sourceName: sourceName ?? this.sourceName,
      description: description ?? this.description,
      isPinned: isPinned ?? this.isPinned,
      sourceId: sourceId ?? this.sourceId,
      filePath: filePath ?? this.filePath,
      bookUrl: bookUrl ?? this.bookUrl,
      rating: rating ?? this.rating,
      status: status ?? this.status,
      wordCount: wordCount ?? this.wordCount,
    );
  }
}
