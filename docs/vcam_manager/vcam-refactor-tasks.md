# vCam Refactor — Task Checklist

**Scope:** Full architectural refactor of the vCam system — remove OTS + Fixed modes, decompose the 4,102-line `s_vcam_system.gd` God object into focused helpers, extract blend management from `m_vcam_manager.gd`, enhance first-person mode, and update contracts/documentation.

**Quality target:** Match the modularity of `M_SaveManager` (740 lines + 4 helpers) and `M_SceneManager` (1,172 lines + 7 helpers). Each file 200–500 lines, single responsibility, TDD where applicable.

---

## Pre-Implementation Checklist

Before starting Phase 1, verify:

- [ ] **PRE-1**: Read required documentation
  - Read `AGENTS.md`, `docs/general/DEV_PITFALLS.md`, `docs/general/STYLE_GUIDE.md`
  - Read `docs/vcam_manager/vcam-manager-overview.md` and `vcam-manager-continuation-prompt.md`
  - Read `scripts/ecs/systems/s_vcam_system.gd` (understand full evaluation pipeline)
  - Read `scripts/managers/m_vcam_manager.gd` (understand blend + registration)

- [ ] **PRE-2**: Verify branch is `vcam` and working tree is clean

---

## Per-Phase Documentation Cadence (Mandatory)

- [ ] **DOC-1**: After each completed phase, update `docs/vcam_manager/vcam-manager-continuation-prompt.md` with exact phase status.
- [ ] **DOC-2**: After each completed phase, update this task file with `[x]` marks and completion notes.
- [ ] **DOC-3**: Update `AGENTS.md` when architecture contracts change (Phase 1 removals, Phase 2/3 helper contracts).
- [ ] **DOC-4**: Commit documentation updates separately from implementation per AGENTS requirements.

---

## Phase 1: Remove OTS + Fixed Modes

**Exit Criteria:** All remaining tests pass. Only orbit + first-person modes remain. Zero references to OTS/fixed in production code.

### Phase 1A: Remove OTS from s_vcam_system.gd

- [ ] **Task 1A.1**: Remove OTS constants and imports
  - Delete `RS_VCAM_MODE_OTS_SCRIPT` const (line 24)
  - Delete `OTS_MIN_CAMERA_DISTANCE`, `OTS_LANDING_FALL_SPEED_MIN/MAX`, `OTS_LANDING_RESPONSE_EPSILON`, `DEFAULT_OTS_AIM_BLEND_DURATION` constants
  - Delete `debug_ots_vertical_logging` export and `_debug_ots_vertical_log_cooldown_sec`

- [ ] **Task 1A.2**: Remove OTS state dictionaries and aim state
  - Delete `_shoulder_sway_state`, `_ots_collision_state`, `_ots_landing_response_state` dicts
  - Delete `_debug_ots_profile_signature_by_vcam`, `_debug_ots_pitch_clamped_by_vcam` dicts
  - Delete `_aim_restore_vcam_id`, `_aim_toggled_on`, `_aim_prev_pressed` vars

- [ ] **Task 1A.3**: Remove OTS functions
  - Delete shoulder sway functions (`_apply_ots_shoulder_sway`, `_ensure_ots_shoulder_sway_state`, `_clear_ots_shoulder_sway_state_for_vcam`)
  - Delete collision avoidance functions (`_apply_ots_collision_avoidance` and all cast/state/hit/exclude helpers)
  - Delete landing response functions (`_apply_ots_landing_camera_response` and state helpers)
  - Delete aim activation functions (`_process_aim_activation`, `_find_aim_target_ots_vcam_id`, `_is_ots_mode`, `_resolve_ots_aim_blend_duration`, `_resolve_ots_aim_exit_blend_duration`)
  - Delete OTS debug logging (`_debug_log_ots_vertical_diagnostics`)

- [ ] **Task 1A.4**: Remove OTS branches from shared functions
  - Remove OTS from `_evaluate_and_submit` pipeline (shoulder sway, collision, landing response calls)
  - Remove OTS from `process_tick` (aim activation calls)
  - Remove OTS from `_is_look_driven_mode_script`, `_is_look_rotation_smoothing_mode`, `_is_follow_target_required`
  - Remove OTS from `_prune_smoothing_state`, `_clear_all_smoothing_state`, `_clear_smoothing_state_for_vcam`
  - Remove OTS from `_exit_tree` cleanup

### Phase 1B: Remove Fixed mode from s_vcam_system.gd

- [ ] **Task 1B.1**: Remove Fixed constants, state, and imports
  - Delete `RS_VCAM_MODE_FIXED_SCRIPT` const
  - Delete `_path_follow_helpers` dictionary

- [ ] **Task 1B.2**: Remove Fixed functions
  - Delete `_is_path_fixed_mode`, `_resolve_or_create_path_anchor`, `_resolve_fixed_anchor_for_component`
  - Delete `_prune_path_helpers`, `_teardown_path_helpers`

- [ ] **Task 1B.3**: Remove Fixed branches from shared functions
  - Remove fixed branch from `_apply_rotation_transition`
  - Remove fixed branch from `_is_follow_target_required`, `_is_fixed_anchor_required` (delete entire function)
  - Remove fixed branch from `_evaluate_and_submit` (fixed anchor resolution)
  - Remove fixed-mode smoothing branch from `_step_smoothing_state`
  - Remove `_teardown_path_helpers` from `_exit_tree`, `_prune_path_helpers` from `process_tick`

### Phase 1C: Remove OTS + Fixed from evaluator

- [ ] **Task 1C.1**: Simplify `u_vcam_mode_evaluator.gd`
  - Delete `RS_VCAM_MODE_OTS_SCRIPT` and `RS_VCAM_MODE_FIXED_SCRIPT` constants
  - Remove OTS/fixed branches from `evaluate()` function
  - Remove `fixed_anchor` parameter from `evaluate()` signature
  - Delete `_evaluate_ots`, `_resolve_ots_values`
  - Delete `_evaluate_fixed`, `_resolve_fixed_values`, `_build_look_at_basis_or_fallback`
  - Only orbit + first-person remain

### Phase 1D: Remove OTS from external systems

- [ ] **Task 1D.1**: Clean `s_movement_system.gd`
  - Delete `RS_VCAM_MODE_OTS_SCRIPT` const
  - Remove OTS movement profile resolution call and `_resolve_active_ots_movement_state` function

- [ ] **Task 1D.2**: Clean `s_rotate_to_input_system.gd`
  - Delete `RS_VCAM_MODE_OTS_SCRIPT` const
  - Remove OTS facing lock resolution and `_resolve_active_ots_facing_lock` function

- [ ] **Task 1D.3**: Clean `ui_hud_controller.gd`
  - Delete `RS_VCAM_MODE_OTS_SCRIPT` const and OTS reticle @onready vars
  - Delete all OTS reticle constants, state, and functions
  - Remove OTS reticle calls from `_ready`/`_update` paths

### Phase 1E: Remove Fixed from component

- [ ] **Task 1E.1**: Simplify `c_vcam_component.gd`
  - Remove `fixed_anchor_path` export and `path_node_path` export
  - Remove `get_fixed_anchor()` and `get_path_node()` getters

### Phase 1F: Delete resources and scene nodes

- [ ] **Task 1F.1**: Delete resource files
  - Delete `scripts/resources/display/vcam/rs_vcam_mode_ots.gd`
  - Delete `scripts/resources/display/vcam/rs_vcam_mode_fixed.gd`
  - Delete `resources/display/vcam/cfg_default_ots.tres`
  - Delete `resources/display/vcam/cfg_default_fixed.tres`
  - Delete `resources/base_settings/gameplay/cfg_ots_movement_default.tres`

- [ ] **Task 1F.2**: Update `scenes/templates/tmpl_camera.tscn`
  - Remove C_VCamOTSComponent node and cfg_default_ots ext_resource

- [ ] **Task 1F.3**: Update `scenes/ui/hud/ui_hud_overlay.tscn`
  - Remove OTSReticleContainer and ReticleDot nodes

### Phase 1G: Update tests

- [ ] **Task 1G.1**: Delete mode-specific test files
  - Delete `tests/unit/resources/display/vcam/test_vcam_mode_ots.gd`
  - Delete `tests/unit/resources/display/vcam/test_vcam_mode_fixed.gd`

- [ ] **Task 1G.2**: Update evaluator tests
  - Remove OTS/fixed test cases from `test_vcam_mode_evaluator.gd`
  - Update all `evaluate()` calls to remove `fixed_anchor` parameter

- [ ] **Task 1G.3**: Update system tests
  - Remove OTS/fixed-specific tests from `test_vcam_system.gd`

- [ ] **Task 1G.4**: Update manager and integration tests
  - Remove OTS/fixed runtime paths from `test_vcam_manager.gd`
  - Remove fixed_anchor/path_node tests from `test_vcam_component.gd`
  - Remove OTS/fixed preset references from `test_vcam_mode_presets.gd`
  - Remove OTS/fixed paths from `test_vcam_runtime.gd`, `test_vcam_blend.gd`

- [ ] **Task 1G.5**: Run full test suite — verify all green

### Phase 1H: Phase 1 commit + docs

- [ ] **Task 1H.1**: Commit Phase 1 implementation
- [ ] **Task 1H.2**: Update continuation prompt and this task file with Phase 1 completion notes

---

## Phase 2: Extract Helpers from s_vcam_system.gd (TDD)

**Exit Criteria:** `s_vcam_system.gd` is ~400–600 lines. Six extracted helpers each have dedicated unit tests. All existing system/integration tests pass unchanged.

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

### Phase 2F: Extract `u_vcam_first_person_effects.gd`

- [ ] **Task 2F.1 (Red)**: Write `tests/unit/ecs/systems/helpers/test_vcam_first_person_effects.gd`
  - Test strafe tilt applies roll from lateral movement
  - Test strafe tilt smooths with second-order dynamics
  - Test zero tilt angle disables effect
  - Test prune/clear lifecycle
  - **Target: ~6 tests**

- [ ] **Task 2F.2 (Green)**: Create `scripts/ecs/systems/helpers/u_vcam_first_person_effects.gd`
  - Extract strafe tilt functions and `_first_person_strafe_tilt_state`

- [ ] **Task 2F.3 (Refactor)**: Wire s_vcam_system.gd to use `U_VCamFirstPersonEffects`
  - Verify all existing tests pass

### Phase 2G: Refactor s_vcam_system.gd as Coordinator

- [ ] **Task 2G.1**: Refactor `_evaluate_and_submit` as thin pipeline
  - Replace all inline logic with helper delegation calls
  - Pipeline: look_input → rotation → evaluate → fp_effects → orbit_effects → smoother → landing → submit

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

## Phase 4: Enhance First-Person Mode (TDD)

**Exit Criteria:** First-person is a solid secondary camera mode with opt-in enhancements. All tests pass.

### Phase 4A: First-person enhancement tests

- [ ] **Task 4A.1 (Red)**: Write/update first-person tests
  - Update `tests/unit/ecs/systems/helpers/test_vcam_first_person_effects.gd` for any new effects
  - Update `tests/unit/resources/display/vcam/test_vcam_mode_first_person.gd` for new resource exports
  - Candidate features (all opt-in, default 0.0 = disabled):
    - Sprint FOV boost (`sprint_fov_boost: float`)
    - Landing head dip (`landing_head_dip: float`)

### Phase 4B: Implement enhancements

- [ ] **Task 4B.1 (Green)**: Add new exports to `rs_vcam_mode_first_person.gd`
  - Add opt-in exports with defaults that disable the feature
  - Add to `get_resolved_values()` with validation

- [ ] **Task 4B.2 (Green)**: Implement effects in `u_vcam_first_person_effects.gd`
  - Wire new effects through the helper API
  - Verify all tests pass

### Phase 4C: Phase 4 commit + docs

- [ ] **Task 4C.1**: Commit Phase 4 implementation
- [ ] **Task 4C.2**: Update continuation prompt and this task file with Phase 4 completion notes

---

## Phase 5: Cleanup & Contracts

**Exit Criteria:** Full test suite green. No stale OTS/fixed references in production code. AGENTS.md reflects refactored architecture. Continuation prompt up to date.

### Phase 5A: Update AGENTS.md

- [ ] **Task 5A.1**: Remove OTS contracts (~15 entries)
  - OTS mode resource, evaluator, collision, shoulder sway, landing response, aim activation
  - OTS movement-profile, facing-lock, reticle, default movement preset
  - OTS-specific references in shared contracts (rotation continuity, look smoothing, etc.)

- [ ] **Task 5A.2**: Remove Fixed mode contracts (~5 entries)
  - Fixed mode resource, evaluator, anchor resolution, path following

- [ ] **Task 5A.3**: Add helper architecture contracts
  - Document 6 extracted system helpers and blend manager helper
  - Document coordinator pipeline pattern
  - Simplify evaluator contract (2 modes, no fixed_anchor param)

### Phase 5B: Dead code sweep

- [ ] **Task 5B.1**: Grep for stale references
  - Search: `RS_VCAM_MODE_OTS`, `RS_VCAM_MODE_FIXED`, `_ots_`, `_fixed_`, `OTSReticle`, `aim_pressed`, `shoulder_sway`, `path_follow_helper`
  - Verify zero hits in production code (test mocks/historical docs excluded)

- [ ] **Task 5B.2**: Verify no orphaned files
  - Check for orphaned `.uid` files for deleted scripts/resources
  - Verify no stale `.tres` references in scene files

- [ ] **Task 5B.3**: Audit RS_VCamResponse
  - Verify orbit-specific fields (`look_ahead_*`, `ground_relative_*`, `orbit_look_bypass_*`) are still consumed
  - Remove any fields that no longer have consumers

### Phase 5C: Update documentation

- [ ] **Task 5C.1**: Update `docs/vcam_manager/vcam-manager-overview.md`
  - Remove OTS/fixed mode descriptions
  - Add helper architecture section
  - Document 2-mode system (orbit + first-person)

- [ ] **Task 5C.2**: Update `docs/vcam_manager/vcam-manager-continuation-prompt.md`
  - Reflect refactored architecture (2 modes, helper-based system, blend manager extraction)
  - Mark all refactor phases complete with dates

- [ ] **Task 5C.3**: Mark this task file complete

### Phase 5D: Phase 5 commit

- [ ] **Task 5D.1**: Commit Phase 5 cleanup
- [ ] **Task 5D.2**: Run final full test suite — verify all green
