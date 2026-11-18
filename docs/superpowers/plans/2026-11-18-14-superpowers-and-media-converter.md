# 14 Superpowers, Enhanced Video Engine & Offline File Converter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement all 14 requested features, enhanced video playback controls (skip +/-10s, variable speed 0.5x-2.0x, aspect ratio, subtitles, loop), and a local offline file converter engine (Image PNG/JPG/WebP/BMP, Markdown/Text/HTML, CSV/JSON/TSV, and Text/Image -> PDF) across Windows and Android with 100% parity, zero cloud dependency, and a strict minimalist light UI.

**Architecture:** PeerLink remains a 100% local-first, peer-to-peer system. Media enhancements, file conversions, text indexing, snapshots, and streaming all execute locally in pure-Dart/native platform channels without third-party cloud services or heavy dependencies. All networking (WebDAV, P2P Clipboard, PeerRoom, Watch-Together) runs over authenticated local LAN sockets protected by mutual key authentication and token authorization adhering strictly to AGENTS.md Rules 1–12.

**Tech Stack:** Flutter / Dart (3.29.0), Java 17 / Maven (Windows Node Daemon), Kotlin / Android SDK 35, Win32 / C++ desktop integration, pure-Dart cryptographic & media parsing engines.

**Spec:** Defined in chat requirements and `AGENTS.md` frozen local-first architecture.

---

## Global Constraints

- **Rule 1–12 Compliance**: Never send user files to Supabase or cloud; never treat discovery/localhost as trust; never auto-execute received files; never treat timestamps as sync truth; never bypass cryptographic verification.
- **UI/UX Consistency**: Strict Minimalist Light-Only theme (`Colors.white`, `#F7F8FA`, `#E5E7EB` 1px borders, `#111827` primary text, `#6B7280` secondary). Zero dark mode, zero gradients, zero `BoxShadow`/glow. Responsive across 320dp–393dp viewports with up to 2.0x font scaling without overflow.
- **Multi-Tree Parity**: Any changes made must synchronize across all 4 Flutter client trees (`app/`, `windows_client/`, `app_redesign/`, `clean_client/`) maintaining 100% code identity.
- **Dependency Discipline**: Zero bloated external C++ or native binaries. All file format conversions (PNG/JPG/WebP, CSV/JSON/TSV, Markdown/HTML, and Image/Text to PDF) are implemented with pure-Dart or lightweight platform-native capabilities.

---

## Review Focus

1. **Memory safety during large conversions**: Converting high-resolution images or large CSVs must not trigger Out-Of-Memory; process chunks and enforce size safety ceilings.
2. **Fail-closed authentication on local servers**: WebDAV and PeerRoom LAN endpoints must reject any request without a valid ephemeral cryptographically-random bearer token.
3. **Atomic version snapshots**: Time-machine versioning must write to temporary files before atomic rename, preventing file corruption on process termination.
4. **Touch & Click Target Sizing**: Dual-pane split-view on desktop must handle window resize gracefully down to mobile widths without throwing RenderFlex layout overflows.
5. **Fail-closed biometric fallback**: Biometric authentication failure or cancellation must keep the Safe Folder locked; fallback to PIN must always be available.

---

## Task Decomposition

### Task 1: Enhanced Video Engine & Offline Multi-Format File Converter (Features E1, E2, #2)

**Files:**
- Create: `app/lib/features/media/services/video_engine_controller.dart`
- Create: `app/lib/features/converter/services/file_converter_service.dart`
- Create: `app/lib/features/converter/presentation/file_converter_sheet.dart`
- Create: `app/lib/features/media/presentation/video_controls_overlay.dart`
- Create: `app/lib/features/media/services/pdf_page_rasterizer_service.dart`
- Modify: `app/lib/features/media/presentation/media_preview_modal.dart`
- Modify: `app/lib/features/vault/presentation/received_vault_view.dart`
- Test: `app/test/features/converter/file_converter_service_test.dart`
- Test: `app/test/features/media/video_engine_controller_test.dart`

**Interfaces:**
- `VideoEngineController`:
  - `void seekRelative(Duration offset)` (+/- 10s, +/- 30s)
  - `void setPlaybackSpeed(double speed)` (0.5x, 0.75x, 1.0x, 1.25x, 1.5x, 2.0x)
  - `void toggleAspectRatio()` (`fit`, `fill`, `sixteenNine`, `original`)
  - `void toggleLoop()`
  - `Future<bool> loadSubtitleFile(String path)` (parses `.srt` timestamps into active cues)
  - `String? get activeSubtitleText`
- `FileConverterService`:
  - `Future<ConversionResult> convertImage({required File source, required ImageFormat targetFormat, int quality = 90, int? targetWidth, int? targetHeight, required Directory destinationDir})`
  - `Future<ConversionResult> convertDocument({required File source, required DocFormat targetFormat, required Directory destinationDir})`
  - `Future<ConversionResult> compileToPdf({required List<File> sourceImagesOrText, required String outputName, required Directory destinationDir})`
- `PdfPageRasterizerService`:
  - `Future<List<Uint8List>> renderPdfPages(File pdfFile, {int maxPages = 50})` (cross-platform pure fallback / platform rendering)

- [ ] **Step 1: Write failing unit tests for VideoEngineController and FileConverterService**
  - Verify speed controls, seek calculation clamping, SRT subtitle parsing, PNG/JPEG/BMP conversions, CSV/JSON/TSV conversions, Markdown-to-HTML, and Text/Image-to-PDF generation.
- [ ] **Step 2: Run tests to verify failures**
  - Expected: Compilation/resolution failure on missing classes.
- [ ] **Step 3: Implement VideoEngineController and FileConverterService**
  - Implement full conversion algorithms with image manipulation, structured document parsing, and lightweight PDF stream generator without heavy native dependencies.
  - Implement `VideoControlsOverlay` with responsive buttons, speed selector, skip 10s, loop, and subtitle display.
  - Integrate into `MediaPreviewModal` for both Android and Windows desktop views.
- [ ] **Step 4: Run unit tests and verify 100% pass**
  - Verify tests pass cleanly.

---

### Task 2: Desktop Dual-Pane Explorer, Live Clipboard P2P Transport & Biometric Safe Folder (Features #1, #3, #4)

**Files:**
- Create: `app/lib/features/vault/presentation/dual_pane_vault_view.dart`
- Create: `app/lib/features/clipboard/services/p2p_clipboard_transport_service.dart`
- Create: `app/lib/features/safe_folder/services/biometric_auth_service.dart`
- Modify: `app/lib/features/vault/presentation/received_vault_view.dart`
- Modify: `app/lib/features/safe_folder/presentation/safe_folder_sheet.dart`
- Test: `app/test/features/vault/dual_pane_vault_test.dart`
- Test: `app/test/features/clipboard/p2p_clipboard_transport_test.dart`
- Test: `app/test/features/safe_folder/biometric_auth_service_test.dart`

**Interfaces:**
- `DualPaneVaultView`:
  - Auto-activates on viewports with width >= 960dp.
  - Shows Left Pane (Vault / Tab 1) & Right Pane (Vault / Tab 2 or Device Storage).
  - Provides 1-tap "Copy/Move to Other Pane" and drag-between-panes.
- `P2pClipboardTransportService`:
  - Listens for local clipboard change when opt-in enabled.
  - Broadcasts encrypted frame `CLIPBOARD_SYNC` over active P2P channel.
  - Receives remote clipboard updates, applies with optional user toast/pill, and triggers 60s auto-clear.
- `BiometricAuthService`:
  - `Future<bool> canAuthenticateBiometrics()`
  - `Future<bool> authenticateWithBiometrics({required String reason})`
  - Fails closed to PIN fallback if biometrics are cancelled, locked, or unavailable.

- [ ] **Step 1: Write failing tests for Dual-Pane Explorer, P2P Clipboard Transport, and BiometricAuthService**
- [ ] **Step 2: Run tests to verify failures**
- [ ] **Step 3: Implement components and integrate into `ReceivedVaultView` and `SafeFolderSheet`**
- [ ] **Step 4: Run tests to verify pass**

---

### Task 3: Local WebDAV Server, USB-C Turbo Mode, PeerRoom Drop & Watch-Together (Features #5, #6, #7, #8)

**Files:**
- Create: `app/lib/features/webdav/services/webdav_server_service.dart`
- Create: `app/lib/features/webdav/presentation/webdav_status_sheet.dart`
- Create: `app/lib/features/transport/services/usb_turbo_mode_service.dart`
- Create: `app/lib/features/peer_room/services/peer_room_service.dart`
- Create: `app/lib/features/peer_room/presentation/peer_room_sheet.dart`
- Create: `app/lib/features/media/services/watch_together_sync_service.dart`
- Create: `app/lib/features/media/presentation/watch_together_modal.dart`
- Modify: `app/lib/features/devices/presentation/devices_screen.dart`
- Test: `app/test/features/webdav/webdav_server_service_test.dart`
- Test: `app/test/features/peer_room/peer_room_service_test.dart`
- Test: `app/test/features/media/watch_together_sync_test.dart`

**Interfaces:**
- `WebDavServerService`:
  - Implements lightweight HTTP WebDAV (PROPFIND, GET, PUT, MKCOL, DELETE, MOVE) for local vault.
  - Protected with random HTTP Basic Auth / token header.
  - Generates exact Windows `net use P: http://<ip>:<port>/ /user:...` mapping command.
- `UsbTurboModeService`:
  - Detects USB tethering interfaces (`192.168.42.x`, `192.168.43.x`) or ADB reverse localhost port.
  - Toggles priority socket routing over wired link for gigabit transfers.
- `PeerRoomService`:
  - Host creates room with 4-digit PIN; peers discover via mDNS/LAN broadcast or direct PIN.
  - Parallel chunk broadcaster sends files to all accepted room members simultaneously.
- `WatchTogetherSyncService`:
  - Emits & receives `{ action: "PLAY" | "PAUSE" | "SEEK", timestampMs: int }` over LAN socket with drift compensation.

- [ ] **Step 1: Write failing tests for WebDAV RFC 4918 handlers, PeerRoom broadcast, and WatchTogether synchronization**
- [ ] **Step 2: Run tests to verify failures**
- [ ] **Step 3: Implement WebDAV server, UsbTurbo detection, PeerRoom manager, and WatchTogether synchronizer**
- [ ] **Step 4: Run tests to verify pass**

---

### Task 4: Offline Full-Text Content Search, Time-Machine Snapshots & Photo Burst/Blur Cleaner (Features #9, #10, #11, #12)

**Files:**
- Create: `app/lib/features/search/services/offline_full_text_search_service.dart`
- Create: `app/lib/features/search/presentation/content_search_sheet.dart`
- Create: `app/lib/features/versioning/services/file_version_snapshot_service.dart`
- Create: `app/lib/features/versioning/presentation/version_history_modal.dart`
- Create: `app/lib/features/backup/services/auto_wifi_photo_backup_service.dart`
- Create: `app/lib/features/cleaner/services/photo_burst_blur_cleaner_service.dart`
- Create: `app/lib/features/cleaner/presentation/smart_photo_cleaner_sheet.dart`
- Modify: `app/lib/features/vault/presentation/received_vault_view.dart`
- Test: `app/test/features/search/offline_full_text_search_test.dart`
- Test: `app/test/features/versioning/file_version_snapshot_test.dart`
- Test: `app/test/features/cleaner/photo_burst_blur_cleaner_test.dart`

**Interfaces:**
- `OfflineFullTextSearchService`:
  - Inverted index built from `.txt`, `.md`, `.json`, `.csv`, `.docx`, `.pptx`, `.xlsx`, `.pdf`.
  - Searches query terms with snippet highlight extraction.
- `FileVersionSnapshotService`:
  - `Future<void> recordSnapshot(File file, {String reason})`
  - `List<FileSnapshot> getSnapshots(File file)`
  - `Future<void> restoreSnapshot(File targetFile, FileSnapshot snapshot)`
- `AutoWifiPhotoBackupService`:
  - Checks current SSID and paired PC online status; syncs delta camera photos by SHA-256 hash.
- `PhotoBurstBlurCleanerService`:
  - Identifies burst clusters (<2s photo intervals) and computes Laplacian edge variance for blur estimation.

- [ ] **Step 1: Write failing tests for inverted index search, snapshot rollback, and photo burst/blur clustering**
- [ ] **Step 2: Run tests to verify failures**
- [ ] **Step 3: Implement search indexer, snapshot store, auto-backup manager, and photo cleaner**
- [ ] **Step 4: Run tests to verify pass**

---

### Task 5: Remote Presentation Controller & Mobile Document Scanner (Features #13, #14), Parity Sync, and Release Build

**Files:**
- Create: `app/lib/features/remote_control/services/remote_presentation_controller_service.dart`
- Create: `app/lib/features/remote_control/presentation/remote_presentation_sheet.dart`
- Create: `app/lib/features/scanner/services/document_scanner_service.dart`
- Create: `app/lib/features/scanner/presentation/document_scanner_sheet.dart`
- Modify: `app/lib/features/vault/presentation/received_vault_view.dart`
- Modify: `app/lib/features/devices/presentation/devices_screen.dart`
- Test: `app/test/features/remote_control/remote_presentation_controller_test.dart`
- Test: `app/test/features/scanner/document_scanner_test.dart`

**Interfaces:**
- `RemotePresentationControllerService`:
  - Transmits presentation commands: `NEXT_SLIDE`, `PREV_SLIDE`, `BLACK_SCREEN`, `MEDIA_PLAY_PAUSE`, `VOLUME_UP`, `VOLUME_DOWN`, `MOUSE_MOVE(dx, dy)`.
  - Windows daemon handles Win32 `SendInput` keyboard events (`VK_RIGHT`, `VK_LEFT`, `VK_MEDIA_PLAY_PAUSE`, etc.).
- `DocumentScannerService`:
  - Perspective transforms corner points from camera frame.
  - Applies high-contrast adaptive thresholding for document readability.
  - Exports multi-page PDF directly to Vault.

- [ ] **Step 1: Write failing tests for remote presentation protocol and document scanning pipeline**
- [ ] **Step 2: Run tests to verify failures**
- [ ] **Step 3: Implement RemotePresentationController and DocumentScannerService**
- [ ] **Step 4: Run tests to verify pass**
- [ ] **Step 5: Run full test suite (`flutter test`) across all test targets**
- [ ] **Step 6: Synchronize code to all 4 Flutter trees (`scripts/sync_windows_to_all.py`) and verify 100% parity**
- [ ] **Step 7: Package Windows release ZIP and run `windows/scripts/install.ps1` to update local Windows install**
