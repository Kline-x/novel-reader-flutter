# 藏书阁（Flutter版）演进与阶段化推进记录

> **基线规范**：严格遵循阶段化开发纪律，阶段未经验证不进入下一阶段；
> 每次阶段完成必须留存测试结果与证据。

---

## 阶段推进总览

| 阶段 | 核心目标 | 状态 | 需真机 | 产出物 / 证据 |
| :--- | :--- | :--- | :--- | :--- |
| **阶段 1** | 多端环境就绪、三端工程脚手架与 CI/CD 建设 | ⏳ **进行中** | 否 | Git 仓库初始化、远程仓库配置、GitHub Actions 流水线、依赖白名单 |
| **阶段 2** | Modern Soft UI 视觉设计系统（软拟态、微阴影、连续曲率） | ⚪ 未开始 | 否 | `soft_theme.dart`、`soft_card.dart`、`floating_dock.dart` |
| **阶段 3** | 自研纯内存排版引擎与手势视口（彻底根治 4 大硬伤） | ⚪ 算法已就绪 | 是 | 整数行截断公式、字符锚点追踪、平移/覆盖/仿真翻页 |
| **阶段 4** | 书源解析引擎、GBK 转码与离线分级存储 | ⚪ 未开始 | 否 | 12 组书源、fast_gbk、SQLite + 沙盒文件冷热分离 |
| **阶段 5** | 上层功能抽屉与 Bento 设置中心完整移植 | ⚪ 未开始 | 否 | 目录搜索抽屉、排版抽屉、换源弹窗、WebDAV/WiFi 传书 |
| **阶段 6** | 三端联合构建、打包与实机门禁验证 | ⚪ 未开始 | 是 | Android APK、iOS ipa、纯血鸿蒙 .hap |

---

## 详细阶段执行与验证记录

### 阶段 1：多端环境就绪与三端工程脚手架搭建
- **开始时间**：2026-09-16 22:00
- **当前负责人**：Antigravity
- **本阶段范围**：
  - [x] 创建新工程物理路径 `/Users/yang/Documents/code/vibCoding/novel_reader_flutter`
  - [x] 初始化 Git 仓库，设置默认主干分支 `main`
  - [x] 配置远程仓库 `origin -> git@github.com:Kline-x/novel-reader-flutter.git`
  - [x] 建立 GitHub Actions 自动化流水线 `.github/workflows/ci.yml`（Lint、单测、构建、鸿蒙准入门禁）
  - [x] 制定生产级 `.gitignore`（覆盖 Flutter、Android、iOS、OpenHarmony NEXT 与 IDE）
  - [x] 制定严格的依赖准入配置文件 `pubspec.yaml`（纯 Dart 优先 + TPC 认证）
  - [x] 确立提交规范 `AGENTS.md` 与交接文档 `HANDOFF.md`
  - [ ] 完成本地 Flutter SDK 安装并跑通 `flutter doctor`
  - [ ] 配置 OpenHarmony NEXT 宿主结构规范
- **离线验收标准**：
  - Git 仓库干净，`git status` 无未受控冗余文件
  - 代码目录层级符合 Clean Architecture 分层规范
  - 流水线 YAML 语法有效，包含静态检查、单元测试与依赖守卫
