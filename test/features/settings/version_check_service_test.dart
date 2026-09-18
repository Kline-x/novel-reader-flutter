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
    });
  });
}
