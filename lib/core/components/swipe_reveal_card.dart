import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 优雅阻尼滑动露出操作按钮卡片 (SwipeRevealCard)
/// 专为解决原生 Dismissible 甩飞整卡、全屏红底的夸张交互而设计：
/// - 支持向左/向右平滑阻尼拖动，最大位移限制为 80dp；
/// - 阻尼超过阈值后吸附固定，优雅露出圆角红色“移出”操作胶囊；
/// - 点击移出按钮触发确认回调，点击卡片主体或反向滑动自动丝滑回弹；
/// - 严格配合 Modern Soft UI 规范，带微触感反馈，绝不甩飞整行。
class SwipeRevealCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onDelete;
  final String deleteLabel;
  final double maxActionWidth;

  const SwipeRevealCard({
    super.key,
    required this.child,
    required this.onDelete,
    this.deleteLabel = '移出',
    this.maxActionWidth = 80.0,
  });

  @override
  State<SwipeRevealCard> createState() => _SwipeRevealCardState();
}

class _SwipeRevealCardState extends State<SwipeRevealCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _dragOffset = 0.0;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _animation = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    )..addListener(() {
        setState(() {
          _dragOffset = _animation.value;
        });
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _animateTo(double target) {
    _animation = Tween<double>(begin: _dragOffset, end: target).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward(from: 0.0);
    _isOpen = target.abs() > 0.1;
  }

  void _close() {
    if (_dragOffset != 0.0) {
      _animateTo(0.0);
    }
  }

  void _handleHorizontalUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.primaryDelta!;
      // 限制最大左右位移并施加轻微阻尼
      _dragOffset = _dragOffset.clamp(-widget.maxActionWidth, widget.maxActionWidth);
    });
  }

  void _handleHorizontalEnd(DragEndDetails details) {
    final threshold = widget.maxActionWidth * 0.38;
    if (_dragOffset > threshold) {
      // 向右滑开露出左侧按钮
      HapticFeedback.lightImpact();
      _animateTo(widget.maxActionWidth);
    } else if (_dragOffset < -threshold) {
      // 向左滑开露出右侧按钮
      HapticFeedback.lightImpact();
      _animateTo(-widget.maxActionWidth);
    } else {
      // 未达到阈值，平滑回弹复位
      _animateTo(0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final absOffset = _dragOffset.abs();
    final shouldRenderAction = absOffset > 0.5;
    final actionOpacity = ((absOffset - 0.5) / 20.0).clamp(0.0, 1.0);

    return Stack(
      children: [
        // 底层：优雅圆角移出按钮容器（绝对防漏光：仅在拖拽露出时渲染，带 Opacity 渐入）
        if (shouldRenderAction)
          Positioned.fill(
            child: Opacity(
              opacity: actionOpacity,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isRevealingLeft = _dragOffset > 0;
                  return Align(
                    alignment: isRevealingLeft ? Alignment.centerLeft : Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          _close();
                          widget.onDelete();
                        },
                        child: Container(
                          width: widget.maxActionWidth - 8.0,
                          height: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC2626),
                            borderRadius: BorderRadius.circular(16.0),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFDC2626).withValues(alpha: 0.35 * actionOpacity),
                                offset: const Offset(0, 4),
                                blurRadius: 10.0,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.white,
                                size: 22.0,
                              ),
                              const SizedBox(height: 3.0),
                              Text(
                                widget.deleteLabel,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

        // 表层：书籍主卡片，跟随手势平滑偏移
        Transform.translate(
          offset: Offset(_dragOffset, 0),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: _handleHorizontalUpdate,
            onHorizontalDragEnd: _handleHorizontalEnd,
            child: Stack(
              children: [
                widget.child,
                if (_isOpen)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _close,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
