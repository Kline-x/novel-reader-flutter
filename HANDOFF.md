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

## 四、 下一步做什么（阶段 1 推进清单）

1. 等待本地 Flutter SDK 安装任务完毕，执行 `flutter doctor` 验证工具链；
2. 执行 `flutter pub get` 拉取项目基线依赖；
3. 在 GitHub 建立同名仓库 `Kline-x/novel-reader-flutter` 并执行推送：
   ```bash
   git push -u origin main
   ```
4. 进入阶段 2：开发 Modern Soft UI 视觉原子组件与三胶囊悬浮 Dock。
