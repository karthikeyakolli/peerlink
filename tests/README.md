# PeerLink Test Architecture & Taxonomy

This directory contains test suites structured according to the verification matrix:

- `unit/`: Unit tests for domain logic and core algorithms.
- `integration/`: Multi-component and local daemon tests.
- `network/`: Network fault injection, disconnect/reconnect, QUIC/TCP-TLS matrix.
- `filesystem/`: Filesystem edge cases (Unicode, long paths, permission denial, disk full, atomic commit).
- `security/`: Penetration tests, malformed inputs, unauthorized IPC, path traversal, scanner policies.
- `sync/`: Causal divergence, tombstone handling, conflict resolution, mass deletion protection.
- `transfer/`: Large streaming, chunking, resume, checksum mismatch, pause/cancel.
- `android/`: Android-specific capability tests (SAF, WorkManager, background constraints).
- `cross-platform/`: Interoperability tests between Windows, Linux, macOS, Android.
- `chaos/`: Power-loss, process kill during commit, database lock recovery.
- `e2e/`: End-to-end user intent scenarios (SEND, ACCESS, SYNC, BACKUP).
