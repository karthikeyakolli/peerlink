# Photo ANR Resolution & Advanced Gesture Video Player Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Resolve the Android photo browsing freeze/ANR by offloading directory scans from the UI thread and virtualizing the thumbnail grid; upgrade `MediaPreviewModal` into a full-featured media studio with MX Player/VLC-style gesture controls (left drag brightness, right drag volume, horizontal scrub, double-tap skip, screen lock mode).

**Architecture:** 
1. Non-blocking asynchronous category scanning in `ReceivedFilesService` with thumbnail downsampling (`ResizeImage`).
2. Virtualized layout in `ReceivedVaultView` eliminating memory spikes.
3. Enhanced `VideoEngineController` with volume (0.0–1.0), in-app brightness (0.0–1.0), lock mode, and gesture state notifiers.
4. Gesture-driven overlay in `MediaPreviewModal` handling two-zone vertical drags, double taps, screen lock mode, and visual HUD badges.

**Tech Stack:** Dart, Flutter, Isolate/Async compute, Pure-Dart Video Engine, Strict Minimalist Light Design (`#FFFFFF` surfaces, `#F7F8FA`, `#E5E7EB` borders, zero dark mode, zero shadows).

---

## Global Constraints

- **Design System:** Strict Minimalist Light-Only (`#FFFFFF` surfaces, `#F7F8FA` background, `#E5E7EB` borders, `#2563EB` primary, zero shadows, zero gradients).
- **Responsive Layout:** Must pass `responsive_viewport_constraints_test.dart` at 320dp, 360dp, and 393dp widths with font scales up to 2.0x without RenderFlex overflow.
- **Rule Compliance:** Zero user files in Supabase (Rule 5); Never auto-execute files (Rule 10); No AI authority over execution (Rule 11); Never trust localhost blindly (Rule 12).
- **Parity:** Maintain 100.0% parity across all 4 Flutter client trees.

---

## Task Decomposition

### Task 1: Fix Android Photo Browsing ANR & Thumbnail Virtualization
- **Files:**
  - Modify: `windows/app/flutter/lib/core/received_files_service.dart`
  - Modify: `windows/app/flutter/lib/features/files/received_vault_view.dart`
- **Deliverables:**
  - Convert `_scanByCategory` filesystem traversal to non-blocking async execution so Android main looper never stalls.
  - In `_buildFileThumbnail`, use downsampled `ResizeImage(FileImage(...), width: 160, height: 160)` with memory caching.
  - Virtualize `_buildFilesGrid` with lazy item loading and viewport constraints.

### Task 2: Advanced Video Engine Controller (Gestures, Volume, Brightness, Screen Lock)
- **Files:**
  - Modify: `windows/app/flutter/lib/core/video_engine_controller.dart`
  - Create: `windows/app/flutter/test/video_engine_gestures_and_player_test.dart`
- **Deliverables:**
  - `volumeNotifier` (0.0 to 1.0) and `setVolume(double vol)`.
  - `brightnessNotifier` (0.0 to 1.0) and `setBrightness(double val)`.
  - `isLockedNotifier` (bool) and `toggleScreenLock()`.
  - Gesture helper methods: `onVerticalDragLeft(double delta)`, `onVerticalDragRight(double delta)`, `onHorizontalDrag(double delta)`, and `onDoubleTap(bool isRightSide)`.

### Task 3: Video Player Gesture Overlay & Universal Viewer UI Upgrade
- **Files:**
  - Modify: `windows/app/flutter/lib/design_system/components/media_preview_modal.dart`
- **Deliverables:**
  - Two-zone gesture detector on video viewport (left = brightness HUD, right = volume HUD).
  - Floating HUD indicators:
    - Left: Brightness badge (`☀️ 75%`) with vertical level pill.
    - Right: Volume badge (`🔊 80%`) with vertical level pill.
    - Center: Fast-scrub timestamp badge (`+00:10 [02:30 / 08:00]`).
  - Screen Lock mode: locks out all controls, showing only an unlock floating pill button.
  - Enhanced Photo Viewer with `InteractiveViewer` pinch-to-zoom and 90° rotation.

### Task 4: Full Verification, Parity Sync & Windows Release Installation
- **Files:**
  - Verify all test suites (`flutter test`).
  - Verify responsive constraints across 320dp, 360dp, 393dp viewports.
  - Sync all 4 Flutter trees (`python scripts/sync_windows_to_all.py`).
  - Package and install Windows release (`package-windows.ps1` and `install.ps1`).
