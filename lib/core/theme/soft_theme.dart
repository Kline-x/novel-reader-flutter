import 'package:flutter/material.dart';

/// Modern Soft UI (Calm Tech) v3.0 顶级优雅旗舰版规范
/// 核心特征：苍岚/暖珀/幽兰/极夜四大意境、Squircle 连续曲率、玉质 Inner Rim 微高光、
/// 环境光流体微网格 (Ambient Mesh Glow)、双层低饱和漫射软阴影。

enum SoftPaletteType {
  mistyJade, // 翠竹微雨 · 宋瓷天青 (Default 旗舰首选·空蒙灵秀)
  warmAmber, // 暖杏流光 · 暖阳蜜蜡 (纸墨温润·安宁治愈)
  moonSilver, // 霁月清辉 · 天光月华 (澄澈净心·月霁微澜)
  darkJade, // 极夜星芒 · 纯粹暗夜 (钛墨零眩光·柔润护眼)
  paper, // 水墨玄素 · 极简墨水屏 (类 Kindle 纯粹阅读)

  // --- 向前兼容别名 ---
  twilightAmber, // 兼容老版本 -> warmAmber
  violetOrchid, // 兼容老版本 -> moonSilver
  auroraSpace, // 兼容老版本 -> darkJade
  parchment, // 兼容老版本：暖阳羊皮纸 -> 映射至 warmAmber
  beanGreen, // 兼容老版本：清润豆沙青 -> 映射至 mistyJade
  night, // 兼容老版本：深空暗夜 -> 映射至 darkJade
}

class SoftColors {
  final SoftPaletteType type;
  final String title;
  final String subtitle;
  final Color background;
  final Color surface;
  final Color card;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color accent;
  final Color accentSoft;
  final Color accentGlow;
  final Color border;
  final Color borderSubtle;
  final Color borderInner;
  final bool isDark;

  // 环境光流体微网格三原色 (Ambient Mesh Glow)
  final Color meshGlow1;
  final Color meshGlow2;
  final Color meshGlow3;

  const SoftColors({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.background,
    required this.surface,
    required this.card,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.accentSoft,
    required this.accentGlow,
    required this.border,
    required this.borderSubtle,
    required this.borderInner,
    required this.isDark,
    required this.meshGlow1,
    required this.meshGlow2,
    required this.meshGlow3,
  });

  // ===================== 1. 苍岚烟雨 (mistyJade) =====================
  /// 苍岚烟雨 · 日间 (Light) - 宋瓷天青
  static const mistyJadeLight = SoftColors(
    type: SoftPaletteType.mistyJade,
    title: '苍岚烟雨',
    subtitle: '宋瓷天青 · 雨后山色极度静谧',
    background: Color(0xFFF8FAF7),
    surface: Color(0xFFEEF3EE),
    card: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF17211C),
    textSecondary: Color(0xFF586B62),
    textTertiary: Color(0xFF92A39B),
    accent: Color(0xFF236B58),
    accentSoft: Color(0x17236B58), // ~9% 柔青
    accentGlow: Color(0x38236B58), // ~22% 微晕
    border: Color(0x0D17211C),
    borderSubtle: Color(0x0D17211C), // rgba(23, 33, 28, 0.05)
    borderInner: Color(0xE6FFFFFF), // 90% 白玉内高光 (rgba(255, 255, 255, 0.9))
    isDark: false,
    meshGlow1: Color(0x59BBF7D0),
    meshGlow2: Color(0x47FED7AA),
    meshGlow3: Color(0x4DBAE6FD),
  );

  /// 苍岚烟雨 · 夜间 (Dark) - 墨玉深夜
  static const mistyJadeDark = SoftColors(
    type: SoftPaletteType.mistyJade,
    title: '苍岚烟雨',
    subtitle: '宋瓷天青 · 墨玉生机夜读深空',
    background: Color(0xFF0C110E),
    surface: Color(0xFF141C18),
    card: Color(0xFF1B2420),
    textPrimary: Color(0xFFE2ECE7),
    textSecondary: Color(0xFF8DA297),
    textTertiary: Color(0xFF5B7066),
    accent: Color(0xFF38D9A9),
    accentSoft: Color(0x1F38D9A9), // ~12%
    accentGlow: Color(0x4738D9A9), // ~28%
    border: Color(0x1AFFFFFF),
    borderSubtle: Color(0x0FFFFFFF), // 6%
    borderInner: Color(0x0DFFFFFF), // 5%
    isDark: true,
    meshGlow1: Color(0x1A10B981),
    meshGlow2: Color(0x1414B8A6),
    meshGlow3: Color(0x146366F1),
  );

  // ===================== 2. 暮色暖珀 (twilightAmber / warmAmber) =====================
  /// 暮色暖珀 · 日间 (Light) - 焦糖蜜金
  static const twilightAmberLight = SoftColors(
    type: SoftPaletteType.twilightAmber,
    title: '暮色暖珀',
    subtitle: '焦糖蜜金 · 古典羊皮纸温意',
    background: Color(0xFFFAF7F2),
    surface: Color(0xFFF2EDE4),
    card: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF231B15),
    textSecondary: Color(0xFF736458),
    textTertiary: Color(0xFF9E8E82),
    accent: Color(0xFFB86820),
    accentSoft: Color(0x17B86820), // ~9%
    accentGlow: Color(0x38B86820), // ~22%
    border: Color(0x0D231B15),
    borderSubtle: Color(0x0D231B15), // rgba(35, 27, 21, 0.05)
    borderInner: Color(0xE6FFFFFF), // 90% 白玉内高光
    isDark: false,
    meshGlow1: Color(0x59FED7AA),
    meshGlow2: Color(0x40FDE68A),
    meshGlow3: Color(0x40EDE9FE),
  );

  /// 暮色暖珀 · 夜间 (Dark) - 炭火微烛
  static const twilightAmberDark = SoftColors(
    type: SoftPaletteType.twilightAmber,
    title: '暮色暖珀',
    subtitle: '焦糖蜜金 · 炭火微烛夜读安眠',
    background: Color(0xFF120F0D),
    surface: Color(0xFF1C1814),
    card: Color(0xFF26201B),
    textPrimary: Color(0xFFEFE8E2),
    textSecondary: Color(0xFFA8988C),
    textTertiary: Color(0xFF6E6055),
    accent: Color(0xFFEAA055),
    accentSoft: Color(0x24EAA055), // ~14%
    accentGlow: Color(0x4DEAA055), // ~30%
    border: Color(0x1AFFFFFF),
    borderSubtle: Color(0x0FFFFFFF),
    borderInner: Color(0x0DFFFFFF),
    isDark: true,
    meshGlow1: Color(0x1AD97706),
    meshGlow2: Color(0x14B45309),
    meshGlow3: Color(0x0FF472B6),
  );

  // ===================== 3. 紫陌幽兰 (violetOrchid / moonSilver) =====================
  /// 紫陌幽兰 · 日间 (Light) - 典雅丝帛
  static const violetOrchidLight = SoftColors(
    type: SoftPaletteType.violetOrchid,
    title: '紫陌幽兰',
    subtitle: '幽兰丁香 · 宣州丝帛墨卷风度',
    background: Color(0xFFF9F8FC),
    surface: Color(0xFFF0EEF7),
    card: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF1D1926),
    textSecondary: Color(0xFF635C73),
    textTertiary: Color(0xFF9790A6),
    accent: Color(0xFF6D599A),
    accentSoft: Color(0x176D599A), // ~9%
    accentGlow: Color(0x386D599A), // ~22%
    border: Color(0x0D1D1926),
    borderSubtle: Color(0x0D1D1926), // 5%
    borderInner: Color(0xE6FFFFFF), // 90%
    isDark: false,
    meshGlow1: Color(0x59DDD6FE),
    meshGlow2: Color(0x40BAE6FD),
    meshGlow3: Color(0x38FECDD3),
  );

  /// 紫陌幽兰 · 夜间 (Dark) - 静夜紫罗兰
  static const violetOrchidDark = SoftColors(
    type: SoftPaletteType.violetOrchid,
    title: '紫陌幽兰',
    subtitle: '幽兰丁香 · 静夜紫罗兰澄澈深邃',
    background: Color(0xFF100E16),
    surface: Color(0xFF1A1724),
    card: Color(0xFF231F30),
    textPrimary: Color(0xFFECE8F5),
    textSecondary: Color(0xFFA299B5),
    textTertiary: Color(0xFF6C6380),
    accent: Color(0xFFA78BFA),
    accentSoft: Color(0x24A78BFA), // ~14%
    accentGlow: Color(0x4DA78BFA), // ~30%
    border: Color(0x1AFFFFFF),
    borderSubtle: Color(0x0FFFFFFF),
    borderInner: Color(0x0DFFFFFF),
    isDark: true,
    meshGlow1: Color(0x1F8B5CF6),
    meshGlow2: Color(0x146366F1),
    meshGlow3: Color(0x0FEC4899),
  );

  // ===================== 4. 极夜星芒 (auroraSpace / darkJade) =====================
  /// 极夜星芒 · 纯粹暗夜 (OLED 深空)
  static const auroraSpace = SoftColors(
    type: SoftPaletteType.auroraSpace,
    title: '极夜星芒',
    subtitle: '纯黑极光 · 钛墨深空纯粹沉浸',
    background: Color(0xFF0C110E),
    surface: Color(0xFF141C18),
    card: Color(0xFF1B2420),
    textPrimary: Color(0xFFE2ECE7),
    textSecondary: Color(0xFF8DA297),
    textTertiary: Color(0xFF5B7066),
    accent: Color(0xFF38D9A9),
    accentSoft: Color(0x1F38D9A9), // ~12%
    accentGlow: Color(0x4738D9A9), // ~28%
    border: Color(0x1AFFFFFF),
    borderSubtle: Color(0x0FFFFFFF),
    borderInner: Color(0x0DFFFFFF), // 5%
    isDark: true,
    meshGlow1: Color(0x1A10B981),
    meshGlow2: Color(0x1414B8A6),
    meshGlow3: Color(0x146366F1),
  );

  // ===================== 5. 水墨玄素 (paper) =====================
  static const paper = SoftColors(
    type: SoftPaletteType.paper,
    title: '水墨玄素',
    subtitle: '水墨纯粹 · 纸白黛墨专注于文',
    background: Color(0xFFF7F7F7),
    surface: Color(0xFFEFEFEF),
    card: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF14161B),
    textSecondary: Color(0xFF6E7480),
    textTertiary: Color(0xFF9CA3AF),
    accent: Color(0xFF17211C),
    accentSoft: Color(0x1417211C),
    accentGlow: Color(0x2817211C),
    border: Color(0x0F14161B),
    borderSubtle: Color(0x1A14161B),
    borderInner: Color(0xE6FFFFFF),
    isDark: false,
    meshGlow1: Color(0x2E000000),
    meshGlow2: Color(0x1F000000),
    meshGlow3: Color(0x1F000000),
  );

  // 默认静态常量映射
  static const mistyJade = mistyJadeLight;
  static const twilightAmber = twilightAmberLight;
  static const warmAmber = twilightAmberLight;
  static const warmAmberLight = twilightAmberLight;
  static const warmAmberDark = twilightAmberDark;
  static const violetOrchid = violetOrchidLight;
  static const moonSilver = violetOrchidLight;
  static const moonSilverLight = violetOrchidLight;
  static const moonSilverDark = violetOrchidDark;
  static const darkJade = auroraSpace;

  // 向前兼容老配置映射
  static const parchment = twilightAmber;
  static const beanGreen = mistyJade;
  static const night = auroraSpace;

  /// 根据主题类型和深浅模式解析对应色彩
  static SoftColors fromType(SoftPaletteType type, {bool? isDark}) {
    final effectiveDark = isDark ?? false;
    switch (type) {
      case SoftPaletteType.mistyJade:
      case SoftPaletteType.beanGreen:
        return effectiveDark ? mistyJadeDark : mistyJadeLight;
      case SoftPaletteType.twilightAmber:
      case SoftPaletteType.warmAmber:
      case SoftPaletteType.parchment:
        return effectiveDark ? twilightAmberDark : twilightAmberLight;
      case SoftPaletteType.violetOrchid:
      case SoftPaletteType.moonSilver:
        return effectiveDark ? violetOrchidDark : violetOrchidLight;
      case SoftPaletteType.auroraSpace:
      case SoftPaletteType.darkJade:
      case SoftPaletteType.night:
        return auroraSpace;
      case SoftPaletteType.paper:
        return paper;
    }
  }

  /// 切换深浅模式
  SoftColors withBrightness({required bool dark}) {
    return fromType(type, isDark: dark);
  }

  /// 官方支持的四大主力意境
  static const List<SoftColors> primaryPresets = [
    mistyJadeLight,
    warmAmberLight,
    moonSilverLight,
    darkJade,
  ];
}

class SoftDecorations {
  /// 升级版 Modern Soft UI 连续曲率玉质软阴影
  /// 融入微外漫射 + 内轮廓高光，触感温润无边界
  static List<BoxShadow> softShadows(
    SoftColors colors, {
    double elevation = 1.0,
  }) {
    if (colors.isDark) {
      return [
        BoxShadow(
          color: colors.borderInner,
          offset: const Offset(0, 1),
          blurRadius: 1,
          spreadRadius: 0.5,
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.45 * elevation),
          offset: Offset(0, 4 * elevation),
          blurRadius: 18 * elevation,
          spreadRadius: -2,
        ),
      ];
    }
    return [
      // 内微高光层 (Inner Rim Light Simulation: inset 0 1px 1px)
      BoxShadow(
        color: colors.borderInner,
        offset: const Offset(0, 1),
        blurRadius: 1,
        spreadRadius: 0.5,
      ),
      // 原型 --sh-card: 0 4px 20px -2px rgba(0,0,0,0.05), 0 2px 6px -1px rgba(0,0,0,0.02)
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.025 * elevation),
        offset: Offset(0, 2 * elevation),
        blurRadius: 6 * elevation,
        spreadRadius: -1,
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.05 * elevation),
        offset: Offset(0, 4 * elevation),
        blurRadius: 20 * elevation,
        spreadRadius: -2,
      ),
    ];
  }

  /// 软拟态凹陷阴影（用于 Switch 轨道、搜索栏、输入框）
  static List<BoxShadow> insetShadows(SoftColors colors) {
    if (colors.isDark) {
      return [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.5),
          offset: const Offset(1, 1),
          blurRadius: 3,
        ),
      ];
    }
    return [
      BoxShadow(
        color: colors.textPrimary.withValues(alpha: 0.06),
        offset: const Offset(1, 1),
        blurRadius: 3,
      ),
      BoxShadow(
        color: Colors.white.withValues(alpha: 0.8),
        offset: const Offset(-1, -1),
        blurRadius: 3,
      ),
    ];
  }

  /// 悬浮毛玻璃胶囊底栏专用高定阴影 (Sublime Dock Shadow) 1:1 像素级对齐原型
  /// 原型：inset 0 1px 1.5px 0 var(--border-inner), 0 16px 36px -4px rgba(0,0,0,0.12), 0 4px 12px -2px rgba(0,0,0,0.06)
  static List<BoxShadow> dockShadow(SoftColors colors) {
    if (colors.isDark) {
      return [
        BoxShadow(
          color: colors.borderInner,
          offset: const Offset(0, 1),
          blurRadius: 1.5,
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.55),
          offset: const Offset(0, 16),
          blurRadius: 36,
          spreadRadius: -4,
        ),
      ];
    }
    return [
      BoxShadow(
        color: colors.borderInner,
        offset: const Offset(0, 1),
        blurRadius: 1.5,
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.06),
        offset: const Offset(0, 4),
        blurRadius: 12,
        spreadRadius: -2,
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.12),
        offset: const Offset(0, 16),
        blurRadius: 36,
        spreadRadius: -4,
      ),
    ];
  }

  /// Squircle 连续曲率圆角常量（全面升级为 26px 旗舰曲率）
  static const double squircleCardRadius = 26.0;
  static const double squircleSubCardRadius = 18.0;
  static const double pillRadius = 9999.0;

  /// Modern Soft UI 强调色微光漫射阴影
  static List<BoxShadow> glowShadows(Color accentColor, {double radius = 10.0}) {
    return [
      BoxShadow(
        color: accentColor.withValues(alpha: 0.28),
        blurRadius: radius,
        offset: const Offset(0, 3),
      ),
    ];
  }
}

/// SoftTheme InheritedWidget
class SoftTheme extends InheritedWidget {
  final SoftColors colors;

  const SoftTheme({
    super.key,
    required this.colors,
    required super.child,
  });

  static SoftColors of(BuildContext context) {
    final theme = context.dependOnInheritedWidgetOfExactType<SoftTheme>();
    return theme?.colors ?? SoftColors.mistyJade;
  }

  @override
  bool updateShouldNotify(SoftTheme oldWidget) => colors != oldWidget.colors;
}
