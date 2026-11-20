# PeerLink Media Center — Reference Architecture & UX Audit

## 1. Executive Summary

This document presents the reverse-engineering and architecture audit conducted for the complete reconstruction of the **PeerLink Media Center** (Media Gallery, Professional Image Viewer, and Video Theater Player). 

PeerLink targets two primary runtime platforms:
- **Windows Desktop** (Win32 / C++ Flutter embedding with keyboard, mouse, context menus, multi-window/mini-player, high-DPI scaling)
- **Android Mobile** (Android 10+ with touch gestures, edge-to-edge immersion, hardware decoder integration, orientation lock, picture-in-picture)

To replace PeerLink's initial rudimentary media viewers with production-grade multimedia experiences, we surveyed the architectural paradigms, UI patterns, and technical mechanics of five reference applications:
1. **CPlay** (Android/Windows video player)
2. **Immich** (Modern photo/video timeline & gallery)
3. **Aves** (Android-native metadata-rich gallery and viewer)
4. **Microsoft Photos** (Windows 11 desktop gallery, sidebar, large-scale viewer)
5. **VLC / mpv** (High-efficiency native decode pipelines, track selection, dynamic subtitle engines)

---

## 2. Reference 1: CPlay — Video Player Reference

**Repository:** `https://github.com/chaoszero6/cplay`  
**License:** GPL-3.0 *(Independent clean-room reconstruction; no code imported directly)*

### 2.1 Studied Capabilities
- **Touch Gesture System (Android):**
  - Left-half vertical drag: Screen brightness adjustment with floating percentage HUD pill.
  - Right-half vertical drag: Media volume adjustment with dynamic speaker icon and level bar.
  - Horizontal drag across display: Fine-grained timeline scrub with timestamp delta preview (`+0:15 / 12:43`).
  - Double-tap left/right zones: Instant 10-second skip backward / forward with animated ripple indicator.
  - Single tap: Toggle HUD chrome with auto-hide timer (3000ms delay).
- **Controls & HUD (Android & Windows):**
  - Top bar: Video title, back button, PiP trigger, audio/subtitle track selector buttons, aspect ratio toggle (Fit, Fill, 16:9, 4:3, Zoom).
  - Bottom bar: Current position, seek scrubber with buffered range visualization, total duration, playback speed selector (`0.25x` to `3.0x`), play/pause toggle, full-screen toggle.
  - Screen Lock (Mobile): Disables all HUD touches and accidental gesture triggers, leaving only an unlock pill.
- **Windows Desktop Features:**
  - Standard keyboard shortcuts: `Space` (play/pause), `Left`/`Right` (seek ±5s), `Ctrl+Left`/`Ctrl+Right` (seek ±30s), `Up`/`Down` (volume ±5%), `M` (mute toggle), `F` or `F11` (full-screen toggle), `Escape` (exit full-screen or close).
  - Context menu on right click: Audio tracks, Subtitles, Aspect ratio, Speed, Properties.
  - A-B Repeat loop: Mark point A and point B for educational or repetitive playback.

### 2.2 PeerLink Adaptation Decisions
- **Adopt:** Unified gesture handler covering brightness, volume, horizontal seek, and double-tap skips on Android; full desktop keyboard shortcut matrix on Windows.
- **Adopt:** Auto-hiding HUD with 3-second inactivity timer that resets on any pointer move or touch.
- **Adopt:** Audio track and subtitle selection menu with language tag parsing (`eng`, `und`, `jpn`, etc.).
- **Adapt for PeerLink:** Direct integration with PeerLink P2P streaming. When viewing a video located on a remote peer, playback initiates over an HTTP-range proxy without waiting for the full multi-gigabyte file to download.
- **Exclude:** External cloud synchronization or proprietary scraper plugins.

---

## 3. Reference 2: Immich — Timeline & Gallery Reference

**Repository:** `https://github.com/immich-app/immich`  
**License:** AGPL-3.0 *(Independent clean-room reconstruction; no code imported directly)*

### 3.1 Studied Capabilities
- **Timeline Date Grouping:**
  - Grouping media items chronologically: Today, Yesterday, This Week, Specific Month & Year (`November 2026`).
  - Sticky date headers during scrolling with item counts and bulk date-selection checkboxes.
- **Grid Layout & Virtualization:**
  - Dynamic aspect-ratio-aware grid with responsive column counts (3 to 6 on mobile, 4 to 10 on desktop).
  - Virtualized memory management using bounded thumbnail memory pools and disk caching.
- **Album & Folder Organization:**
  - Flat albums, hierarchical folders, favorites bucket, and archive bucket.
- **Metadata Inspection:**
  - Slide-up sheet (mobile) / side panel (desktop) revealing full technical parameters: Resolution, ISO, Aperture, Shutter Speed, Focal Length, Camera Model, File Path, File Size, and Creation Date.

### 3.2 PeerLink Adaptation Decisions
- **Adopt:** Date-grouped timeline with sticky headers and multi-select toggles.
- **Adopt:** Responsive desktop/mobile grid scaling.
- **Adopt:** Slide-over Metadata Inspector for both photos and videos.
- **Adapt for PeerLink:** Introduce **Peer Media** and **Encrypted Vault** sections in the gallery hierarchy. The gallery can display media residing on paired P2P devices with network indicators.
- **Exclude:** Server-side machine learning facial recognition and cloud backup microservices (PeerLink is strictly serverless P2P).

---

## 4. Reference 3: Aves — Android Touch Gallery Reference

**Repository:** `https://github.com/deckerst/aves`  
**License:** Apache-2.0

### 4.1 Studied Capabilities
- **Touch-First Fullscreen Viewer:**
  - Smooth two-axis pan and pinch-to-zoom using matrix transforms up to 500% scale.
  - Gesture disambiguation: When zoomed in (>1.0x), horizontal drag pans the image instead of paging to the next image. Paging only triggers when hitting the boundary edge or at 1.0x scale.
  - Double-tap zoom: Smoothly toggles between 1.0x fit-screen and 2.5x detail zoom centered on the tap point.
- **Viewing Tools:**
  - 90-degree lossless visual rotation.
  - Slideshow mode with configurable transition interval (3s, 5s, 10s).
  - Quick action toolbar: Share/Beam, Favorite, Copy, Info, Delete.

### 4.2 PeerLink Adaptation Decisions
- **Adopt:** Strict pan/page gesture disambiguation algorithm in `InteractiveViewer` and `PageView`.
- **Adopt:** Double-tap animated scale toggle centered at the user's focal point.
- **Adopt:** Slideshow with pause/play controls.
- **Adopt:** Instant visual rotation without modifying the underlying immutable file on disk unless explicitly saved.

---

## 5. Reference 4: Microsoft Photos — Windows Desktop Reference

**Reference:** Modern Windows 11 Photos App

### 5.1 Studied Capabilities
- **Desktop Information Architecture:**
  - Left navigation rail / sidebar: "All Media", "Photos", "Videos", "Albums", "Folders", "Favorites", "Vault", "Peer Media".
  - Top header action bar: Search filter, Sort By (Date Newest, Date Oldest, Size, Name), View Density (Comfortable vs Compact), Multi-select trigger, Import/Add folder.
- **Desktop Mouse & Keyboard Interactions:**
  - Right-click context menus on grid items (Open, Play, View Info, Reveal in File Explorer, Copy, Beam to Peer, Add to Favorites, Delete).
  - Arrow key navigation between photos and videos.
  - Mouse-wheel zoom in the viewer; click-and-drag panning.

### 5.2 PeerLink Adaptation Decisions
- **Adopt:** Windows-tailored left navigation sidebar with Collapsible Rail support.
- **Adopt:** Native Windows context menus using Flutter's desktop menu widgets.
- **Adopt:** "Reveal in File Explorer" (`explorer.exe /select,"<path>"`) on Windows.

---

## 6. Reference 5: VLC & mpv — Playback Engine & Architecture

**Repositories:** `videolan/vlc`, `mpv-player/mpv`  
**Flutter Bridge:** `media_kit` (LGPL-2.1+ / MIT)

### 6.1 Studied Capabilities
- Direct hardware-accelerated video decoding (DirectX D3D11 / DXVA2 on Windows, MediaCodec on Android).
- Zero frame copy: Decoding directly into GPU textures (`Texture` widget in Flutter), eliminating CPU bottleneck.
- Comprehensive codec support (H.264, HEVC/H.265, VP9, AV1, ProRes, MKV, MP4, AVI, WebM).
- Embedded and external subtitle parsing (SRT, VTT, ASS/SSA with styling and positioning).
- Audio stream selection, pitch-preserved speed adjustment (`0.25x` - `3.0x`), and gapless seek.

### 6.2 PeerLink Implementation Selection
- To ensure zero fake/mock playback and provide a production-grade engine across both Windows and Android, we integrate `media_kit` (`media_kit`, `media_kit_video`, `media_kit_libs_video`).
- An architectural abstraction `MediaPlaybackBackend` decouples the UI from the underlying player. In unit tests and headless environments, a `SimulatedPlaybackBackend` provides deterministic state transitions; in production, `MediaKitPlaybackBackend` utilizes `libmpv` with full GPU rendering on Windows and Android.

---

## 7. Comparative Feature Matrix

| Feature | CPlay | Immich | Aves | MS Photos | PeerLink Media Center |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Android Touch Brightness/Volume** | Yes | No | No | N/A | **Yes** (Vertical drag on left/right edges) |
| **Android Double-Tap Skip** | Yes | No | No | N/A | **Yes** (±10s with ripple HUD) |
| **Windows Desktop Keyboard Shortcuts** | Yes | Partial | N/A | Yes | **Yes** (Space, Arrows, M, F, Esc, etc.) |
| **Windows Explorer Context & Reveal** | Yes | No | N/A | Yes | **Yes** (`explorer.exe /select`) |
| **Date-Grouped Timeline** | No | Yes | Yes | Yes | **Yes** (Collapsible sticky date headers) |
| **Pinch-to-Zoom & Pan Disambiguation** | N/A | Yes | Yes | Yes | **Yes** (Boundary-checked matrix zoom) |
| **Slideshow Mode** | No | Yes | Yes | Yes | **Yes** (Configurable loop timer) |
| **EXIF & Technical Metadata Inspector** | Basic | Yes | Yes | Yes | **Yes** (Camera, ISO, dimensions, codec, path) |
| **P2P Remote Media Streaming** | No | No | No | No | **Yes** (Unique to PeerLink P2P network) |
| **Zero-Mock Playback Engine** | Yes | Yes | Yes | Yes | **Yes** (`media_kit` with native hardware decode) |

---

## 8. Licensing & Dependency Compliance

1. **Third-Party Repositories:** Cloned exclusively into gitignored research directories (`scratch/media_research/`). No code, icons, or binary assets from CPlay (GPL-3.0) or Immich (AGPL-3.0) are committed to the PeerLink repository.
2. **`media_kit` Ecosystem:** Licensed under MIT. Dynamically linked native libraries (`libmpv`) are governed by LGPL-2.1+, which permits dynamic linking in commercial and open-source applications without infecting the host application code.
3. **`wakelock_plus`:** Licensed under BSD-3-Clause. Prevents device screen timeout during active video playback.

---

## 9. Conclusion

The reconstructed PeerLink Media Center bridges the gap between high-performance desktop productivity (Microsoft Photos & CPlay Windows) and fluid mobile immersion (Aves & CPlay Android), while integrating natively with PeerLink's zero-cloud P2P trust and transfer foundation.
