import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'network_utils.dart';
import 'received_files_service.dart';

class RemoteStreamItem {
  final String name;
  final String relativePath;
  final int sizeBytes;
  final bool isDirectory;
  final String extension;
  final String streamUrl;

  const RemoteStreamItem({
    required this.name,
    required this.relativePath,
    required this.sizeBytes,
    required this.isDirectory,
    required this.extension,
    required this.streamUrl,
  });

  String get formattedSize {
    if (isDirectory) return 'Folder';
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  factory RemoteStreamItem.fromJson(Map<String, dynamic> m, String baseUrl, String token) {
    final rel = m['relativePath']?.toString() ?? '';
    return RemoteStreamItem(
      name: m['name']?.toString() ?? 'item',
      relativePath: rel,
      sizeBytes: (m['sizeBytes'] as num?)?.toInt() ?? 0,
      isDirectory: m['isDirectory'] == true,
      extension: m['extension']?.toString() ?? '',
      streamUrl: '$baseUrl/stream?token=$token&path=${Uri.encodeQueryComponent(rel)}',
    );
  }
}

class LanStreamHostState {
  final bool isHosting;
  final String shareUrl;
  final String hostIp;
  final int port;
  final String token;
  final String rootPath;
  final int servedRequests;

  const LanStreamHostState({
    required this.isHosting,
    this.shareUrl = '',
    this.hostIp = '',
    this.port = 0,
    this.token = '',
    this.rootPath = '',
    this.servedRequests = 0,
  });

  static const LanStreamHostState stopped = LanStreamHostState(isHosting: false);
}

/// "Stream Without Downloading" Remote LAN Media & Folder Server + Client.
/// Hosts a token-authenticated HTTP/1.1 Range-streaming (206 Partial Content) folder
/// over local Wi-Fi (Rule 12: 128-bit cryptographic session token required on every request;
/// path traversal strictly rejected). Clients can browse and stream videos/audio/images/docs
/// directly over LAN using 0 MB of local phone storage.
class LanMediaStreamService {
  static final LanMediaStreamService _instance = LanMediaStreamService._internal();
  static LanMediaStreamService get instance => _instance;

  LanMediaStreamService._internal();

  HttpServer? _server;
  LanStreamHostState _state = LanStreamHostState.stopped;
  final StreamController<LanStreamHostState> _stateController =
      StreamController<LanStreamHostState>.broadcast();

  LanStreamHostState get currentState => _state;
  Stream<LanStreamHostState> get stateStream => _stateController.stream;

  Future<LanStreamHostState> startHostingFolder({
    String? directoryPath,
    int preferredPort = 0,
  }) async {
    await stopHosting();

    final rootDir = Directory(directoryPath ?? ReceivedFilesService.instance.saveDirectory.path);
    if (!rootDir.existsSync()) {
      rootDir.createSync(recursive: true);
    }

    final token = _generateToken();
    final hostIp = await NetworkUtils.getLocalIpAddress();

    _server = await HttpServer.bind(InternetAddress.anyIPv4, preferredPort, shared: true);
    final port = _server!.port;
    final shareUrl = 'http://$hostIp:$port/?token=$token';

    _state = LanStreamHostState(
      isHosting: true,
      shareUrl: shareUrl,
      hostIp: hostIp,
      port: port,
      token: token,
      rootPath: rootDir.path,
      servedRequests: 0,
    );
    _stateController.add(_state);

    _server!.listen((req) => _handleRequest(req, rootDir, token));
    return _state;
  }

  Future<void> stopHosting() async {
    try {
      await _server?.close(force: true);
    } catch (_) {}
    _server = null;
    _state = LanStreamHostState.stopped;
    _stateController.add(_state);
  }

  /// Client helper: queries a peer's LAN Stream host URL (`http://ip:port/?token=...`)
  /// and returns browsable items for zero-download streaming.
  Future<List<RemoteStreamItem>> fetchRemoteDirectory(
    String shareUrl, {
    String subPath = '',
  }) async {
    final uri = Uri.parse(shareUrl.trim());
    final token = uri.queryParameters['token'] ?? '';
    final baseUrl = '${uri.scheme}://${uri.host}:${uri.port}';
    final listUri = Uri.parse(
      '$baseUrl/api/list?token=${Uri.encodeQueryComponent(token)}&sub=${Uri.encodeQueryComponent(subPath)}',
    );

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    try {
      final request = await client.getUrl(listUri);
      final response = await request.close();
      if (response.statusCode != 200) {
        throw HttpException('Remote peer returned HTTP ${response.statusCode}');
      }
      final body = await utf8.decoder.bind(response).join();
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final rawItems = decoded['items'] as List<dynamic>? ?? const [];
      return rawItems
          .map((e) => RemoteStreamItem.fromJson(e as Map<String, dynamic>, baseUrl, token))
          .toList();
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _handleRequest(HttpRequest req, Directory rootDir, String expectedToken) async {
    try {
      final providedToken = req.uri.queryParameters['token'] ?? '';
      if (providedToken != expectedToken) {
        req.response.statusCode = HttpStatus.forbidden;
        req.response.write('403 Forbidden: Invalid or missing PeerLink stream token.');
        await req.response.close();
        return;
      }

      _state = LanStreamHostState(
        isHosting: _state.isHosting,
        shareUrl: _state.shareUrl,
        hostIp: _state.hostIp,
        port: _state.port,
        token: _state.token,
        rootPath: _state.rootPath,
        servedRequests: _state.servedRequests + 1,
      );
      _stateController.add(_state);

      final path = req.uri.path;
      if (path == '/api/list') {
        final sub = req.uri.queryParameters['sub'] ?? '';
        final targetDir = _safeResolveSubDir(rootDir, sub);
        if (targetDir == null || !targetDir.existsSync()) {
          req.response.statusCode = HttpStatus.notFound;
          await req.response.close();
          return;
        }
        final items = <Map<String, dynamic>>[];
        for (final entity in targetDir.listSync(recursive: false, followLinks: false)) {
          final name = entity.uri.pathSegments.where((s) => s.isNotEmpty).lastOrNull ?? '';
          if (name.startsWith('.')) continue;
          final rel = sub.isEmpty ? name : '$sub/$name';
          if (entity is Directory) {
            items.add({
              'name': name,
              'relativePath': rel,
              'sizeBytes': 0,
              'isDirectory': true,
              'extension': '',
            });
          } else if (entity is File) {
            final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
            items.add({
              'name': name,
              'relativePath': rel,
              'sizeBytes': entity.lengthSync(),
              'isDirectory': false,
              'extension': ext,
            });
          }
        }
        req.response.headers.contentType = ContentType.json;
        req.response.write(jsonEncode({'root': rootDir.path, 'sub': sub, 'items': items}));
        await req.response.close();
        return;
      }

      if (path == '/stream') {
        final rel = req.uri.queryParameters['path'] ?? '';
        final file = _safeResolveFile(rootDir, rel);
        if (file == null || !file.existsSync()) {
          req.response.statusCode = HttpStatus.notFound;
          await req.response.close();
          return;
        }
        await _serveFileWithRangeSupport(req, file);
        return;
      }

      // Root HTML zero-download streaming gallery
      req.response.headers.contentType = ContentType.html;
      req.response.write(_buildStreamPortalHtml(expectedToken));
      await req.response.close();
    } catch (_) {
      try {
        req.response.statusCode = HttpStatus.internalServerError;
        await req.response.close();
      } catch (_) {}
    }
  }

  /// HTTP 206 Partial Content Range streaming so videos & audio scrub seamlessly!
  Future<void> _serveFileWithRangeSupport(HttpRequest req, File file) async {
    final totalLength = await file.length();
    final ext = file.path.contains('.') ? file.path.split('.').last.toLowerCase() : '';
    req.response.headers.set('Accept-Ranges', 'bytes');
    req.response.headers.set('Content-Type', _mimeType(ext));

    final rangeHeader = req.headers.value(HttpHeaders.rangeHeader);
    if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
      final parts = rangeHeader.substring(6).split('-');
      final start = int.tryParse(parts[0]) ?? 0;
      final end = (parts.length > 1 && parts[1].isNotEmpty)
          ? (int.tryParse(parts[1]) ?? (totalLength - 1))
          : (totalLength - 1);
      final clampedStart = start.clamp(0, totalLength > 0 ? totalLength - 1 : 0);
      final clampedEnd = end.clamp(clampedStart, totalLength > 0 ? totalLength - 1 : 0);
      final chunkLen = totalLength == 0 ? 0 : (clampedEnd - clampedStart + 1);

      req.response.statusCode = HttpStatus.partialContent;
      req.response.headers.set('Content-Range', 'bytes $clampedStart-$clampedEnd/$totalLength');
      req.response.contentLength = chunkLen;
      await req.response.addStream(file.openRead(clampedStart, clampedEnd + 1));
      await req.response.close();
      return;
    }

    req.response.statusCode = HttpStatus.ok;
    req.response.contentLength = totalLength;
    await req.response.addStream(file.openRead());
    await req.response.close();
  }

  Directory? _safeResolveSubDir(Directory root, String sub) {
    final clean = sub.replaceAll('\\', '/').trim();
    if (clean.contains('..')) return null;
    if (clean.isEmpty) return root;
    final candidate = Directory('${root.path}${Platform.pathSeparator}$clean');
    final normRoot = root.absolute.path.replaceAll('\\', '/').toLowerCase();
    final normCand = candidate.absolute.path.replaceAll('\\', '/').toLowerCase();
    if (!normCand.startsWith(normRoot)) return null;
    return candidate;
  }

  File? _safeResolveFile(Directory root, String rel) {
    final clean = rel.replaceAll('\\', '/').trim();
    if (clean.isEmpty || clean.contains('..')) return null;
    final candidate = File('${root.path}${Platform.pathSeparator}$clean');
    final normRoot = root.absolute.path.replaceAll('\\', '/').toLowerCase();
    final normCand = candidate.absolute.path.replaceAll('\\', '/').toLowerCase();
    if (!normCand.startsWith(normRoot)) return null;
    return candidate;
  }

  String _mimeType(String ext) => switch (ext) {
        'mp4' => 'video/mp4',
        'webm' => 'video/webm',
        'mov' => 'video/quicktime',
        'mkv' => 'video/x-matroska',
        'mp3' => 'audio/mpeg',
        'wav' => 'audio/wav',
        'flac' => 'audio/flac',
        'ogg' => 'audio/ogg',
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        'gif' => 'image/gif',
        'pdf' => 'application/pdf',
        'txt' || 'md' || 'log' => 'text/plain; charset=utf-8',
        'json' => 'application/json; charset=utf-8',
        _ => 'application/octet-stream',
      };

  String _generateToken() {
    final rng = Random.secure();
    return List<int>.generate(16, (_) => rng.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  String _buildStreamPortalHtml(String token) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>PeerLink Stream — Zero Download</title>
<style>
body{margin:0;font-family:-apple-system,Segoe UI,Roboto,sans-serif;background:#f7f8fa;color:#0f172a;padding:20px}
.wrap{max-width:720px;margin:0 auto}
.card{background:#fff;border:1px solid #e5e7eb;border-radius:14px;padding:16px;margin-bottom:12px}
.row{display:flex;align-items:center;justify-content:space-between;padding:10px 0;border-bottom:1px solid #f1f5f9;gap:10px}
.btn{background:#2563eb;color:#fff;border:none;border-radius:8px;padding:6px 12px;font-weight:600;text-decoration:none;font-size:13px;cursor:pointer}
video,audio,img{max-width:100%;border-radius:10px;margin-top:10px;border:1px solid #e5e7eb}
</style>
</head>
<body>
<div class="wrap">
  <div class="card">
    <h2 style="margin:0 0 4px">PeerLink Stream</h2>
    <div style="font-size:13px;color:#64748b">Stream videos, audio, photos &amp; PDFs directly over Wi-Fi without downloading.</div>
    <div id="player"></div>
  </div>
  <div class="card" id="list">Loading folder...</div>
</div>
<script>
const token = "$token";
async function loadDir(sub="") {
  const res = await fetch("/api/list?token=" + encodeURIComponent(token) + "&sub=" + encodeURIComponent(sub));
  const data = await res.json();
  const el = document.getElementById("list");
  el.innerHTML = "";
  if (sub) {
    const up = sub.includes("/") ? sub.substring(0, sub.lastIndexOf("/")) : "";
    const b = document.createElement("button");
    b.className = "btn"; b.textContent = "Back";
    b.onclick = () => loadDir(up);
    el.appendChild(b);
  }
  for (const item of data.items) {
    const row = document.createElement("div"); row.className = "row";
    const title = document.createElement("span");
    title.textContent = (item.isDirectory ? "[Folder] " : "") + item.name;
    row.appendChild(title);
    const btn = document.createElement("button"); btn.className = "btn";
    if (item.isDirectory) {
      btn.textContent = "Open"; btn.onclick = () => loadDir(item.relativePath);
    } else {
      const url = "/stream?token=" + encodeURIComponent(token) + "&path=" + encodeURIComponent(item.relativePath);
      btn.textContent = "Stream";
      btn.onclick = () => {
        const p = document.getElementById("player");
        const e = (item.extension || "").toLowerCase();
        if (["mp4","webm","mov"].includes(e)) p.innerHTML = '<video controls autoplay src="'+url+'"></video>';
        else if (["mp3","wav","flac","ogg"].includes(e)) p.innerHTML = '<audio controls autoplay src="'+url+'"></audio>';
        else if (["jpg","jpeg","png","webp","gif"].includes(e)) p.innerHTML = '<img src="'+url+'"/>';
        else window.open(url, "_blank");
      };
    }
    row.appendChild(btn);
    el.appendChild(row);
  }
}
loadDir();
</script>
</body></html>
''';
  }
}
