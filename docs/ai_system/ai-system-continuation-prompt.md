# AI System Implementation Guide & Continuation Prompt

## Overview

This guide directs you to implement the AI System (GOAP / HTN) by following the tasks outlined in the documentation in sequential order.

**Branch**: `GOAP-AI`
**Status**: Milestone 1 complete (implementation phase)

---

## Current Status: Milestone 1 Complete

- Overview: `docs/ai_system/ai-system-overview.md` — system architecture, goals, non-goals, resource definitions, demo integration.
- Plan: `docs/ai_system/ai-system-plan.md` — 10 milestones, work breakdown, dependency graph, risks.
- Tasks: `docs/ai_system/ai-system-tasks.md` — checklist (1/10 milestones complete).

### Completed in M1 (2026-04-02)

- Added `tests/unit/ai/resources/test_rs_ai_task.gd` with the 5 required red-green tests.
- Implemented:
  - `scripts/interfaces/i_ai_action.gd`
  - `scripts/resources/ai/rs_ai_task.gd`
  - `scripts/resources/ai/rs_ai_primitive_task.gd`
  - `scripts/resources/ai/rs_ai_compound_task.gd`
- Verification:
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/resources/test_rs_ai_task.gd` → `5/5` passing
  - `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd` → `17/17` passing
  - `tools/run_gut_suite.sh` run completed with pre-existing failures in save/state persistence integration tests (outside M1 scope)

### Key Design Decisions

- **GOAP + HTN**: QB v2 scores goals (GOAP layer), winning goal's root task is decomposed by HTN planner into primitive actions.
- **Typed action resources (I_AIAction)**: Each primitive action is a typed resource implementing `I_AIAction` with `start()`, `tick()`, `is_complete()` — matching the QB v2 `I_Condition`/`I_Effect` polymorphic dispatch pattern. No match blocks in the system. New action types = new .gd file, no system modification.
- **Designer-friendly @exports**: Each action resource has typed `@export` fields (e.g., RS_AIActionMoveTo has `target_position: Vector3`, `arrival_threshold: float`) instead of opaque `Dictionary parameters`. Inspector shows exactly what to configure.
- **No blackboard**: QB conditions already read component fields, Redux state, and event payloads via U_PathResolver.
- **No behavior trees**: QB scorer is the decision layer; HTN replaces BT-style decomposition.
- **Animate is stubbed**: RS_AIActionAnimate sets `task_state["animation_state"]` and completes immediately. Full animation system integration deferred.
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

Study these for the AI navigation bridge pattern:

- `scripts/ecs/systems/s_ai_navigation_system.gd` — Bridges `task_state["ai_move_target"]` → `C_InputComponent.move_vector` via inverse camera transform. Execution priority -5 (after S_AIBehaviorSystem at -10, before S_InputSystem/S_MovementSystem at 0).
- `scripts/ecs/systems/s_input_system.gd` — Filtered by `C_PlayerTagComponent` so player input only writes to player-tagged entities. NPCs (no `C_PlayerTagComponent`) keep their AI-calculated move_vector.
- `scripts/ecs/systems/s_movement_system.gd` — Camera-relative movement pipeline. Both player and NPC input flows through the same code path. Study lines 118-143 for the camera-relative transform that S_AINavigationSystem must inverse.

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
- **Compose, Don't Inherit**: S_AIBehaviorSystem composes U_RuleScorer, U_RuleSelector, U_RuleStateTracker, and U_HTNPlanner. It does NOT inherit from a QB base class.
- **Typed Actions via I_AIAction**: Each action resource (RS_AIAction*) implements I_AIAction with `start(context, task_state)`, `tick(context, task_state, delta)`, `is_complete(context, task_state)`. The task runner dispatches polymorphically — NO match blocks or action_type string switching. New action types require only a new .gd file. This matches the I_Condition/I_Effect pattern used by QB v2.
- **RS_AIPrimitiveTask is a Wrapper**: RS_AIPrimitiveTask holds `@export var action: Resource` (I_AIAction). The task is the "what" (position in the HTN plan), the action is the "how" (self-executing logic + typed @export config).
- **Animate is a Stub**: RS_AIActionAnimate sets `task_state["animation_state"]` to a StringName and completes immediately. Full animation system integration is a separate effort.
- **move_to Delegates Movement via S_AINavigationSystem**: RS_AIActionMoveTo writes `task_state["ai_move_target"]` (Vector3) and checks distance for completion. `S_AINavigationSystem` (execution_priority -5) reads the target, calculates XZ-plane world direction, inverse-transforms through the active camera basis, and writes a camera-relative `Vector2` to `C_InputComponent.set_move_vector()`. This means NPCs flow through the exact same `S_MovementSystem` camera-relative pipeline as the player. `S_InputSystem` is filtered by `C_PlayerTagComponent` so player input doesn't clobber AI move_vector. NPC entities must have `C_AIBrainComponent` + `C_InputComponent` + `C_MovementComponent` but NOT `C_PlayerTagComponent`.
- **Demo Scenes are CSG Prototypes**: Use CSG geometry for all level geometry. Functional prototypes, not polished levels.
- **Style & Organization**: Follow `docs/general/STYLE_GUIDE.md` and node naming prefixes (S_, C_, RS_, U_, I_, E_, etc.).
- **Update Docs After Each Milestone**: Per AGENTS.md mandate, update this continuation prompt and the tasks checklist after completing each milestone.

---

## Next Steps

Begin with **Milestone 2: Goal & Brain Settings Resources**:

1. Create `tests/unit/ai/resources/test_rs_ai_goal.gd` with the 5 tests listed under M2 in `docs/ai_system/ai-system-tasks.md` (RED first).
2. Implement `scripts/resources/ai/rs_ai_goal.gd` and `scripts/resources/ai/rs_ai_brain_settings.gd` (GREEN).
3. Verify `RS_AIGoal.conditions` accepts existing QB condition resources (`RS_Condition*`).
4. Run style enforcement and targeted AI resource tests.
5. Run full-suite regression check and document any pre-existing unrelated failures separately.
6. Update `ai-system-tasks.md` + this continuation prompt immediately after M2 completion, then commit docs separately.
