# Project Reorganization Continuation Prompt

## Context

**Goal**: Reorganize cabaret-ball Godot project for improved folder clarity, consistent naming, and developer navigability.
**Scope**: 614 scripts, 76 scenes, 23 tasks across 5 phases.

---

## Read First

1. `docs/general/DEV_PITFALLS.md`
2. `docs/general/STYLE_GUIDE.md`
3. `docs/general/cleanup_v4/reorganization-tasks.md` (primary reference - all details)

---

## Current Status

- **Phase**: 1 (Quick Wins)
- **Completed**: 1/23 (4.3%)
- **Current batch**: Batch 1 - Zero-Risk Quick Wins

---

## Resume Here

**Next tasks to execute (Batch 1)**:
1. Task 2: Move prototype scenes to `tests/scenes/prototypes/`
2. Task 3: Move prototype scripts to `tests/prototypes/`
3. Task 4: Move ECS helpers to `scripts/utils/ecs/`

See `reorganization-tasks.md` for full details, commands, and verification steps.

---

## Execution Rules (Brief)

### Before Each Task
- Ensure clean working tree (`git status`)
- Run tests to establish baseline

### During Each Task
- Use `git mv` for moves (preserves history)
- Update all references with find/replace
- Verify critical files manually

### After Each Task
- Run affected tests
- Commit: `refactor: [task name] - [file count] files updated`
- Update this prompt + tasks doc checkboxes

### Rollback
If tests fail: `git reset --hard HEAD`, analyze, retry.

---

## Quick Reference

| Batch | Tasks | Status |
|-------|-------|--------|
| 1: Quick Wins | 2-4 | Ready |
| 2: Naming Fixes | 5-8 | Needs scans |
| 3: Folder Restructure | 9-16 | Ready |
| 4: Organization | 17-23 | Optional |

---

**Last Updated**: 2026-01-23
