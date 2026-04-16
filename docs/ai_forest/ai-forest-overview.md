# AI Forest Simulation — Overview

## Purpose

Visually verify the GOAP/HTN AI system end-to-end in an environment that isolates AI behavior from unrelated subsystems. The existing AI showcase scene (`scenes/gameplay/gameplay_ai_showcase.tscn`) pulls in ~40 non-AI systems (VCAM, VFX, input, touchscreen, health/damage, post-processing, etc.), which makes it hard to tell whether misbehavior is an AI bug or a cross-system interaction. A top-down "forest" scene with colored cubes and floating labels — driven only by the minimum set of systems needed for AI to function — produces a clean, unambiguous signal.

**Intended outcome**: a standalone scene with multiple species exhibiting emergent predator/prey behavior, ambient needs (hunger), and eventually pack coordination. Each agent carries a Label3D showing its current goal + task, and a 2D HUD panel aggregates the same info in a scannable list.

## Scope

**In scope (across all three phases)**
- New scene `scenes/gameplay/gameplay_ai_forest.tscn` (top-down ortho camera, 60×60 unit arena)
- 4 wolves, 8 rabbits, 6 deer, ~30 static trees
- Generalize `C_DetectionComponent` to detect entities by arbitrary tag (not just `C_PlayerTagComponent`)
- New `C_NeedsComponent` + `RS_NeedsSettings` + `S_NeedsSystem` for hunger/satiety
- New AI goal/task/action resources under `resources/ai/forest/`
- Label3D per agent + `UI_AIBrainDebugOverlay` HUD panel
- Unit + integration tests for every new component, system, action, and resource

**Out of scope**
- Persistence / save support for forest state
- Audio or VFX for forest agents
- Player character in the scene
- Mobile optimization (desktop-only)
- Replacement or refactor of the existing showcase scene

## Architecture

### Systems touched

| System / component | Role in forest | New? |
|---|---|---|
| `S_AIBehaviorSystem` | Goal selection + task execution (orchestrator) | Reused as-is |
| `S_MoveTargetFollowerSystem` | Translates `task_state["ai_move_target"]` into `C_InputComponent.move_input` | Reused |
| `S_AIDetectionSystem` | Proximity detection by tag | **Generalized (Phase 1a)** |
| `S_MovementSystem` | Applies move vector to `CharacterBody3D` | Reused |
| `S_GravitySystem`, `S_FloatingSystem` | Keeps agents grounded | Reused |
| `S_NeedsSystem` | Ticks hunger decay | **New (Phase 2)** |
| `C_AIBrainComponent` | Per-agent brain state + `get_debug_snapshot()` | Reused |
| `C_DetectionComponent` | Adds `target_tag` exported field | **Modified (Phase 1a)** |
| `C_EntityTagComponent` | Agent tagging (`predator`, `prey`, `herbivore`) | Reused |
| `C_NeedsComponent` | Hunger runtime state | **New (Phase 2)** |
| `UI_AIBrainDebugOverlay` | HUD panel aggregating all brains | **New (Phase 1e)** |
| Per-agent `Label3D` | Floating entity_id + goal + task text | **New (Phase 1e)** |

### Data flow

```
C_AIBrainComponent ──(debug snapshot)──▶ UI_AIBrainDebugOverlay + Label3D (read at 4 Hz)
        ▲
        │ (populated each tick)
S_AIBehaviorSystem ──(queries)──▶ RS_AIGoal.conditions (reads C_DetectionComponent, C_NeedsComponent)
        │
        └──▶ U_HTNPlanner ──▶ RS_AIPrimitiveTask queue ──▶ I_AIAction.tick() ──▶ task_state
                                                                                     │
                                                                                     ▼
                                                  S_MoveTargetFollowerSystem ──▶ C_InputComponent.move_input
                                                                                     │
                                                                                     ▼
                                                                              S_MovementSystem ──▶ CharacterBody3D
```

## Species specification

| Role | Tag | `target_tag` | Color | Goals (Phase 1 → 3) |
|---|---|---|---|---|
| **Wolf** | `predator` | `prey` | Dark gray | Phase 1: `hunt`, `wander` · Phase 2: add `hunt` weighted by hunger · Phase 3: add `hunt_pack` with wider pack-detection radius |
| **Rabbit** | `prey` | `predator` | White | Phase 1: `flee`, `wander`, `graze` · Phase 2: `graze` weighted by hunger |
| **Deer** | `herbivore` | `predator` | Brown | Phase 1: `graze`, `startle`, `wander` · Phase 2: `graze` weighted by hunger |
| **Tree** | (none) | — | Dark green | Static StaticBody3D, no brain |

## Phase roadmap

### Phase 1 — Scene shell + species behaviors + detection generalization
Shippable slice: visually confirmable predator/prey behavior without hunger or pack. Wolves chase the nearest rabbit; rabbits flee; deer startle when a wolf is nearby; trees are decoration.

**Acceptance criteria**
- [ ] Scene boots and all brain-bearing agents produce non-empty task queues within 2 seconds
- [ ] Wolves converge on rabbits visually
- [ ] Rabbits visibly accelerate away when a wolf is within detection radius
- [ ] Deer visibly switch from `graze` to `startle` when a wolf enters their detection radius
- [ ] Each agent's Label3D displays `entity_id\ngoal: X\ntask: Y` and updates live
- [ ] HUD overlay lists every brain entity with its current goal/task
- [ ] Existing 124/124 AI unit tests remain green
- [ ] New Phase 1 test suites green

### Phase 2 — Hunger / satiety
Agents grow hungry over time; hunger weights `hunt`/`graze` goal scores via `RS_ConditionComponentField` reading `C_NeedsComponent.hunger`.

**Acceptance criteria**
- [ ] `C_NeedsComponent.hunger` decays toward 0 at `settings.decay_per_second`
- [ ] Wolves below `sated_threshold` pick `hunt` over `wander`
- [ ] Rabbits + deer below `sated_threshold` pick `graze` over `wander`
- [ ] `RS_AIActionFeed` sets hunger toward 1.0 when `graze`/`hunt` completes successfully
- [ ] HUD overlay displays per-agent hunger (color-coded)
- [ ] New Phase 2 test suites green

### Phase 3 — Emergent pack behavior + polish
Wolves that share a pack-detection radius converge on the same prey without an explicit coordinator.

**Acceptance criteria**
- [ ] Two wolves within pack-detection radius independently select the same `detected_entity_id` for hunting within 2 seconds
- [ ] No thrashing between `hunt` and `hunt_pack` goals (cooldown + `decision_group = &"forest_action"`)
- [ ] All three phases' test suites remain green
- [ ] Style enforcement tests pass for every new file

## Related docs

- `docs/ai_system/ai-system-overview.md` — existing AI architecture
- `docs/adr/0001-channel-taxonomy.md` — publisher-based channel rules
- `AGENTS.md` — AI goal-loop pattern, typed-contract pattern, demo-scene authoring contract
- `docs/ai_forest/ai-forest-tasks.md` — commit-level task checklist
- `docs/ai_forest/ai-forest-continuation-prompt.md` — resume prompt
