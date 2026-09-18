import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_reader_flutter/features/settings/presentation/settings_page.dart';
import 'package:novel_reader_flutter/features/settings/services/version_check_service.dart';

/// 返回一份含更高 versionCode 的 manifest，模拟线上确实发布了新版本
class _NewVersionAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    const body = '{"versionCode":2002,"versionName":"1.0.1",'
        '"publishDate":"2026-09-18","releaseNotes":"测试更新说明",'
        '"isForceUpdate":false,'
        '"platforms":{"android":{"downloadUrl":"https://example.com/app.apk",'
        '"installMode":"in_app_apk"}}}';
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

/// 让版本探测立刻失败，测试不依赖真实网络（否则 pumpAndSettle 会被挂起的请求拖垮）
class _OfflineAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    throw DioException.connectionError(
      requestOptions: options,
      reason: 'offline in test',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    VersionCheckService().customDio = Dio()
      ..httpClientAdapter = _OfflineAdapter();

    // 模拟宿主平台返回真实已安装版本号，避免测试依赖原生实现
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel(VersionCheckService.updateChannelName),
      (call) async {
        if (call.method == 'getPackageInfo') {
          return <String, dynamic>{'versionCode': 2002, 'versionName': '1.0.1'};
        }
        return null;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel(VersionCheckService.updateChannelName),
      null,
    );
  });

  testWidgets(
      'SettingsPage check update tile triggers SnackBar when already latest',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // 设为与远程版本号一致（即已经是最新版本）
    VersionCheckService().currentVersionCode = 2002;
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

    // 线上确实发布了 1.0.1+2002，本地为老版本 1000
    VersionCheckService().customDio = Dio()
      ..httpClientAdapter = _NewVersionAdapter();
    VersionCheckService().currentVersionCode = 1000;
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
    expect(find.text('v1.0.1+2002'), findsOneWidget);
    expect(find.text('覆盖安装将完整保留您的全部书架、书签与离线数据'), findsOneWidget);
  });
}
