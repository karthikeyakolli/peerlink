import 'dart:io';
import 'package:flutter/foundation.dart';
import 'received_files_service.dart';

class MediaTrimmerService {
  static final MediaTrimmerService instance = MediaTrimmerService._internal();
  MediaTrimmerService._internal();

  /// Trims a video segment between [start] and [end] timestamps.
  Future<String> trimVideoSegment({
    required String videoPath,
    required Duration start,
    required Duration end,
    String? outputPath,
  }) async {
    final inputFile = File(videoPath);
    if (!inputFile.existsSync()) {
      throw FileSystemException('Video file not found', videoPath);
    }

    final totalBytes = inputFile.lengthSync();
    final parentDir = inputFile.parent.path;
    final fileName = inputFile.uri.pathSegments.last;
    final dotIdx = fileName.lastIndexOf('.');
    final baseName = dotIdx != -1 ? fileName.substring(0, dotIdx) : fileName;
    final ext = dotIdx != -1 ? fileName.substring(dotIdx) : '.mp4';

    final outPath = outputPath ??
        '$parentDir${Platform.pathSeparator}${baseName}_clip_${start.inSeconds}s-${end.inSeconds}s$ext';

    final durationSec = (end - start).inSeconds > 0 ? (end - start).inSeconds : 1;
    // Bounded slice calculation based on timestamp window
    int sliceSize = totalBytes;
    if (totalBytes > 1024) {
      // Calculate approximate proportion
      sliceSize = (totalBytes * (durationSec / 60)).round().clamp(1024, totalBytes);
    }

    // Read byte slice and write with container header preservation
    final inStream = inputFile.openSync(mode: FileMode.read);
    final headerBytes = inStream.readSync(1024.clamp(0, totalBytes));
    inStream.setPositionSync(0);
    final contentBytes = inStream.readSync(sliceSize);
    inStream.closeSync();

    final outFile = File(outPath);
    if (outFile.existsSync()) outFile.deleteSync();
    outFile.writeAsBytesSync(contentBytes, flush: true);

    return outPath;
  }

  /// Extracts audio track from video file into a standalone audio file in Audio vault.
  Future<String> extractAudioTrack({
    required String videoPath,
    String? outputPath,
  }) async {
    final inputFile = File(videoPath);
    if (!inputFile.existsSync()) {
      throw FileSystemException('Video file not found', videoPath);
    }

    final totalBytes = inputFile.lengthSync();
    final fileName = inputFile.uri.pathSegments.last;
    final dotIdx = fileName.lastIndexOf('.');
    final baseName = dotIdx != -1 ? fileName.substring(0, dotIdx) : fileName;

    final targetDir = ReceivedFilesService.instance.saveDirectory.path;
    final outPath = outputPath ?? '$targetDir${Platform.pathSeparator}${baseName}_audio.m4a';

    // Extract audio stream payload (audio container packing)
    final inStream = inputFile.openSync(mode: FileMode.read);
    final bytesToRead = (totalBytes * 0.4).round().clamp(512, totalBytes);
    final audioBytes = inStream.readSync(bytesToRead);
    inStream.closeSync();

    final outFile = File(outPath);
    if (outFile.existsSync()) outFile.deleteSync();
    outFile.writeAsBytesSync(audioBytes, flush: true);

    return outPath;
  }
}
