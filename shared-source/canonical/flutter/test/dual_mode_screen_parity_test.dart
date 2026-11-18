import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/design_system/theme/peerlink_theme.dart';
import 'package:peerlink/features/files/file_manager_home_screen.dart';
import 'package:peerlink/features/home/home_screen.dart';
import 'package:peerlink/features/devices/devices_screen.dart';
import 'package:peerlink/features/files/files_screen.dart';
import 'package:peerlink/features/spaces/spaces_screen.dart';
import 'package:peerlink/features/activity/activity_screen.dart';
import 'package:peerlink/features/search/search_screen.dart';
import 'package:peerlink/features/settings/settings_screen.dart';
import 'package:peerlink/core/app_settings_service.dart';
import 'package:peerlink/core/file_staging_service.dart';

void main() {
  setUp(() {
    AppSettingsService.instance.resetForTesting();
    FileStagingService.instance.resetForTesting();
  });

  group('Minimalist Light-Only Full Screen Parity Tests', () {
    final themeData = PeerLinkTheme.lightTheme;

    testWidgets('FileManagerHomeScreen renders cleanly in forced Light Mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: themeData,
          themeMode: ThemeMode.light,
          home: const FileManagerHomeScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(FileManagerHomeScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('HomeScreen renders cleanly in forced Light Mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: themeData,
          themeMode: ThemeMode.light,
          home: const HomeScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('DevicesScreen renders cleanly in forced Light Mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: themeData,
          themeMode: ThemeMode.light,
          home: const DevicesScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(DevicesScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('FilesScreen renders cleanly in forced Light Mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: themeData,
          themeMode: ThemeMode.light,
          home: const FilesScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(FilesScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('SpacesScreen renders cleanly in forced Light Mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: themeData,
          themeMode: ThemeMode.light,
          home: const SpacesScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(SpacesScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ActivityScreen renders cleanly in forced Light Mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: themeData,
          themeMode: ThemeMode.light,
          home: const ActivityScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(ActivityScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('SearchScreen renders cleanly in forced Light Mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: themeData,
          themeMode: ThemeMode.light,
          home: const SearchScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(SearchScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('SettingsScreen renders cleanly in forced Light Mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: themeData,
          themeMode: ThemeMode.light,
          home: const SettingsScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
