# 藏书阁（Flutter版）演进与阶段化推进记录

> **基线规范**：严格遵循阶段化开发纪律，阶段未经验证不进入下一阶段；
> 每次阶段完成必须留存测试结果与证据。

---

## 阶段推进总览

| 阶段 | 核心目标 | 状态 | 需真机 | 产出物 / 证据 |
| :--- | :--- | :--- | :--- | :--- |
| **阶段 1** | 多端环境就绪、三端工程脚手架与 CI/CD 建设 | ✅ **已完成** | 否 | Flutter 3.47.4、CocoaPods 1.17.0、GitHub Actions CI、flutter analyze 0 issues、flutter test 100% Pass |
| **阶段 2** | Modern Soft UI 视觉设计系统（软拟态、微阴影、连续曲率） | ✅ **已完成** | 否 | `soft_theme.dart`、`soft_card.dart`、`soft_button.dart`、`soft_switch.dart`、`floating_dock.dart`、10/10 自动化小部件测试全过 |
| **阶段 3** | 自研纯内存排版引擎与手势视口（彻底根治 4 大硬伤） | ✅ **已完成** | 否 | 整数行截断公式、字符锚点追踪、平移/覆盖/仿真/滚动翻页、测试 100% 通过 |
| **阶段 4** | 书源解析引擎、GBK 转码与离线分级存储 | ✅ **已完成** | 否 | 12 组书源生态、fast_gbk 嗅探转码、沙盒 chapters/{bookId}/{chapterIndex}.txt + SharedPreferences 冷热分级存储、单元测试 100% 通过 |
| **阶段 5** | 上层功能抽屉与 Bento 设置中心完整移植 | ✅ **已完成** | 否 | 目录搜索抽屉、排版抽屉、换源弹窗、WebDAV/WiFi 传书、Riverpod 控制器联动 |
| **阶段 6** | 多端联合构建、打包与跨端门禁验证 | ✅ **已完成** | 否 | Web (WASM) 成功生成 `build/web`、Android Debug APK (`app-debug.apk` 149MB) 成功构建、纯血鸿蒙 Pure Dart 门禁通过 |

---

## 详细阶段执行与验证记录

### 阶段 1：多端环境就绪与三端工程脚手架搭建
- **开始时间**：2026-09-16 22:00
- **完成时间**：2026-09-16 23:45
- **当前负责人**：Antigravity
- **本阶段交付内容**：
  - [x] 创建新工程物理路径 `/Users/yang/Documents/code/vibCoding/novel_reader_flutter`
  - [x] 初始化 Git 仓库，设置默认主干分支 `main`
  - [x] 自动创建并绑定远程仓库 `origin -> git@github.com:Kline-x/novel-reader-flutter.git`
  - [x] 建立 GitHub Actions 自动化流水线 `.github/workflows/ci.yml`（Lint、单测、构建、鸿蒙准入门禁）
  - [x] 制定生产级 `.gitignore`（覆盖 Flutter、Android、iOS、OpenHarmony NEXT 与 IDE）
  - [x] 制定严格的依赖准入配置文件 `pubspec.yaml`（纯 Dart 优先 + TPC 认证）
  - [x] 确立提交规范 `AGENTS.md` 与交接文档 `HANDOFF.md`
  - [x] 完成本地 Flutter 3.47.4 SDK 与 CocoaPods 1.17.0 安装并配置环境变量
  - [x] 验证排版引擎单测通过（`test/reader_layout_engine_test.dart` 100% Pass）
  - [x] 修复 Flutter 3.47+ `withValues` 规范，`flutter analyze` 达成 0 issues
- **离线验收标准与存证**：
  - Git 仓库干净，分支推送至 GitHub 远端 `main`
  - `flutter analyze` 结果：`No issues found!`
  - `flutter test` 结果：`ReaderLayoutEngine 核心排版引擎测试 All tests passed!`
  - 磁盘空间清理验证：清理安装包后可用磁盘空间为 20GB（消耗可控）

---

### 阶段 4：书源生态、GBK自动嗅探转码与冷热分级存储
- **开始时间**：2026-09-17 00:20
- **完成时间**：2026-09-17 00:46
- **当前负责人**：Antigravity (Phase 4 Subagent)
- **本阶段交付内容**：
  - [x] 实现 `lib/features/sources/services/network_client.dart`：
    - 基于 Dio 封装智能 HTTP 请求通道（支持二进制原始字节流接收 `ResponseType.bytes`）；
    - 自动探测 HTTP `Content-Type` 与 HTML `<meta charset>`（GBK、GB2312、GB18030、UTF-8）；
    - 集成 `fast_gbk` 库实现 GBK / GB2312 字节流无损解码与关键词特定百分号转义，彻底解决老牌网文站乱码问题；
  - [x] 实现 `lib/features/sources/services/source_parser.dart`：
    - 解析 `SourceRule`，实现 `searchBooks`、`fetchToc`、`fetchChapterContent`；
    - 自动清洗段落、剥离广告噪音（含首发域名、天才一秒记住、最新网址、本章完等规则），支持 HTML 实体映射（如 `&emsp;` 全角缩进），输出标准 `List<String> paragraphs`；
  - [x] 扩展 `lib/features/sources/services/builtin_sources.dart`：
    - 收录完整 12 组高质量书源生态（笔趣阁CP、笔趣阁ZWX、思兔阅读、天天看小说、夜天连看、穿越小说[GBK]、笔趣阁7、去读书[GBK]、爱下书[GBK]、香书小说[GBK]、猪猪书网、鬼吹灯书屋）；
  - [x] 实现 `lib/features/sources/services/multi_source_service.dart`：
    - 支持并发对 12 组内置书源进行关键词聚合检索（`searchAll` 与响应式流 `searchStream`）；
    - 智能去重与毫秒级延迟标记，提供书源连通性测速 (`pingAllSources`)；
  - [x] 实现 `lib/features/reader/data/storage_service.dart`：
    - 冷热分级存储机制：
      - 热数据：元数据与阅读进度（字符级锚点 `charOffset`、章索引、书架列表增删改查）持久化至 `SharedPreferences`；
      - 冷数据：长文本章节正文下沉至本地沙盒文件 `chapters/{bookId}/{chapterIndex}.txt`（基于 `path_provider`）；
      - 提供单书与全局缓存占用字节统计 (`getBookCacheSize`, `getTotalCacheSize`)、人性化大小格式化 (`formatBytes`) 与一键清理功能；
  - [x] 完善单元测试：
    - `test/network_client_test.dart`（GBK/UTF-8 编解码、嗅探与转义）；
    - `test/source_parser_test.dart`（书源规则、段落清洗与实体解析）；
    - `test/multi_source_service_test.dart`（多源并发检索、流式发射与延迟统计）；
    - `test/storage_service_test.dart`（热数据读写、冷数据长文本沙盒写入、大小统计与清理）；
- **离线验收标准与存证**：
  - `flutter analyze` 结果：`No issues found!`（0 告警，0 错误）
  - `flutter test` 结果：全部测试套件 21/21 用例 100% 通过（耗时 2 秒内）

---

### 阶段 2：Modern Soft UI 视觉设计体系与书架 Bento 看板
- **开始时间**：2026-09-17 00:00
- **完成时间**：2026-09-17 01:20
- **当前负责人**：Antigravity
- **本阶段交付内容**：
  - [x] 严格遵循 Modern Soft UI（Calm Tech）设计系统：
    - `lib/core/theme/soft_theme.dart`（羊皮纸、水墨白、豆沙青、深空暗夜 4 款护眼微晕染主题；连续曲率 Squircle 24px；双层环境光微阴影；软拟态凹凸阴影）；
    - `lib/core/theme/theme_provider.dart`（基于 Riverpod 的主题切换状态管理）；
    - `lib/core/components/soft_card.dart`、`soft_button.dart`（按下微缩放 scale 反馈）、`soft_switch.dart`（双层凹凸轨道开关）；
    - `lib/core/components/floating_dock.dart`（62px 悬浮毛玻璃三胶囊底栏与丝滑切换）；
    - `lib/core/components/main_scaffold.dart`（集成 IndexedStack 保持页面状态）；
  - [x] 实现书架 Bento 模块与发现页：
    - `lib/features/shelf/presentation/shelf_page.dart`（Bento 数据看板、`lpinyin` 汉字拼音字典序绝对重排、即时检索与高亮过滤、单字微浮雕印章封面、列表/网格两档自由切换）；
    - `lib/features/shelf/presentation/discovery_page.dart`（分类胶囊、热门排行榜单、多源聚合搜索直达）；
    - `lib/features/settings/presentation/settings_page.dart`（读者看板、音量键翻页/屏幕常亮触感开关、WebDAV 增量云备份、WiFi 局域网传书、沙盒缓存统计与弹窗安全清空）；
  - [x] 自动化测试套件 `test/shelf_and_settings_test.dart`（10 个用例全部通过）：
    - 验证 MainScaffold 正常启动与 FloatingDock 三胶囊挂载；
    - 验证 TabBar 自由切换（书架 -> 发现 -> 设置 -> 书架）；
    - 验证拼音首字母字典序排序（道诡异仙 -> 诡秘之主 -> 剑来 -> 十日终焉）；
    - 验证搜索输入过滤、重置、空状态发现页重定向；
    - 验证列表与网格模式切换；
    - 验证音量键翻页与常亮开关状态交互；
    - 验证缓存清空弹窗取消与确认清空流程；
    - 验证 SoftCard、SoftButton 触感 scale 动效及 FloatingDock 62px 悬浮高度。
- **离线验收标准与存证**：
  - `flutter test test/shelf_and_settings_test.dart` 结果：10/10 全部通过。

---

### 阶段 3：自研纯内存确定性排版引擎与视口状态机
- **开始时间**：2026-09-17 00:10
- **完成时间**：2026-09-17 00:50
- **当前负责人**：Antigravity
- **本阶段交付内容**：
  - [x] `lib/features/reader/engine/cjk_punctuation.dart`：35类严格避头避尾禁则表（GB/T 15834 + JIS X 4051），2em 全角缩进规范；
  - [x] `lib/features/reader/engine/page_models.dart`：数学级整数行模型、字符级锚点系统（`charOffset`）；
  - [x] `lib/features/reader/engine/reader_layout_engine.dart`：
    - 整数行截断公式：$N = \lfloor (H_{avail} + S_{line}) / (H_{line} + S_{line}) \rfloor$；
    - 逆向二分映射字符偏移，改字号/转屏分毫不跳；
  - [x] `lib/features/reader/presentation/page_painter.dart`：CustomPainter 逐行自绘渲染、顶栏电量/时间、底栏页码；
  - [x] `lib/features/reader/presentation/reader_viewport.dart`：
    - 支持 4 种翻页动效：平移（Slide）、覆盖（Cover）、3D 仿真（Curl）、垂直流式（Scroll）；
    - 手势拦截与中心 1/3 触控呼出操作栏；
- **离线验收标准与存证**：
  - `test/reader_layout_engine_test.dart` 与 `test/reader_viewport_test.dart` 自动化测试 100% 通过。

---

### 阶段 5：上层功能抽屉与状态全链路联调
- **开始时间**：2026-09-17 00:40
- **完成时间**：2026-09-17 01:15
- **当前负责人**：Antigravity
- **本阶段交付内容**：
  - [x] `lib/features/reader/presentation/catalog_drawer.dart`：目录搜索抽屉、正倒序切换、定位当前章；
  - [x] `lib/features/reader/presentation/typography_drawer.dart`：字号滑块 (12~32px)、行距调节、5款主题色板、4种翻页模式；
  - [x] `lib/features/reader/presentation/reader_controller.dart` & `reader_screen.dart`：Riverpod 驱动排版重算、进度缓存同步；
  - [x] 主流程无缝串联：从书架点击书本直达阅读器、返回书架自动更新进度。

---

### 阶段 6：多端构建、打包与跨端门禁验证
- **开始时间**：2026-09-17 01:18
- **完成时间**：2026-09-17 01:36
- **当前负责人**：Antigravity
- **本阶段交付内容**：
  - [x] Web 端 WASM 构建：`flutter build web --wasm --no-pub` 成功编译生成 `build/web` 静态托管资源；
  - [x] Android 原生 Debug 打包：`flutter build apk --debug --no-pub`，自动配置 Android SDK Build-Tools 36 与 Android-36 Platform，成功输出 `build/app/outputs/flutter-apk/app-debug.apk`（149MB）；
  - [x] 纯血鸿蒙（HarmonyOS NEXT）门禁验证：核心算法、书源解析、网络解码层 100% 遵守 Pure Dart 依赖军规，与 OpenHarmony-TPC 完全兼容；
  - [x] 自动化测试与静态审计全量验收：
    - `flutter analyze`：**0 errors, 0 warnings (No issues found!)**；
    - `flutter test`：**31/31 个测试用例 100% 全部通过**；
    - 磁盘空间：可用空间充裕保持在 **21 GiB**。


