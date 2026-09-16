import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/book_item.dart';

enum ShelfSortMode {
  pinyin('拼音排序', '按书名 A-Z 拼音智能重排'),
  lastRead('最近阅读', '按最近阅读时间排序'),
  progress('阅读进度', '按已读百分比降序');

  final String label;
  final String description;
  const ShelfSortMode(this.label, this.description);
}

class ShelfState {
  final List<BookItem> books;
  final String searchQuery;
  final bool isGridView;
  final ShelfSortMode sortMode;
  final int todayReadingMinutes;

  const ShelfState({
    required this.books,
    this.searchQuery = '',
    this.isGridView = false,
    this.sortMode = ShelfSortMode.pinyin,
    this.todayReadingMinutes = 54,
  });

  int get totalBooksCount => books.length;

  int get averageProgressPercent {
    if (books.isEmpty) return 0;
    final total = books.fold<double>(0.0, (sum, b) => sum + b.progress);
    return ((total / books.length) * 100).clamp(0, 100).toInt();
  }

  /// 今日主推或最近阅读的书籍
  BookItem? get featuredBook {
    if (books.isEmpty) return null;
    final sorted = List<BookItem>.from(books)
      ..sort((a, b) => b.lastReadTime.compareTo(a.lastReadTime));
    return sorted.first;
  }

  /// 经过实时过滤与智能排序的书架列表
  List<BookItem> get filteredBooks {
    var result = List<BookItem>.from(books);

    // 1. 实时搜索过滤
    final query = searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      result = result.where((b) {
        final titleMatch = b.cleanTitle.toLowerCase().contains(query);
        final authorMatch = b.author.toLowerCase().contains(query);
        final pinyinMatch = b.pinyinKey.contains(query);
        return titleMatch || authorMatch || pinyinMatch;
      }).toList();
    }

    // 2. 智能排序
    result.sort((a, b) {
      // 置顶优先级最高
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }

      switch (sortMode) {
        case ShelfSortMode.pinyin:
          return a.pinyinKey.compareTo(b.pinyinKey);
        case ShelfSortMode.lastRead:
          return b.lastReadTime.compareTo(a.lastReadTime);
        case ShelfSortMode.progress:
          return b.progress.compareTo(a.progress);
      }
    });

    return result;
  }

  ShelfState copyWith({
    List<BookItem>? books,
    String? searchQuery,
    bool? isGridView,
    ShelfSortMode? sortMode,
    int? todayReadingMinutes,
  }) {
    return ShelfState(
      books: books ?? this.books,
      searchQuery: searchQuery ?? this.searchQuery,
      isGridView: isGridView ?? this.isGridView,
      sortMode: sortMode ?? this.sortMode,
      todayReadingMinutes: todayReadingMinutes ?? this.todayReadingMinutes,
    );
  }
}

class ShelfNotifier extends StateNotifier<ShelfState> {
  ShelfNotifier() : super(ShelfNotifier._createInitialState());

  static ShelfState _createInitialState() {
    final now = DateTime.now();
    final defaultBooks = [
      BookItem(
        id: 'guimi_zhi_zhu',
        title: '《诡秘之主》',
        author: '爱潜水的乌贼',
        latestChapter: '第 980 章 愚者归来',
        totalChapters: 1432,
        currentChapterIndex: 973,
        currentCharOffset: 120,
        progress: 0.68,
        lastReadTime: now.subtract(const Duration(minutes: 15)),
        category: '玄幻',
        sourceName: '笔趣阁CP',
        description: '起于微末，蒸汽与神秘的宏大史诗，跨越星界的隐秘狂想。',
        isPinned: true,
      ),
      BookItem(
        id: 'daogui_yixian',
        title: '《道诡异仙》',
        author: '狐尾的笔',
        latestChapter: '第 866 章 大千录',
        totalChapters: 1056,
        currentChapterIndex: 865,
        currentCharOffset: 450,
        progress: 0.82,
        lastReadTime: now.subtract(const Duration(hours: 2)),
        category: '悬疑',
        sourceName: '笔趣阁CP',
        description: '诡异与天道交织，真假难辨的非凡民俗修真克苏鲁。',
      ),
      BookItem(
        id: 'chixin_xuntian',
        title: '《赤心巡天》',
        author: '情何以甚',
        latestChapter: '第 968 章 诸生见我',
        totalChapters: 2150,
        currentChapterIndex: 967,
        currentCharOffset: 80,
        progress: 0.45,
        lastReadTime: now.subtract(const Duration(hours: 5)),
        category: '仙侠',
        sourceName: '笔趣阁ZWX',
        description: '山河壮阔，赤子之心巡视诸天，家国天下豪情万丈。',
      ),
      BookItem(
        id: 'suming_zhi_huan',
        title: '《宿命之环》',
        author: '爱潜水的乌贼',
        latestChapter: '第 312 章 光暗交界',
        totalChapters: 890,
        currentChapterIndex: 311,
        currentCharOffset: 200,
        progress: 0.35,
        lastReadTime: now.subtract(const Duration(days: 1)),
        category: '玄幻',
        sourceName: '思兔阅读',
        description: '诡秘世界第二部，特里尔的地下深渊与宿命齿轮。',
      ),
      BookItem(
        id: 'shenkong_bian',
        title: '《深空彼岸》',
        author: '辰东',
        latestChapter: '第 1200 章 飞升绝巅',
        totalChapters: 1320,
        currentChapterIndex: 1199,
        currentCharOffset: 60,
        progress: 0.91,
        lastReadTime: now.subtract(const Duration(days: 2)),
        category: '科幻',
        sourceName: '笔趣阁CP',
        description: '浩瀚星空下旧术与新术碰撞，探索生命超脱的彼岸。',
      ),
      BookItem(
        id: 'lingjing_xingzhe',
        title: '《灵境行者》',
        author: '卖报小郎君',
        latestChapter: '第 184 章 兵者重聚',
        totalChapters: 920,
        currentChapterIndex: 183,
        currentCharOffset: 320,
        progress: 0.20,
        lastReadTime: now.subtract(const Duration(days: 3)),
        category: '都市',
        sourceName: '笔趣阁ZWX',
        description: '灵境世界的超凡试炼，幽默解谜与悬疑副本。',
      ),
    ];

    return ShelfState(books: defaultBooks);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void toggleViewMode() {
    state = state.copyWith(isGridView: !state.isGridView);
  }

  void setSortMode(ShelfSortMode mode) {
    state = state.copyWith(sortMode: mode);
  }

  void togglePin(String bookId) {
    final updated = state.books.map((b) {
      if (b.id == bookId) {
        return b.copyWith(isPinned: !b.isPinned);
      }
      return b;
    }).toList();
    state = state.copyWith(books: updated);
  }

  void removeBook(String bookId) {
    final updated = state.books.where((b) => b.id != bookId).toList();
    state = state.copyWith(books: updated);
  }

  void addBook(BookItem book) {
    final exists = state.books.any((b) => b.id == book.id);
    if (exists) {
      final updated = state.books.map((b) => b.id == book.id ? book : b).toList();
      state = state.copyWith(books: updated);
    } else {
      state = state.copyWith(books: [book, ...state.books]);
    }
  }

  void updateProgress({
    required String bookId,
    required int chapterIndex,
    required int charOffset,
    required double progress,
  }) {
    final updated = state.books.map((b) {
      if (b.id == bookId) {
        return b.copyWith(
          currentChapterIndex: chapterIndex,
          currentCharOffset: charOffset,
          progress: progress,
          lastReadTime: DateTime.now(),
        );
      }
      return b;
    }).toList();
    state = state.copyWith(books: updated);
  }

  void clearShelf() {
    state = state.copyWith(books: []);
  }

  void resetToDefaults() {
    state = ShelfNotifier._createInitialState();
  }
}

final shelfProvider = StateNotifierProvider<ShelfNotifier, ShelfState>((ref) {
  return ShelfNotifier();
});
