import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// 跨平台版本升级包详情
class PlatformUpdateInfo {
  /// 安装包直链（Android APK / 鸿蒙 HAP）
  final String? downloadUrl;

  /// 应用市场或商店跳转链接（iOS App Store, 华为应用市场 appmarket:// 等）
  final String? storeUrl;

  /// 国内高速 CDN / 备用镜像加速下载直链
  final String? backupUrl;

  /// 安装包体积（字节）
  final int? fileSize;

  /// 安装包 SHA256 完整性校验和
  final String? sha256;

  /// 该安装包的真实 versionCode。
  /// --split-per-abi 会按 abiCode*1000+base 重写，三个包各不相同，
  /// 必须拿对应包的号去和设备已安装版本比较。
  final int? versionCode;

  /// 安装模式：in_app_apk（应用内安装APK）, app_store（应用商店）, app_market（华为应用市场）, in_app_hap（鸿蒙HAP）
  final String installMode;

  /// 按 ABI 区分的安装包变体（arm64-v8a / armeabi-v7a / x86_64）。
  /// 流水线是 --split-per-abi 出三个包，清单只挂 arm64 的话，
  /// armeabi-v7a 设备下载后会 INSTALL_FAILED_NO_MATCHING_ABIS。
  final Map<String, PlatformUpdateInfo> variants;

  const PlatformUpdateInfo({
    this.downloadUrl,
    this.storeUrl,
    this.backupUrl,
    this.fileSize,
    this.sha256,
    this.installMode = 'in_app_apk',
    this.variants = const {},
    this.versionCode,
  });

  /// 按设备支持的 ABI 列表挑选匹配的安装包；无匹配时回退到自身（扁平字段）
  PlatformUpdateInfo resolveForAbis(List<String> deviceAbis) {
    if (variants.isEmpty || deviceAbis.isEmpty) return this;
    for (final abi in deviceAbis) {
      final hit = variants[abi];
      if (hit != null) return hit;
    }
    return this;
  }

  factory PlatformUpdateInfo.fromJson(Map<String, dynamic> json) {
    final rawVariants = json['variants'] as Map<String, dynamic>? ?? {};
    final parsedVariants = <String, PlatformUpdateInfo>{};
    rawVariants.forEach((abi, v) {
      if (v is Map<String, dynamic>) {
        parsedVariants[abi] = PlatformUpdateInfo.fromJson(v);
      }
    });
    return PlatformUpdateInfo(
      downloadUrl: json['downloadUrl'] as String?,
      storeUrl: json['storeUrl'] as String?,
      backupUrl: json['backupUrl'] as String?,
      fileSize: json['fileSize'] as int?,
      sha256: json['sha256'] as String?,
      installMode: json['installMode'] as String? ?? 'in_app_apk',
      variants: parsedVariants,
      versionCode: json['versionCode'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (downloadUrl != null) 'downloadUrl': downloadUrl,
      if (storeUrl != null) 'storeUrl': storeUrl,
      if (backupUrl != null) 'backupUrl': backupUrl,
      if (fileSize != null) 'fileSize': fileSize,
      if (sha256 != null) 'sha256': sha256,
      'installMode': installMode,
      if (versionCode != null) 'versionCode': versionCode,
      if (variants.isNotEmpty)
        'variants': variants.map((k, v) => MapEntry(k, v.toJson())),
    };
  }
}

/// 版本更新信息数据模型 (跨端自适应矩阵)
class AppVersionInfo {
  final int versionCode;
  final String versionName;
  final String releaseNotes;
  final String publishDate;
  final bool isForceUpdate;
  final Map<String, PlatformUpdateInfo> platforms;

  const AppVersionInfo({
    required this.versionCode,
    required this.versionName,
    required this.releaseNotes,
    required this.publishDate,
    this.isForceUpdate = false,
    this.platforms = const {},
  });

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) {
    final rawPlatforms = json['platforms'] as Map<String, dynamic>? ?? {};
    final parsedPlatforms = <String, PlatformUpdateInfo>{};
    rawPlatforms.forEach((key, val) {
      if (val is Map<String, dynamic>) {
        parsedPlatforms[key] = PlatformUpdateInfo.fromJson(val);
      }
    });

    // 兼容根级 downloadUrl
    if (!parsedPlatforms.containsKey('android') &&
        json.containsKey('downloadUrl')) {
      parsedPlatforms['android'] = PlatformUpdateInfo(
        downloadUrl: json['downloadUrl'] as String?,
        installMode: 'in_app_apk',
      );
    }

    return AppVersionInfo(
      versionCode: json['versionCode'] as int? ?? 0,
      versionName: json['versionName'] as String? ?? '1.0.0',
      releaseNotes: json['releaseNotes'] as String? ?? '',
      publishDate: json['publishDate'] as String? ?? '',
      isForceUpdate: json['isForceUpdate'] as bool? ?? false,
      platforms: parsedPlatforms,
    );
  }

  Map<String, dynamic> toJson() {
    final platformsMap = <String, dynamic>{};
    platforms.forEach((k, v) => platformsMap[k] = v.toJson());
    return {
      'versionCode': versionCode,
      'versionName': versionName,
      'releaseNotes': releaseNotes,
      'publishDate': publishDate,
      'isForceUpdate': isForceUpdate,
      'platforms': platformsMap,
    };
  }

  /// 获取当前宿主平台的专属升级配置
  PlatformUpdateInfo? get currentPlatformInfo {
    if (kIsWeb) {
      return platforms['web'] ?? platforms['android'];
    }
    if (VersionCheckService.isHarmonyOS) {
      return platforms['harmony'] ?? platforms['android'];
    }
    if (Platform.isAndroid) {
      return platforms['android'];
    }
    if (Platform.isIOS) {
      return platforms['ios'];
    }
    if (Platform.isMacOS) {
      return platforms['macos'] ?? platforms['android'];
    }
    if (Platform.isWindows) {
      return platforms['windows'] ?? platforms['android'];
    }
    return platforms['android'];
  }

  /// 兼容旧版调用习惯获取下载或跳转直链
  String get downloadUrl {
    final info = currentPlatformInfo;
    return info?.downloadUrl ??
        info?.storeUrl ??
        info?.backupUrl ??
        'https://github.com/Kline-x/novel-reader-flutter/releases';
  }

  /// 按设备 ABI 取到的真实发布版本号；拿不到就回退顶层
  int effectiveVersionCodeFor(List<String> deviceAbis) {
    final android = platforms['android'];
    if (android == null) return versionCode;
    return android.resolveForAbis(deviceAbis).versionCode ??
        android.versionCode ??
        versionCode;
  }

  /// 格式化展示的完整版本标签 (如 v1.0.1+2)
  String get displayTag => 'v$versionName+$versionCode';
}

/// 远程版本检测与无损保留数据应用内升级服务 (VersionCheckService)
///
/// 架构特性：
/// 1. 国内多级高可用探测矩阵（国内 CDN 节点 / Gitee 镜像 / GitHub 原源 / 局域网自建 API）；
/// 2. 毫秒级熔断与默认 Mock 稳定版（1.0.1+2）兜底，无网/弱网零卡死；
/// 3. 跨平台矩阵路由适配：
///    - Android：应用内流式分片下载 APK + 系统 FileProvider 覆盖安装（同 ApplicationId 100% 自动无损保留数据库、书架与缓存）；
///    - iOS：一键直跳 App Store (itms-apps://) 或 TestFlight，苹果系统覆盖升级天然无损保留数据；
///    - 鸿蒙（HarmonyOS NEXT）：唤起华为应用市场 (appmarket://) 或企业 HAP 独立升级；
///    - Web / Desktop：唤起外部浏览器直达发布中心。
class VersionCheckService {
  static final VersionCheckService _instance = VersionCheckService._internal();
  factory VersionCheckService() => _instance;
  VersionCheckService._internal();

  Dio? _customDio;
  Dio get _dio =>
      _customDio ??
      Dio(
        BaseOptions(
          connectTimeout: const Duration(milliseconds: 2500),
          receiveTimeout: const Duration(milliseconds: 3500),
        ),
      );

  @visibleForTesting
  set customDio(Dio dio) => _customDio = dio;

  /// 当前客户端版本号。
  ///
  /// 默认值与 pubspec.yaml 对齐，但**必须**在启动时调用 [loadInstalledVersion]
  /// 从平台读取真实的 versionCode 覆盖它——写死的常量一旦与实际安装包脱节，
  /// 就会出现"已经是最新版却一直提示升级、装完又被系统判定为降级"的问题。
  int currentVersionCode = 2002;
  String currentVersionName = '1.0.1';

  bool _installedVersionLoaded = false;

  /// 设备支持的 ABI（优先级从高到低），由 getPackageInfo 一并带回
  List<String> deviceAbis = const [];

  /// 从宿主平台读取真实已安装版本号（Android 经 MethodChannel 取 PackageInfo）。
  /// 读取失败时保留内置默认值，不影响其余功能。
  Future<void> loadInstalledVersion({bool force = false}) async {
    if (_installedVersionLoaded && !force) return;
    _installedVersionLoaded = true;
    if (kIsWeb) return;
    try {
      // 加超时兜底：平台通道未实现或宿主无响应时不得拖住整条检查更新链路
      final info = await _platformChannel
          .invokeMapMethod<String, dynamic>('getPackageInfo')
          .timeout(const Duration(seconds: 2));
      if (info == null) return;
      final code = info['versionCode'];
      final name = info['versionName'];
      if (code is int && code > 0) {
        currentVersionCode = code;
      }
      if (name is String && name.isNotEmpty) {
        currentVersionName = name;
      }
      final abis = info['abis'];
      if (abis is List) {
        deviceAbis = abis.whereType<String>().toList();
      }
      debugPrint(
          '[VersionCheckService] 已读取真实安装版本: $currentVersionName+$currentVersionCode');
    } catch (e) {
      debugPrint('[VersionCheckService] 读取安装版本失败，沿用内置默认值: $e');
    }
  }

  /// 鸿蒙 HarmonyOS NEXT 环境感知标识（可通过宿主注入或环境参数覆盖）
  static bool isHarmonyOS = false;

  static const String updateChannelName = 'com.kline.novelreader/app_update';
  static const MethodChannel _platformChannel =
      MethodChannel(updateChannelName);

  /// 国内多级高可用探测源列表（按优先级排列）
  static const List<String> highAvailabilityEndpoints = [
    // 1. 国内高可用高速 CDN 镜像节点 (jsDelivr 加速)
    'https://cdn.jsdelivr.net/gh/Kline-x/novel-reader-flutter@main/version_manifest.json',
    // 2. Gitee 国内代码托管平台镜像源
    'https://gitee.com/Kline-x/novel-reader-flutter/raw/main/version_manifest.json',
    // 3. GitHub 原源直链
    'https://raw.githubusercontent.com/Kline-x/novel-reader-flutter/main/version_manifest.json',
  ];

  /// 国内 GitHub Release 代理镜像加速节点列表 (方案 1：国内全自动代理镜像加速)
  static const List<String> gitHubProxyMirrors = [
    'https://ghproxy.net/',
    'https://mirror.ghproxy.com/',
    'https://gh-proxy.com/',
  ];

  /// 生成国内高可用加速下载候选列表（方案 1：GitHub Release 镜像代理全自动加速）
  static List<String> buildAcceleratedDownloadUrls(String? originalUrl) {
    if (originalUrl == null || originalUrl.trim().isEmpty) {
      return [];
    }
    final url = originalUrl.trim();
    final result = <String>[];

    // 若目标链接为 GitHub 资源链接，自动优先注入国内高性能代理镜像
    if (url.contains('github.com') || url.contains('githubusercontent.com')) {
      for (final mirror in gitHubProxyMirrors) {
        result.add('$mirror$url');
      }
    }

    // 将原始链接排入候选队列（作为备用或海外网络兜底）
    result.add(url);
    return result;
  }

  /// 预置的默认 Mock 最新稳定版本信息 (1.0.1+2002, 跨平台完整配置)
  static const AppVersionInfo defaultMockVersion = AppVersionInfo(
    versionCode: 2002,
    versionName: '1.0.1',
    publishDate: '2026-09-18',
    releaseNotes:
        '1. 全新【跨端高可用远程版本升级体系】：支持国内多级镜像加速与毫秒级灾备；\n2. 跨平台矩阵路由：Android 应用内流式无损升级、iOS 直通 App Store、鸿蒙直达华为应用市场；\n3. 升级 Modern Soft UI 连续曲率微浮雕组件与流式下载动效；\n4. 核心安全保障：覆盖安装 100% 自动无损保留全部书架、书签与离线正文缓存！',
    isForceUpdate: false,
    platforms: {
      'android': PlatformUpdateInfo(
        downloadUrl:
            'https://github.com/Kline-x/novel-reader-flutter/releases/download/v1.0.1/novel-reader-v1.0.1.apk',
        backupUrl:
            'https://ghproxy.net/https://github.com/Kline-x/novel-reader-flutter/releases/download/v1.0.1/novel-reader-v1.0.1.apk',
        fileSize: 28450120,
        installMode: 'in_app_apk',
      ),
      'ios': PlatformUpdateInfo(
        storeUrl: 'itms-apps://itunes.apple.com/app/id6478901234',
        backupUrl: 'https://testflight.apple.com/join/novelreader',
        installMode: 'app_store',
      ),
      'harmony': PlatformUpdateInfo(
        storeUrl: 'appmarket://details?id=com.kline.novelreader',
        downloadUrl:
            'https://github.com/Kline-x/novel-reader-flutter/releases/download/v1.0.1/novel-reader-harmony-v1.0.1.hap',
        installMode: 'app_market',
      ),
    },
  );

  /// 检查远程是否有最新版本
  ///
  /// - [endpoint]: 可选的自定义远程版本配置接口或局域网调试地址
  /// - [forceMock]: 若为 true 则直接使用默认 Mock 最新稳定版进行比对
  /// - [currentCode]: 可选的当前版本号基准（默认读取 [currentVersionCode]）
  Future<AppVersionInfo?> checkLatestVersion({
    String? endpoint,
    bool forceMock = false,
    int? currentCode,
  }) async {
    if (currentCode == null) {
      await loadInstalledVersion();
    }
    final baseCode = currentCode ?? currentVersionCode;
    AppVersionInfo latestInfo;

    if (forceMock) {
      latestInfo = defaultMockVersion;
    } else {
      latestInfo =
          await _probeHighAvailabilityManifest(customEndpoint: endpoint);
    }

    // 比较版本号：必须拿**本机 ABI 对应的那个包**的 versionCode 去比。
    // --split-per-abi 让 arm64 包是 base+2000、v7a 是 base+1000、x86_64 是 base+4000，
    // 用基础号去比会让所有用户永远停在"已是最新"。
    final latestCode = latestInfo.effectiveVersionCodeFor(deviceAbis);
    if (latestCode > baseCode) {
      return latestInfo;
    }
    return null;
  }

  /// 国内多级镜像源快速探测策略
  Future<AppVersionInfo> _probeHighAvailabilityManifest(
      {String? customEndpoint}) async {
    final endpoints = customEndpoint != null
        ? [customEndpoint, ...highAvailabilityEndpoints]
        : highAvailabilityEndpoints;

    // 逐级快速探测
    for (final url in endpoints) {
      try {
        final response = await _dio.get<Map<String, dynamic>>(
          url,
          options: Options(
            sendTimeout: const Duration(milliseconds: 1500),
            receiveTimeout: const Duration(milliseconds: 2000),
          ),
        );
        if (response.statusCode == 200 && response.data != null) {
          return AppVersionInfo.fromJson(response.data!);
        }
      } catch (e) {
        debugPrint('[VersionCheckService] 节点 $url 探测未响应，尝试下一高可用节点: $e');
      }
    }

    // 所有外网节点均不可达时，绝不能拿内置的 Mock 版本冒充"线上最新版"——
    // 那会让离线用户看到一个并不存在的新版本，点进去又下载失败。
    // 这里返回与当前安装版本等同的信息，等价于"暂无更新"。
    debugPrint('[VersionCheckService] 外网节点均不可达，本次视为暂无更新');
    return AppVersionInfo(
      versionCode: currentVersionCode,
      versionName: currentVersionName,
      releaseNotes: '',
      publishDate: '',
    );
  }

  /// 跨平台执行更新升级路由
  ///
  /// - Android：流式下载 APK 并唤起 FileProvider 覆盖安装（保留所有本地数据）；
  /// - iOS：打开 App Store 详情页（覆盖安装保留数据）；
  /// - 鸿蒙 HarmonyOS NEXT：唤起华为应用市场或企业 HAP 安装；
  /// - 其他：打开默认浏览器直达发布地址。
  Future<void> executePlatformUpdate(
    AppVersionInfo info, {
    required void Function(double progress) onProgress,
    CancelToken? cancelToken,
  }) async {
    final platformInfo = info.currentPlatformInfo;

    // 1. iOS 平台：打开 App Store / TestFlight
    if (!kIsWeb && Platform.isIOS) {
      final targetStore = platformInfo?.storeUrl ??
          platformInfo?.backupUrl ??
          'itms-apps://itunes.apple.com/app/id6478901234';
      onProgress(0.5);
      await openExternalUrl(targetStore);
      onProgress(1.0);
      return;
    }

    // 2. 鸿蒙 HarmonyOS NEXT 平台：优先唤起华为应用市场
    if (isHarmonyOS) {
      final marketUrl = platformInfo?.storeUrl ??
          'appmarket://details?id=com.kline.novelreader';
      if (platformInfo?.installMode == 'app_market') {
        onProgress(0.5);
        await openExternalUrl(marketUrl);
        onProgress(1.0);
        return;
      }
    }

    // 3. Android 平台（或非 iOS 的移动端）：走应用内流式下载 APK + FileProvider 覆盖安装
    if (!kIsWeb && Platform.isAndroid) {
      await downloadAndInstallApk(
        info,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
      return;
    }

    // 4. 桌面端 / Web 端：打开下载直链或官网
    onProgress(0.5);
    await openExternalUrl(info.downloadUrl);
    onProgress(1.0);
  }

  /// 使用 Dio 流式下载 APK 并唤起 Android 覆盖安装
  ///
  /// - [info]: 待更新的版本信息
  /// - [onProgress]: 下载进度回调 (0.0 ~ 1.0)
  /// - [cancelToken]: 可选的取消令牌
  Future<void> downloadAndInstallApk(
    AppVersionInfo info, {
    required void Function(double progress) onProgress,
    CancelToken? cancelToken,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final fileName =
        'novel_reader_v${info.versionName}_${info.versionCode}.apk';
    final saveFile = File('${tempDir.path}/$fileName');

    bool downloadSuccess = false;
    // 按设备 ABI 选择匹配的安装包，避免 v7a 设备下到 arm64 包装不上
    final platformInfo = info.currentPlatformInfo?.resolveForAbis(deviceAbis);
    final candidates = <String>{
      ...buildAcceleratedDownloadUrls(platformInfo?.backupUrl),
      ...buildAcceleratedDownloadUrls(platformInfo?.downloadUrl),
      ...buildAcceleratedDownloadUrls(info.downloadUrl),
    }.toList();

    for (final url in candidates) {
      if (cancelToken?.isCancelled == true) {
        return;
      }
      try {
        final response = await _dio.download(
          url,
          saveFile.path,
          cancelToken: cancelToken,
          onReceiveProgress: (received, total) {
            if (total > 0) {
              final progress = (received / total).clamp(0.0, 1.0);
              onProgress(progress);
            }
          },
        );
        if (response.statusCode != 200) {
          continue;
        }

        // 完整性校验：代理镜像可能被投毒，也可能把 HTML 错误页当 200 返回。
        // 校验不通过一律删除并换下一个候选节点，绝不把来历不明的包交给安装器。
        final reason = await _verifyApk(saveFile, platformInfo);
        if (reason != null) {
          debugPrint('[VersionCheckService] 节点 $url 校验失败($reason)，尝试备用节点');
          if (await saveFile.exists()) {
            await saveFile.delete();
          }
          continue;
        }

        downloadSuccess = true;
        break;
      } catch (e) {
        if (cancelToken?.isCancelled == true) {
          debugPrint('[VersionCheckService] 用户取消了下载: $e');
          return;
        }
        debugPrint('[VersionCheckService] 节点 $url 下载失败，尝试备用节点: $e');
      }
    }

    if (cancelToken?.isCancelled == true) {
      return;
    }

    if (!downloadSuccess) {
      // 此前这里会伪造一个文本文件充当 APK、仿真进度到 100% 再唤起系统安装器，
      // 用户在断网时就会看到"下载完成"后紧跟"解析软件包时出现问题"。
      // 现在直接抛错，由 UI 层给出可理解的失败提示。
      throw Exception('所有下载节点均不可用或安装包校验失败，请检查网络后重试');
    }

    // 确保进度标记为 100%
    onProgress(1.0);

    // 唤起系统安装器
    await installApk(saveFile.path);
  }

  /// 校验下载到的安装包，返回 null 表示通过，否则返回失败原因
  Future<String?> _verifyApk(File file, PlatformUpdateInfo? platformInfo) async {
    if (!await file.exists()) return '文件不存在';

    final bytes = await file.readAsBytes();
    if (bytes.length < 1024) return '文件过小(${bytes.length}B)';

    // APK 本质是 ZIP，必须以 PK 开头；HTML 错误页会在这里被拦住
    if (!(bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        bytes[2] == 0x03 &&
        bytes[3] == 0x04)) {
      return '不是有效的 APK(ZIP) 文件';
    }

    final expectedSize = platformInfo?.fileSize;
    if (expectedSize != null && expectedSize > 0 && bytes.length != expectedSize) {
      return '体积不符(期望 $expectedSize, 实际 ${bytes.length})';
    }

    final expectedSha = platformInfo?.sha256?.trim().toLowerCase();
    if (expectedSha != null && expectedSha.isNotEmpty) {
      final actual = sha256.convert(bytes).toString();
      if (actual != expectedSha) {
        return 'SHA256 不匹配';
      }
    }

    return null;
  }

  /// 唤起 Android 系统安装器执行无损覆盖安装
  ///
  /// 重点：相同 ApplicationId 覆盖安装时，系统会自动保留所有应用内部持久化数据。
  Future<bool> installApk(String filePath) async {
    if (kIsWeb || !Platform.isAndroid) {
      debugPrint('[VersionCheckService] 当前非 Android 平台，跳过原生安装器调起: $filePath');
      return false;
    }

    try {
      final bool? result = await _platformChannel.invokeMethod<bool>(
        'installApk',
        {'filePath': filePath},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('[VersionCheckService] 平台通道唤起安装器异常: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('[VersionCheckService] 唤起安装器未知异常: $e');
      return false;
    }
  }

  /// 唤起外部应用商店或浏览器直链
  Future<bool> openExternalUrl(String url) async {
    if (kIsWeb) {
      return false;
    }

    try {
      final bool? result = await _platformChannel.invokeMethod<bool>(
        'openUrl',
        {'url': url},
      );
      return result ?? false;
    } catch (e) {
      debugPrint('[VersionCheckService] 平台通道打开外部链接异常: $e');
      return false;
    }
  }
}
