import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/components/soft_button.dart';
import '../../../core/components/soft_card.dart';
import '../../../core/theme/soft_theme.dart';
import '../services/wifi_transfer_server.dart';

/// Modern Soft UI 局域网 WiFi 传书弹窗 (wifi_transfer_dialog.dart)
class WifiTransferDialog extends StatefulWidget {
  const WifiTransferDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const WifiTransferDialog(),
    );
  }

  @override
  State<WifiTransferDialog> createState() => _WifiTransferDialogState();
}

class _WifiTransferDialogState extends State<WifiTransferDialog> {
  final WifiTransferServer _server = WifiTransferServer();
  StreamSubscription<WifiServerEvent>? _sub;
  bool _isRunning = false;
  String _serverUrl = '';
  final List<String> _receivedFiles = [];
  bool _isCopied = false;
  Timer? _copiedTimer;

  @override
  void initState() {
    super.initState();
    _isRunning = _server.status == WifiServerStatus.running;
    _serverUrl = _server.serverUrl;

    _sub = _server.eventStream.listen((event) {
      if (!mounted) return;
      setState(() {
        _isRunning = event.status == WifiServerStatus.running;
        _serverUrl = _server.serverUrl;
        if (event.uploadedFileName != null) {
          _receivedFiles.insert(0, event.uploadedFileName!);
        }
      });
    });

    // 默认自动启动服务
    if (!_isRunning) {
      _startServer();
    }
  }

  Future<void> _startServer() async {
    await _server.start();
    if (mounted) {
      setState(() {
        _isRunning = _server.status == WifiServerStatus.running;
        _serverUrl = _server.serverUrl;
      });
    }
  }

  Future<void> _toggleServer() async {
    if (_isRunning) {
      await _server.stop();
    } else {
      await _server.start();
    }
    if (mounted) {
      setState(() {
        _isRunning = _server.status == WifiServerStatus.running;
        _serverUrl = _server.serverUrl;
      });
    }
  }

  @override
  void dispose() {
    _copiedTimer?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = SoftTheme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28.0)),
        boxShadow: SoftDecorations.softShadows(colors, elevation: 1.5),
      ),
      padding: EdgeInsets.fromLTRB(
        24.0,
        16.0,
        24.0,
        MediaQuery.of(context).viewInsets.bottom + 32.0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部小胶囊手柄
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),

          // 标题与状态标识
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.wifi_tethering_rounded, color: colors.accent, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WiFi 局域网极速传书',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isRunning ? const Color(0xFF4CAF50) : colors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isRunning ? '服务运行中' : '服务已停止',
                          style: TextStyle(
                            fontSize: 12,
                            color: _isRunning ? const Color(0xFF388E3C) : colors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: colors.textSecondary),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 核心网址 Squircle 卡片
          SoftCard(
            colors: colors,
            radius: 20.0,
            padding: const EdgeInsets.all(18.0),
            child: Column(
              children: [
                Text(
                  '请在同一 Wi-Fi 下的电脑或手机浏览器打开：',
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                SelectableText(
                  _isRunning ? _serverUrl : 'http://... (请先启动服务)',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: _isRunning ? colors.accent : colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SoftButton(
                      colors: colors,
                      isActive: _isRunning,
                      onPressed: _isRunning
                          ? () {
                              Clipboard.setData(ClipboardData(text: _serverUrl));
                              _copiedTimer?.cancel();
                              setState(() => _isCopied = true);
                              _copiedTimer = Timer(const Duration(milliseconds: 1500), () {
                                if (mounted) {
                                  setState(() => _isCopied = false);
                                }
                              });
                            }
                          : null,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isCopied ? Icons.check_rounded : Icons.copy_rounded,
                            size: 14.0,
                            color: _isRunning ? Colors.white : colors.textSecondary,
                          ),
                          const SizedBox(width: 4.0),
                          Text(
                            _isCopied ? '✓ 已复制' : '复制网址',
                            style: TextStyle(
                              fontSize: 13.0,
                              fontWeight: FontWeight.w600,
                              color: _isRunning ? Colors.white : colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    SoftButton(
                      colors: colors,
                      isActive: false,
                      onPressed: _toggleServer,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded, size: 16.0, color: colors.textPrimary),
                          const SizedBox(width: 4.0),
                          Text(_isRunning ? '停止服务' : '启动服务', style: TextStyle(fontSize: 13.0, color: colors.textPrimary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 传书指南指引
          SoftCard(
            colors: colors,
            radius: 16.0,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 18, color: colors.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '支持 .txt 与 .epub 格式。TXT 文件将自动按章节正则智能切分，秒级入架。',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 接收记录
          if (_receivedFiles.isNotEmpty) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '本次已接收 (${_receivedFiles.length})',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: colors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 120),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _receivedFiles.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Color(0xFF4CAF50), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _receivedFiles[index],
                            style: TextStyle(fontSize: 13, color: colors.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '已入架',
                          style: TextStyle(fontSize: 11, color: colors.accent, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
