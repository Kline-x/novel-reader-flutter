import 'dart:async';
import 'package:flutter/material.dart';

import '../../../core/components/soft_card.dart';
import '../../../core/theme/soft_theme.dart';
import '../models/tts_state.dart';
import '../services/tts_service.dart';

/// Modern Soft UI 听书控制弹窗
class TtsControlSheet extends StatefulWidget {
  const TtsControlSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const TtsControlSheet(),
    );
  }

  @override
  State<TtsControlSheet> createState() => _TtsControlSheetState();
}

class _TtsControlSheetState extends State<TtsControlSheet> {
  final TtsService _ttsService = TtsService();
  StreamSubscription<TtsPlaybackInfo>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = _ttsService.playbackStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = SoftTheme.of(context);
    final isPlaying = _ttsService.isPlaying;
    final bookTitle = _ttsService.bookTitle;
    final chapterTitle = _ttsService.chapterTitle;
    final currentText = _ttsService.currentSentence?.text ?? '准备就绪，点击播放开启听书';
    final curIdx = _ttsService.currentSentenceIndex;
    final total = _ttsService.totalSentences;
    final speed = _ttsService.speechRate;
    final timer = _ttsService.timerOption;
    final remainingSecs = _ttsService.remainingTimerSeconds;

    return Container(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28.0)),
        boxShadow: SoftDecorations.softShadows(colors, elevation: 3.0),
      ),
      padding: EdgeInsets.only(
        top: 12.0,
        left: 20.0,
        right: 20.0,
        bottom: MediaQuery.of(context).padding.bottom + 20.0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 顶部拖拽条
          Center(
            child: Container(
              width: 36.0,
              height: 4.0,
              decoration: BoxDecoration(
                color: colors.textSecondary.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2.0),
              ),
            ),
          ),
          const SizedBox(height: 16.0),

          // 顶栏：标题与关闭按钮
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.headphones_rounded,
                  color: colors.accent,
                  size: 20.0,
                ),
              ),
              const SizedBox(width: 10.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bookTitle.isNotEmpty ? bookTitle : '听书模式',
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      chapterTitle.isNotEmpty ? chapterTitle : '语音播报',
                      style: TextStyle(
                        fontSize: 12.0,
                        color: colors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (remainingSecs > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                  margin: const EdgeInsets.only(right: 8.0),
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(10.0),
                    border: Border.all(color: colors.accent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timer_outlined, size: 12.0, color: colors.accent),
                      const SizedBox(width: 4.0),
                      Text(
                        '${(remainingSecs ~/ 60).toString().padLeft(2, '0')}:${(remainingSecs % 60).toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 11.0,
                          fontWeight: FontWeight.bold,
                          color: colors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(6.0),
                  decoration: BoxDecoration(
                    color: colors.card,
                    shape: BoxShape.circle,
                    boxShadow: SoftDecorations.softShadows(colors, elevation: 0.5),
                  ),
                  child: Icon(Icons.close_rounded, size: 18.0, color: colors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18.0),

          // 当前朗读语句卡片（柔和浮雕卡片）
          SoftCard(
            colors: colors,
            padding: const EdgeInsets.all(16.0),
            radius: 18.0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '正在朗读',
                      style: TextStyle(
                        fontSize: 11.0,
                        fontWeight: FontWeight.bold,
                        color: colors.accent,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      total > 0 ? '${curIdx + 1} / $total 句' : '0 / 0 句',
                      style: TextStyle(
                        fontSize: 11.0,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8.0),
                Text(
                  currentText,
                  style: TextStyle(
                    fontSize: 15.0,
                    height: 1.6,
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14.0),

          // 进度调节滑块
          if (total > 0)
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: colors.accent,
                inactiveTrackColor: colors.accent.withValues(alpha: 0.15),
                thumbColor: colors.accent,
                trackHeight: 3.5,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12.0),
              ),
              child: Slider(
                value: curIdx.toDouble().clamp(0.0, (total - 1).toDouble()),
                min: 0.0,
                max: (total - 1).toDouble().clamp(0.0, double.infinity),
                onChanged: (val) {
                  _ttsService.seekToSentence(val.toInt());
                },
              ),
            ),

          // 播控操作按钮排（上一句 / 播放-暂停 / 下一句）
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 停止
              IconButton(
                key: const ValueKey('tts_stop_btn'),
                icon: const Icon(Icons.stop_circle_outlined, size: 28.0),
                color: colors.textSecondary,
                onPressed: () => _ttsService.stop(),
              ),
              const SizedBox(width: 16.0),
              // 上一句
              IconButton(
                key: const ValueKey('tts_prev_btn'),
                icon: const Icon(Icons.skip_previous_rounded, size: 34.0),
                color: colors.textPrimary,
                onPressed: () => _ttsService.seekPrev(),
              ),
              const SizedBox(width: 16.0),
              // 播放/暂停 大软按钮
              GestureDetector(
                key: const ValueKey('tts_play_pause_btn'),
                onTap: () => _ttsService.togglePlayPause(),
                child: Container(
                  width: 64.0,
                  height: 64.0,
                  decoration: BoxDecoration(
                    color: colors.accent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: colors.accent.withValues(alpha: 0.35),
                        offset: const Offset(0, 4),
                        blurRadius: 12.0,
                      ),
                    ],
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 34.0,
                  ),
                ),
              ),
              const SizedBox(width: 16.0),
              // 下一句
              IconButton(
                key: const ValueKey('tts_next_btn'),
                icon: const Icon(Icons.skip_next_rounded, size: 34.0),
                color: colors.textPrimary,
                onPressed: () => _ttsService.seekNext(),
              ),
              const SizedBox(width: 16.0),
              // 重听当前句
              IconButton(
                key: const ValueKey('tts_replay_btn'),
                icon: const Icon(Icons.replay_rounded, size: 26.0),
                color: colors.textSecondary,
                onPressed: () => _ttsService.seekToSentence(curIdx),
              ),
            ],
          ),
          const SizedBox(height: 20.0),

          // 语速倍率调节
          Row(
            children: [
              Text(
                '语速',
                style: TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.bold,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [0.8, 1.0, 1.25, 1.5, 2.0].map((rate) {
                    final isSelected = (speed - rate).abs() < 0.05;
                    return GestureDetector(
                      key: ValueKey('tts_rate_${rate}x'),
                      onTap: () => _ttsService.setSpeechRate(rate),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                        decoration: BoxDecoration(
                          color: isSelected ? colors.accent : colors.card,
                          borderRadius: BorderRadius.circular(10.0),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: colors.accent.withValues(alpha: 0.3),
                                    blurRadius: 4.0,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : SoftDecorations.softShadows(colors, elevation: 0.5),
                        ),
                        child: Text(
                          '${rate}x',
                          style: TextStyle(
                            fontSize: 11.0,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.white : colors.textPrimary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14.0),

          // 定时关闭
          Row(
            children: [
              Text(
                '定时',
                style: TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.bold,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: TtsTimerOption.values.map((opt) {
                    final isSelected = timer == opt;
                    return GestureDetector(
                      key: ValueKey('tts_timer_${opt.name}'),
                      onTap: () => _ttsService.setTimer(opt),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
                        decoration: BoxDecoration(
                          color: isSelected ? colors.accent : colors.card,
                          borderRadius: BorderRadius.circular(10.0),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: colors.accent.withValues(alpha: 0.3),
                                    blurRadius: 4.0,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : SoftDecorations.softShadows(colors, elevation: 0.5),
                        ),
                        child: Text(
                          opt.label,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.white : colors.textPrimary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
