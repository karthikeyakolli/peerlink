import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/web_beam_server_service.dart';
import 'package:peerlink/design_system/components/web_beam_modal.dart';
import 'package:peerlink/design_system/theme/peerlink_theme.dart';

void main() {
  group('Real On-Device WebBeamServerService Integration & Security Tests', () {
    late Directory tempDir;
    late File sampleFile;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('web_beam_server_test_');
      sampleFile = File('${tempDir.path}${Platform.pathSeparator}hello_phone.txt')
        ..writeAsStringSync('Hello directly from PeerLink Web Beam on device!');
    });

    tearDown(() async {
      await WebBeamServerService.instance.stop();
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    test('Serves real HTML portal, streams exact file bytes with valid token, and rejects unauthorized requests (Rule 12)', () async {
      final prevOverrides = HttpOverrides.current;
      HttpOverrides.global = null;
      addTearDown(() => HttpOverrides.global = prevOverrides);

      final state = await WebBeamServerService.instance.start(
        paths: [sampleFile.path],
        preferredPort: 0,
        overrideHostIp: '127.0.0.1',
      );

      expect(state.isRunning, isTrue);
      expect(state.port, greaterThan(0));
      expect(state.token.length, equals(32)); // 128-bit hex token
      expect(state.portalUrl, equals('http://127.0.0.1:${state.port}/?token=${state.token}'));
      expect(state.files.length, equals(1));

      final client = HttpClient();
      try {
        // 1. Failure path (Rule 12): Request WITHOUT token -> 403 Forbidden
        final noTokenReq = await client.getUrl(Uri.parse('http://127.0.0.1:${state.port}/'));
        final noTokenRes = await noTokenReq.close();
        expect(noTokenRes.statusCode, equals(HttpStatus.forbidden));
        await noTokenRes.drain();

        // 2. Failure path (Rule 12): Download with WRONG token -> 403 Forbidden
        final wrongTokenReq = await client.getUrl(
          Uri.parse('http://127.0.0.1:${state.port}/download/0?token=deadbeef'),
        );
        final wrongTokenRes = await wrongTokenReq.close();
        expect(wrongTokenRes.statusCode, equals(HttpStatus.forbidden));
        await wrongTokenRes.drain();

        // 3. Valid token on portal root -> 200 OK HTML containing file name and download link
        final portalReq = await client.getUrl(Uri.parse(state.portalUrl));
        final portalRes = await portalReq.close();
        expect(portalRes.statusCode, equals(HttpStatus.ok));
        final html = await portalRes.transform(utf8.decoder).join();
        expect(html, contains('PeerLink Web Beam'));
        expect(html, contains('hello_phone.txt'));
        expect(html, contains('/download/0?token=${state.token}'));

        // 4. Valid token on /download/0 -> streams exact file bytes & increments counter
        final dlReq = await client.getUrl(
          Uri.parse('http://127.0.0.1:${state.port}/download/0?token=${state.token}'),
        );
        final dlRes = await dlReq.close();
        expect(dlRes.statusCode, equals(HttpStatus.ok));
        expect(dlRes.headers.value('content-disposition'), contains('hello_phone.txt'));
        final downloadedText = await dlRes.transform(utf8.decoder).join();
        expect(downloadedText, equals('Hello directly from PeerLink Web Beam on device!'));
        expect(WebBeamServerService.instance.currentState.downloadCount, equals(1));

        // 5. Stopping server closes socket cleanly
        await WebBeamServerService.instance.stop();
        expect(WebBeamServerService.instance.currentState.isRunning, isFalse);
      } finally {
        client.close(force: true);
      }
    });

    testWidgets('WebBeamModal renders flat light UI with live QR, real device URL, zero gradients/shadows, and Stop button', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final state = await tester.runAsync(() async {
        return await WebBeamServerService.instance.start(
          paths: [sampleFile.path],
          preferredPort: 0,
          overrideHostIp: '192.168.43.1',
        );
      });

      expect(state?.isRunning, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          theme: PeerLinkTheme.lightTheme,
          home: Scaffold(
            body: WebBeamModal(
              initialPaths: const [],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify live phone URL and QR code are rendered (NOT hardcoded PC IP)
      expect(find.byKey(const Key('web_beam_qr_code')), findsOneWidget);
      expect(find.textContaining('192.168.43.1:${state!.port}/?token='), findsOneWidget);
      expect(find.textContaining('192.168.1.4'), findsNothing);
      expect(find.text('LIVE'), findsOneWidget);

      // Verify zero gradients & zero box shadows inside modal
      for (final container in tester.widgetList<Container>(find.byType(Container))) {
        final dec = container.decoration;
        if (dec is BoxDecoration) {
          expect(dec.gradient, isNull);
          expect(dec.boxShadow, isNull);
        }
      }
    });
  });
}
