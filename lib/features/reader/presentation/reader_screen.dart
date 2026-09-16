import 'package:flutter/material.dart';
import 'catalog_drawer.dart';
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

  const ReaderScreen({
    super.key,
    required this.bookId,
    required this.bookTitle,
    required this.author,
    this.initialChapterIndex = 0,
    this.initialCharOffset = 0,
  });

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late int _currentChapterIndex;
  late int _currentCharOffset;
  double _fontSize = 18.0;
  double _lineHeight = 30.0;
  ReaderThemeOption _theme = ReaderThemeOption.presets[0];
  PageTurnMode _turnMode = PageTurnMode.slide;

  // 章节目录数据（支持后续从 Source/Storage 加载）
  late List<ChapterItem> _chapters;
  List<String> _currentParagraphs = [];

  @override
  void initState() {
    super.initState();
    _currentChapterIndex = widget.initialChapterIndex;
    _currentCharOffset = widget.initialCharOffset;

    // 默认提供示例数据或真实网文内容
    _chapters = List.generate(
      120,
      (i) => ChapterItem(
        index: i,
        title: '第 ${i + 1} 章 ${i == 0 ? "绯红" : i == 1 ? "局势" : "探索"}',
        url: 'https://example.com/ch/$i',
        isCached: i < 5,
      ),
    );

    _loadChapterContent(_currentChapterIndex);
  }

  void _loadChapterContent(int chapterIndex) {
    setState(() {
      _currentChapterIndex = chapterIndex;
      _currentParagraphs = [
        '痛！好痛！头好痛！',
        '绯红的月光透过窗帘的缝隙，斑驳地洒在书桌上。周明瑞只觉得脑袋里仿佛插了一根烧红的铁钎，并在不停地搅动。',
        '他挣扎着想要坐起身，却发现四肢无力，整个身体沉重得如同灌了铅一般。空气中弥漫着一股刺鼻的铁锈味与劣质火药的硝烟气息。',
        '“我不是在家里睡觉吗？怎么会在这里……”周明瑞按着太阳穴，低声呻吟，记忆如同破碎的玻璃碎片在脑海中飞速划过。',
        '桌面上散落着几张草稿纸，一支带有黄铜笔尖的羽毛笔滚落在地毯上，墨水晕染开一片深黑色的污迹。旁边还摆着一把左轮手枪，枪口隐隐散发着淡淡的青烟。',
        '镜子里映照出一张年轻但毫无血色的脸庞，黑发深褐瞳孔，额头侧面赫然有一个狰狞焦黑的血洞！',
        '“自杀？他杀？我穿越了？！”周明瑞猛地屏住了呼吸。',
        '在这个蒸汽与机械咆哮、神秘与疯狂并存的世界中，他深知，唯有保持清醒与克制，才能穿越重重迷雾，揭开绯红之月背后的终极隐秘。',
      ];
    });
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
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('可用书源热切', style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16.0),
              _buildSourceTile('笔趣阁CP', '128ms', '最新更新至第 120 章', true),
              _buildSourceTile('笔趣阁ZWX', '210ms', '最新更新至第 119 章', false),
              _buildSourceTile('思兔阅读', '340ms', '最新更新至第 120 章', false),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSourceTile(String name, String latency, String updateInfo, bool isCurrent) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Row(
        children: [
          Text(name, style: TextStyle(fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
          const SizedBox(width: 8.0),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6.0),
            ),
            child: Text(latency, style: const TextStyle(fontSize: 11.0, color: Colors.green)),
          ),
        ],
      ),
      subtitle: Text(updateInfo, style: const TextStyle(fontSize: 12.0)),
      trailing: isCurrent ? const Icon(Icons.check_circle, color: Color(0xFF5B7FFF)) : null,
      onTap: () {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已无缝平移至书源：$name')),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentTitle = _chapters.isNotEmpty && _currentChapterIndex < _chapters.length
        ? _chapters[_currentChapterIndex].title
        : '正在加载...';

    return Scaffold(
      key: _scaffoldKey,
      drawer: CatalogDrawer(
        chapters: _chapters,
        currentChapterIndex: _currentChapterIndex,
        onSelectChapter: (idx) {
          _loadChapterContent(idx);
        },
      ),
      body: ReaderViewport(
        paragraphs: _currentParagraphs,
        bookTitle: widget.bookTitle,
        chapterTitle: currentTitle,
        initialCharOffset: _currentCharOffset,
        turnMode: _turnMode,
        theme: _theme,
        fontSize: _fontSize,
        lineHeight: _lineHeight,
        onBack: () => Navigator.of(context).maybePop(),
        onOpenCatalog: _openCatalogDrawer,
        onOpenTypography: _openTypographyDrawer,
        onOpenSourceSwitcher: _openSourceSwitcher,
        onProgressChanged: (charOffset) {
          _currentCharOffset = charOffset;
        },
      ),
    );
  }
}
