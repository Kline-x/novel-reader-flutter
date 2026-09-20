import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/components/soft_button.dart';
import '../../../core/theme/soft_theme.dart';
import '../services/version_check_service.dart';

/// Modern Soft UI 极具科技感与温度的跨端新版本更新弹窗
class UpdateDialog extends StatefulWidget {
  final AppVersionInfo info;

  const UpdateDialog({
    super.key,
    required this.info,
  });

  /// 便捷展示更新弹窗
  static Future<void> show(BuildContext context, AppVersionInfo info) {
    return showDialog<void>(
      context: context,
      barrierDismissible: !info.isForceUpdate,
      builder: (_) => UpdateDialog(info: info),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  final VersionCheckService _versionService = VersionCheckService();

  CancelToken? _cancelToken;
  bool _isProcessing = false;
  bool _isInstalledInvoked = false;
  double _progress = 0.0;
  String _statusText = '准备中...';
  bool _hasError = false;

  /// 用户点了「后台下载」：弹窗关掉，但下载要继续跑完。
  bool _movedToBackground = false;

  @override
  void dispose() {
    // 只有「用户主动取消」或「弹窗被意外销毁」才取消下载。
    // 以前这里无条件 cancel，而「后台下载」按钮就是 pop() 一下，
    // 于是点「后台下载」等于直接把下载掐了——按钮名字和行为完全相反。
    if (!_movedToBackground) {
      _cancelToken?.cancel('弹窗销毁');
    }
    super.dispose();
  }

  /// 转入后台：保留 cancelToken 让下载跑完。
  /// 下载完成后由 VersionCheckService 自己调 installApk 唤起系统安装器，
  /// 不依赖这个弹窗还活着；onProgress 里也都有 mounted 判断，销毁后不会误更新 UI。
  void _moveToBackground() {
    _movedToBackground = true;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('正在后台下载，完成后会自动唤起安装'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _cancelDownload() {
    if (_cancelToken != null && !_cancelToken!.isCancelled) {
      _cancelToken!.cancel('用户取消下载');
    }
    if (mounted) {
      setState(() {
        _isProcessing = false;
        _progress = 0.0;
        _statusText = '已取消下载';
      });
      Navigator.of(context).pop();
    }
  }

  /// 根据运行平台展示行动按钮文案
  String get _actionButtonText {
    if (!kIsWeb && Platform.isIOS) {
      return '前往 App Store';
    }
    if (VersionCheckService.isHarmonyOS) {
      final platformInfo = widget.info.currentPlatformInfo;
      if (platformInfo?.installMode == 'app_market') {
        return '前往华为应用市场';
      }
    }
    return '立即更新';
  }

  bool get _isDirectDownload {
    if (!kIsWeb && Platform.isIOS) return false;
    // 鸿蒙一律不直接下载安装：.hap 的 Profile 与设备 UDID 一对一绑定，
    // 而清单里没有 harmony 段时 currentPlatformInfo 会回退到 android，
    // 那是个在纯血鸿蒙上装不了的 APK，下下来也只是白等。
    if (VersionCheckService.isHarmonyOS) return false;
    return true;
  }

  Future<void> _startUpdate() async {
    _cancelToken = CancelToken();
    setState(() {
      _isProcessing = true;
      _hasError = false;
      _isInstalledInvoked = false;
      _progress = 0.0;
      _statusText = _isDirectDownload ? '正在建立高速连接...' : '正在跳转应用商店...';
    });

    try {
      await _versionService.executePlatformUpdate(
        widget.info,
        cancelToken: _cancelToken,
        onProgress: (progress, [speedText]) {
          if (mounted) {
            setState(() {
              _progress = progress;
              if (_isDirectDownload) {
                if (progress >= 1.0) {
                  _statusText = '下载完成，已唤起系统安装器';
                  _isInstalledInvoked = true;
                } else {
                  final pct = (progress * 100).toStringAsFixed(1);
                  final speedPart = (speedText != null && speedText.isNotEmpty)
                      ? ' · $speedText'
                      : '';
                  _statusText = '正在高速下载升级包... $pct%$speedPart';
                }
              } else {
                _statusText = '正在跳转分发中心...';
              }
            });
          }
        },
      );

      if (mounted && _isDirectDownload) {
        setState(() {
          _isInstalledInvoked = true;
          _statusText = '已唤起系统安装器，请在系统界面完成安装';
        });
      }

      if (!_isDirectDownload && mounted) {
        // 跳转商店后稍作延时关闭或保留
        await Future.delayed(const Duration(seconds: 1));
        if (mounted && !widget.info.isForceUpdate) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (_cancelToken?.isCancelled == true) {
        return;
      }
      if (mounted) {
        setState(() {
          _hasError = true;
          _statusText = '操作失败，请检查网络后重试';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = SoftTheme.of(context);

    return PopScope(
      canPop: !widget.info.isForceUpdate,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && _isProcessing) {
          _cancelToken?.cancel('物理返回退出弹窗');
        }
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius:
                BorderRadius.circular(SoftDecorations.squircleCardRadius),
            border: Border.all(color: colors.border, width: 1.0),
            boxShadow: SoftDecorations.softShadows(colors, elevation: 3.0),
          ),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. 顶部科技感徽标与标题区（支持随时点击右上角✕关闭）
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 48.0,
                    height: 48.0,
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colors.accent.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.rocket_launch_rounded,
                      color: colors.accent,
                      size: 26.0,
                    ),
                  ),
                  const SizedBox(width: 14.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '发现新版本',
                          style: TextStyle(
                            fontSize: 19.0,
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4.0),
                        Wrap(
                          spacing: 8.0,
                          runSpacing: 4.0,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0, vertical: 2.0),
                              decoration: BoxDecoration(
                                color: colors.accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                              child: Text(
                                widget.info.displayTag,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: colors.accent,
                                ),
                              ),
                            ),
                            if (widget.info.publishDate.isNotEmpty)
                              Text(
                                widget.info.publishDate,
                                style: TextStyle(
                                  fontSize: 11.0,
                                  color: colors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!widget.info.isForceUpdate) ...[
                    const SizedBox(width: 8.0),
                    GestureDetector(
                      key: const ValueKey('btn_close_update_dialog'),
                      onTap: () {
                        if (_isProcessing) {
                          _cancelToken?.cancel('点击关闭按钮退出');
                        }
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        width: 32.0,
                        height: 32.0,
                        decoration: BoxDecoration(
                          color: colors.surface,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colors.border.withValues(alpha: 0.6),
                            width: 1.0,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.close_rounded,
                          size: 18.0,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 18.0),

              // 2. 更新说明卡片
              Text(
                '更新说明',
                style: TextStyle(
                  fontSize: 13.0,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 8.0),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                width: double.infinity,
                padding: const EdgeInsets.all(14.0),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16.0),
                  border:
                      Border.all(color: colors.border.withValues(alpha: 0.6)),
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _buildReleaseNoteItems(
                        widget.info.releaseNotes, colors),
                  ),
                ),
              ),
              const SizedBox(height: 14.0),

              // 3. 无损保留数据保障提示
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12.0, vertical: 10.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      color: Color(0xFF10B981),
                      size: 18.0,
                    ),
                    const SizedBox(width: 8.0),
                    Expanded(
                      child: Text(
                        '覆盖安装将完整保留您的全部书架、书签与离线数据',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: colors.isDark
                              ? const Color(0xFF34D399)
                              : const Color(0xFF065F46),
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22.0),

              // 4. 底部行动区（按钮 / 流式下载进度）
              if (!_isProcessing && !_hasError)
                Row(
                  children: [
                    if (!widget.info.isForceUpdate) ...[
                      Expanded(
                        child: SoftButton(
                          key: const ValueKey('btn_cancel_update'),
                          colors: colors,
                          isPill: true,
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          onPressed: () => Navigator.of(context).pop(),
                          child: Center(
                            child: Text(
                              '稍后再说',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12.0),
                    ],
                    Expanded(
                      child: SoftButton(
                        key: const ValueKey('btn_confirm_update'),
                        colors: colors,
                        isFilled: true,
                        isPill: true,
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        onPressed: _startUpdate,
                        child: Center(
                          child: Text(
                            _actionButtonText,
                            style: const TextStyle(
                              fontSize: 14.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else if (_hasError)
                Column(
                  children: [
                    Text(
                      _statusText,
                      style: const TextStyle(
                        fontSize: 12.0,
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10.0),
                    Row(
                      children: [
                        Expanded(
                          child: SoftButton(
                            colors: colors,
                            isPill: true,
                            onPressed: () => Navigator.of(context).pop(),
                            child: Center(
                              child: Text(
                                '取消',
                                style: TextStyle(color: colors.textSecondary),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12.0),
                        Expanded(
                          child: SoftButton(
                            colors: colors,
                            isFilled: true,
                            isPill: true,
                            onPressed: _startUpdate,
                            child: const Center(
                              child: Text('重试'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _statusText,
                            style: TextStyle(
                              fontSize: 12.0,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_isDirectDownload)
                          Text(
                            '${(_progress * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: colors.accent,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10.0),
                    // 流式进度条
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6.0),
                      child: Container(
                        height: 8.0,
                        width: double.infinity,
                        color: colors.border.withValues(alpha: 0.5),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: _isDirectDownload
                              ? _progress.clamp(0.0, 1.0)
                              : 1.0,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  colors.accent.withValues(alpha: 0.8),
                                  colors.accent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    // 控制按钮：已唤起安装器显示完成/重新唤起；下载中显示取消下载/后台下载
                    if (_isInstalledInvoked)
                      Row(
                        children: [
                          Expanded(
                            child: SoftButton(
                              key: const ValueKey('btn_update_complete'),
                              colors: colors,
                              isFilled: true,
                              isPill: true,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10.0),
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Center(
                                child: Text(
                                  '完成',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12.0),
                          Expanded(
                            child: SoftButton(
                              key: const ValueKey('btn_reinstall'),
                              colors: colors,
                              isPill: true,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10.0),
                              onPressed: _startUpdate,
                              child: Center(
                                child: Text(
                                  '重新安装',
                                  style: TextStyle(
                                    fontSize: 13.0,
                                    color: colors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          if (!widget.info.isForceUpdate) ...[
                            Expanded(
                              child: SoftButton(
                                key: const ValueKey('btn_cancel_download'),
                                colors: colors,
                                isPill: true,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10.0),
                                onPressed: _cancelDownload,
                                child: Center(
                                  child: Text(
                                    '取消下载',
                                    style: TextStyle(
                                      fontSize: 13.0,
                                      fontWeight: FontWeight.w600,
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12.0),
                            Expanded(
                              child: SoftButton(
                                key: const ValueKey('btn_background_download'),
                                colors: colors,
                                isFilled: true,
                                isPill: true,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10.0),
                                onPressed: _moveToBackground,
                                child: const Center(
                                  child: Text(
                                    '后台下载',
                                    style: TextStyle(
                                      fontSize: 13.0,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildReleaseNoteItems(String notes, SoftColors colors) {
    if (notes.trim().isEmpty) {
      return [
        Text(
          '性能优化与已知问题修复。',
          style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
        ),
      ];
    }

    final lines = notes
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return lines.map((line) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 6.0, right: 8.0),
              width: 5.0,
              height: 5.0,
              decoration: BoxDecoration(
                color: colors.accent,
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: Text(
                line,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: colors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}
