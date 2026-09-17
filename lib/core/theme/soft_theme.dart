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

  /// 暖阳暖纸白 (Default - 对齐原型 --paper: #F5F4F1, --card: #FFFFFF)
  static const parchment = SoftColors(
    type: SoftPaletteType.parchment,
    background: Color(0xFFF5F4F1),
    surface: Color(0xFFEFEFEA),
    card: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF14161B),
    textSecondary: Color(0xFF6E7480),
    accent: Color(0xFF07C160),
    border: Color(0x1414161B),
    isDark: false,
  );

  /// 极简水墨白
  static const paper = SoftColors(
    type: SoftPaletteType.paper,
    background: Color(0xFFF7F7F7),
    surface: Color(0xFFF0F0F0),
    card: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF14161B),
    textSecondary: Color(0xFF6E7480),
    accent: Color(0xFF14161B),
    border: Color(0x1014161B),
    isDark: false,
  );

  /// 清润豆沙青
  static const beanGreen = SoftColors(
    type: SoftPaletteType.beanGreen,
    background: Color(0xFFEDF4ED),
    surface: Color(0xFFE3EDE3),
    card: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF162419),
    textSecondary: Color(0xFF5E7362),
    accent: Color(0xFF07C160),
    border: Color(0x1214161B),
    isDark: false,
  );

  /// 深空暗夜 OLED
  static const night = SoftColors(
    type: SoftPaletteType.night,
    background: Color(0xFF101014),
    surface: Color(0xFF18181F),
    card: Color(0xFF1F1F28),
    textPrimary: Color(0xFFE5E7EB),
    textSecondary: Color(0xFF9CA3AF),
    accent: Color(0xFF07C160),
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
  /// 经典 Modern Soft UI 双层环境光软阴影 (对齐原型 --sh-card: 0 2px 10px rgba(20,22,27,.05), 0 8px 24px rgba(20,22,27,.05))
  static List<BoxShadow> softShadows(SoftColors colors, {double elevation = 1.0}) {
    if (colors.isDark) {
      return [
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.03 * elevation),
          offset: const Offset(-1, -1),
          blurRadius: 4 * elevation,
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.45 * elevation),
          offset: Offset(0, 4 * elevation),
          blurRadius: 16 * elevation,
        ),
      ];
    }
    return [
      BoxShadow(
        color: const Color(0xFF14161B).withValues(alpha: 0.045 * elevation),
        offset: Offset(0, 2 * elevation),
        blurRadius: 10 * elevation,
      ),
      BoxShadow(
        color: const Color(0xFF14161B).withValues(alpha: 0.045 * elevation),
        offset: Offset(0, 8 * elevation),
        blurRadius: 24 * elevation,
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

  /// 悬浮毛玻璃胶囊底栏专用阴影 (Floating Dock Shadow)
  static List<BoxShadow> dockShadow(SoftColors colors) {
    if (colors.isDark) {
      return [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.5),
          offset: const Offset(0, 10),
          blurRadius: 24,
          spreadRadius: -4,
        ),
      ];
    }
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.08),
        offset: const Offset(0, 14),
        blurRadius: 28,
        spreadRadius: -6,
      ),
      BoxShadow(
        color: Colors.white.withValues(alpha: 0.8),
        offset: const Offset(0, -1),
        blurRadius: 6,
      ),
    ];
  }

  /// Squircle 连续曲率圆角常量
  static const double squircleCardRadius = 24.0;
  static const double squircleSubCardRadius = 16.0;
  static const double pillRadius = 9999.0;
}

/// SoftTheme InheritedWidget，支持通过 SoftTheme.of(context) 获取当前 SoftColors
class SoftTheme extends InheritedWidget {
  final SoftColors colors;

  const SoftTheme({
    super.key,
    required this.colors,
    required super.child,
  });

  static SoftColors of(BuildContext context) {
    final theme = context.dependOnInheritedWidgetOfExactType<SoftTheme>();
    return theme?.colors ?? SoftColors.parchment;
  }

  @override
  bool updateShouldNotify(SoftTheme oldWidget) => colors != oldWidget.colors;
}

