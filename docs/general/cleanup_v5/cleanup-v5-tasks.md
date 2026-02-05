# cleanup_v5 Tasks

## Scope / Goals

- Bring repo back into the same conventions enforced by `docs/general/STYLE_GUIDE.md` and `tests/unit/style/*`.
- Normalize out-of-band files/folders (especially root-level assets/scenes and duplicated `* 2` directories).
- Refactor `M_DisplayManager` to be consistent with helper extraction patterns (behavior-preserving).

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

## Phase 0 - Baseline & Inventory (Read-Only)

- [ ] Confirm style baseline:
  - Run: `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true`
- [ ] Inventory paths with spaces (exclude `/.godot*`):
  - Run: `find . -path './.godot*' -prune -o -name '* *' -print`
- [ ] Inventory root-level `.tscn`, `.glb`, `.png` that are referenced by `res://scenes/**`
- [ ] Record an audit note (what will be moved/renamed/deleted, what will be left as-is)

## Phase 1 - Filesystem Hygiene (Low Risk)

- [ ] Delete empty/unused duplicate directories that end with ` 2`:
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
- [ ] Delete empty legacy docs directories with spaces that duplicate canonical folders:
  - `docs/debug manager`
  - `docs/input manager`
  - `docs/ui manager`
- [ ] Run style tests:
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true`

## Phase 2 - Normalize Root-Level Content (Medium Risk)

### 2A - Introduce Models Directory + Test Enforcement

- [ ] Create `assets/models/` (if missing)
- [ ] Extend `tests/unit/style/test_asset_prefixes.gd`:
  - Add `assets/models` => `mdl_` + extensions (at least `.glb`, `.fbx`, `.gltf`)
  - Add `assets/materials` => `mat_` + extensions (at least `.tres`, `.res`)
  - Add `assets/shaders` => `sh_` + extensions (at least `.gdshader`)
- [ ] Add a style test that fails on spaces in production `res://` paths (scenes/resources/scripts/assets)
- [ ] Run style tests

### 2B - Move/Rename Root-Level Scenes and Assets

- [ ] Move and rename root-level scenes into `scenes/prefabs/`:
  - `character.tscn` -> `scenes/prefabs/prefab_*.tscn`
  - `new_exterior.tscn` -> `scenes/prefabs/prefab_*.tscn`
  - `new_interior.tscn` -> `scenes/prefabs/prefab_*.tscn`
- [ ] Move and rename root-level models into `assets/models/`:
  - `Character.glb` -> `assets/models/mdl_*.glb`
  - `NewExterior.glb` -> `assets/models/mdl_*.glb`
  - `NewInterior.glb` -> `assets/models/mdl_*.glb`
- [ ] Move and rename root-level textures into `assets/textures/`:
  - `NewExterior_Image Color Quantizer (3).png` -> `assets/textures/tex_*.png` (or remove if unused)
  - `NewInterior_Image Color Quantizer (2).png` -> `assets/textures/tex_*.png` (or remove if unused)
- [ ] Update references in:
  - `scenes/templates/*`
  - `scenes/gameplay/*`
  - Any `ExtResource(...)` paths in `.tscn`/`.tres`
- [ ] Run headless import to refresh UID/script caches after moves:
  - `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import`
- [ ] Run style tests again

## Phase 3 - Remove Unused LUT PNGs (Low Risk)

- [ ] Confirm no references to:
  - `resources/luts/Astia sRGB.png`
  - `resources/luts/Presetpro Fuji Film.png`
- [ ] Delete both PNGs and their `.import` files (if present)
- [ ] Run style tests

## Phase 4 - Display Manager Refactor (Behavior-Preserving)

- [ ] Confirm display manager test coverage baseline:
  - Unit: `tests/unit/managers/test_display_manager.gd`
  - Integration: `tests/integration/display/*`
- [ ] Extract helpers under `scripts/managers/helpers/display/` (proposed):
  - `u_display_window_applier.gd`
  - `u_display_quality_applier.gd`
  - `u_display_post_process_applier.gd`
  - `u_display_ui_scale_applier.gd`
  - `u_display_ui_theme_applier.gd`
- [ ] De-duplicate option catalogs between `M_DisplayManager` and `UI_DisplaySettingsTab`
- [ ] Remove dead/unused code in `M_DisplayManager` (after tests prove unused):
  - `_is_hex_string()`
  - safe-area padding helpers (if truly unused)
- [ ] Run targeted test suites:
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true`
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/managers -ginclude_subdirs=true`
  - `tools/run_gut_suite.sh -gdir=res://tests/integration/display -ginclude_subdirs=true`

## Notes

- If any move/rename touches `.tscn` files created/edited outside the editor, re-read `docs/general/DEV_PITFALLS.md` regarding UIDs and class cache refresh.

