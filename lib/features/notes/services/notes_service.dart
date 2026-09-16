import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/annotation.dart';
import '../models/bookmark.dart';

/// 读者书签与划线批注持久化管理服务
class NotesService {
  static final NotesService _instance = NotesService._internal();
  factory NotesService() => _instance;
  NotesService._internal();

  static const String _keyBookmarks = 'novel_reader_bookmarks';
  static const String _keyAnnotations = 'novel_reader_annotations';

  SharedPreferences? _prefs;

  final ValueNotifier<int> changeNotifier = ValueNotifier<int>(0);

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  @visibleForTesting
  void setPrefs(SharedPreferences prefs) {
    _prefs = prefs;
  }

  // ==================== 书签管理 ====================

  /// 获取所有书签
  Future<List<Bookmark>> getAllBookmarks() async {
    final prefs = await _getPrefs();
    final raw = prefs.getString(_keyBookmarks);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => Bookmark.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// 获取单本书的所有书签（按创建时间倒序）
  Future<List<Bookmark>> getBookmarks(String bookId) async {
    final all = await getAllBookmarks();
    final filtered = all.where((b) => b.bookId == bookId).toList();
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return filtered;
  }

  /// 添加或更新书签
  Future<void> saveBookmark(Bookmark bookmark) async {
    final all = await getAllBookmarks();
    final idx = all.indexWhere((b) => b.id == bookmark.id);
    if (idx >= 0) {
      all[idx] = bookmark;
    } else {
      all.add(bookmark);
    }
    await _saveAllBookmarks(all);
    changeNotifier.value++;
  }

  /// 移除书签
  Future<void> removeBookmark(String id) async {
    final all = await getAllBookmarks();
    all.removeWhere((b) => b.id == id);
    await _saveAllBookmarks(all);
    changeNotifier.value++;
  }

  /// 检查某位置是否已存在书签
  Future<bool> isBookmarked(String bookId, int chapterIndex, int charOffset) async {
    final bookmarks = await getBookmarks(bookId);
    return bookmarks.any((b) =>
        b.chapterIndex == chapterIndex && (b.charOffset - charOffset).abs() < 100);
  }

  /// 批量覆盖保存书签（供云同步使用）
  Future<void> setAllBookmarks(List<Bookmark> bookmarks) async {
    await _saveAllBookmarks(bookmarks);
    changeNotifier.value++;
  }

  Future<void> _saveAllBookmarks(List<Bookmark> bookmarks) async {
    final prefs = await _getPrefs();
    final encoded = jsonEncode(bookmarks.map((b) => b.toJson()).toList());
    await prefs.setString(_keyBookmarks, encoded);
  }

  // ==================== 划线与批注管理 ====================

  /// 获取所有划线批注
  Future<List<Annotation>> getAllAnnotations() async {
    final prefs = await _getPrefs();
    final raw = prefs.getString(_keyAnnotations);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => Annotation.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// 获取单本书的所有划线批注
  Future<List<Annotation>> getAnnotations(String bookId, {int? chapterIndex}) async {
    final all = await getAllAnnotations();
    var filtered = all.where((a) => a.bookId == bookId).toList();
    if (chapterIndex != null) {
      filtered = filtered.where((a) => a.chapterIndex == chapterIndex).toList();
    }
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return filtered;
  }

  /// 添加或更新划线批注
  Future<void> saveAnnotation(Annotation annotation) async {
    final all = await getAllAnnotations();
    final idx = all.indexWhere((a) => a.id == annotation.id);
    if (idx >= 0) {
      all[idx] = annotation;
    } else {
      all.add(annotation);
    }
    await _saveAllAnnotations(all);
    changeNotifier.value++;
  }

  /// 移除划线批注
  Future<void> removeAnnotation(String id) async {
    final all = await getAllAnnotations();
    all.removeWhere((a) => a.id == id);
    await _saveAllAnnotations(all);
    changeNotifier.value++;
  }

  /// 批量覆盖保存划线批注（供云同步使用）
  Future<void> setAllAnnotations(List<Annotation> annotations) async {
    await _saveAllAnnotations(annotations);
    changeNotifier.value++;
  }

  Future<void> _saveAllAnnotations(List<Annotation> annotations) async {
    final prefs = await _getPrefs();
    final encoded = jsonEncode(annotations.map((a) => a.toJson()).toList());
    await prefs.setString(_keyAnnotations, encoded);
  }

  // ==================== 导出 Markdown 笔记 ====================

  /// 将书籍笔记与划线导出为格式化 Markdown 文本
  Future<String> exportNotesAsMarkdown(String bookId, String bookTitle) async {
    final annotations = await getAnnotations(bookId);
    final bookmarks = await getBookmarks(bookId);

    final buffer = StringBuffer();
    buffer.writeln('# 《$bookTitle》读书笔记与摘录');
    buffer.writeln();
    buffer.writeln('> 导出时间：${DateTime.now().toString().split('.')[0]}');
    buffer.writeln('> 来源：藏书阁 Modern Soft Reader');
    buffer.writeln();

    if (annotations.isNotEmpty) {
      buffer.writeln('## 划线与批注 (${annotations.length})');
      buffer.writeln();
      for (final a in annotations) {
        final colorName = Annotation.colorNames[a.colorIndex.clamp(0, 3)];
        buffer.writeln('### ${a.chapterTitle}');
        buffer.writeln('- **摘录** [$colorName]：');
        buffer.writeln('  > ${a.selectedText}');
        if (a.note != null && a.note!.trim().isNotEmpty) {
          buffer.writeln('- **心得**：${a.note}');
        }
        buffer.writeln('- *时间*：${a.updatedAt.toString().split('.')[0]}');
        buffer.writeln();
      }
    }

    if (bookmarks.isNotEmpty) {
      buffer.writeln('## 书签记录 (${bookmarks.length})');
      buffer.writeln();
      for (final b in bookmarks) {
        buffer.writeln('- **${b.chapterTitle}**：${b.snippet}');
        buffer.writeln('  *标记于 ${b.createdAt.toString().split('.')[0]}*');
        buffer.writeln();
      }
    }

    return buffer.toString();
  }
}
