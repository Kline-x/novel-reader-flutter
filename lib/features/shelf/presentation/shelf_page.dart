import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/components/book_cover_widget.dart';
import '../../../core/components/soft_card.dart';
import '../../../core/components/swipe_reveal_card.dart';
import '../../../core/theme/soft_theme.dart';
import '../../../core/utils/platform_adaptive_helper.dart';
import '../../local_books/presentation/wifi_transfer_dialog.dart';
import '../../local_books/services/local_book_service.dart';
import '../../reader/data/storage_service.dart';
import '../../reader/presentation/reader_screen.dart';
import '../../reader/services/download_service.dart';
import '../models/book_item.dart';
import 'book_detail_page.dart';

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

  final List<BookItem> _books = [];
  StreamSubscription<void>? _shelfSub;

  final StorageService _storageService = StorageService();
  Map<String, int> _cachedCountMap = {};
  StreamSubscription<ShelfBook>? _localBookSub;

  @override
  void initState() {
    super.initState();
    _loadBooksFromStorage();
    _shelfSub = StorageService.shelfUpdateStream.listen((_) {
      _loadBooksFromStorage();
    });
    _localBookSub = LocalBookService().bookImportedStream.listen((_) {
      _loadBooksFromStorage();
    });
  }

  @override
  void dispose() {
    _shelfSub?.cancel();
    _localBookSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBooksFromStorage() async {
    var saved = await _storageService.getBookshelf();
    if (saved.isEmpty && !await _storageService.hasSeededDefaultBooks()) {
      saved = await _storageService.seedDefaultBooks();
    }
    final List<BookItem> loaded = [];
    for (final s in saved) {
      final prog = await _storageService.getReadingProgress(s.bookId);
      final chIdx = prog?.chapterIndex ?? s.currentChapterIndex;
      final chOffset = prog?.charOffset ?? s.currentCharOffset;
      final total = s.totalChapters > 0 ? s.totalChapters : 100;
      final p = ((chIdx + 1) / total).clamp(0.0, 1.0);

      loaded.add(BookItem(
        id: s.bookId,
        title: s.title,
        author: s.author,
        coverUrl: s.coverUrl ?? '',
        latestChapter: s.lastChapterTitle ?? '第一章',
        progress: p,
        totalChapters: s.totalChapters,
        currentChapterIndex: chIdx,
        charOffset: chOffset,
        sourceId: s.sourceId,
        sourceName: s.sourceName ?? '笔趣阁ZWX',
        bookUrl: s.bookUrl,
        filePath: s.filePath,
      ));
    }

    final savedGridView = await _storageService.getShelfGridView();
    if (mounted) {
      setState(() {
        _isGridView = savedGridView;
        _books.clear();
        _books.addAll(loaded);
      });
    }

    // 实时对齐每本书的真实阅读进度与章节索引
    bool changed = false;
    for (int i = 0; i < _books.length; i++) {
      final b = _books[i];
      final prog = await _storageService.getReadingProgress(b.id);
      if (prog != null) {
        final total = b.totalChapters > 0 ? b.totalChapters : 100;
        final p = ((prog.chapterIndex + 1) / total).clamp(0.0, 1.0);
        _books[i] = b.copyWith(
          currentChapterIndex: prog.chapterIndex,
          currentCharOffset: prog.charOffset,
          progress: p,
        );
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
    final prog = await _storageService.getReadingProgress(book.id);
    final targetCh = prog?.chapterIndex ?? book.currentChapterIndex;
    final targetOffset = prog?.charOffset ?? book.charOffset;

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReaderScreen(
          bookId: book.id,
          bookTitle: book.title,
          author: book.author,
          initialChapterIndex: targetCh,
          initialCharOffset: targetOffset,
          bookUrl: book.bookUrl,
          sourceName: book.sourceName,
          sourceId: book.sourceId,
          book: book,
        ),
      ),
    );
    _loadBooksFromStorage();
  }

  Future<void> _openDetail(BookItem book) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookDetailPage(book: book),
      ),
    );
    _loadBooksFromStorage();
  }

  void _showBookOptions(BookItem book) {
    final colors = SoftTheme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '《${book.title}》',
                style: TextStyle(fontSize: 17.0, fontWeight: FontWeight.bold, color: colors.textPrimary),
              ),
              const SizedBox(height: 12.0),
              ListTile(
                leading: Icon(Icons.info_outline_rounded, color: colors.accent),
                title: Text('查看书籍详情', style: TextStyle(color: colors.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  _openDetail(book);
                },
              ),
              ListTile(
                leading: Icon(Icons.menu_book_rounded, color: colors.accent),
                title: Text('立即开始阅读', style: TextStyle(color: colors.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  _openReader(book);
                },
              ),
              ListTile(
                leading: Icon(Icons.download_for_offline_rounded, color: colors.accent),
                title: Text('离线下载全本', style: TextStyle(color: colors.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  DownloadService().startDownload(
                    bookId: book.id,
                    bookTitle: book.title,
                    totalChapters: book.totalChapters,
                    sourceName: book.sourceName,
                    bookUrl: book.bookUrl,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已将《${book.title}》加入后台下载队列'), behavior: SnackBarBehavior.floating),
                  );
                },
              ),
              ListTile(
                leading: Icon(book.isPinned ? Icons.vertical_align_bottom : Icons.vertical_align_top, color: colors.accent),
                title: Text(book.isPinned ? '取消置顶' : '置顶此书', style: TextStyle(color: colors.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    final idx = _books.indexWhere((b) => b.id == book.id);
                    if (idx != -1) {
                      _books[idx] = book.copyWith(isPinned: !book.isPinned);
                    }
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                title: const Text('从书架移出', style: TextStyle(color: Colors.redAccent)),
                onTap: () async {
                  Navigator.pop(context);
                  await _storageService.removeBookFromShelf(book.id);
                  setState(() {
                    _books.removeWhere((b) => b.id == book.id);
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showLocalImportDialog() {
    final colors = SoftTheme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
        title: Row(
          children: [
            Icon(Icons.file_upload_outlined, color: colors.accent),
            const SizedBox(width: 8.0),
            Text('本地图书导入', style: TextStyle(color: colors.textPrimary, fontSize: 17.0)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('支持导入格式：TXT（自动智能正则分章）、EPUB（图文排版）。', style: TextStyle(color: colors.textSecondary, fontSize: 13.0)),
            const SizedBox(height: 12.0),
            Text('如需电脑批量传输，亦可点击顶栏【WiFi传书】在同一局域网浏览器内秒速上传。', style: TextStyle(color: colors.textSecondary, fontSize: 12.0)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('知道了', style: TextStyle(color: colors.accent)),
          ),
        ],
      ),
    );
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
                    // 本地导入入口按钮
                    GestureDetector(
                      key: const ValueKey('shelf_local_import_btn'),
                      behavior: HitTestBehavior.opaque,
                      onTap: _showLocalImportDialog,
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
                              Icons.file_upload_outlined,
                              color: colors.accent,
                              size: 16.0,
                            ),
                            const SizedBox(width: 4.0),
                            Text(
                              '本地导入',
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
                    const SizedBox(width: 8.0),
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
                      onTap: () async {
                        final next = !_isGridView;
                        setState(() => _isGridView = next);
                        await _storageService.setShelfGridView(next);
                      },
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

  Future<void> _confirmRemoveBook(BookItem book, SoftColors colors) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18.0)),
        title: Text('移出书架', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold)),
        content: Text('确定要将《${book.title}》从书架中移除吗？', style: TextStyle(color: colors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('取消', style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _removeBook(book);
    }
  }

  Future<void> _removeBook(BookItem book) async {
    await _storageService.removeFromBookshelf(book.id, title: book.title);
    await _loadBooksFromStorage();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已从书架移出《${book.title}》'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  /// 列表视图（支持轻量阻尼滑动展露移出按钮与真全彩渐变封面）
  Widget _buildListView(List<BookItem> books, SoftColors colors) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 110.0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final book = books[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: SwipeRevealCard(
                key: ValueKey('shelf_swipe_${book.id}_$index'),
                onDelete: () => _confirmRemoveBook(book, colors),
                child: SoftCard(
                  colors: colors,
                  onTap: () => _openReader(book),
                  onLongPress: () => _showBookOptions(book),
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      // 高保真渐变自绘/网络封面组件
                      BookCoverWidget(
                        title: book.title,
                        author: book.author,
                        coverUrl: book.coverUrl,
                        width: 52.0,
                        height: 72.0,
                        borderRadius: 10.0,
                      ),
                      const SizedBox(width: 14.0),
                      // 书籍元信息
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    book.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 16.0,
                                      fontWeight: FontWeight.w700,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                ),
                                if (book.isLocal) ...[
                                  const SizedBox(width: 6.0),
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
                                  const SizedBox(width: 6.0),
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
                      const SizedBox(width: 10.0),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${(book.progress * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: 12.0,
                              fontWeight: FontWeight.bold,
                              color: colors.accent,
                            ),
                          ),
                          const SizedBox(height: 12.0),
                          GestureDetector(
                            onTap: () => _openDetail(book),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                              decoration: BoxDecoration(
                                color: colors.surface,
                                borderRadius: BorderRadius.circular(8.0),
                                border: Border.all(color: colors.border),
                              ),
                              child: Text(
                                '详情',
                                style: TextStyle(fontSize: 11.0, color: colors.textSecondary, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
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
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: PlatformAdaptiveHelper.instance.getShelfGridColumnCount(context),
          mainAxisSpacing: 16.0,
          crossAxisSpacing: 14.0,
          childAspectRatio: 0.62,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final book = books[index];
            return GestureDetector(
              onTap: () => _openDetail(book),
              onLongPress: () => _showBookOptions(book),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: BookCoverWidget(
                      title: book.title,
                      author: book.author,
                      coverUrl: book.coverUrl,
                      width: double.infinity,
                      height: double.infinity,
                      borderRadius: 14.0,
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
