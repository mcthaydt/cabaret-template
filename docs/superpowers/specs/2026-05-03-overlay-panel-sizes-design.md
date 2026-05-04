# Task E — Consistent Overlay Panel Sizes (640×520)

## Problem

The 11 overlay scenes use 6 different `custom_minimum_size` values, ranging from 400×320 (Localization) to 860×620 (Input Rebinding). There is no centralized size constant. `BaseSettingsSimpleOverlay` has a `MIN_PANEL_HEIGHT := 200.0` that only guards the Y-axis for 4 of the 11 overlays.

## Goal

All 11 overlay panels use a single, centralized `OVERLAY_PANEL_SIZE := Vector2(640.0, 520.0)` constant defined on `BaseOverlay`.

## Scope

All 11 overlay scenes are in scope:

| Overlay | Current Size | Target |
|---------|-------------|--------|
| Display Settings | 640×520 | Already matches |
| Gamepad Settings | 640×540 | 640×520 |
| Keyboard/Mouse Settings | 620×460 | 640×520 |
| Audio Settings | 520×440 | 640×520 |
| VFX Settings | 520×360 | 640×520 |
| Localization Settings | 400×320 | 640×520 |
| Touchscreen Settings | 560×520 | 640×520 |
| Input Rebinding | 860×620 | 640×520 |
| Edit Touch Controls | 560×260 | 640×520 |
| Input Profile Selector | 620×500 | 640×520 |
| Save/Load Menu | 760×520 | 640×520 |

## Design

### 1. Add constant to BaseOverlay

`scripts/core/ui/base/base_overlay.gd`:

```gdscript
const OVERLAY_PANEL_SIZE := Vector2(640.0, 520.0)
```

This is the single source of truth. All overlays and builders reference `BaseOverlay.OVERLAY_PANEL_SIZE`.

### 2. Update BaseSettingsSimpleOverlay

`scripts/core/ui/settings/base_settings_simple_overlay.gd`:

- Remove `MIN_PANEL_HEIGHT` constant (superseded by `OVERLAY_PANEL_SIZE`)
- Change `_apply_size_guards()` to set `custom_minimum_size = BaseOverlay.OVERLAY_PANEL_SIZE` on the **Panel** node (`_main_panel`), not on the VBox content which should still shrinkwrap
- Keep `OVERLAY_SCREEN_MARGIN` — it controls CenterContainer margin, not panel size

### 3. Update .tscn files

**Pattern A (Simple overlays: Audio, Display, Localization, VFX):**
- CenterContainer offsets → ±320/±260 (half of 640×520)
- VBox `custom_minimum_size` → `(640, 520)`

**Pattern B (Complex overlays: Gamepad, Keyboard/Mouse, Touchscreen, Input Rebinding, Edit Touch Controls, Input Profile Selector, Save/Load):**
- MainPanelMotionHost `custom_minimum_size` → `(640, 520)`
- CenterContainer already uses full-rect anchors, no offset changes

### 4. Builder updates

Any builder that emits overlay scene nodes references `BaseOverlay.OVERLAY_PANEL_SIZE` instead of hardcoded dimensions. After builder changes, run:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . --headless --script tools/rebuild_scenes.gd
```

### 5. Testing

- Style enforcement test: assert `BaseOverlay.OVERLAY_PANEL_SIZE == Vector2(640, 520)`
- Integration test: load each overlay scene, find its panel/motion-host node, assert `custom_minimum_size` matches the constant

### Files touched

- `scripts/core/ui/base/base_overlay.gd` — add `OVERLAY_PANEL_SIZE`
- `scripts/core/ui/settings/base_settings_simple_overlay.gd` — consume constant, remove `MIN_PANEL_HEIGHT`
- Builder scripts that set overlay dimensions
- 11 `.tscn` overlay scene files (via rebuild)
- New test file for overlay sizing assertions

## Out of scope

- Changing the overlay background dim color or animation
- Modifying overlay content/layout beyond minimum size
- Adding responsive/adaptive sizing for different viewport sizes