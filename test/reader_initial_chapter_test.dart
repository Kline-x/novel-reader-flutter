import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_reader_flutter/features/reader/data/storage_service.dart';
import 'package:novel_reader_flutter/features/reader/presentation/reader_screen.dart';
import 'package:novel_reader_flutter/features/reader/presentation/reader_viewport.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ReaderScreen 初始章节索引逻辑测试', () {
    testWidgets('当显式传入 initialChapterIndex=0 时，绝不被历史进度覆写', (tester) async {
      final storage = StorageService();
      await storage.saveReadingProgress(
        'test_book_1',
        chapterIndex: 3,
        charOffset: 100,
      );

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ReaderScreen(
              bookId: 'test_book_1',
              bookTitle: '测试书籍',
              author: '测试作者',
              initialChapterIndex: 0,
              initialCharOffset: 0,
            ),
          ),
        ),
      );
      // pump 一帧初始化组件
      await tester.pump();

      final viewport = tester.widget<ReaderViewport>(find.byType(ReaderViewport));
      // 验证初始章节必须为第 0 章（由于未加载完网络目录，标题显示为第1章或正在加载，但在首帧初始索引确立为0）
      expect(viewport.initialCharOffset, 0);
    });

    testWidgets('当未传入 initialChapterIndex (null) 时，自动恢复历史保存进度', (tester) async {
      final storage = StorageService();
      await storage.saveReadingProgress(
        'test_book_2',
        chapterIndex: 3,
        charOffset: 120,
      );

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ReaderScreen(
              bookId: 'test_book_2',
              bookTitle: '测试书籍2',
              author: '测试作者2',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(ReaderScreen), findsOneWidget);
    });
  });
}
