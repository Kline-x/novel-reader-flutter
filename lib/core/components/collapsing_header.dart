import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/soft_theme.dart';

/// 折叠式页面标题：静止时是大标题，一滚就收成贴顶的小标题条。
///
/// 为什么不像书架页那样把整块顶部钉住：设置页、发现页都是线性清单，
/// 没有搜索/排序这类翻内容时必须随时够得着的控件，钉一大片只会白占竖向空间。
/// 但标题整个滑走会让人失去「我在哪一页」的锚点——iOS 的大标题会收成小标题，
/// Android 的 collapsing toolbar 也会留一条紧凑 app bar，都不会让它彻底消失。
///
/// 收拢后的标题条兼作回顶按钮：这些页都很长，滚到底想回顶要连划好几下。
class CollapsingHeader extends StatelessWidget {
  const CollapsingHeader({
    super.key,
    required this.colors,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTapCollapsed,
    this.expandedTitleSize = 24.0,
  });

  final SoftColors colors;
  final String title;

  /// 副标题，收拢时淡出并收高。为空则只显示标题。
  final String? subtitle;

  /// 标题右侧的附属控件（如「清除搜索」），跟着标题一起收拢。
  final Widget? trailing;

  /// 收拢态点击标题条时触发，通常是滚回顶部。
  final VoidCallback? onTapCollapsed;

  final double expandedTitleSize;

  /// 按本组件的收拢规格生成 SliverAppBar，两处调用点保持一致。
  static Widget sliver({
    required SoftColors colors,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTapCollapsed,
    double expandedTitleSize = 24.0,
    // 页面下方已有常驻吸顶元素（如发现页 104px 的搜索+分类栏）时传 false：
    // 两条常驻栏叠起来会吃掉近两成屏幕，而那条吸顶栏本身已是足够的锚点。
    bool pinned = true,
  }) {
    final expanded = subtitle == null ? 76.0 : 92.0;
    return SliverAppBar(
      pinned: pinned,
      expandedHeight: expanded,
      collapsedHeight: 52.0,
      toolbarHeight: 52.0,
      automaticallyImplyLeading: false,
      elevation: 0.0,
      scrolledUnderElevation: 0.0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: CollapsingHeader(
        colors: colors,
        title: title,
        subtitle: subtitle,
        trailing: trailing,
        onTapCollapsed: onTapCollapsed,
        expandedTitleSize: expandedTitleSize,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings =
        context.dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
    final maxExtent = settings?.maxExtent ?? 92.0;
    final minExtent = settings?.minExtent ?? 52.0;
    final current = settings?.currentExtent ?? maxExtent;
    // 0 = 完全展开，1 = 完全收拢
    final t = maxExtent - minExtent <= 0
        ? 0.0
        : ((maxExtent - current) / (maxExtent - minExtent)).clamp(0.0, 1.0);

    final titleRow = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              // 收拢后固定成 18，不一路缩到看不清
              fontSize: expandedTitleSize - (expandedTitleSize - 18.0) * t,
              fontWeight: FontWeight.w900,
              color: colors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );

    return GestureDetector(
      onTap: t > 0.6 ? onTapCollapsed : null,
      behavior: HitTestBehavior.opaque,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18.0 * t, sigmaY: 18.0 * t),
          child: Container(
            // 收拢后给一层半透明底，正文滚到标题下面时仍然读得清
            color: colors.background.withValues(alpha: 0.82 * t),
            padding: EdgeInsets.fromLTRB(20.0, 0.0, 20.0, 10.0 + 4.0 * (1 - t)),
            alignment: Alignment.bottomLeft,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleRow,
                if (subtitle != null)
                  ClipRect(
                    child: Align(
                      heightFactor: (1 - t).clamp(0.0, 1.0),
                      alignment: Alignment.topLeft,
                      child: Opacity(
                        opacity: (1 - t * 1.6).clamp(0.0, 1.0),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 3.0),
                          child: Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.0,
                              fontWeight: FontWeight.w500,
                              color: colors.textSecondary
                                  .withValues(alpha: 0.75),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
