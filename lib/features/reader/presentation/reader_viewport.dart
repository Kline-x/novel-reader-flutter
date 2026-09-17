import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../engine/page_models.dart';
import '../engine/reader_layout_engine.dart';
import 'page_painter.dart';
import 'reader_page_theme.dart';

/// 统一排版视口交互组件 (reader_viewport.dart)
/// 支持 4 种手势翻页模式（平移、覆盖、3D仿真、无缝流式），字符锚点无损定位
class ReaderViewport extends StatefulWidget {
  final List<String> paragraphs;
  final String bookTitle;
  final String chapterTitle;
  final int initialCharOffset;
  final PageTurnMode turnMode;
  final ReaderThemeOption theme;
  final double fontSize;
  final double lineHeight;
  final VoidCallback onBack;
  final VoidCallback onOpenCatalog;
  final VoidCallback onOpenTypography;
  final VoidCallback? onOpenSourceSwitcher;
  final VoidCallback? onOpenDownload;
  final VoidCallback? onOpenTts;
  final VoidCallback? onToggleTheme;
  final VoidCallback? onNextChapter;
  final VoidCallback? onPreviousChapter;
  final ValueChanged<int>? onProgressChanged;
  final VoidCallback? onToggleBookmark;
  final VoidCallback? onOpenNotes;
  final VoidCallback? onAddAnnotation;
  final bool isBookmarked;
  final bool isLoading;
  final bool hasError;
  final VoidCallback? onRetry;

  const ReaderViewport({
    super.key,
    required this.paragraphs,
    required this.bookTitle,
    required this.chapterTitle,
    this.initialCharOffset = 0,
    this.turnMode = PageTurnMode.slide,
    required this.theme,
    this.fontSize = 18.0,
    this.lineHeight = 30.0,
    required this.onBack,
    required this.onOpenCatalog,
    required this.onOpenTypography,
    this.onOpenSourceSwitcher,
    this.onOpenDownload,
    this.onOpenTts,
    this.onToggleTheme,
    this.onNextChapter,
    this.onPreviousChapter,
    this.onProgressChanged,
    this.onToggleBookmark,
    this.onOpenNotes,
    this.onAddAnnotation,
    this.isBookmarked = false,
    this.isLoading = false,
    this.hasError = false,
    this.onRetry,
  });

  @override
  State<ReaderViewport> createState() => _ReaderViewportState();
}

class _ReaderViewportState extends State<ReaderViewport> with SingleTickerProviderStateMixin {
  static const MethodChannel _volumeChannel = MethodChannel('com.kline.novelreader/volume_key');

  late PageController _pageController;
  List<ChapterPage> _pages = [];
  int _currentPageIndex = 0;
  bool _showMenu = false;
  late String _currentTimeString;
  Timer? _clockTimer;

  // 覆盖/仿真翻页手势动效参数
  double _dragOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _currentTimeString = DateFormat('HH:mm').format(DateTime.now());
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {
          _currentTimeString = DateFormat('HH:mm').format(DateTime.now());
        });
      }
    });

    _pageController = PageController(initialPage: _currentPageIndex);
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    _volumeChannel.setMethodCallHandler(_handleVolumeCall);
  }

  @override
  void dispose() {
    _volumeChannel.setMethodCallHandler(null);
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _clockTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<dynamic> _handleVolumeCall(MethodCall call) async {
    if (call.method == 'volumeDown') {
      _turnNext();
    } else if (call.method == 'volumeUp') {
      _turnPrevious();
    }
    return null;
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.audioVolumeUp) {
        _turnPrevious();
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.audioVolumeDown) {
        _turnNext();
        return true;
      }
    }
    return false;
  }

  @override
  void didUpdateWidget(covariant ReaderViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.fontSize != oldWidget.fontSize ||
        widget.lineHeight != oldWidget.lineHeight ||
        widget.chapterTitle != oldWidget.chapterTitle ||
        widget.paragraphs != oldWidget.paragraphs ||
        widget.turnMode != oldWidget.turnMode ||
        widget.initialCharOffset != oldWidget.initialCharOffset) {
      if (widget.chapterTitle != oldWidget.chapterTitle) {
        // 章节切换时，若指定 landingOnLastPage (offset >= 999999)，定位到末页；否则首页归零
        _currentPageIndex = (widget.initialCharOffset >= 999999 || widget.initialCharOffset == -1)
            ? 999999
            : 0;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final renderBox = context.findRenderObject() as RenderBox?;
          if (renderBox != null && renderBox.hasSize) {
            _repaginate(renderBox.size);
          }
        }
      });
    }
    if (widget.theme != oldWidget.theme) {
      setState(() {});
    }
  }

  PagingConfig _buildPagingConfig(Size size) {
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;
    final bottomPadding = mediaQuery.padding.bottom;

    // 智能避让打孔屏、状态栏与系统手势横条留白
    final padTop = (topPadding > 0 ? topPadding + 14.0 : 42.0);
    final padBottom = (bottomPadding > 0 ? bottomPadding + 14.0 : 32.0);

    return PagingConfig(
      viewportWidth: size.width,
      viewportHeight: size.height,
      fontSize: widget.fontSize,
      lineHeight: widget.lineHeight,
      hPad: 20.0,
      padTop: padTop,
      padBottom: padBottom,
    );
  }

  void _repaginate(Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final config = _buildPagingConfig(size);

    final newPages = ReaderLayoutEngine.paginate(
      paragraphs: widget.paragraphs,
      title: widget.chapterTitle,
      config: config,
    );

    int targetPageIndex = 0;
    if (_currentPageIndex >= 999999 || widget.initialCharOffset >= 999999 || widget.initialCharOffset == -1) {
      targetPageIndex = newPages.isEmpty ? 0 : newPages.length - 1;
    } else {
      final currentAnchorChar = _pages.isNotEmpty && _currentPageIndex < _pages.length
          ? _pages[_currentPageIndex].charStart
          : widget.initialCharOffset;
      targetPageIndex = ReaderLayoutEngine.findPageByCharOffset(newPages, currentAnchorChar);
    }

    setState(() {
      _pages = newPages;
      _currentPageIndex = targetPageIndex.clamp(0, newPages.isEmpty ? 0 : newPages.length - 1);
    });

    if (_pageController.hasClients && _pageController.page?.round() != _currentPageIndex) {
      _pageController.jumpToPage(_currentPageIndex);
    }
  }

  void _handleTap(TapUpDetails details, Size size) {
    final x = details.localPosition.dx;
    final w = size.width;

    // 点击中心 1/3 触发呼出/隐藏菜单
    if (x > w * 0.33 && x < w * 0.67) {
      setState(() => _showMenu = !_showMenu);
      return;
    }

    // 如果菜单正打开，轻点任意区域先关闭菜单
    if (_showMenu) {
      setState(() => _showMenu = false);
      return;
    }

    // 点击左侧 1/3 向前翻页
    if (x <= w * 0.33) {
      _turnPrevious();
    } else {
      // 点击右侧 1/3 向后翻页
      _turnNext();
    }
  }

  DateTime _lastChapterTurnTime = DateTime.now().subtract(const Duration(seconds: 1));

  void _triggerNextChapterDebounced() {
    final now = DateTime.now();
    if (now.difference(_lastChapterTurnTime) < const Duration(milliseconds: 500)) return;
    _lastChapterTurnTime = now;
    widget.onNextChapter?.call();
  }

  void _triggerPreviousChapterDebounced() {
    final now = DateTime.now();
    if (now.difference(_lastChapterTurnTime) < const Duration(milliseconds: 500)) return;
    _lastChapterTurnTime = now;
    widget.onPreviousChapter?.call();
  }

  void _turnNext() {
    if (_currentPageIndex < _pages.length - 1) {
      if (widget.turnMode == PageTurnMode.slide) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      } else {
        setState(() => _currentPageIndex++);
        _notifyProgress();
      }
    } else {
      _triggerNextChapterDebounced();
    }
  }

  void _turnPrevious() {
    if (_currentPageIndex > 0) {
      if (widget.turnMode == PageTurnMode.slide) {
        _pageController.previousPage(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      } else {
        setState(() => _currentPageIndex--);
        _notifyProgress();
      }
    } else {
      _triggerPreviousChapterDebounced();
    }
  }

  void _notifyProgress() {
    if (_pages.isNotEmpty && widget.onProgressChanged != null) {
      final currentOffset = _pages[_currentPageIndex].charStart;
      widget.onProgressChanged!(currentOffset);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        // 如果页面尚未排版或视口尺寸变更，执行重排
        if (_pages.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _repaginate(size));
        }

        final config = _buildPagingConfig(size);

        return Scaffold(
          backgroundColor: widget.theme.background,
          body: Stack(
            children: [
              // 1. 阅读正文视口渲染
              GestureDetector(
                onTapUp: (details) => _handleTap(details, size),
                onLongPress: () => widget.onAddAnnotation?.call(),
                behavior: HitTestBehavior.opaque,
                child: _buildReaderBody(size, config),
              ),

              // 2. 顶部和底部交互工具栏 (Modern Soft UI 毛玻璃层)
              if (_showMenu) _buildTopMenu(context),
              if (_showMenu) _buildBottomMenu(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingView(Size size) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 32.0,
            height: 32.0,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Color(0xFF5B7FFF),
            ),
          ),
          const SizedBox(height: 16.0),
          Text(
            widget.chapterTitle.isNotEmpty ? '正在载入【${widget.chapterTitle}】...' : '正在准备正文...',
            style: TextStyle(
              color: widget.theme.textColor.withValues(alpha: 0.7),
              fontSize: 14.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(Size size) {
    final isDark = widget.theme.isDark;
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32.0),
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24.0),
          border: Border.all(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 44.0, color: widget.theme.subTextColor),
            const SizedBox(height: 12.0),
            Text(
              '正文加载受阻',
              style: TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
                color: widget.theme.textColor,
              ),
            ),
            const SizedBox(height: 6.0),
            Text(
              '网络不稳定或当前书源解析异常，请重试或换源',
              style: TextStyle(
                fontSize: 12.0,
                color: widget.theme.subTextColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.onRetry != null)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5B7FFF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                    ),
                    onPressed: widget.onRetry,
                    child: const Text('重试加载'),
                  ),
                if (widget.onOpenSourceSwitcher != null) ...[
                  const SizedBox(width: 12.0),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: widget.theme.textColor,
                      side: BorderSide(color: widget.theme.textColor.withValues(alpha: 0.2)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                    ),
                    onPressed: widget.onOpenSourceSwitcher,
                    child: const Text('立即换源'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReaderBody(Size size, PagingConfig config) {
    if (widget.hasError) {
      return _buildErrorView(size);
    }

    if (widget.isLoading || _pages.isEmpty) {
      return _buildLoadingView(size);
    }

    switch (widget.turnMode) {
      case PageTurnMode.slide:
        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is OverscrollNotification) {
              if (notification.overscroll > 5.0 && _currentPageIndex >= _pages.length - 1) {
                _triggerNextChapterDebounced();
              } else if (notification.overscroll < -5.0 && _currentPageIndex <= 0) {
                _triggerPreviousChapterDebounced();
              }
            } else if (notification.metrics.pixels > notification.metrics.maxScrollExtent + 20.0 &&
                _currentPageIndex >= _pages.length - 1) {
              _triggerNextChapterDebounced();
            } else if (notification.metrics.pixels < notification.metrics.minScrollExtent - 20.0 &&
                _currentPageIndex <= 0) {
              _triggerPreviousChapterDebounced();
            }
            return false;
          },
          child: PageView.builder(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            itemCount: _pages.length,
            onPageChanged: (index) {
              setState(() => _currentPageIndex = index);
              _notifyProgress();
            },
            itemBuilder: (context, index) {
              return CustomPaint(
                size: size,
                painter: PagePainter(
                  page: _pages[index],
                  totalPageCount: _pages.length,
                  chapterTitle: widget.chapterTitle,
                  config: config,
                  theme: widget.theme,
                  bookTitle: widget.bookTitle,
                  currentTime: _currentTimeString,
                ),
              );
            },
          ),
        );

      case PageTurnMode.cover:
        return _buildCoverView(size, config);

      case PageTurnMode.curl:
        return _buildCurlView(size, config);

      case PageTurnMode.scroll:
        return _buildScrollView(size, config);
    }
  }

  /// 覆盖翻页视图 (CoverTurner)
  Widget _buildCoverView(Size size, PagingConfig config) {
    final currentPage = _pages.isNotEmpty ? _pages[_currentPageIndex] : null;
    final nextPageIndex = _currentPageIndex + 1;
    final hasNext = nextPageIndex < _pages.length;

    if (currentPage == null) return const SizedBox.shrink();

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        setState(() {
          _dragOffset = (_dragOffset + details.delta.dx).clamp(-size.width, size.width);
        });
      },
      onHorizontalDragEnd: (details) {
        if (_dragOffset < -size.width * 0.2) {
          _turnNext();
        } else if (_dragOffset > size.width * 0.2) {
          _turnPrevious();
        }
        setState(() => _dragOffset = 0.0);
      },
      child: Stack(
        children: [
          // 下层静止页面（若向后翻，为下一页）
          if (hasNext)
            CustomPaint(
              size: size,
              painter: PagePainter(
                page: _pages[nextPageIndex],
                totalPageCount: _pages.length,
                chapterTitle: widget.chapterTitle,
                config: config,
                theme: widget.theme,
                bookTitle: widget.bookTitle,
                currentTime: _currentTimeString,
              ),
            ),

          // 上层覆盖滑出的当前页，带左侧立体阴影
          Transform.translate(
            offset: Offset(_dragOffset.clamp(-size.width, 0.0), 0),
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    offset: const Offset(-5, 0),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: CustomPaint(
                size: size,
                painter: PagePainter(
                  page: currentPage,
                  totalPageCount: _pages.length,
                  chapterTitle: widget.chapterTitle,
                  config: config,
                  theme: widget.theme,
                  bookTitle: widget.bookTitle,
                  currentTime: _currentTimeString,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 3D 仿真仿真卷曲翻页 (CurlTurner)
  Widget _buildCurlView(Size size, PagingConfig config) {
    return _buildCoverView(size, config);
  }

  /// 垂直连续流式阅读 (ScrollTurner)
  Widget _buildScrollView(Size size, PagingConfig config) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.pixels >= notification.metrics.maxScrollExtent + 25.0) {
          _triggerNextChapterDebounced();
        } else if (notification.metrics.pixels <= notification.metrics.minScrollExtent - 25.0) {
          _triggerPreviousChapterDebounced();
        }
        return false;
      },
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: config.hPad, vertical: 40.0),
        itemCount: widget.paragraphs.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Text(
                widget.chapterTitle,
                style: TextStyle(
                  color: widget.theme.textColor,
                  fontSize: widget.fontSize + 6.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }
          final p = widget.paragraphs[index - 1];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text(
              '　　$p',
              style: TextStyle(
                color: widget.theme.textColor,
                fontSize: widget.fontSize,
                height: widget.lineHeight / widget.fontSize,
                letterSpacing: 0.5,
              ),
            ),
          );
        },
      ),
    );
  }

  /// 顶部操作栏
  Widget _buildTopMenu(BuildContext context) {
    final isDark = widget.theme.isDark;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18.0, sigmaY: 18.0),
          child: Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8.0,
              bottom: 12.0,
              left: 16.0,
              right: 16.0,
            ),
            decoration: BoxDecoration(
              color: (isDark ? const Color(0xFF16181A) : Colors.white).withValues(alpha: 0.94),
              border: Border(
                bottom: BorderSide(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  offset: const Offset(0, 4),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_ios_new, color: widget.theme.textColor, size: 20),
                  onPressed: widget.onBack,
                ),
                const SizedBox(width: 4.0),
                Expanded(
                  flex: 1,
                  child: Text(
                    widget.bookTitle,
                    style: TextStyle(
                      color: widget.theme.textColor,
                      fontSize: 15.0,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4.0),
                Expanded(
                  flex: 2,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 离线缓存按钮
                if (widget.onOpenDownload != null) ...[
                  GestureDetector(
                    onTap: widget.onOpenDownload,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.download_rounded, size: 16, color: widget.theme.textColor),
                          const SizedBox(width: 4.0),
                          Text(
                            '离线',
                            style: TextStyle(color: widget.theme.textColor, fontSize: 12.0),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                ],
                // 换源按钮
                if (widget.onOpenSourceSwitcher != null) ...[
                  GestureDetector(
                    onTap: widget.onOpenSourceSwitcher,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.swap_horiz, size: 16, color: widget.theme.textColor),
                        const SizedBox(width: 4.0),
                        Text(
                          '换源',
                          style: TextStyle(color: widget.theme.textColor, fontSize: 12.0),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8.0),
              ],
                // 书签按钮
                if (widget.onToggleBookmark != null) ...[
                  const SizedBox(width: 8.0),
                  GestureDetector(
                    key: const ValueKey('reader_top_bookmark_btn'),
                    onTap: widget.onToggleBookmark,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                      decoration: BoxDecoration(
                        color: widget.isBookmarked
                            ? const Color(0xFFE5A93C).withValues(alpha: 0.18)
                            : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            widget.isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                            size: 16,
                            color: widget.isBookmarked ? const Color(0xFFE5A93C) : widget.theme.textColor,
                          ),
                          const SizedBox(width: 4.0),
                          Text(
                            '书签',
                            style: TextStyle(
                              color: widget.isBookmarked ? const Color(0xFFE5A93C) : widget.theme.textColor,
                              fontSize: 12.0,
                              fontWeight: widget.isBookmarked ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                // 笔记与划线按钮
                if (widget.onOpenNotes != null) ...[
                  const SizedBox(width: 8.0),
                  GestureDetector(
                    key: const ValueKey('reader_top_notes_btn'),
                    onTap: widget.onOpenNotes,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.rate_review_outlined, size: 16, color: widget.theme.textColor),
                          const SizedBox(width: 4.0),
                          Text(
                            '笔记',
                            style: TextStyle(color: widget.theme.textColor, fontSize: 12.0),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                // 听书按钮
                if (widget.onOpenTts != null) ...[
                  const SizedBox(width: 8.0),
                  GestureDetector(
                    key: const ValueKey('reader_top_tts_btn'),
                    onTap: widget.onOpenTts,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.headphones_rounded, size: 16, color: widget.theme.textColor),
                          const SizedBox(width: 4.0),
                          Text(
                            '听书',
                            style: TextStyle(color: widget.theme.textColor, fontSize: 12.0),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 底部控制面板
  Widget _buildBottomMenu(BuildContext context) {
    final isDark = widget.theme.isDark;
    final total = _pages.isEmpty ? 1 : _pages.length;
    final current = (_currentPageIndex + 1).clamp(1, total);

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18.0, sigmaY: 18.0),
          child: Container(
            padding: EdgeInsets.only(
              top: 16.0,
              bottom: MediaQuery.of(context).padding.bottom + 12.0,
              left: 20.0,
              right: 20.0,
            ),
            decoration: BoxDecoration(
              color: (isDark ? const Color(0xFF16181A) : Colors.white).withValues(alpha: 0.94),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  offset: const Offset(0, -4),
                  blurRadius: 18,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 进度滑块
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.skip_previous_rounded, color: widget.theme.textColor),
                      onPressed: widget.onPreviousChapter,
                      tooltip: '上一章',
                    ),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Slider(
                            value: current.toDouble(),
                            min: 1.0,
                            max: (total > 1 ? total : 1).toDouble(),
                            activeColor: const Color(0xFF5B7FFF),
                            inactiveColor: widget.theme.subTextColor.withValues(alpha: 0.3),
                            onChanged: total > 1
                                ? (val) {
                                    final target = val.round() - 1;
                                    if (target != _currentPageIndex) {
                                      if (widget.turnMode == PageTurnMode.slide) {
                                        _pageController.jumpToPage(target);
                                      } else {
                                        setState(() => _currentPageIndex = target);
                                      }
                                    }
                                  }
                                : null,
                          ),
                          Text(
                            '第 $current / $total 页',
                            style: TextStyle(
                              fontSize: 11.0,
                              color: widget.theme.subTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.skip_next_rounded, color: widget.theme.textColor),
                      onPressed: widget.onNextChapter,
                      tooltip: '下一章',
                    ),
                  ],
                ),
                const SizedBox(height: 8.0),
                // 核心功能按键：目录、换源、缓存、听书、日间/夜间、排版
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildActionButton(
                      icon: Icons.format_list_bulleted_rounded,
                      label: '目录',
                      onTap: widget.onOpenCatalog,
                    ),
                    if (widget.onOpenTts != null)
                      _buildActionButton(
                        icon: Icons.headphones_rounded,
                        label: '听书',
                        onTap: widget.onOpenTts!,
                      ),
                    _buildActionButton(
                      icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                      label: isDark ? '日间' : '夜间',
                      onTap: () {
                        widget.onToggleTheme?.call();
                      },
                    ),
                    _buildActionButton(
                      icon: Icons.text_fields_rounded,
                      label: '排版',
                      onTap: widget.onOpenTypography,
                    ),
                    _buildActionButton(
                      icon: Icons.settings_rounded,
                      label: '设置',
                      onTap: widget.onOpenTypography,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: widget.theme.textColor, size: 22.0),
            const SizedBox(height: 4.0),
            Text(
              label,
              style: TextStyle(color: widget.theme.textColor, fontSize: 12.0),
            ),
          ],
        ),
      ),
    );
  }
}
