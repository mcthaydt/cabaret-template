# AI System Implementation Guide & Continuation Prompt

## Overview

This guide directs you to implement the AI System (GOAP / HTN) by following the tasks outlined in the documentation in sequential order.

**Branch**: `GOAP-AI`
**Status**: Milestone 5 complete (implementation phase)

---

## Current Status: Milestone 5 Complete

- Overview: `docs/ai_system/ai-system-overview.md` — system architecture, goals, non-goals, resource definitions, demo integration.
- Plan: `docs/ai_system/ai-system-plan.md` — 10 milestones, work breakdown, dependency graph, risks.
- Tasks: `docs/ai_system/ai-system-tasks.md` — checklist (5/10 milestones complete).

### Completed in M1 (2026-04-02)

- Added `tests/unit/ai/resources/test_rs_ai_task.gd` with red-green resource/interface tests (now 6 total including post-M2 audit hardening for `method_conditions`).
- Implemented:
  - `scripts/interfaces/i_ai_action.gd`
  - `scripts/resources/ai/rs_ai_task.gd`
  - `scripts/resources/ai/rs_ai_primitive_task.gd`
  - `scripts/resources/ai/rs_ai_compound_task.gd`
- Verification:
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/resources/test_rs_ai_task.gd` → `6/6` passing
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` → `17/17` passing
  - `tools/run_gut_suite.sh` run currently completes with `3627/3636` passing, `9` pending/risky (headless/platform skips), and `0` failing tests

### Completed in M2 (2026-04-02)

- Added `tests/unit/ai/resources/test_rs_ai_goal.gd` with the 5 required red-green tests.
- Implemented:
  - `scripts/resources/ai/rs_ai_goal.gd`
  - `scripts/resources/ai/rs_ai_brain_settings.gd`
- Verification:
  - RED confirmed: `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/resources/test_rs_ai_goal.gd` failed with expected missing-script assertions.
  - GREEN confirmed: `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/resources/test_rs_ai_goal.gd` → `5/5` passing.
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` → `17/17` passing.
  - `tools/run_gut_suite.sh` run currently completes with `3627/3636` passing, `9` pending/risky (headless/platform skips), and `0` failing tests.

### Completed in M3 (2026-04-02)

- Added `tests/unit/ecs/components/test_c_ai_brain_component.gd` with the 5 required red-green component tests.
- Implemented:
  - `scripts/ecs/components/c_ai_brain_component.gd`
- Verification:
  - RED confirmed: `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/components/test_c_ai_brain_component.gd` failed with expected missing-script assertions.
  - GREEN confirmed: `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/components/test_c_ai_brain_component.gd` → `5/5` passing.
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` → `17/17` passing.
  - `tools/run_gut_suite.sh` run currently completes with `3633/3642` passing, `9` pending/risky (headless/platform/mobile skips), and `0` failing tests.

### Completed in M4 (2026-04-02)

- Added `tests/unit/ai/test_u_htn_planner.gd` with the 8 required red-green decomposition tests.
- Implemented:
  - `scripts/utils/ai/u_htn_planner.gd`
- Verification:
  - RED confirmed: `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/test_u_htn_planner.gd` failed with expected missing-script assertions for `u_htn_planner.gd`.
  - GREEN confirmed: `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/test_u_htn_planner.gd` → `8/8` passing.
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` → `17/17` passing.
  - `tools/run_gut_suite.sh` run currently completes with `3641/3650` passing, `9` pending/risky (headless/platform/mobile skips), and `0` failing tests.

### Completed in M5 (2026-04-02)

- Added `tests/unit/ecs/systems/test_s_ai_behavior_system_goals.gd` with the 7 required red-green goal-loop tests.
- Implemented:
  - `scripts/ecs/systems/s_ai_behavior_system.gd`
- Verification:
  - RED confirmed: `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/test_s_ai_behavior_system_goals.gd` failed with expected missing-script assertions for `s_ai_behavior_system.gd`.
  - GREEN confirmed: `tools/run_gut_suite.sh -gtest=res://tests/unit/ecs/systems/test_s_ai_behavior_system_goals.gd` → `7/7` passing.
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` → `17/17` passing.
  - `tools/run_gut_suite.sh` run currently completes with `3651/3660` passing, `9` pending/risky (headless/platform/mobile skips), and `0` failing tests.

### Key Design Decisions

- **GOAP + HTN**: QB v2 scores goals (GOAP layer), winning goal's root task is decomposed by HTN planner into primitive actions.
- **Typed action resources (I_AIAction)**: Planned M6/M7 implementation uses typed resources implementing `I_AIAction` with `start()`, `tick()`, `is_complete()` — matching QB v2 `I_Condition`/`I_Effect` polymorphic dispatch. No match blocks in the system. New action types = new `.gd` file, no system modification.
- **Designer-friendly @exports**: Planned action resources use typed `@export` fields (for example RS_AIActionMoveTo `target_position: Vector3`, `arrival_threshold: float`) instead of opaque `Dictionary parameters`.
- **No blackboard**: QB conditions already read component fields, Redux state, and event payloads via U_PathResolver.
- **No behavior trees**: QB scorer is the decision layer; HTN replaces BT-style decomposition.
- **Animate is planned as a stub**: M7 RS_AIActionAnimate should set `task_state["animation_state"]` and complete immediately; full animation integration is deferred.
- **Demo scenes need creation**: Power Core, Comms Array, Nav Nexus rooms built with CSG geometry.

---

## Instructions — YOU MUST DO THIS - NON-NEGOTIABLE

### 1. Review Project Foundations

- `AGENTS.md` — Project conventions, ECS guidelines, QB v2 patterns.
- `docs/general/DEV_PITFALLS.md` — Common mistakes to avoid.
- `docs/general/STYLE_GUIDE.md` — Code style, naming prefixes, formatting requirements.

### 2. Review AI System Documentation

- `docs/ai_system/ai-system-overview.md` — Full system specification: architecture, resources, primitive task types, demo NPC archetypes.
- `docs/ai_system/ai-system-plan.md` — Implementation plan with 10 milestones and dependency graph.
- `docs/ai_system/ai-system-tasks.md` — Task list with commit-level checkboxes per milestone.

### 3. Understand Existing Architecture

Study these existing consumers of QB v2 — they define the pattern you must follow:

- `scripts/ecs/systems/s_character_state_system.gd` — QB v2 composition pattern (U_RuleScorer, U_RuleSelector, U_RuleStateTracker). Study `_build_entity_context()` for context dict construction.
- `scripts/ecs/systems/s_game_event_system.gd` — Event-driven QB evaluation pattern with per-entity context fan-out.
- `scripts/ecs/systems/s_camera_state_system.gd` — QB v2 with camera-specific context building.

Study these for ECS conventions:

- `scripts/ecs/base_ecs_system.gd` — Base system class, `process_tick(delta)` contract.
- `scripts/ecs/base_ecs_component.gd` — Base component class, `COMPONENT_TYPE`, `_validate_required_settings()`.
- `scripts/managers/m_ecs_manager.gd` — Component registration, queries, entity management.

Study these for the typed resource + interface pattern (I_AIAction follows this exactly):

- `scripts/interfaces/i_condition.gd` — Interface: `evaluate(context) -> float`. AI actions follow this pattern with `start/tick/is_complete`.
- `scripts/interfaces/i_effect.gd` — Interface: `execute(context) -> void`. Same polymorphic dispatch pattern.
- `scripts/resources/qb/conditions/rs_condition_component_field.gd` — Example typed condition with `@export_group` + `@export` fields for inspector UX.
- `scripts/resources/qb/effects/rs_effect_set_field.gd` — Example typed effect with multiple `@export` value types.

Study these for movement/input foundations used by the planned M7 AI navigation bridge:

- `scripts/ecs/systems/s_input_system.gd` — Current player input writer; M7 will add `C_PlayerTagComponent` filtering so player input only writes to player-tagged entities.
- `scripts/ecs/systems/s_movement_system.gd` — Camera-relative movement pipeline. M7 AI navigation should inverse this transform and write to `C_InputComponent.move_vector` so NPCs flow through the same path.
- `scripts/utils/ecs/u_ecs_utils.gd` — Active camera lookup helpers used by movement-oriented ECS systems.

Study these for utility and event patterns:

- `scripts/utils/qb/u_rule_scorer.gd` — Rule scoring API.
- `scripts/utils/qb/u_rule_selector.gd` — Winner selection API.
- `scripts/utils/qb/u_rule_state_tracker.gd` — Cooldowns, salience, one-shot gating.
- `scripts/utils/qb/u_path_resolver.gd` — Dot-path traversal for condition evaluation.
- `scripts/events/ecs/u_ecs_event_bus.gd` — Event publishing for RS_AIActionPublishEvent.

### 4. Execute AI System Tasks in Order

Work through the tasks in `ai-system-tasks.md` sequentially:

1. **M1** — Task Resource Skeleton + I_AIAction Interface (RS_AITask, RS_AIPrimitiveTask, RS_AICompoundTask, I_AIAction)
2. **M2** — Goal & Brain Settings Resources (RS_AIGoal, RS_AIBrainSettings)
3. **M3** — C_AIBrainComponent (ECS component)
4. **M4** — U_HTNPlanner (task decomposition utility)
5. **M5** — Goal Evaluation Loop (S_AIBehaviorSystem + QB v2)
6. **M6** — Typed Action Resources (Instant): RS_AIActionWait, RS_AIActionPublishEvent, RS_AIActionSetField + polymorphic task runner
7. **M7** — Typed Action Resources (Movement + Stub): RS_AIActionMoveTo, RS_AIActionScan, RS_AIActionAnimate
8. **M8** — Integration Tests (full pipeline validation)
9. **M9** — Demo Scene Creation (3 gameplay rooms)
10. **M10** — Demo NPC Behavior Authoring & Tuning

### 5. Follow TDD Discipline

For each milestone:

1. Write the test first (unit or integration).
2. Run the test and verify it fails for the expected reason.
3. Implement the minimal code to make it pass.
4. Run the full test suite and verify no regressions.
5. Run `tests/unit/style/test_style_enforcement.gd` after any file creation or rename.
6. Commit with a clear, focused message.

### 6. Preserve Compatibility

You MUST:

- Keep all existing ECS systems, QB v2 consumers, and state management flows working.
- Follow existing composition patterns — compose QB v2 utilities, do not inherit from a QB base class.
- Use `U_ECSEventBus` for `publish_event` tasks, not direct signal connections.
- Use `U_PathResolver` for `set_field` tasks, matching existing condition/effect resolution.
- Register C_AIBrainComponent with M_ECSManager following the standard component lifecycle.

---

## Critical Notes

- **No Autoloads**: AI system follows existing ECS patterns. S_AIBehaviorSystem lives in gameplay scene system groups. C_AIBrainComponent attaches to NPC entities.
- **C_AIBrainComponent settings are required**: `brain_settings` must be a valid `RS_AIBrainSettings` resource. Placeholder/demo NPC scene entities cannot leave this field null.
- **Compose, Don't Inherit**: S_AIBehaviorSystem composes U_RuleScorer, U_RuleSelector, U_RuleStateTracker, and U_HTNPlanner. It does NOT inherit from a QB base class.
- **Typed Actions via I_AIAction (M6/M7 planned)**: Each action resource (RS_AIAction*) should implement I_AIAction with `start(context, task_state)`, `tick(context, task_state, delta)`, `is_complete(context, task_state)`. The task runner should dispatch polymorphically — no match blocks/action-type switching.
- **RS_AIPrimitiveTask is a Wrapper**: RS_AIPrimitiveTask holds `@export var action: Resource` (I_AIAction). The task is the "what" (position in the HTN plan), the action is the "how" (self-executing logic + typed @export config).
- **Animate Stub Scope (M7 planned)**: RS_AIActionAnimate should set `task_state["animation_state"]` to a StringName and complete immediately. Full animation system integration is a separate effort.
- **Planned for M7: move_to Delegates Movement via S_AINavigationSystem**: RS_AIActionMoveTo should write `task_state["ai_move_target"]` (Vector3), and planned `S_AINavigationSystem` (`execution_priority = -5`) should read that target, calculate XZ world direction, inverse-transform through active camera basis, and write camera-relative `Vector2` to `C_InputComponent.set_move_vector()`. M7 also needs `S_InputSystem` filtered by `C_PlayerTagComponent` so player input does not clobber AI move vectors.
- **Demo Scenes are CSG Prototypes**: Use CSG geometry for all level geometry. Functional prototypes, not polished levels.
- **Style & Organization**: Follow `docs/general/STYLE_GUIDE.md` and node naming prefixes (S_, C_, RS_, U_, I_, E_, etc.).
- **Update Docs After Each Milestone**: Per AGENTS.md mandate, update this continuation prompt and the tasks checklist after completing each milestone.

---

## Next Steps

Begin with **Milestone 6: Typed Action Resources (Instant) + Task Runner**:

1. Create `tests/unit/ai/actions/test_ai_actions_instant.gd` with the 5 action tests listed under M6 in `docs/ai_system/ai-system-tasks.md` (RED first).
2. Implement the instant action resources in `scripts/resources/ai/actions/`:
   - `rs_ai_action_wait.gd`
   - `rs_ai_action_publish_event.gd`
   - `rs_ai_action_set_field.gd`
3. Add task-runner tests (M6 Commit 3) and implement `_execute_current_task(brain, delta, context)` in `scripts/ecs/systems/s_ai_behavior_system.gd` using polymorphic `I_AIAction` dispatch (no match blocks).
4. Run targeted M6 tests, then `tests/unit/style/test_style_enforcement.gd`.
5. Run full-suite regression check, update `ai-system-tasks.md` + this continuation prompt, then commit documentation updates separately from implementation.
