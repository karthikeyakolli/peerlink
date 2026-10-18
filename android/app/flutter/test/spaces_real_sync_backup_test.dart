import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/sync_backup_service.dart';
import 'package:peerlink/features/spaces/spaces_screen.dart';

void main() {
  setUp(() {
    SyncBackupService.instance.resetForTesting();
  });

  testWidgets('SpacesScreen: shows empty state when no spaces, does not contain hardcoded fake spaces',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SpacesScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 1. Assert NO hardcoded fake spaces or snapshots
    expect(find.text('Work Documents'), findsNothing);
    expect(find.text('Code Projects & Repos'), findsNothing);
    expect(find.text('Media Vault (Mirror)'), findsNothing);
    expect(find.text('SHA256:4a8b7c6d5e4f3a2b1c0d9e8f7a6b5c4d'), findsNothing);

    // 2. Shows empty state for sync spaces
    expect(find.textContaining('No sync spaces configured', findRichText: true), findsOneWidget);
  });

  testWidgets('SpacesScreen: conflict resolution preserves both files without silent data loss',
      (WidgetTester tester) async {
    // Add a space with pending conflict
    SyncBackupService.instance.addSpace(
      const SyncSpace(
        id: 'space_docs',
        name: 'Project Docs',
        localPath: 'C:\\Docs',
        remotePeerId: 'peer_node_1',
        mode: SyncMode.twoWaySync,
        status: SyncStatus.conflictDetected,
        fileCount: 15,
        lastSyncTime: '5m ago',
        pendingConflicts: 1,
        conflictFile: 'spec.json',
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: SpacesScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Project Docs'), findsOneWidget);
    expect(find.text('Resolve Conflict (1)'), findsOneWidget);

    // Open conflict resolver
    await tester.tap(find.text('Resolve Conflict (1)'));
    await tester.pumpAndSettle();

    // Verify KEEP_BOTH choice exists and explains non-destructive behavior
    expect(find.text('Keep Both (Recommended)'), findsOneWidget);
    expect(find.textContaining('Preserves local file and saves remote version as', findRichText: true), findsOneWidget);

    // Select Keep Both
    await tester.tap(find.text('Keep Both (Recommended)'));
    await tester.pumpAndSettle();

    // Verify conflict is resolved in SyncBackupService
    expect(SyncBackupService.instance.spaces.first.status, SyncStatus.inSync);
    expect(SyncBackupService.instance.spaces.first.pendingConflicts, 0);
  });

  testWidgets('SpacesScreen: mass change warning enforces safety hold',
      (WidgetTester tester) async {
    SyncBackupService.instance.addSpace(
      const SyncSpace(
        id: 'space_vault',
        name: 'Archive Vault',
        localPath: 'C:\\Archive',
        remotePeerId: 'peer_node_1',
        mode: SyncMode.oneWayMirror,
        status: SyncStatus.massChangePaused,
        fileCount: 200,
        lastSyncTime: '1h ago',
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: SpacesScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Review Mass Changes'), findsOneWidget);

    // Tap review
    await tester.tap(find.text('Review Mass Changes'));
    await tester.pumpAndSettle();

    expect(find.text('Mass-Change Circuit Breaker'), findsOneWidget);
    expect(find.textContaining('You must explicitly review and authorize before deletions are applied', findRichText: true), findsOneWidget);

    // Reject deletions
    await tester.tap(find.text('Reject Deletions'));
    await tester.pumpAndSettle();

    // Hold resolved safely
    expect(SyncBackupService.instance.spaces.first.status, SyncStatus.inSync);
  });

  testWidgets('SpacesScreen: Backup tab displays real snapshot and safe non-destructive restore',
      (WidgetTester tester) async {
    // Add a verified snapshot
    await SyncBackupService.instance.createSnapshot(
      name: 'Verified Ledger Snapshot',
      folderPath: 'C:\\Ledger',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: SpacesScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Switch to Backup tab
    await tester.tap(find.text('BACKUPS & SNAPSHOTS'));
    await tester.pumpAndSettle();

    expect(find.text('Verified Ledger Snapshot'), findsOneWidget);
    expect(find.text('Restore Snapshot'), findsOneWidget);

    // Open restore dialog
    await tester.tap(find.text('Restore Snapshot'));
    await tester.pumpAndSettle();

    expect(find.textContaining('NEVER overwrites or deletes past backup snapshots', findRichText: true), findsOneWidget);
  });
}
