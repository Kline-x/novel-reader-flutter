import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_reader_flutter/features/settings/presentation/settings_page.dart';
import 'package:novel_reader_flutter/features/settings/presentation/update_dialog.dart';
import 'package:novel_reader_flutter/features/settings/services/version_check_service.dart';

/// 一旦被调用就炸，用来证明「根本没发起网络请求」
class _ExplodingAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    fail('不应该再发起任何请求：已经有一个下载在后台跑了');
  }
}

const _testVersion = AppVersionInfo(
  versionCode: 6008,
  versionName: '1.0.10',
  publishDate: '2026-09-20',
  releaseNotes: '测试',
  isForceUpdate: false,
  platforms: {
    'android': PlatformUpdateInfo(
      downloadUrl: 'https://example.com/app.apk',
      installMode: 'in_app_apk',
    ),
  },
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = VersionCheckService();

  tearDown(() {
    service.activeDownload.value = null;
  });

  group('后台下载必须被服务持有，而不是住在弹窗的 State 里', () {
    // 点「后台下载」后弹窗就销毁了，下载却还在跑。
    // 状态如果只存在弹窗里，就会出现两个后果：
    //   1. 用户再也看不到进度，只能等安装器自己弹出来；
    //   2. 再点一次「检查更新 → 立即更新」会起第二个 dio.download
    //      往**同一个文件路径**写，两个写者抢一个文件，校验和多半对不上。
    test('已有同版本下载在跑时，不会再起第二个', () async {
      service.customDio = Dio()..httpClientAdapter = _ExplodingAdapter();
      service.activeDownload.value = ActiveDownload(
        info: _testVersion,
        cancelToken: CancelToken(),
        progress: 0.62,
      );

      // 不抛异常就说明它在碰网络之前就返回了
      await service.downloadAndInstallApk(
        _testVersion,
        onProgress: (p, [s]) => fail('不该有新的进度回调'),
      );
    });

    test('外部拿得到正在跑的那次下载的进度', () {
      final token = CancelToken();
      service.activeDownload.value = ActiveDownload(
        info: _testVersion,
        cancelToken: token,
        progress: 0.62,
        speedText: '5.9 MB/s',
      );

      expect(service.hasActiveDownload, isTrue);
      final d = service.activeDownload.value!;
      expect(d.info.versionCode, 6008);
      expect(d.progress, closeTo(0.62, 0.001));
      expect(d.speedText, '5.9 MB/s');
      expect(identical(d.cancelToken, token), isTrue,
          reason: '要能拿到同一个 cancelToken，用户才取消得掉后台那次下载');
    });

    test('没有下载在跑时 hasActiveDownload 为假', () {
      service.activeDownload.value = null;
      expect(service.hasActiveDownload, isFalse);
    });
  });

  group('重新打开弹窗要挂接到正在跑的下载，而不是重新发起', () {
    testWidgets('已有同版本下载在跑时，弹窗直接显示进度与「后台下载」，不显示「立即更新」',
        (tester) async {
      service.activeDownload.value = ActiveDownload(
        info: _testVersion,
        cancelToken: CancelToken(),
        progress: 0.62,
        speedText: '5.9 MB/s',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: UpdateDialog(info: _testVersion)),
        ),
      );
      await tester.pump();

      expect(find.text('后台下载'), findsOneWidget,
          reason: '应当直接进入下载态，让用户看得到进度');
      expect(find.byKey(const ValueKey('btn_confirm_update')), findsNothing,
          reason: '已经在下了，不该再给一个会起第二个下载的「立即更新」');
      expect(find.textContaining('62'), findsWidgets);
    });

    testWidgets('没有下载在跑时，弹窗照常显示「立即更新」', (tester) async {
      service.activeDownload.value = null;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: UpdateDialog(info: _testVersion)),
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('btn_confirm_update')), findsOneWidget);
      expect(find.text('后台下载'), findsNothing);
    });
  });

  group('设置页要让用户能回到后台下载', () {
    setUp(() {
      // 远端探测一律失败：这条路径压根不该走到网络
      service.customDio = Dio()..httpClientAdapter = _ExplodingAdapter();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel(VersionCheckService.updateChannelName),
        (call) async => call.method == 'getPackageInfo'
            ? <String, dynamic>{'versionCode': 4008, 'versionName': '1.0.10'}
            : null,
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel(VersionCheckService.updateChannelName),
        null,
      );
    });

    testWidgets('后台有下载时，版本条目显示进度并可点回进度弹窗', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      service.activeDownload.value = ActiveDownload(
        info: _testVersion,
        cancelToken: CancelToken(),
        progress: 0.62,
        speedText: '5.9 MB/s',
      );

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: SettingsPage())),
      );
      await tester.pumpAndSettle();

      final tile = find.byKey(const ValueKey('settings_check_update_tile'));
      await tester.scrollUntilVisible(tile, 200);

      // 没有任何界面痕迹的话，用户根本不知道还能点回来
      expect(find.textContaining('正在后台下载 62%'), findsOneWidget);

      await tester.tap(tile);
      await tester.pumpAndSettle();

      // 直接挂接到正在跑的那次下载，而不是重新探测、再给一个「立即更新」
      expect(find.text('后台下载'), findsOneWidget);
      expect(find.byKey(const ValueKey('btn_confirm_update')), findsNothing);
    });
  });
}
