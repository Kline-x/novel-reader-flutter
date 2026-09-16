# 接手文档 — 藏书阁（Flutter / 纯血鸿蒙版）

更新时间：2026-09-16　　当前分支：`main`　　当前版本：`v1.0.0+1`

> **这份文档是自包含的**：读完即可开工，不必先看其他文档。
> 项目物理路径：`/Users/yang/Documents/code/vibCoding/novel_reader_flutter`
> 远程仓库地址：`git@github.com:Kline-x/novel-reader-flutter.git`
> 视觉真源：`modern_soft_reader_prototype.html`（Modern Soft UI 高保真原型）
> 进度记录：`PROGRESS.md`，开发纪律与提交规范：`AGENTS.md`。

---

## 一、 当前状态与工程基线

| 维度 | 规范与状态 |
| :--- | :--- |
| **代码仓库** | Git 本地仓库已初始化（`main`），独立于旧版 RN 工程，零历史包袱 |
| **远程仓库** | `origin -> git@github.com:Kline-x/novel-reader-flutter.git` |
| **流水线 CI** | GitHub Actions `.github/workflows/ci.yml`（代码检查、单测、Android/Web构建、鸿蒙准入门禁） |
| **版本管理** | 严格遵循 SemVer 语义化版本：`v1.0.0+1` |
| **分支模型** | `main`（稳定发布主干）、`develop`（日常集成主干）、`feat/*`（功能演进） |
| **代码治理** | 接入 Conventional Commits 规范（`feat/fix/docs/test/refactor/chore`） |
| **三端架构** | iOS + Android + HarmonyOS NEXT（纯血鸿蒙）对等支持架构 |
| **核心算法** | 纯内存 CJK 整数行排版引擎与字符级锚点已实现并跑通测试 |

---

## 二、 核心技术栈与依赖军规

- **核心语言**：Dart 3.x（强类型安全、空安全）
- **状态管理**：`flutter_riverpod: ^2.5.1`
- **网络与嗅探**：`dio: ^5.4.3+1` + `html: ^0.15.4` + `xpath_selector: ^2.2.0` + `json_path: ^0.7.3`
- **中文编码**：`fast_gbk: ^1.0.1`（彻底解决老网文站点 GBK/GB2312 乱码）
- **中文拼音**：`lpinyin: ^2.0.3`（书架按书名拼音真实重排）
- **依赖准入军规**：业务层 100% 选用 Pure Dart 库；原生功能统一接入 OpenHarmony-TPC 官方适配插件。

---

## 三、 四大排版与体验核心设计原则

1. **整数行绝对截断**：单页最大行数 $N = \lfloor (H_{avail} + S_{line}) / (H_{line} + S_{line}) \rfloor$，视口底部严禁裁剪半截字符；
2. **字符级进度锚点 (`charOffset`)**：以章内字符偏移作为持久化锚点，改字号、转屏后自动逆向二分查找新页码，焦点分毫不动；
3. **分级冷热存储**：SQLite 仅持久化元数据与阅读进度，长篇正文下沉至沙盒独立文本文件缓存；
4. **Modern Soft UI 自绘统一**：基于连续曲率 Squircle、双层环境软阴影与 62px 悬浮毛玻璃 Dock 构建全套自绘控件。

---

## 四、 阶段交付成果与当前工程就绪状态

1. **已交付阶段清单**：
   - **阶段 1（工程基线与CI/CD）**：Flutter 3.47.4、CocoaPods 1.17.0、GitHub Actions 四层防御流水线、纯血鸿蒙 Pure Dart 准入门禁；
   - **阶段 2（Modern Soft UI 体系）**：羊皮纸/水墨白/豆沙青/深空暗夜 4 款微晕染主题、Squircle 连续曲率、双层软阴影、62px 悬浮毛玻璃 Dock、书架 Bento 看板、`lpinyin` 汉字字典序重排、个人设置中心与 WiFi 局域网传书；
   - **阶段 3（纯内存排版引擎）**：出版级 35 类避头避尾中文标点禁则表、2em 全角缩进、整数行绝对截断数学公式、字符级进度锚点（`charOffset` 二分反查无跳页）、4 种翻页动效（平移/覆盖/仿真/滚动）；
   - **阶段 4（书源生态与冷热存储）**：12 组优质内置书源、Dio 字节流嗅探、`fast_gbk` 无损转码根治乱码、广告降噪清洗、SharedPreferences 热进度 + 沙盒 `chapters/{bookId}/{ch}.txt` 冷正文分级存储；
   - **阶段 5（上层抽屉与状态联动）**：目录检索与章定位抽屉、排版控制抽屉（字号/行距/主题/翻页模式）、Riverpod 驱动排版与持久化联动；
   - **阶段 6（多端构建与打包验证）**：Web WASM 产物编译成功（`build/web`）、Android Debug APK 成功构建（`build/app/outputs/flutter-apk/app-debug.apk` 149MB）；
   - **阶段 7（真机 E2E 走查与吃狗粮闭环）**：Redmi K60 实测全链路、9 项核心缺陷 100% 修复并真机销项，全量存证归档于 `docs/evidence/`。
2. **全量自动化验证存证**：
   - `flutter analyze`：0 issues found!
   - `flutter test`：32/32 个测试用例 100% 全部通过。
3. **当前就绪状态**：
   - 全阶段（阶段 1~7）任务全部完成，工程达成真正可交付、可日常沉浸阅读的出版级品质。




