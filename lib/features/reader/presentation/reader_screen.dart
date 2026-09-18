import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../local_books/services/local_book_service.dart';
import '../../shelf/models/book_item.dart';
import '../../sources/services/builtin_sources.dart';
import '../../sources/services/source_parser.dart';
import '../../sources/services/multi_source_service.dart';
import '../../sources/models/book_search_result.dart';
import '../../sources/models/source_rule.dart';
import '../../tts/presentation/tts_control_sheet.dart';
import '../../tts/presentation/tts_mini_player.dart';
import '../../tts/services/tts_sentence_splitter.dart';
import '../../tts/services/tts_service.dart';
import '../../notes/models/annotation.dart';
import '../../notes/models/bookmark.dart';
import '../../notes/presentation/add_annotation_dialog.dart';
import '../../notes/presentation/reader_notes_sheet.dart';
import '../../notes/services/notes_service.dart';
import '../data/storage_service.dart';
import '../services/chapter_helper.dart';
import '../services/download_service.dart';
import 'catalog_drawer.dart';
import 'download_sheet.dart';
import 'reader_page_theme.dart';
import 'reader_viewport.dart';
import 'typography_drawer.dart';

/// 完整全功能阅读器页面 (reader_screen.dart)
/// 组装排版视口、手势翻页、目录抽屉、排版抽屉与换源弹窗
class ReaderScreen extends StatefulWidget {
  final String bookId;
  final String bookTitle;
  final String author;
  final int initialChapterIndex;
  final int initialCharOffset;
  final String? bookUrl;
  final String? sourceName;
  final String? sourceId;
  final BookItem? book;

  const ReaderScreen({
    super.key,
    required this.bookId,
    required this.bookTitle,
    required this.author,
    this.initialChapterIndex = 0,
    this.initialCharOffset = 0,
    this.bookUrl,
    this.sourceName,
    this.sourceId,
    this.book,
  });

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final StorageService _storage = StorageService();
  final DownloadService _downloadService = DownloadService();
  final SourceParser _parser = SourceParser();
  final MultiSourceService _multiSourceService = MultiSourceService();
  StreamSubscription<DownloadProgress>? _downloadSub;
  final NotesService _notesService = NotesService();
  bool _isCurrentPageBookmarked = false;
  bool _isInShelf = false;
  List<Annotation> _annotations = [];
  double _ttsMiniOffsetY = 0.0;

  /// 当前页首行文本，用于书签摘要（避免每条书签都显示本章第一段）
  String _currentPageSnippet = '';

  late int _currentChapterIndex;
  late int _currentCharOffset;
  late double _fontSize;
  late double _lineHeight;
  late ReaderThemeOption _theme;
  late PageTurnMode _turnMode;
  late DateTime _sessionStartTime;

  // 章节目录数据（支持按书动态加载）
  late List<ChapterItem> _chapters = [];
  List<String> _currentParagraphs = [];
  String _currentSourceName = '笔趣阁CP';
  String? _resolvedBookUrl;
  bool _isLoading = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    // 启用全局统一的透明沉浸式布局，不隐藏系统栏，消除页面跳转与进退砸落 (解决 1.4 / T1)
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _currentChapterIndex = widget.initialChapterIndex;
    _currentCharOffset = widget.initialCharOffset;
    _currentSourceName =
        widget.sourceName ?? widget.book?.sourceName ?? '笔趣阁CP';
    _resolvedBookUrl = widget.bookUrl ?? widget.book?.bookUrl;

    // 0ms 秒级同步读取持久化阅读设置，杜绝首次渲染闪烁与竞态排版
    final s = StorageService.currentSettings;
    _fontSize = s.fontSize;
    _lineHeight = s.lineHeight;
    final tIdx = s.themeIndex.clamp(0, ReaderThemeOption.presets.length - 1);
    _theme = ReaderThemeOption.presets[tIdx];
    _turnMode = PageTurnMode.values.firstWhere(
      (m) => m.name == s.turnMode,
      orElse: () => PageTurnMode.slide,
    );
    _sessionStartTime = DateTime.now();

    // 动态联动状态栏与导航栏图标明暗 (解决 T5 黑色背景白图标，浅色背景黑图标)
    _applySystemBarTheme();

    _checkShelfStatus();
    _loadAnnotations();
    _loadSettings();

    _downloadSub = _downloadService.progressStream.listen((p) {
      if (p.bookId == widget.bookId && mounted) {
        _refreshCachedIndices();
      }
    });

    _initChaptersAndContent();
  }

  /// 联动系统状态栏与导航栏图标明暗 (解决 T5 动态明暗自适应)
  void _applySystemBarTheme() {
    final isDark = _theme.isDark;
    final iconBrightness = isDark ? Brightness.light : Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: iconBrightness,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: iconBrightness,
      ),
    );
  }

  @override
  void dispose() {
    _storage.saveReadingProgress(
      widget.bookId,
      chapterIndex: _currentChapterIndex,
      charOffset: _currentCharOffset,
    );
    // 累加本次阅读实际时长至今日统计
    final durationSec = DateTime.now().difference(_sessionStartTime).inSeconds;
    _storage.addReadingSeconds(durationSec);
    _downloadSub?.cancel();
    // 保持系统原生 EdgeToEdge 布局并恢复全局状态栏样式
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _storage.getGlobalTheme().then((themeStr) {
      final isDark = themeStr == 'dark' || themeStr == 'night';
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness:
              isDark ? Brightness.light : Brightness.dark,
        ),
      );
    });
    super.dispose();
  }

  Future<void> _checkShelfStatus() async {
    final inShelf =
        await _storage.isBookInShelf(widget.bookId, title: widget.bookTitle);
    if (mounted) {
      setState(() => _isInShelf = inShelf);
    }
  }

  Future<void> _loadAnnotations() async {
    try {
      final all = await _notesService.getAnnotations(widget.bookId);
      final current =
          all.where((a) => a.chapterIndex == _currentChapterIndex).toList();
      if (mounted) {
        setState(() {
          _annotations = current;
        });
      }
    } catch (e) {
      debugPrint('加载划线笔记失败: $e');
    }
  }

  Future<void> _addToShelf() async {
    final currentTitle =
        _chapters.isNotEmpty && _currentChapterIndex < _chapters.length
            ? _chapters[_currentChapterIndex].title
            : '第${_currentChapterIndex + 1}章';
    final shelfBook = ShelfBook(
      bookId: widget.bookId,
      title: widget.bookTitle,
      author: widget.author,
      coverUrl: widget.book?.coverUrl ?? '',
      lastChapterTitle: currentTitle,
      sourceName: _currentSourceName,
      bookUrl: _resolvedBookUrl ?? widget.bookUrl ?? '',
      lastReadTime: DateTime.now(),
    );
    await _storage.addToBookshelf(shelfBook);
    if (mounted) {
      setState(() => _isInShelf = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('《${widget.bookTitle}》已成功加入书架'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _refreshCachedIndices() async {
    final cached = await _storage.getDownloadedChapterIndices(widget.bookId);
    if (mounted && cached.isNotEmpty) {
      setState(() {
        _chapters = _chapters
            .map((c) => c.copyWith(isCached: cached.contains(c.index)))
            .toList();
      });
    }
  }

  Future<void> _initChaptersAndContent() async {
    // 1. 优先使用外部显式指定的章节与偏移（例如从目录跳转或笔记定位）
    if (widget.initialChapterIndex > 0 || widget.initialCharOffset > 0) {
      _currentChapterIndex = widget.initialChapterIndex;
      _currentCharOffset = widget.initialCharOffset;
    } else {
      final savedProgress = await _storage.getReadingProgress(widget.bookId);
      if (savedProgress != null) {
        _currentChapterIndex = savedProgress.chapterIndex;
        _currentCharOffset = savedProgress.charOffset;
      }
    }

    final isLocal =
        widget.bookId.startsWith('local_') || (widget.book?.isLocal ?? false);
    if (isLocal) {
      final localToc = await LocalBookService().getToc(widget.bookId);
      if (localToc.isNotEmpty) {
        if (mounted) {
          setState(() {
            _chapters = localToc
                .map((c) => ChapterItem(
                      index: c.index,
                      title: c.title,
                      url: 'local://${widget.bookId}/${c.index}',
                      isCached: true,
                    ))
                .toList();
            _currentSourceName =
                widget.book?.isEpub == true ? '本地EPUB' : '本地TXT';
          });
          await _loadChapterContent(_currentChapterIndex,
              initialCharOffset: _currentCharOffset);
        }
        return;
      }
    }

    // 2. 在线书籍：优先尝试从本地持久化缓存读取已验证的书籍目录 (0ms 秒开)
    final cachedTocJson = await _storage.getBookToc(widget.bookId);
    if (cachedTocJson != null && cachedTocJson.isNotEmpty) {
      final cachedList =
          cachedTocJson.map((e) => ChapterItem.fromJson(e)).toList();
      if (mounted) {
        setState(() {
          _chapters = cachedList;
        });
      }
      await _loadChapterContent(_currentChapterIndex,
          initialCharOffset: _currentCharOffset);
      _refreshCachedIndices();
      return;
    }

    // 3. 联网拉取真实网络书源完整目录
    await _fetchOnlineTocAndLoad();
  }

  Future<void> _fetchOnlineTocAndLoad() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }

    try {
      SourceRule? rule = BuiltinSources.findByName(_currentSourceName);
      rule ??= BuiltinSources.findByName('笔趣阁CP') ?? BuiltinSources.all.first;

      String? targetUrl =
          _resolvedBookUrl ?? widget.bookUrl ?? widget.book?.bookUrl;

      // 针对 4 本经典预置书提供高可用已验证 URL（优先选用 100% 连通的笔趣阁ZWX源）
      // 针对 4 本经典预置书提供高可用已验证 URL（优先选用 100% 连通的笔趣阁ZWX源，支持拼音与中文）
      final lowerTitle =
          ChapterHelper.cleanTitle(widget.bookTitle).toLowerCase();
      if (targetUrl == null ||
          targetUrl.isEmpty ||
          targetUrl.contains('biquge.company')) {
        if (lowerTitle.contains('诡秘之主') || lowerTitle.contains('guimi')) {
          targetUrl = 'https://www.biqugezwx.com/50/';
          rule = BuiltinSources.findByName('笔趣阁ZWX') ?? rule;
          _currentSourceName = '笔趣阁ZWX';
        } else if (lowerTitle.contains('十日终焉') ||
            lowerTitle.contains('shiri')) {
          targetUrl = 'https://www.biqugezwx.com/745/';
          rule = BuiltinSources.findByName('笔趣阁ZWX') ?? rule;
          _currentSourceName = '笔趣阁ZWX';
        } else if (lowerTitle.contains('道诡异仙') ||
            lowerTitle.contains('daoti')) {
          targetUrl = 'https://www.biqugezwx.com/334/';
          rule = BuiltinSources.findByName('笔趣阁ZWX') ?? rule;
          _currentSourceName = '笔趣阁ZWX';
        } else if (lowerTitle.contains('剑来') ||
            lowerTitle.contains('jianlai')) {
          targetUrl = 'https://www.biqugezwx.com/324/';
          rule = BuiltinSources.findByName('笔趣阁ZWX') ?? rule;
          _currentSourceName = '笔趣阁ZWX';
        }
      }

      // 如果仍未绑定网络 URL，通过多书源检索智能匹配书名
      if (targetUrl == null || targetUrl.isEmpty) {
        final cleanName = ChapterHelper.cleanTitle(widget.bookTitle);
        try {
          final searchRes = await _parser
              .searchBooks(rule, cleanName)
              .timeout(const Duration(seconds: 5));
          if (searchRes.isNotEmpty) {
            final match = searchRes.firstWhere(
              (b) => b.title == cleanName || b.title.contains(cleanName),
              orElse: () => searchRes.first,
            );
            targetUrl = match.bookUrl;
          }
        } catch (_) {
          // 当前源无法连接时，尝试全网 12 组源并发探活匹配
          final allRes = await _multiSourceService.searchAll(cleanName,
              timeout: const Duration(seconds: 5));
          if (allRes.isNotEmpty) {
            final best = allRes.first;
            targetUrl = best.bookUrl;
            final matchedRule = BuiltinSources.findById(best.sourceId);
            if (matchedRule != null) {
              rule = matchedRule;
              _currentSourceName = matchedRule.name;
            }
          }
        }
      }

      if (targetUrl != null && targetUrl.isNotEmpty) {
        _resolvedBookUrl = targetUrl;
        final toc = await _parser
            .fetchToc(rule, targetUrl)
            .timeout(const Duration(seconds: 7));
        if (toc.isNotEmpty) {
          _chapters = toc;
          await _storage.saveBookToc(widget.bookId, toc);
          if (_currentChapterIndex >= _chapters.length) {
            _currentChapterIndex = 0;
          }
          if (mounted) {
            setState(() => _isLoading = false);
          }
          await _loadChapterContent(_currentChapterIndex,
              initialCharOffset: _currentCharOffset);
          _refreshCachedIndices();
          return;
        }
      }
    } catch (e) {
      debugPrint('在线目录解析失败: $e');
    }

    // 4. 网络异常且无缓存时的内存临时降级（绝不向本地沙盒写入12章假目录）
    // 不再回退到 12 章假目录——宁可显示错误态让用户重试或换源，
    // 也不能拿伪造的章节名冒充真目录
    if (_chapters.isEmpty && mounted) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      return;
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
    await _loadChapterContent(_currentChapterIndex,
        initialCharOffset: _currentCharOffset);
  }

  Future<void> _loadChapterContent(int chapterIndex,
      {bool landOnLastPage = false, int? initialCharOffset}) async {
    if (_chapters.isEmpty) return;
    final validIndex = chapterIndex.clamp(0, _chapters.length - 1);

    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _currentChapterIndex = validIndex;
        if (initialCharOffset != null) {
          _currentCharOffset = initialCharOffset;
        } else if (landOnLastPage) {
          _currentCharOffset = 999999;
        } else {
          _currentCharOffset = 0;
        }
      });
    }

    final isLocal =
        widget.bookId.startsWith('local_') || (widget.book?.isLocal ?? false);
    if (isLocal) {
      final localParas =
          await LocalBookService().getChapterContent(widget.bookId, validIndex);
      if (localParas.isNotEmpty) {
        if (mounted) {
          setState(() {
            _currentChapterIndex = validIndex;
            _currentParagraphs = localParas;
            _isLoading = false;
          });
        }
        await _storage.saveReadingProgress(
          widget.bookId,
          chapterIndex: validIndex,
          charOffset: _currentCharOffset,
        );
        await _loadAnnotations();
        await _checkBookmarkStatus();
        return;
      }
    }

    // 优先读取本地沙盒离线长文本缓存 (0ms 秒开)
    final cached = await _storage.getChapterContent(widget.bookId, validIndex);
    if (cached != null && cached.isNotEmpty) {
      if (mounted) {
        setState(() {
          _currentChapterIndex = validIndex;
          _currentParagraphs = ChapterHelper.stripDuplicateTitle(
              cached, _chapters[validIndex].title);
          _isLoading = false;
          _hasError = false;
        });
      }
      await _storage.saveReadingProgress(
        widget.bookId,
        chapterIndex: validIndex,
        charOffset: _currentCharOffset,
      );
      await _loadAnnotations();
      await _checkBookmarkStatus();
      return;
    }

    // 联网抓取章节真实正文
    final chapter = _chapters[validIndex];
    if (chapter.url.isNotEmpty && chapter.url.startsWith('http')) {
      try {
        final rule = SourceParser.findRuleByUrl(chapter.url) ??
            BuiltinSources.findByName(_currentSourceName) ??
            BuiltinSources.all.first;
        final fetchedParas = await _parser
            .fetchChapterContent(rule, chapter.url)
            .timeout(const Duration(seconds: 8));
        if (fetchedParas.isNotEmpty) {
          await _storage.saveChapterContent(
              widget.bookId, validIndex, fetchedParas);
          _refreshCachedIndices();

          if (mounted) {
            setState(() {
              _currentChapterIndex = validIndex;
              _currentParagraphs =
                  ChapterHelper.stripDuplicateTitle(fetchedParas, chapter.title);
              _isLoading = false;
              _hasError = false;
            });
          }
          await _storage.saveReadingProgress(
            widget.bookId,
            chapterIndex: validIndex,
            charOffset: _currentCharOffset,
          );
          await _loadAnnotations();
          await _checkBookmarkStatus();
          return;
        }
      } catch (e) {
        debugPrint('联网抓取正文失败: $e');
      }
    }

    // 在线拉取正文失败且没有沙盒缓存：
    // 1. 如果是 4 本经典预置书，使用 ChapterHelper 匹配专属保真段落；
    final presetParas =
        ChapterHelper.getPresetParagraphs(widget.bookTitle, validIndex);
    if (presetParas != null && presetParas.isNotEmpty) {
      if (mounted) {
        setState(() {
          _currentChapterIndex = validIndex;
          _currentParagraphs = presetParas;
          _isLoading = false;
          _hasError = false;
        });
      }
      await _storage.saveReadingProgress(
        widget.bookId,
        chapterIndex: validIndex,
        charOffset: _currentCharOffset,
      );
      await _loadAnnotations();
      await _checkBookmarkStatus();
      return;
    }

    // 2. 针对非预置书，绝不盲目返回《诡秘之主》周明瑞的正文！
    // 提供高质感的“网络正文获取失败，点击重新尝试或切换书源”提示段落，并提供换源与重试入口
    final failureNoticeParagraphs = [
      '网络正文获取失败，点击重新尝试或切换书源。',
      '抱歉，当前书源【$_currentSourceName】暂未能成功抓取到【${chapter.title}】的正文内容。这可能是由于书源站点临时维护、反爬策略拦截或网络连接不稳定导致。',
      '您可以点击重试加载，或直接点击下方「立即换源」按钮平滑切换至全网其他可用书源继续阅读。',
    ];

    if (mounted) {
      setState(() {
        _currentChapterIndex = validIndex;
        _currentParagraphs = failureNoticeParagraphs;
        _isLoading = false;
        _hasError = true;
      });
    }
    await _storage.saveReadingProgress(
      widget.bookId,
      chapterIndex: validIndex,
      charOffset: _currentCharOffset,
    );
    await _loadAnnotations();
    await _checkBookmarkStatus();
  }

  Future<void> _loadSettings() async {
    final s = await _storage.getReaderSettings();
    if (mounted) {
      setState(() {
        _fontSize = s.fontSize;
        _lineHeight = s.lineHeight;
        final tIdx =
            s.themeIndex.clamp(0, ReaderThemeOption.presets.length - 1);
        _theme = ReaderThemeOption.presets[tIdx];
        _turnMode = PageTurnMode.values.firstWhere(
          (m) => m.name == s.turnMode,
          orElse: () => PageTurnMode.slide,
        );
      });
      _applySystemBarTheme();
    }
  }

  void _persistSettings() {
    final themeIdx =
        ReaderThemeOption.presets.indexWhere((t) => t.id == _theme.id);
    final settings = ReaderSettings(
      fontSize: _fontSize,
      lineHeight: _lineHeight,
      themeIndex: themeIdx >= 0 ? themeIdx : 0,
      turnMode: _turnMode.name,
    );
    StorageService.currentSettings = settings;
    _storage.saveReaderSettings(settings);
  }

  void _toggleNightMode() {
    setState(() {
      if (_theme.isDark) {
        _theme = ReaderThemeOption.presets[0]; // 浅色纸白/羊皮纸
      } else {
        _theme = ReaderThemeOption.presets
            .firstWhere((t) => t.isDark, orElse: () => ReaderThemeOption.night);
      }
    });
    _applySystemBarTheme();
    _persistSettings();
  }

  Future<void> _nextChapter() async {
    if (_currentChapterIndex < _chapters.length - 1) {
      await _loadChapterContent(_currentChapterIndex + 1,
          landOnLastPage: false);
    }
  }

  Future<void> _previousChapter() async {
    if (_currentChapterIndex > 0) {
      await _loadChapterContent(_currentChapterIndex - 1,
          landOnLastPage: true);
    }
  }

  void _openCatalogDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  void _openTypographyDrawer() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return TypographyDrawer(
              fontSize: _fontSize,
              lineHeight: _lineHeight,
              currentTheme: _theme,
              turnMode: _turnMode,
              onFontSizeChanged: (newSize) {
                setState(() => _fontSize = newSize);
                _persistSettings();
                setModalState(() {});
              },
              onLineHeightChanged: (newH) {
                setState(() => _lineHeight = newH);
                _persistSettings();
                setModalState(() {});
              },
              onThemeChanged: (newTheme) {
                setState(() => _theme = newTheme);
                _applySystemBarTheme();
                _persistSettings();
                setModalState(() {});
              },
              onTurnModeChanged: (newMode) {
                setState(() => _turnMode = newMode);
                _persistSettings();
                setModalState(() {});
              },
            );
          },
        );
      },
    );
  }

  /// 换源：先探活候选书源，再由用户确认目标书籍，杜绝"串书"
  ///
  /// 此前的实现用 `t.contains(name) || name.contains(t)` 双向包含匹配，
  /// 再直接取 `matches.first`，导致任何书名里含原书名的同人文都会被换上，
  /// 且顶栏仍显示原书名，用户完全无法察觉自己已经在读另一本书。
  void _openSourceSwitcher() {
    final isLocal =
        widget.bookId.startsWith('local_') || (widget.book?.isLocal ?? false);
    if (isLocal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('当前为本地导入图书，已是独占本地精排源'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    const sources = BuiltinSources.all;
    // 真实测速结果：sourceId -> 延迟(ms)，null 表示不可达，缺省表示仍在测
    final latencyMap = <String, int?>{};

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final isDark = _theme.isDark;
            final accent = _theme.accent;
            final cardBg = isDark ? const Color(0xFF1E1E20) : Colors.white;
            final textPri = isDark ? Colors.white : const Color(0xFF2B2824);
            final textSec = isDark ? Colors.white60 : const Color(0xFF8A8275);

            // 首次构建时发起真实测速（替换此前 45 + index*13 的伪造等差数列）
            if (latencyMap.isEmpty) {
              _multiSourceService.pingAllSources().then((results) {
                for (final r in results) {
                  latencyMap[r.sourceId] = r.latencyMs;
                }
                if (sheetContext.mounted) setSheetState(() {});
              }).catchError((_) {
                for (final s in sources) {
                  latencyMap[s.id] = null;
                }
                if (sheetContext.mounted) setSheetState(() {});
              });
            }

            final probedCount = latencyMap.values.where((v) => v != null).length;

            return Material(
              color: cardBg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24.0)),
              child: Container(
                height: MediaQuery.of(sheetContext).size.height * 0.65,
                padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36.0,
                        height: 4.0,
                        decoration: BoxDecoration(
                          color: textSec.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2.0),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '切换书源',
                          style: TextStyle(
                            fontSize: 18.0,
                            fontWeight: FontWeight.bold,
                            color: textPri,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8.0, vertical: 3.0),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: Text(
                            latencyMap.isEmpty
                                ? '正在测速...'
                                : '$probedCount/${sources.length} 组可达',
                            style: TextStyle(
                              fontSize: 11.0,
                              color: accent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      '换源前会先核对书名与作者，确认无误后才替换目录',
                      style: TextStyle(fontSize: 12.0, color: textSec),
                    ),
                    const SizedBox(height: 12.0),
                    Expanded(
                      child: ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        itemCount: sources.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1.0,
                          color: textSec.withValues(alpha: 0.1),
                        ),
                        itemBuilder: (itemCtx, index) {
                          final source = sources[index];
                          final isCurrent = source.name == _currentSourceName;
                          final isGbk =
                              source.charset.toLowerCase().contains('gb');
                          final probed = latencyMap.containsKey(source.id);
                          final latency = latencyMap[source.id];

                          return ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 4.0),
                            leading: Container(
                              width: 38.0,
                              height: 38.0,
                              decoration: BoxDecoration(
                                color: isCurrent
                                    ? accent
                                    : (isDark
                                        ? Colors.white10
                                        : Colors.black.withValues(alpha: 0.05)),
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                source.name.characters.take(1).toString(),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isCurrent ? Colors.white : textPri,
                                ),
                              ),
                            ),
                            title: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    source.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 15.0,
                                      fontWeight: isCurrent
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      color: isCurrent ? accent : textPri,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8.0),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5.0, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: (isGbk ? Colors.orange : Colors.blue)
                                        .withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(4.0),
                                  ),
                                  child: Text(
                                    isGbk ? 'GBK转码' : 'UTF-8',
                                    style: TextStyle(
                                      fontSize: 9.0,
                                      color: isGbk ? Colors.orange : Colors.blue,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                _buildLatencyBadge(probed, latency),
                              ],
                            ),
                            subtitle: Text(
                              !probed
                                  ? '正在探测连通性...'
                                  : (latency == null ? '当前不可达' : '连通正常'),
                              style: TextStyle(fontSize: 11.0, color: textSec),
                            ),
                            trailing: isCurrent
                                ? Icon(Icons.check_circle,
                                    color: accent, size: 20.0)
                                : Icon(Icons.chevron_right,
                                    color: textSec.withValues(alpha: 0.4),
                                    size: 18.0),
                            onTap: isCurrent
                                ? null
                                : () {
                                    Navigator.of(sheetContext).pop();
                                    _switchToSource(source);
                                  },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLatencyBadge(bool probed, int? latency) {
    if (!probed) {
      return const SizedBox(
        width: 12.0,
        height: 12.0,
        child: CircularProgressIndicator(strokeWidth: 1.6),
      );
    }
    final ok = latency != null;
    final color =
        ok ? (latency < 400 ? Colors.green : Colors.orange) : Colors.redAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6.0),
      ),
      child: Text(
        ok ? '${latency}ms' : '超时',
        style:
            TextStyle(fontSize: 11.0, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  /// 执行换源：搜索 → 择优匹配 → 用户确认 → 替换目录
  Future<void> _switchToSource(SourceRule chosenSource) async {
    final cleanName = ChapterHelper.cleanTitle(widget.bookTitle);
    final oldChapterCount = _chapters.length;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('正在【${chosenSource.name}】中查找《${widget.bookTitle}》...'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );

    List<BookSearchResult> searchRes = [];
    try {
      searchRes = await _parser
          .searchBooks(chosenSource, cleanName)
          .timeout(const Duration(seconds: 6));
    } catch (e) {
      debugPrint('换源检索失败: $e');
    }

    if (!mounted) return;

    // 1) 只认书名精确相等（去掉书名号与空白后）
    final exact = searchRes.where((b) {
      final t = ChapterHelper.cleanTitle(b.title);
      return t == cleanName;
    }).toList();

    // 2) 精确匹配里若有作者也对得上的，优先用它
    BookSearchResult? target;
    if (exact.isNotEmpty) {
      final authorMatched = exact.where((b) {
        final a = b.author.trim();
        return a.isNotEmpty && a == widget.author.trim();
      }).toList();
      target = authorMatched.isNotEmpty ? authorMatched.first : exact.first;
    }

    // 3) 没有精确匹配时，绝不自动采用模糊结果，交给用户自己挑
    if (target == null) {
      final fuzzy = searchRes.where((b) {
        final t = ChapterHelper.cleanTitle(b.title);
        return t.contains(cleanName) || cleanName.contains(t);
      }).toList();

      if (fuzzy.isEmpty) {
        _showSourceFailure(
            '【${chosenSource.name}】未收录《${widget.bookTitle}》，已为您保留当前书源');
        return;
      }
      target = await _pickCandidate(fuzzy, chosenSource.name);
      if (target == null || !mounted) return;
    }

    final picked = target;

    // 4) 拉取新源目录
    List<ChapterItem> newToc = [];
    try {
      newToc = await _parser
          .fetchToc(chosenSource, picked.bookUrl)
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('换源目录拉取失败: $e');
    }

    if (!mounted) return;
    if (newToc.isEmpty) {
      _showSourceFailure('【${chosenSource.name}】目录解析失败，已为您保留当前书源');
      return;
    }

    // 5) 章节数偏差过大时二次确认——这是"串书"的最后一道闸门
    if (oldChapterCount > 0 && newToc.length < oldChapterCount * 0.5) {
      final go = await _confirmDialog(
        title: '目录差异较大',
        content: '当前书源有 $oldChapterCount 章，'
            '【${chosenSource.name}】的《${picked.title}》只有 ${newToc.length} 章。\n\n'
            '这可能不是同一本书，继续切换会替换整个目录。确定继续吗？',
        confirmText: '仍要切换',
      );
      if (go != true || !mounted) return;
    }

    // 6) 告知将清除离线缓存
    final cachedCount = await _storage.getDownloadedChaptersCount(widget.bookId);
    if (!mounted) return;
    if (cachedCount > 0) {
      final go = await _confirmDialog(
        title: '切换书源',
        content:
            '切换后将清除本书已下载的 $cachedCount 章离线缓存（新书源的章节编号与旧源不一致）。\n\n确定切换吗？',
        confirmText: '确定切换',
      );
      if (go != true || !mounted) return;
    }

    setState(() {
      _currentSourceName = chosenSource.name;
      _chapters = newToc;
      _resolvedBookUrl = picked.bookUrl;
    });

    // 旧书源写下的正文缓存必须清掉，否则会继续命中旧内容
    await _storage.clearBookCache(widget.bookId);
    await _storage.saveBookToc(widget.bookId, newToc);
    if (_currentChapterIndex >= _chapters.length) {
      _currentChapterIndex = 0;
    }
    await _loadChapterContent(_currentChapterIndex);

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已切换至【${chosenSource.name}】，共 ${newToc.length} 章'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSourceFailure(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<bool?> _confirmDialog({
    required String title,
    required String content,
    required String confirmText,
  }) {
    final isDark = _theme.isDark;
    return showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E20) : Colors.white,
        title: Text(title,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
        content: Text(content,
            style: TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: isDark ? Colors.white70 : Colors.black87)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(confirmText, style: TextStyle(color: _theme.accent)),
          ),
        ],
      ),
    );
  }

  /// 无精确匹配时，把候选书目摊开让用户自己确认，绝不替用户瞎猜
  Future<BookSearchResult?> _pickCandidate(
      List<BookSearchResult> candidates, String sourceName) {
    final isDark = _theme.isDark;
    return showModalBottomSheet<BookSearchResult>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E20) : Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '【$sourceName】没有完全同名的作品',
                  style: TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 6.0),
                Text(
                  '以下是名称相近的结果，请确认哪一本才是您在读的《${widget.bookTitle}》',
                  style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? Colors.white60 : Colors.black54),
                ),
                const SizedBox(height: 12.0),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: candidates.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final b = candidates[i];
                      return ListTile(
                        title: Text(
                          b.title,
                          style: TextStyle(
                              fontSize: 14.5,
                              color: isDark ? Colors.white : Colors.black87),
                        ),
                        subtitle: Text(
                          [
                            if (b.author.isNotEmpty) b.author,
                            if (b.latestChapter?.isNotEmpty == true)
                              '最新：${b.latestChapter}',
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? Colors.white54 : Colors.black45),
                        ),
                        onTap: () => Navigator.of(ctx).pop(b),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8.0),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('都不是，保留当前书源'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openDownloadSheet() {
    final isLocal =
        widget.bookId.startsWith('local_') || (widget.book?.isLocal ?? false);
    if (isLocal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('当前为本地图书，所有章节已在设备本地就绪，无需重复下载'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    DownloadSheet.show(
      context,
      bookId: widget.bookId,
      bookTitle: widget.bookTitle,
      chapters: _chapters,
      currentChapterIndex: _currentChapterIndex,
      isDark: _theme.isDark,
      onCacheUpdated: _refreshCachedIndices,
      sourceName: _currentSourceName,
    );
  }

  void _openTts() {
    final currentTitle =
        _chapters.isNotEmpty && _currentChapterIndex < _chapters.length
            ? _chapters[_currentChapterIndex].title
            : '第${_currentChapterIndex + 1}章';
    final fullText = _currentParagraphs.join('\n\n');

    // 动态映射当前视口首行字符偏移量到句子索引 (解决 2.1 启动朗读位置同步，读到哪听到哪)
    int startSentenceIndex = 0;
    if (_currentCharOffset > 0 && fullText.isNotEmpty) {
      final sentences = TtsSentenceSplitter.split(fullText);
      for (int i = 0; i < sentences.length; i++) {
        if (_currentCharOffset >= sentences[i].startIndex &&
            _currentCharOffset < sentences[i].endIndex) {
          startSentenceIndex = i;
          break;
        }
        if (sentences[i].startIndex >= _currentCharOffset) {
          startSentenceIndex = i;
          break;
        }
      }
    }

    final tts = TtsService();
    tts.onChapterComplete = () async {
      if (_currentChapterIndex + 1 < _chapters.length) {
        // 必须 await：_loadChapterContent 只在首个 await 前同步更新章索引，
        // 正文 _currentParagraphs 要等存储/网络返回后才赋值。
        // 漏掉 await 会出现"标题已翻到下一章、朗读的还是上一章句子"。
        await _nextChapter();
        if (!mounted) return;
        final newTitle = _chapters[_currentChapterIndex].title;
        final newText = _currentParagraphs.join('\n\n');
        if (newText.trim().isEmpty) {
          await tts.stop();
          return;
        }
        await tts.playChapter(
          bookId: widget.bookId,
          bookTitle: widget.bookTitle,
          chapterIndex: _currentChapterIndex,
          chapterTitle: newTitle,
          content: newText,
          startSentenceIndex: 0,
        );
      } else {
        await tts.stop();
      }
    };

    tts.playChapter(
      bookId: widget.bookId,
      bookTitle: widget.bookTitle,
      chapterIndex: _currentChapterIndex,
      chapterTitle: currentTitle,
      content: fullText,
      startSentenceIndex: startSentenceIndex,
    );

    TtsControlSheet.show(context);
  }

  Future<void> _checkBookmarkStatus() async {
    final isBm = await _notesService.isBookmarked(
      widget.bookId,
      _currentChapterIndex,
      _currentCharOffset,
    );
    if (mounted && isBm != _isCurrentPageBookmarked) {
      setState(() => _isCurrentPageBookmarked = isBm);
    }
  }

  void _toggleBookmark() async {
    final currentTitle =
        _chapters.isNotEmpty && _currentChapterIndex < _chapters.length
            ? _chapters[_currentChapterIndex].title
            : '第${_currentChapterIndex + 1}章';

    if (_isCurrentPageBookmarked) {
      final bookmarks = await _notesService.getBookmarks(widget.bookId);
      // 关键修复：此前 orElse 回退到 bookmarks.first（按创建时间倒序 = 全书最新的书签），
      // 一旦状态与实际位置不同步，就会静默删掉一条完全无关的书签。
      Bookmark? match;
      for (final b in bookmarks) {
        if (b.chapterIndex == _currentChapterIndex &&
            (b.charOffset - _currentCharOffset).abs() < 100) {
          match = b;
          break;
        }
      }

      if (match == null) {
        // 当前位置本就没有书签，纠正状态而非误删他人
        if (mounted) {
          setState(() => _isCurrentPageBookmarked = false);
        }
        return;
      }

      await _notesService.removeBookmark(match.id);
      if (!mounted) return;
      setState(() => _isCurrentPageBookmarked = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已移除书签'),
          duration: Duration(milliseconds: 1000),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      // 优先用当前页首行做摘要；拿不到才退回段落开头
      final raw = _currentPageSnippet.isNotEmpty
          ? _currentPageSnippet
          : (_currentParagraphs.isNotEmpty
              ? _currentParagraphs.first
              : currentTitle);
      final snippet = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
      final bm = Bookmark(
        id: 'bm_${DateTime.now().millisecondsSinceEpoch}',
        bookId: widget.bookId,
        bookTitle: widget.bookTitle,
        chapterIndex: _currentChapterIndex,
        chapterTitle: currentTitle,
        charOffset: _currentCharOffset,
        snippet:
            snippet.length > 50 ? '${snippet.substring(0, 50)}...' : snippet,
        createdAt: DateTime.now(),
      );
      await _notesService.saveBookmark(bm);
      if (!mounted) return;
      setState(() => _isCurrentPageBookmarked = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已添加书签：$currentTitle'),
            duration: const Duration(milliseconds: 1200),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _openNotesSheet() async {
    // 面板里可以删除书签，关闭后必须重算顶栏书签高亮，
    // 否则会出现"书签已全部删除、图标还亮着"的状态不同步。
    await ReaderNotesSheet.show(
      context,
      bookId: widget.bookId,
      bookTitle: widget.bookTitle,
      isDark: _theme.isDark,
      onNavigate: (chIdx, offset) {
        _loadChapterContent(chIdx, initialCharOffset: offset);
      },
    );
    if (!mounted) return;
    await _checkBookmarkStatus();
    await _loadAnnotations();
  }

  /// [lineText] / [charStart] / [charEnd] 来自用户长按命中的那一行；
  /// charStart 为 -1 表示拿不到行坐标（如滚动模式），此时退回段落首句。
  void _openAddAnnotation(String lineText, int charStart, int charEnd) async {
    final currentTitle =
        _chapters.isNotEmpty && _currentChapterIndex < _chapters.length
            ? _chapters[_currentChapterIndex].title
            : '第${_currentChapterIndex + 1}章';

    final hasLine = charStart >= 0 && lineText.trim().isNotEmpty;
    final snippet = hasLine
        ? lineText.replaceAll(RegExp(r'\s+'), ' ').trim()
        : (_currentParagraphs.isNotEmpty
            ? _currentParagraphs.first.replaceAll(RegExp(r'\s+'), ' ')
            : '精彩选段');
    final excerpt = snippet.length > 60 ? snippet.substring(0, 60) : snippet;
    final start = hasLine ? charStart : _currentCharOffset;
    final end = hasLine ? charEnd : _currentCharOffset + excerpt.length;

    final result = await AddAnnotationDialog.show(
      context,
      bookId: widget.bookId,
      bookTitle: widget.bookTitle,
      chapterIndex: _currentChapterIndex,
      chapterTitle: currentTitle,
      charStart: start,
      charEnd: end,
      selectedText: excerpt,
      isDark: _theme.isDark,
    );

    if (result != null) {
      await _notesService.saveAnnotation(result);
      await _loadAnnotations();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('已成功添加划线批注并存入笔记'),
            duration: const Duration(milliseconds: 1200),
            behavior: SnackBarBehavior.floating,
            backgroundColor: _theme.isDark ? const Color(0xFF282A2D) : null,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLocal =
        widget.bookId.startsWith('local_') || (widget.book?.isLocal ?? false);
    final currentTitle =
        _chapters.isNotEmpty && _currentChapterIndex < _chapters.length
            ? _chapters[_currentChapterIndex].title
            : '正在加载...';

    return PopScope(
      canPop: true,
      child: Scaffold(
        key: _scaffoldKey,
        drawer: CatalogDrawer(
          chapters: _chapters,
          currentChapterIndex: _currentChapterIndex,
          theme: _theme,
          isDark: _theme.isDark,
          onSelectChapter: (idx) {
            _loadChapterContent(idx);
          },
          onOpenDownload: isLocal ? null : _openDownloadSheet,
          onOpenNotes: _openNotesSheet,
        ),
        body: Stack(
          children: [
            ReaderViewport(
              paragraphs: _currentParagraphs,
              bookTitle: widget.bookTitle,
              chapterTitle: currentTitle,
              initialCharOffset: _currentCharOffset,
              turnMode: _turnMode,
              theme: _theme,
              fontSize: _fontSize,
              lineHeight: _lineHeight,
              isLoading: _isLoading,
              hasError: _hasError,
              annotations: _annotations,
              isInShelf: _isInShelf,
              onAddToShelf: _addToShelf,
              onRetry: () => _loadChapterContent(_currentChapterIndex),
              onBack: () {
                _storage.saveReadingProgress(
                  widget.bookId,
                  chapterIndex: _currentChapterIndex,
                  charOffset: _currentCharOffset,
                );
                Navigator.of(context).maybePop();
              },
              onOpenCatalog: _openCatalogDrawer,
              onOpenTypography: _openTypographyDrawer,
              onOpenSourceSwitcher: isLocal ? null : _openSourceSwitcher,
              onOpenDownload: isLocal ? null : _openDownloadSheet,
              onOpenTts: _openTts,
              onToggleTheme: _toggleNightMode,
              onNextChapter: _nextChapter,
              onPreviousChapter: _previousChapter,
              onProgressChanged: (charOffset, pageSnippet) {
                _currentCharOffset = charOffset;
                if (pageSnippet.isNotEmpty) {
                  _currentPageSnippet = pageSnippet;
                }
                _storage.saveReadingProgress(
                  widget.bookId,
                  chapterIndex: _currentChapterIndex,
                  charOffset: charOffset,
                );
                _checkBookmarkStatus();
              },
              onToggleBookmark: _toggleBookmark,
              onOpenNotes: _openNotesSheet,
              onAddAnnotation: _openAddAnnotation,
              isBookmarked: _isCurrentPageBookmarked,
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 44.0 + _ttsMiniOffsetY,
              child: SafeArea(
                child: TtsMiniPlayer(
                  isDark: _theme.isDark,
                  offsetY: _ttsMiniOffsetY,
                  onOffsetYChanged: (newOffset) {
                    setState(() {
                      _ttsMiniOffsetY = newOffset;
                    });
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
