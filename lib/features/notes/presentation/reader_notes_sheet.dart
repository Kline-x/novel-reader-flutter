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

  const ReaderNotesSheet({
    super.key,
    required this.bookId,
    required this.bookTitle,
    required this.onNavigate,
  });

  static Future<void> show(
    BuildContext context, {
    required String bookId,
    required String bookTitle,
    required void Function(int chapterIndex, int charOffset) onNavigate,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReaderNotesSheet(
        bookId: bookId,
        bookTitle: bookTitle,
        onNavigate: onNavigate,
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
    await Clipboard.setData(ClipboardData(text: md));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已成功导出 Markdown 笔记并复制到剪贴板！'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = SoftTheme.of(context);
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

            // 标签切换栏
            TabBar(
              controller: _tabController,
              indicatorColor: colors.accent,
              indicatorWeight: 3.0,
              labelColor: colors.textPrimary,
              unselectedLabelColor: colors.textSecondary,
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
