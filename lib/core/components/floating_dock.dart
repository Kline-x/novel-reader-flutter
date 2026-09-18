import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/soft_theme.dart';

/// Modern Soft UI 62px 悬浮毛玻璃胶囊底栏 (FloatingDock)
class FloatingDock extends StatefulWidget {
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
  State<FloatingDock> createState() => _FloatingDockState();
}

class _FloatingDockState extends State<FloatingDock> {
  int? _pressingIndex;

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
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
              decoration: BoxDecoration(
                color: widget.colors.surface
                    .withValues(alpha: widget.colors.isDark ? 0.85 : 0.82),
                borderRadius: BorderRadius.circular(36.0),
                border: Border.all(
                  color: widget.colors.isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.6),
                  width: 1.2,
                ),
                boxShadow: SoftDecorations.dockShadow(widget.colors),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTabItem(
                    index: 0,
                    icon: '📖',
                    label: '书架',
                    key: const ValueKey('tab_shelf'),
                  ),
                  const SizedBox(width: 6.0),
                  _buildTabItem(
                    index: 1,
                    icon: '✨',
                    label: '发现',
                    key: const ValueKey('tab_discovery'),
                  ),
                  const SizedBox(width: 6.0),
                  _buildTabItem(
                    index: 2,
                    icon: '⚙️',
                    label: '设置',
                    key: const ValueKey('tab_settings'),
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
    required String icon,
    required String label,
    required Key key,
  }) {
    final isSelected = widget.currentIndex == index;
    final isPressing = _pressingIndex == index;

    return GestureDetector(
      key: key,
      onTapDown: (_) => setState(() => _pressingIndex = index),
      onTapUp: (_) => setState(() => _pressingIndex = null),
      onTapCancel: () => setState(() => _pressingIndex = null),
      onTap: () => widget.onTabSelected(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: isPressing ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 10.0),
          decoration: BoxDecoration(
            color: isSelected
                ? (widget.colors.isDark
                    ? widget.colors.accent.withValues(alpha: 0.2)
                    : widget.colors.accent.withValues(alpha: 0.15))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(24.0),
            border: isSelected
                ? Border.all(
                    color: widget.colors.accent.withValues(alpha: 0.4),
                    width: 1.0)
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
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                  color: isSelected
                      ? widget.colors.accent
                      : widget.colors.textSecondary,
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
