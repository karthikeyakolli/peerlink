# Feature 1: FastCDC Content-Defined Chunking & Sub-File Delta Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement FastCDC (Fast Content-Defined Chunking) and sub-file delta synchronization in `peerlink-core` to enable bandwidth-efficient transfers of modified files, ensuring unchanged byte blocks are deduplicated and reused locally.

**Architecture:** A high-performance FastCDC chunking engine using a rolling Gear hash with normalized masks (Min 16 KB, Target 64 KB, Max 128 KB). Files are indexed into deterministic content-defined chunk sequences with SHA-256 digests. During sync/transfer, missing chunk bitmaps are computed so only modified chunks travel over the network, and the receiver reconstructs the target file safely in quarantine before atomic promotion.

**Tech Stack:** Java 17, `peerlink-core`, JUnit 5, SHA-256 MessageDigest.

**Spec:** [`docs/transfer/ARCHITECTURE.md`](file:///docs/transfer/ARCHITECTURE.md) and [`docs/transfer/recovery/FAULT-TOLERANCE.md`](file:///docs/transfer/recovery/FAULT-TOLERANCE.md)

## Global Constraints
- Pure local-first computation: no remote/Supabase dependency for chunking or storage.
- Cryptographic integrity: all reconstructed files must match their expected whole-file SHA-256 hash.
- Zero-allocation inner loop for the rolling Gear hash to maintain >500 MB/s scanning throughput.
- All staging occurs in `StagingDirectoryManager` before promotion to user destination.

## Review Focus
1. Insertion shift resistance: inserting bytes at index 0 must leave subsequent chunk hashes identical.
2. Boundary adherence: no chunk may be smaller than `minChunkSize` (unless at EOF) or larger than `maxChunkSize`.
3. Degenerate patterns: repeating byte patterns (e.g., all zeros or all 0xFF) must not cause infinite loops or under/oversized chunks.
4. Concurrency safety: chunker instances must be re-usable or thread-safe.
5. In-place reconstruction: rebuilding a file from local base + delta chunks must produce the exact byte sequence.

---

### Task 1: FastCDC Chunker Core Algorithm

**Files:**
- Create: `core/src/main/java/org/peerlink/core/transfer/cdc/ContentDefinedChunk.java`
- Create: `core/src/main/java/org/peerlink/core/transfer/cdc/FastCdcChunker.java`
- Test: `core/src/test/java/org/peerlink/core/transfer/cdc/FastCdcChunkerTest.java`

**Interfaces:**
- Produces: `List<ContentDefinedChunk> FastCdcChunker.chunk(Path path)`
- Produces: `List<ContentDefinedChunk> FastCdcChunker.chunk(byte[] data)`
- ContentDefinedChunk: `(int chunkIndex, long offsetBytes, int lengthBytes, String sha256Hex)`

- [ ] **Step 1: Write failing unit test for FastCdcChunker**
- [ ] **Step 2: Run test and verify failure**
- [ ] **Step 3: Implement ContentDefinedChunk and FastCdcChunker**
- [ ] **Step 4: Run test and verify it passes**
- [ ] **Step 5: Verify insertion shift resistance (delta efficiency)**

---

### Task 2: Sub-File Delta Manifest & Reconstruction Engine

**Files:**
- Create: `core/src/main/java/org/peerlink/core/transfer/cdc/DeltaSyncManifest.java`
- Create: `core/src/main/java/org/peerlink/core/transfer/cdc/DeltaReconstructor.java`
- Test: `core/src/test/java/org/peerlink/core/transfer/cdc/DeltaSyncReconstructionTest.java`

**Interfaces:**
- Consumes: `FastCdcChunker`, `ContentDefinedChunk`
- Produces: `DeltaSyncManifest.diff(DeltaSyncManifest baseManifest)`
- Produces: `void DeltaReconstructor.reconstruct(Path basePath, Map<String, byte[]> newChunks, Path destinationPath, String expectedSha256)`

- [ ] **Step 1: Write failing test for delta computation and reconstruction**
- [ ] **Step 2: Run test and verify failure**
- [ ] **Step 3: Implement DeltaSyncManifest and DeltaReconstructor**
- [ ] **Step 4: Run test and verify full roundtrip reconstruction**
- [ ] **Step 5: Verify failure path when chunk hash is corrupted**

---

### Task 3: Core Suite Regression Verification & Commit

- [ ] **Step 1: Run Maven test suite for core module**
- [ ] **Step 2: Run test-all.ps1 -SkipGradle verification**
- [ ] **Step 3: Commit Feature 1 to Git**
