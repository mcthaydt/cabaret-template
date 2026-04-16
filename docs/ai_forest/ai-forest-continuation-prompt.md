# AI Forest Simulation — Continuation Prompt

## Overview

This prompt directs you to implement the AI Forest Simulation by executing `docs/ai_forest/ai-forest-tasks.md` in sequential order, respecting the phase dependency chain. The full specification lives in `docs/ai_forest/ai-forest-overview.md`.

**Branch**: GOAP-AI
**Status**: Phase 1b in progress (Commits 4-7 complete on 2026-04-16).
**Next task**: Phase 1b Commit 8 — author `scenes/prefabs/prefab_forest_tree.tscn`.
**Prerequisite**: Baseline AI suite re-measured and green immediately before Phase 1a (`124/124` passing on 2026-04-16).

---

## Current Status: Phase 1b In Progress

Implementation progress:
- Commit 1 RED: added `tests/unit/ecs/systems/test_s_ai_detection_system_tag_target.gd` and confirmed expected failures before implementation.
- Commit 2 GREEN: added `C_DetectionComponent.target_tag` and rewired `S_AIDetectionSystem` to resolve entity roots + filter by tag with player-tag fallback for back-compat.
- Commit 3 REGRESSION: validated existing detection and AI integration suites remain green.
- Commit 4: created `scenes/prefabs/prefab_forest_agent.tscn` + `resources/base_settings/ai_forest/cfg_movement_forest.tres` with required AI components and tuned movement defaults.
- Commit 5: created `scenes/prefabs/prefab_forest_wolf.tscn` with predator tags, prey-target detection tuning, and dark-gray `Body_Mesh` visuals.
- Commit 6: created `scenes/prefabs/prefab_forest_rabbit.tscn` with prey tags, predator-target detection tuning, and smaller white `Body_Mesh` visuals.
- Commit 7: created `scenes/prefabs/prefab_forest_deer.tscn` with herbivore tags, predator-target detection tuning, and brown `Body_Mesh` visuals.

Planning artifacts remain authoritative:
- **`docs/ai_forest/ai-forest-overview.md`** — purpose, scope, architecture, species spec, per-phase acceptance criteria.
- **`docs/ai_forest/ai-forest-tasks.md`** — commit-level task checklist, 37 commits across 3 phases, TDD-structured.
- **`docs/ai_forest/ai-forest-continuation-prompt.md`** — this file.

---

## Audit-Corrected Design Decisions (LOCKED)

These decisions diverge from what an intuitive reading of the AI system might suggest. If you revise the plan, preserve them unless the user explicitly overrides.

1. **Tag-based detection uses `BaseECSEntity.tags`, not a separate component.** There is no `C_EntityTagComponent` — entity tags live on the entity-root `Node3D` that extends `BaseECSEntity` (see `scripts/ecs/base_ecs_entity.gd`). `S_AIDetectionSystem` must resolve candidate entity roots via `U_ECSUtils.find_entity_root()` and filter by `entity.has_tag(target_tag)`. Do not author a new tag component.

2. **`RS_AIGoal` has no `decision_group` field.** `U_AIGoalSelector` hardcodes `GOAL_DECISION_GROUP := StringName("ai_goal")` for every goal rule it compiles (`scripts/utils/ai/u_ai_goal_selector.gd:8,112`). All goals in a brain compete in that single group. Thrash prevention is per-goal via `priority`, `cooldown`, `requires_rising_edge`, `one_shot`. **Do not invent a decision_group authoring field.**

3. **Forest-agent prefab inherits `tmpl_character.tscn` directly.** Peer to `prefab_demo_npc.tscn`, not derived from it. Components added on top: `C_InputComponent`, `C_AIBrainComponent`, `C_DetectionComponent`, `C_MoveTargetComponent`. Omit `C_SpawnRecoveryComponent` and anything gamepad/player-specific.

4. **Debug panel lives at `scripts/debug/` + `scenes/debug/`, not `scripts/ui/hud/`.** Filename prefix `debug_` to signal role and avoid ambiguity with the M_SceneManager-owned HUD. `test_gameplay_scenes_do_not_embed_hud_instances` targets the canonical HUD overlay specifically — a debug panel is allowed.

5. **Wander home captured at `_ready()`.** `RS_AIActionWander.start()` stores `entity.global_position` into `task_state["ai_wander_home"]` the first time it runs. Add a `WANDER_HOME := &"ai_wander_home"` constant to `U_AITaskStateKeys` — never use the bare string (blocked by `test_ai_action_scripts_use_task_state_key_constants`).

6. **Scene must be registered.** Create `resources/scene_registry/cfg_ai_forest_entry.tres` (`scene_id = &"ai_forest"`, `scene_type = 1`, `default_transition = "loading"`, `preload_priority = 0`). Mirrors `cfg_ai_showcase_entry.tres`.

7. **No player entity in the scene.** Pure observer. No `S_InputSystem`, no `C_PlayerTagComponent`, no vcam.

8. **Scene-structure marker scripts are mandatory on container nodes.** Attach `marker_managers_group.gd`, `marker_systems_group.gd`, `marker_systems_core_group.gd` / `_physics_group.gd` / `_movement_group.gd`, `marker_environment_group.gd`, `marker_entities_group.gd`, `marker_lighting_group.gd` to their respective container nodes in the scene tree.

---

## Ground Rules

- **TDD per commit**: every behavioral commit is preceded by a RED (failing test) commit. See `docs/ai_forest/ai-forest-tasks.md` for exact pairing.
- **Baseline preservation**: the AI unit suite must stay green at the end of every commit. Never skip a regression run.
- **No auto-implementation**: only proceed from the phase/task explicitly approved by the user. Stop at phase boundaries for explicit go-ahead.
- **Doc updates are separate commits**: after any phase/commit that alters task state, update this file + tasks doc (and AGENTS.md / DEV_PITFALLS.md when warranted), committed separately from implementation.
- **Style enforcement**: run `tests/unit/style/test_style_enforcement.gd` after every new file or scene addition. Critical rules: AI task-state key constants, AI resource subdirectory layout, gameplay-scene HUD embedding.
- **Scope isolation in tests**: every new test extends `tests/base_test.gd` for automatic `U_ServiceLocator` scope push/pop.

---

## Critical File Index

### Existing (reuse)

| Path | Why you care |
|---|---|
| `scripts/ecs/systems/s_ai_behavior_system.gd` | Orchestrator — no changes planned; already delegates to selector/runner/replanner/context |
| `scripts/ecs/components/c_ai_brain_component.gd` | `get_debug_snapshot()` drives Label3D + debug panel |
| `scripts/ecs/base_ecs_entity.gd` | **`BaseECSEntity`** — authoritative source of entity tags + entity_id. Exported `tags: Array[StringName]` on every entity root |
| `scripts/utils/ai/u_ai_goal_selector.gd` | Hardcodes `&"ai_goal"` decision group globally. Confirms goals have no designer-facing decision_group |
| `scripts/utils/ecs/u_ecs_utils.gd` | `find_entity_root()`, `get_entity_id()`, `get_entity_tags()` — use these in the detection-system rewrite |
| `scripts/resources/ai/goals/rs_ai_goal.gd` | Exports: `goal_id`, `conditions`, `root_task`, `priority`, `score_threshold`, `cooldown`, `one_shot`, `requires_rising_edge`. No `decision_group` |
| `scripts/resources/ai/tasks/rs_ai_primitive_task.gd`, `rs_ai_compound_task.gd` | Task types authored in `.tres` files |
| `scripts/resources/ai/actions/rs_ai_action_move_to.gd` | Template for new detected/flee actions — see how it writes both `C_MoveTargetComponent` AND `task_state` |
| `scripts/resources/qb/conditions/rs_condition_component_field.gd` | Reads any component field via `field_path` — drives detection and hunger conditions |
| `scripts/utils/ai/u_ai_task_state_keys.gd` | **Extend** with a `WANDER_HOME` constant in Phase 1c. Use these, never raw strings |
| `scripts/ecs/components/c_detection_component.gd` | **Phase 1a modifies** — add `target_tag` export |
| `scripts/ecs/systems/s_ai_detection_system.gd` | **Phase 1a modifies** — filter candidates by entity-root tag |
| `scripts/ecs/components/c_move_target_component.gd` | Primary move-target channel; include on forest-agent prefab |
| `scripts/interfaces/i_ai_action.gd` | New action virtuals MUST override start/tick/is_complete — the base pushes errors otherwise |
| `scenes/templates/tmpl_character.tscn` | Base template for `prefab_forest_agent.tscn` |
| `scenes/prefabs/prefab_demo_npc.tscn` | Reference pattern for component wiring (do NOT inherit from it) |
| `resources/ai/patrol_drone/cfg_goal_patrol.tres` | Reference `.tres` authoring pattern for goal + compound task + primitive task |
| `resources/scene_registry/cfg_ai_showcase_entry.tres` | Template for the new `cfg_ai_forest_entry.tres` |
| `scripts/scene_structure/marker_*_group.gd` | Scene-container marker scripts — attach to the forest scene's container nodes |
| `tests/base_test.gd` | Inherit for scope isolation |
| `tools/run_gut_suite.sh` | Test runner |
| `tests/unit/style/test_style_enforcement.gd` | AI string-literal + resource-layout + HUD-embedding rules |

### To be created (Phase 1)

- `scripts/resources/ai/actions/rs_ai_action_move_to_detected.gd`
- `scripts/resources/ai/actions/rs_ai_action_flee_from_detected.gd`
- `scripts/resources/ai/actions/rs_ai_action_wander.gd`
- `scripts/debug/debug_ai_brain_panel.gd`
- `scripts/debug/debug_forest_agent_label.gd`
- `scenes/debug/debug_ai_brain_panel.tscn`
- `scenes/debug/debug_forest_agent_label.tscn`
- `scenes/prefabs/prefab_forest_agent.tscn`
- `scenes/prefabs/prefab_forest_wolf.tscn`, `prefab_forest_rabbit.tscn`, `prefab_forest_deer.tscn`, `prefab_forest_tree.tscn`
- `scenes/gameplay/gameplay_ai_forest.tscn`
- `resources/scene_registry/cfg_ai_forest_entry.tres`
- `resources/base_settings/ai_forest/cfg_movement_forest.tres`
- Goal / brain `.tres` files under `resources/ai/forest/{shared,wolf,rabbit,deer}/`
- New constant in `scripts/utils/ai/u_ai_task_state_keys.gd`: `WANDER_HOME`
- Tests: `test_s_ai_detection_system_tag_target.gd`, `test_ai_actions_forest.gd`, `test_debug_ai_brain_panel.gd`, `test_forest_ecosystem_smoke.gd`

### To be created (Phase 2)

- `scripts/resources/ecs/rs_needs_settings.gd`
- `scripts/ecs/components/c_needs_component.gd`
- `scripts/ecs/systems/s_needs_system.gd`
- `scripts/resources/ai/actions/rs_ai_action_feed.gd`
- Needs settings `.tres` per species: `resources/base_settings/ai_forest/cfg_needs_{wolf,rabbit,deer}.tres`
- Tests: `test_c_needs_component.gd`, `test_s_needs_system.gd`, `test_hunger_drives_goal_score.gd`

### To be created (Phase 3)

- New `C_DetectionComponent` export: `detection_role: StringName`
- Multi-component iteration in `S_AIDetectionSystem`
- `cfg_goal_hunt_pack.tres`
- Additional `C_DetectionComponent` child on `prefab_forest_wolf.tscn`
- Tests: `test_s_ai_detection_system_multi_component.gd`, `test_pack_converges.gd`

---

## How to Resume

When the user says "proceed" or "start Phase 1":

1. Re-read `docs/ai_forest/ai-forest-overview.md` and `ai-forest-tasks.md` — including the "Audit-Corrected Design Decisions" block above.
2. Run baseline: `tools/run_gut_suite.sh -gdir=res://tests/unit/ai -ginclude_subdirs -gexit` — confirm 124/124 (or the latest known baseline).
3. Execute the next unchecked commit in `ai-forest-tasks.md`.
4. After the commit: run the relevant suite, confirm green, mark the task `[x]` in `ai-forest-tasks.md`, update **Status** + **Next task** fields in this prompt, commit the docs update separately.
5. At phase boundaries: stop and wait for user go-ahead before the next phase. Do not auto-advance.

---

## Notes & Caveats

- **No Label3D or billboard patterns exist in the project today.** Phase 1e introduces the first. Expect to investigate `fixed_size` / `no_depth_test` interactions — budget time for manual visual tuning.
- **Detection back-compat matters.** `C_DetectionComponent.is_player_in_range` and `last_detected_player_entity_id` keep their names when `target_tag != &"player"` but semantically mean "target in range" / "last detected target id". Existing NPC showcase depends on these names; do not rename them. Consider adding `is_target_in_range` and `last_detected_entity_id` as simple aliases if the semantic mismatch becomes a pain point.
- **Brain-driven entities require the full runtime movement stack** per AGENTS.md M10: `CharacterBody3D` + `C_InputComponent` + `C_MovementComponent` with valid movement settings. The new `prefab_forest_agent.tscn` must satisfy this.
- **Typed-contract pattern (R1 refactor)** is mandatory: all new `.tres` files use typed fields (`RS_AIGoal.root_task: RS_AITask`, `RS_AIPrimitiveTask.action: I_AIAction`, etc.). Do not duck-type.
- **Channel taxonomy (F5)**: any event a new system emits goes via `U_ECSEventBus` if published by an ECS system; managers go via Redux dispatch. Signals only for intra-manager / manager-UI wiring.
- **GDScript 4.6 pitfalls** (auto-memory): don't name a method `tr`; inner classes start with capital letters; use `str()` not `String()` for Variant→String.
- **Mobile compatibility**: desktop-only scope, but don't introduce runtime `DirAccess.open()` on any preset-like resource — use `const` preload arrays if needed.
- **Style enforcement landmines to watch**:
  - `test_ai_move_target_magic_strings_not_used_in_ai_scripts` — raw `"ai_move_target"` strings in `scripts/resources/ai/**` or `scripts/ecs/systems/s_ai_*.gd` fail the build
  - `test_ai_action_scripts_use_task_state_key_constants` — `task_state["..."]` bracket literals in action files fail the build
  - `test_ai_resource_scripts_are_grouped_by_subdirectory` — new `.gd` AI resources must live under `scripts/resources/ai/{brain,goals,tasks,actions}`

---

## Completion Summary (updated after each phase)

### Phase 0 — Documentation
- **Status**: Complete (2026-04-16, revised v2 same day after audit)
- **Commits**: docs/ai_forest/ai-forest-{overview,tasks,continuation-prompt}.md created and revised
- **Outcome**: Plan approved. Awaiting go-ahead to start Phase 1a.

### Phase 1 — Scene shell + species behaviors + detection generalization
- **Status**: In progress (P1a + P1b Commits 4-7 complete on 2026-04-16)
- **Commits**: 7 / 19
- **Outcome**: Detection system supports tag-targeted lookup, base forest-agent prefab is authored, and wolf/rabbit/deer species prefab wiring is in place.

### Phase 2 — Hunger / satiety
- **Status**: Not started
- **Commits**: 0 / 9
- **Outcome**: —

### Phase 3 — Pack behavior + polish
- **Status**: Not started
- **Commits**: 0 / 9
- **Outcome**: —
