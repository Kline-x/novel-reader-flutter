import 'package:flutter/material.dart';
import '../../../core/components/soft_card.dart';
import '../../../core/components/soft_switch.dart';
import '../../../core/theme/soft_theme.dart';
import '../../sync/presentation/webdav_config_sheet.dart';

/// 设置中心页面 (settings_page.dart)
/// Modern Soft UI 风格：个人看板、物理音量翻页、WebDAV 云同步、WiFi 传书、缓存清理
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _volumeKeyPaging = true;
  bool _screenAwake = true;
  String _cacheSize = '24.8 MB';

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
              onPressed: () {
                Navigator.of(ctx).pop();
                setState(() => _cacheSize = '0.0 KB');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('离线缓存已完全清空')),
                );
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

            // 2. 阅读体验控制
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
                      onChanged: (val) => setState(() => _volumeKeyPaging = val),
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
                      onChanged: (val) => setState(() => _screenAwake = val),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16.0),

            // 3. 数据与云同步 (WebDAV & WiFi)
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
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已启动本地服务：http://192.168.1.100:8080')),
                      );
                    },
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

            // 4. 存储与系统
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
