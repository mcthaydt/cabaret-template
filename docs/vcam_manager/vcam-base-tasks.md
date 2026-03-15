# vCam Base — Task Checklist

**Scope:** Shared infrastructure — state/persistence, base resources, component/interface/manager core, ECS system, scene wiring, mobile drag-look, blend/camera integration, occlusion/silhouette, editor preview, regression/docs.

---

## Pre-Implementation Checklist

Before starting Phase 0, verify:

- [x] **PRE-1**: Read required documentation
  - Read `AGENTS.md`, `docs/general/DEV_PITFALLS.md`, `docs/general/STYLE_GUIDE.md`
  - Read `docs/vcam_manager/vcam-manager-plan.md`, `vcam-manager-overview.md`, `vcam-manager-prd.md`
  - Read `scripts/managers/m_camera_manager.gd` and `scripts/interfaces/i_camera_manager.gd`
  - Read `scripts/ecs/systems/s_input_system.gd` and `scripts/ecs/systems/s_touchscreen_system.gd`
  - Read `scripts/state/utils/u_state_slice_manager.gd`
  - Completion note (2026-03-10): Required reading completed before Phase 0 implementation edits.

- [x] **PRE-2**: Understand existing patterns by reading:
  - `scripts/state/m_state_store.gd` (export pattern, initialize_slices call)
  - `scripts/resources/state/rs_vfx_initial_state.gd` (existing vfx initial state pattern)
  - `scripts/managers/m_camera_manager.gd` (shake-parent hierarchy, transition blends)
  - `scripts/ui/hud/ui_mobile_controls.gd` (existing touch control flow)
  - `scripts/utils/display/u_cinema_grade_preview.gd` (editor preview pattern)
  - `tests/mocks/mock_camera_manager.gd` (mock pattern for camera manager)
  - Completion note (2026-03-10): Existing input/camera/settings patterns were reviewed and reused for Phase 0A/0A2.

- [x] **PRE-3**: Verify branch is `vcam` and working tree is clean
  - Completion note (2026-03-10): Phase 0 work started on branch `vcam` from a clean working tree.

---

## Per-Phase Documentation Cadence (Mandatory)

- [x] **DOC-1**: After each completed phase, update `docs/vcam_manager/vcam-manager-continuation-prompt.md` with exact phase status and next step.
- [x] **DOC-2**: After each completed phase, update the relevant subtask file with `[x]` marks and completion notes.
- [x] **DOC-3**: Update `AGENTS.md` when new stable vCam architecture/pattern contracts emerge.
  - Completion note (2026-03-10): Added Phase 0F/1D/1E/1F vCam runtime contracts (FOV-zone source, second-order dynamics, response resource contract) to `AGENTS.md`.
- [x] **DOC-4**: Update `docs/general/DEV_PITFALLS.md` with new pitfalls discovered during vCam implementation.
  - Completion note (2026-03-10): Added vCam-specific guardrails for `state.vcam.in_fov_zone` migration and occlusion-layer rollout pitfalls.
- [x] **DOC-5**: Commit documentation updates separately from implementation, per AGENTS requirements.
  - Completion note (2026-03-10): Phase 0/1 work follows docs-first/code-next commit separation (documentation commits alternate with implementation commits on `vcam` branch).

---

## Phase 0: State and Persistence

**Exit Criteria:** All ~74 Redux/UI tests pass, `vcam` slice registered as transient in `M_StateStore`, `vfx.occlusion_silhouette_enabled` persisted, VFX settings exposes the silhouette toggle, touchscreen drag-look settings persisted with localization coverage, no console errors

### Phase 0A: Touchscreen Drag-Look Settings Prerequisite

- [x] **Task 0A.1 (Red)**: Write tests for touchscreen drag-look settings
  - Modify `tests/unit/input_manager/test_u_input_reducer.gd` (or create new test file)
  - Modify `tests/unit/resources/test_rs_touchscreen_settings.gd`
  - Test `look_drag_sensitivity` field exists in touchscreen settings with default `1.0`
  - Test `invert_look_y` field exists in touchscreen settings with default `false`
  - Test reducer handles `set_look_drag_sensitivity` action with valid float
  - Test reducer clamps `look_drag_sensitivity` to valid range (e.g. 0.1-5.0)
  - Test reducer handles `set_invert_look_y` action with bool
  - Test reducer ignores unknown action (returns same state)
  - **Target: 6 tests**
  - Completion note (2026-03-10): Added/updated assertions in `test_u_input_reducer.gd` and `test_rs_touchscreen_settings.gd` for `look_drag_sensitivity` and `invert_look_y` defaults/behavior.

- [x] **Task 0A.2 (Green)**: Implement touchscreen drag-look settings
  - Modify `scripts/resources/input/rs_touchscreen_settings.gd`: add `look_drag_sensitivity: float = 1.0`, `invert_look_y: bool = false`
  - Modify `resources/input/touchscreen_settings/cfg_default_touchscreen_settings.tres`: set new defaults
  - Modify `scripts/state/reducers/u_input_reducer.gd`: add action handling
  - All tests should pass
  - Completion note (2026-03-10): Added touchscreen look settings fields and reducer/state sanitization support in input reducer and serialization.

- [x] **Task 0A.3 (Red)**: Write tests for touchscreen settings overlay updates
  - Modify `tests/unit/ui/test_touchscreen_settings_overlay.gd`
  - Modify `tests/unit/ui/test_touchscreen_settings_overlay_localization.gd`
  - Test overlay displays drag-look sensitivity slider
  - Test overlay displays invert-Y toggle
  - Test overlay preview dispatches look sensitivity changes
  - Test overlay apply persists look settings
  - Test localization updates the new drag-look control labels/tooltips
  - **Target: 5 tests**
  - Completion note (2026-03-10): Updated touchscreen overlay/unit localization tests to cover the new look sensitivity slider and invert-Y toggle.

- [x] **Task 0A.4 (Green)**: Implement touchscreen settings overlay changes
  - Modify `scripts/ui/overlays/ui_touchscreen_settings_overlay.gd`: add drag-look sensitivity slider and invert-Y toggle
  - Modify UI locale resources for the new touchscreen look strings
  - All tests should pass
  - Completion note (2026-03-10): Added overlay controls/wiring, theme/localization/tooltips, and dispatch handling for touchscreen drag-look settings.

---

### Phase 0A2: Keyboard Look Settings Prerequisite

- [x] **Task 0A2.1**: Register dedicated look actions in project.godot and input profiles
  - Add `look_left`, `look_right`, `look_up`, `look_down` input actions to `project.godot`
  - Modify `scripts/input/u_input_map_bootstrapper.gd`: add `look_*` actions to `REQUIRED_ACTIONS`
  - Modify `tests/unit/input/test_input_map.gd`: verify bootstrap/runtime input-map coverage for the new actions
  - Default bindings: arrow keys (matching default keyboard profile convention)
  - Update `resources/input/profiles/cfg_default_keyboard.tres`: bind `look_left/right/up/down` to arrow keys
  - Update `resources/input/profiles/cfg_alternate_keyboard.tres`: bind `look_left/right/up/down` to WASD (the non-movement keys in that layout)
  - Update `resources/input/profiles/cfg_accessibility_keyboard.tres`: match default or alternate as appropriate
  - Gamepad and touchscreen profiles: leave `look_*` unbound (right stick and drag-look already feed `look_input` directly)
  - Completion note (2026-03-10): Added `look_*` actions to `project.godot`, bootstrapper required-actions, input-map tests, and keyboard profile bindings (default/accessibility arrows, alternate WASD).

- [x] **Task 0A2.2 (Red)**: Write tests for keyboard look settings in mouse_settings
  - Modify `tests/unit/input_manager/test_u_input_reducer.gd` (or create new test file)
  - Test `keyboard_look_enabled` field exists in `mouse_settings` with default `false`
  - Test `keyboard_look_speed` field exists in `mouse_settings` with default `2.0`
  - Test reducer handles `set_keyboard_look_enabled` action with bool
  - Test reducer handles `set_keyboard_look_speed` action with valid float
  - Test reducer clamps `keyboard_look_speed` to valid range (0.1–10.0)
  - Test reducer ignores unknown action (returns same state)
  - **Target: 6 tests**
  - Completion note (2026-03-10): Added reducer tests for keyboard-look defaults, update actions, and clamping.

- [x] **Task 0A2.3 (Green)**: Implement keyboard look settings
  - Modify `scripts/state/reducers/u_input_reducer.gd`: add `keyboard_look_enabled: false` and `keyboard_look_speed: 2.0` to `DEFAULT_INPUT_SETTINGS_STATE.mouse_settings`
  - Modify `scripts/state/actions/u_input_actions.gd`: add `ACTION_SET_KEYBOARD_LOOK_ENABLED` and `ACTION_SET_KEYBOARD_LOOK_SPEED`
  - Modify `scripts/state/reducers/u_input_reducer.gd`: add action handling
  - Modify `scripts/utils/u_global_settings_serialization.gd`: add the keyboard-look settings actions to `INPUT_SETTINGS_ACTIONS`
  - All tests should pass
  - Completion note (2026-03-10): Added keyboard-look actions/reducer handling and persisted-settings trigger wiring.

- [x] **Task 0A2.4 (Green)**: Implement keyboard look in KeyboardMouseSource
  - Modify `scripts/input/sources/keyboard_mouse_source.gd`:
    - Add `keyboard_look_enabled: bool = false` and `keyboard_look_speed: float = 2.0` properties
    - In `capture_input(delta)`, when `keyboard_look_enabled`, read `look_left`/`look_right`/`look_up`/`look_down` action strength and produce a keyboard look delta: `Vector2(look_x, look_y) * keyboard_look_speed * delta`
    - Add keyboard look delta to `look_delta` (additive with mouse)
    - Respect `invert_y_axis` from `mouse_settings` for the keyboard look Y component
  - Modify `scripts/ecs/systems/s_input_system.gd`: read `keyboard_look_enabled` and `keyboard_look_speed` from `mouse_settings` state and pass to `KeyboardMouseSource` each tick (same pattern as `mouse_sensitivity`)
  - Completion note (2026-03-10): Implemented additive keyboard-look path in `KeyboardMouseSource` and state-driven wiring in `S_InputSystem` (including look-action names).

- [x] **Task 0A2.5**: Expose keyboard look in settings UI
  - Create `scripts/ui/overlays/ui_keyboard_mouse_settings_overlay.gd`
  - Create `scenes/ui/overlays/ui_keyboard_mouse_settings_overlay.tscn`
  - Create `resources/ui_screens/cfg_keyboard_mouse_settings_overlay.tres`
  - Modify `scripts/ui/menus/ui_settings_menu.gd` and `scenes/ui/menus/ui_settings_menu.tscn` to open the new overlay
  - Expose:
    - Toggle for "Keyboard Camera Rotation" (maps to `keyboard_look_enabled`)
    - Slider for "Keyboard Look Speed" (maps to `keyboard_look_speed`, range 0.1–10.0)
  - Speed slider should be grayed out / hidden when `keyboard_look_enabled` is false
  - Because bindings live in profiles, the actual keys shown depend on the active profile — rebinding works through the existing rebind system
  - Completion note (2026-03-10): Added new keyboard/mouse settings overlay scene/script/registry entries, linked from settings menu, with enabled-state gating and dedicated unit coverage.

- [x] **Task 0A2.6**: Patch rebinding UI and localization for `look_*`
  - Modify `scripts/ui/helpers/u_rebind_action_list_builder.gd`: replace legacy `camera_*` coverage with `look_*` under the camera category
  - Modify `resources/localization/cfg_locale_*_ui.tres`: add `input.action.look_left`, `input.action.look_right`, `input.action.look_up`, `input.action.look_down`
  - Modify `tests/unit/ui/test_input_rebinding_overlay.gd` and `tests/unit/integration/test_rebinding_flow.gd` to cover the new camera action names
  - Completion note (2026-03-10): Added `look_*` actions to the camera rebind category, added locale strings across all UI locales, and updated rebind overlay/integration tests.

---

### Phase 0B: Persisted Silhouette Toggle in VFX Settings

- [x] **Task 0B.1 (Red)**: Write tests for `occlusion_silhouette_enabled` in VFX state
  - Modify `tests/unit/state/test_vfx_initial_state.gd`
  - Test `occlusion_silhouette_enabled` field exists with default `true`
  - Test `to_dictionary()` includes `occlusion_silhouette_enabled`
  - **Target: 2 tests**
  - Completion note (2026-03-10): Added initial-state coverage for `occlusion_silhouette_enabled` field presence/type and dictionary export.

- [x] **Task 0B.2 (Green)**: Add field to RS_VFXInitialState
  - Modify `scripts/resources/state/rs_vfx_initial_state.gd`: add `@export var occlusion_silhouette_enabled: bool = true`
  - All tests should pass
  - Completion note (2026-03-10): Added exported occlusion silhouette default field and included it in `to_dictionary()`.

- [x] **Task 0B.3 (Red)**: Write tests for VFX actions and reducer
  - Modify `tests/unit/state/test_vfx_reducer.gd`
  - Test `set_occlusion_silhouette_enabled` action structure
  - Test reducer sets `occlusion_silhouette_enabled = true`
  - Test reducer sets `occlusion_silhouette_enabled = false`
  - Test reducer returns same state for unrelated action
  - **Target: 4 tests**
  - Completion note (2026-03-10): Added action-structure and reducer true/false coverage, plus default/preservation assertions for the new field.

- [x] **Task 0B.4 (Green)**: Implement VFX action and reducer
  - Modify `scripts/state/actions/u_vfx_actions.gd`: add `ACTION_SET_OCCLUSION_SILHOUETTE_ENABLED`
  - Modify `scripts/state/reducers/u_vfx_reducer.gd`: handle action
  - All tests should pass
  - Completion note (2026-03-10): Added action constant/creator registration and reducer handling with default-state merge support.

- [x] **Task 0B.5 (Red)**: Write tests for VFX selector
  - Modify `tests/unit/state/test_vfx_selectors.gd`
  - Test `is_occlusion_silhouette_enabled()` returns value from state
  - Test selector returns `true` when slice missing (default)
  - Test selector returns `true` when field missing (default)
  - **Target: 3 tests**
  - Completion note (2026-03-10): Added selector coverage for enabled/disabled and missing-slice/field default behavior.

- [x] **Task 0B.6 (Green)**: Implement VFX selector
  - Modify `scripts/state/selectors/u_vfx_selectors.gd`: add `is_occlusion_silhouette_enabled(state)`
  - All tests should pass
  - Completion note (2026-03-10): Implemented `U_VFXSelectors.is_occlusion_silhouette_enabled(...)` with safe default `true`.

- [x] **Task 0B.7 (Red)**: Write tests for VFX settings overlay silhouette toggle
  - Create/modify `tests/unit/ui/test_vfx_settings_overlay.gd`
  - Modify `tests/unit/ui/test_vfx_settings_overlay_localization.gd`
  - Test overlay renders a silhouette toggle bound to `occlusion_silhouette_enabled`
  - Test Apply dispatch persists silhouette toggle changes through `U_VFXActions`
  - Test Reset restores silhouette toggle to default (`true`)
  - Test localization updates silhouette label/tooltip keys
  - **Target: 4 tests**
  - Completion note (2026-03-10): Expanded integration/localization coverage for silhouette toggle init/apply/cancel/reset and localized label/tooltip updates.

- [x] **Task 0B.8 (Green)**: Implement VFX settings overlay silhouette toggle
  - Modify `scripts/ui/settings/ui_vfx_settings_overlay.gd`: add control wiring, apply/reset/localization handling
  - Modify `scenes/ui/overlays/settings/ui_vfx_settings_overlay.tscn`: add silhouette toggle row
  - Modify all UI locale resources under `resources/localization/cfg_locale_*_ui.tres` for new silhouette label/tooltip keys
  - All tests should pass
  - Completion note (2026-03-10): Added silhouette toggle UI row and controller wiring, localized strings across all UI locales, and global-settings apply dispatch support.

---

### Phase 0C: vCam Initial State Resource

- [x] **Task 0C.1 (Red)**: Write tests for RS_VCamInitialState
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
  - Test `to_dictionary()` returns `in_fov_zone` as `false`
  - Test `to_dictionary()` returns exactly 11 keys
  - **Target: 12 tests**
  - Completion note (2026-03-10): Added `test_vcam_initial_state.gd` with 12 assertions covering all expected dictionary defaults and key count.

- [x] **Task 0C.2 (Green)**: Implement RS_VCamInitialState
  - Create `scripts/resources/state/rs_vcam_initial_state.gd`
  - Implement `to_dictionary()` returning all 11 fields (including `in_fov_zone: false`)
  - All tests should pass
  - Completion note (2026-03-10): Added `RS_VCamInitialState` with exported runtime observability fields and `to_dictionary()` output matching the Phase 0C contract.

- [x] **Task 0C.3**: Create default resource instance
  - Create `resources/state/cfg_default_vcam_initial_state.tres`
  - Set all fields to defaults
  - Completion note (2026-03-10): Added `cfg_default_vcam_initial_state.tres` bound to `RS_VCamInitialState` for root/store wiring in the next phase.

---

### Phase 0D: vCam Actions and Reducer

- [x] **Task 0D.1 (Red)**: Write tests for U_VCamActions
  - Create `tests/unit/state/test_vcam_actions.gd`
  - Test `set_active_runtime(vcam_id, mode)` action structure has correct type and payload
  - Test `start_blend(previous_id)` action structure
  - Test `update_blend(progress)` action structure
  - Test `complete_blend()` action structure
  - Test `update_silhouette_count(count)` action structure
  - Test `update_target_validity(valid)` action structure
  - Test `record_recovery(reason)` action structure
  - Test `update_fov_zone(in_zone)` action structure
  - **Target: 8 tests**
  - Completion note (2026-03-10): Added `test_vcam_actions.gd` with 8 action-structure tests covering all Phase 0D creators, including `update_fov_zone`.

- [x] **Task 0D.2 (Green)**: Implement U_VCamActions
  - Create `scripts/state/actions/u_vcam_actions.gd`
  - Add 8 action type constants and static creator functions (including `update_fov_zone`)
  - All tests should pass
  - Completion note (2026-03-10): Added `U_VCamActions` constants, registry registration in `_static_init()`, and immediate action creators for runtime/blend/silhouette/target/recovery/FOV-zone updates.

- [x] **Task 0D.2a**: Add vCam event constants to U_ECSEventNames
  - Modify `scripts/events/ecs/u_ecs_event_names.gd`
  - Add `EVENT_VCAM_ACTIVE_CHANGED := &"vcam_active_changed"`
  - Add `EVENT_VCAM_BLEND_STARTED := &"vcam_blend_started"`
  - Add `EVENT_VCAM_BLEND_COMPLETED := &"vcam_blend_completed"`
  - Add `EVENT_VCAM_RECOVERY := &"vcam_recovery"`
  - Follow existing `EVENT_*` naming and `StringName` pattern
  - These events are published by `M_VCamManager` through `U_ECSEventBus` so `S_GameEventSystem`, `S_CameraStateSystem`, and QB rules can subscribe to vCam lifecycle changes
  - Completion note (2026-03-10): Added all four vCam lifecycle constants to `U_ECSEventNames` using the existing `StringName` event pattern.

- [x] **Task 0D.3 (Red)**: Write tests for U_VCamReducer
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
  - Test `update_fov_zone` sets `in_fov_zone` to provided bool
  - Test reducer returns same state for unknown action
  - Test reducer immutability (old state reference != new state reference)
  - **Target: 13 tests**
  - Completion note (2026-03-10): Added `test_vcam_reducer.gd` with 13 tests covering blend lifecycle, clamps, recovery/target/FOV updates, unknown-action behavior, and immutability.

- [x] **Task 0D.4 (Green)**: Implement U_VCamReducer
  - Create `scripts/state/reducers/u_vcam_reducer.gd`
  - Implement `reduce(state, action)` with match statement
  - All tests should pass
  - Completion note (2026-03-10): Added `U_VCamReducer` defaults + reducer branches for all vCam actions with blend-progress and silhouette clamps, safe payload normalization, and unchanged-state return on unknown actions.

---

### Phase 0E: Selectors, Store Export, and Transient Slice Registration

- [x] **Task 0E.1 (Red)**: Write tests for U_VCamSelectors
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
  - Test `is_in_fov_zone(state)` returns value from state
  - Test `is_in_fov_zone(state)` returns `false` when missing
  - **Target: 23 tests**
  - Completion note (2026-03-10): Added `test_vcam_selectors.gd` with 23 tests covering all selector defaults/fields and state immutability.

- [x] **Task 0E.2 (Green)**: Implement U_VCamSelectors
  - Create `scripts/state/selectors/u_vcam_selectors.gd`
  - All selectors null-safe and slice-safe (including 4 debug-field selectors: `get_blend_from_vcam_id`, `get_blend_to_vcam_id`, `is_active_target_valid`, `get_last_recovery_reason`, plus `is_in_fov_zone`)
  - All tests should pass
  - Completion note (2026-03-10): Added `U_VCamSelectors` with null-safe accessors for all runtime and debug fields, including `is_in_fov_zone`.

- [x] **Task 0E.3**: Integrate vcam slice with M_StateStore
  - Modify `scripts/state/m_state_store.gd`: add `@export var vcam_initial_state: Resource`
  - Modify `scripts/state/utils/u_state_slice_manager.gd`: add `vcam` slice registration with `is_transient = true`
  - Modify `scenes/root.tscn`: assign `cfg_default_vcam_initial_state.tres`
  - Completion note (2026-03-10): Wired `vcam_initial_state` through `M_StateStore`/`U_StateSliceManager`, registered `vcam` as transient, and assigned `cfg_default_vcam_initial_state.tres` in `scenes/root.tscn`.

- [x] **Task 0E.4**: Verify integration
  - Run existing state tests (no regressions)
  - Verify `vcam` slice appears in `get_state()` output
  - Verify `vcam` slice is registered as transient
  - Verify `vcam` is NOT included in global settings persistence
  - Completion note (2026-03-10): Added/updated state integration assertions in `test_m_state_store.gd`, `test_state_persistence.gd`, and `test_global_settings_persistence.gd`; all targeted suites passed.

---

### Phase 0F: Camera Slice Migration (`in_fov_zone`)

> **Context:** Phase 0F migrated `in_fov_zone` reads to `state.vcam.in_fov_zone` and retired legacy runtime/test reads of `state.camera.in_fov_zone`.

- [x] **Task 0F.1**: Migrate `S_CameraStateSystem` reads of `state.camera.in_fov_zone`
  - Modify `scripts/ecs/systems/s_camera_state_system.gd`: replace reads of `state.camera.in_fov_zone` with `U_VCamSelectors.is_in_fov_zone(state)` (or `state.vcam.in_fov_zone`)
  - Update any `S_CameraStateSystem` code that dispatches `set_slice("camera", ...)` for `in_fov_zone` to use `U_VCamActions.update_fov_zone(in_zone)` instead
  - Completion note (2026-03-10): `S_CameraStateSystem._is_fov_zone_active(...)` now reads through `U_VCamSelectors.is_in_fov_zone(state)`.

- [x] **Task 0F.2**: Update tests that reference `state.camera`
  - Grep for `set_slice("camera"` and `state.camera` in test files
  - Explicitly update `tests/unit/qb/test_camera_state_system.gd` and any integration/QB camera tests that seed the legacy slice
  - Update any test that sets up `camera.in_fov_zone` to use `vcam.in_fov_zone` instead
  - Verify no remaining references to `state.camera` slice exist in the codebase
  - Completion note (2026-03-10): Updated QB unit/integration camera tests to seed `vcam.in_fov_zone` and verified no non-doc references remain.

- [x] **Task 0F.3**: Retire informal `camera` slice
  - Remove any `camera` slice registration if one exists
  - Add `DEV_PITFALLS.md` note: "The informal `camera` slice is retired. `in_fov_zone` lives in `state.vcam.in_fov_zone`. Do not re-introduce `state.camera`."
  - Completion note (2026-03-10): Updated docs/contracts to treat `state.vcam.in_fov_zone` as canonical runtime source and added a guardrail pitfall note.

- [x] **Task 0F.4**: Verify migration
  - Run full test suite: no test references `state.camera` or `set_slice("camera", ...)`
  - `U_VCamSelectors.is_in_fov_zone(state)` returns correct values through the full dispatch/reduce/select cycle
  - **Target: 2 verification tests**
  - Completion note (2026-03-10): Passed `tests/unit/qb/test_camera_state_system.gd`, `tests/integration/qb/test_camera_shake_pipeline.gd`, and `tests/unit/style/test_style_enforcement.gd`.

---

## Phase 1: Base Authoring Resources (Soft Zone + Blend Hint)

**Exit Criteria:** All ~42 tests pass (7 soft zone + 7 blend hint + 13 second-order dynamics 1D + 7 second-order dynamics 3D + 8 response resource), default `.tres` instances created. Note: look-ahead and auto-level fields on RS_VCamResponse are added in orbit Phase 2C when those features are implemented.

### Phase 1A: RS_VCamSoftZone

- [x] **Task 1A.1 (Red)**: Write tests for RS_VCamSoftZone
  - Create `tests/unit/resources/display/vcam/test_vcam_soft_zone.gd`
  - Test `dead_zone_width` field exists with default (e.g. 0.1)
  - Test `dead_zone_height` field exists with default (e.g. 0.1)
  - Test `soft_zone_width` field exists with default (e.g. 0.4)
  - Test `soft_zone_height` field exists with default (e.g. 0.4)
  - Test `damping` field exists with default (e.g. 2.0)
  - Test all values are non-negative
  - Test soft zone dimensions >= dead zone dimensions conceptually
  - **Target: 7 tests**
  - Completion note (2026-03-10): Added `test_vcam_soft_zone.gd` with 7 assertions covering defaults, non-negative bounds, and zone-size ordering.

- [x] **Task 1A.2 (Green)**: Implement RS_VCamSoftZone
  - Create `scripts/resources/display/vcam/rs_vcam_soft_zone.gd`
  - All `@export` fields with sensible defaults
  - All tests should pass
  - Completion note (2026-03-10): Added `RS_VCamSoftZone` with exported dead-zone/soft-zone dimensions and damping defaults.

---

### Phase 1B: RS_VCamBlendHint

- [x] **Task 1B.1 (Red)**: Write tests for RS_VCamBlendHint
  - Create `tests/unit/resources/display/vcam/test_vcam_blend_hint.gd`
  - Test `blend_duration` field exists with default (e.g. 1.0)
  - Test `ease_type` field exists with default (e.g. `Tween.EASE_IN_OUT`)
  - Test `trans_type` field exists with default (e.g. `Tween.TRANS_CUBIC`)
  - Test `cut_on_distance_threshold` field exists with default `0.0` (disabled)
  - Test `blend_duration` is non-negative
  - Test `cut_on_distance_threshold` is non-negative
  - Test zero `blend_duration` means instant cut
  - **Target: 7 tests**
  - Completion note (2026-03-10): Added `test_vcam_blend_hint.gd` with 7 assertions for defaults, bounds, and instant-cut behavior.

- [x] **Task 1B.2 (Green)**: Implement RS_VCamBlendHint
  - Create `scripts/resources/display/vcam/rs_vcam_blend_hint.gd`
  - All `@export` fields with sensible defaults
  - All tests should pass
  - Completion note (2026-03-10): Added `RS_VCamBlendHint` with blend/tween fields and `is_instant_cut()` helper.

---

### Phase 1C: Default Preset Resources

- [x] **Task 1C.1**: Create default resource instances
  - Create `resources/display/vcam/cfg_default_soft_zone.tres`
  - Create `resources/display/vcam/cfg_default_blend_hint.tres`
  - Verify resources load without errors
  - Completion note (2026-03-10): Added both default vCam resource presets and validated via new resource unit suites + style gate.

---

### Phase 1D: Second-Order Dynamics Utility

> **Why:** Simple lerp/slerp damping produces robotic camera motion with no natural overshoot, settling, or responsiveness. Second-order dynamics model a mass-spring-damper system that gives camera follow, tracking, and soft-zone correction physically plausible motion with tuneable character (snappy, smooth, bouncy).

- [x] **Task 1D.1 (Red)**: Write tests for U_SecondOrderDynamics
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
  - Completion note (2026-03-10): Added `test_second_order_dynamics.gd` with 13 tests covering convergence, damping regimes, stability guards, reset behavior, and response tuning.

- [x] **Task 1D.2 (Green)**: Implement U_SecondOrderDynamics
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
  - Completion note (2026-03-10): Added `U_SecondOrderDynamics` with semi-implicit integration, frequency clamp, large-`dt` guard, and finite-value fallback handling.

- [x] **Task 1D.3**: Run style enforcement tests
  - `tests/unit/style/test_style_enforcement.gd` passes with new files
  - Verify `u_second_order_dynamics.gd` is in `scripts/utils/math/`
  - Completion note (2026-03-10): `tests/unit/style/test_style_enforcement.gd` passed after adding `scripts/utils/math/u_second_order_dynamics.gd`.

---

### Phase 1E: U_SecondOrderDynamics3D (Vector3 Wrapper)

- [x] **Task 1E.1 (Red)**: Write tests for U_SecondOrderDynamics3D
  - Create `tests/unit/utils/test_second_order_dynamics_3d.gd`
  - Test initial state: output matches initial `Vector3`
  - Test step toward target: output moves toward target `Vector3`
  - Test convergence: after many steps, each axis approximates target within epsilon
  - Test axes are independent: stepping X does not affect Y or Z
  - Test `reset(new_value)` snaps all three axes
  - Test critically damped motion on all axes simultaneously
  - Test under-damped produces overshoot on all three axes
  - **Target: 7 tests**
  - Completion note (2026-03-10): Added `test_second_order_dynamics_3d.gd` with 7 tests covering convergence, axis independence, reset semantics, and damping-regime behavior.

- [x] **Task 1E.2 (Green)**: Implement U_SecondOrderDynamics3D
  - Create `scripts/utils/math/u_second_order_dynamics_3d.gd`
  - Add `class_name U_SecondOrderDynamics3D`
  - Wraps three `U_SecondOrderDynamics` instances (x, y, z)
  - Constructor: `func _init(f: float, zeta: float, r: float, initial_value: Vector3 = Vector3.ZERO)`
  - Methods:
    - `func step(target: Vector3, dt: float) -> Vector3`
    - `func reset(value: Vector3) -> void`
    - `func get_value() -> Vector3`
  - All tests should pass
  - Completion note (2026-03-10): Added `U_SecondOrderDynamics3D` as a lightweight 3-axis wrapper around `U_SecondOrderDynamics`.

- [x] **Task 1E.3**: Run style enforcement tests
  - Completion note (2026-03-10): `tests/unit/style/test_style_enforcement.gd` passed with the new vector wrapper utility.

---

### Phase 1F: RS_VCamResponse Resource

- [x] **Task 1F.1 (Red)**: Write tests for RS_VCamResponse
  - Create `tests/unit/resources/display/vcam/test_vcam_response.gd`
  - **Second-order dynamics tuning:**
  - Test `follow_frequency` field exists with default `3.0`
  - Test `follow_damping` field exists with default `0.7` (slightly underdamped for natural feel)
  - Test `follow_initial_response` field exists with default `1.0` (immediate reaction)
  - Test `rotation_frequency` field exists with default `4.0`
  - Test `rotation_damping` field exists with default `1.0` (critically damped — no rotational wobble)
  - Test `rotation_initial_response` field exists with default `1.0`
  - Test `frequency` values must be positive (reject 0.0 and negative)
  - Test `damping` values must be non-negative (0.0 = undamped oscillation is valid but extreme)
  - **Target: 8 tests**
  - Completion note (2026-03-10): Added `test_vcam_response.gd` with 8 tests for defaults and resolved clamp behavior.

- [x] **Task 1F.2 (Green)**: Implement RS_VCamResponse
  - Create `scripts/resources/display/vcam/rs_vcam_response.gd`
  - Extend `Resource`
  - Add `class_name RS_VCamResponse`
  - All `@export` fields with sensible defaults:
    - **Second-order dynamics tuning:**
    - `follow_frequency: float = 3.0` — how fast position tracks target (Hz)
    - `follow_damping: float = 0.7` — position damping ratio (< 1 = slight overshoot, 1 = critical, > 1 = sluggish)
    - `follow_initial_response: float = 1.0` — position initial response (0 = gradual, 1 = immediate)
    - `rotation_frequency: float = 4.0` — how fast rotation tracks target (Hz)
    - `rotation_damping: float = 1.0` — rotation damping ratio
    - `rotation_initial_response: float = 1.0` — rotation initial response
  - All tests should pass
  - Completion note (2026-03-10): Added `RS_VCamResponse` with base follow/rotation fields and `get_resolved_values()` clamp contract for frequency/damping safety.

- [x] **Task 1F.3**: Create default response resource instance
  - Create `resources/display/vcam/cfg_default_response.tres`
  - Set all fields to defaults (follow: f=3.0, z=0.7, r=1.0; rotation: f=4.0, z=1.0, r=1.0)
  - Verify resource loads without errors
  - Completion note (2026-03-10): Added `cfg_default_response.tres` with Phase 1F defaults.

- [x] **Task 1F.5**: Run style enforcement tests
  - Completion note (2026-03-10): `tests/unit/style/test_style_enforcement.gd` passed after adding response resource/test files.

---

## Phase 5: Component, Interface, and Manager Core

**Exit Criteria:** All ~37 tests pass (15 component + 8 interface/manager registration + 11 manager active-selection + 3 manager active-clear/recovery transition checks), `M_VCamManager` registered with ServiceLocator

### Phase 5A: C_VCamComponent

- [x] **Task 5A.1 (Red)**: Write tests for C_VCamComponent
  - Create `tests/unit/ecs/components/test_vcam_component.gd`
  - Test extends `BaseECSComponent`
  - Test `COMPONENT_TYPE` constant is `&"VCamComponent"`
  - Test `vcam_id` export exists
  - Test `priority` export exists with default `0`
  - Test `mode` export exists (Resource type)
  - Test `fixed_anchor_path` export exists (NodePath)
  - Test `follow_target_path` export exists (NodePath)
  - Test `follow_target_entity_id` export exists (StringName, default `&""`) — entity ID fallback for dynamic target resolution via `M_ECSManager.get_entity_by_id()`
  - Test `follow_target_tag` export exists (StringName, default `&""`) — tag fallback for target resolution via `M_ECSManager.get_entities_by_tag()`
  - Test `look_at_target_path` export exists (NodePath)
  - Test `path_node_path` export exists (NodePath)
  - Test `soft_zone` export exists (Resource type)
  - Test `blend_hint` export exists (Resource type)
  - Test `response` export exists (Resource type, RS_VCamResponse)
  - Test `is_active` export exists with default `true`
  - **Target: 15 tests**
  - Completion note (2026-03-10): Added `tests/unit/ecs/components/test_vcam_component.gd` with 15 assertions covering component type and all required exports/defaults.

- [x] **Task 5A.2 (Green)**: Implement C_VCamComponent
  - Create `scripts/ecs/components/c_vcam_component.gd`
  - Extend `BaseECSComponent`, set `COMPONENT_TYPE`
  - Add all exports (including `response: RS_VCamResponse`, `follow_target_entity_id`, `follow_target_tag`, `path_node_path: NodePath`) and runtime-only `runtime_yaw`, `runtime_pitch` vars
  - Implement null-safe `get_follow_target()` and `get_look_at_target()` typed getters
  - Target resolution priority in `S_VCamSystem`: NodePath → entity ID → tag → null (recovery)
  - All tests should pass
  - Completion note (2026-03-10): Added `scripts/ecs/components/c_vcam_component.gd` with full export surface (including entity-id/tag/path fallbacks), `RS_VCamResponse`-typed export hint + runtime guard for `response`, runtime yaw/pitch fields, null-safe target/anchor/path getters, mode-name helper, and auto register/unregister integration with `M_VCamManager`.

---

### Phase 5B: I_VCamManager Interface

- [x] **Task 5B.1**: Create I_VCamManager interface
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
  - Completion note (2026-03-10): Added `scripts/interfaces/i_vcam_manager.gd` with all 8 required methods and `push_error` default implementations.

---

### Phase 5C: M_VCamManager Core (Registration and Active Selection)

- [x] **Task 5C.1 (Red)**: Write tests for M_VCamManager registration
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
  - Completion note (2026-03-10): Added registration-focused coverage in `tests/unit/managers/test_vcam_manager.gd` (interface extension, service registration, duplicate rejection, unregister/reset paths).

- [x] **Task 5C.2 (Green)**: Implement M_VCamManager registration
  - Create `scripts/managers/m_vcam_manager.gd` extending `I_VCamManager`
  - Implement registration dictionary, ServiceLocator registration
  - All tests should pass
  - Completion note (2026-03-10): Implemented `M_VCamManager` core registry maps (`_vcams_by_id`, `_registered_vcams`), ServiceLocator registration as `vcam_manager`, and unregister/runtime-state cleanup behavior.

- [x] **Task 5C.3 (Red)**: Write tests for M_VCamManager active selection
  - Add to `tests/unit/managers/test_vcam_manager.gd`
  - Test `set_active_vcam()` by explicit ID sets active vcam
  - Test `set_active_vcam()` with unknown ID logs error and does nothing
  - Test priority-based selection: highest priority wins
  - Test priority tie-break: ascending `vcam_id` wins
  - Test `get_active_vcam_id()` returns current active
  - Test `get_active_vcam_id()` returns `&""` when no vcams registered
  - Test `set_active_vcam()` dispatches `vcam/set_active_runtime` action
  - Test `set_active_vcam()` publishes `EVENT_VCAM_ACTIVE_CHANGED` through `U_ECSEventBus` with `{vcam_id, previous_vcam_id, mode}` payload
  - Test `is_active = false` on component excludes it from priority selection
  - Test changing `is_active` to false on the active vcam triggers reselection
  - Test priority reselection after unregister picks next highest
  - **Target: 11 tests**
  - Completion note (2026-03-10): Added active-selection coverage in `tests/unit/managers/test_vcam_manager.gd` for explicit selection, unknown-id no-op, priority/tie-break rules, inactive filtering, reselection, Redux dispatch, and ECS event publication.

- [x] **Task 5C.4 (Green)**: Implement M_VCamManager active selection
  - Add active selection logic with explicit override and priority fallback
  - Add Redux dispatch integration (injection-first, ServiceLocator fallback)
  - Publish `U_ECSEventBus.publish(U_ECSEventNames.EVENT_VCAM_ACTIVE_CHANGED, payload)` on active vCam change
  - All tests should pass
  - Completion note (2026-03-10): Implemented explicit-override + priority-based active selection with ascending `vcam_id` tie-break, inactive exclusion, runtime reselection on physics ticks, store dispatch via `U_VCamActions.set_active_runtime(...)`, ECS `EVENT_VCAM_ACTIVE_CHANGED` publishing (including active-clear transitions to empty IDs), and `submit_evaluated_camera(...)` storage for same-frame handoff.
  - Gap-closure addendum (2026-03-10): Added transition-accuracy tests for unregister/pruned-active paths so `previous_vcam_id` is preserved when reseating/clearing active state (`22/22` manager tests passing).

---

## Phase 6: vCam System (ECS) and Scene Wiring

**Exit Criteria:** All ~43 system tests pass (12 core + 6 rotation continuity + 8 second-order dynamics + 4 camera state fields + 6 FOV breathing + 5 landing impact rule + 4 landing impact recovery + 4 recovery tests), `S_VCamSystem` reads look input from Redux, evaluates active/outgoing vcams, applies second-order dynamics smoothing via `RS_VCamResponse`, applies landing impact offset with spring recovery, integrates with QB-driven FOV breathing, submits results to manager, scene wiring complete, desktop manual camera checks pass (`MT-01..MT-04`, `MT-09..MT-15`, `MT-18`)

### Phase 6A: S_VCamSystem

- [x] **Task 6A.1 (Red)**: Write tests for S_VCamSystem
  - Create `tests/unit/ecs/systems/test_vcam_system.gd`
  - Test extends `BaseECSSystem`
  - Test resolves `I_VCamManager` via ServiceLocator
  - Test reads `look_input` from gameplay Redux slice (`gameplay.look_input` from `S_InputSystem` / `S_TouchscreenSystem`)
  - Test evaluates active vCam each tick via `U_VCamModeEvaluator`
  - Test updates `runtime_yaw` on orbit component when `allow_player_rotation = true`
  - Test updates `runtime_pitch` on orbit component when `allow_player_rotation = true`
  - Test does NOT update yaw/pitch on orbit when `allow_player_rotation = false`
  - Test updates yaw/pitch on OTS component using `look_multiplier`
  - Test submits evaluated result to `M_VCamManager.submit_evaluated_camera()`
  - Test evaluates outgoing vCam too when `manager.is_blending()` is true
  - Test resolves follow target from NodePath export first, then falls back to entity query (`M_ECSManager.get_entity_by_id()`) when path is empty
  - Test resolves follow target by tag (`M_ECSManager.get_entities_by_tag()`) as last fallback
  - Test multiple valid tag matches resolve to the first valid ECS-registration-order entity and emit a debug warning
  - Test `use_path` helper is created in the gameplay scene world, not parented under the persistent root manager
  - Test `use_path` with invalid follow target enters standard recovery and does not fabricate path progress
  - Test does nothing when no active vCam exists
  - Test does nothing when manager is not found
  - **Target: 17 tests**
  - Completion note (2026-03-10): Added `tests/unit/ecs/systems/test_vcam_system.gd` with 17 focused tests covering manager resolution, look-input rotation updates, active/outgoing evaluation, NodePath/entity/tag target resolution order, path-helper behavior, and no-op guard paths.

- [x] **Task 6A.2 (Green)**: Implement S_VCamSystem
  - Create `scripts/ecs/systems/s_vcam_system.gd`
  - Extend `BaseECSSystem`, implement `process_tick(delta)`
  - Order the system after gameplay input/movement so current-frame state and target transforms are available before camera evaluation
  - Resolve manager, read look input, evaluate modes, submit results
  - Target resolution priority: NodePath export → `M_ECSManager.get_entity_by_id(target_entity_id)` → `M_ECSManager.get_entities_by_tag(target_tag)` → null (triggers recovery). If tag lookup returns multiple valid entities, use the first valid ECS-registration-order match and emit a debug warning.
  - Keep any `PathFollow3D` helper scene-local in the gameplay world
  - Submit results as the same-frame handoff to `M_VCamManager`; do not rely on root `_physics_process` ordering
  - All tests should pass
  - Completion note (2026-03-10): Added `scripts/ecs/systems/s_vcam_system.gd` with ServiceLocator/injection manager resolution, Redux look-input consumption, orbit/first-person runtime angle updates (`rotation_speed`/`look_multiplier` system-owned), active+previous blend evaluation/submission, NodePath→entity ID→tag target fallback, and gameplay-local `PathFollow3D` helper management for fixed `use_path`.

### Phase 6A2: Second-Order Dynamics Integration in S_VCamSystem

> **Why:** The evaluator computes instantaneous "ideal" poses (where the camera *should* be). Without smoothing, the camera teleports to the ideal pose every frame. Second-order dynamics make the camera *pursue* the ideal pose with physically plausible motion — slight overshoot on fast follow, smooth settling, no robotic snapping.

- [x] **Task 6A2.1 (Red)**: Write tests for second-order dynamics camera smoothing
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
  - Completion note (2026-03-10): Added 8 Phase 6A2 tests to `tests/unit/ecs/systems/test_vcam_system.gd` covering active smoothing, convergence, damping behavior (under/critical), null-response passthrough, rotation convergence, and reset-on-mode/target change semantics.

- [x] **Task 6A2.2 (Green)**: Implement second-order dynamics in S_VCamSystem
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
  - Completion note (2026-03-10): `S_VCamSystem` now applies `RS_VCamResponse`-driven second-order smoothing (position + per-axis rotation), recreates dynamics on response changes, resets dynamics on mode/follow-target changes, unwraps Euler targets for rotation continuity in smoothing space, and passes raw evaluator output through when `response` is null.
  - Follow-up addendum (2026-03-10): orbit/first-person look now uses dedicated movement-style spring-damper smoothing at evaluator input time while `runtime_yaw`/`runtime_pitch` remain raw targets; fixed-mode rotation smoothing remains on the existing response path to avoid double-softness.

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

- [x] **Task 6A.3 (Red)**: Write tests for rotation continuity on mode switch
  - Add to `tests/unit/ecs/systems/test_vcam_system.gd`
  - Test orbit → first-person carries `runtime_yaw`, resets `runtime_pitch` to `0.0`
  - Test first-person → orbit carries `runtime_yaw`, resets `runtime_pitch` to `0.0`
  - Test orbit → fixed preserves outgoing component's `runtime_yaw`/`runtime_pitch`
  - Test fixed → orbit reseeds `runtime_yaw` to authored yaw, resets `runtime_pitch` to `0.0`
  - Test same-mode switch with same target carries both yaw/pitch
  - Test same-mode switch with different target reseeds to authored angles
  - **Target: 6 tests**
  - Completion note (2026-03-10): Added 6 rotation-continuity tests to `tests/unit/ecs/systems/test_vcam_system.gd` covering orbit↔first-person carry/reset, orbit→fixed outgoing preservation, fixed→orbit authored reseed, and same-mode target-aware carry/reseed behavior.

- [x] **Task 6A.4 (Green)**: Implement rotation continuity policy in S_VCamSystem
  - Apply carry/reset/reseed rules based on mode transition type (per overview Rotation Continuity Contract)
  - All tests should pass
  - Completion note (2026-03-10): `S_VCamSystem` now applies transition-aware yaw/pitch continuity on active-vCam switches, including same-mode shared-target carry and authored-angle reseed fallback for target changes.

---

### Phase 6A3: QB-Driven Camera Feel (FOV Breathing + Landing Impact)

> **Indexed as Phase 8 in [vcam-manager-tasks.md](vcam-manager-tasks.md).**

> **Why:** Leverages the existing QB rule engine (`S_CameraStateSystem` + `C_CameraStateComponent`) and ECS event bus instead of building bespoke feel systems. Rules are authored as `.tres` files — designers can tune camera feel without code changes.

#### Phase 6A3a: C_CameraStateComponent Extensions

- [x] **Task 6A3a.1 (Red)**: Write tests for new camera state fields
  - Add to `tests/unit/ecs/components/test_camera_state_component.gd` (or existing camera state tests)
  - Test `landing_impact_offset` field exists with default `Vector3.ZERO`
  - Test `landing_impact_recovery_speed` field exists with default `8.0` (Hz — second-order dynamics frequency for settling)
  - Test `speed_fov_bonus` field exists with default `0.0` (added to target_fov by speed-based rules)
  - Test `speed_fov_max_bonus` field exists with default `15.0` (clamped ceiling for speed FOV)
  - **Target: 4 tests**
  - Completion note (2026-03-10): Added `tests/unit/ecs/components/test_camera_state_component.gd` with default/export coverage for `landing_impact_offset`, `landing_impact_recovery_speed`, `speed_fov_bonus`, and `speed_fov_max_bonus`.

- [x] **Task 6A3a.2 (Green)**: Implement new fields on C_CameraStateComponent
  - Modify `scripts/ecs/components/c_camera_state_component.gd`:
    - `@export var landing_impact_offset: Vector3 = Vector3.ZERO` — transient vertical offset applied to camera on landing
    - `@export var landing_impact_recovery_speed: float = 8.0` — second-order dynamics frequency for offset recovery
    - `@export var speed_fov_bonus: float = 0.0` — current speed-driven FOV addition (set by QB rule)
    - `@export var speed_fov_max_bonus: float = 15.0` — max speed FOV bonus (clamp ceiling)
  - All tests should pass
  - Completion note (2026-03-10): Added the four 6A3a fields/constants to `C_CameraStateComponent`, and extended `reset_state()` + `get_snapshot()` to include landing-impact and speed-FOV runtime data.

  **Composition specification:**
  - **FOV formula:** `target_fov = base_fov + clamp(speed_fov_bonus, 0.0, speed_fov_max_bonus)` — `base_fov` is set by vCam (via `M_VCamManager`), `speed_fov_bonus` is set by the QB speed-FOV rule, `S_CameraStateSystem` applies the composition.
  - **Landing impact offset ownership:** `landing_impact_offset` is applied by `S_VCamSystem` (position offset on the evaluated camera pose), NOT by `S_CameraStateSystem` (which owns shake, not spatial offsets). This keeps shake and impact in separate stages.
  - **Stacking order (three stages, no conflict):**
    1. **FP pitch dip** (before evaluator): `S_VCamSystem` adds `_landing_pitch_offset` to `runtime_pitch` before calling the evaluator — affects the rotation input to the evaluation.
    2. **Position offset** (after evaluator): `S_VCamSystem` reads `landing_impact_offset` from `C_CameraStateComponent` and adds it to the evaluated camera position — affects the final world-space position.
    3. **Shake** (after submit): `M_CameraManager` applies shake offsets through `ShakeParent` after `apply_main_camera_transform()` — a completely independent transform layer.
  - These three stages are ordered and non-conflicting: pitch dip rotates the view, position offset moves the camera, and shake vibrates the final result.

#### Phase 6A3b: FOV Breathing via QB Rule

> Reuses existing `S_CameraStateSystem` tick evaluation + `C_CameraStateComponent.target_fov` + `fov_blend_speed`. The rule reads player velocity magnitude from a movement component and sets `speed_fov_bonus`, which `S_CameraStateSystem` adds to `target_fov`.

- [x] **Task 6A3b.1 (Red)**: Write tests for speed-based FOV rule
  - Add to `tests/unit/qb/test_camera_state_system.gd`
  - Test tick rule with `RS_ConditionComponentField` reading velocity magnitude from `C_MovementComponent` (or `C_InputComponent` move vector length as proxy)
  - Test effect sets `speed_fov_bonus` on `C_CameraStateComponent` via `RS_EffectSetField`
  - Test `speed_fov_bonus` is clamped to `[0.0, speed_fov_max_bonus]`
  - Test `S_CameraStateSystem._resolve_target_fov()` incorporates `speed_fov_bonus` (returns `base_target + speed_fov_bonus`)
  - Test stationary player produces `speed_fov_bonus = 0.0`
  - Test `fov_blend_speed` smooths the FOV transition (no instant snap)
  - **Target: 6 tests**
  - Completion note (2026-03-10): Expanded `tests/unit/qb/test_camera_state_system.gd` with six 6A3b assertions covering speed-rule score application, stationary reset, `speed_fov_bonus` clamping, target-FOV composition, and blend smoothing.

- [x] **Task 6A3b.2 (Green)**: Implement FOV breathing
  - Modify `scripts/ecs/systems/s_camera_state_system.gd`:
    - `_resolve_target_fov()` adds `camera_state.speed_fov_bonus` to the resolved FOV
    - Clamp `speed_fov_bonus` to `[0.0, speed_fov_max_bonus]` before adding
  - Create QB rule `.tres`:
    - Create `resources/qb/camera/cfg_camera_speed_fov_rule.tres`
    - Trigger: `tick` mode (evaluated every frame)
    - Condition: `RS_ConditionComponentField` — read movement velocity magnitude, normalize to 0.0–1.0 range (min=0, max=sprint speed)
    - Optional `response_curve: Curve` — ease-in curve so FOV ramps gently at low speeds, aggressively at sprint
    - Effect: `RS_EffectSetField` — `component_type = C_CameraStateComponent`, `field = speed_fov_bonus`, `operation = set`, `value = 15.0` (max bonus, scaled by condition score)
  - Add rule to `S_CameraStateSystem.DEFAULT_RULE_DEFINITIONS` or inject via export
  - All tests should pass
  - Completion note (2026-03-10): Added `resources/qb/camera/cfg_camera_speed_fov_rule.tres`, registered it in `S_CameraStateSystem.DEFAULT_RULE_DEFINITIONS`, added movement-speed context plumbing for `RS_ConditionComponentField`, and extended `RS_EffectSetField` + camera rule execution context with rule-score scaling so `speed_fov_bonus` tracks normalized speed continuously.

  **Existing infrastructure reused:**
  - `RS_ConditionComponentField` (reads component field, normalizes to 0–1)
  - `RS_EffectSetField` (sets component field with optional curve scaling)
  - `C_CameraStateComponent.target_fov` + `fov_blend_speed` (smooth FOV transitions already work)
  - `S_CameraStateSystem` tick evaluation loop (no new system needed)

#### Phase 6A3c: Landing Impact via QB Rule + Event Bus

> Subscribes to existing `EVENT_ENTITY_LANDED` (already published by physics with `fall_speed` payload). On landing, a QB rule sets `landing_impact_offset` on `C_CameraStateComponent`. `S_VCamSystem` reads and applies this offset, then recovers via second-order dynamics.

- [x] **Task 6A3c.1 (Red)**: Write tests for landing impact rule
  - Add to `tests/unit/qb/test_camera_state_system.gd`
  - Test event rule triggers on `EVENT_ENTITY_LANDED` via `RS_ConditionEventName`
  - Test `RS_ConditionEventPayload` reads `fall_speed` and normalizes to 0.0–1.0 (min=landing_threshold, max=landing_max_speed per existing `RS_ScreenShakeTuning` conventions)
  - Test effect sets `landing_impact_offset.y` to negative value (camera dips down on landing)
    - Scaled by condition score: light landing = small dip, hard landing = large dip
  - Test `landing_impact_offset` is non-zero immediately after landing event
  - Test `landing_impact_offset` recovers toward `Vector3.ZERO` over subsequent ticks (tested in S_VCamSystem)
  - **Target: 5 tests**
  - Completion note (2026-03-10): Expanded `tests/unit/qb/test_camera_state_system.gd` with landing-rule coverage for event matching, normalized fall-speed scaling, below-threshold reset behavior, and non-landing event isolation.

- [x] **Task 6A3c.2 (Red)**: Write tests for landing impact recovery in S_VCamSystem
  - Add to `tests/unit/ecs/systems/test_vcam_system.gd`
  - Test `landing_impact_offset` is added to evaluated camera position each tick
  - Test when `landing_impact_offset != Vector3.ZERO`: second-order dynamics drive offset back toward zero at `landing_impact_recovery_speed` Hz
  - Test recovery is critically damped (no bouncing — a single smooth dip and return)
  - Test `landing_impact_offset = Vector3.ZERO` produces zero additional offset (no overhead when idle)
  - **Target: 4 tests**
  - Completion note (2026-03-10): Added 4 `S_VCamSystem` tests for offset application, zero-offset passthrough, critically damped recovery, and per-tick offset writeback toward zero.

- [x] **Task 6A3c.3 (Green)**: Implement landing impact
  - Create QB rule `.tres`:
    - Create `resources/qb/camera/cfg_camera_landing_impact_rule.tres`
    - Trigger: `event` mode
    - Condition: `RS_ConditionEventName` matching `EVENT_ENTITY_LANDED`
    - Condition: `RS_ConditionEventPayload` — `field = fall_speed`, `normalize_min = 5.0`, `normalize_max = 30.0`
    - Effect: `RS_EffectSetField` — `component_type = C_CameraStateComponent`, `field = landing_impact_offset`, `operation = set`, `value = Vector3(0, -0.3, 0)` (scaled by condition score — max 30cm dip on hardest landing)
  - Add rule to `S_CameraStateSystem.DEFAULT_RULE_DEFINITIONS`
  - Modify `S_VCamSystem`:
    - Read `C_CameraStateComponent.landing_impact_offset` each tick
    - Add offset to evaluated camera position
    - Drive `landing_impact_offset` toward `Vector3.ZERO` via `U_SecondOrderDynamics3D` at `landing_impact_recovery_speed` Hz (critically damped, r=1.0)
    - Write recovered offset back to component each tick
  - All tests should pass
  - Completion note (2026-03-10): Added `cfg_camera_landing_impact_rule.tres` to camera defaults, extended `RS_EffectSetField` with `vector3` literals + score scaling, event-name prefiltering in `S_CameraStateSystem` event evaluation, and landing-offset apply/recover logic in `S_VCamSystem` using `U_SecondOrderDynamics3D`.

  **Existing infrastructure reused:**
  - `EVENT_ENTITY_LANDED` event (already published by physics with `fall_speed` payload)
  - `RS_ConditionEventName` + `RS_ConditionEventPayload` (existing condition types)
  - `RS_EffectSetField` (existing effect type)
  - `S_CameraStateSystem` event evaluation loop (subscribes to events, evaluates rules)
  - `U_SecondOrderDynamics3D` (Phase 1E — reused for offset recovery)

  **Relationship to existing screen shake:**
  - Screen shake (via `S_ScreenShakePublisherSystem` + `M_VFXManager`) already triggers on landing
  - Landing impact offset is ADDITIVE — it stacks with shake for a compound feel:
    - Shake = high-frequency noise (violent vibration)
    - Impact offset = low-frequency dip and spring-back (gut-punch feel)
  - Both are independently tuneable via their respective resources

---

### Phase 6B: Scene Wiring

- [x] **Task 6B.1**: Wire M_VCamManager to root scene
  - Modify `scenes/root.tscn`: add `M_VCamManager` under `Managers`
  - Modify `scripts/root.gd`: register via `_register_if_exists()`
  - Completion note (2026-03-10): Added `M_VCamManager` to `scenes/root.tscn`, registered `vcam_manager` service in `scripts/root.gd`, and declared `vcam_manager -> {state_store, camera_manager}` service dependencies.

- [x] **Task 6B.2**: Wire S_VCamSystem to gameplay scenes
  - Modify `scenes/templates/tmpl_base_scene.tscn`: add `S_VCamSystem` under `Systems/Core`
  - Modify `scenes/gameplay/gameplay_base.tscn`: add `S_VCamSystem` if not inherited
  - Completion note (2026-03-10): Added `S_VCamSystem` to template and gameplay scene system trees under `Systems/Core` with `execution_priority = 100` so it runs after movement systems and before feedback systems (`tmpl_base_scene`, `gameplay_base`, `gameplay_bar`, `gameplay_alleyway`).

- [x] **Task 6B.3**: Wire C_VCamComponent to camera template
  - Modify `scenes/templates/tmpl_camera.tscn`: add default `C_VCamComponent` with `cfg_default_orbit.tres`
  - Verify template remains backward compatible with `C_CameraStateComponent`
  - Completion note (2026-03-10): Added `C_VCamComponent` to `tmpl_camera.tscn` with `cfg_default_orbit.tres` plus default soft-zone/blend/response resources and `follow_target_entity_id = &"player"`; existing `C_CameraStateComponent` remained intact.

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
  - Dispatch `update_target_validity` and `record_recovery` Redux actions
  - Publish `EVENT_VCAM_RECOVERY` through `U_ECSEventBus` with `{reason, vcam_id}` payload so other systems can react (e.g., `S_GameEventSystem` rules that trigger effects on camera recovery)
  - All tests should pass

---

### Phase 6C: Manual Validation (Desktop Camera Modes)

> Mode-specific manual checks are listed in their respective subtask files.
> See: [vcam-orbit-tasks.md](vcam-orbit-tasks.md), [vcam-fixed-tasks.md](vcam-fixed-tasks.md), [vcam-ots-tasks.md](vcam-ots-tasks.md)

---

## Phase 7: Mobile Drag-Look

**Exit Criteria:** All ~16 mobile tests pass, mobile drag-look feeds `gameplay.look_input`, simultaneous move+look+buttons work, `S_InputSystem` does not clobber touchscreen input

### Phase 7A: UI_MobileControls Look Touch Tracking

- [x] **Task 7A.1 (Red)**: Write tests for mobile look touch
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
  - Completion note (2026-03-15): Expanded `test_mobile_controls.gd` with drag-look coverage for delta emission/consume lifecycle and settings-driven sensitivity/invert behavior.

- [x] **Task 7A.2 (Green)**: Implement look touch tracking
  - Modify `scripts/ui/hud/ui_mobile_controls.gd`
  - Track dedicated `_look_touch_id` separate from joystick and button touches
  - Expose per-frame `look_delta: Vector2`
  - Clear delta after each consumption
  - All tests should pass
  - Completion note (2026-03-15): `UI_MobileControls` now tracks dedicated free-screen look touches (`_look_touch_id`), accumulates per-frame look deltas with settings-driven sensitivity/invert-Y, and exposes `consume_look_delta()` + `is_touch_look_active()`.

---

### Phase 7B: S_TouchscreenSystem Look Dispatch

- [x] **Task 7B.1 (Red)**: Write tests for touchscreen look dispatch
  - Modify `tests/unit/ecs/systems/test_s_touchscreen_system.gd`
  - Test dispatches `U_InputActions.update_look_input(look_delta)` when drag-look active
  - Test applies `look_drag_sensitivity` from persisted touchscreen settings
  - Test applies `invert_look_y` from persisted touchscreen settings
  - Test clears look delta after dispatch (delta-based like mouse)
  - **Target: 4 tests**
  - Completion note (2026-03-15): Added drag-look dispatch tests in `test_s_touchscreen_system.gd` for look dispatch, sensitivity/invert behavior, one-shot delta consumption, and touch-look active lifecycle.

- [x] **Task 7B.2 (Green)**: Implement touchscreen look dispatch
  - Modify `scripts/ecs/systems/s_touchscreen_system.gd`
  - Read `look_delta` from `UI_MobileControls`
  - Apply sensitivity and invert-Y from settings
  - Dispatch via `U_InputActions.update_look_input()`
  - All tests should pass
  - Completion note (2026-03-15): `S_TouchscreenSystem` now consumes `UI_MobileControls` drag-look deltas and dispatches them via `U_InputActions.update_look_input(...)`, with component look-strength updates tied to drag magnitude.

---

### Phase 7B2: Touch Look Active Redux Flag

> **Context:** Touch input gating uses `gameplay.touch_look_active` so `S_InputSystem` can deterministically skip look dispatch when touchscreen drag-look is active, without relying on device-type heuristics.

- [x] **Task 7B2.1**: Add `touch_look_active` to gameplay slice
  - Modify `scripts/resources/state/rs_gameplay_initial_state.gd` (or relevant initial state): add `touch_look_active: bool = false`
  - Add action `U_GameplayActions.set_touch_look_active(active: bool)`
  - Add reducer case in `u_gameplay_reducer.gd`
  - Add selector `U_GameplaySelectors.is_touch_look_active(state) -> bool` (returns `false` when missing)
  - Modify `scripts/state/utils/u_state_slice_manager.gd`: add `touch_look_active` to gameplay `transient_fields` so it never persists through save/load or shell handoff
  - Completion note (2026-03-15): Added gameplay touch-look flag state/action/reducer/selector wiring and marked `touch_look_active` transient in `U_StateSliceManager`.

- [x] **Task 7B2.2**: Dispatch flag from S_TouchscreenSystem
  - Modify `scripts/ecs/systems/s_touchscreen_system.gd`:
    - Dispatch `set_touch_look_active(true)` when drag-look gesture begins
    - Dispatch `set_touch_look_active(false)` when drag-look gesture ends (touch released)
  - Completion note (2026-03-15): `S_TouchscreenSystem` now dispatches `U_GameplayActions.set_touch_look_active(...)` on state transitions via `_dispatch_touch_look_active_if_changed(...)`.

- [x] **Task 7B2.3**: Gate S_InputSystem look dispatch
  - Modify `scripts/ecs/systems/s_input_system.gd`:
    - Read `U_GameplaySelectors.is_touch_look_active(state)` each tick
    - When `true`, skip look input dispatch (touchscreen owns look)
    - When `false`, dispatch look input normally
  - Completion note (2026-03-15): `S_InputSystem` now reads `U_GameplaySelectors.is_touch_look_active(...)` and exits early on touchscreen-owned frames, preventing desktop/gamepad source paths from clobbering touchscreen-owned look/move payloads.

- [x] **Task 7B2.4**: Write tests for touch look flag
  - Test `touch_look_active` defaults to `false`
  - Test `set_touch_look_active(true)` sets flag
  - Test `S_TouchscreenSystem` dispatches flag on drag start/end
  - Test `S_InputSystem` skips look dispatch when `touch_look_active` is `true`
  - Test gameplay slice registration marks `touch_look_active` transient
  - **Target: 5 tests**
  - Completion note (2026-03-15): Added coverage in `test_gameplay_slice_reducers.gd`, `test_state_selectors.gd`, `test_s_touchscreen_system.gd`, `test_input_system.gd`, and `test_m_state_store.gd`.

---

### Phase 7C: S_InputSystem Zero-Clobber Guard

- [x] **Task 7C.1 (Red)**: Write tests for input system touchscreen guard
  - Modify `tests/unit/ecs/systems/test_input_system.gd`
  - Test when active device is touchscreen, `S_InputSystem` does NOT dispatch zero `look_input`
  - Test when active device is touchscreen, `S_InputSystem` does NOT dispatch zero `move_input`
  - Test when active device is keyboard/mouse, `S_InputSystem` dispatches normally
  - Test when active device is gamepad, `S_InputSystem` dispatches normally
  - **Target: 4 tests**
  - Completion note (2026-03-15): Added guard coverage in `test_input_system.gd` for touchscreen no-clobber behavior and touch-look-active preservation.

- [x] **Task 7C.2 (Green)**: Implement input system guard
  - Modify `scripts/ecs/systems/s_input_system.gd`
  - Gate `TouchscreenSource` dispatch when touchscreen is the active device type
  - All tests should pass
  - Completion note (2026-03-15): `S_InputSystem` now exits early when `active_device == TOUCHSCREEN`, keeping `S_TouchscreenSystem` as the sole owner of touch-driven move/look/button dispatch.

**Validation run (2026-03-15):**
- `tests/unit/ui/test_mobile_controls.gd` (`14/14` passing)
- `tests/unit/ecs/systems/test_s_touchscreen_system.gd` (`7/7` passing)
- `tests/unit/ecs/systems/test_input_system.gd` (`13/13` passing)
- `tests/unit/state/test_gameplay_slice_reducers.gd` (`10/10` passing)
- `tests/unit/state/test_state_selectors.gd` (`7/7` passing)
- `tests/unit/state/test_m_state_store.gd` (`29/29` passing)
- `tests/unit/state/test_state_persistence.gd` (`9/9` passing)
- `tests/integration/state/test_state_persistence.gd` (`2/2` passing)
- `tests/unit/state/test_action_registry.gd` (`14/14` passing)
- `tests/unit/state/test_u_gameplay_actions.gd` (`7/7` passing)
- `tests/unit/ecs/systems/test_vcam_system.gd` (`94/94` passing)
- `tests/unit/style/test_style_enforcement.gd` remains at known pre-existing HUD inline-theme failure (`16/17`, `scenes/ui/hud/ui_hud_overlay.tscn`)

---

### Phase 7D: Manual Validation (Mobile Drag-Look + Touch Settings)

Mode-specific mobile checks are tracked in their respective subtask files:
- Orbit mobile (MT-05..08): [vcam-orbit-tasks.md](vcam-orbit-tasks.md)
- OTS mobile (MT-16, 17): [vcam-ots-tasks.md](vcam-ots-tasks.md)

Settings checks (mode-agnostic):

- [ ] **MT-35**: Drag-look sensitivity slider in touchscreen settings changes rotation speed
- [ ] **MT-36**: Invert-Y toggle in touchscreen settings inverts vertical drag direction
- [ ] **MT-37**: Drag-look settings persist after quit and relaunch

---

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
  - Test `set_active_vcam()` publishes `EVENT_VCAM_BLEND_STARTED` through `U_ECSEventBus` with `{from_vcam_id, to_vcam_id, duration}` payload
  - Test `is_blending()` returns true during active blend
  - Test `get_blend_progress()` advances over time
  - Test blend completes when progress reaches 1.0
  - Test blend completion publishes `EVENT_VCAM_BLEND_COMPLETED` through `U_ECSEventBus` with `{vcam_id}` payload
  - Test `get_previous_vcam_id()` returns outgoing vcam during blend
  - Test `submit_evaluated_camera()` stores both active and outgoing results during blend
  - Test blend result is computed from two live results (not frozen transforms)
  - Test `set_active_vcam()` with `blend_duration = 0.0` cuts immediately (no blend)
  - **Target: 10 tests**

- [ ] **Task 9B.2 (Green)**: Implement live blend in M_VCamManager
  - Extend manager with blend state tracking, elapsed time, blend evaluation
  - Process blend progression in `_physics_process`
  - Consume only the latest result submitted for the active physics frame; do not rely on root-vs-gameplay `_physics_process` tree order
  - Publish `EVENT_VCAM_BLEND_STARTED` on blend start, `EVENT_VCAM_BLEND_COMPLETED` on completion
  - All tests should pass

---

### Phase 9C: Shake-Safe Camera-Manager Integration

> **Note:** `apply_main_camera_transform()` and `is_blend_active()` are **new API — Phase 9**. They do not exist on `M_CameraManager` today.

- [ ] **Task 9C.1 (Red)**: Write tests for camera-manager API extension
  - Modify `tests/integration/camera_system/test_camera_manager.gd`
  - Test `apply_main_camera_transform(xform)` (new API) updates camera base pose without breaking shake offset
  - Test `is_blend_active()` (new API) returns true during scene-transition blends
  - Test `is_blend_active()` (new API) returns false when no transition blend active
  - **Target: 3 tests**

- [ ] **Task 9C.2 (Green)**: Implement camera-manager API (new methods)
  - Modify `scripts/interfaces/i_camera_manager.gd`: add method signatures for `apply_main_camera_transform()` and `is_blend_active()`
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
  - Test vCam does not apply stale previous-frame results when a current-frame submission is missing
  - **Target: 5 tests**

- [ ] **Task 9D.2 (Green)**: Implement vCam apply flow in M_VCamManager
  - Route final blended/unblended result through `camera_manager.apply_main_camera_transform()`
  - Set `C_CameraStateComponent.base_fov` (use `set_base_fov()` setter)
  - Consume the current-frame `S_VCamSystem` handoff rather than depending on root scene-tree order
  - All tests should pass

- [ ] **Task 9D.3**: Enrich `S_CameraStateSystem` QB rule context with vCam state
  - Modify `scripts/ecs/systems/s_camera_state_system.gd` `_build_camera_context()` method
  - Add `vcam_active_mode` from `U_VCamSelectors.get_active_mode(state)`
  - Add `vcam_is_blending` from `U_VCamSelectors.is_blending(state)`
  - Add `vcam_active_vcam_id` from `U_VCamSelectors.get_active_vcam_id(state)`
  - This enables QB camera rules to condition on vCam state (e.g., "reduce FOV zone effect in OTS mode", "suppress shake during blends")
  - Rules use standard `RS_ConditionContextField` to read these fields — no vCam-specific condition types needed
  - Write regression tests verifying existing camera rules still pass with enriched context

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
- OTS blend (MT-20, 33): [vcam-ots-tasks.md](vcam-ots-tasks.md)

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

- [x] **Task 10A.0 (Pre-requisite)**: Inventory occludable geometry in gameplay scenes
  - Before implementing collision detection, audit all gameplay scenes (`scenes/gameplay/`, `scenes/prefabs/`) for geometry that should occlude camera-to-target line of sight
  - Document which `MeshInstance3D` and `CSGShape3D` nodes need layer 6 (`vcam_occludable`) migration
  - Identify any geometry that should NOT be on the occlusion layer (triggers, zones, small detail props)
  - This audit prevents discovering missing occluder assignments late in Phase 10A.3
  - Completion note (March 15, 2026): Completed scripted scene audit for collision-capable occluder candidates (`CSG*` with `use_collision=true`, `StaticBody3D`) and captured 143 missing layer-6 assignments across gameplay/prefab scenes before migration.

- [x] **Task 10A.1 (Red)**: Write tests for collision detector
  - Create `tests/unit/managers/helpers/test_vcam_collision_detector.gd`
  - Test empty result when nothing between camera and target
  - Test MeshInstance3D occluder detected on layer 6
  - Test CSGShape3D occluder detected on layer 6
  - Test collider on wrong physics layer is ignored
  - Test invalid or freed collider skipped safely (no crash)
  - Test multiple occluders returns all of them
  - **Target: 6 tests**
  - Completion note (March 15, 2026): Added `test_vcam_collision_detector.gd` with 6 Red assertions covering empty rays, mesh/CSG occluder detection, wrong-layer filtering, freed-collider safety, and multi-hit aggregation.

- [x] **Task 10A.2 (Green)**: Implement U_VCamCollisionDetector
  - Create `scripts/managers/helpers/u_vcam_collision_detector.gd`
  - Modify `project.godot`: name physics layer 6 as `vcam_occludable`
  - Implement `static func detect_occluders(space_state, from, to, collision_mask) -> Array`
  - All tests should pass
  - Completion note (March 15, 2026): Added `U_VCamCollisionDetector.detect_occluders(...)` with iterative ray-hit collection, layer-mask validation, geometry-node resolution (`StaticBody3D` collider -> `GeometryInstance3D` descendant), and freed-collider guards; set `project.godot` layer name `3d_physics/layer_6 = "vcam_occludable"`.
  - Validation note (March 15, 2026): `tests/unit/managers/helpers/test_vcam_collision_detector.gd` (`6/6`) and `tests/unit/style/test_style_enforcement.gd` (`17/17`) pass.

- [x] **Task 10A.3**: Roll out layer-6 occluder tagging in authored scenes
  - Modify `scenes/gameplay/gameplay_base.tscn` and any gameplay/prefab scenes used in vCam flows where geometry should occlude camera line-of-sight
  - Ensure only camera-blocking geometry uses layer 6 `vcam_occludable` (do not move trigger/zone-only nodes onto this layer)
  - Re-run scene/style gates after scene edits
  - Completion note (March 15, 2026): Applied `collision_layer = 33` migration for audited occluders in `scenes/gameplay/gameplay_base.tscn`, `scenes/gameplay/gameplay_exterior.tscn`, `scenes/gameplay/gameplay_interior_base.tscn`, `scenes/gameplay/gameplay_interior_house.tscn`, `scenes/gameplay/gameplay_interior_a.tscn`, `scenes/prefabs/prefab_alleyway.tscn`, and `scenes/prefabs/prefab_bar.tscn`; post-migration audit reports `missing_count=0`.
  - Validation note (March 15, 2026): `tests/unit/style/test_style_enforcement.gd` remains at the known pre-existing HUD inline-theme failure (`16/17`, `scenes/ui/hud/ui_hud_overlay.tscn`) with no new scene organization failures.

---

### Phase 10B: U_VCamSilhouetteHelper

> **Visual intent:** Solid-color silhouette visible through occluding geometry. Exact shader implementation determined during Phase 10.

- [x] **Task 10B.1 (Red)**: Write tests for silhouette helper
  - Create `tests/unit/managers/helpers/test_vcam_silhouette_helper.gd`
  - Test `apply_silhouette()` sets shader override on `GeometryInstance3D`
  - Test `apply_silhouette()` preserves original material state for later restoration
  - Test `remove_silhouette()` restores original material override
  - Test `remove_all_silhouettes()` cleans up all tracked overrides
  - Test `get_active_count()` returns correct count
  - Test applying silhouette to freed node is safely handled
  - **Target: 6 tests**
  - Completion note (March 15, 2026): Added `test_vcam_silhouette_helper.gd` with 6 Red assertions covering apply/restore lifecycle, tracked-count observability, and freed-node safety handling.

- [x] **Task 10B.2 (Green)**: Implement U_VCamSilhouetteHelper
  - Create `scripts/managers/helpers/u_vcam_silhouette_helper.gd`
  - Create `assets/shaders/sh_vcam_silhouette_shader.gdshader`
  - Store original override state, apply shader override, restore on removal
  - All tests should pass
  - Completion note (March 15, 2026): Added `U_VCamSilhouetteHelper` with tracked weakref entries, idempotent silhouette application, deterministic material restoration (`remove_silhouette`/`remove_all_silhouettes`), and safe no-op behavior for invalid/freed targets; added `sh_vcam_silhouette_shader.gdshader` for silhouette material overrides.
  - Validation note (March 15, 2026): `tests/unit/managers/helpers/test_vcam_silhouette_helper.gd` (`6/6`) and `tests/unit/style/test_style_enforcement.gd` (`17/17`) pass.

---

### Phase 10B2: VFX Manager Silhouette Routing

> **Context:** Silhouette rendering routes through `M_VFXManager` (detection stays in vCam). This follows the existing VFX event-request pattern (`U_ScreenShake`, damage flash, etc.) so silhouette lifecycle inherits player gating and transition blocking.

- [ ] **Task 10B2.1**: Add `EVENT_SILHOUETTE_UPDATE_REQUEST` event constant
  - Modify `scripts/events/ecs/u_ecs_event_names.gd`: add `EVENT_SILHOUETTE_UPDATE_REQUEST := &"silhouette_update_request"`
  - Payload: `{entity_id: StringName, occluders: Array[GeometryInstance3D], enabled: bool}`

- [ ] **Task 10B2.2**: Publish silhouette requests from M_VCamManager
  - Modify `scripts/managers/m_vcam_manager.gd`:
    - After occlusion detection each tick, publish `EVENT_SILHOUETTE_UPDATE_REQUEST` through `U_ECSEventBus` with the current occluder set plus `entity_id`
    - Do NOT apply silhouettes directly — delegate to VFX manager

- [ ] **Task 10B2.3**: Subscribe and delegate in M_VFXManager
  - Modify `scripts/managers/m_vfx_manager.gd`:
    - Subscribe to `EVENT_SILHOUETTE_UPDATE_REQUEST`
    - Delegate to `U_VCamSilhouetteHelper` for actual material override application/removal
    - Apply standard player gating (`_is_player_entity()`) and transition blocking (`_is_transition_blocked()`) before processing; `entity_id` in the payload is what makes existing player gating work

- [ ] **Task 10B2.4**: Verify routing
  - Test silhouette updates flow through VFX manager (not applied directly by vCam manager)
  - Test player gating applies to silhouette requests
  - Test transition blocking suppresses silhouette updates during scene transitions
  - **Target: 3 tests**

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
  - Extend `m_vcam_manager.gd`: detect occluders in the active gameplay camera `World3D`, consult VFX selector, publish `EVENT_SILHOUETTE_UPDATE_REQUEST` (silhouette application is routed through `M_VFXManager` via Phase 10B2, not applied directly)
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
  - Test OTS vCam evaluates and submits results
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
  - Test drag-look feeds OTS camera through gameplay.look_input
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
  - [ ] **MT-50**: Heading continuity after orbit → OTS switch (player keeps facing same direction)
  - [ ] **MT-51**: Heading continuity after OTS → orbit switch
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

- [ ] **Task 13.6b**: QB-driven camera feel QA (manual)
  - [ ] **MT-88**: FOV breathing while sprinting: FOV widens subtly (e.g. 75 → ~85) as speed increases
  - [ ] **MT-89**: FOV breathing while stationary: FOV returns to base value smoothly (existing `fov_blend_speed` handles transition)
  - [ ] **MT-90**: FOV breathing response curve: FOV ramps gradually at walk speed, aggressively at sprint speed (non-linear curve)
  - [ ] **MT-91**: Landing impact dip: camera dips briefly on hard landing, springs back via second-order dynamics
  - [ ] **MT-92**: Landing impact scales with fall speed: light landing = barely noticeable dip, hard landing = pronounced dip
  - [ ] **MT-93**: Landing impact + shake coexistence: both landing dip (low-frequency) and shake (high-frequency) visible simultaneously, compound feel
  - [ ] **MT-94**: Landing impact on soft landing (below threshold): no camera dip (condition score = 0)

- [ ] **Task 13.7**: Performance regression checks (manual)
  - [ ] **MT-56**: Long scene with many potential occluders: no frame-pacing spikes from occlusion pass
  - [ ] **MT-57**: Rapid switching stress test: no allocation spikes from blend/silhouette churn
  - [ ] **MT-58**: Steady-state camera (no switch, no occlusion change): verify no per-frame dictionary allocations in profiler
  - [ ] **MT-80**: Second-order dynamics per-tick cost: verify no measurable frame time increase vs null response (dynamics are 6 multiplies + 4 adds per axis per tick)

---

## Test Directory Convention

vCam tests follow the existing project test layout:

```text
tests/unit/vcam/              — unit tests for vCam-specific logic (mirrors production layout)
tests/unit/vcam/resources/    — test resource instances (.tres) used by vCam unit tests
tests/integration/vcam/       — integration tests (full pipeline, cross-system)
```

Unit tests for shared infrastructure (state, ECS components/systems, managers) live in their existing directories (`tests/unit/state/`, `tests/unit/ecs/`, `tests/unit/managers/`) alongside other feature tests. The `tests/unit/vcam/` directory is for vCam-only helpers and resources that don't fit an existing category.

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
- [ ] Verify OTS and orbit look consume the existing input pipeline instead of polling raw input directly
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
- [ ] Verify FOV breathing uses existing QB rule infrastructure (`RS_ConditionComponentField` + `RS_EffectSetField` + `S_CameraStateSystem`)
- [ ] Verify FOV breathing does NOT bypass `S_CameraStateSystem._resolve_target_fov()` — it adds `speed_fov_bonus`, not writes `camera.fov` directly
- [ ] Verify landing impact offset is additive with screen shake (both apply simultaneously)
- [ ] Verify landing impact recovery uses `U_SecondOrderDynamics3D` (not simple lerp) for spring-like settling
- [ ] Verify landing impact rule reuses existing `EVENT_ENTITY_LANDED` event (does NOT create a new event)

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
- [OTS Tasks](vcam-ots-tasks.md)
- [Plan](vcam-manager-plan.md)
- [Overview](vcam-manager-overview.md)
- [PRD](vcam-manager-prd.md)
- [Continuation Prompt](vcam-manager-continuation-prompt.md)
