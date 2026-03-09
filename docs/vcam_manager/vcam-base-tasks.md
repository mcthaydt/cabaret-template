# vCam Base — Task Checklist

**Scope:** Shared infrastructure — state/persistence, base resources, component/interface/manager core, ECS system, scene wiring, mobile drag-look, soft zone, blend/camera integration, occlusion/silhouette, editor preview, regression/docs.

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
- [ ] **DOC-2**: After each completed phase, update the relevant subtask file with `[x]` marks and completion notes.
- [ ] **DOC-3**: Update `AGENTS.md` when new stable vCam architecture/pattern contracts emerge.
- [ ] **DOC-4**: Update `docs/general/DEV_PITFALLS.md` with new pitfalls discovered during vCam implementation.
- [ ] **DOC-5**: Commit documentation updates separately from implementation, per AGENTS requirements.

---

## Phase 0: State and Persistence

**Exit Criteria:** All ~74 Redux/UI tests pass, `vcam` slice registered as transient in `M_StateStore`, `vfx.occlusion_silhouette_enabled` persisted, VFX settings exposes the silhouette toggle, touchscreen drag-look settings persisted, no console errors

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
  - Test `to_dictionary()` returns `blend_from_vcam_id` as `&""`
  - Test `to_dictionary()` returns `blend_to_vcam_id` as `&""`
  - Test `to_dictionary()` returns `active_target_valid` as `true`
  - Test `to_dictionary()` returns `last_recovery_reason` as `""`
  - Test `to_dictionary()` returns exactly 10 keys
  - **Target: 11 tests**

- [ ] **Task 0C.2 (Green)**: Implement RS_VCamInitialState
  - Create `scripts/resources/state/rs_vcam_initial_state.gd`
  - Implement `to_dictionary()` returning all 10 fields
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
  - Test `update_target_validity(valid)` action structure
  - Test `record_recovery(reason)` action structure
  - **Target: 7 tests**

- [ ] **Task 0D.2 (Green)**: Implement U_VCamActions
  - Create `scripts/state/actions/u_vcam_actions.gd`
  - Add 7 action type constants and static creator functions
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
  - Test `update_target_validity` sets `active_target_valid` to provided bool
  - Test `record_recovery` sets `last_recovery_reason` to provided string
  - Test reducer returns same state for unknown action
  - Test reducer immutability (old state reference != new state reference)
  - **Target: 12 tests**

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
  - Test `get_blend_from_vcam_id(state)` returns value from state
  - Test `get_blend_from_vcam_id(state)` returns `&""` when missing
  - Test `get_blend_to_vcam_id(state)` returns value from state
  - Test `get_blend_to_vcam_id(state)` returns `&""` when missing
  - Test `is_active_target_valid(state)` returns value from state
  - Test `is_active_target_valid(state)` returns `true` when missing
  - Test `get_last_recovery_reason(state)` returns value from state
  - Test `get_last_recovery_reason(state)` returns `""` when missing
  - **Target: 21 tests**

- [ ] **Task 0E.2 (Green)**: Implement U_VCamSelectors
  - Create `scripts/state/selectors/u_vcam_selectors.gd`
  - All selectors null-safe and slice-safe (including 4 debug-field selectors: `get_blend_from_vcam_id`, `get_blend_to_vcam_id`, `is_active_target_valid`, `get_last_recovery_reason`)
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

**Exit Criteria:** All ~42 tests pass (7 soft zone + 7 blend hint + 13 second-order dynamics 1D + 7 second-order dynamics 3D + 8 response resource), default `.tres` instances created

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

### Phase 1D: Second-Order Dynamics Utility

> **Why:** Simple lerp/slerp damping produces robotic camera motion with no natural overshoot, settling, or responsiveness. Second-order dynamics model a mass-spring-damper system that gives camera follow, tracking, and soft-zone correction physically plausible motion with tuneable character (snappy, smooth, bouncy).

- [ ] **Task 1D.1 (Red)**: Write tests for U_SecondOrderDynamics
  - Create `tests/unit/utils/test_second_order_dynamics.gd`
  - Test initial state: output matches initial value (no jump on first frame)
  - Test step toward target: output moves toward target over multiple steps
  - Test convergence: after many steps, output approximates target within epsilon
  - Test critically damped (zeta=1.0): output reaches target without overshoot
  - Test under-damped (zeta=0.3): output overshoots target then settles
  - Test over-damped (zeta=2.0): output approaches target slower than critical, no overshoot
  - Test zero delta: step with `dt=0.0` returns current value unchanged
  - Test large delta: step with very large `dt` does not produce NaN or explosion (stability)
  - Test negative frequency clamped to minimum (no division by zero or negative sqrt)
  - Test `reset(new_value)` immediately sets output to new value with zero velocity
  - Test frequency controls speed: higher `f` reaches target faster
  - Test initial response `r > 0`: output reacts immediately in the direction of the target on the first step (no initial lag)
  - Test initial response `r = 0`: output starts with zero velocity (gradual start)
  - **Target: 13 tests**

- [ ] **Task 1D.2 (Green)**: Implement U_SecondOrderDynamics
  - Create `scripts/utils/math/u_second_order_dynamics.gd`
  - Add `class_name U_SecondOrderDynamics`
  - Instance-based (not static) — each consumer creates its own instance with independent state
  - Constructor: `func _init(f: float, zeta: float, r: float, initial_value: float = 0.0)`
    - `f` — natural frequency (Hz); controls speed of response. Higher = faster. Typical: 1.0–5.0
    - `zeta` — damping ratio. 0 = undamped oscillation, 0–1 = underdamped (overshoot), 1 = critically damped, >1 = overdamped
    - `r` — initial response. 0 = gradual start, 1 = immediate start, >1 = anticipation (overshoots initial direction)
  - Methods:
    - `func step(target: float, dt: float) -> float` — advance simulation, return new value
    - `func reset(value: float) -> void` — snap to value with zero velocity
    - `func get_value() -> float` — current output
    - `func get_velocity() -> float` — current rate of change
  - Internal state: `_y` (position), `_yd` (velocity), `_prev_target`, precomputed constants `_k1`, `_k2`, `_k3`
  - Stability guard: clamp `dt` and use semi-implicit Euler to prevent explosion at low framerates
  - All tests should pass

  **Core math contract (semi-implicit Euler):**
  ```gdscript
  # Precomputed constants from f, zeta, r:
  var _w := TAU * f        # angular frequency
  var _k1 := zeta / (PI * f)         # damping term
  var _k2 := 1.0 / (_w * _w)        # spring term
  var _k3 := r * zeta / (_w)        # initial response term

  func step(target: float, dt: float) -> float:
      if dt <= 0.0:
          return _y
      # Estimate target velocity
      var td := (target - _prev_target) / dt
      _prev_target = target
      # Stability clamp for k2
      var stable_k2 := maxf(_k2, maxf(dt * dt / 2.0 + dt * _k1 / 2.0, dt * _k1))
      # Semi-implicit Euler integration
      _y += dt * _yd
      _yd += dt * (target + _k3 * td - _y - _k1 * _yd) / stable_k2
      return _y
  ```

- [ ] **Task 1D.3**: Run style enforcement tests
  - `tests/unit/style/test_style_enforcement.gd` passes with new files
  - Verify `u_second_order_dynamics.gd` is in `scripts/utils/math/`

---

### Phase 1E: U_SecondOrderDynamics3D (Vector3 Wrapper)

- [ ] **Task 1E.1 (Red)**: Write tests for U_SecondOrderDynamics3D
  - Create `tests/unit/utils/test_second_order_dynamics_3d.gd`
  - Test initial state: output matches initial `Vector3`
  - Test step toward target: output moves toward target `Vector3`
  - Test convergence: after many steps, each axis approximates target within epsilon
  - Test axes are independent: stepping X does not affect Y or Z
  - Test `reset(new_value)` snaps all three axes
  - Test critically damped motion on all axes simultaneously
  - Test under-damped produces overshoot on all three axes
  - **Target: 7 tests**

- [ ] **Task 1E.2 (Green)**: Implement U_SecondOrderDynamics3D
  - Create `scripts/utils/math/u_second_order_dynamics_3d.gd`
  - Add `class_name U_SecondOrderDynamics3D`
  - Wraps three `U_SecondOrderDynamics` instances (x, y, z)
  - Constructor: `func _init(f: float, zeta: float, r: float, initial_value: Vector3 = Vector3.ZERO)`
  - Methods:
    - `func step(target: Vector3, dt: float) -> Vector3`
    - `func reset(value: Vector3) -> void`
    - `func get_value() -> Vector3`
  - All tests should pass

- [ ] **Task 1E.3**: Run style enforcement tests

---

### Phase 1F: RS_VCamResponse Resource

- [ ] **Task 1F.1 (Red)**: Write tests for RS_VCamResponse
  - Create `tests/unit/resources/display/vcam/test_vcam_response.gd`
  - Test `follow_frequency` field exists with default `3.0`
  - Test `follow_damping` field exists with default `0.7` (slightly underdamped for natural feel)
  - Test `follow_initial_response` field exists with default `1.0` (immediate reaction)
  - Test `rotation_frequency` field exists with default `4.0`
  - Test `rotation_damping` field exists with default `1.0` (critically damped — no rotational wobble)
  - Test `rotation_initial_response` field exists with default `1.0`
  - Test `frequency` values must be positive (reject 0.0 and negative)
  - Test `damping` values must be non-negative (0.0 = undamped oscillation is valid but extreme)
  - **Target: 8 tests**

- [ ] **Task 1F.2 (Green)**: Implement RS_VCamResponse
  - Create `scripts/resources/display/vcam/rs_vcam_response.gd`
  - Extend `Resource`
  - Add `class_name RS_VCamResponse`
  - All `@export` fields with sensible defaults:
    - `follow_frequency: float = 3.0` — how fast position tracks target (Hz)
    - `follow_damping: float = 0.7` — position damping ratio (< 1 = slight overshoot, 1 = critical, > 1 = sluggish)
    - `follow_initial_response: float = 1.0` — position initial response (0 = gradual, 1 = immediate)
    - `rotation_frequency: float = 4.0` — how fast rotation tracks target (Hz)
    - `rotation_damping: float = 1.0` — rotation damping ratio
    - `rotation_initial_response: float = 1.0` — rotation initial response
  - All tests should pass

- [ ] **Task 1F.3**: Create default response resource instance
  - Create `resources/display/vcam/cfg_default_response.tres`
  - Set all fields to defaults (follow: f=3.0, z=0.7, r=1.0; rotation: f=4.0, z=1.0, r=1.0)
  - Verify resource loads without errors

- [ ] **Task 1F.4**: Run style enforcement tests

---

## Phase 5: Component, Interface, and Manager Core

**Exit Criteria:** All ~30 tests pass (12 component + 8 interface/manager registration + 10 manager active-selection), `M_VCamManager` registered with ServiceLocator

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
  - Test `response` export exists (Resource type, RS_VCamResponse)
  - Test `is_active` export exists with default `true`
  - **Target: 12 tests**

- [ ] **Task 5A.2 (Green)**: Implement C_VCamComponent
  - Create `scripts/ecs/components/c_vcam_component.gd`
  - Extend `BaseECSComponent`, set `COMPONENT_TYPE`
  - Add all exports (including `response: RS_VCamResponse`) and runtime-only `runtime_yaw`, `runtime_pitch` vars
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

**Exit Criteria:** All ~26 system tests pass (12 core + 6 rotation continuity + 8 second-order dynamics), `S_VCamSystem` reads look input from Redux, evaluates active/outgoing vcams, applies second-order dynamics smoothing via `RS_VCamResponse`, submits results to manager, scene wiring complete, desktop manual camera checks pass (`MT-01..MT-04`, `MT-09..MT-15`, `MT-18`)

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

### Phase 6A2: Second-Order Dynamics Integration in S_VCamSystem

> **Why:** The evaluator computes instantaneous "ideal" poses (where the camera *should* be). Without smoothing, the camera teleports to the ideal pose every frame. Second-order dynamics make the camera *pursue* the ideal pose with physically plausible motion — slight overshoot on fast follow, smooth settling, no robotic snapping.

- [ ] **Task 6A2.1 (Red)**: Write tests for second-order dynamics camera smoothing
  - Add to `tests/unit/ecs/systems/test_vcam_system.gd`
  - Test with `RS_VCamResponse` assigned: submitted position does NOT match raw evaluator position on first frame after target moves (smoothing active)
  - Test with `RS_VCamResponse` assigned: submitted position converges toward evaluator position over multiple ticks
  - Test with underdamped follow (zeta=0.5): position overshoots target then settles
  - Test with critically damped follow (zeta=1.0): position reaches target without overshoot
  - Test with `RS_VCamResponse = null` on component: raw evaluator output submitted directly (no smoothing, backward compatible)
  - Test rotation smoothing: camera rotation converges toward evaluated rotation over ticks
  - Test `reset()` called on mode switch: dynamics snap to new evaluator pose (no residual momentum from previous mode)
  - Test dynamics reset on follow target change (new target = fresh dynamics, no lerp from old target position)
  - **Target: 8 tests**

- [ ] **Task 6A2.2 (Green)**: Implement second-order dynamics in S_VCamSystem
  - Per active vCam, maintain `U_SecondOrderDynamics3D` for position and `U_SecondOrderDynamics` for each Euler component of rotation
  - On each `process_tick(delta)`:
    1. Evaluate ideal pose via `U_VCamModeEvaluator` (unchanged)
    2. If `component.response` is not null, step dynamics toward ideal pose
    3. Submit smoothed result to manager
  - Create/reset dynamics instances:
    - On first evaluation of a vCam: create dynamics with initial value = evaluator output
    - On mode switch / target change: `reset()` to snap dynamics to new ideal pose
    - On `response` resource change: recreate dynamics with new parameters
  - If `response` is null, pass evaluator output through directly (zero overhead, backward compatible)
  - All tests should pass

  **Integration pattern:**
  ```gdscript
  # Per vCam runtime state (keyed by vcam_id)
  var _follow_dynamics: Dictionary = {}  # vcam_id -> U_SecondOrderDynamics3D
  var _rotation_dynamics: Dictionary = {}  # vcam_id -> {yaw: U_SecondOrderDynamics, pitch: U_SecondOrderDynamics, roll: U_SecondOrderDynamics}

  func _smooth_result(vcam_id: StringName, component: C_VCamComponent, raw_result: Dictionary, delta: float) -> Dictionary:
      if component.response == null:
          return raw_result
      var resp := component.response as RS_VCamResponse
      # Position smoothing
      if not _follow_dynamics.has(vcam_id):
          _follow_dynamics[vcam_id] = U_SecondOrderDynamics3D.new(
              resp.follow_frequency, resp.follow_damping, resp.follow_initial_response,
              raw_result.transform.origin)
      var smooth_pos := _follow_dynamics[vcam_id].step(raw_result.transform.origin, delta)
      # Rotation smoothing (decompose basis to euler, smooth each axis, recompose)
      # ... similar pattern with rotation_frequency/damping/initial_response ...
      var smoothed_xform := Transform3D(smooth_basis, smooth_pos)
      return {transform = smoothed_xform, fov = raw_result.fov, mode_name = raw_result.mode_name}
  ```

- [ ] **Task 6A.3 (Red)**: Write tests for rotation continuity on mode switch
  - Add to `tests/unit/ecs/systems/test_vcam_system.gd`
  - Test orbit → first-person carries `runtime_yaw`, resets `runtime_pitch` to `0.0`
  - Test first-person → orbit carries `runtime_yaw`, resets `runtime_pitch` to `0.0`
  - Test orbit → fixed preserves outgoing component's `runtime_yaw`/`runtime_pitch`
  - Test fixed → orbit reseeds `runtime_yaw` to authored yaw, resets `runtime_pitch` to `0.0`
  - Test same-mode switch with same target carries both yaw/pitch
  - Test same-mode switch with different target reseeds to authored angles
  - **Target: 6 tests**

- [ ] **Task 6A.4 (Green)**: Implement rotation continuity policy in S_VCamSystem
  - Apply carry/reset/reseed rules based on mode transition type (per overview Rotation Continuity Contract)
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

### Phase 6B2: Runtime Recovery Tests

- [ ] **Task 6B2.1 (Red)**: Write tests for invalid-target recovery
  - Add to `tests/unit/managers/test_vcam_manager.gd` or `tests/unit/ecs/systems/test_vcam_system.gd`
  - Test active follow target freed during play: holds last valid pose, triggers reselection
  - Test fixed anchor missing after scene churn: falls back to entity root
  - Test `active_target_valid` selector reflects current validity
  - Test `last_recovery_reason` is set on recovery events
  - **Target: 4 tests**

- [ ] **Task 6B2.2 (Green)**: Implement runtime recovery
  - Add per-tick validity checks in `S_VCamSystem` and `M_VCamManager`
  - Dispatch `update_target_validity` and `record_recovery` actions
  - All tests should pass

---

### Phase 6C: Manual Validation (Desktop Camera Modes)

> Mode-specific manual checks are listed in their respective subtask files.
> See: [vcam-orbit-tasks.md](vcam-orbit-tasks.md), [vcam-fixed-tasks.md](vcam-fixed-tasks.md), [vcam-fps-tasks.md](vcam-fps-tasks.md)

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

Mode-specific mobile checks are tracked in their respective subtask files:
- Orbit mobile (MT-05..08): [vcam-orbit-tasks.md](vcam-orbit-tasks.md)
- First-person mobile (MT-16, 17): [vcam-fps-tasks.md](vcam-fps-tasks.md)

Settings checks (mode-agnostic):

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
  - **Note:** The `damping` field on `RS_VCamSoftZone` controls correction magnitude (how aggressively the camera corrects when the target enters the soft zone). The temporal smoothing of that correction is handled by the second-order dynamics in `S_VCamSystem` (Phase 6A2) — the soft zone helper computes the instantaneous correction vector, and the dynamics smooth the resulting camera position over time.
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

**Exit Criteria:** All ~25 blend and camera-manager tests pass (10 blend evaluator + 8 live blend + 3 camera-manager API + 4 apply flow), moving-to-moving blends work, shake coexists with vCam motion

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

### Phase 9E: Reentrant Blend and Blend Recovery

- [ ] **Task 9E.1 (Red)**: Write tests for reentrant blend (mid-blend interruption)
  - Add to `tests/unit/managers/test_vcam_manager.gd`
  - Test second `set_active_vcam()` during active blend snapshots current blended pose as new "from"
  - Test reentrant switch resets blend progress to `0.0`
  - Test reentrant switch updates `previous_vcam_id`
  - Test rapid triple-switch sequence produces coherent final state (no wedged blend)
  - **Target: 4 tests**

- [ ] **Task 9E.2 (Green)**: Implement reentrant blend in M_VCamManager
  - Snapshot current blended pose on re-entry
  - Update blend state with new target
  - All tests should pass

- [ ] **Task 9E.3 (Red)**: Write tests for blend recovery on invalid vCam
  - Add to `tests/unit/managers/test_vcam_manager.gd`
  - Test outgoing vCam freed during blend: blend completes immediately (cut to incoming)
  - Test incoming vCam freed during blend: blend cancelled, hold outgoing pose, trigger reselection
  - Test both vCams freed during blend: hold last valid pose, clear blend state
  - **Target: 3 tests**

- [ ] **Task 9E.4 (Green)**: Implement blend recovery
  - Add validity checks before blend evaluation each tick
  - Dispatch `record_recovery` on recovery events
  - All tests should pass

---

### Phase 9F: Manual Validation (Blend + Shake Coexistence)

Mode-specific blend checks are tracked in their respective subtask files:
- Orbit blend (MT-19, 21, 32): [vcam-orbit-tasks.md](vcam-orbit-tasks.md)
- Fixed blend (MT-19, 20): [vcam-fixed-tasks.md](vcam-fixed-tasks.md)
- First-person blend (MT-20, 33): [vcam-fps-tasks.md](vcam-fps-tasks.md)

Cross-mode checks (mode-agnostic):

- [ ] **MT-22**: `cut_on_distance_threshold` triggers instant cut when cameras far apart
- [ ] **MT-23**: vCam blend does not fight scene-transition blend (suspends during transition)
- [ ] **MT-34**: vCam + shake + scene-transition blend all coexist cleanly
- [ ] **MT-43**: Rapid repeated switching does not pop or wedge blend state
- [ ] **MT-44**: Mid-blend re-switch transitions smoothly from current interpolated pose

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

### Phase 10C2: Anti-Flicker and Stability Tests

- [ ] **Task 10C2.1 (Red)**: Write tests for occlusion anti-flicker
  - Add to `tests/unit/managers/helpers/test_vcam_silhouette_helper.gd` or `tests/unit/managers/test_vcam_manager.gd`
  - Test same occluder rapidly entering/leaving ray does not cause per-frame material churn (grace-frame removal)
  - Test occluder must be detected for 2 consecutive frames before silhouette is applied (debounce)
  - Test silhouette count does not thrash when blocker set is unchanged
  - Test no material override reapplication when stable occluder set is unchanged from previous frame
  - Test multiple occluders swapping order frame-to-frame does not cause flicker
  - **Target: 5 tests**

- [ ] **Task 10C2.2 (Green)**: Implement anti-flicker behavior
  - Add debounce/grace-frame logic to `U_VCamSilhouetteHelper`
  - Skip override application when occluder set is unchanged
  - All tests should pass

---

### Phase 10D: Manual Validation (Occlusion + Silhouette)

- [ ] **MT-27**: Wall between camera and player shows silhouette shader
- [ ] **MT-28**: CSG geometry occluder shows silhouette
- [ ] **MT-29**: Silhouette clears when obstruction removed
- [ ] **MT-30**: Silhouette toggle in VFX settings disables/enables silhouettes
- [ ] **MT-31**: Silhouettes clear on scene transition (no stale overrides)
- [ ] **MT-45**: Silhouettes remain stable near cover edges (no flicker on marginal blockers)
- [ ] **MT-46**: No visible per-frame churn when standing behind a stationary occluder

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

- [ ] **Task 12.6**: Create observability integration tests
  - Create or extend `tests/integration/vcam/test_vcam_state.gd`
  - Test `blend_from_vcam_id` and `blend_to_vcam_id` populated during blend
  - Test `active_target_valid` reflects follow target status
  - Test `last_recovery_reason` set on target-loss recovery
  - Test debug fields cleared after blend completion
  - **Target: 4 tests**

---

### Phase 12A: Manual Validation (Redux Observability)

- [ ] **MT-40**: `vcam.active_vcam_id` updates when active camera changes
- [ ] **MT-41**: `vcam.is_blending` is true during blend, false after completion
- [ ] **MT-42**: `vcam.silhouette_active_count` reflects active silhouette count
- [ ] **MT-47**: `vcam.blend_from_vcam_id` / `blend_to_vcam_id` show correct values during blend
- [ ] **MT-48**: `vcam.active_target_valid` goes false when target is freed
- [ ] **MT-49**: `vcam.last_recovery_reason` populated after a recovery event

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
  - Update subtask files with `[x]` marks
  - Update `docs/vcam_manager/vcam-manager-overview.md` if needed

- [ ] **Task 13.5**: Cross-mode feel QA (manual)
  - [ ] **MT-50**: Heading continuity after orbit → first-person switch (player keeps facing same direction)
  - [ ] **MT-51**: Heading continuity after first-person → orbit switch
  - [ ] **MT-52**: Fixed → orbit landing uses authored angles (no stale rotation inherited)
  - [ ] **MT-53**: Rapid repeated cross-mode switching does not pop or produce disorienting heading jumps
  - [ ] **MT-54**: Graceful recovery on follow target loss / respawn (no camera jerk)
  - [ ] **MT-55**: First frame after scene load feels correct (no single-frame snap to wrong pose)

- [ ] **Task 13.6**: Second-order dynamics feel QA (manual)
  - [ ] **MT-70**: Orbit follow with default response (f=3.0, z=0.7): camera has subtle overshoot when player reverses direction suddenly, settles naturally
  - [ ] **MT-71**: Orbit follow with high frequency (f=6.0): camera tracks tightly, minimal lag
  - [ ] **MT-72**: Orbit follow with low frequency (f=1.0): camera floats lazily behind player, cinematic feel
  - [ ] **MT-73**: First-person with response: head bob absorbs landing impacts with spring-like settling
  - [ ] **MT-74**: Fixed tracking with response: camera tracks moving player with natural ease-in/ease-out, no robotic lerp
  - [ ] **MT-75**: Response with zeta=0.3 (bouncy): visible overshoot, oscillation settling — intentionally exaggerated, verifies dynamics are working
  - [ ] **MT-76**: Response with zeta=1.5 (overdamped): sluggish but no overshoot — verifies overdamped path
  - [ ] **MT-77**: No response resource assigned (null): camera behaves identically to raw evaluator output (backward compatible, no smoothing)
  - [ ] **MT-78**: Dynamics reset on mode switch: no residual momentum carried from previous mode (camera doesn't swing wildly on switch)
  - [ ] **MT-79**: Dynamics reset on scene load: first frame starts at correct position (no fly-in from origin)

- [ ] **Task 13.7**: Performance regression checks (manual)
  - [ ] **MT-56**: Long scene with many potential occluders: no frame-pacing spikes from occlusion pass
  - [ ] **MT-57**: Rapid switching stress test: no allocation spikes from blend/silhouette churn
  - [ ] **MT-58**: Steady-state camera (no switch, no occlusion change): verify no per-frame dictionary allocations in profiler
  - [ ] **MT-80**: Second-order dynamics per-tick cost: verify no measurable frame time increase vs null response (dynamics are 6 multiplies + 4 adds per axis per tick)

- [ ] **Task 13.8**: Run full test gates
  - Run `tests/unit/style/test_style_enforcement.gd`
  - Run all new vCam unit suites (including anti-flicker, reentrant blend, recovery tests)
  - Run all new vCam integration suites (including observability debug fields)
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
- [ ] Verify second-order dynamics are instance-per-vCam (no shared state between different vCam components)
- [ ] Verify dynamics `reset()` is called on mode switch, target change, and scene load (no residual momentum)
- [ ] Verify null `RS_VCamResponse` on component produces identical behavior to pre-dynamics implementation (backward compatible)
- [ ] Verify dynamics do not allocate per-frame (all instances are pre-created and reused)
- [ ] Verify rotation smoothing decomposes to Euler → smooth → recompose correctly without gimbal lock at typical camera angles

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

# Run second-order dynamics tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/utils -gselect=test_second_order -ginclude_subdirs=true -gexit

# Run vcam unit tests (resources including RS_VCamResponse)
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

- [Main Task Index](vcam-manager-tasks.md)
- [Orbit Tasks](vcam-orbit-tasks.md)
- [Fixed Tasks](vcam-fixed-tasks.md)
- [First-Person Tasks](vcam-fps-tasks.md)
- [Plan](vcam-manager-plan.md)
- [Overview](vcam-manager-overview.md)
- [PRD](vcam-manager-prd.md)
- [Continuation Prompt](vcam-manager-continuation-prompt.md)
