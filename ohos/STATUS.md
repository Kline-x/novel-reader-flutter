# 鸿蒙支持现状：尚未接入，但上游已就绪

**一句话：这个目录目前还是个脚手架，本仓库还构建不出鸿蒙包；但上游工具链已经跟上，具备接入条件。**

在此之前，仓库各处（发布说明、CI 步骤名、设置页文案、版本清单）都声称
「纯血鸿蒙 NEXT 对等支持」「全平台多端对等」。这些说法没有实现支撑，
且版本清单里挂着一个指向从不存在的 `.hap` 的下载地址，鸿蒙用户点更新必然 404。
2026-09-20 已按实际情况清理。

## 这个目录里有什么

14 个文件的 DevEco 工程骨架。`entry/src/main/ets/pages/Index.ets` 只渲染一行文字
「藏书阁 · 鸿蒙原生运行环境」，注释写着「在 OpenHarmony-TPC Flutter SDK 下映射为
FlutterView」，但**没有任何挂载 Flutter 的代码**。CI 与发版流水线也从不构建 `.hap`。

## 上游在哪（2026-09-20 实测，找仓库时踩了两个坑）

Flutter 的鸿蒙移植**换过两次托管平台，且分支命名规则变过**，很容易查到过期信息：

| 平台 | 状态 |
|---|---|
| `gitee.com/openharmony-sig/flutter_flutter` | **已废弃镜像**，最后推送 2025-05-07，最高只到 Flutter 3.7.12 |
| `gitcode.com/openharmony-sig/flutter_flutter` | 活跃，到 `oh-3.41.9-release` / `oh-3.44.9-dev` |
| **`atomgit.com/oh-flutter/flutter_flutter`** | **当前主仓库**，有 `oh-3.47.4-dev` 分支与 **`oh-3.47.4-rc1`** 标签 |

分支命名从早期的 `3.7.12-ohos-1.0.4` 改成了 **`oh-3.47.4-dev`** 这种前缀式。
按旧规则 grep 会把所有新分支漏掉，进而误判项目停滞——这个坑已经踩过一次。

配套仓库：
- 引擎：`atomgit.com/openharmony-sig/flutter_engine`
- 插件：`atomgit.com/oh-flutter/flutter_packages`，**目前最高只到 `oh-3.44.9-dev`**，落后工具链一档

## 版本对位

| | 版本 |
|---|---|
| 本项目构建用 | Flutter **3.47.5** / Dart 3.13 |
| 鸿蒙侧最高 | Flutter **3.47.4-rc1** |

只差一个 patch，同属 Dart 3。这意味着：

- `Color.withValues`（Flutter 3.27+ 才有，本项目用了 **177 处**）原生可用，**一处都不用改**
- 不涉及 Dart 2 → Dart 3 回退，`pubspec.yaml` 的 `sdk: ">=3.3.0 <4.0.0"` 照样满足

## 接入时的已知工作量

1. **工具链**：DevEco Studio + OpenHarmony SDK（下载需华为开发者账号），
   外加从 AtomGit 拉 `oh-3.47.4-*` 的 flutter SDK。本机目前一个都没装。
2. **插件**：`shared_preferences`、`path_provider` 在 `flutter_packages` 里有鸿蒙实现，
   但该仓库停在 `oh-3.44.9-dev`，与 3.47 工具链能否直接配合需实测。
   **`flutter_tts`（听书）鸿蒙侧有无实现尚未查证**，没有的话这个功能要么自己写要么在鸿蒙版砍掉。
3. **平台通道**：`com.kline.novelreader/volume_key`（音量键翻页）要用 ArkTS 重写；
   `com.kline.novelreader/app_update` 里的 `installApk` 在鸿蒙上**没有对等能力**，
   只能改成跳应用市场，对应 `version_manifest.json` 里的 `installMode: app_market`。
4. **验证手段**：目前没有鸿蒙真机。模拟器需 DevEco Studio，且要确认
   鸿蒙 engine 是否提供 x86_64 模拟器产物——只发 arm64 的话模拟器跑不起来。
   **没有验证手段就不要动手**，否则只会重新制造「声称支持但从没跑起来过」的局面。

## 现在鸿蒙用户怎么办

**HarmonyOS 4.2 及更早基于 AOSP，直接支持安装 APK**，用 Release 里的
`novel-reader-arm64-v8a.apk` 即可。只有 HarmonyOS NEXT（5.0 / 星河版）去掉了
Android 兼容层，那部分设备要等本仓库真正接入后才能用。
