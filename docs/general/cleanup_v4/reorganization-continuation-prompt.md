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

- **Phase**: 3 (Folder Restructure)
- **Completed**: 15/23 (65.2%)
- **Current batch**: Batch 3 - Folder Restructure

---

## Resume Here

**Next tasks to execute (Batch 3)**:
1. Task 16: Move scattered interfaces (`scripts/*/i_*.gd` -> `scripts/interfaces/`)

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
| 1: Quick Wins | 2-4 | Complete |
| 2: Naming Fixes | 5-8 | Complete |
| 3: Folder Restructure | 9-16 | In progress (Task 15 complete) |
| 4: Organization | 17-23 | Optional |

---

**Last Updated**: 2026-01-24
