import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/features/onboarding/first_run_permissions_screen.dart';

void main() {
  testWidgets('FirstRunPermissionsScreen displays truthful permission capabilities and non-blocking continuation',
      (WidgetTester tester) async {
    bool completed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: FirstRunPermissionsScreen(
          onComplete: () => completed = true,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Assert key capabilities are displayed
    expect(find.text('First-Run Setup'), findsOneWidget);
    expect(find.text('Nearby Device Discovery'), findsOneWidget);
    expect(find.text('Transfer Alerts & Progress'), findsOneWidget);
    expect(find.text('QR Code Pairing (Camera)'), findsOneWidget);
    expect(find.text('Scoped File Access'), findsOneWidget);

    // Assert non-blocking continue action is present
    expect(find.textContaining('Continue', findRichText: true), findsOneWidget);

    // Scroll to and tap continue to peerlink
    final continueBtn = find.byType(OutlinedButton);
    await tester.ensureVisible(continueBtn);
    await tester.tap(continueBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(completed, isTrue);
  });

  test('OnboardingPreferences correctly persists and reads completion status', () async {
    await OnboardingPreferences.setOnboardingCompleted(false);
    expect(await OnboardingPreferences.isOnboardingCompleted(), isFalse);

    await OnboardingPreferences.setOnboardingCompleted(true);
    expect(await OnboardingPreferences.isOnboardingCompleted(), isTrue);
  });
}
