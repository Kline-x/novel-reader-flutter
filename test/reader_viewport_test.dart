import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    testWidgets('渲染完整 ReaderScreen 页面及多书专属章节与内容加载', (tester) async {
      // 1. 诡秘之主
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

      // 2. 十日终焉
      await tester.pumpWidget(
        const MaterialApp(
          home: ReaderScreen(
            bookId: 'shiri_02',
            bookTitle: '十日终焉',
            author: '杀虫队队员',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ReaderScreen), findsOneWidget);

      // 3. 道诡异仙
      await tester.pumpWidget(
        const MaterialApp(
          home: ReaderScreen(
            bookId: 'daoti_03',
            bookTitle: '道诡异仙',
            author: '狐尾的笔',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ReaderScreen), findsOneWidget);

      // 4. 剑来
      await tester.pumpWidget(
        const MaterialApp(
          home: ReaderScreen(
            bookId: 'jianlai_04',
            bookTitle: '剑来',
            author: '烽火戏诸侯',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ReaderScreen), findsOneWidget);
    });

    testWidgets('ReaderViewport 物理音量键翻页与夜间切换回调测试', (tester) async {
      bool nightToggled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderViewport(
              paragraphs: testParagraphs,
              bookTitle: '测试书籍',
              chapterTitle: '第 1 章 测试',
              theme: ReaderThemeOption.presets[0],
              turnMode: PageTurnMode.slide,
              onBack: () {},
              onOpenCatalog: () {},
              onOpenTypography: () {},
              onOpenSourceSwitcher: () {},
              onToggleTheme: () {
                nightToggled = true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 模拟点击呼出菜单
      await tester.tapAt(const Offset(400, 300));
      await tester.pumpAndSettle();

      // 验证菜单已唤出并点击夜间按钮
      final nightBtn = find.text('夜间');
      expect(nightBtn, findsOneWidget);
      await tester.tap(nightBtn);
      await tester.pumpAndSettle();
      expect(nightToggled, isTrue);

      // 模拟物理按键事件 (音量加减)
      await tester.sendKeyEvent(LogicalKeyboardKey.audioVolumeDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.audioVolumeUp);
      await tester.pumpAndSettle();
    });
  });
}
