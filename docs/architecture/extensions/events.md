# Add Event Type / Subscription

**Status**: Active

## When To Use This Recipe

Use this recipe when adding:

- A new ECS event name constant
- A new typed event class (`Evn_*`)
- A new event bus subscription in a system or component

This recipe does **not** cover:

- ECS component/system authoring (see `ecs.md`)
- QB rule conditions/effects (see `conditions_effects_rules.md`)

## Governing ADR(s)

- [ADR 0004: Event Bus](../adr/0004-event-bus.md)

## Canonical Example

- Typed event: `scripts/core/events/ecs/evn_health_changed.gd` (`Evn_HealthChanged`)
- Event names: `scripts/core/events/ecs/u_ecs_event_names.gd`
- Event bus: `scripts/core/events/ecs/u_ecs_event_bus.gd`
- Base event bus: `scripts/core/events/base_event_bus.gd` (`BaseEventBus`)
- Subscription pattern: `scripts/ecs/systems/s_victory_handler_system.gd`

## Vocabulary

| Term | Meaning |
|------|---------|
| `BaseEventBus` | Instance-based bus: `publish(name, payload)`, `subscribe(name, callback, priority) -> Callable`, `unsubscribe()`. Priority ordering (higher = called first). Deferred unsubscriptions during publish. |
| `U_ECSEventBus` | Static facade over `BaseEventBus`. `publish_typed(event)` auto-converts class name to snake_case event name (strips `Evn_` prefix). |
| `U_StateEventBus` | Static facade for state store domain. |
| `BaseECSEvent` | Typed event base: `timestamp`, `_payload`, `get_payload() -> Dictionary` (deep copy). |
| `U_ECSEventNames` | Centralized `StringName` constants for all event names. |

Event naming: typed classes `Evn_<PascalCase>` → snake_case (`Evn_HealthChanged` → `"health_changed"`). Files: `evn_<snake_case>.gd`.

## Recipe

### Adding a new StringName event

1. Add `const EVENT_<NAME> := StringName("<name>")` to `U_ECSEventNames`.
2. Publish: `U_ECSEventBus.publish(U_ECSEventNames.EVENT_<NAME>, payload_dictionary)`.
3. Subscribe: `U_ECSEventBus.subscribe(name, callback, priority)` — store unsubscribe callable.

### Adding a new typed event

1. Create `scripts/core/events/ecs/evn_<snake_case>.gd`: extend `BaseECSEvent`, `class_name Evn_<PascalCase>`, declare domain fields, implement `_init()` setting all fields + `timestamp` via `U_ECS_UTILS.get_current_time()` + building `_payload`.
2. Add event name constant to `U_ECSEventNames`.
3. Publish: `U_ECSEventBus.publish_typed(Evn_<Name>.new(...))`.
4. Subscribers receive identical Dictionary format regardless of typed vs StringName publishing.

### Adding a new subscription

1. In `on_configured()` (systems) or `_ready()` (components): call `U_ECSEventBus.subscribe(name, callback, priority)`, store returned `Callable` in `_event_unsubscribes: Array[Callable]`.
2. In `_exit_tree()`: iterate `_event_unsubscribes`, check `is_valid()`, call unsubscribe, clear array.

Priority guidelines: `10` = critical state updates, `5-9` = important ordering, `0` = default.

## Anti-patterns

- **Subscribing without storing the unsubscribe callable**: Causes leaks. Always store and clean up.
- **Subscribing in `_process()` or frame-based callbacks**: Subscribe once in `_ready()`/`on_configured()`.
- **Forgetting `is_valid()` check before unsubscribe**: Orphan callbacks.
- **Modifying event payloads without `duplicate(true)`**: Deep-copy before mutation.
- **Overusing high priorities**: Most events should use default (0).
- **Subscribing in a loop**: Causes duplicate warnings.
- **Managers publishing to `U_ECSEventBus`**: Only `M_ECSManager` is exempt (ADR 0001).

## Out Of Scope

- ECS component/system: see `ecs.md`
- QB conditions/effects: see `conditions_effects_rules.md`
- Manager registration: see `managers.md`

## References

- [ECS Events](../../systems/ecs/ecs_events.md)
- [ADR 0004: Event Bus](../adr/0004-event-bus.md)