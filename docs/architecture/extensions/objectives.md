# Add Objective / Victory Route

**Status**: Active

## When To Use This Recipe

Use this recipe when adding:

- A new objective to the progression system
- A new objective set
- A new victory route (trigger zone → completion → scene transition)
- A new scene directive with beat sequences

This recipe does **not** cover:

- QB conditions/effects (see `conditions_effects_rules.md`)
- ECS component/system authoring (see `ecs.md`)
- Scene authoring (see `scenes.md`)

## Governing ADR(s)

- [ADR 0004: Event Bus](../adr/0004-event-bus.md) (victory triggers use ECS events)

## Canonical Example

- Objective: `resources/scene_director/objectives/cfg_obj_level_complete.tres` (`RS_ObjectiveDefinition`)
- Objective set: `resources/scene_director/sets/cfg_objset_default.tres` (`RS_ObjectiveSet`)
- Victory config: `resources/interactions/victory/cfg_victory_goal_bar.tres` (`RS_VictoryInteractionConfig`)
- Victory zone: `scripts/gameplay/inter_victory_zone.gd`
- Objectives manager: `scripts/managers/m_objectives_manager.gd`
- Beat definition: `scripts/resources/scene_director/rs_beat_definition.gd`

## Vocabulary

| Term | Meaning |
|------|---------|
| `RS_ObjectiveDefinition` | Resource: `objective_id`, `objective_type` (STANDARD/VICTORY/CHECKPOINT), `conditions`, `completion_effects`, `dependencies`, `auto_activate`. |
| `RS_ObjectiveSet` | Resource: `set_id`, `objectives: Array[RS_ObjectiveDefinition]`. |
| `RS_VictoryInteractionConfig` | Resource: `objective_id`, `victory_type`, `trigger_once`, `visibility_objective_id`. |
| `Inter_VictoryZone` | Scene interactable with Area3D. Spawns `C_VictoryTriggerComponent`, publishes `Evn_VictoryTriggered`. |
| `M_ObjectivesManager` | Loads sets, evaluates conditions, completes objectives, auto-activates dependents. |
| `M_SceneDirectorManager` | Selects directives by scene, runs beat graphs. |
| `U_ObjectiveGraph` | Validates dependency graph (cycle detection, missing refs). |

## Recipe

### Adding a new objective

1. Create `RS_ObjectiveDefinition` `.tres` under `resources/scene_director/objectives/` named `cfg_obj_<name>.tres`. Set `objective_id`, `objective_type`, `conditions` (commonly `RS_ConditionEventPayload`), `completion_effects` (commonly `RS_EffectDispatchAction`), `dependencies`, `auto_activate`.
2. Add to an `RS_ObjectiveSet` `.tres` (e.g., `cfg_objset_default.tres`).
3. Wire a trigger: place `Inter_VictoryZone` with `RS_VictoryInteractionConfig` whose `objective_id` matches a condition's `match_value_string`.
4. If visibility-gated: set `visibility_objective_id` on the config.

### Adding a new victory route

1. Create `RS_VictoryInteractionConfig` `.tres` under `resources/interactions/victory/` named `cfg_victory_<name>.tres`. Set `objective_id`, `victory_type` (LEVEL_COMPLETE/GAME_COMPLETE), `trigger_once`.
2. Place `Inter_VictoryZone` in scene with the config assigned.
3. Create `RS_ObjectiveDefinition` whose conditions match the trigger. For VICTORY type, set `objective_type = 1`.
4. Completion effect dispatches `gameplay/trigger_victory_routing` with `target_scene` — routes through `S_VictoryHandlerSystem`.

### Adding a new scene directive (beats)

1. Create `RS_BeatDefinition` `.tres` files under `resources/scene_director/beats/`: each with `beat_id`, `preconditions`, `effects`, `wait_mode` (INSTANT/TIMED/SIGNAL), `next_beat_id`, parallel fields.
2. Create `RS_SceneDirective` `.tres` under `resources/scene_director/directives/` named `cfg_directive_<name>.tres`. Set `directive_id`, `target_scene_id`, `selection_conditions`, `priority`, `beats`.
3. Assign to `M_SceneDirectorManager.directives` in scene tree.

## Anti-patterns

- **Circular dependencies in objective graphs**: `U_ObjectiveGraph.validate_graph()` detects and rejects.
- **Calling `_complete_objective()` directly**: Objectives complete only through condition evaluation. Publish ECS events or dispatch Redux actions.
- **Bypassing `trigger_victory_routing`**: VICTORY objectives must route through `S_VictoryHandlerSystem` for sound, UI, and state cleanup.
- **Missing `visibility_objective_id`**: If set, zone is hidden until that objective is active. If needed but not set, zone is always visible.
- **Unregistered objective IDs in dependencies**: Graph validator rejects missing refs.

## Out Of Scope

- QB conditions/effects: see `conditions_effects_rules.md`
- ECS component/system: see `ecs.md`
- Scene authoring: see `scenes.md`

## References

- [Scene Director Overview](../../systems/scene_director/scene-director-overview.md)
- [QB Rule Manager v2](../../systems/qb_rule_manager/qb-v2-overview.md)