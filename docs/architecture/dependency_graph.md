# Dependency Graph (Managers, ECS, State)

This document visualizes **initialization order** and **runtime dependencies** between core managers, ECS, and Redux state.

---

## Manager Initialization Order (`scenes/root.tscn`)

The root scene persists across the whole session. Manager ordering in the scene tree is intentional because some managers read/dispatch state during `_ready()`.

1. `M_StateStore`
2. `M_CursorManager`
3. `M_SceneManager`
4. `M_TimeManager`
5. `M_SpawnManager`
6. `M_CameraManager`
7. `M_InputProfileManager`
8. `M_InputDeviceManager`
9. `M_UIInputHandler`

`scripts/root.gd` registers these into `U_ServiceLocator` and validates declared dependencies.

---

## Service Locator Dependencies

`U_ServiceLocator` dependency declarations are registered by `root.gd` at startup:

- `time_manager` → `state_store`, `cursor_manager`
- `spawn_manager` → `state_store`
- `scene_manager` → `state_store`
- `camera_manager` → `state_store`
- `input_profile_manager` → `state_store`
- `input_device_manager` → `state_store`

`pause_manager` remains a backward-compat ServiceLocator alias that resolves to the same `M_TimeManager` instance.

---

## ECS ↔ Manager Dependencies (Runtime)

### ECS → Managers

- `C_SceneTriggerComponent` → `scene_manager` (calls `transition_to_scene(...)` via `U_ServiceLocator.get_service()`)
- `S_InputSystem` → `input_device_manager` (selects active `I_InputSource` via `U_ServiceLocator.try_get_service()`)

### Managers → ECS

- `M_SceneManager` owns the scene lifecycle and indirectly controls per-scene ECS by loading/unloading gameplay scenes (each with its own `M_ECSManager`).
- `M_SpawnManager` applies spawn transforms to the player entity on scene load.

---

## ECS ↔ State Dependencies (Runtime)

This is the “shape” of the main control loop once a gameplay scene is loaded.

```mermaid
flowchart TD
  subgraph RootScene[Root (scenes/root.tscn)]
    Store[M_StateStore]
    SceneManager[M_SceneManager]
    TimeManager[M_TimeManager]
    SpawnManager[M_SpawnManager]
    InputDeviceManager[M_InputDeviceManager]
    UIInputHandler[M_UIInputHandler]
  end

  subgraph GameplayScene[Gameplay Scene (child of ActiveSceneContainer)]
    ECSManager[M_ECSManager]
    InputSystem[S_InputSystem]
    MovementSystem[S_MovementSystem]
    JumpSystem[S_JumpSystem]
    RotateSystem[S_RotateToInputSystem]
    GravitySystem[S_GravitySystem]
    TouchSystem[S_TouchscreenSystem]
    VictorySystem[S_VictorySystem]
    CheckpointSystem[S_CheckpointSystem]
    HealthSystem[S_HealthSystem]
    SceneTriggerComponent[C_SceneTriggerComponent]
    VibrationSystem[S_GamepadVibrationSystem]
  end

  InputSystem -->|reads active device| Store
  InputSystem -->|selects input source| InputDeviceManager
  InputSystem -->|dispatches input actions| Store

  MovementSystem -->|dispatches entity snapshots| Store
  RotateSystem -->|dispatches entity snapshots| Store
  JumpSystem -->|dispatches entity snapshots| Store
  HealthSystem -->|dispatches gameplay + entity actions| Store
  VictorySystem -->|dispatches gameplay actions| Store
  CheckpointSystem -->|dispatches gameplay actions| Store
  TouchSystem -->|dispatches input actions| Store

  GravitySystem -->|reads physics selectors| Store
  VibrationSystem -->|subscribes + reads settings| Store

  SceneTriggerComponent -->|dispatches spawn target| Store
  SceneTriggerComponent -->|requests transition| SceneManager

  TimeManager -->|reads scene state| Store
  SpawnManager -->|reads gameplay/scene state| Store
  UIInputHandler -->|dispatches navigation actions| Store
  SceneManager -->|dispatches scene actions| Store
```

---

## Notes

- ECS systems that depend on state should support dependency injection via `@export var state_store: I_StateStore` for isolated testing.
- ECS systems should treat missing store as “feature disabled” (skip read/write) rather than crashing.
