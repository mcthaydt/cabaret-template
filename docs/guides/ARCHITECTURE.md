# Architecture Guide

This guide is the high-level routing map for the Cabaret Template architecture. Topic-specific runtime contracts live in `docs/systems/**`; this file explains where the main pieces are and how they connect.

## Project Shape

- Project type: Godot 4.6 with GDScript.
- Core gameplay architecture: node-based ECS under `scripts/ecs/`, coordinated by per-scene `M_ECSManager` instances.
- Persistent app root: `scenes/root.tscn`, with long-lived managers under `Managers`.
- Gameplay scenes: `scenes/gameplay/**`, each with its own ECS manager, systems, entities, and scene-local content.
- Base/templates: `scenes/templates/` contains reusable base scene, character, and camera templates.
- Default config resources: `resources/base_settings/**/cfg_*_default.tres`.
- UI registry: `scripts/ui/utils/u_ui_registry.gd` plus `resources/ui_screens/`.
- State store: `scripts/state/m_state_store.gd`, Redux-style actions/reducers/selectors under `scripts/state/**`.

## Core Documents

- ECS: `docs/systems/ecs/ecs_architecture.md`
- Scene organization: `docs/guides/SCENE_ORGANIZATION_GUIDE.md`
- Style and naming: `docs/guides/STYLE_GUIDE.md`
- Testing pitfalls: `docs/guides/pitfalls/TESTING.md`
- Channel taxonomy ADR: `docs/architecture/adr/0001-channel-taxonomy.md`
- Service locator ADR: `docs/architecture/adr/0005-service-locator.md`

## Communication Channels

The project follows the publisher-based channel taxonomy from ADR 0001:

- ECS components/systems publish gameplay events through `U_ECSEventBus`.
- Managers dispatch Redux actions through `M_StateStore`.
- Manager-to-UI and intra-manager wiring uses explicit Godot signals only where allow-listed.
- Everything else should be a direct method call.

`M_ECSManager` is the only manager exception allowed to publish ECS lifecycle events, because it is ECS infrastructure.

## Service Lookup

Preferred dependency lookup chain:

1. Export injection for tests.
2. `U_ServiceLocator.try_get_service(StringName("..."))` for production.
3. Parent traversal for ECS-local manager discovery where established by base helpers.

Do not add Godot group lookup as a normal manager-discovery path. Use `U_StateUtils.get_store(node)` / `await_store_ready(node)` for required state-store access and `try_get_store(node)` only for optional isolated/editor flows.

## ServiceLocator Test Isolation

- `U_ServiceLocator.register(name, instance)` fails on conflicting registration and is idempotent for the same instance.
- Use `register_or_replace(name, instance)` only when replacement is intentional.
- Tests should use `push_scope()` / `pop_scope()` for isolation.
- `BaseTest` already pushes/pops ServiceLocator scope and clears state handoff.
- Avoid `U_ServiceLocator.clear()` in tests because it wipes the scope stack.

## Quick How-Tos

- Add a component: create `scripts/ecs/components/c_*_component.gd`, extend `BaseECSComponent`, define `COMPONENT_TYPE`, validate required settings, and add default config resources if new exported fields need defaults.
- Add a system: create `scripts/ecs/systems/s_*_system.gd`, extend `BaseECSSystem`, implement `process_tick(delta)`, override `get_phase()`, query components by `StringName`.
- Add manager behavior: keep manager state changes in Redux actions/reducers/selectors; do not publish gameplay events from managers.
- Add a UI screen/overlay: create the controller under `scripts/ui/{menus,overlays,hud}/`, the scene under the matching `scenes/ui/**` folder, and a `resources/ui_screens/cfg_*` definition.
- Add a config resource: class definitions use `rs_*`; resource instances use `cfg_*`.

