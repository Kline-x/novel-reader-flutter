import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/soft_theme.dart';

/// Modern Soft UI 悬浮微光药丸胶囊导航 Dock (SublimeFloatingDock)
///
/// 1:1 像素级对齐原型 modern_soft_ui_sublime_v3.html:
/// 1. 【全悬浮胶囊】：absolute bottom-5 left-4 right-4 h-16 rounded-full；
/// 2. 【毛玻璃微光材质】：BackdropFilter(blur 24px) + 82% 意境卡片半透 + border-subtle 边框；
/// 3. 【玉质内高光与浮空阴影】：inset 0 1px 1.5px borderInner + sh-dock 双层弥散投影；
/// 4. 【三等分微胶囊按键】：
///    - 标签对齐为「藏书阁」、「文渊寻踪」、「偏好设置」；
///    - 选中态：40×24px 极度柔和的 accentSoft 微胶囊包裹图标 + accent 色 10px 极粗字；
///    - 未选中态：textSecondary 次级柔色 + 10px 细致字；
///    - 按压即时 scale-90 弹性物理触感与触觉振动反馈。
class DockedBottomBar extends StatefulWidget {
  static const double dockHeight = 64.0;
  static const double floatBottomMargin = 20.0;
  static const double horizontalMargin = 16.0;

  // 向前兼容属性
  static const double fadeHeight = floatBottomMargin;
  static const double barContentHeight = dockHeight;

  /// 底栏实际占据的总高度（含浮空留白与系统手势安全区）。
  static double totalHeight(BuildContext context) =>
      dockHeight + floatBottomMargin + MediaQuery.paddingOf(context).bottom;

  /// 页面滚动列表建议的底部安全内边距（含浮空胶囊、手势区与 24dp 舒展留白）
  static double contentBottomPadding(BuildContext context) =>
      totalHeight(context) + 24.0;

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

    // 原型 .sublime-dock 背景：浅色 rgba(255,255,255,0.82)，深色 rgba(24,32,28,0.82)
    final dockBg = colors.card.withValues(alpha: 0.82);

    return Positioned(
      left: DockedBottomBar.horizontalMargin,
      right: DockedBottomBar.horizontalMargin,
      bottom: DockedBottomBar.floatBottomMargin + bottomInset,
      height: DockedBottomBar.dockHeight,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(SoftDecorations.pillRadius),
          boxShadow: SoftDecorations.dockShadow(colors),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(SoftDecorations.pillRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24.0, sigmaY: 24.0),
            child: Container(
              decoration: BoxDecoration(
                color: dockBg,
                borderRadius: BorderRadius.circular(SoftDecorations.pillRadius),
                border: Border.all(
                  color: colors.borderSubtle,
                  width: 1.0,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Row(
                children: [
                  Expanded(
                    child: _buildDockItem(
                      index: 0,
                      selectedIcon: Icons.auto_stories_rounded,
                      unselectedIcon: Icons.auto_stories_outlined,
                      label: '藏书阁',
                      key: const ValueKey('tab_shelf'),
                      colors: colors,
                      isDark: isDark,
                    ),
                  ),
                  Expanded(
                    child: _buildDockItem(
                      index: 1,
                      selectedIcon: Icons.explore_rounded,
                      unselectedIcon: Icons.explore_outlined,
                      label: '文渊寻踪',
                      key: const ValueKey('tab_discovery'),
                      colors: colors,
                      isDark: isDark,
                    ),
                  ),
                  Expanded(
                    child: _buildDockItem(
                      index: 2,
                      selectedIcon: Icons.settings_rounded,
                      unselectedIcon: Icons.settings_outlined,
                      label: '偏好设置',
                      key: const ValueKey('tab_settings'),
                      colors: colors,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDockItem({
    required int index,
    required IconData selectedIcon,
    required IconData unselectedIcon,
    required String label,
    required Key key,
    required SoftColors colors,
    required bool isDark,
  }) {
    final isSelected = widget.currentIndex == index;
    final isPressing = _pressingIndex == index;

    final activeColor = colors.accent;
    final inactiveColor = colors.textSecondary;

    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressingIndex = index),
      onTapUp: (_) => setState(() => _pressingIndex = null),
      onTapCancel: () => setState(() => _pressingIndex = null),
      onTap: () {
        if (!isSelected) {
          HapticFeedback.selectionClick();
          widget.onTabSelected(index);
        }
      },
      child: AnimatedScale(
        scale: isPressing ? 0.90 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 选中态拥有 accentSoft 微胶囊背景板 (w-10 h-6 rounded-full)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                width: 40.0,
                height: 24.0,
                decoration: BoxDecoration(
                  color: isSelected ? colors.accentSoft : Colors.transparent,
                  borderRadius:
                      BorderRadius.circular(SoftDecorations.pillRadius),
                ),
                alignment: Alignment.center,
                child: Icon(
                  isSelected ? selectedIcon : unselectedIcon,
                  size: 17.5,
                  color: isSelected ? activeColor : inactiveColor,
                ),
              ),
              const SizedBox(height: 2.0),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.0,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                  color: isSelected ? activeColor : inactiveColor,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
