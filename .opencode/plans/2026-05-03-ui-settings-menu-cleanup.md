# UI Settings & Menu Cleanup — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix 8 UI/menu issues: confirm dialog headers, overlay sizing, localization raw keys, remove dead button, replace shader backgrounds with static aurora images, remove occlusion silhouette toggle, fix focus wrapping, and replace GPU particles with billboarded sprite dust.

**Current Status (as of 2026-05-03):**
- ✅ Task A — Remove Occlusion Silhouette (COMPLETE) — Redux slice + overlay pruned, all tests pass
- ✅ Task B — Remove Test Localization Button (COMPLETE) — Button removed from builder + tab + catalog
- ✅ Task C — Fix Localization Raw Keys
- ✅ Task D — Fix Confirm Dialog Headers
- ⏸ Task E — Consistent Overlay Sizes (pending)
- ✅ Task F — Fix Focus Wrapping
- ⏸ Task G — Replace Shader Backgrounds with Static Images (pending)
- ⏸ Task H — GPU Particles → Billboarded Sprite Dust (deferred to last)

**Commits so far:**
- `5ce48b77` — (REFACTOR) Remove occlusion silhouette from VFX state + UI
- `a9f79a81` — (FIXUP) Remove accidentally committed duplicate files
- `7422b510` — (REFACTOR) Remove Test Localization Button
- `5a5da2e6` — (TEST) Cleanup VFX references to deleted occlusion_silhouette feature
- `fd553448` — test: strengthen core/demo firewall with pre-commit hook
- `e76e48bc` — (FIX) Address localization raw keys, confirm dialog titles, and focus wrapping
- `85878832` — (FIX) Give ConfirmationDialog body text a visible panel background

**Architecture:** Menu backgrounds switch from runtime CanvasItem shader to static `TextureRect` nodes with PixelLab-generated aurora textures. Localization gets proper fallbacks and missing catalog keys. VFX state is pruned of unused occlusion silhouette field. GPU particle systems get replaced with a lightweight `Sprite3D` spawner using billboarded pixel dust textures.

**Tech Stack:** Godot 4.6 (GDScript), PixelLab MCP for asset generation, GUT test framework.

---

## File Inventory

| # | File / Asset | Action | Description |
|---|---|---|---|
| 1 | `scripts/core/ui/settings/ui_display_settings_tab.gd` | Modify | Fix confirm dialog title |
| 2 | `scripts/core/ui/settings/ui_localization_settings_tab.gd` | Modify | Fix confirm dialog title, clean localization |
| 3 | `scenes/core/ui/overlays/settings/ui_audio_settings_overlay.tscn` | Modify | Resize to 640×520 |
| 4 | `scenes/core/ui/overlays/settings/ui_localization_settings_overlay.tscn` | Modify | Resize to 640×520 |
| 5 | `scenes/core/ui/overlays/settings/ui_vfx_settings_overlay.tscn` | Modify | Resize + remove silhouette row |
| 6 | `scenes/core/ui/overlays/settings/ui_gamepad_settings_overlay.tscn` | Modify | Resize to 640×520 |
| 7 | `scenes/core/ui/overlays/settings/ui_keyboard_mouse_settings_overlay.tscn` | Modify | Resize to 640×520 |
| 8 | `scenes/core/ui/overlays/settings/ui_touchscreen_settings_overlay.tscn` | Modify | Resize to 640×520 |
| 9 | `scenes/core/ui/overlays/settings/ui_input_rebind_overlay.tscn` | Modify | Resize to 640×520 |
| 10 | `scripts/core/ui/helpers/u_settings_tab_builder.gd` | Modify | Add `fallback` to `begin_section`, `add_dropdown`, `add_toggle` |
| 11 | `scripts/core/ui/helpers/u_localization_tab_builder.gd` | Modify | Pass human-readable fallbacks |
| 12 | `scripts/core/ui/helpers/u_ui_settings_catalog.gd` | Modify | Remove occlusion silhouette from VFX options |
| 13 | `scripts/core/ui/settings/ui_vfx_settings_overlay.gd` | Modify | Remove silhouette logic |
| 14 | `scenes/core/ui/overlays/settings/ui_vfx_settings_overlay.tscn` | Modify | Remove `SilhouetteEnabledRow` nodes |
| 15 | `scripts/core/resources/state/rs_vfx_initial_state.gd` | Modify | Remove `occlusion_silhouette_enabled` |
| 16 | `scripts/core/state/actions/u_vfx_actions.gd` | Modify | Remove silhouette action |
| 17 | `scripts/core/state/reducers/u_vfx_reducer.gd` | Modify | Remove silhouette case |
| 18 | `scripts/core/state/selectors/u_vfx_selectors.gd` | Modify | Remove `is_occlusion_silhouette_enabled` |
| 19 | `scripts/core/ui/base/base_menu_screen.gd` | Modify | Support `TextureRect` backgrounds, skip shader for TextureRect |
| 20 | `scenes/core/ui/menus/ui_main_menu.tscn` | Modify | Swap `Background` ColorRect → `BackgroundImage` TextureRect |
| 21 | `scenes/core/ui/menus/ui_settings_menu.tscn` | Modify | Swap background node + set shader preset to `"none"` |
| 22 | `scenes/core/ui/menus/ui_pause_menu.tscn` | Modify | Swap background node + set shader preset to `"none"` |
| 23 | `scripts/core/ui/settings/ui_audio_settings_tab.gd` | Modify | Enable `wrap_vertical` in grid focus |
| 24 | `scripts/core/ui/settings/ui_vfx_settings_overlay.gd` | Modify | Enable vertical focus wrapping |
| 25 | `scripts/core/utils/u_particle_spawner.gd` | Rewrite | Replace GPU particles with Sprite3D approach |
| 26 | `assets/core/textures/bg_menu_main.png` | **Create** | PixelLab: aurora waves pixel art background |
| 27 | `assets/core/textures/bg_menu_settings.png` | **Create** | PixelLab: darker aurora variant |
| 28 | `assets/core/textures/bg_menu_overlay.png` | **Create** | PixelLab: dark abstract for overlays |
| 29 | `assets/core/textures/tex_dust_particle.png` | **Create** | PixelLab: soft white pixel dust blob, 32×32 |
| 30 | `resources/core/localization/cfg_locale_en_ui.tres` | Modify | Add missing settings.localization.* keys |
| 31 | `tests/unit/ui/helpers/test_u_localization_tab_builder.gd` | Modify | Remove test button test |
| 32 | `tests/integration/vfx/test_vfx_settings_ui.gd` | Modify | Remove silhouette assertions |
| 33 | `tests/unit/state/test_vfx_selectors.gd` | Modify | Remove silhouette tests |
| 34 | `tests/unit/state/test_vfx_reducer.gd` | Modify | Remove silhouette tests |
| 35 | `tests/unit/state/test_vfx_initial_state.gd` | Modify | Remove silhouette field test |

---

## Execution Order

1. **Task A — Remove Occlusion Silhouette** — Prune VFX state surface area first.
2. **Task B — Remove Test Localization Button** — Small, safe cleanup.
3. **Task C — Fix Localization Raw Keys** — Update builder fallbacks + English catalog.
4. **Task D — Fix Confirm Dialog Headers** — Polish pass.
5. **Task E — Consistent Overlay Sizes** — Layout fixes across 7 `.tscn` files.
6. **Task F — Fix Focus Wrapping** — Navigation UX.
7. **Task G — Generate Static Backgrounds + Swap** — PixelLab assets + `.tscn` updates.
8. **Task H — GPU → Sprite Particles** — Biggest change, do last.

---

## Task A: Remove Occlusion Silhouette from VFX Settings

### A.1 State / Redux Cleanup

**Files:** `scripts/core/resources/state/rs_vfx_initial_state.gd`, `scripts/core/state/actions/u_vfx_actions.gd`, `scripts/core/state/reducers/u_vfx_reducer.gd`, `scripts/core/state/selectors/u_vfx_selectors.gd`, `scripts/core/ui/helpers/u_ui_settings_catalog.gd`

- Remove `occlusion_silhouette_enabled` export and dictionary entry from `RS_VFXInitialState`
- Remove `ACTION_SET_OCCLUSION_SILHOUETTE_ENABLED` constant and `set_occlusion_silhouette_enabled()` action creator from `u_vfx_actions.gd`
- Remove silhouette case in `u_vfx_reducer.gd`
- Remove `is_occlusion_silhouette_enabled()` selector from `u_vfx_selectors.gd`
- Remove the occlusion-silhouette entry from `VFX_TOGGLE_OPTIONS` in `u_ui_settings_catalog.gd`

### A.2 UI Overlay Cleanup

**Files:** `scenes/core/ui/overlays/settings/ui_vfx_settings_overlay.tscn`, `scripts/core/ui/settings/ui_vfx_settings_overlay.gd`

- In `.tscn`: Delete `SilhouetteEnabledRow`, `SilhouetteEnabledLabel`, `SilhouetteEnabledToggle` nodes
- In `.gd`:
  - Remove `@onready` vars for silhouette row / label / toggle
  - Remove `_silhouette_enabled_toggled()` handler
  - Remove silhouette from `_on_apply_pressed()`, `_on_reset_pressed()`, `_on_state_changed()`
  - Remove silhouette from `_configure_tooltips()`
  - Remove from `_configure_focus_neighbors()` vertical controls list
  - Remove `_builder.bind_row()`, `_builder.bind_field_label()`, `_builder.bind_field_control()` calls for silhouette

### A.3 Tests

**Files:** `tests/integration/vfx/test_vfx_settings_ui.gd`, `tests/unit/state/test_vfx_selectors.gd`, `tests/unit/state/test_vfx_reducer.gd`, `tests/unit/state/test_vfx_initial_state.gd`

- Remove every assertion that references `_silhouette_enabled_toggle`, `is_occlusion_silhouette_enabled()`, or silhouette state fields
- Update default-state assertions to only cover shake, intensity, flash, particles

---

## Task B: Remove Test Localization Button

### B.1 Builder

**File:** `scripts/core/ui/helpers/u_localization_tab_builder.gd`

- Remove lines 56–57 (the `_add_button("Test Localization")` call)

### B.2 Tab Script

**File:** `scripts/core/ui/settings/ui_localization_settings_tab.gd`

- Remove `_on_test_localization_pressed()` method
- Remove test callback parameter from `_setup_builder()` → `U_UI_SETTINGS_CATALOG.create_localization_builder(...)` call
- Remove from builder `.set_callbacks()` invocation

### B.3 Tests

**File:** `tests/unit/ui/helpers/test_u_localization_tab_builder.gd`

- Remove `test_localization_builder_creates_test_button()` entirely

---

## Task C: Fix Localization Settings Raw Keys

### C.1 Builder Fallback Support

**File:** `scripts/core/ui/helpers/u_settings_tab_builder.gd`

- `begin_section(key: StringName, section_name: String = "Section", fallback: String = "")`
  - Pass `fallback` to `_add_label(key, section, fallback)`
- `add_dropdown(key: StringName, options: Array[Dictionary], callback: Callable, tooltip_key: StringName = &"", fallback: String = "", custom_name: String = "")`
  - Pass `fallback` to `_add_label(key, row, fallback)`
- `add_toggle(key: StringName, callback: Callable, tooltip_key: StringName = &"", fallback: String = "", custom_name: String = "")`
  - Pass `fallback` to `_add_label(key, row, fallback)`

### C.2 Localization Tab Builder

**File:** `scripts/core/ui/helpers/u_localization_tab_builder.gd`

- Pass human-readable fallbacks:
```gdscript
begin_section(&"settings.localization.section.language", "LanguageSection", "Language")
add_dropdown(&"settings.localization.label.language", ..., "", "Language", "LanguageOptionButton")
begin_section(&"settings.localization.section.accessibility", "AccessibilitySection", "Accessibility")
add_toggle(&"settings.localization.label.dyslexia", ..., &"", "", "DyslexiaCheckButton")
```
*(Note: if `add_toggle/add_dropdown` don't currently accept `fallback`, add the parameter as per C.1.)*

### C.3 Tab Script Cleanup

**File:** `scripts/core/ui/settings/ui_localization_settings_tab.gd`

- In `_localize_labels()`, remove manual `text = U_LOCALIZATION_UTILS.localize(...)` calls for labels that the builder already manages (`LanguageSection`, `LanguageLabel`, `AccessibilitySection`, `DyslexiaLabel`).
- The builder's `localize_labels()` already handles these. Only keep manual localization for:
  - Confirm dialog buttons (`common.keep`, `common.revert`)
  - Confirm dialog title (`settings.localization.confirm_title`)
  - Confirm dialog text (`settings.localization.confirm_text`)
  - Language option button items (re-populated from LOCALE_LABEL_KEYS)

### C.4 English Catalog

**File:** `resources/core/localization/cfg_locale_en_ui.tres`

- Ensure the following keys exist in the `translations` dictionary. Add any that are missing:
  - `settings.localization.section.language` → `"Language"`
  - `settings.localization.section.accessibility` → `"Accessibility"`
  - `settings.localization.label.language` → `"Language"`
  - `settings.localization.label.dyslexia` → `"Dyslexia Font"`
  - `settings.localization.title` → `"Language Settings"`
  - `settings.localization.confirm_title` → `"Confirm Language Change"`
  - `settings.localization.confirm_text` → `"Keep these changes? Reverting in {0}s."`
  - `settings.localization.button.test` → `"Test Localization"` *(will be removed in Task B, but safe to keep until then)*

---

## Task D: Fix Confirm Dialog Headers ✅ DONE

### D.1 Display Settings

**File:** `scripts/core/ui/settings/ui_display_settings_tab.gd`

- In `_configure_window_confirm_dialog()`, after existing OK/Cancel button setup, add:
```gdscript
window_confirm_dialog.title = U_LOCALIZATION_UTILS.localize_with_fallback(
    DIALOG_WINDOW_CONFIRM_TITLE_KEY,
    "Confirm Display Changes"
)
```
- Verify `_update_window_confirm_text()` only sets `dialog_text`, not `title`, so title persists.

### D.2 Localization Settings

**File:** `scripts/core/ui/settings/ui_localization_settings_tab.gd`

- In `_configure_language_confirm_dialog()`, add title setting:
```gdscript
confirm_dialog.title = U_LOCALIZATION_UTILS.localize_with_fallback(
    &"settings.localization.confirm_title",
    "Confirm Language Change"
)
```
- In `_refresh_language_confirm_dialog_localization()`, ensure title is refreshed alongside button labels.

### D.3 Dialog Body Text Background Fix

**Root cause:** Godot `ConfirmationDialog` body text renders over the `Window` `panel` stylebox, not just the `embedded_border`. Only `embedded_border` and `embedded_unfocused_border` were themed, leaving body text area transparent.

**Fix:** Added `_set_stylebox(theme, &"panel", &"Window", config.panel_section)` in `U_UIThemeBuilder._apply_panel_styles()`.

**Files modified:**
- `scripts/core/ui/utils/u_ui_theme_builder.gd`
- `tests/unit/ui/test_ui_theme_builder.gd` — added assertion for `Window` `panel` stylebox

---

## Task E: Consistent Settings Overlay Panel Sizes

**All settings overlays should use `640×520`:**

For each of these `.tscn` files, update `CenterContainer` offsets and inner `VBox` size:
- `scenes/core/ui/overlays/settings/ui_audio_settings_overlay.tscn`
- `scenes/core/ui/overlays/settings/ui_localization_settings_overlay.tscn`
- `scenes/core/ui/overlays/settings/ui_vfx_settings_overlay.tscn`
- `scenes/core/ui/overlays/settings/ui_gamepad_settings_overlay.tscn`
- `scenes/core/ui/overlays/settings/ui_keyboard_mouse_settings_overlay.tscn`
- `scenes/core/ui/overlays/settings/ui_touchscreen_settings_overlay.tscn`
- `scenes/core/ui/overlays/settings/ui_input_rebind_overlay.tscn`

### `.tscn` changes per file
```tscn
; CenterContainer
offset_left = -320.0
offset_top = -260.0
offset_right = 320.0
offset_bottom = 260.0

; Inner VBox under Panel
custom_minimum_size = Vector2(640, 520)
```

---

## Task F: Fix Focus Wrapping on All Menus

### F.1 VFX Overlay

**File:** `scripts/core/ui/settings/ui_vfx_settings_overlay.gd`

- In `_configure_focus_neighbors()`: change `configure_vertical_focus(vertical_controls, false)` → `configure_vertical_focus(vertical_controls, true)`
- Additionally, pass ALL focusable controls as one merged array including the buttons, OR ensure `last_vertical_control.focus_neighbor_bottom` points to the first button and the first button's `focus_neighbor_top` wraps to the last vertical control.

### F.2 Audio Tab

**File:** `scripts/core/ui/settings/ui_audio_settings_tab.gd`

- Change `configure_grid_focus(grid, false, false)` → `configure_grid_focus(grid, true, false)` (wrap vertical only, no horizontal wrap inside rows)
- Ensure button row focus connections work: last grid row → first button, and first button → last grid row.

---

## Task G: Replace Shader Backgrounds with Static Images

### G.1 Generate Assets (PixelLab MCP)

Use `pixellab_create_object` with `directions=1` (static single-image mode), view `"side"`.

| Asset | Description | Size |
|---|---|---|
| `assets/core/textures/bg_menu_main.png` | "Dark pixel art aurora borealis background, flowing teal and purple light waves, starry black sky, retro 16-bit style, large canvas" | 1024 |
| `assets/core/textures/bg_menu_settings.png` | "Dark pixel art abstract background, subtle scanline grid, deep blue and cyan gradients, retro 16-bit style, large canvas" | 1024 |
| `assets/core/textures/bg_menu_overlay.png` | "Dark pixel art abstract texture, very subtle noise pattern, near-black with faint navy highlights, retro 16-bit style, large canvas" | 1024 |

### G.2 Update `base_menu_screen.gd`

**File:** `scripts/core/ui/base/base_menu_screen.gd`

- Modify `_resolve_background_rect()` to prefer `TextureRect` named `BackgroundImage`:
```gdscript
func _resolve_background_rect() -> ColorRect:
    var bg_image := get_node_or_null("BackgroundImage") as TextureRect
    if bg_image != null:
        return null  # TextureRect handles its own texture; skip shader
    var background := get_node_or_null("Background") as ColorRect
    ...
```
- More robust approach: rename method to `_resolve_background_node() -> Control` that returns either ColorRect or TextureRect. Only apply shader if the node is a ColorRect.
- For backward compatibility, keep ColorRect path but skip shader when TextureRect is present.

### G.3 Update Scenes

**Files:** `ui_main_menu.tscn`, `ui_settings_menu.tscn`, `ui_pause_menu.tscn`, all settings overlays

For each scene:
1. If a `Background` ColorRect exists:
   - Rename to `BackgroundImage`
   - Change type from `ColorRect` to `TextureRect`
   - Add `texture = ExtResource("bg_..._png")`
   - Keep anchors as full-rect
2. On the root Control node, set `background_shader_preset = "none"`
3. For overlays: existing `OverlayBackground` ColorRect can stay (it's the dim overlay, not the animated shader); the shader was applied to it by `base_menu_screen.gd`, so changing it to not apply shader when it's just a dim color is correct.

---

## Task H: GPU Particles → Billboarded Sprite Dust

### H.1 Generate Dust Sprite

**PixelLab MCP:** `pixellab_create_object`
- Description: `"Small soft white pixel art dust particle, glowing center, transparent background, 32x32 pixel canvas"`
- Size: `32`
- Directions: `1`

Save as `assets/core/textures/tex_dust_particle.png`

### H.2 Rewrite Particle Spawner

**File:** `scripts/core/utils/u_particle_spawner.gd` — full replacement

Keep the same public API (`spawn_particles()`, `ParticleConfig`, `get_or_create_effects_container()`, `_is_particles_enabled()`) but replace internal implementation:

- Replace `_create_particle_node()`:
  - Instead of `GPUParticles3D.new()`, create `Sprite3D.new()`
  - Set `sprite.billboard = Sprite3D.BILLBOARD_ENABLED`
  - Set `sprite.texture` to a preloaded `tex_dust_particle.png` (or accept texture in config)
  - Set `sprite.pixel_size = config.scale * 0.01` (or similar scale mapping)

- Remove `_setup_draw_pass()`, `_setup_process_material()`, `_defer_particle_activation()`

- Add `_animate_sprite(sprite: Sprite3D, config: ParticleConfig, caller_node: Node)`:
  - Spawn `config.emission_count` sprites at randomized offsets within `spread_angle`
  - Each sprite gets a velocity vector
  - Use a `Tween` or per-sprite `_process` logic to move sprite along velocity + gravity
  - Fade `modulate.a` to 0 over `config.lifetime`
  - `queue_free()` after lifetime

- Simplify `_is_particles_enabled()` to keep existing Redux check

### H.3 Update ECS Particle Systems

Find all `S_*ParticlesSystem*.gd` in `scripts/core/ecs/systems/`:
- `S_JumpParticlesSystem`
- `S_LandingParticlesSystem`
- Any others

For each:
- Ensure they call `U_ParticleSpawner.spawn_particles()` — the API stays the same, only internals change
- If they directly instantiate `GPUParticles3D` or `CPUParticles3D`, replace with `Sprite3D` via the spawner

### H.4 Remove GPU Particle References

**File:** `scripts/core/managers/m_scene_manager.gd` (line 838)

- Remove or simplify the `is GPUParticles3D or node is CPUParticles3D or ...` check.

### H.5 Remove Particles Toggle from VFX Overlay

Since GPU particles are replaced with sprites but the `particles_enabled` toggle still controls whether ANY particles spawn, we can keep the toggle but rename its label/key if desired. However, the user explicitly said "Remove GPU particles" and implied removing the toggle too.

Remove from VFX overlay:
- `ParticlesEnabledRow`, `ParticlesEnabledLabel`, `ParticlesEnabledToggle` from `.tscn`
- Remove from `ui_vfx_settings_overlay.gd` state/handlers
- Remove `particles_enabled` from `RS_VFXInitialState`, `u_vfx_actions`, `u_vfx_reducer`, `u_vfx_selectors`
- Update all VFX tests

---

## Testing Strategy

### Per-Task Verification

After each task, run the most relevant test(s):

```bash
# Task A — VFX state cleanup
tools/run_gut_suite.sh -gtest=res://tests/integration/vfx/test_vfx_settings_ui.gd
tools/run_gut_suite.sh -gtest=res://tests/unit/state/test_vfx_selectors.gd
tools/run_gut_suite.sh -gtest=res://tests/unit/state/test_vfx_reducer.gd

# Task B — Localization button removal
tools/run_gut_suite.sh -gtest=res://tests/unit/ui/helpers/test_u_localization_tab_builder.gd

# Task C — Localization keys
tools/run_gut_suite.sh -gtest=res://tests/integration/localization/test_localization_settings_tab.gd

# Task E — Overlay sizes / style
tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd

# Task F — Focus wrapping
tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_display_settings_focus_wrapping.gd

# Task G — Background swap (no automated visual tests; verify by opening scenes in Godot)

# Task H — Particle spawner
tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/test_spawn_particles_system.gd
```

### Full Suite

After all tasks:
```bash
tools/run_gut_suite.sh
```

---

## Commit Markers

Use `(RED)` / `(GREEN)` markers per TDD workflow in AGENTS.md:

- Task A test removals: `(RED)` remove failing silhouette assertions first
- Task A implementation removals: `(GREEN)` prune state + UI
- Task B–D: similar pattern — failing test edits first, then code
- Task E–G: structural changes — `(REFACTOR)` or `(GREEN)` after visual verification
- Task H: largest change — break into multiple `(RED)` / `(GREEN)` commits

---

*Plan complete. Ready for approval and implementation.*
