import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../models/tts_state.dart';
import 'tts_sentence_splitter.dart';

/// 听书自然语音合成服务
class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  FlutterTts? _flutterTts;
  bool _isInitialized = false;
  bool get _isTestMode => Platform.environment.containsKey('FLUTTER_TEST');

  // 播放状态与元数据
  TtsPlayState _playState = TtsPlayState.stopped;
  String _bookId = '';
  String _bookTitle = '';
  int _chapterIndex = 0;
  String _chapterTitle = '';
  List<TtsSentence> _sentences = [];
  int _currentSentenceIndex = 0;

  // 语速与音调
  double _speechRate = 1.0; // 0.5 ~ 2.0，展示值；传给 flutter_tts 需适配平台倍率
  double _pitch = 1.0; // 0.5 ~ 1.5

  // 睡眠定时器
  TtsTimerOption _timerOption = TtsTimerOption.none;
  int _remainingTimerSeconds = 0;
  Timer? _countdownTimer;

  // 广播控制器
  final StreamController<TtsPlaybackInfo> _playbackController =
      StreamController<TtsPlaybackInfo>.broadcast();
  Stream<TtsPlaybackInfo> get playbackStream => _playbackController.stream;

  // 章节完成回调（通知外部加载下一章并接着播）
  Future<void> Function()? onChapterComplete;
  // 句子跳变回调（供外部排版视口高亮）
  void Function(TtsSentence sentence)? onSentenceChanged;

  // Getters
  TtsPlayState get playState => _playState;
  bool get isPlaying => _playState == TtsPlayState.playing;
  bool get isPaused => _playState == TtsPlayState.paused;
  bool get isStopped => _playState == TtsPlayState.stopped;
  bool get isActive => _playState != TtsPlayState.stopped;
  String get bookId => _bookId;
  String get bookTitle => _bookTitle;
  int get chapterIndex => _chapterIndex;
  String get chapterTitle => _chapterTitle;
  int get currentSentenceIndex => _currentSentenceIndex;
  int get totalSentences => _sentences.length;
  double get speechRate => _speechRate;
  double get pitch => _pitch;
  TtsTimerOption get timerOption => _timerOption;
  int get remainingTimerSeconds => _remainingTimerSeconds;
  TtsSentence? get currentSentence =>
      _sentences.isNotEmpty && _currentSentenceIndex < _sentences.length
          ? _sentences[_currentSentenceIndex]
          : null;

  /// 初始化原生 TTS 实例
  Future<void> init() async {
    if (_isInitialized) return;

    if (_isTestMode) {
      _isInitialized = true;
      return;
    }

    try {
      _flutterTts = FlutterTts();
      await _flutterTts!.setLanguage('zh-CN');
      await _applySpeechRate(_speechRate);
      await _flutterTts!.setPitch(_pitch);

      _flutterTts!.setStartHandler(() {
        _playState = TtsPlayState.playing;
        _notify();
      });

      _flutterTts!.setCompletionHandler(() {
        _onSentenceFinished();
      });

      _flutterTts!.setErrorHandler((msg) {
        debugPrint('[TtsService] TTS error: $msg');
        // 出错时尝试跳到下一句，避免卡死
        _onSentenceFinished();
      });

      _flutterTts!.setPauseHandler(() {
        _playState = TtsPlayState.paused;
        _notify();
      });

      _flutterTts!.setContinueHandler(() {
        _playState = TtsPlayState.playing;
        _notify();
      });

      _flutterTts!.setCancelHandler(() {
        if (_playState == TtsPlayState.playing) {
          _playState = TtsPlayState.paused;
          _notify();
        }
      });

      _isInitialized = true;
    } catch (e) {
      debugPrint('[TtsService] Init error: $e');
    }
  }

  /// 适配 flutter_tts 跨端语速比例
  Future<void> _applySpeechRate(double rate) async {
    if (_flutterTts == null) return;
    try {
      // flutter_tts 在 Android 上 1.0 为正常语速，iOS 上 0.5 为正常语速
      // 统一折算：默认 1.0 时传给 setSpeechRate 0.5 (iOS) 或 1.0 (Android)
      double ttsRate = rate;
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        ttsRate = rate * 0.5;
      }
      await _flutterTts!.setSpeechRate(ttsRate.clamp(0.1, 2.0));
    } catch (_) {}
  }

  /// 开始朗读指定章节
  Future<void> playChapter({
    required String bookId,
    required String bookTitle,
    required int chapterIndex,
    required String chapterTitle,
    required String content,
    int startSentenceIndex = 0,
  }) async {
    await init();

    _bookId = bookId;
    _bookTitle = bookTitle;
    _chapterIndex = chapterIndex;
    _chapterTitle = chapterTitle;
    _sentences = TtsSentenceSplitter.split(content);
    _currentSentenceIndex = startSentenceIndex.clamp(
        0, _sentences.isEmpty ? 0 : _sentences.length - 1);

    if (_sentences.isEmpty) {
      debugPrint('[TtsService] Content is empty, cannot play.');
      return;
    }

    _playState = TtsPlayState.playing;
    _speakCurrentSentence();
  }

  /// 朗读当前索引的句子
  Future<void> _speakCurrentSentence() async {
    if (_sentences.isEmpty || _currentSentenceIndex >= _sentences.length) {
      _handleChapterCompletion();
      return;
    }

    final sentence = _sentences[_currentSentenceIndex];
    onSentenceChanged?.call(sentence);
    _notify();

    if (_flutterTts != null && !_isTestMode) {
      try {
        await _flutterTts!.speak(sentence.text);
      } catch (e) {
        debugPrint('[TtsService] Speak error: $e');
        _onSentenceFinished();
      }
    }
  }

  /// 单句朗读完成
  void _onSentenceFinished() {
    if (_playState != TtsPlayState.playing) return;

    if (_currentSentenceIndex + 1 < _sentences.length) {
      _currentSentenceIndex++;
      _speakCurrentSentence();
    } else {
      _handleChapterCompletion();
    }
  }

  /// 章节朗读完结处理
  void _handleChapterCompletion() {
    // 检查是否设置了「播完本章」
    if (_timerOption == TtsTimerOption.chapterEnd) {
      stop();
      return;
    }

    if (onChapterComplete != null) {
      onChapterComplete!();
    } else {
      stop();
    }
  }

  /// 暂停朗读
  Future<void> pause() async {
    if (_playState != TtsPlayState.playing) return;
    _playState = TtsPlayState.paused;
    if (_flutterTts != null) {
      try {
        await _flutterTts!.pause();
      } catch (_) {
        await _flutterTts!.stop();
      }
    }
    _notify();
  }

  /// 恢复朗读
  Future<void> resume() async {
    if (_playState != TtsPlayState.paused) return;
    _playState = TtsPlayState.playing;
    _speakCurrentSentence();
  }

  /// 播放/暂停切换
  Future<void> togglePlayPause() async {
    if (_playState == TtsPlayState.playing) {
      await pause();
    } else if (_playState == TtsPlayState.paused) {
      await resume();
    } else if (_sentences.isNotEmpty) {
      _playState = TtsPlayState.playing;
      await _speakCurrentSentence();
    }
  }

  /// 停止朗读并复位
  Future<void> stop() async {
    _playState = TtsPlayState.stopped;
    _cancelTimer();
    if (_flutterTts != null) {
      try {
        await _flutterTts!.stop();
      } catch (_) {}
    }
    _notify();
  }

  /// 下一句
  Future<void> seekNext() async {
    if (_sentences.isEmpty) return;
    if (_currentSentenceIndex + 1 < _sentences.length) {
      _currentSentenceIndex++;
      if (_playState == TtsPlayState.playing) {
        if (_flutterTts != null) await _flutterTts!.stop();
        _speakCurrentSentence();
      } else {
        onSentenceChanged?.call(_sentences[_currentSentenceIndex]);
        _notify();
      }
    } else {
      _handleChapterCompletion();
    }
  }

  /// 上一句
  Future<void> seekPrev() async {
    if (_sentences.isEmpty) return;
    if (_currentSentenceIndex > 0) {
      _currentSentenceIndex--;
      if (_playState == TtsPlayState.playing) {
        if (_flutterTts != null) await _flutterTts!.stop();
        _speakCurrentSentence();
      } else {
        onSentenceChanged?.call(_sentences[_currentSentenceIndex]);
        _notify();
      }
    }
  }

  /// 跳转至指定句子
  Future<void> seekToSentence(int index) async {
    if (index < 0 || index >= _sentences.length) return;
    _currentSentenceIndex = index;
    if (_playState == TtsPlayState.playing) {
      if (_flutterTts != null) await _flutterTts!.stop();
      _speakCurrentSentence();
    } else {
      onSentenceChanged?.call(_sentences[_currentSentenceIndex]);
      _notify();
    }
  }

  /// 调节语速 (0.5 ~ 2.0)
  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate;
    await _applySpeechRate(_speechRate);
    _notify();
  }

  /// 调节音调 (0.5 ~ 1.5)
  Future<void> setPitch(double pitch) async {
    _pitch = pitch;
    if (_flutterTts != null) {
      try {
        await _flutterTts!.setPitch(pitch);
      } catch (_) {}
    }
    _notify();
  }

  /// 设置睡眠定时器
  void setTimer(TtsTimerOption option) {
    _timerOption = option;
    _cancelTimer();

    if (option == TtsTimerOption.none || option == TtsTimerOption.chapterEnd) {
      _remainingTimerSeconds = 0;
      _notify();
      return;
    }

    _remainingTimerSeconds = option.minutes * 60;
    _notify();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTimerSeconds > 0) {
        _remainingTimerSeconds--;
        _notify();
      } else {
        _cancelTimer();
        stop();
      }
    });
  }

  void _cancelTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  void _notify() {
    if (_playbackController.isClosed) return;
    _playbackController.add(TtsPlaybackInfo(
      state: _playState,
      bookId: _bookId,
      bookTitle: _bookTitle,
      chapterIndex: _chapterIndex,
      chapterTitle: _chapterTitle,
      currentSentence: currentSentence?.text ?? '',
      sentenceIndex: _currentSentenceIndex,
      totalSentences: _sentences.length,
      speechRate: _speechRate,
      pitch: _pitch,
      timerOption: _timerOption,
      remainingTimerSeconds: _remainingTimerSeconds,
    ));
  }

  void dispose() {
    _cancelTimer();
    _flutterTts?.stop();
    _playbackController.close();
  }
}
