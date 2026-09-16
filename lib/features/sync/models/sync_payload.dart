import '../../notes/models/annotation.dart';
import '../../notes/models/bookmark.dart';
import '../../reader/data/storage_service.dart';

/// WebDAV 多端增量同步载荷数据包
class SyncPayload {
  final int version;
  final String deviceId;
  final String deviceName;
  final DateTime updatedAt;
  final List<ShelfBook> shelf;
  final List<Bookmark> bookmarks;
  final List<Annotation> annotations;

  const SyncPayload({
    this.version = 1,
    required this.deviceId,
    required this.deviceName,
    required this.updatedAt,
    required this.shelf,
    required this.bookmarks,
    required this.annotations,
  });

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'deviceId': deviceId,
      'deviceName': deviceName,
      'updatedAt': updatedAt.toIso8601String(),
      'shelf': shelf.map((b) => b.toJson()).toList(),
      'bookmarks': bookmarks.map((b) => b.toJson()).toList(),
      'annotations': annotations.map((a) => a.toJson()).toList(),
    };
  }

  factory SyncPayload.fromJson(Map<String, dynamic> json) {
    final shelfList = (json['shelf'] as List<dynamic>? ?? [])
        .map((e) => ShelfBook.fromJson(e as Map<String, dynamic>))
        .toList();

    final bookmarkList = (json['bookmarks'] as List<dynamic>? ?? [])
        .map((e) => Bookmark.fromJson(e as Map<String, dynamic>))
        .toList();

    final annotationList = (json['annotations'] as List<dynamic>? ?? [])
        .map((e) => Annotation.fromJson(e as Map<String, dynamic>))
        .toList();

    return SyncPayload(
      version: json['version'] as int? ?? 1,
      deviceId: json['deviceId'] as String? ?? 'unknown_device',
      deviceName: json['deviceName'] as String? ?? 'Flutter Client',
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      shelf: shelfList,
      bookmarks: bookmarkList,
      annotations: annotationList,
    );
  }
}
