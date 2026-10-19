import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/features/home/local_node_card.dart';

void main() {
  testWidgets('LocalNodeCard: Android Native Mode runs zero-config and hides desktop manual IPC controls',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LocalNodeCard(forceAndroidMode: true),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 1. Assert Android Native Node header is present
    expect(find.text('Android Native Node'), findsOneWidget);
    expect(find.text('Zero-Config Direct P2P'), findsOneWidget);

    // 2. Assert desktop manual input fields and test buttons are NOT displayed in Android mode
    expect(find.text('Desktop Local Node IPC'), findsNothing);
    expect(find.text('IPC Auth Token'), findsNothing);
    expect(find.text('Port'), findsNothing);
    expect(find.text('Test Incompatible Version'), findsNothing);

    // 3. Assert zero-config informational fields are visible
    expect(find.text('Local Peer ID'), findsOneWidget);
    expect(find.text('Keystore Security Tier'), findsOneWidget);
    expect(find.text('Active Listeners'), findsOneWidget);
    expect(find.text('OS Background Mode'), findsOneWidget);

    // 4. Assert zero-config routine actions are present
    expect(find.text('Refresh Status'), findsOneWidget);
    expect(find.text('Restart Node'), findsOneWidget);
    expect(find.text('Show Details'), findsOneWidget);

    // 5. Assert diagnostics drawer expands on demand
    await tester.tap(find.text('Show Details'));
    await tester.pumpAndSettle();

    expect(find.text('Hide Details'), findsOneWidget);
    expect(find.text('Technical Route Diagnostics'), findsOneWidget);
    expect(find.textContaining('Usable Transports:'), findsOneWidget);
  });

  testWidgets('LocalNodeCard: Desktop Mode preserves desktop IPC parameters for backward compatibility',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LocalNodeCard(forceAndroidMode: false),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 1. Assert Desktop Local Node IPC is present
    expect(find.text('Desktop Local Node IPC'), findsOneWidget);
    expect(find.text('IPC Auth Token'), findsOneWidget);
    expect(find.text('Port'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
    expect(find.text('Test Incompatible Version'), findsOneWidget);

    // 2. Assert Android native items are not present
    expect(find.text('Android Native Node'), findsNothing);
    expect(find.text('Zero-Config Direct P2P'), findsNothing);
  });
}
