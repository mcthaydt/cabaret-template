# vCam Refactor — Task Checklist

**Scope:** Full architectural refactor of the vCam system — remove OTS, Fixed, and First-Person modes (orbit is the sole shipping mode), decompose the `s_vcam_system.gd` God object into focused helpers, extract blend management from `m_vcam_manager.gd`, and update contracts/documentation.

**Quality target:** Match the modularity of `M_SaveManager` (740 lines + 4 helpers) and `M_SceneManager` (1,172 lines + 7 helpers). Each file 200–500 lines, single responsibility, TDD where applicable.

---

## Pre-Implementation Checklist

Before starting Phase 1, verify:

- [x] **PRE-1**: Read required documentation
  - Read `AGENTS.md`, `docs/general/DEV_PITFALLS.md`, `docs/general/STYLE_GUIDE.md`
  - Read `docs/vcam_manager/vcam-manager-overview.md` and `vcam-manager-continuation-prompt.md`
  - Read `scripts/ecs/systems/s_vcam_system.gd` (understand full evaluation pipeline)
  - Read `scripts/managers/m_vcam_manager.gd` (understand blend + registration)

- [x] **PRE-2**: Verify branch is `vcam` and working tree is clean

---

## Per-Phase Documentation Cadence (Mandatory)

- [ ] **DOC-1**: After each completed phase, update `docs/vcam_manager/vcam-manager-continuation-prompt.md` with exact phase status.
- [ ] **DOC-2**: After each completed phase, update this task file with `[x]` marks and completion notes.
- [ ] **DOC-3**: Update `AGENTS.md` in two stages: (1) after Phase 1, remove deleted OTS/fixed contracts; (2) in Phase 5A, add new helper architecture contracts. Do NOT update AGENTS.md during Phases 2–4.
- [ ] **DOC-4**: Commit documentation updates separately from implementation per AGENTS requirements.

---

## Phase 1: Remove OTS + Fixed + First-Person Modes

**Exit Criteria:** All remaining tests pass. Orbit is the sole mode. Zero references to OTS/fixed/first-person in production code. Aim pipeline (`aim_pressed`) removed entirely.

### Phase 1A: Remove OTS from s_vcam_system.gd

- [x] **Task 1A.1**: Remove OTS constants and imports
  - Delete `RS_VCAM_MODE_OTS_SCRIPT` const (line 24)
  - Delete `OTS_MIN_CAMERA_DISTANCE`, `OTS_LANDING_FALL_SPEED_MIN/MAX`, `OTS_LANDING_RESPONSE_EPSILON`, `DEFAULT_OTS_AIM_BLEND_DURATION` constants
  - Delete `debug_ots_vertical_logging` export and `_debug_ots_vertical_log_cooldown_sec`

- [x] **Task 1A.2**: Remove OTS state dictionaries
  - Delete `_shoulder_sway_state`, `_ots_collision_state`, `_ots_landing_response_state` dicts
  - Delete `_debug_ots_profile_signature_by_vcam`, `_debug_ots_pitch_clamped_by_vcam` dicts
  - Keep `_aim_restore_vcam_id`, `_aim_toggled_on`, `_aim_prev_pressed` — repurposed for FP aim toggle (Task 1A.5)

- [x] **Task 1A.3**: Remove OTS functions
  - Delete shoulder sway functions (`_apply_ots_shoulder_sway`, `_ensure_ots_shoulder_sway_state`, `_clear_ots_shoulder_sway_state_for_vcam`)
  - Delete collision avoidance functions (`_apply_ots_collision_avoidance` and all cast/state/hit/exclude helpers)
  - Delete landing response functions (`_apply_ots_landing_camera_response` and state helpers)
  - Delete `_is_ots_mode`, `_resolve_ots_aim_blend_duration`, `_resolve_ots_aim_exit_blend_duration` (replaced in Task 1A.5)
  - Keep `_process_aim_activation`, `_find_aim_target_ots_vcam_id` — repurposed in Task 1A.5
  - Note: `_read_aim_pressed` (line 3587) stays — aim pipeline retained
  - Delete OTS debug logging (`_debug_log_ots_vertical_diagnostics`)

- [x] **Task 1A.4**: Remove OTS branches from shared functions
  - Remove OTS from `_evaluate_and_submit` pipeline (shoulder sway, collision, landing response calls)
  - Remove OTS-specific mode checks from `process_tick`; keep `_process_aim_activation` call (repurposed in Task 1A.5)
  - Remove OTS from `_is_look_driven_mode_script`, `_is_look_rotation_smoothing_mode`, `_is_follow_target_required`
  - Remove OTS from `_prune_smoothing_state`, `_clear_all_smoothing_state`, `_clear_smoothing_state_for_vcam`
  - Remove OTS from `_exit_tree` cleanup

- [x] **Task 1A.5**: Repurpose aim activation to target first-person mode
  - Rename `_find_aim_target_ots_vcam_id` → `_find_aim_target_fp_vcam_id`
  - Change mode search: check `mode_script == RS_VCAM_MODE_FIRST_PERSON_SCRIPT` instead of OTS
  - Rename `DEFAULT_OTS_AIM_BLEND_DURATION` → `DEFAULT_AIM_BLEND_DURATION`
  - Replace `_resolve_ots_aim_blend_duration` → `_resolve_aim_blend_duration` (reads from FP mode resource)
  - Replace `_resolve_ots_aim_exit_blend_duration` → `_resolve_aim_exit_blend_duration` (reads from FP mode resource)
  - Update `_process_aim_activation`: on press find FP vCam, on release restore previous vCam
  - Update all OTS mode checks in aim flow to use FP mode checks

- [x] **Task 1A.6**: Add aim blend duration exports to `rs_vcam_mode_first_person.gd`
  - Add `@export var aim_blend_duration: float = 0.15`
  - Add `@export var aim_exit_blend_duration: float = 0.2`
  - Add both to `get_resolved_values()` with `maxf(..., 0.01)` validation

Completion notes (2026-03-22):
- `S_VCamSystem` no longer contains OTS runtime/state/debug paths (shoulder sway, collision avoidance, landing camera response, OTS diagnostics, and OTS mode branches removed).
- Aim activation was repurposed to first-person (`_find_aim_target_fp_vcam_id`, `_resolve_aim_blend_duration`, `_resolve_aim_exit_blend_duration`) and now switches orbit -> first-person on press, then restores prior camera on release.
- `RS_VCamModeFirstPerson` now exports `aim_blend_duration` + `aim_exit_blend_duration` with resolved minimum clamp (`0.01`).
- Updated aim-focused system tests and first-person resource tests for new behavior.
- Validation runs:
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/resources/display/vcam -gselect=test_vcam_mode_first_person` (`14/14`)
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/test_vcam_system.gd -gunit_test_name=aim` (`5/5`)
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` (`17/17`)

### Phase 1B: Remove Fixed mode from s_vcam_system.gd

- [x] **Task 1B.1**: Remove Fixed constants, state, and imports
  - Delete `RS_VCAM_MODE_FIXED_SCRIPT` const
  - Delete `_path_follow_helpers` dictionary

- [x] **Task 1B.2**: Remove Fixed functions
  - Delete `_is_path_fixed_mode`, `_resolve_or_create_path_anchor`, `_resolve_fixed_anchor_for_component`
  - Delete `_prune_path_helpers`, `_teardown_path_helpers`

- [x] **Task 1B.3**: Remove Fixed branches from shared functions
  - Remove fixed branch from `_apply_rotation_transition`
  - Remove fixed branch from `_is_follow_target_required`, `_is_fixed_anchor_required` (delete entire function)
  - Remove fixed branch from `_evaluate_and_submit` (fixed anchor resolution)
  - Remove fixed-mode smoothing branch from `_step_smoothing_state`
  - Remove `_teardown_path_helpers` from `_exit_tree`, `_prune_path_helpers` from `process_tick`

Completion notes (2026-03-22):
- `S_VCamSystem` fixed-mode runtime scaffolding is removed:
  - removed fixed mode script constant + `_path_follow_helpers` state
  - removed fixed helper methods (`_is_path_fixed_mode`, `_resolve_or_create_path_anchor`, `_resolve_fixed_anchor_for_component`, `_prune_path_helpers`, `_teardown_path_helpers`, `_is_fixed_anchor_required`)
  - removed fixed branches from `_evaluate_and_submit`, `_apply_rotation_transition`, `_is_follow_target_required`, and `_step_smoothing_state`
- `S_VCamSystem` now treats follow targets as required only for orbit and first-person paths.
- Validation runs:
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/resources/display/vcam -gselect=test_vcam_mode_first_person` (`14/14`)
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/test_vcam_system.gd -gunit_test_name=aim` (`5/5`)
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` (`17/17`)

### Phase 1C: Remove OTS + Fixed from evaluator

- [x] **Task 1C.1**: Simplify `u_vcam_mode_evaluator.gd`
  - Delete `RS_VCAM_MODE_OTS_SCRIPT` and `RS_VCAM_MODE_FIXED_SCRIPT` constants
  - Remove OTS/fixed branches from `evaluate()` function
  - Remove `fixed_anchor` parameter from `evaluate()` signature
  - Delete `_evaluate_ots`, `_resolve_ots_values`
  - Delete `_evaluate_fixed`, `_resolve_fixed_values`, `_build_look_at_basis_or_fallback`
  - Only orbit + first-person remain

Completion notes (2026-03-22):
- `U_VCamModeEvaluator` now supports only orbit + first-person:
  - removed OTS/fixed script constants and dispatch branches
  - removed `fixed_anchor` from `evaluate(...)` signature
  - removed OTS/fixed helper paths (`_evaluate_ots`, `_resolve_ots_values`, `_evaluate_fixed`, `_resolve_fixed_values`, `_build_look_at_basis_or_fallback`)
- Updated evaluator call sites touched by Phase 1C signature change:
  - `tests/unit/ecs/systems/test_vcam_system.gd` helper expectations now call `evaluate(...)` with orbit/first-person signature only
  - `tests/unit/managers/helpers/test_vcam_mode_evaluator.gd` now covers orbit + first-person + unsupported-mode guard (OTS/fixed evaluator assertions removed)
- Validation runs:
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/managers/helpers/test_vcam_mode_evaluator.gd` (`25/25`)
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/resources/display/vcam -gselect=test_vcam_mode_first_person` (`14/14`)
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` (`17/17`)

### Phase 1D: Remove OTS from external systems

- [x] **Task 1D.1**: Clean `s_movement_system.gd`
  - Delete `RS_VCAM_MODE_OTS_SCRIPT` const
  - Remove OTS movement profile resolution call and `_resolve_active_ots_movement_state` function

- [x] **Task 1D.2**: Clean `s_rotate_to_input_system.gd`
  - Delete `RS_VCAM_MODE_OTS_SCRIPT` const
  - Remove OTS facing lock resolution and `_resolve_active_ots_facing_lock` function

- [x] **Task 1D.3**: Clean `ui_hud_controller.gd`
  - Delete `RS_VCAM_MODE_OTS_SCRIPT` const and OTS reticle @onready vars
  - Delete all OTS reticle constants, state, and functions
  - Remove OTS reticle calls from `_ready`/`_update` paths

Completion notes (2026-03-22):
- External OTS integrations are removed from runtime code:
  - `S_MovementSystem` no longer resolves OTS movement overrides (`movement_profile`, `disable_sprint`, blend-weight gating); sprint/max-speed now use movement component settings only.
  - `S_RotateToInputSystem` no longer resolves OTS camera-facing lock overrides; desired yaw is always derived from move input direction.
  - `UI_HudController` no longer contains OTS reticle runtime logic (imports, state, tweening, visibility/fade helpers, and update calls removed).
- Updated impacted unit suites to match Phase 1D contracts:
  - removed OTS-specific movement override tests from `test_movement_system.gd`
  - removed OTS lock-facing tests from `test_rotate_to_input_system.gd`
- Validation runs:
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/test_movement_system.gd` (`9/9`)
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/test_rotate_to_input_system.gd` (`3/3`)
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` (`17/17`)

### Phase 1E: Remove Fixed from component

- [x] **Task 1E.1**: Simplify `c_vcam_component.gd`
  - Remove `fixed_anchor_path` export and `path_node_path` export
  - Remove `get_fixed_anchor()` and `get_path_node()` getters

Completion notes (2026-03-22):
- `C_VCamComponent` fixed-mode bridge exports/getters are removed:
  - removed `fixed_anchor_path` and `path_node_path` exports
  - removed `get_fixed_anchor()` and `get_path_node()` helpers
- Updated component contract tests:
  - removed fixed/path export expectations from `tests/unit/ecs/components/test_vcam_component.gd`
- Validation runs:
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/components/test_vcam_component.gd` (`13/13`)
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` (`17/17`)

### Phase 1F: Delete resources and scene nodes

- [x] **Task 1F.1**: Delete resource files
  - Delete `scripts/resources/display/vcam/rs_vcam_mode_ots.gd`
  - Delete `scripts/resources/display/vcam/rs_vcam_mode_fixed.gd`
  - Delete `resources/display/vcam/cfg_default_ots.tres`
  - Delete `resources/display/vcam/cfg_default_fixed.tres`
  - Delete `resources/base_settings/gameplay/cfg_ots_movement_default.tres`
  - Note: `cfg_default_first_person.tres` already exists and is NOT deleted

- [x] **Task 1F.2**: Update `scenes/templates/tmpl_camera.tscn`
  - Remove C_VCamOTSComponent node and cfg_default_ots ext_resource
  - Add C_VCamFirstPersonComponent node (`c_vcam_component.gd` script) with:
    - `vcam_id = &"camera_first_person"`, `priority = 10`
    - `mode = cfg_default_first_person.tres`
    - Same `follow_target_path`, `soft_zone`, `blend_hint`, `response` as orbit vCam

- [x] **Task 1F.3**: Update `scenes/ui/hud/ui_hud_overlay.tscn`
  - Remove OTSReticleContainer and ReticleDot nodes

Completion notes (2026-03-22):
- Removed OTS/fixed mode resource artifacts from production runtime:
  - deleted scripts: `rs_vcam_mode_ots.gd`, `rs_vcam_mode_fixed.gd`
  - deleted presets: `cfg_default_ots.tres`, `cfg_default_fixed.tres`, `cfg_ots_movement_default.tres`
- Updated authored scenes to remove OTS wiring:
  - `scenes/templates/tmpl_camera.tscn` now uses `cfg_default_first_person.tres` with `C_VCamFirstPersonComponent` (`vcam_id = &"camera_first_person"`).
  - `scenes/ui/hud/ui_hud_overlay.tscn` no longer contains `OTSReticleContainer` / `ReticleDot`.
- Validation runs:
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -gselect=test_style_enforcement` (`17/17`)
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/test_entity_scene_registration.gd` (`3/3`)

### Phase 1G: Update tests

- [x] **Task 1G.1**: Delete mode-specific test files
  - Delete `tests/unit/resources/display/vcam/test_vcam_mode_ots.gd`
  - Delete `tests/unit/resources/display/vcam/test_vcam_mode_fixed.gd`

- [x] **Task 1G.2**: Update evaluator tests
  - Remove OTS/fixed test cases from `test_vcam_mode_evaluator.gd`
  - Update all `evaluate()` calls to remove `fixed_anchor` parameter

- [x] **Task 1G.3**: Update system tests
  - Remove OTS/fixed-specific tests from `test_vcam_system.gd`
  - Add/update aim activation tests to verify `aim_pressed` toggles to FP vCam (not OTS)

- [x] **Task 1G.4**: Update manager and integration tests
  - Remove OTS/fixed runtime paths from `test_vcam_manager.gd`
  - Remove fixed_anchor/path_node tests from `test_vcam_component.gd`
  - Remove OTS/fixed preset references from `test_vcam_mode_presets.gd`
  - Remove OTS/fixed paths from `test_vcam_runtime.gd`, `test_vcam_blend.gd`

- [x] **Task 1G.5**: Run full test suite — verify all green

Completion notes (2026-03-22):
- Removed obsolete OTS/fixed test files and coverage:
  - deleted `test_vcam_mode_ots.gd`, `test_vcam_mode_fixed.gd`, `test_ots_reticle.gd`
  - `test_vcam_system.gd` now targets orbit/first-person-only behavior (`94/94`)
- Updated integration/resource/manager suites for orbit+first-person runtime:
  - `test_vcam_runtime.gd` fixed/OTS cases removed
  - `test_vcam_mobile.gd` OTS drag-look case removed
  - `test_vcam_mode_presets.gd` fixed preset assertions removed
  - `test_vcam_manager.gd` secondary blend fixture naming normalized away from OTS labels
- Validation runs:
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/test_vcam_system.gd` (`94/94`)
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/managers/test_vcam_manager.gd` (`45/45`)
  - `tools/run_gut_suite.sh -gdir=res://tests/integration/vcam` (`26/26`)
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/resources/display/vcam` (`91/91`)
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/style -gselect=test_style_enforcement` (`17/17`)
  - `tools/run_gut_suite.sh -gdir=res://tests -ginclude_subdirs=true` (`3481/3490` passing, `9` pending baseline)

### Phase 1H: Phase 1 commit + docs

- [x] **Task 1H.1**: Commit Phase 1 implementation
- [x] **Task 1H.2**: Update continuation prompt and this task file with Phase 1 completion notes
- [x] **Task 1H.3**: Update AGENTS.md — remove deleted OTS/fixed contracts

Completion notes (2026-03-22):
- Phase 1 implementation is complete and committed through:
  - `a16a9b3e` (Phase 1F implementation)
  - `d60a1142` (Phase 1G test cleanup + validation alignment)
- Phase 1 docs + contract cleanup is complete:
  - `docs/vcam_manager/vcam-manager-continuation-prompt.md` updated to Phase-1-complete status
  - this task file updated through `1H`
  - `AGENTS.md` Stage-1 cleanup removed stale OTS/fixed vCam contracts and aligned runtime guidance to orbit + first-person

### Phase 1I: Remove First-Person Mode + Aim Pipeline

- [x] **Task 1I-A**: Remove FP from `s_vcam_system.gd`
  - Removed `RS_VCAM_MODE_FIRST_PERSON_SCRIPT` const, `DEFAULT_AIM_BLEND_DURATION` const, `_first_person_strafe_tilt_state` dict
  - Removed aim state vars (`_aim_restore_vcam_id`, `_aim_toggled_on`, `_aim_prev_pressed`)
  - Removed all aim/FP functions (`_apply_first_person_strafe_tilt`, `_ensure_first_person_strafe_tilt_state`, `_clear_first_person_strafe_tilt_state_for_vcam`, `_process_aim_activation`, `_find_aim_target_fp_vcam_id`, `_is_first_person_mode`, `_resolve_aim_blend_duration`, `_resolve_aim_exit_blend_duration`, `_read_aim_pressed`, `_is_look_driven_mode_script`)
  - Removed FP branch from `_update_runtime_rotation` and cross-mode rotation transition
  - Simplified mode-gated helpers to orbit-only checks

- [x] **Task 1I-B**: Remove FP from `u_vcam_mode_evaluator.gd`
  - Removed `RS_VCAM_MODE_FIRST_PERSON_SCRIPT` const, FP dispatch branch, `_evaluate_first_person()`, `_resolve_first_person_values()`

- [x] **Task 1I-C**: Remove aim from input/state layer
  - `c_input_component.gd`: removed `aim_pressed` + `set_aim_pressed()`
  - `s_input_system.gd`: removed `aim_action` export, aim capture/dispatch/validation
  - `u_input_actions.gd`: removed `ACTION_UPDATE_AIM_STATE` + `update_aim_state()`
  - `u_input_reducer.gd`: removed `aim_pressed` from state + reduction
  - `u_input_selectors.gd`: removed `is_aim_pressed()`
  - Input sources (`keyboard_mouse_source.gd`, `gamepad_source.gd`, `touchscreen_source.gd`, `i_input_source.gd`): removed `aim_pressed` from payloads/contracts

- [x] **Task 1I-D**: Remove aim from external systems
  - `s_touchscreen_system.gd`: removed aim dispatch/consume
  - `ui_mobile_controls.gd`: removed all aim long-press state/constants/functions

- [x] **Task 1I-E**: Delete FP resources + update scene
  - Deleted `rs_vcam_mode_first_person.gd` + `cfg_default_first_person.tres`
  - Updated `tmpl_camera.tscn`: removed FP ext_resource + `C_VCamFirstPersonComponent` node

- [x] **Task 1I-F**: Update tests
  - Deleted `test_vcam_mode_first_person.gd`
  - Removed FP/aim tests from evaluator, system, input, touchscreen, reducer, selector, mobile controls suites
  - Removed mode-switch/mode-gating tests that required non-orbit mode (orbit-only makes them untestable)
  - Replaced `"first_person"` mode strings with `"custom_mode"` in room-fade/region-visibility tests

- [x] **Task 1I-G**: Commit + update docs

Completion notes (2026-03-22):
- First-person mode and entire aim pipeline (`aim_pressed`) removed from all production code, tests, resources, and scenes.
- Orbit is now the sole vCam mode. Mode evaluator dispatches orbit only; unsupported modes return empty dict.
- Full test suite: 3405 passing, 9 pending (platform/tween skips).
- Phase 2F (`u_vcam_first_person_effects.gd`) and Phase 4 (Enhance First-Person) dropped from roadmap.
- Phase 5 dead-code sweep updated to include FP patterns.

---

## Phase 2: Extract Helpers from s_vcam_system.gd (TDD)

**Exit Criteria:** `s_vcam_system.gd` is ~400–600 lines. Five extracted helpers each have dedicated unit tests. All existing system/integration tests pass unchanged.

**TDD cadence per helper:** Write unit tests (Red) → Extract code to pass them (Green) → Clean up (Refactor) → Verify existing tests still pass.

### Phase 2A: Extract `u_vcam_look_input.gd`

- [ ] **Task 2A.1 (Red)**: Write `tests/unit/ecs/systems/helpers/test_vcam_look_input.gd`
  - Test filter_look_input returns filtered vector with deadzone
  - Test hold timer accumulates during active input
  - Test release decay reduces filtered input over time
  - Test is_active reflects filter state
  - Test prune/clear_all/clear_for_vcam lifecycle
  - **Target: ~8 tests**

- [ ] **Task 2A.2 (Green)**: Create `scripts/ecs/systems/helpers/u_vcam_look_input.gd`
  - Extract `_resolve_filtered_look_input`, `_is_filtered_look_input_active` from s_vcam_system.gd
  - Move `_look_input_filter_state` dict, look filter constants, debug log functions
  - API: `filter_look_input(vcam_id, raw_input, response_values, delta) -> Vector2`
  - API: `is_active(filtered_input, response_values) -> bool`
  - API: `prune(active_vcam_ids)`, `clear_all()`, `clear_for_vcam(vcam_id)`

- [ ] **Task 2A.3 (Refactor)**: Wire s_vcam_system.gd to use `U_VCamLookInput`
  - Replace inline calls with `_look_input_helper.filter_look_input(...)`
  - Verify all existing tests pass

### Phase 2B: Extract `u_vcam_rotation.gd`

- [ ] **Task 2B.1 (Red)**: Write `tests/unit/ecs/systems/helpers/test_vcam_rotation.gd`
  - Test continuity policy carries yaw across same-mode switches
  - Test orbit↔first-person carries yaw, resets pitch
  - Test different-target switches reseed to authored angles
  - Test orbit centering interpolation
  - Test release damping applies to velocities
  - Test prune/clear lifecycle
  - **Target: ~12 tests**

- [ ] **Task 2B.2 (Green)**: Create `scripts/ecs/systems/helpers/u_vcam_rotation.gd`
  - Extract rotation continuity, runtime yaw/pitch management, look smoothing springs, orbit centering, release damping
  - Move `_look_rotation_state`, `_rotation_target_cache`, `_orbit_centering_state`, `_orbit_no_look_input_timers`

- [ ] **Task 2B.3 (Refactor)**: Wire s_vcam_system.gd to use `U_VCamRotation`
  - Verify all existing tests pass

### Phase 2C: Extract `u_vcam_orbit_effects.gd`

- [ ] **Task 2C.1 (Red)**: Write `tests/unit/ecs/systems/helpers/test_vcam_orbit_effects.gd`
  - Test look-ahead applies offset in movement direction
  - Test look-ahead clears when look input active
  - Test ground-relative tracks anchor on landing
  - Test ground-relative ignores anchor while airborne
  - Test soft-zone correction moves camera toward dead zone
  - Test follow-target speed sampling
  - Test position smoothing bypass for stationary targets
  - **Target: ~12 tests**

- [ ] **Task 2C.2 (Green)**: Create `scripts/ecs/systems/helpers/u_vcam_orbit_effects.gd`
  - Extract look-ahead, ground-relative, soft-zone dead zone, motion sampling, bypass logic
  - Move `_look_ahead_state`, `_ground_relative_state`, `_soft_zone_dead_zone_state`, `_follow_target_motion_state`

- [ ] **Task 2C.3 (Refactor)**: Wire s_vcam_system.gd to use `U_VCamOrbitEffects`
  - Verify all existing tests pass

### Phase 2D: Extract `u_vcam_response_smoother.gd`

- [ ] **Task 2D.1 (Red)**: Write `tests/unit/ecs/systems/helpers/test_vcam_response_smoother.gd`
  - Test smoothing applies position dynamics
  - Test null response bypasses smoothing (raw passthrough)
  - Test mode change resets dynamics
  - Test follow-target change resets dynamics
  - Test euler unwrapping avoids long-path spins
  - **Target: ~10 tests**

- [ ] **Task 2D.2 (Green)**: Create `scripts/ecs/systems/helpers/u_vcam_response_smoother.gd`
  - Extract response smoothing, follow/rotation dynamics, smoothing metadata, euler unwrapping, basis composition
  - Move `_follow_dynamics`, `_rotation_dynamics`, `_smoothing_metadata`

- [ ] **Task 2D.3 (Refactor)**: Wire s_vcam_system.gd to use `U_VCamResponseSmoother`
  - Verify all existing tests pass

### Phase 2E: Extract `u_vcam_landing_impact.gd`

- [ ] **Task 2E.1 (Red)**: Write `tests/unit/ecs/systems/helpers/test_vcam_landing_impact.gd`
  - Test landing event normalizes fall speed to 0–1
  - Test resolve_offset returns recovery dynamics result
  - Test apply_offset modifies transform origin
  - Test clear resets all state
  - **Target: ~6 tests**

- [ ] **Task 2E.2 (Green)**: Create `scripts/ecs/systems/helpers/u_vcam_landing_impact.gd`
  - Extract landing event handling, impact offset dynamics, recovery state
  - Move `_landing_recovery_dynamics`, `_landing_recovery_state_id`, `_landing_recovery_frequency_hz`, `_landing_response_event_serial/normalized`

- [ ] **Task 2E.3 (Refactor)**: Wire s_vcam_system.gd to use `U_VCamLandingImpact`
  - Verify all existing tests pass

### Phase 2F: ~~Extract `u_vcam_first_person_effects.gd`~~ *(DROPPED — Phase 1I removed first-person mode)*

### Phase 2G: Refactor s_vcam_system.gd as Coordinator

- [ ] **Task 2G.1**: Refactor `_evaluate_and_submit` as thin pipeline
  - Replace all inline logic with helper delegation calls
  - Pipeline: look_input → rotation → evaluate → orbit_effects → smoother → landing → submit

- [ ] **Task 2G.2**: Refactor prune/clear as coordinator
  - Replace per-dict pruning with `helper.prune()` calls
  - Replace per-dict clearing with `helper.clear_all()` / `helper.clear_for_vcam()` calls

- [ ] **Task 2G.3**: Clean up remaining coordinator code
  - Remove orphaned helper functions, unused imports, dead state vars
  - Verify file is ~400–600 lines
  - Run full test suite — verify all green

### Phase 2H: Phase 2 commit + docs

- [ ] **Task 2H.1**: Commit Phase 2 implementation
- [ ] **Task 2H.2**: Update continuation prompt and this task file with Phase 2 completion notes

---

## Phase 3: Extract Blend Manager from m_vcam_manager.gd (TDD)

**Exit Criteria:** `m_vcam_manager.gd` is ~600–700 lines. Blend helper has dedicated unit tests. All existing blend tests pass unchanged.

### Phase 3A: Extract `u_vcam_blend_manager.gd`

- [ ] **Task 3A.1 (Red)**: Write `tests/unit/managers/helpers/test_vcam_blend_manager.gd`
  - Test configure_transition sets up blend state
  - Test advance progresses blend and completes at duration
  - Test is_active/get_progress reflect blend state
  - Test startup blend queues and resolves transform
  - Test recover_invalid_members handles freed vCams
  - Test reentrant blend snapshots current blended pose
  - **Target: ~10 tests**

- [ ] **Task 3A.2 (Green)**: Create `scripts/managers/helpers/u_vcam_blend_manager.gd`
  - Extract live blend + startup blend state machines from m_vcam_manager.gd
  - Move all blend state variables
  - API: `configure_transition(...)`, `advance(delta)`, `is_active()`, `get_progress()`, `queue_startup_blend(...)`, `resolve_startup_transform(...)`, `recover_invalid_members(...)`, `clear()`

- [ ] **Task 3A.3 (Refactor)**: Wire m_vcam_manager.gd to use `U_VCamBlendManager`
  - Replace inline blend logic with helper delegation
  - Verify all existing blend tests pass
  - Verify manager is ~600–700 lines

### Phase 3B: Phase 3 commit + docs

- [ ] **Task 3B.1**: Commit Phase 3 implementation
- [ ] **Task 3B.2**: Update continuation prompt and this task file with Phase 3 completion notes

---

## ~~Phase 4: Enhance First-Person Mode~~ *(DROPPED — Phase 1I removed first-person mode)*

---

## Phase 4 (renumbered): Cleanup & Contracts

**Exit Criteria:** Full test suite green. No stale OTS/fixed/FP/aim references in production code. AGENTS.md reflects refactored architecture. Continuation prompt up to date.

### Phase 5A: Update AGENTS.md

- [ ] **Task 5A.1**: Remove stale mode contracts
  - OTS mode resource, evaluator, collision, shoulder sway, landing response
  - OTS movement-profile, facing-lock, reticle, default movement preset
  - Fixed mode resource, evaluator, anchor resolution, path following
  - First-person mode resource, aim activation, aim blend, strafe tilt
  - Aim pipeline contracts (touch aim, input source aim_pressed)

- [ ] **Task 5A.2**: Add helper architecture contracts
  - Document 5 extracted system helpers and blend manager helper
  - Document coordinator pipeline pattern
  - Simplify evaluator contract (orbit only, no fixed_anchor param)
  - Update rotation continuity contract for orbit-only

### Phase 5B: Dead code sweep

- [ ] **Task 5B.1**: Grep for stale references
  - Patterns to sweep (expect zero hits in production code): `RS_VCAM_MODE_OTS`, `RS_VCAM_MODE_FIXED`, `RS_VCAM_MODE_FIRST_PERSON`, `_ots_`, `OTSReticle`, `shoulder_sway`, `path_follow_helper`, `cfg_default_ots`, `cfg_default_fixed`, `cfg_default_first_person`, `cfg_ots_movement`, `ots_collision`, `C_VCamOTSComponent`, `C_VCamFirstPersonComponent`, `_is_ots_mode`, `_is_first_person_mode`, `_evaluate_ots`, `_evaluate_fixed`, `_evaluate_first_person`, `_resolve_ots_values`, `_resolve_fixed_values`, `_resolve_first_person_values`, `aim_pressed`, `aim_toggled`, `aim_restore`, `_aim_restore_vcam_id`, `_aim_toggled_on`, `_aim_prev_pressed`, `_read_aim_pressed`, `aim_blend_duration`, `aim_exit_blend_duration`, `consume_aim`, `update_aim_state`, `strafe_tilt`, `head_offset`, `look_multiplier`
  - Verify zero hits for stale patterns in production code (test mocks/historical docs excluded)

- [ ] **Task 5B.2**: Verify no orphaned files
  - Check for orphaned `.uid` files for deleted scripts/resources
  - Verify no stale `.tres` references in scene files

- [ ] **Task 5B.3**: Audit RS_VCamResponse
  - Verify orbit-specific fields (`look_ahead_*`, `ground_relative_*`, `orbit_look_bypass_*`) are still consumed
  - Remove any fields that no longer have consumers

### Phase 5C: Update documentation

- [ ] **Task 5C.1**: Update `docs/vcam_manager/vcam-manager-overview.md`
  - Remove OTS/fixed/first-person mode descriptions
  - Add helper architecture section
  - Document orbit-only mode system

- [ ] **Task 5C.2**: Update `docs/vcam_manager/vcam-manager-continuation-prompt.md`
  - Reflect refactored architecture (orbit-only, helper-based system, blend manager extraction)
  - Mark all refactor phases complete with dates

- [ ] **Task 5C.3**: Mark this task file complete

### Phase 5D: Phase 5 commit

- [ ] **Task 5D.1**: Commit Phase 5 cleanup
- [ ] **Task 5D.2**: Run final full test suite — verify all green
