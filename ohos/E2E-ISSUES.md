# 鸿蒙真机 e2e 问题清单（2026-09-20）

设备：HUAWEI HBN-AL00（Pura 70 Pro）/ `OpenHarmony-6.1.1.120` / API 24
包：`entry-default-signed.hap`，`minAPIVersion=60101024`，arm64，debug 签名
测试方式：`hdc` 驱动真机点击 + 截图逐屏核对，配合 `hilog` 与 `flutter attach`

## 处理结果总表

| # | 问题 | 结果 |
|---|---|---|
| 1 | 版本号误读 v1.0.1 | ✅ 已修，真机验证 `getPackageInfo -> 1.0.9+4007` |
| 2 | 更新下载 APK 的死路 | ✅ 已修，`isHarmonyOS` 真正置位 |
| 3 | TXT 正文行被误判为章节标题 | ✅ 已修，4 条回归测试 |
| 4 | 音量键翻页开关无效 | ⛔ **鸿蒙平台限制**，改为禁用并说明 |
| 5 | 导入只能手填绝对路径 | ✅ 已修，真机验证系统选择器 |
| 6 | 扫描沙盒扫出章节缓存 | ✅ 已修，降级为选择器的兜底 |
| 7 | 应用名是 novel_reader_flutter | ✅ 已修为「藏书阁」 |
| 8 | 调字号把行距一起改掉 | ✅ 已修，4 条回归测试 |
| 9 | 排版面板配色与主题割裂 | ✅ 已修，强调色改用应用主题 |
| 10 | 覆盖安装后主题重置 | ⚠️ **我的误判**，见下 |
| 11 | 阅读器菜单自动隐藏 | ⚠️ **我的误判**，见下 |
| 12 | 顶栏遮住章节标题 | ➖ 设计取舍，不改，见下 |
| 13 | 划线批注弹窗溢出 | ✅ 已修，2 条 widget 测试 |

---

## 一、功能性缺陷

### 1. 版本号误读成 v1.0.1，导致永远提示"有新版本"

设置页显示「当前 v1.0.1（旗舰引擎）」，实际装的是 **1.0.9**。
点「检查更新」能正常拉到清单并弹出「发现新版本 v1.0.9+6007」——
**拿已装的版本当新版本推给用户**。

根因在 `hilog` 里很明确：

```
[VersionCheckService] 读取安装版本失败，沿用内置默认值:
MissingPluginException(No implementation found for method getPackageInfo
on channel com.kline.novelreader/app_update)
```

`com.kline.novelreader/app_update` 是自写 channel，鸿蒙侧没有 ArkTS 实现。

### 2. 「立即更新」下载的是 APK，鸿蒙装不了

同一个 channel 的 `installApk` 在鸿蒙无对等能力。
即使版本号修对了，这条更新链路在鸿蒙上整体不成立——
鸿蒙只能走 AppGallery，详见 `STATUS.md`「装到真机」一节。

### 3. TXT 分章正则把正文行误判为章节标题（**既有缺陷，非鸿蒙特有**）

用一个 3 章的样本文件实测，被分成了 **5 章**：

| # | 目录里的章节名 | 实际 |
|---|---|---|
| 1 | 第一章 鸿蒙初启 | 正常 |
| 2 | 第二章 传书验证 | 正常 |
| 3 | 第二章正文。若这一章能在书架里打开… | **正文行被当成标题** |
| 4 | 第三章 收尾 | 正文被上一条抢走，显示「(本章暂无正文内容)」 |
| 5 | 第三章正文，用于验证章节切换。 | **正文行被当成标题** |

正则只要求行首出现「第X章」，没有对标题长度、是否独占一行做约束。
真实小说里「第三章的内容其实是……」这类句子开头的段落会被误切。

### 4. 物理音量键翻页：鸿蒙平台限制，做不到

原以为是「自写 channel 没实现」，实测发现**不是代码问题**。

Dart 侧本来就在 `HardwareKeyboard` 里处理 `audioVolumeUp/Down`
（`reader_viewport.dart:170`），`volume_key` 那个 channel 是 Android 专用的
——Android 上 Flutter 收不到音量键，必须由 Activity 拦截再转发。

鸿蒙上用 `hdc shell uinput -K -d 17 -u 17` 注入音量下键实测：页码纹丝不动，
日志显示按键被系统 `sceneboard` 吃掉了：

```
com.ohos.sceneboard/AudioSystemManager: [ForceVolumeKeyControlType]volumeType:1
com.ohos.sceneboard/lottie_ohos: VolumeControl-Progress_Image_icon animation
```

音量键是系统独占按键，应用要拦截得有 `ohos.permission.INPUT_MONITORING`
这个系统权限，普通应用申请不到。

**处理**：鸿蒙上把设置页那个开关置灰并改副标题为
「鸿蒙系统独占音量键，应用无法接管」，不再给「已启用」的错觉。
`SoftSwitch.onChanged` 相应改为可空，传 null 即禁用并降透明度。

### 5. 本地导入只能手填绝对路径，没有文件选择器

「导入本地图书」面板要求「输入或粘贴文件绝对路径 (.txt / .epub)」。
普通用户根本拿不到沙箱绝对路径。**应接系统文件选择器**。

### 6. 「扫描沙盒图书」扫出的是章节缓存，不是图书

点「扫描沙盒图书」后，输入框被填入
`/data/storage/el2/base/files/flutter/chapters/to...`——
这是章节缓存目录下的 json，不是可导入的 .txt/.epub。

### 7. 应用名还是 `novel_reader_flutter`

桌面图标下显示 `novel_reader_...` 而不是「藏书阁」。
`AppScope/resources/base/element/string.json` 的 `app_name`
与 `entry` 下 base / zh_CN / en_US 三份 `EntryAbility_label`
都还是 `flutter create` 的默认值。

---

## 二、体验问题

### 8. 调字号会把行距一起改掉

在排版面板点两次「A+」（18 → 20）并切换翻页模式后，
行距从「舒适」变成了「紧凑」——**全程没有碰行距那一行**。

### 9. 排版面板配色与应用主题割裂

应用主题是「极夜星芒」（冰蓝），阅读器夜间模式的强调色也是冰蓝，
唯独排版面板的选中态、滑块、勾选圈是**墨绿**。
排版面板用的是「阅读主题色」而非应用主题色，两套色系撞在一起。

### 10. 覆盖安装后主题被重置 —— **我的误判**

查代码后确认：阅读器底栏那个「夜间/日间」按钮走的是
`_toggleNightMode()`，它会调 `themeModeProvider.setThemeMode()`，
**进而把全局 ThemeMode 写进 SharedPreferences**。

我在 e2e 过程中点过这个按钮，全局明暗因此从 `system` 变成了 `dark`，
重装后自然显示深色。不是覆盖安装丢数据——阅读时长能留下来正说明数据没丢。

顺带说明：全局明暗（ThemeMode）与配色方案（SoftPaletteType）是两个独立维度，
`setThemeMode` 不碰配色。**阅读器里的一个按钮会改全局设置**这件事本身
是否合理，可以另议，但它不是 bug。

### 11. 阅读器菜单自动隐藏 —— **我的误判**

`reader_viewport.dart` 里根本没有自动隐藏的定时器，只有
`_handleTap` 的点击切换：中心 1/3 开关菜单，两侧 1/3 翻页。

我观察到的「菜单消失」，是自动化点击的坐标落在了底部菜单栏的边缘、
没命中按钮，事件穿透到正文，而那个 x 坐标正好在右侧 1/3 → 触发翻页。
是我的测试方式问题，不是应用行为。

### 12. 阅读器顶栏遮住章节标题 —— 设计取舍，不改

菜单唤出时顶栏浮层压住正文第一行的章节大标题，只露出下半截。

但这是阅读器的通行做法（iOS Books、微信读书同样是浮层覆盖），
而且顶栏自己就显示了章节名，信息没有丢失。
要让正文避开就得在菜单显示时改变可视区高度，那会触发重新分页、
页码跟着跳，代价大于收益。保持现状。

### 13. 划线批注弹窗溢出，露出黄黑警告条

长按拖选正文 →「添加划线批注」弹窗 → 两端微调那一行
`RIGHT OVERFLOWED BY 26 PIXELS`。

`lib/features/notes/presentation/add_annotation_dialog.dart:354` 的 Row：

```dart
Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Row(children: [Text('起点 '), 扩, 缩]),
    Text('已选 ${_currentSelectedText.length} 字'),  // 字数增大时更宽
    Row(children: [Text('终点 '), 缩, 扩]),
  ],
)
```

三个子项都按自然宽度排布，没有 Flexible / Expanded，加起来超出可用宽度就溢出。
与问题「发现页长标题溢出」同类——**都是 Row 里没有可收缩项**，
鸿蒙字宽略大于 Android 所以在这里先撞线。debug 包画黄黑条，
release 不画但内容照样被裁。

建议统一排查全项目的 `Row` + 定宽文本组合，不只修这两处。

---

## 三、已确认可用（鸿蒙真机实测通过）

| 功能 | 结果 |
|---|---|
| 启动、渲染、底部导航、页面路由、边缘返回手势 | ✅ |
| 书架：空状态、统计卡片、书籍卡片、进度条 | ✅ |
| **WiFi 局域网传书**：电脑浏览器上传 → 自动分章 → 入架 | ✅ 23 MB 全本 4.8 秒完成 |
| 本地 TXT 阅读：正文渲染、分页、翻页 | ✅ |
| 发现页：书源聚合、真实书目、分类筛选 | ✅ |
| 书籍详情：553 章目录、书源标识 | ✅ |
| 在线阅读：正文抓取、分页翻页 | ✅ |
| 目录抽屉：章节列表、搜索、倒序、已缓存标记 | ✅ |
| 排版：字号实时重排、行距、翻页模式、阅读主题 | ✅（但有问题 8） |
| 夜间模式切换 | ✅ |
| 笔记面板：书签 / 划线笔记双 Tab、导出入口 | ✅ |
| 设置持久化：切主题后冷重启保持 | ✅ |
| 智能拼音自愈：云端 39 条规则拉取 | ✅ |
| WebDAV 配置面板与错误校验 | ✅ |
| 离线章节缓存（设置页显示已缓存 185 KB） | ✅ |
| 中文输入法（IME 唤起与输入） | ✅ |
| TTS 引擎：华为 HiAI `init success` / `listVoices` | ✅ 链路通 |
| 更新检查的网络链路（拉取 version_manifest） | ✅ |

---

## 四、本轮未覆盖

| 项 | 未测原因 |
|---|---|
| 全网书源搜索（输入书名并发搜索） | `uinput -K -t` 只收 ASCII，中文报 `The character of index 0 is invalid`。搜索**后端**链路在打开在线书时已间接验证（`multiSourceService.searchAll` 能匹配到书源并取回目录），只差 UI 输入这一段没走 |
| TTS 实际朗读效果 | 按要求全程保持静音，只验证到引擎初始化 |
| WebDAV 实际同步 | 需要真实账号与授权码 |
| EPUB 导入 | 只测了 TXT |
| 整本下载缓存 | 未触发 |
| 书签添加、划线笔记的写入 | 只看了空态 |
| 书架视图切换 / 排序 / 书架内搜索 | 未触发 |
| 音量键翻页的实际按键响应 | channel 未实现，按了也无反应 |

---

## 五、与鸿蒙无关的既有疑点

发现页点进《偷偷藏不住》（竹已），详情页的简介却是《草芥称王》（月关），
章节名也对不上。疑似书源聚合的匹配问题，**需要拿 Android 对照**
才能确认不是鸿蒙特有的。本轮 Android 设备未连接，没做成对照。
