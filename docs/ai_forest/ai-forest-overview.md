# AI Forest Simulation — Overview

## Purpose

Visually verify the GOAP/HTN AI system end-to-end in an environment that isolates AI behavior from unrelated subsystems. The existing AI showcase scene (`scenes/gameplay/gameplay_ai_showcase.tscn`) pulls in ~40 non-AI systems (VCAM, VFX, input, touchscreen, health/damage, post-processing, etc.), which makes it hard to tell whether misbehavior is an AI bug or a cross-system interaction. A top-down "forest" scene with colored cubes and floating labels — driven only by the minimum set of systems needed for AI to function — produces a clean, unambiguous signal.

**Intended outcome**: a standalone scene with multiple species exhibiting emergent predator/prey behavior, ambient needs (hunger), and eventually pack coordination. Each agent carries a Label3D showing its current goal + task, and a separate debug panel aggregates the same info in a scannable list.

## Scope

**In scope (across all three phases)**
- New scene: `scenes/gameplay/gameplay_ai_forest.tscn` (top-down ortho camera, 60×60 unit arena)
- Scene registry entry: `resources/scene_registry/cfg_ai_forest_entry.tres` so `M_SceneManager` can load it by `scene_id = &"ai_forest"`
- 4 wolves, 8 rabbits, 6 deer, ~30 static trees
- Generalize `S_AIDetectionSystem` to detect entities by arbitrary tag read from the entity root (`BaseECSEntity.tags`), not just player-tagged entities
- New `C_NeedsComponent` + `RS_NeedsSettings` + `S_NeedsSystem` for hunger/satiety
- New AI goal/task/action resources under `resources/ai/forest/`
- Label3D per agent + `debug_ai_brain_panel` control (lives under `scripts/debug/` + `scenes/debug/`)
- Unit + integration tests for every new component, system, action, and resource

**Out of scope**
- Player character in the scene (pure-observer demo)
- Persistence / save support for forest state
- Audio or VFX for forest agents
- Mobile optimization (desktop-only)
- Replacement or refactor of the existing showcase scene

**Implementation note (Phase 1 closeout)**:
- `gameplay_ai_forest.tscn` includes inert gameplay-contract anchors (`Entities/E_PlayerObserver` and `Entities/SpawnPoints/sp_default`) to satisfy scene-validation requirements without introducing a playable/player-driven runtime stack.

## Architecture

### Systems touched

| System / component | Role in forest | New? |
|---|---|---|
| `S_AIBehaviorSystem` | Goal selection + task execution (orchestrator) | Reused as-is |
| `S_MoveTargetFollowerSystem` | Bridges `C_MoveTargetComponent` / brain `task_state` move target → `C_InputComponent.move_vector` | Reused |
| `S_AIDetectionSystem` | Proximity detection, now tag-parametrized | **Modified (Phase 1a)** |
| `S_MovementSystem` | Applies move vector to `CharacterBody3D` | Reused |
| `S_GravitySystem`, `S_FloatingSystem` | Keeps agents grounded | Reused |
| `S_NeedsSystem` | Ticks hunger decay | **New (Phase 2)** |
| `C_AIBrainComponent` | Per-agent brain state + `get_debug_snapshot()` | Reused |
| `C_DetectionComponent` | Gains `target_tag: StringName = &"player"` export | **Modified (Phase 1a)** |
| `C_MoveTargetComponent` | Primary move-target channel consumed by `S_MoveTargetFollowerSystem` | Reused (added to prefab) |
| `C_NeedsComponent` | Hunger runtime state | **New (Phase 2)** |
| `BaseECSEntity.tags` | Source of truth for entity tagging (on the entity root) | Reused, authored per species |
| `debug_ai_brain_panel` | Control with one row per brain entity | **New (Phase 1e)** |
| Per-agent `Label3D` | Floating entity_id + goal + task text | **New (Phase 1e)** |

### Data flow

```
C_AIBrainComponent ──(debug snapshot)──▶ debug_ai_brain_panel + Label3D (read at 4 Hz)
        ▲
        │ (populated each tick)
S_AIBehaviorSystem ──(queries)──▶ RS_AIGoal.conditions (reads C_DetectionComponent, C_NeedsComponent)
        │
        └──▶ U_HTNPlanner ──▶ RS_AIPrimitiveTask queue ──▶ I_AIAction.tick() ──▶ task_state + C_MoveTargetComponent
                                                                                     │
                                                                                     ▼
                                                  S_MoveTargetFollowerSystem ──▶ C_InputComponent.set_move_vector()
                                                                                     │
                                                                                     ▼
                                                                              S_MovementSystem ──▶ CharacterBody3D
```

**Important invariant (`U_AIGoalSelector`):** every goal internally competes in the hardcoded `&"ai_goal"` decision group — there is no designer-accessible decision group on `RS_AIGoal`. Goal-thrash prevention is via `cooldown`, `requires_rising_edge`, and `one_shot` per goal, not per-group rule competition.

## Species specification

Tags are authored on each prefab's entity-root `BaseECSEntity.tags` array (as in `prefab_demo_npc.tscn`: `tags = Array[StringName]([&"npc", &"ai", &"character"])`).

| Role | Entity-root tags | Detection `target_tag` | Color | Goals (Phase 1 → 3) |
|---|---|---|---|---|
| **Wolf** | `[&"predator", &"ai", &"forest"]` | `&"prey"` | Dark gray | Phase 1: `hunt`, `wander` · Phase 2: `hunt` weighted by hunger · Phase 3: add `hunt_pack` with a second `C_DetectionComponent` targeting `&"predator"` |
| **Rabbit** | `[&"prey", &"ai", &"forest"]` | `&"predator"` | White | Phase 1: `flee`, `wander`, `graze` · Phase 2: `graze` weighted by hunger |
| **Deer** | `[&"herbivore", &"ai", &"forest"]` | `&"predator"` | Brown | Phase 1: `graze`, `startle`, `wander` · Phase 2: `graze` weighted by hunger |
| **Tree** | (none) | — | Dark green | Static StaticBody3D, no brain |

## Phase roadmap

### Phase 1 — Scene shell + species behaviors + detection generalization
Shippable slice: visually confirmable predator/prey behavior without hunger or pack. Wolves chase the nearest rabbit; rabbits flee; deer startle when a wolf is nearby; trees are decoration.

**Current verification status (2026-04-16)**: automated suites are green; manual visual pass is still pending.

**Acceptance criteria**
- [ ] Scene boots and all brain-bearing agents produce non-empty task queues within 2 seconds
- [ ] Wolves converge on rabbits visually
- [ ] Rabbits visibly accelerate away when a wolf is within detection radius
- [ ] Deer visibly switch from `graze` to `startle` when a wolf enters their detection radius
- [ ] Each agent's Label3D displays `entity_id\ngoal: X\ntask: Y` and updates live
- [ ] Debug panel lists every brain entity with its current goal/task
- [ ] Existing 124-test AI unit-suite baseline remains green (re-measure before and after Phase 1a)
- [ ] New Phase 1 test suites green
- [ ] `test_style_enforcement.gd` suite green (including HUD-embedding, task-state key, and AI-resource-layout rules)

### Phase 2 — Hunger / satiety
Agents grow hungry over time; hunger weights `hunt`/`graze` goal scores via `RS_ConditionComponentField` reading `C_NeedsComponent.hunger`.

**Acceptance criteria**
- [ ] `C_NeedsComponent.hunger` decays toward 0 at `settings.decay_per_second`
- [ ] Wolves below `sated_threshold` pick `hunt` over `wander`
- [ ] Rabbits + deer below `sated_threshold` pick `graze` over `wander`
- [ ] `RS_AIActionFeed` sets hunger toward 1.0 when a `graze`/`hunt` compound task completes
- [ ] Debug panel + Label3D display per-agent hunger (color-coded)
- [ ] New Phase 2 test suites green

### Phase 3 — Emergent pack behavior + polish
Wolves that share a pack-detection radius converge on the same prey without an explicit coordinator. Note: per-entity goal competition is still in the shared `ai_goal` group — new goals use `priority` + `cooldown` + `requires_rising_edge` to avoid thrashing `hunt` ↔ `hunt_pack`.

**Acceptance criteria**
- [ ] Two wolves within pack-detection radius independently select the same `detected_entity_id` for hunting within 2 seconds
- [ ] No thrashing between `hunt` and `hunt_pack` (tuned via cooldown + priority, not a separate decision group)
- [ ] All three phases' test suites remain green
- [ ] Style enforcement tests pass for every new file

## Related docs

- `docs/ai_system/ai-system-overview.md` — existing AI architecture
- `docs/adr/0001-channel-taxonomy.md` — publisher-based channel rules
- `docs/scene_manager/ADDING_SCENES_GUIDE.md` — scene-registry registration workflow
- `AGENTS.md` — AI goal-loop pattern, typed-contract pattern, demo-scene authoring contract
- `docs/ai_forest/ai-forest-tasks.md` — commit-level task checklist
- `docs/ai_forest/ai-forest-continuation-prompt.md` — resume prompt
