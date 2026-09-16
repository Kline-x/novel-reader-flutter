import 'dart:async';
import 'package:flutter/material.dart';

import '../../../core/theme/soft_theme.dart';
import '../models/tts_state.dart';
import '../services/tts_service.dart';
import 'tts_control_sheet.dart';

/// 听书悬浮迷你播放胶囊 (Floating Mini Player)
class TtsMiniPlayer extends StatefulWidget {
  const TtsMiniPlayer({super.key});

  @override
  State<TtsMiniPlayer> createState() => _TtsMiniPlayerState();
}

class _TtsMiniPlayerState extends State<TtsMiniPlayer>
    with SingleTickerProviderStateMixin {
  final TtsService _ttsService = TtsService();
  StreamSubscription<TtsPlaybackInfo>? _sub;
  late AnimationController _waveController;

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

    final colors = SoftTheme.of(context);
    final isPlaying = _ttsService.isPlaying;
    final sentenceText = _ttsService.currentSentence?.text ?? _ttsService.chapterTitle;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: GestureDetector(
        key: const ValueKey('tts_mini_player_tap'),
        onTap: () => TtsControlSheet.show(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(22.0),
            border: Border.all(
              color: colors.accent.withValues(alpha: 0.25),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.accent.withValues(alpha: 0.15),
                blurRadius: 16.0,
                offset: const Offset(0, 6),
              ),
              ...SoftDecorations.softShadows(colors, elevation: 1.5),
            ],
          ),
          child: Row(
            children: [
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
                          color: colors.accent,
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
                        color: colors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${_ttsService.chapterTitle} · ${_ttsService.speechRate}x 语速',
                      style: TextStyle(
                        fontSize: 10.0,
                        color: colors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8.0),

              // 播放/暂停
              GestureDetector(
                key: const ValueKey('tts_mini_toggle'),
                onTap: () => _ttsService.togglePlayPause(),
                child: Container(
                  padding: const EdgeInsets.all(6.0),
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: colors.accent,
                    size: 18.0,
                  ),
                ),
              ),
              const SizedBox(width: 6.0),

              // 关闭停止
              GestureDetector(
                key: const ValueKey('tts_mini_close'),
                onTap: () => _ttsService.stop(),
                child: Container(
                  padding: const EdgeInsets.all(6.0),
                  decoration: BoxDecoration(
                    color: colors.background,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    color: colors.textSecondary,
                    size: 16.0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
