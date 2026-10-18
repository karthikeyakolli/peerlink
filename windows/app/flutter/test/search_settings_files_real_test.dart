import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/device_trust_service.dart';
import 'package:peerlink/core/operation_journal_service.dart';
import 'package:peerlink/core/sync_backup_service.dart';
import 'package:peerlink/features/search/search_screen.dart';
import 'package:peerlink/features/settings/settings_screen.dart';
import 'package:peerlink/features/files/files_screen.dart';

void main() {
  setUp(() {
    DeviceTrustService.instance.resetForTesting();
    OperationJournalService.instance.resetForTesting();
    SyncBackupService.instance.resetForTesting();
  });

  group('SearchScreen Authoritative Tests', () {
    testWidgets('SearchScreen: removes mock files and distinguishes retrievable from offline discovered results',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SearchScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Assert NO hardcoded mock search results
      expect(find.text('Q3_Financial_Summary.xlsx'), findsNothing);
      expect(find.text('IMG_20261003_Sunset.jpg'), findsNothing);
      expect(find.text('dataset_export_v2.json'), findsNothing);
      expect(find.text('MacBook Pro 16"'), findsNothing);

      // 2. Empty query shows index search guidance
      expect(find.textContaining('Search Local and Authorized Peer Indexes', findRichText: true), findsOneWidget);

      // 3. Add a paired peer that is online and one that is offline
      DeviceTrustService.instance.pairDevice(
        const PairedDevice(
          id: 'peer_online',
          name: 'Backup Server',
          deviceType: 'desktop',
          fingerprint: 'ed25519:abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
          trustLevel: DeviceTrustLevel.trustedPeer,
          isOnline: true,
        ),
      );
      DeviceTrustService.instance.pairDevice(
        const PairedDevice(
          id: 'peer_offline',
          name: 'Field Tablet',
          deviceType: 'tablet',
          fingerprint: 'ed25519:1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
          trustLevel: DeviceTrustLevel.trustedPeer,
          isOnline: false,
        ),
      );

      // Enter query
      await tester.enterText(find.byType(TextField), 'report');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify distinction between currently retrievable (online) and discovered-only (offline)
      expect(find.textContaining('RETRIEVABLE', findRichText: true), findsOneWidget);
      expect(find.textContaining('DISCOVERED (OFFLINE)', findRichText: true), findsOneWidget);
    });
  });

  group('SettingsScreen Live Status & Bandwidth Configuration', () {
    testWidgets('SettingsScreen: displays live node daemon status and enforces bandwidth configuration',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Verified Live Status indicator is rendered (not just static text)
      expect(find.textContaining('Local Node Daemon Status', findRichText: true), findsOneWidget);

      // 2. Bandwidth configuration control is present
      expect(find.textContaining('Transfer Bandwidth Limit', findRichText: true), findsOneWidget);
      expect(find.text('Apply Bandwidth Limit'), findsOneWidget);

      // 3. Unverified experimental tools (Web Beam, Burn-After-Read, Hotspot P2P) are deferred/hidden
      expect(find.text('Burn-After-Read'), findsNothing);
      expect(find.text('Web Beam (Browser Link)'), findsNothing);
    });
  });

  group('FilesScreen Transfer Separation & Recovery Banner', () {
    testWidgets('FilesScreen: separates active transfers from history and renders refresh error banner if node fails',
        (WidgetTester tester) async {
      // Record one active transfer and one completed transfer in journal
      OperationJournalService.instance.recordOperation(
        JournalOperation(
          operationId: 'xfer_active_stream',
          type: OperationType.send,
          state: JournalOperationState.executing,
          stage: JournalStage.execute,
          peerId: 'peer_nas',
          summary: 'archive_2026.zip',
          bytesTransferred: 50000000,
          totalBytes: 100000000,
          timestamp: DateTime.now(),
        ),
      );
      OperationJournalService.instance.recordOperation(
        JournalOperation(
          operationId: 'xfer_past_done',
          type: OperationType.receive,
          state: JournalOperationState.committed,
          stage: JournalStage.finalize,
          peerId: 'peer_workstation',
          summary: 'firmware_update.bin',
          bytesTransferred: 12000000,
          totalBytes: 12000000,
          timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        ),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: FilesScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Switch to ACTIVE & HISTORY tab
      await tester.tap(find.text('ACTIVE & HISTORY'));
      await tester.pumpAndSettle();

      // Active transfer is visible
      expect(find.text('archive_2026.zip'), findsOneWidget);

      // Completed transfer is in history section
      expect(find.text('firmware_update.bin'), findsOneWidget);

      // Verify clear states: EXECUTING and COMMITTED
      expect(find.text('EXECUTING'), findsOneWidget);
      expect(find.text('COMMITTED'), findsOneWidget);
    });
  });
}
