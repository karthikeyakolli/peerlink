# PeerLink — Screen-by-Screen UI/UX Audit & Usability Analysis

**Document Version:** 1.0.0  
**Audit Baseline:** Phase 13.0 Complete Product-Wide UX Redesign  
**Scope:** 18 Feature Screens, 76 Modal/Sheet Components, Navigation Shells, and Form Factors (Compact Phone, Foldable, Tablet, Desktop)  

---

## 1. Executive Usability Assessment

The current PeerLink user interface exhibits significant technical depth and broad feature coverage (over 22 power utilities, P2P transfer engines, document scanning, media players, and sync spaces). However, the product currently suffers from four systemic UX flaws:

1. **Dual Navigation Hierarchy & Competing Shells:**
   On mobile devices (< 600dp), the application renders an outer 3-tab navigation bar (`Files`, `Devices`, `Activity`) while simultaneously embedding an inner 4-tab bottom navigation bar (`Files`, `Media`, `Share`, `Studio`) inside `FileManagerHomeScreen`. This creates visual confusion, reduces vertical reading viewport, and leads to navigation dead-ends.
2. **High Visual Density & Card Stacking:**
   Screens such as `HomeScreen`, `ShareHubFlowView`, and `FileConverterFlowView` present long vertical stacks of competing cards, banners, and metric displays. Progressive disclosure is underutilized, forcing users to scroll past advanced diagnostic telemetry to reach basic actions.
3. **Modal Sheet Overuse for Major Workspaces:**
   Key productivity experiences (Document Scanner, 23 iLovePDF conversion tools, Storage Treemap, Similar Photo Grouper, Audio Equalizer) were initially designed as modal bottom sheets rather than dedicated full-page workspaces. While `DedicatedToolPage` wrapped several sheets, true multi-step workflows require dedicated page navigation with stable backstacks.
4. **Disjointed Media & Player Workspaces:**
   Media management (photos/videos timeline) is bundled inside `MediaHubFlowView` together with audio playback controls (EQ, sleep fade, speed slider). Photo viewing, album management, video playback, and audio listening should be separated into dedicated Gallery and Player Hub workspaces.

---

## 2. In-Depth Screen-by-Screen UX Audit

### 2.1 Navigation Shell (`peerlink_app.dart` & `file_manager_home_screen.dart`)
- **Current Layout:**
  - Outer `MainNavigationShell` provides a Desktop `NavigationRail` (6 tabs) and Mobile `NavigationBar` (3 tabs: `Files`, `Devices`, `Activity`).
  - Inner `FileManagerHomeScreen` has an AppBar with 4 mode switcher icons + 4 action buttons, and its own bottom bar with 4 tabs (`Files`, `Media`, `Share`, `Studio`).
- **Usability Issues:**
  - **Severe Navigation Confusion:** Users on mobile see two bottom navigation bars stacked on top of each other.
  - **Duplicate Mode Selectors:** The top AppBar contains 4 symbols (`folder`, `smart_display`, `share`, `transform`) that duplicate the 4 bottom icons.
  - **Hidden Destinations:** The outer shell's `Spaces` (tab 3), `Search` (tab 4), and `Settings` (tab 5) are inaccessible from the mobile bottom bar unless tapped via small header action buttons.
- **Recommendations:**
  - Unify into a single, clean **3-Destination Global Shell**: **Home**, **Spaces (Workspace Directory)**, and **Activity**.
  - Move Settings and Search into the global AppBar or persistent drawer.
  - Eliminate the inner bottom bar from `FileManagerHomeScreen`. When a user launches a Space from the Spaces Directory, navigate to that Space as a dedicated workspace with its own top app bar and back-navigation.

---

### 2.2 Home Screen (`home_screen.dart`)
- **Current Layout:**
  - Vertical stack: Node IPC Status Card, Send/Receive Hero, Speedometer, Radar Sonar View, Quick Drop Carousel, Desktop Dropzone, Smart Clipboard Banner.
- **Usability Issues:**
  - **Information Overload:** Over 7 competing cards on a single screen. New users do not know where to start.
  - **Unconnected State:** `HomeScreen` is currently disconnected from the main navigation shell in favor of `FileManagerHomeScreen`.
- **Recommendations:**
  - Re-establish `HomeScreen` as the primary landing page answering 4 core user questions:
    1. *Are my devices connected?* (Compact local node & trusted peer pill)
    2. *Are background operations running?* (Active transfer & sync card)
    3. *What should I continue using?* (Recent files & recently used Spaces shortcuts)
    4. *How do I start a common action?* (Clean Quick Actions: Send, Receive, Browse Files, Open Gallery, Scan Doc)
  - Move Radar Sonar and Speedometer to the Share Center Space.

---

### 2.3 File Explorer (`received_vault_view.dart` & `files_screen.dart`)
- **Current Layout:**
  - Vault vs Device Storage toggle, storage breakdown bar, 8-category grid, Recent Files horizontal scroll, Folders and Files list.
- **Usability Issues:**
  - The storage breakdown bar is visually heavy.
  - Multi-selection mode requires long-pressing, but lacks a visible batch action toolbar until selection starts.
  - Breadcrumb navigation is minimal on deep directory traversals.
- **Recommendations:**
  - Adopt Material Files interaction patterns: clean breadcrumbs, dedicated list/grid toggle, sticky sort/filter bar, and clear visual indicators for local vault vs external device storage.

---

### 2.4 Media Gallery (`media_hub_flow_view.dart` - Photos & Videos)
- **Current Layout:**
  - Grid view of photos with similar photo cleanup button; list view of videos with trimmer and subtitle options.
- **Usability Issues:**
  - Lacks chronological date grouping (Today, Yesterday, Last Week, Month).
  - Lacks dedicated full-screen pinch-to-zoom image viewer with non-destructive crop/rotate editing.
  - Mixed together with the Audio Jukebox.
- **Recommendations:**
  - Separate into a dedicated **Media Gallery Space** inspired by Fossify Gallery and Google Photos.
  - Implement chronological timeline browsing with date headers, multi-select filmstrip, full-screen interactive viewer with EXIF metadata inspector, and non-destructive image editor.

---

### 2.5 Player Hub Space (`media_hub_flow_view.dart` - Audio & Video Playback)
- **Current Layout:**
  - Audio Jukebox list with speed dropdown (0.5x-3.0x), EQ button, Sleep Fade button, and FloatingAudioMiniPlayer.
- **Usability Issues:**
  - Embedded as a tab within a file converter/media view rather than functioning as a dedicated listening/watching environment.
  - Video playback launches a modal rather than a full media session player.
- **Recommendations:**
  - Separate into a dedicated **Player Hub Space** inspired by AndroidX Media3 and Voice.
  - Include Video Player with gesture controls (brightness, volume, seeking), persistent Audio Player with playback queue, speed boost, 5-band EQ, and sleep timer.

---

### 2.6 Share Center (`share_hub_flow_view.dart`)
- **Current Layout:**
  - Send/Receive Hero, Transfer Queue, Resumable Bitmask Card, 7 Turbocharger cards, 2 Diagnostic cards.
- **Usability Issues:**
  - Too many secondary experimental tools (Burner Vault, Web Portal, LAN Scratchpad, Walkie-Talkie) crowd the core transfer flow.
  - LocalSend-style simplicity is lost under accordion headers.
- **Recommendations:**
  - Redesign as a clean **Share Center Space** following LocalSend principles:
    1. Primary Send action with clear file review and recipient confirmation.
    2. Primary Receive mode with discovery visibility toggle.
    3. Transfer Queue showing live speed, ETA, and progress.
    4. Secondary utilities organized into a clean "Advanced Tools" drawer or subpage.

---

### 2.7 Document Studio (`file_converter_flow_view.dart` & `document_scanner_sheet.dart`)
- **Current Layout:**
  - 3-step scanner card embedded in conversion studio alongside 23 iLovePDF tools.
- **Usability Issues:**
  - Document scanning is cramped inside a small card inside a conversion list.
  - Multi-page scanning requires navigating modal dialogs.
- **Recommendations:**
  - Promote to a dedicated **Document Studio Space** inspired by Google ML Kit Document Scanner:
    - Step 1: Camera capture / Gallery import.
    - Step 2: Multi-page gallery, reorder, rotate, crop, clean filters (Original, B&W Clean, Magic Color, Grayscale).
    - Step 3: OCR searchable text extraction and PDF compilation.
    - Dedicated PDF Document Viewer with page thumbnails, text selection, and annotation.

---

### 2.8 PDF & Conversion Studio (`ilovepdf_suite_sheet.dart`)
- **Current Layout:**
  - 23 conversion tools displayed in categorized grid or modal sheets.
- **Usability Issues:**
  - Tools were initially invoked with instant dummy toasts. Now dynamic, but need a structured full-page configuration flow for every tool.
- **Recommendations:**
  - Dedicated **PDF & Conversion Studio Space**:
    - Grouped by user intent: *Convert to PDF*, *Convert from PDF*, *Organize & Edit*, *Security & Optimization*.
    - Standard 4-step wizard: Input File Selection -> Configuration Options -> Processing Progress -> Output Verification & Sharing.

---

### 2.9 Device Center (`devices_screen.dart`)
- **Current Layout:**
  - Quick action grid (7 items), Paired Devices list, Discovered Peers radar.
- **Usability Issues:**
  - Quick actions (WebDAV, Clipboard Sync, Remote Deck) trigger modals without explaining prerequisite peer connections.
- **Recommendations:**
  - Redesign as **Device Center Space**:
    - Clear distinction between Discovered (untrusted), Pairing (negotiating), and Trusted (authorized) devices.
    - Device detail view showing Ed25519 public key fingerprint, safety number verification, capabilities, and trust revocation.

---

### 2.10 Sync & Backup Space (`spaces_screen.dart`)
- **Current Layout:**
  - TabBar switching between Sync Spaces and Backup Snapshots.
- **Usability Issues:**
  - Screen title is "Spaces", which conflicts with the global Spaces workspace directory concept.
  - Causal conflict diff view is technical.
- **Recommendations:**
  - Rename clearly to **Sync & Backup Space**.
  - Clearly separate Sync (live causal vector replication across peers) from Backup (immutable Merkle snapshots for historical recovery).
  - Provide human-readable conflict resolution cards (Local edit vs Remote edit side-by-side).

---

### 2.11 Storage Management Space (`storage_treemap_sheet.dart` & `deep_clean_sheet.dart`)
- **Current Layout:**
  - StorageTreemapSheet presents category bytes and largest files; DeepCleanSheet presents junk categories.
- **Usability Issues:**
  - Available only as modal bottom sheets opened from sub-menus.
- **Recommendations:**
  - Create a dedicated **Storage Management Space**:
    - WinDirStat disk space treemap.
    - Similar Photos & Burst Grouper (dHash comparison).
    - Large Files and Duplicate Files inspector with side-by-side review before deletion.

---

### 2.12 Activity Center (`activity_screen.dart`)
- **Current Layout:**
  - List of past transfer and security journal events with filter chips.
- **Usability Issues:**
  - Lacks text search, date filtering, and detailed export capability.
- **Recommendations:**
  - Keep as top-level destination with enhanced filtering (Transfers, Sync, Backup, Security, Quarantined) and detailed diagnostic inspector.

---

### 2.13 Settings & Trust (`settings_screen.dart`)
- **Current Layout:**
  - Long scrollable list of grouped setting cards.
- **Usability Issues:**
  - High scrolling fatigue; difficult to locate specific network or privacy toggles quickly.
- **Recommendations:**
  - Reorganize into structured sections: General, Appearance, Navigation, Devices & Trust, Transfers, Sync & Backup, Storage, Privacy & Permissions.
