import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'soft_theme.dart';

/// 全局主题提供者 (theme_provider.dart)
class ThemeNotifier extends StateNotifier<SoftPaletteType> {
  ThemeNotifier() : super(SoftPaletteType.parchment);

  void setPalette(SoftPaletteType type) {
    state = type;
  }

  void nextPalette() {
    const values = SoftPaletteType.values;
    final nextIndex = (values.indexOf(state) + 1) % values.length;
    state = values[nextIndex];
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, SoftPaletteType>((ref) {
  return ThemeNotifier();
});

final softColorsProvider = Provider<SoftColors>((ref) {
  final paletteType = ref.watch(themeProvider);
  return SoftColors.fromType(paletteType);
});
