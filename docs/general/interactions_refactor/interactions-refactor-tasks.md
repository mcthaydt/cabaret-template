# Interactions Refactor Tasks (TDD-First)

## Overview

This document defines a decision-complete, TDD-first roadmap to refactor interaction authoring to a more resource-driven architecture while preserving current runtime behavior.

This refactor covers all interaction controllers and keeps the existing hybrid runtime pattern:
- Controllers remain runtime orchestrators.
- Resources become the declarative source of interaction configuration.

**Status**: In Progress  
**Current Phase**: Phase 1  
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
| 0 | Baseline and Safety | T001-T003 | Low | Complete |
| 1 | Resource Schema and Validation | T010-T014 | Medium | In Progress |
| 2 | Controller Binding to Resources | T020-T023 | Medium | Not Started |
| 3 | Scene/Prefab Migration | T030-T033 | High | Not Started |
| 4 | Validation and Enforcement | T040-T043 | Medium | Not Started |
| 5 | Cleanup and Doc Closure | T050-T053 | Medium | Not Started |

---

## TDD Task Backlog

## Phase 0 - Baseline and Safety

**Goal**: Lock current behavior and test baseline before introducing new abstractions.

- [x] **T001** Run baseline interaction/unit/integration/style suites.
- [x] **T002** Record current behavior invariants:
  - Door transitions and spawn targeting.
  - Checkpoint activation and respawn behavior.
  - Hazard damage cadence and instant death behavior.
  - Victory trigger dispatch behavior.
  - Signpost prompt/message/repeatable lock behavior.
  - Endgame goal unlock behavior by completed area.
- [x] **T003** Add explicit no-behavior-change rule for infrastructure phases (Phases 1-2).

### T001 Baseline Run Results (2026-02-10, final rerun)

Executed baseline suites using the commands in "Test Plan and Run Commands" (`tools/run_gut_suite.sh ... -ginclude_subdirs=true`).

| Suite | Result | Notes |
|---|---|---|
| `res://tests/unit/interactables` | PASS | 22/22 passing |
| `res://tests/unit/ecs/components` | PASS | 49/49 passing |
| `res://tests/unit/ecs/systems` | PASS | 200/200 passing |
| `res://tests/unit/ui` | PASS | 170/172 passing, 2 pending (existing) |
| `res://tests/integration/gameplay` | PASS | 10/10 passing |
| `res://tests/integration/spawn_system` | PASS | 19/19 passing |
| `res://tests/integration/scene_manager` | PASS | 90/90 passing |
| `res://tests/unit/style` | PASS | 11/11 passing |

Stabilization work completed for deterministic baseline:
- Disabled `M_StateStore` autoload persistence in ECS systems tests that do not test persistence behavior.
- Root cause addressed: ambient `user://savegame.json` autoload emitted state-normalization warnings (for example `spawn_test`) that surfaced as unexpected test errors.

Artifacts:
- Per-suite logs: `.tmp/interactions_refactor_baseline_phase0_final2/*.log`
- Exit code summary: `.tmp/interactions_refactor_baseline_phase0_final2/status.tsv`

### T002 Behavior Invariants (Current Runtime Contract)

Door transitions and spawn targeting:
- `Inter_DoorTrigger` configures and delegates to `C_SceneTriggerComponent` using current exports (`door_id`, `target_scene_id`, `target_spawn_point`, trigger mode, cooldown clamp).
- Door activation path is component-driven (`trigger_interact()`), with transition blocking on transition state and cooldown/pending guards.
- On transition trigger, gameplay `target_spawn_point` is dispatched before scene transition, and transition routing uses door registry transition type with scene-manager high priority.

Checkpoint activation and respawn behavior:
- `Inter_CheckpointZone` maps `checkpoint_id` and `spawn_point_id` to `C_CheckpointComponent` and keeps passive overlap behavior (`ignore_initial_overlap = false`).
- Checkpoint activation updates gameplay `last_checkpoint` and publishes `checkpoint_activated`.
- Spawn fallback behavior remains: missing checkpoint metadata/node falls back to `sp_default` and clears `target_spawn_point`.

Hazard damage cadence and instant death behavior:
- `Inter_HazardZone` maps `damage_amount`, `is_instant_death`, and non-negative `damage_cooldown` to `C_DamageZoneComponent`.
- Hazard zones enforce player collision mask minimum layer 1 and passive overlap behavior (`ignore_initial_overlap = false`).
- Damage applies on enter, exits stop additional cadence damage, cooldown blocks rapid repeated hits, and instant-death zones route through death/game-over flow.

Victory trigger dispatch behavior:
- `Inter_VictoryZone` maps `objective_id`, `area_id`, `victory_type`, and `trigger_once` directly to `C_VictoryTriggerComponent`.
- Victory event handling marks trigger state and dispatches gameplay victory + area-complete actions.
- `GAME_COMPLETE` victory stays gated until required progression prerequisites are satisfied.

Signpost prompt/message/repeatable lock behavior:
- `Inter_Signpost` is interact-only, zero-cooldown, prompt label `"Read"`.
- Activation emits local signal + `signpost_message` event payload containing `message`, `controller_id`, and `repeatable`.
- Non-repeatable signposts lock after first activation and hide interact prompts.
- HUD behavior contract remains: signpost toast suppressed while paused, and interact prompt hidden while toast is visible.

Endgame goal unlock behavior by completed area:
- `Inter_EndgameGoalZone` inherits victory behavior and forces `victory_type = GAME_COMPLETE`.
- Unlock gate is state-driven by `required_area` (default `"interior_house"`): locked state keeps controller disabled/hidden; unlock enables and shows goal volume.
- Gameplay completion gate remains enforced until required area completion is present in gameplay `completed_areas`.

### T003 No-Behavior-Change Rules (Phases 1-2)

For Phase 1 (resource schema/validation) and Phase 2 (controller binding), these runtime contracts are frozen:
- Event names and payload shapes stay identical (`interact_prompt_show`, `interact_prompt_hide`, `signpost_message`, checkpoint/victory event flows).
- Door/checkpoint/hazard/victory/signpost/endgame trigger semantics, gating, cooldown behavior, and transition blocking remain unchanged.
- Scene transition routing behavior (target scene, spawn targeting, transition type resolution, priority usage) remains unchanged.
- Gameplay state effects remain unchanged (`target_spawn_point`, `last_checkpoint`, `completed_areas`, victory/game-complete dispatch timing).
- Existing controller export fields remain supported as fallback during migration; resource configs may layer in without changing runtime outputs.
- Any behavior change found during Phases 1-2 is treated as regression unless explicitly added as a post-Phase-2 scoped task.

### Phase 0 Completion Notes

- Exit criteria met on 2026-02-10 with 8/8 baseline suites green.
- Baseline blocker resolved by test-environment hardening in ECS systems suite.
- Continuation prompt updated for Phase 1 handoff.

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
