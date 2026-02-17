# Time Manager - Continuation Prompt

**Branch**: `TimeManager`
**Current Status**: Planning complete — Phase 1 not yet started
**Last Completed**: Documentation (overview + plan + TDD restructure)
**Next Action**: Begin Phase 1, Commit 1

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

**Current status**: [UPDATE THIS LINE — e.g. "Starting Phase 1 Commit 1" / "Phase 1 complete, starting Phase 2"]

**Implementation plan**: `docs/time_manager/time-manager-plan.md` — contains full code for every file to create/modify.
**Task checklist**: `docs/time_manager/time-manager-tasks.md` — tracks completion per commit.

**Key files to read before starting**:
- `docs/time_manager/time-manager-plan.md` (full spec)
- `scripts/managers/m_pause_manager.gd` (source to port in Phase 1)
- `scripts/root.gd` (ServiceLocator wiring to update in Phase 1 Commit 4)

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

Start with Phase 1, Commit 1: create `u_pause_system.gd` with stubs + `test_time_manager.gd` with U_PauseSystem tests (RED), then implement (GREEN).

---

## Phase Status Log

| Phase | Status | Notes |
|-------|--------|-------|
| Phase 1: Core Refactor | Not started | 14 TDD tests (10 unit + 4 integration) |
| Phase 2: Timescale | Not started | Blocked by Phase 1; 7 TDD tests |
| Phase 3: World Clock | Not started | Blocked by Phase 2; 13 TDD tests |
| Phase 4: Redux State | Not started | Blocked by Phase 3 |
| Phase 5: Documentation | Not started | Blocked by Phase 4; AGENTS.md only |
