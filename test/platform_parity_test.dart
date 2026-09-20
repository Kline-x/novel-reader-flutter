import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 平台对等门禁。
///
/// 本项目自写的 MethodChannel 必须在每个受支持的平台上都有实现，
/// 否则那个平台的调用要么抛 MissingPluginException、要么永久挂起，
/// 而这类问题在别的平台上完全看不出来。
///
/// 真实踩过两次：
/// - 鸿蒙侧插件注册表为空，`path_provider` 的调用既不返回也不抛异常，
///   界面永远停在「正在加载」；
/// - 补完鸿蒙才发现 iOS 压根没有 app_update 通道，版本号同样回退到
///   内置默认值 v1.0.1，把已装版本当新版本推给用户。
///
/// 所以这道门禁不是形式主义：它要求任何新增的宿主能力，
/// 要么三端都实现，要么在下面的豁免表里写清楚为什么做不到。
void main() {
  const channelPrefix = 'com.kline.novelreader/';

  /// 各平台宿主实现所在的文件
  const hosts = <String, String>{
    'Android':
        'android/app/src/main/kotlin/com/kline/novelreader/novel_reader_flutter/MainActivity.kt',
    'iOS': 'ios/Runner/AppDelegate.swift',
    '鸿蒙': 'ohos/entry/src/main/ets/plugins/NovelReaderHostPlugin.ets',
  };

  /// 平台能力确实做不到的豁免。加条目必须写明原因，不接受「以后再说」。
  const exemptions = <String, Map<String, String>>{
    'com.kline.novelreader/volume_key': {
      'iOS': 'iOS 不把音量键事件分发给普通应用，系统层面就拦不到',
    },
  };

  test('自写 MethodChannel 必须三端都有实现', () {
    // 1. 扫出 Dart 侧用到的所有自写通道
    final channels = <String>{};
    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue, reason: '找不到 lib/ 目录');

    final pattern = RegExp("'(${RegExp.escape(channelPrefix)}[a-z_]+)'");
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      for (final m in pattern.allMatches(entity.readAsStringSync())) {
        channels.add(m.group(1)!);
      }
    }

    expect(channels, isNotEmpty,
        reason: '一个自写通道都没扫到，正则或目录结构变了，先修这里');

    // 2. 读各平台宿主实现
    final hostSources = <String, String>{};
    hosts.forEach((platform, path) {
      final f = File(path);
      expect(f.existsSync(), isTrue, reason: '$platform 的宿主实现文件不存在: $path');
      hostSources[platform] = f.readAsStringSync();
    });

    // 3. 逐个通道核对
    final missing = <String>[];
    for (final channel in channels) {
      hostSources.forEach((platform, source) {
        if (source.contains(channel)) return;
        final why = exemptions[channel]?[platform];
        if (why != null) return; // 已写明原因的平台限制
        missing.add('$channel 在 $platform 侧没有实现');
      });
    }

    expect(missing, isEmpty,
        reason: '以下通道缺平台实现，要么补上，要么在 exemptions 里写明为什么做不到：\n'
            '${missing.join('\n')}');
  });

  test('豁免表里的条目必须仍然对应真实存在的通道', () {
    final libDir = Directory('lib');
    final all = libDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .map((f) => f.readAsStringSync())
        .join('\n');

    for (final channel in exemptions.keys) {
      expect(all.contains(channel), isTrue,
          reason: '豁免表里的 $channel 在 lib/ 下已经不存在了，删掉这条豁免');
    }
  });

  test('应用图标三端齐备，且鸿蒙走分层图标', () {
    // 图标也属于「改一端就得改三端」的范畴：
    // 此前鸿蒙一直是 flutter create 的默认蓝色方块，和另外两端对不上。
    const required = <String, List<String>>{
      'Android': [
        'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
        'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_foreground.png',
        'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_background.png',
        'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
      ],
      'iOS': [
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png',
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png',
      ],
      '鸿蒙': [
        'ohos/AppScope/resources/base/media/foreground.png',
        'ohos/AppScope/resources/base/media/background.png',
        'ohos/AppScope/resources/base/media/layered_image.json',
      ],
    };

    final missing = <String>[];
    required.forEach((platform, paths) {
      for (final p in paths) {
        if (!File(p).existsSync()) missing.add('$platform 缺 $p');
      }
    });
    expect(missing, isEmpty, reason: missing.join('\n'));

    // 矢量源必须在库里，改图标要从 SVG 出发而不是改 PNG
    expect(File('design/icon/app_icon.svg').existsSync(), isTrue,
        reason: '图标矢量源必须入库');
  });
}
