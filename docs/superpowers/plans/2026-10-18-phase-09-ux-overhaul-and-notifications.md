# Phase 9: UX Overhaul, Media Category Sheets, Dynamic Progress & Inbound Notifications Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Materially simplify the PeerLink user experience without changing its zero-trust, crash-resilient core architecture. Deliver a simplified 2-tap sharing flow, permission-scoped media category sheets (Photo Picker & SAF), a smoothed truthful transfer progress engine, and actionable OS-level inbound transfer notifications.

**Architecture:**
- **Media Category Picker Component & Bridge**: `MediaCategorySheet` provides a Glassmorphic Material 3 bottom sheet for Photos/Videos (Android Photo Picker `ACTION_PICK_IMAGES`, zero storage permissions), Audio, Documents, Archives, and All Files (SAF `ACTION_OPEN_DOCUMENT`). Native `MainActivity.kt` and `AndroidPigeonBridge.kt` handle category-specific intent dispatch, preserving `content://` URIs and persistable permissions.
- **Simplified Sharing Flow (`FilesScreen` & `HomeScreen`)**: Direct 2-step workflow: (1) Select content from category sheet -> reviews in multi-selection bin with per-item remove and aggregate size -> (2) Tap discovered recipient avatar with trust badge -> transfer begins immediately without manual IP/port configuration wizards.
- **Truthful Dynamic Transfer Progress**: `TransferProgressModel` calculates weighted multi-file aggregate progress from real chunk byte events, applies a 3-sample sliding-window rate calculation to smooth display jitter without falsifying underlying counts, and computes remaining ETA only when statistically valid. Internal enums cleanly map to human-understandable states (`Preparing`, `Waiting for recipient acceptance`, `Transferring`, `Verifying integrity`, `Committing`, `Completed`, `Paused`, `Outcome unknown`).
- **Inbound Transfer Notifications**: `AndroidNotificationController` and `AndroidNotificationBridge` implement dedicated channels (`peerlink_requests`, `peerlink_transfers`, `peerlink_results`). Real inbound transfer offers trigger high-importance heads-up notifications with safe metadata (peer name, file count, size) and explicit immutable `PendingIntent` actions that route safely through the authoritative consent service.

**Tech Stack:** Dart 3.3+ / Flutter (Material 3, Glassmorphism, BouncingScrollPhysics), Kotlin & Java 17/21 (Android NotificationManagerCompat, Photo Picker, SAF, AndroidNodeFacade), JUnit 4 / Flutter Test.

**Spec:** `AGENTS.md`, `peerlink-android-studio/docs/research/phase09_ux_reference_analysis.md`, `docs/compatibility/COMPATIBILITY-FRAMEWORK.md`.

## Global Constraints

- Never place normal user file content in Supabase.
- Never treat discovery as trust (Rule 6).
- Never treat timestamps as sync truth (Rule 7).
- Never blindly replay destructive operations after uncertain outcomes (Rule 9).
- Never auto-execute received files (Rule 10).
- Never give AI authority over identity, encryption, trust, authorization, integrity, sync truth, deletion or execution (Rule 11).
- Never trust localhost merely because it is localhost (Rule 12).
- Zero simulated production behavior: progress must come from real byte counters and authoritative journal events.
- Never convert `content://` URIs into fabricated filesystem paths.
- Never request broad storage access (`MANAGE_EXTERNAL_STORAGE` or raw `READ_EXTERNAL_STORAGE`) merely to display media categories.

## Review Focus

1. **Photo Picker vs SAF Fallback**: Opening "Photos" must invoke `ACTION_PICK_IMAGES` on API 33+ (or compat), requesting zero storage permissions, and fall back cleanly to `ACTION_OPEN_DOCUMENT` with `image/*`.
2. **Multi-Selection Review Shelf**: Adding items across multiple categories accumulates in the selection bin, correctly computes aggregate size, and permits individual removal without clearing the rest.
3. **Truthful Byte Rate & ETA Calculation**: Rate calculation must use sliding-window averages of real chunk events. If fewer than 3 samples exist or rate is zero, ETA is displayed as neutral rather than fabricating fake minutes.
4. **Authoritative Inbound Notification Lifecycle**: Notification for an incoming request must be issued only when a genuine, authenticated offer arrives, and must be automatically dismissed when the offer is accepted, declined, or cancelled.
5. **PendingIntent Safety**: All notification intents must use `FLAG_IMMUTABLE` and pass only safe request IDs (`transferId`), never exposing private encryption keys or pairing tokens.

---

### Task 1: Media Category Sheets Component (`media_category_sheet.dart`) & Native Category Picker Bridge

**Files:**
- Create: `peerlink-android-studio/lib/design_system/components/media_category_sheet.dart`
- Modify: `peerlink-android-studio/android/app/src/main/kotlin/org/peerlink/peerlink/MainActivity.kt`
- Modify: `peerlink-android-studio/android/app/src/main/kotlin/org/peerlink/app/bridge/AndroidPigeonBridge.kt`
- Modify: `peerlink-android-studio/lib/core/platform/android_node_bridge.dart`
- Test: `peerlink-android-studio/test/media_category_sheet_test.dart`

**Interfaces:**
- Produces: `MediaCategorySheet.show(BuildContext, onCategoryPicked)`
- Produces: `AndroidNodeBridge.instance.pickCategoryContentUris(String category) -> Future<List<String>>`
- Consumes: `MainActivity.pickCategoryUris(category, result)`

- [ ] **Step 1: Write failing widget test for `MediaCategorySheet` in `test/media_category_sheet_test.dart`**
  - Verify all 6 categories render: Photos, Videos, Audio, Documents, Archives, All Files.
  - Verify selecting a category fires the appropriate callback with correct category enum/type.
  - Verify selection review shelf shows file count, aggregate size, and remove button.

- [ ] **Step 2: Implement `MediaCategorySheet` in `lib/design_system/components/media_category_sheet.dart`**
  - Build responsive Material 3 modal bottom sheet with glassmorphic cards for each category.
  - Provide selection summary tray with item tags and clear/send triggers.

- [ ] **Step 3: Update `MainActivity.kt` and `AndroidPigeonBridge.kt` for typed category pickers**
  - Handle `category == "photos"` -> `MediaStore.ACTION_PICK_IMAGES` (or `image/*` SAF).
  - Handle `category == "videos"` -> `ACTION_PICK_IMAGES` with `video/*`.
  - Handle `category == "audio"` -> `ACTION_OPEN_DOCUMENT` with `audio/*`.
  - Handle `category == "documents"` -> `ACTION_OPEN_DOCUMENT` with document MIME types.
  - Handle `category == "archives"` -> `ACTION_OPEN_DOCUMENT` with archive MIME types (`zip`, `tar`, `gz`, `7z`).
  - Handle `category == "all"` -> `ACTION_OPEN_DOCUMENT` with `*/*`.

- [ ] **Step 4: Run tests to verify passing**
  - Run: `flutter test test/media_category_sheet_test.dart`

---

### Task 2: Truthful Dynamic Transfer Progress Model (`transfer_progress_model.dart`)

**Files:**
- Create: `peerlink-android-studio/lib/core/transfer/transfer_progress_model.dart`
- Test: `peerlink-android-studio/test/unit/transfer_progress_model_test.dart`

**Interfaces:**
- Produces: `TransferProgressModel.fromEvent(Map<String, dynamic> event) -> TransferProgressModel`
- Produces: `TransferProgressRateTracker.recordSample(bytes, timestamp) -> double rateBps`
- Produces: `TransferProgressRateTracker.calculateEta(remainingBytes) -> Duration?`
- Produces: `TransferProgressModel.userFriendlyStatusText -> String`

- [ ] **Step 1: Write failing unit test in `test/unit/transfer_progress_model_test.dart`**
  - Verify rate smoothing over sliding window (min 3 samples).
  - Verify ETA returns null when samples < 3.
  - Verify multi-file aggregate byte weighting.
  - Verify mapping of raw internal states to human-understandable labels.

- [ ] **Step 2: Implement `TransferProgressModel` and `TransferProgressRateTracker`**
  - Implement zero-simulation sliding window of actual byte deltas.
  - Map states: preparing, waitingForConsent, transferring, verifyingIntegrity, committing, completed, paused, failed, cancelled, outcomeUnknown.

- [ ] **Step 3: Run unit tests to verify passing**
  - Run: `flutter test test/unit/transfer_progress_model_test.dart`

---

### Task 3: Inbound Transfer Notifications Controller & Native Bridge

**Files:**
- Modify: `peerlink-android-studio/android/app/src/main/java/org/peerlink/core/android/AndroidNotificationController.java`
- Modify: `peerlink-android-studio/android/app/src/main/kotlin/org/peerlink/app/notification/AndroidNotificationBridge.kt`
- Modify: `peerlink-android-studio/android/app/src/main/java/org/peerlink/core/android/AndroidNodeFacade.java`
- Test: `peerlink-android-studio/android/app/src/test/kotlin/org/peerlink/app/AndroidNotificationControllerTest.kt`

**Interfaces:**
- Produces: `AndroidNotificationController.showIncomingTransferPrompt(transferId, remotePeerId, peerName, fileName, totalBytes, itemCount)`
- Produces: `AndroidNotificationController.dismissIncomingTransferPrompt(transferId)`
- Produces: Channels: `peerlink_requests` (High), `peerlink_transfers` (Low), `peerlink_results` (Default)
- Consumes: `AndroidNodeFacade.notifyIncomingOffer(...)`

- [ ] **Step 1: Write unit test in `AndroidNotificationControllerTest.kt`**
  - Verify `showIncomingTransferPrompt` invokes bridge with formatted title, safe peer name, and byte size.
  - Verify `dismissIncomingTransferPrompt` cancels notification.
  - Verify `completeTransfer` notifies result channel and dismisses progress.

- [ ] **Step 2: Implement notification methods in `AndroidNotificationController` and `AndroidNotificationBridge`**
  - Add channel `peerlink_requests` with `IMPORTANCE_HIGH` and vibration.
  - Add notification with `FLAG_IMMUTABLE` PendingIntent routing to `MainActivity` with safe extra `TRANSFER_ID`.
  - Wire into `AndroidNodeFacade` when incoming offers are received.

- [ ] **Step 3: Run JVM unit tests to verify passing**
  - Run: `$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'; .\gradlew.bat :app:testDebugUnitTest`

---

### Task 4: Simplified Sharing Flow & Review Shelf in `FilesScreen`

**Files:**
- Modify: `peerlink-android-studio/lib/features/files/files_screen.dart`
- Test: `peerlink-android-studio/test/simplified_sharing_flow_test.dart`

**Interfaces:**
- Connects: `MediaCategorySheet` -> selected files shelf -> discovered recipient tap -> `initiateSend`

- [ ] **Step 1: Write widget test in `test/simplified_sharing_flow_test.dart`**
  - Verify tapping "Choose Content" opens `MediaCategorySheet`.
  - Verify selecting items displays them in the review shelf with individual sizes and aggregate total.
  - Verify tapping a discovered peer starts transfer with selected items.
  - Verify real-time progress banner displays truthful progress and rate.

- [ ] **Step 2: Integrate `MediaCategorySheet` and `TransferProgressModel` into `FilesScreen`**
  - Add "Choose Content by Category" button opening `MediaCategorySheet`.
  - Add visual multi-selection review chips with removal buttons.
  - Add discovered peer quick-send row with avatar, name, and trust badge.
  - Use `TransferProgressModel` to render smoothed real-time progress.

- [ ] **Step 3: Run Flutter tests to verify passing**
  - Run: `flutter test test/simplified_sharing_flow_test.dart`

---

### Task 5: Full Regression Testing & Phase 9 Documentation

**Files:**
- Create: `peerlink-android-studio/docs/reports/phase09_implementation_report.md`
- Create: `docs/reports/phase09_implementation_report.md`

- [ ] **Step 1: Run full JVM and Flutter test suites**
  - Verify 100% passing across all existing and new tests.
- [ ] **Step 2: Write Phase 9 Implementation Report**
  - Document initial state, research patterns adopted, files modified, test commands, and exact outputs.
