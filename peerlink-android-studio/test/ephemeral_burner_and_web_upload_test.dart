import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/app_settings_service.dart';
import 'package:peerlink/core/ephemeral_burner_share_service.dart';
import 'package:peerlink/core/received_files_service.dart';
import 'package:peerlink/core/web_beam_server_service.dart';
import 'package:peerlink/design_system/components/burner_viewer_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late File sampleFile;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('peerlink_burner_test_');
    sampleFile = File('${tempDir.path}${Platform.pathSeparator}secret.txt')
      ..writeAsStringSync('TOP SECRET BURNER CONTENT');
    AppSettingsService.instance.saveLocation = tempDir.path;
  });

  tearDown(() {
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('EphemeralBurnerShareService Tests', () {
    test('createBurnerShare and access without PIN', () {
      final service = EphemeralBurnerShareService.instance;
      final token = service.createBurnerShare(
        filePath: sampleFile.path,
        validDuration: const Duration(minutes: 5),
        maxViews: 1,
      );

      expect(token.fileName, 'secret.txt');
      expect(token.isExpired, isFalse);

      final access = service.accessBurnerShare(token.id);
      expect(access.isAuthorized, isTrue);
      expect(utf8.decode(access.fileBytes!), 'TOP SECRET BURNER CONTENT');

      // Second access should fail because maxViews = 1
      final access2 = service.accessBurnerShare(token.id);
      expect(access2.isAuthorized, isFalse);
      expect(access2.errorMessage, contains('self-destructed or expired'));
    });

    test('createBurnerShare with PIN verification', () {
      final service = EphemeralBurnerShareService.instance;
      final token = service.createBurnerShare(
        filePath: sampleFile.path,
        pin: '1234',
        validDuration: const Duration(minutes: 5),
        maxViews: 1,
      );

      // Wrong PIN
      final fail = service.accessBurnerShare(token.id, pin: '9999');
      expect(fail.isAuthorized, isFalse);
      expect(fail.errorMessage, contains('Incorrect'));

      // Correct PIN
      final ok = service.accessBurnerShare(token.id, pin: '1234');
      expect(ok.isAuthorized, isTrue);
      expect(utf8.decode(ok.fileBytes!), 'TOP SECRET BURNER CONTENT');
    });

    test('revokeBurnerShare permanently wipes token access', () {
      final service = EphemeralBurnerShareService.instance;
      final token = service.createBurnerShare(
        filePath: sampleFile.path,
        validDuration: const Duration(minutes: 10),
      );

      service.revokeBurnerShare(token.id);
      final res = service.accessBurnerShare(token.id);
      expect(res.isAuthorized, isFalse);
    });
  });

  group('WebBeamServerService Bi-Directional Upload Tests', () {
    test('sanitizeUploadFileName prevents directory traversal and illegal chars', () {
      expect(WebBeamServerService.sanitizeUploadFileName('../../etc/passwd'), 'passwd');
      expect(WebBeamServerService.sanitizeUploadFileName('..\\windows\\system32\\cmd.exe'), 'cmd.exe');
      expect(WebBeamServerService.sanitizeUploadFileName('hello*world?.txt'), 'hello_world_.txt');
      expect(WebBeamServerService.sanitizeUploadFileName(''), 'uploaded_file.bin');
      expect(WebBeamServerService.sanitizeUploadFileName('my notes.pdf'), 'my notes.pdf');
    });

    test('Real HTTP POST /upload saves file to vault and handles duplicate collisions', () async {
      final prevOverrides = HttpOverrides.current;
      HttpOverrides.global = null;
      addTearDown(() => HttpOverrides.global = prevOverrides);

      final serverService = WebBeamServerService.instance;
      await serverService.start(
        paths: [sampleFile.path],
        overrideHostIp: '127.0.0.1',
      );

      final state = serverService.currentState;
      expect(state.isRunning, isTrue);

      final client = HttpClient();

      // Upload file 1: notes.txt
      final uri1 = Uri.parse('http://127.0.0.1:${state.port}/upload?token=${state.token}&name=notes.txt');
      final req1 = await client.postUrl(uri1);
      req1.add(utf8.encode('Uploaded note content 123'));
      final resp1 = await req1.close();
      expect(resp1.statusCode, HttpStatus.ok);

      final body1 = await utf8.decodeStream(resp1);
      final json1 = jsonDecode(body1) as Map<String, dynamic>;
      expect(json1['ok'], isTrue);
      expect(json1['name'], 'notes.txt');

      final saved1 = File('${tempDir.path}${Platform.pathSeparator}notes.txt');
      expect(saved1.existsSync(), isTrue);
      expect(saved1.readAsStringSync(), 'Uploaded note content 123');

      // Upload file 2 with same name -> collision avoidance 'notes (1).txt'
      final uri2 = Uri.parse('http://127.0.0.1:${state.port}/upload?token=${state.token}&name=notes.txt');
      final req2 = await client.postUrl(uri2);
      req2.add(utf8.encode('Second version of notes'));
      final resp2 = await req2.close();
      expect(resp2.statusCode, HttpStatus.ok);

      final body2 = await utf8.decodeStream(resp2);
      final json2 = jsonDecode(body2) as Map<String, dynamic>;
      expect(json2['ok'], isTrue);
      expect(json2['name'], 'notes (1).txt');

      final saved2 = File('${tempDir.path}${Platform.pathSeparator}notes (1).txt');
      expect(saved2.existsSync(), isTrue);
      expect(saved2.readAsStringSync(), 'Second version of notes');

      client.close();
      await serverService.stop();
    });
  });

  group('BurnerViewerModal Widget Tests', () {
    testWidgets('BurnerViewerModal unlocks with PIN and displays content', (tester) async {
      final service = EphemeralBurnerShareService.instance;
      final token = service.createBurnerShare(
        filePath: sampleFile.path,
        pin: '4321',
        validDuration: const Duration(minutes: 5),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BurnerViewerModal(token: token),
          ),
        ),
      );
      await tester.pump();

      // Should display PIN prompt
      expect(find.text('Enter 4-Digit Security PIN'), findsOneWidget);
      expect(find.byKey(const Key('burner_pin_input')), findsOneWidget);

      // Enter wrong PIN
      await tester.enterText(find.byKey(const Key('burner_pin_input')), '0000');
      await tester.tap(find.byKey(const Key('unlock_burner_button')));
      await tester.pump();

      expect(find.text('Incorrect 4-digit security PIN.'), findsOneWidget);

      // Enter correct PIN
      await tester.enterText(find.byKey(const Key('burner_pin_input')), '4321');
      await tester.tap(find.byKey(const Key('unlock_burner_button')));
      await tester.pump();

      // Content decrypted to memory
      expect(find.text('TOP SECRET BURNER CONTENT'), findsOneWidget);
      expect(find.byKey(const Key('close_and_burn_button')), findsOneWidget);

      // Tap Close & Destroy
      await tester.tap(find.byKey(const Key('close_and_burn_button')));
      await tester.pump();

      // Verify token is revoked in service
      expect(token.isRevoked, isTrue);
      final accessAfter = service.accessBurnerShare(token.id);
      expect(accessAfter.isAuthorized, isFalse);
    });
  });
}
