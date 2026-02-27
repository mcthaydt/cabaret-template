# cleanup_v6 Continuation Prompt

## Current Status

- Phase: Phase 6 complete (`String(value)` migration + dither enum fix); next: Phase 7 style enforcement expansion.
- Branch: `cleanup-v6` (17 commits ahead of main; Phase 6 docs update pending commit).
- Working tree: implementation committed (`2aba797d`), docs currently modified for Phase 6 status updates.

## Context

After cleanup_v5 (filesystem hygiene + display module refactor), ~409 commits landed on main introducing two major feature systems and several smaller features:

**Major features:**
- **QB v2** — Complete rewrite of the query-based rule engine (scorer, selector, state tracker, validator, character/game/camera rule migration, composite conditions).
- **Scene Director** — Objectives manager, beat runner, beat graph with branching/fork-join, victory/completion flow, scene director manager integration, run coordinator.

**Smaller features:**
- Cinema grading (per-scene color grading post-process)
- Color blind palettes + UI filter
- Post-processing presets (resource-based)
- Global settings persistence
- Display settings UI improvements

All of this code needs to be brought up to the quality bar established by cleanups v1–v5.

## Goals

- Eliminate new `has_method()` duck typing introduced by QB v2 and Scene Director code.
- Add missing interfaces for new managers (`M_ObjectivesManager`, `M_SceneDirector`, `M_RunCoordinator`).
- Fix naming/prefix violations and class name inconsistencies.
- Remove dead code, debug cruft, and orphaned files.
- Extract duplicated helpers into shared utilities.
- Extend style enforcement tests to cover new directories.
- Fix `String(value)` → `str(value)` across display module files.
- Move misplaced files (`u_post_process_layer.gd`, `extract_touchscreen_settings.gd`).
- Create missing initial state `.tres` resources for objectives and scene director slices.
- Document undocumented STYLE_GUIDE.md gaps (`tmpl_*.tscn`, `scripts/core/`).
- Clean up stale documentation.
- Fill cinema grading test coverage gap.

## Required Readings (Do Not Skip)

- `AGENTS.md` — project conventions, testing, and update rules.
- `docs/general/DEV_PITFALLS.md` — known gotchas (imports, class cache, UI pitfalls).
- `docs/general/STYLE_GUIDE.md` — naming, formatting, prefix rules.
- `docs/general/cleanup_v6/cleanup-v6-tasks.md` — the task checklist.
- `docs/general/cleanup_v5/cleanup-v5-continuation-prompt.md` — prior cleanup patterns.

## Process for Completion (Every Phase)

1. Start with the next unchecked task list section.
2. Plan the smallest safe batch of changes; verify references before executing.
3. Execute changes → update references → run headless import if scenes/scripts moved or renamed.
4. Run relevant tests (style suite mandatory after any moves/renames).
5. Update task checklist with [x] and completion notes (commit hash, tests run, deviations).
6. Update this continuation prompt with status, tests run, and next step.
7. Update `AGENTS.md` and/or `DEV_PITFALLS.md` if new patterns or pitfalls emerged.
8. Commit with a clear message; commit documentation updates separately from implementation.

## Test / Document / Commit Checklist

- **Test**: Run the smallest relevant suite first; expand to integration/regression as needed.
- **Document**: Update task checklist + this prompt; update `AGENTS.md`/`DEV_PITFALLS.md` when required.
- **Commit**: Keep code and docs in separate commits and include the commit hash in task notes.

## Tests To Run

- Style suite (always after moves/renames):
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true`
- QB / Scene Director suites:
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/qb -ginclude_subdirs=true`
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/scene_director -ginclude_subdirs=true`
  - `tools/run_gut_suite.sh -gdir=res://tests/integration/scene_director -ginclude_subdirs=true`
- Display suites:
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/managers -ginclude_subdirs=true`
  - `tools/run_gut_suite.sh -gdir=res://tests/integration/display -ginclude_subdirs=true`
- State suites:
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/state -ginclude_subdirs=true`

## Baseline Results (2026-02-26)

- Style baseline (`tests/unit/style`): 11/12 passed; 1 failure in `test_production_paths_have_no_spaces` from orphan `* 2.gd.uid` files (tracked in Phase 1A task list).
- QB baseline (`tests/unit/qb`): 151/151 passed.
- Scene Director baseline:
  - Unit (`tests/unit/scene_director`): 97/97 passed.
  - Integration (`tests/integration/scene_director`): 4/4 passed.
- Display baseline:
  - Unit managers (`tests/unit/managers`): 378/378 passed.
  - Integration (`tests/integration/display`): 40/41 passed with 1 pending (`UIOverlayStack` unavailable in test environment), no failures.
- Known non-failing environment warning: `get_system_ca_certificates` appears at suite startup on macOS.

## Phase 1 Results (2026-02-26)

- Removed all 11 orphaned `* 2.gd.uid` files from the working tree.
- Moved `u_post_process_layer.gd` to `scripts/managers/helpers/display/` and updated preload references.
- Renamed debug helper to `scripts/debug/debug_extract_touchscreen_settings.gd`.
- Implementation commit: `bf3df98` (`refactor(cleanup-v6): move misplaced helper and debug scripts`).
- Validation:
  - `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import` (pass; non-failing ObjectDB leak warning at exit)
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` (12/12 passed)

## Phase 2A Results (2026-02-26)

- Typed Scene Director runner state:
  - `m_scene_director.gd`: `_beat_runner` is now `U_BeatRunner` (removed runner `has_method(...)` checks).
  - `u_beat_runner.gd`: `_parallel_runners` is now `Array[U_BeatRunner]` (removed runner `has_method(...)` checks in signal/parallel update paths).
- Remaining `has_method(...)` calls are intentional polymorphism guards for condition/effect resources (`evaluate`/`execute`) on `Array[Resource]` contracts.
- Implementation commit: `c6f2085` (`refactor(scene-director): remove runner duck typing guards`).
- Validation:
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/scene_director -ginclude_subdirs=true` (97/97 passed)
  - `tools/run_gut_suite.sh -gdir=res://tests/integration/scene_director -ginclude_subdirs=true` (4/4 passed)

## Phase 2B Results (2026-02-26)

- Added interfaces:
  - `scripts/interfaces/i_objectives_manager.gd`
  - `scripts/interfaces/i_scene_director.gd`
  - `scripts/interfaces/i_run_coordinator.gd`
- Updated managers to extend interfaces (`M_ObjectivesManager`, `M_SceneDirector`, `M_RunCoordinator`).
- Removed `has_method("reset_for_new_run")` guard from `M_RunCoordinator` and switched to typed `I_ObjectivesManager` lookup before invoking `reset_for_new_run(...)`.
- Updated run coordinator unit-test stub to implement `I_ObjectivesManager`.
- Implementation commit: `13c65f2` (`refactor(scene-director): add manager interfaces and typed objectives lookup`).
- Validation:
  - `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import` (pass; required after adding interface `class_name` scripts)
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` (12/12 passed)
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/scene_director -ginclude_subdirs=true` (97/97 passed)
  - `tools/run_gut_suite.sh -gdir=res://tests/integration/scene_director -ginclude_subdirs=true` (4/4 passed)
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/qb -ginclude_subdirs=true` (151/151 passed)

## Phase 3A Results (2026-02-26)

- Renamed `class_name RuleStateTracker` → `U_RuleStateTracker` in `scripts/utils/qb/u_rule_state_tracker.gd`.
- Updated all three consumers: `s_camera_state_system.gd`, `s_character_state_system.gd`, `s_game_event_system.gd`.
- Updated two stale AGENTS.md references (QB v2 patterns section).
- Implementation commit: `85c50057` (`refactor(qb): rename RuleStateTracker class to U_RuleStateTracker`).
- No headless import required (no file moves or new `class_name` scripts added, only class_name value changed).

## Phase 3B/3C/3D Results (2026-02-26)

- Renamed four managers with `_manager` suffix (Phase 3B):
  - `M_RunCoordinator` → `M_RunCoordinatorManager` (`m_run_coordinator_manager.gd`)
  - `M_SceneDirector` → `M_SceneDirectorManager` (`m_scene_director_manager.gd`)
  - `M_GameplayInitializer` → `M_GameplayInitializerManager` (`m_gameplay_initializer_manager.gd`)
  - `M_ScreenshotCache` → `M_ScreenshotCacheManager` (`m_screenshot_cache_manager.gd`)
  - Updated: class_name declarations, preload paths in 5 test files, path+node-name in 6 scenes, `root.gd` ServiceLocator strings, style enforcement test, interface doc comments, inline warning prefixes, doc comments in 3 scripts.
- Added `tmpl_*.tscn` row to STYLE_GUIDE.md scene naming table (Phase 3C).
- Added `scripts/core/` to STYLE_GUIDE.md directory tree (Phase 3C).
- Implementation commit: `e37bfd68` (`refactor(cleanup-v6): add _manager suffix to four manager classes (phase 3b)`).
- Validation (Phase 3D):
  - `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import` (pass)
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` (12/12 passed)
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/scene_director -ginclude_subdirs=true` (97/97 passed)
  - `tools/run_gut_suite.sh -gdir=res://tests/integration/scene_director -ginclude_subdirs=true` (4/4 passed)
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/qb -ginclude_subdirs=true` (151/151 passed)

## Phase 4 Results (2026-02-26)

- Removed `_is_post_processing_enabled()` dead method from `u_display_post_process_applier.gd` (no callers).
- Removed `_load_preset_resources()` dead method from `u_display_option_catalog.gd` (mobile-unsafe DirAccess, superseded by const preloads).
- Created `scripts/utils/scene_director/u_objectives_debug_tracer.gd` (`U_ObjectivesDebugTracer`) — extracts ~143 lines of debug infrastructure from `m_objectives_manager.gd`, including `_debug_log`/`_debug_gameplay_slice`/`_debug_objectives_slice`/`_emit_startup_signature`/`_debug_log_config_snapshot` plus `_describe_condition`/`_resource_script_path` support helpers. Private `_resource_get`/`_to_string_name`/`_to_resource_array` duplicated pending Phase 5B shared extraction.
- Updated manager to delegate all debug calls through `U_OBJECTIVES_DEBUG_TRACER`.
- Implementation commit: `d3340d4f` (`refactor(cleanup-v6): remove dead methods and extract objectives debug tracer (phase 4)`).
- **New pitfall discovered**: `log()` is a GDScript built-in (natural logarithm) — cannot be used as a static method name. Used `debug_log()` instead. Documented in DEV_PITFALLS.md.
- Validation:
  - `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import` (pass)
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/scene_director -ginclude_subdirs=true` (97/97 passed)
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/managers -ginclude_subdirs=true` (378/378 passed)
  - `tools/run_gut_suite.sh -gdir=res://tests/integration/display -ginclude_subdirs=true` (40/41 passed, 1 pending pre-existing)

## Phase 5 Results (2026-02-26)

### 5A — Display Applier `_get_tree()` Consolidation

- Created `scripts/utils/display/u_display_applier_utils.gd` (`U_DisplayApplierUtils`) with `get_tree_safe(owner: Node) -> SceneTree`.
- Removed duplicated `_get_tree()` from all 4 appliers; replaced 5 call sites with `U_DisplayApplierUtils.get_tree_safe(_owner)`.
- Implementation commit: `4387cdd8` (`refactor(cleanup-v6): extract duplicated _get_tree() into U_DisplayApplierUtils (phase 5a)`).
- Validation:
  - `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import` (pass)
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/managers -ginclude_subdirs=true` (378/378 passed)
  - `tools/run_gut_suite.sh -gdir=res://tests/integration/display -ginclude_subdirs=true` (40/41 passed, 1 pending pre-existing)

### 5B — Scene Director Resource Access Helpers

- Created `scripts/utils/scene_director/u_resource_access_helpers.gd` (`U_ResourceAccessHelpers`) with 5 static helpers: `resource_get`, `to_resource_array`, `to_float`, `to_int`, `to_string_name`.
- Removed duplicated private methods from `m_scene_director_manager.gd`, `u_beat_runner.gd`, `m_objectives_manager.gd`, and `u_objectives_debug_tracer.gd`; updated all call sites.
- Kept `_to_wait_mode` and `_to_string_name_array` in `u_beat_runner.gd` — specific to beat runner logic.
- Removed the "duplicated pending Phase 5B" comment block from `u_objectives_debug_tracer.gd`.
- Implementation commit: `43804ade` (`refactor(cleanup-v6): extract shared resource helpers into U_ResourceAccessHelpers (phase 5b)`).
- Validation:
  - `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import` (pass)
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/scene_director -ginclude_subdirs=true` (97/97 passed)
  - `tools/run_gut_suite.sh -gdir=res://tests/integration/scene_director -ginclude_subdirs=true` (4/4 passed)
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/managers -ginclude_subdirs=true` (378/378 passed)
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` (12/12 passed)

## Phase 6 Results (2026-02-26)

- Replaced `String(value)` with `str(value)` in 6 files (48 occurrences total): `u_display_selectors.gd`, `u_display_reducer.gd`, `u_display_option_catalog.gd`, `u_global_settings_applier.gd`, `ui_display_settings_tab.gd`, `u_display_quality_applier.gd`.
- Fixed `rs_display_initial_state.gd` dither pattern mismatch: `@export_enum("bayer", "blue_noise")` → `@export_enum("bayer", "noise")` to match the catalog's valid ID `"noise"`.
- Implementation commit: `2aba797d` (`refactor(cleanup-v6): replace String() coercions with str() and fix dither enum mismatch (phase 6)`).
- Validation:
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/managers -ginclude_subdirs=true` (378/378 passed)
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/state -ginclude_subdirs=true` (365/365 passed)
  - `tools/run_gut_suite.sh -gdir=res://tests/integration/display -ginclude_subdirs=true` (40/41 passed, 1 pending pre-existing)

## Notes / Pitfalls

- After moving `.tscn` or `class_name` scripts, run a headless import to refresh UID/script caches:
  - `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import`
- `RuleStateTracker` class name in `u_rule_state_tracker.gd` — confirmed: rename to `U_RuleStateTracker` and update AGENTS.md.
- Hardcoded game-specific IDs (`"bar_complete"`, `"final_complete"`, `"alleyway"`, `"bar"`) exist in template managers — flag for extraction but may be deferred if game-specific config system is not yet designed.
- `rs_display_initial_state.gd` has `@export_enum("bayer", "blue_noise")` but catalog uses ID `"noise"` — potential mismatch to verify.
- Missing initial state `.tres` for objectives and scene director slices — other slices all have wired resources in `root.tscn`, these two fall through to `== null` code path.
- `scripts/core/` exists and is tested but not listed in STYLE_GUIDE.md directory tree.
- `tmpl_*.tscn` prefix is established but not in STYLE_GUIDE.md scene naming table.
