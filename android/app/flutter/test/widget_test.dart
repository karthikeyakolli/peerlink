import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/main.dart';

void main() {
  testWidgets('PeerLink shell renders 6 desktop destinations with File Manager first and no separate Share page',
      (WidgetTester tester) async {
    await tester.pumpWidget(const PeerLinkApp());
    await tester.pumpAndSettle();

    expect(find.text('PeerLink'), findsOneWidget);
    expect(find.text('Files'), findsWidgets);
    expect(find.text('Devices'), findsOneWidget);
    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('Spaces'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // Verify File Manager-first launch screen (pure File Manager, no permanent Quick Share block)
    expect(find.byKey(const Key('vault_storage_scope_vault')), findsOneWidget);
    expect(find.byKey(const Key('vault_storage_scope_device')), findsOneWidget);
    expect(find.text('Quick Share'), findsNothing);
    expect(find.byKey(const Key('appbar_contextual_share_button')), findsOneWidget);

    // Verify light-only enforcement
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, equals(ThemeMode.light));
    expect(app.darkTheme, isNull);
  });

  testWidgets('PeerLink shell renders minimalist 3-tab File Manager navigation on mobile viewport',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const PeerLinkApp());
    await tester.pumpAndSettle();

    expect(find.text('PeerLink'), findsOneWidget);
    expect(find.text('Files'), findsWidgets);
    expect(find.text('Devices'), findsOneWidget);
    expect(find.text('Activity'), findsOneWidget);
    // No separate Share tab in the bottom navigation bar
    expect(find.text('Share'), findsNothing);

    // Verify header utilities for Search, Contextual Share, and Settings
    expect(find.byTooltip('Search & Query'), findsOneWidget);
    expect(find.byKey(const Key('appbar_contextual_share_button')), findsOneWidget);
    expect(find.byTooltip('Settings & Security'), findsOneWidget);

    // Tap Search header utility icon
    await tester.tap(find.byTooltip('Search & Query'));
    await tester.pumpAndSettle();
    expect(find.text('Cross-Device Omni-Search'), findsOneWidget);

    // Tap back button in Search
    expect(find.byTooltip('Back to Home'), findsOneWidget);
    await tester.tap(find.byTooltip('Back to Home'));
    await tester.pumpAndSettle();
    expect(find.text('PeerLink'), findsOneWidget);
  });
}
