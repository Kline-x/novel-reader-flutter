import 'package:flutter/material.dart';
import '../theme/soft_theme.dart';

/// Modern Soft UI 连续曲率微浮雕卡片 (SoftCard)
class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double radius;
  final SoftColors colors;
  final VoidCallback? onTap;
  final double elevation;
  final Border? border;

  const SoftCard({
    super.key,
    required this.child,
    required this.colors,
    this.padding = const EdgeInsets.all(16.0),
    this.margin = EdgeInsets.zero,
    this.radius = 20.0,
    this.onTap,
    this.elevation = 1.0,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    Widget cardContent = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(radius),
        border: border ?? Border.all(color: colors.border, width: 1.0),
        boxShadow: SoftDecorations.softShadows(colors, elevation: elevation),
      ),
      child: child,
    );

    if (onTap != null) {
      cardContent = GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: cardContent,
      );
    }

    if (margin != EdgeInsets.zero) {
      return Padding(padding: margin, child: cardContent);
    }

    return cardContent;
  }
}
