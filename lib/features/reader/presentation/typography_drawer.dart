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
    final cardBg = isDark ? const Color(0xFF282A2D) : const Color(0xFFF1F2F4);

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
                color: Colors.grey.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2.0),
              ),
            ),
          ),
          const SizedBox(height: 16.0),

          // 1. 字号调节 (A- / A+ 滑块)
          Row(
            children: [
              const Text('字号', style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600)),
              const SizedBox(width: 16.0),
              _buildRoundButton(
                icon: Icons.text_decrease,
                onTap: () {
                  if (fontSize > 12.0) onFontSizeChanged(fontSize - 1.0);
                },
                bgColor: cardBg,
              ),
              Expanded(
                child: Slider(
                  value: fontSize,
                  min: 12.0,
                  max: 32.0,
                  divisions: 20,
                  label: '${fontSize.toInt()}px',
                  activeColor: const Color(0xFF5B7FFF),
                  onChanged: onFontSizeChanged,
                ),
              ),
              _buildRoundButton(
                icon: Icons.text_increase,
                onTap: () {
                  if (fontSize < 32.0) onFontSizeChanged(fontSize + 1.0);
                },
                bgColor: cardBg,
              ),
              const SizedBox(width: 8.0),
              SizedBox(
                width: 36.0,
                child: Text(
                  '${fontSize.toInt()}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12.0),

          // 2. 行距调节
          Row(
            children: [
              const Text('行距', style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600)),
              const SizedBox(width: 24.0),
              _buildLineSpacingChip(label: '紧凑', value: fontSize * 1.4, current: lineHeight),
              const SizedBox(width: 12.0),
              _buildLineSpacingChip(label: '舒适', value: fontSize * 1.7, current: lineHeight),
              const SizedBox(width: 12.0),
              _buildLineSpacingChip(label: '宽松', value: fontSize * 2.0, current: lineHeight),
            ],
          ),
          const SizedBox(height: 16.0),

          // 3. 翻页模式选择（四等分自适应圆角胶囊，拒绝单行横向截断）
          Row(
            children: [
              const Text('翻页', style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600)),
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
                                  ? const Color(0xFF5B7FFF)
                                  : (isDark ? Colors.white10 : const Color(0xFFEBECEE)),
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                            child: Center(
                              child: Text(
                                shortTitle,
                                style: TextStyle(
                                  fontSize: 12.0,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark ? Colors.white70 : const Color(0xFF333333)),
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
                      color: isSelected ? const Color(0xFF5B7FFF) : Colors.grey.withValues(alpha: 0.3),
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
        child: Icon(icon, size: 18),
      ),
    );
  }

  Widget _buildLineSpacingChip({
    required String label,
    required double value,
    required double current,
  }) {
    final isSelected = (value - current).abs() < 1.0;
    return GestureDetector(
      onTap: () => onLineHeightChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF5B7FFF).withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(
            color: isSelected ? const Color(0xFF5B7FFF) : Colors.grey.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.0,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? const Color(0xFF5B7FFF) : null,
          ),
        ),
      ),
    );
  }
}
