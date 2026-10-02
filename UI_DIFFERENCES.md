# UI Differences — Original vs Reconstructed

## Methodology

UI reconstruction was performed via binary analysis only (no device screenshots available).
Layout and styling are inferred from UIKit class references, string constants, and
framework import patterns in the binary. Exact pixel values, colors, and spacing cannot
be confirmed without running on device.

---

## VCNextApp (Main Application)

### Navigation Bar

| Property | Original (from Info.plist/binary) | Reconstructed | Difference |
|----------|----------------------------------|---------------|------------|
| Title | "VcamNextPlus" (via BrandUI swizzle) | "VcamNextPlus" | Match |
| Style | Dark (evidence: dark UI patterns) | Dark (.configureWithOpaqueBackground) | Probable match |
| Large titles | Unknown | Yes (prefersLargeTitles) | TODO: VERIFY ON DEVICE |
| Tint color | Unknown (no color constants found) | RGB(0.1, 0.1, 0.1) | INFERRED |

### Main Screen Layout

| Property | Original | Reconstructed | Difference |
|----------|----------|---------------|------------|
| Style | UITableViewController | UITableViewController grouped | Possible difference: plain vs grouped |
| Sections | 4 (evidence from UI logic) | 4 (Account, Camera, Media, Server) | Match |
| Pull to refresh | Probable (common pattern) | Yes (UIRefreshControl) | TODO: VERIFY |
| Cell style | Unknown | UITableViewCellStyleValue1 | INFERRED |

### Login Dialog

| Property | Original | Reconstructed | Difference |
|----------|----------|---------------|------------|
| Type | UIAlertController | UIAlertController | Match |
| Style | Alert | Alert | Match |
| Fields | Username + Password | Username + Password | Match |
| Password secure | Yes (standard) | Yes (.secureTextEntry) | Match |
| Buttons | Login + Cancel | Login + Cancel | Match |

### Camera Config Screen

| Property | Original | Reconstructed | Difference |
|----------|----------|---------------|------------|
| Style | Unknown | UITableViewController grouped | INFERRED |
| Source section | Yes | Yes (Enabled, Source Type, Media Path) | Approximate |
| Color section | Yes | Yes (Enabled, R/G/B Shift, Region) | Approximate |
| Face section | Yes | Yes (Face Blur, Blur Radius) | Approximate |
| Slider controls | Possible for R/G/B values | Not implemented (shows text value) | KNOWN DIFFERENCE |
| Save button | Unknown | UIBarButtonSystemItemSave | INFERRED |

**Known gap:** The original may use sliders (UISlider) for color shift values
rather than the text-display approach in the reconstruction. Without device
screenshots, the exact control type cannot be confirmed.

---

## VCNextOverlay (SpringBoard)

### Floating Button

| Property | Original | Reconstructed | Difference |
|----------|----------|---------------|------------|
| Shape | Circular (evidence: corner radius) | Circular (layer.cornerRadius) | Match |
| Size | Unknown (no constant found) | 50x50 pt | INFERRED |
| Color | Unknown | System blue | INFERRED |
| Icon | Unknown (possibly camera SF Symbol) | "camera.fill" SF Symbol | INFERRED |
| Snap behavior | Yes (edge snapping) | Yes (nearest edge) | Match |
| Window level | UIWindowLevelAlert + N | UIWindowLevelAlert + 1 | Probable match |

### Control Panel

| Property | Original | Reconstructed | Difference |
|----------|----------|---------------|------------|
| Layout | Unknown exact layout | UIStackView vertical | INFERRED |
| Buttons | Toggle, Stream, Source, Color | Toggle, Stream, Source, Color | Match (from notification strings) |
| Status label | Yes (state display) | Yes (UILabel) | Match |
| Animation | Unknown | None implemented | POSSIBLE DIFFERENCE |
| Background | Unknown | Semi-transparent dark | INFERRED |
| Corner radius | Unknown | 12 pt | INFERRED |
| Blur effect | Possible (UIVisualEffectView) | Not implemented | POSSIBLE DIFFERENCE |

**Known gaps:**
1. Panel may use UIVisualEffectView blur background instead of solid color
2. Panel may have slide/fade animation on show/hide
3. Button styling (icons, colors, size) are approximations
4. Panel dismissal behavior (tap outside, swipe) is inferred

---

## Assets

| Asset | Original | Reconstructed | Status |
|-------|----------|---------------|--------|
| AppIcon.png | Extracted from .deb | Not reproduced | MUST COPY FROM ORIGINAL |
| AppIcon@2x.png | Extracted from .deb | Not reproduced | MUST COPY FROM ORIGINAL |
| AppIcon@3x.png | Extracted from .deb | Not reproduced | MUST COPY FROM ORIGINAL |
| BrandLogo.png | Extracted from .deb | Not reproduced | MUST COPY FROM ORIGINAL |

---

## Summary of Remaining UI Differences

### Critical (affects functionality)
- None identified

### Visual (affects appearance)
1. Color shift controls may need sliders instead of text display
2. Control panel may need blur background (UIVisualEffectView)
3. Control panel may need show/hide animation
4. Exact floating button size, color, and icon need device verification
5. Navigation bar tint color needs device verification

### Cosmetic (minor)
1. Exact font sizes and weights throughout app UI
2. Cell heights, content insets, separator styles
3. Status bar appearance handling
4. Exact corner radius values on panel/buttons
5. Shadow/border effects on floating window

### Action Items
- [ ] Run on device, take screenshots, compare side-by-side
- [ ] Adjust floating button appearance to match
- [ ] Verify and fix control panel styling
- [ ] Add animations if present in original
- [ ] Test table view style (plain vs grouped)
