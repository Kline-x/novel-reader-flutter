# AGENTS.md — 藏书阁（Flutter版）开发规范与多Agent协同纪律

**接手请读 [`HANDOFF.md`](HANDOFF.md)。它是自包含的**——当前状态、下一步、
全部硬约束、环境搭建、待办清单都在里面，读完即可开工，不需要再看别的文档。

---

## 一、 并行子 Agent 分工与协作规范 (Multi-Agent Parallelism)

> **原则**：能用多 Agent 并行推进的地方，**坚决开多个子 Agent 分工并发，严禁单一 Agent 串行做完全部事情**。

### 1. 研发攻坚期：模块解耦三路并发 (Feature Concurrency)
- **主 Agent**：架构师与守门人（Gatekeeper）。前置定义数据契约（Data Contract）与模块接口边界；
- **并发子 Agent 矩阵**：
  - **组件/UI Agent**：独立推进 Modern Soft UI 设计系统组件库（`soft_card`, `soft_button`, `soft_switch`, `floating_dock`）；
  - **排版/手势 Agent**：独立攻坚自绘 Viewport 与手势状态机（Slide / Cover / 3D Curl / Scroll）；
  - **书源/数据 Agent**：独立攻坚 12 组书源、GBK/UTF-8 自动探测管道与冷热分级存储；
- **合并与验收**：各子 Agent 完成独立单测后由主 Agent 进行契约复核、差异审查与原子合并。

### 2. 真机验收期：三权分立协作模式 (QA Concurrency)
- **检测 Agent**：独占真机/模拟器，驱动自动化脚本执行操作、抓取走查截图、采集系统日志（**只测不改代码**）；
- **记录 Agent**：维护问题清单（`QA-ISSUES.md`），按严重度（P0/P1/P2）分类归纳、定位根因、去重整理（**只记不改代码**）；
- **修复 Agent**：处理已确认的缺陷，修改源码并跑通离线单测（**只修代码，不碰测试设备**）；
- **主 Agent**：集中收尾，汇总验收结论，触发全量回归门禁。

---

## 二、 平台矩阵自适应裁切法则 (Adaptive Platform Strategy)

真实业务中并非所有项目都跨三端。工程基线必须根据《目标交付矩阵》按需裁切：
1. **单端形态 (Single-Platform)**：如纯 Web、纯 Android 墨水屏、纯 iOS 独立应用。裁剪多端宿主，CI 仅配置单一构建目标，零冗余；
2. **移动跨端形态 (Multi-Platform Mobile)**：iOS + Android（按需选配纯血鸿蒙 NEXT）。保留共享内核 `lib/`，按需挂载 `ios/`、`android/`、`ohos/`；
3. **全平台形态 (Full-Stack / Desktop)**：Mobile + Desktop (macOS/Windows) + Web。业务内核独立，交互层采用响应式/断点自适应布局。

---

## 三、 提交规范 (Commit Conventions)

所有提交必须遵循 Angular / Conventional Commits 标准规范：

```text
<type>(<scope>): <subject>

[optional body]

[optional footer(s)]
```

### 1. Type 允许类型
- **`feat`**：新特性（如排版引擎、Modern Soft UI 组件、书源解析、设置页）
- **`fix`**：修复缺陷（如切半行、标点断行、转屏位置跳脱、乱码）
- **`docs`**：文档更新（如 `HANDOFF.md`, `PROGRESS.md`, 架构说明）
- **`test`**：新增或修改测试用例（排版单测、集成测试、真机门禁）
- **`refactor`**：重构（既不修复 bug 也不添加特性的代码重组）
- **`chore`**：构建流程、依赖管理或辅助工具配置更新
- **`ci`**：流水线配置更新

### 2. Scope 允许范围
- `reader`: 阅读器正文、手势视口、抽屉
- `engine`: 排版度量算法、CJK 标点、字符锚点
- `theme`: Modern Soft UI 视觉、色彩、微阴影、连续曲率
- `sources`: 12 组书源、GBK 转码、规则解析、嗅探
- `shelf`: 书架、Bento 看板、拼音排序、搜索
- `settings`: 设置中心、WebDAV 同步、WiFi 传书、离线清理
- `ohos`: 纯血鸿蒙专属宿主工程、DevEco 配置、TPC 插件
- `infra`: Git、CI、构建脚本、依赖

---

## 四、 阶段化开发与交付纪律

严格按阶段推进，**不跨阶段堆积未经验证的改动**。每个阶段必须遵循：

1. **阶段前明确边界**：开始前明确本阶段目标、影响范围和验收标准，并标明是否需要真机复验；
2. **多 Agent 并发推进**：模块解耦部分并行派发子 Agent 协同开工；
3. **聚焦当期范围**：只解决当前阶段范围内的问题，不顺手混入下一阶段的未成熟改动；
4. **完成质量门禁**：完成后必须运行静态分析（`flutter analyze`）与自动化测试（`flutter test`）；若阶段验收标准需要真机，必须使用当前候选产物在目标设备上完成全部场景并通过；
5. **证据闭环存证**：真机阶段必须留存当前产物的版本/哈希、设备信息、操作步骤、截图和必要日志至 `docs/evidence/`；
6. **文档与代码原子同步**：只有在完成本阶段全部验收并复验通过后，才能把阶段标记为完成，并同步更新 `PROGRESS.md` 与 `HANDOFF.md`；
7. **审阅 Diff 独立提交**：只暂存本阶段产生的文件，严禁将临时文件、未测试代码混入提交。
