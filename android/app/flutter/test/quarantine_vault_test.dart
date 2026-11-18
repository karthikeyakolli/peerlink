import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/quarantine_service.dart';
import 'package:peerlink/core/operation_journal_service.dart';
import 'package:peerlink/features/activity/activity_screen.dart';
import 'package:peerlink/features/activity/quarantine_vault_sheet.dart';

void main() {
  setUp(() {
    QuarantineService.instance.resetForTesting();
    OperationJournalService.instance.resetForTesting();
  });

  tearDown(() {
    QuarantineService.instance.resetForTesting();
    OperationJournalService.instance.resetForTesting();
  });

  group('QuarantineService Unit Tests', () {
    test('starts empty and supports adding and purging items', () async {
      final service = QuarantineService.instance;
      expect(service.isEmpty, isTrue);
      expect(service.count, 0);

      final item1 = QuarantinedItem(
        id: 'quar_1',
        fileName: 'malicious_or_corrupt.tar',
        quarantinePath: '/tmp/quarantine/malicious_or_corrupt.tar',
        reason: QuarantineReason.checksumMismatch,
        expectedSha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        actualSha256: '0000000000000000000000000000000000000000000000000000000000000000',
        quarantinedAt: DateTime.now(),
        fileSizeBytes: 2048,
        sourcePeerId: 'peer_untrusted_77',
      );

      service.addQuarantinedItem(item1);
      expect(service.isEmpty, isFalse);
      expect(service.count, 1);
      expect(service.quarantinedItems.first.fileName, 'malicious_or_corrupt.tar');
      expect(service.quarantinedItems.first.formattedSize, '2.0 KB');

      await service.purgeItem('quar_1');
      expect(service.isEmpty, isTrue);
      expect(service.count, 0);
    });

    test('purgeAll wipes all quarantined files', () async {
      final service = QuarantineService.instance;
      service.addQuarantinedItem(
        QuarantinedItem(
          id: 'item_a',
          fileName: 'partial_1.bin',
          quarantinePath: '/tmp/partial_1.bin',
          reason: QuarantineReason.partialUncertain,
          expectedSha256: 'abc',
          actualSha256: 'def',
          quarantinedAt: DateTime.now(),
          fileSizeBytes: 500,
          sourcePeerId: 'peer_1',
        ),
      );
      service.addQuarantinedItem(
        QuarantinedItem(
          id: 'item_b',
          fileName: 'partial_2.bin',
          quarantinePath: '/tmp/partial_2.bin',
          reason: QuarantineReason.antimalwareFlagged,
          expectedSha256: '123',
          actualSha256: '456',
          quarantinedAt: DateTime.now(),
          fileSizeBytes: 10 * 1024 * 1024,
          sourcePeerId: 'peer_2',
        ),
      );

      expect(service.count, 2);
      expect(service.quarantinedItems[1].formattedSize, '10.00 MB');

      await service.purgeAll();
      expect(service.count, 0);
      expect(service.isEmpty, isTrue);
    });
  });

  group('QuarantineVaultSheet Widget Tests', () {
    testWidgets('renders empty state when no items quarantined', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: QuarantineVaultSheet(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Quarantine Vault'), findsOneWidget);
      expect(find.text('0 isolated items (Rule 9 & 10 Enforcement)'), findsOneWidget);
      expect(find.text('Quarantine Vault is Clean'), findsOneWidget);
      expect(find.textContaining('Zero-Trust Isolation'), findsOneWidget);
    });

    testWidgets('displays quarantined item details, SHA-256 hashes, and purge dialog', (tester) async {
      QuarantineService.instance.addQuarantinedItem(
        QuarantinedItem(
          id: 'test_quar_file',
          fileName: 'payload_firmware.bin.corrupt',
          quarantinePath: '/data/quarantine/payload_firmware.bin.corrupt',
          reason: QuarantineReason.checksumMismatch,
          expectedSha256: 'aabbcc112233',
          actualSha256: 'deadbeef9999',
          quarantinedAt: DateTime.now(),
          fileSizeBytes: 1024 * 1024 * 5,
          sourcePeerId: 'peer_rogue_alpha',
        ),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: QuarantineVaultSheet(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('payload_firmware.bin.corrupt'), findsOneWidget);
      expect(find.text('CHECKSUM_MISMATCH'), findsOneWidget);
      expect(find.text('aabbcc112233'), findsOneWidget);
      expect(find.text('deadbeef9999'), findsOneWidget);
      expect(find.text('5.00 MB · From: peer_rogue_alpha'), findsOneWidget);

      // Tap Crypto-Purge & Shred
      await tester.tap(find.text('Crypto-Purge & Shred'));
      await tester.pumpAndSettle();

      expect(find.text('Crypto-Purge File?'), findsOneWidget);
      expect(find.textContaining('cryptographically shred and delete'), findsOneWidget);

      // Confirm purge
      await tester.tap(find.text('Purge & Shred'));
      await tester.pumpAndSettle();

      expect(QuarantineService.instance.isEmpty, isTrue);
      expect(find.text('Quarantine Vault is Clean'), findsOneWidget);
    });

    testWidgets('Purge All button shreds entire vault upon confirmation', (tester) async {
      QuarantineService.instance.addQuarantinedItem(
        QuarantinedItem(
          id: 'q1',
          fileName: 'part_1.bin',
          quarantinePath: '/data/q1',
          reason: QuarantineReason.partialUncertain,
          expectedSha256: '1111',
          actualSha256: '2222',
          quarantinedAt: DateTime.now(),
          fileSizeBytes: 512,
          sourcePeerId: 'peer_a',
        ),
      );
      QuarantineService.instance.addQuarantinedItem(
        QuarantinedItem(
          id: 'q2',
          fileName: 'part_2.bin',
          quarantinePath: '/data/q2',
          reason: QuarantineReason.unexpectedInterruption,
          expectedSha256: '3333',
          actualSha256: '4444',
          quarantinedAt: DateTime.now(),
          fileSizeBytes: 1024,
          sourcePeerId: 'peer_b',
        ),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: QuarantineVaultSheet(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Purge All'), findsOneWidget);
      await tester.tap(find.text('Purge All'));
      await tester.pumpAndSettle();

      expect(find.text('Purge Entire Vault?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Purge All'));
      await tester.pumpAndSettle();

      expect(QuarantineService.instance.isEmpty, isTrue);
      expect(find.text('Quarantine Vault is Clean'), findsOneWidget);
    });
  });

  group('ActivityScreen Quarantine Integration Tests', () {
    testWidgets('ActivityScreen shows Quarantine Vault banner in PROBLEMS tab when items are isolated', (tester) async {
      QuarantineService.instance.addQuarantinedItem(
        QuarantinedItem(
          id: 'q_leak',
          fileName: 'unverified_blob.dat',
          quarantinePath: '/data/unverified_blob.dat',
          reason: QuarantineReason.checksumMismatch,
          expectedSha256: 'expected_hash_val',
          actualSha256: 'computed_hash_val',
          quarantinedAt: DateTime.now(),
          fileSizeBytes: 4096,
          sourcePeerId: 'peer_unverified',
        ),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: ActivityScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to PROBLEMS tab
      await tester.tap(find.text('PROBLEMS'));
      await tester.pumpAndSettle();

      expect(find.text('Quarantine Vault (1 isolated)'), findsOneWidget);
      expect(find.text('Inspect Vault'), findsOneWidget);

      // Tap Inspect Vault
      await tester.tap(find.text('Inspect Vault'));
      await tester.pumpAndSettle();

      expect(find.text('unverified_blob.dat'), findsOneWidget);
      expect(find.text('expected_hash_val'), findsOneWidget);
    });

    testWidgets('Quarantine Vault icon button in ActivityScreen AppBar opens sheet', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ActivityScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final vaultButton = find.byTooltip('Quarantine Vault');
      expect(vaultButton, findsOneWidget);

      await tester.tap(vaultButton);
      await tester.pumpAndSettle();

      expect(find.text('Quarantine Vault'), findsOneWidget);
      expect(find.text('Quarantine Vault is Clean'), findsOneWidget);
    });
  });
}
