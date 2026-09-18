import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_reader_flutter/core/components/docked_bottom_bar.dart';
import 'package:novel_reader_flutter/core/components/main_scaffold.dart';
import 'package:novel_reader_flutter/core/theme/soft_theme.dart';
import 'package:novel_reader_flutter/features/shelf/models/book_item.dart';
import 'package:novel_reader_flutter/features/shelf/presentation/book_detail_page.dart';
import 'package:novel_reader_flutter/features/sources/models/chapter_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('DockedBottomBar 无界沉浸贴底导航栏测试', () {
    testWidgets('DockedBottomBar 渐隐无分割线、贴底与高度属性验证', (tester) async {
      int selectedTab = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(padding: EdgeInsets.only(bottom: 34.0)),
            child: Scaffold(
              body: Stack(
                children: [
                  DockedBottomBar(
                    currentIndex: selectedTab,
                    colors: SoftColors.parchment,
                    onTabSelected: (idx) => selectedTab = idx,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. 验证 DockedBottomBar 存在且包含 Positioned(bottom: 0)
      final barFinder = find.byType(DockedBottomBar);
      expect(barFinder, findsOneWidget);

      final positionedFinder = find.descendant(
        of: barFinder,
        matching: find.byWidgetPredicate(
          (w) =>
              w is Positioned &&
              w.bottom == 0.0 &&
              w.left == 0.0 &&
              w.right == 0.0,
        ),
      );
      expect(positionedFinder, findsOneWidget);

      // 2. 【零分割线】不得存在任何顶部 BorderSide —— 那条横线正是要消灭的目标；
      //    同时不再使用 BackdropFilter，避免模糊区硬边在内容上留下可见接缝。
      final borderedContainers = find.descendant(
        of: barFinder,
        matching: find.byWidgetPredicate((w) {
          if (w is! Container) return false;
          final deco = w.decoration;
          return deco is BoxDecoration && deco.border != null;
        }),
      );
      expect(borderedContainers, findsNothing);
      expect(
        find.descendant(of: barFinder, matching: find.byType(BackdropFilter)),
        findsNothing,
      );

      // 3. 验证整体高度为 渐隐带 28.0 + 内容 58.0 + 安全区 34.0 = 120.0
      final gradientFinder = find.descendant(
        of: barFinder,
        matching: find.byWidgetPredicate((w) {
          if (w is! Container) return false;
          final deco = w.decoration;
          return deco is BoxDecoration && deco.gradient is LinearGradient;
        }),
      );
      expect(gradientFinder, findsOneWidget);
      expect(tester.getSize(gradientFinder).height, 120.0);

      // 4. 验证 3 个 Tab 项存在且可正常点击切换
      expect(find.byKey(const ValueKey('tab_shelf')), findsOneWidget);
      expect(find.byKey(const ValueKey('tab_discovery')), findsOneWidget);
      expect(find.byKey(const ValueKey('tab_settings')), findsOneWidget);
      expect(find.text('书架'), findsOneWidget);
      expect(find.text('发现'), findsOneWidget);
      expect(find.text('设置'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('tab_discovery')));
      expect(selectedTab, 1);
    });

    testWidgets('MainScaffold 挂载 DockedBottomBar 并支持流畅页面切换', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: MainScaffold(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DockedBottomBar), findsOneWidget);

      // 切换至发现
      await tester.tap(find.byKey(const ValueKey('tab_discovery')));
      await tester.pumpAndSettle();
      expect(find.text('探索好书'), findsOneWidget);

      // 切换至设置
      await tester.tap(find.byKey(const ValueKey('tab_settings')));
      await tester.pumpAndSettle();
      expect(find.text('个人与设置'), findsOneWidget);

      // 切换回书架
      await tester.tap(find.byKey(const ValueKey('tab_shelf')));
      await tester.pumpAndSettle();
      expect(find.text('今日阅读'), findsOneWidget);
    });
  });

  group('BookDetailPage 渐进式目录展开与收起交互测试', () {
    testWidgets('当全书章节数 > 30 时，默认展示前 20 章，支持查看完整目录、收起与正倒序', (tester) async {
      final mockChapters = List.generate(
        55,
        (i) => ChapterItem(
          index: i,
          title: '第${i + 1}章 浩瀚星河',
          url: 'https://example.com/ch/$i',
        ),
      );

      final book = BookItem(
        id: 'test_book_1',
        title: '星际争霸',
        author: '星空',
        coverUrl: '',
        latestChapter: '第55章 浩瀚星河',
        progress: 0.0,
        totalChapters: 55,
        currentChapterIndex: 0,
        charOffset: 0,
      );

      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: BookDetailPage(book: book, initialChapters: mockChapters),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. 验证默认未展开状态：只展示前 20 章
      expect(find.text('第1章 浩瀚星河'), findsOneWidget);
      expect(find.text('第21章 浩瀚星河'), findsNothing);

      // 2. 滚动并验证出现「查看完整目录 (共 55 章)  ▼」按钮
      final expandBtn = find.text('查看完整目录 (共 55 章)  ▼');
      await tester.scrollUntilVisible(expandBtn, 200.0,
          scrollable: find.byType(Scrollable));
      expect(expandBtn, findsOneWidget);

      // 3. 点击展开按钮
      await tester.tap(expandBtn);
      await tester.pumpAndSettle();

      // 4. 验证展开后能够翻阅全部 55 章
      final collapseBtn = find.text('已显示全本全部章节 · 收起 ▲');
      await tester.scrollUntilVisible(collapseBtn, 300.0,
          scrollable: find.byType(Scrollable));
      expect(collapseBtn, findsOneWidget);
      expect(find.text('第55章 浩瀚星河'), findsOneWidget);

      // 5. 点击收起按钮
      await tester.tap(collapseBtn);
      await tester.pumpAndSettle();

      // 6. 验证恢复折叠状态
      expect(find.text('查看完整目录 (共 55 章)  ▼'), findsOneWidget);
      expect(find.text('第21章 浩瀚星河'), findsNothing);

      // 7. 测试正序/倒序切换
      final orderBtn = find.byIcon(Icons.swap_vert_rounded);
      await tester.scrollUntilVisible(orderBtn, -200.0,
          scrollable: find.byType(Scrollable));
      await tester.tap(orderBtn);
      await tester.pumpAndSettle();

      // 倒序后，未展开状态展示倒序前 20 章（首项即为第 55 章）
      expect(find.text('倒序'), findsOneWidget);
      expect(find.text('第55章 浩瀚星河'), findsOneWidget);
    });

    testWidgets('当全书章节数 <= 30 时，直接展示全部章节且不出现展开收起按钮', (tester) async {
      final mockChapters = List.generate(
        25,
        (i) => ChapterItem(
          index: i,
          title: '第${i + 1}章 短篇物语',
          url: 'https://example.com/ch/$i',
        ),
      );

      final book = BookItem(
        id: 'test_book_2',
        title: '短篇集',
        author: '随笔',
        coverUrl: '',
        latestChapter: '第25章 短篇物语',
        progress: 0.0,
        totalChapters: 25,
        currentChapterIndex: 0,
        charOffset: 0,
      );

      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: BookDetailPage(book: book, initialChapters: mockChapters),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 验证第 1 章显示
      expect(find.text('第1章 短篇物语'), findsOneWidget);
      // 滚动验证第 25 章显示
      await tester.scrollUntilVisible(find.text('第25章 短篇物语'), 200.0,
          scrollable: find.byType(Scrollable));
      expect(find.text('第25章 短篇物语'), findsOneWidget);

      // 验证不出现展开/收起按钮
      expect(find.textContaining('查看完整目录'), findsNothing);
      expect(find.textContaining('收起 ▲'), findsNothing);
    });
  });
}
