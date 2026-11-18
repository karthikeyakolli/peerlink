import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/device_trust_service.dart';
import 'package:peerlink/core/operation_journal_service.dart';
import 'package:peerlink/core/sync_backup_service.dart';
import 'package:peerlink/design_system/components/contextual_share_sheet.dart';
import 'package:peerlink/features/files/file_manager_home_screen.dart';
import 'package:peerlink/features/home/home_screen.dart';
import 'package:peerlink/features/devices/devices_screen.dart';
import 'package:peerlink/features/files/files_screen.dart';
import 'package:peerlink/features/spaces/spaces_screen.dart';
import 'package:peerlink/features/settings/settings_screen.dart';
import 'package:peerlink/features/activity/activity_screen.dart';
import 'package:peerlink/features/search/search_screen.dart';
import 'package:peerlink/features/onboarding/first_run_permissions_screen.dart';

void main() {
  setUp(() {
    DeviceTrustService.instance.resetForTesting();
    OperationJournalService.instance.resetForTesting();
    SyncBackupService.instance.resetForTesting();
  });

  const widths = [320.0, 360.0, 393.0];
  const fontScales = [1.0, 1.3, 2.0];

  Future<void> testScreenAtConstraints(
    WidgetTester tester, {
    required Widget screen,
    required double width,
    required double fontScale,
    bool withKeyboard = false,
  }) async {
    tester.view.physicalSize = Size(width, 840);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: Size(width, 840),
          textScaler: TextScaler.linear(fontScale),
          padding: const EdgeInsets.only(top: 24, bottom: 16),
          viewInsets: withKeyboard ? const EdgeInsets.only(bottom: 280) : EdgeInsets.zero,
        ),
        child: MaterialApp(
          home: screen,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull,
        reason: 'Screen ${screen.runtimeType} must not throw overflow exceptions at width $width dp, font scale $fontScale');
  }

  group('Rule 8 — Responsive Viewport Constraints Suite', () {
    for (final width in widths) {
      for (final fontScale in fontScales) {
        testWidgets('FileManagerHomeScreen renders without overflow at ${width}dp width, font scale $fontScale',
            (WidgetTester tester) async {
          await testScreenAtConstraints(
            tester,
            screen: const FileManagerHomeScreen(),
            width: width,
            fontScale: fontScale,
          );
        });

        testWidgets('HomeScreen renders without overflow at ${width}dp width, font scale $fontScale',
            (WidgetTester tester) async {
          await testScreenAtConstraints(
            tester,
            screen: const HomeScreen(),
            width: width,
            fontScale: fontScale,
          );
        });

        testWidgets('DevicesScreen renders without overflow at ${width}dp width, font scale $fontScale',
            (WidgetTester tester) async {
          await testScreenAtConstraints(
            tester,
            screen: const DevicesScreen(),
            width: width,
            fontScale: fontScale,
          );
        });

        testWidgets('FilesScreen renders without overflow at ${width}dp width, font scale $fontScale',
            (WidgetTester tester) async {
          await testScreenAtConstraints(
            tester,
            screen: const FilesScreen(),
            width: width,
            fontScale: fontScale,
          );
        });

        testWidgets('SpacesScreen renders without overflow at ${width}dp width, font scale $fontScale',
            (WidgetTester tester) async {
          await testScreenAtConstraints(
            tester,
            screen: const SpacesScreen(),
            width: width,
            fontScale: fontScale,
          );
        });

        testWidgets('SettingsScreen renders without overflow at ${width}dp width, font scale $fontScale',
            (WidgetTester tester) async {
          await testScreenAtConstraints(
            tester,
            screen: const SettingsScreen(),
            width: width,
            fontScale: fontScale,
          );
        });

        testWidgets('ActivityScreen renders without overflow at ${width}dp width, font scale $fontScale',
            (WidgetTester tester) async {
          await testScreenAtConstraints(
            tester,
            screen: const ActivityScreen(),
            width: width,
            fontScale: fontScale,
          );
        });

        testWidgets('SearchScreen renders without overflow at ${width}dp width, font scale $fontScale',
            (WidgetTester tester) async {
          await testScreenAtConstraints(
            tester,
            screen: const SearchScreen(),
            width: width,
            fontScale: fontScale,
          );
        });

        testWidgets('FirstRunPermissionsScreen renders without overflow at ${width}dp width, font scale $fontScale',
            (WidgetTester tester) async {
          await testScreenAtConstraints(
            tester,
            screen: FirstRunPermissionsScreen(onComplete: () {}),
            width: width,
            fontScale: fontScale,
          );
        });
      }
    }

    testWidgets('SearchScreen and Dialogs handle keyboard viewInsets without overflow at 320dp',
        (WidgetTester tester) async {
      await testScreenAtConstraints(
        tester,
        screen: const SearchScreen(),
        width: 320.0,
        fontScale: 1.3,
        withKeyboard: true,
      );
    });

    testWidgets('ContextualShareSheet renders without overflow at 320dp width, font scale 2.0',
        (WidgetTester tester) async {
      await testScreenAtConstraints(
        tester,
        screen: const Scaffold(
          body: ContextualShareSheet(
            initialPaths: ['/tmp/very_long_presentation_slide_deck_final_v2.pdf'],
          ),
        ),
        width: 320.0,
        fontScale: 2.0,
      );
    });
  });
}
