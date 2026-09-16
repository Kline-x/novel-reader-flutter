import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_reader_flutter/features/reader/presentation/reader_page_theme.dart';
import 'package:novel_reader_flutter/features/reader/presentation/reader_screen.dart';
import 'package:novel_reader_flutter/features/reader/presentation/reader_viewport.dart';

void main() {
  group('ReaderViewport 视口与手势小部件验证', () {
    final testParagraphs = [
      '痛！好痛！头好痛！',
      '绯红的月光透过窗帘的缝隙，斑驳地洒在书桌上。周明瑞只觉得脑袋里仿佛插了一根烧红的铁钎。',
      '镜子里映照出一张年轻但毫无血色的脸庞，黑发深褐瞳孔，额头侧面赫然有一个狰狞焦黑的血洞！',
    ];

    testWidgets('渲染 ReaderViewport 并在平移模式下正常挂载', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderViewport(
              paragraphs: testParagraphs,
              bookTitle: '诡秘之主',
              chapterTitle: '第一章 绯红',
              theme: ReaderThemeOption.presets[0],
              turnMode: PageTurnMode.slide,
              onBack: () {},
              onOpenCatalog: () {},
              onOpenTypography: () {},
              onOpenSourceSwitcher: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 验证未抛出任何异常，且视口成功布局
      expect(find.byType(ReaderViewport), findsOneWidget);
    });

    testWidgets('渲染完整 ReaderScreen 页面', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ReaderScreen(
            bookId: 'guimi_01',
            bookTitle: '诡秘之主',
            author: '爱潜水的乌贼',
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(ReaderScreen), findsOneWidget);
    });
  });
}
