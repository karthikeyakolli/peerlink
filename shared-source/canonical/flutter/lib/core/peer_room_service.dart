import 'dart:math';
import 'package:flutter/foundation.dart';

class PeerRoomMember {
  final String deviceId;
  final String deviceName;
  final DateTime joinedAt;

  const PeerRoomMember({
    required this.deviceId,
    required this.deviceName,
    required this.joinedAt,
  });
}

class PeerRoomSession {
  final String pin;
  final String roomName;
  final String hostDeviceId;
  final List<PeerRoomMember> members;
  final DateTime createdAt;

  PeerRoomSession({
    required this.pin,
    required this.roomName,
    required this.hostDeviceId,
    List<PeerRoomMember>? members,
    DateTime? createdAt,
  })  : members = members ?? [],
        createdAt = createdAt ?? DateTime.now();
}

class PeerRoomService extends ChangeNotifier {
  PeerRoomService._();
  static final PeerRoomService instance = PeerRoomService._();

  final Map<String, PeerRoomSession> _activeRooms = {};

  PeerRoomSession createRoom({
    required String roomName,
    required String hostDeviceId,
  }) {
    final rng = Random();
    String pin;
    do {
      pin = (1000 + rng.nextInt(9000)).toString();
    } while (_activeRooms.containsKey(pin));

    final session = PeerRoomSession(
      pin: pin,
      roomName: roomName,
      hostDeviceId: hostDeviceId,
    );
    _activeRooms[pin] = session;
    notifyListeners();
    return session;
  }

  PeerRoomSession? joinRoom({
    required String pin,
    required String deviceId,
    required String deviceName,
  }) {
    final session = _activeRooms[pin.trim()];
    if (session == null) return null;

    final existingIdx = session.members.indexWhere((m) => m.deviceId == deviceId);
    if (existingIdx != -1) {
      session.members[existingIdx] = PeerRoomMember(
        deviceId: deviceId,
        deviceName: deviceName,
        joinedAt: DateTime.now(),
      );
    } else {
      session.members.add(PeerRoomMember(
        deviceId: deviceId,
        deviceName: deviceName,
        joinedAt: DateTime.now(),
      ));
    }

    notifyListeners();
    return session;
  }

  PeerRoomSession? getRoom(String pin) => _activeRooms[pin.trim()];

  Map<String, dynamic> createBroadcastPayload({
    required PeerRoomSession session,
    required String fileName,
    required int fileSizeBytes,
  }) {
    return {
      'type': 'PEERROOM_BROADCAST',
      'pin': session.pin,
      'roomName': session.roomName,
      'fileName': fileName,
      'fileSizeBytes': fileSizeBytes,
      'recipientCount': session.members.length,
      'recipients': session.members.map((m) => m.deviceId).toList(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  void closeRoom(String pin) {
    _activeRooms.remove(pin.trim());
    notifyListeners();
  }
}
