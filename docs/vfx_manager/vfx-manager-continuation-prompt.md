# VFX Manager - Continuation Prompt

## Current Status (2026-01-16)

- **Refactor status**: Phase 8 complete (UI Settings Preview). Verification pending.
- **Phase 5 commit**: `994da2e`.
- **Phase 6 commit**: `b288afc`.
- **Phase 7 commit**: `5a882b7`.
- **Phase 8 commit**: `75cb6b6`.
- **Next phase**: Phase 9 (Documentation Updates).
- **New helper**: None (Phase 8).
- **Tests run**: Not run (Phase 8 tests pending).
- **Manual QA**: Pending Phase 1 (T1.13), Phase 2 (T2.6), Phase 3 (T3.11), Phase 4 (T4.11), Phase 5 (T5.10), Phase 8 (T8.10).

## Required Readings (Do Not Skip)

- `AGENTS.md` - project conventions, testing, and update rules.
- `docs/general/DEV_PITFALLS.md` - known gotchas.
- `docs/general/STYLE_GUIDE.md` - naming, formatting, prefixes.
- `docs/vfx_manager/vfx-manager-prd.md` - scope + goals.
- `docs/vfx_manager/vfx-manager-plan.md` - phases and sequencing.
- `docs/vfx_manager/vfx-manager-refactor-tasks.md` - primary task list (follow in order).
- `docs/vfx_manager/vfx-manager-overview.md` - current architecture snapshot.
- `docs/vfx_manager/vfx-manager-refactor.md` - prior decisions and rationale.

## Process for Completion (Every Task / Phase)

1. Start with the next unchecked task in `vfx-manager-refactor-tasks.md` (TDD order).
2. Write the test → run it (fail) → implement minimal change → run again (pass).
3. Run relevant test suites; if you add/rename scripts/scenes/resources, run `tests/unit/style/test_style_enforcement.gd`.
4. Update `vfx-manager-refactor-tasks.md` with [x] and completion notes (commit hash, tests run, deviations).
5. Update this continuation prompt with current status, tests run, and next step.
6. Update `AGENTS.md` and/or `DEV_PITFALLS.md` if new patterns or pitfalls emerged.
7. Commit with a clear message; commit documentation updates separately from implementation.

## Test / Document / Commit Checklist

- **Test**: Run the smallest relevant suite first; expand to integration/regression as needed.
- **Document**: Update task checklist + this prompt; update `AGENTS.md`/`DEV_PITFALLS.md` when required.
- **Commit**: Keep code and docs in separate commits and include the commit hash in task notes.

## Repo Reality Checks (Do Not Skip)

- There is **no** `MockECSEventBus`; use `U_ECSEventBus.reset()` in `before_each()`.
- `U_ECSEventNames` centralizes ECS event/service names; use constants for subscriptions.
- Publisher systems publish typed requests via `U_ECSEventBus.publish_typed()`.
- `M_VFXManager` processes request queues inside `_physics_process()`; event handlers only enqueue.
- `M_VFXManager` no longer self-registers; `root.gd` handles ServiceLocator bootstrap.

## Next Step

- Phase 9: update documentation for refactored VFX manager.
