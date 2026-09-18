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
   - **阶段 7（真机 E2E 走查与吃狗粮闭环）**：Redmi K60 实测全链路、9 项核心缺陷 100% 修复并真机销项，全量存证归档于 `docs/evidence/`；
   - **阶段 8（全网真实书源聚合检索与换源 + 桌面定制图标）**：12 组书源流式并发检索、加入书架与立即阅读联动、12 组书源热切面板、全新古典 Modern Soft UI 桌面图标实装与真机 E2E 实测；
   - **阶段 9（后台批量章节与全本离线下载调度引擎）**：3工作槽并发下载池、实时进度广播、沙盒 chapters/{bookId}/*.txt 冷落盘、断网飞行模式秒开阅读、书架绿色离线徽标与 8 项真机证据链归档；
   - **阶段 10（本地图书生态与大文件流式 TXT/EPUB 解析引擎）**：GBK/UTF-8 字符集启发式探测、大文件正则智能分章、RandomAccessFile 字节偏移流式局部 Seek 读取彻底解决 OOM、纯 Dart archive EPUB 解包排版、WiFi 局域网 HTTP 极速传书网页服务、书架本地书籍标识与 7 项真机证据链归档；
   - **阶段 11（听书 TTS 自然语音朗读引擎与锁屏后台音频服务）**：原生 TTS 引擎适配与环境隔离、中文智能分句保真算法、单例响应式广播流、0.8x~2.0x 语速微调、15~60 分钟睡眠定时、Modern Soft UI 底部控制弹窗、底部悬浮迷你播放器动态音波律动与 5 项真机证据链归档；
   - **阶段 12（读者划线批注、书签笔记系统与 WebDAV 多端增量云漫游）**：4 色高亮主题色彩、选段与批注心得绑定、书签增删查、出版级 Markdown 导出、WebDAV Basic Auth 通信、CRDT 风格三方增量合并、ReaderNotesSheet 28px Squircle 底部抽屉、AddAnnotationDialog 触控弹窗、WebDavConfigSheet 配置中心与 6 项 Redmi K60 真机证据链归档；
   - **阶段 13（纯血鸿蒙与 iOS 双端落地与适配）**：纯血鸿蒙 OpenHarmony NEXT `ohos/` 原生 Stage 架构工程、OpenHarmony-TPC 准入门禁实景 100% 审计、iOS 权限声明与 13.0+ 部署规范、多端形态断点与异形屏/挖孔屏安全区自适应、65/65 全量自动化测试全绿与 3 项 Redmi K60 真机证据链归档；
   - **阶段 14（生产极客瘦身、代码混淆签名与 GitHub Releases 全自动发版）**：定制 ProGuard/R8 混淆、资源极客瘦身（arm64-v8a 削减至 22.0MB，瘦身率 85.2%）、`--split-per-abi` 独立分包、GitHub Releases 全自动发版流水线（`.github/workflows/release.yml`）、70/70 全量自动化测试全绿与 2 项 Redmi K60 真机 Release 运行证据链归档；
   - **阶段 15（1:1 原型书籍详情页、真实高可用书源生态与阅读器无损翻页交互）**：1:1 对齐原型 `BookDetailPage`（Hero大图、Squircle立体书封、状态/字数/评分卡片、作品简介展开折叠、千章目录在读/已读标记、可用书源原地切换）、全面接入 100% 真实连通的「笔趣阁ZWX」千章真实正文彻底根除假数据、阅读器末页向后顺畅跨章翻页、书架常驻「本地导入」与「WiFi传书」入口、书籍长按呼出现代轻拟态管理底栏、DownloadService 全本 1000 章秒速离线落盘与 13 项 Redmi K60 真机证据链归档；
    - **阶段 16（真机 E2E 循环排查、扩大范围极限走查与零缺陷交付闭环）**：基于真实物理设备 Redmi K60 与 iQOO Neo11 深度实测，前两轮定位的 26+8+1 项缺陷已 100% 修复销项（含阅读页透明沉浸状态栏与挖孔避让、深色模式全穿透黑底黑字清零、TTS Mini 悬浮条 RenderBox 物理布局重排根治 HitTest 手势脱节、目录搜索高亮与书签溢出修复、书架网格小字与独立微胶囊徽标、设置中心真实容量统计与物理清理、WebDAV空配置拦截等），第二轮扩大范围极限走查零遗留缺陷，全工程 95/95 测试用例 100% 通过，86 张高清真机证据链全量归档；
    - **阶段 17（跨端高可用远程无损版本升级、智能拼音脱敏自愈、正文语义智能断行去广告、书架防漏光沉浸吸顶与书源信誉体系）**：
      1. **跨端高可用远程无损版本升级体系（方案 1 代理镜像落地）**：采用 `ghproxy.net` / `mirror.ghproxy.com` 国内高速镜像代理矩阵与 GitHub 原源短超时快速竞速，彻底消除国内无法访问 GitHub 的痛点；Android 端流式下载 APK 并唤起 FileProvider 覆盖安装（同 ApplicationId 100% 自动无损保留数据库、书架与离线数据）；iOS 直通 App Store；纯血鸿蒙 HarmonyOS NEXT 自适应拉起华为应用市场或企业 HAP；设置中心集成「检查新版本」软卡片与 Modern Soft UI 升级弹窗；
      2. **智能拼音脱敏还原引擎 (PinyinHarmonizer)**：针对第三方网文书源中规避机审替换的拼音字词执行智能自愈还原，使正文通畅连贯，并零误伤保留正常英文词汇，在正文清洗流与沙盒缓存读取层双重即时自愈；
      3. **阅读页正文语义智能分行与广告降噪**：全角空格识别、>320字超长段落按标点智能断段、46+ 条牛皮癣广告正则清洗；
      4. **书源智能信誉分体系**：笔趣阁7全本主力源 +1000 分置顶，缺章跳章残次源思兔阅读 -4000 分沉底；
      5. **换源探活保护与假目录根治**：换源前置探活，未收录绝对不破坏原目录；彻底删除 12 章假目录向沙盒写入逻辑；
      6. **书架与全站吸顶体系**：修复 SwipeRevealCard 静态红色底光外漏；重构 DockedBottomBar 56dp 沉浸贴底毛玻璃底栏；发现页、书架页、详情页全面接入 Pinned 毛玻璃吸顶体系；详情页解除 50 章限制支持全本上千章展开收起。
    - **阶段 18（智能拼音自愈与净化系统三层架构演进：云端热更新 + 自定义规则管理 + 变异解混淆）**：
      1. **变异干扰符智能解混淆引擎升级 (PinyinHarmonizer)**：针对第三方网文书源中添加干扰符规避审查的拼音词汇，实现抗干扰解混淆（Anti-Obfuscation）算法，精准识别并剥离 `-`、`_`、`.`、`*` 等混淆符号；新增汉字夹缝探测（Sandwich Probe），前后中文紧密包围时精准捕获；强化零误伤保护，纯英文句子日常词汇与合法专业术语（level, check, FBI, BOSS 等）绝对安全放行；
      2. **动态规则服务与高可用云端热更新体系 (PinyinRuleService)**：数据实体采用不可变设计，支持国内高速代理镜像、jsDelivr CDN 与 GitHub raw 多节点轮询热更，增量合并并保留用户启停偏好，根目录 `pinyin_rules.json` 独立维护支持免发版云端热更；
      3. **用户端 Modern Soft UI 规则管理抽屉 (PinyinRulesSheet) 与设置中心联动**：设置中心新增「智能拼音自愈与净化」入口，半屏抽屉展示规则统计、一键云端同步、自定义规则添加与启停开关、剪贴板 JSON 一键批量导入导出，规则变动毫秒级即时注入排版引擎生效；
      4. **21.4MB 极客瘦身安装包归档**：执行 `--split-per-abi` 构建独立分包，体积从 61.8MB 锐减至 **21.4 MB**（瘦身超 65%），更新覆盖至根目录 [`novel-reader-release.apk`](novel-reader-release.apk)。
2. **全量自动化验证存证**：
   - `flutter analyze`：**0 issues found!**（0 error, 0 warning）
   - `flutter test`：**161/161 个测试用例 100% 全部通过**（全绿无跳过）。
3. **下一步演进建议**：
   - 当前基线已达成零缺陷交付闭环门禁；
   - 本地已生成全新 21.4MB 极客瘦身版正式安装包 `novel-reader-release.apk`；
   - 手机连入电脑开启 USB 调试即可一秒完成 ADB 直装，或将根目录下 APK 传输至手机直接无损覆盖安装。
