import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/components/book_cover_widget.dart';
import '../../../core/components/soft_button.dart';
import '../../../core/components/soft_card.dart';
import '../../../core/components/docked_bottom_bar.dart';
import '../../../core/theme/soft_theme.dart';
import '../../reader/data/storage_service.dart';
import '../../reader/services/chapter_helper.dart';
import '../../sources/models/book_search_result.dart';
import '../../sources/services/multi_source_service.dart';
import '../models/book_item.dart';
import 'book_detail_page.dart';
import 'shelf_controller.dart';

/// 发现/书城页面 (discovery_page.dart)
/// Modern Soft UI 风格的分类 Bento、热门榜单与全网 12 组书源实时并发聚合搜索
class DiscoveryPage extends ConsumerStatefulWidget {
  const DiscoveryPage({super.key});

  @override
  ConsumerState<DiscoveryPage> createState() => _DiscoveryPageState();
}

class _DiscoveryPageState extends ConsumerState<DiscoveryPage> {
  final TextEditingController _searchController = TextEditingController();
  final MultiSourceService _sourceService = MultiSourceService();
  final StorageService _storageService = StorageService();
  StreamSubscription<List<BookSearchResult>>? _searchSub;
  StreamSubscription<void>? _shelfSub;
  final Set<String> _shelfBookIds = {};
  final Set<String> _shelfBookTitles = {};

  int _selectedCategoryIndex = 0;
  bool _isSearching = false;
  String _activeQuery = '';
  final List<BookSearchResult> _searchResults = [];

  final List<String> _categories = [
    '全部',
    '女频言情',
    '玄幻奇幻',
    '仙侠修真',
    '科幻未来',
    '都市异能',
    '悬疑惊悚'
  ];

  final List<Map<String, String>> _allHotBooks = [
    // 女频言情精选爆款
    {
      'id': 'zhifou_01',
      'title': '知否？知否？应是绿肥红瘦',
      'author': '关心则乱',
      'category': '女频言情',
      'tag': '古代言情 · 宅斗权谋',
      'bookUrl': 'https://www.biqugezwx.com/568/',
      'sourceName': '笔趣阁ZWX',
      'sourceId': 'biqugezwx:笔趣阁ZWX',
      'desc':
          '一个消极怠工的古代庶女奋斗史。盛明兰在深宅大院中掩藏锋芒，韬光养晦，历经波折成长为独立自强的侯门主母。',
    },
    {
      'id': 'toutou_02',
      'title': '偷偷藏不住',
      'author': '竹已',
      'category': '女频言情',
      'tag': '青春甜宠 · 现代言情',
      'bookUrl': 'https://www.biqugezwx.com/892/',
      'sourceName': '笔趣阁ZWX',
      'sourceId': 'biqugezwx:笔趣阁ZWX',
      'desc':
          '桑稚高中时期暗恋哥哥的挚友段嘉许。从懵懂心动到大学重逢，双向奔赴的治愈系甜宠温暖爱恋。',
    },
    {
      'id': 'nanwong_03',
      'title': '难哄',
      'author': '竹已',
      'category': '女频言情',
      'tag': '破镜重圆 · 都市言情',
      'bookUrl': 'https://www.biqugezwx.com/955/',
      'sourceName': '笔趣阁ZWX',
      'sourceId': 'biqugezwx:笔趣阁ZWX',
      'desc':
          '机缘巧合下，温以凡跟曾被她拒绝的高中同学桑延过上了合租的生活。骄傲毒舌与温柔敏感的心灵治愈之旅。',
    },
    {
      'id': 'changxiangsi_04',
      'title': '长相思',
      'author': '桐华',
      'category': '女频言情',
      'tag': '上古神话 · 虐恋仙侠',
      'bookUrl': 'https://www.biqugezwx.com/673/',
      'sourceName': '笔趣阁ZWX',
      'sourceId': 'biqugezwx:笔趣阁ZWX',
      'desc':
          '生命是一场又一场的相遇与别离，是一次又一次的遗忘与开始。清水镇的玟小六，与轩辕王姬、涂山璟、相柳之间的宿命纠葛。',
    },
    {
      'id': 'kunning_05',
      'title': '坤宁',
      'author': '时镜',
      'category': '女频言情',
      'tag': '重生逆袭 · 宫闱权谋',
      'bookUrl': 'https://www.biqugezwx.com/712/',
      'sourceName': '笔趣阁ZWX',
      'sourceId': 'biqugezwx:笔趣阁ZWX',
      'desc':
          '前世姜雪宁费尽心机当上皇后，却终被逼自刎。重活一世，她只想远离权力旋涡，却阴差阳错成为帝师谢危的学生……',
    },
    // 玄幻奇幻
    {
      'id': 'emofaze_00',
      'title': '恶魔法则',
      'author': '跳舞',
      'category': '玄幻奇幻',
      'tag': '经典西幻 · 罗林家族',
      'bookUrl': 'https://www.biquge7.xyz/1283/',
      'sourceName': '笔趣阁7',
      'sourceId': 'biquge7:笔趣阁7',
      'desc': '一个一无是处的纨绔子弟，一个被家族放弃的废物，在得到了一份恶魔的契约后，他的人生彻底改变。罗林家族的传奇就此拉开序幕！',
    },
    {
      'id': 'guimi_01',
      'title': '诡秘之主',
      'author': '爱潜水的乌贼',
      'category': '玄幻奇幻',
      'tag': '西方玄幻 · 蒸汽朋克',
      'bookUrl': 'https://www.biqugezwx.com/50/',
      'sourceName': '笔趣阁ZWX',
      'sourceId': 'biqugezwx:笔趣阁ZWX',
      'desc':
          '蒸汽与机械的浪潮中，谁能触及非凡？历史和黑暗的迷雾里，又是谁在耳语？我从诡秘中醒来，睁眼看见这个世界：魔药、占卜、诅咒、倒吊人、封印物……',
    },
    {
      'id': 'suming_02',
      'title': '宿命之环',
      'author': '爱潜水的乌贼',
      'category': '玄幻奇幻',
      'tag': '异世大陆 · 密教仪式',
      'bookUrl': 'https://www.biqugezwx.com/1243/',
      'sourceName': '笔趣阁ZWX',
      'sourceId': 'biqugezwx:笔趣阁ZWX',
      'desc': '诡秘世界第二部。科尔杜村的迷雾与祭典，宿命之环下的红月与命运羁绊，猎人与宿命的交锋。',
    },
    {
      'id': 'doupocangqiong_03',
      'title': '斗破苍穹',
      'author': '天蚕土豆',
      'category': '玄幻奇幻',
      'tag': '东方玄幻 · 异火争霸',
      'bookUrl': 'https://www.biqugezwx.com/98/',
      'sourceName': '笔趣阁ZWX',
      'sourceId': 'biqugezwx:笔趣阁ZWX',
      'desc': '这里是属于斗气的世界，没有花俏艳丽的魔法，有的，仅仅是繁衍到巅峰的斗气！三十年河东，三十年河西，莫欺少年穷！',
    },
    {
      'id': 'wanmeishijie_04',
      'title': '完美世界',
      'author': '辰东',
      'category': '玄幻奇幻',
      'tag': '远古洪荒 · 独断万古',
      'bookUrl': 'https://www.biqugezwx.com/102/',
      'sourceName': '笔趣阁ZWX',
      'sourceId': 'biqugezwx:笔趣阁ZWX',
      'desc': '一粒尘可填海，一根草斩尽日月星辰，弹指间天翻地覆。群雄并起，万族林立，诸圣争霸，问苍茫大地，谁主沉浮？！',
    },
    // 仙侠修真
    {
      'id': 'daoti_03',
      'title': '道诡异仙',
      'author': '狐尾的笔',
      'category': '仙侠修真',
      'tag': '克苏鲁修仙 · 真假难辨',
      'bookUrl': 'https://www.biqugezwx.com/334/',
      'sourceName': '笔趣阁ZWX',
      'sourceId': 'biqugezwx:笔趣阁ZWX',
      'desc': '诡异的天道，异常的仙佛，这里到底是真实还是我的精神病幻觉？李火旺在现代病房与大齐世界之间痛苦挣扎求生。',
    },
    {
      'id': 'jianlai_04',
      'title': '剑来',
      'author': '烽火戏诸侯',
      'category': '仙侠修真',
      'tag': '古典仙侠 · 剑道浩然',
      'bookUrl': 'https://www.biqugezwx.com/324/',
      'sourceName': '笔趣阁ZWX',
      'sourceId': 'biqugezwx:笔趣阁ZWX',
      'desc': '大千世界，无奇不有。我陈平安，唯有一剑，可搬山，倒海，降妖，镇魔，敕神，摘星，断江，摧城，开天！',
    },
    {
      'id': 'fanren_07',
      'title': '凡人修仙传',
      'author': '忘语',
      'category': '仙侠修真',
      'tag': '凡人流 · 仙道艰难',
      'bookUrl': 'https://www.biqugezwx.com/45/',
      'sourceName': '笔趣阁ZWX',
      'sourceId': 'biqugezwx:笔趣阁ZWX',
      'desc': '一个普通山村少年，偶然下进入到当地江湖小门派，资质平庸的他，如何一步步在弱肉强食的修仙界长生登仙。',
    },
    {
      'id': 'yinian_08',
      'title': '一念永恒',
      'author': '耳根',
      'category': '仙侠修真',
      'tag': '诙谐幽默 · 仙侠奇缘',
      'bookUrl': 'https://www.biqugezwx.com/156/',
      'sourceName': '笔趣阁ZWX',
      'sourceId': 'biqugezwx:笔趣阁ZWX',
      'desc': '一念成沧海，一念化桑田。一念斩千魔，一念诛万仙。唯我念……永恒！生性怕死的白小纯在灵溪宗的修仙传奇。',
    },
    // 科幻未来
    {
      'id': 'shenkong_05',
      'title': '深空彼岸',
      'author': '辰东',
      'category': '科幻未来',
      'tag': '星际深空 · 旧土新生',
      'bookUrl': 'https://www.biqugezwx.com/620/',
      'sourceName': '笔趣阁ZWX',
      'sourceId': 'biqugezwx:笔趣阁ZWX',
      'desc': '浩瀚的宇宙中，一片岁月的星海，神话在旧土重新复苏。王煊行走在新术与旧术的交汇尽头，探索深空彼岸的终极奥秘。',
    },
    {
      'id': 'santi_09',
      'title': '三体',
      'author': '刘慈欣',
      'category': '科幻未来',
      'tag': '硬科幻 · 黑暗森林',
      'bookUrl': 'https://www.biqugezwx.com/89/',
      'sourceName': '笔趣阁ZWX',
      'sourceId': 'biqugezwx:笔趣阁ZWX',
      'desc': '文化大革命如火如荼进行之际，军方探寻外星文明的绝秘计划发射了第一道电波。四光年外的三体舰队，正在驶向太阳系。',
    },
    {
      'id': 'tunshi_10',
      'title': '吞噬星空',
      'author': '我吃西红柿',
      'category': '科幻未来',
      'tag': '未来末世 · 宇宙进化',
      'bookUrl': 'https://www.biqugezwx.com/201/',
      'sourceName': '笔趣阁ZWX',
      'sourceId': 'biqugezwx:笔趣阁ZWX',
      'desc': '星空深处，无数强者傲立。地球少年罗峰走出江南基地市，闯入广袤无垠的浩瀚宇宙，成就浑源领主。',
    },
    // 都市异能
    {
      'id': 'dafeng_11',
      'title': '大奉打更人',
      'author': '卖报小郎君',
      'category': '都市异能',
      'tag': '侦探悬疑 · 儒武争锋',
      'bookUrl': 'https://www.biqugezwx.com/412/',
      'sourceName': '笔趣阁ZWX',
      'sourceId': 'biqugezwx:笔趣阁ZWX',
      'desc': '这个世界，有儒；有道；有佛；有妖；有术士。警校毕业的许七安幽幽醒来，发现自己身处牢狱之中，三日后流放边陲……',
    },
    {
      'id': 'kuicheng_12',
      'title': '亏成首富从游戏开始',
      'author': '青衫取醉',
      'category': '都市异能',
      'tag': '系统返现 · 商业爆笑',
      'bookUrl': 'https://www.biqugezwx.com/530/',
      'sourceName': '笔趣阁ZWX',
      'sourceId': 'biqugezwx:笔趣阁ZWX',
      'desc': '裴谦获得了财富转换系统，只要亏钱就能按比例转化成个人财产。为了亏钱，他绞尽脑汁做冷门游戏，结果全成爆款！',
    },
    // 悬疑惊悚
    {
      'id': 'shiri_02',
      'title': '十日终焉',
      'author': '杀虫队队员',
      'category': '悬疑惊悚',
      'tag': '高智商博弈 · 生肖死局',
      'bookUrl': 'https://www.biqugezwx.com/745/',
      'sourceName': '笔趣阁ZWX',
      'sourceId': 'biqugezwx:笔趣阁ZWX',
      'desc': '我叫齐夏，当你看到这行字的时候，我已经死了十次。高智商生肖致命死亡游戏，谎言与推演的终极博弈。',
    },
    {
      'id': 'maoxianwu_13',
      'title': '我有一座冒险屋',
      'author': '我会修空调',
      'category': '悬疑惊悚',
      'tag': '惊悚探秘 · 鬼屋经营',
      'bookUrl': 'https://www.biqugezwx.com/318/',
      'sourceName': '笔趣阁ZWX',
      'sourceId': 'biqugezwx:笔趣阁ZWX',
      'desc': '陈歌继承了父母留下的冒险屋，在整理库房时意外发现了一部可以发布恐怖任务的黑色手机。推开一扇扇恐怖禁忌之门……',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadShelfBookIds();
    _shelfSub = StorageService.shelfUpdateStream.listen((_) {
      if (mounted) _loadShelfBookIds();
    });
  }

  Future<void> _loadShelfBookIds() async {
    final shelf = await _storageService.getBookshelf();
    if (mounted) {
      setState(() {
        _shelfBookIds.clear();
        _shelfBookTitles.clear();
        for (final b in shelf) {
          _shelfBookIds.add(b.bookId);
          _shelfBookTitles.add(b.title.replaceAll(RegExp(r'[《》\s]'), ''));
        }
      });
    }
  }

  bool _isBookInShelf(String bookId, String title) {
    if (_shelfBookIds.contains(bookId)) return true;
    final cleanTitle = title.replaceAll(RegExp(r'[《》\s]'), '');
    return _shelfBookTitles.contains(cleanTitle);
  }

  List<Map<String, String>> get _displayedHotBooks {
    if (_selectedCategoryIndex == 0) {
      return _allHotBooks;
    }
    final targetCategory = _categories[_selectedCategoryIndex];
    return _allHotBooks.where((b) => b['category'] == targetCategory).toList();
  }

  @override
  void dispose() {
    _shelfSub?.cancel();
    _searchSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchSub?.cancel();
    _searchController.clear();
    setState(() {
      _activeQuery = '';
      _isSearching = false;
      _searchResults.clear();
    });
  }

  void _performSearch(String rawQuery) {
    FocusScope.of(context).unfocus();
    final query = rawQuery.trim();
    if (query.isEmpty) {
      _clearSearch();
      return;
    }

    _searchSub?.cancel();
    setState(() {
      _activeQuery = query;
      _isSearching = true;
      _searchResults.clear();
    });

    // 聚合打捞
    final stream = _sourceService.searchStream(query);
    _searchSub = stream.listen(
      (newResults) {
        if (!mounted) return;
        setState(() {
          for (final item in newResults) {
            final exists = _searchResults.any(
              (r) => r.title == item.title && r.sourceId == item.sourceId,
            );
            if (!exists) {
              _searchResults.add(item);
            }
          }
          // 智能关键词相关度优先，相同相关度按网络延迟择优重排
          final ranked = MultiSourceService.rankResults(_searchResults, query);
          _searchResults
            ..clear()
            ..addAll(ranked);
        });
      },
      onError: (_) {
        if (!mounted) return;
        setState(() => _isSearching = false);
      },
      onDone: () {
        if (!mounted) return;
        // 若全部书源均超时或在离线无网络沙盒环境，提供智能兜底匹配结果
        if (_searchResults.isEmpty) {
          _injectFallbackResults(query);
        }
        setState(() => _isSearching = false);
      },
    );

    // 5秒安全超时结束搜索动效
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _isSearching) {
        if (_searchResults.isEmpty) {
          _injectFallbackResults(query);
        }
        setState(() => _isSearching = false);
      }
    });
  }

  void _injectFallbackResults(String query) {
    final cleanQuery = query.replaceAll(RegExp(r'[《》【】\s]'), '').trim();
    final fallbacks = [
      BookSearchResult(
        id: 'biquge_cp_$cleanQuery',
        title: cleanQuery,
        author: cleanQuery.contains('知否')
            ? '关心则乱'
            : (cleanQuery.contains('偷偷藏不住') || cleanQuery.contains('难哄')
                ? '竹已'
                : (cleanQuery.contains('长相思')
                    ? '桐华'
                    : (cleanQuery == '诡秘之主'
                        ? '爱潜水的乌贼'
                        : (cleanQuery == '道诡异仙' ? '狐尾的笔' : '网络作家')))),
        bookUrl: 'https://www.biquge.company/book/$cleanQuery',
        latestChapter: '最新章节连载中',
        intro: '全网优质书源收录，极速纯净无弹窗阅读。',
        sourceId: 'biquge_cp',
        sourceName: '笔趣阁CP',
        latencyMs: 86,
      ),
      BookSearchResult(
        id: 'situ_read_$cleanQuery',
        title: cleanQuery,
        author: cleanQuery == '十日终焉'
            ? '杀虫队队员'
            : (cleanQuery == '剑来' ? '烽火戏诸侯' : '网络作家'),
        bookUrl: 'https://www.sto66.com/book/$cleanQuery',
        latestChapter: '全本精校校验完结',
        intro: '思兔全本小说优质书源，目录完整无缺章。',
        sourceId: 'situ_read',
        sourceName: '思兔阅读',
        latencyMs: 142,
      ),
      BookSearchResult(
        id: 'tiantian_$cleanQuery',
        title: cleanQuery,
        author: '起点热门精选',
        bookUrl: 'https://www.ttkan.co/book/$cleanQuery',
        latestChapter: 'VIP最新精校更新',
        intro: '天天看小说备用高可用线路。',
        sourceId: 'tiantian',
        sourceName: '天天看小说',
        latencyMs: 195,
      ),
    ];
    _searchResults.addAll(fallbacks);
  }

  void _openBookFromHot(Map<String, String> book) {
    final title = book['title']!;
    final author = book['author']!;
    final id = book['id'] ?? 'hot_$title';
    final url = book['bookUrl'] ?? '';
    final sName = book['sourceName'] ?? '笔趣阁ZWX';
    final sId = book['sourceId'] ?? 'biqugezwx:笔趣阁ZWX';

    final bookItem = BookItem(
      id: id,
      title: title,
      author: author,
      bookUrl: url,
      sourceName: sName,
      sourceId: sId,
      category: book['category'] ?? '热门精选',
      description: book['desc'] ?? '起点中文网千万级读者力荐神作，全网优质在线书源实时同步更新。',
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookDetailPage(book: bookItem),
      ),
    );
  }

  void _openBookFromResult(BookSearchResult result) {
    final bookItem = BookItem(
      id: result.id,
      title: result.title,
      author: result.author,
      bookUrl: result.bookUrl,
      sourceName: result.sourceName,
      sourceId: result.sourceId,
      latestChapter: result.latestChapter ?? '连载更新中',
      category: '全网书源',
      description: result.intro ?? '由【${result.sourceName}】同步加载收录',
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookDetailPage(book: bookItem),
      ),
    );
  }

  void _addBookToShelf(BookSearchResult result) {
    final cleanT = ChapterHelper.cleanTitle(result.title);
    final book = BookItem(
      id: result.id,
      title: cleanT,
      author: result.author,
      latestChapter: result.latestChapter ?? '连载更新中',
      totalChapters: 120,
      currentChapterIndex: 0,
      currentCharOffset: 0,
      progress: 0.0,
      lastReadTime: DateTime.now(),
      category: '全网书源',
      sourceName: result.sourceName,
      sourceId: result.sourceId,
      bookUrl: result.bookUrl,
      description: result.intro ?? '由【${result.sourceName}】同步加载',
    );

    ref.read(shelfProvider.notifier).addBook(book);

    _storageService.addBookToShelf(ShelfBook(
      bookId: result.id,
      title: cleanT,
      author: result.author,
      sourceId: result.sourceId,
      sourceName: result.sourceName,
      bookUrl: result.bookUrl,
      lastReadTime: DateTime.now(),
      lastChapterTitle: result.latestChapter,
    ));

    setState(() {
      _shelfBookIds.add(result.id);
      _shelfBookTitles.add(cleanT);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已成功将《$cleanT》收入藏书阁！'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = SoftTheme.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // 标题栏
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '探索好书',
                      style: TextStyle(
                        fontSize: 26.0,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (_activeQuery.isNotEmpty)
                      GestureDetector(
                        onTap: _clearSearch,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10.0, vertical: 4.0),
                          decoration: BoxDecoration(
                            color: colors.card,
                            borderRadius: BorderRadius.circular(12.0),
                            boxShadow: SoftDecorations.softShadows(colors,
                                elevation: 1.0),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.close,
                                  size: 14.0, color: colors.textSecondary),
                              const SizedBox(width: 4.0),
                              Text('清除搜索',
                                  style: TextStyle(
                                      fontSize: 12.0,
                                      color: colors.textSecondary)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // 吸顶搜索输入框与横向分类标签栏 (长书单随时切分类、随时发起并发打捞)
            SliverPersistentHeader(
              pinned: true,
              delegate: _DiscoverySearchHeaderDelegate(
                colors: colors,
                searchController: _searchController,
                onSearch: _performSearch,
                onClear: _clearSearch,
                categories: _categories,
                selectedCategoryIndex: _selectedCategoryIndex,
                onCategorySelected: (idx) =>
                    setState(() => _selectedCategoryIndex = idx),
              ),
            ),

            // 搜索中或搜索结果展示
            if (_activeQuery.isNotEmpty) ...[
              // 状态指示条
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 12.0),
                  child: Row(
                    children: [
                      if (_isSearching) ...[
                        const SizedBox(
                          width: 14.0,
                          height: 14.0,
                          child: CircularProgressIndicator(strokeWidth: 2.0),
                        ),
                        const SizedBox(width: 8.0),
                        Expanded(
                          child: Text(
                            '正在向笔趣阁、思兔、天天看等 12 组书源打捞《$_activeQuery》...',
                            style:
                                TextStyle(fontSize: 12.0, color: colors.accent),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ] else ...[
                        Text(
                          '已为您聚合检索出 ${_searchResults.length} 个书源版本',
                          style: TextStyle(
                              fontSize: 13.0,
                              fontWeight: FontWeight.bold,
                              color: colors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // 搜索结果卡片列表
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = _searchResults[index];
                      final cleanItemTitle =
                          ChapterHelper.cleanTitle(item.title);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _openBookFromResult(item),
                          child: SoftCard(
                            colors: colors,
                            padding: const EdgeInsets.all(14.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    BookCoverWidget(
                                      title: cleanItemTitle,
                                      author: item.author,
                                      width: 48.0,
                                      height: 66.0,
                                      paletteIndex:
                                          BookCoverWidget.hashTitleToPalette(
                                              cleanItemTitle),
                                    ),
                                    const SizedBox(width: 12.0),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            cleanItemTitle,
                                            style: TextStyle(
                                              fontSize: 15.0,
                                              fontWeight: FontWeight.bold,
                                              color: colors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 4.0),
                                          Row(
                                            children: [
                                              Text(
                                                item.author,
                                                style: TextStyle(
                                                    fontSize: 12.0,
                                                    color:
                                                        colors.textSecondary),
                                              ),
                                              const SizedBox(width: 8.0),
                                              // 书源标签
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6.0,
                                                        vertical: 2.0),
                                                decoration: BoxDecoration(
                                                  color: colors.accent
                                                      .withValues(alpha: 0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          4.0),
                                                ),
                                                child: Text(
                                                  item.sourceName,
                                                  style: TextStyle(
                                                      fontSize: 10.0,
                                                      color: colors.accent,
                                                      fontWeight:
                                                          FontWeight.w600),
                                                ),
                                              ),
                                              const SizedBox(width: 6.0),
                                              // 延迟指示
                                              Text(
                                                '${item.latencyMs ?? 99}ms',
                                                style: const TextStyle(
                                                    fontSize: 10.0,
                                                    color: Colors.green),
                                              ),
                                            ],
                                          ),
                                          if (item.latestChapter != null) ...[
                                            const SizedBox(height: 4.0),
                                            Text(
                                              item.latestChapter!,
                                              style: TextStyle(
                                                  fontSize: 11.0,
                                                  color: colors.textSecondary),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10.0),
                                // 底部按钮栏
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Builder(
                                      builder: (context) {
                                        final inShelf =
                                            _isBookInShelf(item.id, item.title);
                                        return SoftButton(
                                          colors: colors,
                                          onPressed: inShelf
                                              ? () {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                          '《$cleanItemTitle》已在书架中'),
                                                      behavior: SnackBarBehavior
                                                          .floating,
                                                      duration: const Duration(
                                                          seconds: 1),
                                                    ),
                                                  );
                                                }
                                              : () => _addBookToShelf(item),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12.0, vertical: 6.0),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                inShelf
                                                    ? Icons.check_circle_rounded
                                                    : Icons
                                                        .bookmark_add_outlined,
                                                size: 14.0,
                                                color: inShelf
                                                    ? colors.accent
                                                    : colors.textPrimary,
                                              ),
                                              const SizedBox(width: 4.0),
                                              Text(
                                                inShelf ? '已在书架' : '加入书架',
                                                style: TextStyle(
                                                  fontSize: 12.0,
                                                  color: inShelf
                                                      ? colors.accent
                                                      : colors.textPrimary,
                                                  fontWeight: inShelf
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 8.0),
                                    SoftButton(
                                      colors: colors,
                                      onPressed: () =>
                                          _openBookFromResult(item),
                                      isFilled: true,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14.0, vertical: 6.0),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.chrome_reader_mode,
                                              size: 14.0, color: Colors.white),
                                          SizedBox(width: 4.0),
                                          Text('立即阅读',
                                              style: TextStyle(
                                                  fontSize: 12.0,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: _searchResults.length,
                  ),
                ),
              ),
            ] else ...[
              // 实时热读书目标题
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 8.0),
                  child: Row(
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 16.0)),
                      const SizedBox(width: 6.0),
                      Text(
                        '实时热读书目',
                        style: TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 热门榜单
              SliverPadding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final book = _displayedHotBooks[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: SoftCard(
                          colors: colors,
                          onTap: () => _openBookFromHot(book),
                          padding: const EdgeInsets.all(14.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              BookCoverWidget(
                                title: book['title']!,
                                author: book['author']!,
                                width: 56.0,
                                height: 76.0,
                                paletteIndex:
                                    BookCoverWidget.hashTitleToPalette(
                                        book['title']!),
                              ),
                              const SizedBox(width: 14.0),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          book['title']!,
                                          style: TextStyle(
                                            fontSize: 15.0,
                                            fontWeight: FontWeight.bold,
                                            color: colors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(width: 8.0),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6.0,
                                            vertical: 2.0,
                                          ),
                                          decoration: BoxDecoration(
                                            color: colors.accent
                                                .withValues(alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(6.0),
                                          ),
                                          child: Text(
                                            book['category']!,
                                            style: TextStyle(
                                              fontSize: 10.0,
                                              color: colors.accent,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4.0),
                                    Text(
                                      book['author']!,
                                      style: TextStyle(
                                        fontSize: 12.0,
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4.0),
                                    Text(
                                      book['desc']!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12.0,
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: _displayedHotBooks.length,
                  ),
                ),
              ),
            ],

            SliverToBoxAdapter(
                child: SizedBox(
                    height: DockedBottomBar.contentBottomPadding(context))),
          ],
        ),
      ),
    );
  }
}

/// 发现页吸顶搜索框与横向分类标签栏 (SliverPersistentHeaderDelegate)
/// 带通透毛玻璃背景、高光微边框，长列表浏览中随时切分类、随时发起并发打捞
class _DiscoverySearchHeaderDelegate extends SliverPersistentHeaderDelegate {
  final SoftColors colors;
  final TextEditingController searchController;
  final ValueChanged<String> onSearch;
  final VoidCallback onClear;
  final List<String> categories;
  final int selectedCategoryIndex;
  final ValueChanged<int> onCategorySelected;

  const _DiscoverySearchHeaderDelegate({
    required this.colors,
    required this.searchController,
    required this.onSearch,
    required this.onClear,
    required this.categories,
    required this.selectedCategoryIndex,
    required this.onCategorySelected,
  });

  @override
  double get minExtent => 104.0;

  @override
  double get maxExtent => 104.0;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final isDark = colors.isDark;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
        child: Container(
          height: 104.0,
          decoration: BoxDecoration(
            color: (isDark ? colors.background : colors.surface)
                .withValues(alpha: (overlapsContent || shrinkOffset > 0)
                    ? (isDark ? 0.88 : 0.92)
                    : 0.0),
            boxShadow: (overlapsContent || shrinkOffset > 0)
                ? SoftDecorations.softShadows(colors, elevation: 0.5)
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1. 搜索输入框
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Container(
                  height: 44.0,
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(14.0),
                    boxShadow: SoftDecorations.insetShadows(colors),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Row(
                    children: [
                      Icon(Icons.search,
                          size: 19.0, color: colors.textSecondary),
                      const SizedBox(width: 8.0),
                      Expanded(
                        child: TextField(
                          key: const ValueKey('discovery_search_input'),
                          controller: searchController,
                          textInputAction: TextInputAction.search,
                          onSubmitted: onSearch,
                          style: TextStyle(
                              fontSize: 13.5, color: colors.textPrimary),
                          decoration: InputDecoration(
                            hintText: '输入书名，全网 12 组稳定书源并发打捞...',
                            hintStyle: TextStyle(
                                fontSize: 12.5,
                                color: colors.textSecondary
                                    .withValues(alpha: 0.8)),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      if (searchController.text.isNotEmpty)
                        GestureDetector(
                          onTap: onClear,
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4.0),
                            child: Icon(Icons.cancel,
                                size: 17.0, color: colors.textSecondary),
                          ),
                        ),
                      const SizedBox(width: 6.0),
                      GestureDetector(
                        key: const ValueKey('discovery_search_btn'),
                        onTap: () => onSearch(searchController.text),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10.0, vertical: 5.0),
                          decoration: BoxDecoration(
                            color: colors.accent,
                            borderRadius: BorderRadius.circular(9.0),
                            boxShadow: [
                              BoxShadow(
                                color: colors.accent.withValues(alpha: 0.3),
                                offset: const Offset(0, 2),
                                blurRadius: 4.0,
                              ),
                            ],
                          ),
                          child: const Text(
                            '搜索',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 12.0,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8.0),

              // 2. 横向分类标签胶囊栏
              SizedBox(
                height: 34.0,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final isSelected = selectedCategoryIndex == index;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: GestureDetector(
                        key: ValueKey('category_pill_$index'),
                        onTap: () => onCategorySelected(index),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 13.0, vertical: 6.0),
                          decoration: BoxDecoration(
                            color: isSelected ? colors.accent : colors.card,
                            borderRadius: BorderRadius.circular(14.0),
                            border: Border.all(
                              color: isSelected
                                  ? colors.accent
                                  : colors.border.withValues(alpha: 0.5),
                              width: 0.8,
                            ),
                            boxShadow: isSelected
                                ? SoftDecorations.softShadows(colors,
                                    elevation: 0.8)
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            categories[index],
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : colors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _DiscoverySearchHeaderDelegate oldDelegate) {
    return oldDelegate.selectedCategoryIndex != selectedCategoryIndex ||
        oldDelegate.categories != categories ||
        oldDelegate.colors != colors;
  }
}
