import 'package:flutter/material.dart';
import '../../sources/models/chapter_item.dart';
export '../../sources/models/chapter_item.dart';


/// 全功能目录抽屉 (catalog_drawer.dart)
/// 支持关键词快速检索、正倒序瞬时切换、当前章节高亮与自动定位
class CatalogDrawer extends StatefulWidget {
  final List<ChapterItem> chapters;
  final int currentChapterIndex;
  final ValueChanged<int> onSelectChapter;
  final VoidCallback? onOpenDownload;
  final VoidCallback? onOpenNotes;

  const CatalogDrawer({
    super.key,
    required this.chapters,
    required this.currentChapterIndex,
    required this.onSelectChapter,
    this.onOpenDownload,
    this.onOpenNotes,
  });

  @override
  State<CatalogDrawer> createState() => _CatalogDrawerState();
}

class _CatalogDrawerState extends State<CatalogDrawer> {
  final TextEditingController _searchController = TextEditingController();
  bool _isAscending = true;
  String _filterKeyword = '';
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentChapter();
    });
  }

  void _scrollToCurrentChapter() {
    if (_scrollController.hasClients && widget.currentChapterIndex > 0) {
      final targetOffset = (widget.currentChapterIndex * 48.0) - 100.0;
      _scrollController.animateTo(
        targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var displayList = widget.chapters.where((c) {
      if (_filterKeyword.isEmpty) return true;
      return c.title.contains(_filterKeyword);
    }).toList();

    if (!_isAscending) {
      displayList = displayList.reversed.toList();
    }

    return Container(
      width: MediaQuery.of(context).size.width * 0.85,
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            // 抽屉头部
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  const Text(
                    '目录',
                    style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Text(
                    '共 ${widget.chapters.length} 章',
                    style: TextStyle(
                      fontSize: 13.0,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  if (widget.onOpenNotes != null) ...[
                    TextButton.icon(
                      key: const ValueKey('catalog_drawer_notes_btn'),
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onOpenNotes!();
                      },
                      icon: const Icon(Icons.rate_review_rounded, size: 16),
                      label: const Text('笔记'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6.0),
                      ),
                    ),
                    const SizedBox(width: 4.0),
                  ],
                  if (widget.onOpenDownload != null) ...[
                    TextButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onOpenDownload!();
                      },
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('缓存'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6.0),
                      ),
                    ),
                    const SizedBox(width: 4.0),
                  ],
                  // 正倒序切换按钮
                  TextButton.icon(
                    onPressed: () => setState(() => _isAscending = !_isAscending),
                    icon: Icon(_isAscending ? Icons.arrow_downward : Icons.arrow_upward, size: 16),
                    label: Text(_isAscending ? '倒序' : '正序'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    ),
                  ),
                ],
              ),
            ),

            // 搜索过滤输入框
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
              child: Container(
                height: 40.0,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12.0),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Row(
                  children: [
                    Icon(Icons.search, size: 18, color: Theme.of(context).hintColor),
                    const SizedBox(width: 8.0),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(fontSize: 14.0),
                        decoration: const InputDecoration(
                          hintText: '搜索章节名...',
                          hintStyle: TextStyle(fontSize: 13.0),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (val) => setState(() => _filterKeyword = val.trim()),
                      ),
                    ),
                    if (_filterKeyword.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() => _filterKeyword = '');
                        },
                        child: const Icon(Icons.clear, size: 16),
                      ),
                  ],
                ),
              ),
            ),

            const Divider(height: 1),

            // 章节列表
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: displayList.length,
                itemExtent: 48.0,
                itemBuilder: (context, idx) {
                  final chapter = displayList[idx];
                  final isCurrent = chapter.index == widget.currentChapterIndex;

                  return InkWell(
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onSelectChapter(chapter.index);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      alignment: Alignment.centerLeft,
                      color: isCurrent
                          ? const Color(0xFF5B7FFF).withValues(alpha: 0.12)
                          : Colors.transparent,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              chapter.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14.0,
                                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                color: isCurrent ? const Color(0xFF5B7FFF) : null,
                              ),
                            ),
                          ),
                          if (chapter.isCached)
                            const Padding(
                              padding: EdgeInsets.only(left: 6.0),
                              child: Icon(Icons.download_done_rounded, size: 14, color: Colors.green),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
