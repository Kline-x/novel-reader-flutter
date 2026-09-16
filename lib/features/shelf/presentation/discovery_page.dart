import 'package:flutter/material.dart';
import '../../../core/components/soft_card.dart';
import '../../../core/theme/soft_theme.dart';
import '../../reader/presentation/reader_screen.dart';

/// 发现/书城页面 (discovery_page.dart)
/// Modern Soft UI 风格的分类 Bento、热门榜单与多源聚合搜索入口
class DiscoveryPage extends StatefulWidget {
  const DiscoveryPage({super.key});

  @override
  State<DiscoveryPage> createState() => _DiscoveryPageState();
}

class _DiscoveryPageState extends State<DiscoveryPage> {
  final TextEditingController _searchController = TextEditingController();
  int _selectedCategoryIndex = 0;

  final List<String> _categories = ['全部', '玄幻奇幻', '仙侠修真', '科幻未来', '都市异能', '悬疑惊悚'];

  final List<Map<String, String>> _hotBooks = [
    {
      'title': '诡秘之主',
      'author': '爱潜水的乌贼',
      'category': '玄幻',
      'desc': '蒸汽与机械的浪潮中，谁能触及非凡？历史和黑暗的迷雾里，又是谁在耳语？',
    },
    {
      'title': '十日终焉',
      'author': '杀虫队队员',
      'category': '悬疑',
      'desc': '我叫齐夏，当你看到这行字的时候，我已经死了十次。',
    },
    {
      'title': '道诡异仙',
      'author': '狐尾的笔',
      'category': '仙侠',
      'desc': '诡异的天道，异常的仙佛，这里到底是真实还是我的精神病幻觉？',
    },
    {
      'title': '深空彼岸',
      'author': '辰东',
      'category': '科幻',
      'desc': '浩瀚的宇宙中，一片岁月的星海，神话在旧土重新复苏。',
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openBook(Map<String, String> book) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReaderScreen(
          bookId: book['title']!,
          bookTitle: book['title']!,
          author: book['author']!,
        ),
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
            // 标题
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 12.0),
                child: Text(
                  '探索好书',
                  style: TextStyle(
                    fontSize: 26.0,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ),

            // 搜索栏
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                child: Container(
                  height: 44.0,
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(16.0),
                    boxShadow: SoftDecorations.insetShadows(colors),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14.0),
                  child: Row(
                    children: [
                      Icon(Icons.search, size: 18.0, color: colors.textSecondary),
                      const SizedBox(width: 8.0),
                      Expanded(
                        child: TextField(
                          key: const ValueKey('discovery_search_input'),
                          controller: _searchController,
                          style: TextStyle(fontSize: 14.0, color: colors.textPrimary),
                          decoration: InputDecoration(
                            hintText: '全网 12 组稳定书源一键聚合搜书...',
                            hintStyle: TextStyle(fontSize: 13.0, color: colors.textSecondary),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 分类横向滑动胶囊
            SliverToBoxAdapter(
              child: SizedBox(
                height: 48.0,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final isSelected = _selectedCategoryIndex == index;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: GestureDetector(
                        key: ValueKey('category_pill_$index'),
                        onTap: () => setState(() => _selectedCategoryIndex = index),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
                          decoration: BoxDecoration(
                            color: isSelected ? colors.accent : colors.card,
                            borderRadius: BorderRadius.circular(16.0),
                            boxShadow: isSelected
                                ? SoftDecorations.softShadows(colors, elevation: 1.0)
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _categories[index],
                            style: TextStyle(
                              fontSize: 13.0,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? Colors.white : colors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // 热门榜单推荐
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

            // 书籍流
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final book = _hotBooks[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: SoftCard(
                        colors: colors,
                        onTap: () => _openBook(book),
                        padding: const EdgeInsets.all(14.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 50.0,
                              height: 68.0,
                              decoration: BoxDecoration(
                                color: colors.surface,
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                book['title']!.characters.take(2).toString(),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: colors.accent,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12.0),
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
                                          color: colors.accent.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6.0),
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
                  childCount: _hotBooks.length,
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 100.0)),
          ],
        ),
      ),
    );
  }
}
