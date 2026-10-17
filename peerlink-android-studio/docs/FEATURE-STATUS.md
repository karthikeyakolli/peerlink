# PeerLink Android Studio Edition — Feature Status Inventory & Phase 26 Audit

**Document Version:** 1.3.0 (Phase 26 Final Release Qualification Baseline)  
**Project:** `peerlink-android-studio`  
**Classification Baseline:** Verified against real Android OS runtime (`Medium_Phone_API_37.0` emulator, Android 17 / API 37), native JUnit unit tests, instrumented Android tests (20/20 passed), Flutter contract tests (12/12 passed), Bouncy Castle 1.86 dependency upgrade, and release APK assemblies.

---

## 1. Feature Classification Framework

Every major feature across the PeerLink architecture is audited and assigned one of the following statuses:
1. **Implemented and verified:** Code exists, builds, and is covered by passing unit/integration tests on Android/JVM.
2. **Implemented but not verified:** Code exists in source sets, but has not yet been subjected to independent verification on this Android target.
3. **Partially implemented:** Substantial contracts and partial logic exist, but bridge adapters or full workflow loops require completion.
4. **Prototype or mock:** UI or backend exists as a demo stub or hardcoded mock; must be connected to genuine runtime logic or replaced with honest states.
5. **Missing:** No functional code present in repository.
6. **Blocked:** Unavailable hardware, operating system privilege, or missing physical peer.

---

## 2. Feature Matrix & Source Inventory

| Category | Component / Capability | Status | Source Location (Inspected) | Phase 26 Audit Findings & Verification |
| :--- | :--- | :--- | :--- | :--- |
| **Identity & Trust** | Cryptographic Device Identity & Safety Numbers | **Implemented and verified** | `AndroidKeystoreManager.java`, `AndroidKeyStoreProvider.kt`, `PeerCryptoSigner.java` | Standard Ed25519 identity conforming to `KeyType.KEY_TYPE_ED25519` and `DERIVATION_RULE_V1 = "v1:ed25519:sha256_16"`. Private key protected at rest via AndroidKeyStore AES-256-GCM. Domain-separated 30-digit Safety Number (`SAFETY_NUMBER_DOMAIN_V1`), 6-digit Session Auth Code (`SESSION_AUTH_DOMAIN_V1`), and 64-hex SHA-256 fingerprint verified. Substituted keys and tampered challenges strictly rejected. Verified in `AndroidIdentityCompatibilityTest`. |
| **Identity & Trust** | Hardware Security Level Reporting | **Implemented and verified** | `AndroidKeystoreManager.java`, `AndroidKeyStoreProvider.kt` | Truthfully reports `isDirectHardwareSigning() == false` (AndroidKeyStore lacks native Ed25519 support). Accurately reports whether AES master key is in StrongBox/TEE or Software, with minSdk 26 fallback for `KeyInfo.isInsideSecureHardware()`. Verified in `testTruthfulSecurityLevelHardwareInspection`. |
| **Identity & Trust** | Identity Corruption Invariant | **Implemented and verified** | `AndroidKeystoreManager.java` | Refuses silent regeneration on corrupted metadata or invalid ciphertext. Fails safely to prevent accidental identity fork or device spoofing. |
| **Identity & Trust** | Zero-Trust Enforcement | **Implemented and verified** | `AndroidRealPeerConnectivityTest.kt`, `AndroidDeviceToPeerInteroperabilityInstrumentedTest.kt` | Local discovery does NOT imply trust. Untrusted peers are rejected during the 3-way Ed25519 cryptographic handshake with `ERROR_CODE_UNAUTHENTICATED`. |
| **Transport** | Real P2P Socket Duplex Transport | **Implemented and verified** | `StandardTcpTransportProvider.java`, `AndroidDeviceToPeerInteroperabilityInstrumentedTest.kt` | Proved real duplex streaming over OS TCP sockets on real Android OS emulator (`Medium_Phone_API_37.0`). Length-prefixed protobuf framing, 3-way Ed25519 handshake authentication, SHA-256 chunk transfer, and atomic commit verified. |
| **SEND Mode** | SAF Content Transmission & Verification | **Implemented and verified** | `SafStorageProvider.kt`, `PeerTransferEngine.java`, `AndroidFourOperationModesTest.kt`, `AndroidFrameworkServicesInstrumentedTest.kt` | SAF content streaming, chunked transmission, receiver-side SHA-256 chunk validation, and atomic commit verified across independent node instances. Never auto-executes received files. |
| **ACCESS Mode** | Authoritative Scoping & Sandbox | **Implemented and verified** | `RemoteAccessCoordinator.java`, `ShareManager.java`, `AndroidFourOperationModesTest.kt` | Explicit capability tokens, HMAC signature verification, scope enforcement (`BROWSE` vs `DOWNLOAD`), instant share revocation, and path traversal sandbox protection (`../../../../windows/system32` rejected). |
| **SYNC Mode** | Causal Vectors & Conflict Detection | **Implemented and verified** | `SyncManifest.java`, `ConflictDetector.java`, `CausalVersion.java`, `AndroidFourOperationModesTest.kt` | Vector clock causality tracking. Rule 7 compliance: timestamps are never used as conflict authority. Detected concurrent `DELETE_VS_MODIFY` conflict. Tombstones retained across offline reconciliation. |
| **BACKUP Mode** | Snapshot Retention & Safe Restore | **Implemented and verified** | `BackupEngine.java`, `FileBasedBackupTarget.java`, `AndroidFourOperationModesTest.kt` | Full snapshot creation, SHA-256 integrity verification, retention policy pruning, and safe restore under `FAIL_ON_CONFLICT` refusing silent overwrite of existing user files. |
| **Lifecycle & Resilience**| Persistent SQLite Journal & 5-State Recovery | **Implemented and verified** | `AndroidSqliteOperationJournal.java`, `AndroidStartupRecoveryManager.java`, `AndroidSqliteJournalInstrumentedTest.kt` | Authoritative SQLite journal in WAL mode with foreign keys, unique idempotency constraints, and terminal state guards. 5-state recovery implemented: valid incomplete transfers preserved in WAITING state without deleting valid chunks; corrupted staging quarantined to `.corrupt`; confirmed destinations committed; uncertain finalizations quarantined to `.partial_uncertain` under `OUTCOME_UNKNOWN` (Rule 9); storage unavailability handled without crashes. Verified across process recreation. |
| **Lifecycle & Resilience**| Safe Destination Quarantine | **Implemented and verified** | `SafeDestinationHandler.java`, `AndroidLifecycleAndPersistenceTest.kt` | Staging in `.part` files, strict SHA-256 checksum verification before commit, destination sandbox boundary enforcement, explicit removal of executable permissions. |
| **Services** | Foreground Execution & Timeout Handling | **Implemented and verified** | `PeerLinkForegroundService.kt`, `AndroidFrameworkServicesInstrumentedTest.kt` | Android 14+/15+ compliant `FOREGROUND_SERVICE_DATA_SYNC` with `onTimeout(startId, fgsType)` callback, deterministic operation pausing via `nodeFacade.pauseAllActiveTransfers()`, and persistent warning notification. |
| **Services** | Background Schedulable Sync | **Implemented and verified** | `PeerLinkSyncWorker.kt`, `AndroidFrameworkServicesInstrumentedTest.kt` | WorkManager periodic worker with battery and unmetered network constraints. |
| **Networking & Permissions** | Android 17 Local Networking | **Implemented and verified** | `AndroidNsdAdapter.kt`, `AndroidManifest.xml`, `AndroidFrameworkServicesInstrumentedTest.kt` | Declared `android.permission.ACCESS_LOCAL_NETWORK` (API 37+). Runtime permission check evaluates targetSdk >= 37 while maintaining backward compatibility for targetSdk < 37 under INTERNET. First launch, permission denial, permission grant, permission revocation, and discovery restart verified. |
| **Communication** | Native Bridge | **Implemented and verified** | `AndroidPigeonBridge.kt`, `android_node_bridge.dart` | MethodChannel and EventChannel for peer info, fingerprint, security level, discovery, and transfers. |
| **Shell & UI** | Material 3 Mobile Navigation | **Implemented and verified** | `lib/main.dart`, `devices_screen.dart`, `widget_test.dart` | 7 primary navigation destinations. Truthful identity details (Ed25519 peer ID, SHA-256 fingerprint, Keystore security level) displayed. |

---

## 3. Physical Source Isolation Audit

- **Zero Escaping Imports:** Verified across all 74 Dart files and all native Java/Kotlin files.
- **Zero Symlinks:** 100% physically contained inside `peerlink-android-studio/`.
- **Prohibited APIs Excluded:** Zero references to desktop `java.net.http.*`, `java.lang.management.*`, or `DesktopLocalNodeServiceGrpc`.
- **Isolation Status:** `100% SELF-CONTAINED (PASS)`.

---

## 4. Release Build & Size Analysis

- **Universal Debug APK:** 146.65 MB (bundles unstripped JIT debug binaries and symbols for all 4 ABIs: `armeabi-v7a`, `arm64-v8a`, `x86`, `x86_64`).
- **Release Compilation (`--split-per-abi`):**
  - `app-armeabi-v7a-release.apk`: **16.66 MB** (17,472,989 bytes)
  - `app-arm64-v8a-release.apk`: **19.06 MB** (19,982,353 bytes)
  - `app-x86_64-release.apk`: **20.49 MB** (21,482,515 bytes)
- **Size Driver Breakdown (arm64-v8a):**
  - Flutter compiled engine + Dart AOT machine code (`lib/arm64-v8a`): 17 MB
  - Bouncy Castle crypto library (`org/bouncycastle`): 1 MB
  - Compiled Dalvik bytecode (`classes.dex`): 914 KB
  - Flutter Assets (`assets/`): 117 KB
  - Manifest & Resources (`res/`, `resources.arsc`): 12 KB
- **Tree-Shaking:** Font asset `MaterialIcons-Regular.otf` was tree-shaken from 1.64 MB to 14.76 KB (99.1% reduction).
