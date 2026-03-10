# vCam Manager — Task Index

**Progress:** 5 / 5 documentation tasks complete; Phases 0A + 0A2 + 0B + 0C + 0D + 0E + 0F + 1A + 1B + 1C complete, Phase 1D next
**Estimated Test Count:** ~440 checks (about 360 automated tests + 80 manual checks including game-feel QA)
**Status note:** Strict TDD (Red/Green/Refactor). Each camera mode has a dedicated phase. Mobile drag-look is a hard prerequisite for orbit/first-person completion.
**Manual QA cadence:** Manual checks are embedded in the relevant implementation phases (no standalone manual-testing phase).
**Quality gaps addressed:** Orientation continuity, blend interruption, invalid-target recovery, occlusion anti-flicker, performance budget, observability expansion, open-question resolution, cross-mode feel QA, **second-order dynamics for natural camera motion**, **ECS event bus integration**, **QB rule context enrichment**, **entity-based target resolution**, **mode-specific game feel (orbit: look-ahead/auto-level/soft zone; FP: strafe tilt/head bob/landing dip)**.

---

## Subtask Files

| File | Scope | Phases |
|------|-------|--------|
| [vcam-base-tasks.md](vcam-base-tasks.md) | Shared infrastructure: state/persistence, **ECS event bus constants**, base resources, **second-order dynamics**, response tuning, component/interface/manager, ECS system, scene wiring, mobile drag-look, blend, **QB rule context enrichment**, **shared game feel (FOV breathing, landing impact)**, occlusion, editor preview, integration tests, regression/docs | 0, 1, 5, 6, 7, 8, 9, 10, 11, 12, 13 |
| [vcam-orbit-tasks.md](vcam-orbit-tasks.md) | Orbit camera mode: resource, evaluator, default preset, then later **orbit game feel (look-ahead, auto-level, soft zone, hysteresis)** after base Phase 6A2 | 2, 8 |
| [vcam-fps-tasks.md](vcam-fps-tasks.md) | First-person camera mode: resource, evaluator, refactor pass, then later **FP game feel (strafe tilt, head bob, landing head dip)** after base Phase 6A2 | 3, 9 |
| [vcam-fixed-tasks.md](vcam-fixed-tasks.md) | Fixed camera mode: resource, evaluator, final evaluator refactor, manual checks | 4 |

---

## Phase Execution Order

| Task Phase | File | Description | Plan Sections |
|------------|------|-------------|--------------|
| 0 | Base | State and Persistence | 0.0 – 0.4 |
| 1 | Base | Base Authoring Resources (Soft Zone + Blend Hint + second-order utilities + response resource) | 1.1 (partial) |
| 2 | Orbit | Orbit resource, evaluator branch, and default preset | Phase 2A–2B |
| 3 | FPS | First-person resource, evaluator branch, and default preset | Phase 3A–3B |
| 4 | Fixed | Fixed Camera Mode (extends evaluator, final refactor) | 1.1 (partial), 2.3 (partial) |
| 5 | Base | Component, Interface, and Manager Core | 1.2, 2.1, 2.2 |
| 6 | Base | vCam System, scene wiring, and mobile drag-look/touch gating | 2.4, 2.4a, 2.5 |
| 7 | Base | Shared response and same-frame smoothing in `S_VCamSystem` | 1F, 6A2 |
| 8 | Orbit | Orbit game feel (look-ahead, auto-level, soft zone, hysteresis) | Phase 2C |
| 9 | FPS | FP game feel (strafe tilt, head bob, landing head dip) | Phase 3C |
| 10 | Base | QB-Driven Camera Feel | 6A3 (within base-tasks) |
| 11 | Base | Live Blend Evaluation and Camera-Manager Integration | 4.1, 4.2, 4.3 |
| 12 | Base | Occlusion and Silhouette | 5.1, 5.1a, 5.2, 5.3 |
| 13 | Base | Editor Preview | 6.1 |
| 14 | Base | Integration Tests | 7.1 |
| 15 | Base | Regression Coverage and Docs | 7.2, 7.3 |

> **Note:** "Plan Sections" references `vcam-manager-plan.md` section/commit labels, which do not map 1:1 to task phases.
> **Execution order rationale:** Orbit and first-person resource/evaluator work can start before base feel integration, but orbit Phase 2C and FPS Phase 3C stay blocked on base Phase 6A2. This index now treats those feel passes as later phases instead of implying Phases 2 and 3 are fully executable end-to-end up front.

---

## Documentation Alignment (Complete)

- [x] Align runtime wiring with actual root and gameplay scene structure
- [x] Split transient `vcam` observability from persisted silhouette settings
- [x] Correct blend, shake, and soft-zone architecture to match repo reality
- [x] Align file paths and naming with the current style guide
- [x] Make mobile drag-look a hard requirement for rotatable orbit and first-person support
- [x] Complete the `state.camera` to `state.vcam` migration in runtime/tests and retire legacy references
- [x] Enumerate the missing keyboard-look touchpoints: InputMap bootstrap, tests, rebinding UI/category wiring, localization, and settings-save triggers
- [x] Specify the gameplay `SubViewport` / `World3D` and same-frame handoff contracts explicitly
- [x] Standardize silhouette ownership as detect in vCam, render in VFX, with `{entity_id, occluders, enabled}` payload

---

## Links

- [Plan](vcam-manager-plan.md)
- [Overview](vcam-manager-overview.md)
- [PRD](vcam-manager-prd.md)
- [Continuation Prompt](vcam-manager-continuation-prompt.md)
