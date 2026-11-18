import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerlink/core/audio_player_service.dart';
import 'package:peerlink/core/archive_studio_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('audio_archive_test_');
    AudioPlayerService.instance.resetForTesting();
  });

  tearDown(() {
    AudioPlayerService.instance.resetForTesting();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Task 1 — AudioPlayerService Suite', () {
    test('parses fallback metadata when file has no ID3 tags', () async {
      final dummyAudio = File('${tempDir.path}/test_song.mp3');
      dummyAudio.writeAsBytesSync([0x00, 0x01, 0x02, 0x03]);

      final track = await AudioPlayerService.parseAudioMetadata(dummyAudio.path);
      expect(track.fileName, 'test_song.mp3');
      expect(track.displayTitle, 'test_song');
      expect(track.displayArtist, 'Local Audio');
      expect(track.duration.inMinutes, 3);
    });

    test('manages playlist queue, play, pause, seek and speed', () async {
      final song1 = File('${tempDir.path}/song1.mp3')..writeAsBytesSync([1, 2, 3]);
      final song2 = File('${tempDir.path}/song2.mp3')..writeAsBytesSync([4, 5, 6]);

      final service = AudioPlayerService.instance;
      await service.loadFolderQueue([song1.path, song2.path]);

      expect(service.queue.length, 2);
      expect(service.currentIndex, 0);
      expect(service.currentTrack?.fileName, 'song1.mp3');
      expect(service.isPlaying, isTrue);

      service.pause();
      expect(service.isPlaying, isFalse);

      service.seekTo(const Duration(seconds: 45));
      expect(service.position.inSeconds, 45);

      service.setPlaybackSpeed(1.5);
      expect(service.speedNotifier.value, 1.5);

      service.skipNext();
      expect(service.currentIndex, 1);
      expect(service.currentTrack?.fileName, 'song2.mp3');

      service.cycleLoopMode();
      expect(service.loopModeNotifier.value, AudioLoopMode.all);

      service.cycleLoopMode();
      expect(service.loopModeNotifier.value, AudioLoopMode.one);

      service.closeMiniPlayer();
      expect(service.currentTrack, isNull);
      expect(service.queue.isEmpty, isTrue);
    });
  });

  group('Task 1 — ArchiveStudioService Suite', () {
    test('creates archive with compression ratio telemetry and inspects in-place', () async {
      final doc1 = File('${tempDir.path}/report.txt')..writeAsStringSync('Hello PeerLink World! ' * 50);
      final doc2 = File('${tempDir.path}/data.csv')..writeAsStringSync('id,name,role\n1,Alice,Dev\n2,Bob,Sec\n');

      final zipPath = '${tempDir.path}/output_bundle.zip';
      final result = await ArchiveStudioService.instance.createArchiveWithTelemetry(
        [doc1.path, doc2.path],
        zipPath,
        password: 'vault-password',
      );

      expect(File(result.outputPath).existsSync(), isTrue);
      expect(result.fileCount, 2);
      expect(result.isEncrypted, isTrue);
      expect(result.totalOriginalBytes > 0, isTrue);

      final details = await ArchiveStudioService.instance.inspectArchive(zipPath);
      expect(details.fileCount, 2);
      expect(details.entries.any((e) => e.name == 'report.txt'), isTrue);
      expect(details.entries.any((e) => e.name == 'data.csv'), isTrue);
    });

    test('extracts single entry selectively without extracting entire archive', () async {
      final fileA = File('${tempDir.path}/fileA.txt')..writeAsStringSync('Content AAAAAAAAAA');
      final fileB = File('${tempDir.path}/fileB.txt')..writeAsStringSync('Content BBBBBBBBBB');

      final zipPath = '${tempDir.path}/test_archive.zip';
      await ArchiveStudioService.instance.createArchiveWithTelemetry([fileA.path, fileB.path], zipPath);

      final extractDir = '${tempDir.path}/single_extracted';
      final extracted = await ArchiveStudioService.instance.extractSingleEntry(zipPath, 'fileB.txt', extractDir);

      expect(extracted, isNotNull);
      expect(extracted!.existsSync(), isTrue);
      expect(extracted.readAsStringSync(), 'Content BBBBBBBBBB');
      // Verify fileA was NOT extracted into single_extracted
      expect(File('$extractDir/fileA.txt').existsSync(), isFalse);
    });
  });
}
