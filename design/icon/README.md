# 应用图标源文件

矢量源在这里，改图标从这四份 SVG 出发，不要直接改各平台的 PNG。
四份文件的几何由同一段参数生成，改造型时四份一起改，不要单改其中一份。

| 文件 | 用途 |
|---|---|
| `app_icon.svg` | 完整图标。Android 五种 mipmap、iOS 全尺寸、鸿蒙单图都由它导出 |
| `app_icon_foreground.svg` | 鸿蒙分层图标的前景（透明底，内容已缩到安全区 0.86） |
| `app_icon_background.svg` | 分层图标的背景（纯渐变，满幅），鸿蒙与 Android 共用 |
| `app_icon_monochrome.svg` | Android 13+ 主题图标层：整座阁的实心剪影，系统按壁纸取色重新着色 |

## 设计说明

**飞檐叠阁**：三层屋面自下而上收窄，每层脊在正中最高、两侧顺下、到转角挑起；
最下面托着一函书，顶上一颗宝顶。阁是藏书阁，书是被藏的那部分——
名字里的两个意象就是图标本身。

不画「打开的书」「书脊」「书签」，那是阅读类应用最挤的三个符号。

配色沿用应用主题「极夜星芒」：主体是冰蓝渐变（`#CDF4FF` → `#7FDCFF`，
屋身压暗一档到 `#57C6F7` → `#2E9FDC` 让檐口浮起来），背景是深夜蓝
（`#14486A` → `#05151F`）。把冰蓝放在主体而不是背景上，
图标在浅色和深色壁纸上都立得住。

几处踩过的坑，改图标前先看一眼：

- **屋面要实心，不能画成一条带子**。底边跟着起伏的话整道檐会变成「胡须」，
  看不出是屋顶。
- **飞檐的起翘靠三次曲线**：中脊到转角必须**单调**下落，只在最外端挑起。
  二次曲线的单个控制点会在中间拉出两个低点，看着像蝠翼。
- **檐口不能太薄**。48px 下 1024 的画布缩了 21 倍，26px 的檐口只剩 1.2px，
  转角先糊掉。现在最薄一档是 36px。
- **描边/填充的渐变必须 `gradientUnits="userSpaceOnUse"`**。
  默认的 objectBoundingBox 会让三道檐各自从头渐变一遍，层次就散了。
- **屋身不能省**。只有三片屋面的话它们是飘着的，得有竖向的屋身把它们串成一座阁。

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
