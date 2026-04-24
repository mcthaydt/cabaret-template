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
7. `M_VCamManager`
8. `M_VFXManager`
9. `M_CharacterLightingManager`
10. `M_AudioManager`
11. `M_DisplayManager`
12. `M_LocalizationManager`
13. `M_ScreenshotCacheManager`
14. `M_InputProfileManager`
15. `M_InputDeviceManager`
16. `M_UIInputHandler`
17. `M_SaveManager`
18. `M_ObjectivesManager`
19. `M_RunCoordinatorManager`
20. `M_SceneDirectorManager`

`scripts/root.gd` registers the persistent manager services, root-level containers, and viewport nodes into `U_ServiceLocator`, then validates declared dependencies. `M_ScreenshotCacheManager` self-registers as `screenshot_cache`.

---

## Service Locator Services

`scripts/root.gd` registers these manager services:

- `state_store` -> `M_StateStore`
- `cursor_manager` -> `M_CursorManager`
- `scene_manager` -> `M_SceneManager`
- `time_manager` -> `M_TimeManager`
- `pause_manager` -> `M_TimeManager` (backward-compat alias)
- `spawn_manager` -> `M_SpawnManager`
- `camera_manager` -> `M_CameraManager`
- `vcam_manager` -> `M_VCamManager`
- `vfx_manager` -> `M_VFXManager`
- `character_lighting_manager` -> `M_CharacterLightingManager`
- `audio_manager` -> `M_AudioManager`
- `display_manager` -> `M_DisplayManager`
- `localization_manager` -> `M_LocalizationManager`
- `input_profile_manager` -> `M_InputProfileManager`
- `input_device_manager` -> `M_InputDeviceManager`
- `ui_input_handler` -> `M_UIInputHandler`
- `save_manager` -> `M_SaveManager`
- `objectives_manager` -> `M_ObjectivesManager`
- `run_coordinator` -> `M_RunCoordinatorManager`
- `scene_director` -> `M_SceneDirectorManager`

It also registers these root/container services:

- `hud_layer`
- `ui_overlay_stack`
- `transition_overlay`
- `loading_overlay`
- `game_viewport`
- `active_scene_container`
- `post_process_overlay`

Self-registering services:

- `screenshot_cache` -> `M_ScreenshotCacheManager`

---

## Service Locator Dependency Declarations

`U_ServiceLocator` dependency declarations are registered by `root.gd` at startup and validated with `U_ServiceLocator.validate_all()`:

- `time_manager` → `state_store`, `cursor_manager`
- `spawn_manager` → `state_store`
- `scene_manager` → `state_store`
- `camera_manager` → `state_store`
- `vcam_manager` → `state_store`, `camera_manager`
- `vfx_manager` → `state_store`, `camera_manager`
- `character_lighting_manager` → `scene_manager`, `camera_manager`
- `audio_manager` → `state_store`
- `display_manager` → `state_store`
- `localization_manager` → `state_store`
- `input_profile_manager` → `state_store`
- `input_device_manager` → `state_store`
- `save_manager` → `state_store`, `scene_manager`
- `objectives_manager` → `state_store`
- `run_coordinator` → `state_store`, `objectives_manager`
- `scene_director` → `state_store`, `objectives_manager`

---

## ECS ↔ Manager Dependencies (Runtime)

### ECS → Managers

- `C_SceneTriggerComponent` → `scene_manager` (calls `transition_to_scene(...)` via `U_ServiceLocator.try_get_service()`)
- `S_InputSystem` → `input_device_manager` (selects active `I_InputSource` via `U_ServiceLocator.try_get_service()`)
- `S_TouchscreenSystem` → `input_device_manager` (guards touchscreen processing by active device)
- `S_VCamSystem` / `C_VCamComponent` → `vcam_manager` (active vCam selection, blending, evaluated camera submission)
- `S_CameraStateSystem` → `camera_manager` (camera shake/FOV state application)
- `S_SpawnRecoverySystem` → `spawn_manager` (recovery spawn routing)
- ECS VFX/SFX publishers → `vfx_manager` / `audio_manager` through shared spawner/audio utilities

### Managers → ECS

- `M_SceneManager` owns the scene lifecycle and indirectly controls per-scene ECS by loading/unloading gameplay scenes (each with its own `M_ECSManager`).
- `M_SpawnManager` applies spawn transforms to the player entity on scene load.
- `M_VCamManager` receives evaluated camera state from `S_VCamSystem`.
- `M_CameraManager` receives camera effects from `S_CameraStateSystem`.
- `M_VFXManager` and `M_AudioManager` service ECS-triggered effects, with state gating handled by selectors.

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
    CameraManager[M_CameraManager]
    VCamManager[M_VCamManager]
    VFXManager[M_VFXManager]
    AudioManager[M_AudioManager]
    InputDeviceManager[M_InputDeviceManager]
    UIInputHandler[M_UIInputHandler]
    ObjectivesManager[M_ObjectivesManager]
    SceneDirector[M_SceneDirectorManager]
  end

  subgraph GameplayScene[Gameplay Scene (child of ActiveSceneContainer)]
    ECSManager[M_ECSManager]
    CharacterStateSystem[S_CharacterStateSystem]
    CameraStateSystem[S_CameraStateSystem]
    VCamSystem[S_VCamSystem]
    InputSystem[S_InputSystem]
    MovementSystem[S_MovementSystem]
    JumpSystem[S_JumpSystem]
    RotateSystem[S_RotateToInputSystem]
    GravitySystem[S_GravitySystem]
    TouchSystem[S_TouchscreenSystem]
    GameEventSystem[S_GameEventSystem]
    VictoryHandler[S_VictoryHandlerSystem]
    CheckpointHandler[S_CheckpointHandlerSystem]
    HealthSystem[S_HealthSystem]
    SceneTriggerComponent[C_SceneTriggerComponent]
    VibrationSystem[S_GamepadVibrationSystem]
    PlaytimeSystem[S_PlaytimeSystem]
    AIDetectionSystem[S_AIDetectionSystem]
  end

  CharacterStateSystem -->|reads state for QB rule context| Store
  CameraStateSystem -->|reads vCam state for QB rule context| Store
  GameEventSystem -->|reads state for QB rule context| Store

  InputSystem -->|reads active device/settings| Store
  InputSystem -->|selects input source| InputDeviceManager
  InputSystem -->|dispatches input batch| Store

  MovementSystem -->|dispatches entity snapshots| Store
  RotateSystem -->|dispatches entity snapshots| Store
  JumpSystem -->|dispatches entity snapshots| Store
  HealthSystem -->|dispatches gameplay + entity actions| Store
  VictoryHandler -->|dispatches gameplay actions| Store
  CheckpointHandler -->|dispatches gameplay actions| Store
  TouchSystem -->|reads active device/debug guard| Store
  TouchSystem -->|dispatches input + touch-look actions| Store
  PlaytimeSystem -->|reads navigation/scene + dispatches playtime| Store
  AIDetectionSystem -->|dispatches AI demo flags| Store

  GravitySystem -->|reads physics selectors| Store
  VibrationSystem -->|subscribes + reads settings| Store
  VCamSystem -->|reads input/entity state + dispatches vCam observability| Store
  VCamSystem -->|submits evaluated cameras| VCamManager
  CameraStateSystem -->|applies camera state| CameraManager

  SceneTriggerComponent -->|dispatches spawn target| Store
  SceneTriggerComponent -->|requests transition| SceneManager

  TimeManager -->|reads scene state| Store
  SpawnManager -->|reads gameplay/scene state| Store
  UIInputHandler -->|dispatches navigation actions| Store
  SceneManager -->|dispatches scene actions| Store
  ObjectivesManager -->|dispatches objectives actions| Store
  SceneDirector -->|dispatches scene-director actions| Store
```

---

## Notes

- ECS systems that depend on state should support dependency injection via `@export var state_store: I_StateStore` for isolated testing.
- ECS systems should treat missing store as “feature disabled” (skip read/write) rather than crashing.
- `U_ServiceLocator.get_dependency_graph()` prints the live declared service dependency graph in verbose mode during root bootstrap.
