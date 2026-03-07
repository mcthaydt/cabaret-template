# vCam Manager - Task Checklist

**Progress:** 5 / 5 documentation tasks complete; 0 implementation tasks complete
**Estimated Test Count:** ~296 checks (about 254 automated tests + 42 manual checks)
**Status note:** Strict TDD (Red/Green/Refactor). Each camera mode has a dedicated phase. Mobile drag-look is a hard prerequisite for orbit/first-person completion.
**Manual QA cadence:** Manual checks are embedded in the relevant implementation phases (no standalone manual-testing phase).

---

## Pre-Implementation Checklist

Before starting Phase 0, verify:

- [ ] **PRE-1**: Read required documentation
  - Read `AGENTS.md`, `docs/general/DEV_PITFALLS.md`, `docs/general/STYLE_GUIDE.md`
  - Read `docs/vcam_manager/vcam-manager-plan.md`, `vcam-manager-overview.md`, `vcam-manager-prd.md`
  - Read `scripts/managers/m_camera_manager.gd` and `scripts/interfaces/i_camera_manager.gd`
  - Read `scripts/ecs/systems/s_input_system.gd` and `scripts/ecs/systems/s_touchscreen_system.gd`
  - Read `scripts/state/utils/u_state_slice_manager.gd`

- [ ] **PRE-2**: Understand existing patterns by reading:
  - `scripts/state/m_state_store.gd` (export pattern, initialize_slices call)
  - `scripts/resources/state/rs_vfx_initial_state.gd` (existing vfx initial state pattern)
  - `scripts/managers/m_camera_manager.gd` (shake-parent hierarchy, transition blends)
  - `scripts/ui/hud/ui_mobile_controls.gd` (existing touch control flow)
  - `scripts/utils/display/u_cinema_grade_preview.gd` (editor preview pattern)
  - `tests/mocks/mock_camera_manager.gd` (mock pattern for camera manager)

- [ ] **PRE-3**: Verify branch is `vcam` and working tree is clean

---

## Per-Phase Documentation Cadence (Mandatory)

- [ ] **DOC-1**: After each completed phase, update `docs/vcam_manager/vcam-manager-continuation-prompt.md` with exact phase status and next step.
- [ ] **DOC-2**: After each completed phase, update `docs/vcam_manager/vcam-manager-tasks.md` with `[x]` marks and completion notes.
- [ ] **DOC-3**: Update `AGENTS.md` when new stable vCam architecture/pattern contracts emerge.
- [ ] **DOC-4**: Update `docs/general/DEV_PITFALLS.md` with new pitfalls discovered during vCam implementation.
- [ ] **DOC-5**: Commit documentation updates separately from implementation, per AGENTS requirements.

---

## Documentation Alignment (Complete)

- [x] Align runtime wiring with actual root and gameplay scene structure
- [x] Split transient `vcam` observability from persisted silhouette settings
- [x] Correct blend, shake, and soft-zone architecture to match repo reality
- [x] Align file paths and naming with the current style guide
- [x] Make mobile drag-look a hard requirement for rotatable orbit and first-person support

---

## Phase 0: State and Persistence

**Exit Criteria:** All ~56 Redux/UI tests pass, `vcam` slice registered as transient in `M_StateStore`, `vfx.occlusion_silhouette_enabled` persisted, VFX settings exposes the silhouette toggle, touchscreen drag-look settings persisted, no console errors

### Phase 0A: Touchscreen Drag-Look Settings Prerequisite

- [ ] **Task 0A.1 (Red)**: Write tests for touchscreen drag-look settings
  - Modify `tests/unit/input_manager/test_u_input_reducer.gd` (or create new test file)
  - Test `look_drag_sensitivity` field exists in touchscreen settings with default `1.0`
  - Test `invert_look_y` field exists in touchscreen settings with default `false`
  - Test reducer handles `set_look_drag_sensitivity` action with valid float
  - Test reducer clamps `look_drag_sensitivity` to valid range (e.g. 0.1-5.0)
  - Test reducer handles `set_invert_look_y` action with bool
  - Test reducer ignores unknown action (returns same state)
  - **Target: 6 tests**

- [ ] **Task 0A.2 (Green)**: Implement touchscreen drag-look settings
  - Modify `scripts/resources/input/rs_touchscreen_settings.gd`: add `look_drag_sensitivity: float = 1.0`, `invert_look_y: bool = false`
  - Modify `resources/input/touchscreen_settings/cfg_default_touchscreen_settings.tres`: set new defaults
  - Modify `scripts/state/reducers/u_input_reducer.gd`: add action handling
  - All tests should pass

- [ ] **Task 0A.3 (Red)**: Write tests for touchscreen settings overlay updates
  - Modify `tests/unit/ui/test_touchscreen_settings_overlay.gd`
  - Test overlay displays drag-look sensitivity slider
  - Test overlay displays invert-Y toggle
  - Test overlay preview dispatches look sensitivity changes
  - Test overlay apply persists look settings
  - **Target: 4 tests**

- [ ] **Task 0A.4 (Green)**: Implement touchscreen settings overlay changes
  - Modify `scripts/ui/overlays/ui_touchscreen_settings_overlay.gd`: add drag-look sensitivity slider and invert-Y toggle
  - All tests should pass

---

### Phase 0B: Persisted Silhouette Toggle in VFX Settings

- [ ] **Task 0B.1 (Red)**: Write tests for `occlusion_silhouette_enabled` in VFX state
  - Modify `tests/unit/state/test_vfx_initial_state.gd`
  - Test `occlusion_silhouette_enabled` field exists with default `true`
  - Test `to_dictionary()` includes `occlusion_silhouette_enabled`
  - **Target: 2 tests**

- [ ] **Task 0B.2 (Green)**: Add field to RS_VFXInitialState
  - Modify `scripts/resources/state/rs_vfx_initial_state.gd`: add `@export var occlusion_silhouette_enabled: bool = true`
  - All tests should pass

- [ ] **Task 0B.3 (Red)**: Write tests for VFX actions and reducer
  - Modify `tests/unit/state/test_vfx_reducer.gd`
  - Test `set_occlusion_silhouette_enabled` action structure
  - Test reducer sets `occlusion_silhouette_enabled = true`
  - Test reducer sets `occlusion_silhouette_enabled = false`
  - Test reducer returns same state for unrelated action
  - **Target: 4 tests**

- [ ] **Task 0B.4 (Green)**: Implement VFX action and reducer
  - Modify `scripts/state/actions/u_vfx_actions.gd`: add `ACTION_SET_OCCLUSION_SILHOUETTE_ENABLED`
  - Modify `scripts/state/reducers/u_vfx_reducer.gd`: handle action
  - All tests should pass

- [ ] **Task 0B.5 (Red)**: Write tests for VFX selector
  - Modify `tests/unit/state/test_vfx_selectors.gd`
  - Test `is_occlusion_silhouette_enabled()` returns value from state
  - Test selector returns `true` when slice missing (default)
  - Test selector returns `true` when field missing (default)
  - **Target: 3 tests**

- [ ] **Task 0B.6 (Green)**: Implement VFX selector
  - Modify `scripts/state/selectors/u_vfx_selectors.gd`: add `is_occlusion_silhouette_enabled(state)`
  - All tests should pass

- [ ] **Task 0B.7 (Red)**: Write tests for VFX settings overlay silhouette toggle
  - Create/modify `tests/unit/ui/test_vfx_settings_overlay.gd`
  - Modify `tests/unit/ui/test_vfx_settings_overlay_localization.gd`
  - Test overlay renders a silhouette toggle bound to `occlusion_silhouette_enabled`
  - Test Apply dispatch persists silhouette toggle changes through `U_VFXActions`
  - Test Reset restores silhouette toggle to default (`true`)
  - Test localization updates silhouette label/tooltip keys
  - **Target: 4 tests**

- [ ] **Task 0B.8 (Green)**: Implement VFX settings overlay silhouette toggle
  - Modify `scripts/ui/settings/ui_vfx_settings_overlay.gd`: add control wiring, apply/reset/localization handling
  - Modify `scenes/ui/overlays/settings/ui_vfx_settings_overlay.tscn`: add silhouette toggle row
  - Modify all UI locale resources under `resources/localization/cfg_locale_*_ui.tres` for new silhouette label/tooltip keys
  - All tests should pass

---

### Phase 0C: vCam Initial State Resource

- [ ] **Task 0C.1 (Red)**: Write tests for RS_VCamInitialState
  - Create `tests/unit/state/test_vcam_initial_state.gd`
  - Test `to_dictionary()` returns `active_vcam_id` as `&""`
  - Test `to_dictionary()` returns `active_mode` as `""`
  - Test `to_dictionary()` returns `previous_vcam_id` as `&""`
  - Test `to_dictionary()` returns `blend_progress` as `1.0`
  - Test `to_dictionary()` returns `is_blending` as `false`
  - Test `to_dictionary()` returns `silhouette_active_count` as `0`
  - Test `to_dictionary()` returns exactly 6 keys
  - **Target: 7 tests**

- [ ] **Task 0C.2 (Green)**: Implement RS_VCamInitialState
  - Create `scripts/resources/state/rs_vcam_initial_state.gd`
  - Implement `to_dictionary()` returning all 6 fields
  - All tests should pass

- [ ] **Task 0C.3**: Create default resource instance
  - Create `resources/state/cfg_default_vcam_initial_state.tres`
  - Set all fields to defaults

---

### Phase 0D: vCam Actions and Reducer

- [ ] **Task 0D.1 (Red)**: Write tests for U_VCamActions
  - Create `tests/unit/state/test_vcam_actions.gd`
  - Test `set_active_runtime(vcam_id, mode)` action structure has correct type and payload
  - Test `start_blend(previous_id)` action structure
  - Test `update_blend(progress)` action structure
  - Test `complete_blend()` action structure
  - Test `update_silhouette_count(count)` action structure
  - **Target: 5 tests**

- [ ] **Task 0D.2 (Green)**: Implement U_VCamActions
  - Create `scripts/state/actions/u_vcam_actions.gd`
  - Add 5 action type constants and static creator functions
  - All tests should pass

- [ ] **Task 0D.3 (Red)**: Write tests for U_VCamReducer
  - Create `tests/unit/state/test_vcam_reducer.gd`
  - Test `set_active_runtime` updates `active_vcam_id` and `active_mode`
  - Test `start_blend` sets `is_blending = true`, `blend_progress = 0.0`, `previous_vcam_id`
  - Test `update_blend` clamps progress to `0.0..1.0`
  - Test `update_blend` with progress below 0.0 clamps to 0.0
  - Test `update_blend` with progress above 1.0 clamps to 1.0
  - Test `complete_blend` clears `previous_vcam_id`, sets `blend_progress = 1.0`, `is_blending = false`
  - Test `update_silhouette_count` stores non-negative count
  - Test `update_silhouette_count` with negative clamps to 0
  - Test reducer returns same state for unknown action
  - Test reducer immutability (old state reference != new state reference)
  - **Target: 10 tests**

- [ ] **Task 0D.4 (Green)**: Implement U_VCamReducer
  - Create `scripts/state/reducers/u_vcam_reducer.gd`
  - Implement `reduce(state, action)` with match statement
  - All tests should pass

---

### Phase 0E: Selectors, Store Export, and Transient Slice Registration

- [ ] **Task 0E.1 (Red)**: Write tests for U_VCamSelectors
  - Create `tests/unit/state/test_vcam_selectors.gd`
  - Test `get_active_vcam_id(state)` returns value from state
  - Test `get_active_vcam_id(state)` returns `&""` when slice missing
  - Test `get_active_mode(state)` returns value from state
  - Test `get_active_mode(state)` returns `""` when field missing
  - Test `get_previous_vcam_id(state)` returns value from state
  - Test `get_blend_progress(state)` returns value from state
  - Test `get_blend_progress(state)` returns `1.0` when missing
  - Test `is_blending(state)` returns value from state
  - Test `is_blending(state)` returns `false` when missing
  - Test `get_silhouette_active_count(state)` returns value from state
  - Test `get_silhouette_active_count(state)` returns `0` when missing
  - **Target: 11 tests**

- [ ] **Task 0E.2 (Green)**: Implement U_VCamSelectors
  - Create `scripts/state/selectors/u_vcam_selectors.gd`
  - All selectors null-safe and slice-safe
  - All tests should pass

- [ ] **Task 0E.3**: Integrate vcam slice with M_StateStore
  - Modify `scripts/state/m_state_store.gd`: add `@export var vcam_initial_state: Resource`
  - Modify `scripts/state/utils/u_state_slice_manager.gd`: add `vcam` slice registration with `is_transient = true`
  - Modify `scenes/root.tscn`: assign `cfg_default_vcam_initial_state.tres`

- [ ] **Task 0E.4**: Verify integration
  - Run existing state tests (no regressions)
  - Verify `vcam` slice appears in `get_state()` output
  - Verify `vcam` slice is registered as transient
  - Verify `vcam` is NOT included in global settings persistence

---

## Phase 1: Base Authoring Resources (Soft Zone + Blend Hint)

**Exit Criteria:** All ~14 resource tests pass, default `.tres` instances created

### Phase 1A: RS_VCamSoftZone

- [ ] **Task 1A.1 (Red)**: Write tests for RS_VCamSoftZone
  - Create `tests/unit/resources/display/vcam/test_vcam_soft_zone.gd`
  - Test `dead_zone_width` field exists with default (e.g. 0.1)
  - Test `dead_zone_height` field exists with default (e.g. 0.1)
  - Test `soft_zone_width` field exists with default (e.g. 0.4)
  - Test `soft_zone_height` field exists with default (e.g. 0.4)
  - Test `damping` field exists with default (e.g. 2.0)
  - Test all values are non-negative
  - Test soft zone dimensions >= dead zone dimensions conceptually
  - **Target: 7 tests**

- [ ] **Task 1A.2 (Green)**: Implement RS_VCamSoftZone
  - Create `scripts/resources/display/vcam/rs_vcam_soft_zone.gd`
  - All `@export` fields with sensible defaults
  - All tests should pass

---

### Phase 1B: RS_VCamBlendHint

- [ ] **Task 1B.1 (Red)**: Write tests for RS_VCamBlendHint
  - Create `tests/unit/resources/display/vcam/test_vcam_blend_hint.gd`
  - Test `blend_duration` field exists with default (e.g. 1.0)
  - Test `ease_type` field exists with default (e.g. `Tween.EASE_IN_OUT`)
  - Test `trans_type` field exists with default (e.g. `Tween.TRANS_CUBIC`)
  - Test `cut_on_distance_threshold` field exists with default `0.0` (disabled)
  - Test `blend_duration` is non-negative
  - Test `cut_on_distance_threshold` is non-negative
  - Test zero `blend_duration` means instant cut
  - **Target: 7 tests**

- [ ] **Task 1B.2 (Green)**: Implement RS_VCamBlendHint
  - Create `scripts/resources/display/vcam/rs_vcam_blend_hint.gd`
  - All `@export` fields with sensible defaults
  - All tests should pass

---

### Phase 1C: Default Preset Resources

- [ ] **Task 1C.1**: Create default resource instances
  - Create `resources/display/vcam/cfg_default_soft_zone.tres`
  - Create `resources/display/vcam/cfg_default_blend_hint.tres`
  - Verify resources load without errors

---

## Phase 2: Orbit Camera Mode

**Exit Criteria:** All ~18 orbit tests pass (8 resource + 10 evaluator), orbit evaluation produces correct transforms for all authored configurations (runtime manual checks deferred to Phase 6C after scene wiring)

### Phase 2A: RS_VCamModeOrbit Resource

- [ ] **Task 2A.1 (Red)**: Write tests for RS_VCamModeOrbit
  - Create `tests/unit/resources/display/vcam/test_vcam_mode_orbit.gd`
  - Test `distance` field exists with default (e.g. 5.0)
  - Test `authored_pitch` field exists with default (e.g. -20.0 degrees)
  - Test `authored_yaw` field exists with default (e.g. 0.0)
  - Test `allow_player_rotation` field exists with default `true`
  - Test `rotation_speed` field exists with default (e.g. 2.0)
  - Test `fov` field exists with default (e.g. 75.0)
  - Test `distance` must be positive
  - Test `fov` must be within valid range (1.0-179.0)
  - **Target: 8 tests**

- [ ] **Task 2A.2 (Green)**: Implement RS_VCamModeOrbit
  - Create `scripts/resources/display/vcam/rs_vcam_mode_orbit.gd`
  - All `@export` fields with sensible defaults
  - All tests should pass

---

### Phase 2B: Orbit Mode Evaluator

- [ ] **Task 2B.1 (Red)**: Write tests for orbit evaluation in U_VCamModeEvaluator
  - Create `tests/unit/managers/helpers/test_vcam_mode_evaluator.gd`
  - Test orbit evaluation with default settings returns a valid `transform` key
  - Test orbit evaluation returns correct `fov` key matching resource
  - Test orbit evaluation returns `mode_name == "orbit"`
  - Test orbit camera is positioned at `distance` behind and above follow target based on `authored_pitch`
  - Test orbit camera looks at the follow target
  - Test orbit with `allow_player_rotation = true` applies `runtime_yaw` and `runtime_pitch`
  - Test orbit with `allow_player_rotation = false` ignores `runtime_yaw` and `runtime_pitch`
  - Test orbit with zero distance returns empty dictionary (invalid)
  - Test orbit with null follow target returns empty dictionary
  - Test orbit with null mode resource returns empty dictionary without warnings
  - **Target: 10 tests**

- [ ] **Task 2B.2 (Green)**: Implement orbit evaluation in U_VCamModeEvaluator
  - Create `scripts/managers/helpers/u_vcam_mode_evaluator.gd`
  - Implement `static func evaluate(mode, follow_target, look_at_target, runtime_yaw, runtime_pitch) -> Dictionary`
  - Handle orbit mode: compute spherical-to-cartesian position from follow target
  - Return `{transform, fov, mode_name}` or `{}` on invalid input
  - All tests should pass

- [ ] **Task 2B.3**: Create default orbit resource instance
  - Create `resources/display/vcam/cfg_default_orbit.tres`
  - Verify resource loads and evaluates without errors

---

## Phase 3: Fixed Camera Mode

**Exit Criteria:** All ~14 fixed tests pass (6 resource + 8 evaluator), fixed evaluation produces correct transforms for anchored and tracking configurations (runtime manual checks deferred to Phase 6C after scene wiring)

### Phase 3A: RS_VCamModeFixed Resource

- [ ] **Task 3A.1 (Red)**: Write tests for RS_VCamModeFixed
  - Create `tests/unit/resources/display/vcam/test_vcam_mode_fixed.gd`
  - Test `use_world_anchor` field exists with default `true`
  - Test `track_target` field exists with default `false`
  - Test `fov` field exists with default (e.g. 75.0)
  - Test `fov` must be within valid range (1.0-179.0)
  - Test `tracking_damping` field exists with default (e.g. 5.0)
  - Test `tracking_damping` must be non-negative
  - **Target: 6 tests**

- [ ] **Task 3A.2 (Green)**: Implement RS_VCamModeFixed
  - Create `scripts/resources/display/vcam/rs_vcam_mode_fixed.gd`
  - All `@export` fields with sensible defaults
  - All tests should pass

---

### Phase 3B: Fixed Mode Evaluator

- [ ] **Task 3B.1 (Red)**: Write tests for fixed evaluation in U_VCamModeEvaluator
  - Add to `tests/unit/managers/helpers/test_vcam_mode_evaluator.gd`
  - Test fixed evaluation with `use_world_anchor = true` uses resolved `C_VCamComponent.fixed_anchor_path` `Node3D` transform, with fallback to vCam host entity-root `Node3D`, not `C_VCamComponent` transform
  - Test fixed evaluation returns correct `fov` matching resource
  - Test fixed evaluation returns `mode_name == "fixed"`
  - Test fixed with `track_target = true` looks toward follow target
  - Test fixed with `track_target = false` keeps authored rotation
  - Test fixed with `track_target = true` but null follow target falls back to authored rotation
  - Test fixed with null mode resource returns empty dictionary
  - Test fixed evaluation ignores `runtime_yaw` and `runtime_pitch` (fixed cameras are not player-rotatable)
  - **Target: 8 tests**

- [ ] **Task 3B.2 (Green)**: Implement fixed evaluation in U_VCamModeEvaluator
  - Extend evaluator to handle fixed mode
  - Ensure evaluator consumes resolved fixed-anchor `Node3D` input (`fixed_anchor_path` first, entity-root fallback)
  - All tests should pass

---

## Phase 4: First-Person Camera Mode

**Exit Criteria:** All ~18 first-person tests pass (8 resource + 10 evaluator), first-person evaluation produces correct transforms with pitch clamping and head offset (runtime manual checks deferred to Phase 6C after scene wiring)

### Phase 4A: RS_VCamModeFirstPerson Resource

- [ ] **Task 4A.1 (Red)**: Write tests for RS_VCamModeFirstPerson
  - Create `tests/unit/resources/display/vcam/test_vcam_mode_first_person.gd`
  - Test `head_offset` field exists with default (e.g. `Vector3(0, 1.7, 0)`)
  - Test `look_multiplier` field exists with default `1.0`
  - Test `pitch_min` field exists with default (e.g. -89.0)
  - Test `pitch_max` field exists with default (e.g. 89.0)
  - Test `fov` field exists with default (e.g. 75.0)
  - Test `fov` must be within valid range (1.0-179.0)
  - Test `look_multiplier` must be positive
  - Test `pitch_min` < `pitch_max` constraint
  - **Target: 8 tests**

- [ ] **Task 4A.2 (Green)**: Implement RS_VCamModeFirstPerson
  - Create `scripts/resources/display/vcam/rs_vcam_mode_first_person.gd`
  - All `@export` fields with sensible defaults
  - All tests should pass

---

### Phase 4B: First-Person Mode Evaluator

- [ ] **Task 4B.1 (Red)**: Write tests for first-person evaluation in U_VCamModeEvaluator
  - Add to `tests/unit/managers/helpers/test_vcam_mode_evaluator.gd`
  - Test first-person evaluation returns a valid `transform` key
  - Test first-person evaluation returns correct `fov` matching resource
  - Test first-person evaluation returns `mode_name == "first_person"`
  - Test first-person camera is positioned at follow target + `head_offset`
  - Test first-person applies `runtime_yaw` for horizontal rotation
  - Test first-person applies `runtime_pitch` for vertical rotation
  - Test first-person clamps pitch to `pitch_min`/`pitch_max` range
  - Test first-person pitch at min boundary does not exceed
  - Test first-person pitch at max boundary does not exceed
  - Test first-person with null follow target returns empty dictionary
  - **Target: 10 tests**

- [ ] **Task 4B.2 (Green)**: Implement first-person evaluation in U_VCamModeEvaluator
  - Extend evaluator to handle first-person mode
  - All tests should pass

- [ ] **Task 4B.3 (Refactor)**: Review U_VCamModeEvaluator for clarity
  - Ensure all three mode branches are clean and well-separated
  - Verify null/invalid resource handling is consistent across modes
  - No new functionality, only code quality

---

## Phase 5: Component, Interface, and Manager Core

**Exit Criteria:** All ~28 tests pass (10 component + 8 interface/manager registration + 10 manager active-selection), `M_VCamManager` registered with ServiceLocator

### Phase 5A: C_VCamComponent

- [ ] **Task 5A.1 (Red)**: Write tests for C_VCamComponent
  - Create `tests/unit/ecs/components/test_vcam_component.gd`
  - Test extends `BaseECSComponent`
  - Test `COMPONENT_TYPE` constant is `&"VCamComponent"`
  - Test `vcam_id` export exists
  - Test `priority` export exists with default `0`
  - Test `mode` export exists (Resource type)
  - Test `fixed_anchor_path` export exists (NodePath)
  - Test `follow_target_path` export exists (NodePath)
  - Test `look_at_target_path` export exists (NodePath)
  - Test `soft_zone` export exists (Resource type)
  - Test `blend_hint` export exists (Resource type)
  - Test `is_active` export exists with default `true`
  - **Target: 11 tests**

- [ ] **Task 5A.2 (Green)**: Implement C_VCamComponent
  - Create `scripts/ecs/components/c_vcam_component.gd`
  - Extend `BaseECSComponent`, set `COMPONENT_TYPE`
  - Add all exports and runtime-only `runtime_yaw`, `runtime_pitch` vars
  - Implement null-safe `get_follow_target()` and `get_look_at_target()` typed getters
  - All tests should pass

---

### Phase 5B: I_VCamManager Interface

- [ ] **Task 5B.1**: Create I_VCamManager interface
  - Create `scripts/interfaces/i_vcam_manager.gd`
  - Define all 8 interface methods with `push_error` defaults:
    - `register_vcam(vcam)`
    - `unregister_vcam(vcam)`
    - `set_active_vcam(vcam_id, blend_duration)`
    - `get_active_vcam_id()`
    - `get_previous_vcam_id()`
    - `submit_evaluated_camera(vcam_id, result)`
    - `get_blend_progress()`
    - `is_blending()`

---

### Phase 5C: M_VCamManager Core (Registration and Active Selection)

- [ ] **Task 5C.1 (Red)**: Write tests for M_VCamManager registration
  - Create `tests/unit/managers/test_vcam_manager.gd`
  - Test extends `I_VCamManager`
  - Test registers with ServiceLocator as `vcam_manager`
  - Test `register_vcam()` adds component to internal registry
  - Test `register_vcam()` with duplicate `vcam_id` logs error and rejects
  - Test `unregister_vcam()` removes component from registry
  - Test `unregister_vcam()` with unknown component is a no-op
  - Test unregistering the active vcam clears active state
  - Test unregistering all vcams clears all state
  - **Target: 8 tests**

- [ ] **Task 5C.2 (Green)**: Implement M_VCamManager registration
  - Create `scripts/managers/m_vcam_manager.gd` extending `I_VCamManager`
  - Implement registration dictionary, ServiceLocator registration
  - All tests should pass

- [ ] **Task 5C.3 (Red)**: Write tests for M_VCamManager active selection
  - Add to `tests/unit/managers/test_vcam_manager.gd`
  - Test `set_active_vcam()` by explicit ID sets active vcam
  - Test `set_active_vcam()` with unknown ID logs error and does nothing
  - Test priority-based selection: highest priority wins
  - Test priority tie-break: ascending `vcam_id` wins
  - Test `get_active_vcam_id()` returns current active
  - Test `get_active_vcam_id()` returns `&""` when no vcams registered
  - Test `set_active_vcam()` dispatches `vcam/set_active_runtime` action
  - Test `is_active = false` on component excludes it from priority selection
  - Test changing `is_active` to false on the active vcam triggers reselection
  - Test priority reselection after unregister picks next highest
  - **Target: 10 tests**

- [ ] **Task 5C.4 (Green)**: Implement M_VCamManager active selection
  - Add active selection logic with explicit override and priority fallback
  - Add Redux dispatch integration (injection-first, ServiceLocator fallback)
  - All tests should pass

---

## Phase 6: vCam System (ECS) and Scene Wiring

**Exit Criteria:** All ~12 system tests pass, `S_VCamSystem` reads look input from Redux, evaluates active/outgoing vcams, submits results to manager, scene wiring complete, desktop manual camera checks pass (`MT-01..MT-04`, `MT-09..MT-15`, `MT-18`)

### Phase 6A: S_VCamSystem

- [ ] **Task 6A.1 (Red)**: Write tests for S_VCamSystem
  - Create `tests/unit/ecs/systems/test_vcam_system.gd`
  - Test extends `BaseECSSystem`
  - Test resolves `I_VCamManager` via ServiceLocator
  - Test reads `look_input` from gameplay Redux slice
  - Test evaluates active vCam each tick via `U_VCamModeEvaluator`
  - Test updates `runtime_yaw` on orbit component when `allow_player_rotation = true`
  - Test updates `runtime_pitch` on orbit component when `allow_player_rotation = true`
  - Test does NOT update yaw/pitch on orbit when `allow_player_rotation = false`
  - Test updates yaw/pitch on first-person component using `look_multiplier`
  - Test submits evaluated result to `M_VCamManager.submit_evaluated_camera()`
  - Test evaluates outgoing vCam too when `manager.is_blending()` is true
  - Test does nothing when no active vCam exists
  - Test does nothing when manager is not found
  - **Target: 12 tests**

- [ ] **Task 6A.2 (Green)**: Implement S_VCamSystem
  - Create `scripts/ecs/systems/s_vcam_system.gd`
  - Extend `BaseECSSystem`, implement `process_tick(delta)`
  - Resolve manager, read look input, evaluate modes, submit results
  - All tests should pass

---

### Phase 6B: Scene Wiring

- [ ] **Task 6B.1**: Wire M_VCamManager to root scene
  - Modify `scenes/root.tscn`: add `M_VCamManager` under `Managers`
  - Modify `scripts/root.gd`: register via `_register_if_exists()`

- [ ] **Task 6B.2**: Wire S_VCamSystem to gameplay scenes
  - Modify `scenes/templates/tmpl_base_scene.tscn`: add `S_VCamSystem` under `Systems/Core`
  - Modify `scenes/gameplay/gameplay_base.tscn`: add `S_VCamSystem` if not inherited

- [ ] **Task 6B.3**: Wire C_VCamComponent to camera template
  - Modify `scenes/templates/tmpl_camera.tscn`: add default `C_VCamComponent` with `cfg_default_orbit.tres`
  - Verify template remains backward compatible with `C_CameraStateComponent`

---

### Phase 6C: Manual Validation (Desktop Camera Modes)

- [ ] **MT-01**: Orbit camera follows player at configured distance and pitch
- [ ] **MT-02**: Orbit camera rotates horizontally with mouse/right-stick look input
- [ ] **MT-03**: Orbit camera rotates vertically with mouse/right-stick look input (pitch clamped)
- [ ] **MT-04**: Orbit camera with `allow_player_rotation = false` stays at authored angle
- [ ] **MT-09**: Fixed camera stays at authored world position
- [ ] **MT-10**: Fixed camera with `track_target = true` rotates to follow player
- [ ] **MT-11**: Fixed camera with `track_target = false` keeps authored rotation
- [ ] **MT-12**: Fixed camera does not respond to look input
- [ ] **MT-13**: First-person camera positioned at player + head offset
- [ ] **MT-14**: First-person camera rotates with mouse/right-stick look input
- [ ] **MT-15**: First-person camera pitch is clamped at min/max boundaries
- [ ] **MT-18**: First-person `look_multiplier` scales rotation speed

---

## Phase 7: Mobile Drag-Look

**Exit Criteria:** All ~16 mobile tests pass, mobile drag-look feeds `gameplay.look_input`, simultaneous move+look+buttons work, `S_InputSystem` does not clobber touchscreen input

### Phase 7A: UI_MobileControls Look Touch Tracking

- [ ] **Task 7A.1 (Red)**: Write tests for mobile look touch
  - Create or modify `tests/unit/ui/test_mobile_controls.gd`
  - Test touch starting outside joystick/buttons becomes look gesture
  - Test touch starting on joystick stays owned by joystick
  - Test touch starting on virtual button stays owned by button
  - Test look touch drag produces non-zero `look_delta`
  - Test releasing look touch clears `look_delta` to zero
  - Test simultaneous move joystick + look touch produce independent deltas
  - Test multiple button presses during look touch do not conflict
  - Test second free-screen touch while look active is ignored
  - **Target: 8 tests**

- [ ] **Task 7A.2 (Green)**: Implement look touch tracking
  - Modify `scripts/ui/hud/ui_mobile_controls.gd`
  - Track dedicated `_look_touch_id` separate from joystick and button touches
  - Expose per-frame `look_delta: Vector2`
  - Clear delta after each consumption
  - All tests should pass

---

### Phase 7B: S_TouchscreenSystem Look Dispatch

- [ ] **Task 7B.1 (Red)**: Write tests for touchscreen look dispatch
  - Modify `tests/unit/ecs/systems/test_s_touchscreen_system.gd`
  - Test dispatches `U_InputActions.update_look_input(look_delta)` when drag-look active
  - Test applies `look_drag_sensitivity` from persisted touchscreen settings
  - Test applies `invert_look_y` from persisted touchscreen settings
  - Test clears look delta after dispatch (delta-based like mouse)
  - **Target: 4 tests**

- [ ] **Task 7B.2 (Green)**: Implement touchscreen look dispatch
  - Modify `scripts/ecs/systems/s_touchscreen_system.gd`
  - Read `look_delta` from `UI_MobileControls`
  - Apply sensitivity and invert-Y from settings
  - Dispatch via `U_InputActions.update_look_input()`
  - All tests should pass

---

### Phase 7C: S_InputSystem Zero-Clobber Guard

- [ ] **Task 7C.1 (Red)**: Write tests for input system touchscreen guard
  - Modify `tests/unit/ecs/systems/test_input_system.gd`
  - Test when active device is touchscreen, `S_InputSystem` does NOT dispatch zero `look_input`
  - Test when active device is touchscreen, `S_InputSystem` does NOT dispatch zero `move_input`
  - Test when active device is keyboard/mouse, `S_InputSystem` dispatches normally
  - Test when active device is gamepad, `S_InputSystem` dispatches normally
  - **Target: 4 tests**

- [ ] **Task 7C.2 (Green)**: Implement input system guard
  - Modify `scripts/ecs/systems/s_input_system.gd`
  - Gate `TouchscreenSource` dispatch when touchscreen is the active device type
  - All tests should pass

---

### Phase 7D: Manual Validation (Mobile Drag-Look + Touch Settings)

- [ ] **MT-05**: Orbit camera on mobile: drag-look rotates camera horizontally
- [ ] **MT-06**: Orbit camera on mobile: drag-look rotates camera vertically
- [ ] **MT-07**: Orbit camera on mobile: simultaneous move joystick + drag-look works
- [ ] **MT-08**: Orbit camera on mobile: pressing button during drag-look does not disrupt
- [ ] **MT-16**: First-person camera on mobile: drag-look rotates view
- [ ] **MT-17**: First-person camera on mobile: simultaneous move + look works
- [ ] **MT-35**: Drag-look sensitivity slider in touchscreen settings changes rotation speed
- [ ] **MT-36**: Invert-Y toggle in touchscreen settings inverts vertical drag direction
- [ ] **MT-37**: Drag-look settings persist after quit and relaunch

---

## Phase 8: Projection-Based Soft Zone

**Exit Criteria:** All ~10 soft zone tests pass, correction is projection-aware and handles multiple viewport sizes and depths

### Phase 8A: U_VCamSoftZone Helper

- [ ] **Task 8A.1 (Red)**: Write tests for U_VCamSoftZone
  - Create `tests/unit/managers/helpers/test_vcam_soft_zone.gd`
  - Test target inside dead zone produces zero correction
  - Test target in soft zone produces damped non-zero correction
  - Test target outside soft zone (hard zone) clamps back inside viewport boundary
  - Test correction magnitude scales with damping parameter
  - Test correction is zero when soft zone resource is null (disabled)
  - Test correction works at different viewport sizes
  - Test correction works at different target depths (near vs far)
  - Test correction direction is toward the nearest allowed zone boundary
  - Test zero-size dead zone means any offset triggers correction
  - Test full-viewport soft zone means no clamping
  - **Target: 10 tests**

- [ ] **Task 8A.2 (Green)**: Implement U_VCamSoftZone
  - Create `scripts/managers/helpers/u_vcam_soft_zone.gd`
  - Implement `static func compute_camera_correction(camera, follow_world_pos, desired_transform, soft_zone, delta) -> Vector3`
  - Project follow target, test zone membership, reproject correction
  - All tests should pass

---

### Phase 8B: Soft Zone Integration

- [ ] **Task 8B.1**: Integrate soft-zone correction into S_VCamSystem
  - Modify `scripts/ecs/systems/s_vcam_system.gd`: apply correction to evaluated transform before submitting
  - Add 2 regression tests to `test_vcam_system.gd`:
    - Test soft zone correction is applied when component has soft zone resource
    - Test no correction when component has no soft zone resource

---

### Phase 8C: Manual Validation (Soft Zone)

- [ ] **MT-24**: Player in dead zone: camera does not move
- [ ] **MT-25**: Player in soft zone: camera follows with damped lag
- [ ] **MT-26**: Player near screen edge: camera corrects to keep player in frame

---

## Phase 9: Live Blend Evaluation and Camera-Manager Integration

**Exit Criteria:** All ~18 blend and camera-manager tests pass, moving-to-moving blends work, shake coexists with vCam motion

### Phase 9A: U_VCamBlendEvaluator

- [ ] **Task 9A.1 (Red)**: Write tests for U_VCamBlendEvaluator
  - Create `tests/unit/managers/helpers/test_vcam_blend_evaluator.gd`
  - Test blend at progress 0.0 returns `from_result` transform
  - Test blend at progress 1.0 returns `to_result` transform
  - Test blend at progress 0.5 returns interpolated transform
  - Test blend interpolates FOV between from and to results
  - Test blend applies `ease_type` from `RS_VCamBlendHint`
  - Test blend with `cut_on_distance_threshold > 0` and cameras farther apart cuts immediately (returns `to_result`)
  - Test blend with `cut_on_distance_threshold > 0` and cameras closer does NOT cut
  - Test blend with null hint uses linear interpolation defaults
  - Test blend with empty from_result returns to_result
  - Test blend with empty to_result returns from_result
  - **Target: 10 tests**

- [ ] **Task 9A.2 (Green)**: Implement U_VCamBlendEvaluator
  - Create `scripts/managers/helpers/u_vcam_blend_evaluator.gd`
  - Implement `static func blend(from_result, to_result, hint, progress) -> Dictionary`
  - All tests should pass

---

### Phase 9B: Live Blend State in M_VCamManager

- [ ] **Task 9B.1 (Red)**: Write tests for live blend in M_VCamManager
  - Add to `tests/unit/managers/test_vcam_manager.gd`
  - Test `set_active_vcam()` starts blend between old and new vcam IDs
  - Test `is_blending()` returns true during active blend
  - Test `get_blend_progress()` advances over time
  - Test blend completes when progress reaches 1.0
  - Test `get_previous_vcam_id()` returns outgoing vcam during blend
  - Test `submit_evaluated_camera()` stores both active and outgoing results during blend
  - Test blend result is computed from two live results (not frozen transforms)
  - Test `set_active_vcam()` with `blend_duration = 0.0` cuts immediately (no blend)
  - **Target: 8 tests**

- [ ] **Task 9B.2 (Green)**: Implement live blend in M_VCamManager
  - Extend manager with blend state tracking, elapsed time, blend evaluation
  - Process blend progression in `_physics_process`
  - All tests should pass

---

### Phase 9C: Shake-Safe Camera-Manager Integration

- [ ] **Task 9C.1 (Red)**: Write tests for camera-manager API extension
  - Modify `tests/integration/camera_system/test_camera_manager.gd`
  - Test `apply_main_camera_transform(xform)` updates camera base pose without breaking shake offset
  - Test `is_blend_active()` returns true during scene-transition blends
  - Test `is_blend_active()` returns false when no transition blend active
  - **Target: 3 tests**

- [ ] **Task 9C.2 (Green)**: Implement camera-manager API
  - Modify `scripts/interfaces/i_camera_manager.gd`: add method signatures
  - Modify `scripts/managers/m_camera_manager.gd`: implement `apply_main_camera_transform()` and `is_blend_active()`
  - Modify `tests/mocks/mock_camera_manager.gd`: add mock implementations
  - All tests should pass

---

### Phase 9D: vCam Apply Flow

- [ ] **Task 9D.1 (Red)**: Write tests for vCam camera application
  - Add to `tests/unit/managers/test_vcam_manager.gd`
  - Test vCam suspends transform writes when `camera_manager.is_blend_active()` is true
  - Test vCam calls `camera_manager.apply_main_camera_transform()` when blend inactive
  - Test vCam updates `C_CameraStateComponent.base_fov` with evaluated FOV
  - Test vCam does NOT write `camera.fov` directly (leaves that to `S_CameraStateSystem`)
  - **Target: 4 tests**

- [ ] **Task 9D.2 (Green)**: Implement vCam apply flow in M_VCamManager
  - Route final blended/unblended result through `camera_manager.apply_main_camera_transform()`
  - Set `C_CameraStateComponent.base_fov`
  - All tests should pass

---

### Phase 9E: Manual Validation (Blend + Shake Coexistence)

- [ ] **MT-19**: Switching from orbit to fixed blends smoothly (no snap)
- [ ] **MT-20**: Switching from fixed to first-person blends smoothly
- [ ] **MT-21**: Switching between two moving orbit cameras blends live (not frozen)
- [ ] **MT-22**: `cut_on_distance_threshold` triggers instant cut when cameras far apart
- [ ] **MT-23**: vCam blend does not fight scene-transition blend (suspends during transition)
- [ ] **MT-32**: Screen shake during orbit camera works (shake visible, returns to correct position)
- [ ] **MT-33**: Screen shake during first-person camera works
- [ ] **MT-34**: vCam + shake + scene-transition blend all coexist cleanly

---

## Phase 10: Occlusion and Silhouette

**Exit Criteria:** All ~18 occlusion tests pass (6 collision + 6 silhouette + 6 integration), silhouettes work on MeshInstance3D and CSGShape3D, gated by `vfx.occlusion_silhouette_enabled`

### Phase 10A: U_VCamCollisionDetector

- [ ] **Task 10A.1 (Red)**: Write tests for collision detector
  - Create `tests/unit/managers/helpers/test_vcam_collision_detector.gd`
  - Test empty result when nothing between camera and target
  - Test MeshInstance3D occluder detected on layer 6
  - Test CSGShape3D occluder detected on layer 6
  - Test collider on wrong physics layer is ignored
  - Test invalid or freed collider skipped safely (no crash)
  - Test multiple occluders returns all of them
  - **Target: 6 tests**

- [ ] **Task 10A.2 (Green)**: Implement U_VCamCollisionDetector
  - Create `scripts/managers/helpers/u_vcam_collision_detector.gd`
  - Modify `project.godot`: name physics layer 6 as `vcam_occludable`
  - Implement `static func detect_occluders(space_state, from, to, collision_mask) -> Array`
  - All tests should pass

- [ ] **Task 10A.3**: Roll out layer-6 occluder tagging in authored scenes
  - Modify `scenes/gameplay/gameplay_base.tscn` and any gameplay/prefab scenes used in vCam flows where geometry should occlude camera line-of-sight
  - Ensure only camera-blocking geometry uses layer 6 `vcam_occludable` (do not move trigger/zone-only nodes onto this layer)
  - Re-run scene/style gates after scene edits

---

### Phase 10B: U_VCamSilhouetteHelper

- [ ] **Task 10B.1 (Red)**: Write tests for silhouette helper
  - Create `tests/unit/managers/helpers/test_vcam_silhouette_helper.gd`
  - Test `apply_silhouette()` sets shader override on `GeometryInstance3D`
  - Test `apply_silhouette()` preserves original material state for later restoration
  - Test `remove_silhouette()` restores original material override
  - Test `remove_all_silhouettes()` cleans up all tracked overrides
  - Test `get_active_count()` returns correct count
  - Test applying silhouette to freed node is safely handled
  - **Target: 6 tests**

- [ ] **Task 10B.2 (Green)**: Implement U_VCamSilhouetteHelper
  - Create `scripts/managers/helpers/u_vcam_silhouette_helper.gd`
  - Create `assets/shaders/sh_vcam_silhouette_shader.gdshader`
  - Store original override state, apply shader override, restore on removal
  - All tests should pass

---

### Phase 10C: Per-Tick Occlusion Integration

- [ ] **Task 10C.1 (Red)**: Write tests for occlusion in M_VCamManager
  - Add to `tests/unit/managers/test_vcam_manager.gd`
  - Test occluders detected between follow target and camera get silhouettes
  - Test silhouettes only applied when `vfx.occlusion_silhouette_enabled` is true
  - Test silhouettes NOT applied when `vfx.occlusion_silhouette_enabled` is false
  - Test `vcam/update_silhouette_count` dispatched on count change
  - Test all silhouettes cleared when active vcam unregisters
  - Test all silhouettes cleared on scene transition
  - **Target: 6 tests**

- [ ] **Task 10C.2 (Green)**: Implement per-tick occlusion
  - Extend `m_vcam_manager.gd`: detect occluders, consult VFX selector, apply/remove silhouettes
  - Dispatch silhouette count updates
  - All tests should pass

---

### Phase 10D: Manual Validation (Occlusion + Silhouette)

- [ ] **MT-27**: Wall between camera and player shows silhouette shader
- [ ] **MT-28**: CSG geometry occluder shows silhouette
- [ ] **MT-29**: Silhouette clears when obstruction removed
- [ ] **MT-30**: Silhouette toggle in VFX settings disables/enables silhouettes
- [ ] **MT-31**: Silhouettes clear on scene transition (no stale overrides)

---

## Phase 11: Editor Preview

**Exit Criteria:** Rule-of-thirds preview visible in editor, absent at runtime, style tests pass

- [ ] **Task 11.1**: Create U_VCamRuleOfThirdsPreview
  - Create `scripts/utils/display/u_vcam_rule_of_thirds_preview.gd`
  - `@tool`, extends `Node`
  - Creates `CanvasLayer` + drawing child internally
  - `queue_free()` outside editor (zero runtime cost)
  - Follow `U_CinemaGradePreview` pattern

- [ ] **Task 11.2**: Add preview to camera template
  - Modify `scenes/templates/tmpl_camera.tscn`: add preview helper node
  - Verify preview node frees itself at runtime

- [ ] **Task 11.3**: Run style enforcement tests
  - `tests/unit/style/test_style_enforcement.gd` passes with new files

---

### Phase 11A: Manual Validation (Editor Preview)

- [ ] **MT-38**: Rule-of-thirds grid visible in editor viewport on camera template
- [ ] **MT-39**: Rule-of-thirds grid NOT visible at runtime

---

## Phase 12: Integration Tests

**Exit Criteria:** All ~25 integration tests pass

- [ ] **Task 12.1**: Create vCam state integration tests
  - Create `tests/integration/vcam/test_vcam_state.gd`
  - Test vcam slice registered as transient
  - Test vcam slice NOT in global settings persistence
  - Test vfx.occlusion_silhouette_enabled persists via global settings
  - Test touchscreen look settings persist via global settings
  - Test actions dispatch and selectors read correctly end-to-end
  - **Target: 5 tests**

- [ ] **Task 12.2**: Create vCam runtime integration tests
  - Create `tests/integration/vcam/test_vcam_runtime.gd`
  - Test M_VCamManager registers with ServiceLocator from root scene
  - Test S_VCamSystem finds manager via ServiceLocator
  - Test orbit vCam evaluates and submits results through full pipeline
  - Test fixed vCam evaluates and submits results
  - Test first-person vCam evaluates and submits results
  - Test switching active vcams triggers blend
  - Test blend completes and active vcam updates
  - **Target: 7 tests**

- [ ] **Task 12.3**: Create vCam blend integration tests
  - Create `tests/integration/vcam/test_vcam_blend.gd`
  - Test moving-to-moving blend stays live (not frozen transforms)
  - Test cut-on-distance triggers immediate cut
  - Test blend respects ease type
  - Test vCam suspends writes during camera-manager transition blend
  - Test vCam resumes writes after camera-manager transition completes
  - **Target: 5 tests**

- [ ] **Task 12.4**: Create mobile drag-look integration tests
  - Create `tests/integration/vcam/test_vcam_mobile.gd`
  - Test drag-look feeds orbit camera through gameplay.look_input
  - Test drag-look feeds first-person camera through gameplay.look_input
  - Test simultaneous move + look on separate touches
  - Test S_InputSystem does not clobber touchscreen look_input
  - Test touchscreen settings overlay updates drag-look sensitivity
  - Test invert_look_y inverts vertical drag direction
  - **Target: 6 tests**

- [ ] **Task 12.5**: Create occlusion integration tests
  - Create `tests/integration/vcam/test_vcam_occlusion.gd`
  - Test silhouette applied to mesh occluder at runtime
  - Test silhouette cleared on scene swap
  - **Target: 2 tests**

---

### Phase 12A: Manual Validation (Redux Observability)

- [ ] **MT-40**: `vcam.active_vcam_id` updates when active camera changes
- [ ] **MT-41**: `vcam.is_blending` is true during blend, false after completion
- [ ] **MT-42**: `vcam.silhouette_active_count` reflects active silhouette count

---

## Phase 13: Regression Coverage and Docs

**Exit Criteria:** Camera-manager regression tests pass, documentation updated, style enforcement passes

- [ ] **Task 13.1**: Add camera-manager regression tests
  - Modify `tests/integration/camera_system/test_camera_manager.gd`
  - Test shake still works after `apply_main_camera_transform()` call
  - Test `apply_main_camera_transform()` does not displace shake offset

- [ ] **Task 13.2**: Update AGENTS.md if new stable patterns discovered
  - Add vCam Manager section (runtime wiring, input contract, blend pattern)

- [ ] **Task 13.3**: Update DEV_PITFALLS.md if new pitfalls discovered
  - Camera-specific pitfalls (shake-safe writes, soft-zone projection, etc.)

- [ ] **Task 13.4**: Update vCam docs with implementation status
  - Update `docs/vcam_manager/vcam-manager-continuation-prompt.md`
  - Update `docs/vcam_manager/vcam-manager-tasks.md` (this file)
  - Update `docs/vcam_manager/vcam-manager-overview.md` if needed

- [ ] **Task 13.5**: Run full test gates
  - Run `tests/unit/style/test_style_enforcement.gd`
  - Run all new vCam unit suites
  - Run all new vCam integration suites
  - Run camera-manager regression tests
  - Run touchscreen/mobile control regression tests
  - Run input system regression tests

---

## Cross-Cutting Checks

- [ ] Verify `vcam` slice is whole-slice transient, not merely field-transient
- [ ] Verify no direct `camera.global_transform` writes remain in vCam code paths
- [ ] Verify moving-to-moving blends stay live instead of blending from a frozen origin transform
- [ ] Verify silhouettes restore cleanly on scene swap, vCam deactivation, and freed occluders
- [ ] Verify first-person and orbit look consume the existing input pipeline instead of polling raw input directly
- [ ] Verify mobile drag-look supports simultaneous move joystick + look touch + button presses without gesture conflicts
- [ ] Verify mobile drag-look settings persist through the existing touchscreen settings flow
- [ ] Verify `S_InputSystem` no longer overwrites touchscreen move/look input with zero payloads
- [ ] Verify VFX settings overlay exposes and localizes the silhouette toggle wired to `vfx.occlusion_silhouette_enabled`
- [ ] Verify authored camera-occluding geometry is migrated to physics layer 6 (`vcam_occludable`) in scenes covered by vCam flows
- [ ] Verify all three camera modes evaluate correctly in isolation (unit tests) and end-to-end (integration tests)
- [ ] Verify `S_CameraStateSystem` remains the sole writer of `camera.fov`
- [ ] Verify `M_CameraManager` shake hierarchy is not disturbed by vCam transform writes

---

## Test Commands

```bash
# Run vcam unit tests (state)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/state -gselect=test_vcam -ginclude_subdirs=true -gexit

# Run vcam prerequisites (input manager + touchscreen systems + VFX settings UI)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/input_manager -ginclude_subdirs=true -gexit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ecs/systems -gselect=touchscreen -ginclude_subdirs=true -gexit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ecs/systems -gselect=input_system -ginclude_subdirs=true -gexit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ui -gselect=vfx_settings_overlay -ginclude_subdirs=true -gexit

# Run vcam unit tests (resources)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/resources/display/vcam -ginclude_subdirs=true -gexit

# Run vcam unit tests (manager + helpers)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/managers -gselect=test_vcam -ginclude_subdirs=true -gexit

# Run vcam unit tests (ECS)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ecs -gselect=test_vcam -ginclude_subdirs=true -gexit

# Run vcam integration tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration/vcam -ginclude_subdirs=true -gexit

# Run style enforcement
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/style -ginclude_subdirs=true -gexit

# Run camera-manager regression coverage used by vCam integration
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration/camera_system -gselect=camera_manager -ginclude_subdirs=true -gexit

# Run all vcam-related tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gselect=test_vcam -ginclude_subdirs=true -gexit
```

---

## Links

- [Plan](vcam-manager-plan.md)
- [Overview](vcam-manager-overview.md)
- [PRD](vcam-manager-prd.md)
- [Continuation Prompt](vcam-manager-continuation-prompt.md)
