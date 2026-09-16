import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/components/soft_card.dart';
import '../../../core/theme/soft_theme.dart';
import '../../local_books/presentation/wifi_transfer_dialog.dart';
import '../../local_books/services/local_book_service.dart';
import '../../reader/data/storage_service.dart';
import '../../reader/presentation/reader_screen.dart';
import '../models/book_item.dart';

/// 书架页面 (shelf_page.dart)
/// 呈现 Modern Soft UI Bento 看板、拼音智能排序、实时过滤与书籍流/网格
class ShelfPage extends StatefulWidget {
  final VoidCallback onNavigateToDiscovery;

  const ShelfPage({super.key, required this.onNavigateToDiscovery});

  @override
  State<ShelfPage> createState() => _ShelfPageState();
}

class _ShelfPageState extends State<ShelfPage> {
  final TextEditingController _searchController = TextEditingController();
  bool _isGridView = false;
  String _searchKeyword = '';

  final List<BookItem> _books = [
    BookItem(
      id: 'guimi_01',
      title: '诡秘之主',
      author: '爱潜水的乌贼',
      coverUrl: '',
      lastChapter: '第 120 章 绯红之月下的聚会',
      progress: 0.42,
      charOffset: 220,
    ),
    BookItem(
      id: 'shiri_02',
      title: '十日终焉',
      author: '杀虫队队员',
      coverUrl: '',
      lastChapter: '第 89 章 最后的生肖游戏',
      progress: 0.18,
      charOffset: 0,
    ),
    BookItem(
      id: 'daoti_03',
      title: '道诡异仙',
      author: '狐尾的笔',
      coverUrl: '',
      lastChapter: '第 230 章 迷惘的幻觉',
      progress: 0.65,
      charOffset: 450,
    ),
    BookItem(
      id: 'jianlai_04',
      title: '剑来',
      author: '烽火戏诸侯',
      coverUrl: '',
      lastChapter: '第 95 章 少年提剑下山行',
      progress: 0.12,
      charOffset: 0,
    ),
  ];

  final StorageService _storageService = StorageService();
  Map<String, int> _cachedCountMap = {};
  StreamSubscription<ShelfBook>? _localBookSub;

  @override
  void initState() {
    super.initState();
    _loadBooksFromStorage();
    _localBookSub = LocalBookService().bookImportedStream.listen((_) {
      _loadBooksFromStorage();
    });
  }

  @override
  void dispose() {
    _localBookSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBooksFromStorage() async {
    final saved = await _storageService.getBookshelf();
    bool changed = false;
    for (final s in saved) {
      if (!_books.any((b) => b.id == s.bookId)) {
        _books.insert(0, BookItem(
          id: s.bookId,
          title: s.title,
          author: s.author,
          coverUrl: s.coverUrl ?? '',
          lastChapter: s.lastChapterTitle ?? '第一章',
          progress: 0.0,
          charOffset: s.currentCharOffset,
          sourceId: s.sourceId,
          filePath: s.filePath,
        ));
        changed = true;
      }
    }
    if (changed && mounted) {
      setState(() {});
    }
    await _refreshAllCachedCounts();
  }

  Future<void> _refreshAllCachedCounts() async {
    final counts = <String, int>{};
    for (final b in _books) {
      counts[b.id] = await _storageService.getDownloadedChaptersCount(b.id);
    }
    if (mounted) {
      setState(() {
        _cachedCountMap = counts;
      });
    }
  }

  Future<void> _openReader(BookItem book) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReaderScreen(
          bookId: book.id,
          bookTitle: book.title,
          author: book.author,
          initialCharOffset: book.charOffset,
          book: book,
        ),
      ),
    );
    _loadBooksFromStorage();
  }

  @override
  Widget build(BuildContext context) {
    final colors = SoftTheme.of(context);

    // 过滤与拼音排序
    var filteredBooks = _books.where((b) {
      if (_searchKeyword.isEmpty) return true;
      return b.title.contains(_searchKeyword) || b.author.contains(_searchKeyword);
    }).toList();

    filteredBooks.sort((a, b) => a.pinyin.compareTo(b.pinyin));

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // 1. 顶部标题与检索栏
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 12.0),
                child: Row(
                  children: [
                    Text(
                      '藏书阁',
                      style: TextStyle(
                        fontSize: 26.0,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Spacer(),
                    // WiFi 传书入口按钮
                    GestureDetector(
                      key: const ValueKey('shelf_wifi_transfer_btn'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => WifiTransferDialog.show(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 7.0),
                        decoration: BoxDecoration(
                          color: colors.card,
                          borderRadius: BorderRadius.circular(12.0),
                          boxShadow: SoftDecorations.softShadows(colors, elevation: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.wifi_tethering_rounded,
                              color: colors.accent,
                              size: 16.0,
                            ),
                            const SizedBox(width: 4.0),
                            Text(
                              'WiFi传书',
                              style: TextStyle(
                                fontSize: 12.0,
                                fontWeight: FontWeight.bold,
                                color: colors.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10.0),
                    // 视图模式切换按钮
                    GestureDetector(
                      key: const ValueKey('shelf_view_toggle'),
                      onTap: () => setState(() => _isGridView = !_isGridView),
                      child: Container(
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: colors.card,
                          borderRadius: BorderRadius.circular(12.0),
                          boxShadow: SoftDecorations.softShadows(colors, elevation: 0.8),
                        ),
                        child: Icon(
                          _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
                          color: colors.textSecondary,
                          size: 20.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 2. Bento 个人数据看板
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
                child: _buildBentoDashboard(colors),
              ),
            ),

            // 3. 搜索过滤栏
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                child: Container(
                  height: 44.0,
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(16.0),
                    boxShadow: SoftDecorations.insetShadows(colors),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14.0),
                  child: Row(
                    children: [
                      Icon(Icons.search, size: 18.0, color: colors.textSecondary),
                      const SizedBox(width: 8.0),
                      Expanded(
                        child: TextField(
                          key: const ValueKey('shelf_search_input'),
                          controller: _searchController,
                          style: TextStyle(fontSize: 14.0, color: colors.textPrimary),
                          decoration: InputDecoration(
                            hintText: '搜索书架上的作品或作者...',
                            hintStyle: TextStyle(fontSize: 13.0, color: colors.textSecondary),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (val) => setState(() => _searchKeyword = val.trim()),
                        ),
                      ),
                      if (_searchKeyword.isNotEmpty)
                        GestureDetector(
                          key: const ValueKey('shelf_search_clear'),
                          onTap: () {
                            _searchController.clear();
                            setState(() => _searchKeyword = '');
                          },
                          child: Icon(Icons.clear, size: 16.0, color: colors.textSecondary),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // 4. 书架内容流
            if (filteredBooks.isEmpty)
              SliverToBoxAdapter(child: _buildEmptyState(colors))
            else if (_isGridView)
              _buildGridView(filteredBooks, colors)
            else
              _buildListView(filteredBooks, colors),

            // 底部安全留白（避让浮动 Dock）
            const SliverToBoxAdapter(
              child: SizedBox(height: 100.0),
            ),
          ],
        ),
      ),
    );
  }

  /// Bento 现代轻拟态仪表盘
  Widget _buildBentoDashboard(SoftColors colors) {
    return Row(
      children: [
        // 今日阅读时长
        Expanded(
          flex: 4,
          child: SoftCard(
            colors: colors,
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('⏱️', style: TextStyle(fontSize: 14.0)),
                    const SizedBox(width: 6.0),
                    Text(
                      '今日阅读',
                      style: TextStyle(fontSize: 12.0, color: colors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 8.0),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '48',
                        style: TextStyle(
                          fontSize: 26.0,
                          fontWeight: FontWeight.w800,
                          color: colors.accent,
                        ),
                      ),
                      TextSpan(
                        text: ' 分钟',
                        style: TextStyle(fontSize: 12.0, color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12.0),
        // 在读本数
        Expanded(
          flex: 3,
          child: SoftCard(
            colors: colors,
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('📚', style: TextStyle(fontSize: 14.0)),
                    const SizedBox(width: 6.0),
                    Text(
                      '在读藏书',
                      style: TextStyle(fontSize: 12.0, color: colors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 8.0),
                Text(
                  '${_books.length} 本',
                  style: TextStyle(
                    fontSize: 22.0,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 列表视图
  Widget _buildListView(List<BookItem> books, SoftColors colors) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 110.0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final book = books[index];
            final seal = book.title.startsWith('十') && book.title.length > 1
                ? book.title.characters.take(2).string
                : book.title.characters.first;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: SoftCard(
                colors: colors,
                onTap: () => _openReader(book),
                padding: const EdgeInsets.all(14.0),
                child: Row(
                  children: [
                    // 封面占位 Squircle (双字古典印章风)
                    Container(
                      width: 52.0,
                      height: 72.0,
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(
                          color: colors.accent.withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                        boxShadow: SoftDecorations.softShadows(colors, elevation: 0.6),
                      ),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Text(
                        seal,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: seal.length > 1 ? 14.0 : 18.0,
                          fontWeight: FontWeight.w800,
                          letterSpacing: seal.length > 1 ? 1.0 : 0.0,
                          color: colors.accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14.0),
                    // 书籍元信息
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                book.title,
                                style: TextStyle(
                                  fontSize: 16.0,
                                  fontWeight: FontWeight.w700,
                                  color: colors.textPrimary,
                                ),
                              ),
                              if (book.isLocal) ...[
                                const SizedBox(width: 8.0),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: colors.accent.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4.0),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        book.isEpub ? Icons.menu_book_rounded : Icons.description_rounded,
                                        size: 10.0,
                                        color: colors.accent,
                                      ),
                                      const SizedBox(width: 2.0),
                                      Text(
                                        book.isEpub ? '本地EPUB' : '本地TXT',
                                        style: TextStyle(fontSize: 9.0, color: colors.accent, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ] else if (_cachedCountMap[book.id] != null && _cachedCountMap[book.id]! > 0) ...[
                                const SizedBox(width: 8.0),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4.0),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.download_done_rounded, size: 10.0, color: Colors.green),
                                      const SizedBox(width: 2.0),
                                      Text(
                                        '${_cachedCountMap[book.id]}章离线',
                                        style: const TextStyle(fontSize: 9.0, color: Colors.green, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4.0),
                          Text(
                            book.author,
                            style: TextStyle(fontSize: 12.0, color: colors.textSecondary),
                          ),
                          const SizedBox(height: 6.0),
                          Text(
                            book.lastChapter,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11.0, color: colors.textSecondary),
                          ),
                          const SizedBox(height: 8.0),
                          // 进度条
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3.0),
                            child: LinearProgressIndicator(
                              value: book.progress,
                              minHeight: 4.0,
                              backgroundColor: colors.surface,
                              valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    Text(
                      '${(book.progress * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 12.0,
                        fontWeight: FontWeight.bold,
                        color: colors.accent,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          childCount: books.length,
        ),
      ),
    );
  }

  /// 网格视图
  Widget _buildGridView(List<BookItem> books, SoftColors colors) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 110.0),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 16.0,
          crossAxisSpacing: 14.0,
          childAspectRatio: 0.62,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final book = books[index];
            final seal = book.title.startsWith('十') && book.title.length > 1
                ? book.title.characters.take(2).string
                : book.title.characters.first;
            return GestureDetector(
              onTap: () => _openReader(book),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SoftCard(
                      colors: colors,
                      padding: EdgeInsets.zero,
                      child: Container(
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(14.0),
                          border: Border.all(
                            color: colors.accent.withValues(alpha: 0.35),
                            width: 1.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          seal,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: seal.length > 1 ? 16.0 : 20.0,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            color: colors.accent,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6.0),
                  Text(
                    book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.0,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        '${(book.progress * 100).toInt()}% 已读',
                        style: TextStyle(fontSize: 11.0, color: colors.textSecondary),
                      ),
                      if (book.isLocal) ...[
                        const Spacer(),
                        Icon(
                          book.isEpub ? Icons.menu_book_rounded : Icons.description_rounded,
                          size: 12.0,
                          color: colors.accent,
                        ),
                      ] else if (_cachedCountMap[book.id] != null && _cachedCountMap[book.id]! > 0) ...[
                        const Spacer(),
                        const Icon(Icons.download_done_rounded, size: 12.0, color: Colors.green),
                      ],
                    ],
                  ),
                ],
              ),
            );
          },
          childCount: books.length,
        ),
      ),
    );
  }

  /// 空状态占位
  Widget _buildEmptyState(SoftColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60.0, horizontal: 20.0),
      child: Center(
        child: Column(
          children: [
            const Text('📖', style: TextStyle(fontSize: 48.0)),
            const SizedBox(height: 12.0),
            Text(
              '书架空空如也',
              style: TextStyle(fontSize: 16.0, color: colors.textSecondary),
            ),
            const SizedBox(height: 16.0),
            ElevatedButton(
              key: const ValueKey('btn_go_discovery'),
              onPressed: widget.onNavigateToDiscovery,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
              ),
              child: const Text('去海量书库挑选好书'),
            ),
          ],
        ),
      ),
    );
  }
}
