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

  const ReaderThemeOption({
    required this.id,
    required this.name,
    required this.background,
    required this.textColor,
    required this.subTextColor,
    required this.isDark,
  });

  static const ReaderThemeOption paper = ReaderThemeOption(
    id: 'paper',
    name: '纸白',
    background: Color(0xFFFFFDF7),
    textColor: Color(0xFF23262B),
    subTextColor: Color(0xFF6E7480),
    isDark: false,
  );

  static const ReaderThemeOption cream = ReaderThemeOption(
    id: 'cream',
    name: '米黄',
    background: Color(0xFFF6EFDF),
    textColor: Color(0xFF3B3225),
    subTextColor: Color(0xFF8A7F6D),
    isDark: false,
  );

  static const ReaderThemeOption ink = ReaderThemeOption(
    id: 'ink',
    name: '深墨',
    background: Color(0xFF1C1E26),
    textColor: Color(0xFFC9CCD8),
    subTextColor: Color(0xFF8A8FA0),
    isDark: true,
  );

  static const ReaderThemeOption night = ReaderThemeOption(
    id: 'night',
    name: '极夜',
    background: Color(0xFF0B0C10),
    textColor: Color(0xFFB8BCC9),
    subTextColor: Color(0xFF7C8190),
    isDark: true,
  );

  static const ReaderThemeOption defaultTheme = paper;

  static const List<ReaderThemeOption> presets = [
    paper,
    cream,
    ink,
    night,
  ];
}
