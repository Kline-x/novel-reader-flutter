import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_reader_flutter/features/settings/presentation/update_dialog.dart';
import 'package:novel_reader_flutter/features/settings/services/version_check_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testVersion = AppVersionInfo(
    versionCode: 2,
    versionName: '1.0.1',
    publishDate: '2026-09-18',
    releaseNotes: '1. 新增远程版本检测\n2. 优化阅读器排版',
    isForceUpdate: false,
    platforms: {
      'android': PlatformUpdateInfo(
        downloadUrl: 'https://example.com/test.apk',
        installMode: 'in_app_apk',
      ),
    },
  );

  testWidgets('UpdateDialog renders version badge, notes, and safety notice',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: UpdateDialog(info: testVersion),
        ),
      ),
    );

    // 验证标题和版本号 Badge
    expect(find.text('发现新版本'), findsOneWidget);
    expect(find.text('v1.0.1+2'), findsOneWidget);
    expect(find.text('2026-09-18'), findsOneWidget);

    // 验证更新说明
    expect(find.text('1. 新增远程版本检测'), findsOneWidget);
    expect(find.text('2. 优化阅读器排版'), findsOneWidget);

    // 验证无损保留数据保障文案
    expect(find.text('覆盖安装将完整保留您的全部书架、书签与离线数据'), findsOneWidget);

    // 验证按钮
    expect(find.byKey(const ValueKey('btn_cancel_update')), findsOneWidget);
    expect(find.byKey(const ValueKey('btn_confirm_update')), findsOneWidget);
  });

  testWidgets('Clicking cancel button dismisses dialog', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => UpdateDialog.show(context, testVersion),
              child: const Text('Show Dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('发现新版本'), findsOneWidget);

    // 点击稍后再说
    await tester.tap(find.byKey(const ValueKey('btn_cancel_update')));
    await tester.pumpAndSettle();

    expect(find.text('发现新版本'), findsNothing);
  });
}
