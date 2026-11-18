import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/device_trust_service.dart';
import 'package:peerlink/core/quick_text_service.dart';

void main() {
  setUp(() {
    QuickTextService.instance.resetForTesting();
    DeviceTrustService.instance.resetForTesting();
  });

  group('QuickTextService Tests', () {
    test('sendText validates empty text or peerId', () async {
      final service = QuickTextService.instance;
      expect(await service.sendText(text: '', targetPeerId: 'peer_1'), isFalse);
      expect(await service.sendText(text: 'Hello', targetPeerId: ''), isFalse);
    });

    test('sendText records outgoing snippet in history', () async {
      final service = QuickTextService.instance;
      final success = await service.sendText(
        text: 'https://github.com',
        targetPeerId: 'laptop_peer',
        targetPeerName: 'Laptop',
      );

      expect(success, isTrue);
      expect(service.history.length, equals(1));
      final item = service.history.first;
      expect(item.text, equals('https://github.com'));
      expect(item.isOutgoing, isTrue);
      expect(item.isUrl, isTrue);
      expect(item.peerName, equals('Laptop'));
    });

    test('receiveText emits to incoming stream and updates history', () async {
      final service = QuickTextService.instance;
      TextSnippetItem? received;
      final sub = service.incomingTextStream.listen((item) => received = item);

      service.receiveText(
        text: 'Wi-Fi Password: SecretPassword123',
        senderPeerId: 'phone_peer',
        senderPeerName: 'Pixel 8',
      );

      expect(received, isNotNull);
      expect(received!.text, equals('Wi-Fi Password: SecretPassword123'));
      expect(received!.isOutgoing, isFalse);
      expect(received!.isUrl, isFalse);
      expect(received!.peerName, equals('Pixel 8'));

      expect(service.history.length, equals(1));
      await sub.cancel();
    });

    test('clearHistory empties the snippet records', () async {
      final service = QuickTextService.instance;
      await service.sendText(text: 'Test', targetPeerId: 'p1');
      expect(service.history.length, equals(1));

      service.clearHistory();
      expect(service.history.isEmpty, isTrue);
    });
  });
}
