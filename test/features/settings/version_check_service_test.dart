import 'package:flutter_test/flutter_test.dart';
import 'package:novel_reader_flutter/features/settings/services/version_check_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    VersionCheckService().currentVersionCode = 1;
    VersionCheckService().currentVersionName = '1.0.0';
  });

  group('VersionCheckService & AppVersionInfo Tests', () {
    test('AppVersionInfo fromJson and toJson should serialize platform matrix properly', () {
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
      expect(info.platforms['android']?.downloadUrl, 'https://example.com/app.apk');
      expect(info.platforms['ios']?.storeUrl, 'itms-apps://itunes.apple.com/app/id123456');
      expect(info.platforms['harmony']?.installMode, 'app_market');

      final serialized = info.toJson();
      expect(serialized['versionCode'], 3);
      expect(serialized['versionName'], '1.0.2');
      expect((serialized['platforms'] as Map)['android']['fileSize'], 10240);
    });

    test('checkLatestVersion should return new version info when remote versionCode > current', () async {
      final service = VersionCheckService();

      final newVersion = await service.checkLatestVersion(forceMock: true, currentCode: 1);
      expect(newVersion, isNotNull);
      expect(newVersion!.versionCode, 2);
      expect(newVersion.versionName, '1.0.1');
      expect(newVersion.releaseNotes, contains('跨端高可用远程版本升级体系'));
    });

    test('checkLatestVersion should return null when local version is already latest', () async {
      final service = VersionCheckService();

      final newVersion = await service.checkLatestVersion(forceMock: true, currentCode: 2);
      expect(newVersion, isNull);
    });

    test('fallback probe returns defaultMockVersion when endpoints fail or offline', () async {
      final service = VersionCheckService();

      final result = await service.checkLatestVersion(
        endpoint: 'http://127.0.0.1:54321/invalid_version.json',
        currentCode: 1,
      );
      expect(result, isNotNull);
      expect(result!.versionCode, 2);
      expect(result.currentPlatformInfo, isNotNull);
    });

    test('executePlatformUpdate progresses smoothly to 1.0', () async {
      final service = VersionCheckService();
      final progresses = <double>[];

      await service.executePlatformUpdate(
        VersionCheckService.defaultMockVersion,
        onProgress: (p) => progresses.add(p),
      );

      expect(progresses, isNotEmpty);
      expect(progresses.last, 1.0);
    });
  });
}
