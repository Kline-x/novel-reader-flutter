// 版本号一致性校验与同步工具
//
// 背景：曾经出现过 pubspec.yaml = 1.0.1+2002、version_manifest.json = 2、
// 而真机上实际安装的是 4002 —— 三处版本号各说各话，直接导致
// 「已经是最新版却一直提示升级」「装完被系统判定为降级装不上」。
//
// 用法：
//   dart run tool/sync_version_manifest.dart          # 校验，不一致则退出码 1
//   dart run tool/sync_version_manifest.dart --write  # 以 pubspec.yaml 为准写回清单
import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final write = args.contains('--write');

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

  final consistent = manName == pubName && manCode == pubCode;

  stdout.writeln('pubspec.yaml            : $pubName+$pubCode');
  stdout.writeln('version_manifest.json   : $manName+$manCode');

  if (consistent) {
    stdout.writeln('✓ 版本号一致');
    _warnPlaceholders(manifest);
    exit(0);
  }

  if (!write) {
    stderr.writeln('');
    stderr.writeln('✕ 版本号不一致。');
    stderr.writeln('  线上清单的 versionCode 必须与实际发布 APK 的 versionCode 相同，');
    stderr.writeln('  否则客户端会误判"有新版本"，装完又被系统当成降级。');
    stderr.writeln('  执行 `dart run tool/sync_version_manifest.dart --write` 以 pubspec 为准同步。');
    exit(1);
  }

  manifest['versionName'] = pubName;
  manifest['versionCode'] = pubCode;
  manifestFile.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(manifest)}\n');
  stdout.writeln('✓ 已按 pubspec.yaml 同步 version_manifest.json');
  _warnPlaceholders(manifest);
}

/// 发布前提醒：校验和与体积必须是真实值，否则客户端的完整性校验会拦下自家的包
void _warnPlaceholders(Map<String, dynamic> manifest) {
  final platforms = manifest['platforms'] as Map<String, dynamic>?;
  final android = platforms?['android'] as Map<String, dynamic>?;
  if (android == null) return;

  final sha = (android['sha256'] as String?)?.trim();
  final size = android['fileSize'];

  if (sha == null || sha.isEmpty) {
    stdout.writeln('⚠ android.sha256 为空：发版前请填入真实校验和，'
        '否则客户端只能靠 ZIP 魔数做弱校验。');
  }
  if (size == null || size is! int || size <= 0) {
    stdout.writeln('⚠ android.fileSize 缺失或非法：发版前请填入真实体积。');
  }
}
