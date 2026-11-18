import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/app/peerlink_app.dart';
import 'package:peerlink/core/app_settings_service.dart';
import 'package:peerlink/features/settings/settings_screen.dart';
import 'package:peerlink/features/files/files_screen.dart';

void main() {
  setUp(() {
    AppSettingsService.instance.resetForTesting();
  });

  tearDown(() {
    AppSettingsService.instance.resetForTesting();
  });

  group('Minimalist Light-Mode-Only & Streamlined Send Tests', () {
    testWidgets('SettingsScreen removes Dark Mode switcher completely',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Dark Mode / Interface Mode selector is completely removed
      expect(find.text('Appearance & Theme'), findsNothing);
      expect(find.text('Interface Mode'), findsNothing);
      expect(find.text('Dark'), findsNothing);

      // Verify AppSettingsService forces ThemeMode.light unconditionally
      expect(AppSettingsService.instance.themeMode, equals(ThemeMode.light));
      AppSettingsService.instance.themeMode = ThemeMode.dark;
      expect(AppSettingsService.instance.themeMode, equals(ThemeMode.light));
      AppSettingsService.instance.setThemeModeFromString('dark');
      expect(AppSettingsService.instance.themeMode, equals(ThemeMode.light));
      AppSettingsService.instance.setThemeModeFromString('system');
      expect(AppSettingsService.instance.themeMode, equals(ThemeMode.light));
    });

    testWidgets('FilesScreen renders streamlined send action bar with high clarity',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FilesScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify primary and secondary send buttons are all present
      expect(find.text('Add Files...'), findsOneWidget);
      expect(find.text('Add Folder...'), findsOneWidget);
      expect(find.text('Categories...'), findsOneWidget);
      expect(find.text('Pick SAF File'), findsOneWidget);
      expect(find.text('Text / Link...'), findsOneWidget);
      expect(find.text('Paste'), findsOneWidget);

      // Verify no 'Clear' button when empty
      expect(find.text('Clear'), findsNothing);
    });

    testWidgets('PeerLinkApp strictly forces Light Mode with no darkTheme',
        (WidgetTester tester) async {
      await tester.pumpWidget(const PeerLinkApp());
      await tester.pumpAndSettle();

      MaterialApp app = tester.widget(find.byType(MaterialApp));
      expect(app.themeMode, equals(ThemeMode.light));
      expect(app.darkTheme, isNull);
      expect(app.theme?.brightness, equals(Brightness.light));

      // Attempting to mutate setting to dark cannot override forced light mode
      AppSettingsService.instance.themeMode = ThemeMode.dark;
      await tester.pumpAndSettle();

      app = tester.widget(find.byType(MaterialApp));
      expect(app.themeMode, equals(ThemeMode.light));
      expect(app.darkTheme, isNull);
    });
  });
}
