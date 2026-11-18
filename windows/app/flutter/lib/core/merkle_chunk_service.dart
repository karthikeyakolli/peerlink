import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

class MerkleChunk {
  final int index;
  final int offset;
  final int length;
  final String sha256Hash;

  const MerkleChunk({
    required this.index,
    required this.offset,
    required this.length,
    required this.sha256Hash,
  });
}

class MerkleManifest {
  final String fileId;
  final String fileName;
  final int totalBytes;
  final int chunkSize;
  final int totalChunks;
  final String rootHash;
  final List<String> chunkHashes;

  const MerkleManifest({
    required this.fileId,
    required this.fileName,
    required this.totalBytes,
    required this.chunkSize,
    required this.totalChunks,
    required this.rootHash,
    required this.chunkHashes,
  });

  Map<String, dynamic> toJson() => {
        'fileId': fileId,
        'fileName': fileName,
        'totalBytes': totalBytes,
        'chunkSize': chunkSize,
        'totalChunks': totalChunks,
        'rootHash': rootHash,
        'chunkHashes': chunkHashes,
      };

  factory MerkleManifest.fromJson(Map<String, dynamic> json) {
    return MerkleManifest(
      fileId: json['fileId'] as String,
      fileName: json['fileName'] as String,
      totalBytes: json['totalBytes'] as int,
      chunkSize: json['chunkSize'] as int,
      totalChunks: json['totalChunks'] as int,
      rootHash: json['rootHash'] as String,
      chunkHashes: List<String>.from(json['chunkHashes'] as List),
    );
  }
}

class ChunkBitset {
  final int totalChunks;
  final List<bool> _bits;

  ChunkBitset(this.totalChunks) : _bits = List<bool>.filled(totalChunks, false);

  ChunkBitset._fromList(this.totalChunks, List<bool> bits) : _bits = bits;

  bool isReceived(int index) => (index >= 0 && index < totalChunks) ? _bits[index] : false;

  void markReceived(int index) {
    if (index >= 0 && index < totalChunks) {
      _bits[index] = true;
    }
  }

  void markMissing(int index) {
    if (index >= 0 && index < totalChunks) {
      _bits[index] = false;
    }
  }

  int get completedChunksCount => _bits.where((b) => b).length;

  bool get isComplete => completedChunksCount == totalChunks;

  double get progressFraction => totalChunks > 0 ? completedChunksCount / totalChunks : 1.0;

  List<int> get missingChunkIndexes {
    final missing = <int>[];
    for (int i = 0; i < totalChunks; i++) {
      if (!_bits[i]) missing.add(i);
    }
    return missing;
  }

  String serialize() {
    return _bits.map((b) => b ? '1' : '0').join();
  }

  static ChunkBitset deserialize(String serialized) {
    final bits = serialized.split('').map((char) => char == '1').toList();
    return ChunkBitset._fromList(bits.length, bits);
  }
}

/// Authoritative Merkle-Tree chunking and verification engine for resilient, resumable transfers.
class MerkleChunkService {
  static const MerkleChunkService _instance = MerkleChunkService._internal();
  static MerkleChunkService get instance => _instance;

  const MerkleChunkService._internal();

  /// Default 1MB chunk size
  static const int defaultChunkSize = 1024 * 1024;

  /// Builds a complete MerkleManifest from in-memory or streamed bytes.
  MerkleManifest buildManifest(
    String fileId,
    String fileName,
    List<int> fileBytes, {
    int chunkSize = defaultChunkSize,
  }) {
    final totalBytes = fileBytes.length;
    if (totalBytes == 0) {
      final emptyHash = sha256.convert([]).toString();
      return MerkleManifest(
        fileId: fileId,
        fileName: fileName,
        totalBytes: 0,
        chunkSize: chunkSize,
        totalChunks: 0,
        rootHash: emptyHash,
        chunkHashes: [],
      );
    }

    final totalChunks = (totalBytes + chunkSize - 1) ~/ chunkSize;
    final chunkHashes = <String>[];

    for (int i = 0; i < totalChunks; i++) {
      final offset = i * chunkSize;
      final length = min(chunkSize, totalBytes - offset);
      final chunkSlice = fileBytes.sublist(offset, offset + length);
      final chunkDigest = sha256.convert(chunkSlice).toString();
      chunkHashes.add(chunkDigest);
    }

    final rootHash = computeMerkleRoot(chunkHashes);

    return MerkleManifest(
      fileId: fileId,
      fileName: fileName,
      totalBytes: totalBytes,
      chunkSize: chunkSize,
      totalChunks: totalChunks,
      rootHash: rootHash,
      chunkHashes: chunkHashes,
    );
  }

  /// Verifies an isolated incoming chunk against the manifest leaf hash.
  bool verifyChunk(MerkleManifest manifest, int chunkIndex, List<int> chunkBytes) {
    if (chunkIndex < 0 || chunkIndex >= manifest.chunkHashes.length) return false;
    final expected = manifest.chunkHashes[chunkIndex];
    final actual = sha256.convert(chunkBytes).toString();
    return expected == actual;
  }

  /// Computes the hierarchical Merkle Root hash from an array of leaf chunk digests.
  String computeMerkleRoot(List<String> leafHashes) {
    if (leafHashes.isEmpty) return sha256.convert([]).toString();
    if (leafHashes.length == 1) return leafHashes.first;

    List<String> currentLevel = List<String>.from(leafHashes);

    while (currentLevel.length > 1) {
      final nextLevel = <String>[];
      for (int i = 0; i < currentLevel.length; i += 2) {
        if (i + 1 < currentLevel.length) {
          final combined = utf8.encode(currentLevel[i] + currentLevel[i + 1]);
          nextLevel.add(sha256.convert(combined).toString());
        } else {
          // Odd leaf carries over to next level
          nextLevel.add(currentLevel[i]);
        }
      }
      currentLevel = nextLevel;
    }

    return currentLevel.first;
  }

  ChunkBitset createEmptyBitset(int totalChunks) => ChunkBitset(totalChunks);
}
