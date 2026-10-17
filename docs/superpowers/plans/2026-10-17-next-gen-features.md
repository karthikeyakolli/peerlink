# Next-Generation P2P Capabilities Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement next-generation P2P capabilities that existing file-sharing apps lack, starting with Ephemeral "Burn-After-Read" Crypto-Shredding, Cryptographic Proof-of-Receipt, Acoustic Sonic Handshake, Multi-Peer Swarm Beam, and On-Demand Virtual Streaming.

**Architecture:** A layered approach extending PeerLink's portable Java Core reactor (off-heap memory, cryptographic signing, secure wiping) and presenting interactive Glassmorphic UI/UX across all Flutter platform editions (Android, Windows, macOS, Linux).

**Tech Stack:** Java 17, JUnit 5, Dart / Flutter (Glassmorphism, animations, custom shaders), Protobuf, Ed25519 / SHA-256 cryptography.

**Spec:** `AGENTS.md` and `docs/superpowers/plans/2026-10-17-next-gen-features.md`

## Global Constraints

- Never place normal user file content in Supabase.
- Never treat discovery as trust.
- Never treat timestamps as sync truth.
- Never treat watcher events as filesystem truth.
- Never blindly replay destructive operations after uncertain outcomes.
- Never auto-execute received files.
- Never give AI authority over identity, encryption, trust, authorization, integrity, sync truth, deletion or execution.
- Never trust localhost merely because it is localhost.
- Maintain 100% green status on all existing 279 JVM reactor tests and Flutter tests.

## Review Focus

1. **Crypto-Shredding Incomplete Wipe:** Ensure files are completely overwritten with random bytes before unlinking, preventing physical disk recovery.
2. **Race Condition in Ephemeral View Count:** Ensure multi-threaded view events cannot bypass the single-view limit.
3. **Proof-of-Receipt Signature Mismatch:** Ensure receipt serialization is deterministic and strictly canonical across Java and Dart.
4. **Memory Residuals:** Ensure private keys and sensitive file buffers in RAM are zeroized upon session termination.
5. **Platform Cross-Compatibility:** Ensure all UI widgets work identically across Windows, Android, macOS, and Linux without native binary crashes.

---

### Task 1: Ephemeral "Burn-After-Read" & Crypto-Shredding (Core Engine)

**Files:**
- Create: `core/src/main/java/org/peerlink/core/transfer/ephemeral/EphemeralTransferPolicy.java`
- Create: `core/src/main/java/org/peerlink/core/transfer/ephemeral/CryptoShredder.java`
- Create: `core/src/main/java/org/peerlink/core/transfer/ephemeral/EphemeralSessionRegistry.java`
- Test: `core/src/test/java/org/peerlink/core/transfer/ephemeral/CryptoShredderTest.java`
- Test: `core/src/test/java/org/peerlink/core/transfer/ephemeral/EphemeralSessionRegistryTest.java`

**Interfaces:**
- Consumes: `java.nio.file.Path`, `java.security.SecureRandom`
- Produces: `EphemeralTransferPolicy`, `CryptoShredder.shred(Path path)`, `EphemeralSessionRegistry`

- [ ] **Step 1: Write failing unit test for `CryptoShredderTest`**
  - Verify file content is overwritten with random bytes.
  - Verify file size is zeroed and file deleted from filesystem.
  - Verify secure key buffer wipe.

- [ ] **Step 2: Run test to verify it fails**
  - Run: `.\mvnw.cmd test -pl core "-Dtest=CryptoShredderTest" -B`
  - Expected: Compilation failure / ClassNotFoundException.

- [ ] **Step 3: Implement `CryptoShredder` and `EphemeralTransferPolicy`**
  - Multi-pass overwrite (Random -> Inverted -> Zero) using `FileChannel.write()`.
  - Force disk sync (`channel.force(true)`).
  - Truncate to 0 and unlink (`Files.deleteIfExists(path)`).

- [ ] **Step 4: Implement `EphemeralSessionRegistry` with TTL and view counters**
  - ConcurrentHashMap registry for active sessions.
  - Scheduled background scanner for expired TTLs.
  - Thread-safe `recordViewAccess(String transferId)` triggering shred when threshold met.

- [ ] **Step 5: Run tests to verify they pass**
  - Run: `.\mvnw.cmd test -pl core "-Dtest=CryptoShredderTest,EphemeralSessionRegistryTest" -B`
  - Expected: PASS.

- [ ] **Step 6: Commit**
  - `git commit -m "feat(ephemeral): implement CryptoShredder and EphemeralSessionRegistry"`

---

### Task 2: Ephemeral "Burn-After-Read" UI & Sandboxed Glass Viewer (Flutter)

**Files:**
- Create: `peerlink-android-studio/lib/features/files/components/ephemeral_policy_modal.dart`
- Create: `peerlink-android-studio/lib/features/files/components/burn_viewer_modal.dart`
- Modify: `peerlink-android-studio/lib/features/files/files_screen.dart`
- Modify: `peerlink-android-studio/lib/features/home/components/instant_beam_deck.dart`
- Sync to: `windows/app/flutter/`, `linux/app/flutter/`, `macos/app/flutter/`, `android/app/flutter/`, `shared-source/canonical/flutter/`
- Test: `peerlink-android-studio/test/widget/ephemeral_sharing_test.dart`

**Interfaces:**
- Consumes: `InteractiveGlassCard`, `GlassContainer`
- Produces: `EphemeralPolicyModal`, `BurnViewerModal`

- [ ] **Step 1: Write failing widget test for Ephemeral sharing UI**
  - Verify Ephemeral toggle button renders with flame icon.
  - Verify BurnViewerModal shows live countdown timer and watermarked background.
  - Verify dismissal fires shredding callback.

- [ ] **Step 2: Run test to verify failure**
  - Run: `flutter test test/widget/ephemeral_sharing_test.dart`
  - Expected: Compilation failure.

- [ ] **Step 3: Implement `EphemeralPolicyModal` & `BurnViewerModal`**
  - Frosted glass design in Crimson & Amber palette.
  - Particle dissipation animation on burn event.
  - Watermarked secure view surface.

- [ ] **Step 4: Integrate into `FilesScreen` & `InstantBeamDeck`**
  - Add "🔥 Burn Mode" toggle to instant beam deck.
  - Display burn status chip on ephemeral transfers in transfer history.

- [ ] **Step 5: Run tests and verify 100% green**
  - Run: `flutter test` in `peerlink-android-studio`
  - Expected: PASS.

- [ ] **Step 6: Sync to all platform editions**
  - Run sync script across Windows, Linux, macOS, Android.

---

### Task 3: Cryptographic Proof-of-Receipt & Non-Repudiation Watermark

**Files:**
- Create: `core/src/main/java/org/peerlink/core/transfer/receipt/TransferReceipt.java`
- Create: `core/src/main/java/org/peerlink/core/transfer/receipt/ReceiptSigner.java`
- Create: `core/src/main/java/org/peerlink/core/transfer/receipt/ReceiptStore.java`
- Test: `core/src/test/java/org/peerlink/core/transfer/receipt/ReceiptSignerTest.java`
- Create UI: `peerlink-android-studio/lib/features/activity/components/proof_of_receipt_modal.dart`
- Test UI: `peerlink-android-studio/test/widget/proof_of_receipt_test.dart`

**Interfaces:**
- Consumes: Ed25519 keys, SHA-256 hashes
- Produces: Tamper-proof signed mutual receipts with exportable JSON/PDF format.

- [ ] **Step 1: Write failing JVM unit test for receipt signing and validation**
- [ ] **Step 2: Implement `TransferReceipt`, `ReceiptSigner`, and `ReceiptStore`**
- [ ] **Step 3: Write and verify Flutter widget test for `ProofOfReceiptModal`**
- [ ] **Step 4: Integrate receipt badge into `ActivityScreen` & `FilesScreen`**
- [ ] **Step 5: Run all verification tests and sync to all platforms**

---

### Task 4: Acoustic / Ultrasonic "Air-Gap Sonic Handshake"

**Files:**
- Create: `core/src/main/java/org/peerlink/core/discovery/acoustic/AcousticPayloadCodec.java`
- Test: `core/src/test/java/org/peerlink/core/discovery/acoustic/AcousticPayloadCodecTest.java`
- Create UI: `peerlink-android-studio/lib/features/devices/components/sonic_pair_modal.dart`
- Test UI: `peerlink-android-studio/test/widget/sonic_pair_test.dart`

- [ ] **Step 1: Write failing test for FSK audio payload encoding/decoding**
- [ ] **Step 2: Implement audio frequency modulator/demodulator**
- [ ] **Step 3: Implement Sonic Pair modal with animated audio spectrum radar**
- [ ] **Step 4: Verify tests and sync across platforms**

---

### Task 5: Simultaneous Multi-Peer "Swarm Beam" (P2P Mesh Broadcast)

**Files:**
- Create: `core/src/main/java/org/peerlink/core/transfer/swarm/SwarmTransferCoordinator.java`
- Test: `core/src/test/java/org/peerlink/core/transfer/swarm/SwarmTransferCoordinatorTest.java`
- Create UI: `peerlink-android-studio/lib/features/home/components/swarm_mesh_hud.dart`

- [ ] **Step 1: Write failing test for chunk bitmap distribution among 3+ peers**
- [ ] **Step 2: Implement swarm chunk coordinator**
- [ ] **Step 3: Implement Swarm HUD in home screen**
- [ ] **Step 4: Run verification tests**

---

### Task 6: On-Demand Remote Virtual Drive & Instant Streaming

**Files:**
- Create: `core/src/main/java/org/peerlink/core/transfer/stream/VirtualStreamServer.java`
- Test: `core/src/test/java/org/peerlink/core/transfer/stream/VirtualStreamServerTest.java`
- Create UI: `peerlink-android-studio/lib/features/files/components/remote_stream_player_modal.dart`

- [ ] **Step 1: Write failing test for HTTP range-request chunk streaming**
- [ ] **Step 2: Implement VirtualStreamServer with ZeroCopyBufferPool integration**
- [ ] **Step 3: Implement glassmorphic streaming media player modal**
- [ ] **Step 4: Verify tests and sync across platforms**
