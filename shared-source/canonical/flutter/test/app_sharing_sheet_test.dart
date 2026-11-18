import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/app_sharing_service.dart';
import 'package:peerlink/design_system/components/app_sharing_sheet.dart';

void main() {
  group('AppSharingSheet Widget Tests', () {
    setUp(() {
      AppSharingService.instance.setCustomAppsForTesting([
        const SharedAppInfo(
          packageName: 'com.example.game',
          appName: 'Super Runner Game',
          versionName: '1.2.0',
          sizeBytes: 85000000,
          apkPath: '/data/app/game.apk',
        ),
      ]);
    });

    testWidgets('renders apps and stages on tap Send', (tester) async {
      SharedAppInfo? selectedApp;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 800,
              child: AppSharingSheet(
                onAppSelected: (app) => selectedApp = app,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Share Installed Apps (APK)'), findsOneWidget);
      expect(find.text('Super Runner Game'), findsOneWidget);
      expect(find.text('Send'), findsOneWidget);

      await tester.tap(find.text('Send'));
      await tester.pump();

      expect(selectedApp?.appName, 'Super Runner Game');
    });
  });
}
