# PeerLink — Responsive Layout & Viewport Specification

**Document Version:** 1.0.0  
**Phase:** 13.0 Complete Product-Wide UX Redesign  

---

## 1. Breakpoints & Window Size Classes

Following official Android and desktop design guidelines, PeerLink layout rules adapt across 3 primary window size classes:

```
+-------------------------------------------------------------------------------+
| Compact (<600dp)     | Medium (600-840dp)          | Expanded (>840dp)         |
| Portrait Phones      | Foldables, Small Tablets    | Desktops, Large Tablets   |
| Bottom Nav (3 items) | Navigation Rail             | Persistent Sidebar Drawer |
| 1 Column Cards       | 2 Column Grid               | Dual-Pane / Multi-Pane    |
| Full-width Modals    | Floating Dialogs (480dp max)| Centered Windows / Panes  |
+-------------------------------------------------------------------------------+
```

---

## 2. Space Layout Adaptations

### 2.1 File Manager Space
- **Compact:** Single-column file list with breadcrumb header. Bottom bar holds active selection actions.
- **Medium / Expanded:** Dual-pane layout. Left pane: Folder tree and storage drives; Right pane: Active directory file grid or list.

### 2.2 Media Gallery Space
- **Compact:** 3-column photo grid with sticky date headers.
- **Medium:** 4-column photo grid.
- **Expanded:** 5 to 6-column photo grid with collapsible album sidebar.

### 2.3 Share Center Space
- **Compact:** Vertical stack: Send & Receive Hero, Transfer Queue, Collapsible Advanced Tools.
- **Expanded:** 2-column layout: Left column = Send/Receive & Radar; Right column = Active Transfer Queue & Diagnostic governors.

### 2.4 Document Studio & Conversion Studio
- **Compact:** Vertical wizard workflow: File Selection -> Configuration -> Output.
- **Expanded:** Side-by-side workspace: Left pane = Document page carousel / format options; Right pane = Live PDF preview & OCR text inspector.
