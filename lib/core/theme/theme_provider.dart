import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/reader/data/storage_service.dart';
import 'soft_theme.dart';

/// 全局主题提供者 (theme_provider.dart)
class ThemeNotifier extends StateNotifier<SoftPaletteType> {
  ThemeNotifier() : super(SoftPaletteType.parchment) {
    _loadInitialTheme();
  }

  bool _isFollowingSystem = false;
  bool get isFollowingSystem => _isFollowingSystem;

  Future<void> _loadInitialTheme() async {
    try {
      final themeStr = await StorageService().getGlobalTheme();
      if (themeStr == 'system') {
        _isFollowingSystem = true;
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
      if (currentBrightness == Brightness.dark) {
        state = SoftPaletteType.night;
      } else {
        state = SoftPaletteType.parchment;
      }
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

final themeProvider = StateNotifierProvider<ThemeNotifier, SoftPaletteType>((ref) {
  return ThemeNotifier();
});

final softColorsProvider = Provider<SoftColors>((ref) {
  final paletteType = ref.watch(themeProvider);
  return SoftColors.fromType(paletteType);
});
