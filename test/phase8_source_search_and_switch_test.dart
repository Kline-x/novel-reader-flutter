import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_reader_flutter/core/theme/soft_theme.dart';
import 'package:novel_reader_flutter/features/reader/presentation/reader_screen.dart';
import 'package:novel_reader_flutter/features/shelf/presentation/discovery_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget createDiscoveryTestWidget(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    return const ProviderScope(
      child: SoftTheme(
        colors: SoftColors.parchment,
        child: MaterialApp(
          home: DiscoveryPage(),
        ),
      ),
    );
  }

  Widget createReaderTestWidget(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    return const ProviderScope(
      child: SoftTheme(
        colors: SoftColors.parchment,
        child: MaterialApp(
          home: ReaderScreen(
            bookId: 'test_book',
            bookTitle: '《诡秘之主》',
            author: '爱潜水的乌贼',
          ),
        ),
      ),
    );
  }

  group('阶段 8：全网真实书源聚合检索与一键换源测试', () {
    testWidgets('DiscoveryPage 聚合搜索与加入书架全链路测试', (tester) async {
      await tester.pumpWidget(createDiscoveryTestWidget(tester));
      await tester.pumpAndSettle();

      // 1. 验证初始状态
      expect(find.text('探索好书'), findsOneWidget);
      expect(find.text('实时热读书目'), findsOneWidget);

      // 2. 输入搜索关键词并点击搜索
      final inputFinder = find.byKey(const ValueKey('discovery_search_input'));
      expect(inputFinder, findsOneWidget);
      await tester.enterText(inputFinder, '宿命之环');
      await tester.pumpAndSettle();

      final searchBtn = find.byKey(const ValueKey('discovery_search_btn'));
      expect(searchBtn, findsOneWidget);
      await tester.tap(searchBtn);
      await tester.pump(); // 触发搜索开始

      // 等待超时注入兜底完成
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();

      // 3. 验证聚合结果列表展示
      expect(find.textContaining('已为您聚合检索出'), findsOneWidget);
      expect(find.text('笔趣阁CP'), findsWidgets);
      expect(find.text('加入书架'), findsWidgets);
      expect(find.text('立即阅读'), findsWidgets);

      // 4. 点击加入书架按钮
      final addBtn = find.text('加入书架').first;
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('已成功将'), findsOneWidget);

      // 5. 清除搜索，恢复发现首页
      final clearBtn = find.text('清除搜索');
      expect(clearBtn, findsOneWidget);
      await tester.tap(clearBtn);
      await tester.pumpAndSettle();

      expect(find.text('实时热读书目'), findsOneWidget);
    });

    testWidgets('ReaderScreen 换源抽屉挂载与12组书源热切测试', (tester) async {
      await tester.pumpWidget(createReaderTestWidget(tester));
      await tester.pumpAndSettle();

      // 1. 点击视口中心区域呼出顶部控制栏
      await tester.tapAt(const Offset(400, 600));
      await tester.pumpAndSettle();

      // 2. 点击换源按钮
      final switchSourceBtn = find.text('换源');
      expect(switchSourceBtn, findsOneWidget);
      await tester.tap(switchSourceBtn);
      await tester.pumpAndSettle();

      // 3. 验证 12 组内置书源全部展示
      expect(find.text('全网可用书源热切'), findsOneWidget);
      expect(find.text('已连通 12 组稳定书源'), findsOneWidget);

      // 验证典型书源存在
      expect(find.text('笔趣阁CP'), findsOneWidget);
      expect(find.text('思兔阅读'), findsOneWidget);
      expect(find.text('天天看小说'), findsOneWidget);

      // 4. 点击切换至“思兔阅读”
      final situSource = find.text('思兔阅读');
      await tester.tap(situSource);
      await tester.pumpAndSettle();

      // 5. 验证弹窗关闭并展示切换成功提示
      expect(find.textContaining('已成功平滑切至书源【思兔阅读】'), findsOneWidget);
    });
  });
}
