import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_reader_flutter/features/notes/models/annotation.dart';
import 'package:novel_reader_flutter/features/notes/presentation/add_annotation_dialog.dart';
import 'package:novel_reader_flutter/features/local_books/services/txt_parser_engine.dart';
import 'package:novel_reader_flutter/features/reader/presentation/typography_drawer.dart';

/// 鸿蒙真机 e2e 发现的问题的回归护栏。
/// 详见 ohos/E2E-ISSUES.md。
void main() {
  group('问题 8：调字号不得把行距档位带跑', () {
    test('字号变化时行距按原倍数同步重算，倍数保持不变', () {
      const oldFont = 18.0;
      final oldLine = oldFont * kLineHeightRatios[1]; // 舒适 = 30.6

      final newLine = scaledLineHeight(
        oldFontSize: oldFont,
        oldLineHeight: oldLine,
        newFontSize: 20.0,
      );

      expect(newLine, closeTo(20.0 * kLineHeightRatios[1], 0.001),
          reason: '行距应随字号等比放大，保持"舒适"这一档的视觉比例');
    });

    test('字号从 18 调到 20 后，行距仍停在原来那一档', () {
      const oldFont = 18.0;
      const newFont = 20.0;
      for (var i = 0; i < kLineHeightRatios.length; i++) {
        final oldLine = oldFont * kLineHeightRatios[i];
        expect(nearestLineHeightIndex(oldFont, oldLine), i,
            reason: '前提：改字号前本就停在第 $i 档');

        final newLine = scaledLineHeight(
          oldFontSize: oldFont,
          oldLineHeight: oldLine,
          newFontSize: newFont,
        );
        expect(nearestLineHeightIndex(newFont, newLine), i,
            reason: '第 $i 档在字号变化后漂移了——这正是真机上"只点 A+ '
                '行距却从舒适跳到紧凑"的原因');
      }
    });

    test('不重算行距时档位确实会漂移（证明上面的测试不是空测）', () {
      const oldFont = 18.0;
      const newFont = 20.0;
      final oldLine = oldFont * kLineHeightRatios[1]; // 舒适

      // 模拟修复前的行为：只改字号，行距绝对值不动
      expect(nearestLineHeightIndex(newFont, oldLine), 0,
          reason: '30.6 在字号 20 下会被判成"紧凑"，与真机观察一致');
    });

    test('异常输入回落到舒适档，不产生 NaN', () {
      final v = scaledLineHeight(
        oldFontSize: 0.0,
        oldLineHeight: 0.0,
        newFontSize: 16.0,
      );
      expect(v, closeTo(16.0 * kLineHeightRatios[1], 0.001));
      expect(v.isFinite, isTrue);
    });
  });

  group('问题 3：TXT 分章不得把正文行当成标题', () {
    test('真章节标题正常识别', () {
      const titles = [
        '第一章 鸿蒙初启',
        '第二章 传书验证',
        '第三章 收尾',
        '第 12 章 风起',
        '第001章',
        '序言',
        '楔子',
        '正文 第十章 归途',
        '☆、第五章 夜谈',
        'Chapter 3',
        '第一章 开始了！',
      ];
      for (final t in titles) {
        expect(TxtParserEngine.isChapterTitleLine(t), isTrue,
            reason: '「$t」应识别为标题');
      }
    });

    test('以章节号开头的正文段落不得被当成标题', () {
      // 这三条来自鸿蒙真机实测：一本 3 章的 TXT 被切成了 5 章
      const proseLines = [
        '第三章正文，用于验证章节切换。',
        '第二章正文。若这一章能在书架里打开并正确显示，说明三条链路都是通的。',
        '第一章正文，用于验证 TXT 自动分章与排版渲染是否正常。',
      ];
      for (final line in proseLines) {
        expect(TxtParserEngine.isChapterTitleLine(line), isFalse,
            reason: '「$line」是正文，不是标题');
      }
    });

    test('过长的行不当作标题', () {
      final long = '第一章 ${'风' * 60}';
      expect(TxtParserEngine.isChapterTitleLine(long), isFalse);
    });

    test('空行与纯空白不当作标题', () {
      expect(TxtParserEngine.isChapterTitleLine(''), isFalse);
      expect(TxtParserEngine.isChapterTitleLine('   '), isFalse);
    });
  });

  group('问题 13：划线批注弹窗不得溢出', () {
    Widget wrap(Widget child, Size size) {
      return MediaQuery(
        data: MediaQueryData(size: size),
        child: MaterialApp(home: Scaffold(body: Center(child: child))),
      );
    }

    Widget buildDialog() {
      return const AddAnnotationDialog(
        bookId: 'b1',
        bookTitle: '测试书',
        chapterIndex: 0,
        chapterTitle: '第一章',
        charStart: 0,
        charEnd: 42,
        // 42 字，与真机上溢出 26px 时的选中长度一致
        selectedText: '帝国第六次远征舰队旗舰丹东号帝国海军的骄傲帝国海军有史以来最庞大的一条战船啊',
        isDark: true,
        selectionContext: AnnotationSelectionContext(
          fullContextText: '帝国第六次远征舰队旗舰丹东号，帝国海军的骄傲，'
              '帝国海军有史以来最庞大的一条战船。为了迎接这次盛大的欢迎仪式……',
          contextBaseOffset: 0,
        ),
      );
    }

    testWidgets('窄屏下两端微调行不溢出', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(wrap(buildDialog(), const Size(360, 800)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull,
          reason: '出现 RenderFlex overflow 会让 debug 包画出黄黑条');
      expect(find.textContaining('已选'), findsOneWidget);
    });

    testWidgets('极窄屏（320dp）下同样不溢出', (tester) async {
      tester.view.physicalSize = const Size(960, 2000);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(wrap(buildDialog(), const Size(320, 660)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
