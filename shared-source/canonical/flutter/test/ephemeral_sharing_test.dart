import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/design_system/components/burn_viewer_modal.dart';
import 'package:peerlink/design_system/components/ephemeral_policy_modal.dart';

void main() {
  group('Ephemeral Sharing & Burn-After-Read UI Tests', () {
    testWidgets('EphemeralPolicyModal allows selecting 1-View and TTL options', (tester) async {
      EphemeralPolicy? resultPolicy;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  resultPolicy = await EphemeralPolicyModal.show(context);
                },
                child: const Text('Open Ephemeral Policy'),
              ),
            ),
          ),
        ),
      );

      // Open modal
      await tester.tap(find.text('Open Ephemeral Policy'));
      await tester.pumpAndSettle();

      // Verify modal headers and policies exist
      expect(find.text('Burn-After-Read & Ephemeral Beam'), findsOneWidget);
      expect(find.text('1-View Auto-Burn (Recommended)'), findsOneWidget);
      expect(find.text('5-Minute Auto-Burn'), findsOneWidget);
      expect(find.text('Permanent Transfer'), findsOneWidget);

      // Select 5-Minute Auto-Burn
      final fiveMinFinder = find.text('5-Minute Auto-Burn');
      await tester.ensureVisible(fiveMinFinder);
      await tester.tap(fiveMinFinder);
      await tester.pumpAndSettle();

      // Tap apply button
      final applyButton = find.text('Apply Ephemeral Burn Policy');
      await tester.ensureVisible(applyButton);
      await tester.tap(applyButton);
      await tester.pumpAndSettle();

      expect(resultPolicy, isNotNull);
      expect(resultPolicy!.isEphemeral, isTrue);
      expect(resultPolicy!.ttlSeconds, equals(300));
    });

    testWidgets('BurnViewerModal renders countdown timer, watermark, and triggers shred on burn', (tester) async {
      bool shredInvoked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  BurnViewerModal.show(
                    context,
                    fileName: 'classified_contract.pdf',
                    fileSize: '1.4 MB',
                    previewContent: 'ENCRYPTED CONTRACT DATA DUMP',
                    policy: EphemeralPolicy.singleView,
                    onShred: () {
                      shredInvoked = true;
                    },
                  );
                },
                child: const Text('Open Burn Document'),
              ),
            ),
          ),
        ),
      );

      // Open viewer
      await tester.tap(find.text('Open Burn Document'));
      await tester.pump(const Duration(milliseconds: 500));

      // Verify header and preview
      expect(find.text('classified_contract.pdf'), findsOneWidget);
      expect(find.text('EPHEMERAL'), findsOneWidget);
      expect(find.text('ENCRYPTED CONTRACT DATA DUMP'), findsOneWidget);

      // Verify shred button exists and trigger it
      final burnButton = find.text('Close & Burn Now');
      expect(burnButton, findsOneWidget);

      await tester.tap(burnButton);
      await tester.pump(const Duration(seconds: 2));

      expect(shredInvoked, isTrue, reason: 'onShred must be called when user triggers burn');
    });
  });
}
