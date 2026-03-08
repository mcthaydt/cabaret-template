# vCam Manager — Task Index

**Progress:** 5 / 5 documentation tasks complete; 0 implementation tasks complete
**Estimated Test Count:** ~301 checks (about 259 automated tests + 42 manual checks)
**Status note:** Strict TDD (Red/Green/Refactor). Each camera mode has a dedicated phase. Mobile drag-look is a hard prerequisite for orbit/first-person completion.
**Manual QA cadence:** Manual checks are embedded in the relevant implementation phases (no standalone manual-testing phase).

---

## Subtask Files

| File | Scope | Phases |
|------|-------|--------|
| [vcam-base-tasks.md](vcam-base-tasks.md) | Shared infrastructure: state/persistence, base resources, component/interface/manager, ECS system, scene wiring, mobile drag-look, soft zone, blend, occlusion, editor preview, integration tests, regression/docs | 0, 1, 5, 6, 7, 8, 9, 10, 11, 12, 13 |
| [vcam-orbit-tasks.md](vcam-orbit-tasks.md) | Orbit camera mode: resource, evaluator, default preset, manual checks | 2 |
| [vcam-fixed-tasks.md](vcam-fixed-tasks.md) | Fixed camera mode: resource, evaluator, manual checks | 3 |
| [vcam-fps-tasks.md](vcam-fps-tasks.md) | First-person camera mode: resource, evaluator, refactor pass, manual checks | 4 |

---

## Phase Execution Order

| Task Phase | File | Description | Plan Commits |
|------------|------|-------------|--------------|
| 0 | Base | State and Persistence | 0.0 – 0.4 |
| 1 | Base | Base Authoring Resources (Soft Zone + Blend Hint) | 1.1 (partial) |
| 2 | Orbit | Orbit Camera Mode | 1.1 (partial), 2.3 (partial) |
| 3 | Fixed | Fixed Camera Mode | 1.1 (partial), 2.3 (partial) |
| 4 | FPS | First-Person Camera Mode | 1.1 (partial), 2.3 (partial) |
| 5 | Base | Component, Interface, and Manager Core | 1.2, 2.1, 2.2 |
| 6 | Base | vCam System (ECS) and Scene Wiring | 2.4, 2.5 |
| 7 | Base | Mobile Drag-Look | 2.4a |
| 8 | Base | Projection-Based Soft Zone | 3.1, 3.2 |
| 9 | Base | Live Blend Evaluation and Camera-Manager Integration | 4.1, 4.2, 4.3 |
| 10 | Base | Occlusion and Silhouette | 5.1, 5.1a, 5.2, 5.3 |
| 11 | Base | Editor Preview | 6.1 |
| 12 | Base | Integration Tests | 7.1 |
| 13 | Base | Regression Coverage and Docs | 7.2, 7.3 |

> **Note:** "Plan Commits" reference `vcam-manager-plan.md` commit numbers (0.0–7.3), which use a different numbering scheme than task phases (0–13).

---

## Documentation Alignment (Complete)

- [x] Align runtime wiring with actual root and gameplay scene structure
- [x] Split transient `vcam` observability from persisted silhouette settings
- [x] Correct blend, shake, and soft-zone architecture to match repo reality
- [x] Align file paths and naming with the current style guide
- [x] Make mobile drag-look a hard requirement for rotatable orbit and first-person support

---

## Links

- [Plan](vcam-manager-plan.md)
- [Overview](vcam-manager-overview.md)
- [PRD](vcam-manager-prd.md)
- [Continuation Prompt](vcam-manager-continuation-prompt.md)
