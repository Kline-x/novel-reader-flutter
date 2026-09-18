import 'package:flutter/material.dart';
import '../../notes/models/annotation.dart';
import '../engine/page_models.dart';
import 'reader_page_theme.dart';

/// 自绘排版视口 Painter (page_painter.dart)
/// 严格根据 ReaderLayoutEngine 计算的行数与字符边界渲染，零模糊、零切半行，支持真实划线高亮与下划线
class PagePainter extends CustomPainter {
  final ChapterPage page;
  final int totalPageCount;
  final String chapterTitle;
  final PagingConfig config;
  final ReaderThemeOption theme;
  final String bookTitle;
  final String currentTime;
  /// 真实电量 0.0~1.0；为 null 表示当前平台拿不到电量，
  /// 此时页脚不渲染任何电量信息，绝不展示写死的假数值。
  final double? batteryLevel;
  final List<Annotation> annotations;

  PagePainter({
    required this.page,
    required this.totalPageCount,
    required this.chapterTitle,
    required this.config,
    required this.theme,
    required this.bookTitle,
    required this.currentTime,
    this.batteryLevel,
    this.annotations = const [],
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 绘制背景
    final bgPaint = Paint()..color = theme.background;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final resolvedSubColor =
        _resolveHighContrastColor(theme.subTextColor, theme.background);
    final subTextStyle = TextStyle(
      color: resolvedSubColor,
      fontSize: 12.0,
      fontFamily: 'system-ui',
    );

    // 2. 绘制页眉 (顶栏)：左侧章节名，右侧当前时间（在状态栏正下方舒适避让）
    final headerY = (config.padTop - 24.0).clamp(8.0, 100.0);
    if (page.pageIndex > 0 || !page.isFirstPage) {
      final headerLeftPainter = TextPainter(
        text: TextSpan(text: chapterTitle, style: subTextStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '...',
      )..layout(maxWidth: size.width - 120.0);
      headerLeftPainter.paint(canvas, Offset(config.hPad, headerY));

      final headerRightPainter = TextPainter(
        text: TextSpan(text: currentTime, style: subTextStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      headerRightPainter.paint(
        canvas,
        Offset(size.width - config.hPad - headerRightPainter.width, headerY),
      );
    }

    // 3. 绘制正文 (整数行绝对定位，严密对齐排版引擎可用高度)
    final textStyle = TextStyle(
      color: theme.textColor,
      fontSize: config.fontSize,
      height: config.lineHeight / config.fontSize,
      letterSpacing: 0.5,
    );

    double currentY = config.padTop;

    // 首页章节大标题绘制
    if (page.isFirstPage) {
      final titleStyle = TextStyle(
        color: theme.textColor,
        fontSize: config.fontSize + 6.0,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.8,
      );
      final titlePainter = TextPainter(
        text: TextSpan(text: chapterTitle, style: titleStyle),
        textDirection: TextDirection.ltr,
        maxLines: 2,
      )..layout(maxWidth: config.availWidth);

      titlePainter.paint(canvas, Offset(config.hPad, currentY));
      currentY += config.titleHeight;
    }

    // 逐行绘制
    for (final line in page.lines) {
      // 绘制划线高亮背景与下划线
      for (final ann in annotations) {
        if (ann.charEnd > line.charStart && ann.charStart < line.charEnd) {
          final relStart =
              (ann.charStart - line.charStart).clamp(0, line.text.length);
          final relEnd =
              (ann.charEnd - line.charStart).clamp(0, line.text.length);
          if (relEnd > relStart) {
            final textBefore = line.text.substring(0, relStart);
            final textTarget = line.text.substring(relStart, relEnd);
            final beforePainter = TextPainter(
              text: TextSpan(text: textBefore, style: textStyle),
              textDirection: TextDirection.ltr,
            )..layout();
            final targetPainter = TextPainter(
              text: TextSpan(text: textTarget, style: textStyle),
              textDirection: TextDirection.ltr,
            )..layout();

            final highlightX = config.hPad + beforePainter.width;
            final highlightW = targetPainter.width;
            final highlightRect = Rect.fromLTWH(
              highlightX,
              currentY + 2.0,
              highlightW,
              config.lineHeight - 4.0,
            );

            // 1) 柔和半透明色块
            final bgPaint = Paint()
              ..color = ann.color.withValues(alpha: theme.isDark ? 0.35 : 0.45)
              ..style = PaintingStyle.fill;
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                  highlightRect, const Radius.circular(3.0)),
              bgPaint,
            );

            // 2) 优雅下划线
            final underlinePaint = Paint()
              ..color = ann.color.withValues(alpha: 0.95)
              ..strokeWidth = 2.0
              ..style = PaintingStyle.stroke;
            canvas.drawLine(
              Offset(highlightX, currentY + config.lineHeight - 2.0),
              Offset(
                  highlightX + highlightW, currentY + config.lineHeight - 2.0),
              underlinePaint,
            );
          }
        }
      }

      final linePainter = TextPainter(
        text: TextSpan(text: line.text, style: textStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: config.availWidth + 20.0);

      linePainter.paint(canvas, Offset(config.hPad, currentY));
      currentY += config.lineHeight;
    }

    // 4. 绘制页脚 (底栏)：左侧页码比例，右侧电量百分比与胶囊图标
    final footerY = size.height - config.padBottom + 8.0;
    final footerText = '第 ${page.pageIndex + 1}/$totalPageCount 页';
    final footerLeftPainter = TextPainter(
      text: TextSpan(text: footerText, style: subTextStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    footerLeftPainter.paint(canvas, Offset(config.hPad, footerY));

    // 绘制电量百分比数字与高对比度电池图标（仅在拿到真实电量时渲染）
    if (batteryLevel != null) {
      _drawBatteryWithPercentage(canvas, size, footerY, batteryLevel!);
    }
  }

  /// 动态计算满足 WCAG 4.5:1 高对比度色彩
  Color _resolveHighContrastColor(Color color, Color bg) {
    final bgLum = bg.computeLuminance();
    final colLum = color.computeLuminance();
    final contrast = (bgLum > colLum)
        ? (bgLum + 0.05) / (colLum + 0.05)
        : (colLum + 0.05) / (bgLum + 0.05);

    if (contrast < 4.5) {
      return bgLum > 0.5 ? const Color(0xFF383C45) : const Color(0xFFB5BAC6);
    }
    return color;
  }

  /// 绘制电量百分比数字与电池图标
  void _drawBatteryWithPercentage(
      Canvas canvas, Size size, double footerY, double level) {
    final int percent = (level * 100).round().clamp(0, 100);
    final isLowBattery = percent <= 20;
    final isCriticalBattery = percent <= 10;

    // 低电量警报色彩联动与高对比度保障
    Color batteryColor;
    if (isCriticalBattery) {
      batteryColor = const Color(0xFFE53935); // 鲜明警戒红 (<10%)
    } else if (isLowBattery) {
      batteryColor = const Color(0xFFF57C00); // 警示琥珀橙 (<=20%)
    } else {
      batteryColor =
          _resolveHighContrastColor(theme.subTextColor, theme.background);
    }

    final percentStyle = TextStyle(
      color: batteryColor,
      fontSize: 11.0,
      fontWeight: isLowBattery ? FontWeight.bold : FontWeight.w500,
      fontFamily: 'system-ui',
    );

    final percentPainter = TextPainter(
      text: TextSpan(text: '$percent%', style: percentStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    const double batteryWidth = 22.0;
    const double batteryHeight = 10.5;
    const double spacing = 4.0;
    final totalWidth = percentPainter.width + spacing + batteryWidth;

    final startX = size.width - config.hPad - totalWidth;
    final textY = footerY + 1.0;
    final iconY = footerY + 2.0;

    // 1) 绘制电量百分比数字
    percentPainter.paint(canvas, Offset(startX, textY));

    // 2) 绘制电池胶囊
    final iconX = startX + percentPainter.width + spacing;
    _drawBatteryIcon(canvas, Offset(iconX, iconY), batteryColor, batteryWidth,
        batteryHeight, level);
  }

  void _drawBatteryIcon(Canvas canvas, Offset offset, Color color, double width,
      double height, double level) {
    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    // 电池外壳
    final bodyWidth = width - 2.5;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(offset.dx, offset.dy, bodyWidth, height),
      const Radius.circular(2.5),
    );
    canvas.drawRRect(rect, borderPaint);

    // 电池头正极
    final capRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
          offset.dx + bodyWidth, offset.dy + (height - 4.5) / 2, 2.0, 4.5),
      const Radius.circular(1.0),
    );
    canvas.drawRRect(capRect, Paint()..color = color);

    // 电池电量内部填充
    final maxInnerWidth = bodyWidth - 3.6;
    final fillWidth = (maxInnerWidth * level).clamp(1.5, maxInnerWidth);
    final fillRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(offset.dx + 1.8, offset.dy + 1.8, fillWidth, height - 3.6),
      const Radius.circular(1.5),
    );
    canvas.drawRRect(fillRect, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant PagePainter oldDelegate) {
    return oldDelegate.page != page ||
        oldDelegate.theme != theme ||
        oldDelegate.chapterTitle != chapterTitle ||
        oldDelegate.totalPageCount != totalPageCount ||
        oldDelegate.currentTime != currentTime ||
        oldDelegate.batteryLevel != batteryLevel ||
        oldDelegate.annotations != annotations;
  }
}
