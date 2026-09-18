# 项目领域上下文与架构规范 (CONTEXT.md)

藏书阁（Flutter / 纯血鸿蒙跨端小说阅读器）核心领域模型、架构边界与规范词汇表。
本文件供人类开发者与 AI Coding Agent（配合 Matt Pocock Engineering Skills）作为事实标准（Source of Truth）。

---

## 一、 领域词汇表 (Domain Glossary)

在工单（Tickets）、测试用例、规格说明书（Specs）及代码重构中，必须统一采用以下标准术语，严禁使用同义词漂移：

| 术语 (Term) | 中文定义 | 说明与边界 |
| :--- | :--- | :--- |
| **`TypographyEngine`** | 纯内存出版级排版引擎 | 基于 TextPainter 的纯纯内存排版计算。核心数学公式为整数行绝对截断，视口底部绝不允许出现被削切半行的文字。 |
| **`CharAnchor`** | 字符级进度锚点 | 章内绝对字符偏移量（`charOffset`）。字号变更、屏幕旋转时基于此锚点进行反向二分查找新页码，杜绝跳页脱节。 |
| **`ModernSoftUI`** | 现代柔和拟物设计系统 | 视觉规范基准。基于连续曲率（Squircle）、双层超微晕染软阴影、毛玻璃悬浮 Dock（DockedBottomBar）构建的拟物 UI。 |
| **`PinyinHarmonizer`** | 智能拼音脱敏自愈引擎 | 针对第三方网文为避审而将敏感情节替换为拼音或夹带干扰符（如 `ch-u-an-g`）的自愈清洗管线，具备汉字夹缝探测与纯英文放行能力。 |
| **`HierarchicalStorage`** | 分级冷热存储 | 架构准则：热数据（阅读进度、书架排序、用户偏好）走 SQLite / SharedPreferences；冷数据（全本长篇正文 TXT）走沙盒独立分章缓存。 |
| **`BookSource`** | 书源 | 包含抓取规则（XPath / JSONPath / CSS）、字符集探测（`fast_gbk` 无损转码）与信誉评分的数据源实体。 |
| **`SourceAggregator`** | 书源聚合与流式调度器 | 多书源并发搜索、换源前置探活、坏源惩罚降权的核心调度服务。 |
| **`TTSEngine`** | 语音朗读引擎 | 集成原生/鸿蒙 TTS 适配通道、智能断句算法、锁屏后台播放及音波律动迷你悬浮条（Mini Player）。 |
| **`SyncEngine`** | WebDAV 增量同步服务 | 支持 WebDAV Basic Auth 通信与 CRDT 风格多端阅读进度与批注书签的三方合并。 |

---

## 二、 系统架构分层与职责边界 (Architecture Boundaries)

工程严格遵守响应式分层架构（Riverpod 2.x）：

```text
lib/
├── core/                  # 全局基础底座
│   ├── constants/         # 样式、尺寸、动画时长常量
│   ├── network/           # Dio 实例、代理镜像竞速调度器
│   ├── theme/             # Modern Soft UI 主题体系（4款微晕染配色）
│   └── utils/             # 编码探测 (fast_gbk)、拼音重排 (lpinyin)
├── features/              # 垂直功能业务模块（每模块按 presentation / domain / data 划分）
│   ├── reader/            # 阅读器视口、手势状态机 (Slide/Cover/Curl/Scroll)、排版与批注
│   ├── shelf/             # 书架 Bento 看板、拼音字典序排布、全本离线下载徽标
│   ├── sources/           # 12 组内置书源、规则解析引擎、广告降噪、书源信誉体系
│   ├── pinyin_rules/      # 拼音自愈规则云端热更新、自定义规则管理抽屉
│   ├── tts/               # 听书音频控制、后台保活、断句播报
│   ├── local_books/       # 本地 TXT / EPUB 流式解析、WiFi 传书局域网服务器
│   └── settings/          # 设置中心、缓存物理清理、版本无损热更新
```

---

## 三、 不可触碰的架构红线 (Architectural Invariants)

1. **排版引擎视口完整性**：
   - 严禁在排版视口内部直接使用原生的滑动列表进行正文换页；
   - 翻页与断行度量必须经过 `TypographyEngine` 显式计算，严格遵守单页最大行数公式：
     $$N = \lfloor (H_{avail} + S_{line}) / (H_{line} + S_{line}) \rfloor$$
2. **纯血鸿蒙与多端依赖准入**：
   - 业务逻辑层必须 100% 为 Pure Dart 库，不得随意引入依赖 C/C++ 专有桥接或未经鸿蒙 TPC 认证的 Flutter 原生插件。
3. **数据安全与无损覆盖**：
   - 本地缓存清理操作仅限清除 `chapters/{bookId}/*.txt` 缓存文件，严禁触碰数据库中的书籍元数据、书架标记与历史阅读进度。
4. **开发与交付红线（详见 AGENTS.md）**：
   - 全程使用中文思考与回复；
   - 代码修改必须经过 `flutter analyze`（0 issue）与 `flutter test`；
   - 必须通过真机 E2E 循环排查、扩大范围探索找问题，达成零缺陷后方可交付。
