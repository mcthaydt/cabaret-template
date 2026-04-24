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
    - `res://scripts/core/resources/qb/conditions/rs_condition_composite 2.gd.uid`
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
  - `u_display_color_grading_applier.gd`
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

- [x] `m_objectives_manager.gd` (783 lines) — evaluate whether debug infrastructure extraction (Phase 4) brings it under threshold, or if further helper extraction is needed.
  - Phase 4 reduced it from 783 → 624 lines (159 extracted). Still 224 lines over threshold.
  - All remaining code is functional (set loading, objective lifecycle, event dispatch, state sync); no clean split without over-engineering.
  - `_resolve_store`/`_set_store_reference`/`_ensure_store_action_signal_connection`/`_disconnect_store_action_signal` (~65 lines) duplicated with `m_scene_director_manager.gd` — candidate for future extraction, deferred.
  - **Decision: monitored, no further extraction this phase.**
- [x] `m_scene_director_manager.gd` (485 lines) — evaluate whether resource access helper extraction (Phase 5B) brings it under threshold.
  - Phase 5B reduced it from 485 → 448 lines (37 extracted). 48 lines over threshold.
  - File is functionally dense (beat runner orchestration, directive selection, state sync); no clean split without over-engineering.
  - Same store resolver duplication as above — same deferred decision.
  - **Decision: monitored, no further extraction this phase.**
- [x] Flag any remaining files over 400 lines for future consideration.
  - In-scope (new in v6): `m_objectives_manager.gd` (624), `m_scene_director_manager.gd` (448) — see above.
  - Pre-existing large files (out of v6 scope, flagged for future cleanups):
    - `m_scene_manager.gd` (1148), `ui_display_settings_tab.gd` (809), `ui_save_load_menu.gd` (751), `m_save_manager.gd` (742)
    - `m_state_store.gd` (689), `s_camera_state_system.gd` (677), `m_spawn_manager.gd` (671), `m_character_lighting_manager.gd` (654)
    - `m_ecs_manager.gd` (644), `ui_hud_controller.gd` (613), `s_character_state_system.gd` (588), `ui_audio_settings_tab.gd` (574)
    - `ui_input_profile_selector.gd` (558), `ui_input_rebinding_overlay.gd` (550), `u_input_reducer.gd` (504), `ui_touchscreen_settings_overlay.gd` (501)
    - `u_rebind_action_list_builder.gd` (497), `m_camera_manager.gd` (461), `ui_localization_settings_tab.gd` (448)
  - No code changes; documentation-only phase.

## Phase 11 — Cinema Grading Test Coverage (Medium Risk)

- [x] Add unit tests for `U_CinemaGradeRegistry` (scene→grade mapping, neutral fallback, preload safety).
  - Created `tests/unit/managers/test_color_grading_registry.gd` — 14 tests: known scene lookup (all 5 scenes), neutral fallback (scene_id="_neutral", default exposure/contrast/saturation), empty scene_id, `to_dictionary()` validity, re-initialize safety.
- [x] Add unit tests for `U_CinemaGradeSelectors` (all selector functions with defaults).
  - Created `tests/unit/managers/test_color_grading_selectors.gd` — 22 tests: all 13 selector defaults, read-from-state for filter_mode/filter_intensity/exposure/contrast/saturation, `get_color_grading_settings` key filtering, graceful handling of missing/malformed display slice.
- [x] Add integration test for cinema grade applier (scene swap triggers grade change).
  - Created `tests/integration/display/test_color_grading_applier.gd` — 11 tests: CinemaGradeLayer creation, `scene/swapped` loads alleyway grade (filter_mode=6, exposure=-0.18, contrast=1.23 via state and shader uniforms), unknown scene falls back to neutral (filter_mode=0, exposure=0.0, color_grading_ keys still populated).
  - Fixed pitfall: GUT treats Variant inference warning as error — must use `var x: Variant = ...` not `var x :=` when calling helpers that return Variant.
- [x] Run display test suites.
  - Completion notes: Implementation commit `357165a9`. No style violations.
  - Validation:
    - `tools/run_gut_suite.sh -gdir=res://tests/unit/managers -ginclude_subdirs=true` (414/414 passed)
    - `tools/run_gut_suite.sh -gdir=res://tests/integration/display -ginclude_subdirs=true` (51/52 passed, 1 pending pre-existing)
    - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` (12/12 passed)

## Phase 12 — Final Validation

- [x] Run full style suite: `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true`
  - 12/12 passed.
- [x] Run full QB suite: `tools/run_gut_suite.sh -gdir=res://tests/unit/qb -ginclude_subdirs=true`
  - 151/151 passed.
- [x] Run full Scene Director suite: `tools/run_gut_suite.sh -gdir=res://tests/unit/scene_director -ginclude_subdirs=true`
  - 97/97 passed.
- [x] Run Scene Director integration: `tools/run_gut_suite.sh -gdir=res://tests/integration/scene_director -ginclude_subdirs=true`
  - 4/4 passed.
- [x] Run display suites: `tools/run_gut_suite.sh -gdir=res://tests/unit/managers -ginclude_subdirs=true` and `tools/run_gut_suite.sh -gdir=res://tests/integration/display -ginclude_subdirs=true`
  - 414/414 unit/managers passed.
  - 51/52 integration/display passed (1 pending pre-existing: `test_ui_color_blind_layer_has_higher_layer_than_ui_overlay`).
- [x] Run headless import: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import`
  - Pass. Non-failing ObjectDB leak warning at exit (known, pre-existing).
- [x] Record final status in continuation prompt.
  - All suites green. cleanup_v6 complete. Run date: 2026-02-26.

## Phase 13 — Audit Remediation (Low–Medium Risk)

### 13A — Stale Documentation Fixes

- [x] Fix AGENTS.md line 31: `scripts/managers/m_run_coordinator.gd` → `scripts/managers/m_run_coordinator_manager.gd`.
- [x] Clean up resolved items in `cleanup-v6-continuation-prompt.md` Notes / Pitfalls section (lines 277–282). These issues were fixed in Phases 3A, 3C, 6, and 8 but still read as open. Either remove them or annotate each with the phase that resolved it.
  - Completion notes: Fixed AGENTS.md path. Annotated resolved pitfalls with their resolution phases. In commit `b888ba27`.

### 13B — Cinema Grade Reducer Test Coverage

- [x] Add unit tests for `ACTION_SET_PARAMETER` (filter preset string→int mapping) in `tests/unit/state/test_display_reducer.gd` (or a new dedicated cinema grade reducer test file).
- [x] Add unit tests for `ACTION_RESET_TO_SCENE_DEFAULTS` (reset to grade dict values) in the same file.
- [x] Run display and state test suites.
  - Completion notes: Added 10 tests (Tests 29–38) covering filter preset mapping (dramatic→1, vivid_cold→6, none→0, unknown→0), filter_intensity, generic param, empty param_name guard, grade dict key filtering, non-color_grading key ignored, and empty payload null return. In commit `b888ba27`.
  - Validation: `tests/unit/state` 375/375 passed (+10 from baseline 365).

### 13C — Broader `String()` → `str()` Audit

- [x] Audit `String(` calls outside the Phase 6 display module scope (142 files flagged). Identify which are legitimate type coercions (e.g., `String(int)`) vs. Variant coercions that should be `str()`.
- [x] Fix any Variant coercion occurrences found. Leave legitimate numeric/bool coercions as-is.
- [x] Run affected test suites.
  - Completion notes: Audited 80 files. The vast majority are `String(StringName)`, `String(int)`, `String(NodePath)`, or `String(node.name)` — all legitimate coercions. One clear Variant coercion found in v6-scope code: `u_objectives_debug_tracer.gd:128–131` called `String(U_ResourceAccessHelpers.resource_get(...))` where `resource_get` returns `Variant`. Fixed to `str(...)`. Pre-existing patterns in save manager, input reducer, HUD controller, etc. are out of v6 scope. In commit `b888ba27`.
  - Validation: `tests/unit/scene_director` 97/97 passed.

### 13D — Store Resolver Duplication (Medium Risk)

- [x] Extract the shared `_resolve_store` / `_set_store_reference` / `_ensure_store_action_signal_connection` / `_disconnect_store_action_signal` pattern (~65 lines) duplicated between `m_objectives_manager.gd` and `m_scene_director_manager.gd` into a shared mixin or utility.
- [x] Update both managers to use the shared utility.
- [x] Run Scene Director and state tests.
  - Completion notes: Created `scripts/utils/scene_director/u_store_action_binder.gd` (`U_StoreActionBinder` extends `RefCounted`). Both managers: (a) replaced `var _store: I_StateStore = null` + `var _store_action_connected: bool = false` with a getter property backed by `_binder.store` and a `U_StoreActionBinder` instance; (b) replaced all 4 method definitions with binder calls at the call sites; (c) removed `U_SERVICE_LOCATOR`, `U_STATE_UTILS`, and `STORE_SERVICE_NAME` from each manager (now in binder). In commit `b888ba27`.
  - Validation (post-headless import): style 12/12, scene_director unit 97/97, scene_director integration 4/4, QB 151/151 passed.

### 13E — Validate

- [x] Run full style suite.
  - 12/12 passed.
- [x] Run full QB, Scene Director, display, and state suites.
  - QB: 151/151 passed.
  - Scene Director unit: 97/97 passed.
  - Scene Director integration: 4/4 passed.
  - Unit managers: 414/414 passed.
  - State unit: 375/375 passed (+10 from 13B).
  - Integration display: 51/52 passed (1 pending pre-existing).
- [x] Run headless import.
  - Pass. Non-failing ObjectDB leak at exit (known, pre-existing).
- [x] Update continuation prompt with Phase 13 results.

## Phase 14 — Deferred Items (Medium Risk)

### 14A — I_Condition / I_Effect Interfaces

- [x] Create `scripts/interfaces/i_condition.gd` (`I_Condition`) with `func evaluate(context: Dictionary) -> float` (actual return type is float, not bool).
- [x] Create `scripts/interfaces/i_effect.gd` (`I_Effect`) with `func execute(context: Dictionary) -> void`.
- [x] Update `scripts/resources/qb/conditions/rs_base_condition.gd` to extend `I_Condition`.
- [x] Update `scripts/resources/qb/effects/rs_base_effect.gd` to extend `I_Effect`.
- [x] Replace 11 `has_method("evaluate")` / `has_method("execute")` guards with `is I_Condition` / `is I_Effect` checks across: `rs_condition_composite.gd` (2), `m_scene_director_manager.gd` (1), `m_objectives_manager.gd` (2), `u_beat_runner.gd` (2), `u_rule_scorer.gd` (1), `s_game_event_system.gd` (1), `s_character_state_system.gd` (1), `s_camera_state_system.gd` (1). Keep `Array[Resource]` on exports (Godot inspector limitation).
- [x] Update test stubs in 5 test files to extend `I_Condition`/`I_Effect` instead of `Resource`.
- [x] Run QB, Scene Director, and style tests.
  - Implementation commit: `3ce45068`.
  - Validation: QB 151/151, Scene Director unit 97/97, integration 4/4, style 12/12 passed.

### 14B — RS_GameConfig Resource

- [x] Create `scripts/resources/rs_game_config.gd` (`RS_GameConfig`) with `retry_scene_id`, `route_retry`, `default_objective_set_id` exported fields.
- [x] Create `resources/cfg_game_config.tres` instance with current default values.
- [x] Wire `RS_GameConfig` via `@export` on `M_RunCoordinatorManager` and `M_ObjectivesManager` in `scenes/root.tscn` (id `44_game_config`).
- [x] Remove `RETRY_SCENE_ID`, `ROUTE_RETRY_ALLEYWAY`, `OBJECTIVE_SET_DEFAULT` consts from `M_RunCoordinatorManager`; read from `game_config` instead. `M_ObjectivesManager` receives the export but has no standalone consts to remove (debug check strings left in-place). Simplified redundant match block in `_execute_reset_run` (both branches were identical).
- [x] Run Scene Director and state tests.
  - Implementation commit: `8a4c22f6`.
  - Validation: Scene Director unit 97/97, integration 4/4 passed.

### 14C — Manager Interfaces

- [x] Create `scripts/interfaces/i_cursor_manager.gd` (`I_CursorManager`) — set_cursor_state, set_cursor_locked, set_cursor_visible, is_cursor_locked, is_cursor_visible.
- [x] Create `scripts/interfaces/i_spawn_manager.gd` (`I_SpawnManager`) — spawn_player_at_point, initialize_scene_camera, spawn_at_last_spawn.
- [x] Create `scripts/interfaces/i_screenshot_cache_manager.gd` (`I_ScreenshotCacheManager`) — cache_current_frame, get_cached_screenshot, clear_cache, has_cached_screenshot.
- [x] Create `scripts/interfaces/i_gameplay_initializer_manager.gd` (`I_GameplayInitializerManager`) — marker interface (no public API on concrete class).
- [x] Create `scripts/interfaces/i_ui_input_handler.gd` (`I_UIInputHandler`) — marker interface (no public API on concrete class).
- [x] Update all 5 managers to extend their respective interfaces.
- [x] Update consumers: `M_SceneManager` uses `I_CursorManager`/`I_SpawnManager`; `M_TimeManager` uses `I_CursorManager`; `M_SaveManager` uses `I_ScreenshotCacheManager` and removes `has_method("get_cached_screenshot")` guard; `M_GameplayInitializerManager` uses `I_SpawnManager`.
- [x] Run style, QB, Scene Director, and display tests.
  - Implementation commit: `01789d85`.
  - Validation: style 12/12, QB 151/151, scene director unit/integration all pass, managers 414/414, state 375/375, display 51/52 (1 pending pre-existing).

### 14D — Validate & Document

- [x] Run full suite sweep (style, QB, Scene Director, display, state).
  - Style 12/12, QB 151/151, Scene Director unit 97/97, integration 4/4, managers 414/414, state 375/375, display 51/52 (1 pending pre-existing). All green.
- [x] Run headless import.
  - Pass. Non-failing ObjectDB leak at exit (known, pre-existing).
- [x] Update continuation prompt with Phase 14 results.
- [x] Update AGENTS.md if new patterns or pitfalls emerged.
  - No new patterns or pitfalls. Existing interface documentation in AGENTS.md covers the new interfaces.

## Notes

- Phase 14A task description said `evaluate -> bool` but the actual return type is `float` — interface created with `-> float` to match the implementation.
- `M_GameplayInitializerManager` and `M_UIInputHandler` have no public instance methods; their interfaces are marker-only.
- `required_final_area = "bar"` in `s_victory_handler_system.gd` is already an `@export var` (inspector-configurable); it was not moved to `RS_GameConfig`.
