# AI Entity Spec - Forest Wolf

Concrete example spec authored from current forest runtime wiring.

Source template: `docs/ai_system/ai-entity-authoring-template.md`

## 1) Identity

- Entity name: Forest Wolf
- Entity ID (`StringName`): prefab default `&"wolf"`; scene instances override to `&"forest_wolf_01"` ... `&"forest_wolf_04"`
- Role/archetype summary: Predator that hunts nearby prey when detected and otherwise roams within a bounded wander radius.
- Scene/prefab path: `scenes/prefabs/prefab_forest_wolf.tscn`
- Owner scene(s): `scenes/gameplay/gameplay_ai_forest.tscn`

## 2) Runtime Contract (Must Be True)

- [x] Base entity root is `BaseECSEntity` with explicit `entity_id`.
- [x] Inherits from `scenes/templates/tmpl_character.tscn` via `scenes/prefabs/prefab_forest_agent.tscn`.
- [x] Has movement runtime stack required for AI movement.
- [x] `CharacterBody3D`
- [x] `C_InputComponent`
- [x] `C_MovementComponent` with valid settings (`resources/base_settings/ai_forest/cfg_movement_forest.tres`)
- [x] `C_AIBrainComponent` with non-null `RS_AIBrainSettings`
- [x] Detection behavior uses `C_DetectionComponent` with explicit `target_tag = &"prey"`.
- [x] Visual CSG under body uses `use_collision = false`.
- [x] No one-frame pulse dependency; behavior is driven by component state (`is_player_in_range`, detected entity id).
- [x] Goal design assumes shared hardcoded selector group `&"ai_goal"` (no goal-level `decision_group` field).

## 3) Tags And Detection Design

### 3.1 Entity tags on root

- Tags: `Array[StringName]([&"predator", &"ai", &"forest"])`
- Tag intent:
- `predator`: target identity for prey/detection logic.
- `ai`: generic AI filtering/debug grouping.
- `forest`: scene-domain grouping for ecosystem content.

### 3.2 Detection components

| detection_role | target_tag | radius | enter_event_name | cooldown (if any) | Notes |
|---|---|---:|---|---:|---|
| primary | `&"prey"` | `12.0` (`exit_radius = 18.0`) | none | none | Uses XZ distance (`detect_y_axis = false`) |

### 3.3 Detection invariants

- Nearest-target policy: nearest matching-tag target in range by XZ distance.
- Self-exclusion: must ignore own entity when source and target tags overlap (system-level guard).
- No-target behavior: detection clears `is_player_in_range` and `last_detected_player_entity_id`, then goals fall back to `wander`.

## 4) Brain Settings (`RS_AIBrainSettings`)

- Brain resource path: `resources/ai/forest/wolf/cfg_wolf_brain.tres`
- `default_goal_id`: `&"wander"`
- `evaluation_interval`: `0.25`
- Goal list order: `[hunt, wander]`

## 5) Goal Catalog (`RS_AIGoal`)

### Goal: `hunt`

- Goal resource: `resources/ai/forest/shared/cfg_goal_hunt.tres`
- Priority: `10`
- Score threshold: `0.0` (default)
- Cooldown: `0.0` (default)
- One-shot: `false` (default)
- Requires rising edge: `false` (default)
- Root task: `hunt_sequence` compound task
- Trigger inputs:
- `C_DetectionComponent.is_player_in_range == true`
- `C_DetectionComponent.last_detected_player_entity_id` used by action resolution
- Win rationale: outranks `wander` (score `0.3`) whenever prey detection condition passes.
- Fallback: if prey not detected or detected entity is stale/missing, task completes and selector returns to `wander`.

### Goal: `wander`

- Goal resource: `resources/ai/forest/shared/cfg_goal_wander.tres`
- Priority: `0`
- Score threshold: `0.0` (default)
- Cooldown: `0.0` (default)
- One-shot: `false` (default)
- Requires rising edge: `false` (default)
- Root task: primitive `wander`
- Trigger inputs:
- Constant score condition (`0.3`)
- Win rationale: baseline behavior when no higher-priority goal condition passes.
- Fallback: none required; this is the fallback/default behavior.

## 6) HTN/Task Plan

| goal_id | task sequence | action type per task | completion condition | abort/replan condition |
|---|---|---|---|---|
| `hunt` | `move_to_detected_first -> wait_hunt_mid -> move_to_detected_second` | `RS_AIActionMoveToDetected`, `RS_AIActionWait`, `RS_AIActionMoveToDetected` | move actions repath every tick to live detected target position and complete when XZ distance <= `0.6`; wait completes at `0.4s` | selector-driven replan on goal change or queue completion |
| `wander` | `wander` | `RS_AIActionWander` | XZ distance to sampled target <= `arrival_threshold` (`0.5` default) | selector-driven replan on goal change or queue completion |

Implementation notes:
- Move target source: detected entity resolved by `last_detected_player_entity_id`.
- Arrival thresholds: hunt `0.6`; wander default `0.5`.
- Wait/scan durations: hunt wait `0.4`; no scan action in wolf spec.
- Events published: none by wolf goals.
- Field writes: none via `RS_AIActionSetField`.

## 7) Authoring Assets Checklist

- [x] Prefab: `scenes/prefabs/prefab_forest_wolf.tscn`
- [x] Brain: `resources/ai/forest/wolf/cfg_wolf_brain.tres`
- [x] Goals: `resources/ai/forest/shared/cfg_goal_hunt.tres`, `resources/ai/forest/shared/cfg_goal_wander.tres`
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
- Debug panel row expectation: `<entity> | goal=<goal> | task=<task> | detect=<bool> [exit=<radius>]`
- Transition checkpoints:
- `wander -> hunt` when prey enters detection radius.
- `hunt -> wander` when prey exits hysteresis radius or detection goes stale.
- Goal-thrash signal: frequent rapid goal flips per refresh tick without sustained detection change.

## 9) Test Plan

### 9.1 Unit tests

- Relevant existing suites:
- `tests/unit/ecs/systems/test_s_ai_detection_system_tag_target.gd`
- `tests/unit/ai/actions/test_ai_actions_forest.gd`
- `tests/unit/debug/test_debug_forest_agent_label.gd`
- `tests/unit/debug/test_debug_ai_brain_panel.gd`

### 9.2 Integration tests

- Required scene smoke:
- `tests/integration/gameplay/test_forest_ecosystem_smoke.gd`
- Key assertions:
- Wolves obtain non-empty task queues.
- Wolves select non-empty active goals after warm-up.
- Detection-driven goals can resolve valid target entity IDs.

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
- enter `12.0`
- exit `18.0`
- Evaluation cadence: `0.25s`
- Hunt wait duration: `0.4s`
- Acceptable variance: wolves should reliably acquire nearby prey and continue motion without self-collision jitter.

## 11) Definition Of Done

- [x] Runtime contract checklist complete for authored wolf prefab.
- [x] Goals documented with win/fallback logic.
- [x] Task completion/abort behavior documented.
- [x] Durable trigger behavior only.
- [ ] Required test suites executed and green for current patch.
- [x] Debug observability paths defined.
- [ ] Manual in-scene verification completed for current patch.

## 12) Post-Implementation Notes

- This document mirrors current wolf behavior as implemented on 2026-04-16.
- If wolf behavior changes (hunger weighting, pack-hunt, extra detection roles), update this spec in the same PR.
