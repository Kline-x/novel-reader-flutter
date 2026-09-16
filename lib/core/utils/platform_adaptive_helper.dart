import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 设备形态枚举
enum DeviceFormFactor {
  /// 智能手机（竖屏）
  phone,

  /// 折叠屏展开态 / 小平板
  foldable,

  /// 大屏平板 / 平板横屏
  tablet,

  /// 桌面端 / Web 大屏
  desktop,
}

/// 跨端自适应与异形屏安全区辅助引擎
/// 负责 iOS、Android、HarmonyOS NEXT (纯血鸿蒙)、Web 等全端形态的自适应排版断点与安全区下压
class PlatformAdaptiveHelper {
  /// 单例实例
  static final PlatformAdaptiveHelper instance = PlatformAdaptiveHelper._();
  PlatformAdaptiveHelper._();

  /// 测试模式下强制指定的设备形态
  @visibleForTesting
  DeviceFormFactor? testFormFactorOverride;

  /// 测试模式下强制指定的平台
  @visibleForTesting
  TargetPlatform? testPlatformOverride;

  /// 获取当前运行平台类型
  TargetPlatform get currentPlatform =>
      testPlatformOverride ?? defaultTargetPlatform;

  /// 是否运行在 iOS 设备
  bool get isIOS => !kIsWeb && currentPlatform == TargetPlatform.iOS;

  /// 是否运行在 Android 设备
  bool get isAndroid => !kIsWeb && currentPlatform == TargetPlatform.android;

  /// 是否运行在纯血鸿蒙 (OpenHarmony NEXT)
  /// 在 OpenHarmony 运行时，defaultTargetPlatform 为 ohos 或通过系统属性识别
  bool get isHarmonyOS {
    if (kIsWeb) return false;
    // 检查环境变量或构建标识
    final isOhosTarget = currentPlatform == TargetPlatform.android &&
        (Platform.environment['OS_TYPE'] == 'HarmonyOS' ||
            Platform.environment['OHOS_NDK_HOME'] != null);
    return isOhosTarget;
  }

  /// 获取当前设备形态断点
  DeviceFormFactor getFormFactor(BuildContext context) {
    if (testFormFactorOverride != null) {
      return testFormFactorOverride!;
    }
    final width = MediaQuery.of(context).size.width;
    if (width < 600) {
      return DeviceFormFactor.phone;
    } else if (width < 840) {
      return DeviceFormFactor.foldable;
    } else if (width < 1200) {
      return DeviceFormFactor.tablet;
    } else {
      return DeviceFormFactor.desktop;
    }
  }

  /// 是否属于大屏设备（折叠屏展开态、平板或桌面端）
  bool isLargeScreen(BuildContext context) {
    final formFactor = getFormFactor(context);
    return formFactor != DeviceFormFactor.phone;
  }

  /// 书架自适应网格列数计算
  int getShelfGridColumnCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 450) {
      return 3;
    } else if (width < 700) {
      return 4;
    } else if (width < 1000) {
      return 5;
    } else {
      return 6;
    }
  }

  /// 计算阅读器多端自适应安全内边距
  /// 综合考量灵动岛、挖孔屏、刘海屏顶部遮挡及底部手势指示条 (Home Indicator)
  EdgeInsets getAdaptiveReaderPadding(BuildContext context, {
    double baseHorizontal = 18.0,
    double baseVertical = 12.0,
  }) {
    final mediaQuery = MediaQuery.of(context);
    final viewPadding = mediaQuery.padding;

    // 针对挖孔、灵动岛或状态栏做优雅下压
    final topPadding = (viewPadding.top > 0 ? viewPadding.top : 24.0) + baseVertical;
    // 针对底部手势小白条做优雅安全避让
    final bottomPadding = (viewPadding.bottom > 0 ? viewPadding.bottom : 16.0) + baseVertical;
    // 横屏或大屏时的侧边留白
    final horizontalPadding = (viewPadding.left + viewPadding.right > 0)
        ? (viewPadding.left + viewPadding.right) / 2 + baseHorizontal
        : (isLargeScreen(context) ? 48.0 : baseHorizontal);

    return EdgeInsets.only(
      top: topPadding,
      bottom: bottomPadding,
      left: horizontalPadding,
      right: horizontalPadding,
    );
  }

  /// 纯血鸿蒙 OpenHarmony-TPC 准入军规依赖白名单校验
  /// 校验 pubspec.yaml 中依赖项是否满足 Pure Dart 或 OpenHarmony-TPC 官方认证
  static const Set<String> _prohibitedNativePlugins = {
    'flutter_inappwebview',
    'webview_flutter',
    'google_mobile_ads',
    'flutter_facebook_auth',
  };

  /// 检查单个依赖项是否通过鸿蒙准入门禁
  static bool isDependencyCompatibleWithOhos(String package) {
    return !_prohibitedNativePlugins.contains(package.trim().toLowerCase());
  }

  /// 检查依赖列表是否全量通过鸿蒙准入门禁
  static Map<String, dynamic> auditOhosDependencies(List<String> dependencies) {
    final violations = <String>[];
    for (final dep in dependencies) {
      if (!isDependencyCompatibleWithOhos(dep)) {
        violations.add(dep);
      }
    }
    return {
      'passed': violations.isEmpty,
      'violations': violations,
      'total': dependencies.length,
    };
  }
}
