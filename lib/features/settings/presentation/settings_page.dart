import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/components/ambient_mesh_background.dart';
import '../../../core/components/soft_card.dart';
import '../../../core/components/soft_switch.dart';
import '../../../core/theme/soft_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../local_books/presentation/wifi_transfer_dialog.dart';
import '../../../core/components/docked_bottom_bar.dart';
import '../../reader/data/storage_service.dart';
import '../../sync/presentation/webdav_config_sheet.dart';
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

  @override
  void initState() {
    super.initState();
    _loadSettings();
    PinyinRuleService().init();
  }

  Future<void> _loadSettings() async {
    final vPaging = await _storageService.getVolumeKeyPaging();
    final sAwake = await _storageService.getKeepScreenAwake();
    final cacheBytes = await _storageService.getTotalCacheSize();
    final themeStr = await _storageService.getGlobalTheme();

    if (mounted) {
      final isSys = themeStr == 'system';
      setState(() {
        _volumeKeyPaging = vPaging;
        _screenAwake = sAwake;
        _cacheSize = StorageService.formatBytes(cacheBytes);
        _followSystem = isSys;
      });
      try {
        ProviderScope.containerOf(context, listen: false)
            .read(isFollowingSystemProvider.notifier)
            .setFollow(isSys);
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
        child: ListView(
          physics: const BouncingScrollPhysics(),
          // 底栏是 Stack 上的浮层，这里必须按其实际高度预留内边距，
          // 否则最后一项会被压在底栏下方、文字与底栏图标重叠。
          padding: EdgeInsets.fromLTRB(
            20.0,
            16.0,
            20.0,
            DockedBottomBar.contentBottomPadding(context),
          ),
          children: [
            // 顶部标题 (原型 1:1)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '偏好与设置',
                  style: TextStyle(
                    fontSize: 24.0,
                    fontWeight: FontWeight.w900,
                    color: colors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 3.0),
                Text(
                  '个性化阅读体验与多端同步',
                  style: TextStyle(
                    fontSize: 12.0,
                    fontWeight: FontWeight.w500,
                    color: colors.textSecondary.withValues(alpha: 0.75),
                  ),
                ),
              ],
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
                      border: Border.all(color: colors.borderSubtle),
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
                          '藏书阁 阁友',
                          style: TextStyle(
                            fontSize: 16.0,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          '已累计心流阅读 38.5 小时 · 典藏 4 部珍本',
                          style: TextStyle(
                              fontSize: 12.0, color: colors.textSecondary),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('跟随系统深色模式',
                        style: TextStyle(
                            color: colors.textPrimary, fontSize: 14.0, fontWeight: FontWeight.w600)),
                    subtitle: Text('日夜交替自动温和切光',
                        style: TextStyle(
                            fontSize: 11.5, color: colors.textSecondary)),
                    trailing: SoftSwitch(
                      key: const ValueKey('switch_follow_system_theme'),
                      value: _followSystem,
                      colors: colors,
                      onChanged: (val) async {
                        setState(() {
                          _followSystem = val;
                        });
                        final platformBrightness =
                            MediaQuery.of(context).platformBrightness;
                        if (val) {
                          await _storageService.setGlobalTheme('system');
                        } else {
                          await _storageService.setGlobalTheme(
                              ThemeNotifier.paletteToString(colors.type));
                        }
                        if (!mounted) return;
                        try {
                          final container = ProviderScope.containerOf(
                              this.context,
                              listen: false);
                          container
                              .read(isFollowingSystemProvider.notifier)
                              .setFollow(val);
                          container
                              .read(themeProvider.notifier)
                              .setFollowSystem(val,
                                  currentBrightness: platformBrightness);
                        } catch (_) {}
                      },
                    ),
                  ),
                  Divider(height: 16.0, color: colors.borderSubtle),
                  Text(
                    '意境色彩雅集 · Modern Soft UI',
                    style: TextStyle(
                        fontSize: 12.0,
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12.0),
                  // 第一行：翠竹微雨 + 暖杏流光
                  Row(
                    children: [
                      _buildAestheticCard(
                        key: const ValueKey('theme_chip_mistyJade'),
                        aliasKey: const ValueKey('theme_chip_beanGreen'),
                        legacyKey: const ValueKey('theme_chip_paper'),
                        title: '翠竹微雨',
                        subtitle: '宋瓷天青 · 首选',
                        palette: SoftPaletteType.mistyJade,
                        accentColor: const Color(0xFF236B58),
                        bgPreview: const Color(0xFFF8FAF7),
                        isSelected: currentTheme == SoftPaletteType.mistyJade ||
                            currentTheme == SoftPaletteType.beanGreen ||
                            currentTheme == SoftPaletteType.paper,
                        colors: colors,
                      ),
                      const SizedBox(width: 10.0),
                      _buildAestheticCard(
                        key: const ValueKey('theme_chip_twilightAmber'),
                        aliasKey: const ValueKey('theme_chip_warmAmber'),
                        legacyKey: const ValueKey('theme_chip_parchment'),
                        title: '暖杏流光',
                        subtitle: '暖阳蜜蜡 · 温润',
                        palette: SoftPaletteType.warmAmber,
                        accentColor: const Color(0xFFB8621B),
                        bgPreview: const Color(0xFFFAF8F5),
                        isSelected: currentTheme == SoftPaletteType.warmAmber ||
                            currentTheme == SoftPaletteType.twilightAmber ||
                            currentTheme == SoftPaletteType.parchment,
                        colors: colors,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10.0),
                  // 第二行：霁月清辉 + 极夜星芒
                  Row(
                    children: [
                      _buildAestheticCard(
                        key: const ValueKey('theme_chip_moonSilver'),
                        aliasKey: const ValueKey('theme_chip_violetOrchid'),
                        title: '霁月清辉',
                        subtitle: '天光月华 · 澄澈',
                        palette: SoftPaletteType.moonSilver,
                        accentColor: const Color(0xFF3A6289),
                        bgPreview: const Color(0xFFF8F9FA),
                        isSelected: currentTheme == SoftPaletteType.moonSilver ||
                            currentTheme == SoftPaletteType.violetOrchid,
                        colors: colors,
                      ),
                      const SizedBox(width: 10.0),
                      _buildAestheticCard(
                        key: const ValueKey('theme_chip_auroraSpace'),
                        aliasKey: const ValueKey('theme_chip_darkJade'),
                        legacyKey: const ValueKey('theme_chip_night'),
                        title: '极夜星芒',
                        subtitle: '纯黑极光 · OLED',
                        palette: SoftPaletteType.darkJade,
                        accentColor: const Color(0xFF38D9A9),
                        bgPreview: const Color(0xFF0A0D10),
                        isSelected: currentTheme == SoftPaletteType.darkJade ||
                            currentTheme == SoftPaletteType.auroraSpace ||
                            currentTheme == SoftPaletteType.night,
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('物理音量键翻页',
                        style: TextStyle(color: colors.textPrimary)),
                    subtitle: Text('支持长篇阅读时免触屏快速下翻',
                        style: TextStyle(
                            fontSize: 12.0, color: colors.textSecondary)),
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
                  Divider(height: 1, color: colors.border),
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
                            fontSize: 12.0, color: colors.textSecondary),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
              child: Column(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => WebDavConfigSheet.show(context),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading:
                          const Text('☁️', style: TextStyle(fontSize: 20.0)),
                      title: Text('WebDAV 增量云备份',
                          style: TextStyle(color: colors.textPrimary)),
                      subtitle: Text('跨 iOS/Android/纯血鸿蒙同步阅读进度',
                          style: TextStyle(
                              fontSize: 12.0, color: colors.textSecondary)),
                      trailing: ElevatedButton(
                        key: const ValueKey('btn_webdav_sync'),
                        onPressed: _triggerWebDavSync,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12.0, vertical: 4.0),
                        ),
                        child: const Text('立即同步',
                            style: TextStyle(fontSize: 12.0)),
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
                      leading:
                          const Text('📶', style: TextStyle(fontSize: 20.0)),
                      title: Text('WiFi 局域网无线传书',
                          style: TextStyle(color: colors.textPrimary)),
                      subtitle: Text('电脑浏览器访问局域网 IP 直传 TXT/EPUB',
                          style: TextStyle(
                              fontSize: 12.0, color: colors.textSecondary)),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
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
                            fontSize: 11.5, color: colors.textSecondary)),
                    trailing: GestureDetector(
                      key: const ValueKey('btn_clear_cache'),
                      behavior: HitTestBehavior.opaque,
                      onTap: _clearCache,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14.0, vertical: 6.0),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius:
                              BorderRadius.circular(SoftDecorations.pillRadius),
                          border: Border.all(color: colors.borderSubtle),
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
                            fontSize: 11.5, color: colors.textSecondary),
                      ),
                      trailing: _isCheckingUpdate
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.0, color: colors.accent),
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

            const SizedBox(height: 100.0),
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
    final isDarkCard = palette == SoftPaletteType.auroraSpace ||
        palette == SoftPaletteType.night ||
        palette == SoftPaletteType.darkJade;

    // 意境卡片文字高对比度保证：深色卡片使用亮白文字，浅色宣纸卡片使用浓墨深色文字，根治深色模式下的“白底白字”
    final Color cardTitleColor =
        isDarkCard ? const Color(0xFFF0F4F2) : const Color(0xFF17211C);
    final Color cardSubtitleColor =
        isDarkCard ? const Color(0xFF8DA297) : const Color(0xFF586B62);

    Widget cardBody = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: isDarkCard ? const Color(0xFF141C18) : bgPreview,
        borderRadius:
            BorderRadius.circular(SoftDecorations.squircleSubCardRadius),
        border: Border.all(
          color: isSelected
              ? colors.accent
              : colors.border.withValues(alpha: 0.8),
          width: isSelected ? 2.0 : 1.0,
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
                    colors: [
                      accentColor,
                      accentColor.withValues(alpha: 0.7)
                    ],
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
                  child: const Icon(Icons.check, size: 12.0, color: Colors.white),
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
          setState(() => _followSystem = false);
          _storageService
              .setGlobalTheme(ThemeNotifier.paletteToString(palette));
          try {
            final container = ProviderScope.containerOf(context, listen: false);
            container.read(isFollowingSystemProvider.notifier).setFollow(false);
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
