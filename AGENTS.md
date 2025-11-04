# Agents Notes

## Start Here

- Project type: Godot 4.5 (GDScript). Core area:
  - `scripts/ecs`: Lightweight ECS built on Nodes (components + systems + manager).
- Scenes and resources:
  - `templates/`: Base scene and player scene that wire components/systems together.
  - `resources/`: Default `*Settings.tres` for component configs; update when adding new exported fields.
- Documentation to consult (do not duplicate here):
  - General pitfalls: `docs/general/DEV_PITFALLS.md`
- Before adding or modifying code, re-read `docs/general/DEV_PITFALLS.md` and `docs/general/STYLE_GUIDE.md` to stay aligned with testing and formatting requirements.
- Keep project planning docs current: whenever a story advances, update the relevant plan and PRD documents immediately so written guidance matches the implementation state.
- **MANDATORY: Update continuation prompt and tasks checklist after EVERY phase**: When completing a phase (e.g., Phase 2 of Scene Manager), you MUST:
  1. Update the continuation prompt file (e.g., `docs/scene_manager/scene-manager-continuation-prompt.md`) with current status
  2. Update the tasks file (e.g., `docs/scene_manager/scene-manager-tasks.md`) to mark completed tasks with [x] and add completion notes
  3. Update AGENTS.md with new patterns/architecture (if applicable)
  4. Update DEV_PITFALLS.md with new pitfalls discovered (if applicable)
  5. Commit documentation updates separately from implementation
- Commit at the end of each completed story (or logical, test-green milestone) so every commit represents a verified state.
- Make a git commit whenever a feature, refactor, or documentation update moves the needle forward; keep commits focused and validated. Skipping required commits is a blocker—treat the guidance as non-optional.

## Repo Map (essentials)

- `scripts/managers/m_ecs_manager.gd`: Registers components/systems; exposes `get_components(StringName)` and emits component signals.
- `scripts/managers/m_scene_manager.gd`: Scene transition coordinator (Phase 3+); manages ActiveSceneContainer.
- `scripts/state/m_state_store.gd`: Redux store; adds to "state_store" group for discovery via `U_StateUtils.get_store()`.
- `scripts/ecs/ecs_component.gd`: Base for components. Auto-registers with manager; exposes `get_snapshot()` hook.
- `scripts/ecs/ecs_system.gd`: Base for systems. Implement `process_tick(delta)`; runs via `_physics_process`.
- `scripts/ecs/components/*`: Gameplay components with `@export` NodePaths and typed getters.
- `scripts/ecs/systems/*`: Systems that query components by `StringName` and operate per-physics tick.
- `scripts/ecs/resources/*`: `Resource` classes holding tunables consumed by components/systems.
- `scenes/root.tscn`: Main scene (persistent managers + containers).
- `scenes/gameplay/*`: Gameplay scenes (dynamic loading, own M_ECSManager).
- `tests/unit/*`: GUT test suites for ECS and state management.

## ECS Guidelines

- Components
  - Extend `ECSComponent`; define `const COMPONENT_TYPE := StringName("YourComponent")` and set `component_type = COMPONENT_TYPE` in `_init()`.
  - Enforce required settings/resources by overriding `_validate_required_settings()` (call `push_error(...)` and return `false` to abort registration); use `_on_required_settings_ready()` for post-validation setup.
  - Prefer `@export` NodePaths with typed getters that use `get_node_or_null(...) as Type` and return `null` on empty paths.
  - Keep null-safe call sites; systems assume absent paths disable behavior rather than error.
  - If you expose debug state, copy via `snapshot.duplicate(true)` to avoid aliasing.
- Systems
  - Extend `ECSSystem`; implement `process_tick(delta)` (invoked from `_physics_process`).
  - Query with `get_components(StringName)`, dedupe per-body where needed, and clamp/guard values (see movement/rotation/floating examples).
  - Use `U_ECSUtils.map_components_by_body()` when multiple systems need shared body→component dictionaries (avoids duplicate loops).
  - Auto-discovers `M_ECSManager` via parent traversal or `ecs_manager` group; no manual wiring needed.
- Manager
  - Ensure exactly one `M_ECSManager` in-scene. It auto-adds to `ecs_manager` group on `_ready()`.
  - Emits `component_added`/`component_removed` and calls `component.on_registered(self)`.
  - `get_components()` strips out null entries automatically; only guard for missing components when logic truly requires it.

## Scene Organization

- **Root scene pattern (NEW - Phase 2)**: `scenes/root.tscn` persists throughout session
  - Persistent managers: `M_StateStore`, `M_CursorManager`, `M_SceneManager`
  - Scene containers: `ActiveSceneContainer`, `UIOverlayStack`, `TransitionOverlay`, `LoadingOverlay`
  - Gameplay scenes load/unload as children of `ActiveSceneContainer`
- **Gameplay scenes**: Each has own `M_ECSManager` instance
  - Example: `scenes/gameplay/gameplay_base.tscn`
  - Contains: Systems, Entities, SceneObjects, Environment
  - HUD uses `U_StateUtils.get_store(self)` to find M_StateStore via "state_store" group
- Node tree structure: See `docs/scene_organization/SCENE_ORGANIZATION_GUIDE.md`
- Templates: `templates/base_scene_template.tscn` (legacy reference), `templates/player_template.tscn`
- Marker scripts: `scripts/scene_structure/*` (11 total) provide visual organization
- Systems organized by category: Core / Physics / Movement / Feedback
- Naming: Node names use prefixes matching their script types (E_, S_, C_, M_, SO_, Env_)

## Naming Conventions Quick Reference

- **Base classes:** `Base*` prefix (e.g., `BaseECSSystem`, `BaseECSComponent`, `BaseEventVFXSystem`); entity roots extend `ECSEntity`
- **Utilities:** `U_*` prefix (e.g., `U_ECSUtils`, `U_BootSelectors`, `U_GameplayReducer`, `U_ActionRegistry`)
- **Managers:** `M_*` prefix (e.g., `M_ECSManager`, `M_StateStore`)
- **Components:** `C_*` prefix (e.g., `C_MovementComponent`, `C_JumpComponent`)
- **Systems:** `S_*` prefix (e.g., `S_GravitySystem`, `S_MovementSystem`)
- **Resources:** `RS_*` prefix (e.g., `RS_JumpSettings`, `RS_MovementSettings`)
- **Entities:** `E_*` prefix (e.g., `E_Player`, `E_CameraRoot`)
- **Scene Objects:** `SO_*` prefix (e.g., `SO_Floor`, `SO_Block`)

## Conventions and Gotchas

- GDScript typing
  - Annotate locals receiving Variants (e.g., from `Callable.call()`, `JSON.parse_string`, `Time.get_ticks_msec()` calc). Prefer explicit `: float`, `: int`, `: Dictionary`, etc.
  - Use `StringName` for action/component identifiers; keep constants like `const MOVEMENT_TYPE := StringName("C_MovementComponent")`.
- Time helpers
  - For ECS timing, call `U_ECSUtils.get_current_time()` (seconds) instead of repeating `Time.get_ticks_msec() / 1000.0`.
- Copy semantics
  - Use `.duplicate(true)` for deep copies of `Dictionary`/`Array` before mutating; the codebase relies on immutability patterns both in ECS snapshots and state.
- Scenes and NodePaths
  - Wire `@export` NodePaths in scenes; missing paths intentionally short-circuit behavior in systems. See `templates/player_template.tscn` for patterns.
- Resources
  - New exported fields in `*Settings.gd` require updating default `.tres` under `resources/` and any scene using them.
- Tabs and warnings
  - Keep tab indentation in `.gd` files; tests use native method stubs on engine classes—suppress with `@warning_ignore("native_method_override")` where applicable (details in `docs/general/developer_pitfalls.md`).

## Scene Manager Patterns (Phase 10 Complete)

### Scene Registration
- **Register all scenes**: Add scenes to `U_SceneRegistry._register_all_scenes()` before using them
  ```gdscript
  _register_scene(
    StringName("my_scene"),
    "res://scenes/gameplay/my_scene.tscn",
    SceneType.GAMEPLAY,
    "fade",  # default transition
    5        # preload priority (0-10)
  )
  ```
- **Preload priority guidelines**:
  - `10`: Critical UI (main_menu, pause_menu) - preloaded at startup
  - `5-7`: Frequently accessed scenes
  - `0-4`: Occasional access
  - `0`: No preload (loaded on-demand)

### Scene Transitions
- **Get scene manager**: `get_tree().get_first_node_in_group("scene_manager") as M_SceneManager`
- **Basic transition**: `scene_manager.transition_to_scene(StringName("scene_id"))`
- **Override transition type**: `scene_manager.transition_to_scene(StringName("scene_id"), "fade")`
- **Priority transitions**: `scene_manager.transition_to_scene(StringName("game_over"), "fade", M_SceneManager.Priority.CRITICAL)`
- **Transition types**:
  - `"instant"`: < 100ms, no visual effect (UI navigation)
  - `"fade"`: 0.2-0.5s, fade out → load → fade in (polished)
  - `"loading"`: 1.5s+, loading screen with progress bar (large scenes)
- **Priority levels**:
  - `NORMAL = 0`: Standard navigation
  - `HIGH = 1`: Important but not urgent
  - `CRITICAL = 2`: Death, game over (jumps to front of queue)

### Overlay Management (Pause/Menus)
- **Push overlay**: `scene_manager.push_overlay(StringName("pause_menu"))` - adds to stack, pauses tree
- **Pop overlay**: `scene_manager.pop_overlay()` - removes top overlay, resumes if empty
- **Return stack**: `push_overlay_with_return(StringName("settings_menu"))` - remember previous overlay
- **Auto-restore**: `pop_overlay_with_return()` - return to previous overlay automatically
- **Navigation**: `go_back()` - navigate back through UI history (UI scenes only, skips gameplay)

### Scene Triggers (Doors)
- **Component setup**: Add `C_SceneTriggerComponent` to door entities with Area3D collision
- **Required properties**:
  - `door_id`: Unique identifier (e.g., `"door_to_house"`)
  - `target_scene_id`: Destination scene (e.g., `"interior_house"`)
  - `target_spawn_point`: Spawn marker name (e.g., `"sp_entrance_from_exterior"`)
- **Trigger modes**:
  - `AUTO`: Triggers on collision (walk through)
  - `INTERACT`: Requires input action (press 'E')
- **Duplicate request protection**: Components check transition state and use cooldown/pending flags to prevent duplicate requests
- **Input blocking during transitions**: Transition effects temporarily block input to prevent accidental re-triggers; restore input on completion
- **Trigger shape configuration**: Use shape resources (Box or Cylinder). Avoid non-uniform scaling of nodes; adjust shape dimensions on the resource instead. Use `local_offset` to align triggers with visual geometry
- **Cooldown**: Set `cooldown_duration` (1-2 seconds) to prevent spam
- **Door pairings**: Register bidirectional doors in `U_SceneRegistry._register_door_pairings()`
  ```gdscript
  _register_door_pair(
    StringName("exterior"), StringName("door_to_house"),
    StringName("interior_house"), StringName("door_to_exterior")
  )
  ```

### Spawn Point Management
- **Naming convention**: `sp_` prefix + descriptive name (e.g., `sp_entrance_from_exterior`)
- **Container**: Place under `SP_SpawnPoints` (Node3D) in gameplay scenes
- **Default spawn**: Name one marker `sp_default` for initial scene load
- **Position**: Place spawn markers 2-3 units OUTSIDE trigger zones (prevents ping-pong)
- **Automatic restoration**: M_SpawnManager applies spawn on scene load using:
  - Priority: `target_spawn_point` → `last_checkpoint` → `sp_default`
  - Fallback: If a `last_checkpoint` from a different scene is invalid, fall back to `sp_default` automatically

### State Persistence
- **Automatic persistence**: `gameplay` slice persists across transitions via `StateHandoff`
- **Use action creators**: Modify state via `U_GameplayActions` (never set fields directly)
  ```gdscript
  const U_GameplayActions = preload("res://scripts/state/actions/u_gameplay_actions.gd")
  store.dispatch(U_GameplayActions.take_damage(player_id, 25.0))
  store.dispatch(U_GameplayActions.mark_area_complete("interior_house"))
  ```
- **Read state safely**: Use `U_StateUtils.get_store(self)` with `await` in `_ready()`
  ```gdscript
  await get_tree().process_frame
  var store := U_StateUtils.get_store(self)
  var state: Dictionary = store.get_state()
  ```
- **Transient fields**: Excluded from saves (e.g., `is_transitioning`, `transition_type`)
- **Save/load**: `store.save_state("user://savegame.json")` / `store.load_state("user://savegame.json")`

### Camera Blending
- **Automatic blending**: Gameplay → Gameplay transitions blend camera position, rotation, FOV
- **Requirements**: Both scenes must have camera in "main_camera" group
- **Transition type**: Only works with `"fade"` transitions (not instant/loading)
- **Scene-specific setup**: Configure camera per-scene (e.g., exterior: FOV 80°, interior: FOV 65°)
- **Implementation**: Uses transition camera + Tween (0.2s, TRANS_CUBIC, EASE_IN_OUT)

### Scene Preloading & Performance
- **Critical scene preload**: Scenes with `preload_priority >= 10` load at startup
- **Scene cache**: LRU cache with 5 scene limit + 100MB memory cap
- **Preload hints**: Call `hint_preload_scene(StringName("scene_id"))` when player approaches door
- **Automatic hints**: `C_SceneTriggerComponent` auto-hints target scene on player proximity
- **Async loading**: Gameplay scenes load asynchronously with real progress tracking
- **Performance targets**:
  - UI transitions: < 0.5s (cached scenes are instant)
  - Gameplay transitions: < 3s (async with loading screen)
  - Large scenes: < 5s (loading screen with progress bar)

## Test Commands

- Run ECS tests
  - `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ecs -gexit`
- Always include `-gexit` when running GUT via the command line so the runner terminates cleanly; without it the process hangs and triggers harness timeouts.
- Notes
  - Tests commonly `await get_tree().process_frame` after adding nodes to allow auto-registration with `M_ECSManager` before assertions.
  - When stubbing engine methods in tests (e.g., `is_on_floor`, `move_and_slide`), include `@warning_ignore("native_method_override")`.

## Quick How-Tos (non-duplicative)

- Add a new ECS Component
  - Create `scripts/ecs/components/c_your_component.gd` extending `ECSComponent` with `COMPONENT_TYPE` and exported NodePaths; add typed getters; update a scene to wire paths.
- Add a new ECS System
  - Create `scripts/ecs/systems/s_your_system.gd` extending `ECSSystem`; implement `process_tick(delta)`; query with your component's `StringName`; drop the node under a running scene—auto-configured.
- Find M_StateStore from any node
  - Use `U_StateUtils.get_store(self)` to find the store via "state_store" group.
  - In `_ready()`: add `await get_tree().process_frame` BEFORE calling `get_store()` to avoid race conditions.
  - In `process_tick()`: no await needed (store already registered).
- Create a new gameplay scene
  - Duplicate `scenes/gameplay/gameplay_base.tscn` as starting point.
  - Keep M_ECSManager + Systems + Entities + Environment structure.
  - Do NOT add M_StateStore or M_CursorManager (they live in root.tscn).
