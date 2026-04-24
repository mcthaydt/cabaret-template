# ADR 0001: Communication Channel Taxonomy

**Status**: Accepted
**Date**: 2026-04-14
**Context**: Cross-System Cleanup V7.2 Milestone F5

## Context

The project uses three communication channels — Redux dispatch, `U_ECSEventBus`, and Godot signals — but has no formal rule about which publishers use which channel. This ambiguity has led to managers publishing to the ECS event bus, creating coupling that bypasses the Redux state/reducer/history pipeline and makes "contract-by-comment" growth in `AGENTS.md` necessary.

Four managers currently publish to `U_ECSEventBus`:
- `m_save_manager` (3 publishes: save_started/completed/failed)
- `m_objectives_manager` (4 publishes: objective_activated/completed/failed + victory_triggered)
- `m_vcam_manager` (5 publishes: vcam_active_changed/blend_started/blend_completed/recovery/silhouette_update_request)
- `m_scene_director_manager` (3 publishes: directive_started/completed/beat_advanced)
- `m_spawn_manager` (1 publish: player_spawned)

Additionally, `m_scene_manager` subscribes to `EVENT_OBJECTIVE_VICTORY_TRIGGERED` on the ECS bus for victory routing — a manager-to-manager communication that should go through Redux.

## Decision

Adopt **Option B (publisher-based rule)**:

| Publisher | Channel |
|---|---|
| ECS component or system | `U_ECSEventBus` — subscribers can be anywhere |
| Manager | Redux dispatch only |
| Intra-manager / manager-UI wiring | Godot signals |
| Everything else | Method calls |

**One-sentence rule**: If you're a manager, dispatch to Redux.

### What does NOT change

ECS-originated events stay on the bus regardless of subscriber type. These cross-subscriber patterns remain valid:
- `c_health_component` → `health_changed` → `s_screen_shake_publisher_system` (ECS→ECS)
- `s_screen_shake_publisher_system` → `screen_shake_request` → `m_vfx_manager` (ECS→Manager subscriber)
- `s_checkpoint_handler_system` → `checkpoint_activated` → `ui_hud_controller` (ECS→UI subscriber)

### Allow-listed exceptions

- `m_ecs_manager.gd` may publish `entity_registered`/`entity_unregistered` to `U_ECSEventBus` because it IS the ECS infrastructure (not a gameplay manager).

### Enforcement

Grep tests in `tests/unit/style/test_style_enforcement.gd` enforce the taxonomy at CI time:
1. `test_managers_dont_publish_to_ecs_bus` — zero hits for `ECSEventBus.publish` / `EVENT_BUS.publish` in `scripts/managers/` (except `m_ecs_manager.gd`)
2. `test_scene_manager_no_victory_ecs_subscription` — `EVENT_OBJECTIVE_VICTORY_TRIGGERED` absent from `m_scene_manager.gd`
3. `test_manager_signals_allow_list` — manager signal declarations must be in the allow-list (UI wiring signals only)

## Consequences

### Positive

- Managers flow all state changes through Redux, giving action history, validator, and subscriber batching a single source of truth.
- Manager-to-manager communication (e.g., victory routing) goes through Redux dispatch instead of ad-hoc ECS subscriptions.
- Reduces "contract-by-comment" sprawl in `AGENTS.md` — the rule is mechanically enforced.
- Eliminates redundant ECS publishes where Redux already carries the state (vcam, scene director).

### Negative

- ECS systems that consume manager-published events (e.g., `s_spawn_particles_system` consuming `player_spawned`) must migrate to subscribe to Redux `action_dispatched` instead of ECS bus. This changes the subscription source but preserves the request-processing pipeline.

## Alternatives Considered

- **Keep channel choice per feature**: preserves flexibility, but keeps manager/ECS/state boundaries ambiguous and hard to enforce.
- **Route everything through `U_ECSEventBus`**: gives one event mechanism, but bypasses Redux state history and reducer validation for manager-owned state changes.
- **Route everything through Redux**: gives one state pipeline, but makes short-lived ECS gameplay requests heavier and less natural for components/systems.

### Migration summary

| Manager | Migration strategy |
|---|---|
| `m_save_manager` | New `u_save_actions.gd` with `ACTION_SAVE_STARTED/COMPLETED/FAILED`; `ui_hud_controller` subscribes to `action_dispatched` |
| `m_objectives_manager` | Delete 3 dead-code dual-publishes; victory routing via `ACTION_TRIGGER_VICTORY_ROUTING` Redux dispatch |
| `m_vcam_manager` | Remove 5 redundant ECS publishes; Redux already carries vcam state |
| `m_scene_director_manager` | Remove 3 redundant ECS publishes; Redux already carries director state |
| `m_spawn_manager` | Dispatch `ACTION_PLAYER_SPAWNED` to Redux; `s_spawn_particles_system` subscribes to `action_dispatched` |
| `m_scene_manager` | Remove `EVENT_OBJECTIVE_VICTORY_TRIGGERED` subscription; react to `ACTION_TRIGGER_VICTORY_ROUTING` from Redux |
