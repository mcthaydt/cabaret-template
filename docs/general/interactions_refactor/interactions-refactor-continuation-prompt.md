# Interactions Refactor Continuation Prompt

## Current Status

- Initiative: Interactions Refactor (resource-driven configuration, TDD-first)
- Current phase: Phase 0 - Baseline and Safety
- Primary tasks file: `docs/general/interactions_refactor/interactions-refactor-tasks.md`
- Task progress: 0/24 complete

## Next Actions

1. Execute `T001` baseline test runs and record results.
2. Document behavior invariants for `T002`.
3. Add explicit no-behavior-change constraint notes for `T003`.

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
