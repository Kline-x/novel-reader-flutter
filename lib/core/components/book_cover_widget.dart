import 'package:flutter/material.dart';

/// Modern Soft UI v3.0 高保真精装书籍封面组件 (BookCoverWidget)
/// 严格对齐 modern_soft_ui_sublime_v3.html 中精装典藏书本规范：
/// - 9 组古典文人与精装皮质微光色场 (Misty & Leather Palettes)
/// - 仿真立体书脊侧光折射 (Book Spine Lighting)
/// - 斜切温润微高光 (Sheen)
/// - 纵向竖排中文书名 (Vertical Typography)
/// - 底部居中作者姓名 + 顶部状态/分类胶囊
/// - 兼容 HTTP 网络封面图片，失败或无图平滑降级自绘
class BookCoverWidget extends StatelessWidget {
  final String title;
  final String author;
  final String? coverUrl;
  final String? badgeText;
  final double width;
  final double height;
  final double borderRadius;
  final bool showShadow;
  final int? paletteIndex;

  const BookCoverWidget({
    super.key,
    required this.title,
    required this.author,
    this.coverUrl,
    this.badgeText,
    this.width = 52.0,
    this.height = 70.0,
    this.borderRadius = 12.0,
    this.showShadow = true,
    this.paletteIndex,
  });

  /// 9 组古典文人与精装皮质雅致色板 (对齐 v3 原型)
  static const List<List<Color>> coverPalettes = [
    [Color(0xFF374151), Color(0xFF1F2937)], // 1. 玄铁墨石皮质 (十日终焉同款)
    [Color(0xFF853A1B), Color(0xFF541F0C)], // 2. 丹砂赤木精装 (道诡异仙同款)
    [Color(0xFF1E40AF), Color(0xFF111827)], // 3. 霁蓝星海深邃 (诡秘之主同款)
    [Color(0xFF236B58), Color(0xFF143E33)], // 4. 苍岚松影宋瓷
    [Color(0xFFB86820), Color(0xFF6B3A0D)], // 5. 暮色暖珀焦糖
    [Color(0xFF6D599A), Color(0xFF3F325C)], // 6. 紫陌幽兰丝帛
    [Color(0xFF3B4353), Color(0xFF222936)], // 7. 冷杉黛蓝古典
    [Color(0xFF8D5B4C), Color(0xFF4E2E25)], // 8. 栗褐羊皮复古
    [Color(0xFF1F3540), Color(0xFF0F1E26)], // 9. 碧水墨玉深空
  ];

  static int hashTitleToPalette(String str) {
    if (str.isEmpty) return 0;
    int hash = 0;
    for (int i = 0; i < str.length; i++) {
      hash = (hash * 31 + str.codeUnitAt(i)) & 0xFFFFFFFF;
    }
    return hash.abs() % coverPalettes.length;
  }

  @override
  Widget build(BuildContext context) {
    final cleanTitle = title.replaceAll(RegExp(r'[《》\s]'), '');
    final pIdx = paletteIndex ?? hashTitleToPalette(cleanTitle);
    final palette = coverPalettes[pIdx.clamp(0, coverPalettes.length - 1)];

    final bool hasValidNetworkCover = coverUrl != null &&
        coverUrl!.isNotEmpty &&
        coverUrl!.startsWith('http');

    return Container(
      width: width.isFinite ? width : null,
      height: height.isFinite ? height : null,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: const Color(0xFF14161B).withValues(alpha: 0.26),
                  offset: const Offset(0, 6),
                  blurRadius: 14,
                  spreadRadius: -2,
                ),
                BoxShadow(
                  color: palette.first.withValues(alpha: 0.15),
                  offset: const Offset(0, 2),
                  blurRadius: 6,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: hasValidNetworkCover
            ? Image.network(
                coverUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    _buildStylizedCover(cleanTitle, palette),
              )
            : _buildStylizedCover(cleanTitle, palette),
      ),
    );
  }

  Widget _buildStylizedCover(String cleanTitle, List<Color> palette) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : (width.isFinite ? width : 52.0);
        final h = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : (height.isFinite ? height : 72.0);

        final verticalChars = cleanTitle.characters.take(5).toList();
        final isCompact = h < 80.0;
        final titleFontSize = isCompact
            ? (w * 0.22).clamp(10.0, 13.0)
            : (w * 0.17).clamp(13.0, 18.0);
        final authorFontSize = isCompact ? 8.0 : 9.5;
        final spineWidth = (w * 0.08).clamp(5.0, 10.0);

        return Stack(
          children: [
            // 1. 底色双色皮质深邃渐变
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: palette,
                  ),
                ),
              ),
            ),

            // 2. 几何水印微光 (几何印章感)
            Positioned(
              top: -w * 0.3,
              right: -w * 0.2,
              child: Container(
                width: w * 0.95,
                height: w * 0.95,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),

            // 3. 仿真立体书脊侧光折射 (Book Spine Lighting)
            Positioned(
              key: const ValueKey('book_spine_lighting'),
              left: 0,
              top: 0,
              bottom: 0,
              width: spineWidth,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withValues(alpha: 0.32),
                      Colors.white.withValues(alpha: 0.22),
                      Colors.black.withValues(alpha: 0.10),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.35, 0.75, 1.0],
                  ),
                ),
              ),
            ),

            // 4. 顶部温润斜切漫射光 (Subtle Sheen)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    stops: const [0.0, 0.45, 0.8],
                    colors: [
                      Colors.white.withValues(alpha: 0.18),
                      Colors.white.withValues(alpha: 0.04),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // 5. 顶部胶囊标签 (Pill Badge)
            if (badgeText != null && badgeText!.isNotEmpty && !isCompact)
              Positioned(
                top: 5.0,
                left: spineWidth + 1.0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5.5,
                    vertical: 2.0,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.38),
                    borderRadius: BorderRadius.circular(999.0),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    badgeText!,
                    style: const TextStyle(
                      fontSize: 7.5,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),

            // 6. 纵向中文书名 (Vertical Typography)
            Center(
              child: Padding(
                padding: EdgeInsets.only(
                  left: spineWidth * 0.5,
                  top: isCompact ? 3.0 : 8.0,
                  bottom: isCompact ? 12.0 : 20.0,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final char in verticalChars)
                        Text(
                          char,
                          style: TextStyle(
                            fontSize: titleFontSize,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.05,
                            letterSpacing: 1.2,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                offset: const Offset(0, 1.5),
                                blurRadius: 4.0,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // 7. 底部作者姓名
            Positioned(
              left: spineWidth + 1.0,
              right: 4.0,
              bottom: isCompact ? 3.5 : 6.0,
              child: Text(
                author.isNotEmpty ? author : '网络文学',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: authorFontSize,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.88),
                  letterSpacing: 0.4,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      offset: const Offset(0, 1),
                      blurRadius: 2.0,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
