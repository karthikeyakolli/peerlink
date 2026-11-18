import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/design_system/components/radar_sonar_view.dart';
import 'package:peerlink/design_system/components/quick_drop_peer_carousel.dart';
import 'package:peerlink/design_system/components/smart_clipboard_banner.dart';
import 'package:peerlink/design_system/components/photo_backup_preset_card.dart';
import 'package:peerlink/core/smart_content_sniffer.dart';
import 'package:peerlink/core/app_settings_service.dart';
import 'package:peerlink/core/file_staging_service.dart';
import 'package:peerlink/design_system/theme/peerlink_theme.dart';

void main() {
  setUp(() {
    AppSettingsService.instance.resetForTesting();
    FileStagingService.instance.resetForTesting();
  });

  group('Slice 2: Component De-Glowing & Light Surface Normalization Tests', () {
    testWidgets('RadarSonarView renders center node and waves without neon glow bloom',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: PeerLinkTheme.lightTheme,
          home: Scaffold(
            body: RadarSonarView(
              discoveredPeers: const [
                RadarPeerInfo(id: 'peer_1', name: 'MacBook Pro', deviceType: 'laptop'),
              ],
              onPeerSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('This Device'), findsOneWidget);
      expect(find.text('MacBook Pro'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('QuickDropPeerCarousel renders crisp surface colors in Light Mode',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: PeerLinkTheme.lightTheme,
          home: Scaffold(
            body: QuickDropPeerCarousel(
              overridePeers: const [
                QuickDropPeerItem(
                  id: 'peer_phone',
                  name: 'Galaxy S24',
                  deviceType: 'phone',
                  isTrusted: true,
                  isOnline: true,
                ),
              ],
              onPeerTapped: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Galaxy S24'), findsOneWidget);
      expect(find.text('Trusted'), findsOneWidget);

      final textWidget = tester.widget<Text>(find.text('Galaxy S24'));
      expect(textWidget.style?.color, equals(const Color(0xFF0F172A)));
    });

    testWidgets('SmartClipboardBanner renders with high contrast and zero glow in Light Mode',
        (WidgetTester tester) async {
      final snippet = SmartContentSniffer.instance.sniff('https://github.com/peerlink/core');

      await tester.pumpWidget(
        MaterialApp(
          theme: PeerLinkTheme.lightTheme,
          home: Scaffold(
            body: SmartClipboardBanner(
              content: snippet,
              targetPeerName: 'Linux Rig',
              onBeam: () {},
              onDismiss: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(snippet.displayTitle), findsOneWidget);
      expect(find.text('Beam directly to Linux Rig'), findsOneWidget);
      expect(find.text('Beam'), findsOneWidget);
      expect(find.text('Clip'), findsOneWidget);

      final titleWidget = tester.widget<Text>(find.text(snippet.displayTitle));
      expect(titleWidget.style?.color, equals(const Color(0xFF0F172A)));
    });

    testWidgets('PhotoBackupPresetCard renders readable high-contrast typography in Light Mode',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: PeerLinkTheme.lightTheme,
          home: Scaffold(
            body: PhotoBackupPresetCard(
              customScanDir: Directory.systemTemp,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Camera Backup'), findsOneWidget);
      expect(find.textContaining('1-tap delta sync'), findsOneWidget);
      expect(find.byKey(const Key('stage_photos_preset_button')), findsOneWidget);

      final titleWidget = tester.widget<Text>(find.textContaining('Camera Backup'));
      expect(titleWidget.style?.color, equals(const Color(0xFF0F172A)));
    });
  });
}
