# ECS Architecture & Workflow

## Architecture Overview

- `ECSManager` (`scripts/ecs/ecs_manager.gd`) tracks registered components by type and keeps a list of systems. It exposes `register_component`, `register_system`, and `get_components`.
- `ECSComponent` (`scripts/ecs/ecs_component.gd`) extends `Node` and auto-registers itself by walking up the scene tree (or group). Each concrete component sets `component_type` and exposes helpers for the nodes it references.
- `ECSSystem` (`scripts/ecs/ecs_system.gd`) extends `Node`, auto-registers with the manager, and calls `process_tick(delta)` every physics frame. Systems fetch component lists from the manager and implement their behaviour there.
- Game entities are ordinary scenes (for example `templates/player_template.tscn`) that group the Godot nodes (meshes, bodies, etc.) and attach components under a `Components` node. Systems live elsewhere in the scene tree (see `templates/base_scene_template.tscn`), as long as they share an ancestor with the manager or the `ecs_manager` group.
- Runtime scenes start from the base template: `Root` holds `Systems`, `Managers`, environment, floor geometry, and a `SpawnPoints` node. When the player template instantiates under `SpawnPoints/PlayerSpawn`, its components auto-register with the manager in the `Managers` branch, and the systems under `Systems` begin processing them immediately.

## Entity Templates

- Templates live in `templates/` and package reusable entities. The player template provides a reference layout: a `CharacterBody3D` (`Player_Body`) with collider and mesh visuals, plus a sibling `Components` node that hosts `MovementComponent`, `JumpComponent`, `InputComponent`, and `RotateToInputComponent`.
- Each component uses `@export_node_path` fields pointing back to `Player_Body` or `InputComponent`, so instancing the template anywhere automatically wires the body and input graph.
- To author a new entity, follow the same structure—add the gameplay nodes, nest a `Components` child, drop in the relevant ECS components, and assign exported node paths using the inspector.
- Entity scenes can expose their own script for higher-level behaviours (signals, state machines) while letting ECS systems handle movement, rotation, etc.
- When an entity scene is instanced under a manager-aware parent (such as the base template’s `SpawnPoints`), its components register automatically and begin participating in the running systems.

## Creating a Component

1. Derive from `ECSComponent` and give it a `class_name` so scenes can reference it easily.
2. In `_init()` set `component_type` (usually a `StringName` matching the class). This is how the manager indexes the component.
3. Export any required references using `@export_node_path` so designers can assign nodes safely in the inspector.
4. Provide lightweight helper methods to fetch the referenced nodes or expose state that systems will consume.
5. Add component-specific logic (for example input state helpers, timers, etc.) as needed. Keep side effects minimal—systems are responsible for orchestrating behaviour.

## Creating a System

1. Derive from `ECSSystem`, add a `class_name`, and define constants for the component types you care about.
2. Override `process_tick(delta)`. Call `get_components(component_type)` for each component set you need, skip nulls, and implement the per-frame logic. Record intermediate state if multiple components share a node (see `MovementSystem`).
3. Optionally override `on_configured()` to cache configuration or ensure input mappings when the system registers with the manager (see `InputSystem`).
4. For physics-driven behaviour, rely on the base `_physics_process` and keep `process_tick` deterministic.
5. Instantiate the system under any node that leads to the shared manager (or add the manager to the `ecs_manager` group) so automatic registration succeeds.

## Testing New Behaviour

1. Use GUT tests under `tests/unit/ecs/...` to exercise systems and components. Tests typically:
   - Create a temporary scene tree with the manager, relevant components, and any stub nodes (see `tests/unit/ecs/systems/test_movement_system.gd`).
   - Wire the component paths using `get_path_to`.
   - Call the system’s `_physics_process(delta)` to simulate a frame.
   - Assert on the resulting state (velocity, rotation, signals, etc.).
2. To run a focused suite headlessly: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=<test_dir>`.
3. When testing components in isolation, you can create fake bodies or helper classes inside the test file to stand in for complex nodes.
4. If the headless runner times out in the CLI, note that results are printed before Godot exits; you can rely on the reported pass/fail summary.
