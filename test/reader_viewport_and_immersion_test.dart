import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_reader_flutter/features/reader/engine/page_models.dart';
import 'package:novel_reader_flutter/features/reader/presentation/page_painter.dart';
import 'package:novel_reader_flutter/features/reader/presentation/reader_page_theme.dart';
import 'package:novel_reader_flutter/features/reader/presentation/reader_viewport.dart';
import 'package:novel_reader_flutter/features/tts/services/tts_sentence_splitter.dart';
import 'dart:ui';

void main() {
  group('【排版与视口攻坚】专项回归测试', () {
    test('1.2 浅色主题（纸白/羊皮纸/青润）次级文本对比度调校验证', () {
      const paper = ReaderThemeOption.paper;
      const cream = ReaderThemeOption.cream;
      final green =
          ReaderThemeOption.presets.firstWhere((t) => t.id == 'green');

      // 验证羊皮纸名称与高对比度次级文本
      expect(cream.name, '羊皮纸');
      expect(cream.subTextColor, const Color(0xFF5A5043));

      // 计算相对亮度与对比度
      double calcContrast(Color c1, Color c2) {
        final l1 = c1.computeLuminance();
        final l2 = c2.computeLuminance();
        return (l1 > l2)
            ? (l1 + 0.05) / (l2 + 0.05)
            : (l2 + 0.05) / (l1 + 0.05);
      }

      final paperContrast = calcContrast(paper.background, paper.subTextColor);
      final creamContrast = calcContrast(cream.background, cream.subTextColor);
      final greenContrast = calcContrast(green.background, green.subTextColor);

      // WCAG 4.5:1 标尺验证
      expect(paperContrast, greaterThan(4.5));
      expect(creamContrast, greaterThan(4.5));
      expect(greenContrast, greaterThan(4.5));
    });

    test('1.1 / D15 PagePainter 电池图标电量与百分比绘制测试', () {
      const config = PagingConfig(
        viewportWidth: 390.0,
        viewportHeight: 844.0,
        padTop: 80.0,
        padBottom: 48.0,
      );

      final painter = PagePainter(
        page: const ChapterPage(
          pageIndex: 0,
          lines: [
            PageLineItem(
              text: '正文第一行',
              paragraphIndex: 0,
              lineIndexInPara: 0,
              isFirstLineOfPara: true,
              isLastLineOfPara: true,
              charStart: 0,
              charEnd: 5,
            ),
          ],
          isFirstPage: false,
          isLastPage: false,
          charStart: 0,
          charEnd: 5,
        ),
        totalPageCount: 10,
        chapterTitle: '第一章 序章',
        config: config,
        theme: ReaderThemeOption.paper,
        bookTitle: '测试小说',
        currentTime: '20:00',
        batteryLevel: 0.18, // 低电量 18%
      );

      // 验证低电量下 Painter 能在画布上正常执行绘制且不抛异常
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(390.0, 844.0));
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test('2.1 听书 TTS 启动映射当前视口首行字符偏移量测试', () {
      const fullText = '道可道，非常道。名可名，非常名。无名天地之始；有名万物之母。故常无欲以观其妙。';
      final sentences = TtsSentenceSplitter.split(fullText);
      expect(sentences.length, greaterThan(2));

      // 假设当前视口首行处于“有名万物之母”处（偏移约 20 左右）
      const charOffset = 23;
      int startSentenceIndex = 0;
      for (int i = 0; i < sentences.length; i++) {
        if (charOffset >= sentences[i].startIndex &&
            charOffset < sentences[i].endIndex) {
          startSentenceIndex = i;
          break;
        }
        if (sentences[i].startIndex >= charOffset) {
          startSentenceIndex = i;
          break;
        }
      }

      expect(startSentenceIndex, greaterThan(0));
      expect(sentences[startSentenceIndex].text, contains('有名万物之母'));
    });

    testWidgets('3.1 阅读器顶栏「书签」胶囊完整展现且不被右边缘物理截断测试', (tester) async {
      await tester.binding
          .setSurfaceSize(const Size(360.0, 780.0)); // 标准紧凑屏宽 360dp
      addTearDown(() => tester.binding.setSurfaceSize(null));

      bool bookmarkTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderViewport(
              paragraphs: const ['这是测试正文段落。'],
              bookTitle: '极度超长测试小说书名大奉打更人第二卷',
              chapterTitle: '第一章 破案神仙',
              initialCharOffset: 0,
              turnMode: PageTurnMode.slide,
              theme: ReaderThemeOption.paper,
              fontSize: 18.0,
              lineHeight: 30.0,
              isBookmarked: false,
              isInShelf: false,
              onBack: () {},
              onOpenCatalog: () {},
              onOpenTypography: () {},
              onAddToShelf: () {},
              onOpenSourceSwitcher: () {},
              onOpenNotes: () {},
              onToggleBookmark: () {
                bookmarkTapped = true;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 点击中心呼出阅读菜单
      await tester.tapAt(const Offset(180.0, 390.0));
      await tester.pumpAndSettle();

      // 验证「书签」按钮已渲染且在可视区内 (横坐标小于屏幕物理宽度 360.0)
      final bookmarkFinder =
          find.byKey(const ValueKey('reader_top_bookmark_btn'));
      expect(bookmarkFinder, findsOneWidget);

      final topLeft = tester.getTopLeft(bookmarkFinder);
      final bottomRight = tester.getBottomRight(bookmarkFinder);

      expect(topLeft.dx, greaterThanOrEqualTo(0.0));
      expect(bottomRight.dx, lessThanOrEqualTo(360.0),
          reason: '书签胶囊右边缘必须在可视安全区内，绝不被右边缘裁切');

      // 验证书签按钮可正常响应点击
      await tester.tap(bookmarkFinder);
      await tester.pumpAndSettle();
      expect(bookmarkTapped, isTrue);
    });
  });
}
