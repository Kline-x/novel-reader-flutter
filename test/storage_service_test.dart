import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_reader_flutter/features/reader/data/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late StorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = Directory.systemTemp.createTempSync('novel_reader_storage_test_');
    storage = StorageService(customCacheDir: tempDir.path);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('StorageService 冷热分级存储测试', () {
    test('热数据：字符级阅读进度持久化与读取 (SharedPreferences)', () async {
      const bookId = 'book_guimi_01';
      // 保存进度
      await storage.saveReadingProgress(
        bookId,
        chapterIndex: 3,
        charOffset: 520,
        chapterPercent: 0.65,
      );

      // 读取进度并比对
      final anchor = await storage.getReadingProgress(bookId);
      expect(anchor, isNotNull);
      expect(anchor!.chapterIndex, 3);
      expect(anchor.charOffset, 520);
      expect(anchor.chapterPercent, 0.65);
    });

    test('热数据：书架列表增删改查与进度联动', () async {
      final now = DateTime.now();
      final book1 = ShelfBook(
        bookId: 'book_1',
        title: '诡秘之主',
        author: '爱潜水的乌贼',
        lastReadTime: now,
      );
      final book2 = ShelfBook(
        bookId: 'book_2',
        title: '宿命之环',
        author: '爱潜水的乌贼',
        lastReadTime: now,
      );

      // 添加到书架
      await storage.addToBookshelf(book1);
      await storage.addToBookshelf(book2);

      var shelf = await storage.getBookshelf();
      expect(shelf.length, 2);
      expect(shelf.any((b) => b.title == '诡秘之主'), isTrue);

      // 更新某本书的阅读进度
      await storage.saveReadingProgress('book_1', chapterIndex: 12, charOffset: 80);
      shelf = await storage.getBookshelf();
      final updatedBook1 = shelf.firstWhere((b) => b.bookId == 'book_1');
      expect(updatedBook1.currentChapterIndex, 12);
      expect(updatedBook1.currentCharOffset, 80);

      // 从书架移除
      await storage.removeFromBookshelf('book_1');
      shelf = await storage.getBookshelf();
      expect(shelf.length, 1);
      expect(shelf.first.title, '宿命之环');
    });

    test('冷数据：章节长文本沙盒文件持久化与缓存大小统计', () async {
      const bookId = 'book_test_100';
      final paragraphsChapter0 = [
        '第一段：周明瑞睁开双眼。',
        '第二段：桌上放着黄铜左轮手枪。',
      ];
      final paragraphsChapter1 = [
        '第一段：廷根市的阴雨连绵不断。',
        '第二段：黑荆棘安保公司。',
      ];

      // 验证未缓存时状态
      expect(await storage.hasChapterCache(bookId, 0), isFalse);
      expect(await storage.getChapterContent(bookId, 0), isNull);

      // 持久化第 0 章与第 1 章
      await storage.saveChapterContent(bookId, 0, paragraphsChapter0);
      await storage.saveChapterContent(bookId, 1, paragraphsChapter1);

      // 验证已缓存并能精确还原段落列表
      expect(await storage.hasChapterCache(bookId, 0), isTrue);
      expect(await storage.hasChapterCache(bookId, 1), isTrue);

      final loadedPara0 = await storage.getChapterContent(bookId, 0);
      expect(loadedPara0, isNotNull);
      expect(loadedPara0!.length, 2);
      expect(loadedPara0[0], '第一段：周明瑞睁开双眼。');
      expect(loadedPara0[1], '第二段：桌上放着黄铜左轮手枪。');

      // 统计缓存大小
      final bookSize = await storage.getBookCacheSize(bookId);
      expect(bookSize, greaterThan(0));

      final totalSize = await storage.getTotalCacheSize();
      expect(totalSize, equals(bookSize));

      // 验证人性化大小格式化
      expect(StorageService.formatBytes(512), '512 B');
      expect(StorageService.formatBytes(2048), '2.0 KB');
      expect(StorageService.formatBytes(1048576 * 3), '3.0 MB');

      // 单书清理
      await storage.clearBookCache(bookId);
      expect(await storage.hasChapterCache(bookId, 0), isFalse);
      expect(await storage.getBookCacheSize(bookId), 0);
    });

    test('冷数据：一键清理全部沙盒缓存', () async {
      await storage.saveChapterContent('b1', 0, ['测试段落1']);
      await storage.saveChapterContent('b2', 0, ['测试段落2']);
      expect(await storage.getTotalCacheSize(), greaterThan(0));

      await storage.clearAllCache();
      expect(await storage.getTotalCacheSize(), 0);
    });
  });
}
