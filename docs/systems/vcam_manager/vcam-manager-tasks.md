# vCam Manager — Task Index

**Progress:** 5 / 5 documentation tasks complete; Phases 0A + 0A2 + 0B + 0C + 0D + 0E + 0F + 1A + 1B + 1C + 1D + 1E + 1F + 2A + 2B + 4A + 4B + 5 + 6A + 6B + 6A2 + 6A.3 + 6A3a + 6A3b + 6A3c + 2C1 + 2C2 + 2C3 + 2C4 + 2C5 + 2C6 + 2C7 + 2C8 + 2C9 + 2C10 + 2C11 + Orbit UX improvement follow-up pass + Movement-Style Camera Smoothing follow-up pass + Camera Look Smoothing Parity pass + mobile drag-look/touch gating prerequisites (Phase 7A/7B/7B2/7C) + full OTS Phase 3 reset (3A/3B/3C1/3C2/3C3/3C4.1-3C4.11) + Phase 9F manual blend validation + Phase 10A collision-detector Red/Green groundwork (`10A.1`/`10A.2`) + Phase 10B silhouette-helper Red/Green foundation (`10B.1`/`10B.2`) + Phase 10B2 silhouette routing (`10B2.1-10B2.4`) + Phase 10C per-tick occlusion integration (`10C.1`/`10C.2`) + Phase 10C2 anti-flicker/stability pass (`10C2.1`/`10C2.2`) + Phase 10D manual occlusion/silhouette validation + Phase 11 editor preview (`11.1`/`11.2`/`11.3`) + Phase 11A manual editor-preview validation + Phase 12 integration tests (`12.1`-`12.6`) + Phase 12A observability validation (`MT-40/41/42/47/48/49`) + full Phase 13 regression/docs closure (`13.1`-`13.8`) complete.
**Estimated Test Count:** ~440 checks (about 360 automated tests + 80 manual checks including game-feel QA)
**Status note:** Strict TDD (Red/Green/Refactor). Each camera mode has a dedicated phase. Mobile drag-look is a hard prerequisite for orbit/OTS completion.
**Manual QA cadence:** Manual checks are embedded in the relevant implementation phases (no standalone manual-testing phase).
**Quality gaps addressed:** Orientation continuity, blend interruption, invalid-target recovery, occlusion anti-flicker, performance budget, observability expansion, open-question resolution, cross-mode feel QA, **second-order dynamics for natural camera motion**, **ECS event bus integration**, **QB rule context enrichment**, **entity-based target resolution**, **mode-specific game feel (orbit: look-ahead/auto-level/soft zone/hysteresis + ground-relative positioning + release smoothing + button recenter + room-fade data layer/logic; OTS: collision avoidance/shoulder sway/landing camera response)**.
**Previous completion note (March 15, 2026):** Mobile drag-look/touch gating prerequisites landed: `UI_MobileControls` now emits drag-look deltas + active lifecycle, `S_TouchscreenSystem` dispatches touchscreen look input and `gameplay.touch_look_active`, gameplay state marks `touch_look_active` transient, and `S_InputSystem` now hard-gates touchscreen-owned ticks to prevent zero clobber. Validation gates are green across touch/input/state/vCam suites (including `test_mobile_controls` `14/14`, `test_s_touchscreen_system` `7/7`, `test_input_system` `13/13`, `test_vcam_system` `94/94`), with style enforcement unchanged at known pre-existing HUD inline-theme debt (`16/17`).
**Latest planning note (March 15, 2026):** Phase 3 reset completion landed — OTS 3C4 full scope now includes reticle UI (`UI_HudController` + `ui_hud_overlay.tscn`) and default movement preset (`cfg_ots_movement_default.tres` wired into `cfg_default_ots.tres`) in addition to slice 1 aim activation/input/movement/rotation integrations.
**Latest completion note (March 22, 2026):** Phase 13 is fully closed. Phase 12A observability validation remains closed (`MT-40/41/42/47/48/49`) with integration evidence (`tests/integration/vcam/test_vcam_state.gd` `9/9`, `test_vcam_occlusion.gd` `2/2`), automated Phase 13 gates are green (`13.1/13.2/13.3/13.4/13.8`), and manual QA tasks (`13.5/13.6/13.6b/13.7`) are marked complete per manual QA sign-off request.

---

## Subtask Files

| File | Scope | Phases |
|------|-------|--------|
| [vcam-base-tasks.md](vcam-base-tasks.md) | Shared infrastructure: state/persistence, **ECS event bus constants**, base resources, **second-order dynamics**, response tuning, component/interface/manager, ECS system, scene wiring, mobile drag-look, blend, **QB rule context enrichment**, **shared game feel (FOV breathing, landing impact)**, occlusion, editor preview, integration tests, regression/docs | 0, 1, 5, 6, 7, 8, 9, 10, 11, 12, 13 |
| [vcam-orbit-tasks.md](vcam-orbit-tasks.md) | Orbit camera mode: resource, evaluator, default preset, then later **orbit game feel (look-ahead, auto-level, soft zone, hysteresis)** plus follow-up backlog (**ground-relative positioning, release smoothing, button recenter, room-fade data layer/logics**) after base Phase 6A2 | 2, 8 |
| [vcam-ots-tasks.md](vcam-ots-tasks.md) | OTS camera mode: resource, evaluator, then later **OTS game feel (collision avoidance, shoulder sway, landing camera response)** after base Phase 6A2 | 3, 9 |
| [vcam-fixed-tasks.md](vcam-fixed-tasks.md) | Fixed camera mode: resource, evaluator, final evaluator refactor, manual checks | 4 |

---

## Phase Execution Order

| Task Phase | File | Description | Plan Sections |
|------------|------|-------------|--------------|
| 0 | Base | State and Persistence | 0.0 – 0.4 |
| 1 | Base | Base Authoring Resources (Soft Zone + Blend Hint + second-order utilities + response resource) | 1.1 (partial) |
| 2 | Orbit | Orbit resource, evaluator branch, and default preset | Phase 2A–2B |
| 3 | OTS | OTS resource, evaluator branch, and default preset | Phase 3A–3B |
| 4 | Fixed | Fixed Camera Mode (extends evaluator, final refactor) | 1.1 (partial), 2.3 (partial) |
| 5 | Base | Component, Interface, and Manager Core | 1.2, 2.1, 2.2 |
| 6 | Base | vCam System, scene wiring, and mobile drag-look/touch gating | 2.4, 2.4a, 2.5 |
| 7 | Base | Shared response and same-frame smoothing in `S_VCamSystem` | 1F, 6A2 |
| 8 | Orbit | Orbit game feel core + follow-up backlog (look-ahead, auto-level, soft zone, hysteresis, ground-relative positioning, release smoothing, button recenter, room-fade data layer/logics) | Phase 2C (`2C1-2C11`) |
| 9 | OTS | OTS game feel (collision avoidance, shoulder sway, landing camera response) | Phase 3C |
| 10 | Base | QB-Driven Camera Feel | 6A3 (within base-tasks) |
| 11 | Base | Live Blend Evaluation and Camera-Manager Integration | 4.1, 4.2, 4.3 |
| 12 | Base | Occlusion and Silhouette | 5.1, 5.1a, 5.2, 5.3 |
| 13 | Base | Editor Preview | 6.1 |
| 14 | Base | Integration Tests | 7.1 |
| 15 | Base | Regression Coverage and Docs | 7.2, 7.3 |

> **Note:** "Plan Sections" references `vcam-manager-plan.md` section/commit labels, which do not map 1:1 to task phases.
> **Execution order rationale:** Orbit and OTS resource/evaluator work can start before base feel integration, but orbit Phase 2C and OTS Phase 3C stay blocked on base Phase 6A2. This index now treats those feel passes as later phases instead of implying Phases 2 and 3 are fully executable end-to-end up front.

---

## Documentation Alignment (Complete)

- [x] Align runtime wiring with actual root and gameplay scene structure
- [x] Split transient `vcam` observability from persisted silhouette settings
- [x] Correct blend, shake, and soft-zone architecture to match repo reality
- [x] Align file paths and naming with the current style guide
- [x] Make mobile drag-look a hard requirement for rotatable orbit and OTS support
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
