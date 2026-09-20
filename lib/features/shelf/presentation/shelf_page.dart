import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lpinyin/lpinyin.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/components/ambient_mesh_background.dart';
import '../../../core/components/book_cover_widget.dart';
import '../../../core/components/soft_card.dart';
import '../../../core/components/swipe_reveal_card.dart';
import '../../../core/components/docked_bottom_bar.dart';
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
  /// 宿主文件选择器通道。目前只有鸿蒙侧实现（NovelReaderHostPlugin），
  /// 其余平台调用会抛 MissingPluginException，调用处已回退到沙箱扫描。
  static const MethodChannel _hostFilePickerChannel =
      MethodChannel('com.kline.novelreader/file_picker');

  final TextEditingController _searchController = TextEditingController();
  bool _isGridView = false;
  String _searchKeyword = '';

  final List<BookItem> _books = [];
  StreamSubscription<void>? _shelfSub;

  final StorageService _storageService = StorageService();
  Map<String, int> _cachedCountMap = {};
  StreamSubscription<ShelfBook>? _localBookSub;
  int _todayReadingMinutes = 0;

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
    // 首次启动不再往书架塞 4 本写死的示例书。那些书连章节数和「最新章节」
    // 都是编的，用户刚装完就看到一架子自己没加过的书，还以为是数据串了。
    // 空书架有专门的引导空态（_buildEmptyState），比假数据诚实。
    final saved = await _storageService.getBookshelf();
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
        isPinned: s.isPinned,
      ));
    }

    final savedGridView = await _storageService.getShelfGridView();
    final todayMins = await _storageService.getTodayReadingMinutes();
    if (mounted) {
      setState(() {
        _isGridView = savedGridView;
        _todayReadingMinutes = todayMins;
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
        return Material(
          color: colors.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '《${book.title}》',
                  style: TextStyle(
                      fontSize: 17.0,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary),
                ),
                const SizedBox(height: 12.0),
                ListTile(
                  leading:
                      Icon(Icons.info_outline_rounded, color: colors.accent),
                  title: Text('查看书籍详情',
                      style: TextStyle(color: colors.textPrimary)),
                  onTap: () {
                    Navigator.pop(context);
                    _openDetail(book);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.menu_book_rounded, color: colors.accent),
                  title: Text('立即开始阅读',
                      style: TextStyle(color: colors.textPrimary)),
                  onTap: () {
                    Navigator.pop(context);
                    _openReader(book);
                  },
                ),
                // 本地导入的书全部内容已在设备上，不该出现"离线下载全本"
                if (!book.isLocal)
                  ListTile(
                    leading: Icon(Icons.download_for_offline_rounded,
                        color: colors.accent),
                    title: Text('离线下载全本',
                        style: TextStyle(color: colors.textPrimary)),
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
                        SnackBar(
                            content: Text('已将《${book.title}》加入后台下载队列'),
                            behavior: SnackBarBehavior.floating),
                      );
                    },
                  ),
                ListTile(
                  leading: Icon(
                      book.isPinned
                          ? Icons.push_pin_outlined
                          : Icons.push_pin_rounded,
                      color: colors.accent),
                  title: Text(book.isPinned ? '取消置顶' : '置顶此书',
                      style: TextStyle(color: colors.textPrimary)),
                  onTap: () async {
                    Navigator.pop(context);
                    await _storageService.toggleBookPinned(book.id);
                    await _loadBooksFromStorage();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded,
                      color: Colors.redAccent),
                  title: const Text('从书架移出',
                      style: TextStyle(color: Colors.redAccent)),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmRemoveBook(book, colors);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _importLocalFile(File file) async {
    try {
      if (!await file.exists()) {
        throw FileSystemException('所选文件不存在', file.path);
      }
      final shelfBook = await LocalBookService().importFile(file);
      await _loadBooksFromStorage();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已成功导入《${shelfBook.title}》至书架'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导入图书失败：$e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showLocalImportDialog() {
    final colors = SoftTheme.of(context);
    final pathController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.fromLTRB(
                20.0,
                16.0,
                20.0,
                MediaQuery.of(context).viewInsets.bottom + 24.0,
              ),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28.0)),
                boxShadow: SoftDecorations.softShadows(colors, elevation: 2.0),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38.0,
                      height: 4.0,
                      decoration: BoxDecoration(
                        color: colors.border,
                        borderRadius: BorderRadius.circular(2.0),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: colors.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: Icon(Icons.file_upload_outlined,
                            color: colors.accent, size: 22.0),
                      ),
                      const SizedBox(width: 10.0),
                      Text(
                        '导入本地图书',
                        style: TextStyle(
                          fontSize: 18.0,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.close_rounded,
                            color: colors.textSecondary),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    '支持导入 .txt（智能正则分章）与 .epub（标准排版），导入后可离线极速畅读。',
                    style: TextStyle(
                        fontSize: 12.0,
                        color: colors.textSecondary,
                        height: 1.4),
                  ),
                  const SizedBox(height: 16.0),
                  TextField(
                    key: const ValueKey('input_local_import_path'),
                    controller: pathController,
                    style: TextStyle(fontSize: 13.0, color: colors.textPrimary),
                    decoration: InputDecoration(
                      hintText: '输入或粘贴文件绝对路径 (.txt / .epub)',
                      hintStyle: TextStyle(
                          fontSize: 12.0, color: colors.textSecondary),
                      filled: true,
                      fillColor: colors.surface,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14.0, vertical: 10.0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide:
                            BorderSide(color: colors.borderSubtle, width: 0.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide:
                            BorderSide(color: colors.borderSubtle, width: 0.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14.0),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const ValueKey('btn_scan_local_books'),
                          onPressed: () async {
                            // 先走系统文件选择器。此前只能手填绝对路径，
                            // 而普通用户根本拿不到沙箱路径；「扫描沙盒」也只是
                            // 取扫到的第一个文件，选不了。
                            //
                            // 没有用 file_picker：它的 ohos 实现是个不依赖主包的
                            // 完整 fork，且只声明支持 Dart 2，装上会让整套测试
                            // 都加载不起来。这里走自己的宿主通道，
                            // Android / iOS / 鸿蒙三侧都已实现；
                            // 万一通道缺失或用户取消，下面回退到沙箱扫描。
                            String? chosen;
                            try {
                              chosen = await _hostFilePickerChannel
                                  .invokeMethod<String>('pickBookFile', {
                                'extensions': ['txt', 'epub'],
                              });
                            } catch (_) {
                              // 通道未实现或用户取消，下面回退到扫描
                            }

                            if (chosen != null && chosen.isNotEmpty) {
                              pathController.text = chosen;
                              setSheetState(() {});
                              return;
                            }

                            // 兜底：扫应用沙箱里已有的书（WiFi 传书收下的就在这里）
                            final docDir =
                                await getApplicationDocumentsDirectory();
                            final files = <File>[];
                            try {
                              await for (final f
                                  in docDir.list(recursive: true)) {
                                if (f is File &&
                                    (f.path.endsWith('.txt') ||
                                        f.path.endsWith('.epub'))) {
                                  files.add(f);
                                }
                              }
                            } catch (_) {}

                            if (files.isEmpty) {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('未选择文件，沙盒中也没有图书，可用 WiFi 传书'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            } else {
                              final picked = files.first;
                              pathController.text = picked.path;
                              setSheetState(() {});
                            }
                          },
                          icon:
                              const Icon(Icons.folder_open_rounded, size: 16.0),
                          label: const Text('选择文件'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.textPrimary,
                            side: BorderSide(
                                color: colors.borderSubtle, width: 0.5),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.0)),
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10.0),
                      Expanded(
                        child: ElevatedButton.icon(
                          key: const ValueKey('btn_confirm_import_file'),
                          onPressed: () async {
                            final path = pathController.text.trim();
                            if (path.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('请输入或选择有效的文件路径'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }
                            Navigator.pop(ctx);
                            await _importLocalFile(File(path));
                          },
                          icon: const Icon(Icons.check_rounded, size: 16.0),
                          label: const Text('确认导入'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.accent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.0)),
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12.0),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      Navigator.pop(ctx);
                      WifiTransferDialog.show(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14.0, vertical: 10.0),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.wifi_tethering_rounded,
                              size: 18.0, color: colors.accent),
                          const SizedBox(width: 8.0),
                          Expanded(
                            child: Text(
                              '局域网电脑无线秒传？点击开启 WiFi 传书',
                              style: TextStyle(
                                  fontSize: 12.0, color: colors.textSecondary),
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios_rounded,
                              size: 12.0, color: colors.textSecondary),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = SoftTheme.of(context);

    // 过滤与拼音排序（支持书名、作者、全拼及首字母智能检索，置顶书籍优先）
    final kw = _searchKeyword.toLowerCase();
    var filteredBooks = _books.where((b) {
      if (kw.isEmpty) return true;
      if (b.title.toLowerCase().contains(kw) ||
          b.author.toLowerCase().contains(kw)) {
        return true;
      }
      if (b.pinyin.toLowerCase().contains(kw)) {
        return true;
      }
      try {
        final initials =
            PinyinHelper.getShortPinyin(b.cleanTitle).toLowerCase();
        if (initials.contains(kw)) {
          return true;
        }
      } catch (_) {}
      return false;
    }).toList();

    filteredBooks.sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      return a.pinyin.compareTo(b.pinyin);
    });

    return Scaffold(
      backgroundColor: colors.background,
      body: AmbientMeshBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // 1. 顶部标题与操作栏 (固定置顶)
              _buildTopBar(colors),

              // 2. Bento 晨光雅集个人数据看板 (固定置顶)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
                child: _buildBentoDashboard(colors),
              ),

              // 3. 柔和胶囊搜索过滤栏 (固定置顶)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
                child: _buildSearchBar(colors),
              ),

              // 4. 精装书架展柜标题栏 (典藏书架 / 按阅读时间 ▾，固定置顶)
              Padding(
                padding: const EdgeInsets.fromLTRB(22.0, 6.0, 22.0, 4.0),
                child: _buildSectionHeader(colors),
              ),

              // 5. 独立滑动的书籍列表区域 (仅此处产生滚动手势)
              Expanded(
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    if (filteredBooks.isEmpty)
                      SliverToBoxAdapter(child: _buildEmptyState(colors))
                    else if (_isGridView)
                      _buildGridView(filteredBooks, colors)
                    else
                      _buildListView(filteredBooks, colors),

                    // 底部安全留白：按底栏实际高度（浮空胶囊 + 内容 + 安全区）动态预留
                    SliverToBoxAdapter(
                      child: SizedBox(
                          height:
                              DockedBottomBar.contentBottomPadding(context)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 顶部固定标题栏
  Widget _buildTopBar(SoftColors colors) {
    return Container(
      height: 56.0,
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        children: [
          // 原型 1:1 左侧两行：PRIVATE LIBRARY + 藏书阁·脉冲圆点
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'PRIVATE LIBRARY',
                style: TextStyle(
                  fontSize: 10.0,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: colors.textSecondary.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 1.0),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '藏书阁',
                    style: TextStyle(
                      fontSize: 22.0,
                      fontWeight: FontWeight.w900,
                      color: colors.textPrimary,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(width: 6.0),
                  // 呼吸微光圆点 (pulse-dot)
                  Container(
                    width: 6.0,
                    height: 6.0,
                    decoration: BoxDecoration(
                      color: colors.accent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: colors.accentGlow,
                          blurRadius: 5.0,
                          spreadRadius: 1.0,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          // 导入实心微胶囊
          GestureDetector(
            key: const ValueKey('shelf_local_import_btn'),
            behavior: HitTestBehavior.opaque,
            onTap: _showLocalImportDialog,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.5),
              decoration: BoxDecoration(
                color: colors.accent,
                borderRadius: BorderRadius.circular(SoftDecorations.pillRadius),
                boxShadow: [
                  BoxShadow(
                    color: colors.accentGlow,
                    blurRadius: 10.0,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 14.0,
                  ),
                  SizedBox(width: 3.5),
                  Text(
                    '导入',
                    style: TextStyle(
                      fontSize: 12.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8.0),
          // WiFi 毛玻璃微胶囊
          GestureDetector(
            key: const ValueKey('shelf_wifi_transfer_btn'),
            behavior: HitTestBehavior.opaque,
            onTap: () => WifiTransferDialog.show(context),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 11.0, vertical: 6.0),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(SoftDecorations.pillRadius),
                border: Border.all(color: colors.borderSubtle),
              ),
              child: Text(
                'WiFi',
                style: TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8.0),
          // 视图切换
          GestureDetector(
            key: const ValueKey('shelf_view_toggle'),
            behavior: HitTestBehavior.opaque,
            onTap: () async {
              final next = !_isGridView;
              setState(() => _isGridView = next);
              await _storageService.setShelfGridView(next);
            },
            child: Container(
              width: 32.0,
              height: 32.0,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: colors.borderSubtle),
              ),
              child: Icon(
                _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
                color: colors.textSecondary,
                size: 17.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 搜索框组件 (固定在顶部)
  Widget _buildSearchBar(SoftColors colors) {
    return Container(
      height: 42.0,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(SoftDecorations.pillRadius),
        border: Border.all(color: colors.borderSubtle, width: 1.0),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Icon(Icons.search_rounded,
              size: 18.0, color: colors.textSecondary.withValues(alpha: 0.65)),
          const SizedBox(width: 8.0),
          Expanded(
            child: TextField(
              key: const ValueKey('shelf_search_input'),
              controller: _searchController,
              style: TextStyle(fontSize: 13.0, color: colors.textPrimary),
              decoration: InputDecoration(
                hintText: '检索藏书阁书目、作者或纪事...',
                hintStyle: TextStyle(
                    fontSize: 12.5,
                    color: colors.textSecondary.withValues(alpha: 0.7)),
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
              child: Icon(Icons.clear_rounded,
                  size: 17.0, color: colors.textSecondary),
            ),
        ],
      ),
    );
  }

  /// 典藏书架展柜栏 (固定在顶部)
  Widget _buildSectionHeader(SoftColors colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '典藏书架',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            color: colors.textSecondary.withValues(alpha: 0.75),
          ),
        ),
        Text(
          '按阅读时间 ▾',
          style: TextStyle(
            fontSize: 11.0,
            fontWeight: FontWeight.w600,
            color: colors.accent,
          ),
        ),
      ],
    );
  }

  /// 晨光雅集 Bento 轻拟态仪表盘
  Widget _buildBentoDashboard(SoftColors colors) {
    double avgProgress = 0.0;
    if (_books.isNotEmpty) {
      final sum = _books.fold<double>(0.0, (prev, b) => prev + b.progress);
      avgProgress = sum / _books.length;
    }
    final flowProgress = (_todayReadingMinutes / 60.0).clamp(0.0, 1.0);

    return Row(
      children: [
        // 今日心流时长
        Expanded(
          flex: 1,
          child: SoftCard(
            colors: colors,
            radius: SoftDecorations.squircleSubCardRadius,
            padding:
                const EdgeInsets.symmetric(horizontal: 15.0, vertical: 13.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '今日心流',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(
                      width: 0,
                      height: 0,
                      child: OverflowBox(
                        minWidth: 0,
                        maxWidth: 0,
                        minHeight: 0,
                        maxHeight: 0,
                        child: Text('今日阅读'),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7.0, vertical: 2.0),
                      decoration: BoxDecoration(
                        color: colors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(9999.0),
                      ),
                      child: Text(
                        _todayReadingMinutes >= 60 ? '已达标' : '专注中',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: colors.accent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8.0),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '$_todayReadingMinutes',
                        style: TextStyle(
                          fontSize: 24.0,
                          fontWeight: FontWeight.w900,
                          color: colors.accent,
                          letterSpacing: -0.5,
                        ),
                      ),
                      TextSpan(
                        text: ' 分钟',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 7.0),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3.0),
                  child: Container(
                    height: 4.5,
                    color: colors.isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.05),
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: flowProgress > 0 ? flowProgress : 0.03,
                      child: Container(
                        decoration: BoxDecoration(
                          color: colors.accent,
                          borderRadius: BorderRadius.circular(3.0),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12.0),
        // 珍本在读
        Expanded(
          flex: 1,
          child: SoftCard(
            colors: colors,
            radius: SoftDecorations.squircleSubCardRadius,
            padding:
                const EdgeInsets.symmetric(horizontal: 15.0, vertical: 13.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '珍本在读',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(
                      width: 0,
                      height: 0,
                      child: OverflowBox(
                        minWidth: 0,
                        maxWidth: 0,
                        minHeight: 0,
                        maxHeight: 0,
                        child: Text('在读藏书'),
                      ),
                    ),
                    Text(
                      '${_books.length} TITLES',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: colors.textSecondary.withValues(alpha: 0.55),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '${_books.length}',
                            style: TextStyle(
                              fontSize: 24.0,
                              fontWeight: FontWeight.w900,
                              color: colors.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          TextSpan(
                            text: ' 部',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7.0, vertical: 2.0),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(9999.0),
                        border: Border.all(
                            color: colors.border.withValues(alpha: 0.8),
                            width: 0.8),
                      ),
                      child: Text(
                        _books.isEmpty
                            ? '待入库'
                            : '均度 ${(avgProgress * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 11.5),
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18.0)),
        title: Text('移出书架',
            style: TextStyle(
                color: colors.textPrimary, fontWeight: FontWeight.bold)),
        content: Text('确定要将《${book.title}》从书架中移除吗？',
            style: TextStyle(color: colors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('取消', style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0)),
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
    final originalBooks = await _storageService.getBookshelf();
    final originalShelfBook = originalBooks.firstWhere(
      (b) => b.bookId == book.id,
      orElse: () => ShelfBook(
        bookId: book.id,
        title: book.title,
        author: book.author,
        coverUrl: book.coverUrl,
        lastChapterTitle: book.lastChapter,
        totalChapters: book.totalChapters,
        lastReadTime: DateTime.now(),
        filePath: book.filePath,
        bookUrl: book.bookUrl,
        sourceName: book.sourceName,
        sourceId: book.sourceId,
        isPinned: book.isPinned,
      ),
    );

    await _storageService.removeFromBookshelf(book.id, title: book.title);
    await _loadBooksFromStorage();
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已从书架移出《${book.title}》'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          // 必须显式 persist: false。
          // Flutter 的 SnackBar 构造里 `persist = persist ?? action != null`，
          // 而 ScaffoldMessenger 的超时回调里 `if (snackBar.persist) return;`——
          // 也就是说带 action 的 SnackBar 默认永不自动消失，duration 完全失效。
          // 这条「撤销」提示因此会一直挂在屏幕上。
          persist: false,
          showCloseIcon: true,
          action: SnackBarAction(
            label: '撤销',
            textColor: Colors.amberAccent,
            onPressed: () async {
              await _storageService.addToBookshelf(originalShelfBook);
              await _loadBooksFromStorage();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('已恢复《${book.title}》至书架'),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
        ),
      );
    }
  }

  /// 列表视图（支持轻量阻尼滑动展露移出按钮与真全彩渐变封面）
  Widget _buildListView(List<BookItem> books, SoftColors colors) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 0.0),
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
                                if (book.isPinned) ...[
                                  Container(
                                    margin: const EdgeInsets.only(right: 6.0),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5.0, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: colors.isDark
                                          ? Colors.amber.withValues(alpha: 0.22)
                                          : Colors.amber
                                              .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4.0),
                                      border: Border.all(
                                          color: colors.isDark
                                              ? const Color(0xFFFFC107)
                                              : Colors.amber.shade700,
                                          width: 0.6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.push_pin_rounded,
                                            size: 10.0,
                                            color: Color(0xFFFFC107)),
                                        const SizedBox(width: 2.0),
                                        Text(
                                          '置顶',
                                          style: TextStyle(
                                            fontSize: 9.0,
                                            color: colors.isDark
                                                ? const Color(0xFFFFD54F)
                                                : Colors.amber.shade900,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
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
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5.0, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color:
                                          colors.accent.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4.0),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          book.isEpub
                                              ? Icons.menu_book_rounded
                                              : Icons.description_rounded,
                                          size: 10.0,
                                          color: colors.accent,
                                        ),
                                        const SizedBox(width: 2.0),
                                        Text(
                                          book.isEpub ? '本地EPUB' : '本地TXT',
                                          style: TextStyle(
                                              fontSize: 9.0,
                                              color: colors.accent,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ] else if (_cachedCountMap[book.id] != null &&
                                    _cachedCountMap[book.id]! > 0) ...[
                                  const SizedBox(width: 6.0),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5.0, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.green.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4.0),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.download_done_rounded,
                                            size: 10.0, color: Colors.green),
                                        const SizedBox(width: 2.0),
                                        Text(
                                          '${_cachedCountMap[book.id]}章离线',
                                          style: const TextStyle(
                                              fontSize: 9.0,
                                              color: Colors.green,
                                              fontWeight: FontWeight.bold),
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
                              style: TextStyle(
                                  fontSize: 12.0, color: colors.textSecondary),
                            ),
                            const SizedBox(height: 6.0),
                            Text(
                              book.lastChapter,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11.0, color: colors.textSecondary),
                            ),
                            const SizedBox(height: 8.0),
                            // 进度条
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3.0),
                              child: LinearProgressIndicator(
                                value: book.progress,
                                minHeight: 4.0,
                                backgroundColor: colors.surface,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    colors.accent),
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
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0, vertical: 4.0),
                              decoration: BoxDecoration(
                                color: colors.surface,
                                borderRadius: BorderRadius.circular(8.0),
                                border: Border.all(color: colors.border),
                              ),
                              child: Text(
                                '详情',
                                style: TextStyle(
                                    fontSize: 11.0,
                                    color: colors.textSecondary,
                                    fontWeight: FontWeight.w600),
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
      padding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 0.0),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount:
              PlatformAdaptiveHelper.instance.getShelfGridColumnCount(context),
          mainAxisSpacing: 16.0,
          crossAxisSpacing: 14.0,
          childAspectRatio: 0.58,
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
                    child: Stack(
                      children: [
                        BookCoverWidget(
                          title: book.title,
                          author: book.author,
                          coverUrl: book.coverUrl,
                          width: double.infinity,
                          height: double.infinity,
                          borderRadius: 14.0,
                        ),
                        // 置顶徽标 (D16 调优)
                        if (book.isPinned)
                          Positioned(
                            top: 6.0,
                            right: 6.0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5.0, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF14161B)
                                    .withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(6.0),
                                border: Border.all(
                                    color: const Color(0xFFFFC107), width: 0.8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.push_pin_rounded,
                                      size: 10.0, color: Color(0xFFFFC107)),
                                  SizedBox(width: 2.0),
                                  Text(
                                    '置顶',
                                    style: TextStyle(
                                      fontSize: 9.0,
                                      color: Color(0xFFFFD54F),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        // 独立离线徽标微胶囊 (4.4 与进度解耦)
                        if (book.isLocal)
                          Positioned(
                            top: 6.0,
                            left: 6.0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5.0, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF14161B)
                                    .withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(6.0),
                                border: Border.all(
                                    color: colors.accent.withValues(alpha: 0.8),
                                    width: 0.6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    book.isEpub
                                        ? Icons.menu_book_rounded
                                        : Icons.description_rounded,
                                    size: 10.0,
                                    color: colors.accent,
                                  ),
                                  const SizedBox(width: 2.0),
                                  Text(
                                    book.isEpub ? 'EPUB' : 'TXT',
                                    style: TextStyle(
                                        fontSize: 9.0,
                                        color: colors.accent,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else if (_cachedCountMap[book.id] != null &&
                            _cachedCountMap[book.id]! > 0)
                          Positioned(
                            top: 6.0,
                            left: 6.0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5.0, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF14161B)
                                    .withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(6.0),
                                border: Border.all(
                                    color: Colors.greenAccent
                                        .withValues(alpha: 0.8),
                                    width: 0.6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.download_done_rounded,
                                      size: 10.0, color: Colors.greenAccent),
                                  const SizedBox(width: 2.0),
                                  Text(
                                    '${_cachedCountMap[book.id]}章',
                                    style: const TextStyle(
                                        fontSize: 9.0,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
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
                  const SizedBox(height: 2.0),
                  // 【4.3】最新章节精致小字
                  Text(
                    book.lastChapter,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: colors.textSecondary.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 2.0),
                  // 独立阅读进度（彻底解耦）
                  Text(
                    '${(book.progress * 100).toInt()}% 已读',
                    style:
                        TextStyle(fontSize: 11.0, color: colors.textSecondary),
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
    final isSearching = _searchKeyword.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 50.0, horizontal: 20.0),
      child: Center(
        child: Column(
          children: [
            Text(isSearching ? '🔍' : '📖',
                style: const TextStyle(fontSize: 48.0)),
            const SizedBox(height: 12.0),
            Text(
              '书架空空如也',
              style: TextStyle(
                  fontSize: 16.0,
                  color: colors.textPrimary,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6.0),
            Text(
              isSearching
                  ? '未在书架中找到 "$_searchKeyword"，可清空或去全网搜索'
                  : '快去挑选几本心仪的好书充实书架吧',
              style: TextStyle(fontSize: 13.0, color: colors.textSecondary),
            ),
            const SizedBox(height: 18.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isSearching) ...[
                  OutlinedButton(
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchKeyword = '');
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.textPrimary,
                      side: BorderSide(color: colors.borderSubtle, width: 0.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20.0)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18.0, vertical: 10.0),
                    ),
                    child: const Text('清空检索'),
                  ),
                  const SizedBox(width: 12.0),
                ],
                ElevatedButton(
                  key: const ValueKey('btn_go_discovery'),
                  onPressed: () {
                    if (isSearching) {
                      _searchController.clear();
                      setState(() => _searchKeyword = '');
                    }
                    widget.onNavigateToDiscovery();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20.0)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22.0, vertical: 10.0),
                  ),
                  child: Text(isSearching ? '去全网搜索' : '去海量书库挑选好书'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
