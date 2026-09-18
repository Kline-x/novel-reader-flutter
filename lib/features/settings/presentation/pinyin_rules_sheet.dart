import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/components/soft_button.dart';
import '../../../core/components/soft_card.dart';
import '../../../core/components/soft_switch.dart';
import '../../../core/theme/soft_theme.dart';
import '../../sources/services/pinyin_rule_service.dart';

/// Modern Soft UI 风格拼音谐音自愈规则管理面板 (PinyinRulesSheet)
class PinyinRulesSheet extends StatefulWidget {
  const PinyinRulesSheet({super.key});

  /// 便捷展示半屏抽屉
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PinyinRulesSheet(),
    );
  }

  @override
  State<PinyinRulesSheet> createState() => _PinyinRulesSheetState();
}

class _PinyinRulesSheetState extends State<PinyinRulesSheet> {
  final PinyinRuleService _ruleService = PinyinRuleService();
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _ruleService.init();
    _ruleService.addListener(_onRulesChanged);
  }

  @override
  void dispose() {
    _ruleService.removeListener(_onRulesChanged);
    super.dispose();
  }

  void _onRulesChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _syncCloudRules() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);

    try {
      final hasNew = await _ruleService.syncFromRemote();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(hasNew ? '已成功同步最新云端自愈规则' : '当前云端规则已是最新版本'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('云端同步失败，请检查网络连接')),
      );
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _showAddRuleDialog() {
    final colors = SoftTheme.of(context);
    final pinyinController = TextEditingController();
    final hanziController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: colors.card,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(SoftDecorations.squircleCardRadius),
          ),
          title: Text(
            '添加拼音自愈规则',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18.0,
              color: colors.textPrimary,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const ValueKey('input_rule_pinyin'),
                controller: pinyinController,
                decoration: InputDecoration(
                  labelText: '原词 / 拼音',
                  hintText: '如 pinyin 或 ci',
                  hintStyle: TextStyle(
                      fontSize: 13.0,
                      color: colors.textSecondary.withValues(alpha: 0.6)),
                  filled: true,
                  fillColor: colors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: BorderSide(color: colors.border),
                  ),
                ),
              ),
              const SizedBox(height: 12.0),
              TextField(
                key: const ValueKey('input_rule_hanzi'),
                controller: hanziController,
                decoration: InputDecoration(
                  labelText: '目标替换汉字',
                  hintText: '如 拼音 或 词',
                  hintStyle: TextStyle(
                      fontSize: 13.0,
                      color: colors.textSecondary.withValues(alpha: 0.6)),
                  filled: true,
                  fillColor: colors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: BorderSide(color: colors.border),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('取消', style: TextStyle(color: colors.textSecondary)),
            ),
            TextButton(
              key: const ValueKey('btn_confirm_add_rule'),
              onPressed: () {
                final pinyin = pinyinController.text.trim();
                final hanzi = hanziController.text.trim();
                if (pinyin.isNotEmpty && hanzi.isNotEmpty) {
                  _ruleService.addCustomRule(pinyin, hanzi);
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已添加规则: $pinyin → $hanzi')),
                  );
                }
              },
              child: Text('确认添加',
                  style: TextStyle(
                      color: colors.accent, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _exportRules() {
    final jsonText = _ruleService.exportRulesJson();
    Clipboard.setData(ClipboardData(text: jsonText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已复制自定义规则到剪贴板'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _importRules() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('剪贴板未包含文本内容')),
        );
      }
      return;
    }

    final count = await _ruleService.importRulesJson(text);
    if (mounted) {
      if (count > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已成功导入 $count 条新规则')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未识别到有效的规则 JSON 格式')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = SoftTheme.of(context);
    final allRules = _ruleService.rules;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28.0)),
        boxShadow: SoftDecorations.softShadows(colors, elevation: 4.0),
      ),
      child: Column(
        children: [
          // 顶部小胶囊指示条
          Container(
            margin: const EdgeInsets.only(top: 12.0, bottom: 8.0),
            width: 40.0,
            height: 4.5,
            decoration: BoxDecoration(
              color: colors.border,
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),

          // 标题栏
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Icon(Icons.spellcheck_rounded,
                      color: colors.accent, size: 24.0),
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '智能拼音自愈规则',
                        style: TextStyle(
                          fontSize: 18.0,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        '自愈第三方书源中的拼音谐音和谐词',
                        style: TextStyle(
                            fontSize: 12.0, color: colors.textSecondary),
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
          ),

          // 顶部信息与同步卡片
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
            child: SoftCard(
              colors: colors,
              padding: const EdgeInsets.all(14.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '已生效规则总计',
                          style: TextStyle(
                              fontSize: 11.5, color: colors.textSecondary),
                        ),
                        const SizedBox(height: 3.0),
                        Text(
                          '云端 ${_ruleService.cloudRulesCount} 条 · 自定义 ${_ruleService.customRulesCount} 条',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SoftButton(
                    key: const ValueKey('btn_sync_pinyin_cloud'),
                    colors: colors,
                    isPill: true,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12.0, vertical: 6.0),
                    onPressed: _syncCloudRules,
                    child: _isSyncing
                        ? SizedBox(
                            width: 14.0,
                            height: 14.0,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.0, color: colors.accent),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.cloud_sync_rounded,
                                  size: 16.0, color: colors.accent),
                              const SizedBox(width: 4.0),
                              Text(
                                '同步云端',
                                style: TextStyle(
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.bold,
                                  color: colors.accent,
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),

          // 操作工具栏（添加、导出、导入）
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: SoftButton(
                    key: const ValueKey('btn_open_add_rule'),
                    colors: colors,
                    isFilled: true,
                    isPill: true,
                    padding: const EdgeInsets.symmetric(vertical: 9.0),
                    onPressed: _showAddRuleDialog,
                    child: const Center(
                      child: Text(
                        '+ 添加规则',
                        style: TextStyle(
                            fontSize: 13.0, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10.0),
                Expanded(
                  flex: 2,
                  child: SoftButton(
                    key: const ValueKey('btn_export_pinyin_rules'),
                    colors: colors,
                    isPill: true,
                    padding: const EdgeInsets.symmetric(vertical: 9.0),
                    onPressed: _exportRules,
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.upload_rounded,
                              size: 15.0, color: colors.textSecondary),
                          const SizedBox(width: 4.0),
                          Text(
                            '导出',
                            style: TextStyle(
                                fontSize: 12.5, color: colors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10.0),
                Expanded(
                  flex: 2,
                  child: SoftButton(
                    key: const ValueKey('btn_import_pinyin_rules'),
                    colors: colors,
                    isPill: true,
                    padding: const EdgeInsets.symmetric(vertical: 9.0),
                    onPressed: _importRules,
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.download_rounded,
                              size: 15.0, color: colors.textSecondary),
                          const SizedBox(width: 4.0),
                          Text(
                            '导入',
                            style: TextStyle(
                                fontSize: 12.5, color: colors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 16.0),

          // 规则列表
          Expanded(
            child: allRules.isEmpty
                ? Center(
                    child: Text(
                      '暂无规则',
                      style: TextStyle(color: colors.textSecondary),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20.0, vertical: 6.0),
                    physics: const BouncingScrollPhysics(),
                    itemCount: allRules.length,
                    itemBuilder: (context, index) {
                      final rule = allRules[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8.0),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14.0, vertical: 10.0),
                        decoration: BoxDecoration(
                          color: colors.card,
                          borderRadius: BorderRadius.circular(16.0),
                          border: Border.all(color: colors.border),
                          boxShadow: SoftDecorations.softShadows(colors,
                              elevation: 0.5),
                        ),
                        child: Row(
                          children: [
                            // 规则文本
                            Expanded(
                              child: Row(
                                children: [
                                  Text(
                                    rule.pinyin,
                                    style: TextStyle(
                                      fontSize: 14.0,
                                      fontWeight: FontWeight.w700,
                                      color: rule.isEnabled
                                          ? colors.textPrimary
                                          : colors.textSecondary,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0),
                                    child: Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 14.0,
                                      color: colors.accent,
                                    ),
                                  ),
                                  Text(
                                    rule.hanzi,
                                    style: TextStyle(
                                      fontSize: 14.0,
                                      fontWeight: FontWeight.w800,
                                      color: rule.isEnabled
                                          ? colors.accent
                                          : colors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 10.0),
                                  // 标签 Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6.0, vertical: 2.0),
                                    decoration: BoxDecoration(
                                      color: rule.isCustom
                                          ? colors.accent
                                              .withValues(alpha: 0.15)
                                          : colors.textSecondary
                                              .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6.0),
                                    ),
                                    child: Text(
                                      rule.isCustom ? '自定义' : '云端',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: rule.isCustom
                                            ? colors.accent
                                            : colors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // 删除自定义规则
                            if (rule.isCustom)
                              IconButton(
                                key: ValueKey('btn_delete_rule_${rule.id}'),
                                icon: Icon(Icons.delete_outline_rounded,
                                    size: 18.0, color: colors.textSecondary),
                                onPressed: () =>
                                    _ruleService.removeCustomRule(rule.id),
                              ),

                            // 启停开关
                            SoftSwitch(
                              value: rule.isEnabled,
                              onChanged: (val) =>
                                  _ruleService.toggleRule(rule.id, val),
                              colors: colors,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
