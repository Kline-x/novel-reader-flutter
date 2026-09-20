// 2026-09-20 真机反馈的三个缺陷
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_reader_flutter/core/theme/soft_theme.dart';
import 'package:novel_reader_flutter/core/theme/theme_provider.dart';
import 'package:novel_reader_flutter/features/reader/data/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. 全新安装的书架应为空', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('没有手动调用 seedDefaultBooks 时，书架读出来是空的', () async {
      final books = await StorageService().getBookshelf();
      expect(books, isEmpty,
          reason: '刚装完就有 4 本自己没加过的书，用户会以为数据串了');
    });
  });

  group('1b. 设置页的阅读统计必须是真实数据', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('全新安装时累计阅读时长为 0，而不是写死的 38.5 小时', () async {
      expect(await StorageService().getTotalReadingMinutes(), 0);
    });

    test('累计时长跨自然日求和', () async {
      final storage = StorageService();
      await storage.addReadingSeconds(1800); // 今天 30 分钟
      // 直接塞一个历史日期的键，模拟前几天读过
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('novel_reader_daily_seconds_2026_09_01', 3600);

      expect(await storage.getTotalReadingMinutes(), 90);
    });
  });

  group('2. 跟随系统时配色不得被强制判暗', () {
    // 三个共用 auroraSpace 调色板的配色，此前在「跟随系统」下被无条件判暗，
    // 于是选了「极夜星芒」再选「跟随系统」，日间也一直是夜间配色。
    const forcedDarkBefore = [
      SoftPaletteType.auroraSpace,
      SoftPaletteType.darkJade,
      SoftPaletteType.night,
    ];

    for (final palette in forcedDarkBefore) {
      test('$palette 有日间变体，且与夜间变体不同', () {
        final light = SoftColors.fromType(palette, isDark: false);
        final dark = SoftColors.fromType(palette, isDark: true);
        expect(light.background, isNot(equals(dark.background)),
            reason: '日间与夜间必须是两套颜色，否则「跟随系统」切换不出效果');
      });
    }

    // 关键：必须用 ThemeMode.system + 系统为浅色。
    // 缺陷只在 system 分支触发，拿 ThemeMode.light 测等于没测
    // （两种实现都走 else 分支，怎么写都绿）。
    test('跟随系统 + 系统浅色时，这三个配色必须出日间色', () {
      final dispatcher = TestWidgetsFlutterBinding.instance.platformDispatcher;
      dispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(dispatcher.clearPlatformBrightnessTestValue);

      for (final palette in forcedDarkBefore) {
        final container = ProviderContainer(overrides: [
          themeProvider.overrideWith((ref) => _FixedPalette(palette)),
          themeModeProvider.overrideWith((ref) => _FixedMode(ThemeMode.system)),
        ]);
        addTearDown(container.dispose);

        final colors = container.read(softColorsProvider);
        final light = SoftColors.fromType(palette, isDark: false);
        expect(colors.background, light.background,
            reason: '$palette 选「跟随系统」后，系统是日间却出了夜间配色');
      }
    });

    test('跟随系统 + 系统深色时仍应出夜间色', () {
      final dispatcher = TestWidgetsFlutterBinding.instance.platformDispatcher;
      dispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(dispatcher.clearPlatformBrightnessTestValue);

      final container = ProviderContainer(overrides: [
        themeProvider
            .overrideWith((ref) => _FixedPalette(SoftPaletteType.darkJade)),
        themeModeProvider.overrideWith((ref) => _FixedMode(ThemeMode.system)),
      ]);
      addTearDown(container.dispose);

      final colors = container.read(softColorsProvider);
      final dark = SoftColors.fromType(SoftPaletteType.darkJade, isDark: true);
      expect(colors.background, dark.background);
    });

    // 真机复验时发现的第四个缺陷：读到的值修对了，但**值变了通知不出去**。
    // 原先 ThemeModeNotifier 在 didChangePlatformBrightness 里写
    // `state = ThemeMode.system` 想触发刷新，而 StateNotifier 赋同一个值
    // 不会通知监听者，于是系统切深色时界面纹丝不动。
    test('系统亮度变化后，配色必须跟着变', () {
      final dispatcher = TestWidgetsFlutterBinding.instance.platformDispatcher;
      dispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(dispatcher.clearPlatformBrightnessTestValue);

      final container = ProviderContainer(overrides: [
        themeProvider
            .overrideWith((ref) => _FixedPalette(SoftPaletteType.darkJade)),
        themeModeProvider.overrideWith((ref) => _FixedMode(ThemeMode.system)),
      ]);
      addTearDown(container.dispose);

      expect(container.read(softColorsProvider).isDark, isFalse);

      // 模拟系统切到深色：既要改亮度，也要把回调发出去
      dispatcher.platformBrightnessTestValue = Brightness.dark;
      container
          .read(platformBrightnessProvider.notifier)
          .didChangePlatformBrightness();

      expect(container.read(softColorsProvider).isDark, isTrue,
          reason: '系统切深色后界面必须跟着变暗，此前赋同值导致完全不刷新');
      expect(container.read(isDarkModeProvider), isTrue);
    });

    test('isDarkModeProvider 与 softColorsProvider 必须一致', () {
      final dispatcher = TestWidgetsFlutterBinding.instance.platformDispatcher;
      dispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(dispatcher.clearPlatformBrightnessTestValue);

      final container = ProviderContainer(overrides: [
        themeProvider
            .overrideWith((ref) => _FixedPalette(SoftPaletteType.darkJade)),
        themeModeProvider.overrideWith((ref) => _FixedMode(ThemeMode.system)),
      ]);
      addTearDown(container.dispose);

      final isDark = container.read(isDarkModeProvider);
      final colors = container.read(softColorsProvider);
      expect(
        colors.background,
        SoftColors.fromType(SoftPaletteType.darkJade, isDark: isDark).background,
        reason: '两个 provider 曾对同一状态给出相反答案',
      );
    });
  });
}

class _FixedPalette extends ThemeNotifier {
  _FixedPalette(SoftPaletteType type) {
    state = type;
  }
}

class _FixedMode extends ThemeModeNotifier {
  _FixedMode(ThemeMode mode) {
    state = mode;
  }
}
