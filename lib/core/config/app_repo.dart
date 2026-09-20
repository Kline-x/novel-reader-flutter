/// 应用上游仓库的唯一来源。
///
/// 以前清单探测地址、拼音规则地址、Release 兜底链接分散在各处写死
/// `Kline-x/novel-reader-flutter`。后果是：**fork 出来的包会去拉上游的
/// version_manifest.json、下载上游的 APK 来「更新」自己**，而两边签名不同，
/// 安装必然被系统拒绝——fork 版自带一条注定失败的更新链路。
/// 反过来，若有人 fork 后发布修改版，其用户会收到指向上游仓库的更新提示。
///
/// 现在统一从这里取，并支持构建期注入：
///
/// ```bash
/// flutter build apk --release --dart-define=UPDATE_REPO=your-name/your-fork
/// ```
///
/// 发版流水线会自动传 `--dart-define=UPDATE_REPO=${{ github.repository }}`，
/// 所以 fork 的人什么都不用改，发出来的包就指向自己的仓库。
library;

/// 当前包所属的 GitHub 仓库（`owner/name`）。
const String appRepo = String.fromEnvironment(
  'UPDATE_REPO',
  defaultValue: 'Kline-x/novel-reader-flutter',
);

/// 仓库的 Release 列表页，用作所有下载直链都取不到时的兜底跳转。
const String appReleasesUrl = 'https://github.com/$appRepo/releases';

/// 取仓库 main 分支上某个文件的多级高可用地址：
/// 国内代理直链 → jsDelivr CDN → GitHub 原源兜底。
///
/// 国内代理放在最前是因为 jsDelivr 有 CDN 缓存滞后，
/// 刚发完版立刻检查更新可能还读到旧清单。
List<String> repoFileEndpoints(
  String path, {
  String proxy = 'https://ghproxy.net/',
}) =>
    [
      '${proxy}https://raw.githubusercontent.com/$appRepo/main/$path',
      'https://cdn.jsdelivr.net/gh/$appRepo@main/$path',
      'https://raw.githubusercontent.com/$appRepo/main/$path',
    ];
