# cleanup_v6 Tasks

## Scope / Goals

- Bring all code added after cleanup_v5 (QB v2, Scene Director, cinema grading, color blind, post-processing presets, global settings persistence) up to the quality bar established by cleanups v1–v5.
- Eliminate new duck typing, add missing interfaces, fix naming violations, remove dead code, extend test enforcement, and clean up stale docs.

## Constraints (Non-Negotiable)

- Do not start implementation while the working tree is in an unknown/dirty state.
- Keep commits small and test-green.
- Commit documentation updates separately from implementation changes.
- After any file move/rename or scene/resource structure change, run `tests/unit/style/test_style_enforcement.gd`.

## Phase 0 — Baseline & Inventory (Read-Only)

- [x] Confirm style baseline:
  - Run: `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true`
- [x] Confirm QB test baseline:
  - Run: `tools/run_gut_suite.sh -gdir=res://tests/unit/qb -ginclude_subdirs=true`
- [x] Confirm Scene Director test baseline:
  - Run: `tools/run_gut_suite.sh -gdir=res://tests/unit/scene_director -ginclude_subdirs=true`
  - Run: `tools/run_gut_suite.sh -gdir=res://tests/integration/scene_director -ginclude_subdirs=true`
- [x] Confirm display test baseline:
  - Run: `tools/run_gut_suite.sh -gdir=res://tests/unit/managers -ginclude_subdirs=true`
  - Run: `tools/run_gut_suite.sh -gdir=res://tests/integration/display -ginclude_subdirs=true`
- [x] Record baseline results and any pre-existing failures in this document.
  - Baseline run date: 2026-02-26.
  - Style baseline: 11/12 passed, 1 failed (`test_production_paths_have_no_spaces`) due to 4 orphaned files with spaces:
    - `res://scripts/resources/qb/conditions/rs_condition_composite 2.gd.uid`
    - `res://scripts/managers/m_run_coordinator 2.gd.uid`
    - `res://scripts/utils/scene_director/u_beat_graph 2.gd.uid`
    - `res://scripts/state/actions/u_run_actions 2.gd.uid`
  - QB baseline: 151/151 passed.
  - Scene Director baseline: unit 97/97 passed; integration 4/4 passed.
  - Display baseline: unit/managers 378/378 passed; integration/display 40/41 passed with 1 pending (`test_ui_color_blind_layer_has_higher_layer_than_ui_overlay` pending due to missing `UIOverlayStack` in test environment).
  - Environmental warnings observed (non-failing): macOS CA certificate warning (`get_system_ca_certificates`) appears at suite startup.

## Phase 1 — Orphaned Files & Filesystem Cleanup (Low Risk)

### 1A — Delete Orphaned UID Artifacts

- [ ] Delete 11 orphaned `* 2.gd.uid` files:
  - `scripts/managers/m_run_coordinator 2.gd.uid`
  - `scripts/utils/scene_director/u_beat_graph 2.gd.uid`
  - `scripts/state/actions/u_run_actions 2.gd.uid`
  - `scripts/resources/qb/conditions/rs_condition_composite 2.gd.uid`
  - `tests/unit/scene_director/test_beat_graph 2.gd.uid`
  - `tests/unit/scene_director/test_run_coordinator 2.gd.uid`
  - `tests/unit/scene_director/test_victory_migration 2.gd.uid`
  - `tests/unit/qb/test_condition_composite 2.gd.uid`
  - `tests/unit/qb/test_game_event_system 2.gd.uid`
  - `tests/integration/scene_director/test_objectives_integration 2.gd.uid`
  - `tests/integration/scene_director/test_scene_director_integration 2.gd.uid`

### 1B — Move Misplaced Files

- [ ] Move `scripts/managers/helpers/u_post_process_layer.gd` → `scripts/managers/helpers/display/u_post_process_layer.gd` and update all references.
- [ ] Rename `scripts/debug/extract_touchscreen_settings.gd` → `scripts/debug/debug_extract_touchscreen_settings.gd` and update all references (class name if applicable).

### 1C — Validate

- [ ] Run headless import after moves/renames.
- [ ] Run style tests.

## Phase 2 — Duck Typing Removal (Medium Risk)

### 2A — Type `_beat_runner` and `_parallel_runners`

- [ ] In `scripts/managers/m_scene_director.gd`: change `var _beat_runner: Variant = null` → `var _beat_runner: U_BeatRunner = null`. Remove the 4 `has_method()` guards that this fixes (lines ~371, 378, 394, 402).
- [ ] In `scripts/utils/scene_director/u_beat_runner.gd`: change `var _parallel_runners: Array = []` → `var _parallel_runners: Array[U_BeatRunner] = []`. Remove the 4 `has_method()` guards in `_update_parallel()` and `on_signal_received()` (lines ~125, 198, 200, 202).
- [ ] Verify the remaining `has_method("evaluate")` and `has_method("execute")` calls on condition/effect resources are justified (polymorphic `Array[Resource]` contract). Document as accepted.
- [ ] Run Scene Director tests.

### 2B — Add Missing Interfaces

- [ ] Create `scripts/interfaces/i_objectives_manager.gd` (`I_ObjectivesManager`) — extract public API from `M_ObjectivesManager`.
- [ ] Update `M_ObjectivesManager` to extend `I_ObjectivesManager`.
- [ ] Remove `has_method("reset_for_new_run")` guard in `scripts/managers/m_run_coordinator.gd` (line ~106) — use typed interface lookup instead.
- [ ] Create `scripts/interfaces/i_scene_director.gd` (`I_SceneDirector`) — extract public API from `M_SceneDirector`.
- [ ] Update `M_SceneDirector` to extend `I_SceneDirector`.
- [ ] Create `scripts/interfaces/i_run_coordinator.gd` (`I_RunCoordinator`) — extract public API from `M_RunCoordinator`.
- [ ] Update `M_RunCoordinator` to extend `I_RunCoordinator`.
- [ ] Run Scene Director and QB tests.

## Phase 3 — Naming & Prefix Fixes (Medium Risk)

### 3A — Class Name Fixes

- [ ] Rename class `RuleStateTracker` → `U_RuleStateTracker` in `scripts/utils/qb/u_rule_state_tracker.gd`.
- [ ] Update all references to the renamed class.
- [ ] Update AGENTS.md reference from `RuleStateTracker` to `U_RuleStateTracker`.

### 3B — Manager Suffix Convention (Decision: Rename All Four)

- [ ] Rename `m_run_coordinator.gd` → `m_run_coordinator_manager.gd` / class `M_RunCoordinator` → `M_RunCoordinatorManager`. Update all references.
- [ ] Rename `m_scene_director.gd` → `m_scene_director_manager.gd` / class `M_SceneDirector` → `M_SceneDirectorManager`. Update all references.
- [ ] Rename `m_gameplay_initializer.gd` → `m_gameplay_initializer_manager.gd` / class `M_GameplayInitializer` → `M_GameplayInitializerManager`. Update all references.
- [ ] Rename `m_screenshot_cache.gd` → `m_screenshot_cache_manager.gd` / class `M_ScreenshotCache` → `M_ScreenshotCacheManager`. Update all references.
- [ ] Run headless import after renames.

### 3C — STYLE_GUIDE.md Gaps

- [ ] Add `tmpl_*.tscn` row to the scene naming table in STYLE_GUIDE.md (templates already follow this but it's undocumented).
- [ ] Add `scripts/core/` to the directory tree in STYLE_GUIDE.md (exists, has enforcement test, but not documented).

### 3D — Validate

- [ ] Run style tests and QB/Scene Director tests.

## Phase 4 — Dead Code & Debug Cruft Removal (Low Risk)

- [ ] Remove `_is_post_processing_enabled()` dead method from `scripts/managers/helpers/display/u_display_post_process_applier.gd` (lines ~131–140).
- [ ] Remove `_load_preset_resources()` dead method from `scripts/utils/display/u_display_option_catalog.gd` (lines ~204–223) — mobile-unsafe `DirAccess` code superseded by const preloads.
- [ ] Extract `m_objectives_manager.gd` debug infrastructure to a separate helper:
  - Move `DEBUG_VICTORY_TRACE`, `DEBUG_SIGNATURE`, `_emit_startup_signature()`, `_debug_log_config_snapshot()`, `_debug_gameplay_slice()`, `_debug_objectives_slice()` (~100 lines) → new `scripts/utils/scene_director/u_objectives_debug_tracer.gd`.
  - Update `m_objectives_manager.gd` to delegate debug calls to the tracer.
- [ ] Run display and Scene Director tests.

## Phase 5 — Extract Duplicated Helpers (Medium Risk)

### 5A — Display Applier `_get_tree()` Consolidation

- [ ] Create `scripts/utils/display/u_display_applier_utils.gd` with a static `get_tree_safe(owner: Node) -> SceneTree` function.
- [ ] Replace the duplicated `_get_tree()` method in all 4 appliers with a call to the static utility:
  - `u_display_post_process_applier.gd`
  - `u_display_cinema_grade_applier.gd`
  - `u_display_window_applier.gd`
  - `u_display_quality_applier.gd`

### 5B — Scene Director Resource Access Helpers

- [ ] Extract duplicated `_to_int`, `_to_float`, `_to_string_name`, `_to_resource_array`, `_resource_get` methods shared between `m_scene_director.gd` and `u_beat_runner.gd` into a shared utility (e.g., `scripts/utils/scene_director/u_resource_access_helpers.gd`).
- [ ] Update both files to use the shared utility.
- [ ] Run Scene Director and display tests.

## Phase 6 — `String(value)` → `str(value)` Migration (Low Risk)

- [ ] Replace `String(value)` with `str(value)` for Variant→String coercion in:
  - `scripts/state/selectors/u_display_selectors.gd` (~6 occurrences)
  - `scripts/state/reducers/u_display_reducer.gd` (~8 occurrences)
  - `scripts/utils/display/u_display_option_catalog.gd` (~13 occurrences)
  - `scripts/state/utils/u_global_settings_applier.gd` (~5 occurrences)
  - `scripts/ui/settings/ui_display_settings_tab.gd` (~14 occurrences)
  - `scripts/managers/helpers/display/u_display_quality_applier.gd` (~2 occurrences)
- [ ] Verify `rs_display_initial_state.gd` `@export_enum("bayer", "blue_noise")` vs catalog ID `"noise"` — fix mismatch if confirmed.
- [ ] Run display and state tests.

## Phase 7 — Style Enforcement Expansion (Low Risk)

- [ ] Add missing directories to `GD_DIRECTORIES` (tab check) in `tests/unit/style/test_style_enforcement.gd`:
  - `scripts/resources/qb/`
  - `scripts/resources/qb/conditions/`
  - `scripts/resources/qb/effects/`
  - `scripts/resources/scene_director/`
  - `scripts/resources/ecs/`
  - `scripts/resources/display/`
  - `scripts/resources/localization/`
  - `scripts/debug/`
- [ ] Add corresponding entries to `SCRIPT_PREFIX_RULES` for prefix enforcement.
- [ ] Run style tests — fix any newly-caught violations.

## Phase 8 — Missing Initial State Resources (Low Risk)

- [ ] Create `resources/state/cfg_default_objectives_initial_state.tres` (instance of `RS_ObjectivesInitialState`).
- [ ] Create `resources/state/cfg_default_scene_director_initial_state.tres` (instance of `RS_SceneDirectorInitialState`).
- [ ] Wire both exports in `scenes/root.tscn` on the `M_StateStore` node (consistent with all other slices).
- [ ] Verify `u_state_slice_manager.gd` handles the wired resources correctly (should already work — the `== null` fallback just becomes unused).
- [ ] Run state and Scene Director tests.

## Phase 9 — Stale Documentation Cleanup (Low Risk)

- [ ] Fix `docs/display_manager/display-manager-tasks.md`:
  - Update progress header (line 3) to reflect actual completion count.
  - Mark or remove stale outline feature test references (tasks 0A.1, 0B.1).
  - Mark or remove stale LUT file entries in "Files to Create" table (lines ~794–817).
  - Check off Phase 9 Task 9.2 "Update AGENTS.md" (already done).
- [ ] Review `docs/scene_director/` docs for stale status references.
- [ ] Review `docs/qb/` docs for stale status references.

## Phase 10 — Large File Audit (Medium Risk, May Defer)

- [ ] `m_objectives_manager.gd` (783 lines) — evaluate whether debug infrastructure extraction (Phase 4) brings it under threshold, or if further helper extraction is needed.
- [ ] `m_scene_director.gd` (485 lines) — evaluate whether resource access helper extraction (Phase 5B) brings it under threshold.
- [ ] Flag any remaining files over 400 lines for future consideration.

## Phase 11 — Cinema Grading Test Coverage (Medium Risk)

- [ ] Add unit tests for `U_CinemaGradeRegistry` (scene→grade mapping, neutral fallback, preload safety).
- [ ] Add unit tests for `U_CinemaGradeSelectors` (all selector functions with defaults).
- [ ] Add integration test for cinema grade applier (scene swap triggers grade change).
- [ ] Run display test suites.

## Phase 12 — Final Validation

- [ ] Run full style suite: `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true`
- [ ] Run full QB suite: `tools/run_gut_suite.sh -gdir=res://tests/unit/qb -ginclude_subdirs=true`
- [ ] Run full Scene Director suite: `tools/run_gut_suite.sh -gdir=res://tests/unit/scene_director -ginclude_subdirs=true`
- [ ] Run Scene Director integration: `tools/run_gut_suite.sh -gdir=res://tests/integration/scene_director -ginclude_subdirs=true`
- [ ] Run display suites: `tools/run_gut_suite.sh -gdir=res://tests/unit/managers -ginclude_subdirs=true` and `tools/run_gut_suite.sh -gdir=res://tests/integration/display -ginclude_subdirs=true`
- [ ] Run headless import: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import`
- [ ] Record final status in continuation prompt.

## Notes

- Hardcoded game-specific IDs (`"bar_complete"`, `"final_complete"`, `RETRY_SCENE_ID = "alleyway"`, `required_final_area = "bar"`) in template managers are noted but deferred — extracting to a game config system is a feature, not cleanup.
- The `condition.has_method("evaluate")` / `effect.has_method("execute")` pattern on `Array[Resource]` is considered justified polymorphism (documented in AGENTS.md).
- Pre-existing interface gaps (`M_CursorManager`, `M_SpawnManager`, `M_GameplayInitializer`, `M_ScreenshotCache`, `M_UIInputHandler`) are out of scope for v6 — only new managers are targeted.
