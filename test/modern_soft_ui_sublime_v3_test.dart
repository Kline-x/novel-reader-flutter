import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_reader_flutter/core/components/ambient_mesh_background.dart';
import 'package:novel_reader_flutter/core/components/book_cover_widget.dart';
import 'package:novel_reader_flutter/core/theme/soft_theme.dart';
import 'package:novel_reader_flutter/core/theme/theme_provider.dart';

import 'package:novel_reader_flutter/features/shelf/presentation/shelf_page.dart';
import 'package:novel_reader_flutter/features/shelf/presentation/book_detail_page.dart';
import 'package:novel_reader_flutter/features/shelf/models/book_item.dart';
import 'package:novel_reader_flutter/features/sources/models/chapter_item.dart';
import 'package:novel_reader_flutter/features/reader/presentation/reader_page_theme.dart';
import 'package:novel_reader_flutter/features/settings/presentation/settings_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Modern Soft UI v3.0 顶级优雅旗舰版 · 设计系统与四大意境 Seam 测试', () {
    test('四大意境 Token 具备完整定义且苍岚烟雨作为默认旗舰主色', () {
      // 1. 验证默认官方推荐主色：苍岚烟雨 (宋瓷天青)
      const jade = SoftColors.mistyJade;
      expect(jade.title, '苍岚烟雨');
      expect(jade.accent, const Color(0xFF236B58));
      expect(jade.background, const Color(0xFFF8FAF7));
      expect(jade.isDark, isFalse);
      expect(jade.borderInner, const Color(0xE6FFFFFF)); // 玉质高光

      // 2. 验证暮色暖珀 (焦糖蜜金)
      const amber = SoftColors.twilightAmber;
      expect(amber.title, '暮色暖珀');
      expect(amber.accent, const Color(0xFFB86820));
      expect(amber.background, const Color(0xFFFAF7F2));

      // 3. 验证紫陌幽兰 (幽兰丁香)
      const orchid = SoftColors.violetOrchid;
      expect(orchid.title, '紫陌幽兰');
      expect(orchid.accent, const Color(0xFF6D599A));
      expect(orchid.background, const Color(0xFFF9F8FC));

      // 4. 验证极夜星芒 (OLED 深空)
      const aurora = SoftColors.auroraSpace;
      expect(aurora.title, '极夜星芒');
      expect(aurora.accent, const Color(0xFF38D9A9));
      expect(aurora.background, const Color(0xFF0C110E));
      expect(aurora.isDark, isTrue);

      // 5. 验证向前兼容别名映射无损
      expect(SoftColors.fromType(SoftPaletteType.beanGreen), SoftColors.mistyJade);
      expect(SoftColors.fromType(SoftPaletteType.parchment), SoftColors.twilightAmber);
      expect(SoftColors.fromType(SoftPaletteType.night), SoftColors.auroraSpace);
    });

    test('SoftDecorations 提供 26px Squircle 连续曲率与玉质双层微高光阴影', () {
      expect(SoftDecorations.squircleCardRadius, 26.0);
      expect(SoftDecorations.squircleSubCardRadius, 18.0);
      expect(SoftDecorations.pillRadius, 9999.0);

      final shadows = SoftDecorations.softShadows(SoftColors.mistyJade);
      expect(shadows.length, greaterThanOrEqualTo(2));
      // 必须包含玉质内轮廓高光与低饱和漫射阴影
      expect(shadows.first.color, SoftColors.mistyJade.borderInner);
    });

    testWidgets('AmbientMeshBackground 挂载并在底层渲染流体微光且不拦截触控事件', (tester) async {
      bool buttonClicked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: SoftTheme(
            colors: SoftColors.mistyJade,
            child: Scaffold(
              body: AmbientMeshBackground(
                child: Center(
                  child: ElevatedButton(
                    key: const ValueKey('test_mesh_btn'),
                    onPressed: () {
                      buttonClicked = true;
                    },
                    child: const Text('点击测试'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AmbientMeshBackground), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);

      // 验证按钮处于顶层并且点击不被 IgnorePointer 拦截
      await tester.tap(find.byKey(const ValueKey('test_mesh_btn')));
      await tester.pump();
      expect(buttonClicked, isTrue);
    });

    testWidgets('ThemeNotifier 支持切换四大意境并向全局广播状态', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(themeProvider.notifier);
      expect(container.read(themeProvider), SoftPaletteType.mistyJade);

      // 切换到暮色暖珀
      notifier.setPalette(SoftPaletteType.twilightAmber);
      expect(container.read(themeProvider), SoftPaletteType.twilightAmber);
      expect(container.read(softColorsProvider).accent, const Color(0xFFB86820));

      // 切换到紫陌幽兰
      notifier.setPalette(SoftPaletteType.violetOrchid);
      expect(container.read(themeProvider), SoftPaletteType.violetOrchid);
      expect(container.read(softColorsProvider).accent, const Color(0xFF6D599A));

      // 切换到极夜星芒
      notifier.setPalette(SoftPaletteType.auroraSpace);
      expect(container.read(themeProvider), SoftPaletteType.auroraSpace);
      expect(container.read(softColorsProvider).isDark, isTrue);

      await tester.pumpAndSettle();
    });

    testWidgets('BookCoverWidget 具备仿真立体书脊侧光微漫射与典雅书板质感', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: BookCoverWidget(
                title: '十日终焉',
                author: '杀虫队队员',
                badgeText: '连载更新',
                width: 120.0,
                height: 160.0,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BookCoverWidget), findsOneWidget);
      expect(find.text('十'), findsOneWidget);
      expect(find.text('杀虫队队员'), findsOneWidget);
      expect(find.text('连载更新'), findsOneWidget);

      // 验证通过 Key 或特定 DecoratedBox 探测仿真书脊微光组件存在
      expect(find.byKey(const ValueKey('book_spine_lighting')), findsOneWidget);
    });

    testWidgets('书架页底层挂载 AmbientMeshBackground 并呈现晨光雅集心流卡片', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SoftTheme(
              colors: SoftColors.mistyJade,
              child: ShelfPage(onNavigateToDiscovery: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 验证底层挂载流体微光网格
      expect(find.byType(AmbientMeshBackground), findsOneWidget);
      // 验证晨光雅集心流卡片文案与元素
      expect(find.byKey(const ValueKey('shelf_search_input')), findsOneWidget);
    });

    testWidgets('书籍详情页底层挂载 AmbientMeshBackground 且包含精装书封与双胶囊行动栏', (tester) async {
      final testBook = BookItem(
        id: 'test_book_1',
        title: '十日终焉',
        author: '杀虫队队员',
        currentChapterIndex: 53,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SoftTheme(
              colors: SoftColors.mistyJade,
              child: BookDetailPage(
                book: testBook,
                initialChapters: const [
                  ChapterItem(index: 0, title: '第一章', url: 'test_url_1'),
                  ChapterItem(index: 1, title: '第二章', url: 'test_url_2'),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // 验证底层挂载 AmbientMeshBackground
      expect(find.byType(AmbientMeshBackground), findsOneWidget);
      // 验证精装书脊微光封面
      expect(find.byKey(const ValueKey('book_spine_lighting')), findsOneWidget);
      // 验证双胶囊行动按钮存在
      expect(find.byKey(const ValueKey('detail_shelf_btn')), findsOneWidget);
      expect(find.byKey(const ValueKey('detail_read_btn')), findsOneWidget);
    });

    test('阅读器纸质色系强调色与 Modern Soft UI v3 四大意境保持审美协同', () {
      // 1. 纸白 (paper) 与青润 (green) 协同苍岚烟雨天青
      expect(ReaderThemeOption.paper.accent, const Color(0xFF236B58));
      expect(ReaderThemeOption.green.accent, const Color(0xFF236B58));

      // 2. 羊皮纸 (cream) 协同暮色暖珀
      expect(ReaderThemeOption.cream.accent, const Color(0xFFB86820));

      // 3. 深墨 (ink) 与极夜 (night) 协同极夜星芒
      expect(ReaderThemeOption.ink.accent, const Color(0xFF38D9A9));
      expect(ReaderThemeOption.night.accent, const Color(0xFF38D9A9));
    });

    testWidgets('设置中心挂载 AmbientMeshBackground 且支持切换四大意境雅集', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SoftTheme(
              colors: SoftColors.mistyJade,
              child: SettingsPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 验证底层挂载 AmbientMeshBackground
      expect(find.byType(AmbientMeshBackground), findsOneWidget);

      // 验证四大意境卡片 Key 存在
      expect(find.byKey(const ValueKey('theme_chip_mistyJade')), findsOneWidget);
      expect(find.byKey(const ValueKey('theme_chip_twilightAmber')), findsOneWidget);
      expect(find.byKey(const ValueKey('theme_chip_violetOrchid')), findsOneWidget);
      expect(find.byKey(const ValueKey('theme_chip_auroraSpace')), findsOneWidget);

      // 点击切换为暮色暖珀
      await tester.tap(find.byKey(const ValueKey('theme_chip_twilightAmber')));
      await tester.pumpAndSettle();

      // 点击切换为紫陌幽兰
      await tester.tap(find.byKey(const ValueKey('theme_chip_violetOrchid')));
      await tester.pumpAndSettle();
    });
  });
}
