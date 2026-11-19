# PeerLink — Dedicated Workspaces Redesign Specification

**Document Version:** 1.0.0  
**Phase:** 13.0 Complete Product-Wide UX Redesign  

---

## 1. Overview of the 9 Dedicated Workspaces

PeerLink organizes its capabilities into 9 dedicated, professional workspaces accessible from the **Spaces Directory**:

1. **File Manager Space:** Full filesystem navigation, internal storage vs vault, breadcrumbs, search, multi-select, and file operations.
2. **Media Gallery Space:** Chronological photo & video timeline, date grouping, albums, dedicated pinch-to-zoom viewer, and non-destructive image editor.
3. **Player Hub Space:** Video player with gesture controls, persistent audio player with playback queue, 0.5x-3.0x speed boost, 5-band EQ, and sleep fade.
4. **Share Center Space:** Primary Send & Receive actions, nearby device radar, live transfer queue, pairing, and secondary turbochargers.
5. **Device Center Space:** Discovered, pairing, and trusted device management, 30-digit safety numbers, trust revocation, and diagnostics.
6. **Document Studio Space:** 3-step scanner workflow (Capture -> Filter/Reorder -> OCR/PDF), PDF document viewer with annotations.
7. **PDF & Conversion Studio Space:** Categorized conversion wizard (Convert to PDF, Convert from PDF, Organize, Security) covering 23+ offline engines.
8. **Sync & Backup Space:** Decentralized folder synchronization spaces vs point-in-time Merkle backup snapshots with safe non-destructive restoration.
9. **Storage Management Space:** WinDirStat disk space treemap, similar photo & burst grouper, duplicate inspector, and junk cleaner.

---

## 2. Dedicated Workspace Implementation Contracts

Each Space operates with:
- **Dedicated Page Identity:** Standard AppBar with back navigation, workspace title, search icon, and contextual action buttons.
- **Internal State Isolation:** Each Space manages its own active tab, filters, and selection without bleeding state into other workspaces.
- **Independent Empty & Loading States:** Clear, domain-specific guidance when no items are present.
- **Platform Bridging:** Windows Win32 file dialogs, Android SAF, and native camera bindings are isolated cleanly within each workspace.
