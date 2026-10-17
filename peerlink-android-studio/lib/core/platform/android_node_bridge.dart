import 'dart:async';
import 'package:flutter/services.dart';

enum AndroidNodeStateEnum {
  active,
  backgroundCapable,
  osRestricted,
  unavailable,
  unknown,
}

class AndroidNodeBridge {
  static const MethodChannel _methodChannel =
      MethodChannel('org.peerlink/android_node_methods');
  static const EventChannel _eventChannel =
      EventChannel('org.peerlink/android_node_events');

  static final AndroidNodeBridge instance = AndroidNodeBridge._();
  AndroidNodeBridge._();

  Stream<Map<dynamic, dynamic>>? _eventStream;

  Stream<Map<dynamic, dynamic>> get events {
    _eventStream ??= _eventChannel
        .receiveBroadcastStream()
        .map((event) => event as Map<dynamic, dynamic>);
    return _eventStream!;
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
}
