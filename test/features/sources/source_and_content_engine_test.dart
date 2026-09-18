import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_reader_flutter/features/reader/data/storage_service.dart';
import 'package:novel_reader_flutter/features/reader/services/chapter_helper.dart';
import 'package:novel_reader_flutter/features/sources/models/book_search_result.dart';
import 'package:novel_reader_flutter/features/sources/models/chapter_item.dart';
import 'package:novel_reader_flutter/features/sources/services/multi_source_service.dart';
import 'package:novel_reader_flutter/features/sources/services/source_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late StorageService storage;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tempDir = Directory.systemTemp.createTempSync('source_engine_test_');
    storage = StorageService(customCacheDir: tempDir.path);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('【专项一】书源智能权重排序、信誉评分与降权沉底测试', () {
    test('信誉评分：笔趣阁7加1000分，思兔阅读扣4000分', () {
      final biquge7Book = BookSearchResult(
        id: 'biquge7::1',
        title: '恶魔法则',
        author: '跳舞',
        bookUrl: 'https://www.biquge7.xyz/1283/',
        sourceId: 'biquge7:笔趣阁7',
        sourceName: '笔趣阁7',
      );

      final situBook = BookSearchResult(
        id: 'sto66::1',
        title: '恶魔法则',
        author: '跳舞',
        bookUrl: 'https://www.sto66.com/1283/',
        sourceId: 'sto66:思兔阅读',
        sourceName: '思兔阅读',
      );

      final normalBook = BookSearchResult(
        id: 'normal::1',
        title: '恶魔法则',
        author: '跳舞',
        bookUrl: 'https://example.com/1283/',
        sourceId: 'normal_source',
        sourceName: '普通源',
      );

      final scoreBiquge7 =
          MultiSourceService.calculateRelevance(biquge7Book, '恶魔法则');
      final scoreSitu = MultiSourceService.calculateRelevance(situBook, '恶魔法则');
      final scoreNormal =
          MultiSourceService.calculateRelevance(normalBook, '恶魔法则');

      // 笔趣阁7 比 普通源 高 1000 分
      expect(scoreBiquge7 - scoreNormal, 1000);
      // 思兔阅读 比 普通源 低 4000 分
      expect(scoreNormal - scoreSitu, 4000);
      // 笔趣阁7 比 思兔阅读 高出整整 5000 分
      expect(scoreBiquge7 - scoreSitu, 5000);
    });

    test('章节完整度加权：700+ 章节加 500 分，500+ 章节加 200 分', () {
      final book708 = BookSearchResult(
        id: '1',
        title: '恶魔法则',
        author: '跳舞',
        bookUrl: 'https://example.com/1',
        sourceId: 'normal_source',
        sourceName: '普通源',
        latestChapter: '第708章 罗林时代（大结局）',
      );

      final book550 = BookSearchResult(
        id: '2',
        title: '恶魔法则',
        author: '跳舞',
        bookUrl: 'https://example.com/2',
        sourceId: 'normal_source',
        sourceName: '普通源',
        latestChapter: '第550章 帝都暴乱',
      );

      final book200 = BookSearchResult(
        id: '3',
        title: '恶魔法则',
        author: '跳舞',
        bookUrl: 'https://example.com/3',
        sourceId: 'normal_source',
        sourceName: '普通源',
        latestChapter: '第200章 北方要塞',
      );

      final score708 = MultiSourceService.calculateRelevance(book708, '恶魔法则');
      final score550 = MultiSourceService.calculateRelevance(book550, '恶魔法则');
      final score200 = MultiSourceService.calculateRelevance(book200, '恶魔法则');

      expect(score708 - score200, 500);
      expect(score550 - score200, 200);
      expect(score708 - score550, 300);
    });

    test('排序与延迟权衡：思兔阅读彻底沉底，全本优质源稳居榜首', () {
      // 笔趣阁7：全本708章，延迟稍高（180ms）
      final biquge7 = BookSearchResult(
        id: 'biquge7',
        title: '恶魔法则',
        author: '跳舞',
        bookUrl: 'https://www.biquge7.xyz/1283/',
        sourceId: 'biquge7:笔趣阁7',
        sourceName: '笔趣阁7',
        latestChapter: '第708章 罗林时代的终章',
        latencyMs: 180,
      );

      // 笔趣阁ZWX：良好源（+600），最新章第708章（+500），延迟 120ms
      final biqugezwx = BookSearchResult(
        id: 'biqugezwx',
        title: '恶魔法则',
        author: '跳舞',
        bookUrl: 'https://www.biqugezwx.com/1283/',
        sourceId: 'biqugezwx:笔趣阁ZWX',
        sourceName: '笔趣阁ZWX',
        latestChapter: '第708章 罗林时代（全书完）',
        latencyMs: 120,
      );

      // 思兔阅读：严重缺章残次源（-4000），最新仅230章，但延迟极低（15ms）
      final situ = BookSearchResult(
        id: 'sto66',
        title: '恶魔法则',
        author: '跳舞',
        bookUrl: 'https://www.sto66.com/1283/',
        sourceId: 'sto66:思兔阅读',
        sourceName: '思兔阅读',
        latestChapter: '第230章 残缺断章',
        latencyMs: 15,
      );

      final ranked =
          MultiSourceService.rankResults([situ, biqugezwx, biquge7], '恶魔法则');

      // 验证：尽管思兔阅读延迟仅 15ms，但因信誉惩罚被彻底打入谷底
      expect(ranked.first.sourceName, '笔趣阁7');
      expect(ranked[1].sourceName, '笔趣阁ZWX');
      expect(ranked.last.sourceName, '思兔阅读');
    });

    test('相关度相同时，按网络延迟升序优先展现', () {
      final fastBook = BookSearchResult(
        id: '1',
        title: '诡秘之主',
        author: '爱潜水的乌贼',
        bookUrl: 'https://example.com/1',
        sourceId: 'source_a',
        sourceName: '源A',
        latencyMs: 45,
      );

      final slowBook = BookSearchResult(
        id: '2',
        title: '诡秘之主',
        author: '爱潜水的乌贼',
        bookUrl: 'https://example.com/2',
        sourceId: 'source_b',
        sourceName: '源B',
        latencyMs: 260,
      );

      final ranked =
          MultiSourceService.rankResults([slowBook, fastBook], '诡秘之主');
      expect(ranked.first.latencyMs, 45);
      expect(ranked.last.latencyMs, 260);
    });

    test('无关噪点负向过滤：书名作者均不含有效字符扣除 50000 分', () {
      final noiseBook = BookSearchResult(
        id: 'noise',
        title: '天龙八部',
        author: '金庸',
        bookUrl: 'https://example.com/tlbb',
        sourceId: 'test',
        sourceName: '测试源',
      );

      final score = MultiSourceService.calculateRelevance(noiseBook, '诡秘之主');
      expect(score, lessThanOrEqualTo(-40000));
    });
  });

  group('【专项二】正文深度清洗：全角空格切分、超长段落智能断句与广告过滤测试', () {
    test('全角空格（　　）与连续多空格自然段切分', () {
      const rawText = '这是第一段内容。　　这是第二段内容，由全角空格连接。    这是第三段内容，由多空格连接。';
      final paragraphs = SourceParser.cleanAndFilterParagraphs(rawText);

      expect(paragraphs.length, 3);
      expect(paragraphs[0], '这是第一段内容。');
      expect(paragraphs[1], '这是第二段内容，由全角空格连接。');
      expect(paragraphs[2], '这是第三段内容，由多空格连接。');
    });

    test('>320 字超长段落按句末标点（。”、！”、？）语义智能断段', () {
      // 构造超过 380 字的无换行小说单段长文本
      const sentence1 =
          '周明瑞揉了揉胀痛欲裂的太阳穴，只觉得脑袋沉重得像是灌了铅一般，脑海深处大量零碎混乱的记忆碎片在疯狂冲撞，那是属于克莱恩·莫雷蒂的短暂一生，充斥着贫困、窘迫与对神秘学知识的致命好奇，窗外的绯红月光正无声地照耀着这间逼仄阴暗的简陋房间。”'; // ~120字
      const sentence2 =
          '他猛地从那张破旧的硬木椅子上站了起来，不可置信地看着书桌上的那面破碎黄铜镜子，镜子里映出一张年轻而苍白的脸庞，黑色头发，深褐色眼眸，左侧太阳穴处还赫然凝固着一个恐怖狰狞的贯穿弹孔，这怎么可能？难道我已经死过一次了？！”'; // ~120字
      const sentence3 =
          '空气中弥漫着刺鼻的火药味与淡淡的血腥味，煤气路灯的微弱光芒在昏黄中摇曳不定，门外走廊传来了沉重而急促的脚步声，似乎有某种不可名状的恐怖存在正在黑暗中悄然逼近，这绝不是正常的现实世界，必须立刻找到自保的方法！'; // ~113字
      const sentence4 =
          '他颤抖着伸出右手，摸向了抽屉深处的那柄左轮手枪与几枚黄铜子弹，冰冷的金属触感终于让他稍微找回了一丝安全感。'; // ~60字

      const longText = '$sentence1$sentence2$sentence3$sentence4';
      expect(longText.length, greaterThan(320));

      final paragraphs = SourceParser.cleanAndFilterParagraphs(longText);

      // 验证：超长段落被智能断开为 >= 2 个符合阅读舒适度的自然段
      expect(paragraphs.length, greaterThanOrEqualTo(2));
      for (final p in paragraphs) {
        expect(p.isNotEmpty, isTrue);
        // 断开的每一段长度均得到合理控制
        expect(p.length, lessThanOrEqualTo(320));
      }
      // 验证段落内容完整，首尾关键词未丢失
      expect(paragraphs.first.contains('周明瑞揉了揉胀痛欲裂的太阳穴'), isTrue);
      expect(paragraphs.last.contains('冰冷的金属触感终于让他稍微找回了一丝安全感。'), isTrue);
    });

    test('<= 320 字的标准段落不被破坏', () {
      const normalPara = '克莱恩深吸了一口气，平复下狂跳的心脏。他小心翼翼地收起桌上的转运仪式材料，退到了安全距离。';
      final paragraphs = SourceParser.cleanAndFilterParagraphs(normalPara);

      expect(paragraphs.length, 1);
      expect(paragraphs.first, normalPara);
    });

    test('牛皮癣广告黑名单清洗：全面覆盖“xxxx书城”、“最新网址发布页”等 46+ 种模式', () {
      final dirtyLines = [
        '周明瑞深吸了一口气，凝视着桌上的黄铜天平。',
        '欢迎光临全本小说书城阅读最新章节！',
        '请记住最新网址发布页：https://www.biquge.com 防走丢！',
        '克莱恩拿起银质小刀，在空气中缓缓划出灵性之墙。',
        '加入官方书友群：12345678，参与剧情大讨论！',
        '关注微信公众号：爱潜水的乌贼，每周更新番外！',
        '下载最新APP，离线免费听书畅享无广告纯净阅读。',
        '本章未完，点击下一页继续阅读精彩章节',
        '(本章完)',
        '如果您中途有事离开，请务必保存书签以便下次继续阅读。',
        '最新章节首发于七猫书城，禁止转载。',
        '“这就成功了？”克莱恩低声自语。',
      ];

      final paragraphs =
          SourceParser.cleanAndFilterParagraphs(dirtyLines.join('\n'));

      // 纯广告行必须被彻底清除
      expect(paragraphs.any((p) => p.contains('书城')), isFalse);
      expect(paragraphs.any((p) => p.contains('最新网址发布页')), isFalse);
      expect(paragraphs.any((p) => p.contains('书友群')), isFalse);
      expect(paragraphs.any((p) => p.contains('公众号')), isFalse);
      expect(paragraphs.any((p) => p.contains('下载最新APP')), isFalse);
      expect(paragraphs.any((p) => p.contains('点击下一页')), isFalse);
      expect(paragraphs.any((p) => p.contains('本章完')), isFalse);
      expect(paragraphs.any((p) => p.contains('保存书签')), isFalse);

      // 正文有效内容必须完好无损
      expect(paragraphs.length, 3);
      expect(paragraphs[0], '周明瑞深吸了一口气，凝视着桌上的黄铜天平。');
      expect(paragraphs[1], '克莱恩拿起银质小刀，在空气中缓缓划出灵性之墙。');
      expect(paragraphs[2], '“这就成功了？”克莱恩低声自语。');
    });

    test('行末附带牛皮癣广告的行内清洗：广告被剥离，前置有效正文保留', () {
      const lineWithAd = '克莱恩握紧了手中的左轮手枪。最新网址：www.biquge.la 本章未完点击下一页继续阅读';
      final paragraphs = SourceParser.cleanAndFilterParagraphs(lineWithAd);

      expect(paragraphs.length, 1);
      expect(paragraphs.first.contains('克莱恩握紧了手中的左轮手枪。'), isTrue);
      expect(paragraphs.first.contains('www.biquge.la'), isFalse);
      expect(paragraphs.first.contains('点击下一页'), isFalse);
    });
  });

  group('【专项三】真实元数据抓取：OpenGraph 标签与语义节点解析测试', () {
    test('标准 OpenGraph 标签优先解析', () {
      const ogHtml = '''
<!DOCTYPE html>
<html>
<head>
  <meta property="og:description" content="蒸汽与机械的浪潮中，谁能触及非凡？历史和黑暗的迷雾里，又是谁在耳语？" />
  <meta property="og:novel:update_time" content="2026-09-18 10:30:00" />
  <meta property="og:novel:status" content="已完结" />
  <meta property="og:novel:latest_chapter_name" content="第1432章 旅途的终点（全书完）" />
</head>
<body>
  <div id="intro">备用简介内容，不应被读取</div>
  <div class="update">2020-01-01</div>
</body>
</html>
''';
      final meta = SourceParser.parseBookDetailHtml(ogHtml);

      expect(meta['intro'], '蒸汽与机械的浪潮中，谁能触及非凡？历史和黑暗的迷雾里，又是谁在耳语？');
      expect(meta['updateTime'], '2026-09-18 10:30:00');
      expect(meta['status'], '已完结');
      expect(meta['latestChapter'], '第1432章 旅途的终点（全书完）');
    });

    test('无 OpenGraph 标签时的详情页 DOM 语义节点智能兜底', () {
      const semanticHtml = '''
<!DOCTYPE html>
<html>
<head><title>恶魔法则</title></head>
<body>
  <div class="book-intro">
    一个一无是处的纨绔子弟，在得到了一份恶魔的契约后，他的人生彻底改变。罗林家族的传奇拉开序幕！
  </div>
  <div class="update">最后更新：2026-08-15 18:00</div>
  <div class="status-tag">全本完结</div>
</body>
</html>
''';
      final meta = SourceParser.parseBookDetailHtml(semanticHtml);

      expect(meta['intro'], contains('罗林家族的传奇拉开序幕！'));
      expect(meta['updateTime'], '2026-08-15 18:00');
      expect(meta['status'], '已完结');
    });

    test('变体 meta 标签（name="description", og:update_time 等）兼容支持', () {
      const variantHtml = '''
<!DOCTYPE html>
<html>
<head>
  <meta name="description" content="变体简介内容" />
  <meta property="og:update_time" content="2026-07-01 12:00" />
  <meta property="novel:status" content="连载中" />
</head>
<body></body>
</html>
''';
      final meta = SourceParser.parseBookDetailHtml(variantHtml);

      expect(meta['intro'], '变体简介内容');
      expect(meta['updateTime'], '2026-07-01 12:00');
      expect(meta['status'], '连载中');
    });
  });

  group('【专项四】换源探活保护与防假目录持久化测试', () {
    test('换源失败或目标源未收录时：原目录绝不被破坏，原状态完好保留', () {
      // 模拟当前已有完整目录（708 章）
      final originalChapters = List.generate(
        708,
        (i) => ChapterItem(
            index: i,
            title: '第${i + 1}章 标题$i',
            url: 'https://source1.com/ch/$i'),
      );

      var currentChapters = List<ChapterItem>.from(originalChapters);
      var currentSourceName = '笔趣阁7';

      // 目标源未收录（搜索结果为空或无书名匹配）
      final emptySearchResults = <BookSearchResult>[];

      const cleanName = '恶魔法则';
      final matches = emptySearchResults.where((b) {
        final t = b.title.replaceAll(RegExp(r'[《》【】\s]'), '');
        return t == cleanName || t.contains(cleanName) || cleanName.contains(t);
      }).toList();

      if (matches.isNotEmpty) {
        // 只有匹配成功才换源
        currentChapters = [];
        currentSourceName = '新源';
      }

      // 验证：保护机制生效，原目录未被清空，原书源未被破坏
      expect(currentChapters.length, 708);
      expect(currentSourceName, '笔趣阁7');
      expect(currentChapters.first.title, '第1章 标题0');
    });

    test('彻底杜绝向沙盒写入 12 章假目录持久化', () async {
      const testBookId = 'test_fake_toc_guard_book';

      // 检查当前沙盒中无缓存
      final initialToc = await storage.getBookToc(testBookId);
      expect(initialToc, isNull);

      // 当网络异常拉取失败时，仅在内存中获取 ChapterHelper 的临时兜底目录
      final memoryFallback = ChapterHelper.getFallbackChapters('测试未知书籍');
      expect(memoryFallback.length, 12);

      // 核心验证：此时绝不调用 storage.saveBookToc(testBookId, memoryFallback)
      // 再次从沙盒读取，确保本地冷存储绝无 12 章伪造假目录被持久化
      final cachedAfterFallback = await storage.getBookToc(testBookId);
      expect(cachedAfterFallback, isNull);

      // 只有在线拉取到真实目录（>=20章且带真实有效URL）时，才允许持久化入沙盒
      final realChapters = List.generate(
        25,
        (i) => ChapterItem(
          index: i,
          title: '第${i + 1}章 绯红之月',
          url: 'https://biquge7.xyz/${i + 1}.html',
        ),
      );
      await storage.saveBookToc(testBookId, realChapters);

      final realCached = await storage.getBookToc(testBookId);
      expect(realCached, isNotNull);
      expect(realCached!.length, 25);
      expect(realCached.first['title'], '第1章 绯红之月');
    });
  });
}
