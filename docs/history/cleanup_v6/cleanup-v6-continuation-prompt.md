# cleanup_v6 Continuation Prompt

## Current Status

- Phase: **Complete** (All phases 0–14 done).
- Branch: `cleanup-v6`.
- Working tree: clean.
- Next step: PR to main.

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
- `docs/guides/DEV_PITFALLS.md` — known gotchas (imports, class cache, UI pitfalls).
- `docs/guides/STYLE_GUIDE.md` — naming, formatting, prefix rules.
- `docs/history/cleanup_v6/cleanup-v6-tasks.md` — the task checklist.
- `docs/history/cleanup_v5/cleanup-v5-continuation-prompt.md` — prior cleanup patterns.

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

## Phase 7 Results (2026-02-26)

- Added 8 directories to `GD_DIRECTORIES` (tab check): `scripts/resources/qb`, `qb/conditions`, `qb/effects`, `scripts/resources/scene_director`, `scripts/resources/ecs`, `scripts/resources/display`, `scripts/resources/localization`, `scripts/debug`.
- Added 8 `SCRIPT_PREFIX_RULES` entries: all `rs_` for resource dirs, `debug_` for `scripts/debug`.
- No newly-caught violations — all files were already conforming.
- Implementation commit: `9969588b` (`refactor(cleanup-v6): expand style enforcement to qb/scene_director/ecs/display/debug dirs (phase 7)`).
- Validation: `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` (12/12 passed)

## Phase 8 Results (2026-02-26)

- Created `resources/state/cfg_default_objectives_initial_state.tres` — instance of `RS_ObjectivesInitialState` with all-default fields (empty statuses dict, blank active_set_id, empty event_log).
- Created `resources/state/cfg_default_scene_director_initial_state.tres` — instance of `RS_SceneDirectorInitialState` with all-default fields (idle state, index -1, empty IDs).
- Added ext_resource entries `42_objectives_state` and `43_scene_director_state` to `root.tscn`.
- Wired `objectives_initial_state` and `scene_director_initial_state` on `M_StateStore` node. The `== null` fallback paths in `u_state_slice_manager.gd` are now unused but harmlessly unreachable.
- Implementation commit: `c2d869d8` (`refactor(cleanup-v6): create and wire missing objectives/scene_director initial state resources (phase 8)`).
- Validation:
  - `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import` (pass)
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/state -ginclude_subdirs=true` (365/365 passed)
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/scene_director -ginclude_subdirs=true` (97/97 passed)

## Phase 9 Results (2026-02-26)

- `docs/display_manager/display-manager-tasks.md`:
  - Progress header updated: "43% (35/81)" → "~91% (84/92)".
  - Removed stale outline sub-bullets from tasks 0A.1 and 0B.1 (feature dropped, never wired to state).
  - Removed stale LUT rows from "Files to Create" table (`rs_lut_definition.gd`, `sh_lut_shader.gdshader`, and all `resources/luts/` entries). LUT system was replaced by cinema grading.
  - Marked Task 9.2 as done (Display Manager Patterns section already in AGENTS.md).
- `docs/scene_director/scene-director-continuation-prompt.md`: corrected branch ("scene-director" → "main"), updated test counts to cleanup-v6 baseline (151/151 QB, 97/97 scene_director).
- `docs/qb/` — does not exist; no-op.
- Implementation commit: `18bb9da0` (`docs(cleanup-v6): clean up stale display/scene_director docs (phase 9)`).

## Phase 10 Results (2026-02-26)

- `m_objectives_manager.gd`: Phase 4 reduced it from 783 → 624 lines. Still 224 lines over the 400-line threshold. All remaining code is functional (set loading, objective lifecycle, event dispatch, state sync); no clean split without over-engineering. Flagged as monitored.
- `m_scene_director_manager.gd`: Phase 5B reduced it from 485 → 448 lines. 48 lines over threshold. Functionally dense (beat runner orchestration, directive selection, state sync); no clean split. Flagged as monitored.
- Shared pattern identified for future extraction: `_resolve_store`/`_set_store_reference`/`_ensure_store_action_signal_connection`/`_disconnect_store_action_signal` (~65 lines) is duplicated between both managers. Deferred — low value at current size, tight coupling.
- Pre-existing files over 400 lines (out of v6 scope) flagged in tasks checklist for future cleanup consideration. Largest: `m_scene_manager.gd` (1148), `ui_display_settings_tab.gd` (809), `ui_save_load_menu.gd` (751), `m_save_manager.gd` (742).
- No code changes; no commit needed.

## Phase 11 Results (2026-02-26)

- Created `tests/unit/managers/test_color_grading_registry.gd` — 14 tests: known scene lookup (all 5 preloaded scenes), neutral fallback (scene_id="_neutral", default exposure/contrast/saturation), empty scene_id, `to_dictionary()` key validity, re-initialize safety.
- Created `tests/unit/managers/test_color_grading_selectors.gd` — 22 tests: all 13 selector defaults, read-from-state for representative fields, `get_color_grading_settings` key filtering, graceful handling of missing/non-dict display slice.
- Created `tests/integration/display/test_color_grading_applier.gd` — 11 tests: CinemaGradeLayer created under PostProcessOverlay, `scene/swapped` loads alleyway grade (filter_mode=6, exposure=-0.18, contrast=1.23 via both state selectors and shader uniforms), unknown scene falls back to neutral (filter_mode=0, exposure=0.0, state still populated).
- **New pitfall**: GUT treats "Variant inference" warning as a parse error — `var x := helper()` where `helper()` returns `Variant` fails to load. Use `var x: Variant = helper()` instead. Documented in DEV_PITFALLS.md.
- Implementation commit: `357165a9`.
- Validation:
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/managers -ginclude_subdirs=true` (414/414 passed)
  - `tools/run_gut_suite.sh -gdir=res://tests/integration/display -ginclude_subdirs=true` (51/52 passed, 1 pending pre-existing)
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` (12/12 passed)

## Phase 12 Results (2026-02-26)

Final validation run — all suites green:

| Suite | Result |
|---|---|
| Style (`tests/unit/style`) | 12/12 passed |
| QB (`tests/unit/qb`) | 151/151 passed |
| Scene Director unit (`tests/unit/scene_director`) | 97/97 passed |
| Scene Director integration (`tests/integration/scene_director`) | 4/4 passed |
| Unit managers (`tests/unit/managers`) | 414/414 passed |
| Integration display (`tests/integration/display`) | 51/52 passed, 1 pending (pre-existing) |
| Headless import | pass (non-failing ObjectDB leak at exit) |

cleanup_v6 is complete. All goals achieved — duck typing removed, interfaces added, naming violations fixed, dead code removed, shared utilities extracted, style enforcement expanded, initial state resources wired, stale docs cleaned, and cinema grading test coverage added.

## Phase 13 Results (2026-02-27)

### 13A — Stale Documentation Fixes

- Fixed AGENTS.md: `m_run_coordinator.gd` → `m_run_coordinator_manager.gd` (line 31).
- Annotated resolved Notes/Pitfalls items with their resolution phases; removed open-item framing.

### 13B — Cinema Grade Reducer Test Coverage

- Added Tests 29–38 to `tests/unit/state/test_display_reducer.gd`:
  - `ACTION_SET_PARAMETER`: dramatic→mode 1, vivid_cold→mode 6, none→mode 0, unknown→mode 0 fallback, filter_intensity direct store, generic param as `color_grading_` key, empty param_name returns null.
  - `ACTION_RESET_TO_SCENE_DEFAULTS`: color_grading_ keys applied, non-color_grading keys ignored, empty payload returns null.
- State suite: 375/375 passed (+10 from baseline 365).

### 13C — Broader `String()` → `str()` Audit

- Audited 80 files with `String(` calls. Findings:
  - Vast majority are `String(StringName)`, `String(int)`, `String(NodePath)` — all legitimate.
  - One clear v6-scope violation: `u_objectives_debug_tracer.gd:128–131` called `String(resource_get(...))` where `resource_get` returns `Variant`. Fixed to `str(...)`.
  - Pre-existing patterns in save manager, input reducer, HUD controller, etc. are out of v6 scope.

### 13D — Store Resolver Duplication

- Created `scripts/utils/scene_director/u_store_action_binder.gd` (`U_StoreActionBinder extends RefCounted`).
  - Methods: `resolve(exported_store, owner_node, callback)`, `ensure_connection(callback)`, `disconnect_signal(callback)`, `_set_store(next_store, callback)`.
  - Contains `STORE_SERVICE_NAME`, `U_SERVICE_LOCATOR`, `U_STATE_UTILS` (removed from both managers).
- Both managers updated: `var _store` → getter property, `var _store_action_connected` → removed, 4 private methods → removed, call sites → binder calls.

### 13E — Final Validation

| Suite | Result |
|---|---|
| Style (`tests/unit/style`) | 12/12 passed |
| QB (`tests/unit/qb`) | 151/151 passed |
| Scene Director unit | 97/97 passed |
| Scene Director integration | 4/4 passed |
| Unit managers | 414/414 passed |
| State unit | 375/375 passed |
| Integration display | 51/52 passed, 1 pending (pre-existing) |
| Headless import | pass (non-failing ObjectDB leak at exit) |

Implementation commit: `b888ba27`.

## Phase 14 Results (2026-02-27)

### 14A — I_Condition / I_Effect Interfaces

- Created `scripts/interfaces/i_condition.gd` (`I_Condition extends Resource`) with `evaluate(context) -> float` (actual return type is `float`, not `bool` as task description stated).
- Created `scripts/interfaces/i_effect.gd` (`I_Effect extends Resource`) with `execute(context) -> void`.
- `RS_BaseCondition` and `RS_BaseEffect` now extend their interfaces.
- Replaced all 11 `has_method("evaluate")`/`has_method("execute")` guards across: `rs_condition_composite` (2), `m_scene_director_manager` (1), `m_objectives_manager` (2), `u_beat_runner` (2), `u_rule_scorer` (1), `s_game_event_system` (1), `s_character_state_system` (1), `s_camera_state_system` (1).
- Updated 5 test files' stubs to extend `I_Condition`/`I_Effect` instead of `Resource`.
- Implementation commit: `3ce45068`.

### 14B — RS_GameConfig Resource

- Created `scripts/resources/rs_game_config.gd` (`RS_GameConfig`) with `retry_scene_id`, `route_retry`, `default_objective_set_id`.
- Created `resources/cfg_game_config.tres` with default values.
- Added `@export var game_config: RS_GameConfig` to both managers; wired in `root.tscn` (id `44_game_config`).
- Removed `RETRY_SCENE_ID`, `ROUTE_RETRY_ALLEYWAY`, `OBJECTIVE_SET_DEFAULT` consts from `M_RunCoordinatorManager`. Simplified redundant match block.
- `"bar_complete"`/`"final_complete"` debug check strings left in-place (debug-only, not functional consts). `required_final_area` in `s_victory_handler_system.gd` is already an `@export var`.
- Implementation commit: `8a4c22f6`.

### 14C — Manager Interfaces

- Created 5 interfaces: `I_CursorManager`, `I_SpawnManager`, `I_ScreenshotCacheManager`, `I_GameplayInitializerManager` (marker), `I_UIInputHandler` (marker).
- Updated all 5 managers to extend their interfaces.
- Consumer updates: `M_SceneManager` → `I_CursorManager`/`I_SpawnManager`; `M_TimeManager` → `I_CursorManager`; `M_SaveManager` → `I_ScreenshotCacheManager` + removed `has_method("get_cached_screenshot")` guard; `M_GameplayInitializerManager` → `I_SpawnManager`.
- Implementation commit: `01789d85`.

### 14D — Final Validation

| Suite | Result |
|---|---|
| Style (`tests/unit/style`) | 12/12 passed |
| QB (`tests/unit/qb`) | 151/151 passed |
| Scene Director unit | 97/97 passed |
| Scene Director integration | 4/4 passed |
| Unit managers | 414/414 passed |
| State unit | 375/375 passed |
| Integration display | 51/52 passed, 1 pending (pre-existing) |
| Headless import | pass (non-failing ObjectDB leak at exit) |

cleanup_v6 is fully complete including all deferred Phase 14 items.

## Notes / Pitfalls

- After moving `.tscn` or `class_name` scripts, run a headless import to refresh UID/script caches:
  - `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import`

Previously open items now resolved:

- `RuleStateTracker` → `U_RuleStateTracker` (Phase 3A).
- `rs_display_initial_state.gd` dither enum mismatch (`"blue_noise"` → `"noise"`) (Phase 6).
- Missing initial state `.tres` for objectives/scene director slices (Phase 8).
- `scripts/core/` not in STYLE_GUIDE.md directory tree (Phase 3C).
- `tmpl_*.tscn` prefix not in STYLE_GUIDE.md scene naming table (Phase 3C).
- Hardcoded game-specific IDs in run coordinator → `RS_GameConfig` (Phase 14B).
- `has_method("evaluate")`/`has_method("execute")` guards → `is I_Condition`/`is I_Effect` (Phase 14A).
- `has_method("get_cached_screenshot")` in save manager → typed `I_ScreenshotCacheManager` (Phase 14C).
