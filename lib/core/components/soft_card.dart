import 'package:flutter/material.dart';
import '../theme/soft_theme.dart';

/// Modern Soft UI 连续曲率微浮雕卡片 (SoftCard)
/// 遵循 24px Squircle 连续曲率、双层环境微阴影与点击下陷 scale/inset 反馈
class SoftCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double radius;
  final SoftColors colors;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double elevation;
  final Border? border;

  const SoftCard({
    super.key,
    required this.child,
    required this.colors,
    this.padding = const EdgeInsets.all(16.0),
    this.margin = EdgeInsets.zero,
    this.radius = SoftDecorations.squircleCardRadius,
    this.onTap,
    this.onLongPress,
    this.elevation = 1.0,
    this.border,
  });

  @override
  State<SoftCard> createState() => _SoftCardState();
}

class _SoftCardState extends State<SoftCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final effectiveElevation = (_isPressed && (widget.onTap != null || widget.onLongPress != null))
        ? widget.elevation * 0.35
        : widget.elevation;

    Widget cardContent = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: widget.colors.card,
        borderRadius: BorderRadius.circular(widget.radius),
        border: widget.border ?? Border.all(color: widget.colors.border, width: 1.0),
        boxShadow: SoftDecorations.softShadows(widget.colors, elevation: effectiveElevation),
      ),
      child: widget.child,
    );

    if (widget.onTap != null || widget.onLongPress != null) {
      cardContent = GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _isPressed ? 0.975 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: cardContent,
        ),
      );
    }

    if (widget.margin != EdgeInsets.zero) {
      return Padding(padding: widget.margin, child: cardContent);
    }

    return cardContent;
  }
}
