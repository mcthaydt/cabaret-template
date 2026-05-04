# UI Settings & Menu Cleanup — Session Handoff

## Current Status

| Task | Status | Notes |
|------|--------|-------|
| **A** — Remove Occlusion Silhouette from VFX Settings | ✅ COMPLETE | Redux slice + overlay pruned; all tests passing |
| **B** — Remove Test Localization Button | ✅ COMPLETE | Button removed from builder, tab, and catalog |
| **C** — Fix Localization Raw Keys | ✅ COMPLETE | Fallback params added to builder methods; human-readable fallbacks wired; manual `_localize_labels()` removed from LocalizationSettingsTab; missing keys added to all 5 locale catalogs |
| **D** — Fix Confirm Dialog Headers | ✅ COMPLETE | Dialog **titles** localized from keys (display + localization). Dialog **body text panel background** fixed by adding missing `panel` stylebox mapping for `&"Window"` in `U_UIThemeBuilder` |
| **E** — Consistent Settings Overlay Sizes | ⏸ Pending | Not started |
| **F** — Fix Focus Wrapping on All Menus | ✅ COMPLETE | VFX overlay wraps vertically; audio tab wraps vertically in grid |
| **G** — Replace Shader Backgrounds with Static Images | ⏸ Pending | Not started |
| **H** — GPU Particles → Billboarded Sprite Dust | ⏸ Deferred to last | User explicitly deferred |
| **Manifest Refactor** | ✅ COMPLETE | Fixed core→demo style violation via Option 3 (RS_SceneManifestConfig resources) |

---

## Commits on Branch `mobile-fixes`

| Hash | Message |
|------|---------|
| `5ce48b77` | (REFACTOR) Remove occlusion silhouette from VFX state + UI |
| `a9f79a81` | (FIXUP) Remove accidentally committed duplicate files |
| `7422b510` | (REFACTOR) Remove Test Localization Button |
| `5a5da2e6` | (TEST) Cleanup VFX references to deleted occlusion_silhouette feature |
| `fd553448` | test: strengthen core/demo firewall with pre-commit hook |
| `e76e48bc` | (FIX) Address localization raw keys, confirm dialog titles, and focus wrapping |
| `85878832` | (FIX) Give ConfirmationDialog body text a visible panel background |
| `f8c7690c` | (REFACTOR) Replace hardcoded scene paths in u_scene_manifest with RS_SceneManifestConfig resources |

---

## Remaining Work (Tasks E, G, H)

### Task E — Consistent Settings Overlay Sizes (640×520)
- Resize **existing** overlays that still use non-640×520 sizes:
  - `scenes/core/ui/overlays/settings/ui_audio_settings_overlay.tscn` (currently 520×440)
  - `scenes/core/ui/overlays/settings/ui_localization_settings_overlay.tscn` (currently 400×320)
  - `scenes/core/ui/overlays/settings/ui_vfx_settings_overlay.tscn` (currently 520×360)
- Verify via `test_style_enforcement.gd`

**Note:** `ui_gamepad_settings_overlay.tscn`, `ui_keyboard_mouse_settings_overlay.tscn`, `ui_touchscreen_settings_overlay.tscn`, and `ui_input_rebind_overlay.tscn` are **not under `scenes/core/ui/overlays/settings/`** — they live directly under `scenes/core/ui/overlays/` and their sizes have not yet been checked.

### Task G — Replace Shader Backgrounds with Static Images
- Generate 3 aurora backgrounds via PixelLab MCP (`pixellab_create_object` with `directions=1`, view `"side"`):
  - `assets/core/textures/bg_menu_main.png` (dark pixel art aurora, 1024)
  - `assets/core/textures/bg_menu_settings.png` (subtle scanline grid, 1024)
  - `assets/core/textures/bg_menu_overlay.png` (near-black noise pattern, 1024)
- `scripts/core/ui/base/base_menu_screen.gd` — detect `TextureRect` named `BackgroundImage` and skip shader application
- `scenes/core/ui/menus/ui_main_menu.tscn` — swap `Background` ColorRect → `BackgroundImage` TextureRect
- `scenes/core/ui/menus/ui_settings_menu.tscn` — swap background node
- `scenes/core/ui/menus/ui_pause_menu.tscn` — swap background node
- For each scene root Control: set `background_shader_preset = "none"`

### Task H — GPU Particles → Billboarded Sprite Dust (DEFERRED)
- Generate `tex_dust_particle.png` via PixelLab MCP (32px soft white pixel dust)
- `scripts/core/utils/u_particle_spawner.gd` — rewrite internals to use `Sprite3D` + tween-based physics
- Remove `GPUParticles3D` / `CPUParticles3D` references from `m_scene_manager.gd` (line 838 area)
- Keep or remove `particles_enabled` toggle from VFX state per user preference

---

## Manifest Refactor Details (Option 3 — DONE)

**Problem:** `u_scene_manifest.gd` hardcoded `res://scenes/demo/gameplay/gameplay_demo_room.tscn`, causing `test_core_scripts_never_import_from_demo` to fail.

**Solution:** Resource-driven manifest configuration:
- **`RS_SceneManifestConfig`** (`scripts/core/resources/scene_management/rs_scene_manifest_config.gd`): new resource class accepting `Array[Dictionary]` entries and producing `U_SceneRegistryBuilder` output.
- **`cfg_core_scene_entries.tres`** (`resources/core/scene_registry/`): all core UI overlay + end-game menu entries.
- **`cfg_demo_scene_entries.tres`** (`resources/demo/scene_registry/`): demo gameplay scene entry (segregated from core).
- **`u_scene_manifest.gd`**: rewritten to load config resources instead of hardcoding paths.

**Result:** Core script no longer references demo paths. Style enforcement now passes.

---

## Key Technical Context

- `U_VFXSelectors.is_occlusion_silhouette_enabled()` **deleted** — do not resurrect
- `U_VFXActions.set_occlusion_silhouette_enabled()` **deleted** — do not call
- `M_VCamManager._is_occlusion_silhouette_enabled()` still exists but **hardcoded to true** on desktop
- `U_LocalizationTabBuilder.set_callbacks()` now takes **5 params** (removed `test_cb`)
- No autoloads; managers register via `U_ServiceLocator`
- Do **not** use `git add -A` for commits (accidentally committed duplicate files — fixed in `a9f79a81`)
- Do **not** create `.tscn` files by hand — use builder scripts if available

---

## Running Tests

```bash
# Localization keys
tools/run_gut_suite.sh -gtest=res://tests/integration/localization/test_localization_settings_tab.gd

# Overlay sizes / style
tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd

# Focus wrapping
tools/run_gut_suite.sh -gtest=res://tests/unit/ui/test_display_settings_focus_wrapping.gd

# Particle spawner
tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/test_spawn_particles_system.gd

# Full suite after all tasks
tools/run_gut_suite.sh
```

---

## Known Issues / Cleanup Notes

- ⚠️ **Pre-existing scene-registry warning**: `res://resources/core/scene_registry/cfg_core_scene_entries.tres:3` has an invalid UID (`uid://c0rqh1w5f3ye`) for the `rs_scene_manifest_config.gd` script reference. Godot falls back to text path so this does not block runtime, but the UID collision causes test warnings. **Fix:** delete the `.tres` uid line and let Godot regenerate a fresh UID, or simply ignore (harmless).
- ⚠️ Phase 5 base-scene cleanup is **deferred** — do not start unless explicitly requested
- ⚠️ Task G uses PixelLab MCP — verify account credits before generating 3 backgrounds + dust sprite

---

## Branch: `mobile-fixes`
## Last Commit: `f8c7690c`
## Date: 2026-05-03
## Plan: `.opencode/plans/2026-05-03-ui-settings-menu-cleanup.md`
## Handoff: `.opencode/handoff-latest.md`
