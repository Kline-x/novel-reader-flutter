// fork 友好性回归测试
//
// 背景：仓库名曾写死在清单探测地址、拼音规则地址与 Release 兜底链接里。
// 后果是 fork 出来的包会去拉上游的 version_manifest.json、下载上游签名的
// APK 来「更新」自己——两边签名不同，安装必然被系统拒绝。
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_reader_flutter/core/config/app_repo.dart';
import 'package:novel_reader_flutter/features/settings/services/version_check_service.dart';
import 'package:novel_reader_flutter/features/sources/services/pinyin_rule_service.dart';

void main() {
  group('fork 后所有远端地址都跟随当前仓库', () {
    test('清单探测地址不含任何写死的仓库名', () {
      for (final url in VersionCheckService.highAvailabilityEndpoints) {
        expect(url, contains(appRepo),
            reason: '探测地址必须指向 appRepo，否则 fork 版会拉上游清单：$url');
      }
      expect(VersionCheckService.highAvailabilityEndpoints.length, 3);
    });

    test('拼音规则地址同样跟随 appRepo，且不再残留其他账号', () {
      for (final url in PinyinRuleService.remoteEndpoints) {
        expect(url, contains(appRepo), reason: url);
      }
      expect(
        PinyinRuleService.remoteEndpoints.any((e) => e.contains('gaorenhua')),
        isFalse,
        reason: '历史遗留的第二个账号地址拉到的规则未必与本包同步，应已移除',
      );
    });

    test('三级探测顺序为 国内代理 → jsDelivr → GitHub 原源', () {
      final eps = repoFileEndpoints('x.json');
      expect(eps[0], startsWith('https://ghproxy.net/'));
      expect(eps[1], contains('cdn.jsdelivr.net'));
      expect(eps[2], startsWith('https://raw.githubusercontent.com/'));
    });

    test('Release 兜底链接指向当前仓库', () {
      expect(appReleasesUrl, 'https://github.com/$appRepo/releases');
    });
  });
}
