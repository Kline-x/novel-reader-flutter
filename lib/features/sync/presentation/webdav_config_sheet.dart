import 'package:flutter/material.dart';

import '../../../core/components/soft_card.dart';
import '../../../core/components/soft_switch.dart';
import '../../../core/theme/soft_theme.dart';
import '../models/webdav_config.dart';
import '../services/webdav_service.dart';

/// WebDAV 云同步配置与操作面板
class WebDavConfigSheet extends StatefulWidget {
  const WebDavConfigSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const WebDavConfigSheet(),
    );
  }

  @override
  State<WebDavConfigSheet> createState() => _WebDavConfigSheetState();
}

class _WebDavConfigSheetState extends State<WebDavConfigSheet> {
  final WebDavService _webDavService = WebDavService();

  late TextEditingController _urlController;
  late TextEditingController _userController;
  late TextEditingController _pwdController;
  late TextEditingController _pathController;
  bool _autoSync = false;
  DateTime? _lastSyncTime;

  bool _isTesting = false;
  String? _testResult;
  bool _isSyncing = false;
  String? _syncStatusMessage;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController();
    _userController = TextEditingController();
    _pwdController = TextEditingController();
    _pathController = TextEditingController();
    _loadConfig();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _userController.dispose();
    _pwdController.dispose();
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final cfg = await _webDavService.getConfig();
    if (mounted) {
      setState(() {
        _urlController.text = cfg.serverUrl;
        _userController.text = cfg.username;
        _pwdController.text = cfg.password;
        _pathController.text = cfg.remotePath;
        _autoSync = cfg.autoSync;
        _lastSyncTime = cfg.lastSyncTime;
      });
    }
  }

  WebDavConfig _buildCurrentConfig() {
    return WebDavConfig(
      serverUrl: _urlController.text.trim(),
      username: _userController.text.trim(),
      password: _pwdController.text.trim(),
      remotePath: _pathController.text.trim().isEmpty ? '/novel_reader' : _pathController.text.trim(),
      autoSync: _autoSync,
      lastSyncTime: _lastSyncTime,
    );
  }

  Future<void> _saveConfig() async {
    final cfg = _buildCurrentConfig();
    await _webDavService.saveConfig(cfg);
  }

  void _testConnection() async {
    await _saveConfig();
    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final success = await _webDavService.testConnection(
      testConfig: _buildCurrentConfig(),
    );

    if (mounted) {
      setState(() {
        _isTesting = false;
        _testResult = success ? '✓ WebDAV 连通正常' : '✕ 连接失败，请检查账号密码与网络';
      });
    }
  }

  void _triggerSync() async {
    await _saveConfig();
    setState(() {
      _isSyncing = true;
      _syncStatusMessage = '正在进行增量合并与多端漫游...';
    });

    final result = await _webDavService.sync();

    if (mounted) {
      setState(() {
        _isSyncing = false;
        _lastSyncTime = result.syncTime;
        _syncStatusMessage = result.success
            ? '同步成功：书架 ${result.syncedBooks} 本 · 书签 ${result.syncedBookmarks} 个 · 笔记 ${result.syncedAnnotations} 条'
            : '同步失败：${result.message}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = SoftTheme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28.0)),
        boxShadow: SoftDecorations.softShadows(colors, elevation: 4.0),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 拖动手柄
              Center(
                child: Container(
                  width: 36.0,
                  height: 4.0,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(2.0),
                  ),
                ),
              ),
              const SizedBox(height: 14.0),

              // 标题
              Row(
                children: [
                  const Text('☁️', style: TextStyle(fontSize: 22.0)),
                  const SizedBox(width: 8.0),
                  Text(
                    'WebDAV 增量云漫游',
                    style: TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: colors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Text(
                '支持坚果云、Nextcloud 等标准 WebDAV 服务，跨 iOS / Android / 纯血鸿蒙实现阅读进度与书签笔记双向增量同步。',
                style: TextStyle(fontSize: 12.0, color: colors.textSecondary),
              ),
              const SizedBox(height: 16.0),

              // 输入表单卡片
              SoftCard(
                colors: colors,
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  children: [
                    _buildTextField(
                      controller: _urlController,
                      label: '服务器地址',
                      hint: '如 https://dav.jianguoyun.com/dav/',
                      colors: colors,
                      key: const ValueKey('input_webdav_url'),
                    ),
                    const SizedBox(height: 10.0),
                    _buildTextField(
                      controller: _userController,
                      label: '账号 / 邮箱',
                      hint: '输入 WebDAV 账号',
                      colors: colors,
                      key: const ValueKey('input_webdav_user'),
                    ),
                    const SizedBox(height: 10.0),
                    _buildTextField(
                      controller: _pwdController,
                      label: '密码 / 应用授权码',
                      hint: '输入 WebDAV 应用专用密码',
                      obscureText: true,
                      colors: colors,
                      key: const ValueKey('input_webdav_pwd'),
                    ),
                    const SizedBox(height: 10.0),
                    _buildTextField(
                      controller: _pathController,
                      label: '云端目录',
                      hint: '默认 /novel_reader',
                      colors: colors,
                      key: const ValueKey('input_webdav_path'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12.0),

              // 自动同步开关与上次时间
              SoftCard(
                colors: colors,
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text('打开应用时自动同步', style: TextStyle(fontSize: 13.0, color: colors.textPrimary)),
                        const Spacer(),
                        SoftSwitch(
                          value: _autoSync,
                          colors: colors,
                          onChanged: (val) {
                            setState(() => _autoSync = val);
                            _saveConfig();
                          },
                        ),
                      ],
                    ),
                    if (_lastSyncTime != null) ...[
                      const Divider(height: 14.0),
                      Row(
                        children: [
                          Icon(Icons.history_rounded, size: 14.0, color: colors.textSecondary),
                          const SizedBox(width: 4.0),
                          Text(
                            '上次云端对齐：${_lastSyncTime.toString().split('.')[0]}',
                            style: TextStyle(fontSize: 11.0, color: colors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14.0),

              // 状态提示反馈
              if (_testResult != null) ...[
                Container(
                  padding: const EdgeInsets.all(10.0),
                  decoration: BoxDecoration(
                    color: _testResult!.startsWith('✓')
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _testResult!.startsWith('✓') ? Icons.check_circle : Icons.error,
                        size: 16.0,
                        color: _testResult!.startsWith('✓') ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 6.0),
                      Expanded(
                        child: Text(
                          _testResult!,
                          style: TextStyle(
                            fontSize: 12.0,
                            color: _testResult!.startsWith('✓') ? Colors.green : Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10.0),
              ],

              if (_syncStatusMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(10.0),
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.sync_rounded, size: 16.0, color: colors.accent),
                      const SizedBox(width: 6.0),
                      Expanded(
                        child: Text(
                          _syncStatusMessage!,
                          style: TextStyle(fontSize: 12.0, color: colors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12.0),
              ],

              // 按钮操作行
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('btn_test_webdav'),
                      onPressed: _isTesting ? null : _testConnection,
                      icon: _isTesting
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.network_check_rounded, size: 16),
                      label: Text(_isTesting ? '探测中...' : '测试连接'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.textPrimary,
                        side: BorderSide(color: colors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.0)),
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    flex: 1,
                    child: ElevatedButton.icon(
                      key: const ValueKey('btn_sync_now'),
                      onPressed: _isSyncing ? null : _triggerSync,
                      icon: _isSyncing
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.cloud_sync_rounded, size: 16),
                      label: Text(_isSyncing ? '同步中...' : '立即增量漫游'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.0)),
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required SoftColors colors,
    required Key key,
    bool obscureText = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11.0, color: colors.textSecondary, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4.0),
        TextField(
          key: key,
          controller: controller,
          obscureText: obscureText,
          style: TextStyle(fontSize: 13.0, color: colors.textPrimary),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: TextStyle(fontSize: 12.0, color: colors.textSecondary.withValues(alpha: 0.7)),
            filled: true,
            fillColor: colors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: BorderSide(color: colors.border),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          ),
        ),
      ],
    );
  }
}
