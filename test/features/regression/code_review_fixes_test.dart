import 'package:flutter_test/flutter_test.dart';
import 'package:novel_reader_flutter/features/local_books/services/wifi_transfer_server.dart';
import 'package:novel_reader_flutter/features/reader/data/storage_service.dart';
import 'package:novel_reader_flutter/features/reader/services/chapter_helper.dart';
import 'package:novel_reader_flutter/features/sources/services/pinyin_harmonizer.dart';
import 'package:novel_reader_flutter/features/sources/services/pinyin_rule_service.dart';
import 'package:novel_reader_flutter/features/sources/services/source_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 2026-09-18 全量代码审查缺陷的回归用例。
///
/// 这些路径此前 162 个用例一个都没覆盖到——测试全绿却带着 5 个 P0 缺陷发版，
/// 所以每条用例都直接针对「缺陷复现场景」而非正向流程。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ISSUE-01 广告过滤不得误删正常正文', () {
    test('含「笔趣阁」「书城」「下一页」「更新时间」的正文段落必须完整保留', () {
      const cases = [
        '他翻开手里那本旧书，扉页上印着笔趣阁三个褪色的小字，像是上个世纪的遗物。',
        '林昭把地图铺在桌上，指着城东说道：他们的更新时间: 每天午夜换防，我们只有一次机会。',
        '她压低声音说：下一页写着什么，你自己看。说完便转身走进了雨里。',
        '这座城里最气派的建筑，是街角那家新开的百汇书城，三层楼高，灯火通明。',
      ];

      for (final text in cases) {
        final result = SourceParser.cleanAndFilterParagraphs(text);
        expect(result, isNotEmpty, reason: '正文被整段误删: $text');
        expect(result.first.length, greaterThan(text.length ~/ 2),
            reason: '正文被截断过多: $text -> ${result.first}');
      }
    });

    test('真正的整行广告仍然要被丢弃', () {
      const ads = [
        '请记住本书首发域名：www.biquge.la',
        '天才一秒记住本站地址',
        '本站所有小说为转载作品，所有章节均由网友上传',
        '下载APP，看最新章节',
      ];
      for (final ad in ads) {
        expect(SourceParser.cleanAndFilterParagraphs(ad), isEmpty,
            reason: '广告未被过滤: $ad');
      }
    });

    test('正文行尾挂广告时，截掉尾巴保留前面的正文', () {
      const line = '克莱恩握紧了手中的左轮手枪。最新网址：www.biquge.la 本章未完点击下一页继续阅读';
      final result = SourceParser.cleanAndFilterParagraphs(line);
      expect(result.length, 1);
      expect(result.first.contains('克莱恩握紧了手中的左轮手枪。'), isTrue);
      expect(result.first.contains('www.biquge.la'), isFalse);
      expect(result.first.contains('点击下一页'), isFalse);
    });
  });

  group('ISSUE-05 非法规则不得中断正文渲染', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      PinyinHarmonizer.setDynamicRules({});
    });

    test('含正则元字符的自定义规则不会让 restorePinyin 抛异常', () {
      // 直接注入一条含未闭合分组的规则，模拟云端热更或用户手滑输入
      PinyinHarmonizer.setDynamicRules({'a(b': '测试', 'zhengfu': '政府'});

      late String output;
      expect(() {
        output = PinyinHarmonizer.restorePinyin('他说 zhengfu 已经介入');
      }, returnsNormally);

      // 合法规则仍然生效，非法规则被静默跳过
      expect(output.contains('政府'), isTrue);
    });

    test('非法正则规则会被 PinyinRuleService 在入库前拒绝', () async {
      final service = PinyinRuleService();
      expect(PinyinRuleService.isRuleUsable('a(b', isRegex: true), isFalse);
      expect(PinyinRuleService.isRuleUsable('zhengfu'), isTrue);

      final rejected = await service.addCustomRule('a(b', '测试', isRegex: true);
      expect(rejected, isFalse);
    });
  });

  group('ISSUE-02 WiFi 传书文件名净化', () {
    test('路径穿越序列必须被彻底剥离', () {
      final cases = {
        '../../shared_prefs/app.xml': isNot(contains('..')),
        '../../../etc/passwd': isNot(contains('/')),
        r'..\..\databases\books.db': isNot(contains(r'\')),
        '%2e%2e%2f%2e%2e%2fboot.txt': isNot(contains('/')),
      };
      cases.forEach((raw, matcher) {
        final safe = WifiTransferServer.sanitizeFileName(raw);
        expect(safe, matcher, reason: '净化不彻底: $raw -> $safe');
      });
    });

    test('非图书格式一律落成 .txt，正常书名保持不变', () {
      expect(WifiTransferServer.sanitizeFileName('恶意脚本.sh'), endsWith('.txt'));
      expect(WifiTransferServer.sanitizeFileName('诡秘之主.txt'), '诡秘之主.txt');
      expect(WifiTransferServer.sanitizeFileName('剑来.epub'), '剑来.epub');
    });

    test('空名与纯点号名有兜底，不会产生隐藏文件', () {
      expect(WifiTransferServer.sanitizeFileName('...'), isNotEmpty);
      expect(WifiTransferServer.sanitizeFileName('...').startsWith('.'), isFalse);
      expect(WifiTransferServer.sanitizeFileName('   '), endsWith('.txt'));
    });
  });

  group('ISSUE-10 短篇书目录缓存不得被当作脏数据丢弃', () {
    List<Map<String, dynamic>> toc(int n, {bool withUrl = true}) => List.generate(
          n,
          (i) => {
            'index': i,
            'title': '第${i + 1}章 正文',
            'url': withUrl ? 'https://example.com/$i.html' : '',
          },
        );

    test('只有 5 章的短篇书目录是合法数据', () {
      expect(StorageService.isDirtyToc(toc(5)), isFalse);
    });

    test('全部条目无 URL 判定为脏数据', () {
      expect(StorageService.isDirtyToc(toc(30, withUrl: false)), isTrue);
    });

    test('历史 12 章假目录仍被识别并丢弃', () {
      final fake = ChapterHelper.getFallbackChapters('诡秘之主')
          .map((c) => {'index': c.index, 'title': c.title, 'url': c.url})
          .toList();
      expect(StorageService.isDirtyToc(fake), isTrue);
    });
  });

  group('ISSUE-08 预置正文只对第一章生效', () {
    test('第 0 章返回保真段落，其余章节一律返回 null', () {
      expect(ChapterHelper.getPresetParagraphs('诡秘之主', 0), isNotNull);
      expect(ChapterHelper.getPresetParagraphs('诡秘之主', 1), isNull);
      expect(ChapterHelper.getPresetParagraphs('诡秘之主', 500), isNull);
      expect(ChapterHelper.getPresetParagraphs('十日终焉', 42), isNull);
    });
  });
}
