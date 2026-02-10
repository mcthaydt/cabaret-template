# Interactions Refactor Continuation Prompt

## Current Status

- Initiative: Interactions Refactor (resource-driven configuration, TDD-first)
- Current phase: Phase 1 - Resource Schema and Validation
- Primary tasks file: `docs/general/interactions_refactor/interactions-refactor-tasks.md`
- Task progress: 3/24 complete (`T001-T003` marked complete)
- Phase 0 baseline status (2026-02-10): 8/8 suites green
  - `res://tests/unit/interactables`: PASS (22/22)
  - `res://tests/unit/ecs/components`: PASS (49/49)
  - `res://tests/unit/ecs/systems`: PASS (200/200)
  - `res://tests/unit/ui`: PASS (170/172, 2 pending)
  - `res://tests/integration/gameplay`: PASS (10/10)
  - `res://tests/integration/spawn_system`: PASS (19/19)
  - `res://tests/integration/scene_manager`: PASS (90/90)
  - `res://tests/unit/style`: PASS (11/11)

## Next Actions

1. Execute `T010 (RED)`: add failing tests for interaction config schema + validator behavior.
2. Implement `T011-T013 (GREEN)` resource base/types + validator until new tests pass.
3. Perform `T014 (REFACTOR)` naming/default normalization and doc updates.

## Constraints Reminder

- Follow RED -> GREEN -> REFACTOR sequencing.
- Keep behavior parity during Phases 1-2.
- Run style enforcement after scene/resource structure changes:
  - `tests/unit/style/test_style_enforcement.gd`
- Keep documentation commits separate from implementation commits.

## Controllers In Scope

- `scripts/gameplay/inter_door_trigger.gd`
- `scripts/gameplay/inter_checkpoint_zone.gd`
- `scripts/gameplay/inter_hazard_zone.gd`
- `scripts/gameplay/inter_victory_zone.gd`
- `scripts/gameplay/inter_signpost.gd`
- `scripts/gameplay/inter_endgame_goal_zone.gd`

## Notes for Next Engineer/Agent

- Do not refactor tags/spawn architecture as part of this initiative.
- Ensure new interaction config directories are covered by style/contract tests during Phase 4.
- Phase 0 invariants + no-behavior-change rules are now documented in the tasks file and are the source of truth for regression checks in Phases 1-2.
- ECS systems test environment is now stabilized by disabling `M_StateStore` persistence in non-persistence tests.
