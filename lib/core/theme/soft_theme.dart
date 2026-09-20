import 'package:flutter/material.dart';

/// Modern Soft UI (Calm Tech) v3.0 顶级优雅旗舰版规范
/// 核心特征：苍岚/暖珀/幽兰/极夜四大意境、Squircle 连续曲率、玉质 Inner Rim 微高光、
/// 环境光流体微网格 (Ambient Mesh Glow)、双层低饱和漫射软阴影。

enum SoftPaletteType {
  mistyJade, // 翠竹微雨 · 宋瓷天青 (空蒙灵秀)
  warmAmber, // 暖杏流光 · 暖阳蜜蜡 (纸墨温润·安宁治愈)
  moonSilver, // 霁月清辉 · 天光月华 (澄澈净心·月霁微澜)
  darkJade, // 极夜星芒 · 纯粹暗夜 (Default 默认意境·钛墨零眩光·柔润护眼)
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
  /// 苍岚烟雨 · 日间 (Light) - 宋瓷天青 (Apple 级纯净通透玉白)
  static const mistyJadeLight = SoftColors(
    type: SoftPaletteType.mistyJade,
    title: '苍岚烟雨',
    subtitle: '宋瓷天青 · 雨后山色极度清朗',
    background: Color(0xFFF8FAF7),
    surface: Color(0xFFF0F5F2),
    card: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF111C16),
    textSecondary: Color(0xFF53675D),
    textTertiary: Color(0xFF8A9E94),
    accent: Color(0xFF236B58),
    accentSoft: Color(0x14236B58),
    accentGlow: Color(0x30236B58),
    border: Color(0x0A000000), // 0.5dp 极淡微羽化，告别显 low 的粗线
    borderSubtle: Color(0x08000000),
    borderInner: Color(0xE6FFFFFF),
    isDark: false,
    meshGlow1: Color(0x40A7F3D0),
    meshGlow2: Color(0x33FED7AA),
    meshGlow3: Color(0x38BAE6FD),
  );

  /// 苍岚烟雨 · 夜间 (Dark) - 墨玉深夜 (Apple OLED 极致纯黑)
  static const mistyJadeDark = SoftColors(
    type: SoftPaletteType.mistyJade,
    title: '苍岚烟雨',
    subtitle: '宋瓷天青 · 墨玉生机夜读深空',
    background: Color(0xFF000000),
    surface: Color(0xFF111814),
    card: Color(0xFF19221D),
    textPrimary: Color(0xFFF0F5F2),
    textSecondary: Color(0xFF8DA297),
    textTertiary: Color(0xFF5B7066),
    accent: Color(0xFF34D399),
    accentSoft: Color(0x1F34D399),
    accentGlow: Color(0x4734D399),
    border: Color(0x14FFFFFF),
    borderSubtle: Color(0x0DFFFFFF),
    borderInner: Color(0x0DFFFFFF),
    isDark: true,
    meshGlow1: Color(0x1A10B981),
    meshGlow2: Color(0x1414B8A6),
    meshGlow3: Color(0x146366F1),
  );

  // ===================== 2. 暮色暖珀 (twilightAmber / warmAmber) =====================
  /// 暮色暖珀 · 日间 (Light) - 焦糖蜜金 (纯净暖阳白，彻底告别发灰浑浊)
  static const twilightAmberLight = SoftColors(
    type: SoftPaletteType.twilightAmber,
    title: '暮色暖珀',
    subtitle: '焦糖蜜金 · 暖阳宣纸温润明亮',
    background: Color(0xFFFAF7F2),
    surface: Color(0xFFF4EFE9),
    card: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF1F1813),
    textSecondary: Color(0xFF6B5D52),
    textTertiary: Color(0xFF9E8F84),
    accent: Color(0xFFB86820),
    accentSoft: Color(0x14B86820),
    accentGlow: Color(0x30B86820),
    border: Color(0x0A000000),
    borderSubtle: Color(0x08000000),
    borderInner: Color(0xF2FFFFFF),
    isDark: false,
    meshGlow1: Color(0x40FED7AA),
    meshGlow2: Color(0x33FDE68A),
    meshGlow3: Color(0x33EDE9FE),
  );

  /// 暮色暖珀 · 夜间 (Dark) - 炭火微烛 (Apple OLED 纯黑)
  static const twilightAmberDark = SoftColors(
    type: SoftPaletteType.twilightAmber,
    title: '暮色暖珀',
    subtitle: '焦糖蜜金 · 炭火微烛夜读安眠',
    background: Color(0xFF000000),
    surface: Color(0xFF171310),
    card: Color(0xFF221C17),
    textPrimary: Color(0xFFF5EFEB),
    textSecondary: Color(0xFFA8988C),
    textTertiary: Color(0xFF6E6055),
    accent: Color(0xFFE89A4B),
    accentSoft: Color(0x24E89A4B),
    accentGlow: Color(0x4DE89A4B),
    border: Color(0x14FFFFFF),
    borderSubtle: Color(0x0DFFFFFF),
    borderInner: Color(0x0DFFFFFF),
    isDark: true,
    meshGlow1: Color(0x1AD97706),
    meshGlow2: Color(0x14B45309),
    meshGlow3: Color(0x0FF472B6),
  );

  // ===================== 3. 紫陌幽兰 (violetOrchid / moonSilver) =====================
  /// 紫陌幽兰 · 日间 (Light) - 典雅丝帛 (通透浅月光白)
  static const violetOrchidLight = SoftColors(
    type: SoftPaletteType.violetOrchid,
    title: '紫陌幽兰',
    subtitle: '幽兰丁香 · 宣州丝帛墨卷风度',
    background: Color(0xFFF9F8FC),
    surface: Color(0xFFF2EFF7),
    card: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF1A1624),
    textSecondary: Color(0xFF655C75),
    textTertiary: Color(0xFF988FA8),
    accent: Color(0xFF6D599A),
    accentSoft: Color(0x146D599A),
    accentGlow: Color(0x306D599A),
    border: Color(0x0A000000),
    borderSubtle: Color(0x08000000),
    borderInner: Color(0xF2FFFFFF),
    isDark: false,
    meshGlow1: Color(0x40DDD6FE),
    meshGlow2: Color(0x33BAE6FD),
    meshGlow3: Color(0x30FECDD3),
  );

  /// 紫陌幽兰 · 夜间 (Dark) - 静夜紫罗兰 (Apple OLED 纯黑)
  static const violetOrchidDark = SoftColors(
    type: SoftPaletteType.violetOrchid,
    title: '紫陌幽兰',
    subtitle: '幽兰丁香 · 静夜紫罗兰澄澈深邃',
    background: Color(0xFF000000),
    surface: Color(0xFF15121F),
    card: Color(0xFF1E1A2C),
    textPrimary: Color(0xFFF3EFFF),
    textSecondary: Color(0xFFA299B5),
    textTertiary: Color(0xFF6C6380),
    accent: Color(0xFFA78BFA),
    accentSoft: Color(0x24A78BFA),
    accentGlow: Color(0x4DA78BFA),
    border: Color(0x14FFFFFF),
    borderSubtle: Color(0x0DFFFFFF),
    borderInner: Color(0x0DFFFFFF),
    isDark: true,
    meshGlow1: Color(0x1F8B5CF6),
    meshGlow2: Color(0x146366F1),
    meshGlow3: Color(0x0FEC4899),
  );

  // ===================== 4. 极夜星芒 (auroraSpace / darkJade) =====================
  /// 极夜星芒 · 日间 (Light) - 钛金冰川，冷钢青灰
  ///
  /// 原先这套用的是 #0D9488 青碧 + #F8F9FA 微绿白，和「翠竹微雨」
  /// 同属绿松色系、底色 RGB 只差 0/1/3，两个意境肉眼分不出。
  /// 现按它自己的名字走冷色：背景带蓝灰调，强调色换成钢青，
  /// 与绿（翠竹微雨）/ 琥珀（暖杏流光）/ 紫（霁月清辉）各占一个色相。
  static const auroraSpaceLight = SoftColors(
    type: SoftPaletteType.auroraSpace,
    title: '极夜星芒',
    subtitle: '钛金冰川 · 冷钢极简',
    background: Color(0xFFF5F7FA),
    surface: Color(0xFFE9EDF2),
    card: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF0F1922),
    textSecondary: Color(0xFF47566B),
    textTertiary: Color(0xFF94A3B8),
    accent: Color(0xFF2E6FA8),
    accentSoft: Color(0x142E6FA8),
    accentGlow: Color(0x302E6FA8),
    border: Color(0x0A000F1A),
    borderSubtle: Color(0x08000F1A),
    borderInner: Color(0xF2FFFFFF),
    isDark: false,
    meshGlow1: Color(0x38D6E6F5),
    meshGlow2: Color(0x2EDCE4F0),
    meshGlow3: Color(0x2EE6EAF2),
  );

  /// 极夜星芒 · 夜间 (Dark) - OLED 纯黑极光，冰蓝
  ///
  /// 原先卡片 #131A16 与「翠竹微雨·夜」的 #111814 相差仅 RGB 6，
  /// 强调色 #38D9A9 与其 #34D399 相差 26，正文色完全相同——
  /// 夜间两套几乎是同一个皮肤。现改为中性炭底 + 冰蓝极光，
  /// 背景用纯黑吃满 OLED 熄屏像素。
  static const auroraSpaceDark = SoftColors(
    type: SoftPaletteType.auroraSpace,
    title: '极夜星芒',
    subtitle: '纯黑极光 · 冰蓝深空',
    background: Color(0xFF000000),
    surface: Color(0xFF12161A),
    card: Color(0xFF1A2027),
    textPrimary: Color(0xFFEDF2F7),
    textSecondary: Color(0xFF93A4B8),
    textTertiary: Color(0xFF5E7186),
    accent: Color(0xFF4CC2FF),
    accentSoft: Color(0x1F4CC2FF),
    accentGlow: Color(0x474CC2FF),
    border: Color(0x14FFFFFF),
    borderSubtle: Color(0x0DFFFFFF),
    borderInner: Color(0x0DFFFFFF),
    isDark: true,
    meshGlow1: Color(0x1A2E90D9),
    meshGlow2: Color(0x14386FA8),
    meshGlow3: Color(0x14475B78),
  );

  // 兼容老引用
  static const auroraSpace = auroraSpaceDark;

  // ===================== 5. 水墨玄素 (paper) =====================
  static const paper = SoftColors(
    type: SoftPaletteType.paper,
    title: '水墨玄素',
    subtitle: '水墨纯粹 · 纸白黛墨专注于文',
    background: Color(0xFFF8F9FA),
    surface: Color(0xFFF1F3F5),
    card: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF14161B),
    textSecondary: Color(0xFF6E7480),
    textTertiary: Color(0xFF9CA3AF),
    accent: Color(0xFF17211C),
    accentSoft: Color(0x1417211C),
    accentGlow: Color(0x2817211C),
    border: Color(0x0A000000),
    borderSubtle: Color(0x08000000),
    borderInner: Color(0xF2FFFFFF),
    isDark: false,
    meshGlow1: Color(0x24000000),
    meshGlow2: Color(0x18000000),
    meshGlow3: Color(0x18000000),
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
  static const darkJade = auroraSpaceDark;

  // 向前兼容老配置映射
  static const parchment = twilightAmber;
  static const beanGreen = mistyJade;
  static const night = auroraSpaceDark;

  /// 根据主题类型和深浅模式解析对应色彩
  static SoftColors fromType(SoftPaletteType type, {bool? isDark}) {
    switch (type) {
      case SoftPaletteType.mistyJade:
      case SoftPaletteType.beanGreen:
        return (isDark ?? false) ? mistyJadeDark : mistyJadeLight;
      case SoftPaletteType.twilightAmber:
      case SoftPaletteType.warmAmber:
      case SoftPaletteType.parchment:
        return (isDark ?? false) ? twilightAmberDark : twilightAmberLight;
      case SoftPaletteType.violetOrchid:
      case SoftPaletteType.moonSilver:
        return (isDark ?? false) ? violetOrchidDark : violetOrchidLight;
      case SoftPaletteType.auroraSpace:
      case SoftPaletteType.darkJade:
      case SoftPaletteType.night:
        return (isDark ?? true) ? auroraSpaceDark : auroraSpaceLight;
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
    auroraSpaceLight,
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
