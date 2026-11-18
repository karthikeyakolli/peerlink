import 'dart:async';
import 'package:flutter/services.dart';
import 'platform_capabilities.dart';
import '../core/file_staging_service.dart';
import '../core/quick_text_service.dart';
import '../core/pairing_invitation.dart';

enum AndroidNodeStateEnum {
  active,
  backgroundCapable,
  osRestricted,
  unavailable,
  unknown,
}

enum NodeLifecycleStateEnum {
  stopped,
  starting,
  checkingCapabilities,
  recovering,
  discovering,
  ready,
  connected,
  transferring,
  degraded,
  unavailable,
  stopping,
  unknown;

  bool get isOperational =>
      this == ready ||
      this == connected ||
      this == transferring ||
      this == discovering ||
      this == degraded;

  bool get canAcceptTransfers =>
      this == ready || this == connected || this == discovering;

  bool get isTransferring => this == transferring;
}

class NodeCapabilities {
  final List<String> availableNetworkInterfaces;
  final List<String> activeListeners;
  final List<String> usableTransports;
  final List<String> missingPermissions;
  final String backgroundTransferLimitations;
  final Map<String, bool> supportedFeatures;
  final bool isHardwareSigning;
  final String securityLevel;
  final bool canTransfer;

  const NodeCapabilities({
    required this.availableNetworkInterfaces,
    required this.activeListeners,
    required this.usableTransports,
    required this.missingPermissions,
    required this.backgroundTransferLimitations,
    required this.supportedFeatures,
    required this.isHardwareSigning,
    required this.securityLevel,
    required this.canTransfer,
  });

  factory NodeCapabilities.fromMap(Map<dynamic, dynamic> map) {
    return NodeCapabilities(
      availableNetworkInterfaces:
          (map['availableNetworkInterfaces'] as List<dynamic>?)?.cast<String>() ??
              [],
      activeListeners:
          (map['activeListeners'] as List<dynamic>?)?.cast<String>() ?? [],
      usableTransports:
          (map['usableTransports'] as List<dynamic>?)?.cast<String>() ?? [],
      missingPermissions:
          (map['missingPermissions'] as List<dynamic>?)?.cast<String>() ?? [],
      backgroundTransferLimitations:
          map['backgroundTransferLimitations'] as String? ?? 'None',
      supportedFeatures: (map['supportedFeatures'] as Map<dynamic, dynamic>?)?.map(
            (k, v) => MapEntry(k.toString(), v == true),
          ) ??
          {},
      isHardwareSigning: map['isHardwareSigning'] as bool? ?? false,
      securityLevel: map['securityLevel'] as String? ?? 'UNKNOWN',
      canTransfer: map['canTransfer'] as bool? ?? false,
    );
  }
}

class PeerRouteInfo {
  final String host;
  final int port;
  final String technology;
  final List<String> transports;
  final int priority;
  final int lastSeenMs;
  final bool isHealthy;

  const PeerRouteInfo({
    required this.host,
    required this.port,
    required this.technology,
    this.transports = const [],
    this.priority = 5,
    this.lastSeenMs = 0,
    this.isHealthy = true,
  });

  factory PeerRouteInfo.fromMap(Map<dynamic, dynamic> map) {
    return PeerRouteInfo(
      host: map['host'] as String? ?? '127.0.0.1',
      port: (map['port'] as num?)?.toInt() ?? 8765,
      technology: map['technology'] as String? ?? 'UNKNOWN',
      transports: (map['transports'] as List<dynamic>?)?.cast<String>() ?? const [],
      priority: (map['priority'] as num?)?.toInt() ?? 5,
      lastSeenMs: (map['lastSeenMs'] as num?)?.toInt() ?? 0,
      isHealthy: map['isHealthy'] as bool? ?? true,
    );
  }
}

class DiscoveredPeer {
  final String peerId;
  final String name;
  final String host;
  final int port;
  final String technology;
  final List<String> technologies;
  final List<String> transports;
  final String connectionState;
  final List<PeerRouteInfo> routes;
  final int lastSeenMs;

  const DiscoveredPeer({
    required this.peerId,
    required this.name,
    required this.host,
    required this.port,
    required this.technology,
    this.technologies = const [],
    this.transports = const [],
    this.connectionState = 'DISCOVERED',
    this.routes = const [],
    this.lastSeenMs = 0,
  });

  bool get isConnected => connectionState == 'AUTHENTICATED_CONNECTED';

  factory DiscoveredPeer.fromMap(Map<dynamic, dynamic> map) {
    final routesRaw = map['routes'] as List<dynamic>? ?? [];
    return DiscoveredPeer(
      peerId: map['peerId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      host: map['host'] as String? ?? '127.0.0.1',
      port: (map['port'] as num?)?.toInt() ?? 8765,
      technology: map['technology'] as String? ?? 'UNKNOWN',
      technologies: (map['technologies'] as List<dynamic>?)?.cast<String>() ?? const [],
      transports: (map['transports'] as List<dynamic>?)?.cast<String>() ?? const [],
      connectionState: map['connectionState'] as String? ?? 'DISCOVERED',
      routes: routesRaw
          .map((r) => PeerRouteInfo.fromMap(r as Map<dynamic, dynamic>))
          .toList(),
      lastSeenMs: (map['lastSeenMs'] as num?)?.toInt() ?? 0,
    );
  }
}

class AndroidNodeBridge {
  static const MethodChannel _methodChannel =
      MethodChannel('org.peerlink/android_node_methods');
  static const EventChannel _eventChannel =
      EventChannel('org.peerlink/android_node_events');

  static final AndroidNodeBridge instance = AndroidNodeBridge._();

  final StreamController<List<String>> _sharedFilesController =
      StreamController<List<String>>.broadcast();

  Stream<List<String>> get sharedFilesStream => _sharedFilesController.stream;

  final StreamController<Map<String, dynamic>> _incomingTransferIntentController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get incomingTransferIntentStream =>
      _incomingTransferIntentController.stream;

  final Map<String, DiscoveredPeer> _discoveredPeers = {};
  StreamController<List<DiscoveredPeer>>? _discoveredPeersController;
  StreamSubscription? _discoveryEventsSub;

  Stream<List<DiscoveredPeer>> get discoveredPeersStream {
    _discoveredPeersController ??= StreamController<List<DiscoveredPeer>>.broadcast(
      onListen: () {
        _subscribeDiscoveryEvents();
      },
      onCancel: () {
        _discoveryEventsSub?.cancel();
        _discoveryEventsSub = null;
      },
    );
    return _discoveredPeersController!.stream;
  }

  void _subscribeDiscoveryEvents() {
    _discoveryEventsSub ??= events.listen((event) {
      final type = event['type'] as String?;
      if (type == 'peerDiscovered') {
        final peer = DiscoveredPeer.fromMap(event);
        _discoveredPeers[peer.peerId] = peer;
        _discoveredPeersController?.add(_discoveredPeers.values.toList());
      } else if (type == 'peerLost') {
        final peerId = event['peerId'] as String?;
        if (peerId != null) {
          _discoveredPeers.remove(peerId);
          _discoveredPeersController?.add(_discoveredPeers.values.toList());
        }
      }
    });
  }

  List<DiscoveredPeer> get activeDiscoveredPeers => _discoveredPeers.values.toList();

  AndroidNodeBridge._() {
    _methodChannel.setMethodCallHandler((call) async {
      if (call.method == 'onFilesSharedViaIntent') {
        final args = call.arguments as Map<dynamic, dynamic>?;
        final uris = (args?['uris'] as List<dynamic>?)?.cast<String>() ?? [];
        if (uris.isNotEmpty) {
          FileStagingService.instance.addPaths(uris);
          _sharedFilesController.add(uris);
        }
      } else if (call.method == 'onTextSharedViaIntent') {
        final args = call.arguments as Map<dynamic, dynamic>?;
        final text = args?['text'] as String?;
        if (text != null && text.isNotEmpty) {
          QuickTextService.instance.addSnippet(text);
        }
      } else if (call.method == 'onIncomingTransferIntent') {
        final args = call.arguments as Map<dynamic, dynamic>?;
        if (args != null) {
          _incomingTransferIntentController.add(args.cast<String, dynamic>());
        }
      }
    });
  }

  Future<List<String>> pickContentUris({String? category}) async {
    try {
      final List<dynamic>? res =
          await _methodChannel.invokeMethod<List<dynamic>>(
        'pickContentUris',
        category != null ? {'category': category} : null,
      );
      if (res != null) {
        return res.cast<String>();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<String>> pickCategoryContentUris(String category) =>
      pickContentUris(category: category);


  StreamController<Map<dynamic, dynamic>>? _eventsController;
  StreamSubscription<dynamic>? _nativeEventsSub;

  Stream<Map<dynamic, dynamic>> get events {
    if (_eventsController == null || _eventsController!.isClosed) {
      _eventsController = StreamController<Map<dynamic, dynamic>>.broadcast(
        onListen: () {
          _nativeEventsSub ??= _eventChannel
              .receiveBroadcastStream()
              .listen(
                (event) {
                  if (event is Map) {
                    _eventsController?.add(event);
                  }
                },
                onError: (err) => _eventsController?.addError(err),
              );
        },
        onCancel: () {
          _nativeEventsSub?.cancel();
          _nativeEventsSub = null;
        },
      );
    }
    return _eventsController!.stream;
  }

  void emitEventForTesting(Map<dynamic, dynamic> event) {
    if (_eventsController == null || _eventsController!.isClosed) {
      events; // initialize stream controller
    }
    _eventsController?.add(event);
  }

  void resetForTesting() {
    _discoveryEventsSub?.cancel();
    _discoveryEventsSub = null;
    _discoveredPeersController?.close();
    _discoveredPeersController = null;
    _nativeEventsSub?.cancel();
    _nativeEventsSub = null;
    _eventsController?.close();
    _eventsController = null;
    _discoveredPeers.clear();
  }

  Future<AndroidNodeStateEnum> getNodeState() async {
    try {
      final stateStr =
          await _methodChannel.invokeMethod<String>('getNodeState');
      switch (stateStr) {
        case 'ACTIVE':
          return AndroidNodeStateEnum.active;
        case 'BACKGROUND_CAPABLE':
          return AndroidNodeStateEnum.backgroundCapable;
        case 'OS_RESTRICTED':
          return AndroidNodeStateEnum.osRestricted;
        case 'UNAVAILABLE':
          return AndroidNodeStateEnum.unavailable;
        default:
          return AndroidNodeStateEnum.unknown;
      }
    } catch (e) {
      return AndroidNodeStateEnum.unknown;
    }
  }

  Future<NodeLifecycleStateEnum> getLifecycleState() async {
    try {
      final stateStr =
          await _methodChannel.invokeMethod<String>('getLifecycleState');
      switch (stateStr) {
        case 'STOPPED':
          return NodeLifecycleStateEnum.stopped;
        case 'STARTING':
          return NodeLifecycleStateEnum.starting;
        case 'CHECKING_CAPABILITIES':
          return NodeLifecycleStateEnum.checkingCapabilities;
        case 'RECOVERING':
          return NodeLifecycleStateEnum.recovering;
        case 'DISCOVERING':
          return NodeLifecycleStateEnum.discovering;
        case 'READY':
          return NodeLifecycleStateEnum.ready;
        case 'CONNECTED':
          return NodeLifecycleStateEnum.connected;
        case 'TRANSFERRING':
          return NodeLifecycleStateEnum.transferring;
        case 'DEGRADED':
          return NodeLifecycleStateEnum.degraded;
        case 'UNAVAILABLE':
          return NodeLifecycleStateEnum.unavailable;
        case 'STOPPING':
          return NodeLifecycleStateEnum.stopping;
        default:
          return NodeLifecycleStateEnum.unknown;
      }
    } catch (e) {
      return NodeLifecycleStateEnum.unknown;
    }
  }

  Future<NodeCapabilities?> getNodeCapabilities() async {
    try {
      final map = await _methodChannel
          .invokeMethod<Map<dynamic, dynamic>>('getNodeCapabilities');
      if (map != null) {
        return NodeCapabilities.fromMap(map);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<NodeLifecycleStateEnum> startNode() async {
    try {
      await _methodChannel.invokeMethod<String>('startNode');
      return await getLifecycleState();
    } catch (e) {
      return NodeLifecycleStateEnum.unavailable;
    }
  }

  Future<NodeLifecycleStateEnum> stopNode() async {
    try {
      await _methodChannel.invokeMethod<String>('stopNode');
      return await getLifecycleState();
    } catch (e) {
      return NodeLifecycleStateEnum.stopped;
    }
  }

  Stream<NodeLifecycleStateEnum> get lifecycleStream {
    return events
        .where((event) => event['type'] == 'nodeLifecycleChanged')
        .map((event) {
      final newStateStr = event['newState'] as String?;
      switch (newStateStr) {
        case 'STOPPED':
          return NodeLifecycleStateEnum.stopped;
        case 'STARTING':
          return NodeLifecycleStateEnum.starting;
        case 'CHECKING_CAPABILITIES':
          return NodeLifecycleStateEnum.checkingCapabilities;
        case 'RECOVERING':
          return NodeLifecycleStateEnum.recovering;
        case 'DISCOVERING':
          return NodeLifecycleStateEnum.discovering;
        case 'READY':
          return NodeLifecycleStateEnum.ready;
        case 'CONNECTED':
          return NodeLifecycleStateEnum.connected;
        case 'TRANSFERRING':
          return NodeLifecycleStateEnum.transferring;
        case 'DEGRADED':
          return NodeLifecycleStateEnum.degraded;
        case 'UNAVAILABLE':
          return NodeLifecycleStateEnum.unavailable;
        case 'STOPPING':
          return NodeLifecycleStateEnum.stopping;
        default:
          return NodeLifecycleStateEnum.unknown;
      }
    });
  }

  Future<String?> getLocalPeerId() async {
    try {
      return await _methodChannel.invokeMethod<String>('getLocalPeerId');
    } catch (e) {
      return null;
    }
  }

  Future<String?> getFingerprint() async {
    try {
      return await _methodChannel.invokeMethod<String>('getFingerprint');
    } catch (e) {
      return null;
    }
  }

  Future<String?> getSecurityLevel() async {
    try {
      return await _methodChannel.invokeMethod<String>('getSecurityLevel');
    } catch (e) {
      return null;
    }
  }

  Future<String> initiateSend({
    required String targetPeerId,
    required List<String> contentUris,
  }) async {
    var cleanTarget = targetPeerId.trim();
    if (cleanTarget.startsWith('{') && cleanTarget.contains('"peerId"')) {
      try {
        final invitation = PairingInvitation.parse(cleanTarget);
        cleanTarget = invitation.peerId;
        String? hintHost;
        int hintPort = 8765;
        if (invitation.connectionHints.isNotEmpty) {
          final hint = invitation.connectionHints.first;
          if (hint.contains(':')) {
            final parts = hint.split(':');
            hintHost = parts[0];
            hintPort = int.tryParse(parts[1]) ?? 8765;
          } else {
            hintHost = hint;
          }
        }
        await addTrustedPeer(
          peerId: invitation.peerId,
          fingerprint: invitation.fingerprint,
          name: invitation.name,
          host: hintHost,
          port: hintPort,
        );
      } catch (_) {}
    }

    final transferId = await _methodChannel.invokeMethod<String>(
      'initiateSend',
      {
        'targetPeerId': cleanTarget,
        'contentUris': contentUris,
      },
    );
    return transferId ?? '';
  }

  Future<bool> confirmPairing({
    required String sessionId,
    required bool accept,
  }) async {
    final result = await _methodChannel.invokeMethod<bool>(
      'confirmPairing',
      {
        'sessionId': sessionId,
        'accept': accept,
      },
    );
    return result ?? false;
  }

  Future<String?> syncClipboard() async {
    return await _methodChannel.invokeMethod<String>('syncClipboard');
  }

  Future<Map<String, bool>> checkPermissions() async {
    if (!PlatformCapabilities.isAndroid) {
      return {
        'notifications': true,
        'nearbyDevices': true,
        'camera': true,
        'storage': true,
        'localNetwork': true,
      };
    }
    try {
      final Map<dynamic, dynamic>? res =
          await _methodChannel.invokeMapMethod<dynamic, dynamic>('checkPermissions');
      if (res != null) {
        return res.map((k, v) => MapEntry(k.toString(), v == true));
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  Future<Map<String, bool>> requestPermissions(List<String> permissions) async {
    if (!PlatformCapabilities.isAndroid) return {};
    try {
      final Map<dynamic, dynamic>? res =
          await _methodChannel.invokeMapMethod<dynamic, dynamic>(
        'requestPermissions',
        {'permissions': permissions},
      );
      if (res != null) {
        return res.map((k, v) => MapEntry(k.toString(), v == true));
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  Future<List<DiscoveredPeer>> getDiscoveredPeers() async {
    try {
      final list = await _methodChannel.invokeListMethod<dynamic>('getDiscoveredPeers');
      if (list != null) {
        final peers = list
            .map((item) => DiscoveredPeer.fromMap(item as Map<dynamic, dynamic>))
            .toList();
        for (final p in peers) {
          _discoveredPeers[p.peerId] = p;
        }
        _discoveredPeersController?.add(_discoveredPeers.values.toList());
        return peers;
      }
      return activeDiscoveredPeers;
    } catch (e) {
      return activeDiscoveredPeers;
    }
  }

  Future<DiscoveredPeer?> addManualPeer({
    required String peerId,
    required String name,
    required String host,
    int port = 8765,
  }) async {
    try {
      final res = await _methodChannel.invokeMapMethod<dynamic, dynamic>(
        'addManualPeer',
        {
          'peerId': peerId,
          'name': name,
          'host': host,
          'port': port,
        },
      );
      if (res != null) {
        final peer = DiscoveredPeer.fromMap(res);
        _discoveredPeers[peer.peerId] = peer;
        _discoveredPeersController?.add(_discoveredPeers.values.toList());
        return peer;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> refreshDiscovery() async {
    try {
      final res = await _methodChannel.invokeMethod<bool>('refreshDiscovery');
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  Stream<Map<String, dynamic>> get incomingOffersStream {
    return events
        .where((event) => event['type'] == 'incomingTransferOffer')
        .map((event) => Map<String, dynamic>.from(event));
  }

  Future<bool> respondIncomingTransfer({
    required String transferId,
    required bool accept,
  }) async {
    try {
      final res = await _methodChannel.invokeMethod<bool>(
        'respondIncomingTransfer',
        {
          'transferId': transferId,
          'accept': accept,
        },
      );
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> setReceiverConsentMode(String mode) async {
    try {
      final res = await _methodChannel.invokeMethod<bool>(
        'setReceiverConsentMode',
        {'mode': mode},
      );
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<String?> pickDirectoryUri() async {
    if (!PlatformCapabilities.isAndroid) return null;
    try {
      final res = await _methodChannel.invokeMethod<String>('pickDirectoryUri');
      return res;
    } catch (_) {
      return null;
    }
  }

  Future<String?> getAppStorageDirectory() async {
    if (!PlatformCapabilities.isAndroid) return null;
    try {
      final res = await _methodChannel.invokeMethod<String>('getAppStorageDirectory');
      return res;
    } catch (_) {
      return null;
    }
  }

  Future<bool> openFile(String path) async {
    if (!PlatformCapabilities.isAndroid) return false;
    try {
      final res = await _methodChannel.invokeMethod<bool>('openFile', {'path': path});
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> revealInFolder(String path) async {
    if (!PlatformCapabilities.isAndroid) return false;
    try {
      final res = await _methodChannel.invokeMethod<bool>('revealInFolder', {'path': path});
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> shareFile(String path) async {
    if (!PlatformCapabilities.isAndroid) return false;
    try {
      final res = await _methodChannel.invokeMethod<bool>('shareFile', {'path': path});
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> scanMediaFile(String path) async {
    if (!PlatformCapabilities.isAndroid) return false;
    try {
      final res = await _methodChannel.invokeMethod<bool>('scanMediaFile', {'path': path});
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, int>> getStorageSpaceInfo() async {
    if (!PlatformCapabilities.isAndroid) {
      return {'totalBytes': 0, 'freeBytes': 0, 'usedBytes': 0};
    }
    try {
      final res = await _methodChannel.invokeMapMethod<String, dynamic>('getStorageSpaceInfo');
      if (res != null) {
        return {
          'totalBytes': (res['totalBytes'] as num?)?.toInt() ?? 0,
          'freeBytes': (res['freeBytes'] as num?)?.toInt() ?? 0,
          'usedBytes': (res['usedBytes'] as num?)?.toInt() ?? 0,
        };
      }
    } catch (_) {}
    return {'totalBytes': 0, 'freeBytes': 0, 'usedBytes': 0};
  }

  Future<bool> addTrustedPeer({
    required String peerId,
    required String fingerprint,
    String? host,
    int? port,
    String? name,
  }) async {
    try {
      final args = <String, dynamic>{
        'peerId': peerId,
        'fingerprint': fingerprint,
      };
      if (host != null && host.isNotEmpty) args['host'] = host;
      if (port != null) args['port'] = port;
      if (name != null && name.isNotEmpty) args['name'] = name;

      final res = await _methodChannel.invokeMethod<bool>('addTrustedPeer', args);
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> revokeTrustedPeer(String peerId) async {
    try {
      final res = await _methodChannel.invokeMethod<bool>(
        'revokeTrustedPeer',
        {'peerId': peerId},
      );
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isPeerTrusted(String peerId) async {
    try {
      final res = await _methodChannel.invokeMethod<bool>(
        'isPeerTrusted',
        {'peerId': peerId},
      );
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isPeerRevoked(String peerId) async {
    try {
      final res = await _methodChannel.invokeMethod<bool>(
        'isPeerRevoked',
        {'peerId': peerId},
      );
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getJournalOperations() async {
    if (!PlatformCapabilities.isAndroid) return [];
    try {
      final res = await _methodChannel.invokeMethod<List<dynamic>>('getJournalOperations');
      if (res == null) return [];
      return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> startLocalHotspot() async {
    if (!PlatformCapabilities.isAndroid) {
      // Return simulated profile on desktop platforms for offline testability
      return {
        'ssid': 'PeerLink-Direct-SIM88',
        'passphrase': 'passphraseSIM88',
        'gatewayIp': '192.168.49.1',
        'listenPort': 52001,
        'wifiQr': 'WIFI:S:PeerLink-Direct-SIM88;T:WPA;P:passphraseSIM88;;',
        'peerlinkUri': 'peerlink://hotspot?ssid=PeerLink-Direct-SIM88&pass=passphraseSIM88&ip=192.168.49.1&port=52001',
      };
    }
    try {
      final res = await _methodChannel.invokeMapMethod<dynamic, dynamic>('startLocalHotspot');
      if (res == null) return null;
      return res.map((k, v) => MapEntry(k.toString(), v));
    } catch (_) {
      return null;
    }
  }

  Future<bool> stopLocalHotspot() async {
    if (!PlatformCapabilities.isAndroid) return true;
    try {
      final res = await _methodChannel.invokeMethod<bool>('stopLocalHotspot');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isHotspotActive() async {
    if (!PlatformCapabilities.isAndroid) return false;
    try {
      final res = await _methodChannel.invokeMethod<bool>('isHotspotActive');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Copies an Android SAF content:// URI into a temporary app cache file
  /// so Dart's embedded Web Beam HTTP server can stream it over Wi-Fi.
  Future<Map<String, dynamic>?> resolveContentUriToCacheFile(String contentUri) async {
    if (!PlatformCapabilities.isAndroid || !contentUri.startsWith('content://')) {
      return null;
    }
    try {
      final res = await _methodChannel.invokeMapMethod<dynamic, dynamic>(
        'resolveContentUriToCacheFile',
        {'uri': contentUri},
      );
      if (res == null) return null;
      return res.map((k, v) => MapEntry(k.toString(), v));
    } catch (_) {
      return null;
    }
  }

  /// Checks whether Android 11+ All Files Access (MANAGE_EXTERNAL_STORAGE) is granted
  /// so the in-app File Manager can browse, move, copy, zip, and manage Device Storage.
  Future<bool> hasAllFilesAccess() async {
    if (!PlatformCapabilities.isAndroid) return true;
    try {
      final res = await _methodChannel.invokeMethod<bool>('hasAllFilesAccess');
      return res ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Launches the Android OS All Files Access settings screen for PeerLink.
  Future<bool> requestAllFilesAccess() async {
    if (!PlatformCapabilities.isAndroid) return true;
    try {
      final res = await _methodChannel.invokeMethod<bool>('requestAllFilesAccess');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Consumes any cold-start ACTION_SEND / ACTION_SEND_MULTIPLE share payload
  /// buffered by MainActivity before Flutter finished initializing.
  Future<Map<String, dynamic>?> consumePendingShareIntent() async {
    if (!PlatformCapabilities.isAndroid) return null;
    try {
      final res = await _methodChannel.invokeMapMethod<dynamic, dynamic>('consumePendingShareIntent');
      if (res == null) return null;
      return res.map((k, v) => MapEntry(k.toString(), v));
    } catch (_) {
      return null;
    }
  }

  /// Shares one or multiple files (local paths or content:// URIs) to any
  /// installed Android app via ACTION_SEND / ACTION_SEND_MULTIPLE with ClipData permissions.
  Future<bool> shareFiles(List<String> paths, {String title = 'Share via...'}) async {
    if (!PlatformCapabilities.isAndroid || paths.isEmpty) return false;
    try {
      final res = await _methodChannel.invokeMethod<bool>(
        'shareFiles',
        {'paths': paths, 'title': title},
      );
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Shares one or multiple files directly via Android Quick Share (Google Play Services
  /// Nearby Share) when available, falling back cleanly to the Android System Share Sheet.
  Future<String?> shareViaQuickShare(List<String> paths) async {
    if (!PlatformCapabilities.isAndroid || paths.isEmpty) return null;
    try {
      final res = await _methodChannel.invokeMethod<String>(
        'shareViaQuickShare',
        {'paths': paths},
      );
      return res;
    } catch (_) {
      return null;
    }
  }

  /// Queries Android's MediaStore by category ('photos', 'videos', 'audio', 'documents',
  /// 'archives', 'apps', 'downloads') so users immediately see real device media even
  /// across nested DCIM/Pictures/WhatsApp directories or Scoped Storage.
  Future<List<Map<String, dynamic>>> queryDeviceMediaByCategory(
    String category, {
    int limit = 250,
  }) async {
    if (!PlatformCapabilities.isAndroid) return const [];
    try {
      final res = await _methodChannel.invokeListMethod<dynamic>(
        'queryDeviceMediaByCategory',
        {'category': category, 'limit': limit},
      );
      if (res == null) return const [];
      return res
          .whereType<Map>()
          .map((m) => m.map((k, v) => MapEntry(k.toString(), v)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Returns the authoritative native directory where inbound P2P transfers are saved.
  Future<String?> getReceivedDirectory() async {
    if (!PlatformCapabilities.isAndroid) return null;
    try {
      return await _methodChannel.invokeMethod<String>('getReceivedDirectory');
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> audioPlay(String path) async {
    if (!PlatformCapabilities.isAndroid) return {'playing': false};
    try {
      final res = await _methodChannel.invokeMapMethod<dynamic, dynamic>('audioPlay', {'path': path});
      return res?.map((k, v) => MapEntry(k.toString(), v)) ?? {'playing': false};
    } catch (_) {
      return {'playing': false};
    }
  }

  Future<Map<String, dynamic>> audioPause() async {
    if (!PlatformCapabilities.isAndroid) return {'playing': false};
    try {
      final res = await _methodChannel.invokeMapMethod<dynamic, dynamic>('audioPause');
      return res?.map((k, v) => MapEntry(k.toString(), v)) ?? {'playing': false};
    } catch (_) {
      return {'playing': false};
    }
  }

  Future<bool> audioSeek(int positionMs) async {
    if (!PlatformCapabilities.isAndroid) return false;
    try {
      return (await _methodChannel.invokeMethod<bool>('audioSeek', {'positionMs': positionMs})) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> audioStop() async {
    if (!PlatformCapabilities.isAndroid) return;
    try {
      await _methodChannel.invokeMethod<bool>('audioStop');
    } catch (_) {}
  }

  Future<Map<String, dynamic>> audioGetStatus() async {
    if (!PlatformCapabilities.isAndroid) return {'playing': false, 'positionMs': 0, 'durationMs': 0};
    try {
      final res = await _methodChannel.invokeMapMethod<dynamic, dynamic>('audioGetStatus');
      return res?.map((k, v) => MapEntry(k.toString(), v)) ?? {'playing': false, 'positionMs': 0, 'durationMs': 0};
    } catch (_) {
      return {'playing': false, 'positionMs': 0, 'durationMs': 0};
    }
  }

  Future<int> getPdfPageCount(String path) async {
    if (!PlatformCapabilities.isAndroid) return 0;
    try {
      return (await _methodChannel.invokeMethod<int>('getPdfPageCount', {'path': path})) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<Uint8List?> renderPdfPage(String path, int pageIndex, {int width = 900}) async {
    if (!PlatformCapabilities.isAndroid) return null;
    try {
      return await _methodChannel.invokeMethod<Uint8List>(
        'renderPdfPage',
        {'path': path, 'pageIndex': pageIndex, 'width': width},
      );
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> getVideoThumbnail(String path) async {
    if (!PlatformCapabilities.isAndroid) return null;
    try {
      return await _methodChannel.invokeMethod<Uint8List>('getVideoThumbnail', {'path': path});
    } catch (_) {
      return null;
    }
  }
}

