import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_reader_flutter/features/tts/models/tts_state.dart';
import 'package:novel_reader_flutter/features/tts/presentation/tts_control_sheet.dart';
import 'package:novel_reader_flutter/features/tts/presentation/tts_mini_player.dart';
import 'package:novel_reader_flutter/features/tts/services/tts_sentence_splitter.dart';
import 'package:novel_reader_flutter/features/tts/services/tts_service.dart';

void main() {
  group('阶段 11：听书 TTS 引擎与标点断句测试', () {
    test('TtsSentenceSplitter 中文标点分句与引号闭合保真测试', () {
      const content = '''
      第一章 山边小村。
      “韩立，你在看什么？”母亲温和地问道。
      “没什么，只是有些出神！”
      青牛镇依山傍水；风景秀丽；真是一处好地方！
      ''';

      final sentences = TtsSentenceSplitter.split(content);
      expect(sentences.isNotEmpty, isTrue);

      // 验证首句
      expect(sentences[0].text, equals('第一章 山边小村。'));
      // 验证引号包围的句子是否完整归拢
      expect(sentences[1].text, contains('“韩立，你在看什么？”'));
      expect(sentences[2].text, contains('母亲温和地问道。'));
      expect(sentences[3].text, contains('“没什么，只是有些出神！”'));

      // 验证字符偏移范围严格递增
      for (int i = 0; i < sentences.length; i++) {
        final s = sentences[i];
        expect(s.startIndex, lessThan(s.endIndex));
        if (i > 0) {
          expect(s.startIndex, greaterThanOrEqualTo(sentences[i - 1].endIndex));
        }
      }
    });

    test('TtsSentenceSplitter 空文本与极端空白过滤测试', () {
      expect(TtsSentenceSplitter.split(''), isEmpty);
      expect(TtsSentenceSplitter.split('   \n\t  \n  '), isEmpty);
    });

    test('TtsService 状态机流转与语速/音调配置测试', () async {
      final tts = TtsService();

      expect(tts.playState, equals(TtsPlayState.stopped));
      expect(tts.isStopped, isTrue);

      // 语速设置
      await tts.setSpeechRate(1.25);
      expect(tts.speechRate, equals(1.25));

      // 音调设置
      await tts.setPitch(1.1);
      expect(tts.pitch, equals(1.1));

      // 睡眠定时器设置
      tts.setTimer(TtsTimerOption.m15);
      expect(tts.timerOption, equals(TtsTimerOption.m15));
      expect(tts.remainingTimerSeconds, equals(15 * 60));

      tts.setTimer(TtsTimerOption.none);
      expect(tts.timerOption, equals(TtsTimerOption.none));
      expect(tts.remainingTimerSeconds, equals(0));

      // 播完本章选项
      tts.setTimer(TtsTimerOption.chapterEnd);
      expect(tts.timerOption, equals(TtsTimerOption.chapterEnd));
    });
  });

  group('阶段 11：Modern Soft UI 听书控制弹窗与悬浮胶囊组件测试', () {
    testWidgets('TtsControlSheet 挂载与按键触控测试', (tester) async {
      final tts = TtsService();
      // 初始化状态模拟
      await tts.playChapter(
        bookId: 'test_book_tts',
        bookTitle: '凡人修仙传',
        chapterIndex: 0,
        chapterTitle: '第一章 山边小村',
        content: '青牛镇五里沟是一个依山傍水的小山村。这一年韩立十岁。',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => TtsControlSheet.show(ctx),
                child: const Text('Open TTS'),
              ),
            ),
          ),
        ),
      );

      // 点击打开弹窗
      await tester.tap(find.text('Open TTS'));
      await tester.pumpAndSettle();

      // 验证弹窗元素
      expect(find.text('凡人修仙传'), findsOneWidget);
      expect(find.text('第一章 山边小村'), findsOneWidget);
      expect(find.text('正在朗读'), findsOneWidget);

      // 验证操作按钮挂载
      expect(find.byKey(const ValueKey('tts_play_pause_btn')), findsOneWidget);
      expect(find.byKey(const ValueKey('tts_prev_btn')), findsOneWidget);
      expect(find.byKey(const ValueKey('tts_next_btn')), findsOneWidget);
      expect(find.byKey(const ValueKey('tts_stop_btn')), findsOneWidget);

      // 验证语速胶囊
      expect(find.byKey(const ValueKey('tts_rate_1.25x')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('tts_rate_1.25x')));
      await tester.pump();
      expect(tts.speechRate, equals(1.25));

      // 验证定时器胶囊
      expect(find.byKey(const ValueKey('tts_timer_m15')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('tts_timer_m15')));
      await tester.pump();
      expect(tts.timerOption, equals(TtsTimerOption.m15));

      // 停止服务
      await tts.stop();
    });

    testWidgets('TtsMiniPlayer 显隐生命周期与点击交互测试', (tester) async {
      final tts = TtsService();
      await tts.stop();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TtsMiniPlayer(),
          ),
        ),
      );

      // 未启动时应为空
      expect(find.byKey(const ValueKey('tts_mini_player_tap')), findsNothing);

      // 模拟启动播放
      await tts.playChapter(
        bookId: 'test_book_tts',
        bookTitle: '凡人修仙传',
        chapterIndex: 0,
        chapterTitle: '第一章 山边小村',
        content: '韩立背着包裹上山。',
      );
      await tester.pump();

      // 激活时应可见
      expect(find.byKey(const ValueKey('tts_mini_player_tap')), findsOneWidget);
      expect(find.byKey(const ValueKey('tts_mini_toggle')), findsOneWidget);
      expect(find.byKey(const ValueKey('tts_mini_close')), findsOneWidget);

      // 点击关闭
      await tester.tap(find.byKey(const ValueKey('tts_mini_close')));
      await tester.pump();
      expect(tts.isStopped, isTrue);
    });
  });
}
