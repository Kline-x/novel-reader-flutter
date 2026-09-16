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
    name: '复古羊皮',
    background: Color(0xFFF6F1E7),
    textColor: Color(0xFF2C2416),
    subTextColor: Color(0xFF8C8070),
    isDark: false,
  );

  static const ReaderThemeOption defaultTheme = paper;

  static const List<ReaderThemeOption> presets = [
    paper,
    ReaderThemeOption(
      id: 'white',
      name: '柔和白昼',
      background: Color(0xFFF9F9FA),
      textColor: Color(0xFF1D1E20),
      subTextColor: Color(0xFF86888D),
      isDark: false,
    ),
    ReaderThemeOption(
      id: 'green',
      name: '淡雅护眼',
      background: Color(0xFFEBF1E8),
      textColor: Color(0xFF223123),
      subTextColor: Color(0xFF7A8B7B),
      isDark: false,
    ),
    ReaderThemeOption(
      id: 'gray',
      name: '深空雅灰',
      background: Color(0xFF242628),
      textColor: Color(0xFFD6D7D9),
      subTextColor: Color(0xFF7D8086),
      isDark: true,
    ),
    ReaderThemeOption(
      id: 'oled',
      name: '纯黑极夜',
      background: Color(0xFF000000),
      textColor: Color(0xFFA6A8AB),
      subTextColor: Color(0xFF5A5C61),
      isDark: true,
    ),
  ];
}
