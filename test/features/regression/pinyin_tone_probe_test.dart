import 'package:flutter_test/flutter_test.dart';
import 'package:novel_reader_flutter/features/sources/services/pinyin_harmonizer.dart';

/// 真机走查《恶魔法则》时发现：书源大量使用**带声调**拼音规避审查，
/// 而规则表全是无声调写法，导致一条都匹配不上、整段正文夹满拼音。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => PinyinHarmonizer.setDynamicRules({}));

  test('声调折叠：带声调拼音字母归一化为基本字母', () {
    expect(PinyinHarmonizer.foldTones('rì'), 'ri');
    expect(PinyinHarmonizer.foldTones('shè'), 'she');
    expect(PinyinHarmonizer.foldTones('dìdū'), 'didu');
    expect(PinyinHarmonizer.foldTones('nǎi'), 'nai');
    expect(PinyinHarmonizer.foldTones('zhèngfǔ'), 'zhengfu');
  });

  test('真机实拍的带声调正文能被还原', () {
    final cases = <String, String>{
      '这是一个夏rì的午后，天上悬挂的烈rì还在无情的放shè着热量。': 'rì',
      '焦头烂额的dìdū治安所的士兵已经把自己吃nǎi的力气都使出来了。': 'dìdū',
      '他说zhèngfǔ已经介入了。': 'zhèngfǔ',
    };
    cases.forEach((input, mustGo) {
      final out = PinyinHarmonizer.restorePinyin(input);
      // ignore: avoid_print
      print('$input\n  -> $out');
      expect(out.contains(mustGo), isFalse, reason: '带声调拼音未被处理: $input');
    });
  });

  test('具体词义还原正确', () {
    final out = PinyinHarmonizer.restorePinyin('这是一个夏rì的午后，烈rì放shè着热量。');
    expect(out.contains('夏日'), isTrue);
    expect(out.contains('烈日'), isTrue);
    expect(out.contains('放射'), isTrue);

    final out2 = PinyinHarmonizer.restorePinyin('焦头烂额的dìdū治安所，吃nǎi的力气。');
    expect(out2.contains('帝都'), isTrue);
    expect(out2.contains('吃奶'), isTrue);
  });

  test('纯英文语境的重音字母绝不能被折叠', () {
    const text = 'He sat in the café reading a naïve résumé.';
    expect(PinyinHarmonizer.restorePinyin(text), text);
  });
}
