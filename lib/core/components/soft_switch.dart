import 'package:flutter/material.dart';
import '../theme/soft_theme.dart';

/// Modern Soft UI 软拟态凹凸触感开关 (SoftSwitch)
class SoftSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final SoftColors colors;

  const SoftSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    const trackWidth = 52.0;
    const trackHeight = 30.0;
    const thumbSize = 24.0;
    const padding = 3.0;

    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeInOutCubic,
        width: trackWidth,
        height: trackHeight,
        padding: const EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: value
              ? colors.accent.withOpacity(colors.isDark ? 0.4 : 0.25)
              : colors.card,
          borderRadius: BorderRadius.circular(trackHeight / 2),
          border: Border.all(
            color: value ? colors.accent : colors.border,
            width: 1.0,
          ),
          boxShadow: SoftDecorations.insetShadows(colors),
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeInOutCubic,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: thumbSize,
                height: thumbSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: value ? colors.accent : colors.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      offset: const Offset(1, 2),
                      blurRadius: 4,
                    ),
                    if (!colors.isDark)
                      BoxShadow(
                        color: Colors.white.withOpacity(0.9),
                        offset: const Offset(-1, -1),
                        blurRadius: 2,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
