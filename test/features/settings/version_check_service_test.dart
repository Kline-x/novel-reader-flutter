import 'package:flutter_test/flutter_test.dart';
import 'package:novel_reader_flutter/features/settings/services/version_check_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    VersionCheckService().currentVersionCode = 1;
    VersionCheckService().currentVersionName = '1.0.0';
  });

  group('VersionCheckService & AppVersionInfo Tests', () {
    test(
        'AppVersionInfo fromJson and toJson should serialize platform matrix properly',
        () {
      final json = {
        'versionCode': 3,
        'versionName': '1.0.2',
        'releaseNotes': '1. 修复已知问题\n2. 优化体验',
        'publishDate': '2026-09-18',
        'isForceUpdate': false,
        'platforms': {
          'android': {
            'downloadUrl': 'https://example.com/app.apk',
            'backupUrl': 'https://cdn.example.com/app.apk',
            'fileSize': 10240,
            'installMode': 'in_app_apk',
          },
          'ios': {
            'storeUrl': 'itms-apps://itunes.apple.com/app/id123456',
            'installMode': 'app_store',
          },
          'harmony': {
            'storeUrl': 'appmarket://details?id=com.example.app',
            'installMode': 'app_market',
          },
        },
      };

      final info = AppVersionInfo.fromJson(json);
      expect(info.versionCode, 3);
      expect(info.versionName, '1.0.2');
      expect(info.displayTag, 'v1.0.2+3');
      expect(info.platforms.length, 3);
      expect(info.platforms['android']?.downloadUrl,
          'https://example.com/app.apk');
      expect(info.platforms['ios']?.storeUrl,
          'itms-apps://itunes.apple.com/app/id123456');
      expect(info.platforms['harmony']?.installMode, 'app_market');

      final serialized = info.toJson();
      expect(serialized['versionCode'], 3);
      expect(serialized['versionName'], '1.0.2');
      expect((serialized['platforms'] as Map)['android']['fileSize'], 10240);
    });

    test(
        'checkLatestVersion should return new version info when remote versionCode > current',
        () async {
      final service = VersionCheckService();

      final newVersion =
          await service.checkLatestVersion(forceMock: true, currentCode: 1000);
      expect(newVersion, isNotNull);
      expect(newVersion!.versionCode, 2002);
      expect(newVersion.versionName, '1.0.1');
      expect(newVersion.releaseNotes, contains('跨端高可用远程版本升级体系'));
    });

    test(
        'checkLatestVersion should return null when local version is already latest',
        () async {
      final service = VersionCheckService();

      final newVersion =
          await service.checkLatestVersion(forceMock: true, currentCode: 2002);
      expect(newVersion, isNull);
    });

    test(
        '所有节点不可达时视为暂无更新，绝不拿内置 Mock 版本冒充线上最新版',
        () async {
      final service = VersionCheckService();
      service.currentVersionCode = 1000;
      service.currentVersionName = '1.0.0';

      final result = await service.checkLatestVersion(
        endpoint: 'http://127.0.0.1:54321/invalid_version.json',
        currentCode: 1000,
      );
      // 离线兜底若返回内置 Mock，就会让用户看到一个并不存在的新版本，
      // 点进去必然下载失败；因此这里必须是 null（无更新）。
      expect(result, isNull);
    });

    test('forceMock 仍可取到内置稳定版配置（供离线自检使用）', () async {
      final service = VersionCheckService();
      final result =
          await service.checkLatestVersion(forceMock: true, currentCode: 1000);
      expect(result, isNotNull);
      expect(result!.versionCode, 2002);
      expect(result.currentPlatformInfo, isNotNull);
    });

    test('必须按本机 ABI 的 versionCode 比较，否则分包后永远判定"已是最新"', () {
      // --split-per-abi 把 versionCode 重写成 abiCode*1000+base：
      // base=4003 → v7a 5003 / arm64 6003 / x86_64 8003（x86_64 的 abiCode 是 4 不是 3）
      final info = AppVersionInfo.fromJson({
        'versionCode': 6003,
        'versionName': '1.0.2',
        'releaseNotes': '',
        'publishDate': '',
        'platforms': {
          'android': {
            'versionCode': 6003,
            'installMode': 'in_app_apk',
            'variants': {
              'arm64-v8a': {'versionCode': 6003},
              'armeabi-v7a': {'versionCode': 5003},
              'x86_64': {'versionCode': 8003},
            },
          },
        },
      });

      expect(info.effectiveVersionCodeFor(['arm64-v8a']), 6003);
      expect(info.effectiveVersionCodeFor(['armeabi-v7a', 'armeabi']), 5003);
      expect(info.effectiveVersionCodeFor(['x86_64']), 8003);
      // 未知 ABI 回退顶层
      expect(info.effectiveVersionCodeFor(['mips']), 6003);
      expect(info.effectiveVersionCodeFor(const []), 6003);
    });


    test('按设备 ABI 选择匹配的安装包，避免 v7a 设备下到 arm64 包', () {
      final android = PlatformUpdateInfo.fromJson({
        'downloadUrl': 'https://example.com/arm64.apk',
        'fileSize': 100,
        'sha256': 'aaa',
        'installMode': 'in_app_apk',
        'variants': {
          'arm64-v8a': {
            'downloadUrl': 'https://example.com/arm64.apk',
            'fileSize': 100,
            'sha256': 'aaa',
          },
          'armeabi-v7a': {
            'downloadUrl': 'https://example.com/v7a.apk',
            'fileSize': 90,
            'sha256': 'bbb',
          },
        },
      });

      // v7a 设备（SUPPORTED_ABIS 通常是 [armeabi-v7a, armeabi]）
      final v7a = android.resolveForAbis(['armeabi-v7a', 'armeabi']);
      expect(v7a.downloadUrl, 'https://example.com/v7a.apk');
      expect(v7a.sha256, 'bbb');
      expect(v7a.fileSize, 90);

      // arm64 设备优先命中 arm64
      final a64 = android.resolveForAbis(['arm64-v8a', 'armeabi-v7a']);
      expect(a64.downloadUrl, 'https://example.com/arm64.apk');

      // 未知 ABI 或拿不到 ABI 时回退到扁平字段，绝不能返回空
      expect(android.resolveForAbis(['mips']).downloadUrl,
          'https://example.com/arm64.apk');
      expect(android.resolveForAbis(const []).downloadUrl,
          'https://example.com/arm64.apk');
    });

    test('variants 能完整 round-trip 序列化', () {
      final src = PlatformUpdateInfo.fromJson({
        'downloadUrl': 'https://example.com/a.apk',
        'installMode': 'in_app_apk',
        'variants': {
          'x86_64': {
            'downloadUrl': 'https://example.com/x64.apk',
            'sha256': 'ccc',
          },
        },
      });
      final back = PlatformUpdateInfo.fromJson(src.toJson());
      expect(back.variants.length, 1);
      expect(back.variants['x86_64']!.sha256, 'ccc');
    });

    test(
        'buildAcceleratedDownloadUrls automatically prepends domestic proxy mirrors for GitHub URLs',
        () {
      const rawUrl =
          'https://github.com/Kline-x/novel-reader-flutter/releases/download/v1.0.1/app.apk';
      final accelerated =
          VersionCheckService.buildAcceleratedDownloadUrls(rawUrl);

      expect(accelerated.length, greaterThan(1));
      expect(
          accelerated.any((u) => u.startsWith('https://ghproxy.net/')), isTrue);
      expect(
          accelerated.any((u) => u.startsWith('https://mirror.ghproxy.com/')),
          isTrue);
      expect(accelerated.last, rawUrl); // 原始 URL 兜底存在

      // 非 GitHub URL 保持原样不重复添加前缀
      const cdnUrl = 'https://my-oss-bucket.aliyuncs.com/app.apk';
      final normal = VersionCheckService.buildAcceleratedDownloadUrls(cdnUrl);
      expect(normal, [cdnUrl]);

      // 已带有 ghproxy 前缀的 URL 应自动剥离前缀，绝不出现双重嵌套死链
      const nestedProxyUrl =
          'https://ghproxy.net/https://github.com/Kline-x/novel-reader-flutter/releases/download/v1.0.6/app.apk';
      final cleanedList =
          VersionCheckService.buildAcceleratedDownloadUrls(nestedProxyUrl);
      expect(cleanedList.any((u) => u.contains('https://ghproxy.net/https://ghproxy.net/')),
          isFalse);
      expect(cleanedList.first, startsWith('https://ghproxy.net/https://github.com/'));
    });

    test('探测节点应自动追加防缓存时间戳与防缓存头，且当首节点版本偏低时能择优选用更高版本节点', () async {
      final service = VersionCheckService();
      service.currentVersionCode = 4003;
      service.currentVersionName = '1.0.2';

      // 验证高可用探测端点中包含 ghproxy 加速源且已剔除 404 Gitee 源
      expect(VersionCheckService.highAvailabilityEndpoints.any((e) => e.contains('ghproxy.net')), isTrue);
      expect(VersionCheckService.highAvailabilityEndpoints.any((e) => e.contains('gitee.com')), isFalse);
    });
  });
}

