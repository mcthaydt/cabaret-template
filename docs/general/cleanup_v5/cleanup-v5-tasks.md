# cleanup_v5 Tasks

## Scope / Goals

- Bring repo back into the same conventions enforced by `docs/general/STYLE_GUIDE.md` and `tests/unit/style/*`.
- Normalize out-of-band files/folders (especially root-level assets/scenes and duplicated `* 2` directories).
- Refactor the display module (`M_DisplayManager` + display settings UI) to be modular, scalable, and designer-friendly:
  - Centralize option catalogs (data-driven where possible)
  - Extract focused “appliers” (window/quality/post-process/ui scale/theme)
  - Improve player UX (Apply/Cancel + preview, confirm/revert for risky window changes)

## Constraints (Non-Negotiable)

- Do not start cleanup_v5 implementation while the working tree is in an unknown/dirty state. Resolve existing WIP first (commit or stash).
- Keep commits small and test-green.
- Commit documentation updates separately from implementation changes.
- After any file move/rename or scene/resource structure change, run `tests/unit/style/test_style_enforcement.gd`.

## Decisions (Confirmed)

- Models will live in `assets/models/` and must use `mdl_` prefix.
- Prefix enforcement will be extended to include:
  - `assets/models` (`mdl_`)
  - `assets/materials` (`mat_`)
  - `assets/shaders` (`sh_`)
- Remove unused LUT PNGs:
  - `resources/luts/Astia sRGB.png`
  - `resources/luts/Presetpro Fuji Film.png`
- Display settings UI stays **Apply/Cancel + preview** (no auto-save).
- Add a **Confirm display changes (10s) / Revert** flow for window mode/size changes.
- Make display option catalogs **data-driven** (quality/window presets) to avoid duplicated hard-coded lists.

## Phase 0 - Baseline & Inventory (Read-Only)

- [ ] Confirm style baseline:
  - Run: `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true`
- [ ] Inventory paths with spaces (exclude `/.godot*`):
  - Run: `find . -path './.godot*' -prune -o -name '* *' -print`
- [ ] Inventory root-level `.tscn`, `.glb`, `.png` that are referenced by `res://scenes/**`
- [ ] Record an audit note (what will be moved/renamed/deleted, what will be left as-is)

## Phase 1 - Filesystem Hygiene (Low Risk)

- [x] Delete empty/unused duplicate directories that end with ` 2`:
  - `scenes/ui/widgets 2`
  - `scenes/ui/overlays 2`
  - `resources/input/touchscreen_settings 2`
  - `resources/input/gamepad_settings 2`
  - `resources/input/rebind_settings 2`
  - `resources/input/profiles 2`
  - `tests/assets/textures 2`
  - `tests/assets/audio 2` (and its empty children)
  - `docs/state_store/general 2`
  - `docs/input_manager/refactoring 2`
  - `docs/scene_manager/general 2`
  - `assets/audio/music 2`
  - `assets/button_prompts/keyboard 2`
- [x] Delete empty legacy docs directories with spaces that duplicate canonical folders:
  - `docs/debug manager`
  - `docs/input manager`
  - `docs/ui manager`
- [x] Run style tests:
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true`

Completion Notes (2026-02-05): Removed all listed duplicate/legacy directories (all empty/untracked). Tests: `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true`. Commit: e6fd729 (docs-only; no tracked file removals).

## Phase 2 - Normalize Root-Level Content (Medium Risk)

### 2A - Introduce Models Directory + Test Enforcement

- [x] Create `assets/models/` (if missing)
- [x] Extend `tests/unit/style/test_asset_prefixes.gd`:
  - Add `assets/models` => `mdl_` + extensions (at least `.glb`, `.fbx`, `.gltf`)
  - Add `assets/materials` => `mat_` + extensions (at least `.tres`, `.res`)
  - Add `assets/shaders` => `sh_` + extensions (at least `.gdshader`)
- [x] Add a style test that fails on spaces in production `res://` paths (scenes/resources/scripts/assets)
- [x] Run style tests

Completion Notes (2026-02-05): Added prefix enforcement for models/materials/shaders and a no-spaces production path test. Tests: `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true`. Commit: a39e818.

### 2B - Move/Rename Root-Level Scenes and Assets

- [x] Move and rename root-level scenes into `scenes/prefabs/`:
  - `character.tscn` -> `scenes/prefabs/prefab_character.tscn`
  - `new_exterior.tscn` -> `scenes/prefabs/prefab_new_exterior.tscn`
  - `new_interior.tscn` -> `scenes/prefabs/prefab_new_interior.tscn`
- [x] Move and rename root-level models into `assets/models/`:
  - `Character.glb` -> `assets/models/mdl_character.glb`
  - `NewExterior.glb` -> `assets/models/mdl_new_exterior.glb`
  - `NewInterior.glb` -> `assets/models/mdl_new_interior.glb`
- [x] Move and rename root-level textures into `assets/textures/`:
  - `NewExterior_Image Color Quantizer (3).png` -> `assets/textures/tex_alleyway.png`
  - `NewInterior_Image Color Quantizer (2).png` -> `assets/textures/tex_bar.png`
  - `Character_Image Color Quantizer (1) 11.04.png` -> `assets/textures/tex_character.png`
- [x] Update references in:
  - `scenes/templates/*`
  - `scenes/gameplay/*`
  - Any `ExtResource(...)` paths in `.tscn`/`.tres`
- [x] Run headless import to refresh UID/script caches after moves:
  - `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import`
- [x] Run style tests again

Completion Notes (2026-02-05): Phase 2B moves complete (prefabs/models/textures) and references updated. Set GLB import `gltf/embedded_image_handling=0` to avoid extracted textures with spaces; removed generated PNGs and reran headless import (cleared `.godot/uid_cache.bin` after UID warnings). Tests: `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` (rerun after prefab rename). Commits: 3a7b476 (normalize root assets), 7e01424 (rename prefab scenes to alleyway/bar).

## Phase 3 - Remove Unused LUT PNGs (Low Risk)

- [x] Confirm no references to:
  - `resources/luts/Astia sRGB.png`
  - `resources/luts/Presetpro Fuji Film.png`
- [x] Delete both PNGs and their `.import` files (if present)
- [x] Run style tests

Completion Notes (2026-02-05): LUT PNGs removed after reference check; style suite passed. Commit: a39e818.

## Phase 4 - Display Module Refactor (Modular + UX + Designer-Friendly)

- [x] Confirm display manager test coverage baseline:
  - Unit: `tests/unit/managers/test_display_manager.gd`
  - Integration: `tests/integration/display/*`

### 4A - Data-Driven Option Catalogs (Single Source of Truth)

- [x] Introduce a central catalog (`U_DisplayOptionCatalog` or equivalent) that provides:
  - Window size presets + lookup size by ID
  - Quality presets + lookup resource by ID
  - Window mode / dither pattern / color blind mode option lists
- [x] Make quality presets discoverable from `res://resources/display/cfg_quality_presets/` (drop-in `.tres` files appear in UI).
- [x] Add window size presets as resources (designer-friendly):
  - Directory: `res://resources/display/cfg_window_size_presets/`
  - Resource type: `RS_WindowSizePreset` with `preset_id`, `size`, `label`, `sort_order`
- [x] Update both `M_DisplayManager` and `UI_DisplaySettingsTab` to use the catalog (remove duplicated hard-coded lists).
- [x] Add coverage:
  - Unit tests for catalog discovery + sorting + fallback behavior
  - Style enforcement remains unchanged (no new prefix categories required)

Completion Notes (2026-02-05): Added `U_DisplayOptionCatalog`, `RS_WindowSizePreset`, window size presets, and catalog-backed option lists for window/quality/dither/color blind; reducer + UI now pull from catalog. Tests: `tools/run_gut_suite.sh -gdir=res://tests/unit/utils -ginclude_subdirs=true`, `tools/run_gut_suite.sh -gdir=res://tests/unit/managers -ginclude_subdirs=true`, `tools/run_gut_suite.sh -gdir=res://tests/integration/display -ginclude_subdirs=true` (warnings: macOS CA cert, InputMap bootstrapper, ObjectDB leak, particle spawner deferred errors). Commit: b0680e8.

### 4B - Extract Appliers (Modular, Testable)

- [ ] Extract focused appliers under `scripts/managers/helpers/display/` (proposed):
  - `u_display_window_applier.gd` (mode/size/vsync + platform guards)
  - `u_display_quality_applier.gd` (quality preset application + viewport wiring)
  - `u_display_post_process_applier.gd` (effect toggles/params via `U_PostProcessLayer`)
  - `u_display_ui_scale_applier.gd` (UIScaleRoot registration + font scaling)
  - `u_display_ui_theme_applier.gd` (palette → Theme binding)
- [ ] Keep `M_DisplayManager` as the orchestrator:
  - Builds effective settings (Redux slice + preview overlay)
  - Hash-gates expensive work
  - Delegates to appliers (DI-friendly for tests)

### 4C - Confirm Display Changes (10s) / Revert (Player UX)

- [ ] Add a confirm flow for risky window changes (mode/size):
  - When the user presses **Apply** and mode/size changed, show a confirm dialog with a 10s countdown.
  - **Do not dispatch** window actions to Redux until the player confirms.
  - If timer expires or user chooses **Revert**, restore previous window settings and keep the overlay usable.
  - If player chooses **Keep**, dispatch window actions and clear preview mode as normal.
- [ ] Ensure the dialog is gamepad-friendly:
  - Focus defaults to “Keep”
  - Back button = Revert
  - Countdown text updates reliably (no await-before-signal pitfalls)
- [ ] Add integration tests:
  - Confirm flow blocks dispatch until confirmed
  - Revert path restores prior window ops state

### 4D - Settings UI Polish (Clarity + Accessibility)

- [ ] Contextual enable/disable:
  - Window size row disabled unless in `windowed` mode
  - Effect intensity sliders disabled unless effect enabled
- [ ] Improve readability and UX:
  - Grouping + microcopy where players need clarity (e.g., CRT parameters)
  - Focus neighbors remain deterministic; ScrollContainer follow-focus works
- [ ] Confirm flow integrates cleanly with Apply/Cancel + preview (no auto-save regression).

### 4E - Remove Dead Code (Only After Proof)

- [ ] Remove dead/unused code in `M_DisplayManager` only after tests prove unused:
  - `_is_hex_string()`
  - safe-area padding helpers (if truly unused)

### 4F - Run Targeted Test Suites

- [ ] `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true`
- [ ] `tools/run_gut_suite.sh -gdir=res://tests/unit/managers -ginclude_subdirs=true`
- [ ] `tools/run_gut_suite.sh -gdir=res://tests/integration/display -ginclude_subdirs=true`

## Notes

- If any move/rename touches `.tscn` files created/edited outside the editor, re-read `docs/general/DEV_PITFALLS.md` regarding UIDs and class cache refresh.
