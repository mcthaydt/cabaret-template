# AI Entity Authoring Template

Use this template before implementing any new AI entity. Fill every section first, then build exactly what is specified.

Suggested spec path per entity: `docs/ai_system/entities/ai-entity-<entity_name>.md`

---

## 1) Identity

- Entity name:
- Entity ID (`StringName`):
- Role/archetype summary (1-2 sentences):
- Scene/prefab path (expected): `scenes/prefabs/prefab_<name>.tscn`
- Owner scene(s) where this entity appears:

## 2) Runtime Contract (Must Be True)

- [ ] Base entity root is `BaseECSEntity` with explicit `entity_id`.
- [ ] Inherits from `scenes/templates/tmpl_character.tscn` (directly or via shared prefab).
- [ ] Has movement runtime stack required for AI movement:
- [ ] `CharacterBody3D`
- [ ] `C_InputComponent`
- [ ] `C_MovementComponent` with valid settings
- [ ] `C_AIBrainComponent` with non-null `RS_AIBrainSettings`
- [ ] If detection-based behavior exists: `C_DetectionComponent` configured with explicit `target_tag`.
- [ ] Visual CSG nodes under body use `use_collision = false` (avoid self-collision jitter).
- [ ] Any one-frame trigger dependency is replaced by durable state flags (Redux or component state).
- [ ] No design assumes `decision_group` on `RS_AIGoal` (goal selector uses hardcoded `&"ai_goal"`).

## 3) Tags And Detection Design

### 3.1 Entity tags on root

- Tags (`Array[StringName]`):
- Why each tag exists:

### 3.2 Detection components

For each detection role, fill one row:

| detection_role | target_tag | radius | enter_event_name | cooldown (if any) | Notes |
|---|---|---:|---|---:|---|
| primary |  |  |  |  |  |

### 3.3 Detection invariants

- Expected nearest-target policy:
- Self-exclusion requirement (same-tag scenarios):
- Behavior when no target found:

## 4) Brain Settings (`RS_AIBrainSettings`)

- Brain resource path: `resources/ai/<domain>/cfg_<name>_brain.tres`
- `default_goal_id`:
- `evaluation_interval`:
- Expected goal list order:

## 5) Goal Catalog (`RS_AIGoal`)

Add one block per goal.

### Goal: `<goal_id>`

- Goal resource path: `resources/ai/<domain>/cfg_goal_<goal_id>.tres`
- Priority:
- Score threshold:
- Cooldown:
- One-shot:
- Requires rising edge:
- Root task resource:
- Trigger inputs (state paths / component fields / event payload fields):
- Why this goal should win over competing goals:
- Explicit failure mode/fallback when conditions fail:

## 6) HTN/Task Plan

For each goal, define concrete decomposition and completion rules.

| goal_id | task_id sequence (in order) | action type per task | completion condition | abort/replan condition |
|---|---|---|---|---|
|  |  |  |  |  |

Implementation notes:
- `RS_AIActionMoveTo` target source (node path / entity / position):
- Arrival threshold strategy:
- Wait/scan durations:
- Events published (if any):
- Field writes via `RS_AIActionSetField` (if any):

## 7) Authoring Assets Checklist

- [ ] Prefab scene (`prefab_*.tscn`)
- [ ] Brain resource (`cfg_*_brain.tres`)
- [ ] Goal resources (`cfg_goal_*.tres`)
- [ ] Task resources (`cfg_task_*.tres`) where applicable
- [ ] Action resources (`cfg_action_*.tres`) where applicable
- [ ] Scene-specific overrides (list exact files):
- [ ] Debug label wiring (if needed for this entity type)

## 8) Observability And Debug Plan

- Expected `C_AIBrainComponent.get_debug_snapshot()` fields to monitor:
- Per-entity debug label format:
- Debug panel row expectations:
- Log/event checkpoints that prove behavior transitions:
- How to identify goal thrash quickly:

## 9) Test Plan (Required Before Merge)

### 9.1 Unit tests

- New/updated test files:
- RED cases to write first:
- GREEN conditions that must pass:

### 9.2 Integration tests

- Scene-level test coverage:
- Required assertions (goal selected, queue non-empty, transition behavior):
- Edge cases (target disappears, same-tag entities, no targets, cooldown behavior):

### 9.3 Mandatory suites

- [ ] `tests/unit/style/test_style_enforcement.gd`
- [ ] AI goal/task unit suites relevant to changed goals/actions
- [ ] At least one integration/smoke test covering this entity in-scene

## 10) Tuning Budget

- Movement speed/acceleration targets:
- Detection radius targets:
- Cooldown/interval ranges:
- Task timing ranges:
- Acceptable behavior variance (what "good enough" looks like):

## 11) Definition Of Done

- [ ] Runtime contract checklist complete (Section 2).
- [ ] All goals documented with clear win/fallback logic.
- [ ] All task completion/abort conditions documented.
- [ ] Durable triggers only (no one-frame pulse dependencies).
- [ ] Required tests written and green.
- [ ] Debug observability confirms expected goal/task transitions.
- [ ] Scene playtest shows behavior matching this document.

## 12) Post-Implementation Notes

- What changed from spec and why:
- Unexpected issues discovered:
- Pitfalls to add to `docs/general/DEV_PITFALLS.md`:
- Follow-up tasks (if any):
