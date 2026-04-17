# AI Entity Spec - Forest Rabbit

Concrete example spec authored from current forest runtime wiring.

Source template: `docs/ai_system/ai-entity-authoring-template.md`

## 1) Identity

- Entity name: Forest Rabbit
- Entity ID (`StringName`): prefab default `&"rabbit"`; scene instances override to `&"forest_rabbit_01"` ... `&"forest_rabbit_08"`
- Role/archetype summary: Prey entity that prioritizes fleeing predators, then idles/grazes, then wanders.
- Scene/prefab path: `scenes/prefabs/prefab_forest_rabbit.tscn`
- Owner scene(s): `scenes/gameplay/gameplay_ai_forest.tscn`

## 2) Runtime Contract (Must Be True)

- [x] Base entity root is `BaseECSEntity` with explicit `entity_id`.
- [x] Inherits from `scenes/templates/tmpl_character.tscn` via `scenes/prefabs/prefab_forest_agent.tscn`.
- [x] Has movement runtime stack required for AI movement.
- [x] `CharacterBody3D`
- [x] `C_InputComponent`
- [x] `C_MovementComponent` with valid settings (`resources/base_settings/ai_forest/cfg_movement_forest.tres`)
- [x] `C_AIBrainComponent` with non-null `RS_AIBrainSettings`
- [x] Detection behavior uses `C_DetectionComponent` with explicit `target_tag = &"predator"`.
- [x] Visual CSG under body uses `use_collision = false`.
- [x] No one-frame pulse dependency; behavior is driven by component state (`is_player_in_range`, detected entity id).
- [x] Goal design assumes shared hardcoded selector group `&"ai_goal"` (no goal-level `decision_group` field).

## 3) Tags And Detection Design

### 3.1 Entity tags on root

- Tags: `Array[StringName]([&"prey", &"ai", &"forest"])`
- Tag intent:
- `prey`: predator targeting identity.
- `ai`: generic AI filtering/debug grouping.
- `forest`: scene-domain grouping for ecosystem content.

### 3.2 Detection components

| detection_role | target_tag | radius | enter_event_name | cooldown (if any) | Notes |
|---|---|---:|---|---:|---|
| primary | `&"predator"` | `8.0` (`exit_radius = 16.0`) | none | none | Uses XZ distance (`detect_y_axis = false`) |

### 3.3 Detection invariants

- Nearest-target policy: nearest matching-tag target in range by XZ distance.
- Self-exclusion: must ignore own entity when source and target tags overlap (system-level guard).
- No-target behavior: detection clears `is_player_in_range` and `last_detected_player_entity_id`, then selector can fall back to `graze`/`wander`.

## 4) Brain Settings (`RS_AIBrainSettings`)

- Brain resource path: `resources/ai/forest/rabbit/cfg_rabbit_brain.tres`
- `default_goal_id`: `&"wander"`
- `evaluation_interval`: `0.25`
- Goal list order: `[flee, graze, wander]`

## 5) Goal Catalog (`RS_AIGoal`)

### Goal: `flee`

- Goal resource: `resources/ai/forest/shared/cfg_goal_flee.tres`
- Priority: `10`
- Score threshold: `0.0` (default)
- Cooldown: `0.0` (default)
- One-shot: `false` (default)
- Requires rising edge: `false` (default)
- Root task: primitive `flee_from_detected`
- Trigger inputs:
- `C_DetectionComponent.is_player_in_range == true`
- `C_DetectionComponent.last_detected_player_entity_id` used by flee target resolution
- Win rationale: outranks all non-threat goals whenever predator detection is positive.
- Fallback: when detection is false/stale, selector drops to `graze` (then `wander`).

### Goal: `graze`

- Goal resource: `resources/ai/forest/shared/cfg_goal_graze.tres`
- Priority: `2`
- Score threshold: `0.0` (default)
- Cooldown: `4.0`
- One-shot: `false` (default)
- Requires rising edge: `false` (default)
- Root task: primitive `graze_wait`
- Trigger inputs: constant score condition (`0.5`)
- Win rationale: baseline idle behavior when not under threat; outranks `wander` score (`0.3`).
- Fallback: if cooldown blocks `graze`, selector can pick `wander`.

### Goal: `wander`

- Goal resource: `resources/ai/forest/shared/cfg_goal_wander.tres`
- Priority: `0`
- Score threshold: `0.0` (default)
- Cooldown: `0.0` (default)
- One-shot: `false` (default)
- Requires rising edge: `false` (default)
- Root task: primitive `wander`
- Trigger inputs: constant score condition (`0.3`)
- Win rationale: always-available fallback.
- Fallback: none required.

## 6) HTN/Task Plan

| goal_id | task sequence | action type per task | completion condition | abort/replan condition |
|---|---|---|---|---|
| `flee` | `flee_from_detected` | `RS_AIActionFleeFromDetected` | XZ distance to flee target <= `0.6`; stale/missing detection completes early | selector-driven replan on goal change or queue completion |
| `graze` | `graze_wait` | `RS_AIActionWait` | wait duration `1.8s` elapsed | selector-driven replan on goal change or queue completion |
| `wander` | `wander` | `RS_AIActionWander` | XZ distance to sampled target <= `arrival_threshold` (`0.5` default) | selector-driven replan on goal change or queue completion |

Implementation notes:
- Flee target is computed as `self + normalize(self - detected) * flee_distance`.
- Flee tunables from goal resource: `flee_distance = 12.0`, `arrival_threshold = 0.6`.
- `graze` and `wander` are non-event baseline behaviors.

## 7) Authoring Assets Checklist

- [x] Prefab: `scenes/prefabs/prefab_forest_rabbit.tscn`
- [x] Brain: `resources/ai/forest/rabbit/cfg_rabbit_brain.tres`
- [x] Goals: `resources/ai/forest/shared/cfg_goal_flee.tres`, `cfg_goal_graze.tres`, `cfg_goal_wander.tres`
- [x] Task/action resources are embedded as goal subresources in current authoring
- [x] Scene overrides: `scenes/gameplay/gameplay_ai_forest.tscn` entity IDs + transforms
- [x] Debug label wiring inherited from `prefab_forest_agent`

## 8) Observability And Debug Plan

- `C_AIBrainComponent.get_debug_snapshot()` fields to monitor: `entity_id`, `goal_id`, `task_id`, `is_player_in_range`, `detection_radius`, `detection_exit_radius`
- Per-entity label format:
- `<entity_id>`
- `goal: <goal_id>`
- `task: <task_id>`
- `detect:<bool> [exit:<radius when > detection_radius>]`
- Transition checkpoints:
- `graze/wander -> flee` when predator enters detection radius.
- `flee -> graze/wander` when predator exits hysteresis radius or detection goes stale.

## 9) Test Plan

### 9.1 Unit tests

- `tests/unit/ecs/systems/test_s_ai_detection_system_tag_target.gd`
- `tests/unit/ai/actions/test_ai_actions_forest.gd`
- `tests/unit/debug/test_debug_forest_agent_label.gd`
- `tests/unit/debug/test_debug_ai_brain_panel.gd`

### 9.2 Integration tests

- `tests/integration/gameplay/test_forest_ecosystem_smoke.gd`
- Assertions: rabbit brains select active goals and maintain non-empty task queues after warm-up.

### 9.3 Mandatory suites

- [ ] `tests/unit/style/test_style_enforcement.gd`
- [ ] Relevant AI unit suites for detection/actions/debug labels
- [ ] Forest integration smoke suite

## 10) Tuning Budget

- Movement settings target (`cfg_movement_forest`):
- `max_speed = 8.0`
- `acceleration = 28.0`
- `deceleration = 32.0`
- Detection radii:
- enter `8.0`
- exit `16.0`
- Evaluation cadence: `0.25s`
- Flee behavior: `flee_distance = 12.0`, arrival threshold `0.6`

## 11) Definition Of Done

- [x] Runtime contract checklist complete for authored rabbit prefab.
- [x] Goals documented with win/fallback logic.
- [x] Task completion/abort behavior documented.
- [x] Durable trigger behavior only.
- [ ] Required test suites executed and green for current patch.
- [x] Debug observability paths defined.
- [ ] Manual in-scene verification completed for current patch.

## 12) Post-Implementation Notes

- This document mirrors current rabbit behavior as implemented on 2026-04-16.
- If rabbit behavior changes (hunger weighting, species-specific flee tuning), update this spec in the same PR.
