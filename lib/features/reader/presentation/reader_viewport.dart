import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../notes/models/annotation.dart';
import '../../../core/theme/soft_theme.dart';
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
  /// 进度变更回调：除字符偏移外，一并回传当前页首行文本，
  /// 供书签摘要使用——此前书签摘要恒为本章第一段，列表里根本分不出是哪一页。
  final void Function(int charOffset, String pageSnippet)? onProgressChanged;
  final VoidCallback? onToggleBookmark;
  final VoidCallback? onOpenNotes;
  /// 长按划线回调：带上用户真正按到的文本与起止字符区间（保持三参数向下兼容）
  final void Function(String text, int charStart, int charEnd)? onAddAnnotation;
  /// 多维选区回调：提供字/句/段四维候选与微调上下文
  final void Function(AnnotationSelectionContext selectionContext)? onAddAnnotationContext;
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
    this.onAddAnnotationContext,
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
          widget.initialCharOffset != oldWidget.initialCharOffset ||
          (oldWidget.paragraphs.isEmpty && widget.paragraphs.isNotEmpty)) {
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
    // 底部手势安全区 + 页脚高度与呼吸留白，避免末行正文紧贴页码。
    // 此前额外留 28px，叠加整数行截断的富余后，末段结束到页脚常空出 4~5 行；
    // 收紧到 16px，正文得以多排一行，观感更饱满。
    final padBottom = safeBottom + 16.0;

    return PagingConfig(
      viewportWidth: size.width,
      viewportHeight: size.height,
      fontSize: widget.fontSize,
      lineHeight: widget.lineHeight,
      hPad: 20.0,
      padTop: padTop,
      padBottom: padBottom,
      // 章末标记本身只占一行左右，此前预留 48px 造成末页额外空出两行
      endMarkHeight: 20.0,
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

    // 严禁在此处同步调用 jumpToPage，避免因底层 PageView 尺寸尚未更新被强行 clamp 到 0！
    // 统一交由 postFrameCallback 在完成 layout 后安全执行。
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
  ///
  /// ListView 首帧往往还没完成布局，maxScrollExtent 仍是 0，
  /// 此前直接 return 导致还原被静默跳过、重进永远停在章首。
  /// 这里改为跨帧重试，直到拿到有效的 maxScrollExtent 为止。
  void _restoreScrollAnchor(int anchor, {int attempt = 0}) {
    if (widget.turnMode != PageTurnMode.scroll) return;
    if (anchor <= 0) return;
    if (attempt > 12) return;

    final total = _totalCharsOfChapter;
    if (total <= 0) return;

    if (!_scrollController.hasClients ||
        _scrollController.position.maxScrollExtent <= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _restoreScrollAnchor(anchor, attempt: attempt + 1);
      });
      return;
    }

    final extent = _scrollController.position.maxScrollExtent;
    final fraction = anchor >= 999999 ? 1.0 : (anchor / total).clamp(0.0, 1.0);
    final target = (extent * fraction).clamp(0.0, extent);
    if ((_scrollController.offset - target).abs() > 1.0) {
      _scrollController.jumpTo(target);
    }
  }

  /// 把长按坐标映射到具体字符与语义维度（字、句、段、行），支持精准自由划线
  void _handleLongPress(Offset pos, PagingConfig config) {
    final cb = widget.onAddAnnotation;
    if (cb == null) return;

    // 滚动流式模式没有分页行坐标，退回按段落整体划线
    if (widget.turnMode == PageTurnMode.scroll ||
        _pages.isEmpty ||
        _currentPageIndex >= _pages.length) {
      cb('', -1, -1);
      return;
    }

    final page = _pages[_currentPageIndex];
    if (page.lines.isEmpty) {
      cb('', -1, -1);
      return;
    }

    // 1. 纵向命中：定位到具体行
    final startY = config.padTop + (page.isFirstPage ? config.titleHeight : 0.0);
    final rawIndex = ((pos.dy - startY) / config.lineHeight).floor();
    final lineIndex = rawIndex.clamp(0, page.lines.length - 1);
    final line = page.lines[lineIndex];

    // 2. 横向命中：定位到该行内具体字符索引
    final lineText = line.text;
    final relativeX = math.max(0.0, pos.dx - config.hPad);
    int hitCharInLine = 0;
    double curX = line.isFirstLineOfPara ? (config.fontSize * 2.0) : 0.0;
    for (int i = 0; i < lineText.length; i++) {
      final code = lineText.codeUnitAt(i);
      final charW = (code < 128) ? config.fontSize * 0.55 : config.fontSize;
      if (relativeX < curX + charW * 0.7) {
        hitCharInLine = i;
        break;
      }
      curX += charW;
      hitCharInLine = i;
    }
    if (lineText.isNotEmpty) {
      hitCharInLine = hitCharInLine.clamp(0, lineText.length - 1);
    }
    final hitCharOffset = line.charStart + hitCharInLine;

    // 3. 段落级上下文提取（寻找所属段落起止与完整文本）
    final pIndex = line.paragraphIndex;
    final rawPara = (pIndex >= 0 && pIndex < widget.paragraphs.length)
        ? widget.paragraphs[pIndex]
        : lineText;

    int paraCharStart = line.charStart;
    int paraCharEnd = line.charEnd;
    for (final p in _pages) {
      for (final l in p.lines) {
        if (l.paragraphIndex == pIndex) {
          if (l.isFirstLineOfPara) paraCharStart = l.charStart;
          if (l.isLastLineOfPara) paraCharEnd = l.charEnd;
        }
      }
    }

    // 4. 计算四维语义候选
    // (A) 单行
    final lineCandidate = AnnotationCandidate(
      text: lineText.trim(),
      charStart: line.charStart,
      charEnd: line.charEnd,
      mode: AnnotationSelectionMode.line,
    );

    // (B) 选字/词
    final maxOffsetInPara = math.max<int>(0, rawPara.length - 1);
    final int relHitInPara =
        (hitCharOffset - paraCharStart).clamp(0, maxOffsetInPara).toInt();
    final wordText = (relHitInPara < rawPara.length)
        ? rawPara.substring(relHitInPara, math.min<int>(relHitInPara + 1, rawPara.length))
        : (lineText.isNotEmpty ? lineText[hitCharInLine] : '');
    final wordCandidate = AnnotationCandidate(
      text: wordText,
      charStart: hitCharOffset,
      charEnd: math.min<int>(hitCharOffset + 1, paraCharEnd),
      mode: AnnotationSelectionMode.word,
    );

    // (C) 整段
    final paraCandidate = AnnotationCandidate(
      text: rawPara.trim(),
      charStart: paraCharStart,
      charEnd: paraCharEnd,
      mode: AnnotationSelectionMode.paragraph,
    );

    // (D) 智能单句（前后寻找标点 。！？；…\n 和 .!?;）
    const puncts = '。！？；…\n.!?;';
    int sentStart = 0;
    for (int i = relHitInPara - 1; i >= 0; i--) {
      if (puncts.contains(rawPara[i])) {
        sentStart = i + 1;
        break;
      }
    }
    int sentEnd = rawPara.length;
    for (int i = relHitInPara; i < rawPara.length; i++) {
      if (puncts.contains(rawPara[i])) {
        sentEnd = i + 1;
        if (sentEnd < rawPara.length && '”’）》〉"\''.contains(rawPara[sentEnd])) {
          sentEnd++;
        }
        break;
      }
    }
    final sentText = (sentStart < sentEnd && sentEnd <= rawPara.length)
        ? rawPara.substring(sentStart, sentEnd).trim()
        : lineText.trim();
    final sentenceCandidate = AnnotationCandidate(
      text: sentText.isNotEmpty ? sentText : lineText.trim(),
      charStart: paraCharStart + sentStart,
      charEnd: paraCharStart + sentEnd,
      mode: AnnotationSelectionMode.sentence,
    );

    final selectionContext = AnnotationSelectionContext(
      wordCandidate: wordCandidate,
      sentenceCandidate: sentenceCandidate,
      paragraphCandidate: paraCandidate,
      lineCandidate: lineCandidate,
      fullContextText: rawPara,
      contextBaseOffset: paraCharStart,
    );

    widget.onAddAnnotationContext?.call(selectionContext);
    cb(
      sentenceCandidate.text.isNotEmpty ? sentenceCandidate.text : line.text.trim(),
      sentenceCandidate.charStart,
      sentenceCandidate.charEnd,
    );
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
      final page = _pages[_currentPageIndex];
      final currentOffset = page.charStart;
      _activeCharOffset = currentOffset;
      final snippet = page.lines.isNotEmpty ? page.lines.first.text.trim() : '';
      widget.onProgressChanged?.call(currentOffset, snippet);
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
                onLongPressStart: (d) =>
                    _handleLongPress(d.localPosition, config),
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
          SizedBox(
            width: 32.0,
            height: 32.0,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: widget.theme.accent,
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
                      backgroundColor: widget.theme.accent,
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
              // 关键防洗拦截：若当前目标页处于后段，而底层初始化瞬态派发了 0，严禁洗刷真实进度
              if (_currentPageIndex > 0 && index == 0 && _pages.length > 1) {
                return;
              }
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

    final changed = _activeCharOffset != offset;
    _activeCharOffset = offset;
    widget.onProgressChanged?.call(offset, '');
    // 菜单展开时底部的「本章已读 N%」依赖 _activeCharOffset，
    // 不 setState 的话文案会一直停在 0%
    if (changed && _showMenu && mounted) {
      setState(() {});
    }
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

  /// 顶部沉浸操作栏（1:1 像素级对齐原型 modern_soft_ui_sublime_v3.html）
  Widget _buildTopMenu(BuildContext context) {
    final isDark = widget.theme.isDark;
    final softColors = SoftTheme.of(context).withBrightness(dark: isDark);

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
          child: Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8.0,
              bottom: 10.0,
              left: 16.0,
              right: 16.0,
            ),
            decoration: BoxDecoration(
              color: softColors.card.withValues(alpha: isDark ? 0.90 : 0.95),
              border: Border(
                bottom: BorderSide(
                  color: softColors.borderSubtle,
                  width: 1.0,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                  offset: const Offset(0, 4),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Row(
              children: [
                // 原型：圆形微浮雕返回键 p-2 rounded-full squircle-subcard
                GestureDetector(
                  onTap: widget.onBack,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 36.0,
                    height: 36.0,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: softColors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: softColors.borderSubtle,
                        width: 1.0,
                      ),
                    ),
                    child: Icon(Icons.arrow_back_ios_new_rounded,
                        color: softColors.textPrimary, size: 15),
                  ),
                ),
                const SizedBox(width: 12.0),
                // 原型：双行书名与章节副标
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.bookTitle,
                        style: TextStyle(
                          color: softColors.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1.5),
                      Text(
                        widget.chapterTitle.isNotEmpty
                            ? widget.chapterTitle.toUpperCase()
                            : 'CHAPTER ${_currentPageIndex + 1}',
                        style: TextStyle(
                          color: softColors.textSecondary.withValues(alpha: 0.75),
                          fontSize: 9.5,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10.0),
                // 右侧圆形微浮雕功能键：换源、书签、更多
                if (widget.onOpenSourceSwitcher != null) ...[
                  _buildSublimeTopBtn(
                    key: const ValueKey('reader_top_source_btn'),
                    icon: Icons.swap_horiz_rounded,
                    tooltip: '换源',
                    softColors: softColors,
                    onTap: widget.onOpenSourceSwitcher!,
                  ),
                  const SizedBox(width: 8.0),
                ],
                if (widget.onToggleBookmark != null) ...[
                  _buildSublimeTopBtn(
                    key: const ValueKey('reader_top_bookmark_btn'),
                    icon: widget.isBookmarked
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    tooltip: widget.isBookmarked ? '取消书签' : '加书签',
                    softColors: softColors,
                    highlightColor:
                        widget.isBookmarked ? softColors.accent : null,
                    onTap: widget.onToggleBookmark!,
                  ),
                  const SizedBox(width: 8.0),
                ],
                if (widget.onAddToShelf != null) ...[
                  _buildSublimeTopBtn(
                    key: const ValueKey('reader_top_shelf_btn'),
                    icon: widget.isInShelf
                        ? Icons.bookmark_added_rounded
                        : Icons.library_add_outlined,
                    tooltip: widget.isInShelf ? '已在书架' : '加入书架',
                    softColors: softColors,
                    highlightColor:
                        widget.isInShelf ? softColors.accent : null,
                    onTap: () {
                      if (!widget.isInShelf) {
                        widget.onAddToShelf!();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('《${widget.bookTitle}》已在书架中'),
                            duration: const Duration(seconds: 1),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(width: 8.0),
                ],
                _buildTopOverflowMenu(softColors),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 底部控制面板（1:1 像素级对齐原型 modern_soft_ui_sublime_v3.html）
  Widget _buildBottomMenu(BuildContext context) {
    final isDark = widget.theme.isDark;
    final softColors = SoftTheme.of(context).withBrightness(dark: isDark);
    final total = _pages.isEmpty ? 1 : _pages.length;
    final current = (_currentPageIndex + 1).clamp(1, total);
    final isScrollMode = widget.turnMode == PageTurnMode.scroll;
    final percent = ((current / (total > 0 ? total : 1)) * 100).toInt();

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
          child: Container(
            padding: EdgeInsets.only(
              top: 14.0,
              bottom: MediaQuery.of(context).padding.bottom + 12.0,
              left: 18.0,
              right: 18.0,
            ),
            decoration: BoxDecoration(
              color: softColors.card.withValues(alpha: isDark ? 0.90 : 0.95),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(26.0)),
              border: Border(
                top: BorderSide(
                  color: softColors.borderSubtle,
                  width: 1.0,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                  offset: const Offset(0, -6),
                  blurRadius: 24,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 进度滑块：左⏮ 右⏭，中轴轨道
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.skip_previous_rounded,
                          color: softColors.textSecondary, size: 20),
                      onPressed: widget.onPreviousChapter,
                      tooltip: '上一章',
                    ),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isScrollMode)
                            SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 3.0,
                                activeTrackColor: softColors.accent,
                                inactiveTrackColor: softColors.surface,
                                thumbColor: softColors.accent,
                                overlayColor:
                                    softColors.accent.withValues(alpha: 0.12),
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6.0,
                                  elevation: 2.0,
                                ),
                              ),
                              child: Slider(
                                value: current.toDouble(),
                                min: 1.0,
                                max: (total > 1 ? total : 1).toDouble(),
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
                                            _notifyProgress();
                                          }
                                        }
                                      }
                                    : null,
                              ),
                            ),
                          Text(
                            isScrollMode
                                ? '本章已读 ${_scrollPercentLabel()}'
                                : '第 $current / $total 页 · $percent%',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                              color: softColors.textSecondary
                                  .withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.skip_next_rounded,
                          color: softColors.textSecondary, size: 20),
                      onPressed: widget.onNextChapter,
                      tooltip: '下一章',
                    ),
                  ],
                ),
                const SizedBox(height: 6.0),
                // 5 键等宽直出排布：目录、听书、居中【笔记】脉冲点、日间/夜间、排版
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSublimeBottomBtn(
                      key: const ValueKey('reader_bottom_catalog_btn'),
                      icon: Icons.format_list_bulleted_rounded,
                      label: '目录',
                      softColors: softColors,
                      onTap: widget.onOpenCatalog,
                    ),
                    if (widget.onOpenTts != null)
                      _buildSublimeBottomBtn(
                        key: const ValueKey('reader_bottom_tts_btn'),
                        icon: Icons.headphones_rounded,
                        label: '听书',
                        softColors: softColors,
                        onTap: widget.onOpenTts!,
                      ),
                    // 居中正位的【笔记】核心按键，带脉冲呼吸点 pulse-dot
                    _buildSublimeCenterNoteBtn(
                      softColors: softColors,
                      onTap: widget.onOpenNotes,
                    ),
                    _buildSublimeBottomBtn(
                      key: const ValueKey('reader_bottom_theme_btn'),
                      icon: isDark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      label: isDark ? '日间' : '夜间',
                      softColors: softColors,
                      onTap: () {
                        widget.onToggleTheme?.call();
                      },
                    ),
                    _buildSublimeBottomBtn(
                      key: const ValueKey('reader_bottom_typography_btn'),
                      icon: Icons.text_fields_rounded,
                      label: '排版',
                      softColors: softColors,
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

  /// 原型 1:1 圆形微浮雕顶栏小键
  Widget _buildSublimeTopBtn({
    required Key key,
    required IconData icon,
    required String tooltip,
    required SoftColors softColors,
    required VoidCallback onTap,
    Color? highlightColor,
  }) {
    final baseColor = highlightColor ?? softColors.textPrimary;
    final isHighlighted = highlightColor != null;

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        key: key,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 36.0,
          height: 36.0,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isHighlighted ? softColors.accentSoft : softColors.surface,
            shape: BoxShape.circle,
            border: Border.all(
              color: isHighlighted
                  ? softColors.accent.withValues(alpha: 0.3)
                  : softColors.borderSubtle,
              width: 1.0,
            ),
          ),
          child: Icon(icon, size: 17.0, color: baseColor),
        ),
      ),
    );
  }

  /// 原型 1:1 底栏等宽功能键
  Widget _buildSublimeBottomBtn({
    required Key key,
    required IconData icon,
    required String label,
    required SoftColors softColors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 21.0, color: softColors.textSecondary),
            const SizedBox(height: 3.5),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.0,
                fontWeight: FontWeight.w500,
                color: softColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 原型 1:1 居中正位【笔记】键（带脉冲呼吸点 pulse-dot）
  Widget _buildSublimeCenterNoteBtn({
    required SoftColors softColors,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      key: const ValueKey('reader_bottom_notes_btn'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.edit_note_rounded,
                  size: 22.0,
                  color: softColors.accent,
                ),
                const SizedBox(height: 3.5),
                Text(
                  '笔记',
                  style: TextStyle(
                    fontSize: 10.0,
                    fontWeight: FontWeight.bold,
                    color: softColors.accent,
                  ),
                ),
              ],
            ),
          ),
          // 呼吸微光红/绿点 (w-1.5 h-1.5 rounded-full pulse-dot)
          Positioned(
            top: 2.0,
            right: 2.0,
            child: Container(
              width: 6.0,
              height: 6.0,
              decoration: BoxDecoration(
                color: softColors.accent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: softColors.accentGlow,
                    blurRadius: 4.0,
                    spreadRadius: 1.0,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 低频操作收进「更多」菜单，给书名让出呼吸空间
  Widget _buildTopOverflowMenu(SoftColors softColors) {
    final entries = <PopupMenuEntry<String>>[];
    if (widget.onOpenNotes != null) {
      entries.add(const PopupMenuItem<String>(
        value: 'notes',
        child: Row(children: [
          Icon(Icons.rate_review_outlined, size: 18.0),
          SizedBox(width: 10.0),
          Text('笔记与划线'),
        ]),
      ));
    }
    if (widget.onOpenDownload != null) {
      entries.add(const PopupMenuItem<String>(
        value: 'download',
        child: Row(children: [
          Icon(Icons.download_rounded, size: 18.0),
          SizedBox(width: 10.0),
          Text('离线缓存'),
        ]),
      ));
    }
    if (entries.isEmpty) return const SizedBox.shrink();

    return PopupMenuButton<String>(
      key: const ValueKey('reader_top_more_btn'),
      tooltip: '更多',
      padding: EdgeInsets.zero,
      color: softColors.card,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
        side: BorderSide(color: softColors.borderSubtle),
      ),
      itemBuilder: (_) => entries,
      onSelected: (v) {
        switch (v) {
          case 'shelf':
            widget.onAddToShelf?.call();
            break;
          case 'notes':
            widget.onOpenNotes?.call();
            break;
          case 'download':
            widget.onOpenDownload?.call();
            break;
        }
      },
      child: Container(
        width: 36.0,
        height: 36.0,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: softColors.surface,
          shape: BoxShape.circle,
          border: Border.all(
            color: softColors.borderSubtle,
            width: 1.0,
          ),
        ),
        child: Icon(Icons.more_horiz_rounded,
            size: 18.0, color: softColors.textPrimary),
      ),
    );
  }

  /// 滚动模式下用章内百分比替代页码
  String _scrollPercentLabel() {
    final total = _totalCharsOfChapter;
    if (total <= 0) return '0%';
    final pct = ((_activeCharOffset / total) * 100).clamp(0.0, 100.0);
    return '${pct.toStringAsFixed(0)}%';
  }
}
