import 'package:flutter/material.dart';
import '../../sources/models/chapter_item.dart';
import 'reader_page_theme.dart';
export '../../sources/models/chapter_item.dart';

/// 全功能目录抽屉 (catalog_drawer.dart)
/// 支持关键词快速检索、正倒序瞬时切换、当前章节高亮与自动定位，全面适配深色模式
class CatalogDrawer extends StatefulWidget {
  final List<ChapterItem> chapters;
  final int currentChapterIndex;
  final ValueChanged<int> onSelectChapter;
  final VoidCallback? onOpenDownload;
  final VoidCallback? onOpenNotes;
  final ReaderThemeOption? theme;
  final bool isDark;

  const CatalogDrawer({
    super.key,
    required this.chapters,
    required this.currentChapterIndex,
    required this.onSelectChapter,
    this.onOpenDownload,
    this.onOpenNotes,
    this.theme,
    this.isDark = false,
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
    final isDark = widget.theme?.isDark ?? widget.isDark;
    final primaryTextColor = isDark
        ? Colors.white
        : (Theme.of(context).textTheme.titleLarge?.color ??
            const Color(0xFF1F2329));
    final secondaryTextColor = isDark
        ? Colors.white54
        : (Theme.of(context).textTheme.bodySmall?.color ??
            const Color(0xFF8F959E));
    final accentColor =
        isDark ? const Color(0xFF7098FF) : const Color(0xFF5B7FFF);

    var displayList = widget.chapters.where((c) {
      if (_filterKeyword.isEmpty) return true;
      return c.title.toLowerCase().contains(_filterKeyword.toLowerCase());
    }).toList();

    if (!_isAscending) {
      displayList = displayList.reversed.toList();
    }

    return Container(
      width: MediaQuery.of(context).size.width * 0.85,
      color: isDark
          ? const Color(0xFF1E2022)
          : Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            // 抽屉头部
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  RichText(
                    text: TextSpan(
                      text: '目录',
                      style: TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                        color: primaryTextColor,
                      ),
                      children: [
                        TextSpan(
                          text: ' (${widget.chapters.length})',
                          style: TextStyle(
                            fontSize: 12.0,
                            fontWeight: FontWeight.normal,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (widget.onOpenNotes != null) ...[
                    TextButton.icon(
                      key: const ValueKey('catalog_drawer_notes_btn'),
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onOpenNotes!();
                      },
                      icon: Icon(Icons.rate_review_rounded,
                          size: 14, color: accentColor),
                      label: Text('笔记',
                          style: TextStyle(fontSize: 12, color: accentColor)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 2.0),
                  ],
                  if (widget.onOpenDownload != null) ...[
                    TextButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onOpenDownload!();
                      },
                      icon: Icon(Icons.download_rounded,
                          size: 14, color: accentColor),
                      label: Text('缓存',
                          style: TextStyle(fontSize: 12, color: accentColor)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 2.0),
                  ],
                  // 正倒序切换按钮
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _isAscending = !_isAscending),
                    icon: Icon(
                        _isAscending
                            ? Icons.arrow_downward
                            : Icons.arrow_upward,
                        size: 14,
                        color: accentColor),
                    label: Text(_isAscending ? '倒序' : '正序',
                        style: TextStyle(fontSize: 12, color: accentColor)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),

            // 搜索过滤输入框
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
              child: Container(
                height: 40.0,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF282A2D)
                      : Theme.of(context).dividerColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.transparent,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.search,
                      size: 18,
                      color:
                          isDark ? Colors.white54 : Theme.of(context).hintColor,
                    ),
                    const SizedBox(width: 8.0),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(
                          fontSize: 14.0,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: '搜索章节名...',
                          hintStyle: TextStyle(
                            fontSize: 13.0,
                            color: isDark
                                ? Colors.white38
                                : Theme.of(context).hintColor,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (val) =>
                            setState(() => _filterKeyword = val.trim()),
                      ),
                    ),
                    if (_filterKeyword.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() => _filterKeyword = '');
                        },
                        child: Icon(Icons.clear,
                            size: 16, color: isDark ? Colors.white54 : null),
                      ),
                  ],
                ),
              ),
            ),

            // 搜索命中计数提示
            if (_filterKeyword.isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '找到 ${displayList.length} 个相关章节',
                    style: TextStyle(
                      fontSize: 12.0,
                      fontWeight: FontWeight.w600,
                      color: accentColor,
                    ),
                  ),
                ),
              ),

            Divider(height: 1, color: isDark ? Colors.white12 : null),

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
                          ? const Color(0xFF5B7FFF)
                              .withValues(alpha: isDark ? 0.22 : 0.12)
                          : Colors.transparent,
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildChapterTitle(
                              chapter.title,
                              isCurrent: isCurrent,
                              isDark: isDark,
                              accentColor: accentColor,
                            ),
                          ),
                          if (chapter.isCached)
                            const Padding(
                              padding: EdgeInsets.only(left: 6.0),
                              child: Icon(Icons.download_done_rounded,
                                  size: 14, color: Colors.green),
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

  /// 构建章节标题（支持关键词高亮与深色适配）
  Widget _buildChapterTitle(
    String title, {
    required bool isCurrent,
    required bool isDark,
    required Color accentColor,
  }) {
    final defaultColor = isCurrent
        ? const Color(0xFF5B7FFF)
        : (isDark ? Colors.white70 : const Color(0xFF1F2329));

    if (_filterKeyword.isEmpty ||
        !title.toLowerCase().contains(_filterKeyword.toLowerCase())) {
      return Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 14.0,
          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
          color: defaultColor,
        ),
      );
    }

    // 分割关键词以进行精确高亮
    final spans = <TextSpan>[];
    final lowerTitle = title.toLowerCase();
    final lowerKeyword = _filterKeyword.toLowerCase();
    int start = 0;

    while (true) {
      final index = lowerTitle.indexOf(lowerKeyword, start);
      if (index == -1) {
        if (start < title.length) {
          spans.add(TextSpan(
            text: title.substring(start),
            style: TextStyle(color: defaultColor),
          ));
        }
        break;
      }
      if (index > start) {
        spans.add(TextSpan(
          text: title.substring(start, index),
          style: TextStyle(color: defaultColor),
        ));
      }
      spans.add(TextSpan(
        text: title.substring(index, index + _filterKeyword.length),
        style: TextStyle(
          color: accentColor,
          fontWeight: FontWeight.bold,
          backgroundColor: accentColor.withValues(alpha: 0.18),
        ),
      ));
      start = index + _filterKeyword.length;
    }

    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: TextStyle(
          fontSize: 14.0,
          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
        ),
        children: spans,
      ),
    );
  }
}
