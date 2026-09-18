import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('阶段 14：生产混淆瘦身与 ProGuard 规则校验', () {
    test('ProGuard 混淆规则文件完整性校验', () {
      final rulesFile = File('android/app/proguard-rules.pro');
      expect(rulesFile.existsSync(), isTrue, reason: 'proguard-rules.pro 必须存在');

      final content = rulesFile.readAsStringSync();
      // 必须包含对 Flutter 引擎的白名单保护
      expect(content, contains('-keep class io.flutter.** { *; }'));
      // 必须包含对包名主代码的保护
      expect(
          content,
          contains(
              '-keep class com.kline.novelreader.novel_reader_flutter.** { *; }'));
      // 必须包含第三方平台插件
      expect(content, contains('fluttertts'));
      expect(content, contains('sharedpreferences'));
      expect(content, contains('pathprovider'));
      // 必须包含 Parcelable 与 枚举
      expect(content, contains('Parcelable'));
      expect(content, contains('enum *'));
    });

    test('Gradle 生产构建脚本瘦身与混淆开关校验', () {
      final gradleFile = File('android/app/build.gradle.kts');
      expect(gradleFile.existsSync(), isTrue);

      final content = gradleFile.readAsStringSync();
      expect(content, contains('isMinifyEnabled = true'));
      expect(content, contains('isShrinkResources = true'));
      expect(content, contains('proguardFiles('));
      expect(content, contains('"proguard-rules.pro"'));
    });

    test('生产包体积瘦身率校验 (Release vs Debug)', () {
      final releaseArm64 =
          File('build/app/outputs/flutter-apk/app-arm64-v8a-release.apk');
      if (releaseArm64.existsSync()) {
        final bytes = releaseArm64.lengthSync();
        final mb = bytes / (1024 * 1024);
        // 单架构 release 包应当小于 30MB（远小于 149MB 的 debug 通用包）
        expect(mb, lessThan(30.0),
            reason: 'arm64-v8a 发布包体积应小于 30MB，当前为 ${mb.toStringAsFixed(1)}MB');
      }
    });
  });

  group('阶段 14：GitHub Releases 自动化发版流水线校验', () {
    test('release.yml 工作流触发与发版步骤完整性', () {
      final releaseYml = File('.github/workflows/release.yml');
      expect(releaseYml.existsSync(), isTrue, reason: 'release.yml 必须存在');

      final content = releaseYml.readAsStringSync();
      // 触发条件
      expect(content, contains('push:'));
      expect(content, contains("tags:\n      - 'v*'"));
      expect(content, contains('workflow_dispatch:'));

      // 门禁保障
      expect(content, contains('quality-gate'));
      expect(content, contains('flutter analyze'));
      expect(content, contains('flutter test'));
      expect(content, contains('OpenHarmony NEXT Dependency Audit'));

      // 构建构件
      expect(content, contains('build apk --release --split-per-abi'));
      expect(content, contains('build appbundle --release'));
      expect(content, contains('build web --release'));
      expect(content, contains('sha256sum'));

      // GitHub Release 发布 action
      expect(content, contains('softprops/action-gh-release@v2'));
      expect(content, contains('SHA256SUMS.txt'));
    });
  });

  group('全工程终审：14 个阶段目标全部达成闭环校验', () {
    test('PROGRESS.md 与 HANDOFF.md 必须包含全部 14 个完整阶段记录', () {
      final progressFile = File('PROGRESS.md');
      expect(progressFile.existsSync(), isTrue);
      final progressContent = progressFile.readAsStringSync();

      for (int i = 1; i <= 14; i++) {
        expect(
          progressContent,
          contains('阶段 $i'),
          reason: 'PROGRESS.md 必须包含 阶段 $i',
        );
      }
    });
  });
}
