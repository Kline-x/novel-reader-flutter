import 'package:flutter/material.dart';
import '../engine/page_models.dart';
import 'reader_page_theme.dart';

/// 自绘排版视口 Painter (page_painter.dart)
/// 严格根据 ReaderLayoutEngine 计算的行数与字符边界渲染，零模糊、零切半行
class PagePainter extends CustomPainter {
  final ChapterPage page;
  final int totalPageCount;
  final String chapterTitle;
  final PagingConfig config;
  final ReaderThemeOption theme;
  final String bookTitle;
  final String currentTime;
  final double batteryLevel; // 0.0 ~ 1.0

  PagePainter({
    required this.page,
    required this.totalPageCount,
    required this.chapterTitle,
    required this.config,
    required this.theme,
    required this.bookTitle,
    required this.currentTime,
    this.batteryLevel = 0.85,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 绘制背景
    final bgPaint = Paint()..color = theme.background;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final subTextStyle = TextStyle(
      color: theme.subTextColor,
      fontSize: 12.0,
      fontFamily: 'system-ui',
    );

    // 2. 绘制页眉 (顶栏)：左侧章节名，右侧当前时间
    final headerY = (config.padTop - 20.0).clamp(10.0, 60.0);
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

    // 3. 绘制正文 (整数行绝对定位)
    final textStyle = TextStyle(
      color: theme.textColor,
      fontSize: config.fontSize,
      height: config.lineHeight / config.fontSize,
      letterSpacing: 0.5,
    );

    double currentY = config.padTop + 24.0;

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
      currentY += titlePainter.height + 24.0;
    }

    // 逐行绘制
    for (final line in page.lines) {
      final linePainter = TextPainter(
        text: TextSpan(text: line.text, style: textStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: config.availWidth + 20.0);

      linePainter.paint(canvas, Offset(config.hPad, currentY));
      currentY += config.lineHeight;
    }

    // 4. 绘制页脚 (底栏)：左侧页码比例，右侧电量胶囊
    final footerY = size.height - config.padBottom + 4.0;
    final footerText = '第 ${page.pageIndex + 1}/$totalPageCount 页';
    final footerLeftPainter = TextPainter(
      text: TextSpan(text: footerText, style: subTextStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    footerLeftPainter.paint(canvas, Offset(config.hPad, footerY));

    // 电量小图标
    final batteryX = size.width - config.hPad - 24.0;
    final batteryY = footerY + 2.0;
    _drawBatteryIcon(canvas, Offset(batteryX, batteryY), theme.subTextColor);
  }

  void _drawBatteryIcon(Canvas canvas, Offset offset, Color color) {
    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // 电池外壳
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(offset.dx, offset.dy, 20.0, 10.0),
      const Radius.circular(2.0),
    );
    canvas.drawRRect(rect, borderPaint);

    // 电池头
    final capRect = Rect.fromLTWH(offset.dx + 20.0, offset.dy + 2.5, 2.0, 5.0);
    canvas.drawRect(capRect, Paint()..color = color);

    // 电池电量填充
    final fillWidth = (16.0 * batteryLevel).clamp(1.0, 16.0);
    final fillRect = Rect.fromLTWH(offset.dx + 2.0, offset.dy + 2.0, fillWidth, 6.0);
    canvas.drawRect(fillRect, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant PagePainter oldDelegate) {
    return oldDelegate.page != page ||
        oldDelegate.theme != theme ||
        oldDelegate.config != config ||
        oldDelegate.currentTime != currentTime;
  }
}
