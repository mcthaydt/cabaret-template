# Add ECS Component / System / Event

**Status**: Active

## When To Use This Recipe

Use this recipe when adding:

- A new ECS component (`C_*`)
- A new ECS system (`S_*`)
- A new typed ECS event (`Evn_*`)
- A new StringName event constant

This recipe does **not** cover:

- Manager authoring (see `managers.md`)
- State slice creation (see `state.md`)
- QB rule conditions/effects (see `conditions_effects_rules.md`)

## Governing ADR(s)

- [ADR 0003: ECS Node-Based Architecture](../adr/0003-ecs-node-based.md)
- [ADR 0004: Event Bus](../adr/0004-event-bus.md)

## Canonical Example

- Component: `scripts/core/ecs/components/c_health_component.gd`
- System: `scripts/core/ecs/systems/s_health_system.gd`
- Typed event: `scripts/core/events/ecs/evn_health_changed.gd`
- Event names: `scripts/core/events/ecs/u_ecs_event_names.gd`
- Event bus: `scripts/core/events/ecs/u_ecs_event_bus.gd`

## Vocabulary

| Term | Meaning |
|------|---------|
| `BaseECSComponent` | Base class for components. Auto-registers with `M_ECSManager` in deferred `_ready()`. |
| `BaseECSSystem` | Base class for systems. Must override `process_tick(delta)`. Auto-registers. |
| `BaseECSEntity` | Base class for entity roots (`E_*`). Provides `entity_id`, `tags`. |
| `U_ECSEventBus` | Static event bus. `publish(name, payload)`, `subscribe(name, callback, priority) -> Callable`. |
| `BaseECSEvent` | Base for typed events. Has `timestamp`, `_payload`, `get_payload() -> Dictionary` (deep copy). |
| `SystemPhase` | Enum: `PRE_PHYSICS`, `INPUT`, `PHYSICS_SOLVE` (default), `POST_PHYSICS`, `CAMERA`, `VFX`. |
| `U_EntityQuery` | Multi-component query result: `entity`, `components` dict, `get_component()`, `has_component()`. |

Prefix rules: `C_` components, `S_` systems, `E_` entities, `Evn_` typed events, `EVENT_` event name constants.

## Recipe

### Adding a new component

1. Create `scripts/core/ecs/components/c_<name>_component.gd`: extend `BaseECSComponent`, set `const COMPONENT_TYPE := StringName("<Name>Component")`, `@export` fields, implement `_init()` setting `component_type = COMPONENT_TYPE`, override `_validate_required_settings() -> bool` if needed.
2. If configurable: create `scripts/core/ecs/resources/rs_<name>_settings.gd` (extend `Resource`).
3. Add component node to entity scene as child of the `E_*` root.
4. Components auto-register with `M_ECSManager`.

### Adding a new system

1. Create `scripts/core/ecs/systems/s_<name>_system.gd`: extend `BaseECSSystem`, override `get_phase()` and `process_tick(delta)`.
2. Use `get_components(component_type)` for single-type queries, `query_entities(required, optional)` for multi-component.
3. Set `execution_priority` for ordering within phase (0-199, higher = later).
4. Systems auto-register with `M_ECSManager`.

### Adding a new StringName event

1. Add `const EVENT_<NAME> := StringName("<name>")` to `U_ECSEventNames`.
2. Publish: `U_ECSEventBus.publish(U_ECSEventNames.EVENT_<NAME>, payload)`.
3. Subscribe: store unsubscribe callable, call in `_exit_tree()`.

### Adding a new typed event

1. Create `scripts/core/events/ecs/evn_<snake_case>.gd`: extend `BaseECSEvent`, `class_name Evn_<PascalCase>`, declare fields, `_init()` sets all fields + `timestamp` + builds `_payload`.
2. Add event name constant to `U_ECSEventNames`.
3. Publish: `U_ECSEventBus.publish_typed(Evn_<Name>.new(...))`.

## Anti-patterns

- **Cross-component NodePath wiring**: Systems use `query_entities()`, not `@export_node_path` between components.
- **Direct `_physics_process()` in managed systems**: Use `process_tick(delta)`.
- **`has_method()` duck-typing**: Use typed interfaces (`I_ECSManager`, `I_ECSEntity`).
- **Forgetting to unsubscribe from event bus**: Store callable, call in `_exit_tree()`.
- **Modifying event payloads without `duplicate(true)`**: Deep-copy before mutation.
- **Entity roots without `BaseECSEntity`**: All gameplay entities must extend it.
- **Managers publishing to `U_ECSEventBus`**: Only `M_ECSManager` is exempt (ADR 0001).

## Out Of Scope

- Manager registration: see `managers.md`
- QB conditions/effects: see `conditions_effects_rules.md`
- AI behavior: see `ai.md`

## References

- [ECS Architecture](../../systems/ecs/ecs_architecture.md)
- [ECS Events](../../systems/ecs/ecs_events.md)
- [ADR 0003: ECS Node-Based](../adr/0003-ecs-node-based.md)
- [ADR 0004: Event Bus](../adr/0004-event-bus.md)