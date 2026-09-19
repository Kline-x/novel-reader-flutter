import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/reader/data/storage_service.dart';
import 'soft_theme.dart';

/// 全局主题与四大意境状态提供者 (theme_provider.dart)
class ThemeNotifier extends StateNotifier<SoftPaletteType>
    with WidgetsBindingObserver {
  ThemeNotifier() : super(SoftPaletteType.mistyJade) {
    WidgetsBinding.instance.addObserver(this);
    _loadInitialTheme();
  }

  bool _isFollowingSystem = false;
  bool get isFollowingSystem => _isFollowingSystem;

  /// 当前系统亮度
  static Brightness get systemBrightness =>
      PlatformDispatcher.instance.platformBrightness;

  /// 系统亮度对应的配色（浅色默认翠竹微雨，深色默认极夜星芒）
  static SoftPaletteType paletteForBrightness(Brightness b) =>
      b == Brightness.dark ? SoftPaletteType.darkJade : SoftPaletteType.mistyJade;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 系统深浅色切换时实时跟随
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
    const values = [
      SoftPaletteType.mistyJade,
      SoftPaletteType.warmAmber,
      SoftPaletteType.moonSilver,
      SoftPaletteType.darkJade,
      SoftPaletteType.paper,
    ];
    final nextIndex = (values.indexOf(state) + 1) % values.length;
    state = values[nextIndex];
    StorageService().setGlobalTheme(paletteToString(state));
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
}

class FollowSystemNotifier extends StateNotifier<bool> {
  FollowSystemNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    try {
      final themeStr = await StorageService().getGlobalTheme();
      state = themeStr == 'system';
    } catch (_) {}
  }

  void setFollow(bool follow) {
    state = follow;
  }
}

final isFollowingSystemProvider =
    StateNotifierProvider<FollowSystemNotifier, bool>((ref) {
  return FollowSystemNotifier();
});

final themeProvider =
    StateNotifierProvider<ThemeNotifier, SoftPaletteType>((ref) {
  return ThemeNotifier();
});

final softColorsProvider = Provider<SoftColors>((ref) {
  final paletteType = ref.watch(themeProvider);
  final isFollowing = ref.watch(isFollowingSystemProvider);

  final bool isDark;
  if (isFollowing) {
    isDark = ThemeNotifier.systemBrightness == Brightness.dark;
  } else {
    isDark = paletteType == SoftPaletteType.darkJade ||
        paletteType == SoftPaletteType.auroraSpace ||
        paletteType == SoftPaletteType.night;
  }

  return SoftColors.fromType(paletteType, isDark: isDark);
});
