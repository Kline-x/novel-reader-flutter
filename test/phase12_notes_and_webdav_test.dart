import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:novel_reader_flutter/features/notes/models/annotation.dart';
import 'package:novel_reader_flutter/features/notes/models/bookmark.dart';
import 'package:novel_reader_flutter/features/notes/presentation/add_annotation_dialog.dart';
import 'package:novel_reader_flutter/features/notes/presentation/reader_notes_sheet.dart';
import 'package:novel_reader_flutter/features/notes/services/notes_service.dart';
import 'package:novel_reader_flutter/features/reader/data/storage_service.dart';
import 'package:novel_reader_flutter/features/sync/models/webdav_config.dart';
import 'package:novel_reader_flutter/features/sync/presentation/webdav_config_sheet.dart';
import 'package:novel_reader_flutter/features/sync/services/webdav_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('阶段 12：书签与划线批注模型及持久化服务测试', () {
    late SharedPreferences prefs;
    late NotesService notesService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      notesService = NotesService();
      notesService.setPrefs(prefs);
    });

    test('Bookmark 模型序列化与反序列化及 CRUD 验证', () async {
      final now = DateTime.now();
      final bm = Bookmark(
        id: 'bm_001',
        bookId: 'book_fanren',
        bookTitle: '凡人修仙传',
        chapterIndex: 3,
        chapterTitle: '第三章 七玄门试炼',
        charOffset: 128,
        snippet: '试炼在一条被称为落日坡的山道上进行。',
        createdAt: now,
      );

      final json = bm.toJson();
      final fromJson = Bookmark.fromJson(json);

      expect(fromJson.id, 'bm_001');
      expect(fromJson.bookTitle, '凡人修仙传');
      expect(fromJson.chapterIndex, 3);
      expect(fromJson.snippet, contains('落日坡'));

      // 存储与读取
      await notesService.saveBookmark(bm);
      final list = await notesService.getBookmarks('book_fanren');
      expect(list.length, 1);
      expect(list.first.id, 'bm_001');

      // 状态检查
      final isBm = await notesService.isBookmarked('book_fanren', 3, 130);
      expect(isBm, isTrue);

      final isBmOther = await notesService.isBookmarked('book_fanren', 4, 0);
      expect(isBmOther, isFalse);

      // 移除
      await notesService.removeBookmark('bm_001');
      final listAfter = await notesService.getBookmarks('book_fanren');
      expect(listAfter.isEmpty, isTrue);
    });

    test('Annotation 划线批注模型与 Markdown 导出验证', () async {
      final now = DateTime.now();
      final ann = Annotation(
        id: 'ann_001',
        bookId: 'book_fanren',
        bookTitle: '凡人修仙传',
        chapterIndex: 3,
        chapterTitle: '第三章 七玄门试炼',
        charStart: 50,
        charEnd: 88,
        selectedText: '数十名少年需要在一个时辰内登上峰顶。',
        note: '主角韩立的心性从这里展现',
        colorIndex: 1, // 薄荷绿
        createdAt: now,
        updatedAt: now,
      );

      await notesService.saveAnnotation(ann);
      final list = await notesService.getAnnotations('book_fanren');
      expect(list.length, 1);
      expect(list.first.selectedText, contains('数十名少年'));
      expect(list.first.colorIndex, 1);

      // 添加一个书签以便完整测试导出
      await notesService.saveBookmark(Bookmark(
        id: 'bm_002',
        bookId: 'book_fanren',
        bookTitle: '凡人修仙传',
        chapterIndex: 3,
        chapterTitle: '第三章 七玄门试炼',
        charOffset: 200,
        snippet: '韩立咬紧牙关，手掌被尖石划破也未曾停下半步。',
        createdAt: now,
      ));

      final md = await notesService.exportNotesAsMarkdown('book_fanren', '凡人修仙传');
      expect(md, contains('# 《凡人修仙传》读书笔记与摘录'));
      expect(md, contains('数十名少年需要在一个时辰内登上峰顶。'));
      expect(md, contains('主角韩立的心性从这里展现'));
      expect(md, contains('薄荷绿'));
      expect(md, contains('书签记录'));
    });
  });

  group('阶段 12：WebDAV 云端漫游与三方增量合并引擎测试', () {
    late SharedPreferences prefs;
    late WebDavService webDavService;
    late StorageService storageService;
    late NotesService notesService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      webDavService = WebDavService();
      webDavService.setTestMode(true);
      webDavService.setPrefs(prefs);
      storageService = StorageService(prefs: prefs);
      notesService = NotesService();
      notesService.setPrefs(prefs);
    });

    test('WebDavConfig 读取、保存与测试连通性验证', () async {
      const config = WebDavConfig(
        serverUrl: 'https://dav.jianguoyun.com/dav/',
        username: 'reader_user@example.com',
        password: 'secure_password_123',
        remotePath: '/my_books_backup',
        autoSync: true,
      );

      await webDavService.saveConfig(config);
      final loaded = await webDavService.getConfig();

      expect(loaded.username, 'reader_user@example.com');
      expect(loaded.remotePath, '/my_books_backup');
      expect(loaded.autoSync, isTrue);

      final connected = await webDavService.testConnection(testConfig: loaded);
      expect(connected, isTrue);
    });

    test('WebDAV 增量同步模拟与书架/书签对齐验证', () async {
      // 设置完整 WebDAV 凭据
      await webDavService.saveConfig(const WebDavConfig(
        serverUrl: 'https://dav.jianguoyun.com/dav/',
        username: 'test_user',
        password: 'test_password',
      ));

      // 准备本地书架书籍与书签
      final now = DateTime.now();
      await storageService.addToBookshelf(ShelfBook(
        bookId: 'book_fanren',
        title: '凡人修仙传',
        author: '忘语',
        currentChapterIndex: 5,
        currentCharOffset: 210,
        lastReadTime: now,
      ));

      await notesService.saveBookmark(Bookmark(
        id: 'bm_local_1',
        bookId: 'book_fanren',
        bookTitle: '凡人修仙传',
        chapterIndex: 5,
        chapterTitle: '第五章 初入修仙',
        charOffset: 210,
        snippet: '韩立收拾好行囊，踏上了新的旅程。',
        createdAt: now,
      ));

      final result = await webDavService.sync(
        storageService: storageService,
        notesService: notesService,
      );

      expect(result.success, isTrue);
      expect(result.syncedBooks, 1);
      expect(result.syncedBookmarks, 1);
      expect(result.message, contains('增量漫游同步成功'));
    });

    test('WebDAV 空配置拦截测试：未配置账号密码时拒绝同步并提示完善配置', () async {
      await webDavService.saveConfig(const WebDavConfig(
        serverUrl: 'https://dav.jianguoyun.com/dav/',
        username: '',
        password: '',
      ));
      final result = await webDavService.sync(
        storageService: storageService,
        notesService: notesService,
      );
      expect(result.success, isFalse);
      expect(result.message, contains('请先完善 WebDAV 配置'));
    });
  });

  group('阶段 12：Modern Soft UI 组件与弹窗触控交互测试', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      NotesService().setPrefs(prefs);
      WebDavService().setPrefs(prefs);
      WebDavService().setTestMode(true);
    });

    testWidgets('ReaderNotesSheet 挂载与标签切换及导出测试', (tester) async {
      tester.view.physicalSize = const Size(1440, 3200);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      // 先存入一个书签和一个笔记
      final now = DateTime.now();
      await NotesService().saveBookmark(Bookmark(
        id: 'bm_test',
        bookId: 'book_1',
        bookTitle: '测试书',
        chapterIndex: 1,
        chapterTitle: '第一章 测试',
        charOffset: 50,
        snippet: '书签摘要内容',
        createdAt: now,
      ));

      await NotesService().saveAnnotation(Annotation(
        id: 'ann_test',
        bookId: 'book_1',
        bookTitle: '测试书',
        chapterIndex: 1,
        chapterTitle: '第一章 测试',
        charStart: 10,
        charEnd: 30,
        selectedText: '划线选段内容',
        note: '这句写得真好',
        colorIndex: 0,
        createdAt: now,
        updatedAt: now,
      ));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                key: const ValueKey('open_sheet_btn'),
                onPressed: () {
                  ReaderNotesSheet.show(
                    context,
                    bookId: 'book_1',
                    bookTitle: '测试书',
                    onNavigate: (_, __) {},
                  );
                },
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('open_sheet_btn')));
      await tester.pumpAndSettle();

      // 验证标题与书签挂载
      expect(find.text('书签与笔记'), findsOneWidget);
      expect(find.text('导出笔记'), findsOneWidget);
      expect(find.text('书签摘要内容'), findsOneWidget);

      // 切换到划线笔记 Tab
      await tester.tap(find.textContaining('划线笔记'));
      await tester.pumpAndSettle();

      expect(find.text('“划线选段内容”'), findsOneWidget);
      expect(find.text('心得：这句写得真好'), findsOneWidget);
    });

    testWidgets('AddAnnotationDialog 4色高亮选择与批注提交测试', (tester) async {
      tester.view.physicalSize = const Size(1440, 3200);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      Annotation? createdResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                key: const ValueKey('open_dialog_btn'),
                onPressed: () async {
                  createdResult = await AddAnnotationDialog.show(
                    context,
                    bookId: 'book_1',
                    bookTitle: '测试书',
                    chapterIndex: 1,
                    chapterTitle: '第一章',
                    charStart: 0,
                    charEnd: 20,
                    selectedText: '这是一段测试高亮的优美文字',
                  );
                },
                child: const Text('录入'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('open_dialog_btn')));
      await tester.pumpAndSettle();

      expect(find.text('添加划线批注'), findsOneWidget);
      expect(find.text('“这是一段测试高亮的优美文字”'), findsOneWidget);

      // 点击第 2 个颜色（薄荷绿）
      await tester.tap(find.byKey(const ValueKey('highlight_color_1')));
      await tester.pumpAndSettle();

      // 输入心得
      await tester.enterText(
        find.byKey(const ValueKey('input_annotation_note')),
        '值得反复品味的精彩段落',
      );
      await tester.pumpAndSettle();

      // 点击确定划线
      await tester.tap(find.byKey(const ValueKey('btn_confirm_annotation')));
      await tester.pumpAndSettle();

      expect(createdResult, isNotNull);
      expect(createdResult!.colorIndex, 1);
      expect(createdResult!.note, '值得反复品味的精彩段落');
    });

    testWidgets('WebDavConfigSheet 挂载与连通性/同步测试', (tester) async {
      tester.view.physicalSize = const Size(1440, 3200);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                key: const ValueKey('open_webdav_sheet_btn'),
                onPressed: () {
                  WebDavConfigSheet.show(context);
                },
                child: const Text('打开 WebDAV'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('open_webdav_sheet_btn')));
      await tester.pumpAndSettle();

      expect(find.text('WebDAV 增量云漫游'), findsOneWidget);
      expect(find.byKey(const ValueKey('input_webdav_url')), findsOneWidget);
      expect(find.byKey(const ValueKey('btn_test_webdav')), findsOneWidget);
      expect(find.byKey(const ValueKey('btn_sync_now')), findsOneWidget);

      // 输入配置
      await tester.enterText(find.byKey(const ValueKey('input_webdav_user')), 'test_user');
      await tester.enterText(find.byKey(const ValueKey('input_webdav_pwd')), 'test_pwd');
      await tester.pumpAndSettle();

      // 点击测试连接
      await tester.tap(find.byKey(const ValueKey('btn_test_webdav')));
      await tester.pumpAndSettle();
      expect(find.text('✓ WebDAV 连通正常'), findsOneWidget);

      // 点击立即增量漫游
      await tester.tap(find.byKey(const ValueKey('btn_sync_now')));
      await tester.pumpAndSettle();
      expect(find.textContaining('同步成功'), findsOneWidget);
    });
  });
}
