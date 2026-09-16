import 'dart:async';
import 'package:flutter/material.dart';
import '../../sources/models/chapter_item.dart';
import '../data/storage_service.dart';
import '../services/download_service.dart';
import '../../../core/theme/soft_theme.dart';
import '../../../core/components/soft_card.dart';

/// 离线缓存下载调度底部弹窗 (download_sheet.dart)
/// Modern Soft UI 风格，支持快速缓存后 20 章、50 章、全本，实时显示进度与存储占用
class DownloadSheet extends StatefulWidget {
  final String bookId;
  final String bookTitle;
  final List<ChapterItem> chapters;
  final int currentChapterIndex;
  final VoidCallback? onCacheUpdated;

  const DownloadSheet({
    super.key,
    required this.bookId,
    required this.bookTitle,
    required this.chapters,
    required this.currentChapterIndex,
    this.onCacheUpdated,
  });

  static Future<void> show(
    BuildContext context, {
    required String bookId,
    required String bookTitle,
    required List<ChapterItem> chapters,
    required int currentChapterIndex,
    VoidCallback? onCacheUpdated,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DownloadSheet(
        bookId: bookId,
        bookTitle: bookTitle,
        chapters: chapters,
        currentChapterIndex: currentChapterIndex,
        onCacheUpdated: onCacheUpdated,
      ),
    );
  }

  @override
  State<DownloadSheet> createState() => _DownloadSheetState();
}

class _DownloadSheetState extends State<DownloadSheet> {
  final DownloadService _downloadService = DownloadService();
  final StorageService _storageService = StorageService();

  StreamSubscription<DownloadProgress>? _progressSub;
  DownloadProgress? _currentProgress;
  int _cachedCount = 0;
  int _cacheSizeBytes = 0;
  bool _isLoadingCacheInfo = true;

  @override
  void initState() {
    super.initState();
    _currentProgress = _downloadService.getProgress(widget.bookId);
    _progressSub = _downloadService.progressStream.listen((p) {
      if (p.bookId == widget.bookId && mounted) {
        setState(() {
          _currentProgress = p;
        });
        if (p.status == DownloadStatus.completed) {
          _refreshCacheInfo();
          widget.onCacheUpdated?.call();
        }
      }
    });

    _refreshCacheInfo();
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    super.dispose();
  }

  Future<void> _refreshCacheInfo() async {
    final count = await _storageService.getDownloadedChaptersCount(widget.bookId);
    final size = await _storageService.getBookCacheSize(widget.bookId);
    if (mounted) {
      setState(() {
        _cachedCount = count;
        _cacheSizeBytes = size;
        _isLoadingCacheInfo = false;
      });
    }
  }

  void _triggerBatchDownload(int count) {
    _downloadService.startBatchDownload(
      bookId: widget.bookId,
      bookTitle: widget.bookTitle,
      chapters: widget.chapters,
      startIndex: widget.currentChapterIndex,
      count: count,
    );
  }

  void _triggerDownloadAll() {
    _downloadService.startBatchDownload(
      bookId: widget.bookId,
      bookTitle: widget.bookTitle,
      chapters: widget.chapters,
      startIndex: 0,
      count: widget.chapters.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = SoftTheme.of(context);
    final totalChapters = widget.chapters.length;
    final isDownloading = _currentProgress != null &&
        _currentProgress!.status == DownloadStatus.downloading;

    return Material(
      color: colors.card,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. 拖动手柄
              Center(
                child: Container(
                  width: 36.0,
                  height: 4.0,
                  decoration: BoxDecoration(
                    color: colors.textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2.0),
                  ),
                ),
              ),
              const SizedBox(height: 16.0),

              // 2. 标题与缓存统计
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '离线下载调度中心',
                        style: TextStyle(
                          fontSize: 18.0,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        widget.bookTitle,
                        style: TextStyle(
                          fontSize: 13.0,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    child: Text(
                      _isLoadingCacheInfo
                          ? '统计中...'
                          : '已离线 $_cachedCount/$totalChapters 章 (${StorageService.formatBytes(_cacheSizeBytes)})',
                      style: TextStyle(
                        fontSize: 11.0,
                        fontWeight: FontWeight.bold,
                        color: colors.accent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16.0),

              // 3. 下载进度实时监控卡片
              if (_currentProgress != null &&
                  _currentProgress!.status != DownloadStatus.idle) ...[
                SoftCard(
                  colors: colors,
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isDownloading
                                    ? Icons.downloading_rounded
                                    : Icons.check_circle_rounded,
                                color: colors.accent,
                                size: 18.0,
                              ),
                              const SizedBox(width: 8.0),
                              Text(
                                isDownloading ? '正在后台高速缓存...' : '离线缓存已就绪',
                                style: TextStyle(
                                  fontSize: 13.0,
                                  fontWeight: FontWeight.bold,
                                  color: colors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${(_currentProgress!.progress * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: 14.0,
                              fontWeight: FontWeight.bold,
                              color: colors.accent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10.0),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4.0),
                        child: LinearProgressIndicator(
                          value: _currentProgress!.progress,
                          minHeight: 6.0,
                          backgroundColor: colors.surface,
                          valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _currentProgress!.currentChapterTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.0,
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                          Text(
                            '${_currentProgress!.completed}/${_currentProgress!.total} 章  ${_currentProgress!.speedText}',
                            style: TextStyle(
                              fontSize: 11.0,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      if (isDownloading) ...[
                        const SizedBox(height: 10.0),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.close, size: 14.0),
                              label: const Text('取消下载', style: TextStyle(fontSize: 12.0)),
                              onPressed: () {
                                _downloadService.cancelDownload(widget.bookId);
                              },
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16.0),
              ],

              // 4. 批量操作选项
              Text(
                '快捷离线方案',
                style: TextStyle(
                  fontSize: 13.0,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 10.0),
              Row(
                children: [
                  Expanded(
                    child: _buildBatchOptionButton(
                      colors: colors,
                      icon: Icons.download_rounded,
                      title: '缓存后 20 章',
                      subtitle: '适合通勤碎片阅读',
                      onTap: isDownloading ? null : () => _triggerBatchDownload(20),
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: _buildBatchOptionButton(
                      colors: colors,
                      icon: Icons.offline_bolt_rounded,
                      title: '缓存后 50 章',
                      subtitle: '推荐 · 畅读不断章',
                      isHighlight: true,
                      onTap: isDownloading ? null : () => _triggerBatchDownload(50),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12.0),
              Row(
                children: [
                  Expanded(
                    child: _buildBatchOptionButton(
                      colors: colors,
                      icon: Icons.all_inclusive_rounded,
                      title: '缓存全本章节',
                      subtitle: '全量离线 · 断网无忧',
                      onTap: isDownloading ? null : _triggerDownloadAll,
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: _buildBatchOptionButton(
                      colors: colors,
                      icon: Icons.delete_outline_rounded,
                      title: '清空本书缓存',
                      subtitle: '释放本地磁盘空间',
                      isDestructive: true,
                      onTap: isDownloading
                          ? null
                          : () async {
                              await _storageService.clearBookCache(widget.bookId);
                              await _refreshCacheInfo();
                              widget.onCacheUpdated?.call();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('已成功释放本书所有本地缓存！'),
                                    behavior: SnackBarBehavior.floating,
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              }
                            },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBatchOptionButton({
    required SoftColors colors,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    bool isHighlight = false,
    bool isDestructive = false,
  }) {
    final borderColor = isHighlight
        ? colors.accent
        : (isDestructive
            ? Colors.red.withValues(alpha: 0.3)
            : colors.textSecondary.withValues(alpha: 0.15));

    final iconColor = isHighlight
        ? colors.accent
        : (isDestructive ? Colors.redAccent : colors.textPrimary);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
          decoration: BoxDecoration(
            color: isHighlight
                ? colors.accent.withValues(alpha: 0.08)
                : colors.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(color: borderColor, width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18.0, color: iconColor),
                  const SizedBox(width: 6.0),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 13.0,
                        fontWeight: FontWeight.bold,
                        color: isDestructive ? Colors.redAccent : colors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4.0),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10.0,
                  color: colors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
