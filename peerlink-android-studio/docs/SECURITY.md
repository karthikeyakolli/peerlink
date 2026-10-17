# PeerLink Android Studio Edition — Security & Trust Architecture

**Document Version:** 1.1.0 (Phase 24 Verified Baseline)  
**Target:** `peerlink-android-studio`

---

## 1. Core Mandatory Security Rules

PeerLink operates under zero-trust assumptions across all network boundaries and platforms:
1. **Never treat discovery as trust (Rule 6):** Device discovery via mDNS / NSD / Wi-Fi Direct indicates reachability, NOT authenticity. Untrusted discovered peers are rejected during the 3-way handshake.
2. **Never treat timestamps as sync truth (Rule 7):** Causal ordering is determined using cryptographic version vectors (vector clocks), not wall clocks.
3. **Never treat watcher events as filesystem truth (Rule 8):** Watcher events are hints; manifests must be reconciled against actual filesystem state.
4. **Never blindly replay destructive operations after uncertain outcomes (Rule 9):** Interrupted operations transition to `OUTCOME_UNKNOWN` with diagnostic notes; automatic replay is prohibited.
5. **Never auto-execute received files (Rule 10):** Inbound content is quarantined in `.part` staging files, cryptographic SHA-256 integrity is validated, and executable bits are stripped (`setExecutable(false)`).
6. **Never give AI authority over security (Rule 11):** AI proposals are strictly non-authoritative recommendations and cannot modify identity, trust, or data.
7. **Never trust localhost merely because it is localhost (Rule 12):** All loopback/local connections require mutual cryptographic authentication.

---

## 2. Identity, Key Types & Truthful Hardware Security

### 2.1 Cryptographic Key Specifications & Pairing Safety
- **Established Standard:** `KeyType.KEY_TYPE_ED25519`.
- **Derivation Rule:** `DERIVATION_RULE_V1 = "v1:ed25519:sha256_16"` (`peer_<16-hex>`).
- **Short Fingerprint:** SHA-256 formatted as `SHA256:<16-hex>` for brief notification banners and list items.
- **Full Fingerprint:** Full SHA-256 formatted as `SHA256:<64-hex>` (`PeerCryptoSigner.computeFullFingerprint`) for unambiguous cryptographic audit and collision protection.
- **Out-of-Band Safety Number:** 30 numeric digits formatted into 6 blocks of 5 digits (`PeerCryptoSigner.computeSafetyNumber`) derived from SHA-512 over sorted public keys with explicit domain separation (`PeerLink:PairwiseSafetyNumber:v1:Ed25519:`), providing symmetrical verbal/visual pairing verification.
- **Session Authentication Code:** 6-digit numeric PIN (`PeerCryptoSigner.computeSessionAuthCode`) derived from SHA-256 binding `PeerLink:SessionAuthCode:v1:Ed25519:`, session ID, sorted peer keys, random nonces, and timestamp for ephemeral challenge authentication.
- **Three-Way Verification Demarcation:**
  1. *Full Fingerprint:* Static 64-character hex (`SHA256:<64-hex>`) for device identity validation and registry lookup.
  2. *Safety Number:* Pairwise, bilateral 30-digit numeric code binding two identities across sessions.
  3. *Session Auth Code:* Ephemeral, 6-digit PIN binding single connection session parameters.
- **Cloned Identity Protection:** `InMemoryTrustStore` strictly detects conflicting public keys mapped to the same Peer ID and rejects them with `SecurityException("Cloned identity detected!")`.
- **Public Key Wire Encoding:** Raw 32-byte Ed25519 public key.

### 2.2 Keystore Protection & Security Level Truthfulness
- **The Reality of AndroidKeyStore:** Android Keystore does not provide native Ed25519 keypair generation or signing.
- **Implementation Strategy:**
  - The Ed25519 device private key is held in memory by `PeerCryptoSigner` (Bouncy Castle vetted implementation).
  - At rest, the private key is encrypted using AES-256-GCM (`AndroidKeyStoreSecureKeyStore`).
  - **Nonce Uniqueness:** Each encryption generates a fresh, cryptographically secure 96-bit random IV (`cipher.getIV()`). Nonce reuse is strictly prohibited and verified across 1,000 iterations.
  - The AES-256 master key is generated and stored in `AndroidKeyStore` (`AndroidKeyStoreProvider`), targeting StrongBox/TEE hardware backing.
- **minSdk 26 Fallback & Truthful Status Reporting:**
  - `isDirectHardwareSigning()` returns `false` (never falsely claimed as hardware Ed25519 signing).
  - `isHardwareProtectedAtRest()` accurately reports hardware backing.
  - On Android 12+ (API 31+), `KeyInfo.getSecurityLevel()` is inspected (`HARDWARE_STRONGBOX`, `HARDWARE_TEE`, `SOFTWARE`).
  - On Android 8.0-11 (API 26-30), `KeyInfo.isInsideSecureHardware()` is used for backward-compatible hardware inspection without crashing.
  - Unit test and emulator environments truthfully report `SecurityLevel.SOFTWARE` or `SOFTWARE_TEST_HARNESS`.

### 2.3 Identity Corruption Invariant
- If identity metadata or private key ciphertext is corrupted, `AndroidKeystoreManager` strictly refuses silent regeneration.
- It throws an explicit `KeyStorageException` or `IdentityCorruptionException` requiring user diagnostic intervention, preventing device identity forks or unauthorized key substitution.

---

## 3. Mutual Authentication & Protocol Contracts

- **3-Way Handshake:** Every peer connection executes mutual authentication (`HandshakeRequest`, `HandshakeResponse`, `HandshakeAck`).
- **Cryptographic Challenge:** Ephemeral random nonces are signed using the Ed25519 private key and verified against the peer's public key.
- **TrustStore Enforcement:** Only peers explicitly paired and registered in `TrustStore` are permitted to establish authenticated sessions. Untrusted peers are immediately disconnected with `ERROR_CODE_UNAUTHENTICATED`.

---

## 4. Scoped Storage & Sandbox Isolation

- **Scoped Storage:** Content access uses Android Storage Access Framework (`content://` URIs) via `SafStorageProvider`, eliminating broad storage permission requirements on modern Android.
- **Path Traversal Sandboxing:** All requested relative paths are validated by `PathSandboxValidator`. Any sequences containing `../`, null bytes, or absolute drive letters are rejected before any filesystem interaction.
- **Safe Destination Staging:** Inbound files are received into temporary staging files (`.part.<uuid>`), verified against their expected SHA-256 checksums, and atomically committed to their final destination.
- **Statvfs vs FileStore:** Usable disk space preflight queries use `File.getUsableSpace()` statvfs fallbacks to safely operate within Android unprivileged app sandboxes without triggering SELinux `SecurityException`.

---

## 5. Durable Recovery & Journaling (Phase 26 Qualification)

- **Authoritative SQLite Journal:** `AndroidSqliteOperationJournal` operates under SQLite WAL mode with foreign keys and strict terminal state guards (`OperationState.isTerminalState()`).
- **Idempotency Guarantee:** Unique index on `idempotency_key` guarantees that repeated operations are detected and deduplicated without side effects.
- **Five-State Discrimination (`AndroidStartupRecoveryManager`):**
  1. *Valid Incomplete Transfers:* Retains verified `.part` staging chunks without deletion; transitions operation to non-terminal `WAITING` state with `VALID_INCOMPLETE_RESUMABLE` flag.
  2. *Corrupted Staging Content:* Renames corrupted chunk/staging files to `.corrupt.<timestamp>` to preserve forensic evidence while preventing unsafe use.
  3. *Successfully Committed Destinations:* Confirmed bit-perfect destination files transition to `COMMITTED` without redundant re-transfer.
  4. *Uncertain Finalization:* Partial destination writes are quarantined to `.partial_uncertain.<timestamp>` with operation set to `OUTCOME_UNKNOWN` (Rule 9).
  5. *Storage / Database Unavailable:* Handles `SQLiteException` and filesystem `IOException` gracefully with explicit error logs.

---

## 6. Dependency Security Audit: Bouncy Castle 1.86

- **Artifact:** `org.bouncycastle:bcprov-jdk18on:1.86` (Upgraded in Phase 26 from 1.78.1)
- **Advisory Review:**
  - Upgraded to latest supported Bouncy Castle release 1.86.
  - Addressed historical CVEs in legacy algorithms (FrodoKEM CVE-2026-5598, GOST CTR CVE-2025-14813, PKIX CVE-2026-5588).
- **Toolchain & Runtime Compatibility:**
  - Fully compatible with Android API 26+ (`minSdk = 26`), AGP 9.1.0, and JDK 17 / JDK 25 toolchains.
  - Zero duplicate cryptographic providers packaged in release APK.
- **PeerLink Usage:** PeerLink uses only RFC 8032 standard Ed25519 signature algorithm (`KeyPairGenerator.getInstance("Ed25519")`, `Signature.getInstance("Ed25519")`).
- **Cryptographic KAT Verification:** Passed 100% of Ed25519 known-answer tests, cross-platform signature verification tests, and corrupt challenge rejection tests.
