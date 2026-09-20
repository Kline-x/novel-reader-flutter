import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/components/soft_button.dart';
import '../../../core/theme/soft_theme.dart';
import '../models/annotation.dart';

/// 读者划线与批注录入弹窗（支持选字/选句/选段/选行及两端步进微调）
class AddAnnotationDialog extends StatefulWidget {
  final String bookId;
  final String bookTitle;
  final int chapterIndex;
  final String chapterTitle;
  final int charStart;
  final int charEnd;
  final String selectedText;
  final bool isDark;
  final AnnotationSelectionContext? selectionContext;

  const AddAnnotationDialog({
    super.key,
    required this.bookId,
    required this.bookTitle,
    required this.chapterIndex,
    required this.chapterTitle,
    required this.charStart,
    required this.charEnd,
    required this.selectedText,
    this.isDark = false,
    this.selectionContext,
  });

  static Future<Annotation?> show(
    BuildContext context, {
    required String bookId,
    required String bookTitle,
    required int chapterIndex,
    required String chapterTitle,
    required int charStart,
    required int charEnd,
    required String selectedText,
    bool isDark = false,
    AnnotationSelectionContext? selectionContext,
  }) {
    return showDialog<Annotation>(
      context: context,
      builder: (_) => AddAnnotationDialog(
        bookId: bookId,
        bookTitle: bookTitle,
        chapterIndex: chapterIndex,
        chapterTitle: chapterTitle,
        charStart: charStart,
        charEnd: charEnd,
        selectedText: selectedText,
        isDark: isDark,
        selectionContext: selectionContext,
      ),
    );
  }

  @override
  State<AddAnnotationDialog> createState() => _AddAnnotationDialogState();
}

class _AddAnnotationDialogState extends State<AddAnnotationDialog> {
  int _selectedColorIndex = 0;
  final TextEditingController _noteController = TextEditingController();

  late int _currentCharStart;
  late int _currentCharEnd;
  late String _currentSelectedText;
  AnnotationSelectionMode? _activeMode;

  @override
  void initState() {
    super.initState();
    final ctx = widget.selectionContext;
    if (ctx != null &&
        ctx.sentenceCandidate != null &&
        ctx.sentenceCandidate!.text.isNotEmpty) {
      // 智能默认：读书划线最常用单句
      _activeMode = AnnotationSelectionMode.sentence;
      _currentCharStart = ctx.sentenceCandidate!.charStart;
      _currentCharEnd = ctx.sentenceCandidate!.charEnd;
      _currentSelectedText = ctx.sentenceCandidate!.text;
    } else {
      _currentCharStart = widget.charStart;
      _currentCharEnd = widget.charEnd;
      _currentSelectedText = widget.selectedText;
      if (ctx?.lineCandidate != null) {
        _activeMode = AnnotationSelectionMode.line;
      }
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _switchMode(AnnotationSelectionMode mode) {
    final ctx = widget.selectionContext;
    if (ctx == null) return;
    AnnotationCandidate? cand;
    switch (mode) {
      case AnnotationSelectionMode.word:
        cand = ctx.wordCandidate;
        break;
      case AnnotationSelectionMode.sentence:
        cand = ctx.sentenceCandidate;
        break;
      case AnnotationSelectionMode.paragraph:
        cand = ctx.paragraphCandidate;
        break;
      case AnnotationSelectionMode.line:
        cand = ctx.lineCandidate;
        break;
    }
    if (cand != null && cand.text.isNotEmpty) {
      setState(() {
        _activeMode = mode;
        _currentCharStart = cand!.charStart;
        _currentCharEnd = cand.charEnd;
        _currentSelectedText = cand.text;
      });
    }
  }

  void _adjustStart(int delta) {
    final ctx = widget.selectionContext;
    if (ctx == null || ctx.fullContextText == null) return;
    final fullText = ctx.fullContextText!;
    final base = ctx.contextBaseOffset;

    final minBound = base;
    final maxBound = math.max<int>(base, _currentCharEnd - 1);
    final newStart =
        (_currentCharStart + delta).clamp(minBound, maxBound).toInt();
    if (newStart == _currentCharStart) return;

    final relStart = (newStart - base).clamp(0, fullText.length).toInt();
    final relEnd =
        (_currentCharEnd - base).clamp(relStart + 1, fullText.length).toInt();
    final newText = fullText.substring(relStart, relEnd).trim();

    setState(() {
      _activeMode = null;
      _currentCharStart = newStart;
      if (newText.isNotEmpty) {
        _currentSelectedText = newText;
      }
    });
  }

  void _adjustEnd(int delta) {
    final ctx = widget.selectionContext;
    if (ctx == null || ctx.fullContextText == null) return;
    final fullText = ctx.fullContextText!;
    final base = ctx.contextBaseOffset;
    final maxEnd = base + fullText.length;

    final newEnd =
        (_currentCharEnd + delta).clamp(_currentCharStart + 1, maxEnd).toInt();
    if (newEnd == _currentCharEnd) return;

    final relStart =
        (_currentCharStart - base).clamp(0, fullText.length).toInt();
    final relEnd = (newEnd - base).clamp(relStart + 1, fullText.length).toInt();
    final newText = fullText.substring(relStart, relEnd).trim();

    setState(() {
      _activeMode = null;
      _currentCharEnd = newEnd;
      if (newText.isNotEmpty) {
        _currentSelectedText = newText;
      }
    });
  }

  void _submit() {
    final now = DateTime.now();
    final note = _noteController.text.trim();
    final annotation = Annotation(
      id: 'ann_${now.millisecondsSinceEpoch}',
      bookId: widget.bookId,
      bookTitle: widget.bookTitle,
      chapterIndex: widget.chapterIndex,
      chapterTitle: widget.chapterTitle,
      charStart: _currentCharStart,
      charEnd: _currentCharEnd,
      selectedText: _currentSelectedText,
      note: note.isEmpty ? null : note,
      colorIndex: _selectedColorIndex,
      createdAt: now,
      updatedAt: now,
    );
    Navigator.of(context).pop(annotation);
  }

  Widget _buildMiniStepBtn(
      String label, VoidCallback onTap, SoftColors colors, String keyStr) {
    return GestureDetector(
      key: ValueKey(keyStr),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 3.5),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(6.0),
          border: Border.all(
            color: colors.borderSubtle,
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionModeTabs(SoftColors colors) {
    final ctx = widget.selectionContext;
    if (ctx == null) return const SizedBox.shrink();

    final modes = [
      if (ctx.wordCandidate != null) AnnotationSelectionMode.word,
      if (ctx.sentenceCandidate != null) AnnotationSelectionMode.sentence,
      if (ctx.paragraphCandidate != null) AnnotationSelectionMode.paragraph,
      if (ctx.lineCandidate != null) AnnotationSelectionMode.line,
    ];

    if (modes.length <= 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Container(
        padding: const EdgeInsets.all(3.0),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: colors.borderSubtle, width: 0.5),
        ),
        child: Row(
          children: modes.map((mode) {
            final isSelected = _activeMode == mode;
            return Expanded(
              child: GestureDetector(
                key: ValueKey('mode_tab_${mode.name}'),
                behavior: HitTestBehavior.opaque,
                onTap: () => _switchMode(mode),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (widget.isDark ? colors.card : Colors.white)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(9.0),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(
                                  alpha: widget.isDark ? 0.25 : 0.05),
                              blurRadius: 4.0,
                              offset: const Offset(0, 1.5),
                            )
                          ]
                        : null,
                  ),
                  child: Text(
                    mode.badgeText,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? colors.accent : colors.textSecondary,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.isDark ? SoftColors.night : SoftTheme.of(context);
    final hasContextForAdjust =
        widget.selectionContext?.fullContextText != null;

    return Dialog(
      backgroundColor: colors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.edit_note_rounded, color: colors.accent, size: 22.0),
                const SizedBox(width: 8.0),
                Text(
                  '添加划线批注',
                  style: TextStyle(
                    fontSize: 17.0,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12.0),

            // 选区维度快速切换药丸栏
            _buildSelectionModeTabs(colors),

            // 引言卡片
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(14.0),
                border: Border.all(color: colors.borderSubtle, width: 0.5),
              ),
              child: Text(
                '“$_currentSelectedText”',
                key: const ValueKey('annotation_dialog_selected_text'),
                style: TextStyle(
                  fontSize: 13.0,
                  height: 1.45,
                  fontStyle: FontStyle.italic,
                  color: colors.textPrimary,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // 两端微调步进器
            if (hasContextForAdjust) ...[
              const SizedBox(height: 8.0),
              // 起点组 / 已选字数 / 终点组三者都是定宽内容，窄屏或字宽略大的
              // 平台（实测鸿蒙）会挤爆这一行。包 Flexible 没用——溢出只会转移到
              // 子 Row 内部；这里整体等比缩小，一个字都不丢。
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text('起点 ',
                            style: TextStyle(
                                fontSize: 10.5, color: colors.textSecondary)),
                        _buildMiniStepBtn('◀ 扩', () => _adjustStart(-1), colors,
                            'btn_start_expand'),
                        const SizedBox(width: 4.0),
                        _buildMiniStepBtn('缩 ▶', () => _adjustStart(1), colors,
                            'btn_start_shrink'),
                      ],
                    ),
                    Text(
                      '已选 ${_currentSelectedText.length} 字',
                      style: TextStyle(
                        fontSize: 11.0,
                        fontWeight: FontWeight.w600,
                        color: colors.accent,
                      ),
                    ),
                    Row(
                      children: [
                        Text('终点 ',
                            style: TextStyle(
                                fontSize: 10.5, color: colors.textSecondary)),
                        _buildMiniStepBtn('◀ 缩', () => _adjustEnd(-1), colors,
                            'btn_end_shrink'),
                        const SizedBox(width: 4.0),
                        _buildMiniStepBtn('扩 ▶', () => _adjustEnd(1), colors,
                            'btn_end_expand'),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14.0),

            // 4色高亮选择器
            Text('高亮色彩',
                style: TextStyle(fontSize: 12.0, color: colors.textSecondary)),
            const SizedBox(height: 8.0),
            Row(
              children: List.generate(Annotation.highlightColors.length, (i) {
                final isSelected = _selectedColorIndex == i;
                final c = Annotation.highlightColors[i];
                return GestureDetector(
                  key: ValueKey('highlight_color_$i'),
                  onTap: () => setState(() => _selectedColorIndex = i),
                  child: Container(
                    margin: const EdgeInsets.only(right: 12.0),
                    width: 32.0,
                    height: 32.0,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? colors.textPrimary
                            : Colors.transparent,
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: c.withValues(alpha: 0.5),
                          blurRadius: isSelected ? 8.0 : 2.0,
                        ),
                      ],
                    ),
                    child: isSelected
                        ? const Icon(Icons.check,
                            size: 16.0, color: Colors.black87)
                        : null,
                  ),
                );
              }),
            ),
            const SizedBox(height: 14.0),

            // 心得批注输入框
            TextField(
              key: const ValueKey('input_annotation_note'),
              controller: _noteController,
              maxLines: 2,
              style: TextStyle(fontSize: 13.0, color: colors.textPrimary),
              decoration: InputDecoration(
                hintText: '写下你的读书感想或批注（选填）...',
                hintStyle:
                    TextStyle(fontSize: 12.0, color: colors.textSecondary),
                filled: true,
                fillColor: colors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide:
                      BorderSide(color: colors.borderSubtle, width: 0.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide(color: colors.accent, width: 1.5),
                ),
                contentPadding: const EdgeInsets.all(12.0),
              ),
            ),
            const SizedBox(height: 18.0),

            // 操作按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child:
                      Text('取消', style: TextStyle(color: colors.textSecondary)),
                ),
                const SizedBox(width: 8.0),
                SoftButton(
                  key: const ValueKey('btn_confirm_annotation'),
                  colors: colors,
                  isActive: true,
                  onPressed: _submit,
                  child: Text(
                    '确定划线',
                    style: TextStyle(
                      fontSize: 13.0,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
