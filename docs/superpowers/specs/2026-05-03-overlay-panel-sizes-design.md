# Task E — Control-Style Tabbed Settings Panel

## Problem

The 7 settings overlays (Display, Audio, VFX, Localization, Gamepad, Keyboard/Mouse, Touchscreen) are separate overlay scenes, each pushed onto the overlay stack independently. This creates a disjointed user experience: switching between settings categories requires closing one overlay and opening another, with enter/exit animations each time. The overlays also use 6 different `custom_minimum_size` values with no centralized constant.

## Goal

Replace the 7 settings overlays + `UI_SettingsMenu` landing page with a single `UI_SettingsPanel` overlay that uses internal tab navigation (like Remedy's *Control*). The panel is 860×620 and uses instant-apply semantics (no Apply/Cancel buttons).

## Architecture

### Navigation flow

1. **Pause button** → Pause Menu overlay (unchanged)
2. **"Settings" on Pause Menu** → Opens `UI_SettingsPanel` overlay directly
3. **User switches tabs** within the panel — content swaps instantly, no overlay transition

The existing `UI_SettingsMenu` (category button list) is removed. The pause menu's "Settings" button now opens `UI_SettingsPanel` instead.

### Scene structure

```
UI_SettingsPanel (extends BaseOverlay)
├── OverlayBackground (ColorRect — dim)
├── CenterContainer
│   └── Panel (PanelContainer, 860×620)
│       └── VBoxContainer
│           ├── TabBar (HBoxContainer with tab buttons)
│           │   ├── Display
│           │   ├── Audio
│           │   ├── VFX
│           │   ├── Language
│           │   ├── Gamepad
│           │   ├── K/M
│           │   └── Touch
│           ├── HSeparator
│           └── ContentContainer (VBoxContainer — active tab content)
```

### Panel size

```gdscript
# On BaseOverlay (single source of truth)
const OVERLAY_PANEL_SIZE := Vector2(860.0, 620.0)
```

All 11 overlays (7 merged into tabs + 4 utility overlays) use this size constant.

### Tab pages

Each former settings overlay's *content* becomes a tab page (extending `VBoxContainer`):

| Tab | Source | What happens |
|-----|--------|-------------|
| Display | `ui_display_settings_tab.gd` | Already a `VBoxContainer`. Repurpose directly. |
| Audio | `ui_audio_settings_tab.gd` | Already a `VBoxContainer`. Repurpose directly. |
| VFX | `ui_vfx_settings_overlay.gd` | Extract builder content into a new `ui_vfx_settings_tab.gd` |
| Language | `ui_localization_settings_tab.gd` | Already a `VBoxContainer`. Repurpose directly. |
| Gamepad | `ui_gamepad_settings_overlay.gd` | Extract builder content into a new `ui_gamepad_settings_tab.gd` |
| K/M | `ui_keyboard_mouse_settings_overlay.gd` | Extract builder content into a new `ui_keyboard_mouse_settings_tab.gd` |
| Touch | `ui_touchscreen_settings_overlay.gd` | Extract builder content into a new `ui_touchscreen_settings_tab.gd` |

### Utility overlays (remain separate)

These are action-oriented, not settings pages. They stay as independent overlays pushed on top of the settings panel:

| Overlay | Opened from | Size |
|---------|-------------|------|
| Input Rebinding | Gamepad / K/M tabs | 860×620 |
| Edit Touch Controls | Touchscreen tab | 860×620 |
| Input Profile Selector | Gamepad / K/M tabs | 860×620 |
| Save/Load Menu | Pause Menu (unchanged) | 860×620 |

### Instant apply

No Apply/Cancel buttons. Each setting change dispatches directly to the appropriate manager. "Reset to defaults" is still available per-tab.

For Display and Language tabs, the existing 10-second confirmation dialogs are **preserved**. Resolution changes and language switches still require explicit confirmation before applying. All other settings (Audio, VFX, Gamepad, K/M, Touch) apply instantly.

### Focus wrapping

The tab bar is in the focus chain above the content area. Wrapping vertically within the content stays as-is. Tab buttons wrap horizontally. Gamepad D-pad left/right switches tabs.

### Tab bar accessibility

- Each tab button is focusable with proper focus neighbor setup
- The active tab button is visually distinct (theme token)
- Switching tabs preserves focus within the content area (first focusable control in the new tab gets focus)

## Implementation details

### 1. Add OVERLAY_PANEL_SIZE to BaseOverlay

`scripts/core/ui/base/base_overlay.gd`:

```gdscript
const OVERLAY_PANEL_SIZE := Vector2(860.0, 620.0)
```

### 2. Create UI_SettingsPanel

New script: `scripts/core/ui/settings/ui_settings_panel.gd`
- Extends `BaseOverlay`
- Contains tab bar and content container
- Manages tab switching (show/hide content pages)
- Instantiates tab page scripts as children of `ContentContainer`
- Handles gamepad/keyboard tab navigation

### 3. Create tab pages

New scripts extracted from overlay scripts:

| New file | Source |
|----------|--------|
| `ui_vfx_settings_tab.gd` | Extract from `ui_vfx_settings_overlay.gd` |
| `ui_gamepad_settings_tab.gd` | Extract from `ui_gamepad_settings_overlay.gd` |
| `ui_keyboard_mouse_settings_tab.gd` | Extract from `ui_keyboard_mouse_settings_overlay.gd` |
| `ui_touchscreen_settings_tab.gd` | Extract from `ui_touchscreen_settings_overlay.gd` |

Existing tab scripts are reused directly:
- `ui_display_settings_tab.gd`
- `ui_audio_settings_tab.gd`
- `ui_localization_settings_tab.gd`

### 4. Remove obsolete overlays and menu

**Deleted scenes and scripts:**
- `ui_settings_menu.gd` / `.tscn` — replaced by `UI_SettingsPanel`
- `ui_display_settings_overlay.gd` / `.tscn` — absorbed into tab
- `ui_audio_settings_overlay.gd` / `.tscn` — absorbed into tab
- `ui_localization_settings_overlay.gd` / `.tscn` — absorbed into tab
- `ui_vfx_settings_overlay.gd` / `.tscn` — content moves to tab (delete overlay)
- `ui_gamepad_settings_overlay.gd` / `.tscn` — content moves to tab (delete overlay)
- `ui_keyboard_mouse_settings_overlay.gd` / `.tscn` — content moves to tab (delete overlay)
- `ui_touchscreen_settings_overlay.gd` / `.tscn` — content moves to tab (delete overlay)

**Remaining overlays (resized to 860×620, otherwise unchanged):**
- `ui_input_rebinding_overlay.gd` / `.tscn`
- `ui_edit_touch_controls_overlay.gd` / `.tscn`
- `ui_input_profile_selector.gd` / `.tscn`
- `ui_save_load_menu.gd` / `.tscn`

### 5. Update U_UIRegistry and navigation

- Replace `settings_menu_overlay` definition with `settings_panel` pointing to the new `UI_SettingsPanel` scene
- Remove overlay definitions for the 7 absorbed settings overlays
- Update `allowed_parents` for utility overlays to include `settings_panel`
- Update pause menu to reference `settings_panel` instead of `settings_menu_overlay`
- Remove `BaseSettingsSimpleOverlay` (no longer needed)

### 6. Update BaseSettingsSimpleOverlay removal

Since all simple overlay wrappers are removed:
- Delete `scripts/core/ui/settings/base_settings_simple_overlay.gd`
- Move `OVERLAY_SCREEN_MARGIN` constant to `BaseOverlay` if still needed by remaining overlays

### 7. Resize remaining utility overlays to 860×620

Update `.tscn` files for the 4 remaining overlays:
- Input Rebinding: 860→860, 620→620 (already matches)
- Edit Touch Controls: 560×260 → 860×620
- Input Profile Selector: 620×500 → 860×620
- Save/Load Menu: 760×520 → 860×620

### 8. Builder updates

- `U_SettingsTabBuilder` stays (used by tab pages)
- Add tab page builder pattern: each tab's `_setup_builder()` runs when the tab is first shown (lazy initialization)
- Any builder referencing overlay dimensions uses `BaseOverlay.OVERLAY_PANEL_SIZE`

### 9. Testing

- Style enforcement test: `BaseOverlay.OVERLAY_PANEL_SIZE == Vector2(860, 620)`
- Integration test: `UI_SettingsPanel` loads, tab switching shows/hides content correctly
- Integration test: each tab page instantiates without errors
- Integration test: utility overlays still open from within the settings panel
- Focus test: tab bar focus navigation works with gamepad/keyboard
- Update existing overlay tests to test tab pages instead of separate overlays
- Remove tests for deleted overlay scripts

## Phased approach

This is a significant refactor. Suggested order:

1. **Phase 1**: Add `OVERLAY_PANEL_SIZE` constant, resize remaining utility overlays to 860×620
2. **Phase 2**: Create `UI_SettingsPanel` with tab bar and content switching
3. **Phase 3**: Create tab page scripts (extract content from overlays)
4. **Phase 4**: Wire up navigation, registry, and pause menu
5. **Phase 5**: Remove obsolete overlays, `BaseSettingsSimpleOverlay`, and old tests

## Files touched (summary)

### New
- `scripts/core/ui/settings/ui_settings_panel.gd`
- `scenes/core/ui/settings/ui_settings_panel.tscn` (via builder)
- `scripts/core/ui/settings/ui_vfx_settings_tab.gd`
- `scripts/core/ui/settings/ui_gamepad_settings_tab.gd`
- `scripts/core/ui/settings/ui_keyboard_mouse_settings_tab.gd`
- `scripts/core/ui/settings/ui_touchscreen_settings_tab.gd`
- Test files for new panel and tabs

### Modified
- `scripts/core/ui/base/base_overlay.gd` — add `OVERLAY_PANEL_SIZE`
- `scripts/core/ui/utils/u_ui_registry.gd` — update screen definitions
- `resources/core/ui_screens/*.tres` — update/add definitions
- 4 utility overlay `.tscn` files — resize to 860×620
- Pause menu script — reference `settings_panel` instead of `settings_menu_overlay`
- Any scripts referencing absorbed overlays

### Deleted
- `scripts/core/ui/settings/base_settings_simple_overlay.gd`
- `scripts/core/ui/menus/ui_settings_menu.gd` + `.tscn`
- 7 settings overlay scripts + scenes (Display, Audio, Localization, VFX, Gamepad, K/M, Touchscreen)
- Related test files for deleted overlays
- `.tres` definitions for deleted overlays

## Out of scope

- Changing the overlay background dim color or animation
- Adding responsive/adaptive sizing for different viewport sizes
- Modifying pause menu layout or options (only the "Settings" button target changes)
- Changes to Save/Load menu beyond resizing