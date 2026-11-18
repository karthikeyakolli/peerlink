import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/main.dart' as app_main;
import 'package:peerlink/core/app_settings_service.dart';
import 'package:peerlink/core/file_staging_service.dart';

void main() {
  group('Minimalist Light-Only Xiaomi File Manager + Integrated Share Tests', () {
    late Directory tempVault;

    setUp(() {
      AppSettingsService.instance.resetForTesting();
      FileStagingService.instance.resetForTesting();
      tempVault = Directory.systemTemp.createTempSync('xiaomi_minimal_fm_test_');
      AppSettingsService.instance.saveLocation = tempVault.path;
      File('${tempVault.path}/invoice.pdf').writeAsStringSync('PDF content');
    });

    tearDown(() {
      try {
        if (tempVault.existsSync()) {
          tempVault.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    testWidgets('Launches directly into pure Light-Only File Manager and opens contextual share sheet on demand',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const app_main.PeerLinkApp());
      await tester.pumpAndSettle();

      // 1. Strictly forced Light Mode — no dark theme
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.themeMode, equals(ThemeMode.light));
      expect(materialApp.darkTheme, isNull);
      expect(materialApp.theme?.brightness, equals(Brightness.light));

      // 2. Default Launch Screen IS the pure File Manager (no separate Share tab or Quick Share card)
      expect(find.byKey(const Key('vault_storage_scope_vault')), findsOneWidget);
      expect(find.byKey(const Key('vault_storage_scope_device')), findsOneWidget);
      expect(find.text('Quick Share'), findsNothing);
      expect(find.text('invoice.pdf'), findsWidgets);

      // 3. Enforce ZERO gradients and ZERO glowing/box shadows on File Manager screen
      for (final container in tester.widgetList<Container>(find.byType(Container))) {
        final dec = container.decoration;
        if (dec is BoxDecoration) {
          expect(dec.gradient, isNull, reason: 'No card or container gradients allowed');
          expect(dec.boxShadow, isNull, reason: 'No glowing or drop shadows allowed');
        }
      }

      // 4. Tapping Contextual Share in AppBar opens the on-demand ContextualShareSheet smoothly
      final shareAction = find.byKey(const Key('appbar_contextual_share_button'));
      expect(shareAction, findsOneWidget);
      await tester.tap(shareAction);
      await tester.pumpAndSettle();

      expect(find.text('Share & Receive'), findsOneWidget);
      expect(find.byKey(const Key('contextual_channel_web_beam')), findsOneWidget);
      expect(find.byKey(const Key('contextual_channel_receive')), findsOneWidget);
      expect(find.byKey(const Key('contextual_channel_hotspot')), findsOneWidget);
      expect(find.byKey(const Key('contextual_channel_text')), findsOneWidget);

      // 5. Enforce ZERO gradients and ZERO shadows inside ContextualShareSheet too
      for (final container in tester.widgetList<Container>(find.byType(Container))) {
        final dec = container.decoration;
        if (dec is BoxDecoration) {
          expect(dec.gradient, isNull, reason: 'No gradients in contextual share sheet');
          expect(dec.boxShadow, isNull, reason: 'No shadows in contextual share sheet');
        }
      }

      // 6. Closing the sheet returns immediately to File Manager
      Navigator.of(tester.element(find.text('Share & Receive'))).pop();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('vault_storage_scope_vault')), findsOneWidget);
    });
  });
}
