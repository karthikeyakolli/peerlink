# 8 Enhancements & Power Upgrades Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement 8 advanced file management and cross-platform superpowers (Floating Audio Player Studio, In-Place ZIP Archive Browser, Collapsible Stash Tray Dock, Deep APK Inspector, LAN Speed Benchmark Diagnostics, Exact Duplicate Finder & Visual Diff, Offline PDF Power Suite, and Secure Expiring Beam Links) with strict Minimalist Light UI and 100% test coverage across Android and Windows.

**Architecture:** Pure-Dart and lightweight platform services conforming to frozen contracts. Zero heavy third-party dependencies. Strict compliance with AGENTS.md Rules 1–12 (Rule 5: Zero user files in Supabase; Rule 6: Never treat discovery as trust; Rule 10: Never auto-execute received files; Rule 11: No AI authority over trust/crypto/truth/execution; Rule 12: Never trust localhost merely because it is localhost).

**Tech Stack:** Dart, Flutter, Windows Desktop Runner (Win32/C++), Android SAF & JNI, Pure-Dart PDF & ZIP parsers, RFC 4918 HTTP engine.

---

## Global Constraints

- **Design System:** Strict Minimalist Light-Only (`#FFFFFF` surfaces, `#F7F8FA` background, `#E5E7EB` borders, `#2563EB` primary blue, zero shadows, zero gradients, zero dark mode).
- **Responsive Layout:** Must render cleanly without RenderFlex overflows on 320dp, 360dp, and 393dp viewports with font scalings up to 2.0x.
- **Rule 10 & 11:** Static inspection only for APKs and received files; never auto-execute.
- **Cross-Platform Parity:** All additions must maintain 100.0% parity across `windows_flutter`, `android_flutter`, `canonical_flutter`, and `peerlink-android-studio`.

---

## Task Decomposition

### Task 1: Floating Audio Player & In-Place Archive Studio (Enhancements 1 & 2)
- **Files:**
  - Create: `windows/app/flutter/lib/core/audio_player_service.dart`
  - Create: `windows/app/flutter/lib/design_system/components/floating_audio_mini_player.dart`
  - Create: `windows/app/flutter/lib/core/archive_studio_service.dart`
  - Create: `windows/app/flutter/lib/design_system/components/archive_studio_sheet.dart`
  - Test: `windows/app/flutter/test/audio_player_and_archive_studio_test.dart`
- **Deliverables:**
  - `AudioPlayerService` with playlist queuing, shuffle, loop, ID3 tag extraction.
  - `FloatingAudioMiniPlayer` 48dp sticky player bar with progress scrubber and play/skip controls.
  - `ArchiveStudioService` virtual in-place ZIP directory parser, single-file extractor, and encrypted ZIP creator.
  - `ArchiveStudioSheet` modal for virtual archive browsing.

### Task 2: Multi-Folder Stash Tray & APK Inspector (Enhancements 3 & 4)
- **Files:**
  - Create: `windows/app/flutter/lib/core/file_stash_tray_service.dart`
  - Create: `windows/app/flutter/lib/design_system/components/stash_tray_dock.dart`
  - Create: `windows/app/flutter/lib/core/apk_inspector_service.dart`
  - Create: `windows/app/flutter/lib/design_system/components/apk_inspector_sheet.dart`
  - Test: `windows/app/flutter/test/stash_tray_and_apk_inspector_test.dart`
- **Deliverables:**
  - `FileStashTrayService` singleton holding multi-folder stashed items, color tag labeling (`blue`, `emerald`, `amber`, `purple`, `rose`), and batch actions.
  - `StashTrayDock` floating bottom tray with count badge and batch execution actions.
  - `ApkInspectorService` parsing APK manifest and certificate fingerprint without executing.
  - `ApkInspectorSheet` displaying permissions risk, SDK targets, and signer verification.

### Task 3: LAN Benchmark Diagnostics & Exact Duplicate Visual Diff (Enhancements 5 & 6)
- **Files:**
  - Create: `windows/app/flutter/lib/core/lan_benchmark_service.dart`
  - Create: `windows/app/flutter/lib/design_system/components/lan_benchmark_sheet.dart`
  - Create: `windows/app/flutter/lib/core/duplicate_diff_service.dart`
  - Create: `windows/app/flutter/lib/design_system/components/duplicate_diff_sheet.dart`
  - Test: `windows/app/flutter/test/lan_benchmark_and_duplicate_diff_test.dart`
- **Deliverables:**
  - `LanBenchmarkService` for measuring socket throughput, jitter, and bottleneck analysis (2.4 GHz vs 5 GHz vs USB Turbo).
  - `LanBenchmarkSheet` with live speed gauge and 1-tap diagnostic resolution.
  - `DuplicateDiffService` finding SHA-256 exact duplicates and calculating line-by-line diffs.
  - `DuplicateDiffSheet` side-by-side diff viewer with clean minimalist line highlighting.

### Task 4: Offline PDF Power Suite & Expiring Beam Links (Enhancements 7 & 8)
- **Files:**
  - Create: `windows/app/flutter/lib/core/pdf_power_suite_service.dart`
  - Create: `windows/app/flutter/lib/design_system/components/pdf_suite_sheet.dart`
  - Create: `windows/app/flutter/lib/core/expiring_beam_link_service.dart`
  - Create: `windows/app/flutter/lib/design_system/components/expiring_beam_link_sheet.dart`
  - Test: `windows/app/flutter/test/pdf_power_suite_and_beam_links_test.dart`
- **Deliverables:**
  - `PdfPowerSuiteService` providing pure-Dart PDF merging, page splitting, and watermarking.
  - `PdfSuiteSheet` with 1-tap document merge and watermark workflow.
  - `ExpiringBeamLinkService` generating tokenized, PIN-protected, auto-expiring local HTTP links.
  - `ExpiringBeamLinkSheet` showing QR code, PIN, and live countdown timer.

### Task 5: Integration, Viewport Verification, Multi-Tree Sync & Release Packaging
- **Files:**
  - Modify: `windows/app/flutter/lib/features/files/file_manager_home_screen.dart`
  - Modify: `windows/app/flutter/lib/features/files/received_vault_view.dart`
  - Modify: `windows/app/flutter/lib/features/devices/devices_screen.dart`
  - Modify: `dist_share/index.html`
- **Deliverables:**
  - Wire floating mini-player, stash dock, and sheets into the primary UI.
  - Run full test suite in `windows/app/flutter` ensuring 100% pass.
  - Verify responsive constraints across 320dp, 360dp, 393dp with font scalings up to 2.0x.
  - Run `sync_windows_to_all.py` and confirm 100.0% cross-platform parity.
  - Package and verify Windows release.
