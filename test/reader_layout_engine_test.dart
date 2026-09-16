import 'dart:io';
import '../lib/features/reader/engine/cjk_punctuation.dart';
import '../lib/features/reader/engine/page_models.dart';
import '../lib/features/reader/engine/reader_layout_engine.dart';

void main() {
  print('=== 开始执行 ReaderLayoutEngine 核心排版引擎纯数学基线测试 ===');

  // 测试用例：模拟《诡秘之主》第一章经典段落
  final sampleParagraphs = [
    '痛！好痛！头好痛！',
    '绯红的月光透过窗帘的缝隙，斑驳地洒在书桌上。周明瑞只觉得脑袋里仿佛插了一根烧红的铁钎，并在不停地搅动。',
    '他挣扎着想要坐起身，却发现四肢无力，整个身体沉重得如同灌了铅一般。空气中弥漫着一股刺鼻的铁锈味与劣质火药的硝烟气息。',
    '“我不是在家里睡觉吗？怎么会在这里……”周明瑞按着太阳穴，低声呻吟，记忆如同破碎的玻璃碎片在脑海中飞速划过。',
    '桌面上散落着几张草稿纸，一支带有黄铜笔尖的羽毛笔滚落在地毯上，墨水晕染开一片深黑色的污迹。旁边还摆着一把左轮手枪，枪口隐隐散发着淡淡的青烟。',
    '镜子里映照出一张年轻但毫无血色的脸庞，黑发深褐瞳孔，额头侧面赫然有一个狰狞焦黑的血洞！',
    '“自杀？他杀？我穿越了？！”周明瑞猛地屏住了呼吸。',
  ];

  // 1. 验证 18px 默认排版
  final config18 = const PagingConfig(
    viewportWidth: 390.0,  // iPhone 14/15 视口宽
    viewportHeight: 740.0, // 扣除 Safe Area 后的视口高
    fontSize: 18.0,
    lineHeight: 30.0,
    hPad: 20.0,
  );

  final pages18 = ReaderLayoutEngine.paginate(
    paragraphs: sampleParagraphs,
    title: '第一章 绯红',
    config: config18,
  );

  print('【18px 字号】排版完成：总页数 = ${pages18.length}');
  assert(pages18.isNotEmpty, '分页结果不应为空');

  for (final page in pages18) {
    print('  - 第 ${page.pageIndex + 1} 页：共 ${page.lines.length} 行，字符区间 [${page.charStart}..${page.charEnd}]');
    // 验证每一页的行数严禁超过最大行数
    final maxAllowedLines = page.isFirstPage ? config18.firstPageMaxLines : config18.maxLinesPerPage;
    assert(page.lines.length <= maxAllowedLines, '行数不能超过整数行上限，否则底部必切半行！');

    // 验证避头规则
    for (final line in page.lines) {
      if (line.text.isNotEmpty) {
        final firstChar = line.text[0];
        assert(!CjkPunctuation.isForbiddenStart(firstChar), '行首出现避头标点: $firstChar');
      }
    }
  }

  // 2. 验证改字号后字符锚点是否精准保留 (P2-07 痛点)
  // 假设读者在 18px 下正在阅读第 2 页某个关键字符（例如偏移量 220 处的“镜子里映照出”）
  const readingCharOffset = 220;
  final originalPage = ReaderLayoutEngine.findPageByCharOffset(pages18, readingCharOffset);
  print('在 18px 下，字符偏移 $readingCharOffset 落在第 ${originalPage + 1} 页');

  // 读者将字号从 18px 调大为 24px（大字版面）
  final config24 = const PagingConfig(
    viewportWidth: 390.0,
    viewportHeight: 740.0,
    fontSize: 24.0,
    lineHeight: 40.0,
    hPad: 20.0,
  );

  final pages24 = ReaderLayoutEngine.paginate(
    paragraphs: sampleParagraphs,
    title: '第一章 绯红',
    config: config24,
  );

  print('【24px 大字号】排版完成：总页数 = ${pages24.length}（页数自然增加）');
  final targetPage24 = ReaderLayoutEngine.findPageByCharOffset(pages24, readingCharOffset);
  print('改字号为 24px 后，字符偏移 $readingCharOffset 自动精准锚定至第 ${targetPage24 + 1} 页！');
  assert(pages24[targetPage24].containsCharOffset(readingCharOffset), '新页码必须包含该字符锚点！');

  print('=== ✅ 所有 ReaderLayoutEngine 排版与锚点基线测试通过！===');
}
