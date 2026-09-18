import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/reader/data/storage_service.dart';
import 'soft_theme.dart';

/// 全局主题提供者 (theme_provider.dart)
class ThemeNotifier extends StateNotifier<SoftPaletteType>
    with WidgetsBindingObserver {
  ThemeNotifier() : super(SoftPaletteType.parchment) {
    WidgetsBinding.instance.addObserver(this);
    _loadInitialTheme();
  }

  bool _isFollowingSystem = false;
  bool get isFollowingSystem => _isFollowingSystem;

  /// 当前系统亮度
  static Brightness get systemBrightness =>
      PlatformDispatcher.instance.platformBrightness;

  /// 系统亮度对应的配色
  static SoftPaletteType paletteForBrightness(Brightness b) =>
      b == Brightness.dark ? SoftPaletteType.night : SoftPaletteType.parchment;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 系统深浅色切换时实时跟随
  ///
  /// 此前全工程没有任何地方监听 platformBrightness，
  /// 系统切换深色模式后应用毫无反应。
  @override
  void didChangePlatformBrightness() {
    if (!_isFollowingSystem) return;
    final next = paletteForBrightness(systemBrightness);
    if (state != next) {
      state = next;
    }
  }

  Future<void> _loadInitialTheme() async {
    try {
      final themeStr = await StorageService().getGlobalTheme();
      if (themeStr == 'system') {
        _isFollowingSystem = true;
        // 关键修复：此前这里只置了标志位，没有按系统亮度设置 state，
        // 于是 state 永远停留在构造时的 parchment（浅色），
        // 导致"跟随系统深色模式"开着也永远是浅色。
        state = paletteForBrightness(systemBrightness);
      } else {
        _isFollowingSystem = false;
        final type = stringToPalette(themeStr);
        if (type != null) {
          state = type;
        }
      }
    } catch (_) {}
  }

  void setPalette(SoftPaletteType type) {
    _isFollowingSystem = false;
    state = type;
    StorageService().setGlobalTheme(paletteToString(type));
  }

  void setFollowSystem(bool follow, {Brightness? currentBrightness}) {
    _isFollowingSystem = follow;
    if (follow) {
      StorageService().setGlobalTheme('system');
      state = paletteForBrightness(currentBrightness ?? systemBrightness);
    } else {
      StorageService().setGlobalTheme(paletteToString(state));
    }
  }

  void nextPalette() {
    _isFollowingSystem = false;
    const values = SoftPaletteType.values;
    final nextIndex = (values.indexOf(state) + 1) % values.length;
    state = values[nextIndex];
    StorageService().setGlobalTheme(paletteToString(state));
  }

  static SoftPaletteType? stringToPalette(String str) {
    switch (str.toLowerCase()) {
      case 'paper':
      case 'white':
        return SoftPaletteType.paper;
      case 'parchment':
        return SoftPaletteType.parchment;
      case 'beangreen':
      case 'green':
        return SoftPaletteType.beanGreen;
      case 'night':
      case 'dark':
        return SoftPaletteType.night;
      default:
        return null;
    }
  }

  static String paletteToString(SoftPaletteType type) {
    switch (type) {
      case SoftPaletteType.paper:
        return 'paper';
      case SoftPaletteType.parchment:
        return 'parchment';
      case SoftPaletteType.beanGreen:
        return 'beanGreen';
      case SoftPaletteType.night:
        return 'night';
    }
  }
}

final themeProvider =
    StateNotifierProvider<ThemeNotifier, SoftPaletteType>((ref) {
  return ThemeNotifier();
});

final softColorsProvider = Provider<SoftColors>((ref) {
  final paletteType = ref.watch(themeProvider);
  return SoftColors.fromType(paletteType);
});
