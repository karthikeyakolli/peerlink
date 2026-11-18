import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import '../platform/android_node_bridge.dart';
import 'archive_extractor_service.dart';
import 'network_utils.dart';
import 'received_files_service.dart';

class WebBeamHostedFile {
  final String name;
  final String localPath;
  final int sizeBytes;
  final bool isTempCacheCopy;

  const WebBeamHostedFile({
    required this.name,
    required this.localPath,
    required this.sizeBytes,
    this.isTempCacheCopy = false,
  });

  String get formattedSize => WebBeamServerService.formatBytes(sizeBytes);
}

class WebBeamSessionState {
  final bool isRunning;
  final String portalUrl;
  final String hostIp;
  final int port;
  final String token;
  final List<WebBeamHostedFile> files;
  final int downloadCount;
  final int uploadCount;
  final String? lastUploadedFileName;
  final DateTime? expiresAt;
  final bool burnAfterDownload;
  final String? error;

  const WebBeamSessionState({
    required this.isRunning,
    this.portalUrl = '',
    this.hostIp = '',
    this.port = 0,
    this.token = '',
    this.files = const [],
    this.downloadCount = 0,
    this.uploadCount = 0,
    this.lastUploadedFileName,
    this.expiresAt,
    this.burnAfterDownload = false,
    this.error,
  });

  int get totalBytes => files.fold(0, (sum, f) => sum + f.sizeBytes);

  String get summaryFileName {
    if (files.isEmpty) return 'No files selected';
    if (files.length == 1) return files.first.name;
    return '${files.first.name} (+${files.length - 1} more)';
  }

  String get summaryFileSize => WebBeamServerService.formatBytes(totalBytes);

  static const WebBeamSessionState stopped = WebBeamSessionState(isRunning: false);
}

/// Real on-device embedded HTTP micro-portal for Zero-Install Browser Web Beam.
/// Binds directly on the phone or PC's Wi-Fi / Hotspot LAN interface, enforces a
/// cryptographically random 128-bit session token (Rule 12), and streams files
/// directly from local storage without touching any cloud or external PC.
class WebBeamServerService {
  static final WebBeamServerService _instance = WebBeamServerService._internal();
  static WebBeamServerService get instance => _instance;

  WebBeamServerService._internal();

  HttpServer? _server;
  Timer? _expiryTimer;
  WebBeamSessionState _state = WebBeamSessionState.stopped;

  final StreamController<WebBeamSessionState> _stateController =
      StreamController<WebBeamSessionState>.broadcast();

  WebBeamSessionState get currentState => _state;
  Stream<WebBeamSessionState> get stateStream => _stateController.stream;

  Future<WebBeamSessionState> start({
    required List<String> paths,
    int preferredPort = 8090,
    Duration ttl = const Duration(minutes: 15),
    String? overrideHostIp,
    bool burnAfterDownload = false,
  }) async {
    await stop();

    final hostedFiles = await _resolvePaths(paths);
    if (hostedFiles.isEmpty) {
      _emit(const WebBeamSessionState(
        isRunning: false,
        error: 'No readable files were found to host. Please pick at least one file.',
      ));
      return _state;
    }

    HttpServer server;
    try {
      server = await HttpServer.bind(
        InternetAddress.anyIPv4,
        preferredPort,
        shared: true,
      );
    } catch (_) {
      try {
        server = await HttpServer.bind(
          InternetAddress.anyIPv4,
          0,
          shared: true,
        );
      } catch (e) {
        _emit(WebBeamSessionState(
          isRunning: false,
          error: 'Could not start local Wi-Fi portal: $e',
        ));
        return _state;
      }
    }

    final hostIp = overrideHostIp ?? await NetworkUtils.getLocalIpAddress();
    final token = _generate128BitToken();
    final port = server.port;
    final portalUrl = 'http://$hostIp:$port/?token=$token';
    final expiresAt = DateTime.now().add(ttl);

    _server = server;
    _server!.listen(
      _handleRequest,
      onError: (_) {},
      cancelOnError: false,
    );

    _expiryTimer?.cancel();
    _expiryTimer = Timer(ttl, () {
      stop();
    });

    _emit(WebBeamSessionState(
      isRunning: true,
      portalUrl: portalUrl,
      hostIp: hostIp,
      port: port,
      token: token,
      files: List.unmodifiable(hostedFiles),
      downloadCount: 0,
      expiresAt: expiresAt,
      burnAfterDownload: burnAfterDownload,
    ));

    return _state;
  }

  Future<WebBeamSessionState> addFiles(List<String> paths) async {
    if (!_state.isRunning) {
      return start(paths: paths);
    }
    final newFiles = await _resolvePaths(paths);
    if (newFiles.isEmpty) return _state;

    final existingPaths = _state.files.map((f) => f.localPath).toSet();
    final merged = List<WebBeamHostedFile>.from(_state.files);
    for (final f in newFiles) {
      if (!existingPaths.contains(f.localPath)) {
        merged.add(f);
        existingPaths.add(f.localPath);
      }
    }

    _emit(WebBeamSessionState(
      isRunning: _state.isRunning,
      portalUrl: _state.portalUrl,
      hostIp: _state.hostIp,
      port: _state.port,
      token: _state.token,
      files: List.unmodifiable(merged),
      downloadCount: _state.downloadCount,
      uploadCount: _state.uploadCount,
      lastUploadedFileName: _state.lastUploadedFileName,
      expiresAt: _state.expiresAt,
    ));
    return _state;
  }

  Future<void> stop() async {
    _expiryTimer?.cancel();
    _expiryTimer = null;

    final prevFiles = _state.files;
    final server = _server;
    _server = null;

    if (server != null) {
      try {
        await server.close(force: true);
      } catch (_) {}
    }

    for (final f in prevFiles) {
      if (f.isTempCacheCopy) {
        try {
          final file = File(f.localPath);
          if (file.existsSync()) file.deleteSync();
        } catch (_) {}
      }
    }

    _emit(WebBeamSessionState.stopped);
  }

  Future<List<WebBeamHostedFile>> _resolvePaths(List<String> paths) async {
    final result = <WebBeamHostedFile>[];
    final seen = <String>{};

    for (final raw in paths) {
      final clean = raw.trim();
      if (clean.isEmpty) continue;

      if (clean.startsWith('content://')) {
        final resolved = await AndroidNodeBridge.instance.resolveContentUriToCacheFile(clean);
        if (resolved != null) {
          final localPath = resolved['path'] as String?;
          final name = resolved['name'] as String?;
          final size = (resolved['sizeBytes'] as num?)?.toInt() ?? 0;
          if (localPath != null && localPath.isNotEmpty && !seen.contains(localPath)) {
            seen.add(localPath);
            result.add(WebBeamHostedFile(
              name: (name != null && name.isNotEmpty) ? name : _basename(localPath),
              localPath: localPath,
              sizeBytes: size,
              isTempCacheCopy: true,
            ));
          }
        }
        continue;
      }

      try {
        final file = File(clean);
        if (file.existsSync()) {
          if (!seen.contains(file.path)) {
            seen.add(file.path);
            result.add(WebBeamHostedFile(
              name: _basename(file.path),
              localPath: file.path,
              sizeBytes: file.lengthSync(),
            ));
          }
          continue;
        }

        final dir = Directory(clean);
        if (dir.existsSync()) {
          for (final entity in dir.listSync(recursive: true, followLinks: false)) {
            if (entity is File) {
              final base = _basename(entity.path);
              if (base.startsWith('.') || base.endsWith('.part') || base.endsWith('.tmp')) {
                continue;
              }
              if (!seen.contains(entity.path)) {
                seen.add(entity.path);
                result.add(WebBeamHostedFile(
                  name: base,
                  localPath: entity.path,
                  sizeBytes: entity.lengthSync(),
                ));
              }
            }
          }
        }
      } catch (_) {}
    }

    return result;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final res = request.response;
    res.headers.set('X-Content-Type-Options', 'nosniff');
    res.headers.set('Cache-Control', 'no-store');

    try {
      if (!_state.isRunning) {
        res.statusCode = HttpStatus.serviceUnavailable;
        res.write('Web Beam Portal is stopped.');
        await res.close();
        return;
      }

      if (request.method != 'GET' && request.method != 'HEAD' && request.method != 'POST') {
        res.statusCode = HttpStatus.methodNotAllowed;
        res.write('Method Not Allowed');
        await res.close();
        return;
      }

      final providedToken = request.uri.queryParameters['token'] ?? '';
      if (!_constantTimeEquals(providedToken, _state.token)) {
        res.statusCode = HttpStatus.forbidden;
        res.headers.contentType = ContentType.text;
        res.write('403 Forbidden: Invalid or missing PeerLink Web Beam token.');
        await res.close();
        return;
      }

      final path = request.uri.path;
      if (request.method == 'POST' && path == '/upload') {
        await _handleUpload(request, res);
        return;
      }

      if (path == '/' || path.isEmpty) {
        res.statusCode = HttpStatus.ok;
        res.headers.contentType = ContentType.html;
        res.write(_buildPortalHtml());
        await res.close();
        return;
      }

      if (path == '/download-all.zip') {
        final paths = _state.files.map((f) => f.localPath).where((p) => File(p).existsSync()).toList();
        if (paths.isEmpty) {
          res.statusCode = HttpStatus.notFound;
          res.write('No files available to zip.');
          await res.close();
          return;
        }
        final zipPath =
            '${Directory.systemTemp.path}${Platform.pathSeparator}peerlink_beam_${DateTime.now().millisecondsSinceEpoch}.zip';
        try {
          await ArchiveExtractorService.instance.createZip(paths, zipPath);
          final zipFile = File(zipPath);
          res.statusCode = HttpStatus.ok;
          res.headers.set(HttpHeaders.contentTypeHeader, 'application/zip');
          res.headers.set(HttpHeaders.contentLengthHeader, zipFile.lengthSync().toString());
          res.headers.set('Content-Disposition', 'attachment; filename="PeerLink_Shared_Files.zip"');
          if (request.method != 'HEAD') {
            await res.addStream(zipFile.openRead());
          }
          await res.close();
          if (_state.burnAfterDownload) {
            unawaited(stop());
          }
        } finally {
          try {
            final f = File(zipPath);
            if (f.existsSync()) f.deleteSync();
          } catch (_) {}
        }
        return;
      }

      if (path.startsWith('/preview/')) {
        final idxStr = path.substring('/preview/'.length);
        final idx = int.tryParse(idxStr);
        if (idx == null || idx < 0 || idx >= _state.files.length) {
          res.statusCode = HttpStatus.notFound;
          await res.close();
          return;
        }
        final hosted = _state.files[idx];
        final file = File(hosted.localPath);
        if (!file.existsSync()) {
          res.statusCode = HttpStatus.notFound;
          await res.close();
          return;
        }
        final totalLen = file.lengthSync();
        res.headers.set(HttpHeaders.contentTypeHeader, _mimeTypeForFile(hosted.name));
        res.headers.set('Accept-Ranges', 'bytes');
        res.headers.set('Content-Disposition', 'inline');
        final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);
        if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
          final parts = rangeHeader.substring(6).split('-');
          final start = (int.tryParse(parts[0]) ?? 0).clamp(0, totalLen > 0 ? totalLen - 1 : 0);
          final end = (parts.length > 1 && parts[1].isNotEmpty)
              ? (int.tryParse(parts[1]) ?? (totalLen - 1)).clamp(start, totalLen > 0 ? totalLen - 1 : 0)
              : (totalLen > 0 ? totalLen - 1 : 0);
          res.statusCode = HttpStatus.partialContent;
          res.headers.set('Content-Range', 'bytes $start-$end/$totalLen');
          res.headers.set(HttpHeaders.contentLengthHeader, (totalLen == 0 ? 0 : end - start + 1).toString());
          if (request.method != 'HEAD') {
            await res.addStream(file.openRead(start, end + 1));
          }
          await res.close();
          return;
        }
        res.statusCode = HttpStatus.ok;
        res.headers.set(HttpHeaders.contentLengthHeader, totalLen.toString());
        if (request.method != 'HEAD') {
          await res.addStream(file.openRead());
        }
        await res.close();
        return;
      }

      if (path.startsWith('/download/')) {
        final idxStr = path.substring('/download/'.length);
        final idx = int.tryParse(idxStr);
        if (idx == null || idx < 0 || idx >= _state.files.length) {
          res.statusCode = HttpStatus.notFound;
          res.write('File not found.');
          await res.close();
          return;
        }

        final hosted = _state.files[idx];
        final file = File(hosted.localPath);
        if (!file.existsSync()) {
          res.statusCode = HttpStatus.notFound;
          res.write('File is no longer available on sender device.');
          await res.close();
          return;
        }

        final length = file.lengthSync();
        final safeFilename = hosted.name.replaceAll('"', '_').replaceAll('\r', '').replaceAll('\n', '');
        final encodedFilename = Uri.encodeComponent(hosted.name);

        res.statusCode = HttpStatus.ok;
        res.headers.set(HttpHeaders.contentTypeHeader, _mimeTypeForFile(hosted.name));
        res.headers.set(HttpHeaders.contentLengthHeader, length.toString());
        res.headers.set(
          'Content-Disposition',
          'attachment; filename="$safeFilename"; filename*=UTF-8\'\'$encodedFilename',
        );

        if (request.method == 'HEAD') {
          await res.close();
          return;
        }

        await res.addStream(file.openRead());

        if (_state.isRunning) {
          final shouldBurn = _state.burnAfterDownload;
          _emit(WebBeamSessionState(
            isRunning: _state.isRunning,
            portalUrl: _state.portalUrl,
            hostIp: _state.hostIp,
            port: _state.port,
            token: _state.token,
            files: _state.files,
            downloadCount: _state.downloadCount + 1,
            uploadCount: _state.uploadCount,
            lastUploadedFileName: _state.lastUploadedFileName,
            expiresAt: _state.expiresAt,
            burnAfterDownload: _state.burnAfterDownload,
          ));
          await res.close();
          if (shouldBurn) {
            unawaited(stop());
          }
          return;
        }

        await res.close();
        return;
      }

      res.statusCode = HttpStatus.notFound;
      res.write('Not Found');
      await res.close();
    } catch (_) {
      try {
        res.statusCode = HttpStatus.internalServerError;
        await res.close();
      } catch (_) {}
    }
  }

  /// Streams an uploaded file directly from a Windows PC or mobile browser into
  /// PeerLink's local Vault using atomic .part staging and strict filename sanitization.
  Future<void> _handleUpload(HttpRequest request, HttpResponse res) async {
    final rawName = request.uri.queryParameters['name'] ??
        request.headers.value('x-file-name') ??
        'uploaded_${DateTime.now().millisecondsSinceEpoch}.bin';
    final safeName = sanitizeUploadFileName(rawName);

    final saveDir = ReceivedFilesService.instance.saveDirectory;
    if (!saveDir.existsSync()) {
      saveDir.createSync(recursive: true);
    }

    // Non-destructive collision avoidance
    File targetFile = File('${saveDir.path}${Platform.pathSeparator}$safeName');
    if (targetFile.existsSync()) {
      final dot = safeName.lastIndexOf('.');
      final stem = dot > 0 ? safeName.substring(0, dot) : safeName;
      final ext = dot > 0 ? safeName.substring(dot) : '';
      int suffix = 1;
      while (targetFile.existsSync()) {
        targetFile = File('${saveDir.path}${Platform.pathSeparator}$stem ($suffix)$ext');
        suffix++;
      }
    }

    final partFile = File('${targetFile.path}.part');
    IOSink? sink;
    int totalBytes = 0;
    try {
      sink = partFile.openWrite();
      await for (final chunk in request) {
        sink.add(chunk);
        totalBytes += chunk.length;
      }
      await sink.flush();
      await sink.close();
      sink = null;

      await partFile.rename(targetFile.path);
      final finalName = _basename(targetFile.path);
      if (Platform.isAndroid) {
        await AndroidNodeBridge.instance.scanMediaFile(targetFile.path);
      }

      if (_state.isRunning) {
        _emit(WebBeamSessionState(
          isRunning: _state.isRunning,
          portalUrl: _state.portalUrl,
          hostIp: _state.hostIp,
          port: _state.port,
          token: _state.token,
          files: _state.files,
          downloadCount: _state.downloadCount,
          uploadCount: _state.uploadCount + 1,
          lastUploadedFileName: finalName,
          expiresAt: _state.expiresAt,
        ));
      }

      res.statusCode = HttpStatus.ok;
      res.headers.contentType = ContentType.json;
      res.write(jsonEncode({
        'ok': true,
        'name': finalName,
        'sizeBytes': totalBytes,
      }));
      await res.close();
    } catch (e) {
      try {
        await sink?.close();
      } catch (_) {}
      try {
        if (partFile.existsSync()) partFile.deleteSync();
      } catch (_) {}
      res.statusCode = HttpStatus.internalServerError;
      res.headers.contentType = ContentType.json;
      res.write(jsonEncode({'ok': false, 'error': e.toString()}));
      await res.close();
    }
  }

  /// Strips directory separators, traversal segments, and illegal characters from browser upload names.
  static String sanitizeUploadFileName(String raw) {
    final decoded = Uri.decodeComponent(raw).trim();
    final base = decoded.split(RegExp(r'[\\/]')).where((s) => s.isNotEmpty && s != '.' && s != '..').toList();
    final candidate = base.isNotEmpty ? base.last : 'uploaded_file.bin';
    final cleaned = candidate.replaceAll(RegExp(r'[<>:"|?*\x00-\x1F]'), '_').trim();
    if (cleaned.isEmpty || cleaned == '.' || cleaned == '..') {
      return 'uploaded_file.bin';
    }
    return cleaned;
  }

  String _buildPortalHtml() {
    final buffer = StringBuffer();
    final escapedToken = _htmlEscape(_state.token);
    buffer.writeln('<!DOCTYPE html>');
    buffer.writeln('<html lang="en">');
    buffer.writeln('<head>');
    buffer.writeln('<meta charset="UTF-8">');
    buffer.writeln('<meta name="viewport" content="width=device-width, initial-scale=1.0">');
    buffer.writeln('<title>PeerLink Web Beam</title>');
    buffer.writeln('<style>');
    buffer.writeln('*{box-sizing:border-box;margin:0;padding:0;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;}');
    buffer.writeln('body{background:#F7F8FA;color:#0F172A;min-height:100vh;padding:24px 16px;display:flex;justify-content:center;}');
    buffer.writeln('.wrap{width:100%;max-width:560px;}');
    buffer.writeln('.hdr{margin-bottom:20px;}');
    buffer.writeln('.badge{display:inline-block;font-size:11px;font-weight:700;color:#2563EB;background:#EFF6FF;border:1px solid #DBEAFE;padding:4px 10px;border-radius:999px;margin-bottom:10px;}');
    buffer.writeln('h1{font-size:22px;font-weight:700;letter-spacing:-0.3px;margin-bottom:4px;}');
    buffer.writeln('.sub{font-size:13px;color:#64748B;}');
    buffer.writeln('.card{background:#FFFFFF;border:1px solid #E5E7EB;border-radius:14px;padding:14px 16px;margin-bottom:10px;display:flex;align-items:center;justify-content:space-between;gap:12px;}');
    buffer.writeln('.meta{min-width:0;flex:1;}');
    buffer.writeln('.fname{font-size:14px;font-weight:600;color:#0F172A;word-break:break-word;}');
    buffer.writeln('.fsize{font-size:12px;color:#64748B;margin-top:2px;}');
    buffer.writeln('.btn{display:inline-block;background:#2563EB;color:#FFFFFF;text-decoration:none;font-size:13px;font-weight:600;padding:9px 16px;border-radius:10px;white-space:nowrap;}');
    buffer.writeln('.btn:hover{background:#1D4ED8;}');
    buffer.writeln('.foot{margin-top:20px;font-size:12px;color:#64748B;text-align:center;}');
    buffer.writeln('</style>');
    buffer.writeln('</head>');
    buffer.writeln('<body>');
    buffer.writeln('<div class="wrap">');
    buffer.writeln('<div class="hdr">');
    buffer.writeln('<div class="badge">PeerLink Direct LAN Transfer${_state.burnAfterDownload ? " • Burn After Download" : ""}</div>');
    buffer.writeln('<h1>Shared Files (${_state.files.length})</h1>');
    buffer.writeln('<p class="sub">Direct Wi-Fi media gallery &amp; transfer straight from sender — no cloud, no app install required.</p>');
    if (_state.files.length > 1) {
      buffer.writeln('<div style="margin-top:12px;"><a class="btn" href="/download-all.zip?token=$escapedToken" download>Download All as ZIP (${_state.files.length} files)</a></div>');
    }
    buffer.writeln('</div>');

    for (int i = 0; i < _state.files.length; i++) {
      final f = _state.files[i];
      final safeName = _htmlEscape(f.name);
      final safeSize = _htmlEscape(f.formattedSize);
      final ext = f.name.contains('.') ? f.name.split('.').last.toLowerCase() : '';
      final previewUrl = '/preview/$i?token=$escapedToken';
      final isImg = const {'jpg', 'jpeg', 'png', 'webp', 'gif'}.contains(ext);
      final isVid = const {'mp4', 'webm', 'mov'}.contains(ext);
      final isAud = const {'mp3', 'wav', 'flac', 'ogg', 'm4a'}.contains(ext);

      buffer.writeln('<div class="card" style="flex-direction:column;align-items:stretch;">');
      buffer.writeln('<div style="display:flex;align-items:center;justify-content:space-between;gap:12px;">');
      buffer.writeln('<div class="meta"><div class="fname">$safeName</div><div class="fsize">$safeSize</div></div>');
      buffer.writeln('<a class="btn" href="/download/$i?token=$escapedToken" download>Download</a>');
      buffer.writeln('</div>');
      if (isImg) {
        buffer.writeln('<img src="$previewUrl" alt="$safeName" style="width:100%;max-height:320px;object-fit:contain;border-radius:10px;border:1px solid #E5E7EB;background:#F8FAFC;margin-top:10px;">');
      } else if (isVid) {
        buffer.writeln('<video controls preload="metadata" src="$previewUrl" style="width:100%;max-height:320px;border-radius:10px;border:1px solid #E5E7EB;margin-top:10px;"></video>');
      } else if (isAud) {
        buffer.writeln('<audio controls preload="metadata" src="$previewUrl" style="width:100%;margin-top:10px;"></audio>');
      }
      buffer.writeln('</div>');
    }

    buffer.writeln('<div class="card" style="flex-direction:column;align-items:stretch;margin-top:16px;">');
    buffer.writeln('<div class="fname" style="margin-bottom:4px;">Send files back to PeerLink (Windows / Mobile)</div>');
    buffer.writeln('<div class="fsize" style="margin-bottom:10px;">Select files from this device to upload directly over local Wi-Fi into the PeerLink Vault.</div>');
    buffer.writeln('<input id="plFile" type="file" multiple style="margin-bottom:10px;font-size:13px;">');
    buffer.writeln('<button id="plSend" class="btn" style="border:none;cursor:pointer;text-align:center;">Upload Selected Files</button>');
    buffer.writeln('<div id="plStatus" class="fsize" style="margin-top:8px;"></div>');
    buffer.writeln('</div>');
    buffer.writeln('<script>');
    buffer.writeln('document.getElementById("plSend").addEventListener("click", async function(){');
    buffer.writeln('  const input=document.getElementById("plFile");');
    buffer.writeln('  const status=document.getElementById("plStatus");');
    buffer.writeln('  if(!input.files||input.files.length===0){status.textContent="Pick at least one file first.";return;}');
    buffer.writeln('  let ok=0;');
    buffer.writeln('  for(const f of input.files){');
    buffer.writeln('    status.textContent="Uploading "+f.name+"...";');
    buffer.writeln('    const r=await fetch("/upload?token=$escapedToken&name="+encodeURIComponent(f.name),{method:"POST",body:f});');
    buffer.writeln('    if(r.ok){ok++;}else{status.textContent="Failed uploading "+f.name;return;}');
    buffer.writeln('  }');
    buffer.writeln('  status.textContent="Uploaded "+ok+" file(s) directly to PeerLink Vault!";');
    buffer.writeln('  input.value="";');
    buffer.writeln('});');
    buffer.writeln('</script>');

    buffer.writeln('<div class="foot">128-bit Token Protected • Direct Local Wi-Fi (${_htmlEscape(_state.hostIp)}:${_state.port})</div>');
    buffer.writeln('</div>');
    buffer.writeln('</body></html>');
    return buffer.toString();
  }

  void _emit(WebBeamSessionState next) {
    _state = next;
    if (!_stateController.isClosed) {
      _stateController.add(next);
    }
  }

  static String _generate128BitToken() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static bool _constantTimeEquals(String a, String b) {
    final aBytes = utf8.encode(a);
    final bBytes = utf8.encode(b);
    if (aBytes.length != bBytes.length || aBytes.isEmpty) return false;
    int diff = 0;
    for (int i = 0; i < aBytes.length; i++) {
      diff |= aBytes[i] ^ bBytes[i];
    }
    return diff == 0;
  }

  static String _basename(String path) {
    final parts = path.split(RegExp(r'[\\/]')).where((s) => s.isNotEmpty).toList();
    return parts.isNotEmpty ? parts.last : 'file';
  }

  static String _htmlEscape(String input) {
    return const HtmlEscape().convert(input);
  }

  static String _mimeTypeForFile(String name) {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'mp4':
        return 'video/mp4';
      case 'mkv':
        return 'video/x-matroska';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'pdf':
        return 'application/pdf';
      case 'txt':
        return 'text/plain; charset=utf-8';
      case 'json':
        return 'application/json; charset=utf-8';
      case 'zip':
        return 'application/zip';
      case 'apk':
        return 'application/vnd.android.package-archive';
      default:
        return 'application/octet-stream';
    }
  }

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
