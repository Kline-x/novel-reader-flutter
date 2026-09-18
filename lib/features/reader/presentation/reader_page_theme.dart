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
    this.accent = const Color(0xFF07C160),
  });

  static const ReaderThemeOption paper = ReaderThemeOption(
    id: 'paper',
    name: '纸白',
    background: Color(0xFFFFFDF7),
    textColor: Color(0xFF23262B),
    subTextColor: Color(0xFF555B66), // WCAG 4.5:1 高对比度灰阶
    isDark: false,
  );

  static const ReaderThemeOption cream = ReaderThemeOption(
    id: 'cream',
    name: '羊皮纸',
    background: Color(0xFFF6EFDF),
    textColor: Color(0xFF3B3225),
    subTextColor: Color(0xFF5A5043), // 调校为深暖褐灰，对比度 > 5.0:1
    isDark: false,
  );

  static const ReaderThemeOption green = ReaderThemeOption(
    id: 'green',
    name: '青润',
    background: Color(0xFFEBF2EB),
    textColor: Color(0xFF1B2E1E),
    subTextColor: Color(0xFF3D5341), // 调校为墨绿深色次级文本，清晰可辨
    isDark: false,
  );

  static const ReaderThemeOption ink = ReaderThemeOption(
    id: 'ink',
    name: '深墨',
    background: Color(0xFF1C1E26),
    textColor: Color(0xFFC9CCD8),
    subTextColor: Color(0xFF9096A8),
    isDark: true,
    accent: Color(0xFF2BD97C),
  );

  static const ReaderThemeOption night = ReaderThemeOption(
    id: 'night',
    name: '极夜',
    background: Color(0xFF0B0C10),
    textColor: Color(0xFFB8BCC9),
    subTextColor: Color(0xFF888D9C),
    isDark: true,
    accent: Color(0xFF2BD97C),
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
