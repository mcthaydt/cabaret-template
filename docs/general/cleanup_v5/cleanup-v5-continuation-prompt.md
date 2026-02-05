# cleanup_v5 Continuation Prompt

## Current Status

- Phase: Planning only (no cleanup_v5 implementation started yet).
- Important: The repo currently has unrelated WIP changes in the working tree. Cleanup_v5 implementation should not begin until that WIP is resolved (commit or stash) so we can reason about diffs and keep commits focused.

## Goals

- Restore consistency with the repo's established cleanup_v1-v4.5 conventions.
- Remove "copy artifact" directories (e.g., `* 2`) and other out-of-band clutter.
- Normalize root-level scenes/models/textures into the canonical folder layout and naming rules.
- Refactor `M_DisplayManager` to reduce responsibility sprawl using helper extraction patterns, without changing behavior.

## Confirmed Decisions

- Add `assets/models/` and enforce `mdl_` prefix (models).
- Enforce prefix rules in tests for:
  - `assets/models` (`mdl_`)
  - `assets/materials` (`mat_`)
  - `assets/shaders` (`sh_`)
- Remove unused LUT PNGs:
  - `resources/luts/Astia sRGB.png`
  - `resources/luts/Presetpro Fuji Film.png`

## Known Cleanup Targets (From Initial Audit)

- Duplicate empty directories created by OS copy ops (suffix ` 2`):
  - `scenes/ui/widgets 2`, `scenes/ui/overlays 2`
  - `resources/input/* 2`
  - `tests/assets/* 2`
  - `docs/* 2`
  - `assets/* 2`
- Empty legacy docs directories with spaces:
  - `docs/debug manager`, `docs/input manager`, `docs/ui manager`
- Root-level scenes/models/textures referenced by gameplay/templates:
  - `character.tscn`, `new_exterior.tscn`, `new_interior.tscn`
  - `Character.glb`, `NewExterior.glb`, `NewInterior.glb`
  - `NewExterior_Image Color Quantizer (3).png`, `NewInterior_Image Color Quantizer (2).png`

## Next Steps (When Implementation Starts)

1. Resolve current repo WIP (commit or stash) so cleanup_v5 can proceed with clean, reviewable diffs.
2. Execute Phase 1 filesystem hygiene (delete unused `* 2` dirs and empty legacy docs dirs).
3. Execute Phase 2 normalization:
   - Create `assets/models/`
   - Move/rename root-level scenes into `scenes/prefabs/` with `prefab_` naming
   - Move/rename models to `assets/models/mdl_*.glb`
   - Move/rename textures to `assets/textures/tex_*.png` (or delete if truly unused)
   - Update references and run headless `--import` to refresh caches
4. Remove unused LUT PNGs (and `.import` files) after confirming no references.
5. Extend style enforcement:
   - Update `tests/unit/style/test_asset_prefixes.gd` for `mdl_`, `mat_`, `sh_`
   - Add a test that fails on spaces in production `res://` paths
6. Refactor Display Manager in small, test-backed steps (helper extraction, de-dup catalogs, remove dead code).

## Tests To Run

- Style suite (always after moves/renames):
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true`
- Display-related suites after refactors:
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/managers -ginclude_subdirs=true`
  - `tools/run_gut_suite.sh -gdir=res://tests/integration/display -ginclude_subdirs=true`

## Notes / Pitfalls

- After moving `.tscn` or `class_name` scripts, run a headless import to refresh UID/script caches:
  - `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import`
- Avoid introducing spaces in any production `res://` paths; cleanup_v5 will add enforcement for this.

