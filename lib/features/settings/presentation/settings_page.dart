import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/components/collapsing_header.dart';
import '../../../core/components/ambient_mesh_background.dart';
import '../../../core/components/soft_card.dart';
import '../../../core/components/soft_switch.dart';
import '../../../core/theme/soft_theme.dart';
import '../../../core/utils/platform_adaptive_helper.dart';
import '../../../core/theme/theme_provider.dart';
import '../../local_books/presentation/wifi_transfer_dialog.dart';
import '../../../core/components/docked_bottom_bar.dart';
import '../../reader/data/storage_service.dart';
import '../../sync/presentation/webdav_config_sheet.dart';
import '../services/backup_service.dart';
import '../services/version_check_service.dart';
import '../../sources/services/pinyin_rule_service.dart';
import 'pinyin_rules_sheet.dart';
import 'update_dialog.dart';

/// 设置中心页面 (settings_page.dart)
/// Modern Soft UI 风格：外观与主题、个人看板、物理音量翻页、WebDAV 云同步、WiFi 传书、缓存清理
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final StorageService _storageService = StorageService();
  final VersionCheckService _versionService = VersionCheckService();

  bool _volumeKeyPaging = true;
  bool _screenAwake = true;
  String _cacheSize = '0 B';
  bool _followSystem = false;
  bool _isCheckingUpdate = false;
  final ScrollController _scrollController = ScrollController();
  int _totalReadingMinutes = 0;
  int _shelfBookCount = 0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    PinyinRuleService().init();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 设置项很长，滚到底再想回顶要连划好几下。收拢后的标题条兼作回顶按钮。
  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0.0,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  /// 阅读概览文案。没读过书时不编数字，直接给引导。
  String _buildReadingSummary() {
    final parts = <String>[];
    if (_totalReadingMinutes >= 60) {
      final hours = (_totalReadingMinutes / 60).toStringAsFixed(1);
      parts.add('已累计心流阅读 $hours 小时');
    } else if (_totalReadingMinutes > 0) {
      parts.add('已累计心流阅读 $_totalReadingMinutes 分钟');
    }
    if (_shelfBookCount > 0) {
      parts.add('典藏 $_shelfBookCount 部珍本');
    }
    return parts.isEmpty ? '还没有开始阅读，去挑一本好书吧' : parts.join(' · ');
  }

  /// 音量键翻页是否可用。按平台能力判断，不按平台名。
  ///
  /// 只有 Android 有拦截实现（MainActivity 覆写 onKeyDown）。
  /// 鸿蒙上 defaultTargetPlatform 同样报 android，所以必须再用宿主
  /// 自报的 isHarmonyOS 排除——那是 getPackageInfo 带回来的，比
  /// 环境变量嗅探可靠。iOS 本就不分发音量键给应用。
  bool get _canUseVolumeKeyPaging =>
      PlatformAdaptiveHelper.instance.supportsVolumeKeyPaging &&
      !VersionCheckService.isHarmonyOS;

  Future<void> _loadSettings() async {
    final vPaging = await _storageService.getVolumeKeyPaging();
    final sAwake = await _storageService.getKeepScreenAwake();
    final cacheBytes = await _storageService.getTotalCacheSize();
    final themeStr = await _storageService.getGlobalTheme();
    final totalMinutes = await _storageService.getTotalReadingMinutes();
    final shelfCount = (await _storageService.getBookshelf()).length;

    if (mounted) {
      final isSys = themeStr == 'system';
      setState(() {
        _volumeKeyPaging = vPaging;
        _screenAwake = sAwake;
        _cacheSize = StorageService.formatBytes(cacheBytes);
        _followSystem = isSys;
        _totalReadingMinutes = totalMinutes;
        _shelfBookCount = shelfCount;
      });
      try {
        ProviderScope.containerOf(context, listen: false)
            .read(themeModeProvider.notifier)
            .setFollowSystem(isSys);
      } catch (_) {}
    }
  }

  Future<void> _refreshCacheSize() async {
    final cacheBytes = await _storageService.getTotalCacheSize();
    if (mounted) {
      setState(() {
        _cacheSize = StorageService.formatBytes(cacheBytes);
      });
    }
  }

  void _triggerWebDavSync() async {
    WebDavConfigSheet.show(context);
  }

  /// 宿主文件通道：选文件（导入）与存文件（导出）。三端都有实现，
  /// 详见 test/platform_parity_test.dart 的对等门禁。
  static const MethodChannel _fileChannel =
      MethodChannel('com.kline.novelreader/file_picker');

  final BackupService _backupService = BackupService();

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// 导出备份：打包 → 落到临时文件 → 交给系统保存选择器由用户决定存哪儿
  Future<void> _exportBackup() async {
    _toast('正在打包备份...');
    try {
      final bytes = await _backupService.exportToBytes();
      final fileName = BackupService.suggestedFileName();
      final tmp = await getTemporaryDirectory();
      final staged = File('${tmp.path}/$fileName');
      await staged.writeAsBytes(bytes);

      final sizeText = '${(bytes.length / 1024 / 1024).toStringAsFixed(1)} MB';
      try {
        final saved = await _fileChannel.invokeMethod<String>('saveFile', {
          'fileName': fileName,
          'sourcePath': staged.path,
        });
        if (saved == null) return; // 用户取消，不打扰
        _toast('备份已导出（$sizeText，不含 WebDAV 密码）');
      } on MissingPluginException {
        // 通道缺失时不能让用户白等一场，至少告诉他文件在哪
        _toast('已生成备份（$sizeText），存于应用目录：${staged.path}');
      }
    } catch (e) {
      _toast('导出失败：$e');
    }
  }

  /// 导入备份：选 zip → 读概要让用户确认 → 恢复
  Future<void> _importBackup() async {
    String? picked;
    try {
      picked = await _fileChannel.invokeMethod<String>('pickBookFile', {
        'extensions': ['zip'],
      });
    } on MissingPluginException {
      _toast('当前平台暂不支持选择文件');
      return;
    } catch (e) {
      _toast('打开文件选择器失败：$e');
      return;
    }
    if (picked == null || picked.isEmpty) return; // 用户取消

    final bytes = await File(picked).readAsBytes();
    final summary = BackupService.peek(bytes);
    if (summary == null) {
      _toast('这不是一份有效的藏书阁备份');
      return;
    }
    if (!mounted) return;

    // 恢复会覆盖现有书架与进度，属于不可撤销操作，必须先让用户确认
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导入这份备份？'),
        content: Text(
          '${summary.display}\n\n'
          '导入后当前的书架、阅读进度与偏好会被备份里的内容覆盖，且无法撤销。',
        ),
        actions: [
          TextButton(
            key: const ValueKey('btn_cancel_import_backup'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            key: const ValueKey('btn_confirm_import_backup'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确认导入'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final result = await _backupService.importFromBytes(bytes);
    if (!result.ok) {
      _toast('导入失败：${result.error}');
      return;
    }
    // WebDAV 密码没有进备份，恢复后要手动补，不提醒的话用户只会看到同步一直失败
    _toast('已恢复 ${result.restoredKeys} 项设置与 ${result.restoredFiles} 个文件，'
        '请重启应用生效；WebDAV 密码需重新填写');
  }

  Future<void> _checkAppUpdate() async {
    if (_isCheckingUpdate) return;
    setState(() => _isCheckingUpdate = true);

    try {
      final latest = await _versionService.checkLatestVersion();
      if (!mounted) return;
      if (latest != null) {
        UpdateDialog.show(context, latest);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '当前已是最新版本 (v${_versionService.currentVersionName})，尽享极速纯净体验'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('检查更新失败，请检查网络设置')),
      );
    } finally {
      if (mounted) {
        setState(() => _isCheckingUpdate = false);
      }
    }
  }

  void _clearCache() async {
    final colors = SoftTheme.of(context);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: colors.card,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(SoftDecorations.squircleCardRadius),
          ),
          title: Text(
            '清空离线缓存',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
          content: Text(
            '当前缓存正文文本大小为 $_cacheSize，清空后可随时按需重新拉取，确认清空吗？',
            style: TextStyle(color: colors.textSecondary),
          ),
          actions: [
            TextButton(
              key: const ValueKey('btn_cancel_clear_cache'),
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('取消', style: TextStyle(color: colors.textSecondary)),
            ),
            TextButton(
              key: const ValueKey('btn_confirm_clear_cache'),
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _storageService.clearAllCache();
                await _refreshCacheSize();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('离线缓存已完全清空')),
                  );
                }
              },
              child: const Text('确认清空',
                  style: TextStyle(
                      color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = SoftTheme.of(context);
    final currentTheme = colors.type;

    return Scaffold(
      backgroundColor: colors.background,
      body: AmbientMeshBackground(
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              // 折叠标题：静止时是大标题，一滚就收成贴顶的小标题条。
              // 设置是线性清单，没有搜索/排序这类要随时够得着的控件，
              // 所以不像书架页那样钉住一整块；但标题整个滑走会让人
              // 失去「我在哪一页」的锚点，两大平台的惯例都是收拢而非消失。
              CollapsingHeader.sliver(
                colors: colors,
                title: '偏好与设置',
                subtitle: '个性化阅读体验与多端同步',
                onTapCollapsed: _scrollToTop,
              ),
              SliverPadding(
                // 底栏是 Stack 上的浮层，这里必须按其实际高度预留内边距，
                // 否则最后一项会被压在底栏下方、文字与底栏图标重叠。
                padding: EdgeInsets.fromLTRB(
                  20.0,
                  8.0,
                  20.0,
                  DockedBottomBar.contentBottomPadding(context),
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // 1. 用户/设备 Bento 看板
                    SoftCard(
                      colors: colors,
                      padding: const EdgeInsets.all(18.0),
                      child: Row(
                        children: [
                          Container(
                            width: 52.0,
                            height: 52.0,
                            decoration: BoxDecoration(
                              color: colors.surface,
                              shape: BoxShape.circle,
                              border: Border.all(color: colors.borderSubtle),
                            ),
                            alignment: Alignment.center,
                            child: const Text('📖',
                                style: TextStyle(fontSize: 24.0)),
                          ),
                          const SizedBox(width: 14.0),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '藏书阁 阁友',
                                  style: TextStyle(
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.bold,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4.0),
                                // 这里原先写死「已累计心流阅读 38.5 小时 · 典藏 4 部珍本」，
                                // 全新安装、书架为空时也照样显示，是纯假数据。
                                // 现在读真实的累计阅读时长与书架数量。
                                Text(
                                  _buildReadingSummary(),
                                  style: TextStyle(
                                      fontSize: 12.0,
                                      color: colors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16.0),

                    // 2. 外观与意境主题 (原型 1:1)
                    _buildSectionHeader('视觉与意境主题', colors),
                    SoftCard(
                      colors: colors,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('跟随系统深色模式',
                                style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 14.0,
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text('日夜交替自动温和切光',
                                style: TextStyle(
                                    fontSize: 11.5,
                                    color: colors.textSecondary)),
                            trailing: SoftSwitch(
                              key: const ValueKey('switch_follow_system_theme'),
                              value: _followSystem,
                              colors: colors,
                              onChanged: (val) async {
                                setState(() {
                                  _followSystem = val;
                                });
                                try {
                                  final container = ProviderScope.containerOf(
                                      this.context,
                                      listen: false);
                                  await container
                                      .read(themeModeProvider.notifier)
                                      .setFollowSystem(val);
                                } catch (_) {}
                              },
                            ),
                          ),
                          if (!_followSystem) ...[
                            Divider(
                                height: 1.0,
                                thickness: 0.5,
                                color: colors.borderSubtle),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text('当前显示模式',
                                  style: TextStyle(
                                      color: colors.textPrimary,
                                      fontSize: 14.0,
                                      fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                  colors.isDark ? '已切换为夜间模式' : '已切换为日间模式',
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      color: colors.textSecondary)),
                              trailing: GestureDetector(
                                key: const ValueKey(
                                    'btn_toggle_light_dark_manual'),
                                onTap: () async {
                                  try {
                                    final container = ProviderScope.containerOf(
                                        this.context,
                                        listen: false);
                                    await container
                                        .read(themeModeProvider.notifier)
                                        .toggleLightDark();
                                  } catch (_) {}
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12.0, vertical: 6.0),
                                  decoration: BoxDecoration(
                                    color:
                                        colors.accent.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10.0),
                                    border: Border.all(
                                      color:
                                          colors.accent.withValues(alpha: 0.3),
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        colors.isDark
                                            ? Icons.dark_mode_rounded
                                            : Icons.light_mode_rounded,
                                        size: 15.0,
                                        color: colors.accent,
                                      ),
                                      const SizedBox(width: 4.0),
                                      Text(
                                        colors.isDark ? '暗夜深色' : '清爽浅色',
                                        style: TextStyle(
                                          fontSize: 12.0,
                                          fontWeight: FontWeight.bold,
                                          color: colors.accent,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                          Divider(
                              height: 16.0,
                              thickness: 0.5,
                              color: colors.borderSubtle),
                          Text(
                            '意境色彩雅集 · Modern Soft UI',
                            style: TextStyle(
                                fontSize: 12.0,
                                color: colors.textSecondary,
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 12.0),
                          // 第一行：极夜星芒（默认）+ 暖杏流光
                          Row(
                            children: [
                              _buildAestheticCard(
                                key: const ValueKey('theme_chip_auroraSpace'),
                                aliasKey: const ValueKey('theme_chip_darkJade'),
                                legacyKey: const ValueKey('theme_chip_night'),
                                title: '极夜星芒',
                                subtitle:
                                    colors.isDark ? '冰蓝深空 · 首选' : '钛金冰川 · 首选',
                                palette: SoftPaletteType.darkJade,
                                accentColor: colors.isDark
                                    ? const Color(0xFF4CC2FF)
                                    : const Color(0xFF2E6FA8),
                                bgPreview: colors.isDark
                                    ? const Color(0xFF12161A)
                                    : const Color(0xFFF5F7FA),
                                isSelected:
                                    currentTheme == SoftPaletteType.darkJade ||
                                        currentTheme ==
                                            SoftPaletteType.auroraSpace ||
                                        currentTheme == SoftPaletteType.night,
                                colors: colors,
                              ),
                              const SizedBox(width: 10.0),
                              _buildAestheticCard(
                                key: const ValueKey('theme_chip_twilightAmber'),
                                aliasKey:
                                    const ValueKey('theme_chip_warmAmber'),
                                legacyKey:
                                    const ValueKey('theme_chip_parchment'),
                                title: '暖杏流光',
                                subtitle: '暖阳蜜蜡 · 温润',
                                palette: SoftPaletteType.warmAmber,
                                accentColor: const Color(0xFFB86820),
                                bgPreview: colors.isDark
                                    ? const Color(0xFF171310)
                                    : const Color(0xFFFAF7F2),
                                isSelected: currentTheme ==
                                        SoftPaletteType.warmAmber ||
                                    currentTheme ==
                                        SoftPaletteType.twilightAmber ||
                                    currentTheme == SoftPaletteType.parchment,
                                colors: colors,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10.0),
                          // 第二行：霁月清辉 + 翠竹微雨
                          Row(
                            children: [
                              _buildAestheticCard(
                                key: const ValueKey('theme_chip_moonSilver'),
                                aliasKey:
                                    const ValueKey('theme_chip_violetOrchid'),
                                title: '霁月清辉',
                                subtitle: '天光月华 · 澄澈',
                                palette: SoftPaletteType.moonSilver,
                                accentColor: const Color(0xFF6D599A),
                                bgPreview: colors.isDark
                                    ? const Color(0xFF15121F)
                                    : const Color(0xFFF9F8FC),
                                isSelected: currentTheme ==
                                        SoftPaletteType.moonSilver ||
                                    currentTheme ==
                                        SoftPaletteType.violetOrchid,
                                colors: colors,
                              ),
                              const SizedBox(width: 10.0),
                              _buildAestheticCard(
                                key: const ValueKey('theme_chip_mistyJade'),
                                aliasKey:
                                    const ValueKey('theme_chip_beanGreen'),
                                legacyKey: const ValueKey('theme_chip_paper'),
                                title: '翠竹微雨',
                                subtitle: '宋瓷天青 · 空蒙',
                                palette: SoftPaletteType.mistyJade,
                                accentColor: const Color(0xFF236B58),
                                bgPreview: colors.isDark
                                    ? const Color(0xFF111814)
                                    : const Color(0xFFF8FAF7),
                                isSelected: currentTheme ==
                                        SoftPaletteType.mistyJade ||
                                    currentTheme == SoftPaletteType.beanGreen ||
                                    currentTheme == SoftPaletteType.paper,
                                colors: colors,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16.0),

                    // 3. 阅读体验与自愈控制
                    _buildSectionHeader('阅读与偏好设置', colors),
                    SoftCard(
                      colors: colors,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 6.0),
                      child: Column(
                        children: [
                          // 只有 Android 能把音量键交给应用：iOS 不分发给普通应用，
                          // 鸿蒙由系统 sceneboard 独占（实测注入音量键只弹系统音量条）。
                          // 不支持的平台直接禁用并说明原因，不给「已启用」的错觉。
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            enabled: _canUseVolumeKeyPaging,
                            title: Text('物理音量键翻页',
                                style: TextStyle(
                                  color: _canUseVolumeKeyPaging
                                      ? colors.textPrimary
                                      : colors.textSecondary,
                                )),
                            subtitle: Text(
                                _canUseVolumeKeyPaging
                                    ? '支持长篇阅读时免触屏快速下翻'
                                    : '当前系统独占音量键，应用无法接管',
                                style: TextStyle(
                                    fontSize: 12.0,
                                    color: colors.textSecondary)),
                            trailing: SoftSwitch(
                              key: const ValueKey('switch_volume_paging'),
                              value: _volumeKeyPaging && _canUseVolumeKeyPaging,
                              colors: colors,
                              onChanged: !_canUseVolumeKeyPaging
                                  ? null
                                  : (val) async {
                                      setState(() => _volumeKeyPaging = val);
                                      await _storageService
                                          .setVolumeKeyPaging(val);
                                    },
                            ),
                          ),
                          Divider(
                              height: 1.0,
                              thickness: 0.5,
                              color: colors.borderSubtle),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('阅读时保持屏幕常亮',
                                style: TextStyle(color: colors.textPrimary)),
                            trailing: SoftSwitch(
                              key: const ValueKey('switch_screen_awake'),
                              value: _screenAwake,
                              colors: colors,
                              onChanged: (val) async {
                                setState(() => _screenAwake = val);
                                await _storageService.setKeepScreenAwake(val);
                              },
                            ),
                          ),
                          Divider(
                              height: 1.0,
                              thickness: 0.5,
                              color: colors.borderSubtle),
                          GestureDetector(
                            key: const ValueKey('settings_pinyin_rules_tile'),
                            behavior: HitTestBehavior.opaque,
                            onTap: () => PinyinRulesSheet.show(context),
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Container(
                                padding: const EdgeInsets.all(6.0),
                                decoration: BoxDecoration(
                                  color: colors.accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                child: Icon(Icons.spellcheck_rounded,
                                    color: colors.accent, size: 20.0),
                              ),
                              title: Text('智能拼音自愈与净化',
                                  style: TextStyle(color: colors.textPrimary)),
                              subtitle: Text(
                                '自愈第三方书源中的拼音谐音 · 支持云端热更新与自定义',
                                style: TextStyle(
                                    fontSize: 12.0,
                                    color: colors.textSecondary),
                              ),
                              trailing: Icon(Icons.arrow_forward_ios_rounded,
                                  size: 14.0, color: colors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16.0),

                    // 4. 数据与云同步 (WebDAV & WiFi)
                    _buildSectionHeader('数据与多端同步', colors),
                    SoftCard(
                      colors: colors,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 6.0),
                      child: Column(
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => WebDavConfigSheet.show(context),
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Text('☁️',
                                  style: TextStyle(fontSize: 20.0)),
                              title: Text('WebDAV 增量云备份',
                                  style: TextStyle(color: colors.textPrimary)),
                              subtitle: Text('跨 iOS/Android 设备同步阅读进度',
                                  style: TextStyle(
                                      fontSize: 12.0,
                                      color: colors.textSecondary)),
                              trailing: ElevatedButton(
                                key: const ValueKey('btn_webdav_sync'),
                                onPressed: _triggerWebDavSync,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colors.accent,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12.0)),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12.0, vertical: 4.0),
                                ),
                                child: const Text('立即同步',
                                    style: TextStyle(fontSize: 12.0)),
                              ),
                            ),
                          ),
                          Divider(
                              height: 1.0,
                              thickness: 0.5,
                              color: colors.borderSubtle),
                          GestureDetector(
                            key: const ValueKey('settings_export_backup_tile'),
                            behavior: HitTestBehavior.opaque,
                            onTap: _exportBackup,
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Text('📦',
                                  style: TextStyle(fontSize: 20.0)),
                              title: Text('导出备份',
                                  style: TextStyle(color: colors.textPrimary)),
                              subtitle: Text('书架、进度、批注与本地书打包成一个文件（不含密码）',
                                  style: TextStyle(
                                      fontSize: 12.0,
                                      color: colors.textSecondary)),
                              trailing: Icon(Icons.arrow_forward_ios_rounded,
                                  size: 14.0, color: colors.textSecondary),
                            ),
                          ),
                          Divider(
                              height: 1.0,
                              thickness: 0.5,
                              color: colors.borderSubtle),
                          GestureDetector(
                            key: const ValueKey('settings_import_backup_tile'),
                            behavior: HitTestBehavior.opaque,
                            onTap: _importBackup,
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Text('📥',
                                  style: TextStyle(fontSize: 20.0)),
                              title: Text('导入备份',
                                  style: TextStyle(color: colors.textPrimary)),
                              subtitle: Text('从备份文件恢复，会覆盖当前数据',
                                  style: TextStyle(
                                      fontSize: 12.0,
                                      color: colors.textSecondary)),
                              trailing: Icon(Icons.arrow_forward_ios_rounded,
                                  size: 14.0, color: colors.textSecondary),
                            ),
                          ),
                          Divider(
                              height: 1.0,
                              thickness: 0.5,
                              color: colors.borderSubtle),
                          GestureDetector(
                            key: const ValueKey('settings_wifi_transfer_tile'),
                            behavior: HitTestBehavior.opaque,
                            onTap: () => WifiTransferDialog.show(context),
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Text('📶',
                                  style: TextStyle(fontSize: 20.0)),
                              title: Text('WiFi 局域网无线传书',
                                  style: TextStyle(color: colors.textPrimary)),
                              subtitle: Text('电脑浏览器访问局域网 IP 直传 TXT/EPUB',
                                  style: TextStyle(
                                      fontSize: 12.0,
                                      color: colors.textSecondary)),
                              trailing: Icon(Icons.arrow_forward_ios_rounded,
                                  size: 14.0, color: colors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16.0),

                    // 5. 存储与版本 (原型 1:1)
                    _buildSectionHeader('存储与版本', colors),
                    SoftCard(
                      colors: colors,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 6.0),
                      child: Column(
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('离线章节缓存',
                                style: TextStyle(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.5)),
                            subtitle: Text('已缓存 $_cacheSize',
                                style: TextStyle(
                                    fontSize: 11.5,
                                    color: colors.textSecondary)),
                            trailing: GestureDetector(
                              key: const ValueKey('btn_clear_cache'),
                              behavior: HitTestBehavior.opaque,
                              onTap: _clearCache,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14.0, vertical: 6.0),
                                decoration: BoxDecoration(
                                  color: colors.surface,
                                  borderRadius: BorderRadius.circular(
                                      SoftDecorations.pillRadius),
                                  border:
                                      Border.all(color: colors.borderSubtle),
                                ),
                                child: Text(
                                  '清理',
                                  style: TextStyle(
                                    fontSize: 12.0,
                                    fontWeight: FontWeight.bold,
                                    color: colors.accent,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Divider(height: 1, color: colors.borderSubtle),
                          Material(
                            color: Colors.transparent,
                            child: ListTile(
                              key: const ValueKey('settings_check_update_tile'),
                              contentPadding: EdgeInsets.zero,
                              onTap: _isCheckingUpdate ? null : _checkAppUpdate,
                              title: Text('藏书阁版本',
                                  style: TextStyle(
                                      color: colors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13.5)),
                              subtitle: Text(
                                '当前 v${_versionService.currentVersionName} (旗舰引擎)',
                                style: TextStyle(
                                    fontSize: 11.5,
                                    color: colors.textSecondary),
                              ),
                              trailing: _isCheckingUpdate
                                  ? SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2.0,
                                          color: colors.accent),
                                    )
                                  : GestureDetector(
                                      key: const ValueKey('btn_check_version'),
                                      behavior: HitTestBehavior.opaque,
                                      onTap: _checkAppUpdate,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 13.0, vertical: 6.5),
                                        decoration: BoxDecoration(
                                          color: colors.accent,
                                          borderRadius: BorderRadius.circular(
                                              SoftDecorations.pillRadius),
                                          boxShadow: [
                                            BoxShadow(
                                              color: colors.accentGlow,
                                              blurRadius: 8.0,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: const Text(
                                          '检查更新',
                                          style: TextStyle(
                                            fontSize: 12.0,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAestheticCard({
    required Key key,
    Key? aliasKey,
    Key? legacyKey,
    required String title,
    required String subtitle,
    required SoftPaletteType palette,
    required Color accentColor,
    required Color bgPreview,
    required bool isSelected,
    required SoftColors colors,
  }) {
    // 意境卡片文字高对比度保证：跟随当前全局明暗模式，深色下使用亮白文字，浅色下使用浓墨深字
    final bool isDarkCard = colors.isDark;
    final Color cardTitleColor =
        isDarkCard ? const Color(0xFFF5F5F7) : const Color(0xFF111827);
    final Color cardSubtitleColor =
        isDarkCard ? const Color(0xFFA1A1A6) : const Color(0xFF6E6E73);

    Widget cardBody = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: bgPreview,
        borderRadius:
            BorderRadius.circular(SoftDecorations.squircleSubCardRadius),
        border: Border.all(
          color: isSelected
              ? colors.accent
              : (colors.isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05)),
          width: isSelected ? 1.5 : 0.5,
        ),
        boxShadow: isSelected
            ? SoftDecorations.glowShadows(colors.accent)
            : SoftDecorations.softShadows(colors, elevation: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 24.0,
                height: 24.0,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [accentColor, accentColor.withValues(alpha: 0.7)],
                  ),
                  borderRadius: BorderRadius.circular(7.0),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.35),
                      blurRadius: 4.0,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  title.substring(0, 1),
                  style: const TextStyle(
                    fontSize: 12.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              if (isSelected)
                Container(
                  width: 18.0,
                  height: 18.0,
                  decoration: BoxDecoration(
                    color: colors.accent,
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Icons.check, size: 12.0, color: Colors.white),
                ),
            ],
          ),
          const SizedBox(height: 10.0),
          Text(
            title,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: cardTitleColor,
            ),
          ),
          const SizedBox(height: 2.0),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11.0,
              color: cardSubtitleColor,
            ),
          ),
        ],
      ),
    );

    if (legacyKey != null) {
      cardBody = KeyedSubtree(key: legacyKey, child: cardBody);
    }
    if (aliasKey != null) {
      cardBody = KeyedSubtree(key: aliasKey, child: cardBody);
    }

    return Expanded(
      child: GestureDetector(
        key: key,
        behavior: HitTestBehavior.opaque,
        onTap: () {
          try {
            final container = ProviderScope.containerOf(context, listen: false);
            container.read(themeProvider.notifier).setPalette(palette);
          } catch (_) {}
        },
        child: cardBody,
      ),
    );
  }

  Widget _buildSectionHeader(String title, SoftColors colors) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13.0,
          fontWeight: FontWeight.w600,
          color: colors.textSecondary,
        ),
      ),
    );
  }
}
