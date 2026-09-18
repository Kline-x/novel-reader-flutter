/// TTS 播放状态
enum TtsPlayState {
  stopped,
  playing,
  paused,
}

/// 定时关闭选项
enum TtsTimerOption {
  none(0, '关闭'),
  m15(15, '15分钟'),
  m30(30, '30分钟'),
  m60(60, '60分钟'),
  chapterEnd(-1, '播完本章');

  final int minutes;
  final String label;
  const TtsTimerOption(this.minutes, this.label);
}

/// TTS 实时播放广播包
class TtsPlaybackInfo {
  final TtsPlayState state;
  final String bookId;
  final String bookTitle;
  final int chapterIndex;
  final String chapterTitle;
  final String currentSentence;
  final int sentenceIndex;
  final int totalSentences;
  final double speechRate;
  final double pitch;
  final TtsTimerOption timerOption;
  final int remainingTimerSeconds;

  const TtsPlaybackInfo({
    required this.state,
    required this.bookId,
    required this.bookTitle,
    required this.chapterIndex,
    required this.chapterTitle,
    required this.currentSentence,
    required this.sentenceIndex,
    required this.totalSentences,
    required this.speechRate,
    required this.pitch,
    required this.timerOption,
    required this.remainingTimerSeconds,
  });

  bool get isPlaying => state == TtsPlayState.playing;
  bool get isPaused => state == TtsPlayState.paused;
  bool get isStopped => state == TtsPlayState.stopped;
  bool get isActive => state != TtsPlayState.stopped;

  double get progress =>
      totalSentences > 0 ? (sentenceIndex + 1) / totalSentences : 0.0;
}
