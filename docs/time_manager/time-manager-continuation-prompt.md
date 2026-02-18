# Time Manager - Continuation Prompt

**Branch**: `TimeManager`
**Current Status**: Phase 3 in progress — Commit 1 complete
**Last Completed**: Phase 3, Commit 1 (`u_world_clock.gd` + tests)
**Next Action**: Begin Phase 3, Commit 2 (wire world clock into `m_time_manager.gd` + integration test)

---

## Context

We are implementing `M_TimeManager` to replace `M_PauseManager` as the central time authority for the Cabaret Template. The full implementation plan is documented in `docs/time_manager/time-manager-plan.md` and the task checklist is in `docs/time_manager/time-manager-tasks.md`.

The implementation follows **TDD (Red-Green-Refactor)** — tests are written within each phase, not deferred. Each helper commit creates the class with stubs, writes tests (RED), then implements (GREEN).

The implementation is split into 5 phases:

- **Phase 1**: Core refactor — replace M_PauseManager (6 commits, includes 14 TDD tests)
- **Phase 2**: Timescale support (3 commits, includes 7 TDD tests)
- **Phase 3**: World clock (2 commits, includes 13 TDD tests)
- **Phase 4**: Redux state & persistence (6 commits)
- **Phase 5**: Documentation (1 commit — AGENTS.md only)

---

## Resume Prompt

Use this to resume implementation in a new session:

---

We are on branch `TimeManager` implementing `M_TimeManager` to replace `M_PauseManager`.

**Current status**: Phase 3 in progress, Commit 1 complete

**Implementation plan**: `docs/time_manager/time-manager-plan.md` — contains full code for every file to create/modify.
**Task checklist**: `docs/time_manager/time-manager-tasks.md` — tracks completion per commit.

**Key files to read before starting**:
- `docs/time_manager/time-manager-plan.md` (full spec)
- `scripts/managers/m_time_manager.gd` (Phase 1 baseline for Phase 2+)
- `scripts/root.gd` (ServiceLocator wiring to update in Phase 1 Commit 4)
- `AGENTS.md`
- `docs/general/DEV_PITFALLS.md`
- `docs/general/STYLE_GUIDE.md`

**Implementation rules**:
1. Follow TDD strictly — write tests BEFORE implementing method bodies in each commit
2. GDScript requires class files to exist before tests reference them — create stubs first, then tests (RED), then implement (GREEN)
3. Run the relevant test suite after each commit before proceeding
4. Mark tasks complete in `time-manager-tasks.md` after each commit
5. Update the "Current status" line in this file after each phase
6. Commit at the end of each logical milestone (test-green state)
7. Do not create new planning docs unless asked; always keep `time-manager-tasks.md` and this continuation prompt updated after each phase (plus AGENTS/DEV_PITFALLS updates when new patterns or pitfalls are discovered)

**Phase 1 test commands** (run after Commit 6):
```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/managers -gselect=test_time_manager -gexit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration/scene_manager -gexit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/integration -gexit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/scene_manager -gexit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/style -gexit
```

**Full test suite** (run after all phases):
```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Continue with Phase 3, Commit 2: wire `U_WorldClock` into `m_time_manager.gd`, add the world-clock integration test, run RED then GREEN.

---

## Phase Status Log

| Phase | Status | Notes |
|-------|--------|-------|
| Phase 1: Core Refactor | Complete | 6 commits complete; `M_PauseManager` removed; Phase 1 test suites passing |
| Phase 2: Timescale | Complete | Commits 1-3 complete; timescale + ECS scaled delta tests green |
| Phase 3: World Clock | In progress | Commit 1 complete (U_WorldClock helper + 12 tests) |
| Phase 4: Redux State | Not started | Blocked by Phase 3 |
| Phase 5: Documentation | Not started | Blocked by Phase 4; AGENTS.md only |
