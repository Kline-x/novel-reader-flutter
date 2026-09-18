import 'dart:async';
import 'dart:collection';
import '../data/storage_service.dart';
import '../../sources/models/chapter_item.dart';
import '../../sources/models/source_rule.dart';
import '../../sources/services/source_parser.dart';
import '../../sources/services/builtin_sources.dart';

enum DownloadStatus {
  idle,
  downloading,
  paused,
  completed,
  error,
}

class DownloadProgress {
  final String bookId;
  final String bookTitle;
  final int total;
  final int completed;
  final int failed;
  final double progress;
  final String currentChapterTitle;
  final DownloadStatus status;
  final String? errorMessage;
  final String speedText;

  const DownloadProgress({
    required this.bookId,
    required this.bookTitle,
    required this.total,
    required this.completed,
    this.failed = 0,
    required this.progress,
    required this.currentChapterTitle,
    required this.status,
    this.errorMessage,
    this.speedText = '',
  });

  DownloadProgress copyWith({
    String? bookId,
    String? bookTitle,
    int? total,
    int? completed,
    int? failed,
    double? progress,
    String? currentChapterTitle,
    DownloadStatus? status,
    String? errorMessage,
    String? speedText,
  }) {
    return DownloadProgress(
      bookId: bookId ?? this.bookId,
      bookTitle: bookTitle ?? this.bookTitle,
      total: total ?? this.total,
      completed: completed ?? this.completed,
      failed: failed ?? this.failed,
      progress: progress ?? this.progress,
      currentChapterTitle: currentChapterTitle ?? this.currentChapterTitle,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      speedText: speedText ?? this.speedText,
    );
  }
}

/// 后台批量章节与全本离线下载调度引擎 (DownloadService)
/// - 并发槽控制（默认 3 个工作槽），防止书源反爬封禁；
/// - 支持「缓存后20章」「缓存后50章」「缓存全本」；
/// - 任务支持开始、暂停、恢复、取消；
/// - 广播 Stream<DownloadProgress> 实时同步进度至 UI；
/// - 自动冷落盘至 StorageService (chapters/{bookId}/{index}.txt)。
class DownloadService {
  static DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;

  static void setMockInstance(DownloadService instance) {
    _instance = instance;
  }

  static void resetInstance() {
    _instance = DownloadService._internal();
  }

  DownloadService._internal({StorageService? storageService, SourceParser? parser})
      : _storage = storageService ?? StorageService(),
        _parser = parser ?? SourceParser();

  factory DownloadService.withStorage(StorageService storage, {SourceParser? parser}) {
    return DownloadService._internal(storageService: storage, parser: parser);
  }

  final StorageService _storage;
  final SourceParser _parser;

  final Map<String, DownloadProgress> _activeTasks = {};
  final Map<String, Queue<ChapterItem>> _taskQueues = {};
  final Map<String, bool> _cancelFlags = {};
  final Map<String, bool> _pauseFlags = {};

  final Map<String, String> _taskSources = {};
  final StreamController<DownloadProgress> _progressController =
      StreamController<DownloadProgress>.broadcast();

  Stream<DownloadProgress> get progressStream => _progressController.stream;

  DownloadProgress? getProgress(String bookId) => _activeTasks[bookId];

  bool isDownloading(String bookId) {
    final t = _activeTasks[bookId];
    return t != null && t.status == DownloadStatus.downloading;
  }

  /// 启动全本或指定章数下载
  Future<void> startDownload({
    required String bookId,
    required String bookTitle,
    int totalChapters = 50,
    String? sourceName,
    String? bookUrl,
  }) async {
    final sName = sourceName ?? _taskSources[bookId] ?? '笔趣阁ZWX';
    _taskSources[bookId] = sName;
    final cachedToc = await _storage.getBookToc(bookId);
    List<ChapterItem> chapters = [];
    if (cachedToc != null && cachedToc.isNotEmpty) {
      chapters = cachedToc.map((e) => ChapterItem.fromJson(e)).toList();
    }
    if (chapters.isEmpty && bookUrl != null && bookUrl.isNotEmpty) {
      final rule = BuiltinSources.findByName(sName) ?? BuiltinSources.findByName('笔趣阁ZWX');
      if (rule != null) {
        try {
          chapters = await _parser.fetchToc(rule, bookUrl);
          await _storage.saveBookToc(bookId, chapters.map((e) => e.toJson()).toList());
        } catch (_) {}
      }
    }
    if (chapters.isEmpty) {
      chapters = List.generate(totalChapters, (i) => ChapterItem(index: i, title: '第${i + 1}章', url: ''));
    }
    await startBatchDownload(
      bookId: bookId,
      bookTitle: bookTitle,
      chapters: chapters,
      count: chapters.isNotEmpty ? chapters.length : totalChapters,
      sourceName: sName,
    );
  }

  /// 启动批量章节下载
  Future<void> startBatchDownload({
    required String bookId,
    required String bookTitle,
    required List<ChapterItem> chapters,
    int startIndex = 0,
    int count = 50,
    String? sourceName,
  }) async {
    if (isDownloading(bookId)) {
      return;
    }

    final sName = sourceName ?? _taskSources[bookId] ?? '笔趣阁ZWX';
    _taskSources[bookId] = sName;

    _cancelFlags[bookId] = false;
    _pauseFlags[bookId] = false;

    // 截取需要下载的章节范围
    final endIndex = (startIndex + count).clamp(0, chapters.length);
    final targetChapters = chapters.sublist(
      startIndex.clamp(0, chapters.length),
      endIndex,
    );

    if (targetChapters.isEmpty) return;

    final totalTarget = targetChapters.length;
    var progress = DownloadProgress(
      bookId: bookId,
      bookTitle: bookTitle,
      total: totalTarget,
      completed: 0,
      failed: 0,
      progress: 0.0,
      currentChapterTitle: targetChapters.first.title,
      status: DownloadStatus.downloading,
    );

    _activeTasks[bookId] = progress;
    _progressController.add(progress);

    // 过滤掉已经缓存的章节
    final cachedIndices = await _storage.getDownloadedChapterIndices(bookId);
    final pendingChapters = targetChapters.where((ch) => !cachedIndices.contains(ch.index)).toList();
    final alreadyCachedCount = totalTarget - pendingChapters.length;

    progress = progress.copyWith(
      completed: alreadyCachedCount,
      progress: totalTarget > 0 ? alreadyCachedCount / totalTarget : 1.0,
      currentChapterTitle: pendingChapters.isNotEmpty ? pendingChapters.first.title : '已全部下载',
      status: pendingChapters.isEmpty ? DownloadStatus.completed : DownloadStatus.downloading,
    );
    _activeTasks[bookId] = progress;
    _progressController.add(progress);

    if (pendingChapters.isEmpty) {
      return;
    }

    final queue = Queue<ChapterItem>.from(pendingChapters);
    _taskQueues[bookId] = queue;

    // 启动并发工作池（默认 3 个并发 worker）
    const concurrency = 3;
    final workers = <Future<void>>[];
    for (var i = 0; i < concurrency; i++) {
      workers.add(_runWorker(bookId, bookTitle, totalTarget));
    }

    await Future.wait(workers);

    if (_cancelFlags[bookId] == true) {
      final finalP = _activeTasks[bookId]?.copyWith(status: DownloadStatus.idle);
      if (finalP != null) {
        _activeTasks.remove(bookId);
        _progressController.add(finalP);
      }
    } else if (_pauseFlags[bookId] == true) {
      final finalP = _activeTasks[bookId]?.copyWith(status: DownloadStatus.paused);
      if (finalP != null) {
        _activeTasks[bookId] = finalP;
        _progressController.add(finalP);
      }
    } else {
      final current = _activeTasks[bookId];
      if (current != null) {
        final completedP = current.copyWith(
          status: DownloadStatus.completed,
          progress: 1.0,
          currentChapterTitle: '下载完成 (共 ${current.completed} 章)',
        );
        _activeTasks[bookId] = completedP;
        _progressController.add(completedP);
      }
    }
  }

  /// 单个 Worker 循环处理队列中的章节
  Future<void> _runWorker(String bookId, String bookTitle, int totalTarget) async {
    final queue = _taskQueues[bookId];
    if (queue == null) return;

    final stopwatch = Stopwatch()..start();

    while (queue.isNotEmpty) {
      if (_cancelFlags[bookId] == true || _pauseFlags[bookId] == true) {
        break;
      }

      final chapter = queue.removeFirst();

      try {
        // 智能书源规则匹配：优先基于章节 URL 探测匹配书源规则，再基于任务绑定的 sourceName，最后兜底
        SourceRule? rule = SourceParser.findRuleByUrl(chapter.url);
        if (rule == null) {
          final srcName = _taskSources[bookId];
          if (srcName != null && srcName.isNotEmpty) {
            rule = BuiltinSources.findByName(srcName);
          }
        }
        rule ??= BuiltinSources.findByName('笔趣阁ZWX') ?? BuiltinSources.all.first;

        // 尝试从网络或书源抓取
        List<String>? paragraphs;
        if (chapter.url.isNotEmpty && chapter.url.startsWith('http')) {
          try {
            paragraphs = await _parser.fetchChapterContent(rule, chapter.url);
          } catch (_) {}
        }

        // 核心铁律：如果远程抓取正文失败（paragraphs == null || paragraphs.isEmpty），
        // 绝不能调用 _generateOfflineFallbackParagraphs 写入沙盒！
        // 记录失败并跳过，严禁向沙盒写入“【离线缓存章节】...风声呼啸，长夜未央”假正文！
        if (paragraphs == null || paragraphs.isEmpty) {
          final current = _activeTasks[bookId];
          if (current != null) {
            final updated = current.copyWith(
              failed: current.failed + 1,
            );
            _activeTasks[bookId] = updated;
            _progressController.add(updated);
          }
          continue;
        }

        // 只有远程抓取到的真实正文，才持久化保存至沙盒冷存储
        await _storage.saveChapterContent(bookId, chapter.index, paragraphs);

        final current = _activeTasks[bookId];
        if (current != null) {
          final newCompleted = current.completed + 1;
          final p = (newCompleted / totalTarget).clamp(0.0, 1.0);
          final elapsedSec = stopwatch.elapsedMilliseconds / 1000.0;
          final speed = elapsedSec > 0 ? (newCompleted / elapsedSec).toStringAsFixed(1) : '0';

          final updated = current.copyWith(
            completed: newCompleted,
            progress: p,
            currentChapterTitle: chapter.title,
            speedText: '$speed 章/秒',
          );
          _activeTasks[bookId] = updated;
          _progressController.add(updated);
        }

        // 微延时避免并发轰炸
        await Future.delayed(const Duration(milliseconds: 30));
      } catch (e) {
        final current = _activeTasks[bookId];
        if (current != null) {
          final updated = current.copyWith(
            failed: current.failed + 1,
          );
          _activeTasks[bookId] = updated;
          _progressController.add(updated);
        }
      }
    }
  }

  /// 暂停下载
  void pauseDownload(String bookId) {
    _pauseFlags[bookId] = true;
    final current = _activeTasks[bookId];
    if (current != null) {
      final paused = current.copyWith(status: DownloadStatus.paused);
      _activeTasks[bookId] = paused;
      _progressController.add(paused);
    }
  }

  /// 取消下载
  void cancelDownload(String bookId) {
    _cancelFlags[bookId] = true;
    _taskQueues[bookId]?.clear();
    final current = _activeTasks[bookId];
    if (current != null) {
      final idle = current.copyWith(status: DownloadStatus.idle);
      _activeTasks.remove(bookId);
      _progressController.add(idle);
    }
  }

  void dispose() {
    _progressController.close();
  }
}
