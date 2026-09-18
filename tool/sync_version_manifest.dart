// 版本清单校验与发布信息回填工具
//
// 解决三件事：
// 1. 版本号一致性 —— pubspec.yaml / version_manifest.json 必须同版本，
//    否则会出现「已是最新却一直提示升级」「装完被系统判定为降级」；
// 2. 安装包完整性 —— 客户端下载 APK 后会校验 sha256 与体积，
//    清单里不填真实值，新版就会把自家的包拦下；
// 3. ABI 匹配 —— 流水线产出 arm64-v8a / armeabi-v7a / x86_64 三个包，
//    清单若只挂 arm64，v7a 设备下载后会 INSTALL_FAILED_NO_MATCHING_ABIS。
//
// 用法：
//   # 只校验版本号一致性（CI 门禁用）
//   dart run tool/sync_version_manifest.dart
//
//   # 以 pubspec.yaml 为准同步版本号
//   dart run tool/sync_version_manifest.dart --write
//
//   # 发版：按 tag 回填三个 ABI 包的下载地址、sha256 与体积
//   dart run tool/sync_version_manifest.dart --write --tag v1.0.2 \
//       --apk arm64-v8a=release-artifacts/apk/novel-reader-arm64-v8a.apk \
//       --apk armeabi-v7a=release-artifacts/apk/novel-reader-armeabi-v7a.apk \
//       --apk x86_64=release-artifacts/apk/novel-reader-x86_64.apk
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

const _repo = 'Kline-x/novel-reader-flutter';
const _proxy = 'https://ghproxy.net/';

/// arm64-v8a 覆盖绝大多数在用机型，作为扁平字段的默认值供老客户端回退
const _defaultAbi = 'arm64-v8a';

/// Flutter `--split-per-abi` 会按 `abiCode * 1000 + 基础 versionCode` 重写每个包的
/// versionCode（见 flutter_tools 的 gradle 脚本）。注意 x86_64 的 abiCode 是 **4** 不是 3
/// ——历史上 3 留给了 x86。清单若直接写 pubspec 的基础号，
/// 客户端拿真实 versionCode（如 arm64 的 6003）去比 4003，永远判定"已是最新"，
/// 新版本再也推不出去。
const _abiVersionCode = {
  'armeabi-v7a': 1,
  'arm64-v8a': 2,
  'x86': 3,
  'x86_64': 4,
};

/// 优先用 aapt2 从 APK 里读真实 versionCode；读不到再退回公式推算
int _resolveApkVersionCode(String apkPath, String abi, int baseCode) {
  final fromAapt = _readVersionCodeWithAapt(apkPath);
  if (fromAapt != null) return fromAapt;

  final abiCode = _abiVersionCode[abi];
  final guessed = abiCode == null ? baseCode : abiCode * 1000 + baseCode;
  stdout.writeln('    ⚠ 未找到 aapt2，$abi 的 versionCode 按公式推算为 $guessed，'
      '发布前请人工核对');
  return guessed;
}

/// 在 Android SDK 的 build-tools 里找 aapt2 并 dump 出 versionCode
int? _readVersionCodeWithAapt(String apkPath) {
  final exe = _findAapt2();
  if (exe == null) return null;
  try {
    final r = Process.runSync(exe, ['dump', 'badging', apkPath]);
    if (r.exitCode != 0) return null;
    final m = RegExp(r"versionCode='(\d+)'").firstMatch(r.stdout.toString());
    return m == null ? null : int.tryParse(m.group(1)!);
  } catch (_) {
    return null;
  }
}

String? _findAapt2() {
  final sdk = Platform.environment['ANDROID_HOME'] ??
      Platform.environment['ANDROID_SDK_ROOT'];
  if (sdk == null) return null;
  final buildTools = Directory('$sdk/build-tools');
  if (!buildTools.existsSync()) return null;

  final versions = buildTools
      .listSync()
      .whereType<Directory>()
      .map((d) => d.path)
      .toList()
    ..sort();
  for (final dir in versions.reversed) {
    for (final name in ['aapt2.exe', 'aapt2', 'aapt.exe', 'aapt']) {
      final f = File('$dir/$name');
      if (f.existsSync()) return f.path;
    }
  }
  return null;
}

void main(List<String> args) {
  final write = args.contains('--write');
  final tag = _optionValue(args, '--tag');
  final apkArgs = _optionValues(args, '--apk');

  final pubspec = File('pubspec.yaml');
  final manifestFile = File('version_manifest.json');
  if (!pubspec.existsSync() || !manifestFile.existsSync()) {
    stderr.writeln('✕ 找不到 pubspec.yaml 或 version_manifest.json');
    exit(2);
  }

  final versionLine = pubspec
      .readAsLinesSync()
      .firstWhere((l) => l.startsWith('version:'), orElse: () => '');
  final match =
      RegExp(r'version:\s*([0-9.]+)\+([0-9]+)').firstMatch(versionLine);
  if (match == null) {
    stderr.writeln('✕ pubspec.yaml 的 version 字段格式异常: "$versionLine"');
    exit(2);
  }
  final pubName = match.group(1)!;
  final pubCode = int.parse(match.group(2)!);

  final manifest =
      jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
  final manName = manifest['versionName'] as String?;
  final manCode = manifest['versionCode'] as int?;

  stdout.writeln('pubspec.yaml          : $pubName+$pubCode');
  stdout.writeln('version_manifest.json : $manName+$manCode');

  // 顶层 versionCode 记的是**实际发布包**的号。
  // --split-per-abi 会把它重写成 abiCode*1000+base（arm64 即 base+2000），
  // 所以这里不能直接和 pubspec 的基础号比，要按 base 的余数校验。
  final variantsNow = ((manifest['platforms'] as Map<String, dynamic>?)?['android']
      as Map<String, dynamic>?)?['variants'] as Map<String, dynamic>?;
  final hasVariants = variantsNow != null && variantsNow.isNotEmpty;
  final codeConsistent = hasVariants
      ? (manCode != null && manCode % 1000 == pubCode % 1000)
      : manCode == pubCode;
  final consistent = manName == pubName && codeConsistent;

  // ---- 纯校验模式（CI 门禁） ----
  if (!write) {
    if (!consistent) {
      stderr.writeln('');
      stderr.writeln('✕ 版本号不一致。线上清单的 versionCode 必须与实际发布 APK 相同，');
      stderr.writeln('  否则客户端会误判"有新版本"，装完又被系统当成降级。');
      stderr.writeln('  执行 `dart run tool/sync_version_manifest.dart --write` 同步。');
      exit(1);
    }
    stdout.writeln('✓ 版本号一致'
        '${hasVariants ? '（清单记录的是分包后的真实 versionCode）' : ''}');
    _reportIntegrity(manifest);
    exit(0);
  }

  // ---- 回填模式 ----
  manifest['versionName'] = pubName;
  manifest['versionCode'] = pubCode;

  if (apkArgs.isNotEmpty) {
    final effectiveTag = tag ?? 'v$pubName';
    final android = (manifest['platforms'] as Map<String, dynamic>)['android']
        as Map<String, dynamic>;
    final variants = <String, dynamic>{};

    for (final spec in apkArgs) {
      final idx = spec.indexOf('=');
      if (idx <= 0) {
        stderr.writeln('✕ --apk 参数格式应为 <abi>=<路径>，收到: $spec');
        exit(2);
      }
      final abi = spec.substring(0, idx);
      final path = spec.substring(idx + 1);
      final file = File(path);
      if (!file.existsSync()) {
        stderr.writeln('✕ APK 不存在: $path');
        exit(2);
      }

      final bytes = file.readAsBytesSync();
      final digest = sha256.convert(bytes).toString();
      final assetName = 'novel-reader-$abi.apk';
      final url =
          'https://github.com/$_repo/releases/download/$effectiveTag/$assetName';
      final abiVersionCode = _resolveApkVersionCode(path, abi, pubCode);

      variants[abi] = {
        'versionCode': abiVersionCode,
        'downloadUrl': url,
        'backupUrl': '$_proxy$url',
        'fileSize': bytes.length,
        'sha256': digest,
      };
      stdout.writeln('  · $abi  versionCode=$abiVersionCode  '
          '${bytes.length} B  sha256=${digest.substring(0, 16)}...');
    }

    android['variants'] = variants;

    // 扁平字段保留 arm64（老客户端不认识 variants 时的回退目标）
    final fallback = variants[_defaultAbi] ?? variants.values.first;
    final f = fallback as Map<String, dynamic>;
    android['downloadUrl'] = f['downloadUrl'];
    android['backupUrl'] = f['backupUrl'];
    android['fileSize'] = f['fileSize'];
    android['sha256'] = f['sha256'];
    android['versionCode'] = f['versionCode'];

    // 顶层 versionCode 也要用 arm64 包的真实值：
    // 不认识 variants 的老客户端就是拿它和自己的 versionCode 比较的
    manifest['versionCode'] = f['versionCode'];
  }

  manifestFile.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(manifest)}\n');
  stdout.writeln('✓ 已写回 version_manifest.json');
  _reportIntegrity(manifest);
}

String? _optionValue(List<String> args, String name) {
  final i = args.indexOf(name);
  if (i < 0 || i + 1 >= args.length) return null;
  return args[i + 1];
}

List<String> _optionValues(List<String> args, String name) {
  final out = <String>[];
  for (var i = 0; i < args.length - 1; i++) {
    if (args[i] == name) out.add(args[i + 1]);
  }
  return out;
}

/// 发布前体检：缺少校验和会让客户端只能靠 ZIP 魔数做弱校验
void _reportIntegrity(Map<String, dynamic> manifest) {
  final android = (manifest['platforms'] as Map<String, dynamic>?)?['android']
      as Map<String, dynamic>?;
  if (android == null) return;

  final variants = android['variants'] as Map<String, dynamic>?;
  if (variants == null || variants.isEmpty) {
    stdout.writeln('⚠ 未配置 variants：armeabi-v7a / x86_64 设备将下载到 arm64 包而装不上。');
  } else {
    stdout.writeln('✓ 已配置 ${variants.length} 个 ABI 变体：${variants.keys.join(', ')}');
  }

  final sha = (android['sha256'] as String?)?.trim();
  final size = android['fileSize'];
  if (sha == null || sha.isEmpty) {
    stdout.writeln('⚠ android.sha256 为空：客户端只能靠 ZIP 魔数做弱校验。');
  }
  if (size is! int || size <= 0) {
    stdout.writeln('⚠ android.fileSize 缺失或非法。');
  }
}
