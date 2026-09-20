# 应用图标源文件

矢量源在这里，改图标从这三份 SVG 出发，不要直接改各平台的 PNG。

| 文件 | 用途 |
|---|---|
| `app_icon.svg` | 完整图标。Android 五种 mipmap、iOS 全尺寸、鸿蒙单图都由它导出 |
| `app_icon_foreground.svg` | 鸿蒙分层图标的前景（透明底，内容已缩到安全区 0.86） |
| `app_icon_background.svg` | 分层图标的背景（纯渐变，满幅），鸿蒙与 Android 共用 |
| `app_icon_monochrome.svg` | Android 13+ 主题图标层：书实心、门镂空、星保留，系统按壁纸取色重新着色 |

## 设计说明

书封上开一道拱门，门内是星空。书是门，门是阁，门后是故事——
不直接画楼阁，避开阅读类应用常见的「打开的书」「书脊」撞车。

配色取自应用主题「极夜星芒」：`#4CC2FF`（夜间 accent）与 `#2E6FA8`（日间 accent），
所以图标和 App 内的强调色是同一个色，不是「看起来像」。

## 导出

用 Chrome headless 渲染 SVG 再缩放，不要用位图放大：

```bash
chrome --headless --disable-gpu --screenshot=out.png \
  --window-size=1024,1024 --hide-scrollbars \
  --default-background-color=00000000 file:///绝对路径/app_icon.svg
```

各平台需要的尺寸：

- Android 传统位图 `mipmap-*/ic_launcher.png` = 48/72/96/144/192（Android 8 以下回退用）
- Android 自适应图标 `mipmap-*/ic_launcher_{foreground,background,monochrome}.png`
  = 108/162/216/324/432（画布 108dp，内容须落在中心 72dp 安全区内），
  配 `mipmap-anydpi-v26/ic_launcher.xml`
- iOS `AppIcon.appiconset/` 按 `Contents.json` 里列的 15 个尺寸
- 鸿蒙 `AppScope/resources/base/media/`：
  - `foreground.png` / `background.png` 各 1024，配 `layered_image.json`
  - `app_icon.png` 512（单图，留作兜底）
  - `entry/src/main/resources/base/media/icon.png` 512（Ability 图标与启动窗口）
