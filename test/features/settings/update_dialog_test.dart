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

  testWidgets('Clicking top-right close icon dismisses dialog immediately',
      (tester) async {
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
    expect(find.byKey(const ValueKey('btn_close_update_dialog')), findsOneWidget);

    // 点击右上角关闭按钮
    await tester.tap(find.byKey(const ValueKey('btn_close_update_dialog')));
    await tester.pumpAndSettle();

    expect(find.text('发现新版本'), findsNothing);
  });

  group('后台下载不能把下载掐掉', () {
    // 「后台下载」按钮的行为就是 Navigator.pop() 一下把弹窗收起来，
    // 而 PopScope 的 onPopInvokedWithResult 对**任何** pop 都会触发，
    // 分不清这次 pop 是用户返回还是转入后台。
    // 上一轮只在 dispose() 里加了判断，漏了 PopScope 这条路，
    // 于是点「后台下载」依然等于取消下载——真机上表现为「后台更新还是不行」。
    test('转入后台时不取消，其余情况照常取消', () {
      expect(
        shouldCancelDownloadOnPop(isProcessing: true, movedToBackground: true),
        isFalse,
        reason: '点「后台下载」必须让下载继续跑完',
      );
      expect(
        shouldCancelDownloadOnPop(isProcessing: true, movedToBackground: false),
        isTrue,
        reason: '物理返回 / 点遮罩退出弹窗，仍应取消下载',
      );
      expect(
        shouldCancelDownloadOnPop(isProcessing: false, movedToBackground: false),
        isFalse,
        reason: '压根没在下载，没有可取消的东西',
      );
    });
  });
}
