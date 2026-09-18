import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/soft_theme.dart';

/// Modern Soft UI 56px 沉浸贴底毛玻璃导航栏 (DockedBottomBar)
/// 精准适配 56.0dp + 底部安全区，通透高斯模糊与流体微发光指示胶囊
class DockedBottomBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final SoftColors? colors;

  const DockedBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    this.colors,
  });

  @override
  State<DockedBottomBar> createState() => _DockedBottomBarState();
}

class _DockedBottomBarState extends State<DockedBottomBar> {
  int? _pressingIndex;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors ?? SoftTheme.of(context);
    final isDark = colors.isDark;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final totalHeight = 56.0 + bottomInset;

    return Positioned(
      left: 0.0,
      right: 0.0,
      bottom: 0.0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
          child: Container(
            height: totalHeight,
            padding: EdgeInsets.only(bottom: bottomInset),
            decoration: BoxDecoration(
              color: (isDark ? colors.background : colors.surface)
                  .withValues(alpha: isDark ? 0.72 : 0.82),
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : colors.border.withValues(alpha: 0.55),
                  width: 0.8,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.3)
                      : colors.border.withValues(alpha: 0.08),
                  offset: const Offset(0, -2),
                  blurRadius: 12.0,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: SizedBox(
              height: 56.0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildTabItem(
                    index: 0,
                    iconData: Icons.auto_stories_rounded,
                    label: '书架',
                    key: const ValueKey('tab_shelf'),
                    colors: colors,
                    isDark: isDark,
                  ),
                  _buildTabItem(
                    index: 1,
                    iconData: Icons.auto_awesome_rounded,
                    label: '发现',
                    key: const ValueKey('tab_discovery'),
                    colors: colors,
                    isDark: isDark,
                  ),
                  _buildTabItem(
                    index: 2,
                    iconData: Icons.settings_rounded,
                    label: '设置',
                    key: const ValueKey('tab_settings'),
                    colors: colors,
                    isDark: isDark,
                  ),
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
    required IconData iconData,
    required String label,
    required Key key,
    required SoftColors colors,
    required bool isDark,
  }) {
    final isSelected = widget.currentIndex == index;
    final isPressing = _pressingIndex == index;

    return GestureDetector(
      key: key,
      onTapDown: (_) => setState(() => _pressingIndex = index),
      onTapUp: (_) => setState(() => _pressingIndex = null),
      onTapCancel: () => setState(() => _pressingIndex = null),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTabSelected(index);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: isPressing ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: isSelected ? 18.0 : 14.0,
            vertical: 7.0,
          ),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            colors.accent.withValues(alpha: 0.24),
                            colors.surface.withValues(alpha: 0.9),
                          ]
                        : [
                            colors.accent.withValues(alpha: 0.14),
                            colors.card.withValues(alpha: 0.95),
                          ],
                  )
                : null,
            color: isSelected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(16.0),
            border: isSelected
                ? Border.all(
                    color:
                        colors.accent.withValues(alpha: isDark ? 0.45 : 0.32),
                    width: 1.0,
                  )
                : Border.all(color: Colors.transparent, width: 1.0),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color:
                          colors.accent.withValues(alpha: isDark ? 0.28 : 0.2),
                      offset: const Offset(0, 2),
                      blurRadius: 10.0,
                      spreadRadius: 0,
                    ),
                    if (!isDark)
                      BoxShadow(
                        color: const Color(0xFF14161B).withValues(alpha: 0.04),
                        offset: const Offset(0, 1),
                        blurRadius: 3.0,
                        spreadRadius: 0,
                      ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                iconData,
                size: 18.0,
                color: isSelected
                    ? colors.accent
                    : colors.textSecondary.withValues(alpha: 0.72),
                shadows: isSelected
                    ? [
                        Shadow(
                          color: colors.accent.withValues(alpha: 0.55),
                          blurRadius: 8.0,
                        ),
                      ]
                    : null,
              ),
              const SizedBox(width: 7.0),
              Text(
                label,
                style: TextStyle(
                  fontSize: isSelected ? 13.5 : 13.0,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? colors.accent
                      : colors.textSecondary.withValues(alpha: 0.8),
                  letterSpacing: 0.25,
                  shadows: isSelected
                      ? [
                          Shadow(
                            color: colors.accent.withValues(alpha: 0.4),
                            blurRadius: 6.0,
                          ),
                        ]
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
