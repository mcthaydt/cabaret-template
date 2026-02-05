# cleanup_v5 Continuation Prompt

## Current Status

- Phase: Phase 2B complete (root-level prefab/model/texture moves + prefab rename). Phase 2A partial (models dir created; tests still pending).
- Important: Working tree was clean at time of Phase 2B (2026-02-05). Root-level scenes/models/textures moved and references updated; prefab names finalized as `prefab_alleyway.tscn` and `prefab_bar.tscn`. GLB import settings switched to keep embedded images (`gltf/embedded_image_handling=0`) to avoid extracted PNGs with spaces.
- Tests: 
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` (2026-02-05)
  - Headless import: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import` (2026-02-05, twice; cleared `.godot/uid_cache.bin` after UID warnings, rerun after prefab rename)

## Goals

- Restore consistency with the repo's established cleanup_v1-v4.5 conventions.
- Remove "copy artifact" directories (e.g., `* 2`) and other out-of-band clutter.
- Normalize root-level scenes/models/textures into the canonical folder layout and naming rules.
- Refactor the display module (`M_DisplayManager` + display settings UI) to be modular, scalable, and designer-friendly:
  - Centralize option catalogs (data-driven where possible)
  - Extract focused appliers (window/quality/post-process/ui scale/theme)
  - Improve player UX without regressing stability

## Required Readings (Do Not Skip)

- `AGENTS.md` - project conventions, testing, and update rules.
- `docs/general/DEV_PITFALLS.md` - known gotchas (imports, class cache, UI pitfalls).
- `docs/general/STYLE_GUIDE.md` - naming, formatting, prefix rules.
- `docs/general/cleanup_v5/cleanup-v5-continuation-prompt.md` - this file (keep current).
- `docs/general/cleanup_v4.5/reorganization-continuation-prompt.md` - most recent cleanup patterns.
- `docs/general/cleanup_v4/` docs - prior cleanup conventions and pitfalls.
- Display manager docs (if working Phase 3+):
  - `docs/display_manager/display-manager-continuation-prompt.md`
  - `docs/display_manager/display-manager-tasks.md`

## Process for Completion (Every Phase)

1. Start with the next unchecked task list section (define it if missing).
2. Plan the smallest safe batch of moves/renames; verify references before executing.
3. Execute filesystem changes → update references → run headless import if scenes/scripts moved.
4. Run relevant tests (style suite mandatory after any moves/renames).
5. Update any task checklist with [x] and completion notes (commit hash, tests run, deviations).
6. Update this continuation prompt with status, tests run, and next step.
7. Update `AGENTS.md` and/or `DEV_PITFALLS.md` if new patterns or pitfalls emerged.
8. Commit with a clear message; commit documentation updates separately from implementation.

## Test / Document / Commit Checklist

- **Test**: Run the smallest relevant suite first; expand to integration/regression as needed.
- **Document**: Update task checklist + this prompt; update `AGENTS.md`/`DEV_PITFALLS.md` when required.
- **Commit**: Keep code and docs in separate commits and include the commit hash in task notes.

## Confirmed Decisions

- Add `assets/models/` and enforce `mdl_` prefix (models).
- Enforce prefix rules in tests for:
  - `assets/models` (`mdl_`)
  - `assets/materials` (`mat_`)
  - `assets/shaders` (`sh_`)
- Remove unused LUT PNGs:
  - `resources/luts/Astia sRGB.png`
  - `resources/luts/Presetpro Fuji Film.png`
- Display settings UI stays **Apply/Cancel + preview** (no auto-save).
- Add a **Confirm display changes (10s) / Revert** flow for window mode/size changes.
- Make display option catalogs **data-driven** (quality/window presets) to avoid duplicated hard-coded lists.

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

## Next Steps (Phase 2A+ / Phase 3)

1. Finish Phase 2A enforcement work:
   - Update `tests/unit/style/test_asset_prefixes.gd` for `mdl_`, `mat_`, `sh_`
   - Add a test that fails on spaces in production `res://` paths
2. Remove unused LUT PNGs (and `.import` files) after confirming no references.
3. Refactor Display Manager in small, test-backed steps (helper extraction, de-dup catalogs, remove dead code).
   - Add data-driven option catalogs (quality + window size presets)
   - Add confirm/revert countdown for window changes
   - Polish settings UI (contextual enabling, focus, microcopy)

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
