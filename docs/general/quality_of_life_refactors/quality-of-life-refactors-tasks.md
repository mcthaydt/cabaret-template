# Quality of Life Refactors Tasks (TDD-First)

## Overview

This document defines a decision-complete, TDD-first roadmap for quality-of-life interaction and HUD feedback improvements.

This initiative focuses on three UX outcomes:
- Functional feedback split:
  - Autosave feedback uses a top-center spinner.
  - Checkpoint feedback uses a dedicated checkpoint toast.
  - Signpost feedback uses a dedicated signpost message panel.
- Hybrid interaction discoverability:
  - Keep existing HUD key/button prompt.
  - Add a world-space 3D interact icon for in-range interactables.
- Signpost readability:
  - Signpost panel auto-hides after a configurable delay.

**Status**: Not Started  
**Current Phase**: Phase 0 (Ready)  
**Task ID Range**: QOL-T001-QOL-T065  
**Primary Tasks File**: `docs/general/quality_of_life_refactors/quality-of-life-refactors-tasks.md`  
**Continuation Prompt File**: `docs/general/quality_of_life_refactors/quality-of-life-refactors-continuation-prompt.md` (required per phase)

---

## Scope

### In Scope

- HUD feedback channel separation in:
  - `scripts/ui/hud/ui_hud_controller.gd`
  - `scenes/ui/hud/ui_hud_overlay.tscn`
- Autosave feedback UX change:
  - Replace autosave toast behavior with top-center spinner behavior.
- Checkpoint feedback UX refinement:
  - Keep checkpoint feedback separate from signpost/autosave pathways.
  - Avoid default player-facing raw checkpoint IDs.
- Signpost feedback redesign:
  - Add dedicated signpost panel with auto-hide behavior.
  - Add signpost duration config support.
- Interaction discoverability improvements:
  - Add world-space 3D interact icon support for interact-mode controllers.
  - Preserve existing HUD prompt behavior and event contracts.
- Interaction config schema updates:
  - Add `message_duration_sec` to signpost config resource.
  - Add interaction hint fields to base interaction config resource.
- Tests:
  - Add/update unit/integration tests for split channels, blocker behavior, signpost duration, and hybrid cues.

### Out of Scope

- Save format/version changes.
- Scene manager transition architecture changes.
- ECS event renaming or payload contract breaks.
- Full UI style system rewrite unrelated to this QoL scope.

---

## Goals / Non-Goals

### Goals

- Improve player clarity by separating unrelated HUD feedback.
- Prevent autosave feedback from blocking interaction flow.
- Improve readability of signpost messages with dedicated presentation and timing.
- Improve interactable discoverability with additive world-space cues.
- Preserve established interaction input clarity and accessibility by keeping HUD prompts.

### Non-Goals

- Removing existing HUD prompt flows.
- Replacing the interaction event bus contract.
- Broad refactor of non-interaction HUD widgets.

---

## Constraints and Guardrails

- TDD is mandatory per phase: RED tests first, then GREEN implementation, then REFACTOR cleanup.
- Existing event names and payload expectations must remain backward-compatible:
  - `interact_prompt_show`
  - `interact_prompt_hide`
  - `signpost_message`
  - `save_started`
  - `save_completed`
  - `save_failed`
  - `checkpoint_activated`
- Event payloads may be extended additively when required by this initiative, but existing keys/semantics must remain valid for current subscribers.
- Use naming conventions from `docs/general/STYLE_GUIDE.md`:
  - Resource scripts: `rs_*`
  - Resource instances: `cfg_*`
  - UI scripts/scenes: existing `ui_*` conventions
- Keep tabs in `.gd` files and preserve style checks.
- Any scene/resource structure changes must run style enforcement:
  - `tests/unit/style/test_style_enforcement.gd`
- Keep docs commits separate from implementation commits.
- After each phase completion:
  - Update this tasks file status.
  - Update continuation prompt file.
  - Update `AGENTS.md` / `docs/general/DEV_PITFALLS.md` when new patterns/pitfalls are discovered.

---

## Architecture Decisions

### Functional Feedback Split

- HUD feedback is split into separate channels by function:
  - Autosave channel: spinner only.
  - Checkpoint channel: checkpoint toast only.
  - Signpost channel: signpost panel only.
- Channels must not reuse one shared text label path for all events.

### Interaction Prompt Strategy

- Hybrid strategy is authoritative:
  - Keep current HUD prompt (`UI_ButtonPrompt`) for explicit key/button instruction.
  - Add world-space 3D icon cue for interactable proximity/discoverability.
- 3D icon is additive and never replaces HUD input guidance.

### Signpost Auto-Hide Policy

- Signpost panel auto-hides by default.
- New signpost config field `message_duration_sec` controls duration (default `3.0`).
- Auto-hide timing must be pause-safe and transition-safe.

### Blocker Policy

- Autosave spinner does not call `U_InteractBlocker.block()`.
- Signpost panel and checkpoint toast may use controlled blocker behavior to avoid spam/overlap.
- Overlap rules must keep prompt restoration deterministic.

### Event Payload Extension Policy (Additive-Only)

- `save_completed` and `save_failed` must include `is_autosave` additively so autosave spinner hide logic can remain contract-safe and deterministic.
- `signpost_message` may include `message_duration_sec` additively so HUD can apply per-signpost timing from config.
- Existing subscribers expecting current payload keys must continue to function without modification.

---

## Assumptions and Defaults

- Signpost message auto-hide default is `3.0s`.
- Autosave feedback is spinner-first and does not reuse toast text pipeline.
- Existing event names remain stable; behavior changes are subscriber-side and HUD layout-side.
- World-space icon support is config-driven and opt-in by interaction authoring.
- Documentation quality should mirror `docs/general/interactions_refactor/*`.

---

## Planned Public API / Interface Changes

- `scripts/ui/hud/ui_hud_controller.gd`:
  - Add dedicated handling paths for checkpoint toast, signpost panel, and autosave spinner.
- `scenes/ui/hud/ui_hud_overlay.tscn`:
  - Add dedicated nodes for autosave spinner and signpost panel while preserving checkpoint toast node(s).
- `scripts/resources/interactions/rs_signpost_interaction_config.gd`:
  - Add `@export var message_duration_sec: float = 3.0` (clamped/min-safe in usage).
- `scripts/resources/interactions/rs_interaction_config.gd`:
  - Add interaction-hint fields for world-space icon behavior (opt-in).
- Additive event payload extensions (no event name changes):
  - `save_completed`: include `is_autosave`.
  - `save_failed`: include `is_autosave`.
  - `signpost_message`: include `message_duration_sec` (optional/additive).

No event contract break is planned.

---

## Phase Table

| Phase | Name | Task IDs | Risk | Status |
|---|---|---|---|---|
| 0 | Baseline and Invariants | QOL-T001-QOL-T004 | Low | Not Started |
| 1 | HUD Channel Split Scaffolding | QOL-T010-QOL-T014 | Medium | Not Started |
| 2 | Autosave Spinner | QOL-T020-QOL-T025 | Medium | Not Started |
| 3 | Checkpoint Toast Redesign | QOL-T030-QOL-T034 | Medium | Not Started |
| 4 | Signpost Panel + Duration | QOL-T040-QOL-T046 | Medium | Not Started |
| 5 | 3D Interact Icon + HUD Hybrid | QOL-T050-QOL-T057 | High | Not Started |
| 6 | Regression + Polish + Closure | QOL-T060-QOL-T065 | Medium | Not Started |

---

## TDD Task Backlog

## Phase 0 - Baseline and Invariants

**Goal**: Lock current behavior and capture baseline invariants before functional split work.

- [ ] **QOL-T001** Run baseline suites:
  - `res://tests/unit/ui`
  - `res://tests/unit/interactables`
  - `res://tests/unit/save`
  - `res://tests/integration/save_manager`
  - `res://tests/unit/style`
- [ ] **QOL-T002** Record current coupling invariants:
  - Checkpoint, signpost, and autosave currently route through shared toast behavior.
  - Interact prompt suppression/restoration behavior during toasts.
  - `U_InteractBlocker` usage during toast lifecycle.
- [ ] **QOL-T003** Record no-event-contract-break rule and payload compatibility constraints.
- [ ] **QOL-T004** Record pause/overlay/transition suppression invariants for current HUD feedback.

### Phase 0 Exit Criteria

- Baseline suite results recorded in this file.
- Invariants documented and treated as regression guardrails for Phases 1-2.

---

## Phase 1 - HUD Channel Split Scaffolding

**Goal**: Separate presentation channels in HUD scene/controller while preserving behavior.

- [ ] **QOL-T010** Add RED tests covering independent node/channel visibility state.
- [ ] **QOL-T011** Add separate HUD nodes for:
  - Autosave spinner (top-center)
  - Checkpoint toast
  - Signpost message panel
- [ ] **QOL-T012** Refactor HUD controller internals into channel-specific show/hide helpers.
- [ ] **QOL-T013** Maintain baseline-visible behavior until Phase 2+ switches routing logic.
- [ ] **QOL-T014** GREEN tests for channel separation scaffolding.

### Phase 1 Exit Criteria

- Scene/controller supports independent channels.
- Existing feedback still appears as before (no functional regressions yet).

---

## Phase 2 - Autosave Spinner

**Goal**: Move autosave feedback to spinner-only behavior.

- [ ] **QOL-T020** Add RED tests:
  - Autosave `save_started` shows spinner.
  - Autosave `save_completed` / `save_failed` hides spinner.
  - Autosave does not invoke checkpoint/signpost channels.
- [ ] **QOL-T021** Route autosave events to spinner channel only.
- [ ] **QOL-T022** Extend save completion/failure payloads additively:
  - `save_completed` includes `is_autosave`.
  - `save_failed` includes `is_autosave`.
  - Keep existing payload keys unchanged.
- [ ] **QOL-T023** Ensure autosave spinner does not call interaction blocker APIs.
- [ ] **QOL-T024** Ensure manual save/load overlay behavior remains unchanged.
- [ ] **QOL-T025** GREEN tests for autosave spinner lifecycle and non-blocking behavior.

### Phase 2 Exit Criteria

- Autosave feedback is spinner-only and non-blocking.
- Checkpoint/signpost channels unaffected by autosave events.
- `save_completed`/`save_failed` payload compatibility preserved with additive `is_autosave`.

---

## Phase 3 - Checkpoint Toast Redesign

**Goal**: Keep checkpoint feedback separate and improve default player-facing text.

- [ ] **QOL-T030** Add RED tests for checkpoint-only toast behavior and text fallback.
- [ ] **QOL-T031** Isolate checkpoint toast rendering from signpost/autosave paths.
- [ ] **QOL-T032** Replace default raw checkpoint ID output with player-facing fallback copy.
- [ ] **QOL-T033** Preserve checkpoint toast timing and prompt restoration behavior unless explicitly changed.
- [ ] **QOL-T034** GREEN tests for checkpoint-only channel and copy behavior.

### Phase 3 Exit Criteria

- Checkpoint feedback channel is independent and readable.
- No coupling regressions with signpost/autosave presentation.

---

## Phase 4 - Signpost Panel + Duration

**Goal**: Add dedicated signpost panel with config-driven auto-hide timing.

- [ ] **QOL-T040** Add RED tests for signpost panel lifecycle:
  - show
  - auto-hide by duration
  - pause suppression
  - prompt restoration
- [ ] **QOL-T041** Add `message_duration_sec` to `RS_SignpostInteractionConfig` with default `3.0`.
- [ ] **QOL-T042** Update signpost config validator coverage and defaults where needed.
- [ ] **QOL-T043** Publish signpost duration additively on `signpost_message` payload (`message_duration_sec`) from config.
- [ ] **QOL-T044** Route `signpost_message` handling to dedicated signpost panel channel and consume payload duration (fallback to default when absent).
- [ ] **QOL-T045** Keep controlled blocker usage for signpost display (not autosave spinner).
- [ ] **QOL-T046** GREEN tests for signpost duration, suppression, and restoration.

### Phase 4 Exit Criteria

- Signpost feedback is panel-based and auto-hides by config duration.
- Pause/overlay behavior remains stable and test-covered.
- `signpost_message` remains backward-compatible with additive duration payload support.

---

## Phase 5 - 3D Interact Icon + HUD Hybrid

**Goal**: Add world-space interact icon cues while preserving existing HUD prompt behavior.

- [ ] **QOL-T050** Add RED tests for world icon visibility conditions:
  - in-range + interactable + unblocked
  - out-of-range
  - transition/overlay blocked
- [ ] **QOL-T051** Add interaction hint fields to `RS_InteractionConfig` (base, opt-in).
- [ ] **QOL-T052** Implement world-space icon support in interact-mode controller flow.
- [ ] **QOL-T053** Keep current `interact_prompt_show/hide` HUD prompt behavior unchanged.
- [ ] **QOL-T054** Ensure icon and HUD prompt can coexist without conflicting hide/show races.
- [ ] **QOL-T055** Add/author assets/resources for icon rendering if needed (prefix/style compliant).
- [ ] **QOL-T056** Update scene/prefab wiring for at least one door + one signpost reference flow.
- [ ] **QOL-T057** GREEN tests for hybrid cue behavior.

### Phase 5 Exit Criteria

- World icon appears/hides correctly under interaction conditions.
- HUD prompt remains present and correct by active device.
- Hybrid flow is regression-safe.

---

## Phase 6 - Regression + Polish + Closure

**Goal**: Verify stability, close documentation, and prepare merge-ready state.

- [ ] **QOL-T060** Run targeted regression gates:
  - `res://tests/unit/ui`
  - `res://tests/unit/interactables`
  - `res://tests/unit/save`
  - `res://tests/integration/save_manager`
  - `res://tests/unit/style`
- [ ] **QOL-T061** Run additional impacted suites if failures or cross-domain regressions appear.
- [ ] **QOL-T062** Confirm no event contract regressions in call sites and tests.
- [ ] **QOL-T063** Final UX polish pass for channel timings/layout overlap edge cases.
- [ ] **QOL-T064** Update this tasks file with completion notes and final suite results.
- [ ] **QOL-T065** Update continuation prompt, and update `AGENTS.md` / `DEV_PITFALLS.md` if new patterns/pitfalls were discovered.

### Phase 6 Exit Criteria

- All required suites green (or clearly documented expected pending/risky tests).
- Documentation synchronized and initiative marked complete.

---

## Test Plan and Run Commands

Use `tools/run_gut_suite.sh` with recursive inclusion:

- `tools/run_gut_suite.sh -gdir=res://tests/unit/ui -ginclude_subdirs=true -gexit`
- `tools/run_gut_suite.sh -gdir=res://tests/unit/interactables -ginclude_subdirs=true -gexit`
- `tools/run_gut_suite.sh -gdir=res://tests/unit/save -ginclude_subdirs=true -gexit`
- `tools/run_gut_suite.sh -gdir=res://tests/integration/save_manager -ginclude_subdirs=true -gexit`
- `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true -gexit`

If scene/resource structure changes are made, style suite is mandatory before phase completion.

---

## Test Cases and Scenarios (Acceptance Matrix)

1. HUD feedback separation:
  - Autosave spinner does not trigger checkpoint/signpost channels.
  - Checkpoint and signpost channels do not collide.

2. Blocker behavior:
  - Autosave spinner never blocks interaction.
  - Signpost display still prevents immediate interaction spam while visible.

3. Signpost panel:
  - Auto-hides using configured duration.
  - Suppressed while paused/overlays active.
  - Restores prompt state correctly when still in range.

4. Hybrid interact cues:
  - 3D icon appears in range and hides on exit.
  - HUD prompt still shows correct glyph/text per device.
  - Transition/overlay blocked states suppress both cues.

5. Save events:
  - `is_autosave=true` drives spinner lifecycle for started/completed/failed save events.
  - Autosave fail hides spinner and surfaces failure feedback non-blockingly.

6. Regression gates:
  - UI, interactables, save, integration/save_manager, and style suites pass.

---

## Documentation and Continuation Requirements (Per Phase)

At completion of each phase:

1. Update this tasks file:
  - Mark completed tasks `[x]`.
  - Add completion notes with:
    - Date
    - Tests run
    - Commit hash(es)
    - Any deviations
2. Update continuation prompt:
  - `docs/general/quality_of_life_refactors/quality-of-life-refactors-continuation-prompt.md`
3. Update `AGENTS.md` if new architecture/patterns become project standards.
4. Update `docs/general/DEV_PITFALLS.md` if new pitfalls are discovered.
5. Commit docs updates separately from implementation updates.
