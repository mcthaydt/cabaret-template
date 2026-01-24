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

- **Phase**: 4 (Organization)
- **Completed**: 20/23 (87.0%)
- **Current batch**: Phase 5 - Polish

---

## Resume Here

**Next tasks to execute (Phase 5 - Polish)**:
1. Task 21: Consolidate utilities into domain subfolders
2. Task 22: Clean up unused test files
3. Task 23: (see reorganization-tasks.md)

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
| 3: Folder Restructure | 9-16 | Complete |
| 4: Organization | 17-23 | Complete |

---

**Last Updated**: 2026-01-24
