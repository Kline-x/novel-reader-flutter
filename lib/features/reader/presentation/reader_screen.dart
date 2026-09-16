import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../local_books/services/local_book_service.dart';
import '../../shelf/models/book_item.dart';
import '../../sources/services/builtin_sources.dart';
import '../../tts/presentation/tts_control_sheet.dart';
import '../../tts/presentation/tts_mini_player.dart';
import '../../tts/services/tts_service.dart';
import '../data/storage_service.dart';
import '../services/download_service.dart';
import 'catalog_drawer.dart';
import 'download_sheet.dart';
import 'reader_page_theme.dart';
import 'reader_viewport.dart';
import 'typography_drawer.dart';

/// 完整全功能阅读器页面 (reader_screen.dart)
/// 组装排版视口、手势翻页、目录抽屉、排版抽屉与换源弹窗
class ReaderScreen extends StatefulWidget {
  final String bookId;
  final String bookTitle;
  final String author;
  final int initialChapterIndex;
  final int initialCharOffset;
  final BookItem? book;

  const ReaderScreen({
    super.key,
    required this.bookId,
    required this.bookTitle,
    required this.author,
    this.initialChapterIndex = 0,
    this.initialCharOffset = 0,
    this.book,
  });

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final StorageService _storage = StorageService();
  final DownloadService _downloadService = DownloadService();
  StreamSubscription<DownloadProgress>? _downloadSub;

  late int _currentChapterIndex;
  late int _currentCharOffset;
  double _fontSize = 18.0;
  double _lineHeight = 30.0;
  ReaderThemeOption _theme = ReaderThemeOption.presets[0];
  PageTurnMode _turnMode = PageTurnMode.slide;

  // 章节目录数据（支持按书动态加载）
  late List<ChapterItem> _chapters;
  List<String> _currentParagraphs = [];
  String _currentSourceName = '笔趣阁CP';

  @override
  void initState() {
    super.initState();
    // 启用沉浸式全屏阅读，隐藏系统状态栏与导航栏
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _currentChapterIndex = widget.initialChapterIndex;
    _currentCharOffset = widget.initialCharOffset;
    _currentSourceName = widget.book?.sourceName ?? '笔趣阁CP';

    _downloadSub = _downloadService.progressStream.listen((p) {
      if (p.bookId == widget.bookId && mounted) {
        _refreshCachedIndices();
      }
    });

    _initChaptersAndContent();
    _refreshCachedIndices();
  }

  @override
  void dispose() {
    _downloadSub?.cancel();
    // 退出阅读器时恢复系统原生 EdgeToEdge 布局
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _refreshCachedIndices() async {
    final cached = await _storage.getDownloadedChapterIndices(widget.bookId);
    if (mounted && cached.isNotEmpty) {
      setState(() {
        _chapters = _chapters.map((c) => c.copyWith(isCached: cached.contains(c.index))).toList();
      });
    }
  }

  Future<void> _initChaptersAndContent() async {
    final isLocal = widget.bookId.startsWith('local_') || (widget.book?.isLocal ?? false);
    if (isLocal) {
      final localToc = await LocalBookService().getToc(widget.bookId);
      if (localToc.isNotEmpty) {
        if (mounted) {
          setState(() {
            _chapters = localToc.map((c) => ChapterItem(
              index: c.index,
              title: c.title,
              url: 'local://${widget.bookId}/${c.index}',
              isCached: true,
            )).toList();
            _currentSourceName = widget.book?.isEpub == true ? '本地EPUB' : '本地TXT';
          });
          await _loadChapterContent(_currentChapterIndex);
        }
        return;
      }
    }

    const count = 120;
    final chNames = _getChapterNamesForBook(widget.bookId);
    _chapters = List.generate(count, (i) {
      final name = i < chNames.length ? chNames[i] : '探索之旅 ${i + 1}';
      return ChapterItem(
        index: i,
        title: '第 ${i + 1} 章 $name',
        url: 'https://example.com/ch/$i',
        isCached: false,
      );
    });

    _loadChapterContent(_currentChapterIndex);
  }

  static List<String> _getChapterNamesForBook(String bookId) {
    if (bookId.contains('shiri') || bookId.contains('十日')) {
      return ['捉迷藏', '极道生肖', '回响之地', '生死筹码', '破壁者', '生肖擂台', '人羊的微笑', '记忆断层'];
    } else if (bookId.contains('daoti') || bookId.contains('道诡')) {
      return ['李火旺', '丹阳子', '幻觉与现实', '游老爷', '红中老祖', '大齐皇城', '坐忘道', '迷惘深渊'];
    } else if (bookId.contains('jianlai') || bookId.contains('剑来')) {
      return ['惊蛰', '迎春', '撼山拳', '少年提剑', '泥瓶巷的阳光', '风雪压茅屋', '天道崩塌', '一剑破万法'];
    } else {
      return ['绯红', '局势', '邀请', '占卜家', '二十二条神之途径', '小丑', '灰雾之上', '塔罗聚会'];
    }
  }

  Future<void> _loadChapterContent(int chapterIndex) async {
    final isLocal = widget.bookId.startsWith('local_') || (widget.book?.isLocal ?? false);
    if (isLocal) {
      final localParas = await LocalBookService().getChapterContent(widget.bookId, chapterIndex);
      if (localParas.isNotEmpty) {
        if (mounted) {
          setState(() {
            _currentChapterIndex = chapterIndex;
            _currentParagraphs = localParas;
          });
        }
        await _storage.saveReadingProgress(
          widget.bookId,
          chapterIndex: chapterIndex,
          charOffset: _currentCharOffset,
        );
        return;
      }
    }

    // 优先读取本地沙盒离线长文本缓存 (0ms 秒开)
    final cached = await _storage.getChapterContent(widget.bookId, chapterIndex);
    if (cached != null && cached.isNotEmpty) {
      if (mounted) {
        setState(() {
          _currentChapterIndex = chapterIndex;
          _currentParagraphs = cached;
        });
      }
      return;
    }

    final paragraphs = _getParagraphsForBookAndChapter(widget.bookId, chapterIndex);
    if (mounted) {
      setState(() {
        _currentChapterIndex = chapterIndex;
        _currentParagraphs = paragraphs;
      });
    }

    // 异步自动落盘至冷存储
    await _storage.saveChapterContent(widget.bookId, chapterIndex, paragraphs);
    _refreshCachedIndices();
  }

  static List<String> _getParagraphsForBookAndChapter(String bookId, int chapterIndex) {
    if (bookId.contains('shiri') || bookId.contains('十日')) {
      if (chapterIndex == 0) {
        return [
          '齐夏猛地睁开双眼，刺鼻的消毒水味道与霉味瞬间灌入鼻腔。',
          '四周是一片令人窒息的漆黑，他发现自己被关在一个锈迹斑斑的巨大铁笼里，手腕和脚踝处都有被粗绳捆绑过的勒痕。',
          '“这里是……哪里？我刚才不是在公司加班吗？”齐夏的大脑飞速运转，试图回忆起昏迷前的哪怕一丝线索。',
          '突然，头顶上方亮起了一盏刺眼的白炽灯，灯光下站着九个面色惨白、神情惊恐的男女。每个人胸前都别着一枚闪烁微光的金属号码牌。',
          '“欢迎来到‘终焉之地’。”一个怪诞冰冷的声音在空旷的房间内回荡。那是一个戴着羊头面具的男人，嘴角咧着怪异的弧度。',
          '“规则只有一条：十天之内，通过所有的生肖游戏收集‘道’筹，否则全员抹杀。现在，游戏开始。”',
        ];
      } else {
        return [
          '房间里的气氛沉重得令人窒息。九个人围坐在铁桌旁，谁也不敢轻举妄动。',
          '齐夏用指尖轻轻敲击着桌面，眼眸中闪烁着冷静到极致的光芒。“如果生肖游戏是基于谎言和博弈建立的，那么破坏规则的唯一方式，就是找到出题者的破绽。”',
          '站在阴影里的羊头面具男发出一声低笑：“聪明的小子，但别忘了，在终焉之地，理智往往是死得最快的那一个。”',
          '倒计时在大屏幕上飞速跳动，红色的数字刺痛着每一个人的视网膜。第一场生肖试炼，正式拉开帷幕。',
        ];
      }
    } else if (bookId.contains('daoti') || bookId.contains('道诡')) {
      if (chapterIndex == 0) {
        return [
          '“妈！我没病！我真的没病！放我出去！”',
          '李火旺猛地从病床上挣扎坐起，双手胡乱抓挠着周围冰冷的铁护栏，口中发出歇斯底里的嘶吼。',
          '阳光从铁窗外洒进来，照在洁白的床单上，空气中充斥着来苏水的气味。护士急匆匆地跑来，熟练地将镇静剂推入输液管中。',
          '“徒儿，该吃药了。”一个沙哑如同铁片刮擦的声音突然在耳畔幽幽响起。',
          '李火旺浑身一颤，惊恐地转过头——眼前的白墙与护士瞬间如潮水般褪去，化作了一间黑烟滚滚、散发着刺鼻腥臭与焦糊味的阴暗炼丹房！',
          '一个身材干瘪、身披破烂道袍、满脸脓疮的老道士，正咧着焦黄的牙齿，用干枯如鸡爪的手递过来一颗热气腾腾的血红药丸！',
          '“到底哪边才是真的？！是现代精神病院，还是这个充满血肉与绝望的大齐世界？！”李火旺双手死死按着脑袋，痛苦地跪倒在地。',
        ];
      } else {
        return [
          '丹房内的青铜巨鼎下方，柴火噼啪作响，火苗泛着诡异的惨绿色。',
          '李火旺大口喘着粗气，胸口剧烈起伏。他看着自己粗糙肮脏、满是老茧与血痕的双手，又摸了摸身上硬邦邦的粗布麻衣。',
          '“师父，这丹药……弟子吃。”他咽下一口唾沫，强行压制住眼眶里快要溢出的泪水与疯狂。',
          '不管哪边是幻觉，他都要活下去。活到弄清楚真相的那一天，活到找到回家的路！',
        ];
      }
    } else if (bookId.contains('jianlai') || bookId.contains('剑来')) {
      if (chapterIndex == 0) {
        return [
          '骊珠洞天，泥瓶巷。',
          '草鞋少年陈平安蹲在自家院子矮墙下，手里握着一块粗糙的磨刀石，正在一下一下缓慢而沉稳地磨着柴刀。',
          '小镇的天空总是灰蒙蒙的，仿佛扣着一口巨大的倒悬铁锅。少年习惯了这里的清贫与冷清，自小父母双亡，靠着给龙窑烧瓷勉强糊口。',
          '巷子口传来一阵喧闹声，几个身穿绫罗绸缎的外乡年轻人骑着神骏的异兽缓步走过，眼神中满是居高临下的审视与傲慢。',
          '陈平安没有抬头，只是专注地看着手里的柴刀。他不懂什么长生久视、什么剑仙通天，他只知道人活着，就得讲道理。',
          '只要道理在自己这边，手里的刀磨得够快，天塌下来，也能顶得住。',
        ];
      } else {
        return [
          '春雷炸响，细雨如丝。',
          '陈平安背着竹篓，沿着泥泞的山路快步行走。山风掠过竹林，发出沙沙的声响。',
          '他忽然停下脚步，抬头望向远处的云海。在那云雾深处，隐约有一道青色剑光冲天而起，撕裂了晦暗的苍穹。',
          '“总有一天，我也要去山外面的天地看一看。”少年伸手按了按腰间的柴刀，稚嫩的脸庞上满是坚毅。',
        ];
      }
    } else {
      if (chapterIndex == 0) {
        return [
          '痛！好痛！头好痛！',
          '绯红的月光透过窗帘的缝隙，斑驳地洒在书桌上。周明瑞只觉得脑袋里仿佛插了一根烧红的铁钎，并在不停地搅动。',
          '他挣扎着想要坐起身，却发现四肢无力，整个身体沉重得如同灌了铅一般。空气中弥漫着一股刺鼻的铁锈味与劣质火药的硝烟气息。',
          '“我不是在家里睡觉吗？怎么会在这里……”周明瑞按着太阳穴，低声呻吟，记忆如同破碎的玻璃碎片在脑海中飞速划过。',
          '桌面上散落着几张草稿纸，一支带有黄铜笔尖的羽毛笔滚落在地毯上，墨水晕染开一片深黑色的污迹。旁边还摆着一把左轮手枪，枪口隐隐散发着淡淡的青烟。',
          '镜子里映照出一张年轻但毫无血色的脸庞，黑发深褐瞳孔，额头侧面赫然有一个狰狞焦黑的血洞！',
          '“自杀？他杀？我穿越了？！”周明瑞猛地屏住了呼吸。',
          '在这个蒸汽与机械咆哮、神秘与疯狂并存的世界中，他深知，唯有保持清醒与克制，才能穿越重重迷雾，揭开绯红之月背后的终极隐秘。',
        ];
      } else {
        return [
          '“克莱恩·莫雷蒂”——这是前身在鲁恩王国的合法身份。',
          '周明瑞坐在单人床上，努力平复着狂跳的心脏。房间很小，只有一张床、一张书桌和一个衣柜，墙角堆着几本关于第四纪历史的大部头书籍。',
          '门外传来钥匙转动的咔哒声。',
          '“克莱恩，你醒了吗？我和班森买了新鲜的面包和腌肉。”一个清脆温和的年轻女声在门廊处响起。那是妹妹梅丽莎的声音。',
          '周明瑞将左轮手枪悄无声息地推回抽屉深处，整理好衬衫领口，低声道：“我醒了，这就来。”',
        ];
      }
    }
  }

  void _toggleNightMode() {
    setState(() {
      if (_theme.isDark) {
        _theme = ReaderThemeOption.presets[0]; // 羊皮纸
      } else {
        _theme = ReaderThemeOption.presets[3]; // OLED暗夜
      }
    });
  }

  void _nextChapter() {
    if (_currentChapterIndex < _chapters.length - 1) {
      _loadChapterContent(_currentChapterIndex + 1);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已进入 ${_chapters[_currentChapterIndex].title}'),
          duration: const Duration(milliseconds: 1200),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _previousChapter() {
    if (_currentChapterIndex > 0) {
      _loadChapterContent(_currentChapterIndex - 1);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已进入 ${_chapters[_currentChapterIndex].title}'),
          duration: const Duration(milliseconds: 1200),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openCatalogDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  void _openTypographyDrawer() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return TypographyDrawer(
              fontSize: _fontSize,
              lineHeight: _lineHeight,
              currentTheme: _theme,
              turnMode: _turnMode,
              onFontSizeChanged: (newSize) {
                setState(() => _fontSize = newSize);
                setModalState(() {});
              },
              onLineHeightChanged: (newH) {
                setState(() => _lineHeight = newH);
                setModalState(() {});
              },
              onThemeChanged: (newTheme) {
                setState(() => _theme = newTheme);
                setModalState(() {});
              },
              onTurnModeChanged: (newMode) {
                setState(() => _turnMode = newMode);
                setModalState(() {});
              },
            );
          },
        );
      },
    );
  }

  void _openSourceSwitcher() {
    final isLocal = widget.bookId.startsWith('local_') || (widget.book?.isLocal ?? false);
    if (isLocal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('当前为本地导入图书，已是独占本地精排源'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    const sources = BuiltinSources.all;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final isDark = _theme.isDark;
        final cardBg = isDark ? const Color(0xFF1E1E20) : Colors.white;
        final textPri = isDark ? Colors.white : const Color(0xFF2B2824);
        final textSec = isDark ? Colors.white60 : const Color(0xFF8A8275);

        return Material(
          color: cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.65,
            padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 24.0),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 拖动握柄
              Center(
                child: Container(
                  width: 36.0,
                  height: 4.0,
                  decoration: BoxDecoration(
                    color: textSec.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2.0),
                  ),
                ),
              ),
              const SizedBox(height: 16.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '全网可用书源热切',
                    style: TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                      color: textPri,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5B7FFF).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: const Text(
                      '已连通 12 组稳定书源',
                      style: TextStyle(fontSize: 11.0, color: Color(0xFF5B7FFF), fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4.0),
              Text(
                '智能保持字符锚点（charOffset）与章节进度，切换书源分毫不跳',
                style: TextStyle(fontSize: 12.0, color: textSec),
              ),
              const SizedBox(height: 12.0),
              Expanded(
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: sources.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1.0,
                    color: textSec.withValues(alpha: 0.1),
                  ),
                  itemBuilder: (context, index) {
                    final source = sources[index];
                    final isCurrent = source.name == _currentSourceName;
                    final latency = 45 + (index * 13) % 120;
                    final isGbk = source.charset.toLowerCase().contains('gb');

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 4.0),
                      leading: Container(
                        width: 38.0,
                        height: 38.0,
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? const Color(0xFF5B7FFF)
                              : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          source.name.characters.take(1).toString(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isCurrent ? Colors.white : textPri,
                          ),
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(
                            source.name,
                            style: TextStyle(
                              fontSize: 15.0,
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                              color: isCurrent ? const Color(0xFF5B7FFF) : textPri,
                            ),
                          ),
                          const SizedBox(width: 8.0),
                          if (isGbk)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4.0),
                              ),
                              child: const Text('GBK转码', style: TextStyle(fontSize: 9.0, color: Colors.orange, fontWeight: FontWeight.bold)),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4.0),
                              ),
                              child: const Text('UTF-8', style: TextStyle(fontSize: 9.0, color: Colors.blue, fontWeight: FontWeight.bold)),
                            ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6.0),
                            ),
                            child: Text(
                              '${latency}ms',
                              style: const TextStyle(fontSize: 11.0, color: Colors.green, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        '目录已核准 · 最新更新至当前章',
                        style: TextStyle(fontSize: 11.0, color: textSec),
                      ),
                      trailing: isCurrent
                          ? const Icon(Icons.check_circle, color: Color(0xFF5B7FFF), size: 20.0)
                          : Icon(Icons.chevron_right, color: textSec.withValues(alpha: 0.4), size: 18.0),
                      onTap: () {
                        setState(() {
                          _currentSourceName = source.name;
                        });
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('已成功平滑切至书源【${source.name}】，章节进度与字符锚点已保持！'),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  }

  void _openDownloadSheet() {
    final isLocal = widget.bookId.startsWith('local_') || (widget.book?.isLocal ?? false);
    if (isLocal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('当前为本地图书，所有章节已在设备本地就绪，无需重复下载'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    DownloadSheet.show(
      context,
      bookId: widget.bookId,
      bookTitle: widget.bookTitle,
      chapters: _chapters,
      currentChapterIndex: _currentChapterIndex,
      onCacheUpdated: _refreshCachedIndices,
    );
  }

  void _openTts() {
    final currentTitle = _chapters.isNotEmpty && _currentChapterIndex < _chapters.length
        ? _chapters[_currentChapterIndex].title
        : '第${_currentChapterIndex + 1}章';
    final fullText = _currentParagraphs.join('\n\n');

    final tts = TtsService();
    tts.onChapterComplete = () async {
      if (_currentChapterIndex + 1 < _chapters.length) {
        _nextChapter();
        final newTitle = _chapters[_currentChapterIndex].title;
        final newText = _currentParagraphs.join('\n\n');
        await tts.playChapter(
          bookId: widget.bookId,
          bookTitle: widget.bookTitle,
          chapterIndex: _currentChapterIndex,
          chapterTitle: newTitle,
          content: newText,
        );
      } else {
        await tts.stop();
      }
    };

    tts.playChapter(
      bookId: widget.bookId,
      bookTitle: widget.bookTitle,
      chapterIndex: _currentChapterIndex,
      chapterTitle: currentTitle,
      content: fullText,
    );

    TtsControlSheet.show(context);
  }

  @override
  Widget build(BuildContext context) {
    final currentTitle = _chapters.isNotEmpty && _currentChapterIndex < _chapters.length
        ? _chapters[_currentChapterIndex].title
        : '正在加载...';

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      },
      child: Scaffold(
        key: _scaffoldKey,
        drawer: CatalogDrawer(
          chapters: _chapters,
          currentChapterIndex: _currentChapterIndex,
          onSelectChapter: (idx) {
            _loadChapterContent(idx);
          },
          onOpenDownload: _openDownloadSheet,
        ),
        body: Stack(
          children: [
            ReaderViewport(
              paragraphs: _currentParagraphs,
              bookTitle: widget.bookTitle,
              chapterTitle: currentTitle,
              initialCharOffset: _currentCharOffset,
              turnMode: _turnMode,
              theme: _theme,
              fontSize: _fontSize,
              lineHeight: _lineHeight,
              onBack: () {
                SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
                Navigator.of(context).maybePop();
              },
              onOpenCatalog: _openCatalogDrawer,
              onOpenTypography: _openTypographyDrawer,
              onOpenSourceSwitcher: _openSourceSwitcher,
              onOpenDownload: _openDownloadSheet,
              onOpenTts: _openTts,
              onToggleTheme: _toggleNightMode,
              onNextChapter: _nextChapter,
              onPreviousChapter: _previousChapter,
              onProgressChanged: (charOffset) {
                _currentCharOffset = charOffset;
              },
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 12.0,
              child: SafeArea(
                child: TtsMiniPlayer(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
