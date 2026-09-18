import 'package:flutter_test/flutter_test.dart';
import 'package:novel_reader_flutter/features/sources/services/pinyin_rule_service.dart';
import 'package:novel_reader_flutter/features/sources/services/pinyin_harmonizer.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PinyinRuleService().resetForTest();
  });

  group('PinyinRuleService Tests', () {
    test('init should load default cloud rules', () async {
      final service = PinyinRuleService();
      await service.init();

      expect(service.cloudRulesCount, greaterThanOrEqualTo(22));
      expect(service.customRulesCount, 0);
      expect(service.activeRulesCount, service.cloudRulesCount);
      expect(service.rules.any((r) => r.pinyin == 'zhengfu'), isTrue);
    });

    test('addCustomRule should add and inject into PinyinHarmonizer', () async {
      final service = PinyinRuleService();
      await service.init();

      await service.addCustomRule('ceshi', '测试');
      expect(service.customRulesCount, 1);
      expect(service.rules.first.pinyin, 'ceshi');
      expect(service.rules.first.hanzi, '测试');

      // 验证动态生效到 Harmonizer
      final restored = PinyinHarmonizer.restorePinyin('这是一个ceshi段落');
      expect(restored, '这是一个测试段落');
    });

    test('toggleRule should enable and disable rules properly', () async {
      final service = PinyinRuleService();
      await service.init();

      await service.addCustomRule('kaifa', '开发');
      final ruleId = service.rules.first.id;

      // 禁用该规则
      await service.toggleRule(ruleId, false);
      expect(service.rules.first.isEnabled, isFalse);

      final notRestored = PinyinHarmonizer.restorePinyin('项目kaifa中');
      expect(notRestored, '项目kaifa中');

      // 重新启用该规则
      await service.toggleRule(ruleId, true);
      expect(service.rules.first.isEnabled, isTrue);

      final restored = PinyinHarmonizer.restorePinyin('项目kaifa中');
      expect(restored, '项目开发中');
    });

    test('removeCustomRule should remove rule and update harmonizer', () async {
      final service = PinyinRuleService();
      await service.init();

      await service.addCustomRule('linshi', '临时');
      final ruleId = service.rules.first.id;
      expect(service.customRulesCount, 1);

      await service.removeCustomRule(ruleId);
      expect(service.customRulesCount, 0);
      expect(PinyinHarmonizer.dynamicRules.containsKey('linshi'), isFalse);
    });

    test('export and import JSON should work correctly', () async {
      final service = PinyinRuleService();
      await service.init();

      await service.addCustomRule('shuru', '输入');
      await service.addCustomRule('shuchu', '输出');

      final exportedJson = service.exportRulesJson();
      expect(exportedJson, contains('shuru'));
      expect(exportedJson, contains('shuchu'));

      // 清空存储并重置测试
      SharedPreferences.setMockInitialValues({});
      service.resetForTest();
      await service.init();
      expect(service.customRulesCount, 0);

      final importedCount = await service.importRulesJson(exportedJson);
      expect(importedCount, 2);
      expect(service.customRulesCount, 2);
      expect(PinyinHarmonizer.restorePinyin('数据shuru与shuchu'), '数据输入与输出');
    });
  });
}
