import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

enum WifiServerStatus { stopped, starting, running, error }

class WifiServerEvent {
  final WifiServerStatus status;
  final String? ipAddress;
  final int port;
  final String? message;
  final String? uploadedFileName;

  const WifiServerEvent({
    required this.status,
    this.ipAddress,
    this.port = 8888,
    this.message,
    this.uploadedFileName,
  });
}

/// 局域网 WiFi 极速网页传书服务 (wifi_transfer_server.dart)
/// - 基于 Dart 原生 HttpServer 搭建，零多余平台依赖，跨 iOS / Android / HarmonyOS
/// - 自动嗅探设备局域网 IPv4 地址
/// - 内嵌 Modern Soft UI 美学网页端，支持桌面与手机浏览器无感极速传书
class WifiTransferServer {
  static final WifiTransferServer _instance = WifiTransferServer._internal();
  factory WifiTransferServer() => _instance;
  WifiTransferServer._internal();

  HttpServer? _server;
  WifiServerStatus _status = WifiServerStatus.stopped;
  String _ipAddress = '127.0.0.1';
  final _eventController = StreamController<WifiServerEvent>.broadcast();
  int _port = 8888;
  String? customUploadDir;

  // 接收上传文件回调
  Future<void> Function(File file)? onFileReceived;

  /// 单次上传体积上限（100MB），防止恶意/误操作的超大请求把进程撑爆
  static const int maxUploadBytes = 100 * 1024 * 1024;

  /// 允许接收的图书扩展名白名单
  static const Set<String> allowedExtensions = {'.txt', '.epub'};

  /// 净化上传文件名，彻底阻断路径穿越
  ///
  /// 此前文件名直接取自 query 参数 / Content-Disposition 并拼进路径，
  /// 同一局域网内任何人都可用 `?filename=../../shared_prefs/x.xml`
  /// 覆写应用沙盒里的任意文件。
  static String sanitizeFileName(String raw) {
    // 1. 只取最后一段，剥掉任何目录成分（含 Windows 反斜杠与 URL 编码后的分隔符）
    var name = raw.trim();
    try {
      name = Uri.decodeComponent(name);
    } catch (_) {
      // 非法百分号编码保持原样，后续字符过滤同样能兜住
    }
    name = name.split(RegExp(r'[/\\]')).last;

    // 2. 去掉控制字符、路径穿越序列与文件系统保留字符
    name = name
        .replaceAll(RegExp(r'[\x00-\x1f]'), '')
        .replaceAll('..', '')
        .replaceAll(RegExp(r'[<>:"|?*]'), '')
        .trim();

    // 3. 剥掉开头的点，避免生成隐藏文件或空名
    while (name.startsWith('.')) {
      name = name.substring(1);
    }

    // 4. 扩展名白名单校验，非图书格式一律按 .txt 落盘
    final lower = name.toLowerCase();
    final ext = allowedExtensions.firstWhere(
      (e) => lower.endsWith(e),
      orElse: () => '',
    );
    if (ext.isEmpty) {
      name = '${name.isEmpty ? 'novel' : name}.txt';
    }

    // 5. 限制长度并兜底
    if (name.length > 120) {
      final keepExt = name.substring(name.lastIndexOf('.'));
      name = name.substring(0, 100) + keepExt;
    }
    if (name.isEmpty || name == '.txt') {
      name = 'novel_${DateTime.now().millisecondsSinceEpoch}.txt';
    }
    return name;
  }

  WifiServerStatus get status => _status;
  String get ipAddress => _ipAddress;
  int get port => _port;
  String get serverUrl => 'http://$_ipAddress:$_port';
  Stream<WifiServerEvent> get eventStream => _eventController.stream;

  /// 获取局域网有效 IPv4 地址
  static Future<String> getLocalIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback &&
              !addr.address.startsWith('127.') &&
              (addr.address.startsWith('192.168.') ||
                  addr.address.startsWith('10.') ||
                  addr.address.startsWith('172.'))) {
            return addr.address;
          }
        }
      }
      // 备选第一个非回环
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback && !addr.address.startsWith('127.')) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return '127.0.0.1';
  }

  /// 启动 HTTP 传书服务
  Future<bool> start({int port = 8888}) async {
    if (_status == WifiServerStatus.running) return true;

    _status = WifiServerStatus.starting;
    _eventController.add(WifiServerEvent(status: _status));

    try {
      _ipAddress = await getLocalIpAddress();
      _port = port;

      _server = await HttpServer.bind(InternetAddress.anyIPv4, _port);
      _status = WifiServerStatus.running;

      _eventController.add(WifiServerEvent(
        status: _status,
        ipAddress: _ipAddress,
        port: _port,
        message: '服务已成功启动，请在同局域网浏览器访问 $serverUrl',
      ));

      _server!.listen(_handleRequest, onError: (e) {
        _status = WifiServerStatus.error;
        _eventController
            .add(WifiServerEvent(status: _status, message: e.toString()));
      });

      return true;
    } catch (e) {
      _status = WifiServerStatus.error;
      _eventController
          .add(WifiServerEvent(status: _status, message: '启动失败: $e'));
      return false;
    }
  }

  /// 停止传书服务
  Future<void> stop() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
    }
    _status = WifiServerStatus.stopped;
    _eventController.add(WifiServerEvent(status: _status, message: '服务已停止'));
  }

  void _handleRequest(HttpRequest request) async {
    // 跨域支持
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers
        .add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers
        .add('Access-Control-Allow-Headers', 'Content-Type');

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }

    final path = request.uri.path;

    if (request.method == 'GET' && (path == '/' || path == '/index.html')) {
      _serveWebPage(request);
    } else if (request.method == 'GET' && path == '/api/status') {
      _serveStatus(request);
    } else if (request.method == 'POST' && path == '/api/upload') {
      await _handleUpload(request);
    } else {
      request.response.statusCode = HttpStatus.notFound;
      request.response.write('Not Found');
      await request.response.close();
    }
  }

  void _serveStatus(HttpRequest request) {
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({
      'status': 'running',
      'ip': _ipAddress,
      'port': _port,
      'serverUrl': serverUrl,
    }));
    request.response.close();
  }

  /// 二次防线：确认最终落点确实位于 local_books 目录内
  File _resolveSafeTarget(Directory baseDir, String fileName) {
    final safeName = sanitizeFileName(fileName);
    final target = File('${baseDir.path}/$safeName');
    final normalizedBase = baseDir.path.replaceAll(r'\', '/');
    final normalizedTarget = target.path.replaceAll(r'\', '/');
    if (!normalizedTarget.startsWith('$normalizedBase/')) {
      throw Exception('非法的上传路径: $fileName');
    }
    return target;
  }

  Future<void> _handleUpload(HttpRequest request) async {
    try {
      final contentType = request.headers.contentType;
      String filename = 'novel_${DateTime.now().millisecondsSinceEpoch}.txt';

      // 提取文件名（支持 query 参数 ?filename=... 或 Content-Disposition）
      if (request.uri.queryParameters.containsKey('filename')) {
        filename = sanitizeFileName(request.uri.queryParameters['filename']!);
      }

      // 体积闸门：Content-Length 明显超限直接拒绝，不读取任何字节
      final declaredLength = request.contentLength;
      if (declaredLength > maxUploadBytes) {
        request.response.statusCode = HttpStatus.requestEntityTooLarge;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({
          'success': false,
          'message': '文件超过 ${maxUploadBytes ~/ (1024 * 1024)}MB 上限',
        }));
        await request.response.close();
        return;
      }

      String basePath;
      if (customUploadDir != null) {
        basePath = customUploadDir!;
      } else {
        final docDir = await getApplicationDocumentsDirectory();
        basePath = docDir.path;
      }
      final localBooksDir = Directory('$basePath/local_books');
      if (!await localBooksDir.exists()) {
        await localBooksDir.create(recursive: true);
      }

      if (contentType != null && contentType.primaryType == 'multipart') {
        // multipart/form-data 处理
        final boundary = contentType.parameters['boundary'];
        if (boundary == null) {
          throw Exception('Missing multipart boundary');
        }

        final bytes = <int>[];
        await for (final chunk in request) {
          bytes.addAll(chunk);
          if (bytes.length > maxUploadBytes) {
            throw Exception('上传体积超过上限');
          }
        }
        final fileData = _extractMultipartFile(bytes, boundary);
        if (fileData != null) {
          if (fileData.filename != null) {
            filename = sanitizeFileName(fileData.filename!);
          }
          final finalFile = _resolveSafeTarget(localBooksDir, filename);
          await finalFile.writeAsBytes(fileData.bytes);
          if (onFileReceived != null) {
            await onFileReceived!(finalFile);
          }
        }
      } else {
        final safeTarget = _resolveSafeTarget(localBooksDir, filename);
        final sink = safeTarget.openWrite();
        var written = 0;
        await for (final chunk in request) {
          written += chunk.length;
          if (written > maxUploadBytes) {
            await sink.close();
            await safeTarget.delete();
            throw Exception('上传体积超过上限');
          }
          sink.add(chunk);
        }
        await sink.flush();
        await sink.close();
        if (onFileReceived != null) {
          await onFileReceived!(safeTarget);
        }
      }

      _eventController.add(WifiServerEvent(
        status: _status,
        ipAddress: _ipAddress,
        port: _port,
        message: '收到新书: $filename',
        uploadedFileName: filename,
      ));

      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'success': true,
        'filename': filename,
        'message': '上传并解析成功',
      }));
      await request.response.close();
    } catch (e) {
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'success': false,
        'error': e.toString(),
      }));
      await request.response.close();
    }
  }

  _MultipartResult? _extractMultipartFile(List<int> bytes, String boundary) {
    final boundaryBytes = utf8.encode('--$boundary');
    // 简易 multipart 数据区定位
    final doubleNewline = [13, 10, 13, 10]; // \r\n\r\n

    int headerStart = -1;
    for (int i = 0; i <= bytes.length - boundaryBytes.length; i++) {
      bool match = true;
      for (int j = 0; j < boundaryBytes.length; j++) {
        if (bytes[i + j] != boundaryBytes[j]) {
          match = false;
          break;
        }
      }
      if (match) {
        headerStart = i + boundaryBytes.length;
        break;
      }
    }

    if (headerStart == -1) return null;

    int bodyStart = -1;
    for (int i = headerStart; i <= bytes.length - 4; i++) {
      if (bytes[i] == doubleNewline[0] &&
          bytes[i + 1] == doubleNewline[1] &&
          bytes[i + 2] == doubleNewline[2] &&
          bytes[i + 3] == doubleNewline[3]) {
        bodyStart = i + 4;
        break;
      }
    }

    if (bodyStart == -1) return null;

    final headerText = utf8.decode(bytes.sublist(headerStart, bodyStart - 4),
        allowMalformed: true);
    String? filename;
    // 优先取 RFC 5987 的 filename*=UTF-8''xxx —— 它明确标注了编码，最可靠
    final starMatch = RegExp(
      "filename\\*\\s*=\\s*([A-Za-z0-9-]+)'[^']*'([^;\r\n]+)",
      caseSensitive: false,
    ).firstMatch(headerText);
    if (starMatch != null) {
      try {
        filename = Uri.decodeFull(starMatch.group(2)!.trim());
      } catch (_) {}
    }
    if (filename == null) {
      final fnMatch = RegExp(r'filename\s*=\s*["' "'" r']?([^"' "'" r';\r\n]+)',
              caseSensitive: false)
          .firstMatch(headerText);
      if (fnMatch != null) {
        final rawName = fnMatch.group(1)!.trim();
        try {
          filename = Uri.decodeFull(rawName);
        } catch (_) {
          filename = rawName;
        }
      }
    }
    // 非 UTF-8 客户端送来的头解码后会出现替换字符，此时宁可退回时间戳命名
    if (filename != null && filename.contains('�')) {
      filename = null;
    }

    // 寻找末尾 boundary
    int bodyEnd = bytes.length;
    for (int i = bodyStart; i <= bytes.length - boundaryBytes.length; i++) {
      bool match = true;
      for (int j = 0; j < boundaryBytes.length; j++) {
        if (bytes[i + j] != boundaryBytes[j]) {
          match = false;
          break;
        }
      }
      if (match) {
        bodyEnd = i - 2; // 去除前置 \r\n
        break;
      }
    }

    if (bodyEnd < bodyStart) bodyEnd = bodyStart;
    final fileBytes = bytes.sublist(bodyStart, bodyEnd);
    return _MultipartResult(
        filename: filename, bytes: Uint8List.fromList(fileBytes));
  }

  void _serveWebPage(HttpRequest request) {
    request.response.headers.contentType = ContentType.html;
    request.response.write(_webPageHtml);
    request.response.close();
  }

  static const String _webPageHtml = '''
<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>藏书阁 · 局域网 WiFi 极速传书</title>
  <style>
    :root {
      --bg: #F8F5EE;
      --card-bg: rgba(255, 255, 255, 0.85);
      --primary: #C5A059;
      --primary-hover: #B38E46;
      --text: #2A2520;
      --subtext: #7A7265;
      --radius: 24px;
      --shadow: 0 12px 32px rgba(42, 37, 32, 0.06), 0 2px 8px rgba(42, 37, 32, 0.03);
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      background-color: var(--bg);
      font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", "Noto Serif SC", serif;
      color: var(--text);
      display: flex;
      flex-direction: column;
      align-items: center;
      min-height: 100vh;
      padding: 40px 20px;
    }
    .header {
      text-align: center;
      margin-bottom: 32px;
    }
    .header h1 {
      font-size: 32px;
      font-weight: 700;
      letter-spacing: 2px;
      color: #8C6D2B;
      margin-bottom: 8px;
    }
    .header p {
      color: var(--subtext);
      font-size: 14px;
    }
    .card {
      background: var(--card-bg);
      backdrop-filter: blur(20px);
      border-radius: var(--radius);
      box-shadow: var(--shadow);
      width: 100%;
      max-width: 560px;
      padding: 36px 30px;
      border: 1px solid rgba(255, 255, 255, 0.9);
      transition: all 0.3s ease;
    }
    .drop-zone {
      border: 2px dashed #D9CEBD;
      border-radius: 18px;
      padding: 44px 20px;
      text-align: center;
      cursor: pointer;
      background: rgba(248, 245, 238, 0.6);
      transition: all 0.25s ease;
    }
    .drop-zone:hover, .drop-zone.dragover {
      border-color: var(--primary);
      background: rgba(197, 160, 89, 0.08);
      transform: scale(1.01);
    }
    .icon {
      font-size: 48px;
      margin-bottom: 12px;
    }
    .btn {
      display: inline-block;
      margin-top: 18px;
      background: linear-gradient(135deg, #D4AF67, #BA9148);
      color: #fff;
      padding: 12px 28px;
      border-radius: 30px;
      font-size: 15px;
      font-weight: 600;
      box-shadow: 0 4px 14px rgba(186, 145, 72, 0.3);
      cursor: pointer;
      border: none;
      transition: all 0.2s;
    }
    .btn:hover {
      background: linear-gradient(135deg, #BA9148, #A37C35);
      transform: translateY(-1px);
    }
    .file-input { display: none; }
    .status-list {
      margin-top: 28px;
      width: 100%;
      max-width: 560px;
    }
    .status-item {
      background: var(--card-bg);
      border-radius: 16px;
      padding: 16px 20px;
      margin-bottom: 12px;
      box-shadow: var(--shadow);
      display: flex;
      align-items: center;
      justify-content: space-between;
      border: 1px solid rgba(255, 255, 255, 0.8);
    }
    .file-name {
      font-size: 15px;
      font-weight: 600;
      max-width: 320px;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }
    .badge {
      font-size: 12px;
      padding: 4px 10px;
      border-radius: 20px;
      background: #E8F5E9;
      color: #2E7D32;
      font-weight: 600;
    }
    .progress-bar {
      width: 100%;
      height: 6px;
      background: #E8E2D5;
      border-radius: 3px;
      overflow: hidden;
      margin-top: 16px;
      display: none;
    }
    .progress-fill {
      height: 100%;
      background: var(--primary);
      width: 0%;
      transition: width 0.2s;
    }
  </style>
</head>
<body>
  <div class="header">
    <h1>🏛️ 藏书阁</h1>
    <p>局域网 WiFi 极速网页传书 · 自动入架与分章排版</p>
  </div>
  <div class="card">
    <div class="drop-zone" id="dropZone">
      <div class="icon">📖</div>
      <h3>拖拽 TXT 或 EPUB 文件到这里</h3>
      <p style="color: var(--subtext); font-size: 13px; margin-top: 6px;">支持任意大文件 TXT（自动正则分章）与精排 EPUB</p>
      <button class="btn" onclick="document.getElementById('fileInput').click()">选择本地文件</button>
      <input type="file" id="fileInput" class="file-input" accept=".txt,.epub" multiple>
    </div>
    <div class="progress-bar" id="progressBar">
      <div class="progress-fill" id="progressFill"></div>
    </div>
  </div>
  <div class="status-list" id="statusList"></div>

  <script>
    const dropZone = document.getElementById('dropZone');
    const fileInput = document.getElementById('fileInput');
    const progressBar = document.getElementById('progressBar');
    const progressFill = document.getElementById('progressFill');
    const statusList = document.getElementById('statusList');

    ['dragenter', 'dragover'].forEach(name => {
      dropZone.addEventListener(name, (e) => {
        e.preventDefault();
        dropZone.classList.add('dragover');
      });
    });
    ['dragleave', 'drop'].forEach(name => {
      dropZone.addEventListener(name, (e) => {
        e.preventDefault();
        dropZone.classList.remove('dragover');
      });
    });

    dropZone.addEventListener('drop', (e) => {
      const files = e.dataTransfer.files;
      if (files.length > 0) uploadFiles(files);
    });

    fileInput.addEventListener('change', () => {
      if (fileInput.files.length > 0) uploadFiles(fileInput.files);
    });

    async function uploadFiles(files) {
      progressBar.style.display = 'block';
      for (let i = 0; i < files.length; i++) {
        const file = files[i];
        progressFill.style.width = '20%';
        const formData = new FormData();
        formData.append('file', file, file.name);

        try {
          const res = await fetch('/api/upload?filename=' + encodeURIComponent(file.name), {
            method: 'POST',
            body: formData,
          });
          progressFill.style.width = '100%';
          const data = await res.json();
          addStatusItem(file.name, true);
        } catch (err) {
          addStatusItem(file.name, false);
        }
      }
      setTimeout(() => {
        progressBar.style.display = 'none';
        progressFill.style.width = '0%';
      }, 1000);
    }

    function addStatusItem(name, success) {
      const item = document.createElement('div');
      item.className = 'status-item';
      item.innerHTML = `
        <div class="file-name">\${name}</div>
        <div class="badge" style="background: \${success ? '#E8F5E9' : '#FFEBEE'}; color: \${success ? '#2E7D32' : '#C62828'}">
          \${success ? '✓ 已成功传输并入架' : '✕ 传输失败'}
        </div>
      `;
      statusList.prepend(item);
    }
  </script>
</body>
</html>
''';
}

class _MultipartResult {
  final String? filename;
  final Uint8List bytes;
  _MultipartResult({this.filename, required this.bytes});
}
