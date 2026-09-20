import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_reader_flutter/core/utils/platform_adaptive_helper.dart';

void main() {
  final helper = PlatformAdaptiveHelper.instance;

  tearDown(() => helper.testPlatformOverride = null);

  group('平台能力：音量键翻页只有 Android 拦得住', () {
    test('Android 支持', () {
      helper.testPlatformOverride = TargetPlatform.android;
      expect(helper.supportsVolumeKeyPaging, isTrue,
          reason: 'MainActivity 覆写了 onKeyDown，能拦下音量键');
    });

    test('iOS 不支持', () {
      helper.testPlatformOverride = TargetPlatform.iOS;
      expect(helper.supportsVolumeKeyPaging, isFalse,
          reason: 'iOS 不把音量键事件分发给普通应用');
    });

    test('桌面端不支持', () {
      for (final p in [
        TargetPlatform.windows,
        TargetPlatform.macOS,
        TargetPlatform.linux,
      ]) {
        helper.testPlatformOverride = p;
        expect(helper.supportsVolumeKeyPaging, isFalse, reason: '$p 没有这回事');
      }
    });
  });
}
