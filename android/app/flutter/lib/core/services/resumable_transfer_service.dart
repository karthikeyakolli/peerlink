/// Session ledger tracking chunk bitmasks for interrupted or ongoing transfers.
class ResumableTransferSession {
  final String transferId;
  final String fileName;
  final int totalBytes;
  final int chunkSize; // default 1 MB (1048576 bytes)
  final int totalChunks;
  final Set<int> receivedChunks;
  bool isPaused;

  ResumableTransferSession({
    required this.transferId,
    required this.fileName,
    required this.totalBytes,
    this.chunkSize = 1048576,
    Set<int>? receivedChunks,
    this.isPaused = false,
  })  : totalChunks = (totalBytes / chunkSize).ceil().clamp(1, 1000000),
        receivedChunks = receivedChunks ?? <int>{};

  double get progressRatio => totalChunks > 0 ? (receivedChunks.length / totalChunks).clamp(0.0, 1.0) : 0.0;
  int get receivedBytes => (receivedChunks.length * chunkSize).clamp(0, totalBytes);
  bool get isComplete => receivedChunks.length >= totalChunks;

  List<int> get missingChunks {
    final List<int> missing = [];
    for (int i = 0; i < totalChunks; i++) {
      if (!receivedChunks.contains(i)) {
        missing.add(i);
      }
    }
    return missing;
  }

  void markChunkReceived(int chunkIndex) {
    if (chunkIndex >= 0 && chunkIndex < totalChunks) {
      receivedChunks.add(chunkIndex);
    }
  }
}

/// Resumable Chunk Bitmask Engine ensuring transfers survive Wi-Fi drops without restarting.
class ResumableTransferService {
  ResumableTransferService._();
  static final ResumableTransferService instance = ResumableTransferService._();

  final Map<String, ResumableTransferSession> _sessions = {};

  ResumableTransferSession getOrCreateSession({
    required String transferId,
    required String fileName,
    required int totalBytes,
    int chunkSize = 1048576,
  }) {
    return _sessions.putIfAbsent(
      transferId,
      () => ResumableTransferSession(
        transferId: transferId,
        fileName: fileName,
        totalBytes: totalBytes,
        chunkSize: chunkSize,
      ),
    );
  }

  ResumableTransferSession? getSession(String transferId) => _sessions[transferId];

  List<ResumableTransferSession> get activeSessions => _sessions.values.toList();

  void recordChunk(String transferId, int chunkIndex) {
    _sessions[transferId]?.markChunkReceived(chunkIndex);
  }

  void pauseTransfer(String transferId) {
    final s = _sessions[transferId];
    if (s != null) s.isPaused = true;
  }

  void resumeTransfer(String transferId) {
    final s = _sessions[transferId];
    if (s != null) s.isPaused = false;
  }
}
