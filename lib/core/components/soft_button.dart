import 'package:flutter/material.dart';
import '../theme/soft_theme.dart';

/// Modern Soft UI 触感微浮雕胶囊按钮 (SoftButton)
class SoftButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final SoftColors colors;
  final bool isPill;
  final double radius;
  final EdgeInsetsGeometry padding;
  final bool isActive;

  const SoftButton({
    super.key,
    required this.child,
    required this.colors,
    this.onPressed,
    this.isPill = false,
    this.radius = 16.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
    this.isActive = false,
  });

  @override
  State<SoftButton> createState() => _SoftButtonState();
}

class _SoftButtonState extends State<SoftButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = widget.isPill ? 32.0 : widget.radius;
    final isDepressed = _isPressed || widget.isActive;

    return GestureDetector(
      onTapDown: widget.onPressed == null ? null : (_) => setState(() => _isPressed = true),
      onTapUp: widget.onPressed == null ? null : (_) => setState(() => _isPressed = false),
      onTapCancel: widget.onPressed == null ? null : () => setState(() => _isPressed = false),
      onTap: widget.onPressed,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          padding: widget.padding,
          decoration: BoxDecoration(
            color: widget.isActive
                ? widget.colors.accent.withValues(alpha: widget.colors.isDark ? 0.25 : 0.15)
                : widget.colors.surface,
            borderRadius: BorderRadius.circular(effectiveRadius),
            border: Border.all(
              color: widget.isActive ? widget.colors.accent : widget.colors.border,
              width: widget.isActive ? 1.5 : 1.0,
            ),
            boxShadow: isDepressed
                ? SoftDecorations.insetShadows(widget.colors)
                : SoftDecorations.softShadows(widget.colors, elevation: 0.8),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
