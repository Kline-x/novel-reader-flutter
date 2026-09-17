import 'package:flutter/material.dart';

/// 高保真书籍封面组件 (BookCoverWidget)
/// 严格 1:1 对齐原型 scheme-v2-impl.html 中 .cover 及 cvr-1~cvr-9 规范：
/// - 9 组双色撞色渐变色场 + 几何母题装饰
/// - 斜切光泽高光 (Glossy Sheen)
/// - 书脊立体反光条 (Spine Highlight)
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
    this.borderRadius = 10.0,
    this.showShadow = true,
    this.paletteIndex,
  });

  /// 9 组原型色板
  static const List<List<Color>> coverPalettes = [
    [Color(0xFF0E7490), Color(0xFF06B6D4)], // cvr-1 青蓝
    [Color(0xFFF97316), Color(0xFFDC2626)], // cvr-2 橙红
    [Color(0xFFF59E0B), Color(0xFFEF4444)], // cvr-3 琥珀赤
    [Color(0xFFFACC15), Color(0xFF8B5CF6)], // cvr-4 黄紫撞色
    [Color(0xFF34D399), Color(0xFF059669)], // cvr-5 碧绿
    [Color(0xFF1E3A8A), Color(0xFF6D28D9)], // cvr-6 靛蓝深紫
    [Color(0xFF84CC16), Color(0xFF0F766E)], // cvr-7 草绿蓝青
    [Color(0xFF334155), Color(0xFF4F46E5)], // cvr-8 灰蓝紫
    [Color(0xFF111827), Color(0xFF2563EB)], // cvr-9 极夜宝蓝
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

    final bool hasValidNetworkCover =
        coverUrl != null && coverUrl!.isNotEmpty && coverUrl!.startsWith('http');

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: const Color(0xFF14161B).withValues(alpha: 0.22),
                  offset: const Offset(0, 4),
                  blurRadius: 10,
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
                errorBuilder: (_, __, ___) => _buildStylizedCover(cleanTitle, palette),
              )
            : _buildStylizedCover(cleanTitle, palette),
      ),
    );
  }

  Widget _buildStylizedCover(String cleanTitle, List<Color> palette) {
    // 竖排字符（最多展示 5 个字）
    final verticalChars = cleanTitle.characters.take(5).toList();
    final isCompact = height < 80.0;
    final titleFontSize = isCompact ? (width * 0.22).clamp(10.0, 13.0) : (width * 0.17).clamp(13.0, 18.0);
    final authorFontSize = isCompact ? 8.0 : 9.5;

    return Stack(
      children: [
        // 1. 底色双色色场渐变
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

        // 2. 几何母题半透明光晕装饰
        Positioned(
          top: -width * 0.3,
          right: -width * 0.2,
          child: Container(
            width: width * 0.9,
            height: width * 0.9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.14),
            ),
          ),
        ),

        // 3. 左侧书脊立体高光 (Spine Highlight)
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: (width * 0.08).clamp(3.0, 8.0),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.white.withValues(alpha: 0.45),
                  Colors.white.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),

        // 4. 顶部光泽斜切高光 (Sheen)
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: const [0.0, 0.4, 0.7],
                colors: [
                  Colors.white.withValues(alpha: 0.28),
                  Colors.white.withValues(alpha: 0.06),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // 5. 顶部标签（如有）
        if (badgeText != null && badgeText!.isNotEmpty && !isCompact)
          Positioned(
            top: 5.0,
            left: 5.0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(99.0),
              ),
              child: Text(
                badgeText!,
                style: const TextStyle(
                  fontSize: 7.5,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

        // 6. 纵向中文书名 (Vertical Chinese Typography)
        Center(
          child: Padding(
            padding: EdgeInsets.only(
              top: isCompact ? 4.0 : 8.0,
              bottom: isCompact ? 14.0 : 20.0,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final char in verticalChars)
                  Text(
                    char,
                    style: TextStyle(
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.05,
                      letterSpacing: 1.0,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.4),
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

        // 7. 底部作者姓名居中
        Positioned(
          left: 3.0,
          right: 3.0,
          bottom: isCompact ? 3.5 : 6.0,
          child: Text(
            author.isNotEmpty ? author : '网络文学',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: authorFontSize,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.92),
              letterSpacing: 0.4,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  offset: const Offset(0, 1),
                  blurRadius: 2.0,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
