# Interactions Refactor Tasks (TDD-First)

## Overview

This document defines a decision-complete, TDD-first roadmap to refactor interaction authoring to a more resource-driven architecture while preserving current runtime behavior.

This refactor covers all interaction controllers and keeps the existing hybrid runtime pattern:
- Controllers remain runtime orchestrators.
- Resources become the declarative source of interaction configuration.

**Status**: Not Started  
**Current Phase**: Phase 0  
**Task ID Range**: T001-T053  
**Primary Tasks File**: `docs/general/interactions_refactor/interactions-refactor-tasks.md`  
**Continuation Prompt File**: `docs/general/interactions_refactor/interactions-refactor-continuation-prompt.md` (required per phase)

---

## Scope

### In Scope

- Refactor interaction configuration for:
  - `scripts/gameplay/inter_door_trigger.gd`
  - `scripts/gameplay/inter_checkpoint_zone.gd`
  - `scripts/gameplay/inter_hazard_zone.gd`
  - `scripts/gameplay/inter_victory_zone.gd`
  - `scripts/gameplay/inter_signpost.gd`
  - `scripts/gameplay/inter_endgame_goal_zone.gd`
- Add typed interaction config resources and config instances.
- Add validator utilities and enforcement coverage.
- Migrate prefab/gameplay scene interaction values to resource-driven configuration.
- Preserve existing event payload shapes, ECS/state contracts, and user-visible behavior.

### Out of Scope

- ECS tag model changes.
- Spawn system architecture changes.
- Refactoring unrelated UI/settings systems.

---

## Goals / Non-Goals

### Goals

- Make interaction content easier and safer to author with AI and designers.
- Reduce duplicated literal values across scenes/controllers.
- Improve validation and fail-fast behavior for misconfigured interactions.
- Keep behavior stable during infrastructure phases.

### Non-Goals

- Runtime rewrite away from controller scripts.
- Behavior redesign for interaction flow.
- State schema redesign outside explicit interaction config additions.

---

## Constraints and Guardrails

- TDD is mandatory per phase: RED tests first, then GREEN implementation, then REFACTOR cleanup.
- During infrastructure phases (Phases 1-2), behavior parity is mandatory.
- Use naming conventions from `docs/general/STYLE_GUIDE.md`:
  - Resource scripts: `rs_*`
  - Resource instances: `cfg_*`
- Keep tabs in `.gd` files and preserve existing style checks.
- Any scene/resource structure changes must run style enforcement:
  - `tests/unit/style/test_style_enforcement.gd`
- When adding/moving scene/resource/class_name files, run a headless import pass to refresh caches when needed:
  - `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import`
- Keep docs commits separate from implementation commits.
- After each phase completion:
  - Update this tasks file status.
  - Update continuation prompt file.
  - Update `AGENTS.md` / `docs/general/DEV_PITFALLS.md` when new patterns/pitfalls are discovered.

---

## Architecture Decisions

### Runtime Model

- Keep current hybrid model:
  - `Inter_*` controllers own runtime behavior and component wiring.
  - `RS_*InteractionConfig` resources define declarative configuration values.

### Config Precedence and Backward Compatibility

- During migration (Phase 2-4):
  1. If typed config resource is assigned, controller reads config values first.
  2. Existing exported controller fields remain as fallback.
  3. If both are set and conflict, config resource wins.
- Final cleanup phase removes deprecated fallback exports only after all scene/prefab migrations are complete and green.

### New Resource Script Family

Add under `scripts/resources/interactions/`:
- `rs_interaction_config.gd` (base)
- `rs_door_interaction_config.gd`
- `rs_checkpoint_interaction_config.gd`
- `rs_hazard_interaction_config.gd`
- `rs_victory_interaction_config.gd`
- `rs_signpost_interaction_config.gd`
- `rs_endgame_goal_interaction_config.gd`

### Config Instances

Add under `resources/interactions/` using `cfg_` prefix.  
Example categories:
- `resources/interactions/doors/`
- `resources/interactions/checkpoints/`
- `resources/interactions/hazards/`
- `resources/interactions/victory/`
- `resources/interactions/signposts/`
- `resources/interactions/endgame/`

### Validator Utility

Add utility under `scripts/gameplay/helpers/`:
- `u_interaction_config_validator.gd`

Validator responsibilities:
- Type verification for assigned config resources.
- Required field checks by interaction type.
- Semantic checks (non-empty ids, legal enum combinations, non-negative cooldowns, valid target fields).
- Clear push_error/push_warning messages with controller path + field name.

---

## Assumptions and Defaults

- Runtime architecture remains hybrid: controllers orchestrate runtime flow; resources provide declarative configuration.
- Existing event names and payload contracts remain unchanged unless explicitly documented in a phase task.
- Tag and spawn architectures are explicitly out of scope and must not be changed by this refactor.
- TDD loop applies to each phase and task cluster: RED -> GREEN -> REFACTOR.
- Documentation milestones (tasks/continuation/pitfalls/agents updates) are committed separately from implementation milestones.

---

## Public API / Interface Changes (Planned)

- Add typed `@export var config: RS_*InteractionConfig` to each relevant controller.
- Preserve existing exported fields during migration window:
  - Door: `door_id`, `target_scene_id`, `target_spawn_point`, mode, cooldown.
  - Checkpoint: `checkpoint_id`, `spawn_point_id`.
  - Hazard: `damage_amount`, `is_instant_death`, `damage_cooldown`.
  - Victory: `objective_id`, `area_id`, `victory_type`, `trigger_once`.
  - Signpost: `message`, `repeatable`, prompt behavior.
  - Endgame Goal: `required_area` + inherited victory config.
- No event name changes planned:
  - Preserve existing event contracts such as `interact_prompt_show`, `interact_prompt_hide`, `signpost_message`, and transition/victory flows.

---

## Phase Table

| Phase | Name | Task IDs | Risk | Status |
|---|---|---|---|---|
| 0 | Baseline and Safety | T001-T003 | Low | Not Started |
| 1 | Resource Schema and Validation | T010-T014 | Medium | Not Started |
| 2 | Controller Binding to Resources | T020-T023 | Medium | Not Started |
| 3 | Scene/Prefab Migration | T030-T033 | High | Not Started |
| 4 | Validation and Enforcement | T040-T043 | Medium | Not Started |
| 5 | Cleanup and Doc Closure | T050-T053 | Medium | Not Started |

---

## TDD Task Backlog

## Phase 0 - Baseline and Safety

**Goal**: Lock current behavior and test baseline before introducing new abstractions.

- [ ] **T001** Run baseline interaction/unit/integration/style suites.
- [ ] **T002** Record current behavior invariants:
  - Door transitions and spawn targeting.
  - Checkpoint activation and respawn behavior.
  - Hazard damage cadence and instant death behavior.
  - Victory trigger dispatch behavior.
  - Signpost prompt/message/repeatable lock behavior.
  - Endgame goal unlock behavior by completed area.
- [ ] **T003** Add explicit no-behavior-change rule for infrastructure phases (Phases 1-2).

**Phase 0 Exit Criteria**
- Baseline tests passing and documented.
- Behavior invariants documented in this file or continuation prompt.

---

## Phase 1 - Resource Schema and Validation (Tests First)

**Goal**: Introduce strongly-typed interaction configs and validation framework.

### RED

- [ ] **T010 (RED)** Add tests for resource schema loading/validation:
  - Base config defaults and required fields.
  - Type-specific required field failures.
  - Invalid enum/empty field handling.

### GREEN

- [ ] **T011 (GREEN)** Add `rs_interaction_config.gd` base type.
- [ ] **T012 (GREEN)** Add typed config resources:
  - `rs_door_interaction_config.gd`
  - `rs_checkpoint_interaction_config.gd`
  - `rs_hazard_interaction_config.gd`
  - `rs_victory_interaction_config.gd`
  - `rs_signpost_interaction_config.gd`
  - `rs_endgame_goal_interaction_config.gd`
- [ ] **T013 (GREEN)** Add `u_interaction_config_validator.gd` with strict required-field checks.

### REFACTOR

- [ ] **T014 (REFACTOR)** Normalize defaults, naming, and `cfg_` instance conventions.

**Phase 1 Exit Criteria**
- All resource and validator tests green.
- Config resource family exists and is documented.

---

## Phase 2 - Controller Binding to Resources (Tests First)

**Goal**: Wire controllers to typed resources with behavior parity and fallback compatibility.

### RED

- [ ] **T020 (RED)** Add controller tests proving config parity for each interaction controller.

### GREEN

- [ ] **T021 (GREEN)** Wire controllers to read typed config resources.
- [ ] **T022 (GREEN)** Keep existing exports as backward-compatible fallback during migration.

### REFACTOR

- [ ] **T023 (REFACTOR)** Centralize config-apply paths to remove duplication across controllers.

**Phase 2 Exit Criteria**
- Controller tests prove no behavior regressions under config-driven mode.
- Config precedence and fallback behavior are deterministic and tested.

---

## Phase 3 - Scene/Prefab Migration (Tests First)

**Goal**: Move authored interaction values from scene literals to resource instances.

### RED

- [ ] **T030 (RED)** Add scene-level tests for required config presence and invalid config failure.

### GREEN

- [ ] **T031 (GREEN)** Migrate prefab and gameplay scenes to config resources.
- [ ] **T032 (GREEN)** Add/refresh config instances under `resources/interactions/`.

### REFACTOR

- [ ] **T033 (REFACTOR)** Remove duplicated per-scene literal values where config owns truth.

**Phase 3 Exit Criteria**
- Prefab/gameplay scenes use config resources for interaction data.
- Scene-level validation tests pass.

---

## Phase 4 - Validation and Enforcement (Tests First)

**Goal**: Enforce conventions and guard against malformed interaction configs.

### RED

- [ ] **T040 (RED)** Add style/contract checks for interaction config conventions.
  - Add script prefix enforcement coverage for `res://scripts/resources/interactions` (`rs_`).
  - Add resource naming/placement checks for `res://resources/interactions` (`cfg_` instance convention).
  - Add explicit checks that interaction config resources declare `script = ExtResource(...)`.

### GREEN

- [ ] **T041 (GREEN)** Enforce required script/resource attachment patterns.
- [ ] **T042 (GREEN)** Add negative tests:
  - Missing IDs.
  - Empty targets.
  - Invalid enum combinations.
  - Illegal values (negative cooldown where forbidden).

### REFACTOR

- [ ] **T043 (REFACTOR)** Tighten error messages and editor-facing docs.

**Phase 4 Exit Criteria**
- Validation and enforcement tests prevent bad config authoring patterns.
- Error messages are actionable for AI and humans.

---

## Phase 5 - Cleanup and Documentation Closure

**Goal**: Remove migration scaffolding and close the refactor with clean docs.

- [ ] **T050** Remove deprecated fallback exports after migration is complete.
- [ ] **T051** Run full targeted suites and style enforcement.
- [ ] **T052** Update continuation prompt + task status + `AGENTS.md` / `DEV_PITFALLS.md` as applicable.
- [ ] **T053** Create docs-only commit for phase completion artifacts.

**Phase 5 Exit Criteria**
- Migration fallback removed.
- All targeted suites green.
- Documentation synchronized with final architecture.

---

## Required Field Matrix (Validator Contract)

### Base (`RS_InteractionConfig`)

Required:
- `interaction_id: StringName` (non-empty)
- `enabled_by_default: bool`
- `trigger_settings: RS_SceneTriggerSettings` (non-null, or controller-level fallback allowed only in migration phases)

### Door (`RS_DoorInteractionConfig`)

Required:
- `door_id: StringName` (non-empty)
- `target_scene_id: StringName` (non-empty)
- `target_spawn_point: StringName` (non-empty)
- `trigger_mode` valid for door flow
- `cooldown_duration >= 0.0`

### Checkpoint (`RS_CheckpointInteractionConfig`)

Required:
- `checkpoint_id: StringName` (non-empty)
- `spawn_point_id: StringName` (non-empty)

### Hazard (`RS_HazardInteractionConfig`)

Required:
- `damage_amount >= 0.0`
- `damage_cooldown >= 0.0`
- `is_instant_death: bool`

### Victory (`RS_VictoryInteractionConfig`)

Required:
- `objective_id` or `area_id` according to victory type rules
- `victory_type` valid enum
- `trigger_once: bool`

### Signpost (`RS_SignpostInteractionConfig`)

Required:
- `message: String` (non-empty for production content)
- `repeatable: bool`
- prompt metadata as needed by current prompt system

### Endgame Goal (`RS_EndgameGoalInteractionConfig`)

Required:
- Inherits victory requirements
- `required_area: String` (non-empty)
- must map to `GAME_COMPLETE` path

---

## Test Plan and Run Commands

Run these suites at the specified points in the phase checklist.

### Unit - Interactions

- `tools/run_gut_suite.sh -gdir=res://tests/unit/interactables -ginclude_subdirs=true`
- `tools/run_gut_suite.sh -gdir=res://tests/unit/ecs/components -ginclude_subdirs=true`
- `tools/run_gut_suite.sh -gdir=res://tests/unit/ecs/systems -ginclude_subdirs=true`
- `tools/run_gut_suite.sh -gdir=res://tests/unit/ui -ginclude_subdirs=true`

### Integration - Gameplay/Spawn

- `tools/run_gut_suite.sh -gdir=res://tests/integration/gameplay -ginclude_subdirs=true`
- `tools/run_gut_suite.sh -gdir=res://tests/integration/spawn_system -ginclude_subdirs=true`
- `tools/run_gut_suite.sh -gdir=res://tests/integration/scene_manager -ginclude_subdirs=true`

### Style / Contract

- `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true`
- Mandatory reference check: `tests/unit/style/test_style_enforcement.gd`

### Full Regression Gate (Phase 5)

- `tools/run_gut_suite.sh -gdir=res://tests/unit -ginclude_subdirs=true`
- `tools/run_gut_suite.sh -gdir=res://tests/integration -ginclude_subdirs=true`

---

## Test Scenarios (Must Be Covered)

- Door transition + spawn target correctness.
- Checkpoint activation and respawn behavior.
- Hazard damage cadence and instant death behavior.
- Victory trigger dispatch behavior.
- Signpost prompt/message + repeatable lock behavior.
- Endgame goal unlock based on completed area.
- Interaction blocking during transitions and overlays.

---

## Rollback and Migration Notes

- Keep migration reversible until Phase 5:
  - Preserve fallback exports in controllers.
  - Keep old scene-authored values intact until config resources are verified.
- If regressions appear:
  1. Re-enable fallback path in affected controller.
  2. Revert scene config assignment for failing interaction type.
  3. Keep validator warnings enabled to surface broken configs.
- Do not remove fallback exports before Phase 5 exit criteria are met.

---

## Documentation and Continuation Requirements (Per Phase)

At each phase completion:

1. Update this tasks file:
  - Mark completed tasks `[x]`.
  - Add completion notes under phase section (tests run, commit hash, caveats).
2. Update continuation prompt:
  - `docs/general/interactions_refactor/interactions-refactor-continuation-prompt.md`
3. Update architecture references when patterns stabilize:
  - `AGENTS.md` interaction patterns section (if behavior/pattern changed)
  - `docs/general/DEV_PITFALLS.md` for new interaction pitfalls (if any)
4. Keep documentation commits separate from implementation commits.

---

## Acceptance Criteria For This Planning Item

- [x] New tasks doc path and filename fixed.
- [x] Phases, task IDs, TDD order, and test matrix pre-decided.
- [x] No implementer decisions remain on scope or architecture direction.
