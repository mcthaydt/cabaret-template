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

- **Phase**: 2 (Naming Fixes)
- **Completed**: 4/23 (17.4%)
- **Current batch**: Batch 2 - Naming Fixes

---

## Resume Here

**Next tasks to execute (Batch 2)**:
1. Task 5: Fix manager helper prefixes (`m_` -> `u_`)
2. Task 6: Rename interactable controllers (`e_` -> `inter_`)
3. Task 7: Convert surface marker to component
4. Task 8: Rename `main.gd`

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
| 2: Naming Fixes | 5-8 | Needs scans |
| 3: Folder Restructure | 9-16 | Ready |
| 4: Organization | 17-23 | Optional |

---

**Last Updated**: 2026-01-23
