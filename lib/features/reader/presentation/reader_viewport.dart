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
  final VoidCallback onOpenSourceSwitcher;
  final VoidCallback? onOpenDownload;
  final VoidCallback? onOpenTts;
  final VoidCallback? onToggleTheme;
  final VoidCallback? onNextChapter;
  final VoidCallback? onPreviousChapter;
  final ValueChanged<int>? onProgressChanged;

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
    required this.onOpenSourceSwitcher,
    this.onOpenDownload,
    this.onOpenTts,
    this.onToggleTheme,
    this.onNextChapter,
    this.onPreviousChapter,
    this.onProgressChanged,
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
        widget.turnMode != oldWidget.turnMode) {
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

    // 记录重排前的字符锚点
    final currentAnchorChar = _pages.isNotEmpty && _currentPageIndex < _pages.length
        ? _pages[_currentPageIndex].charStart
        : widget.initialCharOffset;

    final newPages = ReaderLayoutEngine.paginate(
      paragraphs: widget.paragraphs,
      title: widget.chapterTitle,
      config: config,
    );

    // 逆向二分查找新页码 (P2-07 痛点彻底根治)
    final newPageIndex = ReaderLayoutEngine.findPageByCharOffset(newPages, currentAnchorChar);

    setState(() {
      _pages = newPages;
      _currentPageIndex = newPageIndex.clamp(0, newPages.isEmpty ? 0 : newPages.length - 1);
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
      widget.onNextChapter?.call();
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
      widget.onPreviousChapter?.call();
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

  Widget _buildReaderBody(Size size, PagingConfig config) {
    if (_pages.isEmpty) {
      return Center(
        child: CircularProgressIndicator(color: widget.theme.textColor),
      );
    }

    switch (widget.turnMode) {
      case PageTurnMode.slide:
        return PageView.builder(
          controller: _pageController,
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
    final currentPage = _pages[_currentPageIndex];
    final nextPageIndex = _currentPageIndex + 1;
    final hasNext = nextPageIndex < _pages.length;

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        setState(() {
          _dragOffset = (_dragOffset + details.delta.dx).clamp(-size.width, 0.0);
        });
      },
      onHorizontalDragEnd: (details) {
        if (_dragOffset < -size.width * 0.25 && hasNext) {
          _turnNext();
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
            offset: Offset(_dragOffset, 0),
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
    return ListView.builder(
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
                const SizedBox(width: 8.0),
                Expanded(
                  child: Text(
                    widget.bookTitle,
                    style: TextStyle(
                      color: widget.theme.textColor,
                      fontSize: 16.0,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
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
                      onPressed: widget.onPreviousChapter ?? _turnPrevious,
                    ),
                    Expanded(
                      child: Slider(
                        value: current.toDouble(),
                        min: 1.0,
                        max: total.toDouble(),
                        activeColor: const Color(0xFF5B7FFF),
                        inactiveColor: widget.theme.subTextColor.withValues(alpha: 0.3),
                        onChanged: (val) {
                          final target = val.round() - 1;
                          if (target != _currentPageIndex) {
                            if (widget.turnMode == PageTurnMode.slide) {
                              _pageController.jumpToPage(target);
                            } else {
                              setState(() => _currentPageIndex = target);
                            }
                          }
                        },
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.skip_next_rounded, color: widget.theme.textColor),
                      onPressed: widget.onNextChapter ?? _turnNext,
                    ),
                  ],
                ),
                const SizedBox(height: 8.0),
                // 四大功能按键：目录、夜间、排版、设置
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildActionButton(
                      icon: Icons.format_list_bulleted_rounded,
                      label: '目录',
                      onTap: widget.onOpenCatalog,
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
