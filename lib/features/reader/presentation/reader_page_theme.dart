import 'package:flutter/material.dart';

enum PageTurnMode {
  slide('平移翻页', '水平平滑滑动'),
  cover('覆盖翻页', '拟真叠页滑入'),
  curl('仿真卷曲', '3D 逼真翻折'),
  scroll('无缝流式', '垂直无限瀑布');

  final String title;
  final String desc;
  const PageTurnMode(this.title, this.desc);
}

class ReaderThemeOption {
  final String id;
  final String name;
  final Color background;
  final Color textColor;
  final Color subTextColor;
  final bool isDark;

  /// 阅读器强调色。此前阅读器内各控件硬编码 0xFF5B7FFF（蓝），
  /// 与应用整体的绿色主色冲突，进阅读器像换了一个 App。
  /// 浅色主题用与全局一致的 #07C160，深色主题用提亮版本保证暗底可读。
  final Color accent;

  const ReaderThemeOption({
    required this.id,
    required this.name,
    required this.background,
    required this.textColor,
    required this.subTextColor,
    required this.isDark,
    this.accent = const Color(0xFF236B58),
  });

  static const ReaderThemeOption paper = ReaderThemeOption(
    id: 'paper',
    name: '纸白',
    background: Color(0xFFFAFAFC),
    textColor: Color(0xFF1D1D1F),
    subTextColor: Color(0xFF6E6E73), // Apple 标杆二级灰
    isDark: false,
    accent: Color(0xFF236B58),
  );

  static const ReaderThemeOption cream = ReaderThemeOption(
    id: 'cream',
    name: '羊皮纸',
    background: Color(0xFFF8F4EC),
    textColor: Color(0xFF2C2219),
    subTextColor: Color(0xFF5A5043),
    isDark: false,
    accent: Color(0xFFB86820),
  );

  static const ReaderThemeOption green = ReaderThemeOption(
    id: 'green',
    name: '青润',
    background: Color(0xFFEEF5F1),
    textColor: Color(0xFF13261C),
    subTextColor: Color(0xFF4C6656),
    isDark: false,
    accent: Color(0xFF236B58),
  );

  static const ReaderThemeOption ink = ReaderThemeOption(
    id: 'ink',
    name: '深墨',
    background: Color(0xFF14171F),
    textColor: Color(0xFFECEEF5),
    subTextColor: Color(0xFF9096A8),
    isDark: true,
    accent: Color(0xFF38D9A9),
  );

  static const ReaderThemeOption night = ReaderThemeOption(
    id: 'night',
    name: '极夜',
    background: Color(0xFF000000), // Apple OLED 极致纯黑
    textColor: Color(0xFFE5E7EB),
    subTextColor: Color(0xFF888D9C),
    isDark: true,
    accent: Color(0xFF38D9A9),
  );

  static const ReaderThemeOption defaultTheme = paper;

  static const List<ReaderThemeOption> presets = [
    paper,
    cream,
    green,
    ink,
    night,
  ];
}
