# 鸿蒙支持现状：已在纯血鸿蒙真机上跑起来

**一句话结论（2026-09-20 实测）：藏书阁已经装进 HarmonyOS 真机并正常运行**——
HUAWEI HBN-AL00 / `OpenHarmony-6.1.1.120` / API 24。
书架、发现页、书籍详情、页面路由、返回手势、主题跟随系统，全部实测正常，
发现页能拉到真实书源数据、书籍详情能拿到 553 章目录。

`flutter build hap` 全程无改动通过，**本项目的 Dart 代码一行都没为鸿蒙改过**。
真正要处理的是工程配置：装上 DevEco 26 拿到闭源 SDK（第 11 关）、
降级 API 声明才能装进比 IDE 旧的设备（第 16 关）、
补三个 `*_ohos` 插件实现（第 17 关）。

补上三个 `*_ohos` 插件后，**阅读器正文、分页翻页、设置持久化（冷重启保持）
也全部实测通过**，鸿蒙版已是功能可用状态。

尚未实现/未验证：**物理音量键翻页**（开关能开但 `volume_key` 这个自写 channel
鸿蒙侧没实现，实际不生效）、应用内更新（`installApk` 无对等能力，只能跳应用市场）、
TTS 听书、WiFi 传书、本地导入。

在此之前，仓库各处声称「纯血鸿蒙 NEXT 对等支持」「全平台多端对等」，
且版本清单里挂着指向从不存在的 `.hap` 的下载地址。已清理。

## 这个目录里有什么

14 个文件的 DevEco 工程骨架。`entry/src/main/ets/pages/Index.ets` 只渲染一行文字，
**没有任何挂载 Flutter 的代码**，不是可用工程。真要接入需用
`flutter create --platforms ohos .` 重新生成（见下文第 4 关）。

**实测构建没有用这个目录。** 为了不污染主仓库，实验是在
`E:\code\flutter-ohos\app`（本仓库的一份副本）里做的，那边的 `ohos/` 是
`flutter create` 重新生成再逐关改出来的。等真机跑通、确认可维护之后，
再把改好的工程回灌进本目录。

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

## 编译环境：两条路，只有第二条走得到头

| | 路线 A：纯开源工具链 | 路线 B：DevEco Studio |
|---|---|---|
| 宿主 | WSL Ubuntu 22.04 | **Windows 原生** |
| 华为账号 | 不需要 | **需要（下载 IDE + 申请签名证书）** |
| 结果 | ❌ 止步第 11 关 | ✅ **编出签名 `.hap`** |

**路线 A 走不通的原因**见下文第 11 关：引擎 ArkTS 层用了华为私有窗口接口，
开源 SDK 里根本没有这些符号，换多少个 API 版本都没用。

**不需要 Mac，也不需要 GitHub macOS runner。** 曾误判「只有 darwin 产物」——
那只对维护者的覆盖清单成立，OBS 默认源 Linux/Windows 产物都有。
也曾误判「Windows 没有 commandline-tools 所以必须 WSL」——DevEco Studio
自带完整的 Windows 版 ohpm / hvigor / node / JDK，路线 B 全程在 Windows 上跑。

### 路线 A 组件来源（免登录）

| 组件 | 来源 | 大小 |
|---|---|---|
| 鸿蒙 Flutter SDK | `atomgit.com/oh-flutter/flutter_flutter` 分支 `oh-3.44.9-dev` | ~1.5 GB |
| commandline-tools（ohpm/hvigor/node） | `repo.huaweicloud.com/openharmony/ohpm/5.1.0/commandline-tools-linux-x64-5.1.0.840.zip` | 2.0 GB |
| OpenHarmony SDK | `repo.huaweicloud.com/openharmony/os/6.1-LTS/ohos-sdk-windows_linux-public.tar.gz` | 3.2 GB |
| Dart SDK + 引擎产物 | `flutter-ohos.obs.cn-south-1.myhuaweicloud.com`，首次 `flutter --version` 自动拉 | ~600 MB |

搭建脚本与踩坑记录见 `E:\code\flutter-ohos\README.md`（本机路径，未入库）。

### 路线 B 环境（实测走通）

| 组件 | 位置 |
|---|---|
| DevEco Studio | `D:\DevEco Studio`（26.0.0.821） |
| HarmonyOS SDK（闭源） | `D:\DevEco Studio\sdk\default\{hms,openharmony}`，**只有 API 26** |
| ohpm / hvigor / node | `D:\DevEco Studio\tools\` 下，26.0.0.630 / node v24.14.1 |
| JDK | `D:\DevEco Studio\jbr`（JDK 25，**必须用这个**，见第 12 关） |
| 鸿蒙 Flutter SDK | `E:\code\flutter-ohos\sdk-3.44`（`oh-3.44.9-dev`） |

环境变量脚本 `E:\code\flutter-ohos\env-win.ps1`：设 `DEVECO_SDK_HOME`、`JAVA_HOME`，
并把 jbr/flutter/ohpm/hvigor/node/toolchains 六个 bin 目录拼进 PATH。
**PATH 必须用数组 `-join ';'` 拼**，直接在双引号里插 `$DEVECO` 会被路径中的空格切碎。

**选 `oh-3.44.9-dev` 而非 `oh-3.47.4-dev`**：后者维护者重建了 darwin 产物
（Dart 3.13.3 / kernel 138），非 darwin 宿主会回退 OBS 默认源（Dart 3.12.2 / kernel 130），
混用报 `Unexpected Kernel Format Version 130 (expected 138)`。3.44.9 这代自洽，
实测 `flutter --version` 报 Dart 3.12.2，对得上。

## 实测走过的 18 关

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
| 11 | ArkTS 编译失败：引擎用了华为私有接口 | ✅ 装 DevEco Studio 取闭源 SDK，见下 |
| 12 | `The keystore was created by a newer JDK version` | DevEco 的 jbr 是 JDK 25，系统 JDK 是 1.8。`JAVA_HOME` 指向 `D:\DevEco Studio\jbr` 并把它的 `bin` 放 PATH 最前 |
| 13 | 没有签名证书，打不出可安装包 | AGC 申请调试证书 + Profile（Profile 与设备 UDID 一对一绑），填进 `build-profile.json5` 的 `signingConfigs` |
| 14 | — | ✅ **构建成功**，产出 112.3 MB 的 `entry-default-signed.hap` |
| 15 | `install failed due to older sdk version in the device` | 包 `minAPIVersion=260000026`，真机是 API 24。见下 |
| 16 | 想降级声明成 API 24 重编 | hvigor 写死只收它内置表里的最新 SDK。改表 + SDK 镜像绕过，见下 |
| 17 | ✅ **装上并跑起来了**，但一进阅读器就永远「正在加载」 | 插件一个都没注册，MethodChannel 永久挂起。加三个 `*_ohos` 包，见下 |
| 18 | `00303231 srcPath is not a relative path` | pub cache 在 C 盘、工程在 E 盘，跨盘没有相对路径。设 `PUB_CACHE` 同盘 |

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

装上 DevEco Studio 26 之后这一关就过了，ArkTS 编译、打包、签名一路到底。

### 第 15~16 关：编出来了，但装不上真机

`hdc install` 报 `install failed due to older sdk version in the device`。
解包 `.hap` 看 `module.json`：

```json
"minAPIVersion": 260000026,
"targetAPIVersion": 260000026,
"compileSdkVersion": "26.0.0.105"
```

真机是 HUAWEI HBN-AL00，`OpenHarmony-6.1.1.120`，**API 24**。包要 26，装不上。

直接改 `build-profile.json5` 的 `compatibleSdkVersion` 没用，hvigor 拒绝：

```
00303312 Cannot find the corresponding SDK version under the specified SDK path.
```

翻 `hvigor-ohos-plugin\src\sdk\hmos-sdk-loader.js` 找到原因，是硬校验：

```js
checkSdkVersionMatch(o) {
  const e = HosVersionMapper.INSTANCE.getLatestSupportVersion()
             .getFullBaseApi().getValue();
  o.fullVersion !== e && _log.printErrorExit("COMPILE_SDK_VERSION_MISMATCH", ...)
}
```

**`getLatestSupportVersion()` 读的是一个静态 json，与本地装了哪些 SDK 无关**：
`@ohos/hos-sdkmanager-common/build/res/hos-config.json`。DevEco 26 的表里最高是
`26.0.0`，于是编译目标只能是 26。

顺便修正一个容易犯的错：该表里 **API 24 对应平台版本 `6.1.1`**，
`6.1.0` 是 API 23。`6.1.0(24)` 是个不存在的组合。

| 平台版本 | API |
|---|---|
| 26.0.0 | 26.0.0 |
| 6.1.1 | 24 |
| 6.1.0 | 23 |
| 6.0.0 | 20 |
| 5.0.5 | 17 |

### 绕过：改表 + SDK 镜像，实测能编出 API 24 的包

既然那张表是静态文件，把最高档删掉，`getLatestSupportVersion()` 自然降到 24。
API 26 的头文件是 24 的超集，编译照样过。两份东西都做成副本，**原 DevEco 不动**：

1. **hvigor 副本**：DevEco 安装目录只读，`robocopy` 把 `D:\DevEco Studio\tools\hvigor`
   整个复制到 `D:\OpenHarmony\hvigor-as24`（226 MB），删掉副本里 `hos-config.json`
   的 `26.0.0` 档（`osVersionMapper` / `osNameMapper` / `pathVersionMapper` 三处）。
   构建时把 `D:\OpenHarmony\hvigor-as24\bin` 前置进 PATH。
2. **SDK 镜像**：`D:\OpenHarmony\sdk-as24`，各组件的大目录用**目录联结**
   （`New-Item -ItemType Junction`）链回原 SDK，只有元数据是真实副本——
   `sdk-pkg.json` 和 10 个组件的 `uni-package.json` / `oh-uni-package.json`，
   `apiVersion` 改 `24`、`platformVersion` 改 `6.1.1`。整个镜像只占 **32.6 MB**。
3. `local.properties` 的 `hwsdk.dir`、环境变量 `DEVECO_SDK_HOME` 都指镜像，
   `build-profile.json5` 写 `"6.1.1(24)"`。

结果：

```
minAPIVersion     60101024      ← 6.1.1 + API 24，与设备一致
targetAPIVersion  60101024
compileSdkVersion 26.0.0.105    ← 头文件仍是 26 的
```

**残留风险**：引擎运行时若调用了 API 26 才有的接口，在 API 24 设备上会崩。
编译期查不出来（头文件是 26 的），只能跑起来看。

改元数据时踩的两个坑：
- PowerShell 的 `Set-Content -Encoding UTF8` **会写 BOM**，JSON 解析直接失败，
  表现成「找不到 SDK 版本」，与版本号无关。用 `cp` + `sed` 改最稳。
- `.properties` 里反斜杠是转义符，`hwsdk.dir=D:\OpenHarmony\...` 会被读成
  `D:OpenHarmony...`。用正斜杠。

## 已经验证成立的（重要）

**本项目的 Dart 代码完全没问题**，整个构建已经端到端跑通：

```
Running Hvigor task assembleHap...   66.5s
√ Built build\ohos\hap\entry-default-signed.hap.
```

arm64 产物 117.7 MB，x64 产物 119.4 MB，都已签名。编译通过意味着：

- **177 处 `Color.withValues` 零改动编译通过**（该 API 自 Flutter 3.27 起提供，3.44.9 原生支持）
- **不涉及 Dart 2 → Dart 3 回退**，`sdk: ">=3.3.0 <4.0.0"` 直接满足
- **`flutter_tts` / `shared_preferences` / `path_provider` 没有在编译期拦截**
  （运行期是否可用未验证——没跑起来过）

## 下一步

构建已经不是问题了，**没跑起来过**才是。当前手段是 x86_64 模拟器：
DevEco 的虚拟设备里有 `HarmonyOS 7.0.0(26.0.0)` 镜像，API 对得上产物。
对应的包用 `flutter build hap --debug --target-platform ohos-x64` 编
（引擎的 `ohos-x64` 产物 OBS 上有，已实测存在并可用，产物 119 MB）。

### 第 17 关：插件一个都没注册，MethodChannel 永久挂起

跑起来之后立刻撞上：书架、书籍详情、发现页都正常（纯网络路径），
但一进阅读器就永远停在「正在加载...」，**既不超时也不报错**。

根因在 `ohos/entry/src/main/ets/plugins/GeneratedPluginRegistrant.ets`：

```ets
static registerWith(flutterEngine: FlutterEngine) {
  try {
  } catch (e) { ... }
}
```

**空的。** `flutter create --platforms ohos` 只为「声明了 ohos 实现的插件」生成注册代码，
而 pub 上的官方 `path_provider` / `shared_preferences` / `flutter_tts` 都没有 ohos 实现。
于是 Dart 侧发出的 MethodChannel 调用没有任何 handler 接，
**Future 既不完成也不抛异常，永久 pending**。

这一点很坑：代码里的 `try/catch` 接得住抛出的异常，**接不住永不完成的 Future**。
本项目 `getCacheDirectory()` 就有完整的 try/catch 兜底，照样卡死。

解法是三个 ohos 实现包，**pub.dev 上都有现成的**：

| 包 | 版本 | 对应 |
|---|---|---|
| `path_provider_ohos` | 2.2.1 | `path_provider` |
| `shared_preferences_ohos` | 2.2.0 | `shared_preferences` |
| `flutter_tts_ohos` | 4.2.5 | `flutter_tts`（版本号正好对上） |

加进 `pubspec.yaml` 后 `flutter pub get` 会自动重新生成注册表：

```ets
flutterEngine.getPlugins()?.add(new SharedPreferencesPlugin());
flutterEngine.getPlugins()?.add(new PathProviderPlugin());
flutterEngine.getPlugins()?.add(new FlutterTtsPlugin());
```

接上之后实测：阅读器正文正常加载、分页翻页正常；
切换主题后**冷重启仍保持**，且累计阅读时长有记录——
说明 `shared_preferences_ohos` 与 `path_provider_ohos` 都真正在工作，
不只是「不卡了」。

### 第 18 关：pub cache 必须和工程同一个盘

加完插件构建立刻报：

```
00303231 The srcPath is not a relative path:
C:/Users/gaore/AppData/Local/Pub/Cache/hosted/pub.dev/flutter_tts_ohos-4.2.5/ohos
```

hvigor 要求模块的 `srcPath` 是相对路径，而插件的 ohos 模块就在 pub cache 里。
pub cache 默认在 `C:\Users\<user>\AppData\Local\Pub\Cache`，工程在 `E:\`，
**跨盘写不出相对路径**。设 `PUB_CACHE` 到同盘再 `flutter pub get` 即可。

跑起来之后才能验证的已知工作：

- 两个自写 MethodChannel 要用 ArkTS 重写——这两个**没有现成的 ohos 包**，
  必须自己实现：`com.kline.novelreader/volume_key`（音量键翻页）；
  `com.kline.novelreader/app_update` 里的 `installApk` **鸿蒙无对等能力**，只能跳应用市场；
- `flutter_tts_ohos` 已接入，但听书实际效果未验证；
- WiFi 传书（局域网 HTTP 服务）、本地 TXT/EPUB 导入未验证；
- 发现页的书籍数据是串的（书名《偷偷藏不住》/ 简介却是《草芥称王》/ 章节名也对不上），
  疑似书源聚合的既有问题，**需要拿 Android 对照确认不是鸿蒙特有的**。

注意 `atomgit.com/oh-flutter/flutter_packages` 里**没有** `path_provider_ohos`
（只有 `shared_preferences_ohos`）。直接用 pub.dev 上的版本更省事，见第 17 关。

## 装到真机：机制与 Android 完全不同

**鸿蒙 NEXT 不允许自由侧载。**

| | Android | HarmonyOS NEXT |
|---|---|---|
| 签名密钥 | 自己生成 | 华为云签发，需实名认证 |
| Profile | 不存在 | **与设备 UDID 一对一绑定** |
| 证书配额 | 不限 | 每账号 1 正式 + 2 调试 |
| 分发 | 挂 Release 让人下 | **只能 AppGallery 上架审核** |

流程：`hdc shell bm get --udid` → AGC 注册设备 → 申请调试证书+Profile → 签名 → `hdc install`。

**还有一条 Android 上不存在的约束**：包的 `minAPIVersion` 必须 ≤ 设备 API，
而 hvigor 只肯按它内置表里的最新 API 编译（见第 16 关）。也就是说
**IDE 版本一旦领先于手机系统版本，默认就装不上**，得按第 16 关的办法降。

**所以本项目「GitHub Release + 应用内更新」这套分发在鸿蒙上整个失效**，
`.hap` 装不上任何未注册设备。要让真实用户用上，终点只有 AppGallery 上架。

## 模拟器

DevEco 26 的虚拟设备管理器里镜像很全，手机从 `HarmonyOS 5.0.1(13)` 一路到
`HarmonyOS 7.0.0(26.0.0)`，另有折叠屏 / 平板 / 2in1 / 电视 / 智能表。
**模拟器不需要签名证书，也不需要注册 UDID**，是目前最省事的验证手段。

模拟器是 x86_64，要单独编：

```bash
flutter build hap --debug --target-platform ohos-x64
```

引擎的 `ohos-x64` 产物 OBS 上有，实测可用，产出 119 MB 的
`entry-default-signed.hap`，内含 `libs/x86_64/libflutter.so`。

社区的 `gitee.com/openharmony-emu/vendor_emulator_emulator_x86_64` 停更于 2024-11，
用不上了。

## 现在鸿蒙用户怎么办

**HarmonyOS 4.2 及更早基于 AOSP，直接支持安装 APK**，用 Release 里的
`novel-reader-arm64-v8a.apk` 即可。只有 HarmonyOS NEXT（5.0 / 星河版）去掉了
Android 兼容层，那部分设备要等本仓库真正接入后才能用。

## 给上游提 issue 的素材

1. `flutter create --platforms ohos` 生成的工程在**纯 OpenHarmony 工具链下开箱即错**，
   需手改 4 处（`compileSdkVersion` 缺失、版本格式、两处 `runtimeOS`、`deviceTypes`）；
2. 模板写死 `5.0.5(17)` / `26.0.0`，与 commandline-tools 5.1.0 自带的 API 18 不同步；
3. 引擎 HAR 依赖闭源 HarmonyOS SDK 的私有接口，导致**纯开源工具链无法完成构建**，
   但文档未说明这一前提；
4. hvigor 的 `checkSdkVersionMatch` 只接受内置静态表里的最新 API，
   **无法为低于 IDE 版本的设备构建**。这不是 Flutter 移植的问题，是 hvigor 本身的，
   但对「装了新 IDE、手机还是旧系统」的开发者是个硬阻塞，值得向华为反馈。
