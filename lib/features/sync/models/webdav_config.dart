/// WebDAV 云同步配置模型
class WebDavConfig {
  final String serverUrl;
  final String username;
  final String password;
  final String remotePath;
  final bool autoSync;
  final DateTime? lastSyncTime;

  const WebDavConfig({
    required this.serverUrl,
    required this.username,
    required this.password,
    this.remotePath = '/novel_reader',
    this.autoSync = false,
    this.lastSyncTime,
  });

  bool get isConfigured =>
      serverUrl.trim().isNotEmpty &&
      username.trim().isNotEmpty &&
      password.trim().isNotEmpty;

  Map<String, dynamic> toJson() {
    return {
      'serverUrl': serverUrl,
      'username': username,
      'password': password,
      'remotePath': remotePath,
      'autoSync': autoSync,
      if (lastSyncTime != null) 'lastSyncTime': lastSyncTime!.toIso8601String(),
    };
  }

  factory WebDavConfig.fromJson(Map<String, dynamic> json) {
    return WebDavConfig(
      serverUrl: json['serverUrl'] as String? ?? '',
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      remotePath: json['remotePath'] as String? ?? '/novel_reader',
      autoSync: json['autoSync'] as bool? ?? false,
      lastSyncTime: json['lastSyncTime'] != null
          ? DateTime.tryParse(json['lastSyncTime'] as String)
          : null,
    );
  }

  WebDavConfig copyWith({
    String? serverUrl,
    String? username,
    String? password,
    String? remotePath,
    bool? autoSync,
    DateTime? lastSyncTime,
  }) {
    return WebDavConfig(
      serverUrl: serverUrl ?? this.serverUrl,
      username: username ?? this.username,
      password: password ?? this.password,
      remotePath: remotePath ?? this.remotePath,
      autoSync: autoSync ?? this.autoSync,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }
}
