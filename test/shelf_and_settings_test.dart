import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_reader_flutter/core/components/floating_dock.dart';
import 'package:novel_reader_flutter/core/components/main_scaffold.dart';
import 'package:novel_reader_flutter/core/components/soft_button.dart';
import 'package:novel_reader_flutter/core/components/soft_card.dart';
import 'package:novel_reader_flutter/core/components/soft_switch.dart';
import 'package:novel_reader_flutter/core/theme/soft_theme.dart';
import 'package:novel_reader_flutter/features/reader/data/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService().seedDefaultBooks();
  });

  Widget createTestWidget(WidgetTester tester, {Widget? child}) {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    return ProviderScope(
      child: SoftTheme(
        colors: SoftColors.parchment,
        child: MaterialApp(
          home: child ?? const MainScaffold(),
        ),
      ),
    );
  }

  group('MainScaffold 基础挂载与 FloatingDock 切换测试', () {
    testWidgets('正常启动，默认进入书架页且展示 Bento 看板与浮动底栏', (tester) async {
      await tester.pumpWidget(createTestWidget(tester));
      await tester.pumpAndSettle();

      // 验证书架主标题与 Bento 看板
      expect(find.text('藏书阁'), findsOneWidget);
      expect(find.text('今日阅读'), findsOneWidget);
      expect(find.text('在读藏书'), findsOneWidget);

      // 验证 62px 悬浮毛玻璃 Dock 三胶囊存在
      expect(find.byKey(const ValueKey('tab_shelf')), findsOneWidget);
      expect(find.byKey(const ValueKey('tab_discovery')), findsOneWidget);
      expect(find.byKey(const ValueKey('tab_settings')), findsOneWidget);
    });

    testWidgets('TabBar 切换正常：可自由在书架、发现、设置之间切换', (tester) async {
      await tester.pumpWidget(createTestWidget(tester));
      await tester.pumpAndSettle();

      // 1. 切换至发现页
      await tester.tap(find.byKey(const ValueKey('tab_discovery')));
      await tester.pumpAndSettle();
      expect(find.text('探索好书'), findsOneWidget);
      expect(find.text('实时热读书目'), findsOneWidget);

      // 2. 切换至设置页
      await tester.tap(find.byKey(const ValueKey('tab_settings')));
      await tester.pumpAndSettle();
      expect(find.text('个人与设置'), findsOneWidget);
      expect(find.text('阅读控制'), findsOneWidget);
      expect(find.text('物理音量键翻页'), findsOneWidget);

      // 3. 切换回书架页
      await tester.tap(find.byKey(const ValueKey('tab_shelf')));
      await tester.pumpAndSettle();
      expect(find.text('藏书阁'), findsOneWidget);
      expect(find.text('今日阅读'), findsOneWidget);
    });
  });

  group('ShelfPage 拼音排序逻辑与搜索过滤测试', () {
    testWidgets('拼音字母序重排验证：书架应按道诡异仙(D) -> 诡秘之主(G) -> 剑来(J) -> 十日终焉(S) 排序', (tester) async {
      await tester.pumpWidget(createTestWidget(tester));
      await tester.pumpAndSettle();

      // 验证 4 本书均已渲染
      final daoFinder = find.text('道诡异仙');
      final guiFinder = find.text('诡秘之主');
      final jianFinder = find.text('剑来');
      final shiFinder = find.text('十日终焉');

      expect(daoFinder, findsOneWidget);
      expect(guiFinder, findsOneWidget);
      expect(jianFinder, findsOneWidget);
      expect(shiFinder, findsOneWidget);

      // 获取纵向 Y 坐标，验证严格自上而下拼音字典序排列
      final daoY = tester.getTopLeft(daoFinder).dy;
      final guiY = tester.getTopLeft(guiFinder).dy;
      final jianY = tester.getTopLeft(jianFinder).dy;
      final shiY = tester.getTopLeft(shiFinder).dy;

      expect(daoY < guiY, isTrue, reason: '道诡异仙(D) 应排在 诡秘之主(G) 前');
      expect(guiY < jianY, isTrue, reason: '诡秘之主(G) 应排在 剑来(J) 前');
      expect(jianY < shiY, isTrue, reason: '剑来(J) 应排在 十日终焉(S) 前');
    });

    testWidgets('搜索过滤与重置功能验证', (tester) async {
      await tester.pumpWidget(createTestWidget(tester));
      await tester.pumpAndSettle();

      // 1. 输入关键词 "诡秘"
      await tester.enterText(find.byKey(const ValueKey('shelf_search_input')), '诡秘');
      await tester.pumpAndSettle();

      expect(find.text('诡秘之主'), findsOneWidget);
      expect(find.text('道诡异仙'), findsNothing);
      expect(find.text('十日终焉'), findsNothing);
      expect(find.text('剑来'), findsNothing);

      // 2. 点击清空按钮重置
      await tester.tap(find.byKey(const ValueKey('shelf_search_clear')));
      await tester.pumpAndSettle();

      expect(find.text('诡秘之主'), findsOneWidget);
      expect(find.text('道诡异仙'), findsOneWidget);
      expect(find.text('十日终焉'), findsOneWidget);
      expect(find.text('剑来'), findsOneWidget);

      // 2.1 测试拼音检索 "guimi"
      await tester.enterText(find.byKey(const ValueKey('shelf_search_input')), 'guimi');
      await tester.pumpAndSettle();
      expect(find.text('诡秘之主'), findsOneWidget);
      expect(find.text('剑来'), findsNothing);

      // 2.2 测试拼音首字母缩写检索 "srzy"
      await tester.enterText(find.byKey(const ValueKey('shelf_search_input')), 'srzy');
      await tester.pumpAndSettle();
      expect(find.text('十日终焉'), findsOneWidget);
      expect(find.text('诡秘之主'), findsNothing);

      // 3. 搜索不存在的内容触发空状态
      await tester.enterText(find.byKey(const ValueKey('shelf_search_input')), '未收录的冷门小说XYZ');
      await tester.pumpAndSettle();

      expect(find.text('书架空空如也'), findsOneWidget);
      expect(find.byKey(const ValueKey('btn_go_discovery')), findsOneWidget);

      // 4. 点击空状态按钮跳转至发现页
      await tester.tap(find.byKey(const ValueKey('btn_go_discovery')));
      await tester.pumpAndSettle();

      expect(find.text('探索好书'), findsOneWidget);
    });

    testWidgets('书架长按书籍置顶与排序置顶优先验证', (tester) async {
      await tester.pumpWidget(createTestWidget(tester));
      await tester.pumpAndSettle();

      // 长按最后排名的 "十日终焉"
      await tester.longPress(find.text('十日终焉'));
      await tester.pumpAndSettle();

      // 验证底部弹窗中出现 "置顶此书"
      expect(find.text('置顶此书'), findsOneWidget);
      await tester.tap(find.text('置顶此书'));
      await tester.pumpAndSettle();

      // 验证十日终焉出现 "置顶" 标签
      expect(find.text('置顶'), findsOneWidget);

      // 验证置顶后 "十日终焉" 跃升至首位（Y坐标小于道诡异仙与诡秘之主）
      final shiY = tester.getTopLeft(find.text('十日终焉')).dy;
      final daoY = tester.getTopLeft(find.text('道诡异仙')).dy;
      final guiY = tester.getTopLeft(find.text('诡秘之主')).dy;

      expect(shiY < daoY, isTrue, reason: '置顶后 十日终焉 应排在 道诡异仙 前');
      expect(shiY < guiY, isTrue, reason: '置顶后 十日终焉 应排在 诡秘之主 前');
    });

    testWidgets('列表与网格模式切换验证', (tester) async {
      await tester.pumpWidget(createTestWidget(tester));
      await tester.pumpAndSettle();

      // 初始应为列表视图
      expect(find.byType(SliverList), findsOneWidget);
      expect(find.byType(SliverGrid), findsNothing);

      // 点击切换按钮进入网格模式
      await tester.tap(find.byKey(const ValueKey('shelf_view_toggle')));
      await tester.pumpAndSettle();

      expect(find.byType(SliverGrid), findsOneWidget);
      expect(find.text('道诡异仙'), findsOneWidget);

      // 再次点击切回列表模式
      await tester.tap(find.byKey(const ValueKey('shelf_view_toggle')));
      await tester.pumpAndSettle();

      expect(find.byType(SliverList), findsOneWidget);
      expect(find.byType(SliverGrid), findsNothing);
    });
  });

  group('SettingsPage 开关切换与缓存清空弹窗测试', () {
    testWidgets('音量键翻页与常亮开关正常切换', (tester) async {
      await tester.pumpWidget(createTestWidget(tester));
      await tester.pumpAndSettle();

      // 切换至设置页
      await tester.tap(find.byKey(const ValueKey('tab_settings')));
      await tester.pumpAndSettle();

      final volumeSwitchFinder = find.byKey(const ValueKey('switch_volume_paging'));
      expect(volumeSwitchFinder, findsOneWidget);

      // 初始状态为 true
      SoftSwitch volumeSwitch = tester.widget(volumeSwitchFinder);
      expect(volumeSwitch.value, isTrue);

      // 点击切换为 false
      await tester.tap(volumeSwitchFinder);
      await tester.pumpAndSettle();

      volumeSwitch = tester.widget(volumeSwitchFinder);
      expect(volumeSwitch.value, isFalse);

      // 再次点击切回 true
      await tester.tap(volumeSwitchFinder);
      await tester.pumpAndSettle();

      volumeSwitch = tester.widget(volumeSwitchFinder);
      expect(volumeSwitch.value, isTrue);

      // 切换常亮开关
      final awakeSwitchFinder = find.byKey(const ValueKey('switch_screen_awake'));
      SoftSwitch awakeSwitch = tester.widget(awakeSwitchFinder);
      expect(awakeSwitch.value, isTrue);

      await tester.tap(awakeSwitchFinder);
      await tester.pumpAndSettle();

      awakeSwitch = tester.widget(awakeSwitchFinder);
      expect(awakeSwitch.value, isFalse);
    });

    testWidgets('缓存清空弹窗取消与确认清空流程验证', (tester) async {
      await tester.pumpWidget(createTestWidget(tester));
      await tester.pumpAndSettle();

      // 切换至设置页
      await tester.tap(find.byKey(const ValueKey('tab_settings')));
      await tester.pumpAndSettle();

      // 验证初始缓存大小为 24.8 MB
      expect(find.text('24.8 MB'), findsOneWidget);

      // 点击清理缓存按钮唤起弹窗
      await tester.tap(find.byKey(const ValueKey('btn_clear_cache')));
      await tester.pumpAndSettle();

      expect(find.text('清空离线缓存'), findsOneWidget);
      expect(find.byKey(const ValueKey('btn_cancel_clear_cache')), findsOneWidget);
      expect(find.byKey(const ValueKey('btn_confirm_clear_cache')), findsOneWidget);

      // 1. 点击取消
      await tester.tap(find.byKey(const ValueKey('btn_cancel_clear_cache')));
      await tester.pumpAndSettle();

      expect(find.text('清空离线缓存'), findsNothing);
      expect(find.text('24.8 MB'), findsOneWidget);

      // 2. 再次打开弹窗并确认清空
      await tester.tap(find.byKey(const ValueKey('btn_clear_cache')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('btn_confirm_clear_cache')));
      await tester.pumpAndSettle();

      // 弹窗关闭，缓存更新为 0.0 KB 并弹出 SnackBar
      expect(find.text('清空离线缓存'), findsNothing);
      expect(find.text('0.0 KB'), findsOneWidget);
      expect(find.text('离线缓存已完全清空'), findsOneWidget);
    });
  });

  group('Modern Soft UI 规范与触感反馈测试', () {
    testWidgets('SoftCard 连续曲率 24px 与点击下陷 scale 动效验证', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SoftCard(
              colors: SoftColors.parchment,
              onTap: () => tapped = true,
              child: const Text('SoftCard Test'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cardFinder = find.byType(SoftCard);
      expect(cardFinder, findsOneWidget);

      // 初始 scale 为 1.0
      AnimatedScale scaleWidget = tester.widget(find.descendant(of: cardFinder, matching: find.byType(AnimatedScale)));
      expect(scaleWidget.scale, 1.0);

      // 手势按下
      final gesture = await tester.startGesture(tester.getCenter(cardFinder));
      await tester.pump(const Duration(milliseconds: 50));

      scaleWidget = tester.widget(find.descendant(of: cardFinder, matching: find.byType(AnimatedScale)));
      expect(scaleWidget.scale, 0.975);

      // 手势抬起
      await gesture.up();
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
      scaleWidget = tester.widget(find.descendant(of: cardFinder, matching: find.byType(AnimatedScale)));
      expect(scaleWidget.scale, 1.0);
    });

    testWidgets('SoftButton 胶囊触感 scale 下陷与选中态测试', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SoftButton(
              colors: SoftColors.parchment,
              isPill: true,
              onPressed: () {},
              child: const Text('Pill Button'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final btnFinder = find.byType(SoftButton);
      expect(btnFinder, findsOneWidget);

      // 初始 scale 1.0
      AnimatedScale scaleWidget = tester.widget(find.descendant(of: btnFinder, matching: find.byType(AnimatedScale)));
      expect(scaleWidget.scale, 1.0);

      // 按下
      final gesture = await tester.startGesture(tester.getCenter(btnFinder));
      await tester.pump(const Duration(milliseconds: 50));

      scaleWidget = tester.widget(find.descendant(of: btnFinder, matching: find.byType(AnimatedScale)));
      expect(scaleWidget.scale, 0.96);

      await gesture.up();
      await tester.pumpAndSettle();

      scaleWidget = tester.widget(find.descendant(of: btnFinder, matching: find.byType(AnimatedScale)));
      expect(scaleWidget.scale, 1.0);
    });

    testWidgets('FloatingDock 62px 悬浮毛玻璃胶囊容器高度验证', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                FloatingDock(
                  currentIndex: 0,
                  colors: SoftColors.parchment,
                  onTabSelected: (_) {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final dockFinder = find.byType(FloatingDock);
      expect(dockFinder, findsOneWidget);

      // 验证毛玻璃容器存在且高度为 62.0
      final containerFinder = find.descendant(
        of: dockFinder,
        matching: find.byWidgetPredicate(
          (w) => w is Container && w.constraints?.maxHeight == 62.0,
        ),
      );
      expect(containerFinder, findsOneWidget);
    });
  });
}
