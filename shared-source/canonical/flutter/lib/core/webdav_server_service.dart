import 'dart:convert';
import 'dart:io';

class WebDavStartResult {
  final bool isRunning;
  final int port;
  final String username;
  final String password;
  final String? errorMessage;

  const WebDavStartResult({
    required this.isRunning,
    required this.port,
    required this.username,
    required this.password,
    this.errorMessage,
  });
}

class WebDavServerService {
  WebDavServerService._();
  static final WebDavServerService instance = WebDavServerService._();

  HttpServer? _server;
  Directory? _rootDir;
  String? _username;
  String? _password;

  bool get isRunning => _server != null;
  int get port => _server?.port ?? 0;
  String? get username => _username;
  String? get password => _password;

  Future<WebDavStartResult> start({
    required Directory rootDirectory,
    required String username,
    required String password,
    int port = 0,
  }) async {
    await stop();

    _rootDir = rootDirectory;
    _username = username;
    _password = password;

    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      _server!.listen(_handleHttpRequest);

      return WebDavStartResult(
        isRunning: true,
        port: _server!.port,
        username: username,
        password: password,
      );
    } catch (e) {
      return WebDavStartResult(
        isRunning: false,
        port: 0,
        username: username,
        password: password,
        errorMessage: 'Failed to bind WebDAV server: $e',
      );
    }
  }

  Future<void> stop() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
    }
  }

  String getWindowsMountCommand({required String ip, String driveLetter = 'P:'}) {
    final p = port;
    final u = _username ?? 'peerlink';
    final pass = _password ?? '';
    return 'net use $driveLetter http://$ip:$p/ /user:$u $pass';
  }

  void _handleHttpRequest(HttpRequest request) async {
    final response = request.response;

    // Rule 12: Authenticate every request
    final authHeader = request.headers.value('Authorization');
    final expectedAuth = 'Basic ${base64Encode(utf8.encode('$_username:$_password'))}';

    if (authHeader == null || authHeader != expectedAuth) {
      response.statusCode = HttpStatus.unauthorized;
      response.headers.set('WWW-Authenticate', 'Basic realm="PeerLink WebDAV Vault"');
      response.headers.set('Content-Type', 'text/plain');
      response.write('401 Unauthorized');
      await response.close();
      return;
    }

    final method = request.method.toUpperCase();
    final path = Uri.decodeComponent(request.uri.path);
    final targetEntity = _resolvePath(path);

    try {
      switch (method) {
        case 'OPTIONS':
          response.statusCode = HttpStatus.ok;
          response.headers.set('DAV', '1, 2');
          response.headers.set('MS-Author-Via', 'DAV');
          response.headers.set('Allow', 'OPTIONS, GET, HEAD, PROPFIND, PUT, DELETE, MKCOL, MOVE, COPY');
          await response.close();
          break;

        case 'PROPFIND':
          await _handlePropfind(request, response, targetEntity, path);
          break;

        case 'GET':
        case 'HEAD':
          await _handleGet(request, response, targetEntity);
          break;

        case 'PUT':
          await _handlePut(request, response, targetEntity);
          break;

        case 'MKCOL':
          await _handleMkcol(response, targetEntity);
          break;

        case 'DELETE':
          await _handleDelete(response, targetEntity);
          break;

        case 'MOVE':
        case 'COPY':
          await _handleMoveCopy(request, response, targetEntity, isMove: method == 'MOVE');
          break;

        default:
          response.statusCode = HttpStatus.methodNotAllowed;
          await response.close();
      }
    } catch (e) {
      try {
        response.statusCode = HttpStatus.internalServerError;
        response.write('Error: $e');
        await response.close();
      } catch (_) {}
    }
  }

  FileSystemEntity _resolvePath(String relativePath) {
    var clean = relativePath.trim();
    if (clean.startsWith('/')) clean = clean.substring(1);
    if (clean.isEmpty) return _rootDir!;
    return File('${_rootDir!.path}${Platform.pathSeparator}${clean.replaceAll('/', Platform.pathSeparator)}');
  }

  Future<void> _handlePropfind(
    HttpRequest request,
    HttpResponse response,
    FileSystemEntity target,
    String requestPath,
  ) async {
    response.statusCode = 207; // Multi-Status
    response.headers.set('Content-Type', 'application/xml; charset="utf-8"');

    final xml = StringBuffer();
    xml.writeln('<?xml version="1.0" encoding="utf-8" ?>');
    xml.writeln('<D:multistatus xmlns:D="DAV:">');

    void appendResponse(FileSystemEntity entity, String href) {
      final isDir = FileSystemEntity.isDirectorySync(entity.path);
      final stat = entity.statSync();
      final name = entity.uri.pathSegments.where((s) => s.isNotEmpty).lastOrNull ?? '';

      xml.writeln('  <D:response>');
      xml.writeln('    <D:href>$href</D:href>');
      xml.writeln('    <D:propstat>');
      xml.writeln('      <D:prop>');
      xml.writeln('        <D:displayname>${_escapeXml(name)}</D:displayname>');
      if (isDir) {
        xml.writeln('        <D:resourcetype><D:collection/></D:resourcetype>');
      } else {
        xml.writeln('        <D:resourcetype/>');
        xml.writeln('        <D:getcontentlength>${stat.size}</D:getcontentlength>');
      }
      xml.writeln('        <D:getlastmodified>${stat.modified.toUtc().toIso8601String()}</D:getlastmodified>');
      xml.writeln('      </D:prop>');
      xml.writeln('      <D:status>HTTP/1.1 200 OK</D:status>');
      xml.writeln('    </D:propstat>');
      xml.writeln('  </D:response>');
    }

    // Append target itself
    appendResponse(target, requestPath.isEmpty ? '/' : requestPath);

    // If directory, append immediate children
    if (FileSystemEntity.isDirectorySync(target.path)) {
      final dir = Directory(target.path);
      for (final child in dir.listSync(followLinks: false)) {
        final childName = child.uri.pathSegments.where((s) => s.isNotEmpty).last;
        final childHref = requestPath.endsWith('/') ? '$requestPath$childName' : '$requestPath/$childName';
        appendResponse(child, childHref);
      }
    }

    xml.writeln('</D:multistatus>');
    response.write(xml.toString());
    await response.close();
  }

  Future<void> _handleGet(HttpRequest request, HttpResponse response, FileSystemEntity target) async {
    if (!target.existsSync() || FileSystemEntity.isDirectorySync(target.path)) {
      response.statusCode = HttpStatus.notFound;
      await response.close();
      return;
    }

    final file = File(target.path);
    response.statusCode = HttpStatus.ok;
    response.headers.set('Content-Length', file.lengthSync().toString());
    response.headers.set('Accept-Ranges', 'bytes');
    await response.addStream(file.openRead());
    await response.close();
  }

  Future<void> _handlePut(HttpRequest request, HttpResponse response, FileSystemEntity target) async {
    final file = File(target.path);
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }

    final sink = file.openWrite();
    await sink.addStream(request);
    await sink.close();

    response.statusCode = HttpStatus.created;
    await response.close();
  }

  Future<void> _handleMkcol(HttpResponse response, FileSystemEntity target) async {
    final dir = Directory(target.path);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
      response.statusCode = HttpStatus.created;
    } else {
      response.statusCode = HttpStatus.methodNotAllowed;
    }
    await response.close();
  }

  Future<void> _handleDelete(HttpResponse response, FileSystemEntity target) async {
    if (!target.existsSync()) {
      response.statusCode = HttpStatus.notFound;
    } else {
      if (FileSystemEntity.isDirectorySync(target.path)) {
        Directory(target.path).deleteSync(recursive: true);
      } else {
        File(target.path).deleteSync();
      }
      response.statusCode = HttpStatus.noContent;
    }
    await response.close();
  }

  Future<void> _handleMoveCopy(
    HttpRequest request,
    HttpResponse response,
    FileSystemEntity target, {
    required bool isMove,
  }) async {
    final destHeader = request.headers.value('Destination');
    if (destHeader == null || !target.existsSync()) {
      response.statusCode = HttpStatus.badRequest;
      await response.close();
      return;
    }

    final destUri = Uri.parse(destHeader);
    final destEntity = _resolvePath(destUri.path);

    if (isMove) {
      if (FileSystemEntity.isDirectorySync(target.path)) {
        Directory(target.path).renameSync(destEntity.path);
      } else {
        File(target.path).renameSync(destEntity.path);
      }
    } else {
      if (FileSystemEntity.isDirectorySync(target.path)) {
        // Simple directory copy
        _copyDirectorySync(Directory(target.path), Directory(destEntity.path));
      } else {
        File(target.path).copySync(destEntity.path);
      }
    }

    response.statusCode = HttpStatus.created;
    await response.close();
  }

  void _copyDirectorySync(Directory src, Directory dst) {
    if (!dst.existsSync()) dst.createSync(recursive: true);
    for (final it in src.listSync(recursive: false)) {
      final name = it.uri.pathSegments.where((s) => s.isNotEmpty).last;
      if (it is Directory) {
        _copyDirectorySync(it, Directory('${dst.path}/$name'));
      } else if (it is File) {
        it.copySync('${dst.path}/$name');
      }
    }
  }

  String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
