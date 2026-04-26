# AI System Overview (Behavior Trees)

**Project**: Cabaret Template (Godot 4.6)
**Created**: 2026-03-31
**Last Updated**: 2026-04-23
**Status**: BT runtime migration complete through Cleanup V8 P1.10; extension recipe authored
**Scope**: Utility-scored behavior trees for NPC orchestration, powered by typed BT resources and reusable AI actions

## Summary

The AI system provides data-driven NPC behavior through utility-scored behavior trees. Each brain points to an `RS_BTNode` root on `RS_AIBrainSettings`; `S_AIBehaviorSystem` evaluates that tree through `U_BTRunner`, assembles runtime context through `U_AIContextAssembler`, and stores per-node runtime state in `C_AIBrainComponent.bt_state_bag`.

Legacy GOAP/HTN goal, task, selector, replanner, and task-runner resources were removed in Cleanup V8 P1.10. QB rule infrastructure remains available for non-AI game logic and for BT condition/scorer resources.

## Current Runtime Contracts

- `S_AIBehaviorSystem` is the canonical BT orchestration system. Keep it orchestration-first: no inline selector/planner/task-runner stacks.
- Planning, when needed, is isolated to `RS_BTPlanner` and `U_BTPlannerSearch`; world-state assembly is isolated to `U_AIWorldStateBuilder`.
- Debug throttling/probing composes shared utilities (`U_DebugLogThrottle`, `U_AIRenderProbe`). Do not reintroduce local debug cooldown or render-probe stacks.
- Treat brain, BT, and action fields as typed runtime contracts: `C_AIBrainComponent.brain_settings: RS_AIBrainSettings`, `RS_AIBrainSettings.root: RS_BTNode`, BT resources under `scripts/core/resources/bt/` and `scripts/demo/resources/ai/bt/`, and actions implementing `I_AIAction`.
- Keep AI resource scripts organized under `scripts/demo/resources/ai/brain/`, `scripts/demo/resources/ai/bt/`, and `scripts/demo/resources/ai/actions/`. Do not reintroduce legacy `goals/` or `tasks/` resource folders.
- Honor `RS_AIBrainSettings.evaluation_interval` with `C_AIBrainComponent.evaluation_timer`. The first evaluation should run immediately when no BT state is running; running BT actions continue ticking every physics frame.
- `U_AIContextAssembler.build_context(...)` injects the active scene `ecs_manager` so scan/reserve/harvest/deposit/build actions can resolve authored ECS targets.
- Movement-sensitive actions resolve positions through `U_AIActionPositionResolver` before falling back to entity roots.
- `RS_BTAction` drives `I_AIAction.start/tick/is_complete`; per-node action state lives in `bt_state_bag`, keyed by BT node instance IDs.
- `RS_AIActionWait`, `RS_AIActionPublishEvent`, and `RS_AIActionSetField` remain instant/simple action building blocks. `RS_AIActionMoveTo`, `RS_AIActionScan`, and `RS_AIActionAnimate` are the movement/stub action baseline.
- `S_MoveTargetFollowerSystem` bridges active `C_MoveTargetComponent` payloads into world-space movement vectors. It has no legacy GOAP task-state fallback.
- `S_MovementSystem` routes AI-authored move vectors through world-space velocity handling while keeping player input camera-relative.
- `S_InputSystem` updates only player-tagged `C_InputComponent` entities so player input does not clobber AI-authored movement.
- Demo NPC entities should instance `scenes/core/prefabs/prefab_demo_npc.tscn`, inherit the shared character stack, use `Player_Body` as the runtime body path, and disable collision on custom CSG visuals.
- Author durable demo triggers through gameplay flags (`gameplay.ai_demo_flags.*`) rather than transient one-frame input fields.
- Shared unsupported recovery belongs to `C_SpawnRecoveryComponent` and `S_SpawnRecoverySystem`, not AI brain settings.
- Player-proximity detection uses `C_DetectionComponent` and `S_AIDetectionSystem`; tag-based detection must skip the detector entity itself.
- Predator consume loops lock prey identity during move-to-detected and consume that locked target first.

## Pitfalls

- AI placeholders must assign a valid `RS_AIBrainSettings` resource; missing or wrong-type settings abort component registration.
- BT branches that score from local readiness also need terminal-state gates, or agents can keep selecting obsolete no-op branches.
- Harvest actions must validate inventory acceptance before decrementing resource-node stock and must clear owned reservations after success or rejection.
- Acquire/deposit loops must be deficit-driven; filter source scans by the active deficit and cap deposits to outstanding requirements.
- Move completion radii must be compatible with downstream interaction/consume radii.
- AI demo flags are gameplay actions (`U_GameplayActions.set_ai_demo_flag`), not navigation actions.

## Repo Reality Checks

- General BT framework: `RS_BTNode`, composites (`Sequence`, `Selector`, `UtilitySelector`), decorators (`Inverter`, `Cooldown`, `Once`, `RisingEdge`) in `scripts/core/resources/bt/`; `U_BTRunner` in `scripts/core/utils/bt/`
- AI-specific BT nodes: `RS_BTAction`, `RS_BTCondition`, scorers (`RS_AIScorerConstant`, `RS_AIScorerCondition`, `RS_AIScorerContextField`), planner (`RS_BTPlanner`, `RS_BTPlannerAction`, `RS_WorldStateEffect`) in `scripts/demo/resources/ai/bt/`; planner search (`U_BTPlannerSearch`, `U_BTPlannerRuntime`, `U_AIWorldStateBuilder`) in `scripts/core/utils/ai/`
- Directory split enforced by style boundary tests: `scripts/core/resources/bt/` must not import AI-specific types (per ADR 0007)
- Action resources implementing `I_AIAction`: `RS_AIActionMoveTo`, `RS_AIActionWait`, `RS_AIActionScan`, `RS_AIActionAnimate`, `RS_AIActionPublishEvent`, `RS_AIActionSetField`, `RS_AIActionWander`, `RS_AIActionFeed`, `RS_AIActionHarvest`, `RS_AIActionDeposit` in `scripts/demo/resources/ai/actions/`
- QB Rule Manager v2 remains available for non-AI game logic: `U_RuleScorer`, `U_RuleSelector`, `U_RuleStateTracker`, `U_RuleValidator` in `scripts/core/utils/qb/`
- Typed conditions (`RS_ConditionComponentField`, `RS_ConditionReduxField`, `RS_ConditionEntityTag`, `RS_ConditionComposite`) in `scripts/core/resources/qb/conditions/` — implement `I_Condition.evaluate(context)`, consumed by `RS_BTCondition` and scorers
- `C_AIBrainComponent` enforces required settings at runtime: `brain_settings` must be a valid `RS_AIBrainSettings` resource
- Demo NPCs instance `scenes/core/prefabs/prefab_demo_npc.tscn` (inherits `tmpl_character.tscn`), keeping full shared character stacks plus AI additions
- `U_PathResolver` handles dot-path traversal for component fields, Redux state, and event payloads
- ECS pattern: systems extend `BaseECSSystem`, implement `process_tick(delta)`, query components via `get_components(StringName)`
- Entity tags available via `M_ECSManager` for entity queries
- ECS event bus (`U_ECSEventBus`) for decoupled gameplay events

## Goals

- Provide a general-purpose NPC behavior system driven entirely by `.tres` resource authoring (no hardcoded behavior logic)
- Support utility-scored branch selection: `RS_BTUtilitySelector` picks the highest-scoring viable child each tick
- Support decorator patterns: cooldown, one-shot, and rising-edge as `RS_BTCooldown`, `RS_BTOnce`, `RS_BTRisingEdge` wrapping subtrees
- Support opt-in planning: `RS_BTPlanner` backed by `U_BTPlannerSearch` for dynamic action sequencing
- Allow per-NPC behavior configuration via `C_AIBrainComponent` brain settings resource
- Integrate with existing ECS systems (movement, animation, events) for action execution
- Enable cooperative and non-hostile NPC patterns (not just combat AI)

## Non-Goals

- No runtime pathfinding mesh generation (uses Godot's built-in `NavigationServer3D` or simple waypoint paths)
- No blackboard system beyond `bt_state_bag` and context dictionary (component fields + Redux state + event payloads via `U_PathResolver`)
- No group coordination / squad AI (NPCs are individually autonomous)
- No perception system (line-of-sight, hearing) — proximity and state-based conditions are sufficient for demo scope
- No learning or adaptation (behaviors are static resource definitions)
- No GOAP/HTN — legacy goal/task/compound-task/planner resources were deleted in V8 P1.10

## Target Architecture

```
S_AIBehaviorSystem (scripts/core/ecs/systems/s_ai_behavior_system.gd)  [extends BaseECSSystem]
  Per-entity tick:
  ├── U_AIContextAssembler.build_context(...)    →  read-only context Dictionary
  ├── U_BTRunner.tick(root, context, bt_state_bag) →  int (RUNNING/SUCCESS/FAILURE)
  └── Respects evaluation_interval via C_AIBrainComponent.evaluation_timer

C_AIBrainComponent (scripts/core/ecs/components/c_ai_brain_component.gd)  [extends BaseECSComponent]
  @export var brain_settings: RS_AIBrainSettings
  Runtime state:
  ├── bt_state_bag: Dictionary          (per-node state keyed by node.get_instance_id())
  ├── evaluation_timer: float            (countdown to next BT evaluation)
  └── active_goal_id: StringName        (legacy compat, not used by BT runner)

RS_AIBrainSettings (scripts/demo/resources/ai/brain/rs_ai_brain_settings.gd)
  ├── @export var root: RS_BTNode             (BT root node)
  └── @export var evaluation_interval: float  (seconds between evaluations, default 0.5)

General BT Framework (scripts/core/resources/bt/):
  RS_BTNode               base class — Status enum (RUNNING/SUCCESS/FAILURE)
  RS_BTComposite          branch base — typed children: Array[RS_BTNode]
  ├── RS_BTSequence        children in order, fails on first FAILURE
  ├── RS_BTSelector        children in order, succeeds on first SUCCESS
  └── RS_BTUtilitySelector scored children — picks highest-scoring viable child
  RS_BTDecorator           wrapper base — child: RS_BTNode
  ├── RS_BTCooldown        suppresses child for duration after SUCCESS
  ├── RS_BTOnce            allows child SUCCESS once, then always SUCCESS
  ├── RS_BTRisingEdge      fires child only on false→true scorer transition
  └── RS_BTInverter        inverts child result

AI-Specific BT Nodes (scripts/demo/resources/ai/bt/):
  RS_BTAction             leaf wrapping I_AIAction (start/tick/is_complete)
  RS_BTCondition          leaf wrapping I_Condition (evaluate → bool)
  RS_BTPlanner            opt-in planner node backed by U_BTPlannerSearch
  RS_BTPlannerAction      planner action resource
  RS_WorldStateEffect     world-state effect for planning
  Scorers (scripts/demo/resources/ai/bt/scorers/):
  ├── RS_AIScorer            base — _get_score(context) → float
  ├── RS_AIScorerConstant     returns fixed if_true score
  ├── RS_AIScorerCondition    returns if_true when I_Condition evaluates true
  └── RS_AIScorerContextField reads a float from context dictionary

I_AIAction (scripts/core/interfaces/i_ai_action.gd)
  ├── func start(context: Dictionary, task_state: Dictionary) -> void
  ├── func tick(context: Dictionary, task_state: Dictionary, delta: float) -> void
  └── func is_complete(context: Dictionary, task_state: Dictionary) -> bool

Action resources (scripts/demo/resources/ai/actions/):
  RS_AIActionMoveTo, RS_AIActionWait, RS_AIActionScan,
  RS_AIActionAnimate, RS_AIActionPublishEvent, RS_AIActionSetField,
  RS_AIActionWander, RS_AIActionFeed, RS_AIActionHarvest, RS_AIActionDeposit
```

## Responsibilities & Boundaries

### AI System owns

- BT evaluation per entity via `U_BTRunner.tick()` at `evaluation_interval`
- Per-node runtime state management via `C_AIBrainComponent.bt_state_bag`
- Context assembly via `U_AIContextAssembler`
- Opt-in planning via `RS_BTPlanner` + `U_BTPlannerSearch`

### AI System depends on

- `M_ECSManager`: Component queries, entity registration
- `I_Condition` implementations: `RS_BTCondition` wraps QB condition resources for BT leaf checks
- `I_AIAction` implementations: `RS_BTAction` delegates execution to typed action resources
- Movement systems: Actions like `move_to` set targets that `S_MoveTargetFollowerSystem` executes
- ECS Event Bus: Actions like `publish_event` emit events for other systems to consume

### AI System does NOT own

- Navigation mesh / pathfinding computation (delegates to Godot `NavigationServer3D` or waypoint arrays)
- Actual movement execution (sets targets; movement systems move the body)
- Animation playback (requests states; animation system applies them)
- Visual representation (NPC visuals are separate scene nodes)
- QB rule scoring outside AI (`U_RuleScorer`/`U_RuleSelector` remain general-purpose utilities)

## Action Types

Each action is a typed resource implementing `I_AIAction` with `@export` fields for inspector authoring. Actions self-execute via `start()`, `tick()`, `is_complete()` and are dispatched polymorphically by `RS_BTAction` (no match blocks).

| Action Resource | Key Exports | Completion |
|----------------|-------------|------------|
| `RS_AIActionMoveTo` | `target_position`, `target_node_path`, `waypoint_index`, `arrival_threshold` | Reached within threshold distance |
| `RS_AIActionWait` | `duration` | Timer elapsed |
| `RS_AIActionScan` | `scan_duration`, `rotation_speed` | Duration elapsed |
| `RS_AIActionAnimate` | `animation_state` | Stub: completes immediately (sets state field) |
| `RS_AIActionPublishEvent` | `event_name`, `payload` | Instant (fire and advance) |
| `RS_AIActionSetField` | `field_path`, `value_type`, typed value exports | Instant |
| `RS_AIActionWander` | `home_radius` | Reached random point within radius |
| `RS_AIActionFeed` | (uses detected target) | Consume cycle complete |
| `RS_AIActionHarvest` | (uses ECS target) | Resource node harvested |
| `RS_AIActionDeposit` | (uses ECS target) | Inventory deposited |

## Demo Integration

NPC archetypes in the forest demo and Signal Lost rooms use utility-scored BTs:

1. **Wolf** (forest): Utility selector with 3 scored branches — `hunt_solo` (prey detected + hungry), `search_food` (hungry, cooldown-gated wander), `wander` (constant fallback). Hunt branch is a sequence: detect → move → feed.

2. **Deer** (forest): Utility selector with flee (predator proximity) and graze/wander branches.

3. **Rabbit** (forest): Utility selector with flee and wander branches.

4. **Patrol Drone** (Power Core): Utility selector — `patrol` (move between waypoints) and `investigate` (move/scan at activatable node). Investigate gated by gameplay flag `gameplay.ai_demo_flags.power_core_activated`.

5. **Sentry** (Comms Array): Utility selector — `guard` and `investigate_disturbance` branches. Investigate gated by `gameplay.ai_demo_flags.comms_disturbance_heard`.

6. **Guide Prism** (Nav Nexus): Utility selector — `show_path`, `encourage`, `celebrate` branches. Celebrate gated by `gameplay.ai_demo_flags.nav_goal_reached`.

## Implementation History

### V7.2: GOAP/HTN Stack (deleted in V8)

The original AI stack used GOAP goal selection with HTN task decomposition. It was replaced by utility-scored behavior trees in Cleanup V8 Phase 1 (P1.1–P1.10). Legacy resources (`RS_AIGoal`, `RS_AITask`, `RS_AICompoundTask`, `RS_AIPrimitiveTask`, `U_HTNPlanner`, goal selector, replanner, task runner) were deleted.

### V8 Phase 1: BT Migration (complete)

- P1.1–P1.5: BT framework scaffolding (node, composites, leaves, decorators, scorers)
- P1.6: `U_BTRunner` runtime driver
- P1.6b: Opt-in planner (`RS_BTPlanner`, `U_BTPlannerSearch`, world-state builder)
- P1.7: Brain component + brain settings migration to `root: RS_BTNode`
- P1.8: `S_AIBehaviorSystem` cutover + debug panel
- P1.9: Content migration (wolf, deer, rabbit, sentry, patrol_drone, guide_prism)
- P1.10: Legacy GOAP/HTN deletion

## Verification Checklist

1. BT utility selector switches behavior based on scorer-driven game state changes
2. BT sequence executes children in order; fails fast on FAILURE
3. Actions execute and complete (move_to reaches target, wait elapses)
4. Decorators gate behavior correctly (cooldown suppresses, one-shot fires once, rising-edge detects transitions)
5. Planner node produces valid action plans from world-state search
6. All demo NPCs behave as designed in their respective scenes
7. Style enforcement passes for all new files
8. No performance regression with multiple simultaneous AI NPCs

## Resolved Questions

| Question | Decision |
|----------|----------|
| GOAP vs BT vs utility AI? | Utility-scored BT with scoped planning. See ADR 0006. |
| Shared blackboard? | No. `bt_state_bag` is per-node runtime state only. Conditions read component fields, Redux state, and event payloads via `U_PathResolver`. |
| Planning scope? | Opt-in `RS_BTPlanner` node for branches that need dynamic sequencing. Not global. See ADR 0006. |
| Navigation? | Godot `NavigationServer3D` for complex levels; simple waypoint arrays for demo NPCs. |
| Perception? | Proximity + state-based conditions only. No raycasting LOS/hearing for demo scope. |

## Links

- [AI Extension Recipe](../../architecture/extensions/ai.md)
- [ADR 0006: Utility BT with Scoped Planning](../../architecture/adr/0006-ai-architecture-utility-bt-with-scoped-planning.md)
- [ADR 0007: BT Framework Scope](../../architecture/adr/0007-bt-framework-scope-general-vs-ai-specific.md)
- [QB Rule Manager v2 Overview](../qb_rule_manager/qb-v2-overview.md)
