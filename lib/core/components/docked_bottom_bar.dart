import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/soft_theme.dart';

/// Modern Soft UI 无界沉浸贴底导航栏 (DockedBottomBar)
///
/// 设计要点：
/// 1. 【零分割线】：不使用任何 BorderSide、不使用 BackdropFilter 的硬边模糊区，
///    改为顶部 28px 的透明→背景色渐变带，正文滚动时自然消融，彻底没有那条突兀的横线；
/// 2. 【去色块】：选中态不再是生硬的绿色圆角填充块，改为柔和径向光晕 + 图标发光，
///    视觉重量落在图标与文字本身，而非底板；
/// 3. 【双态图标】：选中 Filled / 未选中 Outlined，配合 200ms 缩放切换；
/// 4. 【舒展均分】：三等分均布，44dp 最小触控热区与按压弹性缩放。
class DockedBottomBar extends StatefulWidget {
  /// 顶部渐隐带高度：内容从这里平滑没入底栏，替代分割线
  static const double fadeHeight = 28.0;
  static const double barContentHeight = 58.0;

  /// 底栏实际占据的总高度（含渐隐带与系统手势安全区）。
  /// 页面内的滚动列表必须按这个值预留底部内边距，否则最后一项会被压在底栏下面。
  static double totalHeight(BuildContext context) =>
      fadeHeight + barContentHeight + MediaQuery.paddingOf(context).bottom;

  /// 页面滚动列表建议的底部安全内边距
  static double contentBottomPadding(BuildContext context) =>
      totalHeight(context) + 16.0;

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
    final base = isDark ? colors.background : colors.surface;

    return Positioned(
      left: 0.0,
      right: 0.0,
      bottom: 0.0,
      child: IgnorePointer(
        ignoring: false,
        child: Container(
          height: DockedBottomBar.fadeHeight +
              DockedBottomBar.barContentHeight +
              bottomInset,
          decoration: BoxDecoration(
            // 自上而下由完全透明过渡到背景色：没有边界，也就没有"分割线"
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                base.withValues(alpha: 0.0),
                base.withValues(alpha: 0.72),
                base.withValues(alpha: 0.97),
                base,
              ],
              stops: const [0.0, 0.22, 0.46, 1.0],
            ),
          ),
          padding: EdgeInsets.only(
              top: DockedBottomBar.fadeHeight, bottom: bottomInset),
          child: SizedBox(
            height: DockedBottomBar.barContentHeight,
            child: Row(
              children: [
                Expanded(
                  child: _buildTabItem(
                    index: 0,
                    selectedIcon: Icons.auto_stories_rounded,
                    unselectedIcon: Icons.auto_stories_outlined,
                    label: '书架',
                    key: const ValueKey('tab_shelf'),
                    colors: colors,
                    isDark: isDark,
                  ),
                ),
                Expanded(
                  child: _buildTabItem(
                    index: 1,
                    selectedIcon: Icons.explore_rounded,
                    unselectedIcon: Icons.explore_outlined,
                    label: '发现',
                    key: const ValueKey('tab_discovery'),
                    colors: colors,
                    isDark: isDark,
                  ),
                ),
                Expanded(
                  child: _buildTabItem(
                    index: 2,
                    selectedIcon: Icons.settings_rounded,
                    unselectedIcon: Icons.settings_outlined,
                    label: '设置',
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
    );
  }

  Widget _buildTabItem({
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

    final inactiveColor = colors.textSecondary.withValues(alpha: 0.7);

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
      child: Center(
        child: AnimatedScale(
          scale: isPressing ? 0.93 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: SizedBox(
            height: 46.0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 40.0,
                  height: 26.0,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // 选中态柔和径向光晕：无硬边、无色块，只是一团呼吸感的底光
                      AnimatedOpacity(
                        opacity: isSelected ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOut,
                        child: Container(
                          width: 40.0,
                          height: 26.0,
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              colors: [
                                colors.accent
                                    .withValues(alpha: isDark ? 0.26 : 0.18),
                                colors.accent.withValues(alpha: 0.0),
                              ],
                              stops: const [0.0, 1.0],
                            ),
                          ),
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (child, anim) =>
                            ScaleTransition(scale: anim, child: child),
                        child: Icon(
                          isSelected ? selectedIcon : unselectedIcon,
                          key: ValueKey('icon_${index}_$isSelected'),
                          size: 23.0,
                          color: isSelected ? colors.accent : inactiveColor,
                          shadows: isSelected
                              ? [
                                  Shadow(
                                    color: colors.accent.withValues(
                                        alpha: isDark ? 0.55 : 0.35),
                                    blurRadius: 12.0,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2.0),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  style: TextStyle(
                    fontSize: 11.0,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? colors.accent : inactiveColor,
                    letterSpacing: 0.3,
                    height: 1.2,
                  ),
                  child: Text(label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
