# AI System Overview (GOAP / HTN)

**Project**: Cabaret Template (Godot 4.6)
**Created**: 2026-03-31
**Last Updated**: 2026-04-02
**Status**: IMPLEMENTATION IN PROGRESS (M4 complete)
**Scope**: Quality-based NPC behavior selection using GOAP goals and HTN task decomposition, powered by QB Rule Manager v2

## Summary

The AI system provides data-driven NPC behavior through two complementary paradigms: **GOAP** (Goal-Oriented Action Planning) for goal selection and **HTN** (Hierarchical Task Network) for task decomposition. In the target runtime design, QB v2 rules score candidate goals/behaviors (0.0-1.0), the winner becomes the active behavior, and an HTN planner decomposes compound tasks into executable primitive actions. This will run as an ECS system (`S_AIBehaviorSystem`) consuming `C_AIBrainComponent` data, with behavior definitions authored as `.tres` resources.

## Repo Reality Checks

- QB Rule Manager v2 is fully implemented: `U_RuleScorer`, `U_RuleSelector`, `U_RuleStateTracker`, `U_RuleValidator` in `scripts/utils/qb/`
- Existing QB consumers provide the pattern: `S_CharacterStateSystem`, `S_GameEventSystem`, `S_CameraStateSystem` each compose QB utilities directly (no base-class inheritance)
- Typed conditions (`RS_ConditionComponentField`, `RS_ConditionReduxField`, `RS_ConditionEntityTag`, etc.) in `scripts/resources/qb/conditions/` — implement `I_Condition.evaluate(context)` for polymorphic dispatch
- Typed effects (`RS_EffectDispatchAction`, `RS_EffectPublishEvent`, `RS_EffectSetField`, etc.) in `scripts/resources/qb/effects/` — implement `I_Effect.execute(context)` for polymorphic dispatch
- M1-M4 implemented scaffolding: `I_AIAction`, `RS_AITask`, `RS_AIPrimitiveTask`, `RS_AICompoundTask`, `RS_AIGoal`, `RS_AIBrainSettings`, `C_AIBrainComponent`, and `U_HTNPlanner`
- `C_AIBrainComponent` enforces required settings at runtime: `brain_settings` must be a valid `RS_AIBrainSettings` resource
- M6/M7 planned: typed `RS_AIAction*` resources will implement `I_AIAction` with `start()`, `tick()`, `is_complete()` for self-executing task logic
- `U_PathResolver` handles dot-path traversal for component fields, Redux state, and event payloads
- ECS pattern: systems extend `BaseECSSystem`, implement `process_tick(delta)`, query components via `get_components(StringName)`
- Component pattern: extend `BaseECSComponent`, define `const COMPONENT_TYPE := StringName("...")`, use `@export` NodePaths with typed getters
- Entity tags available via `M_ECSManager` for entity queries
- ECS event bus (`U_ECSEventBus`) for decoupled gameplay events

## Goals

- Provide a general-purpose NPC behavior system driven entirely by `.tres` resource authoring (no hardcoded behavior logic)
- Support GOAP goal selection: each NPC evaluates a set of goals per tick, QB scoring picks the active goal
- Support HTN task decomposition: compound tasks decompose into ordered primitive tasks; primitive tasks map to concrete actions (move_to, wait, scan, animate)
- Allow per-NPC behavior configuration via `C_AIBrainComponent` settings resource
- Integrate with existing ECS systems (movement, animation, events) for action execution
- Support cooldowns, one-shot behaviors, and salience (rising-edge) detection via existing QB v2 features
- Enable cooperative and non-hostile NPC patterns (not just combat AI)

## Non-Goals

- No runtime pathfinding mesh generation (uses Godot's built-in `NavigationServer3D` or simple waypoint paths)
- No blackboard system beyond what QB rule context provides (component fields + Redux state + event payloads)
- No behavior trees — GOAP/HTN replaces BT; the QB scorer is the decision layer
- No group coordination / squad AI (NPCs are individually autonomous)
- No perception system (line-of-sight, hearing) — proximity and state-based conditions are sufficient for demo scope
- No learning or adaptation (behaviors are static resource definitions)

## Target Architecture (M3-M10)

```
S_AIBehaviorSystem (scripts/ecs/systems/s_ai_behavior_system.gd)  [extends BaseECSSystem]
  Composes:
  ├── U_RuleScorer         (existing, scores goal rules 0.0-1.0)
  ├── U_RuleSelector       (existing, picks winner from scored rules)
  ├── U_RuleStateTracker   (existing, cooldowns + salience + one-shot)
  └── U_HTNPlanner         (NEW, scripts/utils/ai/u_htn_planner.gd)  [extends RefCounted]
        Decomposes compound tasks into primitive task queues

C_AIBrainComponent (scripts/ecs/components/c_ai_brain_component.gd)  [extends BaseECSComponent]
  @export_custom(PROPERTY_HINT_RESOURCE_TYPE, "RS_AIBrainSettings") var brain_settings: Resource
  Runtime state:
  ├── active_goal_id: StringName
  ├── current_task_queue: Array[RS_AIPrimitiveTask]
  ├── current_task_index: int
  └── task_state: Dictionary  (per-task scratch data)

Resources:
  RS_AIBrainSettings  (scripts/resources/ai/rs_ai_brain_settings.gd)
    ├── goals: Array[RS_AIGoal]         (candidate goals for this NPC)
    ├── default_goal_id: StringName     (fallback when no goal scores > 0)
    └── evaluation_interval: float      (ticks between full re-evaluations, default 0.5s)

  RS_AIGoal  (scripts/resources/ai/rs_ai_goal.gd)
    ├── goal_id: StringName
    ├── conditions: Array[Resource]     (QB v2 typed conditions — scored 0.0-1.0)
    ├── root_task: RS_AITask            (HTN entry point when this goal wins)
    └── priority: int                   (tiebreaker)

  RS_AITask  (scripts/resources/ai/rs_ai_task.gd)  [base class]
    ├── task_id: StringName

  RS_AICompoundTask  (scripts/resources/ai/rs_ai_compound_task.gd)  [extends RS_AITask]
    ├── subtasks: Array[RS_AITask]      (ordered decomposition)
    ├── method_conditions: Array[Resource]  (QB conditions for decomposition applicability)

  RS_AIPrimitiveTask  (scripts/resources/ai/rs_ai_primitive_task.gd)  [extends RS_AITask]
    └── action: Resource                (I_AIAction — typed action resource with @export fields)

  I_AIAction  (scripts/interfaces/i_ai_action.gd)  [interface]
    ├── func start(context: Dictionary, task_state: Dictionary) -> void
    ├── func tick(context: Dictionary, task_state: Dictionary, delta: float) -> void
    └── func is_complete(context: Dictionary, task_state: Dictionary) -> bool

  RS_AIActionMoveTo       (scripts/resources/ai/actions/rs_ai_action_move_to.gd)
    ├── @export var target_position: Vector3
    ├── @export var target_node_path: NodePath
    ├── @export var waypoint_index: int = -1
    └── @export var arrival_threshold: float = 0.5

  RS_AIActionWait         (scripts/resources/ai/actions/rs_ai_action_wait.gd)
    └── @export var duration: float = 1.0

  RS_AIActionScan         (scripts/resources/ai/actions/rs_ai_action_scan.gd)
    ├── @export var scan_duration: float = 2.0
    └── @export var rotation_speed: float = 1.0

  RS_AIActionAnimate      (scripts/resources/ai/actions/rs_ai_action_animate.gd)  [stub]
    └── @export var animation_state: StringName

  RS_AIActionPublishEvent (scripts/resources/ai/actions/rs_ai_action_publish_event.gd)
    ├── @export var event_name: StringName
    └── @export var payload: Dictionary

  RS_AIActionSetField     (scripts/resources/ai/actions/rs_ai_action_set_field.gd)
    ├── @export var field_path: String
    ├── @export_enum("float", "int", "bool", "string", "string_name") var value_type: String = "float"
    └── @export var float_value: float  (+ int_value, bool_value, etc.)
```

## Responsibilities & Boundaries

### AI System owns

- Per-NPC goal evaluation via QB v2 scoring each tick (or at `evaluation_interval`)
- HTN decomposition of winning goal's root task into a primitive task queue
- Primitive task execution lifecycle (start → tick → complete/fail → next)
- Task state tracking per-NPC (active goal, task queue, progress)
- Re-planning when goal changes mid-execution (abandon current queue, decompose new goal)

### AI System depends on

- `M_ECSManager`: Component queries, entity registration
- QB v2 utilities: `U_RuleScorer`, `U_RuleSelector`, `U_RuleStateTracker` for goal scoring
- `U_PathResolver`: Dot-path traversal for condition evaluation
- Movement/physics systems: Primitive tasks like `move_to` set target positions that existing movement systems execute
- Animation system (NEW): Primitive tasks like `animate` request animation states
- ECS Event Bus: Primitive tasks like `publish_event` emit events for other systems to consume

### AI System does NOT own

- Navigation mesh / pathfinding computation (delegates to Godot `NavigationServer3D` or waypoint arrays)
- Actual movement execution (sets targets; movement systems move the body)
- Animation playback (requests states; animation system applies them)
- Visual representation (NPC visuals are separate scene nodes)

## Planned Action Types (Initial Set)

Each action is a typed resource planned to implement `I_AIAction` with `@export` fields for inspector authoring. Actions will self-execute via `start()`, `tick()`, `is_complete()` and be dispatched polymorphically (no match blocks), matching QB v2 `I_Condition`/`I_Effect` patterns.

| Action Resource | Key Exports | Completion |
|----------------|-------------|------------|
| `RS_AIActionMoveTo` | `target_position`, `target_node_path`, `waypoint_index`, `arrival_threshold` | Reached within threshold distance |
| `RS_AIActionWait` | `duration` | Timer elapsed |
| `RS_AIActionScan` | `scan_duration`, `rotation_speed` | Duration elapsed |
| `RS_AIActionAnimate` | `animation_state` | Stub: completes immediately (sets state field) |
| `RS_AIActionPublishEvent` | `event_name`, `payload` | Instant (fire and advance) |
| `RS_AIActionSetField` | `field_path`, `value_type`, typed value exports | Instant |

## Planned Demo Integration (Signal Lost)

Three NPC archetypes are intended to prove the system:

1. **Patrol Drone** (Power Core): GOAP with 2 goals — `patrol` (move between waypoints) and `investigate` (pause when player activates a node). QB scores `proximity_to_player` and `node_recently_activated`.

2. **Sentry** (Comms Array): HTN with compound tasks — `guard_area` decomposes to [scan → patrol → scan], `investigate_disturbance` decomposes to [move_to_noise → scan → return]. QB scores `player_noise_level` and cooldown.

3. **Guide Prism** (Nav Nexus): Cooperative GOAP with 3 goals — `show_path` (move to next platform), `encourage` (fly to respawn, pulse), `celebrate` (spin + particles at goal). QB scores `player_progress`, `player_fell_recently`, `is_at_goal`.

## Implementation Phases

### Phase 1: Core Resources & Brain Component (M1–M3)
- Create `RS_AITask`, `RS_AIPrimitiveTask`, `RS_AICompoundTask` resource classes
- Create `I_AIAction` interface with `start()`, `tick()`, `is_complete()` contract
- Create `RS_AIGoal`, `RS_AIBrainSettings` resource classes
- Create `C_AIBrainComponent` with required brain-settings export and runtime state fields (completed in M3)
- Unit tests for resource serialization and component registration

### Phase 2: Goal Evaluation & HTN Planner (M4–M5)
- Create `U_HTNPlanner` (RefCounted) — decomposes compound tasks recursively into flat primitive task queue
- Method condition evaluation for decomposition branching, cycle detection
- Create `S_AIBehaviorSystem` extending `BaseECSSystem`
- Compose QB v2 utilities for goal scoring per-NPC per-tick
- Goal selection: highest-scoring goal becomes active; ties broken by priority
- Goal change detection: clear task queue on goal switch
- Unit tests for decomposition and goal scoring

Phase status: M4 complete (`U_HTNPlanner` + decomposition tests), M5 pending.

### Phase 3: Typed Action Resources (M6–M7)
- Create 6 typed action resources implementing `I_AIAction`: `RS_AIActionMoveTo`, `RS_AIActionWait`, `RS_AIActionScan`, `RS_AIActionAnimate` (stub), `RS_AIActionPublishEvent`, `RS_AIActionSetField`
- Each action resource has `@export` fields for inspector authoring and self-executing `start()`/`tick()`/`is_complete()` logic
- Task runner in `S_AIBehaviorSystem` dispatches polymorphically (no match blocks)
- Unit tests for each action in isolation

### Phase 4: Integration & Demo Scenes (M8–M9)
- End-to-end integration tests: goal evaluation → HTN decomposition → action execution → re-planning
- Create 3 demo gameplay scenes (Power Core, Comms Array, Nav Nexus) with CSG geometry, waypoints, triggers

### Phase 5: Demo NPC Authoring & Tuning (M10)
- Author `.tres` resources for Patrol Drone, Sentry, and Guide Prism
- Wire NPC entity scenes with `C_AIBrainComponent` + visual CSG meshes into demo scenes
- Ensure each placeholder NPC has a non-null placeholder `RS_AIBrainSettings` resource assigned (component registration rejects null/wrong type)
- Playtest and tune QB rule scores, cooldowns, evaluation intervals

## Verification Checklist

1. NPC with 2+ goals switches behavior based on game state changes
2. HTN decomposition produces correct primitive task sequence
3. Primitive tasks execute and complete (move_to reaches target, wait elapses)
4. Goal change mid-task-queue abandons old queue and starts new decomposition
5. Cooldowns prevent goal thrashing (via `U_RuleStateTracker`)
6. All 3 demo NPCs behave as designed in their respective rooms
7. Style enforcement passes for all new files
8. No performance regression with 3 simultaneous AI NPCs

## Resolved Questions

| Question | Decision |
|----------|----------|
| GOAP vs BT vs utility AI? | GOAP goals + HTN decomposition. QB v2 is the "utility AI" scoring layer. No behavior trees. |
| Shared blackboard? | No. QB conditions already read component fields, Redux state, and event payloads via `U_PathResolver`. No separate blackboard needed. |
| Navigation? | Godot `NavigationServer3D` for complex levels; simple waypoint arrays for demo NPCs. |
| Perception? | Proximity + state-based conditions only. No raycasting LOS/hearing for demo scope. |

## Links

- [AI System Plan](ai-system-plan.md)
- [AI System Tasks](ai-system-tasks.md)
- [AI System Continuation Prompt](ai-system-continuation-prompt.md)
- [QB Rule Manager v2 Overview](../qb_rule_manager/qb-v2-overview.md)
