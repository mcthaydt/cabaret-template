# Settings UI: Inline Groups & Style Guards

**Date:** 2026-05-01
**Status:** Approved

## Overview

Two improvements to the settings UI builder system:

1. **Inline groups** — related controls (e.g. a volume slider and its mute toggle) share a single row instead of each occupying a full line
2. **Style guards** — settings overlay panels are bounded by the viewport so they never extend off-screen, with scroll when content is taller than the available height

## Part 1: Inline Groups

### API

Two new methods added to `U_SettingsTabBuilder` (`scripts/core/ui/helpers/u_settings_tab_builder.gd`):

```gdscript
func begin_inline_group(group_name: String = "") -> U_SettingsTabBuilder
func end_inline_group() -> U_SettingsTabBuilder
```

While a group is active, calls to `add_slider()`, `add_toggle()`, and `add_dropdown()` append into a single shared `HBoxContainer` row rather than each creating their own. The group is closed by `end_inline_group()`.

### Internal state

Two new fields on `U_SettingsTabBuilder`:

- `_inline_group_row: HBoxContainer` — the shared row; `null` when no group is active
- `_inline_group_item_count: int` — count of items added to the current group

### Label sizing inside groups

- First item in a group: label keeps `custom_minimum_size = Vector2(180, 0)` (same as standalone rows)
- Subsequent items: label gets `custom_minimum_size = Vector2(0, 0)` (compact — takes only its text width)

### Changes to `add_*` methods

Each of `add_slider()`, `add_toggle()`, `add_dropdown()` is modified to:
1. Check `_inline_group_row != null`
2. If active: skip `_add_row()`, use `_inline_group_row` as the container, apply compact label sizing for non-first items, increment `_inline_group_item_count`
3. If not active: behaviour unchanged

### Tab builder updates

**`U_AudioTabBuilder`** (`scripts/core/ui/helpers/u_audio_tab_builder.gd`):
Four inline groups — one per channel:
```gdscript
begin_inline_group("MasterVolume")
add_slider(...)  # MasterVolumeSlider
add_toggle(...)  # MasterMuteToggle
end_inline_group()
# repeated for Music, SFX, Ambient
```
The standalone `SpatialAudioToggle` stays on its own row.

**`U_DisplayTabBuilder`** (`scripts/core/ui/helpers/u_display_tab_builder.gd`):
Four inline groups:
- `WindowSizeOption` + `WindowModeOption`
- `VSyncToggle` + `QualityPresetOption`
- `PostProcessingToggle` + `PostProcessPresetOption`
- `ColorBlindModeOption` + `HighContrastToggle`

### Impact on `UI_AudioSettingsTab`

**`_capture_control_references()`** (`scripts/core/ui/settings/ui_audio_settings_tab.gd`):
No code change needed. The method finds rows via `.get_parent()` on the slider:
```gdscript
_master_row = _find_child_by_name(self, "MasterVolumeSlider").get_parent() as HBoxContainer
```
After inlining, the slider's parent is the shared row (which also contains the mute toggle). `_master_row` therefore correctly references the combined row.

**`_update_mute_visuals()`**: Row dimming (`modulate.a = 0.4`) will now dim the mute checkbox alongside the slider. This is acceptable — the entire channel row fades when muted.

**`_configure_focus_neighbors()`**: No change. The grid focus tracks focusable controls directly, not their row containers.

### Impact on `UI_DisplaySettingsTab`

The display tab captures its control references by name via `find_child()` calls. Inline grouping does not change control names, so reference capture is unaffected. `ui_display_settings_tab.gd` must be read during implementation to determine whether it has a `_configure_focus_neighbors()` method; if it does, it should be updated so paired controls get horizontal neighbours pointing to each other. If not, one should be added.

---

## Part 2: Style Guards

### Problem

Each settings overlay (`AudioSettingsOverlay`, `DisplaySettingsOverlay`, `LocalizationSettingsOverlay`) uses a `CenterContainer` with hardcoded pixel offsets:
- Audio: ±260 × ±220 (520 × 440 panel)
- Display: ±320 × ±260 (640 × 520 panel)
- Localization: ±200 × ±160 (400 × 320 panel)

On viewports smaller than these sizes the panel overflows. The tab content inside has no scroll, so action buttons can become unreachable.

### Solution

Runtime constraints applied in `BaseSettingsSimpleOverlay` (`scripts/core/ui/settings/base_settings_simple_overlay.gd`) — no `.tscn` edits required.

#### Constant

```gdscript
const OVERLAY_SCREEN_MARGIN := 40.0
const MIN_PANEL_HEIGHT := 200.0
```

#### Updated `_on_panel_ready()` call order

```gdscript
func _on_panel_ready() -> void:
    _setup_builder()
    if _builder != null:
        _builder.build()
    _wrap_content_in_scroll()   # new — must run after build() so tab children exist
    _apply_size_guards()        # new — must run after wrap so ScrollContainer is in place
    _apply_overlay_theme()
    play_enter_animation()
```

Also connect in `_on_panel_ready()`:
```gdscript
get_viewport().size_changed.connect(_apply_size_guards)
```

#### `_wrap_content_in_scroll()`

Called once in `_on_panel_ready()`, after `_builder.build()`:

1. Collects all existing children of `_main_panel_content` (the VBox)
2. Creates a new `ScrollContainer` with `SIZE_EXPAND_FILL` on both axes and `follow_focus = true`
3. Adds the `ScrollContainer` to `_main_panel_content`
4. Reparents all collected children into the `ScrollContainer`

This wraps tab content in a scroll without modifying any `.tscn` file.

#### `_apply_size_guards()`

Called in `_on_panel_ready()` and reconnected on `get_viewport().size_changed`:

1. **Viewport-bound the CenterContainer**: converts it from hardcoded offsets to `PRESET_FULL_RECT` with `OVERLAY_SCREEN_MARGIN` on all four sides, so its available area is always `viewport - 2×margin`
2. **Center the Panel**: sets `Panel.size_flags_horizontal = SIZE_SHRINK_CENTER` and `Panel.size_flags_vertical = SIZE_SHRINK_CENTER` so it centres itself within the now-viewport-bounded CenterContainer
3. **Cap panel height**: sets `_main_panel_content.custom_maximum_size.y = max(MIN_PANEL_HEIGHT, viewport_height - OVERLAY_SCREEN_MARGIN * 2)` — Godot 4's `custom_maximum_size` takes precedence over `custom_minimum_size`, so this caps the panel to the viewport while the existing per-overlay `custom_minimum_size` values in the `.tscn` remain as the preferred floor

The ScrollContainer from step above fills the bounded VBox height. Tab content scrolls when it exceeds the capped height. `follow_focus = true` keeps the focused control visible during keyboard navigation.

### Node path assumptions

`BaseSettingsSimpleOverlay` assumes:
- `$CenterContainer` — the centering container
- `$CenterContainer/Panel` — the panel (already in `_main_panel`)
- `$CenterContainer/Panel/VBox` — the content VBox (already in `_main_panel_content`)

All three overlay scenes match this structure.

---

## Files Changed

| File | Change |
|------|--------|
| `scripts/core/ui/helpers/u_settings_tab_builder.gd` | Add `begin_inline_group()`, `end_inline_group()`, modify `add_*` methods |
| `scripts/core/ui/helpers/u_audio_tab_builder.gd` | Wrap 4 slider+mute pairs in inline groups |
| `scripts/core/ui/helpers/u_display_tab_builder.gd` | Wrap 4 control pairs in inline groups |
| `scripts/core/ui/settings/base_settings_simple_overlay.gd` | Add `_wrap_content_in_scroll()`, `_apply_size_guards()` |
| `scripts/core/ui/settings/ui_display_settings_tab.gd` | Update focus neighbour configuration for new 2-column pairs |

## Out of Scope

- `U_LocalizationTabBuilder` — only two standalone controls; no pairs to inline
- Horizontal overflow guard (B) — not selected; sliders have natural minimum widths
- Changes to any `.tscn` files — all layout changes are runtime-applied
