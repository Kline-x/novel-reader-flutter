import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/components/soft_card.dart';
import '../../../core/components/soft_switch.dart';
import '../../../core/theme/soft_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../local_books/presentation/wifi_transfer_dialog.dart';
import '../../reader/data/storage_service.dart';
import '../../sync/presentation/webdav_config_sheet.dart';

/// 设置中心页面 (settings_page.dart)
/// Modern Soft UI 风格：外观与主题、个人看板、物理音量翻页、WebDAV 云同步、WiFi 传书、缓存清理
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final StorageService _storageService = StorageService();

  bool _volumeKeyPaging = true;
  bool _screenAwake = true;
  String _cacheSize = '0 B';
  bool _followSystem = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final vPaging = await _storageService.getVolumeKeyPaging();
    final sAwake = await _storageService.getKeepScreenAwake();
    final cacheBytes = await _storageService.getTotalCacheSize();
    final themeStr = await _storageService.getGlobalTheme();

    if (mounted) {
      setState(() {
        _volumeKeyPaging = vPaging;
        _screenAwake = sAwake;
        _cacheSize = StorageService.formatBytes(cacheBytes);
        _followSystem = themeStr == 'system';
      });
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

  void _clearCache() async {
    final colors = SoftTheme.of(context);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: colors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SoftDecorations.squircleCardRadius),
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
              child: const Text('确认清空', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
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
      body: SafeArea(
        bottom: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          children: [
            // 顶部标题
            Text(
              '个人与设置',
              style: TextStyle(
                fontSize: 26.0,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16.0),

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
                    ),
                    alignment: Alignment.center,
                    child: const Text('📖', style: TextStyle(fontSize: 24.0)),
                  ),
                  const SizedBox(width: 14.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '藏书阁 读者',
                          style: TextStyle(
                            fontSize: 16.0,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          '已累计阅读 38.5 小时 · 读完 3 本',
                          style: TextStyle(fontSize: 12.0, color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16.0),

            // 2. 外观与主题 (任务 5.5)
            _buildSectionHeader('外观与主题', colors),
            SoftCard(
              colors: colors,
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('跟随系统深色模式', style: TextStyle(color: colors.textPrimary, fontSize: 14.0)),
                    subtitle: Text('开启后将自动匹配系统深浅色切换', style: TextStyle(fontSize: 11.5, color: colors.textSecondary)),
                    trailing: SoftSwitch(
                      key: const ValueKey('switch_follow_system_theme'),
                      value: _followSystem,
                      colors: colors,
                      onChanged: (val) async {
                        setState(() {
                          _followSystem = val;
                        });
                        final platformBrightness = MediaQuery.of(context).platformBrightness;
                        if (val) {
                          await _storageService.setGlobalTheme('system');
                        } else {
                          await _storageService.setGlobalTheme(ThemeNotifier.paletteToString(colors.type));
                        }
                        if (!mounted) return;
                        try {
                          ProviderScope.containerOf(this.context, listen: false)
                              .read(themeProvider.notifier)
                              .setFollowSystem(val, currentBrightness: platformBrightness);
                        } catch (_) {}
                      },
                    ),
                  ),
                  Divider(height: 16.0, color: colors.border),
                  Text(
                    '主题配色风格',
                    style: TextStyle(fontSize: 12.0, color: colors.textSecondary, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10.0),
                  Row(
                    children: [
                      _buildThemeChip(
                        key: const ValueKey('theme_chip_paper'),
                        title: '纯白雅致',
                        palette: SoftPaletteType.paper,
                        previewBg: const Color(0xFFF7F7F7),
                        previewBorder: const Color(0xFFE0E0E0),
                        isSelected: !_followSystem && currentTheme == SoftPaletteType.paper,
                        colors: colors,
                      ),
                      const SizedBox(width: 8.0),
                      _buildThemeChip(
                        key: const ValueKey('theme_chip_parchment'),
                        title: '羊皮纸',
                        palette: SoftPaletteType.parchment,
                        previewBg: const Color(0xFFF5F4F1),
                        previewBorder: const Color(0xFFDCD8CF),
                        isSelected: !_followSystem && currentTheme == SoftPaletteType.parchment,
                        colors: colors,
                      ),
                      const SizedBox(width: 8.0),
                      _buildThemeChip(
                        key: const ValueKey('theme_chip_beanGreen'),
                        title: '水墨绿',
                        palette: SoftPaletteType.beanGreen,
                        previewBg: const Color(0xFFEDF4ED),
                        previewBorder: const Color(0xFFCDE0CD),
                        isSelected: !_followSystem && currentTheme == SoftPaletteType.beanGreen,
                        colors: colors,
                      ),
                      const SizedBox(width: 8.0),
                      _buildThemeChip(
                        key: const ValueKey('theme_chip_night'),
                        title: '极夜黑',
                        palette: SoftPaletteType.night,
                        previewBg: const Color(0xFF1F1F28),
                        previewBorder: const Color(0xFF38384A),
                        isSelected: !_followSystem && currentTheme == SoftPaletteType.night,
                        colors: colors,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16.0),

            // 3. 阅读体验控制
            _buildSectionHeader('阅读控制', colors),
            SoftCard(
              colors: colors,
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('物理音量键翻页', style: TextStyle(color: colors.textPrimary)),
                    subtitle: Text('支持长篇阅读时免触屏快速下翻', style: TextStyle(fontSize: 12.0, color: colors.textSecondary)),
                    trailing: SoftSwitch(
                      key: const ValueKey('switch_volume_paging'),
                      value: _volumeKeyPaging,
                      colors: colors,
                      onChanged: (val) async {
                        setState(() => _volumeKeyPaging = val);
                        await _storageService.setVolumeKeyPaging(val);
                      },
                    ),
                  ),
                  Divider(height: 1, color: colors.border),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('阅读时保持屏幕常亮', style: TextStyle(color: colors.textPrimary)),
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
                ],
              ),
            ),
            const SizedBox(height: 16.0),

            // 4. 数据与云同步 (WebDAV & WiFi)
            _buildSectionHeader('数据与多端同步', colors),
            SoftCard(
              colors: colors,
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
              child: Column(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => WebDavConfigSheet.show(context),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Text('☁️', style: TextStyle(fontSize: 20.0)),
                      title: Text('WebDAV 增量云备份', style: TextStyle(color: colors.textPrimary)),
                      subtitle: Text('跨 iOS/Android/纯血鸿蒙同步阅读进度', style: TextStyle(fontSize: 12.0, color: colors.textSecondary)),
                      trailing: ElevatedButton(
                        key: const ValueKey('btn_webdav_sync'),
                        onPressed: _triggerWebDavSync,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                        ),
                        child: const Text('立即同步', style: TextStyle(fontSize: 12.0)),
                      ),
                    ),
                  ),
                  Divider(height: 1, color: colors.border),
                  GestureDetector(
                    key: const ValueKey('settings_wifi_transfer_tile'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => WifiTransferDialog.show(context),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Text('📶', style: TextStyle(fontSize: 20.0)),
                      title: Text('WiFi 局域网无线传书', style: TextStyle(color: colors.textPrimary)),
                      subtitle: Text('电脑浏览器访问局域网 IP 直传 TXT/EPUB', style: TextStyle(fontSize: 12.0, color: colors.textSecondary)),
                      trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14.0, color: colors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16.0),

            // 5. 存储与系统
            _buildSectionHeader('存储管理与关于', colors),
            SoftCard(
              colors: colors,
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('离线正文缓存', style: TextStyle(color: colors.textPrimary)),
                    subtitle: Text(_cacheSize, style: TextStyle(fontSize: 12.0, color: colors.textSecondary)),
                    trailing: OutlinedButton(
                      key: const ValueKey('btn_clear_cache'),
                      onPressed: _clearCache,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: colors.accent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 2.0),
                      ),
                      child: Text('清理缓存', style: TextStyle(fontSize: 12.0, color: colors.accent)),
                    ),
                  ),
                  Divider(height: 1, color: colors.border),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('软件版本', style: TextStyle(color: colors.textPrimary)),
                    trailing: Text('v1.0.0+1 (iOS / Android / 纯血鸿蒙)', style: TextStyle(fontSize: 12.0, color: colors.textSecondary)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 100.0),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeChip({
    required Key key,
    required String title,
    required SoftPaletteType palette,
    required Color previewBg,
    required Color previewBorder,
    required bool isSelected,
    required SoftColors colors,
  }) {
    return Expanded(
      child: GestureDetector(
        key: key,
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() => _followSystem = false);
          _storageService.setGlobalTheme(ThemeNotifier.paletteToString(palette));
          try {
            ProviderScope.containerOf(context, listen: false)
                .read(themeProvider.notifier)
                .setPalette(palette);
          } catch (_) {}
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          decoration: BoxDecoration(
            color: previewBg,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(
              color: isSelected ? colors.accent : previewBorder,
              width: isSelected ? 2.0 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: colors.accent.withValues(alpha: 0.25),
                      blurRadius: 6.0,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: palette == SoftPaletteType.night ? Colors.white : const Color(0xFF14161B),
                ),
              ),
              if (isSelected) ...[
                const SizedBox(height: 2.0),
                Icon(Icons.check_circle_rounded, size: 12.0, color: colors.accent),
              ],
            ],
          ),
        ),
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
