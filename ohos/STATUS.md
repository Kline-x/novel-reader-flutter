# 鸿蒙支持现状：实测编译过，卡在闭源 SDK

**一句话结论（2026-09-20 实测）：本项目的 Dart 代码能正常编译成鸿蒙产物，
卡点在 Flutter 引擎的 ArkTS 层需要华为闭源的 HarmonyOS SDK，
而该 SDK 只能通过 DevEco Studio 获取，需要华为开发者账号登录。**

在此之前，仓库各处声称「纯血鸿蒙 NEXT 对等支持」「全平台多端对等」，
且版本清单里挂着指向从不存在的 `.hap` 的下载地址。已清理。

## 这个目录里有什么

14 个文件的 DevEco 工程骨架。`entry/src/main/ets/pages/Index.ets` 只渲染一行文字，
**没有任何挂载 Flutter 的代码**，不是可用工程。真要接入需用
`flutter create --platforms ohos .` 重新生成（见下文第 4 关）。

## 上游在哪（找仓库踩过两个坑）

Flutter 的鸿蒙移植**换过两次托管平台，且分支命名规则变过**：

| 平台 | 状态 |
|---|---|
| `gitee.com/openharmony-sig/flutter_flutter` | **已废弃镜像**，停在 2025-05 / Flutter 3.7.12 |
| `gitcode.com/openharmony-sig/flutter_flutter` | 活跃，到 `oh-3.41.9-release` / `oh-3.44.9-dev` |
| **`atomgit.com/oh-flutter/flutter_flutter`** | **当前主仓库**，有 `oh-3.47.4-dev` 与 `oh-3.47.4-rc1` |

分支命名从 `3.7.12-ohos-1.0.4` 改成了 **`oh-3.47.4-dev`** 前缀式。
按旧规则 grep 会漏掉全部新分支并误判项目停滞——**这个坑踩过一次**。

配套仓库：引擎 `atomgit.com/openharmony-sig/flutter_engine`，
插件 `atomgit.com/oh-flutter/flutter_packages`（最高 `oh-3.44.9-dev`）。

## 编译环境（全部免登录，WSL Ubuntu 22.04 实测可用）

**不需要 Mac，也不需要 GitHub macOS runner。** 曾误判「只有 darwin 产物」——
那只对维护者的覆盖清单成立，OBS 默认源 Linux/Windows 产物都有。

| 组件 | 来源 | 大小 |
|---|---|---|
| 鸿蒙 Flutter SDK | `atomgit.com/oh-flutter/flutter_flutter` 分支 `oh-3.44.9-dev` | ~1.5 GB |
| commandline-tools（ohpm/hvigor/node） | `repo.huaweicloud.com/openharmony/ohpm/5.1.0/commandline-tools-linux-x64-5.1.0.840.zip` | 2.0 GB |
| OpenHarmony SDK | `repo.huaweicloud.com/openharmony/os/6.1-LTS/ohos-sdk-windows_linux-public.tar.gz` | 3.2 GB |
| Dart SDK + 引擎产物 | `flutter-ohos.obs.cn-south-1.myhuaweicloud.com`，首次 `flutter --version` 自动拉 | ~600 MB |

搭建脚本与踩坑记录见 `E:\code\flutter-ohos\README.md`（本机路径，未入库）。

**选 `oh-3.44.9-dev` 而非 `oh-3.47.4-dev`**：后者维护者重建了 darwin 产物
（Dart 3.13.3 / kernel 138），非 darwin 宿主会回退 OBS 默认源（Dart 3.12.2 / kernel 130），
混用报 `Unexpected Kernel Format Version 130 (expected 138)`。3.44.9 这代自洽，
实测 `flutter --version` 报 Dart 3.12.2，对得上。

## 实测走过的 11 关

| # | 卡点 | 解法 |
|---|---|---|
| 1 | Flutter 自报 `0.0.0-unknown` | 浅克隆没 tag，`git tag 3.44.9 HEAD` 并删 `bin/cache/flutter.version.json` |
| 2 | 依赖解析 | ✅ **80 包零冲突**，无需降级任何依赖 |
| 3 | `No Hmos SDK found` | `updateLocalProperties` 要求 `hmosSdk != null`，判定条件是目录下同时有 `hmscore/` 与 `openharmony/`。commandline-tools 自带的叫 `hms/`，做软链 `hmscore -> hms` |
| 4 | `Missing file "oh-package.json5"` | 现有 `ohos/` 是空壳，`flutter create --platforms ohos .` 重新生成 |
| 5 | `00306042 Specification Limit Violation` | 模板写死 `compatibleSdkVersion: "5.0.5(17)"` / `targetSdkVersion: "26.0.0"`，后者缺 `(API)` 后缀 |
| 6 | `00303168 SDK component missing` | `hms/` 各组件缺 `oh-uni-package.json`（实际叫 `uni-package.json`），HarmonyOS 模式读不到版本 |
| 7 | `00303034 Please configure compileSdkVersion` | OpenHarmony 模式必须显式写 `compileSdkVersion`，HarmonyOS 模式不用 |
| 8 | `00303208 Unable to find 'sdk.dir'` | 往 `ohos/local.properties` 加 `sdk.dir=`。**注意该文件无结尾换行**，`echo >>` 会把新行粘到上一行 |
| 9 | `00303065 runtimeOS does not match` | `runtimeOS` 在 `build-profile.json5` 和 `entry/build-profile.json5` **两处**都要改 |
| 10 | `00303060 system capability sets empty` | `module.json5` 的 `deviceTypes` 从 `"phone"` 改 `"default"` |
| 11 | **ArkTS 编译失败（当前卡点）** | 见下 |

第 1~10 关全是环境与模板配置问题，**与本项目代码无关**。

### 第 11 关：引擎 ArkTS 层需要闭源 HarmonyOS SDK

引擎 HAR 的 `oh-package.json5` 自己声明：

```json
"compatibleSdkVersion": 12,
"compatibleSdkType": "HarmonyOS"
```

它用到 `getGlobalWindowMode`、`isInFreeWindowMode`、`enableDrag`、`CompetitionStrategy`
等**华为私有窗口接口**。实测这些接口在以下 SDK 中均不存在：

| SDK | 结果 |
|---|---|
| OpenHarmony 6.1-LTS（API 23） | ❌ 18 个错：`CompetitionStrategy` 等接口已变更 |
| commandline-tools 自带 openharmony（API 18） | ❌ 29 个错：缺 `getGlobalWindowMode` 等新接口 |
| commandline-tools 自带 hms | ❌ grep 不到这些符号，且缺版本元数据 |
| 华为云镜像更新版本 | ❌ **不存在**，`harmonyos/ohpm/` 与 `openharmony/ohpm/` 最高都是 5.1.0 |

**所以 API 版本换来换去都没用**——开源 SDK 里根本没有这些符号，
必须用 DevEco Studio 附带的闭源 HarmonyOS SDK。

## 已经验证成立的（重要）

**本项目的 Dart 代码完全没问题。** 第 10 关之后的日志：

```
flutter assemble:
copy flutter assets to project start / end
> hvigor Finished :entry:default@FlutterTask... after 10 s 626 ms
```

`FlutterTask` 通过意味着：

- **177 处 `Color.withValues` 零改动编译通过**（该 API 自 Flutter 3.27 起提供，3.44.9 原生支持）
- **不涉及 Dart 2 → Dart 3 回退**，`sdk: ">=3.3.0 <4.0.0"` 直接满足
- **`flutter_tts` / `shared_preferences` / `path_provider` 没有在编译期拦截**
  （运行期是否可用未验证——没跑起来过）

## 下一步：只差一个华为开发者账号

1. 在 [developer.huawei.com](https://developer.huawei.com) 注册并**实名认证**；
2. 下载安装 DevEco Studio，取其附带的 HarmonyOS SDK；
3. 把 `sdk.dir` / `DEVECO_SDK_HOME` 指向该 SDK，`runtimeOS` 改回 `HarmonyOS`，
   版本格式用 `M.S.F(API)`，从第 11 关继续。

之后还剩的已知工作：

- 两个 MethodChannel 要用 ArkTS 重写：`com.kline.novelreader/volume_key`（音量键翻页）；
  `com.kline.novelreader/app_update` 里的 `installApk` **鸿蒙无对等能力**，只能跳应用市场；
- `flutter_tts`（听书）鸿蒙侧实现未验证；
- 插件 `shared_preferences` / `path_provider` 的 ohos 实现在
  `atomgit.com/oh-flutter/flutter_packages`，需确认与 3.44.9 配套。

## 装到真机：机制与 Android 完全不同

**鸿蒙 NEXT 不允许自由侧载。**

| | Android | HarmonyOS NEXT |
|---|---|---|
| 签名密钥 | 自己生成 | 华为云签发，需实名认证 |
| Profile | 不存在 | **与设备 UDID 一对一绑定** |
| 证书配额 | 不限 | 每账号 1 正式 + 2 调试 |
| 分发 | 挂 Release 让人下 | **只能 AppGallery 上架审核** |

流程：`hdc shell bm get --udid` → AGC 注册设备 → 申请调试证书+Profile → 签名 → `hdc install`。

**所以本项目「GitHub Release + 应用内更新」这套分发在鸿蒙上整个失效**，
`.hap` 装不上任何未注册设备。要让真实用户用上，终点只有 AppGallery 上架。

## 模拟器

引擎产物里**有 `ohos-x64`**（`ohos-x64/artifacts.zip` 31 MB，实测存在），
理论上支持 x86_64 模拟器。但模拟器镜像需 DevEco Studio，同样要账号。
社区的 `gitee.com/openharmony-emu/vendor_emulator_emulator_x86_64` 停更于 2024-11。

## 现在鸿蒙用户怎么办

**HarmonyOS 4.2 及更早基于 AOSP，直接支持安装 APK**，用 Release 里的
`novel-reader-arm64-v8a.apk` 即可。只有 HarmonyOS NEXT（5.0 / 星河版）去掉了
Android 兼容层，那部分设备要等本仓库真正接入后才能用。

## 给上游提 issue 的素材

1. `flutter create --platforms ohos` 生成的工程在**纯 OpenHarmony 工具链下开箱即错**，
   需手改 4 处（`compileSdkVersion` 缺失、版本格式、两处 `runtimeOS`、`deviceTypes`）；
2. 模板写死 `5.0.5(17)` / `26.0.0`，与 commandline-tools 5.1.0 自带的 API 18 不同步；
3. 引擎 HAR 依赖闭源 HarmonyOS SDK 的私有接口，导致**纯开源工具链无法完成构建**，
   但文档未说明这一前提。
