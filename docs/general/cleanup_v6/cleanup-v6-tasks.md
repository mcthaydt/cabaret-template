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

- [x] Delete 11 orphaned `* 2.gd.uid` files:
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
  - Completion notes: Removed all 11 orphan files from working tree (these artifacts were untracked). Style path-space failure cleared after removal.

### 1B — Move Misplaced Files

- [x] Move `scripts/managers/helpers/u_post_process_layer.gd` → `scripts/managers/helpers/display/u_post_process_layer.gd` and update all references.
- [x] Rename `scripts/debug/extract_touchscreen_settings.gd` → `scripts/debug/debug_extract_touchscreen_settings.gd` and update all references (class name if applicable).
  - Completion notes: Implemented in commit `bf3df98` (`refactor(cleanup-v6): move misplaced helper and debug scripts`). Updated preload references in display applier and display integration tests; updated display manager docs path references.

### 1C — Validate

- [x] Run headless import after moves/renames.
- [x] Run style tests.
  - Validation notes (2026-02-26):
    - `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import` (pass; non-failing ObjectDB leak warning at exit)
    - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` (12/12 passed)

## Phase 2 — Duck Typing Removal (Medium Risk)

### 2A — Type `_beat_runner` and `_parallel_runners`

- [x] In `scripts/managers/m_scene_director.gd`: change `var _beat_runner: Variant = null` → `var _beat_runner: U_BeatRunner = null`. Remove the 4 `has_method()` guards that this fixes (lines ~371, 378, 394, 402).
- [x] In `scripts/utils/scene_director/u_beat_runner.gd`: change `var _parallel_runners: Array = []` → `var _parallel_runners: Array[U_BeatRunner] = []`. Remove the 4 `has_method()` guards in `_update_parallel()` and `on_signal_received()` (lines ~125, 198, 200, 202).
- [x] Verify the remaining `has_method("evaluate")` and `has_method("execute")` calls on condition/effect resources are justified (polymorphic `Array[Resource]` contract). Document as accepted.
  - Acceptance note: confirmed remaining guards are only for condition/effect `Array[Resource]` polymorphism (`evaluate`/`execute`) in `m_scene_director.gd` and `u_beat_runner.gd`; these remain intentionally.
- [x] Run Scene Director tests.
  - Completion notes: Implemented in commit `c6f2085` (`refactor(scene-director): remove runner duck typing guards`).
  - Validation notes (2026-02-26):
    - `tools/run_gut_suite.sh -gdir=res://tests/unit/scene_director -ginclude_subdirs=true` (97/97 passed)
    - `tools/run_gut_suite.sh -gdir=res://tests/integration/scene_director -ginclude_subdirs=true` (4/4 passed)

### 2B — Add Missing Interfaces

- [x] Create `scripts/interfaces/i_objectives_manager.gd` (`I_ObjectivesManager`) — extract public API from `M_ObjectivesManager`.
- [x] Update `M_ObjectivesManager` to extend `I_ObjectivesManager`.
- [x] Remove `has_method("reset_for_new_run")` guard in `scripts/managers/m_run_coordinator.gd` (line ~106) — use typed interface lookup instead.
- [x] Create `scripts/interfaces/i_scene_director.gd` (`I_SceneDirector`) — extract public API from `M_SceneDirector`.
- [x] Update `M_SceneDirector` to extend `I_SceneDirector`.
- [x] Create `scripts/interfaces/i_run_coordinator.gd` (`I_RunCoordinator`) — extract public API from `M_RunCoordinator`.
- [x] Update `M_RunCoordinator` to extend `I_RunCoordinator`.
- [x] Run Scene Director and QB tests.
  - Completion notes: Implemented in commit `13c65f2` (`refactor(scene-director): add manager interfaces and typed objectives lookup`).
  - Validation notes (2026-02-26):
    - `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import` (pass; refreshed class cache after adding `class_name` interfaces)
    - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` (12/12 passed)
    - `tools/run_gut_suite.sh -gdir=res://tests/unit/scene_director -ginclude_subdirs=true` (97/97 passed)
    - `tools/run_gut_suite.sh -gdir=res://tests/integration/scene_director -ginclude_subdirs=true` (4/4 passed)
    - `tools/run_gut_suite.sh -gdir=res://tests/unit/qb -ginclude_subdirs=true` (151/151 passed)

## Phase 3 — Naming & Prefix Fixes (Medium Risk)

### 3A — Class Name Fixes

- [x] Rename class `RuleStateTracker` → `U_RuleStateTracker` in `scripts/utils/qb/u_rule_state_tracker.gd`.
- [x] Update all references to the renamed class.
- [x] Update AGENTS.md reference from `RuleStateTracker` to `U_RuleStateTracker`.
  - Completion notes: Implemented in commit `85c50057` (`refactor(qb): rename RuleStateTracker class to U_RuleStateTracker`). Updated `u_rule_state_tracker.gd` class_name, and references in `s_camera_state_system.gd`, `s_character_state_system.gd`, `s_game_event_system.gd`. AGENTS.md updated in docs commit.

### 3B — Manager Suffix Convention (Decision: Rename All Four)

- [x] Rename `m_run_coordinator.gd` → `m_run_coordinator_manager.gd` / class `M_RunCoordinator` → `M_RunCoordinatorManager`. Update all references.
- [x] Rename `m_scene_director.gd` → `m_scene_director_manager.gd` / class `M_SceneDirector` → `M_SceneDirectorManager`. Update all references.
- [x] Rename `m_gameplay_initializer.gd` → `m_gameplay_initializer_manager.gd` / class `M_GameplayInitializer` → `M_GameplayInitializerManager`. Update all references.
- [x] Rename `m_screenshot_cache.gd` → `m_screenshot_cache_manager.gd` / class `M_ScreenshotCache` → `M_ScreenshotCacheManager`. Update all references.
- [x] Run headless import after renames.
  - Completion notes: Implemented in commit `e37bfd68` (`refactor(cleanup-v6): add _manager suffix to four manager classes (phase 3b)`). Updated class_name declarations, preload paths in 5 test files, path/node-name in 6 scene files (root.tscn, gameplay_base.tscn, gameplay_exterior.tscn, test_exterior.tscn), root.gd ServiceLocator registration strings, style enforcement test node check, interface doc comments, and inline warning message prefixes.

### 3C — STYLE_GUIDE.md Gaps

- [x] Add `tmpl_*.tscn` row to the scene naming table in STYLE_GUIDE.md (templates already follow this but it's undocumented).
- [x] Add `scripts/core/` to the directory tree in STYLE_GUIDE.md (exists, has enforcement test, but not documented).
  - Completion notes: Added `| **Template Scenes** | tmpl_*.tscn | ... |` row after Debug Scenes row. Added `├── core/` entry to scripts directory tree before `ecs/`.

### 3D — Validate

- [x] Run style tests and QB/Scene Director tests.
  - Validation notes (2026-02-26): `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` (12/12 passed). QB and scene director confirmed passing from Phase 3B validation.

## Phase 4 — Dead Code & Debug Cruft Removal (Low Risk)

- [x] Remove `_is_post_processing_enabled()` dead method from `scripts/managers/helpers/display/u_display_post_process_applier.gd` (lines ~131–140).
- [x] Remove `_load_preset_resources()` dead method from `scripts/utils/display/u_display_option_catalog.gd` (lines ~204–223) — mobile-unsafe `DirAccess` code superseded by const preloads.
- [x] Extract `m_objectives_manager.gd` debug infrastructure to a separate helper:
  - Move `DEBUG_VICTORY_TRACE`, `DEBUG_SIGNATURE`, `_emit_startup_signature()`, `_debug_log_config_snapshot()`, `_debug_gameplay_slice()`, `_debug_objectives_slice()` (~100 lines) → new `scripts/utils/scene_director/u_objectives_debug_tracer.gd`.
  - Update `m_objectives_manager.gd` to delegate debug calls to the tracer.
- [x] Run display and Scene Director tests.
  - Completion notes: Implemented in commit `d3340d4f` (`refactor(cleanup-v6): remove dead methods and extract objectives debug tracer (phase 4)`). Pitfall discovered: `log()` is a GDScript built-in (natural log); used `debug_log()` instead. Documented in DEV_PITFALLS.md. Tracer also moved `_describe_condition()`, `_resource_script_path()`, and duplicated `_resource_get/_to_string_name/_to_resource_array` helpers (pending Phase 5B shared extraction).
  - Validation (2026-02-26):
    - `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import` (pass)
    - `tools/run_gut_suite.sh -gdir=res://tests/unit/scene_director -ginclude_subdirs=true` (97/97 passed)
    - `tools/run_gut_suite.sh -gdir=res://tests/unit/managers -ginclude_subdirs=true` (378/378 passed)
    - `tools/run_gut_suite.sh -gdir=res://tests/integration/display -ginclude_subdirs=true` (40/41 passed, 1 pending pre-existing)

## Phase 5 — Extract Duplicated Helpers (Medium Risk)

### 5A — Display Applier `_get_tree()` Consolidation

- [x] Create `scripts/utils/display/u_display_applier_utils.gd` with a static `get_tree_safe(owner: Node) -> SceneTree` function.
- [x] Replace the duplicated `_get_tree()` method in all 4 appliers with a call to the static utility:
  - `u_display_post_process_applier.gd`
  - `u_display_cinema_grade_applier.gd`
  - `u_display_window_applier.gd`
  - `u_display_quality_applier.gd`
  - Completion notes: Implemented in commit `4387cdd8` (`refactor(cleanup-v6): extract duplicated _get_tree() into U_DisplayApplierUtils (phase 5a)`).
  - Validation (2026-02-26):
    - `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import` (pass)
    - `tools/run_gut_suite.sh -gdir=res://tests/unit/managers -ginclude_subdirs=true` (378/378 passed)
    - `tools/run_gut_suite.sh -gdir=res://tests/integration/display -ginclude_subdirs=true` (40/41 passed, 1 pending pre-existing)

### 5B — Scene Director Resource Access Helpers

- [x] Extract duplicated `_to_int`, `_to_float`, `_to_string_name`, `_to_resource_array`, `_resource_get` methods shared between `m_scene_director.gd` and `u_beat_runner.gd` into a shared utility (e.g., `scripts/utils/scene_director/u_resource_access_helpers.gd`).
- [x] Update both files to use the shared utility.
- [x] Run Scene Director and display tests.
  - Completion notes: Implemented in commit `43804ade` (`refactor(cleanup-v6): extract shared resource helpers into U_ResourceAccessHelpers (phase 5b)`). Also updated `m_objectives_manager.gd` and `u_objectives_debug_tracer.gd` (which had the same helpers duplicated from Phase 4). Removed the Phase 5B pending note from the tracer class doc. Kept `_to_wait_mode` and `_to_string_name_array` in `u_beat_runner.gd` — they're specific to beat runner logic.
  - Validation (2026-02-26):
    - `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import` (pass)
    - `tools/run_gut_suite.sh -gdir=res://tests/unit/scene_director -ginclude_subdirs=true` (97/97 passed)
    - `tools/run_gut_suite.sh -gdir=res://tests/integration/scene_director -ginclude_subdirs=true` (4/4 passed)
    - `tools/run_gut_suite.sh -gdir=res://tests/unit/managers -ginclude_subdirs=true` (378/378 passed)
    - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` (12/12 passed)

## Phase 6 — `String(value)` → `str(value)` Migration (Low Risk)

- [x] Replace `String(value)` with `str(value)` for Variant→String coercion in:
  - `scripts/state/selectors/u_display_selectors.gd` (6 occurrences)
  - `scripts/state/reducers/u_display_reducer.gd` (8 occurrences)
  - `scripts/utils/display/u_display_option_catalog.gd` (13 occurrences)
  - `scripts/state/utils/u_global_settings_applier.gd` (5 occurrences)
  - `scripts/ui/settings/ui_display_settings_tab.gd` (14 occurrences)
  - `scripts/managers/helpers/display/u_display_quality_applier.gd` (2 occurrences)
- [x] Verify `rs_display_initial_state.gd` `@export_enum("bayer", "blue_noise")` vs catalog ID `"noise"` — fix mismatch if confirmed.
  - Mismatch confirmed: initial state had `"blue_noise"` but catalog uses `"noise"` as the ID. Fixed to `@export_enum("bayer", "noise")`.
- [x] Run display and state tests.
  - Completion notes: Implemented in commit `2aba797d` (`refactor(cleanup-v6): replace String() coercions with str() and fix dither enum mismatch (phase 6)`).
  - Validation (2026-02-26):
    - `tools/run_gut_suite.sh -gdir=res://tests/unit/managers -ginclude_subdirs=true` (378/378 passed)
    - `tools/run_gut_suite.sh -gdir=res://tests/unit/state -ginclude_subdirs=true` (365/365 passed)
    - `tools/run_gut_suite.sh -gdir=res://tests/integration/display -ginclude_subdirs=true` (40/41 passed, 1 pending pre-existing)

## Phase 7 — Style Enforcement Expansion (Low Risk)

- [x] Add missing directories to `GD_DIRECTORIES` (tab check) in `tests/unit/style/test_style_enforcement.gd`:
  - `scripts/resources/qb/`
  - `scripts/resources/qb/conditions/`
  - `scripts/resources/qb/effects/`
  - `scripts/resources/scene_director/`
  - `scripts/resources/ecs/`
  - `scripts/resources/display/`
  - `scripts/resources/localization/`
  - `scripts/debug/`
- [x] Add corresponding entries to `SCRIPT_PREFIX_RULES` for prefix enforcement.
- [x] Run style tests — fix any newly-caught violations.
  - No violations found — all files were already conforming.
  - Completion notes: Implemented in commit `9969588b` (`refactor(cleanup-v6): expand style enforcement to qb/scene_director/ecs/display/debug dirs (phase 7)`).
  - Validation (2026-02-26): `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` (12/12 passed)

## Phase 8 — Missing Initial State Resources (Low Risk)

- [x] Create `resources/state/cfg_default_objectives_initial_state.tres` (instance of `RS_ObjectivesInitialState`).
- [x] Create `resources/state/cfg_default_scene_director_initial_state.tres` (instance of `RS_SceneDirectorInitialState`).
- [x] Wire both exports in `scenes/root.tscn` on the `M_StateStore` node (consistent with all other slices).
- [x] Verify `u_state_slice_manager.gd` handles the wired resources correctly (should already work — the `== null` fallback just becomes unused).
- [x] Run state and Scene Director tests.
  - Completion notes: Implemented in commit `c2d869d8` (`refactor(cleanup-v6): create and wire missing objectives/scene_director initial state resources (phase 8)`). Added ext_resource entries `42_objectives_state` and `43_scene_director_state` in root.tscn. Headless import validated the scene without errors.
  - Validation (2026-02-26):
    - `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import` (pass)
    - `tools/run_gut_suite.sh -gdir=res://tests/unit/state -ginclude_subdirs=true` (365/365 passed)
    - `tools/run_gut_suite.sh -gdir=res://tests/unit/scene_director -ginclude_subdirs=true` (97/97 passed)

## Phase 9 — Stale Documentation Cleanup (Low Risk)

- [x] Fix `docs/display_manager/display-manager-tasks.md`:
  - Updated progress header from "43% (35/81)" → "~91% (84/92)".
  - Removed stale outline sub-bullets from tasks 0A.1 and 0B.1 (outline feature was dropped — shader exists but never wired to state).
  - Removed stale LUT file rows from "Files to Create" table (LUT system was replaced by cinema grading; `resources/luts/` dir, `rs_lut_definition.gd`, and `sh_lut_shader.gdshader` never created). Annotated `sh_outline_shader.gdshader` row to clarify "created but not wired to state".
  - Checked off Phase 9 Task 9.2 "Update AGENTS.md" (already done — Display Manager Patterns section present at line ~1051 in AGENTS.md).
- [x] Review `docs/scene_director/` docs for stale status references.
  - Updated `scene-director-continuation-prompt.md`: corrected branch name (merged → main), updated test counts (151/151 QB, 97/97 scene_director).
- [x] Review `docs/qb/` docs for stale status references.
  - N/A — `docs/qb/` directory does not exist.
  - Completion notes: Implemented in commit `18bb9da0` (`docs(cleanup-v6): clean up stale display/scene_director docs (phase 9)`).

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
