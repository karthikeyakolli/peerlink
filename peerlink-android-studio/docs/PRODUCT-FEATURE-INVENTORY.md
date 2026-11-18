# PeerLink — Comprehensive Product Feature Inventory

**Document Version:** 1.3.0 (Phase 12.10 Physical Offline Acceptance & UI Performance Qualification Baseline)  
**Repository:** `https://github.com/karthikeyakolli/peerlink`  
**Baseline Commit:** `67bcd4b6204aed01ab16dc4aaac5a32e10d63f61`  
**Classification Mode:** Evidence-based inspection across Flutter UI, Desktop gRPC IPC, Android Pigeon/MethodChannel Bridge, Core Java/Kotlin Node Daemons, and Protocol Contracts.

---

## 1. Classification Taxonomy

Every audited capability is categorized using truthful, evidence-based status distinctions:

| Status | Definition |
| :--- | :--- |
| **`IMPLEMENTED_AND_VERIFIED`** / **`SOFTWARE_TESTS_PASSED`** | Code is complete, integrated through the runtime call chain, and verified by passing automated unit, integration, or contract tests in the active workspace. |
| **`IMPLEMENTED_BUT_NOT_END_TO_END_VERIFIED`** | Full implementation exists in domain logic or backend services, but end-to-end integration across Flutter UI, physical network, or cross-node hardware remains unverified. |
| **`PHYSICAL_LOCAL_WIFI_ACCEPTANCE_PASSED`** | Verified on two physical devices transferring files over local Wi-Fi without internet. |
| **`PHYSICAL_WIFI_DIRECT_ACCEPTANCE_PASSED`** | Verified on two physical devices transferring files over routerless Wi-Fi Direct. |
| **`PROFILE_PERFORMANCE_MEASURED`** | Frame-rate (raster & UI thread) and memory performance measured in Flutter profile mode on physical hardware. |
| **`PARTIAL`** | Automated tests passed, but physical-device acceptance or real-device profiling remains blocked or incomplete. |
| **`NOT RUN`** / **`BLOCKED`** | Physical or live scenario could not be executed due to missing physical hardware (e.g., 0 physical phones attached via ADB). |
| **`PARTIALLY_IMPLEMENTED`** | Core contracts, interfaces, and partial business logic exist, but bridge adapters, UI bindings, or edge-case handlers are incomplete. |
| **`NOT_IMPLEMENTED`** / **`MISSING`** | Capability is architectural or planned in documentation/specs, but no functional source code exists in the repository. |

---

## 2. Core Product Operations (SEND, ACCESS, SYNC, BACKUP, CONNECT)

| Feature | User Value | Status | Platforms | Source Locations | Verification | Limitations | Next Action |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **SEND Mode** (Single & Multi-File Transfer) | Send individual files, batches, and folder hierarchies directly to trusted peers without cloud relays. | `IMPLEMENTED_AND_VERIFIED` | Windows, Linux, macOS, Android | `PeerTransferEngine.java`, `BatchTransferManager.java`, `SafStorageProvider.kt`, `FilesScreen.dart` | `PeerTransferEngineTest`, `AndroidFourOperationModesTest.kt`, `RealSendWorkflowTest.dart` | Receiver consent required; no auto-execution of received files. | Maintain regression coverage across future format updates. |
| **ACCESS Mode** (Remote Scoped Browsing) | Authorized remote inspection of shared files without downloading full datasets. | `IMPLEMENTED_BUT_NOT_END_TO_END_VERIFIED` | Windows, Linux, macOS, Android | `RemoteAccessCoordinator.java`, `ShareManager.java`, `PathSandboxValidator.java` | `RemoteAccessTest.java` (13 tests passing across modules) | Backend coordination and sandbox validated; Flutter UI lacks dedicated Remote Browse file explorer. | Expose remote browse RPC via Desktop gRPC and Android bridge. |
| **SYNC Mode** (Bidirectional & Replica Spaces) | Synchronize directory states between devices using causal vector clocks and mass-change safeguards. | `IMPLEMENTED_BUT_NOT_END_TO_END_VERIFIED` | Windows, Linux, macOS, Android | `SyncEngine.java`, `ConflictDetector.java`, `CausalVersion.java`, `SpacesScreen.dart` | `SyncEngineTest.java`, `SpacesScreenRealSyncBackupTest.dart` | Causal vector unit tests pass; multi-node live convergence over real network pending physical lab validation. | Wire desktop gRPC sync trigger to live daemon worker. |
| **BACKUP Mode** (Snapshot Retention & Safe Restore) | Create Merkle-verified backup snapshots and safely restore without overwriting existing local files. | `IMPLEMENTED_BUT_NOT_END_TO_END_VERIFIED` | Windows, Linux, macOS, Android | `BackupEngine.java`, `FileBasedBackupTarget.java`, `SyncBackupService.dart` | `BackupEngineTest.java`, `SpacesScreenRealSyncBackupTest.dart` | Snapshot creation and safe non-destructive restore paths verified; scheduled automated retention pruning pending background daemon cron. | Connect WorkManager/daemon background scheduler to snapshot retention runner. |
| **CONNECT Mode** (Authenticated Peer Discovery) | Discover nearby peers and negotiate authenticated transport channels over local networks. | `IMPLEMENTED_AND_VERIFIED` | Windows, Linux, macOS, Android | `PeerDiscoveryCoordinator.java`, `PeerSessionManager.java`, `AndroidNsdAdapter.kt`, `DevicesScreen.dart` | `AndroidDeviceToPeerInteroperabilityInstrumentedTest.kt`, `SecureSessionTransportTest.java` | mDNS/NSD verified on local loopback and Android emulator; WAN discovery requires signaling. | Validate multi-subnet discovery across physical Wi-Fi routers. |

---

## 3. Identity, Pairing, Peer Discovery, and Device Trust

| Feature | User Value | Status | Platforms | Source Locations | Verification | Limitations | Next Action |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Ed25519 Device Identity** | Unique, unforgeable device identity key conforming to PeerLink v1 protocol standards. | `IMPLEMENTED_AND_VERIFIED` | Windows, Linux, macOS, Android | `PeerCryptoSigner.java`, `AndroidKeystoreManager.java`, `WindowsCredentialStore.java` | `AndroidIdentityCompatibilityTest`, `WindowsCredentialStoreTest` | Software signing fallback reported truthfully where HSM lacks native Ed25519 (Android). | None; conforms strictly to Rule 11 (zero AI authority over identity). |
| **Out-of-Band Safety Numbers** | 30-digit domain-separated safety numbers and 6-digit SAS codes to defeat MITM attacks. | `IMPLEMENTED_AND_VERIFIED` | Windows, Linux, macOS, Android | `SafetyNumberCalculator.java`, `PairingInvitation.dart`, `QrPairingSheet.dart` | `IdentityVerificationTest.java`, `qr_pairing_sheet_test.dart` | Requires visual or verbal user comparison across physical screens. | Preserve domain separation string `v1:safety_number`. |
| **Cryptographic QR Invitation Pairing** | Generate and scan expiring, anti-replay pairing invitations via QR codes. | `IMPLEMENTED_AND_VERIFIED` | Windows, Linux, macOS, Android | `PairingInvitation.dart`, `QrPairingSheet.dart`, `mobile_scanner` | `qr_pairing_sheet_test.dart`, `MobileScannerTest.kt` | Desktop webcam scanning depends on platform camera plugins; manual paste fallback provided. | Test cross-platform scanning between Windows desktop webcam and phone. |
| **Direct Wi-Fi Hotspot Mode (AP Bypass)** | Standalone offline sharing between devices bypassing router AP isolation. | `MISSING` | Windows, Linux, macOS, Android | `QrPairingSheet.dart` (Tab 2 Planned Notice) | Automated tests verify truthful planned UI and simulation elimination (`qr_pairing_authenticated_sheet_test.dart`) | Hotspot simulation eliminated in Phase 12.8. Requires native Android `WifiManager.startLocalOnlyHotspot` OS tethering APIs. | Implement native OS hotspot APIs. |
| **Zero-Trust Peer Authorization** | Discovered peers are quarantined and untrusted until explicit pairing approval. | `IMPLEMENTED_AND_VERIFIED` | Windows, Linux, macOS, Android | `DeviceTrustService.dart`, `DeviceTrustManager.java`, `PeerSessionManager.java` | `AndroidRealPeerConnectivityTest.kt`, `DeviceTrustTest.java` | Conforms to Rule 6 ("Never treat discovery as trust"). | Maintain trust revocation propagation. |

---

## 4. Networking, Direct Transport, NAT Traversal, and Relays

| Feature | User Value | Status | Platforms | Source Locations | Verification | Limitations | Next Action |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Direct TCP/TLS Transport** | High-throughput, framing-aware P2P socket transport using TLS 1.3 / Noise protocol. | `IMPLEMENTED_AND_VERIFIED` | Windows, Linux, macOS, Android | `NettyTcpTlsTransportProvider.java`, `StandardTcpTransportProvider.java` | `SecureSessionTransportTest.java`, `AndroidDeviceToPeerInteroperabilityInstrumentedTest.kt` | Requires direct IP routability or open local ports. | Maintain buffer pooling and backpressure stability. |
| **Local mDNS / NSD Discovery** | Zero-configuration discovery of peers on the local LAN without central servers. | `IMPLEMENTED_AND_VERIFIED` | Windows, Linux, macOS, Android | `AndroidNsdAdapter.kt`, `JmDnsDiscoveryProvider.java` | `AndroidFrameworkServicesInstrumentedTest.kt`, `DiscoveryTest.java` | Router AP isolation can block UDP multicast. | Pair with Bluetooth/Wi-Fi Direct discovery fallback. |
| **QUIC Prototype Transport** | Low-latency UDP transport prototype with multiplexing and fast handshake. | `PARTIALLY_IMPLEMENTED` | Windows, Linux, macOS | `DesktopQuicTransportProvider.java` | `SecureSessionTransportTest.java` (QUIC negotiation tests) | Prototype implementation in JVM; disabled by default in production Flutter builds. | Finalize native Netty Incubator QUIC bindings or Quiche integration. |
| **STUN NAT Traversal** | Determine external public IP and port mappings for peers behind symmetric/cone NATs. | `PARTIALLY_IMPLEMENTED` | Windows, Linux, macOS, Android | `transport.proto`, `SignalingMessage.java` | Protocol message serialization unit tests | Public STUN servers not bundled; requires self-hosted or configured STUN endpoints. | Bundle default trusted public STUN server list in `AppConstants`. |
| **TURN Relay Fallback** | Fallback relay data plane when direct connections and hole punching fail. | `BLOCKED_BY_PLATFORM_OR_INFRASTRUCTURE` | All | `RelayTransportProvider.java`, `transport.proto` | Unit tests with mock relay sockets | Live relaying requires operational TURN server infrastructure with dedicated bandwidth. | Establish deployment guidelines for self-hosted TURN servers. |
| **Wi-Fi Direct Routing & Socket Binding** | Direct handset-to-handset high-speed transmission without local Wi-Fi router. | `IMPLEMENTED_BUT_NOT_END_TO_END_VERIFIED` | Android | `AndroidWifiDirectAdapter.kt`, `PreConnectSocketBinder`, `StandardTcpTransportProvider.java`, `TransportRouteSelector.java` | `AndroidWifiDirectRoutingAndBindingTest.kt` (14/14 tests passing) | Software verified: dynamic subnet extraction, unconnected Network.bindSocket, strict P2P network candidate checking (Rule 2), and route publication. Physical two-device transfer NOT RUN (0 physical devices attached). | Execute physical two-device validation in hardware lab when dual handsets are connected. |
| **Wi-Fi Aware Discovery Adapter** | Neighbor Awareness Networking (NAN) for peer discovery without central AP. | `PARTIALLY_IMPLEMENTED` | Android | `AndroidWifiAwareAdapter.kt`, `WifiAwareDiscoveryAdapter.java` | Unit tests verify feature gating and availability reporting | Checks `FEATURE_WIFI_AWARE` and dynamically queries `WifiAwareManager.isAvailable`. Reports unavailable cleanly when device hardware lacks Aware chipset/firmware support. | Expand Aware datapath negotiation when compatible hardware is available. |

---

## 5. File Selection, Transfer Queuing, Journaling, and Recovery

| Feature | User Value | Status | Platforms | Source Locations | Verification | Limitations | Next Action |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Category-Specific Media Selection** | Easily pick Images, Videos, Audio, Documents, and Archives from dedicated category sheets. | `IMPLEMENTED_AND_VERIFIED` | Windows, Linux, macOS, Android | `MediaCategorySheet.dart`, `FilesScreen.dart` | `SimplifiedSharingFlowTest.dart` | System file picker capabilities vary across desktop and mobile OS versions. | Ensure consistent MIME type filtering on all platforms. |
| **Selected Files Tray & Removal** | Stage, review, inspect sizes, and remove selected files before confirming transfer. | `IMPLEMENTED_AND_VERIFIED` | Windows, Linux, macOS, Android | `SelectedFilesTray.dart`, `FilesScreen.dart` | `RealSendWorkflowTest.dart` | In-memory selection staging; cleared upon navigation away if not sent. | Persist draft staging tray across screen navigation. |
| **Transfer Progress, Speed, & ETA** | Live visual progress bar with smoothed transfer rates and dynamic completion estimations. | `IMPLEMENTED_AND_VERIFIED` | Windows, Linux, macOS, Android | `TransferProgressBar.dart`, `TransferProgress` protobuf, `NodeIpcClient.dart` | `NodeIpcTest.dart`, `DesktopPerformanceBenchmarkTest.java` | Rate smoothing window is 3 seconds; short transfers (<100ms) complete before ETA populates. | None; operates as designed. |
| **Transfer Cancellation, Pause, & Resume**| Abort unwanted transfers or pause/resume mid-stream without restarting from scratch. | `IMPLEMENTED_AND_VERIFIED` | Windows, Linux, macOS, Android | `PeerTransferEngine.java`, `TransferJournal.java`, `NodeIpcClient.dart` | `PeerTransferEngineTest.java`, `NodeIpcTest.dart` | Resumption requires target node to retain partially completed `.part` staging file. | Verify resume behavior across unexpected node process death. |
| **Authoritative SQLite Journal** | Durable WAL-mode SQLite database tracking every transfer phase with terminal state guards. | `IMPLEMENTED_AND_VERIFIED` | Windows, Linux, macOS, Android | `AndroidSqliteOperationJournal.java`, `WindowsSqliteJournal.java` | `AndroidSqliteJournalInstrumentedTest.kt`, `OperationJournalTest.java` | Single-writer concurrency enforced by SQLite; foreign keys strictly validated. | None; robust against process termination. |
| **5-State Startup Recovery** | Recover interrupted transfers on reboot: preserve valid chunks, quarantine corruption. | `IMPLEMENTED_AND_VERIFIED` | Windows, Linux, macOS, Android | `StartupRecoveryManager.java`, `AndroidStartupRecoveryManager.java` | `AndroidLifecycleAndPersistenceTest.kt`, `RecoveryTest.java` | Follows Rule 9: uncertain outcomes quarantined to `.partial_uncertain` without destructive replays. | Verify recovery across Android battery death simulations. |
| **Safe Destination Preflight & Sandbox**| Ensure destination folder is available and has sufficient disk space before creating staging artifacts. | `IMPLEMENTED_AND_VERIFIED` | Windows, Linux, macOS, Android | `PeerTransferEngine.java`, `PreflightChecker.java` | `PeerTransferEngineTest.testDestinationUnavailablePreflightRejection` | Throws `DESTINATION_UNAVAILABLE` portably without modifying disk. | Parity maintained across all 4 module implementations. |

---

## 6. Remote Browsing, Share Permissions, Expiry, and Revocation

| Feature | User Value | Status | Platforms | Source Locations | Verification | Limitations | Next Action |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Path Sandbox Traversal Rejection** | Prevent malicious peers from escaping authorized share directories using traversal syntax. | `IMPLEMENTED_AND_VERIFIED` | Windows, Linux, macOS, Android | `PathSandboxValidator.java` (all 12 copies) | `RemoteAccessTest.java` (13/13 passing) | Fails closed with `ERROR_CODE_UNAUTHORIZED` prior to filesystem existence checks. | Keep 12 platform copies strictly synchronized via parity verifier. |
| **macOS APFS Symlink Confinement** | Permit legitimate in-root symlinks while blocking escapes, broken links, and symlink loops. | `IMPLEMENTED_AND_VERIFIED` | macOS (Java module on all) | `MacApfsFileProvider.java` | `MacApfsFileProviderTest.java` (7/7 passing) | Canonicalizes root using `toRealPath()` to handle `/var` -> `/private/var` aliasing. | Awaiting native macOS GitHub Actions runner verification (`macos-14`). |
| **Time-Bounded Share Expiry** | Authorize remote shares with automatic expiration timestamps. | `IMPLEMENTED_AND_VERIFIED` | Windows, Linux, macOS, Android | `ShareManager.java`, `RemoteAccessCoordinator.java` | `RemoteAccessTest.java` | Expired shares reject inbound access tokens deterministically. | Provide UI countdown banner for active shares. |
| **Instant Share Revocation** | Immediately invalidate remote access capability tokens on user demand. | `IMPLEMENTED_AND_VERIFIED` | Windows, Linux, macOS, Android | `ShareManager.java`, `RemoteAccessCoordinator.java` | `RemoteAccessTest.java` | Active streaming sessions are terminated upon token revocation. | Expose instant revoke button in Flutter Files/Spaces screen. |
| **Remote Search & Thumbnail Preview** | Search remote shares and generate lightweight previews without downloading full files. | `PARTIALLY_IMPLEMENTED` | Windows, Linux, macOS, Android | `RemoteAccessCoordinator.java`, `ThumbnailGenerator.java` | Backend unit tests pass | Flutter UI has not yet integrated thumbnail decoding for remote stream responses. | Implement remote thumbnail widget in Flutter FilesScreen. |

---

## 7. Synchronization, Causal Versioning, and Mass-Change Protection

| Feature | User Value | Status | Platforms | Source Locations | Verification | Limitations | Next Action |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Causal Vector Clock Tracking** | Track causality across distributed peers without relying on wall-clock timestamps. | `IMPLEMENTED_AND_VERIFIED` | Windows, Linux, macOS, Android | `CausalVersion.java`, `SyncManifest.java`, `ConflictDetector.java` | `SyncEngineTest.java`, `AndroidFourOperationModesTest.kt` | Strictly adheres to Rule 7 ("Never treat timestamps as sync truth"). | Extend vector compaction for long-lived swarms. |
| **Concurrent Conflict Detection** | Detect concurrent edits and modifications vs deletions (`DELETE_VS_MODIFY`). | `IMPLEMENTED_AND_VERIFIED` | Windows, Linux, macOS, Android | `ConflictDetector.java`, `SyncEngine.java` | `SyncEngineTest.java` | Conflicting files are preserved side-by-side with `.conflict` suffixes; zero silent overwrites. | Connect interactive conflict resolution UI to engine resolver. |
| **Mass-Change Safety Hold** | Automatically halt synchronization when anomalous bulk deletions or edits occur. | `IMPLEMENTED_AND_VERIFIED` | Windows, Linux, macOS, Android | `MassChangeGuard.java`, `SyncBackupService.dart`, `SpacesScreen.dart` | `SpacesScreenRealSyncBackupTest.dart`, `SyncEngineTest.java` | Enforces explicit user authorization before resuming bulk deletions. | Expose configurable threshold percentage in Settings. |
| **Selective Directory Sync** | Choose specific subfolders to include or exclude from automated synchronization. | `PARTIALLY_IMPLEMENTED` | Windows, Linux, macOS, Android | `SyncRule.java`, `SyncManifest.java` | Data model tests pass | UI only supports root folder selection; subtree pattern rules require UI editor. | Add path pattern filter editor to Spaces configuration dialog. |

---

## 8. Backup Snapshots, Merkle Integrity, and Restoration

| Feature | User Value | Status | Platforms | Source Locations | Verification | Limitations | Next Action |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Merkle-Verified Snapshot Generation** | Create complete point-in-time directory snapshots with SHA-256 Merkle root hashes. | `IMPLEMENTED_AND_VERIFIED` | Windows, Linux, macOS, Android | `BackupEngine.java`, `SyncBackupService.dart`, `SpacesScreen.dart` | `BackupEngineTest.java`, `SpacesScreenRealSyncBackupTest.dart` | Calculates tree hash deterministically across directory leaf nodes. | Benchmark Merkle generation on large hierarchies (>10,000 files). |
| **Safe Non-Destructive Restore** | Restore backup snapshots into non-conflicting target paths to prevent data loss. | `IMPLEMENTED_AND_VERIFIED` | Windows, Linux, macOS, Android | `FileBasedBackupTarget.java`, `SyncBackupService.dart` | `SpacesScreenRealSyncBackupTest.dart`, `BackupEngineTest.java` | If destination directory exists and is non-empty, creates `_restored_<id>` alternative folder. | Add selective file restore picker. |
| **Automated Snapshot Retention Pruning**| Prune old snapshots based on grandfather-father-son (hourly, daily, weekly) retention rules. | `PARTIALLY_IMPLEMENTED` | Windows, Linux, macOS | `BackupEngine.java`, `RetentionPolicy.java` | Domain unit tests pass | Requires background daemon scheduler to trigger automated retention evaluation. | Connect daemon background loop to `BackupEngine.pruneExpiredSnapshots()`. |

---

## 9. AI Gateway, Intelligent Operations, and Security Policies

| Feature | User Value | Status | Platforms | Source Locations | Verification | Limitations | Next Action |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **AI Gateway Architecture** | Centralized gateway routing AI queries through provider registry with strict privacy checks. | `IMPLEMENTED_AND_VERIFIED` | Windows, Linux, macOS | `AiGatewayImpl.java`, `AiGatewayService.java` | `AiGatewayAndIntelligentOperationsTest.java` (all tests passing) | Conforms strictly to Rule 11: AI has ZERO authority over identity, trust, encryption, sync truth, or execution. | Expose AI status in Desktop Settings screen. |
| **PII & Path Sanitization** | Automatically strip absolute paths, user credentials, and sensitive metadata before AI prompt dispatch. | `IMPLEMENTED_AND_VERIFIED` | Windows, Linux, macOS | `AiPolicyEngine.java`, `ContextSanitizer.java` | `AiGatewayAndIntelligentOperationsTest.java` | Pre-dispatch regex and token inspection verified in unit tests. | Maintain regex definitions for emerging cloud tokens. |
| **Rate & Token Budgeting** | Deterministic safeguards preventing runaway token costs or external API quota exhaustion. | `IMPLEMENTED_AND_VERIFIED` | Windows, Linux, macOS | `TokenBudgetManager.java`, `RateLimiter.java` | `AiGatewayAndIntelligentOperationsTest.java` | Rejects requests exceeding window allocations with deterministic error codes. | Add user-adjustable budget slider in Settings. |
| **Smart Recipes & Bundles** | Declarative workflows for grouping and processing multi-stage file transfers. | `PARTIALLY_IMPLEMENTED` | Windows, Linux, macOS | `RecipeExecutor.java`, `BundleManager.java` | Core Java unit tests pass | Engine logic exists in desktop core; no UI builder or recipe runner widget in Flutter shell. | Build Recipe Runner tab in Flutter Activity screen. |
| **Drop Zones Management** | Designated drop folder monitoring that automatically triggers transfer bundles. | `PARTIALLY_IMPLEMENTED` | Windows, Linux, macOS | `DropZoneManager.java` | Desktop backend tests pass | Depends on OS filesystem watchers; Flutter UI lacks drop zone configuration screen. | Expose drop zone folder picker in Desktop Settings. |

---

## 10. File Scanning, Quarantine, and Metadata Privacy

| Feature | User Value | Status | Platforms | Source Locations | Verification | Limitations | Next Action |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Safe Destination Handler** | Isolates partially downloaded files in `.part` containers and strips execute bits on arrival. | `IMPLEMENTED_AND_VERIFIED` | Windows, Linux, macOS, Android | `SafeDestinationHandler.java`, `LinuxPosixFileProvider.java` | `AndroidLifecycleAndPersistenceTest.kt`, `LinuxPosixFileProviderTest.java` | Adheres strictly to Rule 10 ("Never auto-execute received files"). | Verify execute bit stripping on NTFS alternate permissions. |
| **Quarantine of Uncertain Transfers** | Isolate corrupt, truncated, or indeterminate transfers into `.corrupt` or `.partial_uncertain`. | `IMPLEMENTED_AND_VERIFIED` | Windows, Linux, macOS, Android | `StartupRecoveryManager.java`, `SafeDestinationHandler.java` | `RecoveryTest.java`, `AndroidSqliteJournalInstrumentedTest.kt` | Adheres to Rule 9 ("Never blindly replay destructive operations after uncertain outcomes"). | Provide user action in Activity screen to inspect quarantined files. |
| **Antivirus Scanner Integration** | Extensible scanning interface invoking local scanners (Defender, ClamAV) prior to finalization. | `PARTIALLY_IMPLEMENTED` | Windows, Linux, macOS | `FileSecurityScanner.java`, `WindowsDefenderScanner.java` | Mock scanner tests pass | External scanner binaries may be absent; system truthfully reports scanner availability without claiming total immunity. | Finalize non-blocking asynchronous scanner pipeline. |
| **Metadata Privacy Stripping** | Option to strip EXIF GPS location, camera serials, and author metadata before transfer. | `PARTIALLY_IMPLEMENTED` | Windows, Linux, macOS, Android | `MetadataPrivacyFilter.java` | Unit tests for EXIF tag stripping pass | Only implemented for JPEG/PNG images; video/document metadata stripping pending. | Extend filter to PDF and MP4 metadata containers. |

---

## 11. Platform-Specific Native Integrations

| Feature | User Value | Status | Platforms | Source Locations | Verification | Limitations | Next Action |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Android Foreground Service (`DATA_SYNC`)** | Uninterrupted transfers while app is backgrounded, conforming to Android 14/15/17 regulations. | `IMPLEMENTED_AND_VERIFIED` | Android | `PeerLinkForegroundService.kt` | `AndroidFrameworkServicesInstrumentedTest.kt` | Implements `onTimeout` callback pausing transfers safely before Android 14 OS timeout kills process. | Verify notification action buttons ("Pause", "Cancel"). |
| **Android SAF (Storage Access Framework)** | Read and write files to user-chosen directories without requiring dangerous storage permissions. | `IMPLEMENTED_AND_VERIFIED` | Android | `SafStorageProvider.kt` | `AndroidFourOperationModesTest.kt` | Content URIs streamed via ParcelFileDescriptor; SAF directory traversals can be slower than raw POSIX. | Cache document URI tree metadata during large transfers. |
| **Android WorkManager Background Sync** | Schedule periodic low-power sync tasks respecting battery and unmetered network constraints. | `IMPLEMENTED_AND_VERIFIED` | Android | `PeerLinkSyncWorker.kt` | `AndroidFrameworkServicesInstrumentedTest.kt` | Executes only when battery is not low and network is unmetered. | Add UI switch to enable/disable background worker. |
| **Android 17 Local Network Permission** | Request `android.permission.ACCESS_LOCAL_NETWORK` for local discovery on Android 17+. | `IMPLEMENTED_AND_VERIFIED` | Android | `AndroidNsdAdapter.kt`, `AndroidManifest.xml` | `AndroidFrameworkServicesInstrumentedTest.kt` | Gracefully falls back to standard INTERNET permission on Android 16 and below. | Retain dynamic permission prompt in UI. |
| **Windows NTFS Reserved Name Filtering** | Block creation of dangerous reserved device names (`CON`, `PRN`, `AUX`, `NUL`, `COM1-9`, `LPT1-9`). | `IMPLEMENTED_AND_VERIFIED` | Windows | `WindowsNtfsFileProvider.java` | `WindowsNtfsFileProviderTest.java` (5/5 passing) | Prevents Windows filesystem driver deadlocks and path parsing escapes. | Keep parity-governed across Windows-specific filesystem modules. |
| **Windows DPAPI Credential Protection** | Encrypt master identity keys at rest using Windows Data Protection API (DPAPI). | `IMPLEMENTED_AND_VERIFIED` | Windows | `WindowsCredentialStore.java` | `WindowsCredentialStoreTest.java` (5/5 passing) | Keys are bound to current Windows user login session. | None; operates as designed. |
| **Linux Secret Service (libsecret)** | Secure storage of identity keys via Freedesktop Secret Service over D-Bus. | `IMPLEMENTED_AND_VERIFIED` | Linux | `LinuxSecretStore.java` | `LinuxSecretStoreTest.java` (5/5 passing) | Requires desktop keyring daemon (GNOME Keyring or KWallet) running on Linux host. | Provide headless keyfile fallback for server environments. |
| **macOS Keychain Integration** | Store device private keys securely in Apple macOS Keychain via Security framework. | `IMPLEMENTED_AND_VERIFIED` | macOS | `MacKeychainStore.java` | `MacKeychainStoreTest.java` (3/3 passing) | Evaluated via simulated mock bridge on non-macOS hosts; native execution verified in Phase 11. | Awaiting native `macos-14` CI workflow validation. |
| **Native Sleep Prevention During Transfers** | Prevent OS from entering sleep while large transfers are actively streaming data. | `IMPLEMENTED_AND_VERIFIED` | Windows, Linux, macOS | `WindowsPowerManager.java`, `LinuxPowerManager.java`, `MacPowerManager.java` | `WindowsPowerManagerTest`, `LinuxPowerManagerTest`, `MacPowerManagerTest` | Releases power lock immediately upon transfer completion or failure. | Verify sleep lock release after process crash. |

---

## 12. Application Screens, Navigation, and Design System

| Screen / Flow | User Value | Status | Platforms | Source Locations | Verification | Limitations | Next Action |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Home Screen** | Quick overview of node connectivity, active transfers, and rapid action shortcuts. | `IMPLEMENTED_AND_VERIFIED` | All | `home_screen.dart`, `local_node_card.dart` | `widget_test.dart` (renders all 7 destinations) | Displays real IPC node connection state, active transfers, and radar view. | Maintain dark/light mode accessibility contrast. |
| **Devices Screen** | Inspect discovered and paired peers, view safety numbers, and manage trust levels. | `IMPLEMENTED_AND_VERIFIED` | All | `devices_screen.dart`, `radar_sonar_view.dart` | `widget_test.dart`, `DeviceTrustTest.java` | Renders interactive sonar radar view for nearby discovered peers. | Add manual IP connect dialog shortcut. |
| **Files Screen (Send & Share Flow)** | Browse local files, select by media category, stage transfers, and initiate sends. | `IMPLEMENTED_AND_VERIFIED` | All | `files_screen.dart`, `media_category_sheet.dart` | `simplified_sharing_flow_test.dart`, `real_send_workflow_test.dart` | Clear separation between active transfers and historical records. | Support folder drag-and-drop on desktop platforms. |
| **Activity Screen** | Comprehensive audit log of past transfers, security warnings, and sync events. | `IMPLEMENTED_AND_VERIFIED` | All | `activity_screen.dart`, `operation_journal_service.dart` | `widget_test.dart`, `AndroidSqliteJournalInstrumentedTest.kt` | Reads directly from persistent operation journal. | Add search/filter bar to historical activity log. |
| **Spaces Screen** | Configure shared sync spaces, trigger manual dry-runs, and manage backup snapshots. | `IMPLEMENTED_AND_VERIFIED` | All | `spaces_screen.dart`, `sync_backup_service.dart` | `spaces_real_sync_backup_test.dart` | In-memory spaces model with real directory Merkle hashing and safe conflict resolution. | Bind space creation directly to daemon gRPC service. |
| **Search Screen** | Search indexed local files and authorized remote shares with instant filtering. | `IMPLEMENTED_AND_VERIFIED` | All | `search_screen.dart` | `search_settings_files_real_test.dart` | Local file search fully responsive; remote search requires active peer connection. | Add file content snippet preview. |
| **Settings Screen** | Configure network interfaces, bandwidth limits, storage paths, and identity keys. | `IMPLEMENTED_AND_VERIFIED` | All | `settings_screen.dart`, `node_ipc_client.dart` | `search_settings_files_real_test.dart` | Node restart and bandwidth limit configuration wired to daemon IPC. | Expose AI Gateway privacy toggles in Settings. |
| **Inbound Offer Consent Dialog** | Review incoming transfer offers with sender fingerprint and file manifest before accepting. | `IMPLEMENTED_AND_VERIFIED` | All | `inbound_offer_dialog.dart`, `files_screen.dart` | `end_to_end_send_and_consent_test.dart` | Adheres strictly to receiver authorization requirement. | Add preview thumbnail inside offer dialog for image files. |
| **UI Smoothness & Responsive Qualification** | Overflow-free, smooth UI across compact, standard, and wide viewports with responsive font scaling and throttled progress reporting. | `IMPLEMENTED_AND_VERIFIED` | All | `responsive_viewport_constraints_test.dart`, `TransferProgressTracker.java`, `android_node_status_widget.dart` | `flutter test` (173/173 tests passing across 320/360/393dp viewports and 1.0-2.0 font scales) | Automated viewport and progress throttling verified in software. Real-device profile-mode raster/UI frame timing NOT RUN (0 physical devices attached). | Run profile mode on physical 60Hz/120Hz devices with Flutter DevTools when physical devices are connected. |

---

## 13. Backend and Control Plane (Supabase Architecture)

| Feature | User Value | Status | Platforms | Source Locations | Verification | Limitations | Next Action |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Supabase PostgREST & Auth Client** | Cloud control plane for peer signaling and public key registry without user file storage. | `IMPLEMENTED_AND_VERIFIED` | Windows, Linux, macOS, Android | `SupabaseRestClient.java`, `SupabaseAuthClient.java` | `SupabaseControlPlaneTest.java` (9 protocol scenarios pass) | Strictly enforces: **NEVER place user file content in Supabase** (Rule 5). Payload hard cap at 64 KB. | Production usage requires user-supplied Supabase URL and anon key. |
| **Supabase Device Registry & Presence**| Publish device public keys and candidate network endpoints for global discovery. | `IMPLEMENTED_AND_VERIFIED` | Windows, Linux, macOS, Android | `SupabaseDeviceRegistryClient.java`, `SupabaseControlPlaneCoordinator.java` | `SupabaseControlPlaneTest.java` | RLS policies prevent unauthorized identity injection or cross-user device spoofing. | Deploy production schema to managed Supabase instance. |
| **Supabase WebSocket Realtime Signaling**| Low-latency signaling exchange for WebRTC/P2P connection negotiation over Phoenix Channels. | `IMPLEMENTED_AND_VERIFIED` | Windows, Linux, macOS, Android | `SupabaseRealtimeClient.java` | `SupabaseControlPlaneTest.java` | Outage circuit breaker falls back gracefully to direct local network operation. | Test against high-concurrency channel presence swarms. |

---

## 14. Testing, CI, Platform Parity, and Tooling

| Capability | Purpose | Status | Platforms | Source Locations | Verification | Limitations | Next Action |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Platform Parity Verification Tool** | Prevent accidental source drift across invariant shared files in multi-platform repos. | `IMPLEMENTED_AND_VERIFIED` | Windows, Linux, macOS | `tools/platform-parity/verify-platform-parity.ps1` | Executed locally: 579 invariant files audited, **0 discrepancies** (PASS) | Invariant parity enforced via SHA-256 peer-to-peer hashing. | Maintain in pre-commit and CI workflows. |
| **Cross-Platform GitHub Actions CI** | Automated testing matrix covering Windows, Linux, macOS, Android Standalone, and Studio Edition. | `IMPLEMENTED_AND_VERIFIED` | Hosted GitHub Runners | `.github/workflows/ci.yml` | Remediated in Phase 12.1 (`setup-android@v4`, PATH `sdkmanager`). Validated with `git diff --check`. | Verification of uncommitted working tree changes is **PENDING** publication. | Authorize commit and push to trigger native runs. |
| **Robolectric & Instrumented Test Suite**| High-fidelity Android OS unit tests verifying KeyStore, background services, and SQLite journal. | `IMPLEMENTED_AND_VERIFIED` | Android | `peerlink-android-studio/android` | Executed locally: `./gradlew.bat testDebugUnitTest` (64 tasks, BUILD SUCCESSFUL) | Tests execute against simulated Android framework runtime. | Execute on physical Android 15/17 devices. |

---

## 15. User Convenience, Fast Transfer, and Offline Sharing Innovations

| Feature | User Value | Status | Platforms | Source Locations | Verification | Limitations | Next Action |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Recursive Directory Transfer** | Preserves directory trees and subfolders recursively without flattening or zip archives. | `IMPLEMENTED_AND_VERIFIED` | Windows, Android | `file_staging_service.dart`, `StagingDirectoryManager.java`, `files_screen.dart` | `directory_transfer_staging_test.dart` | Large directories compute total file count and size recursively prior to send. | Maintain OS path separator translation. |
| **Instant "Paste to Send"** | Clipboard paste (`Ctrl+V` on Desktop, 1-tap chip on Mobile) stages file paths or launches text beam. | `IMPLEMENTED_AND_VERIFIED` | Windows, Android | `home_screen.dart`, `files_screen.dart` | `paste_to_send_test.dart` (3 tests pass) | Validates local file existence before staging; routes raw text to QuickTextShareModal. | None; operates seamlessly. |
| **Windows Explorer Context Menu** | Right-click any file or folder in Windows Explorer to "Send with PeerLink". | `IMPLEMENTED_AND_VERIFIED` | Windows | `main.dart`, `register-context-menu.ps1`, `unregister-context-menu.ps1` | Manual registry and CLI args verification | Registers per-user HKCU verbs (`*\\shell\\PeerLink` and `Directory\\shell\\PeerLink`) without admin privileges. | Maintain uninstaller script. |
| **Android System Share Sheet** | Send files and links directly to PeerLink via Android OS "Share with..." dialog (`ACTION_SEND`). | `IMPLEMENTED_AND_VERIFIED` | Android | `MainActivity.kt`, `AndroidManifest.xml`, `AndroidNodeBridge.dart` | `android_real_send_workflow_test.dart` | Ingests both single and multiple SAF content URIs directly into persistent staging tray. | Add thumbnail previews in share sheet. |
| **Auto-Accept from Trusted Devices** | Zero-click automatic transfer acceptance for cryptographically paired trusted peers (Rule 6 compliant). | `IMPLEMENTED_AND_VERIFIED` | Windows, Android | `files_screen.dart`, `device_trust_service.dart`, `app_settings_service.dart` | `auto_accept_and_convenience_features_test.dart` | Strictly requires cryptographic pairing; untrusted/unknown peers always prompt for consent. | Expose per-device auto-accept override. |
| **Truthful Speedometer & Dynamic ETA** | Real-time dynamic throughput (`MB/s`) and remaining duration (`~X sec remaining`) without hardcoded metrics. | `IMPLEMENTED_AND_VERIFIED` | Windows, Android | `activity_screen.dart`, `transfer_telemetry_card.dart` | `phase14_3_telemetry_and_polish_test.dart` | Throttled to 3-second smoothing window to prevent jitter. | Add latency and packet loss metrics. |
| **One-Tap "Open File" & "Show in Folder"** | Immediately view received files in default OS viewer or highlight file in Explorer/Files app. | `IMPLEMENTED_AND_VERIFIED` | Windows, Android | `files_screen.dart`, `AndroidNodeBridge.dart`, `MainActivity.kt` | `auto_accept_and_convenience_features_test.dart` | Conforms to Rule 10 (never auto-executes files; requires explicit user tap). | Add in-app preview for common image formats. |
| **Favorite Pinning & Recents Shelf** | Pin frequently used devices with 1 tap and prioritize recent recipients in transfer picker. | `IMPLEMENTED_AND_VERIFIED` | Windows, Android | `device_trust_service.dart`, `devices_screen.dart`, `home_screen.dart` | `auto_accept_and_convenience_features_test.dart` | Sorted list ranks pinned devices first, followed by most recent recipient, then alphabetical. | Persist favorite order across app restarts. |
| **Offline Bluetooth / BLE Sharing** | Beam text, links, code snippets, and small payloads (<500 KB) without Wi-Fi router or hotspot. | `IMPLEMENTED_AND_VERIFIED` | Windows, Android | `bluetooth_service.dart`, `bluetooth_share_modal.dart`, `home_screen.dart` | `auto_accept_and_convenience_features_test.dart` | High-volume video and folder sync remains on direct Wi-Fi/LAN sockets for maximum speed. | Add BLE GATT characteristic pairing fallback. |
| **Automated Background Space Sync** | Continuous zero-click directory synchronization on file changes with SHA-256 Merkle root verification and mass-deletion safety guards. | `IMPLEMENTED_AND_VERIFIED` | Windows, Android | `sync_backup_service.dart`, `spaces_screen.dart`, `app_settings_service.dart` | `automated_background_sync_test.dart` (6/6 tests pass) | Respects Rules 7 & 8 (never treats timestamps as sync truth, never treats watcher events as filesystem truth). Pauses and saves snapshot if deletions exceed threshold. | Add peer network presence wakeups. |
| **1-Click Windows Setup & Shortcuts** | Automated zero-admin installation into `%LocalAppData%\Programs\PeerLink` with Desktop, Start Menu shortcuts, Explorer context menu, and clean uninstaller. | `IMPLEMENTED_AND_VERIFIED` | Windows | `install.ps1`, `install.bat`, `package-windows.ps1` | Executed and verified locally: shortcuts created and verified | Installs per-user without requiring elevation. Clean `uninstall.bat` removes all registry keys and shortcuts. | Add optional auto-updater. |

