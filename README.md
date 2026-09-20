# 藏书阁 · Novel Reader

一个 Flutter 写的小说阅读器：书架、书源聚合换源、离线缓存、本地 TXT/EPUB 导入、
WiFi 局域网传书、TTS 听书、WebDAV 进度同步。

## 支持的平台

| 平台 | 状态 |
|---|---|
| Android | ✅ 主力平台，Release 提供 arm64-v8a / armeabi-v7a / x86_64 三个包 |
| HarmonyOS 4.2 及更早 | ✅ 基于 AOSP，直接安装上面的 arm64 APK |
| Web | ⚠️ 有构建产物，但本地导入 / 传书 / 听书 / 离线缓存受限，未作为正式形态维护 |
| iOS | ⚠️ 工程存在，未签名分发 |
| HarmonyOS NEXT（5.0 星河版） | ❌ **不支持**，原因见 [`ohos/STATUS.md`](ohos/STATUS.md) |

## 安装

从 [Releases](https://github.com/Kline-x/novel-reader-flutter/releases) 下载对应
ABI 的 APK。绝大多数机型用 `novel-reader-arm64-v8a.apk`。

安装包用固定密钥签名，自 v1.0.8 起可正常覆盖升级。v1.0.7 及更早的安装
需要先卸载——那几个版本每个包的签名都不同（见下）。

## 开发

```bash
flutter pub get
flutter analyze && flutter test
flutter build apk --release --split-per-abi
```

本地构建取不到正式签名密钥时会退回 debug 签名，并自动把包名换成
`...novel_reader_flutter.dev`、应用名「藏书阁 Dev」，与正式版**并排安装**互不冲突。
调试装 `.dev` 那个，验证更新链路请装 Release 里的正式包。

## 发版

打 `v*` 标签触发 `.github/workflows/release.yml`：构建三个 ABI 的 APK + AAB + Web，
用 GitHub Secrets 里的固定密钥签名，**出包后校验证书**（debug 签名一律拦下），
建 Release，再把下载地址与 sha256 回填进 `version_manifest.json` 并提交回 main。
客户端就是从 main 拉这份清单做更新检查的。

签名密钥一次性配置：`bash tool/setup_signing_secrets.sh`。

### 版本号

`--split-per-abi` 会把 versionCode 重写成 `abiCode * 1000 + 基础号`，
abiCode 为 armeabi-v7a=1 / arm64-v8a=2 / x86=3 / **x86_64=4**。
所以 `pubspec.yaml` 写 `+4007` 时，实际产出 v7a 5007 / arm64 6007 / x86_64 8007。
清单里记的是**分包后的真实号**，`tool/sync_version_manifest.dart` 会按余数校验一致性。

## fork 说明

仓库地址不写死在代码里。发版流水线会自动注入
`--dart-define=UPDATE_REPO=${{ github.repository }}`，所以 fork 之后
更新检查、清单回填都会指向你自己的仓库，无需改任何代码。
你需要自己跑一次 `tool/setup_signing_secrets.sh` 配置签名密钥，否则发版会直接失败。
