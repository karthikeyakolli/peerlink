import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/app_settings_service.dart';
import 'package:peerlink/features/files/received_vault_view.dart';

void main() {
  group('ReceivedVaultView Widget Tests', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('vault_widget_test_');
      AppSettingsService.instance.saveLocation = tempDir.path;
    });

    tearDown(() {
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    testWidgets('renders category chips, search bar, and empty state when empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ReceivedVaultView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search received files...'), findsOneWidget);
      expect(find.text('Photos'), findsOneWidget);
      expect(find.text('Videos'), findsOneWidget);
      expect(find.text('Audio'), findsOneWidget);
      expect(find.text('Docs'), findsOneWidget);
      expect(find.text('Apps'), findsOneWidget);
      expect(find.text('Archives'), findsOneWidget);
      expect(find.text('No Received Files'), findsOneWidget);
    });

    testWidgets('renders received file cards when files are present', (tester) async {
      File('${tempDir.path}/presentation.pdf').writeAsBytesSync([1, 2, 3]);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ReceivedVaultView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('presentation.pdf'), findsWidgets);
      expect(find.byIcon(Icons.remove_red_eye_outlined), findsOneWidget);
    });
  });
}
