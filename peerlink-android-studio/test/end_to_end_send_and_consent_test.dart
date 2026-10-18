import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/platform/android_node_bridge.dart';
import 'package:peerlink/features/files/files_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> methodCalls;
  late StreamController<dynamic> eventController;

  setUp(() {
    methodCalls = [];
    eventController = StreamController<dynamic>.broadcast();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('org.peerlink/android_node_methods'),
      (MethodCall call) async {
        methodCalls.add(call);
        switch (call.method) {
          case 'initiateSend':
            final target = call.arguments['targetPeerId'] as String? ?? '';
            return 'tx_mock_12345';
          case 'respondIncomingTransfer':
            final transferId = call.arguments['transferId'] as String? ?? '';
            final accept = call.arguments['accept'] as bool? ?? false;
            return true;
          case 'setReceiverConsentMode':
            return true;
          case 'getNodeCapabilities':
            return {
              'availableNetworkInterfaces': ['wlan0'],
              'activeListeners': ['TCP://0.0.0.0:8765'],
              'usableTransports': ['TCP_TLS'],
              'missingPermissions': <String>[],
              'backgroundTransferLimitations': 'None',
              'supportedFeatures': {'SEND': true, 'RECEIVE': true},
              'isHardwareSigning': true,
              'securityLevel': 'STRONGBOX',
              'canTransfer': true,
            };
          case 'getDiscoveredPeers':
            return [];
          case 'getLifecycleState':
            return 'READY';
          default:
            return null;
        }
      },
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
      const EventChannel('org.peerlink/android_node_events'),
      MockStreamHandler.inline(
        onListen: (Object? arguments, MockStreamHandlerEventSink events) {
          eventController.stream.listen(
            (event) => events.success(event),
            onError: (Object error) => events.error(code: 'ERROR', message: error.toString()),
            onDone: () => events.endOfStream(),
          );
        },
      ),
    );
  });

  tearDown(() async {
    AndroidNodeBridge.instance.resetForTesting();
    await eventController.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('org.peerlink/android_node_methods'),
      null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
      const EventChannel('org.peerlink/android_node_events'),
      null,
    );
  });

  group('Phase 5: Native Android Bridge End-to-End Send & Consent', () {
    test('initiateSend dispatches targetPeerId and contentUris to native node', () async {
      final transferId = await AndroidNodeBridge.instance.initiateSend(
        targetPeerId: 'peer_galaxy_s24',
        contentUris: ['/storage/emulated/0/Download/document.pdf'],
      );

      expect(transferId, equals('tx_mock_12345'));
      expect(methodCalls.any((call) => call.method == 'initiateSend'), isTrue);
      final call = methodCalls.firstWhere((call) => call.method == 'initiateSend');
      expect(call.arguments['targetPeerId'], equals('peer_galaxy_s24'));
      expect(call.arguments['contentUris'], contains('/storage/emulated/0/Download/document.pdf'));
    });

    test('respondIncomingTransfer dispatches consent decision to native receiver', () async {
      final accepted = await AndroidNodeBridge.instance.respondIncomingTransfer(
        transferId: 'tx_incoming_999',
        accept: true,
      );

      expect(accepted, isTrue);
      expect(methodCalls.any((call) => call.method == 'respondIncomingTransfer'), isTrue);
      final call = methodCalls.firstWhere((call) => call.method == 'respondIncomingTransfer');
      expect(call.arguments['transferId'], equals('tx_incoming_999'));
      expect(call.arguments['accept'], isTrue);
    });

    test('setReceiverConsentMode updates consent policy on native node', () async {
      final res = await AndroidNodeBridge.instance.setReceiverConsentMode('MANUAL_PROMPT_ALL');

      expect(res, isTrue);
      expect(methodCalls.any((call) => call.method == 'setReceiverConsentMode'), isTrue);
      final call = methodCalls.firstWhere((call) => call.method == 'setReceiverConsentMode');
      expect(call.arguments['mode'], equals('MANUAL_PROMPT_ALL'));
    });

    test('incomingOffersStream filters and forwards native incomingTransferOffer events', () async {
      final offers = <Map<String, dynamic>>[];
      final sub = AndroidNodeBridge.instance.incomingOffersStream.listen(offers.add);

      await pumpEventQueue();

      eventController.add({
        'type': 'incomingTransferOffer',
        'transferId': 'tx_incoming_888',
        'senderPeer': 'peer_pixel_9',
        'fileName': 'presentation.key',
        'totalBytes': 204800,
        'itemCount': 1,
      });

      await pumpEventQueue();

      expect(offers.length, equals(1));
      expect(offers[0]['transferId'], equals('tx_incoming_888'));
      expect(offers[0]['senderPeer'], equals('peer_pixel_9'));
      expect(offers[0]['fileName'], equals('presentation.key'));
      expect(offers[0]['totalBytes'], equals(204800));

      await sub.cancel();
    });

    testWidgets('FilesScreen displays incoming transfer dialog and dispatches consent', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FilesScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Emit incoming offer event from native layer
      eventController.add({
        'type': 'incomingTransferOffer',
        'transferId': 'tx_prompt_123',
        'senderPeer': 'peer_desktop_office',
        'fileName': 'project_specs.zip',
        'totalBytes': 512000,
        'itemCount': 1,
      });

      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Dialog should be displayed
      expect(find.text('Incoming File Transfer'), findsOneWidget);
      expect(find.textContaining('peer_desktop_office'), findsOneWidget);
      expect(find.textContaining('project_specs.zip'), findsOneWidget);
      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);

      // Tap Accept
      await tester.tap(find.text('Accept'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify respondIncomingTransfer was dispatched with accept: true
      final acceptCall = methodCalls.firstWhere(
        (call) => call.method == 'respondIncomingTransfer' && call.arguments['transferId'] == 'tx_prompt_123',
      );
      expect(acceptCall.arguments['accept'], isTrue);
    });
  });
}
