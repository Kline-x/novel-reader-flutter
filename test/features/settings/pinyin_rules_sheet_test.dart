import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_reader_flutter/features/settings/presentation/pinyin_rules_sheet.dart';
import 'package:novel_reader_flutter/features/settings/presentation/settings_page.dart';
import 'package:novel_reader_flutter/features/sources/services/pinyin_rule_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PinyinRuleService().resetForTest();
  });

  testWidgets('PinyinRulesSheet renders header, stat card and action toolbar',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PinyinRulesSheet(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('智能拼音自愈规则'), findsOneWidget);
    expect(find.textContaining('已生效规则总计'), findsOneWidget);
    expect(find.byKey(const ValueKey('btn_sync_pinyin_cloud')), findsOneWidget);
    expect(find.byKey(const ValueKey('btn_open_add_rule')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('btn_export_pinyin_rules')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('btn_import_pinyin_rules')), findsOneWidget);

    // 验证规则列表中展示云端规则
    expect(find.text('zhengfu'), findsOneWidget);
    expect(find.text('政府'), findsOneWidget);
    expect(find.text('云端'), findsWidgets);
  });

  testWidgets('PinyinRulesSheet add custom rule flow works', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PinyinRulesSheet(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 点击添加规则
    await tester.tap(find.byKey(const ValueKey('btn_open_add_rule')));
    await tester.pumpAndSettle();

    expect(find.text('添加拼音自愈规则'), findsOneWidget);

    // 输入规则
    await tester.enterText(
        find.byKey(const ValueKey('input_rule_pinyin')), 'gongzuo');
    await tester.enterText(
        find.byKey(const ValueKey('input_rule_hanzi')), '工作');
    await tester.pump();

    // 确认添加
    await tester.tap(find.byKey(const ValueKey('btn_confirm_add_rule')));
    await tester.pumpAndSettle();

    // 验证已新增在列表中并展示“自定义”标签
    expect(find.text('gongzuo'), findsOneWidget);
    expect(find.text('工作'), findsOneWidget);
    expect(find.text('自定义'), findsWidgets);
  });

  testWidgets('SettingsPage can open PinyinRulesSheet via tile',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SettingsPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final tileFinder = find.byKey(const ValueKey('settings_pinyin_rules_tile'));
    await tester.scrollUntilVisible(tileFinder, 200);
    expect(tileFinder, findsOneWidget);

    await tester.tap(tileFinder);
    await tester.pumpAndSettle();

    // 成功呼出 PinyinRulesSheet
    expect(find.text('智能拼音自愈规则'), findsOneWidget);
  });
}
