import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/app_settings_service.dart';
import 'package:peerlink/core/bluetooth_service.dart';
import 'package:peerlink/core/device_trust_service.dart';
import 'package:peerlink/design_system/components/bluetooth_share_modal.dart';
import 'package:peerlink/features/home/home_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('peerlink_conv_test_');
    AppSettingsService.instance.resetForTesting();
    BluetoothService.instance.resetForTesting();
  });

  tearDown(() {
    BluetoothService.instance.resetForTesting();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('DeviceTrustService Pinning & Recents', () {
    test('Pinning and unpinning devices updates status', () {
      final trust = DeviceTrustService.instance;
      const testPeerId = 'peer_laptop_001';

      expect(trust.isPinned(testPeerId), isFalse);
      trust.togglePinDevice(testPeerId);
      expect(trust.isPinned(testPeerId), isTrue);

      trust.togglePinDevice(testPeerId);
      expect(trust.isPinned(testPeerId), isFalse);
    });

    test('Recent recipient tracking updates correctly', () {
      final trust = DeviceTrustService.instance;
      const testPeerId = 'peer_desktop_office';

      trust.recordSendRecipient(testPeerId);
      expect(trust.recentRecipientId, equals(testPeerId));
    });

    test('sortedDevices orders pinned devices first then recents', () {
      final trust = DeviceTrustService.instance;
      // Pair 3 devices
      trust.pairDevice(
        const PairedDevice(
          id: 'dev_c',
          name: 'Charlie Laptop',
          deviceType: 'desktop',
          fingerprint: 'fp_c',
          trustLevel: DeviceTrustLevel.trustedPeer,
          isOnline: true,
          lastSeen: 'Now',
        ),
      );
      trust.pairDevice(
        const PairedDevice(
          id: 'dev_a',
          name: 'Alpha Phone',
          deviceType: 'phone',
          fingerprint: 'fp_a',
          trustLevel: DeviceTrustLevel.trustedPeer,
          isOnline: true,
          lastSeen: 'Now',
        ),
      );
      trust.pairDevice(
        const PairedDevice(
          id: 'dev_b',
          name: 'Bravo Tablet',
          deviceType: 'tablet',
          fingerprint: 'fp_b',
          trustLevel: DeviceTrustLevel.trustedPeer,
          isOnline: true,
          lastSeen: 'Now',
        ),
      );

      // Pin dev_b
      if (!trust.isPinned('dev_b')) {
        trust.togglePinDevice('dev_b');
      }
      // Record dev_c as recent
      trust.recordSendRecipient('dev_c');

      final sorted = trust.sortedDevices;
      expect(sorted.length, greaterThanOrEqualTo(3));

      // Pinned 'dev_b' must be first
      expect(sorted.first.id, equals('dev_b'));
      // Recent 'dev_c' should come before unpinned 'dev_a'
      final indexC = sorted.indexWhere((d) => d.id == 'dev_c');
      final indexA = sorted.indexWhere((d) => d.id == 'dev_a');
      expect(indexC, lessThan(indexA));
    });

    test('Cryptographic trust check only validates paired trusted peers', () {
      final trust = DeviceTrustService.instance;
      trust.pairDevice(
        const PairedDevice(
          id: 'dev_trusted',
          name: 'Verified Phone',
          deviceType: 'phone',
          fingerprint: 'fp_trusted',
          trustLevel: DeviceTrustLevel.trustedPeer,
          isOnline: true,
          lastSeen: 'Now',
        ),
      );

      expect(trust.isTrusted('dev_trusted'), isTrue);
      expect(trust.isTrusted('untrusted_rogue_peer'), isFalse);
    });
  });

  group('BluetoothService & BLE Offline Sharing', () {
    test('BluetoothService streams nearby discovered devices', () async {
      final service = BluetoothService.instance;
      final future = service.discoveredDevicesStream.first;
      service.addDiscoveredDeviceForTesting(
        const BluetoothDeviceRecord(
          id: 'ble_nearby_01',
          name: 'Nearby Laptop',
          rssi: -65,
          fingerprint: 'fp_ble_01',
        ),
      );
      final devices = await future;
      expect(devices, isNotEmpty);
      expect(devices.any((d) => d.id.contains('ble_nearby')), isTrue);
    });

    test('BluetoothService signal strength categorization', () {
      const strong = BluetoothDeviceRecord(
        id: '1',
        name: 'Strong Peer',
        rssi: -50,
        fingerprint: 'fp',
      );
      const medium = BluetoothDeviceRecord(
        id: '2',
        name: 'Medium Peer',
        rssi: -68,
        fingerprint: 'fp',
      );
      const weak = BluetoothDeviceRecord(
        id: '3',
        name: 'Weak Peer',
        rssi: -85,
        fingerprint: 'fp',
      );

      expect(strong.signalStrength, equals('Strong'));
      expect(medium.signalStrength, equals('Medium'));
      expect(weak.signalStrength, equals('Weak'));
    });

    test('BluetoothService advertising toggle', () async {
      final service = BluetoothService.instance;
      expect(service.isAdvertising, isFalse);

      await service.startAdvertising();
      expect(service.isAdvertising, isTrue);

      await service.stopAdvertising();
      expect(service.isAdvertising, isFalse);
    });

    test('beamTextSnippet beams text payload to peer', () async {
      final service = BluetoothService.instance;
      final payloadFuture = service.incomingPayloadStream.first;

      final success = await service.beamTextSnippet(
        targetDeviceId: 'ble_target_01',
        text: 'Hello via offline Bluetooth!',
      );

      expect(success, isTrue);
      final received = await payloadFuture;
      expect(received.text, equals('Hello via offline Bluetooth!'));
      expect(received.isFile, isFalse);
    });

    test('beamSmallFile transmits small files and rejects files exceeding 500KB', () async {
      final service = BluetoothService.instance;

      // Small file (< 500 KB)
      final smallFile = File('${tempDir.path}/small_card.vcf');
      smallFile.writeAsStringSync('BEGIN:VCARD\nFN:PeerLink Test\nEND:VCARD');

      final smallSuccess = await service.beamSmallFile(
        targetDeviceId: 'ble_target_01',
        filePath: smallFile.path,
      );
      expect(smallSuccess, isTrue);

      // Oversized file (> 500 KB)
      final largeFile = File('${tempDir.path}/large_blob.dat');
      largeFile.writeAsBytesSync(List.filled(600 * 1024, 0xAB));

      final largeSuccess = await service.beamSmallFile(
        targetDeviceId: 'ble_target_01',
        filePath: largeFile.path,
      );
      expect(largeSuccess, isFalse);
    });
  });

  group('Bluetooth UI & Dialogs', () {
    testWidgets('BluetoothShareModal opens and renders device scanner', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BluetoothShareModal(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bluetooth Offline Beam'), findsOneWidget);
      expect(find.text('Target Bluetooth Device'), findsOneWidget);
      expect(find.text('Beam via Bluetooth'), findsOneWidget);
    });

    testWidgets('BluetoothShareModal.showIncomingPayload displays received text dialog', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    BluetoothShareModal.showIncomingPayload(
                      context,
                      payload: BluetoothPayloadRecord(
                        id: 'payload_01',
                        senderDeviceId: 'sender_01',
                        senderName: 'Test Phone',
                        text: 'Offline Bluetooth Link: https://example.com',
                        sizeBytes: 42,
                        timestamp: DateTime.now(),
                      ),
                    );
                  },
                  child: const Text('Show Dialog'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Bluetooth Text Received'), findsOneWidget);
      expect(find.text('From: Test Phone'), findsOneWidget);
      expect(find.text('Offline Bluetooth Link: https://example.com'), findsOneWidget);
      expect(find.text('Copy to Clipboard'), findsOneWidget);
      expect(find.text('Dismiss'), findsOneWidget);

      await tester.tap(find.text('Dismiss'));
      await tester.pumpAndSettle();
      expect(find.text('Bluetooth Text Received'), findsNothing);
    });

    testWidgets('HomeScreen renders Bluetooth Beam quick action chip', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bluetooth Beam'), findsOneWidget);
      expect(find.byIcon(Icons.bluetooth_searching_rounded), findsOneWidget);
    });
  });
}
