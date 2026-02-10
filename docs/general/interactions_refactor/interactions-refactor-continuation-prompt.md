# Interactions Refactor Continuation Prompt

## Current Status

- Initiative: Interactions Refactor (resource-driven configuration, TDD-first)
- Current phase: Phase 4 - Validation and Enforcement
- Primary tasks file: `docs/general/interactions_refactor/interactions-refactor-tasks.md`
- Task progress: 16/24 complete (`T001-T003`, `T010-T014`, `T020-T023`, `T030-T033` complete)
- Phase 0 baseline status (2026-02-10): 8/8 suites green
  - `res://tests/unit/interactables`: PASS (22/22)
  - `res://tests/unit/ecs/components`: PASS (49/49)
  - `res://tests/unit/ecs/systems`: PASS (200/200)
  - `res://tests/unit/ui`: PASS (170/172, 2 pending)
  - `res://tests/integration/gameplay`: PASS (10/10)
  - `res://tests/integration/spawn_system`: PASS (19/19)
  - `res://tests/integration/scene_manager`: PASS (90/90)
  - `res://tests/unit/style`: PASS (11/11)

## Phase 2 Completion Summary (2026-02-10)

- Added config parity tests for all in-scope interaction controllers, including new endgame goal coverage.
- Bound all in-scope controllers to config resources with deterministic precedence (`config` wins) and fallback to existing exports.
- Added shared resolver helper: `scripts/gameplay/helpers/u_interaction_config_resolver.gd`.
- Validation suites:
  - `res://tests/unit/interactables`: PASS (34/34)
  - `res://tests/unit/style`: PASS (11/11)
  - `res://tests/unit/resources`: PASS (32/32)

## Phase 3 Completion Summary (2026-02-10)

- Added scene-level config-binding coverage via `tests/unit/interactables/test_scene_interaction_config_binding.gd`.
- Migrated gameplay/prefab interaction controllers to resource `config` assignments across exterior/alleyway/interior scenes and interaction prefabs.
- Added scene-specific `cfg_*.tres` instances under `resources/interactions/**` (doors/checkpoints/hazards/victory/signposts/endgame).
- Removed duplicated scene-authored interaction literals where config resources now own values.
- Validation suites:
  - `res://tests/unit/interactables`: PASS (36/36)
  - `res://tests/unit/style`: PASS (11/11)
  - `res://tests/integration/gameplay`: PASS (10/10)
  - `res://tests/integration/spawn_system`: PASS (19/19)
  - `res://tests/integration/scene_manager`: PASS (90/90)
  - `res://tests/unit/resources`: PASS (32/32)

## Next Actions

1. Execute `T040 (RED)`: add style/contract tests for interaction config naming, placement, and required script attachment coverage.
2. Implement `T041-T042 (GREEN)`: enforce required config attachment patterns and add negative-path validation tests (missing IDs/targets, invalid enums, illegal values).
3. Perform `T043 (REFACTOR)`: tighten error messages and Phase 4 editor-facing guidance.

## Constraints Reminder

- Follow RED -> GREEN -> REFACTOR sequencing.
- Keep behavior parity while enforcing config contracts (avoid changing runtime event payloads/flow).
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
- Phase 2 artifacts now exist:
  - Resolver utility: `scripts/gameplay/helpers/u_interaction_config_resolver.gd`
  - Controller config binding + fallback tests: `tests/unit/interactables/test_e_*`
- Phase 3 artifacts now exist:
  - Scene migration guard test: `tests/unit/interactables/test_scene_interaction_config_binding.gd`
  - Scene-level config assignment in gameplay/prefab interaction nodes
  - Expanded authored config instances in `resources/interactions/**`
