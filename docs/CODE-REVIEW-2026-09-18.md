# 藏书阁（novel-reader-flutter）全量代码审查报告

- **审查日期**：2026-09-18
- **审查范围**：`lib/` 全量 64 个 Dart 文件、约 22,000 行（含工作区未提交改动）
- **基线**：`main` @ `5936899`，版本 `1.0.1+2002`
- **质量门禁实测**：`flutter analyze` → 0 issues；`flutter test` → 162/162 通过
- **结论**：静态检查与单测全绿，但存在 **15 项真实缺陷**，其中 5 项为高危（内容丢失 / 安全 / 崩溃），单测未覆盖到这些路径

> 严重度定义：**P0** = 数据丢失、安全风险、功能性崩溃；**P1** = 核心体验错误、用户可感知的错误结果；**P2** = 局部体验问题、性能或维护性风险。

---

## 一、缺陷总览

| 编号 | 严重度 | 模块 | 一句话描述 | 验证方式 |
| :--- | :---: | :--- | :--- | :--- |
| [ISSUE-01](#issue-01) | **P0** | 书源解析 | 广告过滤正则把整段正常正文整段删除 | ✅ 探针测试实证 |
| [ISSUE-02](#issue-02) | **P0** | WiFi 传书 | 上传文件名未过滤，可路径穿越写任意文件；服务无鉴权 | 代码审查 |
| [ISSUE-03](#issue-03) | **P0** | 版本升级 | 下载的 APK 不做 sha256/体积校验就唤起安装 | 代码审查 |
| [ISSUE-04](#issue-04) | **P0** | 版本升级 | 离线时写入假 APK 文本文件并唤起系统安装器 | 代码审查 |
| [ISSUE-05](#issue-05) | **P0** | 拼音自愈 | 规则 pattern 未转义直接拼进正则，一条规则即可让全书正文渲染中断 | ✅ 探针测试实证 |
| [ISSUE-06](#issue-06) | **P1** | 听书 TTS | 自动续章时朗读的是上一章的正文 | 代码审查 |
| [ISSUE-07](#issue-07) | **P1** | 书签 | 状态不同步时删除的是**无关**书签（数据丢失） | 代码审查 |
| [ISSUE-08](#issue-08) | **P1** | 阅读器 | 预置书任意章节离线降级都显示第 1 章内容 | 代码审查 |
| [ISSUE-09](#issue-09) | **P1** | 换源 | 换源后不清正文缓存，仍显示旧源的章节内容 | 代码审查 |
| [ISSUE-10](#issue-10) | **P1** | 存储 | 少于 20 章的书目录缓存每次读取即被删除 | 代码审查 |
| [ISSUE-11](#issue-11) | **P1** | 阅读器 | 页脚电量恒定显示 85%，是写死的假数据 | 代码审查 |
| [ISSUE-12](#issue-12) | **P1** | 本地导入 | 只存外部文件路径不落盘拷贝，源文件被清理后整本书报废 | 代码审查 |
| [ISSUE-13](#issue-13) | **P2** | 拼音自愈 | 服务未在启动时初始化，自定义规则不生效；且规则表按段落重建 | 代码审查 |
| [ISSUE-14](#issue-14) | **P2** | 换源 | 异步回调内 `setState` 未判 `mounted`，返回时抛异常 | 代码审查 |
| [ISSUE-15](#issue-15) | **P2** | 阅读器 | 滚动翻页模式下阅读进度完全不落盘 | 代码审查 |

---

## 二、缺陷详情

### <a id="issue-01"></a>ISSUE-01 · P0 · 广告过滤正则把整段正常正文整段删除

**位置**：[`lib/features/sources/services/source_parser.dart:249-338`](../lib/features/sources/services/source_parser.dart#L249)

**根因**：广告黑名单里有大量 `.*(?:关键词).*` 形式的**整行贪婪**正则（`笔趣阁`、`书城`、`上一页|返回目录|下一页`、`更新时间[：:]`、`xxx.com` 等）。清洗逻辑的设计意图是「只剥掉广告片段，剩余长度 ≥6 就保留」：

```dart
final stripped = line.replaceAll(pattern, '').trim();
if (stripped.length < 6) { isNoise = true; break; }
else { line = stripped; }
```

但 `.*…*` 匹配的是**整行**，`replaceAll` 后 `stripped` 恒为空串，长度 0 < 6 → 整段被判为广告直接丢弃。只要正文里出现这些词，这一整个自然段就从小说里消失了，且无任何提示。

**实证**（探针测试实际输出）：

```
IN : 他翻开手里那本旧书，扉页上印着笔趣阁三个褪色的小字，像是上个世纪的遗物。
OUT: []
IN : 林昭把地图铺在桌上，指着城东说道：他们的更新时间: 每天午夜换防，我们只有一次机会。
OUT: []
IN : 她压低声音说：下一页写着什么，你自己看。说完便转身走进了雨里。
OUT: []
IN : 这座城里最气派的建筑，是街角那家新开的百汇书城，三层楼高，灯火通明。
OUT: []
```

四段完全正常的小说正文，全部被静默删除。

**修复建议**：
1. 把整行贪婪模式拆成两类——**整行删除类**（纯广告行）用 `RegExp` 配 `hasMatch` 后直接丢弃；**片段剥离类**用非贪婪、不带前后 `.*` 的模式做 `replaceAll`。
2. 对「剥离后变空」的情况增加保护：若原行长度 > 40 且不含 URL/域名特征，倾向保留原行而不是丢弃。
3. 移除 `笔趣阁`/`书城`/`下一页` 这类高频普通词的整行规则，或加上「同一行还需命中域名、`最新`、`发布页` 等第二特征」的组合条件。

---

### <a id="issue-02"></a>ISSUE-02 · P0 · WiFi 传书路径穿越 + 服务无鉴权

**位置**：[`wifi_transfer_server.dart:166-220`](../lib/features/local_books/services/wifi_transfer_server.dart#L166)

**根因**：上传文件名直接取自 URL query 或 multipart 的 `Content-Disposition`，未做任何净化就拼进路径：

```dart
filename = request.uri.queryParameters['filename']!;   // 完全可控
...
final targetFile = File('${localBooksDir.path}/$filename');
await finalFile.writeAsBytes(fileData.bytes);
```

**失效场景**：服务 `HttpServer.bind(InternetAddress.anyIPv4, 8888)` 监听全部网卡、无任何鉴权，且返回 `Access-Control-Allow-Origin: *`。在同一 WiFi（咖啡厅 / 酒店 / 办公室）下，任何人都可以：

```
POST http://<手机IP>:8888/api/upload?filename=../../shared_prefs/xxx.xml
```

覆盖应用沙盒内的 SharedPreferences、数据库或已缓存的正文文件。此外 multipart 分支用 `request.fold` 把**整个请求体累积进内存**，上传一个大文件即可 OOM 崩溃。

**修复建议**：
1. 文件名净化：只取 `basename`，白名单字符集，强制 `.txt`/`.epub` 后缀，拒绝含 `..`、`/`、`\` 的名字。
2. 落盘前用 `File(...).resolveSymbolicLinksSync()` 或路径前缀比对确认仍在 `local_books` 目录内。
3. 启动服务时生成一次性 PIN/token，网页端与 `/api/upload` 都校验；或至少在弹窗显著提示「仅在可信网络开启」。
4. multipart 改为流式解析并设置最大体积上限。

---

### <a id="issue-03"></a>ISSUE-03 · P0 · 下载的 APK 不做完整性校验就唤起安装

**位置**：[`version_check_service.dart:376-450`](../lib/features/settings/services/version_check_service.dart#L376)

**根因**：`PlatformUpdateInfo` 声明并解析了 `sha256` 与 `fileSize` 字段，但**全工程没有任何一处使用它们**（已 grep 确认）。下载流程为：

```dart
final response = await _dio.download(url, saveFile.path, ...);
if (response.statusCode == 200) { downloadSuccess = true; break; }
...
await installApk(saveFile.path);
```

候选地址由 `buildAcceleratedDownloadUrls` 生成，**优先走三个第三方代理镜像**（`ghproxy.net`、`mirror.ghproxy.com`、`gh-proxy.com`）。

**失效场景**：
- 任一代理镜像被投毒 / 域名易主，返回的任意 APK 都会被原样交给系统安装器；
- 代理返回 200 + HTML 错误页时同样判定为「下载成功」，用户看到进度 100% 后弹出「解析软件包时出现问题」。

**修复建议**：下载完成后强制校验 `sha256`（`package:crypto`）与 `fileSize`，任一不符则删除文件、跳到下一候选地址；`version_manifest.json` 必须填写真实校验和。

---

### <a id="issue-04"></a>ISSUE-04 · P0 · 离线时写入假 APK 并唤起系统安装器

**位置**：[`version_check_service.dart:425-450`](../lib/features/settings/services/version_check_service.dart#L425)

**根因**：所有下载地址失败后，代码不是报错，而是伪造一个文件并仿真进度：

```dart
if (!downloadSuccess) {
  await saveFile.writeAsString('PK_MOCK_APK_FOR_UPDATE_VERIFICATION_${info.versionCode}');
  for (int i = 1; i <= 10; i++) { await Future.delayed(...); onProgress(i / 10.0); }
}
onProgress(1.0);
await installApk(saveFile.path);   // 把这个几十字节的文本文件丢给系统安装器
```

**失效场景**：用户在弱网/断网下点「立即升级」→ 进度条平滑走到 100% → 弹窗提示「下载完成，已唤起系统安装器」→ 系统弹出「解析软件包时出现问题」。这是单测脚手架逻辑被带进了生产分支。

**修复建议**：用 `kDebugMode` 或显式注入的测试开关隔离该兜底；生产路径下所有候选地址失败应直接抛错并提示「网络不可用，请稍后重试或手动前往发布页」。

---

### <a id="issue-05"></a>ISSUE-05 · P0 · 规则 pattern 未转义，一条规则即可让全书正文渲染中断

**位置**：[`pinyin_harmonizer.dart:395-405`](../lib/features/sources/services/pinyin_harmonizer.dart#L395)

**根因**：阶段四把规则的 `pattern` **未经转义**直接字符串插值进 `RegExp`，且该段没有 `try/catch`（相邻的阶段五反而有）：

```dart
for (final entry in activeMap.entries) {
  final regex = RegExp('(?<![a-zA-Z])${entry.key}(?![a-zA-Z])', caseSensitive: false);
  ...
}
```

`activeMap` 来源包括**用户在「智能拼音自愈」抽屉里手动添加的规则**、**剪贴板批量导入的 JSON**，以及**云端热更下发的 `pinyin_rules.json`**——全部是外部可控文本。

**实证**（探针测试实际输出）：

```
FormatException: Unterminated group
(?<![a-zA-Z])a(b(?![a-zA-Z])
package:.../pinyin_harmonizer.dart 401:11  PinyinHarmonizer.restorePinyin
```

**失效场景**：用户输入一条含 `(`、`[`、`+`、`*` 的规则（甚至只是手滑），异常从 `restorePinyin` 抛出并贯穿 `cleanAndFilterParagraphs` / `getChapterContent`，此后**所有章节正文都无法渲染**，且规则已持久化，重启也不恢复——用户只能猜到去删规则。云端下发一条坏规则则影响全部用户。

**修复建议**：
1. 非正则规则用 `RegExp.escape(pattern)` 转义；
2. 整个阶段四包 `try/catch`，单条规则失败只跳过该条；
3. `addCustomRule` 与 `syncFromRemote` 落库前先 `RegExp(...)` 试编译，非法规则直接拒绝并提示。

---

### <a id="issue-06"></a>ISSUE-06 · P1 · 听书自动续章时朗读上一章正文

**位置**：[`reader_screen.dart:968-984`](../lib/features/reader/presentation/reader_screen.dart#L968)

**根因**：

```dart
tts.onChapterComplete = () async {
  _nextChapter();                                    // 内部是未 await 的异步加载
  final newTitle = _chapters[_currentChapterIndex].title;
  final newText = _currentParagraphs.join('\n\n');   // 此刻仍是旧章节的段落
  await tts.playChapter(..., chapterTitle: newTitle, content: newText);
};
```

`_nextChapter()` → `_loadChapterContent()` 只在第一个 `await` 之前**同步**更新了 `_currentChapterIndex`，`_currentParagraphs` 要等存储/网络返回后才赋值。

**失效场景**：开启听书连续朗读，第 N 章念完后自动续章——标题显示第 N+1 章，念的却是第 N 章的正文，且会一直重复下去。

**修复建议**：把 `_loadChapterContent` 改为返回加载后的段落，`onChapterComplete` 里 `await` 它再取内容；或加载完成后由 `_loadChapterContent` 主动通知 TTS 续播。

---

### <a id="issue-07"></a>ISSUE-07 · P1 · 取消书签时删除的是无关书签

**位置**：[`reader_screen.dart:1015-1025`](../lib/features/reader/presentation/reader_screen.dart#L1015)

**根因**：

```dart
final match = bookmarks.firstWhere(
  (b) => b.chapterIndex == _currentChapterIndex && (b.charOffset - _currentCharOffset).abs() < 100,
  orElse: () => bookmarks.first,          // ← 找不到就删第一条
);
await _notesService.removeBookmark(match.id);
```

`getBookmarks` 按 `createdAt` 倒序返回，所以 `bookmarks.first` 是**全书最新的那条书签**。

**失效场景**：
- `_checkBookmarkStatus()` 只在 `onProgressChanged` 时触发，**切换章节时不会重算**。带着「已书签」状态进入新章节，点一下书签图标 → 当前位置无匹配 → 静默删掉最新的那条书签；
- 翻页后立刻点书签（异步状态检查尚未回来）同样触发。

**修复建议**：`orElse` 去掉，改用可空查找；找不到匹配时不删任何东西，并顺手把 `_isCurrentPageBookmarked` 纠正为 `false`。同时在 `_loadChapterContent` 成功后调用一次 `_checkBookmarkStatus()`。

---

### <a id="issue-08"></a>ISSUE-08 · P1 · 预置书任意章节离线降级都显示第 1 章内容

**位置**：[`chapter_helper.dart:121-182`](../lib/features/reader/services/chapter_helper.dart#L121) · 调用点 [`reader_screen.dart:500-518`](../lib/features/reader/presentation/reader_screen.dart#L500)

**根因**：`getPresetParagraphs(String bookTitle, int chapterIndex)` 声明了 `chapterIndex` 参数却**从头到尾没有使用**，只按书名返回固定的第一章段落。

**失效场景**：断网或书源解析失败时，读《诡秘之主》第 500 章，页面会正常渲染出「周明瑞醒来 / 绯红的月光」——即第 1 章的内容，且没有任何「这是降级内容」的提示，随后还会 `saveReadingProgress` 把进度按第 500 章存下去。这与 PROGRESS.md 中「彻底根除假数据」的结论相悖。

**修复建议**：预置段落改为只在 `chapterIndex == 0` 时返回，其余章节直接走 ISSUE 里的「获取失败」提示卡片；或干脆移除该降级路径。

---

### <a id="issue-09"></a>ISSUE-09 · P1 · 换源后不清正文缓存，仍显示旧源内容

**位置**：[`reader_screen.dart:857-887`](../lib/features/reader/presentation/reader_screen.dart#L857)

**根因**：换源成功后只覆盖了目录（`saveBookToc`），随即 `_loadChapterContent(_currentChapterIndex)`；而该方法会**优先命中沙盒缓存** `chapters/{bookId}/{index}.txt`，这些文件是旧书源写下的。`StorageService` 里已有 `deleteBookToc`，但没有对应的「清正文缓存」调用。

**失效场景**：用户正因为当前源缺章/乱码才去换源，换完弹出「已成功平滑切至书源 XXX，共获取 N 章目录」，正文却纹丝不动，仍是旧源的错误内容。

**修复建议**：换源成功后调用 `clearBookCache(bookId)`（或至少删掉当前章及相邻章的缓存文件）再重新加载。

---

### <a id="issue-10"></a>ISSUE-10 · P1 · 少于 20 章的书，目录缓存每次读取即被删除

**位置**：[`storage_service.dart:607-625`](../lib/features/reader/data/storage_service.dart#L607)

**根因**：

```dart
if (list.length < 20 || list.every((c) => (c['url'] ?? '').toString().isEmpty)) {
  await file.delete();
  return null;
}
```

这是为了清理历史「12 章假目录」而加的，但它把**所有**短目录都当成脏数据删掉了。`book_detail_page.dart:118-120` 还重复了一遍同样的 `>= 20` 判定。

**失效场景**：短篇小说、单章合集、章节数本来就少的书，目录缓存写进去后**下一次读取必被删除**，于是每次进书都要重新联网抓目录；断网时直接退化成 12 章假目录（ISSUE-08 的兄弟问题）。

**修复建议**：把判定条件换成真正的脏数据特征——例如「全部 url 为空」或「命中 `ChapterHelper` 的 12 个固定假章节名」，而不是用章节数量做阈值。

---

### <a id="issue-11"></a>ISSUE-11 · P1 · 页脚电量恒定 85%，是写死的假数据

**位置**：[`page_painter.dart:16/27/187-231`](../lib/features/reader/presentation/page_painter.dart#L16)

**根因**：`PagePainter.batteryLevel` 默认 `0.85`，而 `reader_viewport.dart` 里 6 处 `PagePainter(...)` 构造**没有一处传入该参数**；`pubspec.yaml` 也没有任何电量相关依赖（`battery_plus` 等）。

**失效场景**：阅读页右下角永远显示「85%」和对应的电池填充；PROGRESS.md 声称的「低于 20%/10% 警戒变色」永远不会触发——真实低电量时用户看到的仍是 85%，属于误导性 UI。

**修复建议**：接入 `battery_plus` 并通过 `ReaderViewport` 定时（或监听）把真实电量传入；若暂不接入，则移除百分比数字、只保留图标，或直接隐藏该区域。

> 同类问题：`reader_screen.dart:736` 换源面板里的延迟 `45 + (index * 13) % 120` 是**按下标算出来的假毫秒数**，副标题还固定写着「目录已核准 · 最新更新至当前章」「已连通 12 组稳定书源」。`MultiSourceService.pingAllSources()` / `NetworkClient.measureLatency()` 已经实现了真实测速，应直接接上。

---

### <a id="issue-12"></a>ISSUE-12 · P1 · 本地导入只存外部路径，源文件被清理后整本书报废

**位置**：[`local_book_service.dart:73-97`](../lib/features/local_books/services/local_book_service.dart#L73)

**根因**：导入时只把 `file.path` 写进 meta 和 `ShelfBook.filePath`，**没有把书籍文件拷贝进应用沙盒**。TXT 的分章索引记录的又是字节偏移，强依赖那个原始文件长期存在且字节不变。

**失效场景**：Android 上通过文件选择器选中的文件常常落在缓存目录或分享临时目录；系统清理缓存、用户清空下载目录、或重装后权限失效，书架上的书就永久变成「（本地源文件已不存在或已被移除）」，而书架条目、阅读进度、书签都还在。

**修复建议**：导入时把文件复制到 `local_books/raw/{bookId}.{ext}`，meta 记录沙盒内路径；原文件仅作为一次性来源。

---

### <a id="issue-13"></a>ISSUE-13 · P2 · 拼音规则服务未在启动时初始化，且规则表按段落重建

**位置**：[`pinyin_rule_service.dart:198-213`](../lib/features/sources/services/pinyin_rule_service.dart#L198) · [`pinyin_harmonizer.dart:133-138`](../lib/features/sources/services/pinyin_harmonizer.dart#L133)

**两个问题**：

1. **规则不生效**：`PinyinRuleService().init()` 全工程只在 `settings_page.dart:38` 的 `initState` 里调用过一次（且未 await）。冷启动后直奔书架读书的用户，`_initialized` 始终为 false，`allRules` 只会走 `_initFromDefaults()` 返回 38 条内置规则——**用户自定义规则和已缓存的云端规则全部不参与自愈**，直到本次运行中打开过一次设置页为止。应在 `main()` 里与 `StorageService.init()` 一起预热。

2. **性能**：`_initFromDefaults()` 只重建列表、**不置位 `_initialized`**，于是每次调用都重来一遍；而 `_activeRulesMap` 是个 getter，`restorePinyin` 每处理**一个段落**就重建一次完整规则表，阶段四再为其中约 140 条规则各编译一个 `RegExp`。一章 60 段 ≈ 8400 次正则构造，全部发生在 UI 线程的 `getChapterContent` 里。应把规则表与编译好的正则缓存起来，仅在规则变更时失效。

---

### <a id="issue-14"></a>ISSUE-14 · P2 · 换源回调内 `setState` 未判 `mounted`

**位置**：[`reader_screen.dart:863`](../lib/features/reader/presentation/reader_screen.dart#L863)

**根因**：换源的 `onTap` 里连续 `await searchBooks(5s)` 与 `await fetchToc(7s)` 之后直接 `setState(...)`，中间没有 `mounted` 判断（同方法后半段反而判了）。

**失效场景**：用户点了换源后在最长 12 秒的等待里返回书架 → `setState() called after dispose()` 异常。同类问题另见 `webdav_config_sheet.dart:95/104/134`。

**修复建议**：所有跨 `await` 的 `setState` 前统一加 `if (!mounted) return;`。

---

### <a id="issue-15"></a>ISSUE-15 · P2 · 滚动翻页模式下阅读进度完全不落盘

**位置**：[`reader_viewport.dart:882-928`](../lib/features/reader/presentation/reader_viewport.dart#L882)

**根因**：`_buildScrollView` 直接用 `ListView.builder` 渲染 `widget.paragraphs`，全程**不调用 `_notifyProgress()`**，`onProgressChanged` 自然不会触发。`_activeCharOffset` 停留在进入章节时的值。

**失效场景**：用户把翻页模式设为「滚动」，读到本章 80% 退出，再进来回到章首。另外底部进度滑块在非 slide 模式下（`reader_viewport.dart:1259-1262`）只改 `_currentPageIndex`、同样不上报进度。

**修复建议**：滚动模式下监听 `ScrollController.offset`，按可见首段映射回 `charOffset` 并节流上报；滑块的非 slide 分支补一次 `_notifyProgress()`。

---

## 三、其他观察（未计入缺陷清单）

| 位置 | 观察 |
| :--- | :--- |
| `version_check_service.dart:184` | `currentVersionCode = 2002` 是手写常量，需与 `pubspec.yaml`、`version_manifest.json` 三处手工同步。建议接 `package_info_plus` 在运行时读取，否则漏改一处就会出现「反复提示升级到自己正在运行的版本」。 |
| `version_check_service.dart:171-178` | `_dio` getter 在无自定义实例时**每次访问都 new 一个 Dio**，连接池完全失效。 |
| `storage_service.dart:432-447` | `isBookInShelf` 双向 `contains` 匹配，《剑来》在架时搜《剑来传》会被误判为「已在书架」。 |
| `reader_layout_engine.dart:16-34` | `measureChar` 按 UTF-16 code unit 处理，emoji 等代理对会被拆成两半，可能在行尾断出孤立代理字符。 |
| `page_painter.dart:266-273` | `shouldRepaint` 比较 `config`，但 `PagingConfig` 未重写 `==`，等价于每帧必重绘。 |
| `tts_sentence_splitter.dart:48` | 每断一句就 `content.substring(cursor)` 一次，整体 O(n²)，长章节在 UI 线程上有明显卡顿。 |
| `txt_parser_engine.dart:25-29` | UTF-16LE BOM（`FF FE`）被当作 UTF-8 处理，Windows 记事本「Unicode」编码的 TXT 导入即乱码。 |
| `download_service.dart:144-147` | 拿不到目录时生成 N 条空 URL 的假章节交给下载池，全部必然失败，只是空转计数。 |

---

## 四、建议的修复优先级

1. **立刻修**（影响正确性与安全）：ISSUE-01、ISSUE-05、ISSUE-02、ISSUE-03、ISSUE-04
2. **本迭代内修**（用户可感知的错误结果）：ISSUE-06、ISSUE-07、ISSUE-08、ISSUE-09、ISSUE-10、ISSUE-11、ISSUE-12
3. **排期修**：ISSUE-13、ISSUE-14、ISSUE-15 及第三节的观察项

**测试补强建议**：现有 162 个用例全绿却未能拦住上述任何一项，说明覆盖集中在「正向路径」。建议补充——
- `cleanAndFilterParagraphs` 的**正文保真**用例（断言正常段落不被删）；
- `PinyinHarmonizer` 的**恶意/非法规则**用例；
- `WifiTransferServer` 的**路径穿越**用例；
- 换源、TTS 续章、书签开关的**状态机**用例。
