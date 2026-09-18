import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_reader_flutter/features/sources/services/network_client.dart';
import 'package:novel_reader_flutter/features/sources/services/pinyin_harmonizer.dart';
import 'package:novel_reader_flutter/features/sources/services/pinyin_rule_service.dart';

class MockRemoteRuleAdapter implements HttpClientAdapter {
  final Map<String, dynamic> responses;

  MockRemoteRuleAdapter(this.responses);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.toString();
    for (final entry in responses.entries) {
      if (path.contains(entry.key)) {
        final bodyText = entry.value as String;
        final bytes = utf8.encode(bodyText);
        return ResponseBody.fromBytes(
          bytes,
          200,
          headers: {
            'content-type': ['application/json; charset=utf-8'],
          },
        );
      }
    }
    return ResponseBody.fromBytes(utf8.encode('{}'), 404);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PinyinRuleService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    service = PinyinRuleService();
    await service.resetAll();
    await service.init();
  });

  group('【专项一】PinyinRule 模型与基础属性测试', () {
    test('PinyinRule 序列化与反序列化及 copyWith', () {
      const rule = PinyinRule(
        id: 'rule_1',
        pattern: 'zhengce',
        replacement: '政策',
        isRegex: false,
        isEnabled: true,
        isCustom: true,
      );

      final json = rule.toJson();
      final fromJsonRule = PinyinRule.fromJson(json);

      expect(fromJsonRule, equals(rule));
      expect(fromJsonRule.id, 'rule_1');
      expect(fromJsonRule.pattern, 'zhengce');
      expect(fromJsonRule.replacement, '政策');
      expect(fromJsonRule.isCustom, isTrue);

      final updated = rule.copyWith(isEnabled: false, replacement: '策略');
      expect(updated.isEnabled, isFalse);
      expect(updated.replacement, '策略');
      expect(updated.pattern, 'zhengce');
    });
  });

  group('【专项二】PinyinRuleService 规则增删改查与导入导出测试', () {
    test('默认内置云端规则正确加载', () {
      expect(service.allRules.isNotEmpty, isTrue);
      expect(service.exactRulesMap.containsKey('zhengfu'), isTrue);
      expect(service.exactRulesMap['zhengfu'], '政府');
      expect(service.exactRulesMap['sharen'], '杀人');
      expect(service.exactRulesMap['kuaigan'], '快感');
    });

    test('添加、覆盖与删除自定义规则', () async {
      // 1. 添加自定义规则
      await service.addCustomRule('zhengce', '政策');
      expect(service.customRules.any((r) => r.pattern == 'zhengce'), isTrue);
      expect(service.exactRulesMap['zhengce'], '政策');

      // 2. 覆盖已有规则的替换词
      await service.addCustomRule('zhengce', '大政方针');
      expect(service.exactRulesMap['zhengce'], '大政方针');

      // 3. 删除自定义规则
      final targetRule =
          service.customRules.firstWhere((r) => r.pattern == 'zhengce');
      await service.deleteCustomRule(targetRule.id);
      expect(service.customRules.any((r) => r.pattern == 'zhengce'), isFalse);
      expect(service.exactRulesMap.containsKey('zhengce'), isFalse);
    });

    test('规则停用与重新启用 (toggleRule)', () async {
      await service.addCustomRule('chongdong', '冲动');
      final rule =
          service.customRules.firstWhere((r) => r.pattern == 'chongdong');

      // 停用
      await service.toggleRule(rule.id, false);
      expect(service.exactRulesMap.containsKey('chongdong'), isFalse);

      // 重新启用
      await service.toggleRule(rule.id, true);
      expect(service.exactRulesMap['chongdong'], '冲动');
    });

    test('自定义规则导出与导入合并去重 (exportRulesJson / importRulesJson)', () async {
      await service.addCustomRule('diy_one', '自定义一');
      await service.addCustomRule('diy_two', '自定义二');

      final exportedJson = service.exportRulesJson();
      expect(exportedJson.contains('diy_one'), isTrue);
      expect(exportedJson.contains('diy_two'), isTrue);

      // 重置服务
      await service.resetAll();
      expect(service.customRules.isEmpty, isTrue);

      // 重新导入
      final importedCount = await service.importRulesJson(exportedJson);
      expect(importedCount, 2);
      expect(service.exactRulesMap['diy_one'], '自定义一');
      expect(service.exactRulesMap['diy_two'], '自定义二');

      // 重复导入去重合并验证
      final duplicateImportCount = await service.importRulesJson(exportedJson);
      expect(duplicateImportCount, 2);
      expect(service.customRules.length, 2);
    });
  });

  group('【专项三】PinyinRuleService 云端热更新节点轮询同步测试', () {
    test('从云端 CDN 镜像拉取最新规则热更新', () async {
      final mockDio = Dio();
      mockDio.httpClientAdapter = MockRemoteRuleAdapter({
        'jsdelivr.net': '''
{
  "version": 2,
  "updatedAt": "2026-09-18",
  "rules": [
    {"pattern": "xinguize", "replacement": "新规则", "isRegex": false},
    {"pattern": "zhengfu", "replacement": "人民政府", "isRegex": false}
  ]
}
''',
      });

      final netClient = NetworkClient(dio: mockDio);
      final success = await service.syncFromRemote(client: netClient);

      expect(success, isTrue);
      expect(service.currentVersion, 2);
      expect(service.exactRulesMap['xinguize'], '新规则');
      expect(service.exactRulesMap['zhengfu'], '人民政府');
    });

    test('云端节点全部网络异常时安全回退不崩溃', () async {
      final mockDio = Dio();
      mockDio.httpClientAdapter = MockRemoteRuleAdapter({}); // 全部 404

      final netClient = NetworkClient(dio: mockDio);
      final success = await service.syncFromRemote(client: netClient);

      expect(success, isFalse);
      // 原有本地内置规则不受破坏
      expect(service.exactRulesMap['zhengfu'], '政府');
    });
  });

  group('【专项四】PinyinHarmonizer 变异干扰符解混淆 (Anti-Obfuscation) 测试', () {
    test('识别并还原中划线混淆拼音 (z-h-e-n-g-f-u -> 政府)', () {
      const dirty = '当地z-h-e-n-g-f-u迅速采取了应对措施。';
      final clean = PinyinHarmonizer.restorePinyin(dirty);
      expect(clean, '当地政府迅速采取了应对措施。');
    });

    test('识别并还原点号混淆拼音 (s.h.a.r.e.n -> 杀人)', () {
      const dirty = '他犯下了严厉的s.h.a.r.e.n重罪，被当场抓获。';
      final clean = PinyinHarmonizer.restorePinyin(dirty);
      expect(clean, '他犯下了严厉的杀人重罪，被当场抓获。');
    });

    test('识别并还原下划线与星号混淆拼音 (z_h_e_n_g_f_u / s*h*o*u*q*i*a*n*g)', () {
      const dirty1 = '调查局调取了z_h_e_n_g_f_u的核心档案。';
      expect(PinyinHarmonizer.restorePinyin(dirty1), '调查局调取了政府的核心档案。');

      const dirty2 = '歹徒掏出了一支黑色的s*h*o*u*q*i*a*n*g瞄准前方。';
      expect(PinyinHarmonizer.restorePinyin(dirty2), '歹徒掏出了一支黑色的手枪瞄准前方。');
    });

    test('识别并还原间隔干扰符 (zheng-fu / sha.ren / jing_cha)', () {
      const dirty = 'zheng-fu派遣了jing_cha搜捕sha.ren凶犯。';
      final clean = PinyinHarmonizer.restorePinyin(dirty);
      expect(clean, '政府派遣了警察搜捕杀人凶犯。');
    });

    test('识别单字音节变异干扰并与语境自愈联动 (z_h_e_n_g府 -> 政府)', () {
      const dirty = '有关部门已通知各级z_h_e_n_g府配合调查。';
      final clean = PinyinHarmonizer.restorePinyin(dirty);
      expect(clean, '有关部门已通知各级政府配合调查。');
    });
  });

  group('【专项五】PinyinHarmonizer 汉字夹缝拼音探测 (Sandwich Pinyin Probe) 测试', () {
    test('汉字前后紧密包围的小写拼音精准捕获并自愈', () {
      const dirty1 = '当时的zhengfu机构早已瘫痪。';
      expect(PinyinHarmonizer.restorePinyin(dirty1), '当时的政府机构早已瘫痪。');

      const dirty2 = '他抵抗不住少女的youhuo，陷入了沉沦。';
      expect(PinyinHarmonizer.restorePinyin(dirty2), '他抵抗不住少女的诱惑，陷入了沉沦。');

      const dirty3 = '周明瑞体内涌起一股kuaigan，意识逐渐模糊。';
      expect(PinyinHarmonizer.restorePinyin(dirty3), '周明瑞体内涌起一股快感，意识逐渐模糊。');
    });

    test('绝不误伤夹缝中的英文合法缩写与专有名词 (FBI, BOSS, NPC, DNA)', () {
      const safe1 = '他向FBI探员出示了相关证件。';
      expect(PinyinHarmonizer.restorePinyin(safe1), safe1);

      const safe2 = '众人合力击败了第十层的终极BOSS怪物。';
      expect(PinyinHarmonizer.restorePinyin(safe2), safe2);

      const safe3 = '通过DNA比对确定了嫌疑人身份。';
      expect(PinyinHarmonizer.restorePinyin(safe3), safe3);
    });

    test('绝不误伤普通中英文混排中的合法英文单词 (level, check, system)', () {
      const sentence = '角色升级到了最高level，开启了全新的技能树。';
      expect(PinyinHarmonizer.restorePinyin(sentence), sentence);
    });
  });

  group('【专项六】动态规则与 PinyinHarmonizer 联动实时生效测试', () {
    test('用户动态添加规则后立即生效', () async {
      const dirty = '新出台的fangzhen政策得到了大家的一致赞成。';
      // 初始未添加该规则，fangzhen 保持原样
      expect(PinyinHarmonizer.restorePinyin(dirty), dirty);

      // 动态添加新规则
      await service.addCustomRule('fangzhen', '方针');

      // 再次执行，即刻生效自愈
      final clean = PinyinHarmonizer.restorePinyin(dirty);
      expect(clean, '新出台的方针政策得到了大家的一致赞成。');
    });

    test('动态正则表达式规则支持生效', () async {
      await service.addCustomRule(r'G\d{3,4}', '高铁列车', isRegex: true);

      const dirty = '克莱恩登上了前往贝克兰德的G1024。';
      final clean = PinyinHarmonizer.restorePinyin(dirty);
      expect(clean, '克莱恩登上了前往贝克兰德的高铁列车。');
    });
  });
}
