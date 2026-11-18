# 8 New Power Features & Advanced System Upgrades Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement 8 high-impact power features across storage cleaning, batch renaming, video PiP, media trimming/audio extraction, zero-touch hotspot QR tethering, Wi-Fi 6 link diagnostics, ephemeral burner sharing, and bi-directional web portal upload, strictly adhering to the pure Minimalist Light design system and 100.0% cross-platform parity.

**Architecture:** 
1. Pure-Dart business logic services with immutable data models and unit tests.
2. Minimalist Light UI components (`#FFFFFF` surfaces, `#F7F8FA` background, `#E5E7EB` borders, `#2563EB` primary, zero dark mode, zero shadows).
3. Zero external packages, zero AI authority over execution/deletion, zero user files in Supabase.
4. 100.0% cross-platform parity synchronized across all 4 Flutter trees.

**Tech Stack:** Dart, Flutter, Pure-Dart I/O & HTTP, Responsive layout engine, Windows x64 runner & Android Studio.

---

## Global Constraints

- **Design System:** Strict Minimalist Light-Only (`#FFFFFF` surfaces, `#F7F8FA` background, `#E5E7EB` borders, `#2563EB` primary, `#0F172A` text, zero gradients, zero shadows).
- **Responsive Layout:** Must pass `responsive_viewport_constraints_test.dart` at 320dp, 360dp, and 393dp widths with font scales up to 2.0x without RenderFlex overflow.
- **Rule Compliance:** Zero user files in Supabase (Rule 5); Never auto-execute files (Rule 10); No AI authority over execution (Rule 11); Never trust localhost blindly (Rule 12).
- **Parity:** Maintain 100.0% parity across all 4 Flutter client trees.

---

## Tasks Breakdown

- [ ] **Task 1: Storage Cleaner Service & Batch Renamer**
  - Implement `StorageCleanerService` to scan for zero-byte files, orphaned fragments (`.part`, `.tmp`), duplicate forwarded media, and empty directories with Recycle Bin undo.
  - Implement `StorageCleanerSheet` in Vault view.
  - Implement `BatchRenamerService` with prefix/suffix, search & replace, sequence padding, and collision detection.
  - Implement `BatchRenamerModal` in multi-select action bar.
  - Unit & widget tests.

- [ ] **Task 2: Video PiP, Background Audio & Media Trimmer/Extractor**
  - Implement Floating Picture-in-Picture (PiP) and background audio in `VideoEngineController` & `FloatingVideoPipOverlay`.
  - Implement `MediaTrimmerService` to extract audio tracks and trim video clips without quality loss.
  - Implement `VideoTrimmerSheet` in `MediaPreviewModal`.
  - Unit & widget tests.

- [ ] **Task 3: Zero-Touch Hotspot QR Tether & Wi-Fi 6 Link Diagnostic**
  - Implement `HotspotTetherQrService` and `HotspotTetherQrSheet` for 1-tap QR connection.
  - Implement `NetworkDiagnosticService` and `NetworkDiagnosticCard` evaluating 2.4GHz vs 5GHz/Wi-Fi 6 and suggesting direct hotspot switch when throttled.
  - Unit & widget tests.

- [ ] **Task 4: Ephemeral Burner Vault Share & Bi-Directional Web Portal 2.0**
  - Implement `EphemeralBurnerShareService` with 4-digit PIN, self-destruct on close, and screenshot-protected memory-only viewer `BurnerViewerModal`.
  - Implement bi-directional multipart file upload in `WebBeamServerService` so any browser on the local network can drop files to send back to the device.
  - Unit & widget tests.

- [ ] **Task 5: Verification, Parity Sync & Windows Release Installation**
  - Run full test suite (`flutter test`).
  - Run responsive viewport tests across 320dp, 360dp, 393dp viewports.
  - Run `python scripts/sync_windows_to_all.py` and `python scripts/check_cross_platform_parity.py` (verify 100.0% parity).
  - Build Windows package with `package-windows.ps1` and install with `install.ps1`.
