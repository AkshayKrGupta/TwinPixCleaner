# Frost Design System & Brand Language
> **Version 1.0.0** • *Unified macOS Design Language for Native Utility & Productivity Apps*

The **Frost Design System** is a modern macOS-native design framework tailored for premium, high-performance desktop utility apps. It merges Apple's **liquid glassmorphism** (materials, translucency, vibrancy) with **intelligent dynamic accent gradients**, high-contrast typography, and tactile micro-interactions.

---

## 🎨 1. Color Palette & Dynamic Theming

Frost apps dynamically harmonize with the user's macOS environment by calculating vibrant gradient ramps directly from `NSColor.controlAccentColor`.

```
                    ┌──────────────────────────────┐
                    │   macOS System Accent Color  │
                    └──────────────┬───────────────┘
                                   │
                     HSB Extraction & Hue Shift (+28°)
                                   │
              ┌────────────────────┴────────────────────┐
              ▼                                         ▼
      [ Brand Primary ]                         [ Brand Alt ]
   Hue: h, Sat: max(s, 0.35)             Hue: (h + 28°), Sat: (s - 0.08)
```

### 1.1 Dynamic Accent Gradient Tokens
| Token | Fallback Hex | Visual Role | Formula / Description |
| :--- | :--- | :--- | :--- |
| **`FrostTheme.Colors.brand`** | `#6366F1` (Indigo) | Primary interactive actions, prominent icons, badges | `accentStops.0` derived from system accent |
| **`FrostTheme.Colors.brandAlt`** | `#A855F7` (Purple) | Secondary gradient stops, sparkles, AI/ML accents | `accentStops.1` (+28° hue shift stop) |
| **`FrostTheme.accentGradient`** | Linear: `#6366F1` ➔ `#A855F7` | Hero buttons, selection rings, branding titles | `LinearGradient(leading ➔ trailing)` |

### 1.2 Surface & Canvas Gradients
Frost apps use deep multi-stop background gradients under liquid glass materials instead of flat monochrome backgrounds:

* **Light Mode Canvas**:
  * Gradient: `#E8EAF6` (soft periwinkle) ➔ `#F5F7FA` (ice mist)
  * Vector: `startPoint: .topLeading, endPoint: .bottomTrailing`
* **Dark Mode Canvas**:
  * Gradient: `#141724` (deep obsidian navy) ➔ `#1C1F2E` (midnight slate)
  * Vector: `startPoint: .topLeading, endPoint: .bottomTrailing`

### 1.3 Semantic Colors
| Token | Light Color | Dark Color | Usage |
| :--- | :--- | :--- | :--- |
| **`FrostTheme.Colors.success`** | `Color.green` (`#34C759`) | `Color.green` (`#30D158`) | Completed states, undo checks, reclaim stats |
| **`FrostTheme.Colors.warning`** | `Color.orange` (`#FF9500`) | `Color.orange` (`#FF9F0A`) | Skipped/unreadable notices, permission alerts |
| **`FrostTheme.Colors.destructive`**| `Color.red` (`#FF3B30`) | `Color.red` (`#FF453A`) | Delete, trash, purge actions |

---

## 🧊 2. Materials, Elevation & Glassmorphism

Frost relies on macOS **NSVisualEffectView / SwiftUI Materials** combined with subtle inner specular strokes and dual-mode shadows.

### 2.1 Frost Card Specification (`.frostCard()`)
Cards float above the canvas background with depth and tactile presence:

```swift
// Card Configuration
.background(.ultraThinMaterial)
.cornerRadius(20)
.shadow(
    color: colorScheme == .dark ? .black.opacity(0.3) : .black.opacity(0.06),
    radius: 16,
    y: 6
)
.overlay(
    RoundedRectangle(cornerRadius: 20)
        .strokeBorder(
            colorScheme == .dark ? .white.opacity(0.1) : .white.opacity(0.25),
            lineWidth: 1
        )
)
```

### 2.2 Material Layering Hierarchy
1. **Window Base (Layer 0)**: `FrostTheme.backgroundGradient` (Canvas)
2. **Standard Containers (Layer 1)**: `.ultraThinMaterial` (Cards, List rows, Toolbar bars)
3. **Floating Overlays & Badges (Layer 2)**: `.ultraThickMaterial` (Floating toasts, quick look overlays, tooltips)

---

## ✍️ 3. Typography & Text Hierarchy

Typography adheres to Apple’s San Francisco system font with rounded accents for branding and tabular data precision.

```
Hero Title    : 36pt • Bold     • Rounded   (TwinPixCleaner / App Names)
View Header   : 22pt • Semibold • Standard  (Screen titles, dialog titles)
Section Title : 15pt • Semibold • Standard  (Group headers, card titles)
Body Text     : 13pt • Regular  • Standard  (Main interface content)
Subheadline   : 12pt • Medium   • Standard  (Row primary text, button labels)
Secondary/Path: 11pt • Regular  • Standard  (Paths, metadata, helper copy)
Caption / Tag : 10pt • Medium   • Standard  (Badges, micro-stats, footer copyright)
```

### 3.1 Truncation & Path Display Rules
* Always use **middle truncation** for directory paths and asset identifiers:
  ```swift
  Text(url.path)
      .lineLimit(1)
      .truncationMode(.middle)
  ```
* Accompany truncated paths with native hover tooltips:
  ```swift
  .help(url.path)
  ```
* Enable text selection on inspector detail views:
  ```swift
  .textSelection(.enabled)
  ```

---

## 🔘 4. Component Library

### 4.1 Buttons

#### A. Primary Accent Button (`.frostPrimary`)
* **Shape**: Capsule
* **Fill**: `FrostTheme.accentGradient`
* **Text**: `#FFFFFF`, `.headline` or `.system(size: 13, weight: .medium)`
* **Shadow**: `color: .black.opacity(0.15), radius: 8, y: 4` (Pressed: `radius: 4, y: 2`)
* **Animation**: `.scaleEffect(isPressed ? 0.98 : 1.0)` with `.easeOut(duration: 0.2)`

#### B. Secondary Glass Button (`.frostSecondary`)
* **Shape**: Capsule
* **Fill**: `.ultraThinMaterial`
* **Stroke**: `Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 1)`
* **Text**: `Color.primary`

#### C. Floating Toast (`undoToast`)
* **Shape**: Capsule
* **Material**: `.ultraThickMaterial` with `.environment(\.colorScheme, .dark)`
* **Shadow**: `color: .black.opacity(0.3), radius: 8, y: 2`
* **Transition**: `.move(edge: .bottom).combined(with: .opacity)`

---

### 4.2 Interactive Grid Cards (`DuplicateItemView` Pattern)
* **Default State**:
  * Dimensions: Adaptive min `200pt`
  * Material: `.ultraThinMaterial`, `cornerRadius: 16`
  * Specular stroke: `RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.2), lineWidth: 0.5)`
  * Shadow: `color: .black.opacity(0.08), radius: 3, y: 1`
* **Selected State**:
  * Scale: `1.02` with `.spring(response: 0.3, dampingFraction: 0.7)`
  * Highlight Stroke: `RoundedRectangle(cornerRadius: 16).strokeBorder(FrostTheme.accentGradient, lineWidth: 2)`
  * Shadow: `color: Color.accentColor.opacity(0.3), radius: 8, y: 4`
  * Background: `Color.accentColor.opacity(0.1)`

---

### 4.3 Modal Sheets & Dialogs
All modal sheets must follow **standard flexible sizing** so macOS windows can be resized smoothly across various display densities:

```swift
.frame(
    minWidth: 720,
    idealWidth: 820,
    maxWidth: 1200,
    minHeight: 520,
    idealHeight: 640,
    maxHeight: 900
)
.frostBackground()
```

---

## ⌨️ 5. Keyboard & Interaction Ergonomics

Every app in the Frost family must honor power-user keyboard standards:

| Shortcut | Action | Scope |
| :--- | :--- | :--- |
| **`⌘N`** | New Scan / New Session | Global window command |
| **`⌘Z`** | Undo Batch / Restore Last Trashed Action | Global window command |
| **`Spacebar`** | Toggle Full-Resolution Quick Look Preview | Focused card / list item |
| **`Delete` / `⌫`** | Delete / Trash Selected Items | Results list / table |
| **`Esc`** | Dismiss Modal Sheet / Overlay | Active sheet |
| **`⌘W`** | Close Window | Standard window |
| **`⌘,`** | Open Preferences / Settings | Standard menu |

---

## ♿ 6. Accessibility & Motion Guidelines

1. **Reduce Motion Compliance**:
   * Wrap pulsing animations, spring bounces, and scale transforms with:
     ```swift
     @Environment(\.accessibilityReduceMotion) private var reduceMotion
     .animation(reduceMotion ? nil : .spring(...))
     ```
2. **Accessibility Traits & Labels**:
   * Decorative icons must be hidden: `.accessibilityHidden(true)`
   * Progress views must expose formatted values: `.accessibilityValue("\(percentage)%")`
   * Selectable items must declare `.isSelected` traits:
     ```swift
     .accessibilityAddTraits(isSelected ? .isSelected : [])
     ```
3. **Contrast Guarantee**:
   * Secondary text must never drop below a `4.5:1` contrast ratio against materials.

---

## 📁 7. Reusable Code Structure

To adopt this design system in a new app, share the following standard architecture:

```text
Sources/YourApp/
├── UI/
│   ├── FrostTheme.swift          # Core tokens, gradients, modifiers, button styles
│   ├── Theme.swift               # Light/Dark/System appearance toggle
│   ├── AppIconLoader.swift       # Bundle & asset runtime icon resolver
│   ├── Components/
│   │   ├── FrostCard.swift       # Reusable card container
│   │   ├── FloatingToast.swift   # Undo / completion notifications
│   │   └── QuickLookCoordinator. # Native Spacebar Quick Look engine
```
