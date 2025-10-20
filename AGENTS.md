# Agents Notes

## Start Here

- Project type: Godot 4.5 (GDScript). Two core areas:
  - `scripts/ecs`: Lightweight ECS built on Nodes (components + systems + manager).
  - `scripts/state`: Redux-like state store utilities (actions, reducers, selectors, persistence).
- Scenes and resources:
  - `templates/`: Base scene and player scene that wire components/systems together.
  - `resources/`: Default `*Settings.tres` for component configs; update when adding new exported fields.
- Documentation to consult (do not duplicate here):
  - State store: `docs/redux_state_store/*`
  - General pitfalls: `docs/general/developer_pitfalls.md`

## Repo Map (essentials)

- `scripts/managers/m_ecs_manager.gd`: Registers components/systems; exposes `get_components(StringName)` and emits component signals.
- `scripts/ecs/ecs_component.gd`: Base for components. Auto-registers with manager; exposes `get_snapshot()` hook.
- `scripts/ecs/ecs_system.gd`: Base for systems. Implement `process_tick(delta)`; runs via `_physics_process`.
- `scripts/ecs/components/*`: Gameplay components with `@export` NodePaths and typed getters.
- `scripts/ecs/systems/*`: Systems that query components by `StringName` and operate per-physics tick.
- `scripts/ecs/resources/*`: `Resource` classes holding tunables consumed by components/systems.
- `scripts/state/*`: `M_StateManager`, `U_ReducerUtils`, `U_ActionUtils`, selectors, and persistence helpers.
- `tests/unit/*`: GUT test suites split into `ecs` and `state`.

## ECS Guidelines

- Components
  - Extend `ECSComponent`; define `const COMPONENT_TYPE := StringName("YourComponent")` and set `component_type = COMPONENT_TYPE` in `_init()`.
  - Prefer `@export` NodePaths with typed getters that use `get_node_or_null(...) as Type` and return `null` on empty paths.
  - Keep null-safe call sites; systems assume absent paths disable behavior rather than error.
  - If you expose debug state, copy via `snapshot.duplicate(true)` to avoid aliasing.
- Systems
  - Extend `ECSSystem`; implement `process_tick(delta)` (invoked from `_physics_process`).
  - Query with `get_components(StringName)`, dedupe per-body where needed, and clamp/guard values (see movement/rotation/floating examples).
  - Auto-discovers `M_ECSManager` via parent traversal or `ecs_manager` group; no manual wiring needed.
- Manager
  - Ensure exactly one `M_ECSManager` in-scene. It auto-adds to `ecs_manager` group on `_ready()`.
  - Emits `component_added`/`component_removed` and calls `component.on_registered(self)`.

## State Store Guidelines

- Reducers are static classes with:
  - `get_slice_name() -> StringName`, `get_initial_state() -> Dictionary`, optional `get_persistable() -> bool`, and `reduce(state, action) -> Dictionary`.
  - Do not mutate input state; return new dictionaries using `duplicate(true)` where needed.
- Actions and selectors
  - Use `U_ActionUtils.create_action(type, payload)` so `type` becomes a `StringName` and shape stays consistent.
  - For expensive derivations, wrap a lambda with `U_SelectorUtils.MemoizedSelector` to cache on state version.
- Store usage
  - Add a single `M_StateManager` node to the tree (it joins `state_store` group). Discover from any node via `U_StateStoreUtils.get_store(node)`.
  - To persist, use `store.save_state(path[, whitelist])`; restore using `store.load_state(path)`.
  - For full architecture/tradeoffs/PRD, see `docs/redux_state_store/*`.

## Conventions and Gotchas

- GDScript typing
  - Annotate locals receiving Variants (e.g., from `Callable.call()`, `JSON.parse_string`, `Time.get_ticks_msec()` calc). Prefer explicit `: float`, `: int`, `: Dictionary`, etc.
  - Use `StringName` for action/component identifiers; keep constants like `const MOVEMENT_TYPE := StringName("C_MovementComponent")`.
- Copy semantics
  - Use `.duplicate(true)` for deep copies of `Dictionary`/`Array` before mutating; the codebase relies on immutability patterns both in ECS snapshots and state.
- Scenes and NodePaths
  - Wire `@export` NodePaths in scenes; missing paths intentionally short-circuit behavior in systems. See `templates/player_template.tscn` for patterns.
- Resources
  - New exported fields in `*Settings.gd` require updating default `.tres` under `resources/` and any scene using them.
- Tabs and warnings
  - Keep tab indentation in `.gd` files; tests use native method stubs on engine classes—suppress with `@warning_ignore("native_method_override")` where applicable (details in `docs/general/developer_pitfalls.md`).

## Test Commands

- Run ECS tests
  - `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ecs`
- Run State Store tests
  - `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/state`
- Notes
  - Tests commonly `await get_tree().process_frame` after adding nodes to allow auto-registration with `M_ECSManager` before assertions.
  - When stubbing engine methods in tests (e.g., `is_on_floor`, `move_and_slide`), include `@warning_ignore("native_method_override")`.

## Quick How-Tos (non-duplicative)

- Add a new ECS Component
  - Create `scripts/ecs/components/c_your_component.gd` extending `ECSComponent` with `COMPONENT_TYPE` and exported NodePaths; add typed getters; update a scene to wire paths.
- Add a new ECS System
  - Create `scripts/ecs/systems/s_your_system.gd` extending `ECSSystem`; implement `process_tick(delta)`; query with your component’s `StringName`; drop the node under a running scene—auto-configured.
- Add a state slice
  - Define a reducer class with required static methods; in-scene, call `M_StateManager.register_reducer(YourReducer)` during initialization.
