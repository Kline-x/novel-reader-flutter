import 'package:flutter/material.dart';
import '../theme/soft_theme.dart';

/// Modern Soft UI (Calm Tech) 流体环境微光背景组件
/// 核心灵魂：在宣纸/墨玉基底上，散布薄荷、浅杏与霁蓝三大流体漫射微光球 (Ambient Mesh Glow)，
/// 营造“清晨推开书斋窗棂、微风携晨雾漫卷”的呼吸感与空气感。
class AmbientMeshBackground extends StatelessWidget {
  final Widget? child;

  const AmbientMeshBackground({
    super.key,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = SoftTheme.of(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. 纸感基底色
        Container(
          color: colors.background,
        ),

        // 2. 流体微光球层 (完全穿透点击事件，零触控拦截)
        Positioned.fill(
          child: IgnorePointer(
            child: OverflowBox(
              alignment: Alignment.topCenter,
              maxHeight: double.infinity,
              maxWidth: double.infinity,
              child: SizedBox(
                width: MediaQuery.sizeOf(context).width,
                height: MediaQuery.sizeOf(context).height,
                child: CustomPaint(
                  painter: _MeshGlowPainter(
                    glow1: colors.meshGlow1,
                    glow2: colors.meshGlow2,
                    glow3: colors.meshGlow3,
                    isDark: colors.isDark,
                  ),
                ),
              ),
            ),
          ),
        ),

        // 3. 上层业务内容视图
        if (child != null) child!,
      ],
    );
  }
}

class _MeshGlowPainter extends CustomPainter {
  final Color glow1;
  final Color glow2;
  final Color glow3;
  final bool isDark;

  _MeshGlowPainter({
    required this.glow1,
    required this.glow2,
    required this.glow3,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 光晕 1：左上方（柔薄荷/祖母绿幽光）
    final paint1 = Paint()
      ..shader = RadialGradient(
        colors: [
          glow1,
          glow1.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(w * 0.1, h * 0.08),
          radius: w * 0.45,
        ),
      )
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50.0);

    canvas.drawCircle(Offset(w * 0.1, h * 0.08), w * 0.45, paint1);

    // 光晕 2：右侧中上（暖浅杏/碧水微光）
    final paint2 = Paint()
      ..shader = RadialGradient(
        colors: [
          glow2,
          glow2.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(w * 0.95, h * 0.32),
          radius: w * 0.42,
        ),
      )
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 55.0);

    canvas.drawCircle(Offset(w * 0.95, h * 0.32), w * 0.42, paint2);

    // 光晕 3：左侧中下（霁蓝/星海幽蓝）
    final paint3 = Paint()
      ..shader = RadialGradient(
        colors: [
          glow3,
          glow3.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(w * 0.15, h * 0.68),
          radius: w * 0.38,
        ),
      )
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50.0);

    canvas.drawCircle(Offset(w * 0.15, h * 0.68), w * 0.38, paint3);
  }

  @override
  bool shouldRepaint(covariant _MeshGlowPainter oldDelegate) {
    return oldDelegate.glow1 != glow1 ||
        oldDelegate.glow2 != glow2 ||
        oldDelegate.glow3 != glow3 ||
        oldDelegate.isDark != isDark;
  }
}
