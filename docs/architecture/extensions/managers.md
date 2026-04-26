# Add Manager

**Status**: Active

## When To Use This Recipe

Use this recipe when adding a new manager node to the `Managers` container in the scene tree. Managers are singleton `Node` subclasses that own a domain's runtime lifecycle and register with `U_ServiceLocator`.

This recipe does **not** cover:

- ECS systems (see `ecs.md`)
- State slice creation (see `state.md`)
- UI screens (see `ui.md`)

## Governing ADR(s)

- [ADR 0005: Service Locator](../adr/0005-service-locator.md)

## Canonical Example

- Simple manager: `scripts/core/managers/m_cursor_manager.gd` (73 lines — minimal full pattern)
- Interface: `scripts/core/interfaces/i_cursor_manager.gd`
- Registration: `scripts/core/root.gd` (`_register_if_exists()`)
- Service locator: `scripts/core/u_service_locator.gd`

## Vocabulary

| Term | Meaning |
|------|---------|
| `I_<Name>Manager` | Interface class. Extends `Node`, stubs every method with `push_error` + default return. |
| `M_<Name>Manager` | Production implementation. Extends the interface via path-based `extends`. |
| `U_ServiceLocator` | Static registry. `register(service_name, instance)`, `get_service(name)`, `try_get_service(name)`. |
| `U_DependencyResolution` | 3-step dependency lookup: cached → `@export` injected → `try_get_service()`. |
| `Marker_ManagersGroup` | Scene-tree marker on the `Managers` container node. |

Service name convention: snake_case of the domain (`"cursor_manager"`, `"save_manager"`).

## Recipe

1. Create interface: `scripts/core/interfaces/i_<name>_manager.gd` — extend `Node`, `class_name I_<Name>Manager`, stub every public method with `push_error` and default return.
2. Create manager: `scripts/core/managers/m_<name>_manager.gd` — `@icon("res://assets/editor_icons/icn_manager.svg")`, `extends "res://scripts/core/interfaces/i_<name>_manager.gd"`, `class_name M_<Name>Manager`. In `_ready()`: register with `U_ServiceLocator.register(StringName("<name>_manager"), self)`, discover dependencies.
3. Add node to `root.tscn` under the `Managers` container.
4. Register in `root.gd` `_initialize_service_locator()`: add `_register_if_exists(managers_node, "M_<Name>Manager", StringName("<name>_manager"))` and `U_ServiceLocator.register_dependency()` for each dependency.
5. If data-driven config needed: create `scripts/core/resources/managers/rs_<name>_config.gd` (extend `Resource`).
6. If helpers needed: create under `scripts/core/managers/helpers/<domain>/`.

## Anti-patterns

- **`has_method()` checks on managers**: Cast through the interface instead.
- **Bypassing ServiceLocator with `get_node()`**: Cross-manager dependencies go through `U_ServiceLocator`.
- **Double `register()` calls**: Use `register_or_replace()` if intentional replacement.
- **Registering freed/null instances**: ServiceLocator pushes error and skips.
- **Forgetting `await get_tree().process_frame`** when discovering other managers in `_ready()` — they may not be registered yet.
- **Managers publishing to `U_ECSEventBus`**: Only `M_ECSManager` is exempt per ADR 0001.

## Out Of Scope

- ECS component/system: see `ecs.md`
- State slice: see `state.md`
- UI screen: see `ui.md`

## References

- [ADR 0005: Service Locator](../adr/0005-service-locator.md)
- [Architecture Guide](../../guides/ARCHITECTURE.md)