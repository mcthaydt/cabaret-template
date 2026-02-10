# Interactions Refactor Continuation Prompt

## Current Status

- Initiative: Interactions Refactor (resource-driven configuration, TDD-first)
- Current phase: Phase 2 - Controller Binding to Resources
- Primary tasks file: `docs/general/interactions_refactor/interactions-refactor-tasks.md`
- Task progress: 8/24 complete (`T001-T003`, `T010-T014` complete)
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

1. Execute `T020 (RED)`: add controller parity tests for config-driven behavior across all in-scope interaction controllers.
2. Implement `T021-T022 (GREEN)`: bind controllers to typed configs while preserving fallback exports.
3. Perform `T023 (REFACTOR)`: centralize config-apply paths and remove duplication across controllers.

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
- Phase 1 artifacts now exist:
  - Resource scripts: `scripts/resources/interactions/`
  - Validator utility: `scripts/gameplay/helpers/u_interaction_config_validator.gd`
  - Config instances: `resources/interactions/*/cfg_*.tres`
