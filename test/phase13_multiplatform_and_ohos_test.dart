import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_reader_flutter/core/utils/platform_adaptive_helper.dart';

void main() {
  group('阶段 13：跨端自适应与异形屏安全区测试', () {
    testWidgets('手机竖屏形态 (<600dp) 判定与 3 列网格分配', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625; // 逻辑宽度 ≈ 411.4dp
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final helper = PlatformAdaptiveHelper.instance;
              final formFactor = helper.getFormFactor(context);
              final columns = helper.getShelfGridColumnCount(context);
              final isLarge = helper.isLargeScreen(context);

              expect(formFactor, equals(DeviceFormFactor.phone));
              expect(columns, equals(3));
              expect(isLarge, isFalse);
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('折叠屏展开态 / 小平板 (600~840dp) 判定与 4 列网格自适应', (tester) async {
      tester.view.physicalSize = const Size(1400, 1600);
      tester.view.devicePixelRatio = 2.0; // 逻辑宽度 700dp
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final helper = PlatformAdaptiveHelper.instance;
              final formFactor = helper.getFormFactor(context);
              final columns = helper.getShelfGridColumnCount(context);
              final isLarge = helper.isLargeScreen(context);

              expect(formFactor, equals(DeviceFormFactor.foldable));
              expect(columns, equals(5)); // 700dp 进入 >= 700 的 5 列区间
              expect(isLarge, isTrue);
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('大屏平板与桌面端 (>840dp) 判定与 6 列网格自适应', (tester) async {
      tester.view.physicalSize = const Size(2560, 1600);
      tester.view.devicePixelRatio = 2.0; // 逻辑宽度 1280dp
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final helper = PlatformAdaptiveHelper.instance;
              final formFactor = helper.getFormFactor(context);
              final columns = helper.getShelfGridColumnCount(context);
              final isLarge = helper.isLargeScreen(context);

              expect(formFactor, equals(DeviceFormFactor.desktop));
              expect(columns, equals(6));
              expect(isLarge, isTrue);
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('异形屏/挖孔屏/灵动岛与底部手势条安全区动态计算', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              padding: EdgeInsets.only(top: 48, bottom: 34),
            ),
            child: Builder(
              builder: (context) {
                final helper = PlatformAdaptiveHelper.instance;
                final padding = helper.getAdaptiveReaderPadding(context);

                // 顶部下压：48 + 12 = 60
                expect(padding.top, equals(60.0));
                // 底部小白条避让：34 + 12 = 46
                expect(padding.bottom, equals(46.0));
                return const SizedBox();
              },
            ),
          ),
        ),
      );
    });
  });

  group('阶段 13：纯血鸿蒙 (OpenHarmony NEXT) 规范与生态准入门禁', () {
    test('OpenHarmony-TPC 准入算法：黑名单拦截与 Pure Dart 准入验证', () {
      final safeDeps = ['dio', 'flutter_riverpod', 'lpinyin', 'fast_gbk', 'archive'];
      final audit1 = PlatformAdaptiveHelper.auditOhosDependencies(safeDeps);
      expect(audit1['passed'], isTrue);
      expect(audit1['violations'], isEmpty);

      final unsafeDeps = ['dio', 'flutter_inappwebview', 'google_mobile_ads'];
      final audit2 = PlatformAdaptiveHelper.auditOhosDependencies(unsafeDeps);
      expect(audit2['passed'], isFalse);
      expect(audit2['violations'], contains('flutter_inappwebview'));
      expect(audit2['violations'], contains('google_mobile_ads'));
    });

    test('实景审计：检验当前工程 pubspec.yaml 全量依赖 100% 符合纯血鸿蒙规范', () {
      final pubspecFile = File('pubspec.yaml');
      expect(pubspecFile.existsSync(), isTrue);

      final lines = pubspecFile.readAsLinesSync();
      final deps = <String>[];
      bool inDeps = false;
      for (final line in lines) {
        if (line.startsWith('dependencies:')) {
          inDeps = true;
          continue;
        } else if (line.startsWith('dev_dependencies:') || line.startsWith('flutter:')) {
          inDeps = false;
        }
        if (inDeps && line.trim().isNotEmpty && !line.startsWith('#') && line.contains(':')) {
          final depName = line.split(':').first.trim();
          if (depName != 'flutter' && depName != 'sdk') {
            deps.add(depName);
          }
        }
      }

      final result = PlatformAdaptiveHelper.auditOhosDependencies(deps);
      expect(
        result['passed'],
        isTrue,
        reason: '发现未被 OpenHarmony-TPC 认证的依赖: ${result['violations']}',
      );
    });

    test('纯血鸿蒙工程结构完整性校验 (ohos/)', () {
      // 1. AppScope
      final appJson5 = File('ohos/AppScope/app.json5');
      expect(appJson5.existsSync(), isTrue);
      expect(appJson5.readAsStringSync(), contains('com.kline.novelreader.flutter'));
      expect(appJson5.readAsStringSync(), contains('\$media:app_icon'));

      // 2. build-profile.json5
      final buildProfile = File('ohos/build-profile.json5');
      expect(buildProfile.existsSync(), isTrue);
      expect(buildProfile.readAsStringSync(), contains('OpenHarmony'));

      // 3. entry module.json5 与 权限配置
      final moduleJson5 = File('ohos/entry/src/main/module.json5');
      expect(moduleJson5.existsSync(), isTrue);
      final moduleContent = moduleJson5.readAsStringSync();
      expect(moduleContent, contains('ohos.permission.INTERNET'));
      expect(moduleContent, contains('ohos.permission.READ_MEDIA'));
      expect(moduleContent, contains('ohos.permission.KEEP_BACKGROUND_RUNNING'));

      // 4. ArkTS 入口与主视图
      final entryAbility = File('ohos/entry/src/main/ets/entryability/EntryAbility.ets');
      expect(entryAbility.existsSync(), isTrue);
      expect(entryAbility.readAsStringSync(), contains('UIAbility'));

      final appIcon = File('ohos/AppScope/resources/base/media/app_icon.png');
      expect(appIcon.existsSync(), isTrue);
    });
  });

  group('阶段 13：iOS 平台落地与合规权限配置校验', () {
    test('iOS Info.plist 权限声明与本地化应用名称校验', () {
      final infoPlist = File('ios/Runner/Info.plist');
      expect(infoPlist.existsSync(), isTrue);

      final content = infoPlist.readAsStringSync();
      // 应用名称
      expect(content, contains('<string>藏书阁</string>'));
      // WiFi 局域网传书权限
      expect(content, contains('NSLocalNetworkUsageDescription'));
      expect(content, contains('NSBonjourServices'));
      // 听书后台音频
      expect(content, contains('UIBackgroundModes'));
      expect(content, contains('<string>audio</string>'));
      // 文件 App 互联
      expect(content, contains('UISupportsDocumentBrowser'));
      expect(content, contains('LSSupportsOpeningDocumentsInPlace'));
    });

    test('iOS Podfile 部署目标与架构规范校验', () {
      final podfile = File('ios/Podfile');
      expect(podfile.existsSync(), isTrue);
      final content = podfile.readAsStringSync();
      expect(content, contains("platform :ios, '13.0'"));
    });
  });
}
