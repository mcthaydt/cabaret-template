# AI Forest Simulation — Continuation Prompt

## Overview

This prompt directs you to implement the AI Forest Simulation by executing `docs/ai_forest/ai-forest-tasks.md` in sequential order, respecting the phase dependency chain. The full specification lives in `docs/ai_forest/ai-forest-overview.md`.

**Branch**: GOAP-AI
**Status**: Documentation delivered — **Phase 1a next** (awaiting explicit user go-ahead before implementation).
**Next task**: Phase 1a Commit 1 — write failing tests for tag-based detection in `tests/unit/ecs/systems/test_s_ai_detection_system_tag_target.gd`.
**Prerequisite**: Baseline AI suite green (124/124 last measured 2026-04-16). Re-run before starting Phase 1a to confirm baseline.

---

## Current Status: Docs Only

Three planning artifacts are in place. No code changes yet. Waiting for user to say "proceed with Phase 1a".

- **`docs/ai_forest/ai-forest-overview.md`** — purpose, scope, architecture, species spec, per-phase acceptance criteria.
- **`docs/ai_forest/ai-forest-tasks.md`** — commit-level task checklist, 32 commits across 3 phases, TDD-structured.
- **`docs/ai_forest/ai-forest-continuation-prompt.md`** — this file.

---

## Ground Rules

- **TDD per commit**: every behavioral commit is preceded by a RED (failing test) commit. See `docs/ai_forest/ai-forest-tasks.md` for exact pairing.
- **Baseline preservation**: full AI unit suite must stay green at the end of every commit. Never skip a regression run.
- **No auto-implementation**: only proceed from the phase/task explicitly approved by the user. Stop at phase boundaries for explicit go-ahead.
- **Doc updates are separate commits**: after any phase/commit that alters task state, update this file + tasks doc (and AGENTS.md / DEV_PITFALLS.md when warranted), committed separately from implementation.
- **Style enforcement**: run `tests/unit/style/test_style_enforcement.gd` after every new file or scene addition.
- **Scope isolation in tests**: every new test extends `tests/base_test.gd` for automatic `U_ServiceLocator` scope push/pop.

---

## Critical File Index

### Existing (reuse)

| Path | Why you care |
|---|---|
| `scripts/ecs/systems/s_ai_behavior_system.gd` | Orchestrator — no changes planned; already delegates to selector/runner/replanner/context |
| `scripts/ecs/components/c_ai_brain_component.gd` | `get_debug_snapshot()` drives Label3D + HUD |
| `scripts/resources/ai/goals/rs_ai_goal.gd` | `goal_id`, `conditions`, `root_task`, `priority`, `score_threshold`, `cooldown`, `one_shot`, `requires_rising_edge` |
| `scripts/resources/ai/tasks/rs_ai_primitive_task.gd`, `rs_ai_compound_task.gd` | Task types authored in `.tres` files |
| `scripts/resources/ai/actions/rs_ai_action_move_to.gd` | Supports `target_position` / `waypoint_index` / `target_node_path` resolution — reuse where detection isn't needed |
| `scripts/resources/qb/conditions/rs_condition_component_field.gd` | Reads any component field via `field_path` — drives threat/prey/hunger conditions. No new condition types needed in Phase 1-2. |
| `scripts/utils/ai/u_ai_task_state_keys.gd` | Canonical task_state keys. Use these, never raw strings. |
| `scripts/ecs/components/c_entity_tag_component.gd` | Existing tag component — source of truth for species tagging |
| `scripts/ecs/components/c_detection_component.gd` | **Phase 1a modifies** — add `target_tag` export |
| `scripts/ecs/systems/s_ai_detection_system.gd` | **Phase 1a modifies** — tag-based query |
| `scenes/templates/tmpl_character.tscn` | Base template for `prefab_forest_agent.tscn` |
| `scenes/prefabs/prefab_demo_npc.tscn` | Reference pattern for component wiring |
| `tests/base_test.gd` | Inherit for scope isolation |
| `tools/run_gut_suite.sh` | Test runner |

### To be created (Phase 1)

- `scripts/resources/ai/actions/rs_ai_action_move_to_detected.gd`
- `scripts/resources/ai/actions/rs_ai_action_flee_from_detected.gd`
- `scripts/resources/ai/actions/rs_ai_action_wander.gd`
- `scripts/ui/hud/ui_ai_brain_debug_overlay.gd`
- `scripts/ui/hud/ui_forest_agent_label.gd`
- `scenes/ui/hud/ui_ai_brain_debug_overlay.tscn`
- `scenes/ui/hud/ui_forest_agent_label.tscn`
- `scenes/prefabs/prefab_forest_agent.tscn`
- `scenes/prefabs/prefab_forest_wolf.tscn`, `prefab_forest_rabbit.tscn`, `prefab_forest_deer.tscn`, `prefab_forest_tree.tscn`
- `scenes/gameplay/gameplay_ai_forest.tscn`
- Goal / brain `.tres` files under `resources/ai/forest/{shared,wolf,rabbit,deer}/`
- Tests: `test_s_ai_detection_system_tag_target.gd`, `test_ai_actions_forest.gd`, `test_ui_ai_brain_debug_overlay.gd`, `test_forest_ecosystem_smoke.gd`

### To be created (Phase 2)

- `scripts/resources/ecs/rs_needs_settings.gd`
- `scripts/ecs/components/c_needs_component.gd`
- `scripts/ecs/systems/s_needs_system.gd`
- `scripts/resources/ai/actions/rs_ai_action_feed.gd`
- Needs settings `.tres` per species
- Tests: `test_c_needs_component.gd`, `test_s_needs_system.gd`, `test_hunger_drives_goal_score.gd`

### To be created (Phase 3)

- `cfg_goal_hunt_pack.tres`
- Tests: `test_pack_converges.gd`
- Multi-detection-component support in `S_AIDetectionSystem` + `C_DetectionComponent.detection_role`

---

## How to Resume

When the user says "proceed" or "start Phase 1":

1. Re-read `docs/ai_forest/ai-forest-overview.md` and `ai-forest-tasks.md`.
2. Run baseline: `tools/run_gut_suite.sh -gdir=res://tests/unit/ai -ginclude_subdirs -gexit` — confirm 124/124.
3. Execute the next unchecked commit in `ai-forest-tasks.md`.
4. After the commit: run the relevant suite, confirm green, mark the task `[x]` in `ai-forest-tasks.md`, update **Status** + **Next task** fields in this prompt, commit the docs update separately.
5. At phase boundaries: stop and wait for user go-ahead before the next phase. Do not auto-advance.

---

## Notes & Caveats

- **No Label3D or billboard patterns exist in the project today.** Phase 1e introduces the first. Expect to discover fixed-size / depth-test interactions the hard way — budget investigative time.
- **`C_DetectionComponent` generalization must preserve player-detection back-compat.** Existing NPC showcase tests rely on `is_player_in_range` / `last_detected_player_entity_id` — keep those as aliases of the new fields when `target_tag == &"player"`.
- **Brain-driven entities require the full runtime movement stack** per AGENTS.md M10 contract: `CharacterBody3D` + `C_InputComponent` + `C_MovementComponent` with valid movement settings. The new `prefab_forest_agent.tscn` must satisfy this.
- **Typed-contract pattern (R1 refactor)** is mandatory: all new `.tres` files use typed fields (`RS_AIGoal.root_task: RS_AITask`, `RS_AIPrimitiveTask.action: I_AIAction`, etc.). Do not duck-type.
- **Channel taxonomy (F5)**: any event a new system emits goes via `U_ECSEventBus` if published by an ECS system; managers go via Redux dispatch. Signals only for intra-manager / manager-UI wiring.
- **GDScript 4.6 pitfalls** (from auto-memory): don't name a method `tr`; inner classes start with capital letters; use `str()` not `String()` for Variant→String.
- **Mobile compatibility**: this scene is desktop-only per scope, but don't introduce runtime `DirAccess.open()` on any preset-like resource — use `const` preload arrays if needed.

---

## Completion Summary (updated after each phase)

### Phase 0 — Documentation
- **Status**: Complete (2026-04-16)
- **Commits**: docs/ai_forest/ai-forest-{overview,tasks,continuation-prompt}.md created
- **Outcome**: Plan approved. Awaiting go-ahead to start Phase 1a.

### Phase 1 — Scene shell + species behaviors + detection generalization
- **Status**: Not started
- **Commits**: 0 / 15
- **Outcome**: —

### Phase 2 — Hunger / satiety
- **Status**: Not started
- **Commits**: 0 / 9
- **Outcome**: —

### Phase 3 — Pack behavior + polish
- **Status**: Not started
- **Commits**: 0 / 8
- **Outcome**: —
