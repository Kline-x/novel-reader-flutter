import 'package:flutter/material.dart';

/// Modern Soft UI (Calm Tech) 主题与配色规范
/// 核心特征：柔和深度、连续曲率 Squircle、双层环境微阴影、毛玻璃悬浮

enum SoftPaletteType {
  parchment, // 暖阳羊皮纸 (经典护眼)
  paper,     // 极简水墨白
  beanGreen, // 清润豆沙青 (深度护眼)
  night,     // 深空暗夜 OLED (低功耗)
}

class SoftColors {
  final SoftPaletteType type;
  final Color background;
  final Color surface;
  final Color card;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final Color border;
  final bool isDark;

  const SoftColors({
    required this.type,
    required this.background,
    required this.surface,
    required this.card,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.border,
    required this.isDark,
  });

  /// 暖阳羊皮纸 (Default)
  static const parchment = SoftColors(
    type: SoftPaletteType.parchment,
    background: Color(0xFFF4F1EA),
    surface: Color(0xFFEBE6DC),
    card: Color(0xFFEDE9DF),
    textPrimary: Color(0xFF2D2B28),
    textSecondary: Color(0xFF8C827A),
    accent: Color(0xFFC5A059),
    border: Color(0x18000000),
    isDark: false,
  );

  /// 极简水墨白
  static const paper = SoftColors(
    type: SoftPaletteType.paper,
    background: Color(0xFFFAFAFA),
    surface: Color(0xFFF0F0F0),
    card: Color(0xFFF5F5F5),
    textPrimary: Color(0xFF1A1A1A),
    textSecondary: Color(0xFF757575),
    accent: Color(0xFF333333),
    border: Color(0x12000000),
    isDark: false,
  );

  /// 清润豆沙青
  static const beanGreen = SoftColors(
    type: SoftPaletteType.beanGreen,
    background: Color(0xFFEAF1EA),
    surface: Color(0xFFDEE8DE),
    card: Color(0xFFE2EBE2),
    textPrimary: Color(0xFF1E2D24),
    textSecondary: Color(0xFF6A7B6E),
    accent: Color(0xFF4E8752),
    border: Color(0x15000000),
    isDark: false,
  );

  /// 深空暗夜 OLED
  static const night = SoftColors(
    type: SoftPaletteType.night,
    background: Color(0xFF111418),
    surface: Color(0xFF181C22),
    card: Color(0xFF1D222A),
    textPrimary: Color(0xFFD0D3D6),
    textSecondary: Color(0xFF626B76),
    accent: Color(0xFFE5B76C),
    border: Color(0x1AFFFFFF),
    isDark: true,
  );

  static SoftColors fromType(SoftPaletteType type) {
    switch (type) {
      case SoftPaletteType.parchment:
        return parchment;
      case SoftPaletteType.paper:
        return paper;
      case SoftPaletteType.beanGreen:
        return beanGreen;
      case SoftPaletteType.night:
        return night;
    }
  }
}

class SoftDecorations {
  /// 经典 Modern Soft UI 双层环境光软阴影 (Soft Depth)
  static List<BoxShadow> softShadows(SoftColors colors, {double elevation = 1.0}) {
    if (colors.isDark) {
      return [
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.03 * elevation),
          offset: const Offset(-2, -2),
          blurRadius: 6 * elevation,
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.45 * elevation),
          offset: Offset(3 * elevation, 4 * elevation),
          blurRadius: 10 * elevation,
        ),
      ];
    }
    return [
      BoxShadow(
        color: Colors.white.withValues(alpha: 0.9),
        offset: Offset(-3 * elevation, -3 * elevation),
        blurRadius: 8 * elevation,
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.06 * elevation),
        offset: Offset(4 * elevation, 5 * elevation),
        blurRadius: 12 * elevation,
      ),
    ];
  }

  /// 软拟态凹陷阴影（用于 Switch 轨道、输入框）
  static List<BoxShadow> insetShadows(SoftColors colors) {
    if (colors.isDark) {
      return [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.6),
          offset: const Offset(2, 2),
          blurRadius: 4,
        ),
      ];
    }
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.08),
        offset: const Offset(2, 2),
        blurRadius: 4,
      ),
      BoxShadow(
        color: Colors.white.withValues(alpha: 0.8),
        offset: const Offset(-2, -2),
        blurRadius: 4,
      ),
    ];
  }
}
