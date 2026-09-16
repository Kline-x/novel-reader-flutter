import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/soft_theme.dart';

/// Modern Soft UI 62px 悬浮毛玻璃胶囊底栏 (FloatingDock)
class FloatingDock extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final SoftColors colors;

  const FloatingDock({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Positioned(
      left: 24.0,
      right: 24.0,
      bottom: bottomInset + 16.0,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(36.0),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18.0, sigmaY: 18.0),
            child: Container(
              height: 62.0,
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
              decoration: BoxDecoration(
                color: colors.surface.withOpacity(colors.isDark ? 0.85 : 0.82),
                borderRadius: BorderRadius.circular(36.0),
                border: Border.all(
                  color: colors.isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.white.withOpacity(0.6),
                  width: 1.2,
                ),
                boxShadow: SoftDecorations.softShadows(colors, elevation: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTabItem(index: 0, icon: '📖', label: '书架'),
                  const SizedBox(width: 6.0),
                  _buildTabItem(index: 1, icon: '✨', label: '发现'),
                  const SizedBox(width: 6.0),
                  _buildTabItem(index: 2, icon: '⚙️', label: '设置'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem({
    required int index,
    required String icon,
    required String label,
  }) {
    final isSelected = currentIndex == index;

    return GestureDetector(
      onTap: () => onTabSelected(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: isSelected
              ? (colors.isDark
                  ? colors.accent.withOpacity(0.2)
                  : colors.accent.withOpacity(0.15))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24.0),
          border: isSelected
              ? Border.all(color: colors.accent.withOpacity(0.4), width: 1.0)
              : Border.all(color: Colors.transparent, width: 1.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 16.0)),
            const SizedBox(width: 6.0),
            Text(
              label,
              style: TextStyle(
                fontSize: 14.0,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? colors.accent : colors.textSecondary,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
