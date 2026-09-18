import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';

import '../models/tts_state.dart';
import '../services/tts_service.dart';
import 'tts_control_sheet.dart';

/// 听书悬浮迷你播放胶囊 (Floating Mini Player)
/// 具备深浅主题微透毛玻璃自适应与防遮挡拖拽能力
class TtsMiniPlayer extends StatefulWidget {
  final bool isDark;
  final double? offsetY;
  final ValueChanged<double>? onOffsetYChanged;

  const TtsMiniPlayer({
    super.key,
    this.isDark = false,
    this.offsetY,
    this.onOffsetYChanged,
  });

  @override
  State<TtsMiniPlayer> createState() => _TtsMiniPlayerState();
}

class _TtsMiniPlayerState extends State<TtsMiniPlayer>
    with SingleTickerProviderStateMixin {
  final TtsService _ttsService = TtsService();
  StreamSubscription<TtsPlaybackInfo>? _sub;
  late AnimationController _waveController;
  double _dragOffsetY = 0.0;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _sub = _ttsService.playbackStream.listen((_) {
      if (mounted) {
        _syncWaveAnimation();
        setState(() {});
      }
    });
    _syncWaveAnimation();
  }

  void _syncWaveAnimation() {
    if (_ttsService.isPlaying) {
      if (!_waveController.isAnimating) {
        _waveController.repeat(reverse: true);
      }
    } else {
      if (_waveController.isAnimating) {
        _waveController.stop();
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ttsService.isActive) {
      return const SizedBox.shrink();
    }

    final isDark = widget.isDark;
    final isPlaying = _ttsService.isPlaying;
    final sentenceText =
        _ttsService.currentSentence?.text ?? _ttsService.chapterTitle;

    final cardBg = isDark
        ? const Color(0xFF1E2024).withValues(alpha: 0.88)
        : Colors.white.withValues(alpha: 0.94);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.15)
        : const Color(0xFF07C160).withValues(alpha: 0.25);
    final textPrimary = isDark ? Colors.white : const Color(0xFF14161B);
    final textSecondary = isDark ? Colors.white70 : const Color(0xFF6E7480);
    const accentColor = Color(0xFF07C160);
    final closeBtnBg = isDark ? Colors.white12 : const Color(0xFFF5F4F1);

    final Widget content = Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: GestureDetector(
        key: const ValueKey('tts_mini_player_tap'),
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (details) {
          if (widget.onOffsetYChanged != null) {
            final cur = widget.offsetY ?? 0.0;
            final next = (cur - details.delta.dy).clamp(-20.0, 380.0);
            widget.onOffsetYChanged!(next);
          } else {
            setState(() {
              // 允许向上拖动避让底部滑块或电量，最大向上位移 360dp，向下缓冲 60dp
              _dragOffsetY =
                  (_dragOffsetY + details.delta.dy).clamp(-360.0, 60.0);
            });
          }
        },
        onTap: () => TtsControlSheet.show(context, isDark: isDark),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22.0),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(22.0),
                border: Border.all(
                  color: borderColor,
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black45
                        : accentColor.withValues(alpha: 0.15),
                    blurRadius: 16.0,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // 拖拽手柄指示点
                  Container(
                    margin: const EdgeInsets.only(right: 8.0),
                    child: Icon(
                      Icons.drag_indicator_rounded,
                      size: 14.0,
                      color: textSecondary.withValues(alpha: 0.4),
                    ),
                  ),

                  // 动态音波律动条
                  AnimatedBuilder(
                    animation: _waveController,
                    builder: (context, _) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(4, (i) {
                          final double factor = isPlaying
                              ? ((_waveController.value + i * 0.25) % 1.0)
                              : 0.2;
                          final double barHeight = 6.0 + factor * 12.0;
                          return Container(
                            margin: const EdgeInsets.only(right: 2.5),
                            width: 3.0,
                            height: barHeight,
                            decoration: BoxDecoration(
                              color: accentColor,
                              borderRadius: BorderRadius.circular(1.5),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                  const SizedBox(width: 8.0),

                  // 正在播报的内容摘要
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          sentenceText,
                          style: TextStyle(
                            fontSize: 12.0,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${_ttsService.chapterTitle} · ${_ttsService.speechRate}x 语速 (按住可上下拖拽)',
                          style: TextStyle(
                            fontSize: 10.0,
                            color: textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4.0),

                  // 播放/暂停 (具备44dp舒适触控热区与显式opaque命中)
                  GestureDetector(
                    key: const ValueKey('tts_mini_toggle'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _ttsService.togglePlayPause(),
                    child: Container(
                      width: 44.0,
                      height: 44.0,
                      alignment: Alignment.center,
                      child: Container(
                        width: 32.0,
                        height: 32.0,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: accentColor,
                          size: 20.0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 2.0),

                  // 关闭停止 (具备44dp舒适触控热区与显式opaque命中)
                  GestureDetector(
                    key: const ValueKey('tts_mini_close'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _ttsService.stop(),
                    child: Container(
                      width: 44.0,
                      height: 44.0,
                      alignment: Alignment.center,
                      child: Container(
                        width: 32.0,
                        height: 32.0,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: closeBtnBg,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          color: textSecondary,
                          size: 18.0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (widget.onOffsetYChanged != null) {
      return content;
    }

    return Transform.translate(
      offset: Offset(0, _dragOffsetY),
      child: content,
    );
  }
}
