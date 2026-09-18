import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/components/book_cover_widget.dart';
import '../../../core/components/soft_button.dart';
import '../../../core/components/soft_card.dart';
import '../../../core/theme/soft_theme.dart';
import '../../reader/data/storage_service.dart';
import '../../reader/presentation/reader_screen.dart';
import '../../reader/services/chapter_helper.dart';
import '../../sources/models/chapter_item.dart';
import '../../sources/models/source_rule.dart';
import '../../sources/services/builtin_sources.dart';
import '../../sources/services/source_parser.dart';
import '../models/book_item.dart';
import 'shelf_controller.dart';

/// 高保真书籍详情页 (BookDetailPage)
/// 严格 1:1 对齐原型 scheme-v2-impl.html 中的 #page-detail 视觉与结构
class BookDetailPage extends ConsumerStatefulWidget {
  final BookItem book;
  final List<ChapterItem>? initialChapters;

  const BookDetailPage({
    super.key,
    required this.book,
    this.initialChapters,
  });

  @override
  ConsumerState<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPageState extends ConsumerState<BookDetailPage> {
  late BookItem _book;
  final StorageService _storageService = StorageService();
  final SourceParser _parser = SourceParser();

  bool _isInShelf = false;
  bool _isLoadingToc = true;

  /// 目录抓取失败：宁可空着让用户重试/换源，也不能塞 12 章假目录冒充真目录
  bool _tocFailed = false;
  bool _isReversed = false;
  bool _isIntroExpanded = false;
  bool _isAllChaptersExpanded = false;
  List<ChapterItem> _chapters = [];
  int _currentChapterIndex = 0;
  int _currentCharOffset = 0;
  String? _latestUpdateTime;

  @override
  void initState() {
    super.initState();
    _book = widget.book;
    _checkShelfStatus();
    _loadProgress();
    if (widget.initialChapters != null && widget.initialChapters!.isNotEmpty) {
      _chapters = widget.initialChapters!;
      _isLoadingToc = false;
      _fetchDetailMeta();
    } else {
      _loadToc();
    }
  }

  Future<void> _checkShelfStatus() async {
    final shelf = await _storageService.getBookshelf();
    final cleanT = _book.cleanTitle.toLowerCase();
    final inShelf = shelf.any((b) {
      final bClean = b.title.replaceAll(RegExp(r'[《》\s]'), '').toLowerCase();
      return b.bookId == _book.id || bClean == cleanT;
    });
    if (mounted) {
      setState(() => _isInShelf = inShelf);
    }
  }

  Future<void> _loadProgress() async {
    final prog = await _storageService.getReadingProgress(_book.id);
    if (prog != null && mounted) {
      setState(() {
        _currentChapterIndex = prog.chapterIndex;
        _currentCharOffset = prog.charOffset;
      });
    }
  }

  void _fetchDetailMeta() {
    SourceRule? rule = BuiltinSources.findByName(_book.sourceName) ??
        BuiltinSources.all.firstWhere(
          (s) => s.id == _book.sourceId,
          orElse: () => BuiltinSources.all.first,
        );
    if (_book.bookUrl != null && _book.bookUrl!.isNotEmpty) {
      _parser.fetchBookDetail(rule, _book.bookUrl!).then((detail) {
        if (mounted && detail.isNotEmpty) {
          setState(() {
            if (detail['intro'] != null &&
                (detail['intro'] as String).isNotEmpty) {
              _book = _book.copyWith(description: detail['intro'] as String);
            }
            if (detail['updateTime'] != null) {
              _latestUpdateTime = detail['updateTime'] as String;
            }
            if (detail['status'] != null) {
              _book = _book.copyWith(status: detail['status'] as String);
            }
          });
        }
      });
    }
  }

  Future<void> _loadToc({bool forceRefresh = false}) async {
    setState(() => _isLoadingToc = true);

    // 1. 若非强制刷新，优先读取沙盒缓存目录
    if (!forceRefresh) {
      final cachedToc = await _storageService.getBookToc(_book.id);
      // 与 StorageService.getBookToc 保持同一套脏数据判据，
      // 不再用「章节数 >= 20」误伤短篇书
      if (cachedToc != null && !StorageService.isDirtyToc(cachedToc)) {
        if (mounted) {
          setState(() {
            _chapters = cachedToc.map((m) => ChapterItem.fromJson(m)).toList();
            _isLoadingToc = false;
          });
          _fetchDetailMeta();
        }
        return;
      }
    }

    // 2. 在线拉取完整真实目录
    try {
      SourceRule? rule = BuiltinSources.findByName(_book.sourceName) ??
          BuiltinSources.all.firstWhere(
            (s) => s.id == _book.sourceId,
            orElse: () => BuiltinSources.all.first,
          );

      String? targetUrl = _book.bookUrl;
      final lowerTitle = ChapterHelper.cleanTitle(_book.title).toLowerCase();
      if (targetUrl == null ||
          targetUrl.isEmpty ||
          targetUrl.contains('biquge.company')) {
        if (lowerTitle.contains('恶魔') || lowerTitle.contains('emofaze')) {
          targetUrl = 'https://www.biquge7.xyz/1283/';
          rule = BuiltinSources.findByName('笔趣阁7') ?? rule;
        } else if (lowerTitle.contains('诡秘之主') ||
            lowerTitle.contains('guimi')) {
          targetUrl = 'https://www.biqugezwx.com/50/';
          rule = BuiltinSources.findByName('笔趣阁ZWX') ?? rule;
        } else if (lowerTitle.contains('十日终焉') ||
            lowerTitle.contains('shiri')) {
          targetUrl = 'https://www.biqugezwx.com/745/';
          rule = BuiltinSources.findByName('笔趣阁ZWX') ?? rule;
        } else if (lowerTitle.contains('道诡异仙') ||
            lowerTitle.contains('daoti')) {
          targetUrl = 'https://www.biqugezwx.com/334/';
          rule = BuiltinSources.findByName('笔趣阁ZWX') ?? rule;
        } else if (lowerTitle.contains('剑来') ||
            lowerTitle.contains('jianlai')) {
          targetUrl = 'https://www.biqugezwx.com/324/';
          rule = BuiltinSources.findByName('笔趣阁ZWX') ?? rule;
        }
      }

      if (targetUrl == null || targetUrl.isEmpty) {
        final cleanTitle = ChapterHelper.cleanTitle(_book.title);
        final searchResults = await _parser
            .searchBooks(rule, cleanTitle)
            .timeout(const Duration(seconds: 5));
        if (searchResults.isNotEmpty) {
          final matched = searchResults.firstWhere(
            (b) => b.title == cleanTitle || b.title.contains(cleanTitle),
            orElse: () => searchResults.first,
          );
          targetUrl = matched.bookUrl;
        }
      }

      if (targetUrl != null && targetUrl.isNotEmpty) {
        _book = _book.copyWith(
            bookUrl: targetUrl, sourceName: rule.name, sourceId: rule.id);
        final toc = await _parser
            .fetchToc(rule, targetUrl)
            .timeout(const Duration(seconds: 8));
        if (toc.isNotEmpty) {
          _chapters = toc;
          _tocFailed = false;
          await _storageService.saveBookToc(_book.id, toc);
          if (mounted) {
            setState(() => _isLoadingToc = false);
          }
          _fetchDetailMeta();
          return;
        }
      }
    } catch (e) {
      debugPrint('详情页目录拉取失败: $e');
    }

    // 3. 网络异常且无缓存时的仅内存临时兜底，绝不写入本地持久化缓存以防污染
    // 此前这里会回退到 ChapterHelper 的 12 章假目录，
    // 用户看到的是「伯爵的儿子 / 白痴 / 文不成武不就…」这种伪造章节，
    // 却完全不知道真目录根本没拉到。
    if (_chapters.isEmpty) {
      _tocFailed = true;
    }
    if (mounted) {
      setState(() => _isLoadingToc = false);
    }
  }

  Future<void> _toggleShelf() async {
    if (_isInShelf) {
      // 从书架移除
      await _storageService.removeBookFromShelf(_book.id, title: _book.title);
      ref.read(shelfProvider.notifier).removeBook(_book.id);
      if (mounted) {
        setState(() => _isInShelf = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已将《${_book.title}》从书架移出'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } else {
      // 加入书架
      final shelfBook = ShelfBook(
        bookId: _book.id,
        title: _book.title,
        author: _book.author,
        coverUrl: _book.coverUrl,
        sourceId: _book.sourceId,
        sourceName: _book.sourceName,
        bookUrl: _book.bookUrl,
        lastReadTime: DateTime.now(),
        lastChapterTitle:
            _chapters.isNotEmpty ? _chapters.last.title : _book.latestChapter,
      );
      await _storageService.addBookToShelf(shelfBook);
      ref.read(shelfProvider.notifier).addBook(_book);
      if (mounted) {
        setState(() => _isInShelf = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已将《${_book.title}》收入藏书阁！'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  void _openReader({int? chapterIndex}) {
    final targetCh = chapterIndex ?? _currentChapterIndex;
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => ReaderScreen(
          bookId: _book.id,
          bookTitle: _book.title,
          author: _book.author,
          initialChapterIndex: targetCh,
          initialCharOffset: chapterIndex != null ? 0 : _currentCharOffset,
          bookUrl: _book.bookUrl,
          sourceName: _book.sourceName,
          sourceId: _book.sourceId,
          book: _book,
        ),
      ),
    )
        .then((_) {
      _loadProgress();
      _checkShelfStatus();
    });
  }

  void _openSourceSwitcher() {
    final colors = SoftTheme.of(context);
    const sources = BuiltinSources.all;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.65,
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28.0)),
            boxShadow: SoftDecorations.softShadows(colors, elevation: 2.0),
          ),
          padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40.0,
                  height: 4.0,
                  decoration: BoxDecoration(
                    color: colors.textSecondary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2.0),
                  ),
                ),
              ),
              const SizedBox(height: 16.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '切换可用书源',
                    style: TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8.0, vertical: 3.0),
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Text(
                      '12 组稳定书源',
                      style: TextStyle(
                          fontSize: 11.0,
                          color: colors.accent,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8.0),
              Text(
                '无缝切换书源并同步更新最新目录',
                style: TextStyle(fontSize: 12.0, color: colors.textSecondary),
              ),
              const SizedBox(height: 12.0),
              Expanded(
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: sources.length,
                  separatorBuilder: (_, __) => Divider(
                      height: 1.0, color: colors.border.withValues(alpha: 0.5)),
                  itemBuilder: (context, index) {
                    final s = sources[index];
                    final isCurrent = s.name == _book.sourceName;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 2.0),
                      leading: Container(
                        width: 36.0,
                        height: 36.0,
                        decoration: BoxDecoration(
                          color: isCurrent ? colors.accent : colors.surface,
                          borderRadius: BorderRadius.circular(10.0),
                          border: Border.all(
                              color: isCurrent ? colors.accent : colors.border),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          s.name.characters.take(1).toString(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color:
                                isCurrent ? Colors.white : colors.textPrimary,
                          ),
                        ),
                      ),
                      title: Text(
                        s.name,
                        style: TextStyle(
                          fontSize: 15.0,
                          fontWeight:
                              isCurrent ? FontWeight.bold : FontWeight.w500,
                          color: isCurrent ? colors.accent : colors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        s.baseUrl,
                        style: TextStyle(
                            fontSize: 11.0, color: colors.textSecondary),
                      ),
                      trailing: isCurrent
                          ? Icon(Icons.check_circle,
                              color: colors.accent, size: 20.0)
                          : Icon(Icons.chevron_right,
                              color:
                                  colors.textSecondary.withValues(alpha: 0.5),
                              size: 18.0),
                      onTap: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        Navigator.of(context).pop();
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('正在检测【${s.name}】全本目录收录情况...'),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 1),
                          ),
                        );
                        try {
                          final cleanTitle =
                              ChapterHelper.cleanTitle(_book.title);
                          final searchResults = await _parser
                              .searchBooks(s, cleanTitle)
                              .timeout(const Duration(seconds: 5));
                          final matches = searchResults.where((b) {
                            final t =
                                b.title.replaceAll(RegExp(r'[《》【】\s]'), '');
                            return t == cleanTitle ||
                                t.contains(cleanTitle) ||
                                cleanTitle.contains(t);
                          }).toList();
                          if (matches.isNotEmpty) {
                            final matched = matches.first;
                            final newToc = await _parser
                                .fetchToc(s, matched.bookUrl)
                                .timeout(const Duration(seconds: 7));
                            if (newToc.isNotEmpty) {
                              if (mounted) {
                                setState(() {
                                  _book = _book.copyWith(
                                      sourceName: s.name,
                                      sourceId: s.id,
                                      bookUrl: matched.bookUrl);
                                  _chapters = newToc;
                                });
                              }
                              await _storageService.saveBookToc(
                                  _book.id, newToc);
                              if (mounted) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        '已成功切换至【${s.name}】，获取到 ${newToc.length} 章完整目录！'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                              _fetchDetailMeta();
                              return;
                            }
                          }
                        } catch (_) {}

                        // 目标源未收录或网络超时的安全保护，保留原目录绝不破坏
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                  '【${s.name}】暂未收录《${_book.title}》，已为您保留当前高可用源目录！'),
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = SoftTheme.of(context);
    final isDark = colors.isDark;

    final displayChapters =
        _isReversed ? _chapters.reversed.toList() : _chapters;
    // 目录没拉到时不要拿 BookItem 的默认章节数顶上——
    // 会出现"篇幅 100 章"和下方"目录获取失败"自相矛盾
    final hasRealToc = _chapters.isNotEmpty;
    final totalChaptersCount = hasRealToc ? _chapters.length : 0;
    // 书源不返回字数，此前按"章节数 × 0.28"伪造成"198.2万字"。
    // 拿不到真实字数时改为展示真实的章节总数。
    final readWordCount =
        _book.wordCount ?? (hasRealToc ? '$totalChaptersCount 章' : '—');

    return Scaffold(
      backgroundColor: colors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. SliverAppBar 沉浸吸顶大顶部区域
          SliverAppBar(
            pinned: true,
            expandedHeight: 250.0,
            backgroundColor: colors.background,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leadingWidth: 64.0,
            leading: Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Center(
                child: GestureDetector(
                  key: const ValueKey('detail_back_btn'),
                  onTap: () => Navigator.of(context).maybePop(),
                  child: Container(
                    width: 38.0,
                    height: 38.0,
                    decoration: BoxDecoration(
                      color: (isDark ? colors.surface : colors.card)
                          .withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12.0),
                      boxShadow:
                          SoftDecorations.softShadows(colors, elevation: 0.8),
                    ),
                    child: Icon(
                      Icons.chevron_left_rounded,
                      color: colors.textPrimary,
                      size: 22.0,
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Center(
                  child: GestureDetector(
                    onTap: _openSourceSwitcher,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10.0, vertical: 6.0),
                      decoration: BoxDecoration(
                        color: (isDark ? colors.surface : colors.card)
                            .withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12.0),
                        boxShadow:
                            SoftDecorations.softShadows(colors, elevation: 0.6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6.0,
                            height: 6.0,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6.0),
                          Text(
                            _book.sourceName,
                            style: TextStyle(
                              fontSize: 12.0,
                              fontWeight: FontWeight.bold,
                              color: colors.accent,
                            ),
                          ),
                          const SizedBox(width: 2.0),
                          Icon(Icons.arrow_drop_down,
                              color: colors.accent, size: 16.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
            flexibleSpace: LayoutBuilder(
              builder: (context, constraints) {
                final topPadding = MediaQuery.paddingOf(context).top;
                final currentHeight = constraints.maxHeight;
                final collapseRange = 250.0 - (kToolbarHeight + topPadding);
                final expandRatio = collapseRange > 0
                    ? ((currentHeight - (kToolbarHeight + topPadding)) /
                            collapseRange)
                        .clamp(0.0, 1.0)
                    : 0.0;
                final titleOpacity = (1.0 - expandRatio * 2.2).clamp(0.0, 1.0);
                final contentOpacity =
                    ((expandRatio - 0.25) / 0.75).clamp(0.0, 1.0);

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // 顶部光影晕染背景
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              colors.accent
                                  .withValues(alpha: isDark ? 0.25 : 0.18),
                              colors.background.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // 收拢时常驻顶栏中心优雅渐入的书名与作者
                    if (titleOpacity > 0.01)
                      Positioned(
                        top: topPadding,
                        left: 64.0,
                        right: 120.0,
                        height: kToolbarHeight,
                        child: Opacity(
                          opacity: titleOpacity,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _book.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 15.0,
                                    fontWeight: FontWeight.bold,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                Text(
                                  _book.author,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.0,
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    // 展开状态下的大封面与书籍详情元数据
                    if (contentOpacity > 0.01)
                      Positioned(
                        left: 20.0,
                        right: 20.0,
                        bottom: 12.0,
                        child: Opacity(
                          opacity: contentOpacity,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 3D 立体大封面
                              BookCoverWidget(
                                title: _book.title,
                                author: _book.author,
                                coverUrl: _book.coverUrl,
                                width: 96.0,
                                height: 134.0,
                                paletteIndex:
                                    BookCoverWidget.hashTitleToPalette(
                                        _book.title),
                              ),
                              const SizedBox(width: 16.0),
                              // 右侧元数据
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _book.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 20.0,
                                        fontWeight: FontWeight.w800,
                                        color: colors.textPrimary,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 6.0),
                                    Row(
                                      children: [
                                        Icon(Icons.person_outline_rounded,
                                            size: 14.0,
                                            color: colors.textSecondary),
                                        const SizedBox(width: 4.0),
                                        Expanded(
                                          child: Text(
                                            _book.author,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w600,
                                              color: colors.textSecondary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10.0),
                                    Wrap(
                                      spacing: 6.0,
                                      runSpacing: 6.0,
                                      children: [
                                        _buildTag(colors, _book.category),
                                        _buildTag(colors, _book.status),
                                        // 此前写死"已连通 12 组源"，改为展示真实生效的书源
                                        _buildTag(colors, _book.sourceName),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),

          // 2. 三列数据统计卡片 (d-stats)
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: SoftCard(
                colors: colors,
                padding: const EdgeInsets.symmetric(
                    vertical: 14.0, horizontal: 10.0),
                child: Row(
                  children: [
                    _buildStatItem(colors, '状态', _book.status, isGold: false),
                    _buildStatDivider(colors),
                    _buildStatItem(colors, '篇幅', readWordCount, isGold: false),
                    // 书源不提供评分，拿不到真实值就不显示这一格，
                    // 而不是给每本书都挂一个写死的"★ 9.6"
                    if (_book.rating != null) ...[
                      _buildStatDivider(colors),
                      _buildStatItem(colors, '读者评分',
                          '★ ${_book.rating!.toStringAsFixed(1)}',
                          isGold: true),
                    ] else ...[
                      _buildStatDivider(colors),
                      _buildStatItem(colors, '书源', _book.sourceName,
                          isGold: false),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // 3. 双主行动按钮栏 (d-btns)
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
              child: Row(
                children: [
                  // 加入书架 / 已在书架
                  Expanded(
                    flex: 4,
                    child: GestureDetector(
                      key: const ValueKey('detail_shelf_btn'),
                      onTap: _toggleShelf,
                      child: Container(
                        height: 48.0,
                        decoration: BoxDecoration(
                          color: _isInShelf
                              ? colors.accent
                                  .withValues(alpha: isDark ? 0.25 : 0.15)
                              : colors.card,
                          borderRadius: BorderRadius.circular(16.0),
                          border: Border.all(
                            color: _isInShelf ? colors.accent : colors.border,
                            width: _isInShelf ? 1.5 : 1.0,
                          ),
                          boxShadow: SoftDecorations.softShadows(colors,
                              elevation: 0.8),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isInShelf
                                  ? Icons.check_circle_rounded
                                  : Icons.add_rounded,
                              size: 18.0,
                              color: _isInShelf
                                  ? colors.accent
                                  : colors.textPrimary,
                            ),
                            const SizedBox(width: 6.0),
                            Text(
                              _isInShelf ? '已在书架' : '加入书架',
                              style: TextStyle(
                                fontSize: 14.0,
                                fontWeight: FontWeight.bold,
                                color: _isInShelf
                                    ? colors.accent
                                    : colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 14.0),

                  // 开始阅读 / 继续阅读
                  Expanded(
                    flex: 6,
                    child: GestureDetector(
                      key: const ValueKey('detail_read_btn'),
                      onTap: () => _openReader(),
                      child: Container(
                        height: 48.0,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colors.accent,
                              Color.lerp(
                                      colors.accent, Colors.blueAccent, 0.4) ??
                                  colors.accent,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16.0),
                          boxShadow: [
                            BoxShadow(
                              color: colors.accent.withValues(alpha: 0.35),
                              offset: const Offset(0, 4),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _currentChapterIndex > 0
                                  ? '继续阅读 (第${_currentChapterIndex + 1}章)'
                                  : '开始阅读',
                              style: const TextStyle(
                                fontSize: 15.0,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 6.0),
                            const Icon(Icons.play_arrow_rounded,
                                size: 20.0, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. 书籍简介模块
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: SoftCard(
                colors: colors,
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 4.0,
                          height: 14.0,
                          decoration: BoxDecoration(
                            color: colors.accent,
                            borderRadius: BorderRadius.circular(2.0),
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        Text(
                          '作品简介',
                          style: TextStyle(
                            fontSize: 15.0,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        if (_latestUpdateTime != null &&
                            _latestUpdateTime!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8.0, vertical: 3.0),
                            decoration: BoxDecoration(
                              color: colors.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6.0),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.update_rounded,
                                    size: 12.0, color: colors.accent),
                                const SizedBox(width: 3.0),
                                Text(
                                  '更新: $_latestUpdateTime',
                                  style: TextStyle(
                                    fontSize: 11.0,
                                    fontWeight: FontWeight.w600,
                                    color: colors.accent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10.0),
                    Text(
                      _getDisplayIntro(),
                      maxLines: _isIntroExpanded ? 20 : 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.6,
                        color: colors.textSecondary,
                      ),
                    ),
                    if (_book.description.length > 50)
                      GestureDetector(
                        onTap: () => setState(
                            () => _isIntroExpanded = !_isIntroExpanded),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                _isIntroExpanded ? '收起' : '展开全文',
                                style: TextStyle(
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.bold,
                                  color: colors.accent,
                                ),
                              ),
                              Icon(
                                _isIntroExpanded
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                size: 16.0,
                                color: colors.accent,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // 5. 目录头部吸顶组件 (带正倒序切换与章数常驻)
          SliverPersistentHeader(
            pinned: true,
            delegate: _BookDetailTocHeaderDelegate(
              colors: colors,
              totalCount:
                  _chapters.isNotEmpty ? _chapters.length : totalChaptersCount,
              isReversed: _isReversed,
              onToggleReverse: () => setState(() => _isReversed = !_isReversed),
            ),
          ),

          // 章节列表或加载骨架
          if (_isLoadingToc)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20.0, vertical: 20.0),
                child: Center(
                  child: Column(
                    children: [
                      SizedBox(
                        width: 24.0,
                        height: 24.0,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.0, color: colors.accent),
                      ),
                      const SizedBox(height: 10.0),
                      Text('正在从【${_book.sourceName}】同步千章目录...',
                          style: TextStyle(
                              fontSize: 12.0, color: colors.textSecondary)),
                    ],
                  ),
                ),
              ),
            )
          else if (_tocFailed || _chapters.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20.0, vertical: 28.0),
                child: Column(
                  children: [
                    Icon(Icons.cloud_off_rounded,
                        size: 36.0, color: colors.textSecondary),
                    const SizedBox(height: 10.0),
                    Text('目录获取失败',
                        style: TextStyle(
                            fontSize: 14.0,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary)),
                    const SizedBox(height: 6.0),
                    Text('网络不稳定或【${_book.sourceName}】暂未收录本书',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12.0, color: colors.textSecondary)),
                    const SizedBox(height: 14.0),
                    SoftButton(
                      colors: colors,
                      isFilled: true,
                      isPill: true,
                      onPressed: () => _loadToc(forceRefresh: true),
                      child: const Text('重新获取目录'),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20.0, 0.0, 20.0, 8.0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final chapter = displayChapters[index];
                    final rawIndex = chapter.index;
                    final isCurrent = rawIndex == _currentChapterIndex;
                    final isDone = rawIndex < _currentChapterIndex;

                    return GestureDetector(
                      onTap: () => _openReader(chapterIndex: rawIndex),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12.0, horizontal: 14.0),
                        margin: const EdgeInsets.only(bottom: 6.0),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? colors.accent
                                  .withValues(alpha: isDark ? 0.2 : 0.08)
                              : colors.card,
                          borderRadius: BorderRadius.circular(12.0),
                          border: Border.all(
                            color: isCurrent
                                ? colors.accent
                                : colors.border.withValues(alpha: 0.6),
                            width: isCurrent ? 1.2 : 0.8,
                          ),
                        ),
                        child: Row(
                          children: [
                            // 序号
                            SizedBox(
                              width: 32.0,
                              child: Text(
                                '${rawIndex + 1}'.padLeft(2, '0'),
                                style: TextStyle(
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.bold,
                                  color: isCurrent
                                      ? colors.accent
                                      : colors.textSecondary
                                          .withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                            // 标题
                            Expanded(
                              child: Text(
                                chapter.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14.0,
                                  fontWeight: isCurrent
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isCurrent
                                      ? colors.accent
                                      : colors.textPrimary,
                                ),
                              ),
                            ),
                            // 状态微标签
                            if (isCurrent)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6.0, vertical: 2.0),
                                decoration: BoxDecoration(
                                  color: colors.accent,
                                  borderRadius: BorderRadius.circular(6.0),
                                ),
                                child: const Text(
                                  '在读',
                                  style: TextStyle(
                                      fontSize: 10.0,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white),
                                ),
                              )
                            else if (isDone)
                              Icon(Icons.check_circle_outline_rounded,
                                  size: 16.0,
                                  color: colors.textSecondary
                                      .withValues(alpha: 0.4))
                            else
                              Icon(Icons.chevron_right,
                                  size: 16.0,
                                  color: colors.textSecondary
                                      .withValues(alpha: 0.2)),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount:
                      (displayChapters.length > 30 && !_isAllChaptersExpanded)
                          ? 20
                          : displayChapters.length,
                ),
              ),
            ),

            // 渐进式目录展开/收起控制组件
            if (displayChapters.length > 30 && !_isAllChaptersExpanded)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20.0, 4.0, 20.0, 40.0),
                  child: SoftCard(
                    colors: colors,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _isAllChaptersExpanded = true);
                    },
                    padding: const EdgeInsets.symmetric(vertical: 14.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '查看完整目录 (共 ${displayChapters.length} 章)  ▼',
                          style: TextStyle(
                            fontSize: 14.0,
                            fontWeight: FontWeight.w600,
                            color: colors.accent,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (displayChapters.length > 30 && _isAllChaptersExpanded)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 40.0),
                  child: Center(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _isAllChaptersExpanded = false);
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 10.0, horizontal: 20.0),
                        child: Text(
                          '已显示全本全部章节 · 收起 ▲',
                          style: TextStyle(
                            fontSize: 13.0,
                            fontWeight: FontWeight.w500,
                            color: colors.textSecondary,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              )
            else
              const SliverToBoxAdapter(
                child: SizedBox(height: 36.0),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildTag(SoftColors colors, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: colors.border),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.0,
          fontWeight: FontWeight.w600,
          color: colors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildStatItem(SoftColors colors, String label, String val,
      {required bool isGold}) {
    return Expanded(
      child: Column(
        children: [
          Text(
            val,
            style: TextStyle(
              fontSize: 16.0,
              fontWeight: FontWeight.w800,
              color: isGold ? const Color(0xFFF59E0B) : colors.textPrimary,
            ),
          ),
          const SizedBox(height: 4.0),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.0,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider(SoftColors colors) {
    return Container(
      width: 1.0,
      height: 24.0,
      color: colors.border,
    );
  }

  String _getDisplayIntro() {
    if (_book.description.isNotEmpty &&
        !_book.description.contains('全网优质文学精选') &&
        !_book.description.contains('汇聚神作连载')) {
      return _book.description;
    }
    final cleanT = _book.cleanTitle;
    if (cleanT.contains('恶魔') || cleanT.contains('emofaze')) {
      return '一个一无是处的纨绔子弟，一个被家族放弃的废物，在得到了一份恶魔的契约后，他的人生彻底改变。罗林家族的传奇就此拉开序幕！拥有真实西幻世界观、罗林家族纷争、恶魔骑士团等宏大史诗篇章。';
    } else if (cleanT.contains('诡秘')) {
      return '蒸汽与机械的浪潮中，谁能触及非凡？历史和黑暗的迷雾里，又是谁在耳语？我从诡秘中醒来，睁眼看见这个世界：魔药、占卜、诅咒、倒吊人、封印物……';
    } else if (cleanT.contains('道诡')) {
      return '诡异的天道，异常的仙佛，这里到底是真实还是精神病幻觉？李火旺在现代病房与大齐世界之间痛苦求存。';
    }
    return _book.description.isNotEmpty
        ? _book.description
        : '全网优质文学精选，汇聚神作连载与完结名著，支持千章完整目录解析与多书源无缝阅读。';
  }
}

/// 沉浸式吸顶目录工具栏 (SliverPersistentHeaderDelegate)
class _BookDetailTocHeaderDelegate extends SliverPersistentHeaderDelegate {
  final SoftColors colors;
  final int totalCount;
  final bool isReversed;
  final VoidCallback onToggleReverse;

  const _BookDetailTocHeaderDelegate({
    required this.colors,
    required this.totalCount,
    required this.isReversed,
    required this.onToggleReverse,
  });

  @override
  double get minExtent => 46.0;

  @override
  double get maxExtent => 46.0;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final isDark = colors.isDark;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
        child: Container(
          height: 46.0,
          decoration: BoxDecoration(
            color: (isDark ? colors.background : colors.surface)
                .withValues(alpha: isDark ? 0.88 : 0.92),
            border: Border(
              bottom: BorderSide(
                color: colors.border.withValues(alpha: isDark ? 0.3 : 0.5),
                width: 0.8,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            children: [
              Container(
                width: 4.0,
                height: 14.0,
                decoration: BoxDecoration(
                  color: colors.accent,
                  borderRadius: BorderRadius.circular(2.0),
                ),
              ),
              const SizedBox(width: 8.0),
              Text(
                '目录',
                style: TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(width: 8.0),
              Text(
                totalCount > 0 ? '共 $totalCount 章' : '暂未获取',
                style: TextStyle(fontSize: 12.0, color: colors.textSecondary),
              ),
              const Spacer(),
              // 正序/倒序切换按钮
              GestureDetector(
                onTap: onToggleReverse,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10.0, vertical: 4.5),
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(color: colors.border),
                    boxShadow:
                        SoftDecorations.softShadows(colors, elevation: 0.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.swap_vert_rounded,
                          size: 14.0, color: colors.textSecondary),
                      const SizedBox(width: 3.0),
                      Text(
                        isReversed ? '倒序' : '正序',
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _BookDetailTocHeaderDelegate oldDelegate) {
    return oldDelegate.totalCount != totalCount ||
        oldDelegate.isReversed != isReversed ||
        oldDelegate.colors != colors;
  }
}
