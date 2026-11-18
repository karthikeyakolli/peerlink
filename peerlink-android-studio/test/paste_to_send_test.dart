import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/file_staging_service.dart';
import 'package:peerlink/features/home/home_screen.dart';
import 'package:peerlink/features/files/files_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    FileStagingService.instance.resetForTesting();
    tempDir = Directory.systemTemp.createTempSync('peerlink_paste_test_');
  });

  tearDown(() {
    FileStagingService.instance.resetForTesting();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets('HomeScreen renders Paste to Send action chip', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Paste to Send'), findsOneWidget);
    expect(find.byIcon(Icons.paste_rounded), findsWidgets);
  });

  testWidgets('FilesScreen renders Paste action button', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FilesScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Paste'), findsOneWidget);
    expect(find.byIcon(Icons.paste_rounded), findsWidgets);
  });

  testWidgets('Tapping Paste to Send with file path on clipboard stages file', (tester) async {
    final testFile = File('${tempDir.path}/pasted_sample.pdf');
    testFile.writeAsStringSync('sample content');

    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (methodCall) async {
        if (methodCall.method == 'Clipboard.getData') {
          return <String, dynamic>{'text': testFile.path};
        }
        return null;
      },
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Paste to Send'));
    await tester.pumpAndSettle();

    expect(FileStagingService.instance.count, equals(1));
    expect(FileStagingService.instance.stagedFiles.first.name, equals('pasted_sample.pdf'));
  });
}
