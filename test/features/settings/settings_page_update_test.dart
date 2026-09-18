import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_reader_flutter/features/settings/presentation/settings_page.dart';
import 'package:novel_reader_flutter/features/settings/services/version_check_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'SettingsPage check update tile triggers SnackBar when already latest',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // 设为与远程版本号一致（即已经是最新版本）
    VersionCheckService().currentVersionCode = 2;
    VersionCheckService().currentVersionName = '1.0.1';

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SettingsPage(),
        ),
      ),
    );

    // 等待初始设置加载完成
    await tester.pumpAndSettle();

    // 查找“检查新版本”磁贴并确保可见
    final checkTile = find.byKey(const ValueKey('settings_check_update_tile'));
    await tester.scrollUntilVisible(checkTile, 200);
    expect(checkTile, findsOneWidget);

    // 点击检查更新
    await tester.tap(checkTile);
    await tester.pumpAndSettle();

    // 验证弹出轻量 SnackBar
    expect(find.text('当前已是最新版本 (v1.0.1)，尽享极速纯净体验'), findsOneWidget);
  });

  testWidgets(
      'SettingsPage check update tile triggers UpdateDialog when new version available',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // 设为本地老版本（1），将能检测到 1.0.1+2 新版本
    VersionCheckService().currentVersionCode = 1;
    VersionCheckService().currentVersionName = '1.0.0';

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SettingsPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final checkButton = find.byKey(const ValueKey('btn_check_version'));
    await tester.scrollUntilVisible(checkButton, 200);
    expect(checkButton, findsOneWidget);

    await tester.tap(checkButton);
    await tester.pumpAndSettle();

    // 验证弹出 UpdateDialog
    expect(find.text('发现新版本'), findsOneWidget);
    expect(find.text('v1.0.1+2'), findsOneWidget);
    expect(find.text('覆盖安装将完整保留您的全部书架、书签与离线数据'), findsOneWidget);
  });
}
