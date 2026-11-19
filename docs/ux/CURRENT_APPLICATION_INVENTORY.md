# PeerLink — Comprehensive Current Application Inventory

**Document Version:** 1.0.0  
**Phase:** 13.0 Complete Product-Wide UI/UX Audit & Navigation Redesign  
**Audit Target:** `https://github.com/karthikeyakolli/peerlink`  
**Platforms Audited:** Android (Flutter + Native Bridge), Windows Desktop (Flutter Runner + Win32 Service), Linux, macOS  

---

## 1. Inventory Summary & Architecture Overview

The PeerLink front-end currently comprises **18 feature modules/screens**, **76 reusable design system components/sheets**, and **132 core services and data models**.

The application currently has two competing navigation shells:
1. **Outer Shell (`PeerLinkApp` -> `MainNavigationShell` in `lib/app/peerlink_app.dart`):**
   - On Desktop (>= 600dp): 6-item NavigationRail (`Files`, `Devices`, `Activity`, `Spaces`, `Search`, `Settings`).
   - On Mobile (< 600dp): 3-item NavigationBar (`Files`, `Devices`, `Activity`).
2. **Inner Shell (`FileManagerHomeScreen` in `lib/features/files/file_manager_home_screen.dart`):**
   - Mode switcher in AppBar: 4 modes (`File Manager`, `Media Viewer & Player`, `Share & Link Hub`, `File Conversions & Studio`).
   - Mode switcher in BottomBar: 4 tabs (`Files`, `Media`, `Share`, `Studio`).
   - Action buttons in AppBar: Sync Spaces (navigates to outer tab 3), Search (navigates to outer tab 4), Contextual Share, Settings (navigates to outer tab 5).

---

## 2. Screen-by-Screen Detailed Inventory

### FileManagerHomeScreen
- **Source File:** [`features/files/file_manager_home_screen.dart`](file:///c:/Users/OMEN/.gemini/antigravity-ide/scratch/peerlink-master/windows/app/flutter/lib/features/files/file_manager_home_screen.dart)
- **Route / Entry Point:** MainNavigationShell (tab index 0) / Initial route
- **Parent Workspace:** File Manager / Global Inner Shell
- **Main Purpose:** Primary landing screen providing a Xiaomi-inspired minimalist light file manager shell with 4 embedded modes.
- **Existing Components:** AppBar mode buttons (4), AppBar actions (Sync, Search, Share, Settings), StashTrayDock, FloatingAudioMiniPlayer, Bottom navigation bar (4 tabs)
- **Available Actions:** Switch between File Manager, Media Viewer, Share Hub, and Studio flows; trigger Sync Spaces, Search, Contextual Share, and Settings navigation.
- **Underlying Operation:** `In-memory mode switching via `setState(() => _selectedMode = mode)`. Listens to `RansomwareCanaryGuard` events.`
- **State Management:** StatefulWidget (`_selectedMode`, `_canarySub`)
- **Dependencies:** `RansomwareCanaryGuard`, `ContextualShareSheet`, `FloatingAudioMiniPlayer`, `StashTrayDock`
- **Loading State:** Instant mount; child views handle their own loading.
- **Empty State:** Delegated to child flow views.
- **Error State:** Ransomware canary alerts surface via modal dialog.
- **Permission-Denied State:** None at shell level; child views request permissions on demand.
- **Offline State:** 100% offline-first. No internet connectivity required.
- **Destructive-Action Handling:** None directly on shell.
- **Back-Navigation Behavior:** Handled by `MainNavigationShell` with double-back exit toast.
- **Platform Availability:** Android, Windows, Linux, macOS.
- **Known Problems:** Creates double bottom navigation on mobile devices; duplicates top-left mode switcher with bottom navigation bar; tightly couples 4 distinct flows into a single screen.

### HomeScreen (Original Dashboard)
- **Source File:** [`features/home/home_screen.dart`](file:///c:/Users/OMEN/.gemini/antigravity-ide/scratch/peerlink-master/windows/app/flutter/lib/features/home/home_screen.dart)
- **Route / Entry Point:** `lib/features/home/home_screen.dart` (Previously index 0; presently bypassed by `FileManagerHomeScreen`)
- **Parent Workspace:** Home Workspace
- **Main Purpose:** Central operational overview answering connectivity, active transfers, ambient clipboard, and quick sharing shortcuts.
- **Existing Components:** LocalNodeCard, SendReceiveHero, TransferSpeedometer, RadarSonarView, QuickDropPeerCarousel, DesktopDropzone, SmartClipboardBanner
- **Available Actions:** Quick Send, Quick Receive, QR Pairing, Bluetooth Share, Web Portal, Clipboard Sniff action, Radar tap-to-send.
- **Underlying Operation:** `SEND, CONNECT, ACCESS. Subscribes to NodeIpcClient, QuickTextService, BluetoothService, and ambient system clipboard.`
- **State Management:** StatefulWidget (`_incomingTextSub`, `_incomingBluetoothSub`, `_localAndroidPeerId`, `_activeClipboardContent`)
- **Dependencies:** `NodeIpcClient`, `DeviceTrustService`, `OperationJournalService`, `QuickTextService`, `BluetoothService`, `AndroidNodeBridge`
- **Loading State:** Animated progress indicators on Node IPC connection and Radar discovery.
- **Empty State:** Radar displays scanning ripples when 0 peers found; empty recent transfers list.
- **Error State:** Node IPC disconnection banners with reconnect retry button.
- **Permission-Denied State:** Camera (for QR scanner), Bluetooth (for BT share), Local Network (Android 17+).
- **Offline State:** Operates fully over LAN mDNS/NSD and Bluetooth.
- **Destructive-Action Handling:** None.
- **Back-Navigation Behavior:** Standard pop behavior.
- **Platform Availability:** Android, Windows, Linux, macOS.
- **Known Problems:** Orphaned in current navigation shell; visually dense with competing cards (speedometer, radar, dropzone, hero cards all stacked vertically).

### MediaHubFlowView
- **Source File:** [`features/media/media_hub_flow_view.dart`](file:///c:/Users/OMEN/.gemini/antigravity-ide/scratch/peerlink-master/windows/app/flutter/lib/features/media/media_hub_flow_view.dart)
- **Route / Entry Point:** Embedded in `FileManagerHomeScreen` (mode 1)
- **Parent Workspace:** Media Gallery & Player Hub Space
- **Main Purpose:** Consolidated media management view covering Photos, Videos, Audio Jukebox, and Documents across Vault and Device Storage.
- **Existing Components:** 2-tier sticky filter bar, Storage scope selector (Vault vs Device), Virus audit chip, Category chips, Photo Grid with SimilarPhotoGrouper, Video List with Trimmer & Subtitle menu, Audio Jukebox with Speed/EQ/Sleep controls, FloatingAudioMiniPlayer
- **Available Actions:** Filter by scope and media type; trigger similar photo grouping; play video/audio; open video trimmer; open subtitle sync; audit threat via virus scanner; adjust playback speed (0.5x-3.0x); launch 5-band EQ; launch Sleep timer.
- **Underlying Operation:** `ACCESS, AUDIT. Uses `SystemMediaScannerService` and `ReceivedFilesService`.`
- **State Management:** StatefulWidget (`_currentTab`, `_storageScope`, `_isLoading`, `_playbackSpeed`)
- **Dependencies:** `SystemMediaScannerService`, `ReceivedFilesService`, `MediaPreviewModal`, `VideoTrimmerSheet`, `SubtitleSyncSheet`, `VirusScannerSheet`
- **Loading State:** `CircularProgressIndicator` during directory scanning.
- **Empty State:** Clean empty state illustration with 'No media files found'. Controls remain sticky and interactive.
- **Error State:** Graceful fallback to empty state; snackbar notifications on scan failure.
- **Permission-Denied State:** Storage / Media access (READ_MEDIA_IMAGES, READ_MEDIA_VIDEO, READ_MEDIA_AUDIO).
- **Offline State:** 100% local device storage.
- **Destructive-Action Handling:** Video trimming can create new clips; similar photo grouper deletes rejected burst shots.
- **Back-Navigation Behavior:** Controlled by outer shell.
- **Platform Availability:** Android, Windows.
- **Known Problems:** Combines Gallery (photos/videos) and Player Hub (jukebox/EQ/speed/sleep) into one view rather than giving each a dedicated professional workspace.

### ShareHubFlowView
- **Source File:** [`features/share/share_hub_flow_view.dart`](file:///c:/Users/OMEN/.gemini/antigravity-ide/scratch/peerlink-master/windows/app/flutter/lib/features/share/share_hub_flow_view.dart)
- **Route / Entry Point:** Embedded in `FileManagerHomeScreen` (mode 2)
- **Parent Workspace:** Share Center Space
- **Main Purpose:** P2P transfer hub offering primary Send/Receive actions, Radar discovery, Resumable Bitmask engine, Turbochargers, and Network diagnostics.
- **Existing Components:** Send & Receive Hero Cards, Active Transfers Live Queue, Resumable Bitmask Engine Standby/Active Card, Expandable 'Cross-Device Turbochargers' (Link Bonding, Walkie-Talkie, Presentation Clicker, LAN Scratchpad, Hotspot Tether QR, Web Portal 2.0, Burner Vault Share), Expandable 'Network & Engine Settings' (Speed Benchmark, Governors)
- **Available Actions:** Initiate file send; toggle receive radar; resume paused bitmask chunks; bond sockets; open PTT walkie-talkie; control presentation slides; open shared scratchpad; launch Web Portal; configure bandwidth caps.
- **Underlying Operation:** `SEND, CONNECT. Interacts with `ResumableTransferService`, `NodeIpcClient`, `LocalWalkieTalkieSheet`, `MultiStreamBondingSheet`.`
- **State Management:** StatefulWidget (`_turbochargersExpanded`, `_settingsExpanded`, `_speedLimitMbps`, `_batteryGuardEnabled`)
- **Dependencies:** `ResumableTransferService`, `FileStagingService`, `DeviceTrustService`, `ContextualShareSheet`
- **Loading State:** Telemetry progress bars and animated radar waves.
- **Empty State:** Standby bitmask card when 0 sessions; empty transfers queue indicator.
- **Error State:** Error banners when socket connection drops; transfer failure retry buttons.
- **Permission-Denied State:** Local network, Bluetooth, Microphone (for walkie-talkie), Wi-Fi state.
- **Offline State:** Operates strictly over local Wi-Fi, Wi-Fi Direct, and Bluetooth.
- **Destructive-Action Handling:** Transfer cancellation options (delete partial vs preserve .part).
- **Back-Navigation Behavior:** Controlled by outer shell.
- **Platform Availability:** Android, Windows, Linux, macOS.
- **Known Problems:** Contains 14 secondary tools inside expandable accordions; primary LocalSend-style send/receive flow is interspersed with experimental turbochargers.

### FileConverterFlowView
- **Source File:** [`features/converter/file_converter_flow_view.dart`](file:///c:/Users/OMEN/.gemini/antigravity-ide/scratch/peerlink-master/windows/app/flutter/lib/features/converter/file_converter_flow_view.dart)
- **Route / Entry Point:** Embedded in `FileManagerHomeScreen` (mode 3)
- **Parent Workspace:** Document Studio & Conversion Studio Space
- **Main Purpose:** Document scanning, universal PDF conversion studio (23+ tools), offline format converters, and security sanitizers.
- **Existing Components:** Studio Category Filter Tabs, Smart Document Scanner Hero (3-step workflow, Camera capture, Photo import, B&W/Magic filters, OCR text export), iLovePDF Studio (23 categorized tools), Security & Privacy Utilities (Treemap, DoD Shredder, EXIF Stripper, Split-APK, Video Trimmer, Checksum Verifier)
- **Available Actions:** Launch camera scanner; import photos to doc album; apply image filters; extract OCR; run 23 PDF tools; execute 7-pass DoD shredding; strip GPS EXIF metadata; inspect Split-APK bundles; compute SHA-256/MD5 checksums.
- **Underlying Operation:** `CONVERT, SANITIZE, SHRED. Calls `PdfPowerSuiteService`, `SecureShredderService`, `ExifSanitizerService`, `OcrTextExtractorService`.`
- **State Management:** StatefulWidget (`_activeStudioCategory`, `_selectedFile`, `_isProcessing`, `_scannerPages`)
- **Dependencies:** `PdfPowerSuiteService`, `SecureShredderService`, `ExifSanitizerService`, `StorageTreemapSheet`, `SplitApkInspectorSheet`
- **Loading State:** Deterministic progress indicators during multi-pass shredding and PDF compilation.
- **Empty State:** Clean category empty states.
- **Error State:** Informative failure banners on corrupted input formats or password mismatches.
- **Permission-Denied State:** Camera (for document capture), Storage/SAF (for document saving).
- **Offline State:** 100% on-device processing. No external cloud conversion APIs.
- **Destructive-Action Handling:** DoD shredder permanently deletes files (requires explicit confirmation).
- **Back-Navigation Behavior:** Controlled by outer shell.
- **Platform Availability:** Android, Windows, Linux, macOS.
- **Known Problems:** Amalgamates two distinct disciplines: Document Scanning (camera, multi-page, filters, OCR) and PDF/File Conversion (iLovePDF 23 tools, format conversions, shredder, treemap).

### DevicesScreen
- **Source File:** [`features/devices/devices_screen.dart`](file:///c:/Users/OMEN/.gemini/antigravity-ide/scratch/peerlink-master/windows/app/flutter/lib/features/devices/devices_screen.dart)
- **Route / Entry Point:** MainNavigationShell (tab index 1)
- **Parent Workspace:** Device Center Space
- **Main Purpose:** Device trust management, peer discovery, pairing invitation exchange, and quick inter-device actions.
- **Existing Components:** Compact 2-row Quick Actions grid (Direct IP, Clipboard Sync, Stream Folder, WebDAV Drive, PeerRoom Drop, Remote Deck, Speed Test), Paired Devices List with Trust Badges, Discovered Peers Radar List, Safety Number Verification Modal
- **Available Actions:** Pair via QR code; verify 30-digit safety numbers; revoke device trust; disconnect active peer; initiate WebDAV file drive; sync LAN clipboard; launch remote presentation clicker.
- **Underlying Operation:** `CONNECT, ACCESS. Interacts with `DeviceTrustService`, `PeerDiscoveryCoordinator`, `QrPairingSheet`.`
- **State Management:** StatefulWidget (`_devicesSub`, `_isScanning`, `_selectedDevice`)
- **Dependencies:** `DeviceTrustService`, `NodeIpcClient`, `AndroidNodeBridge`, `QrPairingSheet`
- **Loading State:** Pulsing radar scan indicator.
- **Empty State:** 'No devices found nearby. Tap Pair Device to connect.'
- **Error State:** Connection rejection and trust revocation error snackbars.
- **Permission-Denied State:** Camera (for QR scanning), Local Network (Android 17+), Bluetooth.
- **Offline State:** Works entirely offline over local Wi-Fi and Wi-Fi Direct.
- **Destructive-Action Handling:** Revoking trust or forgetting a device terminates active sessions.
- **Back-Navigation Behavior:** Returns to tab index 0.
- **Platform Availability:** Android, Windows, Linux, macOS.
- **Known Problems:** Quick action tiles trigger modal sheets rather than full-page dedicated workflows; device capabilities are not dynamically queried before displaying actions.

### ActivityScreen
- **Source File:** [`features/activity/activity_screen.dart`](file:///c:/Users/OMEN/.gemini/antigravity-ide/scratch/peerlink-master/windows/app/flutter/lib/features/activity/activity_screen.dart)
- **Route / Entry Point:** MainNavigationShell (tab index 2)
- **Parent Workspace:** Activity Center
- **Main Purpose:** Comprehensive audit log of past transfers, sync events, backup snapshots, security warnings, and quarantined items.
- **Existing Components:** Filter Chips (All, Transfers, Sync, Security, Quarantined), Activity Event List, Event Detail Sheet, Quarantine Vault Action
- **Available Actions:** Filter events by type; inspect event telemetry (bytes, speed, sender, status); inspect quarantined files; clear completed history.
- **Underlying Operation:** `AUDIT. Reads directly from `OperationJournalService` and `StartupRecoveryManager`.`
- **State Management:** StatefulWidget (`_filter`, `_events`)
- **Dependencies:** `OperationJournalService`, `StartupRecoveryManager`, `QuarantineVaultSheet`
- **Loading State:** Shimmer skeleton while reading SQLite WAL database.
- **Empty State:** 'No recent activity recorded.' with checkmark icon.
- **Error State:** Displays database read error banner if SQLite fails.
- **Permission-Denied State:** None.
- **Offline State:** 100% local SQLite database.
- **Destructive-Action Handling:** Clearing history (clears UI log records only, not transferred files).
- **Back-Navigation Behavior:** Returns to tab index 0.
- **Platform Availability:** Android, Windows, Linux, macOS.
- **Known Problems:** Currently lacks search bar and date-range filtering for large audit logs.

### SpacesScreen
- **Source File:** [`features/spaces/spaces_screen.dart`](file:///c:/Users/OMEN/.gemini/antigravity-ide/scratch/peerlink-master/windows/app/flutter/lib/features/spaces/spaces_screen.dart)
- **Route / Entry Point:** MainNavigationShell (tab index 3) / AppBar action button
- **Parent Workspace:** Sync & Backup Space
- **Main Purpose:** Manage bidirectional folder sync spaces and Merkle-verified backup snapshots.
- **Existing Components:** TabBar (Sync Spaces vs Backup Snapshots), Sync Space Card (status, participating peer, mode, folder path), Backup Snapshot Card (Merkle hash, creation time, size, restore button), Add Space Dialog, Create Backup Dialog, Dry-Run Diff Viewer
- **Available Actions:** Create sync space; trigger manual sync; trigger dry-run; resolve causal conflicts; create backup snapshot; preview non-destructive restore; restore snapshot into safe alternative folder.
- **Underlying Operation:** `SYNC, BACKUP. Calls `SyncBackupService`, `SyncEngine`, `BackupEngine`.`
- **State Management:** StatefulWidget (`_tabController`, `_spaces`, `_snapshots`, `_isSyncing`)
- **Dependencies:** `SyncBackupService`, `DeviceTrustService`, `AndroidNodeBridge`, `WindowsFileDialog`
- **Loading State:** Linear progress bar on active Merkle hashing or causal reconciliation.
- **Empty State:** Clean empty state explaining the difference between Sync (convergent replicas) and Backup (historical recovery).
- **Error State:** Mass-change safety hold alert if bulk deletions detected; conflict alert modal.
- **Permission-Denied State:** Storage / Directory access (SAF tree URI or Windows folder picker).
- **Offline State:** Local filesystem snapshots; P2P sync across trusted peers.
- **Destructive-Action Handling:** Safe non-destructive restore guarantees no existing file overwrite.
- **Back-Navigation Behavior:** Returns to tab index 0.
- **Platform Availability:** Android, Windows, Linux, macOS.
- **Known Problems:** Naming collision: the screen is called 'SpacesScreen' but handles only Sync & Backup, whereas the user architecture requires 'Spaces' to be the top-level Workspace Directory.

### SearchScreen
- **Source File:** [`features/search/search_screen.dart`](file:///c:/Users/OMEN/.gemini/antigravity-ide/scratch/peerlink-master/windows/app/flutter/lib/features/search/search_screen.dart)
- **Route / Entry Point:** MainNavigationShell (tab index 4) / AppBar action button
- **Parent Workspace:** Global Search
- **Main Purpose:** Unified global search across local files, media, documents, devices, and indexed spaces.
- **Existing Components:** Search Text Field with Clear button, Filter Chips (All, Files, Media, Documents, Devices, Spaces), Results List with MIME-specific leading icons, File Action menu
- **Available Actions:** Instant search typing; filter results by category; open file preview; stage file for sharing; reveal in File Explorer; inspect device.
- **Underlying Operation:** `QUERY. Searches local filesystem and cached device registry.`
- **State Management:** StatefulWidget (`_query`, `_filter`, `_results`, `_isSearching`)
- **Dependencies:** `SystemMediaScannerService`, `ReceivedFilesService`, `DeviceTrustService`
- **Loading State:** Inline spinner while searching deep directory structures.
- **Empty State:** 'Type to search files, media, devices, and spaces.' / 'No matches found.'
- **Error State:** Graceful display of zero results without crashing.
- **Permission-Denied State:** Storage read access.
- **Offline State:** 100% on-device search. Zero cloud query dispatch.
- **Destructive-Action Handling:** None.
- **Back-Navigation Behavior:** Returns to previous screen.
- **Platform Availability:** Android, Windows, Linux, macOS.
- **Known Problems:** Does not index content inside PDF/text documents; search results lack thumbnail previews.

### SettingsScreen
- **Source File:** [`features/settings/settings_screen.dart`](file:///c:/Users/OMEN/.gemini/antigravity-ide/scratch/peerlink-master/windows/app/flutter/lib/features/settings/settings_screen.dart)
- **Route / Entry Point:** MainNavigationShell (tab index 5) / AppBar action button
- **Parent Workspace:** Settings, Privacy & Trust
- **Main Purpose:** Central configuration for node daemons, bandwidth, storage directories, trust, security policies, and AI gateway rules.
- **Existing Components:** Grouped Settings Cards (Node Daemon Status, Transfers & Speed, Safety & Antimalware, Device Identity, System Permissions, AI Assistant & Gateway), Rule 11 Enforced Badge, Bandwidth Slider, Storage Path Picker, Dark/Light Mode toggle
- **Available Actions:** Restart local node daemon; set transfer bandwidth limit; change default save directory; regenerate device identity; toggle ransomware canary; configure AI token budget.
- **Underlying Operation:** `CONFIGURE. Interacts with `AppSettingsService`, `NodeIpcClient`, `RansomwareCanaryGuard`.`
- **State Management:** StatefulWidget (`_settings`, `_nodeStatus`)
- **Dependencies:** `AppSettingsService`, `NodeIpcClient`, `AndroidNodeBridge`, `WindowsFileDialog`
- **Loading State:** Skeleton placeholders during node IPC health probe.
- **Empty State:** N/A (all settings categories always populated).
- **Error State:** Error dialog on node daemon communication failure.
- **Permission-Denied State:** Notification permission, Storage access.
- **Offline State:** 100% local configuration.
- **Destructive-Action Handling:** Regenerating device identity invalidates all existing peer pairings (requires confirmation).
- **Back-Navigation Behavior:** Returns to previous screen.
- **Platform Availability:** Android, Windows, Linux, macOS.
- **Known Problems:** Settings is a long vertical scroll; requires categorized subpages or scannable tabbed sections.

### FirstRunPermissionsScreen
- **Source File:** [`features/onboarding/first_run_permissions_screen.dart`](file:///c:/Users/OMEN/.gemini/antigravity-ide/scratch/peerlink-master/windows/app/flutter/lib/features/onboarding/first_run_permissions_screen.dart)
- **Route / Entry Point:** Presented on cold start if required permissions are ungranted
- **Parent Workspace:** Onboarding & Trust Setup
- **Main Purpose:** Explain privacy-first architecture, device identity, and request required permissions with transparent rationale.
- **Existing Components:** PeerLink Logo, Privacy Principles Carousel, Permission Cards (Storage/SAF, Local Network, Notifications, Camera), 'Grant Permissions' Button, 'Skip to Restricted Mode' Button
- **Available Actions:** Request system permissions sequentially; skip non-essential permissions; complete onboarding.
- **Underlying Operation:** `ONBOARDING. Calls `AndroidNodeBridge` and `PlatformCapabilities`.`
- **State Management:** StatefulWidget (`_currentStep`, `_permissionsGranted`)
- **Dependencies:** `AndroidNodeBridge`, `AppSettingsService`
- **Loading State:** Smooth transitions between explanation cards.
- **Empty State:** N/A.
- **Error State:** Displays polite explanation if permission is denied, offering manual settings launch.
- **Permission-Denied State:** Storage, Local Network, Camera, Notifications.
- **Offline State:** 100% local.
- **Destructive-Action Handling:** None.
- **Back-Navigation Behavior:** Cannot exit until completed or skipped to restricted mode.
- **Platform Availability:** Android (desktop bypasses automatically).
- **Known Problems:** Does not explain Ed25519 cryptographic identity generation or out-of-band safety number comparison.

