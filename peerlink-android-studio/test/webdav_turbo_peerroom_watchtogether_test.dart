import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/webdav_server_service.dart';
import 'package:peerlink/core/usb_turbo_mode_service.dart';
import 'package:peerlink/core/peer_room_service.dart';
import 'package:peerlink/core/watch_together_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  HttpOverrides? prevOverrides;

  setUp(() async {
    prevOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    tempDir = await Directory.systemTemp.createTemp('peerlink_task3_test_');
  });

  tearDown(() async {
    HttpOverrides.global = prevOverrides;
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  group('WebDavServerService RFC 4918 Tests', () {
    test('starts server, rejects unauthenticated requests, and handles OPTIONS & PROPFIND & GET & PUT', () async {
      final service = WebDavServerService.instance;
      final file1 = File('${tempDir.path}/report.txt')..writeAsStringSync('Hello WebDAV Vault');

      final startResult = await service.start(
        rootDirectory: tempDir,
        username: 'peerlink',
        password: 'secure_password_123',
        port: 0, // ephemeral port
      );

      expect(startResult.isRunning, isTrue);
      expect(startResult.port, greaterThan(0));

      final port = startResult.port;
      final client = HttpClient();

      try {
        // 1. Unauthenticated request -> Must return 401 Unauthorized (Rule 12)
        final unauthReq = await client.openUrl('OPTIONS', Uri.parse('http://127.0.0.1:$port/'));
        final unauthRes = await unauthReq.close();
        expect(unauthRes.statusCode, HttpStatus.unauthorized);

        // 2. Authenticated OPTIONS request -> Returns DAV: 1, 2
        final authHeader = 'Basic ${base64Encode(utf8.encode('peerlink:secure_password_123'))}';
        final optReq = await client.openUrl('OPTIONS', Uri.parse('http://127.0.0.1:$port/'));
        optReq.headers.set('Authorization', authHeader);
        final optRes = await optReq.close();
        expect(optRes.statusCode, HttpStatus.ok);
        expect(optRes.headers.value('DAV'), contains('1'));

        // 3. Authenticated PROPFIND request -> Returns multistatus XML
        final propReq = await client.openUrl('PROPFIND', Uri.parse('http://127.0.0.1:$port/'));
        propReq.headers.set('Authorization', authHeader);
        final propRes = await propReq.close();
        expect(propRes.statusCode, 207); // Multi-Status
        final propXml = await utf8.decodeStream(propRes);
        expect(propXml, contains('multistatus'));
        expect(propXml, contains('report.txt'));

        // 4. Authenticated GET request -> Returns file bytes
        final getReq = await client.getUrl(Uri.parse('http://127.0.0.1:$port/report.txt'));
        getReq.headers.set('Authorization', authHeader);
        final getRes = await getReq.close();
        expect(getRes.statusCode, HttpStatus.ok);
        final body = await utf8.decodeStream(getRes);
        expect(body, 'Hello WebDAV Vault');

        // 5. Authenticated PUT request -> Writes file
        final putReq = await client.openUrl('PUT', Uri.parse('http://127.0.0.1:$port/new_file.txt'));
        putReq.headers.set('Authorization', authHeader);
        putReq.write('Created via WebDAV');
        final putRes = await putReq.close();
        expect(putRes.statusCode, HttpStatus.created);

        final createdFile = File('${tempDir.path}/new_file.txt');
        expect(createdFile.existsSync(), isTrue);
        expect(createdFile.readAsStringSync(), 'Created via WebDAV');

        // 6. Test Windows net use command generation
        final netUseCmd = service.getWindowsMountCommand(ip: '192.168.1.5', driveLetter: 'P:');
        expect(netUseCmd, contains('net use P: http://192.168.1.5:$port/ /user:peerlink secure_password_123'));
      } finally {
        client.close();
        await service.stop();
        expect(service.isRunning, isFalse);
      }
    });
  });

  group('UsbTurboModeService Tests', () {
    test('identifies USB tethering subnets and activates wired turbo mode', () {
      final usb = UsbTurboModeService.instance;

      expect(usb.isWiredSubnet('192.168.42.129'), isTrue);
      expect(usb.isWiredSubnet('192.168.43.50'), isTrue);
      expect(usb.isWiredSubnet('192.168.1.100'), isFalse);
      expect(usb.isWiredSubnet('10.0.0.5'), isFalse);

      usb.setTurboEnabled(true);
      expect(usb.isTurboEnabled, isTrue);

      final throughput = usb.estimateThroughputLabel(isWired: true);
      expect(throughput, contains('Gigabit'));

      usb.setTurboEnabled(false);
    });
  });

  group('PeerRoomService Multi-Recipient Drop Tests', () {
    test('creates temporary room, validates PIN, adds members and broadcasts', () {
      final roomService = PeerRoomService.instance;

      final session = roomService.createRoom(
        roomName: 'Design Team Classroom',
        hostDeviceId: 'host-pc-1',
      );

      expect(session.pin.length, 4);
      expect(session.roomName, 'Design Team Classroom');
      expect(session.members.isEmpty, isTrue);

      // Join with incorrect PIN -> fails
      final wrongJoin = roomService.joinRoom(
        pin: '9999',
        deviceId: 'student-phone-1',
        deviceName: 'Pixel 8',
      );
      expect(wrongJoin, isNull);

      // Join with correct PIN -> succeeds
      final correctJoin = roomService.joinRoom(
        pin: session.pin,
        deviceId: 'student-phone-1',
        deviceName: 'Pixel 8',
      );
      expect(correctJoin, isNotNull);
      expect(session.members.length, 1);
      expect(session.members.first.deviceName, 'Pixel 8');

      // Broadcast file item
      final broadcastPacket = roomService.createBroadcastPayload(
        session: session,
        fileName: 'slides.pdf',
        fileSizeBytes: 1024 * 500,
      );

      expect(broadcastPacket['type'], 'PEERROOM_BROADCAST');
      expect(broadcastPacket['fileName'], 'slides.pdf');
      expect(broadcastPacket['recipientCount'], 1);

      roomService.closeRoom(session.pin);
      expect(roomService.getRoom(session.pin), isNull);
    });
  });

  group('WatchTogetherSyncService Tests', () {
    test('emits sync playback actions and triggers drift compensation', () {
      final watch = WatchTogetherSyncService.instance;
      watch.startSession(sessionId: 'movie-night-lan', isHost: true);

      Map<String, dynamic>? dispatched;
      watch.onBroadcastAction = (action) => dispatched = action;

      // Host plays at 15 seconds
      watch.broadcastPlaybackState(
        action: WatchPlaybackAction.play,
        positionMs: 15000,
        speed: 1.0,
      );

      expect(dispatched, isNotNull);
      expect(dispatched!['action'], 'PLAY');
      expect(dispatched!['positionMs'], 15000);

      // Client checks drift compensation
      int? seekTarget;
      watch.onDriftCorrectionRequired = (pos) => seekTarget = pos;

      // Local is at 10,000ms, incoming packet says 14,000ms (drift = 4,000ms > 500ms threshold)
      watch.handleIncomingAction({
        'action': 'PLAY',
        'positionMs': 14000,
        'speed': 1.0,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      }, currentLocalPositionMs: 10000);

      expect(seekTarget, 14000);

      watch.stopSession();
    });
  });
}
