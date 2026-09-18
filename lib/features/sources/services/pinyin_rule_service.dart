import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'network_client.dart';
import 'pinyin_harmonizer.dart';

/// 拼音自愈规则实体数据模型
class PinyinRule {
  final String id;
  final String pattern;
  final String replacement;
  final bool isRegex;
  final bool isEnabled;
  final bool isCustom;

  /// 别名：原拼音/谐音模式
  String get pinyin => pattern;

  /// 别名：目标标准汉字
  String get hanzi => replacement;

  const PinyinRule({
    required this.id,
    required this.pattern,
    required this.replacement,
    this.isRegex = false,
    this.isEnabled = true,
    this.isCustom = false,
  });

  /// 兼容通过 pinyin/hanzi 命名的构造
  factory PinyinRule.named({
    required String id,
    required String pinyin,
    required String hanzi,
    bool isCustom = false,
    bool isEnabled = true,
    bool isRegex = false,
  }) {
    return PinyinRule(
      id: id,
      pattern: pinyin,
      replacement: hanzi,
      isCustom: isCustom,
      isEnabled: isEnabled,
      isRegex: isRegex,
    );
  }

  PinyinRule copyWith({
    String? id,
    String? pattern,
    String? replacement,
    bool? isRegex,
    bool? isEnabled,
    bool? isCustom,
  }) {
    return PinyinRule(
      id: id ?? this.id,
      pattern: pattern ?? this.pattern,
      replacement: replacement ?? this.replacement,
      isRegex: isRegex ?? this.isRegex,
      isEnabled: isEnabled ?? this.isEnabled,
      isCustom: isCustom ?? this.isCustom,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'pattern': pattern,
        'replacement': replacement,
        'pinyin': pattern,
        'hanzi': replacement,
        'isRegex': isRegex,
        'isEnabled': isEnabled,
        'isCustom': isCustom,
      };

  factory PinyinRule.fromJson(Map<String, dynamic> json) {
    final pattern =
        (json['pattern'] as String?) ?? (json['pinyin'] as String?) ?? '';
    final replacement =
        (json['replacement'] as String?) ?? (json['hanzi'] as String?) ?? '';
    return PinyinRule(
      id: json['id'] as String? ?? '',
      pattern: pattern,
      replacement: replacement,
      isRegex: json['isRegex'] as bool? ?? false,
      isEnabled: json['isEnabled'] as bool? ?? true,
      isCustom: json['isCustom'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PinyinRule &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          pattern == other.pattern &&
          replacement == other.replacement &&
          isRegex == other.isRegex &&
          isEnabled == other.isEnabled &&
          isCustom == other.isCustom;

  @override
  int get hashCode =>
      Object.hash(id, pattern, replacement, isRegex, isEnabled, isCustom);

  @override
  String toString() =>
      'PinyinRule($pattern -> $replacement, regex: $isRegex, enabled: $isEnabled, custom: $isCustom)';
}

/// 动态规则管理与云端热更新服务 (pinyin_rule_service.dart)
/// 负责云端高可用多节点热更拉取、用户自定义规则持久化、导入/导出及与 PinyinHarmonizer 的即时联动
class PinyinRuleService extends ChangeNotifier {
  static final PinyinRuleService _instance = PinyinRuleService._internal();
  factory PinyinRuleService() => _instance;
  PinyinRuleService._internal();

  static const String _keyRemoteRules = 'pinyin_remote_rules_cache';
  static const String _keyCustomRules = 'pinyin_custom_rules';
  static const String _keyVersion = 'pinyin_rules_version';

  /// 云端高可用镜像分发节点 (涵盖国内高速代理、jsDelivr CDN 与 GitHub raw)
  static const List<String> remoteEndpoints = [
    'https://ghfast.top/https://raw.githubusercontent.com/Kline-x/novel-reader-flutter/main/pinyin_rules.json',
    'https://cdn.jsdelivr.net/gh/Kline-x/novel-reader-flutter@main/pinyin_rules.json',
    'https://raw.githubusercontent.com/Kline-x/novel-reader-flutter/main/pinyin_rules.json',
    'https://cdn.jsdelivr.net/gh/gaorenhua/novel-reader-flutter@main/pinyin_rules.json',
    'https://raw.githubusercontent.com/gaorenhua/novel-reader-flutter/main/pinyin_rules.json',
  ];

  /// 基础内置云端规则（对齐 pinyin_rules.json，提供离线保底能力）
  static const List<Map<String, String>> _defaultBuiltinRules = [
    {'pattern': 'zhengfu', 'replacement': '政府'},
    {'pattern': 'jingcha', 'replacement': '警察'},
    {'pattern': 'guojia', 'replacement': '国家'},
    {'pattern': 'sharen', 'replacement': '杀人'},
    {'pattern': 'siwang', 'replacement': '死亡'},
    {'pattern': 'shouqiang', 'replacement': '手枪'},
    {'pattern': 'zidan', 'replacement': '子弹'},
    {'pattern': 'baozha', 'replacement': '爆炸'},
    {'pattern': 'dupin', 'replacement': '毒品'},
    {'pattern': 'gaochao', 'replacement': '高潮'},
    {'pattern': 'luoti', 'replacement': '裸体'},
    {'pattern': 'chiluoluo', 'replacement': '赤裸裸'},
    {'pattern': 'youhuo', 'replacement': '诱惑'},
    {'pattern': 'chuanxi', 'replacement': '喘息'},
    {'pattern': 'shenyin', 'replacement': '呻吟'},
    {'pattern': 'xinggan', 'replacement': '性感'},
    {'pattern': 'xingyu', 'replacement': '性欲'},
    {'pattern': 'routi', 'replacement': '肉体'},
    {'pattern': 'naizi', 'replacement': '奶子'},
    {'pattern': 'datui', 'replacement': '大腿'},
    {'pattern': 'xiongbu', 'replacement': '胸部'},
    {'pattern': 'kuaigan', 'replacement': '快感'},
    // 高频补充
    {'pattern': 'junshi', 'replacement': '军事'},
    {'pattern': 'fubai', 'replacement': '腐败'},
    {'pattern': 'zhengzhi', 'replacement': '政治'},
    {'pattern': 'shexiangtou', 'replacement': '摄像头'},
    {'pattern': 'fanzui', 'replacement': '犯罪'},
    {'pattern': 'dubo', 'replacement': '赌博'},
    {'pattern': 'xidu', 'replacement': '吸毒'},
    {'pattern': 'zisha', 'replacement': '自杀'},
    {'pattern': 'shengzhiqi', 'replacement': '生殖器'},
    {'pattern': 'zigong', 'replacement': '子宫'},
    {'pattern': 'yinbu', 'replacement': '阴部'},
    {'pattern': 'yindao', 'replacement': '阴道'},
    {'pattern': 'rufang', 'replacement': '乳房'},
    {'pattern': 'boqi', 'replacement': '勃起'},
    {'pattern': 'shejing', 'replacement': '射精'},
    {'pattern': 'xiati', 'replacement': '下体'},
    {'pattern': 'tunbu', 'replacement': '臀部'},
  ];

  final List<PinyinRule> _remoteRules = [];
  final List<PinyinRule> _customRules = [];
  bool _initialized = false;

  /// 是否已从本地磁盘（SharedPreferences）完成一次真实加载。
  /// 与 [_initialized] 区分：后者只表示"内存里已有可用规则表"（可能只是内置兜底）。
  bool _loadedFromDisk = false;
  int _currentVersion = 1;

  bool get isInitialized => _initialized;
  int get currentVersion => _currentVersion;

  /// 所有规则列表（优先自定义，其次云端）供 UI 列表展示
  List<PinyinRule> get rules => [..._customRules, ..._remoteRules];

  /// 规则统计指标
  int get cloudRulesCount => _remoteRules.length;
  int get customRulesCount => _customRules.length;
  int get activeRulesCount =>
      _customRules.where((r) => r.isEnabled).length +
      _remoteRules.where((r) => r.isEnabled).length;

  /// 获取当前所有生效的规则列表（包含启用的云端+自定义规则）
  List<PinyinRule> get allRules {
    if (!_initialized) {
      _initFromDefaults();
    }
    // 自定义规则优先于云端相同 pattern 的规则
    final customEnabled = _customRules.where((r) => r.isEnabled).toList();
    final customPatterns =
        customEnabled.map((r) => r.pattern.toLowerCase()).toSet();

    final remoteEnabled = _remoteRules
        .where((r) =>
            r.isEnabled && !customPatterns.contains(r.pattern.toLowerCase()))
        .toList();

    return [...customEnabled, ...remoteEnabled];
  }

  /// 所有用户自定义规则列表（包含未启用的）
  List<PinyinRule> get customRules => List.unmodifiable(_customRules);

  /// 所有云端规则列表（包含未启用的）
  List<PinyinRule> get remoteRules => List.unmodifiable(_remoteRules);

  /// 提供快速精确匹配字典 (pattern.toLowerCase -> replacement)
  Map<String, String> get exactRulesMap {
    final map = <String, String>{};
    for (final rule in allRules) {
      if (!rule.isRegex) {
        map[rule.pattern.toLowerCase()] = rule.replacement;
      }
    }
    return map;
  }

  /// 初始化加载本地缓存规则与用户自定义规则
  Future<void> init() async {
    if (_loadedFromDisk) return;

    final prefs = await SharedPreferences.getInstance();
    _currentVersion = prefs.getInt(_keyVersion) ?? 1;

    // 1. 读取云端规则缓存
    final remoteJsonStr = prefs.getString(_keyRemoteRules);
    if (remoteJsonStr != null && remoteJsonStr.isNotEmpty) {
      try {
        final decoded = jsonDecode(remoteJsonStr) as List<dynamic>;
        _remoteRules.clear();
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            _remoteRules.add(PinyinRule.fromJson(item));
          }
        }
      } catch (e) {
        debugPrint('读取云端规则缓存失败，回退默认规则: $e');
        _initFromDefaults();
      }
    } else {
      _initFromDefaults();
    }

    // 2. 读取用户自定义规则
    final customJsonStr = prefs.getString(_keyCustomRules);
    if (customJsonStr != null && customJsonStr.isNotEmpty) {
      try {
        final decoded = jsonDecode(customJsonStr) as List<dynamic>;
        _customRules.clear();
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            _customRules.add(PinyinRule.fromJson(item));
          }
        }
      } catch (e) {
        debugPrint('读取用户自定义规则失败: $e');
      }
    }

    _initialized = true;
    _loadedFromDisk = true;
    _syncToHarmonizer();
    notifyListeners();
  }

  void _syncToHarmonizer() {
    PinyinHarmonizer.setDynamicRules(exactRulesMap);
    PinyinHarmonizer.invalidateCache();
  }

  void _initFromDefaults() {
    _remoteRules.clear();
    // 置位，避免 allRules 每次被访问都重建整张默认表（此前一段正文即触发一次）
    _initialized = true;
    for (int i = 0; i < _defaultBuiltinRules.length; i++) {
      final entry = _defaultBuiltinRules[i];
      _remoteRules.add(
        PinyinRule(
          id: 'builtin_$i',
          pattern: entry['pattern']!,
          replacement: entry['replacement']!,
          isRegex: false,
          isEnabled: true,
          isCustom: false,
        ),
      );
    }
  }

  /// 从云端拉取规则热更新（高可用节点轮询，失败安全降级）
  Future<bool> syncFromRemote({NetworkClient? client}) async {
    final netClient = client ?? NetworkClient();

    for (final url in remoteEndpoints) {
      try {
        final content =
            await netClient.fetchHtml(url, timeout: const Duration(seconds: 4));
        if (content.isEmpty || !content.contains('"rules"')) {
          continue;
        }

        final data = jsonDecode(content) as Map<String, dynamic>;
        final newVersion = data['version'] as int? ?? 1;
        final rulesList = data['rules'] as List<dynamic>? ?? [];

        if (rulesList.isEmpty) continue;

        final newRules = <PinyinRule>[];
        // 保留用户在本地对该云端规则的开关设置
        final disabledPatterns = _remoteRules
            .where((r) => !r.isEnabled)
            .map((r) => r.pattern.toLowerCase())
            .toSet();

        for (int i = 0; i < rulesList.length; i++) {
          final item = rulesList[i] as Map<String, dynamic>;
          final pattern = (item['pattern'] as String? ?? '').trim();
          final replacement = (item['replacement'] as String? ?? '').trim();
          final isRegex = item['isRegex'] as bool? ?? false;

          if (pattern.isEmpty || replacement.isEmpty) continue;
          // 云端下发的规则同样可能非法，编译不过直接丢弃，避免污染本地规则表
          if (!isRuleUsable(pattern, isRegex: isRegex)) {
            debugPrint('[PinyinRuleService] 跳过云端非法规则: $pattern');
            continue;
          }

          newRules.add(
            PinyinRule(
              id: 'remote_${newVersion}_$i',
              pattern: pattern,
              replacement: replacement,
              isRegex: isRegex,
              isEnabled: !disabledPatterns.contains(pattern.toLowerCase()),
              isCustom: false,
            ),
          );
        }

        if (newRules.isNotEmpty) {
          _remoteRules
            ..clear()
            ..addAll(newRules);
          _currentVersion = newVersion;
          await _persistRemoteRules();
          _initialized = true;
          _syncToHarmonizer();
          notifyListeners();
          return true;
        }
      } catch (e) {
        debugPrint('从节点 $url 同步拼音规则失败: $e');
      }
    }

    return false;
  }

  /// 校验一条规则是否可安全使用（正则规则必须能成功编译）
  static bool isRuleUsable(String pattern, {bool isRegex = false}) {
    if (pattern.trim().isEmpty) return false;
    if (!isRegex) return true;
    try {
      RegExp(pattern);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 添加自定义规则
  ///
  /// 返回 true 表示已成功写入；返回 false 表示规则非法（如正则语法错误）已被拒绝。
  Future<bool> addCustomRule(
    String pattern,
    String replacement, {
    bool isRegex = false,
  }) async {
    final cleanPattern = pattern.trim();
    final cleanReplacement = replacement.trim();
    if (cleanPattern.isEmpty || cleanReplacement.isEmpty) return false;
    if (!isRuleUsable(cleanPattern, isRegex: isRegex)) return false;

    // 检查是否已有相同 pattern 的自定义规则
    final existingIdx = _customRules.indexWhere(
      (r) => r.pattern.toLowerCase() == cleanPattern.toLowerCase(),
    );

    final ruleId = existingIdx >= 0
        ? _customRules[existingIdx].id
        : 'custom_${DateTime.now().millisecondsSinceEpoch}_${cleanPattern.hashCode}';

    final rule = PinyinRule(
      id: ruleId,
      pattern: cleanPattern,
      replacement: cleanReplacement,
      isRegex: isRegex,
      isEnabled: true,
      isCustom: true,
    );

    if (existingIdx >= 0) {
      _customRules[existingIdx] = rule;
    } else {
      _customRules.insert(0, rule);
    }

    await _persistCustomRules();
    _syncToHarmonizer();
    notifyListeners();
    return true;
  }

  /// 删除自定义规则
  Future<void> deleteCustomRule(String id) async {
    _customRules.removeWhere((r) => r.id == id);
    await _persistCustomRules();
    _syncToHarmonizer();
    notifyListeners();
  }

  /// 别名：删除自定义规则（兼容历史接口）
  Future<void> removeCustomRule(String id) => deleteCustomRule(id);

  /// 切换指定规则启用/停用状态
  Future<void> toggleRule(String id, bool isEnabled) async {
    // 优先在自定义规则中查找
    final customIdx = _customRules.indexWhere((r) => r.id == id);
    if (customIdx >= 0) {
      _customRules[customIdx] =
          _customRules[customIdx].copyWith(isEnabled: isEnabled);
      await _persistCustomRules();
      _syncToHarmonizer();
      notifyListeners();
      return;
    }

    // 次选在云端规则中查找
    final remoteIdx = _remoteRules.indexWhere((r) => r.id == id);
    if (remoteIdx >= 0) {
      _remoteRules[remoteIdx] =
          _remoteRules[remoteIdx].copyWith(isEnabled: isEnabled);
      await _persistRemoteRules();
      _syncToHarmonizer();
      notifyListeners();
    }
  }

  /// 导出所有自定义规则为 JSON 字符串
  String exportRulesJson() {
    final mapList = _customRules.map((r) => r.toJson()).toList();
    final exportData = {
      'version': _currentVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'rules': mapList,
    };
    return const JsonEncoder.withIndent('  ').convert(exportData);
  }

  /// 导入 JSON 文本并去重合并
  Future<int> importRulesJson(String jsonStr) async {
    try {
      final decoded = jsonDecode(jsonStr);
      List<dynamic> list;
      if (decoded is Map<String, dynamic> && decoded['rules'] is List) {
        list = decoded['rules'] as List<dynamic>;
      } else if (decoded is List) {
        list = decoded;
      } else {
        return 0;
      }

      int count = 0;
      for (final item in list) {
        if (item is! Map<String, dynamic>) continue;
        final pattern =
            (item['pattern'] as String?) ?? (item['pinyin'] as String?) ?? '';
        final replacement = (item['replacement'] as String?) ??
            (item['hanzi'] as String?) ??
            '';
        final isRegex = item['isRegex'] as bool? ?? false;
        final isEnabled = item['isEnabled'] as bool? ?? true;

        final cleanPattern = pattern.trim();
        final cleanReplacement = replacement.trim();
        if (cleanPattern.isEmpty || cleanReplacement.isEmpty) continue;

        final existingIdx = _customRules.indexWhere(
          (r) => r.pattern.toLowerCase() == cleanPattern.toLowerCase(),
        );

        final id = existingIdx >= 0
            ? _customRules[existingIdx].id
            : 'custom_${DateTime.now().millisecondsSinceEpoch}_${cleanPattern.hashCode}_$count';

        final rule = PinyinRule(
          id: id,
          pattern: cleanPattern,
          replacement: cleanReplacement,
          isRegex: isRegex,
          isEnabled: isEnabled,
          isCustom: true,
        );

        if (existingIdx >= 0) {
          _customRules[existingIdx] = rule;
        } else {
          _customRules.add(rule);
        }
        count++;
      }

      if (count > 0) {
        await _persistCustomRules();
        _syncToHarmonizer();
        notifyListeners();
      }
      return count;
    } catch (e) {
      debugPrint('导入规则失败: $e');
      return 0;
    }
  }

  /// 重置全部自定义规则与恢复初始状态
  Future<void> resetAll() async {
    _customRules.clear();
    _initFromDefaults();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCustomRules);
    await prefs.remove(_keyRemoteRules);
    _initialized = true;
    _syncToHarmonizer();
    notifyListeners();
  }

  /// 单元测试专用重置
  void resetForTest() {
    _remoteRules.clear();
    _customRules.clear();
    _initialized = false;
    _currentVersion = 1;
    PinyinHarmonizer.setDynamicRules({});
  }

  Future<void> _persistRemoteRules() async {
    final prefs = await SharedPreferences.getInstance();
    final mapList = _remoteRules.map((r) => r.toJson()).toList();
    await prefs.setString(_keyRemoteRules, jsonEncode(mapList));
    await prefs.setInt(_keyVersion, _currentVersion);
  }

  Future<void> _persistCustomRules() async {
    final prefs = await SharedPreferences.getInstance();
    final mapList = _customRules.map((r) => r.toJson()).toList();
    await prefs.setString(_keyCustomRules, jsonEncode(mapList));
  }
}
