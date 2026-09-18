import 'package:flutter/material.dart';
import 'reader_page_theme.dart';

/// 排版设置抽屉 (typography_drawer.dart)
/// 覆盖字号、行距、背景色板、翻页模式等核心阅读参数
class TypographyDrawer extends StatelessWidget {
  final double fontSize;
  final double lineHeight;
  final ReaderThemeOption currentTheme;
  final PageTurnMode turnMode;
  final ValueChanged<double> onFontSizeChanged;
  final ValueChanged<double> onLineHeightChanged;
  final ValueChanged<ReaderThemeOption> onThemeChanged;
  final ValueChanged<PageTurnMode> onTurnModeChanged;

  const TypographyDrawer({
    super.key,
    required this.fontSize,
    required this.lineHeight,
    required this.currentTheme,
    required this.turnMode,
    required this.onFontSizeChanged,
    required this.onLineHeightChanged,
    required this.onThemeChanged,
    required this.onTurnModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = currentTheme.isDark;
    final accent = currentTheme.accent;

    // 行距三档基于当前字号推算；改字号后 lineHeight 不会自动跟着变，
    // 此前用"数值差 < 1.0"判定选中，导致三档经常一个都不高亮。
    // 改为永远高亮"最接近的一档"，让用户始终看得出当前处于哪一档。
    final spacingOptions = <double>[
      fontSize * 1.4,
      fontSize * 1.7,
      fontSize * 2.0,
    ];
    var nearestSpacingIndex = 0;
    var nearestSpacingDelta = double.infinity;
    for (var i = 0; i < spacingOptions.length; i++) {
      final delta = (spacingOptions[i] - lineHeight).abs();
      if (delta < nearestSpacingDelta) {
        nearestSpacingDelta = delta;
        nearestSpacingIndex = i;
      }
    }
    final cardBg = isDark ? const Color(0xFF282A2D) : const Color(0xFFF1F2F4);
    final textColor = isDark ? Colors.white : const Color(0xFF1F2329);
    final subTextColor = isDark ? Colors.white70 : const Color(0xFF646A73);

    return Container(
      padding: EdgeInsets.only(
        top: 20.0,
        left: 20.0,
        right: 20.0,
        bottom: MediaQuery.of(context).padding.bottom + 16.0,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2022) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            offset: const Offset(0, -4),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部拖动条指示
          Center(
            child: Container(
              width: 36.0,
              height: 4.0,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white24
                    : Colors.grey.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2.0),
              ),
            ),
          ),
          const SizedBox(height: 16.0),

          // 1. 字号调节 (A- / A+ 滑块)
          Row(
            children: [
              Text('字号',
                  style: TextStyle(
                      fontSize: 14.0,
                      fontWeight: FontWeight.w600,
                      color: textColor)),
              const SizedBox(width: 16.0),
              _buildRoundButton(
                icon: Icons.text_decrease,
                onTap: () {
                  if (fontSize > 12.0) onFontSizeChanged(fontSize - 1.0);
                },
                bgColor: cardBg,
                iconColor: textColor,
              ),
              Expanded(
                child: Slider(
                  value: fontSize,
                  min: 12.0,
                  max: 32.0,
                  divisions: 20,
                  label: '${fontSize.toInt()}px',
                  activeColor: accent,
                  inactiveColor: isDark ? Colors.white24 : null,
                  onChanged: onFontSizeChanged,
                ),
              ),
              _buildRoundButton(
                icon: Icons.text_increase,
                onTap: () {
                  if (fontSize < 32.0) onFontSizeChanged(fontSize + 1.0);
                },
                bgColor: cardBg,
                iconColor: textColor,
              ),
              const SizedBox(width: 8.0),
              SizedBox(
                width: 36.0,
                child: Text(
                  '${fontSize.toInt()}',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(fontWeight: FontWeight.bold, color: textColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12.0),

          // 2. 行距调节
          Row(
            children: [
              Text('行距',
                  style: TextStyle(
                      fontSize: 14.0,
                      fontWeight: FontWeight.w600,
                      color: textColor)),
              const SizedBox(width: 24.0),
              _buildLineSpacingChip(
                  label: '紧凑',
                  value: spacingOptions[0],
                  isSelected: nearestSpacingIndex == 0,
                  subTextColor: subTextColor,
                  isDark: isDark),
              const SizedBox(width: 12.0),
              _buildLineSpacingChip(
                  label: '舒适',
                  value: spacingOptions[1],
                  isSelected: nearestSpacingIndex == 1,
                  subTextColor: subTextColor,
                  isDark: isDark),
              const SizedBox(width: 12.0),
              _buildLineSpacingChip(
                  label: '宽松',
                  value: spacingOptions[2],
                  isSelected: nearestSpacingIndex == 2,
                  subTextColor: subTextColor,
                  isDark: isDark),
            ],
          ),
          const SizedBox(height: 16.0),

          // 3. 翻页模式选择（四等分自适应圆角胶囊，拒绝单行横向截断）
          Row(
            children: [
              Text('翻页',
                  style: TextStyle(
                      fontSize: 14.0,
                      fontWeight: FontWeight.w600,
                      color: textColor)),
              const SizedBox(width: 16.0),
              Expanded(
                child: Row(
                  children: PageTurnMode.values.map((mode) {
                    final isSelected = mode == turnMode;
                    final shortTitle = mode.title.replaceAll('翻页', '');
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2.5),
                        child: GestureDetector(
                          onTap: () => onTurnModeChanged(mode),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(vertical: 7.0),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? accent
                                  : (isDark
                                      ? Colors.white10
                                      : const Color(0xFFEBECEE)),
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                            child: Center(
                              child: Text(
                                shortTitle,
                                style: TextStyle(
                                  fontSize: 12.0,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark
                                          ? Colors.white70
                                          : const Color(0xFF333333)),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0),

          // 4. 背景色板调色盘
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ReaderThemeOption.presets.map((theme) {
              final isSelected = theme.id == currentTheme.id;
              return GestureDetector(
                onTap: () => onThemeChanged(theme),
                child: Container(
                  width: 44.0,
                  height: 44.0,
                  decoration: BoxDecoration(
                    color: theme.background,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? accent
                          : Colors.grey.withValues(alpha: 0.3),
                      width: isSelected ? 2.5 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        offset: const Offset(0, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: isSelected
                      ? Icon(Icons.check, size: 20, color: theme.textColor)
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRoundButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color bgColor,
    Color? iconColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36.0,
        height: 36.0,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: iconColor),
      ),
    );
  }

  Widget _buildLineSpacingChip({
    required bool isSelected,
    required String label,
    required double value,
    required Color subTextColor,
    required bool isDark,
  }) {
    final accent = currentTheme.accent;
    return GestureDetector(
      onTap: () => onLineHeightChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: isSelected
              ? accent.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(
            color: isSelected
                ? accent
                : (isDark
                    ? Colors.white24
                    : Colors.grey.withValues(alpha: 0.3)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.0,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? accent : subTextColor,
          ),
        ),
      ),
    );
  }
}
