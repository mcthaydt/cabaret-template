# ECS ↔ State Contract

This document is the **single source of truth** for how ECS nodes (systems/components) interact with the Redux-style `M_StateStore`.

**Scope**: gameplay ECS systems + ECS components that directly read/dispatch state.

**Out of scope**: UI/manager → state flows (see `docs/architecture/dependency_graph.md`).

---

## Contract Rules

- **ECS writes state only via action creators** (e.g. `U_InputActions`, `U_GameplayActions`, `U_EntityActions`).
- **ECS reads state via selectors when available**; direct dictionary reads are allowed only when no selector exists yet.
- **Null store is not an error in tests**: systems may run without a store (or use injected `@export var state_store: I_StateStore`).
- **State immutability**: ECS must never mutate dictionaries returned by `store.get_state()` / `store.get_slice()` (duplicate before mutation).

---

## ECS → State (Write Dependencies)

### Input slice (`U_InputActions`)

| Producer | Action(s) | Dispatch cadence | Notes |
|---|---|---|---|
| `S_InputSystem` | `U_InputActions.update_move_input(Vector2)` | per physics tick | Always dispatches when store exists; sourced from active `I_InputSource`. |
| `S_InputSystem` | `U_InputActions.update_look_input(Vector2)` | per physics tick | Mouse delta / right-stick. |
| `S_InputSystem` | `U_InputActions.update_jump_state(bool, bool)` | per physics tick | `(pressed, just_pressed)` form. |
| `S_InputSystem` | `U_InputActions.update_sprint_state(bool)` | per physics tick | Supports accessibility sprint toggle via settings. |
| `S_TouchscreenSystem` | `U_InputActions.update_move_input(Vector2)` | per physics tick (touchscreen active) | Only runs when active device is touchscreen. |
| `S_TouchscreenSystem` | `U_InputActions.update_jump_state(bool, bool)` | per physics tick (touchscreen active) | Button-derived jump edge detection. |
| `S_TouchscreenSystem` | `U_InputActions.update_sprint_state(bool)` | per physics tick (touchscreen active) | Touch sprint button. |

### Gameplay slice (`U_GameplayActions`)

| Producer | Action(s) | Dispatch cadence | Required payload fields (contract) |
|---|---|---|---|
| `S_CheckpointHandlerSystem` | `U_GameplayActions.set_last_checkpoint(StringName)` | on `checkpoint_activation_requested` | `spawn_point_id` |
| `C_SceneTriggerComponent` | `U_GameplayActions.set_target_spawn_point(StringName)` | on door trigger | `target_spawn_point` |
| `S_HealthSystem` | `U_GameplayActions.take_damage(String, float)` | on applied damage | `entity_id`, `amount` |
| `S_HealthSystem` | `U_GameplayActions.heal(String, float)` | on applied healing | `entity_id`, `amount` |
| `S_HealthSystem` | `U_GameplayActions.increment_death_count()` | first death per entity_id | increments once per death sequence |
| `S_HealthSystem` | `U_GameplayActions.trigger_death(String)` | on death | `entity_id` |
| `S_VictoryHandlerSystem` | `U_GameplayActions.trigger_victory(StringName)` | on `victory_execution_requested` | `objective_id` |
| `S_VictoryHandlerSystem` | `U_GameplayActions.mark_area_complete(StringName)` | on `victory_execution_requested` | `area_id` |
| `S_VictoryHandlerSystem` | `U_GameplayActions.game_complete()` | on final victory execution | no payload |

### Entity coordination slice (`U_EntityActions`)

These actions are the **bridge** for persisting ECS-derived snapshots into Redux state.

| Producer | Action(s) | Dispatch cadence | Snapshot keys written |
|---|---|---|---|
| `S_MovementSystem` | `U_EntityActions.update_entity_snapshot(String, Dictionary)` | per physics tick (for bodies processed) | `position`, `velocity`, `rotation`, `is_moving`, `entity_type`, (optional) `is_on_floor` |
| `S_RotateToInputSystem` | `U_EntityActions.update_entity_snapshot(String, Dictionary)` | when rotating | `rotation` |
| `S_JumpSystem` | `U_EntityActions.update_entity_snapshot(String, Dictionary)` | on jump / land transitions | `is_on_floor` |
| `S_HealthSystem` | `U_EntityActions.update_entity_snapshot(String, Dictionary)` | per tick when store exists | `health`, `max_health`, `is_dead` |

---

## State → ECS (Read Dependencies)

### Pause gating (`U_GameplaySelectors`)

| Consumer | Read | Effect |
|---|---|---|
| `S_InputSystem` | `U_GameplaySelectors.get_is_paused(store.get_slice("gameplay"))` | Skips input capture when paused. |
| `S_MovementSystem` | `U_GameplaySelectors.get_is_paused(store.get_slice("gameplay"))` | Skips movement simulation when paused. |
| `S_JumpSystem` | `U_GameplaySelectors.get_is_paused(store.get_slice("gameplay"))` | Skips jumping when paused. |
| `S_RotateToInputSystem` | `U_GameplaySelectors.get_is_paused(store.get_slice("gameplay"))` | Skips rotation updates when paused. |
| `S_GravitySystem` | `U_GameplaySelectors.get_is_paused(store.get_slice("gameplay"))` | Skips gravity when paused. |

### Active input device + tuning (`U_InputSelectors`)

| Consumer | Read | Effect |
|---|---|---|
| `S_InputSystem` | `U_InputSelectors.get_active_device_type(state)` | Selects which `I_InputSource` captures input. |
| `S_InputSystem` | `U_InputSelectors.get_active_gamepad_id(state)` | Writes device_id into `C_GamepadComponent`. |
| `S_InputSystem` | `U_InputSelectors.is_gamepad_connected(state)` | Writes connection status to `C_GamepadComponent`. |
| `S_InputSystem` | `U_InputSelectors.get_mouse_settings(state)` | Mouse sensitivity/scaling for look. |
| `S_InputSystem` | `U_InputSelectors.get_gamepad_settings(state)` | Applies deadzones/sensitivity to `C_GamepadComponent`. |
| `S_GamepadVibrationSystem` | `U_InputSelectors.get_gamepad_settings(state)` | Gates vibration + applies intensity multiplier. |

### Debug + platform guards

| Consumer | Read | Effect |
|---|---|---|
| `S_TouchscreenSystem` | `U_DebugSelectors.is_touchscreen_disabled(state)` | Emergency kill-switch for touch controls. |

### Physics/visual settings

| Consumer | Read | Effect |
|---|---|---|
| `S_GravitySystem` | `U_PhysicsSelectors.get_gravity_scale(state)` | Applies zone-driven gravity multipliers. |
| `S_LandingIndicatorSystem` | `U_VisualSelectors.should_show_landing_indicator(state)` | Toggles landing indicator visibility. |

### Direct state reads (no selector yet)

These reads are part of the contract until replaced by selectors.

| Consumer | Read path | Usage |
|---|---|---|
| `S_JumpSystem` | `state.settings.input_settings.accessibility.jump_buffer_time` | Increases jump buffer for accessibility. |
| `S_HealthSystem` | `store.get_slice("gameplay").player_entity_id` | Determines which entity is the player. |
| `S_HealthSystem` | `store.get_slice("gameplay").player_health` | One-time sync so health persists across gameplay scenes. |
| `S_VictoryHandlerSystem` | `state.gameplay.completed_areas` | Guards `GAME_COMPLETE` victory until required area completed. |
| `C_SceneTriggerComponent` | `store.get_slice("scene").is_transitioning` | Blocks door triggers during transitions. |
| `C_SceneTriggerComponent` | `state.scene.current_scene_id` | Door pairing lookup via `U_SceneRegistry`. |

---

## Testing Notes

- Systems that declare `@export var state_store: I_StateStore` should inject `tests/mocks/mock_state_store.gd` in unit tests.
- Prefer verifying **actions dispatched** (shape + type) over asserting on internal state dictionaries.
