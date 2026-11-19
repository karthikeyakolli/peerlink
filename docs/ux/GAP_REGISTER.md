# PeerLink — Comprehensive UX/UI Gap Register & Technical Defect Log

**Document Version:** 1.0.0  
**Phase:** 13.0 Complete Product-Wide UX Redesign  
**Classification Taxonomy:**
- `EXISTING_AND_VERIFIED`: Code and UI are operational and passed automated test suites.
- `EXISTING_BUT_INCOMPLETE`: Implemented in part, but lacking key workflow steps, edge-case UI, or platform adaptation.
- `NEW_UI_IMPLEMENTATION`: Requires new front-end UI architecture, layouts, or component reorganization (backend is ready).
- `NEW_BACKEND_REQUIREMENT`: Requires changes or extensions to underlying services, platform bridges, or IPC daemons.
- `NOT_TESTED`: Code exists, but has not been exercised on physical devices or with automated widget tests.
- `UNSUPPORTED`: Intentionally out of scope for the current frozen architecture or platform capabilities.
- `DEFERRED`: Planned for subsequent release cycle after core navigation redesign stabilizes.

---

## 1. Primary Architectural & Navigation Gaps

| Gap ID | Area / Screen | Description of Usability / Architectural Defect | Classification | Impact on User Experience | Proposed Resolution |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **GAP-NAV-01** | Global Navigation | Dual nested bottom navigation bars on mobile (< 600dp): `MainNavigationShell` (3 tabs) wraps `FileManagerHomeScreen` (4 tabs). | `NEW_UI_IMPLEMENTATION` | High. Confuses navigation hierarchy, creates visual clutter, and steals ~52dp vertical screen space. | Collapse into single 3-tab global shell (`Home`, `Spaces Directory`, `Activity`). Workspaces open as dedicated pages with native back navigation. |
| **GAP-NAV-02** | Home Screen | `HomeScreen` (original dashboard with Node status, Speedometer, Radar) is bypassed by `FileManagerHomeScreen` and inaccessible from primary navigation. | `NEW_UI_IMPLEMENTATION` | High. New users land directly in a file explorer without a clear overview of device connectivity, active transfers, or shortcuts. | Re-establish `HomeScreen` as tab 0, streamlined to answer the 4 core overview questions. |
| **GAP-NAV-03** | Mode Duplication | `FileManagerHomeScreen` has 4 AppBar mode buttons duplicating the 4 bottom navigation buttons. | `NEW_UI_IMPLEMENTATION` | Medium. Visual redundancy; competing interaction controls in the header and footer. | Remove AppBar mode switcher icons. |
| **GAP-NAV-04** | Desktop Layout | Desktop viewport (>= 600dp) uses a basic NavigationRail without resizable multi-pane browsing or desktop-optimized toolbars. | `NEW_UI_IMPLEMENTATION` | Medium. Wastes screen real-estate on large monitors (1080p, 1440p, 4K). | Implement responsive dual-pane / multi-pane layout on desktop with keyboard shortcuts and breadcrumbs. |
| **GAP-NAV-05** | State Loss | Switching modes inside `FileManagerHomeScreen` resets scroll positions, selected items, and search queries. | `NEW_UI_IMPLEMENTATION` | Medium. Frustrating user experience when comparing files or multitasking between transfers and conversions. | Implement `IndexedStack` or `PageStorageKey` state preservation across workspaces. |

---

## 2. Workspace & Feature-Specific Gaps

| Gap ID | Workspace / Feature | Description of Defect | Classification | Impact on User Experience | Proposed Resolution |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **GAP-MED-01** | Media Gallery | Lacks chronological date grouping (Today, Yesterday, Last Week, Month). Files render in a raw flat grid. | `NEW_UI_IMPLEMENTATION` | Medium. Browsing large photo libraries (>500 items) causes scrolling fatigue. | Add sticky chronological date headers and group photos by capture date. |
| **GAP-MED-02** | Media Gallery | Lacks dedicated full-screen pinch-to-zoom image viewer with contextual overlay controls. | `NEW_UI_IMPLEMENTATION` | Medium. Users cannot inspect photo details smoothly or zoom into high-res images. | Build professional full-screen `ImageViewerPage` with pinch, pan, double-tap zoom, and tap-to-toggle controls. |
| **GAP-MED-03** | Media Gallery | Image editing is limited to basic rotate; lacks non-destructive crop, aspect-ratio presets, and color tuning. | `EXISTING_BUT_INCOMPLETE` | Medium. Users cannot crop or enhance photos before P2P sharing. | Build non-destructive `ImageEditorPage` with crop presets (1:1, 4:3, 16:9), rotation, and 'Save as Copy' enforcement. |
| **GAP-PLY-01** | Player Hub | Audio jukebox and video player are embedded as tabs inside a file converter view rather than a dedicated media environment. | `NEW_UI_IMPLEMENTATION` | High. Confuses media consumption with file management; restricts playback queue management. | Promote to dedicated **Player Hub Space** with persistent mini-player, video gesture controls (brightness/volume), and audio queue. |
| **GAP-SHR-01** | Share Center | High visual card density in `ShareHubFlowView`: 7 experimental turbochargers and 2 diagnostic accordions crowd core send/receive actions. | `NEW_UI_IMPLEMENTATION` | High. Beginners struggle to find basic Send/Receive buttons amidst advanced telemetry. | Reorganize into a clean LocalSend-inspired layout: primary Send & Receive hero cards at top, transfer queue in middle, advanced tools in a collapsible drawer. |
| **GAP-DOC-01** | Document Studio | Smart Document Scanner is crammed into a small card inside a conversion list. Multi-page scanning requires modal dialogs. | `NEW_UI_IMPLEMENTATION` | High. Document scanning feels like an afterthought rather than a core productivity tool. | Promote to dedicated **Document Studio Space** with 3-step workflow: Camera/Import -> Multi-Page Gallery & Filters -> OCR & PDF Compiler. |
| **GAP-DOC-02** | Document Studio | Lacks a dedicated full-page PDF document viewer with page thumbnails and text selection. | `NEW_UI_IMPLEMENTATION` | Medium. Users must leave PeerLink to view compiled PDF documents in an external viewer. | Build dedicated `PdfDocumentViewerPage` with page navigation, zoom, and text search. |
| **GAP-CNV-01** | Conversion Studio | 23 conversion tools were originally presented as modal sheets with instant dummy toasts. | `EXISTING_AND_VERIFIED` *(Fixed in Phase 12.11)* | Resolved. Verified with real dynamic file pickers, but needs clean categorized UI grid. | Implement categorized 4-step wizard: Input File -> Settings -> Processing Progress -> Output Verification. |
| **GAP-DEV-01** | Device Center | Quick action tiles (WebDAV, Clipboard Sync, Remote Deck) trigger modals without explaining prerequisite peer connections. | `NEW_UI_IMPLEMENTATION` | Medium. Users tap tiles for offline peers and get confusing connection failure toasts. | Dynamically query peer capabilities and online status; disable incompatible action tiles with transparent explanatory tooltips. |
| **GAP-SNC-01** | Sync & Backup | Screen is titled 'SpacesScreen', which conflicts with the global 'Spaces' workspace directory concept. | `NEW_UI_IMPLEMENTATION` | Medium. Naming confusion between generic application spaces and folder synchronization spaces. | Rename screen to **Sync & Backup Space**. |
| **GAP-SNC-02** | Sync & Backup | Causal conflict diff view is technical and lacks clear human-readable comparison. | `EXISTING_BUT_INCOMPLETE` | Medium. Users risk making wrong decisions when resolving concurrent conflicts. | Build side-by-side visual conflict comparator showing file modifications, timestamps, and sizes with 'Keep Local', 'Keep Remote', or 'Keep Both'. |
| **GAP-STR-01** | Storage Management | Storage Treemap and Similar Photo Grouper are accessible only as sub-modal sheets. | `NEW_UI_IMPLEMENTATION` | Medium. Power file cleanup features are buried in secondary menus. | Create a dedicated **Storage Management Space** housing the Treemap heatmap, Burst Grouper, Large Files inspector, and Deep Clean junk cleaner. |
| **GAP-ACT-01** | Activity Center | Audit log lacks date-range filtering, text search, and export capability. | `EXISTING_BUT_INCOMPLETE` | Low. Hard to find specific historical transfers in long lists. | Add search query bar and category filter pills to Activity Center. |
| **GAP-SET-01** | Settings | Settings is a single long vertical scroll with 6 large cards, creating scrolling fatigue. | `NEW_UI_IMPLEMENTATION` | Low. Difficult to quickly jump to specific privacy, daemon, or transfer options. | Group into scannable subpages: General, Appearance, Navigation, Devices & Trust, Transfers, Sync & Backup, Storage, Privacy & Permissions. |

---

## 3. Component Duplication Inventory

The audit isolated 8 duplicate or redundant component pairs in `design_system/components/`:
1. `BatchRenameDialog` vs `BatchRenamerModal` -> Consolidate into `BatchRenameDialog`.
2. `BurnViewerModal` vs `BurnerViewerModal` -> Consolidate into `BurnerViewerModal`.
3. `SplitApkInspectorSheet` vs `ApkInspectorSheet` -> Consolidate into `SplitApkInspectorSheet`.
4. `RemotePresentationClickerSheet` vs `RemotePresentationSheet` -> Consolidate into `RemotePresentationClickerSheet`.
5. `StorageCleanerSheet` vs `DeepCleanSheet` -> Consolidate into `DeepCleanSheet`.
6. `PdfSuiteSheet` vs `IlovepdfSuiteSheet` -> Consolidate into `IlovepdfSuiteSheet`.
7. `SmartPhotoCleanerSheet` vs `SimilarPhotoGrouperSheet` -> Consolidate into `SimilarPhotoGrouperSheet`.
8. `DuplicateDiffSheet` vs `FileHashDiffSheet` vs `VisualDiffComparatorSheet` -> Consolidate into `VisualDiffComparatorSheet`.
