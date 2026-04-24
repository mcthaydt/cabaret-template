# ECS ↔ State Contract

This document is the **single source of truth** for how ECS nodes (systems/components) interact with the Redux-style `M_StateStore`.

**Scope**: gameplay ECS systems, ECS components, ECS rule contexts, and ECS-owned helper resources that directly read/dispatch state.

**Out of scope**: UI/manager → state flows (see `docs/architecture/dependency_graph.md`).

---

## Contract Rules

- **ECS writes state via action creators** (e.g. `U_InputActions`, `U_GameplayActions`, `U_EntityActions`) unless a configured QB rule explicitly uses `RS_EffectDispatchAction`.
- **QB rule effects may dispatch only through `RS_EffectDispatchAction`** with `state_store` supplied by an ECS rule context; prefer action creators for scripted ECS systems.
- **ECS reads state via selectors when available**; direct dictionary reads are allowed only when no selector exists yet.
- **Null store is not an error in tests**: systems may run without a store (or use injected `@export var state_store: I_StateStore`).
- **State immutability**: ECS must never mutate dictionaries returned by `store.get_state()` / `store.get_slice()` (duplicate before mutation).

---

## ECS → State (Write Dependencies)

### Input slice (`U_InputActions`)

| Producer | Action(s) | Dispatch cadence | Notes |
|---|---|---|---|
| `S_InputSystem` | `U_InputActions.update_input_batch(...)` | per physics tick | Writes move, look, jump, sprint, camera-center, active-device, and look-source fields in one action. |
| `S_TouchscreenSystem` | `U_InputActions.update_move_input(Vector2)` | per physics tick (touchscreen active) | Only runs when active device is touchscreen. |
| `S_TouchscreenSystem` | `U_InputActions.update_look_input(Vector2, LOOK_SOURCE_TOUCHSCREEN)` | per physics tick (touchscreen active) | Touch look delta. |
| `S_TouchscreenSystem` | `U_InputActions.update_jump_state(bool, bool)` | per physics tick (touchscreen active) | Button-derived jump edge detection. |
| `S_TouchscreenSystem` | `U_InputActions.update_sprint_state(bool)` | per physics tick (touchscreen active) | Touch sprint button. |
| `S_TouchscreenSystem` | `U_InputActions.update_camera_center_state(bool)` | per physics tick (touchscreen active) | Consumes one-shot recenter requests from `UI_MobileControls` empty-space double-tap input. |

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
| `S_TouchscreenSystem` | `U_GameplayActions.set_touch_look_active(bool)` | when touch-look active changes | `active` |
| `S_AIDetectionSystem` | `U_GameplayActions.set_ai_demo_flag(StringName, bool)` | on configured detection enter/exit | `flag_id`, `value` |
| `S_PlaytimeSystem` | `U_GameplayActions.increment_playtime(int)` | once per accumulated whole second while gameplay is active | `seconds` |

### Entity coordination slice (`U_EntityActions`)

These actions are the **bridge** for persisting ECS-derived snapshots into Redux state.

| Producer | Action(s) | Dispatch cadence | Snapshot keys written |
|---|---|---|---|
| `S_MovementSystem` | `U_EntityActions.update_entity_snapshots(Dictionary)` | per physics tick (batched for bodies processed) | `position`, `velocity`, `rotation`, `is_moving`, `entity_type`, (optional) `is_on_floor` |
| `S_RotateToInputSystem` | `U_EntityActions.update_entity_snapshot(String, Dictionary)` | when rotating | `rotation` |
| `S_JumpSystem` | `U_EntityActions.update_entity_snapshot(String, Dictionary)` | on jump / land transitions | `is_on_floor` |
| `S_HealthSystem` | `U_EntityActions.update_entity_snapshot(String, Dictionary)` | per tick when store exists | `health`, `max_health`, `is_dead` |
| `RS_AIActionFeed` | `U_EntityActions.remove_entity(StringName)` | when a feed target is consumed | `entity_id` |

### vCam slice (`U_VCamActions`)

| Producer | Action(s) | Dispatch cadence | Notes |
|---|---|---|---|
| `S_VCamSystem` via `U_VCamRuntimeState` | `U_VCamActions.update_target_validity(bool)` | when active target validity changes | Observability for active vCam target health. |
| `S_VCamSystem` via `U_VCamRuntimeState` | `U_VCamActions.record_recovery(String)` | when a target recovery reason changes | Records recovery reason and clears active vCam through `M_VCamManager`. |

### Rule-dispatched actions (`RS_EffectDispatchAction`)

| Producer | Action(s) | Dispatch cadence | Notes |
|---|---|---|---|
| `S_CharacterStateSystem` rule context | configured `action_type` | tick or matching ECS event, depending on rule trigger | Character QB rules may dispatch only through `RS_EffectDispatchAction`. |
| `S_CameraStateSystem` rule context | configured `action_type` | tick or matching ECS event, depending on rule trigger | Camera QB rules may dispatch only through `RS_EffectDispatchAction`. |
| `S_GameEventSystem` rule context | configured `action_type` | tick or matching ECS event, depending on rule trigger | Game QB rules may dispatch only through `RS_EffectDispatchAction`; publish-event effects remain ECS events, not Redux actions. |

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
| `S_InputSystem` | `U_GameplaySelectors.is_touch_look_active(state)` | Suppresses non-touch look capture while touch look is active. |
| `S_PlaytimeSystem` | `U_NavigationSelectors.is_paused(navigation_slice)` | Skips playtime accumulation while paused. |

### Active input device + tuning (`U_InputSelectors`)

| Consumer | Read | Effect |
|---|---|---|
| `S_InputSystem` | `U_InputSelectors.get_active_device_type(state)` | Selects which `I_InputSource` captures input. |
| `S_InputSystem` | `U_InputSelectors.get_active_gamepad_id(state)` | Writes device_id into `C_GamepadComponent`. |
| `S_InputSystem` | `U_InputSelectors.is_gamepad_connected(state)` | Writes connection status to `C_GamepadComponent`. |
| `S_InputSystem` | `U_InputSelectors.get_mouse_settings(state)` | Mouse sensitivity/scaling for look. |
| `S_InputSystem` | `U_InputSelectors.get_gamepad_settings(state)` | Applies deadzones/sensitivity to `C_GamepadComponent`. |
| `S_InputSystem` | `U_InputSelectors.get_active_profile_id(state)` | Debug input source labeling. |
| `S_GamepadVibrationSystem` | `U_InputSelectors.get_gamepad_settings(state)` | Gates vibration + applies intensity multiplier. |
| `S_GamepadVibrationSystem` | `U_InputSelectors.get_input_state_snapshot(state)` | Tracks latest input state for vibration guard logic. |
| `S_TouchscreenSystem` | `U_InputSelectors.get_active_device_type(state)` | Runs only when touchscreen is the active input device. |
| `S_VCamSystem` via `U_VCamRuntimeState` | `U_InputSelectors.get_look_input(state)` | Camera orbit/look input. |
| `S_VCamSystem` via `U_VCamRuntimeState` | `U_InputSelectors.get_move_input(state)` | Camera look-ahead/follow effects. |
| `S_VCamSystem` via `U_VCamRuntimeState` | `U_InputSelectors.is_camera_center_just_pressed(state)` | Camera recenter trigger. |

### Debug + platform guards

| Consumer | Read | Effect |
|---|---|---|
| `S_TouchscreenSystem` | `U_DebugSelectors.is_touchscreen_disabled(state)` | Emergency kill-switch for touch controls. |

### Physics/visual settings

| Consumer | Read | Effect |
|---|---|---|
| `S_GravitySystem` | `U_PhysicsSelectors.get_gravity_scale(state)` | Applies zone-driven gravity multipliers. |
| `S_LandingIndicatorSystem` | `U_VisualSelectors.should_show_landing_indicator(state)` | Toggles landing indicator visibility. |
| `U_ParticleSpawner` | `U_VFXSelectors.is_particles_enabled(state)` | Gates ECS-triggered particles. |
| `BaseEventSFXSystem` | `U_GameplaySelectors.get_is_paused(state)` | Blocks ECS-triggered audio while paused. |
| `BaseEventSFXSystem` | `U_SceneSelectors.is_transitioning(state)` | Blocks ECS-triggered audio during scene transitions. |
| `BaseEventSFXSystem` | `U_NavigationSelectors.get_shell(state)` | Blocks ECS-triggered audio outside the gameplay shell. |

### Entity and vCam snapshots

| Consumer | Read | Effect |
|---|---|---|
| `S_GamepadVibrationSystem` | `U_EntitySelectors.get_player_entity_id(state)` | Applies damage vibration only to the player entity. |
| `S_VCamSystem` / helpers | `U_EntitySelectors.get_entity(state, entity_id)` | Resolves follow targets and debug data from entity snapshots. |
| `S_CameraStateSystem` | `U_VCamSelectors.get_active_mode(state)` | Supplies camera QB rule context. |
| `S_CameraStateSystem` | `U_VCamSelectors.is_blending(state)` | Supplies camera QB rule context. |
| `S_CameraStateSystem` | `U_VCamSelectors.get_active_vcam_id(state)` | Supplies camera QB rule context. |

### Objective and progress reads

| Consumer | Read | Effect |
|---|---|---|
| `S_VictoryHandlerSystem` | `U_GameplaySelectors.get_completed_areas(state)` | Guards `GAME_COMPLETE` victory until required area completed. |
| `S_VictoryHandlerSystem` | `U_GameplaySelectors.get_game_completed(state)` | Avoids duplicate game-complete handling. |
| `S_VictoryHandlerSystem` | `U_GameplaySelectors.get_last_victory_objective(state)` | Debug/logging context for victory handling. |
| `S_VictoryHandlerSystem` | `U_ObjectivesSelectors.get_statuses_snapshot(state)` | Debug/logging context for objectives state. |
| `S_VictoryHandlerSystem` | `U_ObjectivesSelectors.get_active_set_id(state)` | Debug/logging context for objectives state. |

### Rule context state snapshots

| Consumer | Read | Effect |
|---|---|---|
| `S_AIBehaviorSystem` | `get_frame_state_snapshot()` / resolved `state_store` | Supplies Redux state and store to BT/AI action contexts. |
| `S_CharacterStateSystem` | `get_frame_state_snapshot()` / resolved `state_store` | Supplies Redux state and store to character QB rule conditions/effects. |
| `S_CameraStateSystem` | `get_frame_state_snapshot()` / resolved `state_store` | Supplies Redux state and store to camera QB rule conditions/effects. |
| `S_GameEventSystem` | `store.get_state()` | Supplies Redux state and store to game-event QB rule conditions/effects. |

### Navigation and scene guards

| Consumer | Read | Effect |
|---|---|---|
| `S_PlaytimeSystem` | `state.navigation.shell` | Tracks playtime only in gameplay shell. |
| `S_PlaytimeSystem` | `state.scene.is_transitioning` | Skips playtime while scene transitions. |

### Direct state reads (no selector yet)

These reads are part of the contract until replaced by selectors.

| Consumer | Read path | Usage |
|---|---|---|
| `S_JumpSystem` | `state.settings.input_settings.accessibility.jump_buffer_time` | Increases jump buffer for accessibility. |
| `S_HealthSystem` | `store.get_slice("gameplay").player_entity_id` | Determines which entity is the player. |
| `S_HealthSystem` | `store.get_slice("gameplay").player_health` | One-time sync so health persists across gameplay scenes. |
| `C_SceneTriggerComponent` | `store.get_slice("scene").is_transitioning` | Blocks door triggers during transitions. |
| `C_SceneTriggerComponent` | `state.scene.current_scene_id` | Door pairing lookup via `U_SceneRegistry`. |
| `S_WallVisibilitySystem` | full state dictionary | Resolves camera/visibility context for occlusion behavior. |
| `S_RegionVisibilitySystem` | full state dictionary | Resolves region visibility runtime state. |
| `U_ParticleSpawner` | full state dictionary | Reads particle/VFX settings before spawning. |

---

## Testing Notes

- Systems that declare `@export var state_store: I_StateStore` should inject `tests/mocks/mock_state_store.gd` in unit tests.
- Prefer verifying **actions dispatched** (shape + type) over asserting on internal state dictionaries.
