# PeerLink — Global Design System Specification

**Document Version:** 1.0.0  
**Phase:** 13.0 Complete Product-Wide UX Redesign  
**Design Principles:** Minimal, Professional, Calm, Clean, Practical, Consistent, Responsive, Accessible.  
**Strict Prohibitions:** NO neon colors, NO glowing effects, NO excessive gradients, NO glassmorphism, NO decorative blur, NO animated background noise, NO artificial dashboard vanity charts, NO oversized decorative illustrations.  

---

## 1. Color Palette & Semantic Tokens

PeerLink uses a restrained palette anchored by neutral slate surfaces, high-contrast dark typography, and a single controlled cobalt blue accent (`#2563EB`). All interactive states are communicated through shape, typography, iconography, and text labels—never through color alone.

### 1.1 Semantic Color Tokens

| Token Name | Light Mode Value | Dark Mode Value | Usage / Semantic Meaning |
| :--- | :--- | :--- | :--- |
| `color-primary` | `#2563EB` (Cobalt 600) | `#3B82F6` (Cobalt 500) | Primary action buttons, active navigation indicators, key accents. |
| `color-primary-hover` | `#1D4ED8` (Cobalt 700) | `#60A5FA` (Cobalt 400) | Interactive hover state for primary controls. |
| `color-background` | `#F8FAFC` (Slate 50) | `#0B0F19` (Dark 950) | Global application background canvas. |
| `color-surface` | `#FFFFFF` (Pure White) | `#131B2E` (Dark 900) | Primary card, sheet, and modal container surface. |
| `color-surface-elevated`| `#FFFFFF` (Pure White) | `#1E293B` (Slate 800) | Floating trays, toolbars, popups, and dropdown menus. |
| `color-border` | `#E2E8F0` (Slate 200) | `#334155` (Slate 700) | Card outlines, dividers, and structural container boundaries. |
| `color-border-subtle` | `#F1F5F9` (Slate 100) | `#1E293B` (Slate 800) | Internal list dividers and secondary separators. |
| `color-text-primary` | `#0F172A` (Slate 900) | `#F8FAFC` (Slate 50) | Primary headlines, file titles, and high-emphasis body text. |
| `color-text-secondary` | `#475569` (Slate 600) | `#94A3B8` (Slate 400) | Supporting descriptions, metadata, file sizes, and timestamps. |
| `color-text-disabled` | `#94A3B8` (Slate 400) | `#64748B` (Slate 500) | Inactive controls, placeholder text, and unavailable actions. |
| `color-success` | `#15803D` (Green 700) | `#22C55E` (Green 500) | Completed transfers, verified checksums, and trusted peers. |
| `color-success-surface`| `#F0FDF4` (Green 50) | `#052E16` (Green 950) | Success badge backgrounds and verified notification banners. |
| `color-warning` | `#B45309` (Amber 700) | `#F59E0B` (Amber 500) | Sync causal conflicts, mass-change safety holds, pending transfers. |
| `color-warning-surface`| `#FEF3C7` (Amber 100) | `#451A03` (Amber 950) | Conflict warning containers and attention banners. |
| `color-error` | `#B91C1C` (Red 700) | `#EF4444` (Red 500) | Transfer failures, malware trip events, and corrupted files. |
| `color-error-surface` | `#FEF2F2` (Red 50) | `#450A0A` (Red 950) | Quarantined item banners and destructive confirmation modals. |
| `color-focus` | `#2563EB` (Cobalt 600) | `#60A5FA` (Cobalt 400) | 2dp solid focus ring for keyboard navigation. |

---

## 2. Typography Scale

PeerLink uses system sans-serif typography (`Inter`, `Segoe UI`, or Roboto) with strict mathematical proportions and minimum 11sp sizes for accessibility.

| Typographic Role | Font Size | Font Weight | Line Height | Usage |
| :--- | :--- | :--- | :--- | :--- |
| **Display** | 24sp | Bold (700) | 32dp | Hero section greetings and major screen titles. |
| **Page Title** | 18sp | Bold (700) | 24dp | Workspace header titles and top app bar labels. |
| **Section Title** | 15sp | SemiBold (600) | 20dp | Card group headers and studio tool category titles. |
| **Subsection Title**| 13sp | SemiBold (600) | 18dp | List group headers and secondary dialog titles. |
| **Body Primary** | 13sp | Medium (500) | 18dp | File names, peer names, and primary form labels. |
| **Body Secondary** | 12sp | Regular (400) | 16dp | Explanatory descriptions and instructions. |
| **Caption / Metadata**| 11sp | Regular (400) | 14dp | File sizes, timestamps, MIME types, and speeds. |
| **Button Label** | 13sp | SemiBold (600) | 16dp | Action button text. |
| **Numeric / Code** | 12sp | Medium (500) (Mono)| 16dp | Checksums (SHA-256), IP addresses, and safety numbers. |

---

## 3. Spacing, Elevation & Corner Radii

### 3.1 4dp Spacing Scale
- `space-2` = 2dp (Micro adjustments)
- `space-4` = 4dp (Badge padding, icon-text gap)
- `space-8` = 8dp (Grid spacing, chip padding)
- `space-12` = 12dp (Card internal padding, list-item vertical padding)
- `space-16` = 16dp (Screen margins, major section padding)
- `space-20` = 20dp (Modal dialog padding)
- `space-24` = 24dp (Screen section separation)

### 3.2 Corner Radii
- `radius-sm` = 6dp (Badges, tags, small utility buttons)
- `radius-md` = 10dp (Primary buttons, text inputs, list tiles)
- `radius-lg` = 14dp (Cards, dialog containers, hero cards)
- `radius-full` = 999dp (Pills, circular avatar badges)

### 3.3 Elevation & Shadows
- **No heavy diffuse drop shadows.**
- Elevation 0: Flat with 1dp border (`#E2E8F0`).
- Elevation 1: 1dp border + subtle `BoxShadow(color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 1))`.
- Floating sheets: 1dp top border + subtle upward shadow `blurRadius: 12, offset: Offset(0, -2)`.

---

## 4. Component Standards

1. **Touch Targets:**
   On Android, all interactive buttons, icons, and list items have a minimum interactive touch area of **48x48dp** (`VisualDensity.standard` with `minimumSize: Size(48, 48)`).
2. **Buttons:**
   - **Primary Action:** Solid Cobalt (`#2563EB`) background, white text, 10dp radius.
   - **Secondary Action:** Outlined with 1dp `#E2E8F0`, slate text (`#334155`), white surface.
   - **Destructive Action:** Solid Crimson (`#B91C1C`) or Red outline with explicit two-step confirmation dialog.
3. **Progress Indicators:**
   Always report deterministic progress when byte counts are known. Never use indefinite spinners when definite chunk/byte data is streaming.
4. **Empty States:**
   Every empty state must contain:
   - A clean 40x40dp neutral icon.
   - A clear explanation of why the view is empty.
   - A primary actionable button (e.g. "Select Files to Send", "Scan First Document", "Pair Device").
