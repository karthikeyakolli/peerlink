import 'dart:async';
import 'package:flutter/services.dart';
import 'platform_capabilities.dart';

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
          _sharedFilesController.add(uris);
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
    final transferId = await _methodChannel.invokeMethod<String>(
      'initiateSend',
      {
        'targetPeerId': targetPeerId,
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
    try {
      final res = await _methodChannel.invokeMapMethod<String, bool>('checkPermissions');
      return res ?? {};
    } catch (e) {
      return {};
    }
  }

  Future<Map<String, bool>> requestPermissions(List<String> permissions) async {
    try {
      final res = await _methodChannel.invokeMapMethod<String, bool>(
        'requestPermissions',
        {'permissions': permissions},
      );
      return res ?? {};
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

  Future<bool> addTrustedPeer({
    required String peerId,
    required String fingerprint,
  }) async {
    try {
      final res = await _methodChannel.invokeMethod<bool>(
        'addTrustedPeer',
        {
          'peerId': peerId,
          'fingerprint': fingerprint,
        },
      );
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
}

