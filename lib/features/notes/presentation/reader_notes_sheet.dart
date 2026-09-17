import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/components/soft_card.dart';
import '../../../core/theme/soft_theme.dart';
import '../models/annotation.dart';
import '../models/bookmark.dart';
import '../services/notes_service.dart';

/// 读者书签与划线笔记汇总抽屉/弹窗 (reader_notes_sheet.dart)
class ReaderNotesSheet extends StatefulWidget {
  final String bookId;
  final String bookTitle;
  final void Function(int chapterIndex, int charOffset) onNavigate;
  final bool isDark;

  const ReaderNotesSheet({
    super.key,
    required this.bookId,
    required this.bookTitle,
    required this.onNavigate,
    this.isDark = false,
  });

  static Future<void> show(
    BuildContext context, {
    required String bookId,
    required String bookTitle,
    required void Function(int chapterIndex, int charOffset) onNavigate,
    bool isDark = false,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReaderNotesSheet(
        bookId: bookId,
        bookTitle: bookTitle,
        onNavigate: onNavigate,
        isDark: isDark,
      ),
    );
  }

  @override
  State<ReaderNotesSheet> createState() => _ReaderNotesSheetState();
}

class _ReaderNotesSheetState extends State<ReaderNotesSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final NotesService _notesService = NotesService();

  List<Bookmark> _bookmarks = [];
  List<Annotation> _annotations = [];
  bool _isLoading = true;
  String? _exportFeedback;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
    _notesService.changeNotifier.addListener(_loadData);
  }

  @override
  void dispose() {
    _notesService.changeNotifier.removeListener(_loadData);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final b = await _notesService.getBookmarks(widget.bookId);
    final a = await _notesService.getAnnotations(widget.bookId);
    if (mounted) {
      setState(() {
        _bookmarks = b;
        _annotations = a;
        _isLoading = false;
      });
    }
  }

  void _exportNotes() async {
    final md = await _notesService.exportNotesAsMarkdown(
      widget.bookId,
      widget.bookTitle,
    );
    try {
      await Clipboard.setData(ClipboardData(text: md));
    } catch (_) {}
    if (mounted) {
      setState(() {
        _exportFeedback = '✓ 笔记已成功导出并复制至剪贴板';
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _exportFeedback = null;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.isDark ? SoftColors.night : SoftTheme.of(context);
    final maxHeight = MediaQuery.of(context).size.height * 0.75;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28.0)),
        boxShadow: SoftDecorations.softShadows(colors, elevation: 4.0),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // 拖动把手
            Container(
              margin: const EdgeInsets.only(top: 10.0, bottom: 6.0),
              width: 36.0,
              height: 4.0,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(2.0),
              ),
            ),

            // 头部标题与导出按键
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              child: Row(
                children: [
                  Text(
                    '书签与笔记',
                    style: TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    key: const ValueKey('btn_export_notes'),
                    onTap: _exportNotes,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                      decoration: BoxDecoration(
                        color: colors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.share_rounded, size: 14.0, color: colors.accent),
                          const SizedBox(width: 4.0),
                          Text(
                            '导出笔记',
                            style: TextStyle(
                              fontSize: 12.0,
                              fontWeight: FontWeight.w600,
                              color: colors.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 就地行内反馈提示条（防止 SnackBar 被 ModalBottomSheet 遮挡）
            if (_exportFeedback != null)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
                decoration: BoxDecoration(
                  color: widget.isDark ? const Color(0xFF103A20) : const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(10.0),
                  border: Border.all(color: const Color(0xFF07C160).withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 16.0, color: Color(0xFF07C160)),
                    const SizedBox(width: 8.0),
                    Expanded(
                      child: Text(
                        _exportFeedback!,
                        style: TextStyle(
                          fontSize: 12.0,
                          fontWeight: FontWeight.w600,
                          color: widget.isDark ? const Color(0xFF70E1A0) : const Color(0xFF1B5E20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // 标签切换栏
            TabBar(
              controller: _tabController,
              indicatorColor: colors.accent,
              indicatorWeight: 3.0,
              labelColor: colors.textPrimary,
              unselectedLabelColor: colors.textSecondary,
              dividerColor: widget.isDark ? Colors.white12 : null,
              tabs: [
                Tab(text: '书签 (${_bookmarks.length})'),
                Tab(text: '划线笔记 (${_annotations.length})'),
              ],
            ),

            // 列表内容
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildBookmarkList(colors),
                        _buildAnnotationList(colors),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookmarkList(SoftColors colors) {
    if (_bookmarks.isEmpty) {
      return Center(
        child: Text('暂无书签，轻触顶栏书签按钮即可添加', style: TextStyle(color: colors.textSecondary)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      itemCount: _bookmarks.length,
      itemBuilder: (context, index) {
        final b = _bookmarks[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 10.0),
          child: SoftCard(
            colors: colors,
            padding: const EdgeInsets.all(12.0),
            onTap: () {
              Navigator.of(context).pop();
              widget.onNavigate(b.chapterIndex, b.charOffset);
            },
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.bookmark_rounded, color: colors.accent, size: 20.0),
                const SizedBox(width: 10.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.chapterTitle,
                        style: TextStyle(
                          fontSize: 14.0,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        b.snippet,
                        style: TextStyle(fontSize: 12.0, color: colors.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        b.createdAt.toString().split('.')[0],
                        style: TextStyle(fontSize: 10.0, color: colors.textSecondary.withValues(alpha: 0.7)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, size: 18.0, color: colors.textSecondary),
                  onPressed: () => _notesService.removeBookmark(b.id),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnnotationList(SoftColors colors) {
    if (_annotations.isEmpty) {
      return Center(
        child: Text('暂无划线笔记，在阅读时长按文本即可划线', style: TextStyle(color: colors.textSecondary)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      itemCount: _annotations.length,
      itemBuilder: (context, index) {
        final a = _annotations[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 10.0),
          child: SoftCard(
            colors: colors,
            padding: const EdgeInsets.all(12.0),
            onTap: () {
              Navigator.of(context).pop();
              widget.onNavigate(a.chapterIndex, a.charStart);
            },
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6.0,
                  height: 42.0,
                  decoration: BoxDecoration(
                    color: a.color,
                    borderRadius: BorderRadius.circular(3.0),
                  ),
                ),
                const SizedBox(width: 10.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            a.chapterTitle,
                            style: TextStyle(
                              fontSize: 13.0,
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                            decoration: BoxDecoration(
                              color: a.color.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(6.0),
                            ),
                            child: Text(
                              Annotation.colorNames[a.colorIndex.clamp(0, 3)],
                              style: TextStyle(fontSize: 10.0, color: colors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6.0),
                      Container(
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Text(
                          '“${a.selectedText}”',
                          style: TextStyle(
                            fontSize: 12.0,
                            fontStyle: FontStyle.italic,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      if (a.note != null && a.note!.trim().isNotEmpty) ...[
                        const SizedBox(height: 6.0),
                        Text(
                          '心得：${a.note}',
                          style: TextStyle(
                            fontSize: 12.0,
                            fontWeight: FontWeight.w500,
                            color: colors.accent,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4.0),
                      Text(
                        a.updatedAt.toString().split('.')[0],
                        style: TextStyle(fontSize: 10.0, color: colors.textSecondary.withValues(alpha: 0.7)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, size: 18.0, color: colors.textSecondary),
                  onPressed: () => _notesService.removeAnnotation(a.id),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
