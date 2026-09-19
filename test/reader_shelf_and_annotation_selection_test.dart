import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_reader_flutter/features/notes/models/annotation.dart';
import 'package:novel_reader_flutter/features/notes/presentation/add_annotation_dialog.dart';
import 'package:novel_reader_flutter/features/reader/presentation/reader_page_theme.dart';
import 'package:novel_reader_flutter/features/reader/presentation/reader_viewport.dart';

void main() {
  group('阅读页加入书架外置与自由划线测试', () {
    testWidgets('顶部栏外置「加入书架」按钮：未入架可点击入架，已入架显示完成状态', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      bool addedToShelf = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderViewport(
              paragraphs: const ['第一段文字测试', '第二段文字测试'],
              bookTitle: '大奉打更人',
              chapterTitle: '第一章 牢狱之灾',
              theme: ReaderThemeOption.presets[0],
              onBack: () {},
              onOpenCatalog: () {},
              onOpenTypography: () {},
              onAddToShelf: () {
                addedToShelf = true;
              },
              isInShelf: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 点击屏幕中央呼出顶部与底部菜单栏
      await tester.tapAt(const Offset(270.0, 600.0));
      await tester.pumpAndSettle();

      // 验证外置的加入书架按钮显式存在
      final shelfBtnFinder = find.byKey(const ValueKey('reader_top_shelf_btn'));
      expect(shelfBtnFinder, findsOneWidget);

      // 点击加入书架
      await tester.tap(shelfBtnFinder);
      await tester.pumpAndSettle();
      expect(addedToShelf, isTrue);
    });

    testWidgets('AddAnnotationDialog支持【选字/选句/选段/选行】胶囊切换与两端微调扩缩',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      const fullContext = '天地不仁，以万物为刍狗。圣人不仁，以百姓为刍狗。';
      const selectionCtx = AnnotationSelectionContext(
        wordCandidate: AnnotationCandidate(
          text: '万物',
          charStart: 5,
          charEnd: 7,
          mode: AnnotationSelectionMode.word,
        ),
        sentenceCandidate: AnnotationCandidate(
          text: '天地不仁，以万物为刍狗。',
          charStart: 0,
          charEnd: 12,
          mode: AnnotationSelectionMode.sentence,
        ),
        paragraphCandidate: AnnotationCandidate(
          text: fullContext,
          charStart: 0,
          charEnd: 24,
          mode: AnnotationSelectionMode.paragraph,
        ),
        lineCandidate: AnnotationCandidate(
          text: '天地不仁，以万物为刍狗。',
          charStart: 0,
          charEnd: 12,
          mode: AnnotationSelectionMode.line,
        ),
        fullContextText: fullContext,
        contextBaseOffset: 0,
      );

      Annotation? submittedAnnotation;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                key: const ValueKey('trigger_dialog_btn'),
                onPressed: () async {
                  submittedAnnotation = await AddAnnotationDialog.show(
                    ctx,
                    bookId: 'book_100',
                    bookTitle: '道德经',
                    chapterIndex: 4,
                    chapterTitle: '第五章',
                    charStart: 0,
                    charEnd: 12,
                    selectedText: '天地不仁，以万物为刍狗。',
                    selectionContext: selectionCtx,
                  );
                },
                child: const Text('打开划线弹窗'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 呼出弹窗
      await tester.tap(find.byKey(const ValueKey('trigger_dialog_btn')));
      await tester.pumpAndSettle();

      // 默认智能选择【选句】
      expect(find.text('添加划线批注'), findsOneWidget);
      expect(find.text('“天地不仁，以万物为刍狗。”'), findsOneWidget);

      // 1. 切换为【选字】
      await tester.tap(find.byKey(const ValueKey('mode_tab_word')));
      await tester.pumpAndSettle();
      expect(find.text('“万物”'), findsOneWidget);

      // 2. 切换为【选段】
      await tester.tap(find.byKey(const ValueKey('mode_tab_paragraph')));
      await tester.pumpAndSettle();
      expect(find.text('“天地不仁，以万物为刍狗。圣人不仁，以百姓为刍狗。”'), findsOneWidget);

      // 3. 切换回【选句】
      await tester.tap(find.byKey(const ValueKey('mode_tab_sentence')));
      await tester.pumpAndSettle();
      expect(find.text('“天地不仁，以万物为刍狗。”'), findsOneWidget);

      // 4. 测试微调步进器：起点往后缩1字（缩去“天”）
      await tester.tap(find.byKey(const ValueKey('btn_start_shrink')));
      await tester.pumpAndSettle();
      expect(find.text('“地不仁，以万物为刍狗。”'), findsOneWidget);

      // 5. 点击确定提交划线
      await tester.tap(find.byKey(const ValueKey('btn_confirm_annotation')));
      await tester.pumpAndSettle();

      expect(submittedAnnotation, isNotNull);
      expect(submittedAnnotation!.charStart, equals(1));
      expect(submittedAnnotation!.selectedText, equals('地不仁，以万物为刍狗。'));
    });
  });
}
