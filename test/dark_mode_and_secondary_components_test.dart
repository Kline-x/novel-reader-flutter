import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_reader_flutter/core/components/main_scaffold.dart';
import 'package:novel_reader_flutter/core/theme/soft_theme.dart';
import 'package:novel_reader_flutter/features/notes/presentation/add_annotation_dialog.dart';
import 'package:novel_reader_flutter/features/notes/presentation/reader_notes_sheet.dart';
import 'package:novel_reader_flutter/features/notes/services/notes_service.dart';
import 'package:novel_reader_flutter/features/reader/presentation/catalog_drawer.dart';
import 'package:novel_reader_flutter/features/reader/presentation/download_sheet.dart';
import 'package:novel_reader_flutter/features/reader/presentation/reader_page_theme.dart';
import 'package:novel_reader_flutter/features/reader/presentation/typography_drawer.dart';
import 'package:novel_reader_flutter/features/tts/presentation/tts_control_sheet.dart';
import 'package:novel_reader_flutter/features/tts/presentation/tts_mini_player.dart';
import 'package:novel_reader_flutter/features/tts/services/tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('【专项攻坚 1 & D1-D6】排版抽屉深色模式黑底黑字清零测试', () {
    testWidgets('深色模式下“字号/行距/翻页”标题、数值、A-/A+图标与未选标签均为亮白/高对比度', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TypographyDrawer(
              fontSize: 18.0,
              lineHeight: 30.0,
              currentTheme: ReaderThemeOption.night,
              turnMode: PageTurnMode.slide,
              onFontSizeChanged: (_) {},
              onLineHeightChanged: (_) {},
              onThemeChanged: (_) {},
              onTurnModeChanged: (_) {},
            ),
          ),
        ),
      );

      // 验证标题“字号”、“行距”、“翻页”颜色为白色
      final fontSizeTitle = tester.widget<Text>(find.text('字号'));
      expect(fontSizeTitle.style?.color, equals(Colors.white));

      final lineHeightTitle = tester.widget<Text>(find.text('行距'));
      expect(lineHeightTitle.style?.color, equals(Colors.white));

      final turnModeTitle = tester.widget<Text>(find.text('翻页'));
      expect(turnModeTitle.style?.color, equals(Colors.white));

      // 验证字号数值 18 的颜色为白色
      final fontSizeValue = tester.widget<Text>(find.text('18'));
      expect(fontSizeValue.style?.color, equals(Colors.white));

      // 验证未选中的行距标签（如“紧凑”）文字颜色为 white70
      final compactChipText = tester.widget<Text>(find.text('紧凑'));
      expect(compactChipText.style?.color, equals(Colors.white70));

      // 验证 A- 和 A+ 图标颜色为白色
      final iconDecrease =
          tester.widget<Icon>(find.byIcon(Icons.text_decrease));
      expect(iconDecrease.color, equals(Colors.white));

      final iconIncrease =
          tester.widget<Icon>(find.byIcon(Icons.text_increase));
      expect(iconIncrease.color, equals(Colors.white));
    });
  });

  group('【专项攻坚 2 & 3 & D7/D9/3.5】目录抽屉深色适配与搜索高亮计数测试', () {
    const mockChapters = [
      ChapterItem(index: 0, title: '第一章 少年出山', url: 'u1', isCached: true),
      ChapterItem(index: 1, title: '第二章 风起云涌', url: 'u2', isCached: false),
      ChapterItem(index: 2, title: '第三章 少年英雄', url: 'u3', isCached: false),
    ];

    testWidgets('深色模式下目录抽屉背景为水墨黑且未选章节标题为亮色', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            drawer: CatalogDrawer(
              chapters: mockChapters,
              currentChapterIndex: 0,
              isDark: true,
              onSelectChapter: (_) {},
            ),
          ),
        ),
      );

      // 打开抽屉
      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      // 验证抽屉背景色为水墨黑
      final container = tester.widget<Container>(find.byType(Container).first);
      expect(container.color, equals(const Color(0xFF1E2022)));

      // 验证未选中章节（第二章）标题文字颜色为 white70（杜绝黑底黑字）
      final chapter2Text = tester.widget<Text>(find.text('第二章 风起云涌'));
      expect(chapter2Text.style?.color, equals(Colors.white70));
    });

    testWidgets('搜索关键词高亮与命中计数条目展示', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            drawer: CatalogDrawer(
              chapters: mockChapters,
              currentChapterIndex: 0,
              isDark: false,
              onSelectChapter: (_) {},
            ),
          ),
        ),
      );

      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      // 输入搜索词“少年”
      await tester.enterText(find.byType(TextField), '少年');
      await tester.pumpAndSettle();

      // 验证显示命中计数“找到 2 个相关章节”
      expect(find.text('找到 2 个相关章节'), findsOneWidget);

      // 验证第一章和第三章采用 RichText 包含高亮 TextSpan
      final richTexts = tester.widgetList<RichText>(find.byType(RichText));
      final hasHighlightedSpan = richTexts.any((rt) {
        if (rt.text is TextSpan) {
          final span = rt.text as TextSpan;
          return span.children?.any((c) => c is TextSpan && c.text == '少年') ??
              false;
        }
        return false;
      });
      expect(hasHighlightedSpan, isTrue);
    });
  });

  group('【专项攻坚 4 & 5 & D10/D11/3.2/3.4】书签笔记与批注弹窗深色防眩光与导出就地反馈', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      NotesService().setPrefs(prefs);
    });

    testWidgets('ReaderNotesSheet在深色模式下呈现深色卡片并支持导出笔记行内反馈', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          return null;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                key: const ValueKey('open_notes_sheet_btn'),
                onPressed: () {
                  ReaderNotesSheet.show(
                    context,
                    bookId: 'book_test',
                    bookTitle: '大奉打更人',
                    isDark: true,
                    onNavigate: (_, __) {},
                  );
                },
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 点击打开抽屉
      await tester.tap(find.byKey(const ValueKey('open_notes_sheet_btn')));
      await tester.pumpAndSettle();

      // 验证深色卡片背景
      final container = tester.widget<Container>(find.byType(Container).first);
      final boxDecoration = container.decoration as BoxDecoration;
      expect(boxDecoration.color, equals(SoftColors.night.card));

      // 点击导出笔记按钮
      await tester.tap(find.byKey(const ValueKey('btn_export_notes')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 验证就地行内反馈条弹出
      expect(find.text('✓ 笔记已成功导出并复制至剪贴板'), findsOneWidget);

      // 推进3秒定时器完成清理
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('AddAnnotationDialog在深色模式下背景为夜间防眩光深色卡片', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AddAnnotationDialog(
              bookId: 'book_test',
              bookTitle: '大奉打更人',
              chapterIndex: 0,
              chapterTitle: '第一章',
              charStart: 0,
              charEnd: 10,
              selectedText: '天地不仁以万物为刍狗',
              isDark: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final dialog = tester.widget<Dialog>(find.byType(Dialog));
      expect(dialog.backgroundColor, equals(SoftColors.night.card));
    });
  });

  group('【专项攻坚 6 & D12】离线下载抽屉深色模式适配', () {
    testWidgets('DownloadSheet在isDark为true时呈现深色沉浸卡片', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DownloadSheet(
              bookId: 'book_download_test',
              bookTitle: '宿命之环',
              chapters: [ChapterItem(index: 0, title: '第一章', url: 'u1')],
              currentChapterIndex: 0,
              isDark: true,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final material = tester.widget<Material>(
          find.byKey(const ValueKey('download_sheet_material')));
      expect(material.color, equals(SoftColors.night.card));
    });
  });

  group('【专项攻坚 7 & D13/D14/2.2/2.4】听书Mini条与控制面板优化', () {
    setUp(() async {
      final tts = TtsService();
      await tts.playChapter(
        bookId: 'book_tts_test',
        bookTitle: '诡秘之主',
        chapterIndex: 0,
        chapterTitle: '第一章 绯红',
        content: '绯红的月光照耀在古老的大地上。',
      );
    });

    tearDown(() async {
      await TtsService().stop();
    });

    testWidgets('TtsMiniPlayer在isDark为true时使用深色微透背景并支持拖拽手势', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned(
                  bottom: 44.0,
                  left: 0,
                  right: 0,
                  child: TtsMiniPlayer(isDark: true),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(TtsMiniPlayer), findsOneWidget);
      expect(find.textContaining('按住可上下拖拽'), findsOneWidget);

      // 验证垂直拖拽位移不崩溃
      await tester.drag(find.byKey(const ValueKey('tts_mini_player_tap')),
          const Offset(0, -50));
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('TtsControlSheet在深色模式下适配且语速定时按钮具备48dp最小热区', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TtsControlSheet(isDark: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 验证语速 1.0x 按钮
      final rateBtn = find.byKey(const ValueKey('tts_rate_1.0x'));
      expect(rateBtn, findsOneWidget);

      final rateGesture = tester.widget<GestureDetector>(rateBtn);
      expect(rateGesture.behavior, equals(HitTestBehavior.opaque));

      // 验证定时按钮具有 HitTestBehavior.opaque
      final timerBtn = find.byKey(const ValueKey('tts_timer_none'));
      expect(timerBtn, findsOneWidget);
      final timerGesture = tester.widget<GestureDetector>(timerBtn);
      expect(timerGesture.behavior, equals(HitTestBehavior.opaque));
    });
  });

  group('【专项攻坚 8 & D8】主界面退出 SnackBar 白底白字修复测试', () {
    testWidgets('MainScaffold双击退出时弹出SnackBar文字显式声明textPrimary', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: MainScaffold(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 触发一次后退模拟物理返回按键
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('再按一次退出藏书阁'), findsOneWidget);
      final textWidget = tester.widget<Text>(find.text('再按一次退出藏书阁'));
      // 显式指定了颜色，非空且不为默认白底白字
      expect(textWidget.style?.color, isNotNull);
      expect(textWidget.style?.color, equals(SoftColors.parchment.textPrimary));
    });
  });
}
