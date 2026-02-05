# Input Manager Task Checklist

**Progress:** 100% Complete

**Note:** Remaining tasks (6.7, 6.13, Phase 7) deferred or absorbed into UI Manager. See `docs/ui_manager/ui-manager-tasks.md` for continuation.

**Recent Updates (2025-11-20):**
- Phase 6 Tasks 6.0-6.5 complete: VirtualJoystick + VirtualButtons + MobileControls scene added
- MobileControls uses profile-driven button metadata, Tween-based opacity fade, and pause/transition hide rules
- Physical mobile device available for QA; `--emulate-mobile` kept only as a desktop smoke fallback
- New UI tests: `test_mobile_controls.gd` covering visibility, metadata instantiation, custom positions, and tween fade

## Phase 0: Research & Architecture Validation

- [x] Task 0.1: Run Baseline Tests - FR-128 *(2025-11-06, GUT suite green)*
- [x] Task 0.2: Review Project Patterns *(2025-11-06, patterns logged in research)*
- [x] Task 0.3: Prototype Gamepad Input Detection (TDD) - FR-033, FR-034, FR-035 *(tests/prototypes/prototype_gamepad.gd + tests/unit/prototypes/test_prototype_gamepad.gd)*
- [x] Task 0.4: Prototype Touchscreen Input (TDD) - FR-046, FR-047, FR-048 *(tests/prototypes/prototype_touch.gd + tests/unit/prototypes/test_prototype_touch.gd)*
- [x] Task 0.5: Measure Baseline Input Latency - FR-116 *(tests/prototypes/benchmark_input_latency.gd + tests/unit/prototypes/test_benchmark_input_latency.gd)*
- [x] Task 0.6: Validate InputMap Modification Safety (TDD) - FR-015, FR-017 *(tests/prototypes/prototype_inputmap_safety.gd + tests/unit/prototypes/test_prototype_inputmap_safety.gd)*
- [x] Task 0.7: Design File Structure (Resources in scripts/ecs/resources/, NO scripts/input/) *(docs/input_manager/general/input-manager-file-structure.md)*
- [x] Task 0.8: Create Research Documentation *(docs/input_manager/general/input-manager-research.md)*
- [x] Task 0.9: Integration Point Validation (TDD) - Test manager discovery, state dispatch, ECS registration *(tests/unit/integration/test_input_manager_integration_points.gd)*

## Phase 1: Enhanced Keyboard/Mouse + State Integration

- [x] Task 1.1: Create Input Actions (TDD) - FR-075, FR-076 *(2025-11-07, scripts/state/actions/u_input_actions.gd + tests/unit/input_manager/test_u_input_actions.gd)*
- [x] Task 1.2: Create Input Selectors (TDD) - FR-077 *(2025-11-07, scripts/state/selectors/u_input_selectors.gd + tests/unit/input_manager/test_u_input_selectors.gd)*
- [x] Task 1.3: Extend Gameplay Reducer for Input Actions (TDD) - FR-076 *(2025-11-07, scripts/state/reducers/u_input_reducer.gd + u_gameplay_reducer.gd + rs_gameplay_initial_state.gd + tests/unit/input_manager/test_u_input_reducer.gd)*
- [x] Task 1.4: Create Settings Reducer for Input Settings (TDD) - FR-076, FR-078 *(2025-11-06, added RS_SettingsInitialState + settings slice reducer)*
- [x] Task 1.5: Enhance S_InputSystem with State Dispatch - FR-006 *(2025-11-06, cached store dispatch + new unit coverage)*
- [x] Task 1.6: Add Mouse Sensitivity Setting - FR-100 *(2025-11-06, settings-driven sensitivity w/ tests)*
- [x] Task 1.7: Integration Testing
  - Notes (2025-11-07): Verified end-to-end in `tests/unit/integration/test_input_manager_integration_points.gd`.
    - Inputs reset across StateHandoff (transient gameplay input fields), while save/load persists full gameplay slice.
    - Batched state signals emit once per physics frame; dispatch overhead improved via reducer routing and unchanged-state short-circuiting.
    - Related suites green: state unit, scene manager persistence, state performance.

## Phase 2: Input Profiles

- [x] Task 2.1: Create RS_InputProfile Resource (TDD) - FR-011, FR-012
  - Notes (2025-11-07): Implemented resource and unit tests:
    - Resource: `scripts/input/resources/rs_input_profile.gd`
    - Tests: `tests/unit/resources/test_rs_input_profile.gd`
- [x] Task 2.2: Create Default Input Profiles - FR-012
  - Notes (2025-11-07): Added built-in profiles under `resources/input/profiles/`:
    - `cfg_default_keyboard.tres`, `cfg_alternate_keyboard.tres`, `cfg_accessibility_keyboard.tres`
    - Profiles include metadata; action mappings will be expanded alongside manager TDD.
- [x] Task 2.3: Create M_InputProfileManager (TDD) - FR-014, FR-015, FR-089
  - Notes (2025-11-07): Scaffolded manager, wired to root, and added unit tests:
    - Manager: `scripts/managers/m_input_profile_manager.gd`
    - Wiring: `scenes/root.tscn`
    - Tests: `tests/unit/managers/test_m_input_profile_manager.gd`
- [x] Task 2.4: Add M_InputProfileManager to Root Scene - FR-089
  - Notes (2025-11-07): `M_InputProfileManager` node added under `Managers` in `scenes/root.tscn` and joins `input_profile_manager` group at runtime.
- [x] Task 2.5: Create Profile Selection UI - FR-014
  - Notes (2025-11-07): Added `scenes/ui/input_profile_selector.tscn` with `scripts/ui/input_profile_selector.gd`. Lists available profiles and calls manager `switch_profile()`.
- [x] Task 2.6: Integration Testing - FR-133
  - Notes (2025-11-07): Added `tests/unit/integration/test_profile_switching_flow.gd` to validate pause-gated switching, signal emission, and settings slice update.

- [x] Task 2.7: Wire Profile Selector Overlay - FR-014
  - Notes (2025-11-07): Registered `input_profile_selector` in Scene Registry and wired into Pause Menu.
    - Scene registry entry: `resources/scene_registry/cfg_ui_input_profile_selector_entry.tres`
    - Pause Menu: Added button and handler to open overlay with return.
    - Overlay scene: `scenes/ui/input_profile_selector.tscn` with script `scripts/ui/input_profile_selector.gd`
    - Integration test: `tests/unit/integration/test_input_profile_selector_overlay.gd` (push pause → open selector → verify overlay active)

- [x] Task 2.8: Manual QA — Open Profile Selector from Pause Menu
  - Steps: Run `scenes/root.tscn`, press ESC, click "Input Profiles".
  - Expected: Overlay appears with dropdown listing profiles.

- [x] Task 2.9: Manual QA — Switch to Alternate (Arrows Only)
  - Steps: Select "Alternate (Keyboard/Mouse)", click Apply, close overlays.
  - Expected: Arrow keys move; WASD no longer moves; Space=Jump, Shift=Sprint.

- [x] Task 2.10: Manual QA — Switch back to Default (WASD Only)
  - Steps: Open selector, choose "Default (Keyboard/Mouse)", Apply.
  - Expected: WASD move; Arrow keys no longer move; Space=Jump, Shift=Sprint.

- [x] Task 2.11: Manual QA — Overlay Preselects Active Profile
  - Steps: Reopen selector after switching.
  - Expected: Dropdown preselects the currently active profile.

- [x] Task 2.12: Manual QA — Accessibility Profile Applies
  - Steps: Apply "Accessibility (Keyboard/Mouse)", resume gameplay.
  - Expected: WASD/Space/Shift remain; sprint toggle and jump buffer will be wired in later phases.

## Phase 3: Gamepad Support

- [x] Task 3.1: Create RS_GamepadSettings resource (TDD) - FR-036, FR-037, FR-038
  - Notes (2025-11-07): Added `scripts/input/resources/rs_gamepad_settings.gd` plus default tuning at `resources/input/gamepad_settings/cfg_default_gamepad_settings.tres`; exercised via `tests/unit/resources/test_rs_gamepad_settings.gd`.
- [x] Task 3.2: Create C_GamepadComponent (TDD) - FR-039, FR-084
  - Notes (2025-11-07): Implemented `scripts/ecs/components/c_gamepad_component.gd` with stick state, deadzone helpers, vibration callables, and dictionary-based settings application. Covered by `tests/unit/ecs/components/test_c_gamepad_component.gd`.
- [x] Task 3.3: Extend S_InputSystem for Gamepad Input (TDD) - FR-034, FR-035, FR-036, FR-037
  - Notes (2025-11-07): `scripts/ecs/systems/s_input_system.gd` now reads joypad axes, dispatches gamepad state through `U_InputActions`, and respects per-stick deadzones. Updated coverage in `tests/unit/ecs/systems/test_input_system.gd` + reducer/action suites.
- [x] Task 3.4: Implement Gamepad Vibration Support (TDD) - FR-038, FR-045
  - Notes (2025-11-07): Added `scripts/ecs/systems/s_gamepad_vibration_system.gd`, tied into `U_ECSEventBus` + gameplay actions. Validated by `tests/unit/ecs/systems/test_gamepad_vibration_system.gd` and integration flow `tests/unit/integration/test_gamepad_vibration_flow.gd`.
- [x] Task 3.5: Handle Gamepad Connect/Disconnect (TDD) - FR-033, FR-040, FR-041, FR-042
  - Notes (2025-11-07): Hot-plug + active-device tracking lives in `S_InputSystem` with new actions (`gamepad_connected`, `device_changed`, `gamepad_disconnected`) and reducer assertions (`tests/unit/input_manager/test_u_input_actions.gd`, `test_u_input_reducer.gd`).
- [x] Task 3.6: Add Gamepad Settings UI - FR-036, FR-038
  - Notes (2025-11-07): Created `scenes/ui/gamepad_settings_overlay.tscn`, `scripts/ui/gamepad_settings_overlay.gd`, and `scripts/ui/gamepad_stick_preview.gd`; overlay wired via Scene Registry + Pause Menu CTA. Verified with `tests/unit/ui/test_gamepad_settings_overlay.gd`.
- [x] Task 3.7: Integration Testing - FR-133
  - Notes (2025-11-07): Added vibration + hot-plug end-to-end tests (`tests/unit/integration/test_gamepad_vibration_flow.gd`) and expanded ECS/unit coverage. Suites run headless with `--log-file` to avoid log rotation crashes.

- _Manual QA pending (2025-11-07): Physical controller pass has not been performed yet; keep the following scenarios unchecked until verified._

- [x] Task 3.8: Manual QA — Basic Gamepad Input
  - Steps: Connect gamepad, run `scenes/root.tscn`, press ESC to unpause
  - Expected: Left stick moves player, right stick rotates camera (if implemented)

- [x] Task 3.9: Manual QA — Device Switching (Keyboard → Gamepad)
  - Steps: Start with WASD movement, then touch gamepad left stick
  - Expected: Input switches to gamepad seamlessly, WASD stops working until keyboard pressed again

- [x] Task 3.10: Manual QA — Device Switching (Gamepad → Keyboard)
  - Steps: Start with gamepad movement, then press WASD keys
  - Expected: Input switches to keyboard, gamepad stick stops working until stick moved again

- [x] Task 3.11: Manual QA — Multi-Gamepad Switching
  - Steps: Connect 2+ gamepads, move left stick on gamepad 0, then move left stick on gamepad 1
  - Expected: Last-used gamepad controls player (switches from gamepad 0 to gamepad 1)

- [x] Task 3.12: Manual QA — Hot-Plug Connect
  - Steps: Start game with no gamepad, connect gamepad mid-gameplay
  - Expected: Gamepad detected, device_id assigned, gamepad input works immediately

- [x] Task 3.13: Manual QA — Hot-Plug Disconnect
  - Steps: Start with active gamepad, disconnect controller mid-gameplay
  - Expected: Input falls back to keyboard, no crashes, player can continue with WASD

- [x] Task 3.14: Manual QA — Deadzone Filtering (Stick Drift)
  - Steps: Open Gamepad Settings, observe stick visualization with controller at rest
  - Expected: Stick circles show raw position near center, filtered position is (0,0) if within deadzone

- [x] Task 3.15: Manual QA — Deadzone Tuning
  - Steps: Adjust left stick deadzone slider from 0.0 to 1.0, watch live preview
  - Expected: Deadzone ring grows/shrinks, stick position turns red inside deadzone, green outside

- [x] Task 3.16: Manual QA — Vibration (Landing)
  - Steps: Jump and land on ground with gamepad connected, vibration enabled
  - Expected: Light rumble on landing (weak=0.2, strong=0.1, 100ms duration)

- [x] Task 3.17: Manual QA — Vibration (Damage)
  - Steps: Take damage from hazard with gamepad connected
  - Expected: Medium rumble (weak=0.5, strong=0.3, 200ms duration)

- [x] Task 3.18: Manual QA — Vibration (Death)
  - Steps: Die with gamepad connected
  - Expected: Heavy rumble (weak=0.8, strong=0.6, 400ms duration)

- [x] Task 3.19: Manual QA — Vibration Toggle Off
  - Steps: Open Gamepad Settings, disable vibration, take damage/land/die
  - Expected: No vibration occurs, gameplay continues normally

- [x] Task 3.20: Manual QA — Settings UI (Apply)
  - Steps: Open Gamepad Settings, adjust deadzones + vibration, click Apply
  - Expected: Settings saved to state store, overlay closes, settings persist after reopening

- [x] Task 3.21: Manual QA — Settings UI (Cancel)
  - Steps: Open Gamepad Settings, adjust deadzones, click Cancel
  - Expected: Changes discarded, overlay closes, settings unchanged when reopened

- [x] Task 3.22: Manual QA — Settings UI (Live Preview)
  - Steps: Open Gamepad Settings, move gamepad sticks while watching visualization
  - Expected: Stick circles update in real-time (60 FPS), show raw position accurately

- [x] Task 3.24: Manual QA — Settings Persistence
  - Steps: Adjust deadzones, apply, close game, restart
  - Expected: Custom deadzone values loaded from settings on restart

## Phase 4: Device Auto-Detection + Button Prompts

- [x] Task 4.1: Create M_InputDeviceManager (TDD) - FR-057, FR-058, FR-059, FR-060, FR-090
  - Notes (2025-11-10): Implemented device manager with auto-detection for keyboard/mouse, gamepad, and touchscreen inputs.
    - Manager: `scripts/managers/m_input_device_manager.gd`
    - Tests: `tests/unit/managers/test_m_input_device_manager.gd`
    - Wiring: Added to `scenes/root.tscn` under `Managers` (joins `input_device_manager` group)
    - Features: Device switching on input activity, gamepad hot-plug handling, last-used device tracking, state store integration
- [x] Task 4.2: Implement Device Detection Logic (TDD) - FR-058, FR-060, FR-063, FR-064
  - Notes (2025-11-10): Device detection logic implemented in `M_InputDeviceManager._input()` and `_unhandled_input()`.
    - Keyboard/mouse: Detects InputEventKey (non-echo), InputEventMouseButton (pressed), InputEventMouseMotion (with movement)
    - Gamepad: Detects InputEventJoypadButton (pressed), InputEventJoypadMotion (above DEVICE_SWITCH_DEADZONE)
    - Touchscreen: Detects InputEventScreenTouch (pressed), InputEventScreenDrag
    - Hot-plug: Listens to `Input.joy_connection_changed` signal, updates device state on connect/disconnect
    - State dispatch: Emits `device_changed` signal and dispatches `U_InputActions.device_changed()` to state store
- [x] Task 4.3: Create U_ButtonPromptRegistry (TDD) - FR-066, FR-067, FR-068
  - Notes (2025-11-10): Static registry utility for mapping actions to button prompt icons and labels.
    - Utility: `scripts/ui/u_button_prompt_registry.gd`
    - Tests: `tests/unit/input_manager/test_u_button_prompt_registry.gd`
    - Features: Lazy texture loading/caching, action→texture path mapping per device type, fallback label generation from InputMap, texture path label derivation
    - Registered actions: interact, jump, sprint, pause, move_forward/backward/left/right, toggle_inventory
- [x] Task 4.4: Create Button Prompt Assets - FR-067
  - Notes (2025-11-10): Added Kenney Input Prompts (CC0) to `resources/button_prompts/`.
    - Keyboard: key_w.png, key_a.png, key_s.png, key_d.png, key_space.png, key_shift.png, key_e.png, key_escape.png
    - Gamepad: button_south.png, button_east.png, button_west.png, button_north.png, button_start.png, button_select.png, button_ls.png, button_rs.png, button_lb.png, button_rb.png, button_lt.png, button_rt.png, dpad_up/down/left/right.png
    - License: `resources/button_prompts/LICENSE_Kenney_Input_Prompts.txt`
    - Import settings: Configured for UI usage (64x64 PNG, mipmaps disabled)
- [x] Task 4.5: Integrate Button Prompts with HUD - FR-069, FR-070
  - Notes (2025-11-10): Created reusable ButtonPrompt component and integrated with HUD.
    - Component: `scripts/ui/button_prompt.gd` + `scenes/ui/button_prompt.tscn`
    - HUD integration: `scripts/ui/hud_controller.gd` + `scenes/ui/hud_overlay.tscn`
    - Features: Auto-updates on device change, shows icon + text, falls back to text-only if icon missing
    - Tests: `tests/unit/ui/test_button_prompt.gd`, `tests/unit/ui/test_hud_button_prompts.gd`
    - Behavior: Listens to `M_InputDeviceManager.device_changed` signal, refreshes prompt texture/label dynamically
- [x] Task 4.6: Add M_InputDeviceManager to Root Scene - FR-090
  - Notes (2025-11-10): `M_InputDeviceManager` node added to `scenes/root.tscn` under `Managers` container.
    - Process mode: `PROCESS_MODE_ALWAYS` to track device changes even when paused
    - Group membership: Joins `input_device_manager` group on `_ready()` for discovery via `get_tree().get_first_node_in_group()`
- [x] Task 4.7: Integration Testing - FR-134
  - Notes (2025-11-10): Added end-to-end integration test for button prompt flow.
    - Integration test: `tests/unit/integration/test_button_prompt_flow.gd`
    - Coverage: Device switching (keyboard→gamepad→keyboard), prompt visibility on interact event, prompt auto-hide, HUD component integration
    - Verified: ButtonPrompt component updates texture and label when device changes, falls back to text-only when icon unavailable

## Phase 5: Rebinding System + Persistence

- [x] Task 5.1: Create RS_RebindSettings resource (TDD) - FR-022
  - Notes (2025-11-11): Added `scripts/input/resources/rs_rebind_settings.gd`, default settings resource at `resources/input/rebind_settings/cfg_default_rebind_settings.tres`, and unit coverage in `tests/unit/resources/test_rs_rebind_settings.gd`.
- [x] Task 5.2: Create U_InputRebindUtils (TDD) - FR-021, FR-023, FR-027
  - Notes (2025-11-11): Implemented `scripts/utils/input/u_input_rebind_utils.gd` for validation, conflict detection, InputMap/profile rebinding, and event serialization. Added unit tests at `tests/unit/utils/test_u_input_rebind_utils.gd`.
- [x] Task 5.3: Create Rebinding UI - FR-021, FR-024, FR-025, FR-026
  - Notes (2025-11-11): Added `scenes/ui/input_rebinding_overlay.tscn` with `scripts/ui/input_rebinding_overlay.gd`, conflict/error dialogs, and action list rendering powered by `U_InputRebindUtils`. Automated UI coverage lives at `tests/unit/ui/test_input_rebinding_overlay.gd`.
- [x] Task 5.4: Implement Input Settings Persistence (TDD) - FR-094, FR-095, FR-096, FR-102, FR-103
  - Notes (2025-11-11): Added `scripts/utils/input/u_input_serialization.gd`, persistence hooks in `scripts/managers/m_input_profile_manager.gd`, new bulk-load action in `scripts/state/actions/u_input_actions.gd`, reducer merge logic, and unit coverage in `tests/unit/managers/test_m_input_profile_manager.gd`.
- [x] Task 5.5: Handle Custom Bindings Load/Save (TDD) - FR-029, FR-098
  - Notes (2025-11-12): `M_InputProfileManager.load_custom_bindings()` now resolves saved or fallback profiles and reapplies pending bindings before clearing cache. Added explicit save payload assertions in `tests/unit/managers/test_m_input_profile_manager.gd`; new coverage validates reload path and JSON serialization includes `custom_bindings`.
- [x] Task 5.6: Implement Reset to Default (TDD) - FR-030
  - Notes (2025-11-12): Added Reset button to `input_rebinding_overlay` wiring through `M_InputProfileManager.reset_to_defaults()`. Manager reorders reset flow to restore profile bindings before emitting `bindings_reset`, clears custom caches, dispatches `reset_bindings`, and saves. Coverage updates in `tests/unit/managers/test_m_input_profile_manager.gd` and `tests/unit/ui/test_input_rebinding_overlay.gd` verify InputMap restoration, store merge, and UI status messaging.
- [x] Task 5.7: Implement Multi-Event Binding Support (TDD) - FR-031
  - Notes (2025-11-12): Overlay exposes Add vs Replace flows; `U_InputRebindUtils.rebind_action()` supports append mode and dedupes InputMap/profile, while reducer + manager caches persist multiple bindings. Coverage added via `tests/unit/ui/test_input_rebinding_overlay.gd`, `tests/unit/utils/test_u_input_rebind_utils.gd`, and manager cache assertions.
- [x] Task 5.8: Add Save/Load Performance Benchmark (TDD) - FR-028
  - Notes (2025-11-12): Added `tests/unit/utils/test_input_serialization_performance.gd` to ensure `U_InputSerialization.save_settings()` / `.load_settings()` stay under 100ms using a high-volume bindings dataset, with per-test cleanup guarding `user://` artifacts.
- [x] Task 5.9: Integration Testing - FR-135, FR-136
  - Notes (2025-11-12): Added `tests/unit/integration/test_rebinding_flow.gd` to exercise UI-driven rebind conflicts, add-mode bindings, and persistence reload, plus tightened pause overlay waits for reliability. `tests/unit/utils/test_input_serialization_performance.gd` verifies save/load stay under 100ms during integration run.

- [x] Task 5.10: Manual QA — Open Rebinding Overlay from Pause Menu
  - Steps: Run game, press ESC, click "Rebind Controls"
  - Expected: Rebinding overlay appears with list of rebindable actions

- [x] Task 5.11: Manual QA — Rebind Keyboard Action (Simple Case)
  - Steps: Click "Jump" action, press 'K' key
  - Expected: Jump action updates to 'K', old binding (Space) cleared, change reflected in UI

- [x] Task 5.12: Manual QA — Rebind Gamepad Action (Simple Case)
  - Steps: Connect gamepad, click "Jump", press Gamepad B button
  - Expected: Jump action updates to B button, old binding cleared

- [x] Task 5.13: Manual QA — Conflict Detection (Keyboard)
  - Steps: Rebind "Jump" to 'W' (already bound to move_forward)
  - Expected: Warning dialog appears: "W is already bound to Move Forward. Replace binding?"

- [x] Task 5.14: Manual QA — Confirm Conflict and Swap
  - Steps: Continue from 5.13, click "Confirm"
  - Expected: Jump now bound to W, move_forward binding cleared, both updated in UI

- [x] Task 5.15: Manual QA — Cancel Conflict
  - Steps: Trigger conflict, click "Cancel"
  - Expected: Rebind operation cancelled, original bindings unchanged

- [x] Task 5.16: Manual QA — Reserved Action Protection
  - Steps: Attempt to rebind 'Pause' action (ESC)
  - Expected: Action grayed out or shows "Reserved" label, cannot be rebound

- [x] Task 5.17: Manual QA — Invalid Input Handling (Escape During Capture)
  - Steps: Click action to rebind, press Escape during input capture
  - Expected: Capture cancelled, returns to rebinding overlay, no changes applied

- [x] Task 5.18: Manual QA — Device-Specific Rebinding
  - Steps: Rebind "Jump" for keyboard (K), then rebind "Jump" for gamepad (B)
  - Expected: Both bindings coexist, Jump works with K on keyboard AND B on gamepad

- [x] Task 5.19: Manual QA — Persistence (Save & Restart)
  - Steps: Rebind Jump to K, Sprint to L, Apply, close game, restart
  - Expected: Custom bindings loaded on startup, Jump=K and Sprint=L still active

- [x] Task 5.20: Manual QA — Reset Single Action
  - Steps: Rebind Jump to K, click "Reset" next to Jump action
  - Expected: Jump reverts to default (Space), other custom bindings unchanged

- [x] Task 5.21: Manual QA — Reset All Actions
  - Steps: Rebind multiple actions, click "Reset All to Defaults"
  - Expected: Confirmation dialog, all actions revert to defaults, save file updated

- [x] Task 5.22: Manual QA — Profile Interaction (Rebinding Persists Per-Profile)
  - Steps: Switch to Profile A, rebind Jump to K, switch to Profile B, switch back to A
  - Expected: Profile A retains custom Jump=K binding, Profile B uses defaults

- [x] Task 5.23: Manual QA — Edge Cases (Mouse Buttons, Triggers)
  - Steps: Rebind action to Mouse Button 4, another to Gamepad LT (left trigger)
  - Expected: Both bindings work correctly, trigger analog input converts to button press

## Phase 0-5: Critical Architecture Refactors

### Issue 1: Consolidate Device Detection
- [x] Task 1.1: Add Redux selectors for active device + gamepad ID *(2025-11-11; scripts/state/selectors/u_input_selectors.gd, tests/unit/input_manager/test_u_input_selectors.gd)*
- [x] Task 1.2: Remove device tracking from S_InputSystem *(2025-11-11; scripts/ecs/systems/s_input_system.gd, tests/unit/ecs/systems/test_input_system.gd, tests/unit/integration/test_gamepad_vibration_flow.gd)*
- [x] Task 1.3: Update M_InputDeviceManager to dispatch before emitting `device_changed` *(2025-11-11; scripts/managers/m_input_device_manager.gd, tests/unit/managers/test_m_input_device_manager.gd — added ordering/state-visibility assertions)*
 - [x] Task 1.4: Add integration suite for device detection flow *(2025-11-11; tests/unit/integration/test_device_detection_flow.gd, connection-state dispatch + multi-device scenarios)*
 - [x] Task 1.5: Refresh existing suites to rely on manager as single source *(2025-11-11; vibration/UI/prompt suites now drive M_InputDeviceManager with real input events)*

### Issue 2: Fix State Synchronization
- [x] Task 2.1: Add synchronous Redux apply for rebinds *(2025-11-15; `scripts/state/m_state_store.gd` adds `immediate` flag handling with new coverage in `tests/unit/state/test_m_state_store.gd`)*
- [x] Task 2.2: Update U_InputActions to mark rebind/reset as immediate *(2025-11-15; `scripts/state/actions/u_input_actions.gd` serializes events + immediate flag, overlay tests updated for new payloads)*
- [x] Task 2.3: Refactor M_InputProfileManager to derive InputMap from Redux *(2025-11-15; `scripts/managers/m_input_profile_manager.gd` rebuilds bindings from store, tests/unit/managers suite refreshed)*
- [x] Task 2.4: Rewrite InputRebindingOverlay to dispatch-first *(2025-11-15; `scripts/ui/input_rebinding_overlay.gd` now dispatches before UI updates, store-driven assertions added to overlay tests)*
- [x] Task 2.5: Simplify save/load to read/write Redux only *(2025-11-15; `save_custom_bindings()` / `load_custom_bindings()` now operate on settings slice with updated manager tests)*
- [x] Task 2.6: Move conflict resolution into reducer *(2025-11-15; enhanced `scripts/state/reducers/u_input_reducer.gd` plus expanded reducer coverage)*
- [x] Task 2.7: Integration testing for state synchronization *(2025-11-16; `tests/unit/integration/test_state_synchronization_flow.gd` now covers conflict swaps, save/load roundtrip, and dispatch failure safeguards)*

### Issue 3: Fix Profile Manager Initialization
- [x] Task 3.1: Add ready signal to M_StateStore *(2025-11-19; `scripts/state/m_state_store.gd` now emits `store_ready` + `is_ready()` helper with new coverage in `tests/unit/state/test_m_state_store.gd` and `U_StateUtils.await_store_ready` utility)*
- [x] Task 3.2: Refactor M_InputProfileManager initialization *(2025-11-19; `scripts/managers/m_input_profile_manager.gd` awaits the store-ready signal, removes retry logic, and `tests/unit/managers/test_m_input_profile_manager.gd` asserts single-pass startup + load/save flow)*
- [x] Task 3.3: Update M_InputDeviceManager to use store.ready pattern *(2025-11-19; manager now queues device events until the store is ready, updates action order, and extends `tests/unit/managers/test_m_input_device_manager.gd` for pending-event flush assertions)*
- [x] Task 3.4: Integration testing *(2025-11-19; new `tests/unit/integration/test_manager_initialization_order.gd` exercises store-first / manager-first sequencing, hot reloads, and 100-iteration stress runs)*

### Issue 4: Consolidate Event Serialization
- [x] Task 4.1: Audit U_InputRebindUtils serialization *(2025-11-19; `scripts/utils/input/u_input_rebind_utils.gd` now roundtrips keyboard/mouse/gamepad/touch events, preserves modifiers/pressure, and `tests/unit/utils/test_input_event_serialization_roundtrip.gd` covers each type + legacy schemas)*
- [x] Task 4.2: Delete RS_InputProfile serialization *(2025-11-19; `scripts/input/resources/rs_input_profile.gd` delegates to U_InputRebindUtils for both directions, keeping action dictionaries canonical)*
- [x] Task 4.3: Update U_InputSerialization / reducers to normalize via canonical schema *(2025-11-19; `scripts/utils/input/u_input_serialization.gd` and `scripts/state/reducers/u_input_reducer.gd` now sanitize dictionaries through the shared helper and recognize new device types)*
- [x] Task 4.4: Simplify reducer normalization *(2025-11-19; reducer + selectors treat `screen_touch` / `screen_drag` as touch device type, avoiding divergent schemas)*
- [x] Task 4.5: Add comprehensive roundtrip tests *(2025-11-19; new utils test suite validates event dicts ⇄ InputEvent conversions and RS_InputProfile serialization uses the shared helper)*

### Issue 5: Deduplicate Deadzone Logic
- [x] Task 5.1: Standardize RS_GamepadSettings.apply_deadzone *(2025-11-19; `scripts/input/resources/rs_gamepad_settings.gd` exposes a static canonical helper with curve/Curve support and additional unit coverage)*
- [x] Task 5.2: Remove S_InputSystem._apply_deadzone *(2025-11-19; system now calls the resource helper directly and `tests/unit/ecs/systems/test_input_system.gd` re-ran green)*
- [x] Task 5.3: Remove C_GamepadComponent._apply_deadzone_manual *(2025-11-19; component delegates to RS_GamepadSettings and the component test suite verifies curve usage)*
- [x] Task 5.4: Verify consistency across codebase *(2025-11-19; `scripts/ui/gamepad_settings_overlay.gd` and related previews use the shared helper, with UI + integration suites rerun)*

## Phase 6: Touchscreen Support

**Architecture Review Complete:** See `docs/input_manager/general/phase-6-touchscreen-architecture.md` for comprehensive audit and integration analysis.

**Key Decisions (Finalized 2025-11-16):**
- ✅ **Positioning:** Drag-to-reposition overlay (separate `EditTouchControlsOverlay` screen accessed via Pause Menu → Touchscreen Settings → Edit Layout)
- ✅ **Visibility:** HIDDEN during scene transitions (cleaner visual), HIDDEN during pause menu
- ✅ **Opacity:** Dynamic fade (30% opacity after 2s idle, full opacity on touch)
- ✅ **Button Set:** Complete - 4 buttons (Jump, Sprint, Interact, Pause) in cfg_default_touchscreen.tres
- ✅ **Auto-hide:** When gamepad OR keyboard connected (M_InputDeviceManager integration)
- ✅ **Orientation:** Landscape only (no rotation support in Phase 6)
- ✅ **Assets:** Kenney.nl Mobile pack (joystick_base.png, joystick_thumb.png, button_background.png)
- ✅ **Testing:** Physical device available for on-hardware QA; desktop `--emulate-mobile` flag retained as optional smoke fallback alongside unit tests
- ✅ **Reset:** Default touchscreen profile (`cfg_default_touchscreen.tres`) with metadata-driven button configuration

**Architecture Validation (2025-11-16):**
- ✅ **Viewport Scaling:** CORRECT - Uses 960x540 with stretch mode, no hardcoded phone dimensions found
- ✅ **Redux State:** READY - touchscreen_settings slice exists, just needs position fields added
- ✅ **Device Detection:** WORKING - M_InputDeviceManager already handles InputEventScreenTouch/Drag
- ✅ **ECS Pattern:** READY - S_TouchscreenSystem can reuse existing C_InputComponent (no new component needed)
- ✅ **Profile System:** EXTENSIBLE - Just needs cfg_default_touchscreen.tres added to existing profiles

**What Went Wrong in backup-input-manager:**
- ❌ Hardcoded phone dimensions (1080x1920) instead of viewport-relative coords
- ❌ Multiple sources of truth for positions (UI vars, profile, partial Redux)
- ❌ Excessive programmatic UI (built entirely in code, no .tscn scenes)
- ❌ No clear reset path (no default touchscreen profile)

### Task 6.0: Create Default Touchscreen Profile (TDD) - NEW

**CRITICAL PREREQUISITE:**

- [x] Task 6.0.0: Fix RS_InputProfile serialization bug (BLOCKER - must complete before 6.0.1) *(2025-11-16, Vector2 hybrid serialization implemented)*
  - **BUG FOUND:** Touchscreen fields exist but are NOT serialized in to_dictionary() / from_dictionary()
  - **Impact:** Default touchscreen profile won't save/load properly, reset-to-defaults will fail
  - **TDD RED:** Write test in `tests/unit/resources/test_rs_input_profile.gd`
    - Test touchscreen profile roundtrip: create profile with virtual_buttons → to_dict() → from_dict() → verify fields match
    - Test save/load: save profile with touchscreen data → load from disk → verify virtual_buttons and virtual_joystick_position restored
  - **TDD GREEN:** Fix `scripts/input/resources/rs_input_profile.gd`
    - Add to `to_dictionary()` (around line 53):
      ```gdscript
      "virtual_buttons": virtual_buttons.duplicate(true),
      "virtual_joystick_position": virtual_joystick_position,
      ```
    - Add to `from_dictionary()` (around line 73):
      ```gdscript
      virtual_buttons = data.get("virtual_buttons", [])
      virtual_joystick_position = data.get("virtual_joystick_position", Vector2(-1, -1))
      ```
  - **TDD REFACTOR:** Run all profile tests, verify no regressions
  - **Note:** Fields already exist in RS_InputProfile (lines 20-22), just need serialization

**TDD RED-GREEN-REFACTOR CYCLE:**

- [x] Task 6.0.1: **RED** - Write failing tests for touchscreen profile loading *(2025-11-16)*
  - Extend `tests/unit/resources/test_rs_input_profile.gd` with:
    ```gdscript
    func test_touchscreen_profile_loads_with_virtual_buttons():
        var profile: RS_InputProfile = load("res://resources/input/profiles/cfg_default_touchscreen.tres")
        assert_not_null(profile, "Touchscreen profile should load")
        assert_eq(profile.device_type, 2, "Device type should be touchscreen")
        assert_eq(profile.virtual_buttons.size(), 4, "Should have 4 virtual buttons")
        # Test button structure
        for button in profile.virtual_buttons:
            assert_true(button.has("action"), "Button should have action")
            assert_true(button.has("position"), "Button should have position")

    func test_touchscreen_profile_has_joystick_position():
        var profile: RS_InputProfile = load("res://resources/input/profiles/cfg_default_touchscreen.tres")
        assert_ne(profile.virtual_joystick_position, Vector2(-1, -1), "Should have joystick position")
    ```
  - **Expected result:** Tests FAIL (profile doesn't exist yet) ❌

- [x] Task 6.0.2: **GREEN** - Create minimal profile to pass tests *(2025-11-16, resources/input/profiles/cfg_default_touchscreen.tres created)*
  - Create `resources/input/profiles/cfg_default_touchscreen.tres`
  - Set minimum fields to make tests pass:
    - `profile_name: "Default (Touchscreen)"`
    - `device_type: 2` (TOUCHSCREEN)
    - `virtual_joystick_position: Vector2(120, 520)`
    - `virtual_buttons` with 4 entries
  - **Expected result:** Tests PASS ✅

- [x] Task 6.0.3: **RED** - Write failing tests for manager loading *(2025-11-16)*
  - Extend `tests/unit/managers/test_m_input_profile_manager.gd` with:
    ```gdscript
    func test_manager_loads_touchscreen_profile():
        # Setup manager
        var manager = autofree(M_InputProfileManager.new())
        add_child(manager)
        await get_tree().process_frame

        # Assert touchscreen profile loaded
        var profile_ids := manager.get_available_profile_ids()
        assert_true(profile_ids.has("default_touchscreen"), "Should load touchscreen profile")
    ```
  - **Expected result:** Test FAILS (manager doesn't load touchscreen yet) ❌

- [x] Task 6.0.4: **GREEN** - Add touchscreen profile loading to manager *(2025-11-16)*
  - Edit `scripts/managers/m_input_profile_manager.gd`
  - Add to `_load_available_profiles()`:
    ```gdscript
    var default_touchscreen_res := load("res://resources/input/profiles/cfg_default_touchscreen.tres")
    if default_touchscreen_res is RS_InputProfile:
        available_profiles["default_touchscreen"] = default_touchscreen_res
    ```
  - **Expected result:** Test PASSES ✅

- [x] Task 6.0.5: **RED** - Write failing tests for reset_touchscreen_positions() *(2025-11-16)*
  - Add to `test_m_input_profile_manager.gd`:
    ```gdscript
    func test_reset_touchscreen_positions_returns_defaults():
        # Setup
        var manager = autofree(M_InputProfileManager.new())
        add_child(manager)
        await get_tree().process_frame

        # Call reset
        var positions := manager.reset_touchscreen_positions()

        # Assert returned defaults
        assert_eq(positions.size(), 4, "Should return 4 button positions")
        assert_true(positions[0].has("action"), "Should have action field")
        assert_true(positions[0].has("position"), "Should have position field")
    ```
  - **Expected result:** Test FAILS (method doesn't exist) ❌

- [x] Task 6.0.6: **GREEN** - Implement reset_touchscreen_positions() *(2025-11-16, added to M_InputProfileManager)*
  - Add method to `m_input_profile_manager.gd`:
    ```gdscript
    func reset_touchscreen_positions() -> Array[Dictionary]:
        var profile := _get_default_touchscreen_profile()
        if profile == null: return []

        var result: Array[Dictionary] = []
        for button in profile.virtual_buttons:
            result.append(button.duplicate(true))
        return result
    ```
  - **Expected result:** Test PASSES ✅

- [x] Task 6.0.7: **REFACTOR** - Run all tests and verify no regressions *(2025-11-16, 12/12 resource tests + 26/26 manager tests passing)*
  - Run full test suite: `tests/unit/resources/test_rs_input_profile.gd`
  - Run full test suite: `tests/unit/managers/test_m_input_profile_manager.gd`
  - **Expected result:** All tests PASS ✅

- [x] Task 6.0.8: Download Kenney.nl Mobile Assets - NEW (Gap Fill, non-TDD) *(2025-11-16)*
  - Download Kenney Input Prompts - Mobile pack (free, CC0) from kenney.nl ✅
  - Extract joystick_base.png, joystick_thumb.png, button_background.png ✅
  - Import to `resources/button_prompts/mobile/` ✅
  - Configure import settings: 64x64 PNG, mipmaps disabled, filter enabled (will auto-configure on next Godot launch)
  - Add LICENSE_Kenney_Mobile.txt to resources folder ✅
  - **Files installed:** joystick_base.png (3.0K), joystick_thumb.png (1.7K), button_background.png (1.5K)
  - **Source:** Kenney Mobile Controls 1, Style A/Default

### Task 6.1: Create RS_TouchscreenSettings Resource (TDD) - FR-101

**TDD RED-GREEN-REFACTOR CYCLE:**

- [x] Task 6.1.1: **RED** - Write failing tests for RS_TouchscreenSettings *(2025-11-16)*
  - Created `tests/unit/resources/test_rs_touchscreen_settings.gd`
  - Tests verify deadzone calculation and default values
  - **Result:** Tests FAILED as expected (class doesn't exist) ❌

- [x] Task 6.1.2: **GREEN** - Create minimal RS_TouchscreenSettings to pass tests *(2025-11-16)*
  - Created `scripts/input/resources/rs_touchscreen_settings.gd`
  - Implemented static `apply_touch_deadzone()` helper method
  - Added exports for virtual_joystick_size, joystick_deadzone, button_opacity
  - **Result:** Tests PASSED ✅

- [x] Task 6.1.3: **REFACTOR** - Add remaining exports and default resource *(2025-11-16)*
  - Added full exports: `virtual_joystick_opacity`, `button_size`, `button_opacity`
  - Created `resources/input/touchscreen_settings/cfg_default_touchscreen_settings.tres`
  - **Result:** Tests still PASSED (4/4 tests, 11 assertions) ✅

### Task 6.2: Add Redux State Integration (TDD)

**CRITICAL REQUIREMENT: Vector2 Serialization Strategy (User Decision: Hybrid Approach)**
- Redux state stores positions as **Vector2 in memory** (native Godot type)
- Save/load converts to **Dictionary {x: float, y: float}** for JSON compatibility
- **Pattern:**
  - Actions receive Vector2, store Vector2: `{type: "...", payload: {position: Vector2(x, y)}}`
  - Reducer stores Vector2 directly: `ts_settings["custom_joystick_position"] = position`
  - Selectors return Vector2: `return state.get("custom_joystick_position", Vector2(-1, -1))`
  - Save converts Vector2 → dict: `{"x": pos.x, "y": pos.y}`
  - Load converts dict → Vector2: `Vector2(dict.get("x", -1), dict.get("y", -1))`
- **Why Hybrid:** Simpler reducer/selector code, JSON-compatible persistence, no runtime conversion overhead

**TDD RED-GREEN-REFACTOR CYCLE:**

- [x] Task 6.2.1: **RED** - Write failing tests for touchscreen actions *(2025-11-16)*
  - Extended `test_u_input_actions.gd` with 2 new test functions
  - Tested action creators return correct shape (Vector2 positions, not dicts)
  - **Result:** Tests FAILED as expected (actions don't exist) ❌

- [x] Task 6.2.2: **GREEN** - Add touchscreen actions to pass tests *(2025-11-16)*
  - Added constants: `ACTION_UPDATE_TOUCHSCREEN_SETTINGS`, `ACTION_SAVE_VIRTUAL_CONTROL_POSITION`
  - Added action creators to `u_input_actions.gd`
  - **Result:** Tests PASSED (22/22 action tests) ✅

- [x] Task 6.2.3: **RED** - Write failing tests for touchscreen reducers *(2025-11-16)*
  - Extended `test_u_input_reducer.gd` with 4 new test functions
  - Tested Vector2 storage directly (NOT dict), missing fields default correctly
  - **Result:** Tests FAILED as expected (reducer cases don't exist) ❌

- [x] Task 6.2.4: **GREEN** - Add reducer cases to pass tests *(2025-11-16)*
  - Extended `u_input_reducer.gd` with touchscreen cases
  - Added missing fields to DEFAULT_INPUT_SETTINGS_STATE:
    - `"joystick_deadzone": 0.15`, `"button_opacity": 0.8`
    - `"custom_joystick_position": Vector2(-1, -1)`, `"custom_button_positions": {}`
    - `"custom_button_sizes": {}`, `"custom_button_opacities": {}` (per-button customization)
  - **Result:** Tests PASSED (21/21 reducer tests) ✅

- [x] Task 6.2.5: **RED** - Write failing tests for touchscreen selectors *(2025-11-16)*
  - Extended `test_u_input_selectors.gd` with 4 new test functions
  - Tested `get_touchscreen_settings`, `get_virtual_control_position`, sentinel value handling
  - **Result:** Tests FAILED as expected (selectors don't exist) ❌

- [x] Task 6.2.6: **GREEN** - Add selectors to pass tests *(2025-11-16)*
  - Added `get_touchscreen_settings()` and `get_virtual_control_position()` to `u_input_selectors.gd`
  - Returns Vector2 fields as-is (no conversion needed)
  - **Result:** Tests PASSED (28/28 selector tests) ✅

- [x] Task 6.2.7: **REFACTOR** - Run full Redux test suite *(2025-11-16)*
  - Verified no regressions in actions/reducers/selectors
  - **Result:** All Redux tests PASSED (82/82 tests, 278 assertions) ✅

- [x] Task 6.2.8: **NEW** - Add Vector2 serialization to U_InputSerialization *(2025-11-16)*
  - Created `_serialize_touchscreen_vector2_fields()` (Vector2 → {x, y} dict)
  - Created `_deserialize_touchscreen_vector2_fields()` ({x, y} → Vector2)
  - Updated `_prepare_save_payload()` and `_sanitize_loaded_settings()` to use helpers
  - Created `test_u_input_serialization.gd` with 5 roundtrip tests
  - **Result:** All tests PASSED (5/5 serialization tests, 26 assertions), roundtrip verified ✅

### Task 6.3: Create VirtualJoystick UI Component (TDD) - FR-047, FR-049, FR-050, FR-051

**Status (2025-11-19):** ✅ Implemented `scripts/ui/virtual_joystick.gd` + `scenes/ui/virtual_joystick.tscn` with full test coverage in `tests/unit/ui/test_virtual_joystick.gd` (press/drag/deadzone/multi-touch/reposition + Redux save hook). Regression coverage updated via `tests/unit/integration/test_button_prompt_flow.gd` and the headless unit/integration suite now passes when run with a local HOME override (`HOME="$PWD/.home_tmp" ... gut_cmdln.gd ... -gdir=res://tests/unit -ginclude_subdirs -gexit`).

**TDD Approach:** Feature-by-feature cycles (User Decision: 2025-11-16)

- [x] Task 6.3.1: **Cycle 1 - Basic Touch Detection**
  - **RED:** Write failing tests for touch press/release
    - Create `tests/unit/ui/test_virtual_joystick.gd`
    - Test touch press activates joystick (`is_active() == true`)
    - Test touch release deactivates joystick (`is_active() == false`)
    - Test `joystick_released` signal emitted on release
    - **Expected:** FAIL (VirtualJoystick class doesn't exist) ❌ *(fulfilled 2025-11-19 via new GUT suite)*
  - **GREEN:** Create minimal implementation
    - Create `scripts/ui/virtual_joystick.gd` (extends Control, class_name VirtualJoystick)
    - Implement `_input()` handler for InputEventScreenTouch
    - Track `_touch_id: int` and `_is_active: bool` state
    - Emit `joystick_released()` signal on touch release
    - Add `is_active() -> bool` getter
    - **Expected:** Tests PASS ✅ *(VirtualJoystick instantiation + press/release signal)*
  - **REFACTOR:** None needed (minimal code)

- [x] Task 6.3.2: **Cycle 2 - Touch Drag & Vector Calculation**
  - **RED:** Write failing tests for drag vector calculation
    - Test drag updates joystick vector (get_vector() returns non-zero)
    - Test vector magnitude clamped to joystick_radius
    - Test vector normalized to -1..1 range
    - Test `joystick_moved(vector)` signal emitted on drag
    - **Expected:** FAIL (drag handling not implemented) ❌ *(captured by new tests before implementation)*
  - **GREEN:** Implement drag handling
    - Add `_touch_start_position: Vector2` and `_current_vector: Vector2` state
    - Implement InputEventScreenDrag handler in `_input()`
    - Calculate offset from touch start position
    - Clamp offset to `joystick_radius`, normalize to -1..1
    - Emit `joystick_moved(vector)` signal on drag
    - Add `get_vector() -> Vector2` getter
    - **Expected:** Tests PASS ✅ *(Vector clamping + joystick_moved signal implemented)*
  - **REFACTOR:** Extract `_calculate_joystick_vector(offset: Vector2) -> Vector2` helper method

- [x] Task 6.3.3: **Cycle 3 - Deadzone Filtering**
  - **RED:** Write failing tests for deadzone application
    - Test small movements below deadzone return Vector2.ZERO
    - Test movements above deadzone rescaled to 0..1 range
    - Test deadzone uses `RS_TouchscreenSettings.apply_touch_deadzone()` helper
    - **Expected:** FAIL (deadzone not applied) ❌ *(failing assertion added in new suite)*
  - **GREEN:** Apply deadzone to calculated vector
    - Add `@export var deadzone: float = 0.15`
    - Call `RS_TouchscreenSettings.apply_touch_deadzone(normalized, deadzone)` in `_calculate_joystick_vector()`
    - **Expected:** Tests PASS ✅ *(APIs now call RS_TouchscreenSettings.apply_touch_deadzone)*
  - **REFACTOR:** None needed

- [x] Task 6.3.4: **Cycle 4 - Multi-Touch Handling**
  - **RED:** Write failing tests for multi-touch safety
    - Test second touch ignored (different index doesn't affect joystick)
    - Test joystick only responds to first assigned touch ID
    - Test `_touch_id` reset to -1 on release (ready for next touch)
    - **Expected:** FAIL (multi-touch not handled) ❌ *(validated by additional test cases)*
  - **GREEN:** Add touch ID validation
    - In `_handle_touch()`: Only assign touch if `_touch_id == -1` (first touch wins)
    - In `_handle_drag()`: Early return if `event.index != _touch_id` (ignore other touches)
    - In `_release()`: Reset `_touch_id = -1`
    - **Expected:** Tests PASS ✅ *(touch ID guard + reset logic complete)*
  - **REFACTOR:** None needed

- [x] Task 6.3.5: **Cycle 5 - Drag-to-Reposition**
  - **RED:** Write failing tests for repositioning mode
    - Test `can_reposition` flag enables drag-to-reposition mode
    - Test Control.position updated when dragged in reposition mode
    - Test position saved to Redux via `U_InputActions.save_virtual_control_position()`
    - Test normal joystick vector ignored when `_is_repositioning == true`
    - **Expected:** FAIL (repositioning not implemented) ❌ *(tracked via new GUT regression)*
  - **GREEN:** Implement reposition logic
    - Add `@export var can_reposition: bool = false`
    - Add `var _is_repositioning: bool = false` internal state
    - In `_handle_drag()`: Check `can_reposition`, update Control.position if true
    - Add `_save_position()` method (dispatch to Redux via U_StateUtils.get_store())
    - Prevent normal vector calculation when `_is_repositioning`
    - **Expected:** Tests PASS ✅ *(Redux dispatch + position updates verified)*
  - **REFACTOR:** Clean up `_handle_drag()` branching logic (if/else for reposition vs normal drag)

- [x] Task 6.3.6: **Scene Setup & Textures** (non-TDD)
  - Create `scenes/ui/virtual_joystick.tscn` with Control root
  - Add TextureRect children for base and thumb visuals
  - Add `@export var base_texture: Texture2D` and `@export var thumb_texture: Texture2D` to script
  - Set texture defaults in scene inspector:
    - `base_texture`: `res://assets/button_prompts/mobile/joystick_base.png`
    - `thumb_texture`: `res://assets/button_prompts/mobile/joystick_thumb.png`
  - Add programmatic fallback in `_ready()` if textures null (load defaults)
  - Configure Control size: 240x240 (120px radius * 2)
  - Add `@export var joystick_radius: float = 120.0` to script
  - Run full test suite: `tests/unit/ui/test_virtual_joystick.gd`
  - **Expected:** All tests PASS (10-12 test methods, ~35+ assertions) ✅
  - Manual smoke test (optional desktop fallback): `--emulate-mobile` flag, verify joystick responds to mouse drag

### Task 6.4: Create VirtualButton UI Component (TDD) - FR-048

**Status (2025-11-20):** ✅ Implemented `scripts/ui/virtual_button.gd` + `scenes/ui/virtual_button.tscn` with full coverage in `tests/unit/ui/test_virtual_button.gd` (11 tests / 73 assertions covering press/release, drag-out, action types, multi-touch, reposition save, and visual feedback). Regression suite executed via `Godot --headless ... -gtest=res://tests/unit/ui/test_virtual_button.gd -gexit`.

**User Decisions (2025-11-20):**
- ✅ **TDD Structure:** 5 detailed cycles (same as VirtualJoystick)
- ✅ **Drag-out behavior:** Cancel press (release) - mobile UI convention
- ✅ **Action types:** Configurable per-button via `@export var action_type: ActionType`
- ✅ **Visual feedback:** Modulate color (darken) + Scale pulse (0.95)

**TDD Approach:** Feature-by-feature cycles (5 mini RED-GREEN-REFACTOR cycles)

- [x] Task 6.4.1: **Cycle 1 - Basic Touch Press/Release**
  - **RED:** Write failing tests for touch press/release
    - Create `tests/unit/ui/test_virtual_button.gd`
    - Test touch press activates button (`is_pressed() == true`)
    - Test touch release deactivates button (`is_pressed() == false`)
    - Test `button_pressed(action)` signal emitted on press
    - Test `button_released(action)` signal emitted on release
    - **Expected:** FAIL (VirtualButton class doesn't exist) ❌ *(captured 2025-11-20 before script stub existed)*
  - **GREEN:** Create minimal implementation
    - Create `scripts/ui/virtual_button.gd` (extends Control, class_name VirtualButton)
    - Implement `_input()` handler for InputEventScreenTouch
    - Track `_touch_id: int` and `_is_pressed: bool` state
    - Add `@export var action: StringName` for action binding
    - Emit `button_pressed(action)` and `button_released(action)` signals
    - Add `is_pressed() -> bool` getter
    - **Expected:** Tests PASS ✅ *(press/release assertions now green in the new suite)*
  - **REFACTOR:** None needed (minimal code)

- [x] Task 6.4.2: **Cycle 2 - Drag-Out Handling**
  - **RED:** Write failing tests for drag-out cancellation
    - Test drag outside button bounds cancels press
    - Test `button_released(action)` signal emitted on drag-out
    - Test `is_pressed() == false` after drag-out
    - Test returning finger to button bounds does NOT re-activate (must lift and re-press)
    - **Expected:** FAIL (drag-out not implemented) ❌ *(new tests failed until drag handler existed)*
  - **GREEN:** Implement drag-out detection
    - Add InputEventScreenDrag handler in `_input()`
    - Check if drag position is outside `get_global_rect()`
    - If outside and `_is_pressed`, call `_release()` to cancel
    - **Expected:** Tests PASS ✅ *(drag-out tests now stable)*
  - **REFACTOR:** Extract `_is_touch_inside() -> bool` helper method *(done while wiring drag logic)*

- [x] Task 6.4.3: **Cycle 3 - Action Type (Tap vs Hold)**
  - **RED:** Write failing tests for action type behavior
    - Test TAP mode: `button_pressed` emits on release only (not on press)
    - Test HOLD mode: `button_pressed` emits on press start, `button_released` on release
    - Test action_type defaults to HOLD (for sprint-like actions)
    - **Expected:** FAIL (action type not implemented) ❌ *(tap/hold assertions red prior to enum)*
  - **GREEN:** Add action type enum and conditional emission
    - Add `enum ActionType { TAP, HOLD }`
    - Add `@export var action_type: ActionType = ActionType.HOLD`
    - In `_handle_touch()`: Only emit `button_pressed` if HOLD mode
    - In `_release()`: Emit `button_pressed` if TAP mode, always emit `button_released`
    - **Expected:** Tests PASS ✅ *(tap vs hold coverage now green)*
  - **REFACTOR:** None needed

- [x] Task 6.4.4: **Cycle 4 - Multi-Touch Safety**
  - **RED:** Write failing tests for multi-touch handling
    - Test second touch ignored (different index doesn't affect button)
    - Test button only responds to first assigned touch ID
    - Test `_touch_id` reset to -1 on release (ready for next touch)
    - **Expected:** FAIL (multi-touch not handled) ❌ *(new touch-id assertions failed before guards)*
  - **GREEN:** Add touch ID validation
    - In `_handle_touch()`: Only assign touch if `_touch_id == -1` (first touch wins)
    - In `_handle_drag()`: Early return if `event.index != _touch_id`
    - In `_release()`: Reset `_touch_id = -1`
    - **Expected:** Tests PASS ✅ *(multi-touch suite now stable)*
  - **REFACTOR:** None needed

- [x] Task 6.4.5: **Cycle 5 - Drag-to-Reposition**
  - **RED:** Write failing tests for repositioning mode
    - Test `can_reposition` flag enables drag-to-reposition mode
    - Test Control.position updated when dragged in reposition mode
    - Test position saved to Redux via `U_InputActions.save_virtual_control_position()`
    - Test normal button press ignored when `can_reposition == true`
    - **Expected:** FAIL (repositioning not implemented) ❌ *(reposition suite failed before logic landed)*
  - **GREEN:** Implement reposition logic
    - Add `@export var can_reposition: bool = false`
    - In `_handle_drag()`: If `can_reposition`, update Control.position instead of checking bounds
    - Add `_save_position()` method (dispatch to Redux via U_StateUtils.get_store())
    - Call `_save_position()` on touch release when repositioning
    - **Expected:** Tests PASS ✅ *(Redux dispatch verified via `TestStateStore`)*
  - **REFACTOR:** Clean up `_handle_drag()` branching logic *(separated reposition vs normal flow)*

- [x] Task 6.4.6: **Scene Setup, Textures & Visual Feedback** (non-TDD)
  - Create `scenes/ui/virtual_button.tscn` with Control root
  - Add TextureRect child for button visual
  - Add `@export var button_texture: Texture2D` to script
  - Set texture default in scene: `res://assets/button_prompts/mobile/button_background.png`
  - Add programmatic fallback in `_ready()` if texture null
  - **Visual feedback on press:**
    - Modulate color: `modulate = Color(0.8, 0.8, 0.8, 1.0)` when pressed
    - Scale pulse: `scale = Vector2(0.95, 0.95)` when pressed
    - Restore on release: `modulate = Color.WHITE`, `scale = Vector2.ONE`
  - Configure Control size: 100x100 (default button size)
  - Run full test suite: `tests/unit/ui/test_virtual_button.gd`
  - **Expected:** All tests PASS (10-12 test methods, ~25+ assertions) ✅ *(final visual feedback test makes suite 11 tests / 73 assertions)*

### Task 6.5: Create MobileControls Scene + Visibility Logic (TDD) - FR-046, FR-053, FR-054, FR-056-B, FR-056-C

**TDD RED-GREEN-REFACTOR CYCLE:**

- [x] Task 6.5.1: **RED** - Write failing tests for MobileControls visibility *(tests/unit/ui/test_mobile_controls.gd added)*
  - Create `tests/unit/ui/test_mobile_controls.gd`
  - Test conditional instantiation, device detection, pause menu hiding, opacity changes
  - **Expected:** FAIL ❌

- [x] Task 6.5.2: **GREEN** - Create minimal MobileControls to pass tests *(scripts/ui/mobile_controls.gd initial implementation)*
  - Create `scripts/ui/mobile_controls.gd` with minimum implementation
  - **Expected:** Tests PASS ✅

- [x] Task 6.5.3: **REFACTOR** - Add metadata-driven buttons and create scene *(mobile_controls.tscn + root wiring + Tween fade)*
  - Add dynamic button instantiation from profile (4 buttons: jump, sprint, interact, pause)
  - Add dynamic opacity fade logic using **Tween** (User Decision: GPU-accelerated, smoother)
    ```gdscript
    var _idle_tween: Tween = null
    const FADE_DELAY: float = 2.0
    const IDLE_OPACITY: float = 0.3
    const ACTIVE_OPACITY: float = 1.0

    func _on_input_activity() -> void:
        # Kill existing tween if active
        if _idle_tween and _idle_tween.is_running():
            _idle_tween.kill()

        # Restore to full opacity immediately
        modulate.a = ACTIVE_OPACITY

        # Start new fade tween after delay
        _idle_tween = create_tween()
        _idle_tween.tween_interval(FADE_DELAY)
        _idle_tween.tween_property(self, "modulate:a", IDLE_OPACITY, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    ```
  - Visibility rules: HIDDEN during scene transitions, HIDDEN during pause menu, HIDDEN when gamepad/keyboard connected
  - Create `scenes/ui/mobile_controls.tscn`
  - Add to `root.tscn`
  - **Expected:** Tests still PASS ✅
  - **User Decision Note:** Transitions hide controls (changed from "visible with gray" to "hidden" for cleaner visual)
  - **Performance Note:** Tween is GPU-accelerated, better for mobile battery life than _process() checks

### Task 6.6: Create S_TouchscreenSystem (TDD) - FR-052, FR-055

**TDD RED-GREEN-REFACTOR CYCLE:**

- [x] Task 6.6.1: **RED** - Write failing tests for S_TouchscreenSystem *(2025-11-20, added `tests/unit/ecs/systems/test_s_touchscreen_system.gd`)*
- [x] Task 6.6.2: **GREEN** - Create minimal S_TouchscreenSystem to pass tests *(2025-11-20, device/emulation guards + debug flag check + state dispatch)*
- [x] Task 6.6.3: **REFACTOR** - Add to gameplay scene *(2025-11-20, system node added under Systems/Core in `scenes/gameplay/gameplay_base.tscn`)*
- [x] Task 6.6.4: **NEW** - Add debug.disable_touchscreen emergency flag *(2025-11-20, new debug slice/actions/selectors + default resource wired to M_StateStore)*

### Task 6.8: Integration Testing - FR-133
- [x] Task 6.8.1: Create `tests/unit/integration/test_touchscreen_input_flow.gd`
  - Added integration coverage for touchscreen input flow, visibility guards (device + transition), and position persistence via StateHandoff
  - Test scenario: Virtual joystick movement updates C_InputComponent
    - Instantiate MobileControls, VirtualJoystick, C_InputComponent, S_TouchscreenSystem
    - Simulate touch drag on joystick
    - Verify component `move_vector` updated
  - Test scenario: Virtual button press triggers jump
    - Simulate touch press on JumpButton
    - Verify jump action dispatched or component updated
  - Test scenario: Gamepad connect hides virtual controls
    - Simulate device change to GAMEPAD
    - Verify MobileControls.visible == false
  - Test scenario: Pause menu hides virtual controls
    - Push pause_menu overlay
    - Verify MobileControls.visible == false
  - Test scenario: Scene transition hides virtual controls (USER DECISION: cleaner visual)
    - Simulate scene transition (`M_SceneManager.is_transitioning() == true`)
    - Verify MobileControls.visible == false (hidden during transitions)
  - Test scenario: Drag-to-reposition saves position
    - Enable `can_reposition`, drag joystick to new position
    - Verify Redux state updated with new position
  - Test scenario: Settings persistence (save/load)
    - Save custom positions, load settings
    - Verify positions restored correctly
  - Test scenario: Vector2 deserialization (CRITICAL - User Decision: Hybrid approach)
    - Save touchscreen settings with Vector2 positions
    - Verify JSON contains {x, y} dictionaries (not Vector2 objects)
    - Load settings from JSON
    - Verify positions deserialized as Vector2 objects (not dictionaries)
    - Test edge case: Load Phase 5 save file (no touchscreen_settings)
    - Verify reducer defaults missing Vector2 fields to Vector2(-1, -1)
  - Test scenario: Device switching race condition prevention
    - Touchscreen active, virtual controls visible
    - Connect gamepad (device switches)
    - Verify S_TouchscreenSystem stops processing on SAME frame (not 1 frame late)
    - Verify no input ghosting (touchscreen input doesn't bleed into gamepad frame)
  - Test scenario: Emergency disable flag
    - Set debug.disable_touchscreen = true
    - Verify S_TouchscreenSystem skips processing
    - Verify virtual controls still visible (system disabled, not UI)
    - Set flag = false
    - Verify system resumes processing

### Task 6.9: Manual QA (Physical Mobile Device) - NEW
- [x] Task 6.9.1: Deploy to device
  - Install build on the test handset (iOS/Android) with touch enabled
  - Confirm virtual controls instantiate without `--emulate-mobile`
- [x] Task 6.9.2: Basic joystick movement
  - Drag on virtual joystick with a finger
  - Expected: Player moves in joystick direction
- [x] Task 6.9.3: Button presses
  - Tap Jump button
  - Expected: Player jumps
  - Tap Sprint button
  - Expected: Player sprints
- [x] Task 6.9.4: Auto-hide on gamepad
  - Connect Bluetooth gamepad, press a button
  - Expected: Virtual controls disappear and Bluetooth gamepad input remains responsive (no gating on cursor capture for mobile)
  - Touch screen
  - Expected: Virtual controls reappear
- **Deferral:** Tasks 6.9.5-6.9.7 moved to Phase 6R (Post-Reposition QA) after drag/save logic lands.
- [x] Task 6.9.8: Dynamic opacity fade (USER DECISION)
  - Observe virtual controls after 2 seconds of no input
  - Expected: Controls fade to 30% opacity
  - Touch screen (or move joystick)
  - Optional desktop smoke: one `--emulate-mobile` run after device pass
  - Expected: Controls restore to full opacity immediately

### Task 6.10: Create TouchscreenSettingsOverlay (TDD) - FR-056-E - NEW (Gap Fill)
- [x] Task 6.10.1: Create `scenes/ui/touchscreen_settings_overlay.tscn`
  - Root: TouchscreenSettingsOverlay (Control)
  - Sliders: Joystick Size (0.5-2.0), Button Size (0.5-2.0)
  - Sliders: Joystick Opacity (0.3-1.0), Button Opacity (0.3-1.0)
  - Slider: Joystick Deadzone (0.0-0.5)
  - Live preview: VirtualJoystick + VirtualButton visualization (like GamepadSettingsOverlay stick preview)
  - Buttons: Apply, Cancel, Reset to Defaults
- [x] Task 6.10.2: Create `scripts/ui/touchscreen_settings_overlay.gd`
  - Extend `Control`, similar to `GamepadSettingsOverlay` pattern
  - Subscribe to state store for current settings
  - Update live preview on slider changes
  - Apply button dispatches `update_touchscreen_settings` actions to Redux
  - Reset button calls `M_InputProfileManager.reset_touchscreen_positions()`
- [x] Task 6.10.3: Wire overlay to Scene Registry + Pause Menu
  - Register in Scene Registry: `touchscreen_settings`
  - Add button to Pause Menu: "Touchscreen Settings"
  - Wire to `scene_manager.push_overlay_with_return(StringName("touchscreen_settings"))`
- [x] Task 6.10.4: Unit tests: `tests/unit/ui/test_touchscreen_settings_overlay.gd`
  - Test slider updates preview in real-time
  - Test Apply button dispatches to Redux
  - Test Reset button restores defaults
  - Test Cancel button discards changes

### Task 6.11: Create EditTouchControlsOverlay (TDD) - FR-056-D - NEW (Gap Fill)
- [x] Task 6.11.1: Create `scenes/ui/edit_touch_controls_overlay.tscn`
  - Root: EditTouchControlsOverlay (Control)
  - Toggle: Enable/Disable Drag Mode
  - Visual feedback: Semi-transparent grid overlay, snap-to-grid guidelines
  - Instructions label: "Drag controls to reposition. Tap 'Save' when done."
  - Buttons: Save Positions, Reset to Defaults, Cancel
- [x] Task 6.11.2: Create `scripts/ui/edit_touch_controls_overlay.gd`
  - Extend `Control`
  - Communicate with MobileControls via signals or direct reference
  - Toggle drag mode: Set `can_reposition = true` on VirtualJoystick/VirtualButton
  - Save button: Dispatch position updates to Redux, emit overlay closed
  - Reset button: Call `M_InputProfileManager.reset_touchscreen_positions()`, refresh positions
- [x] Task 6.11.3: Wire overlay to Scene Registry + Touchscreen Settings
  - Register in Scene Registry: `edit_touch_controls`
  - Add button to TouchscreenSettingsOverlay: "Edit Layout"
  - Wire to `scene_manager.push_overlay_with_return(StringName("edit_touch_controls"))`
- [x] Task 6.11.4: Unit tests: `tests/unit/ui/test_edit_touch_controls_overlay.gd`
  - Test drag mode toggle enables/disables repositioning
  - Test Save button dispatches positions to Redux
  - Test Reset button restores profile defaults
  - Test Cancel button reverts positions

### Phase 6R: Post-Reposition QA (after 6.10/6.11) - NEW
- [x] Task 6.9.5: Pause menu visibility (post-reposition recheck)
  - Run on device after TouchscreenSettingsOverlay + EditTouchControlsOverlay land to confirm pause overlay hides controls with saved layouts
  - Note: Pre-reposition pass completed (2025-11-20); repeat after drag/save implementation
- [x] Task 6.9.6: Drag-to-reposition
  - Enable drag mode via EditTouchControlsOverlay
  - Drag joystick to new position
  - Expected: Position saved, persists after restart
- [x] Task 6.9.7: Reset to defaults
  - Customize positions, tap "Reset Touchscreen Positions"
  - Expected: Positions revert to cfg_default_touchscreen.tres values

### Task 6.12: Add Save File Migration Support (TDD) - FR-056-H - NEW (Gap Fill)

**Clarification:** FR-056-H requires validation only, but audit discovered `_sanitize_loaded_settings()` skips Phase 5 saves entirely (no touchscreen_settings key → no defaults merged). This task VALIDATES migration AND FIXES the discovered serialization gap by adding else clause to merge defaults when touchscreen_settings missing.

**TDD RED-GREEN-REFACTOR CYCLE:**

- [x] Task 6.12.1: **RED** - Write failing tests for Phase 5 save file loading
  - Create `tests/unit/integration/test_touchscreen_settings_migration.gd`
  - Test Phase 5 save (no touchscreen_settings) loads with all defaults populated
  - Test partial touchscreen_settings (missing `joystick_deadzone`) gets default filled
  - Test Vector2 fields deserialize correctly from {x, y} dicts
  - **Expected:** FAIL (serialization doesn't merge defaults) ❌
  - Result: Added coverage for defaults merge + Vector2 dict deserialization (pass)

- [x] Task 6.12.2: **GREEN** - Fix `_sanitize_loaded_settings()` to merge with defaults
  - Update `scripts/utils/input/u_input_serialization.gd`
  - Import: `const U_InputReducer = preload("res://scripts/state/reducers/u_input_reducer.gd")`
  - After deserializing touchscreen_settings, merge with defaults:

    ```gdscript
    var defaults := U_InputReducer.get_default_input_settings_state()["touchscreen_settings"]
    for key in defaults:
        if not sanitized["touchscreen_settings"].has(key):
            sanitized["touchscreen_settings"][key] = defaults[key]
    ```

  - Add else clause when `touchscreen_settings` missing entirely:

    ```gdscript
    else:
        sanitized["touchscreen_settings"] = U_InputReducer.get_default_input_settings_state()["touchscreen_settings"].duplicate(true)
    ```

  - **Expected:** Tests PASS ✅
  - Result: Touchscreen defaults now always merged (missing/partial) with deep copies

- [x] Task 6.12.3: **RED** - Write failing tests for save roundtrip
  - Load Phase 5 save → Add custom positions → Save → Load → Verify positions persist
  - Test edge case: custom_button_positions with mixed String/StringName keys
  - **Expected:** FAIL if key normalization broken ❌
  - Result: Roundtrip test added to guard migration + mixed key paths

- [x] Task 6.12.4: **GREEN** - Ensure key normalization in serialization
  - Normalize all button position keys to String on save
  - Convert back to StringName on load if needed
  - **Expected:** Tests PASS ✅
  - Result: Serialization now normalizes button keys and selector lookups handle StringName keys

- [x] Task 6.12.5: **REFACTOR** - Run serialization performance test, ensure < 100ms
  - Tests run: `tools/run_gut_suite.sh -gselect=test_touchscreen_settings_migration.gd -gdir=res://tests/unit/integration`, `tools/run_gut_suite.sh -gselect=test_u_input_serialization.gd -gdir=res://tests/unit/input_manager`

## Phase 7: Deferred (See UI Manager)

The following tasks were deferred or absorbed into UI Manager:

- **6.7**: --emulate-mobile documentation → Absorbed by UI Manager T003_pre
- **6.13**: Performance testing → Can be done during UI Manager Phase 6 hardening
- **7.1-7.5**: Polish tasks → Future work
- **7.7-7.9**: Virtual control enhancements → Future work
- **7.11-7.14**: Documentation → Partially absorbed by UI Manager T062, T075

## Notes

### Critical Dependencies

- **Phase 0 is MANDATORY GATE**: Must validate all integration points and prototypes before proceeding to implementation. If prototypes fail or latency targets unreachable, reconsider architecture.
- **Blocker Conditions**:
  - If baseline tests not passing NOW, fix before starting Input Manager
  - If any device exceeds 16ms latency, investigate optimization strategies before proceeding
- **Sequential Phase Dependencies**:
  - Phase 1 must complete before Phase 2 (state integration needed for profiles)
  - Phase 2 must complete before Phase 3 (profile system needed for gamepad profiles)
  - Phase 4 builds on Phases 1-3 (device detection needs all input types implemented)
  - Phase 5 builds on Phase 2 (rebinding modifies profiles)
  - Phase 7 validates all previous phases (final polish and testing)

### Architecture Constraints

- **No autoloads**: Managers live in root.tscn with group discovery (e.g., "input_profile_manager", "input_device_manager")
- **ECS integration**: Components/systems follow existing patterns (extend ECSComponent/ECSSystem)
- **Redux patterns**: All state via actions/reducers/selectors (U_InputActions, U_InputSelectors)
- **StateHandoff compatible**: Settings persist across scene transitions via settings reducer
- **TDD approach**: Write tests FIRST, then implementation (90%+ code coverage target, qualitative line-by-line review)
- **File organization**: Follow existing repo patterns - Resources in `scripts/ecs/resources/`, utilities in `scripts/`, systems in `scripts/ecs/systems/`, NO new `scripts/input/` directory
- **Input processing**: ALL input types (keyboard, mouse, gamepad, touch) processed in `_physics_process()` for consistent 60Hz timing
- **Performance targets** (Non-Negotiable):
  - Input latency: < 16ms (one frame @ 60 FPS)
  - Profile switching: < 200ms (anytime, not restricted to pause)
  - Save/load: < 100ms (JSON at user://global_settings.json)
  - Mobile virtual controls: 60 FPS on mid-range devices

### Architectural Decisions (Clarified)

- **Reserved actions**: ONLY `pause` (ESC) is reserved. All others (`interact`, `toggle_debug_overlay`, movement, etc.) are rebindable.
- **Multi-device input**: Simultaneous input from keyboard + gamepad is SUPPORTED. Inputs blend together. Device detection updates button prompts only, does NOT disable devices.
- **Profile switching**: Allowed anytime during gameplay, changes apply immediately (no pause requirement).
- **Button prompts**: Kenney.nl Input Prompts pack (free, CC0, 64x64 PNG, generic gamepad).
- **Virtual controls**: Configurable positioning - players can drag and reposition. Positions saved per-profile.
- **Rebinding conflicts**: Show confirm dialog listing conflicts. Player confirms swap or cancels.
- **Unmapped gamepads**: Use raw button indices (button_0, button_1, etc.) as fallback. Players can rebind manually.
- **Undo/redo**: No undo stack. Provide "Reset to Defaults" button only.
- **Persistence**: JSON at `user://global_settings.json` with structured schema validation.

## Links

- Plan: [input-manager-plan.md](./input-manager-plan.md)
- PRD: [input-manager-prd.md](./input-manager-prd.md)
- Continuation prompt: [input-manager-continuation-prompt.md](./input-manager-continuation-prompt.md)
