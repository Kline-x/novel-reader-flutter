import 'package:flutter/material.dart';

import '../../../core/components/soft_button.dart';
import '../../../core/theme/soft_theme.dart';
import '../models/annotation.dart';

/// 读者划线与批注录入弹窗
class AddAnnotationDialog extends StatefulWidget {
  final String bookId;
  final String bookTitle;
  final int chapterIndex;
  final String chapterTitle;
  final int charStart;
  final int charEnd;
  final String selectedText;
  final bool isDark;

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
      ),
    );
  }

  @override
  State<AddAnnotationDialog> createState() => _AddAnnotationDialogState();
}

class _AddAnnotationDialogState extends State<AddAnnotationDialog> {
  int _selectedColorIndex = 0;
  final TextEditingController _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
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
      charStart: widget.charStart,
      charEnd: widget.charEnd,
      selectedText: widget.selectedText,
      note: note.isEmpty ? null : note,
      colorIndex: _selectedColorIndex,
      createdAt: now,
      updatedAt: now,
    );
    Navigator.of(context).pop(annotation);
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.isDark ? SoftColors.night : SoftTheme.of(context);

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

            // 引言卡片
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(14.0),
                border: Border.all(color: colors.border),
              ),
              child: Text(
                '“${widget.selectedText}”',
                style: TextStyle(
                  fontSize: 13.0,
                  fontStyle: FontStyle.italic,
                  color: colors.textPrimary,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
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
                  borderSide: BorderSide(color: colors.border),
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
