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
  final bool isFilled;

  const SoftButton({
    super.key,
    required this.child,
    required this.colors,
    this.onPressed,
    this.isPill = false,
    this.radius = 16.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
    this.isActive = false,
    this.isFilled = false,
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

    Widget content = widget.child;
    if (widget.isFilled) {
      content = DefaultTextStyle.merge(
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.2,
        ),
        child: IconTheme.merge(
          data: const IconThemeData(color: Colors.white),
          child: widget.child,
        ),
      );
    }

    return GestureDetector(
      onTapDown: widget.onPressed == null
          ? null
          : (_) => setState(() => _isPressed = true),
      onTapUp: widget.onPressed == null
          ? null
          : (_) => setState(() => _isPressed = false),
      onTapCancel: widget.onPressed == null
          ? null
          : () => setState(() => _isPressed = false),
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
            color: widget.isFilled
                ? (_isPressed
                    ? Color.lerp(widget.colors.accent, Colors.black, 0.12)!
                    : widget.colors.accent)
                : (widget.isActive
                    ? widget.colors.accent
                        .withValues(alpha: widget.colors.isDark ? 0.25 : 0.15)
                    : widget.colors.surface),
            borderRadius: BorderRadius.circular(effectiveRadius),
            border: Border.all(
              color: widget.isFilled
                  ? (_isPressed
                      ? Color.lerp(widget.colors.accent, Colors.black, 0.18)!
                      : widget.colors.accent)
                  : (widget.isActive
                      ? widget.colors.accent
                      : widget.colors.border),
              width: (widget.isFilled || widget.isActive) ? 1.5 : 1.0,
            ),
            boxShadow: widget.isFilled
                ? (_isPressed
                    ? [
                        BoxShadow(
                          color: widget.colors.accent.withValues(alpha: 0.2),
                          offset: const Offset(0, 1),
                          blurRadius: 3,
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: widget.colors.accent.withValues(alpha: 0.38),
                          offset: const Offset(0, 3.5),
                          blurRadius: 9,
                        ),
                      ])
                : (isDepressed
                    ? SoftDecorations.insetShadows(widget.colors)
                    : SoftDecorations.softShadows(widget.colors,
                        elevation: 0.8)),
          ),
          child: content,
        ),
      ),
    );
  }
}
