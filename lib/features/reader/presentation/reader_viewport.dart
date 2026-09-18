import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../notes/models/annotation.dart';
import '../data/storage_service.dart';
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
  final VoidCallback? onAddToShelf;
  final bool isInShelf;
  final List<Annotation> annotations;
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
    this.onAddToShelf,
    this.isInShelf = false,
    this.annotations = const [],
    this.isBookmarked = false,
    this.isLoading = false,
    this.hasError = false,
    this.onRetry,
  });

  @override
  State<ReaderViewport> createState() => _ReaderViewportState();
}

class _ReaderViewportState extends State<ReaderViewport>
    with SingleTickerProviderStateMixin {
  static const MethodChannel _volumeChannel =
      MethodChannel('com.kline.novelreader/volume_key');

  late PageController _pageController;
  late AnimationController _turnAnimController;
  int _animDirection = 1; // 1: 下一页, -1: 上一页
  List<ChapterPage> _pages = [];
  int _currentPageIndex = 0;
  int _activeCharOffset = 0;
  bool _showMenu = false;
  late String _currentTimeString;
  Timer? _clockTimer;

  // 覆盖/仿真翻页手势动效参数
  double _dragOffset = 0.0;

  // 滚动流式阅读模式的进度上报（此前该模式完全不上报进度，退出后回到章首）
  final ScrollController _scrollController = ScrollController();
  DateTime _lastScrollReport = DateTime.fromMillisecondsSinceEpoch(0);

  // 真实电量（null = 当前平台取不到，此时页脚不渲染电量，杜绝写死的 85% 假数据）
  static const MethodChannel _deviceChannel =
      MethodChannel('com.kline.novelreader/app_update');
  double? _batteryLevel;
  Timer? _batteryTimer;
  final StorageService _storageService = StorageService();
  bool _volumeKeyPagingEnabled = true;

  @override
  void initState() {
    super.initState();
    _activeCharOffset = widget.initialCharOffset;
    _currentTimeString = DateFormat('HH:mm').format(DateTime.now());
    _loadReaderPreferences();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {
          _currentTimeString = DateFormat('HH:mm').format(DateTime.now());
        });
      }
    });

    _turnAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );

    _refreshBatteryLevel();
    _batteryTimer = Timer.periodic(
        const Duration(minutes: 1), (_) => _refreshBatteryLevel());

    _pageController = PageController(initialPage: _currentPageIndex);
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    _volumeChannel.setMethodCallHandler(_handleVolumeCall);
  }

  /// 读取宿主平台真实电量；取不到就保持 null，页脚不显示电量
  Future<void> _refreshBatteryLevel() async {
    try {
      final level = await _deviceChannel.invokeMethod<int>('getBatteryLevel');
      if (!mounted) return;
      final normalized =
          (level == null || level < 0 || level > 100) ? null : level / 100.0;
      if (normalized != _batteryLevel) {
        setState(() => _batteryLevel = normalized);
      }
    } catch (_) {
      // 非 Android 平台或通道未实现：静默保持 null
    }
  }

  Future<void> _loadReaderPreferences() async {
    try {
      final enabled = await _storageService.getVolumeKeyPaging();
      if (mounted) {
        setState(() {
          _volumeKeyPagingEnabled = enabled;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _volumeChannel.setMethodCallHandler(null);
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _clockTimer?.cancel();
    _batteryTimer?.cancel();
    _turnAnimController.dispose();
    _pageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<dynamic> _handleVolumeCall(MethodCall call) async {
    if (!_volumeKeyPagingEnabled) return null;
    if (call.method == 'volumeDown') {
      _turnNext();
    } else if (call.method == 'volumeUp') {
      _turnPrevious();
    }
    return null;
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (!_volumeKeyPagingEnabled) return false;
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
      if (widget.chapterTitle != oldWidget.chapterTitle ||
          widget.initialCharOffset != oldWidget.initialCharOffset) {
        _activeCharOffset = widget.initialCharOffset;
        if (widget.initialCharOffset >= 999999 ||
            widget.initialCharOffset == -1) {
          _currentPageIndex = 999999;
        }
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

    // 智能避让打孔屏/状态栏与系统手势横条留白 (解决 1.3 / T2 / T3 / T4)
    final safeTop = topPadding > 0 ? topPadding : 32.0;
    final safeBottom = bottomPadding > 0 ? bottomPadding : 16.0;

    // 状态栏 + 页眉高度与呼吸留白，避让居中挖孔摄像头
    final padTop = safeTop + 36.0;
    // 底部手势安全区 + 页脚高度与呼吸留白，避免末行正文紧贴页码
    final padBottom = safeBottom + 28.0;

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
    final anchor =
        _activeCharOffset >= 0 ? _activeCharOffset : widget.initialCharOffset;
    if (_currentPageIndex >= 999999 || anchor >= 999999 || anchor == -1) {
      targetPageIndex = newPages.isEmpty ? 0 : newPages.length - 1;
    } else {
      targetPageIndex =
          ReaderLayoutEngine.findPageByCharOffset(newPages, anchor);
    }

    final newIndex =
        targetPageIndex.clamp(0, newPages.isEmpty ? 0 : newPages.length - 1);
    if (newPages.isNotEmpty && newIndex < newPages.length) {
      _activeCharOffset = newPages[newIndex].charStart;
    }

    setState(() {
      _pages = newPages;
      _currentPageIndex = newIndex;
      if (!_pageController.hasClients) {
        _pageController.dispose();
        _pageController = PageController(initialPage: _currentPageIndex);
      }
    });

    if (_pageController.hasClients) {
      _pageController.jumpToPage(_currentPageIndex);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_pageController.hasClients &&
          _pageController.page?.round() != _currentPageIndex) {
        _pageController.jumpToPage(_currentPageIndex);
      }
      _restoreScrollAnchor(anchor);
    });
  }

  /// 滚动流式模式下按 charOffset 还原滚动位置
  void _restoreScrollAnchor(int anchor) {
    if (widget.turnMode != PageTurnMode.scroll) return;
    if (!_scrollController.hasClients) return;
    if (anchor <= 0) return;

    final total = _totalCharsOfChapter;
    if (total <= 0) return;

    final extent = _scrollController.position.maxScrollExtent;
    if (extent <= 0) return;

    final fraction = anchor >= 999999
        ? 1.0
        : (anchor / total).clamp(0.0, 1.0);
    _scrollController.jumpTo(extent * fraction);
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

  DateTime _lastChapterTurnTime =
      DateTime.now().subtract(const Duration(seconds: 1));

  void _triggerNextChapterDebounced() {
    final now = DateTime.now();
    if (now.difference(_lastChapterTurnTime) <
        const Duration(milliseconds: 500)) {
      return;
    }
    _lastChapterTurnTime = now;
    widget.onNextChapter?.call();
  }

  void _triggerPreviousChapterDebounced() {
    final now = DateTime.now();
    if (now.difference(_lastChapterTurnTime) <
        const Duration(milliseconds: 500)) {
      return;
    }
    _lastChapterTurnTime = now;
    widget.onPreviousChapter?.call();
  }

  void _turnNext() {
    if (_turnAnimController.isAnimating) return;
    if (_currentPageIndex < _pages.length - 1) {
      if (widget.turnMode == PageTurnMode.slide) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      } else {
        _animDirection = 1;
        _turnAnimController.forward(from: 0.0).then((_) {
          if (!mounted) return;
          setState(() {
            _currentPageIndex++;
            _dragOffset = 0.0;
          });
          _turnAnimController.reset();
          _notifyProgress();
        });
      }
    } else {
      _triggerNextChapterDebounced();
    }
  }

  void _turnPrevious() {
    if (_turnAnimController.isAnimating) return;
    if (_currentPageIndex > 0) {
      if (widget.turnMode == PageTurnMode.slide) {
        _pageController.previousPage(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      } else {
        _animDirection = -1;
        _turnAnimController.forward(from: 0.0).then((_) {
          if (!mounted) return;
          setState(() {
            _currentPageIndex--;
            _dragOffset = 0.0;
          });
          _turnAnimController.reset();
          _notifyProgress();
        });
      }
    } else {
      _triggerPreviousChapterDebounced();
    }
  }

  void _notifyProgress() {
    if (_pages.isNotEmpty && _currentPageIndex < _pages.length) {
      final currentOffset = _pages[_currentPageIndex].charStart;
      _activeCharOffset = currentOffset;
      if (widget.onProgressChanged != null) {
        widget.onProgressChanged!(currentOffset);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        // 如果页面尚未排版或视口尺寸变更，执行重排
        if (_pages.isEmpty) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _repaginate(size));
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
            widget.chapterTitle.isNotEmpty
                ? '正在载入【${widget.chapterTitle}】...'
                : '正在准备正文...',
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
          border: Border.all(
              color: (isDark ? Colors.white : Colors.black)
                  .withValues(alpha: 0.08)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded,
                size: 44.0, color: widget.theme.subTextColor),
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
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0)),
                    ),
                    onPressed: widget.onRetry,
                    child: const Text('重试加载'),
                  ),
                if (widget.onOpenSourceSwitcher != null) ...[
                  const SizedBox(width: 12.0),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: widget.theme.textColor,
                      side: BorderSide(
                          color: widget.theme.textColor.withValues(alpha: 0.2)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0)),
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
              if (notification.overscroll > 5.0 &&
                  _currentPageIndex >= _pages.length - 1) {
                _triggerNextChapterDebounced();
              } else if (notification.overscroll < -5.0 &&
                  _currentPageIndex <= 0) {
                _triggerPreviousChapterDebounced();
              }
            } else if (notification.metrics.pixels >
                    notification.metrics.maxScrollExtent + 20.0 &&
                _currentPageIndex >= _pages.length - 1) {
              _triggerNextChapterDebounced();
            } else if (notification.metrics.pixels <
                    notification.metrics.minScrollExtent - 20.0 &&
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
                  batteryLevel: _batteryLevel,
                  annotations: widget.annotations,
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
    if (_pages.isEmpty) return const SizedBox.shrink();
    final currentPage = _pages[_currentPageIndex];
    final nextPageIndex = _currentPageIndex + 1;
    final prevPageIndex = _currentPageIndex - 1;
    final hasNext = nextPageIndex < _pages.length;
    final hasPrev = prevPageIndex >= 0;

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (_turnAnimController.isAnimating) return;
        setState(() {
          _dragOffset =
              (_dragOffset + details.delta.dx).clamp(-size.width, size.width);
        });
      },
      onHorizontalDragEnd: (details) {
        if (_turnAnimController.isAnimating) return;
        if (_dragOffset < -size.width * 0.15) {
          _turnNext();
        } else if (_dragOffset > size.width * 0.15) {
          _turnPrevious();
        } else {
          setState(() => _dragOffset = 0.0);
        }
      },
      child: AnimatedBuilder(
        animation: _turnAnimController,
        builder: (context, _) {
          final animVal = _turnAnimController.value;
          double offset = _dragOffset;
          if (_turnAnimController.isAnimating) {
            if (_animDirection == 1) {
              offset = -animVal * size.width;
            } else {
              offset = (-1.0 + animVal) * size.width;
            }
          }

          final isPrev = _animDirection == -1 &&
              (_turnAnimController.isAnimating || _dragOffset > 0);

          if (isPrev) {
            return Stack(
              children: [
                CustomPaint(
                  size: size,
                  painter: PagePainter(
                    page: currentPage,
                    totalPageCount: _pages.length,
                    chapterTitle: widget.chapterTitle,
                    config: config,
                    theme: widget.theme,
                    bookTitle: widget.bookTitle,
                    currentTime: _currentTimeString,
                    batteryLevel: _batteryLevel,
                    annotations: widget.annotations,
                  ),
                ),
                if (hasPrev)
                  Transform.translate(
                    offset: Offset(offset, 0),
                    child: Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            offset: const Offset(4, 0),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: CustomPaint(
                        size: size,
                        painter: PagePainter(
                          page: _pages[prevPageIndex],
                          totalPageCount: _pages.length,
                          chapterTitle: widget.chapterTitle,
                          config: config,
                          theme: widget.theme,
                          bookTitle: widget.bookTitle,
                          currentTime: _currentTimeString,
                          batteryLevel: _batteryLevel,
                          annotations: widget.annotations,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          }

          return Stack(
            children: [
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
                    batteryLevel: _batteryLevel,
                    annotations: widget.annotations,
                  ),
                ),
              Transform.translate(
                offset: Offset(offset.clamp(-size.width, 0.0), 0),
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
                      batteryLevel: _batteryLevel,
                      annotations: widget.annotations,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 3D 仿真仿真卷曲翻页 (CurlTurner)
  Widget _buildCurlView(Size size, PagingConfig config) {
    if (_pages.isEmpty) return const SizedBox.shrink();
    final currentPage = _pages[_currentPageIndex];
    final nextPageIndex = _currentPageIndex + 1;
    final prevPageIndex = _currentPageIndex - 1;
    final hasNext = nextPageIndex < _pages.length;
    final hasPrev = prevPageIndex >= 0;

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (_turnAnimController.isAnimating) return;
        setState(() {
          _dragOffset =
              (_dragOffset + details.delta.dx).clamp(-size.width, size.width);
        });
      },
      onHorizontalDragEnd: (details) {
        if (_turnAnimController.isAnimating) return;
        if (_dragOffset < -size.width * 0.15) {
          _turnNext();
        } else if (_dragOffset > size.width * 0.15) {
          _turnPrevious();
        } else {
          setState(() => _dragOffset = 0.0);
        }
      },
      child: AnimatedBuilder(
        animation: _turnAnimController,
        builder: (context, _) {
          double progress = 0.0;
          if (_turnAnimController.isAnimating) {
            progress = _turnAnimController.value;
          } else if (_dragOffset != 0.0) {
            progress = (_dragOffset.abs() / size.width).clamp(0.0, 1.0);
          }

          final isPrev = _animDirection == -1 &&
              (_turnAnimController.isAnimating || _dragOffset > 0);

          if (isPrev) {
            final angle = (1.0 - progress) * (3.14159 / 2.0);
            return Stack(
              children: [
                CustomPaint(
                  size: size,
                  painter: PagePainter(
                    page: currentPage,
                    totalPageCount: _pages.length,
                    chapterTitle: widget.chapterTitle,
                    config: config,
                    theme: widget.theme,
                    bookTitle: widget.bookTitle,
                    currentTime: _currentTimeString,
                    batteryLevel: _batteryLevel,
                    annotations: widget.annotations,
                  ),
                ),
                if (hasPrev)
                  Transform(
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateY(-angle),
                    alignment: Alignment.centerLeft,
                    child: Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                                alpha:
                                    (0.3 * (1.0 - progress)).clamp(0.0, 0.3)),
                            offset: const Offset(4, 0),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: CustomPaint(
                        size: size,
                        painter: PagePainter(
                          page: _pages[prevPageIndex],
                          totalPageCount: _pages.length,
                          chapterTitle: widget.chapterTitle,
                          config: config,
                          theme: widget.theme,
                          bookTitle: widget.bookTitle,
                          currentTime: _currentTimeString,
                          batteryLevel: _batteryLevel,
                          annotations: widget.annotations,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          }

          final angle = progress * (3.14159 / 2.0);
          return Stack(
            children: [
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
                    batteryLevel: _batteryLevel,
                    annotations: widget.annotations,
                  ),
                ),
              Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(-angle),
                alignment: Alignment.centerLeft,
                child: Container(
                  foregroundDecoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.black.withValues(
                            alpha: (0.12 * progress).clamp(0.0, 0.2)),
                        Colors.transparent,
                        Colors.black.withValues(
                            alpha: (0.22 * progress).clamp(0.0, 0.28)),
                      ],
                    ),
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
                      batteryLevel: _batteryLevel,
                      annotations: widget.annotations,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 章节正文的总字符数，与排版引擎的 charOffset 坐标系一致
  /// （每段经 normalizeParagraph 后会附加 2 个全角空格缩进）
  int get _totalCharsOfChapter {
    var total = 0;
    for (final p in widget.paragraphs) {
      final trimmed = p.trim();
      if (trimmed.isEmpty) continue;
      total += trimmed.startsWith('　　')
          ? trimmed.length
          : trimmed.length + 2;
    }
    return total;
  }

  /// 滚动模式下按滚动比例换算 charOffset 并节流上报，保证退出后能回到原位
  void _reportScrollProgress(ScrollMetrics metrics) {
    final now = DateTime.now();
    if (now.difference(_lastScrollReport) < const Duration(milliseconds: 400)) {
      return;
    }
    _lastScrollReport = now;

    final total = _totalCharsOfChapter;
    if (total <= 0) return;

    final extent = metrics.maxScrollExtent;
    final fraction =
        extent <= 0 ? 0.0 : (metrics.pixels / extent).clamp(0.0, 1.0);
    final offset = (total * fraction).round().clamp(0, total);

    _activeCharOffset = offset;
    widget.onProgressChanged?.call(offset);
  }

  /// 垂直连续流式阅读 (ScrollTurner)
  Widget _buildScrollView(Size size, PagingConfig config) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.pixels >=
            notification.metrics.maxScrollExtent + 25.0) {
          _triggerNextChapterDebounced();
        } else if (notification.metrics.pixels <=
            notification.metrics.minScrollExtent - 25.0) {
          _triggerPreviousChapterDebounced();
        } else if (notification is ScrollUpdateNotification ||
            notification is ScrollEndNotification) {
          _reportScrollProgress(notification.metrics);
        }
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
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
              bottom: 10.0,
              left: 8.0,
              right: 8.0,
            ),
            decoration: BoxDecoration(
              color: (isDark ? const Color(0xFF16181A) : Colors.white)
                  .withValues(alpha: 0.94),
              border: Border(
                bottom: BorderSide(
                  color: (isDark ? Colors.white : Colors.black)
                      .withValues(alpha: 0.08),
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
                GestureDetector(
                  onTap: widget.onBack,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 32.0,
                    height: 32.0,
                    alignment: Alignment.center,
                    child: Icon(Icons.arrow_back_ios_new,
                        color: widget.theme.textColor, size: 18),
                  ),
                ),
                const SizedBox(width: 4.0),
                Expanded(
                  child: Text(
                    widget.bookTitle,
                    style: TextStyle(
                      color: widget.theme.textColor,
                      fontSize: 14.0,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6.0),
                // 右侧功能胶囊排布区：紧凑自适应排布，确保在任何屏宽下「书签」胶囊完整展现 (解决 3.1)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: false,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 加书架 / 已入架
                      if (widget.onAddToShelf != null) ...[
                        GestureDetector(
                          key: const ValueKey('reader_top_shelf_btn'),
                          onTap: widget.isInShelf ? null : widget.onAddToShelf,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5.0, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: widget.isInShelf
                                  ? (isDark
                                      ? Colors.white12
                                      : Colors.black.withValues(alpha: 0.05))
                                  : const Color(0xFF07C160)
                                      .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  widget.isInShelf
                                      ? Icons.check_circle_outline
                                      : Icons.bookmark_add_outlined,
                                  size: 13.5,
                                  color: widget.isInShelf
                                      ? const Color(0xFF07C160)
                                      : widget.theme.textColor,
                                ),
                                const SizedBox(width: 2.0),
                                Text(
                                  widget.isInShelf ? '已入架' : '加书架',
                                  style: TextStyle(
                                    color: widget.isInShelf
                                        ? const Color(0xFF07C160)
                                        : widget.theme.textColor,
                                    fontSize: 10.0,
                                    fontWeight: widget.isInShelf
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 3.0),
                      ],
                      // 换源按钮
                      if (widget.onOpenSourceSwitcher != null) ...[
                        GestureDetector(
                          key: const ValueKey('reader_top_source_btn'),
                          onTap: widget.onOpenSourceSwitcher,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5.0, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: (isDark ? Colors.white : Colors.black)
                                  .withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.swap_horiz_rounded,
                                    size: 14.0, color: widget.theme.textColor),
                                const SizedBox(width: 2.0),
                                Text(
                                  '换源',
                                  style: TextStyle(
                                      color: widget.theme.textColor,
                                      fontSize: 10.0),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 3.0),
                      ],
                      // 笔记与划线按钮
                      if (widget.onOpenNotes != null) ...[
                        GestureDetector(
                          key: const ValueKey('reader_top_notes_btn'),
                          onTap: widget.onOpenNotes,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5.0, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: (isDark ? Colors.white : Colors.black)
                                  .withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.rate_review_outlined,
                                    size: 13.5, color: widget.theme.textColor),
                                const SizedBox(width: 2.0),
                                Text(
                                  '笔记',
                                  style: TextStyle(
                                      color: widget.theme.textColor,
                                      fontSize: 10.0),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 3.0),
                      ],
                      // 书签按钮
                      if (widget.onToggleBookmark != null) ...[
                        GestureDetector(
                          key: const ValueKey('reader_top_bookmark_btn'),
                          onTap: widget.onToggleBookmark,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5.0, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: widget.isBookmarked
                                  ? const Color(0xFFE5A93C)
                                      .withValues(alpha: 0.18)
                                  : (isDark ? Colors.white : Colors.black)
                                      .withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  widget.isBookmarked
                                      ? Icons.bookmark_rounded
                                      : Icons.bookmark_border_rounded,
                                  size: 13.5,
                                  color: widget.isBookmarked
                                      ? const Color(0xFFE5A93C)
                                      : widget.theme.textColor,
                                ),
                                const SizedBox(width: 2.0),
                                Text(
                                  '书签',
                                  style: TextStyle(
                                    color: widget.isBookmarked
                                        ? const Color(0xFFE5A93C)
                                        : widget.theme.textColor,
                                    fontSize: 10.0,
                                    fontWeight: widget.isBookmarked
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 3.0),
                      ],
                      // 离线缓存按钮
                      if (widget.onOpenDownload != null) ...[
                        GestureDetector(
                          onTap: widget.onOpenDownload,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5.0, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: (isDark ? Colors.white : Colors.black)
                                  .withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.download_rounded,
                                    size: 13.5, color: widget.theme.textColor),
                                const SizedBox(width: 2.0),
                                Text(
                                  '离线',
                                  style: TextStyle(
                                      color: widget.theme.textColor,
                                      fontSize: 10.0),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
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
              color: (isDark ? const Color(0xFF16181A) : Colors.white)
                  .withValues(alpha: 0.94),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24.0)),
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
                      icon: Icon(Icons.skip_previous_rounded,
                          color: widget.theme.textColor),
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
                            inactiveColor: widget.theme.subTextColor
                                .withValues(alpha: 0.3),
                            onChanged: total > 1
                                ? (val) {
                                    final target = val.round() - 1;
                                    if (target != _currentPageIndex) {
                                      if (widget.turnMode ==
                                          PageTurnMode.slide) {
                                        _pageController.jumpToPage(target);
                                      } else {
                                        setState(
                                            () => _currentPageIndex = target);
                                        // 非 slide 模式不会触发 onPageChanged，
                                        // 需手动上报进度，否则拖动滑块后进度不落盘
                                        _notifyProgress();
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
                      icon: Icon(Icons.skip_next_rounded,
                          color: widget.theme.textColor),
                      onPressed: widget.onNextChapter,
                      tooltip: '下一章',
                    ),
                  ],
                ),
                const SizedBox(height: 8.0),
                // 核心功能按键：目录、听书、日间/夜间、排版
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
                      icon: isDark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
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
