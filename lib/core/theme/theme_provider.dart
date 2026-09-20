
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/reader/data/storage_service.dart';
import 'soft_theme.dart';

/// 全局主题与四大意境状态提供者 (theme_provider.dart)
/// 核心模型：四大意境 (ThemeMood) 与明暗模式 (ThemeMode: system / light / dark) 完全正交！
/// - 开启跟随系统时：系统白天 -> 所选意境日间版；系统黑夜 -> 所选意境夜间版；意境永不丢失；
/// - 关闭跟随系统时：手动指定日间或夜间，可任意搭配四大意境色彩。

class ThemeNotifier extends StateNotifier<SoftPaletteType> {
  // 默认意境：极夜星芒。没选过配色的新用户直接进这一套。
  ThemeNotifier() : super(SoftPaletteType.darkJade) {
    _loadInitialTheme();
  }

  static const String _keySelectedMood = 'novel_reader_selected_mood';

  Future<void> _loadInitialTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final moodStr = prefs.getString(_keySelectedMood);
      if (moodStr != null) {
        final type = stringToPalette(moodStr);
        if (type != null) {
          state = type;
          return;
        }
      }
      // 兼容历史老字段
      final themeStr = await StorageService().getGlobalTheme();
      if (themeStr != 'system' && themeStr != 'light' && themeStr != 'dark') {
        final type = stringToPalette(themeStr);
        if (type != null) {
          state = type;
        }
      }
    } catch (_) {}
  }

  Future<void> setPalette(SoftPaletteType type) async {
    state = type;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keySelectedMood, paletteToString(type));
    } catch (_) {}
  }

  void nextPalette() {
    const values = [
      SoftPaletteType.mistyJade,
      SoftPaletteType.warmAmber,
      SoftPaletteType.moonSilver,
      SoftPaletteType.darkJade,
      SoftPaletteType.paper,
    ];
    final nextIndex = (values.indexOf(state) + 1) % values.length;
    setPalette(values[nextIndex]);
  }

  static SoftPaletteType? stringToPalette(String str) {
    switch (str.toLowerCase()) {
      case 'mistyjade':
      case 'jade':
      case 'beangreen':
      case 'green':
        return SoftPaletteType.mistyJade;
      case 'warmamber':
      case 'twilightamber':
      case 'amber':
      case 'parchment':
      case 'cream':
        return SoftPaletteType.warmAmber;
      case 'moonsilver':
      case 'violetorchid':
      case 'orchid':
      case 'silver':
      case 'moon':
        return SoftPaletteType.moonSilver;
      case 'darkjade':
      case 'auroraspace':
      case 'aurora':
      case 'night':
      case 'dark':
        return SoftPaletteType.darkJade;
      case 'paper':
      case 'white':
        return SoftPaletteType.paper;
      default:
        return null;
    }
  }

  static String paletteToString(SoftPaletteType type) {
    switch (type) {
      case SoftPaletteType.mistyJade:
      case SoftPaletteType.beanGreen:
        return 'mistyJade';
      case SoftPaletteType.warmAmber:
      case SoftPaletteType.twilightAmber:
      case SoftPaletteType.parchment:
        return 'warmAmber';
      case SoftPaletteType.moonSilver:
      case SoftPaletteType.violetOrchid:
        return 'moonSilver';
      case SoftPaletteType.darkJade:
      case SoftPaletteType.auroraSpace:
      case SoftPaletteType.night:
        return 'darkJade';
      case SoftPaletteType.paper:
        return 'paper';
    }
  }

  /// 当前系统亮度
  static Brightness get systemBrightness =>
      currentPlatformBrightness;
}

/// 明暗模式状态管理 (system / light / dark)
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _loadInitialMode();
  }

  static const String _keyThemeMode = 'novel_reader_theme_mode';

  Future<void> _loadInitialMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeStr = prefs.getString(_keyThemeMode);
      if (modeStr != null) {
        if (modeStr == 'light') {
          state = ThemeMode.light;
        } else if (modeStr == 'dark') {
          state = ThemeMode.dark;
        } else {
          state = ThemeMode.system;
        }
        return;
      }

      // 兼容老版本
      final legacy = await StorageService().getGlobalTheme();
      if (legacy == 'system') {
        state = ThemeMode.system;
      } else if (legacy == 'dark' || legacy == 'night') {
        state = ThemeMode.dark;
      } else {
        // 默认跟随系统
        state = ThemeMode.system;
      }
    } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeStr = mode == ThemeMode.light
          ? 'light'
          : (mode == ThemeMode.dark ? 'dark' : 'system');
      await prefs.setString(_keyThemeMode, modeStr);
      await StorageService().setGlobalTheme(modeStr);
    } catch (_) {}
  }

  Future<void> setFollowSystem(bool follow) async {
    if (follow) {
      await setThemeMode(ThemeMode.system);
    } else {
      // 关闭跟随系统时，默认保持当前系统实际呈现的明暗模式
      final isDark =
          currentPlatformBrightness == Brightness.dark;
      await setThemeMode(isDark ? ThemeMode.dark : ThemeMode.light);
    }
  }

  Future<void> toggleLightDark() async {
    if (state == ThemeMode.dark) {
      await setThemeMode(ThemeMode.light);
    } else {
      await setThemeMode(ThemeMode.dark);
    }
  }
}

/// 核心提供者定义
final themeProvider =
    StateNotifierProvider<ThemeNotifier, SoftPaletteType>((ref) {
  return ThemeNotifier();
});

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

/// 系统深浅色的响应式来源。
///
/// 原先由 ThemeModeNotifier 兼任观察者，在 didChangePlatformBrightness 里
/// 写 `state = ThemeMode.system` 想「触发刷新」——但 StateNotifier 赋同一个值
/// 根本不会通知监听者（枚举是 const 单例，identical 为真直接 return），
/// 于是系统切深色时 UI 完全不重建。必须让亮度**本身**成为会变的状态。
class PlatformBrightnessNotifier extends StateNotifier<Brightness>
    with WidgetsBindingObserver {
  PlatformBrightnessNotifier() : super(currentPlatformBrightness) {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangePlatformBrightness() {
    state = currentPlatformBrightness;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

final platformBrightnessProvider =
    StateNotifierProvider<PlatformBrightnessNotifier, Brightness>(
        (ref) => PlatformBrightnessNotifier());

/// 系统当前的深浅色。
///
/// 走 `WidgetsBinding.instance.platformDispatcher` 而不是
/// `PlatformDispatcher.instance`：后者是真实单例，测试里覆盖不了，
/// 导致「跟随系统」这条分支长期没有任何测试能覆盖——
/// 极夜星芒在跟随系统下恒为夜间的缺陷就是这么漏出去的。
Brightness get currentPlatformBrightness =>
    WidgetsBinding.instance.platformDispatcher.platformBrightness;

/// 是否跟随系统深浅色
final isFollowingSystemProvider = Provider<bool>((ref) {
  final mode = ref.watch(themeModeProvider);
  return mode == ThemeMode.system;
});

/// 当前是否为深色模式（结合模式设置与系统亮度）
final isDarkModeProvider = Provider<bool>((ref) {
  final mode = ref.watch(themeModeProvider);
  if (mode == ThemeMode.system) {
    return ref.watch(platformBrightnessProvider) == Brightness.dark;
  }
  return mode == ThemeMode.dark;
});

/// 合成最终当前生效的 SoftColors（意境 × 明暗完全联动）
final softColorsProvider = Provider<SoftColors>((ref) {
  final paletteType = ref.watch(themeProvider);

  // 明暗一律复用 isDarkModeProvider，不再各算一遍。
  // 此前这里额外把 auroraSpace / darkJade / night 三个配色强制判暗，
  // 于是选了「极夜星芒」再选「跟随系统」，系统明明是日间也一直显示夜间
  // ——而这三个配色本来就有日间变体（auroraSpaceLight）。
  // 而且 isDarkModeProvider 没有这段强制逻辑，两个 provider 会给出相反答案。
  final isDark = ref.watch(isDarkModeProvider);

  return SoftColors.fromType(paletteType, isDark: isDark);
});

