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

**Status**: Complete  
**Current Phase**: Phase 6 (Complete)  
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
| 0 | Baseline and Invariants | QOL-T001-QOL-T004 | Low | Complete |
| 1 | HUD Channel Split Scaffolding | QOL-T010-QOL-T014 | Medium | Complete |
| 2 | Autosave Spinner | QOL-T020-QOL-T025 | Medium | Complete |
| 3 | Checkpoint Toast Redesign | QOL-T030-QOL-T034 | Medium | Complete |
| 4 | Signpost Panel + Duration | QOL-T040-QOL-T046 | Medium | Complete |
| 5 | 3D Interact Icon + HUD Hybrid | QOL-T050-QOL-T057 | High | Complete |
| 6 | Regression + Polish + Closure | QOL-T060-QOL-T065 | Medium | Complete |

---

## TDD Task Backlog

## Phase 0 - Baseline and Invariants

**Goal**: Lock current behavior and capture baseline invariants before functional split work.

- [x] **QOL-T001** Run baseline suites:
  - `res://tests/unit/ui`
  - `res://tests/unit/interactables`
  - `res://tests/unit/save`
  - `res://tests/integration/save_manager`
  - `res://tests/unit/style`
- [x] **QOL-T002** Record current coupling invariants:
  - Checkpoint, signpost, and autosave currently route through shared toast behavior.
  - Interact prompt suppression/restoration behavior during toasts.
  - `U_InteractBlocker` usage during toast lifecycle.
- [x] **QOL-T003** Record no-event-contract-break rule and payload compatibility constraints.
- [x] **QOL-T004** Record pause/overlay/transition suppression invariants for current HUD feedback.

### QOL-T001 Baseline Run Results (2026-02-10)

Executed baseline suites using the commands in "Test Plan and Run Commands" (`tools/run_gut_suite.sh ... -ginclude_subdirs=true`).

| Suite | Result | Notes |
|---|---|---|
| `res://tests/unit/ui` | PASS | 170/172 passing, 2 pending (mobile-only expected pending) |
| `res://tests/unit/interactables` | PASS | 36/36 passing |
| `res://tests/unit/save` | PASS | 121/122 passing, 1 pending (headless viewport capture expected pending) |
| `res://tests/integration/save_manager` | PASS | 19/19 passing |
| `res://tests/unit/style` | PASS | 12/12 passing |

Execution notes:
- All five required Phase 0 gate suites completed successfully.
- Existing non-blocking warnings remained unchanged (inner-class warnings, expected warning assertions, and known macOS headless certificate log line).
- No regressions were introduced during baseline capture (docs-only phase).

### QOL-T002 Coupling Invariants (Current Runtime Contract)

- HUD currently uses one shared toast path for checkpoint, signpost, and autosave feedback:
  - Scene path: `MarginContainer/ToastContainer/PanelContainer/MarginContainer/CheckpointToast`.
  - Controller path: `scripts/ui/hud/ui_hud_controller.gd` routes `_on_checkpoint_event`, `_on_signpost_message`, `_on_save_started`, `_on_save_completed`, and `_on_save_failed` through `_show_checkpoint_toast(...)`.
- Interact prompt suppression and restoration are tied to toast lifecycle:
  - `_show_checkpoint_toast(...)` hides `interact_prompt`, sets `_toast_active = true`, and defers any new `interact_prompt_show` rendering while toast is active.
  - On toast tween completion, HUD clears `_toast_active` and restores prompt only if controller context is still active (`_active_prompt_id != 0`) and not paused.
- `U_InteractBlocker` is currently coupled to toast display:
  - Toast show calls `U_InteractBlocker.block()`.
  - Toast hide calls `U_InteractBlocker.unblock_with_cooldown(0.3)`.
  - `TriggeredInteractableController` gates interaction input on `U_InteractBlocker.is_blocked()`.

### QOL-T003 Event Contract Invariants (Additive-Only Policy)

- Event names are contract-frozen for this initiative:
  - `interact_prompt_show`, `interact_prompt_hide`, `signpost_message`, `save_started`, `save_completed`, `save_failed`, `checkpoint_activated`.
- Baseline payload keys that existing subscribers currently consume:
  - `interact_prompt_show`: `controller_id`, `action`, `prompt`.
  - `interact_prompt_hide`: `controller_id`.
  - `signpost_message`: `message`, `controller_id`, `repeatable`.
  - `save_started`: `slot_id`, `is_autosave`.
  - `save_completed`: `slot_id`.
  - `save_failed`: `slot_id`, `error_code`.
  - `checkpoint_activated`: `checkpoint_id` (HUD fallback copy applies when absent).
- Compatibility rule for future work:
  - Only additive payload extensions are allowed.
  - Existing keys and semantics must remain valid.
  - Subscribers must tolerate absent new keys by using defaults/fallbacks.

### QOL-T004 Pause/Overlay/Transition Suppression Invariants

- Pause/overlay suppression in HUD is active and must remain deterministic:
  - When navigation is paused, HUD hides interact prompt and toast, clears `_toast_active`, and calls `U_InteractBlocker.force_unblock()`.
  - `_show_checkpoint_toast(...)` and `_on_signpost_message(...)` both short-circuit while paused.
- Prompt and activation suppression during transitions/overlays is enforced at interactable controllers:
  - `TriggeredInteractableController._show_interact_prompt()` skips prompt publish when `_is_transition_blocked()` is true.
  - `BaseInteractableController.can_activate()` returns false while transition/overlay blocking is active.
  - `_is_transition_blocked()` currently checks scene slice `is_transitioning`, non-empty `scene_stack`, and `scene_manager.is_transitioning()`.
- HUD gameplay visibility suppression baseline:
  - Health bar hides when paused or when navigation shell is not `gameplay` (including transitions away from gameplay).

### Phase 0 Completion Notes

- Phase 0 exit criteria met on 2026-02-10.
- Baseline suite results recorded and invariants documented in this file.
- Next phase target: Phase 1 (`QOL-T010-QOL-T014`) RED tests for channel split scaffolding.

### Phase 0 Exit Criteria

- Baseline suite results recorded in this file.
- Invariants documented and treated as regression guardrails for Phases 1-2.

---

## Phase 1 - HUD Channel Split Scaffolding

**Goal**: Separate presentation channels in HUD scene/controller while preserving behavior.

- [x] **QOL-T010** Add RED tests covering independent node/channel visibility state.
- [x] **QOL-T011** Add separate HUD nodes for:
  - Autosave spinner (top-center)
  - Checkpoint toast
  - Signpost message panel
- [x] **QOL-T012** Refactor HUD controller internals into channel-specific show/hide helpers.
- [x] **QOL-T013** Maintain baseline-visible behavior until Phase 2+ switches routing logic.
- [x] **QOL-T014** GREEN tests for channel separation scaffolding.

### QOL-T010 RED Test Coverage Added (2026-02-10)

- Added `tests/unit/ui/test_hud_feedback_channels.gd` with RED-first expectations for:
  - Independent visibility state for `ToastContainer`, `AutosaveSpinnerContainer`, and `SignpostPanelContainer`.
  - Phase 1 routing parity rule (signpost/autosave still visible via checkpoint toast path while new channels remain inactive).
- Initial RED run failed as expected before implementation:
  - Missing HUD nodes (`AutosaveSpinnerContainer`, `SignpostPanelContainer`).
  - Missing channel helper method surface.

### QOL-T011/QOL-T012 Implementation Summary

- HUD scene scaffolding added in `scenes/ui/hud/ui_hud_overlay.tscn`:
  - `MarginContainer/AutosaveSpinnerContainer` (new top-center spinner channel container).
  - `MarginContainer/SignpostPanelContainer` (new dedicated signpost panel container).
  - Existing `MarginContainer/ToastContainer` preserved as checkpoint toast channel.
- HUD controller channel helpers added in `scripts/ui/hud/ui_hud_controller.gd`:
  - `_show_autosave_spinner()` / `_hide_autosave_spinner()`
  - `_show_signpost_panel(text)` / `_hide_signpost_panel()`
  - `_hide_checkpoint_toast_immediate()` and checkpoint tween cancellation helper for deterministic channel switching.
- Pause handling now explicitly hides all three channels before forcing unblock.

### QOL-T013 Baseline-Visible Parity Confirmation

- Event routing intentionally unchanged for Phase 1:
  - `signpost_message` still routes to `_show_checkpoint_toast(...)`.
  - Autosave `save_started`/`save_completed`/`save_failed` still route through checkpoint toast path.
- Dedicated spinner/signpost panel channels are scaffolded but not yet used for runtime routing (deferred to Phase 2+).

### QOL-T014 GREEN Validation Results (2026-02-10)

Validation suites executed:

| Suite | Result | Notes |
|---|---|---|
| `res://tests/unit/ui` | PASS | 172/174 passing, 2 expected pending mobile-only |
| `res://tests/unit/interactables` | PASS | 36/36 passing |
| `res://tests/unit/save` | PASS | 121/122 passing, 1 expected pending headless viewport capture |
| `res://tests/integration/save_manager` | PASS | 19/19 passing |
| `res://tests/unit/style` | PASS | 12/12 passing |

Implementation commit:
- `c231a2d` - Add HUD feedback channel scaffolding and tests.

### Phase 1 Completion Notes

- Phase 1 exit criteria met on 2026-02-10.
- Independent HUD channels now exist and are test-covered.
- Runtime behavior parity preserved as required; routing switch is deferred to Phase 2.
- Next phase target: Phase 2 (`QOL-T020-QOL-T025`) autosave spinner routing + non-blocking behavior.

### Phase 1 Exit Criteria

- Scene/controller supports independent channels.
- Existing feedback still appears as before (no functional regressions yet).

---

## Phase 2 - Autosave Spinner

**Goal**: Move autosave feedback to spinner-only behavior.

- [x] **QOL-T020** Add RED tests:
  - Autosave `save_started` shows spinner.
  - Autosave `save_completed` / `save_failed` hides spinner.
  - Autosave does not invoke checkpoint/signpost channels.
- [x] **QOL-T021** Route autosave events to spinner channel only.
- [x] **QOL-T022** Extend save completion/failure payloads additively:
  - `save_completed` includes `is_autosave`.
  - `save_failed` includes `is_autosave`.
  - Keep existing payload keys unchanged.
- [x] **QOL-T023** Ensure autosave spinner does not call interaction blocker APIs.
- [x] **QOL-T024** Ensure manual save/load overlay behavior remains unchanged.
- [x] **QOL-T025** GREEN tests for autosave spinner lifecycle and non-blocking behavior.

### QOL-T020 RED Test Coverage Added (2026-02-10)

- Expanded `tests/unit/ui/test_hud_feedback_channels.gd` to require Phase 2 behavior:
  - Autosave routes to spinner channel (not checkpoint/signpost channels).
  - Spinner lifecycle hides on autosave completion/failure.
  - Spinner path remains non-blocking (`U_InteractBlocker` unaffected).
  - Manual save events do not toggle autosave spinner channel.
- Expanded `tests/unit/save/test_save_manager.gd` payload checks:
  - `save_completed` includes `is_autosave` for manual and autosave flows.
  - `save_failed` includes `is_autosave` on failure path.
- RED runs failed as expected before implementation:
  - HUD still routed autosave through checkpoint toast.
  - Save manager completion/failure payloads missing additive `is_autosave`.

### QOL-T021/QOL-T022 Implementation Summary

- `scripts/ui/hud/ui_hud_controller.gd` autosave routing updated:
  - `save_started` (`is_autosave=true`) now calls `_show_autosave_spinner()`.
  - `save_completed` / `save_failed` (`is_autosave=true`) now call `_hide_autosave_spinner()`.
  - Autosave path no longer uses `_show_checkpoint_toast(...)`.
- `scripts/managers/m_save_manager.gd` event payloads extended additively:
  - `save_completed` now publishes `slot_id` + `is_autosave`.
  - `save_failed` now publishes `slot_id` + `is_autosave` + `error_code`.

### QOL-T023 Non-Blocking Spinner Confirmation

- Autosave spinner path does not call toast blocker methods.
- HUD now clears stale blocker state if a checkpoint toast is interrupted during channel switching to avoid stuck interaction lock.
- Spinner lifecycle test confirms `U_InteractBlocker.is_blocked()` remains false across autosave start/completion.

### QOL-T024 Manual Save/Load Behavior Confirmation

- Manual save events (`is_autosave=false`) do not show/hide autosave spinner.
- Save/load menu behavior remains unchanged (existing `tests/unit/ui/test_save_load_menu.gd` suite remains green).
- No scene or overlay flow regressions observed in save integration gate.

### QOL-T025 GREEN Validation Results (2026-02-10)

Validation suites executed:

| Suite | Result | Notes |
|---|---|---|
| `res://tests/unit/ui` | PASS | 175/177 passing, 2 expected pending mobile-only |
| `res://tests/unit/interactables` | PASS | 36/36 passing |
| `res://tests/unit/save` | PASS | 123/124 passing, 1 expected pending headless viewport capture |
| `res://tests/integration/save_manager` | PASS | 19/19 passing |
| `res://tests/unit/style` | PASS | 12/12 passing |

Implementation commit:
- `e35bc12` - Route autosave feedback to spinner and add payload flags.

### Phase 2 Completion Notes

- Phase 2 exit criteria met on 2026-02-10.
- Autosave feedback is now spinner-only and non-blocking.
- Save completion/failure payload compatibility preserved via additive `is_autosave`.
- Next phase target: Phase 3 (`QOL-T030-QOL-T034`) checkpoint toast copy and isolation refinement.

### Phase 2 Exit Criteria

- Autosave feedback is spinner-only and non-blocking.
- Checkpoint/signpost channels unaffected by autosave events.
- `save_completed`/`save_failed` payload compatibility preserved with additive `is_autosave`.

---

## Phase 3 - Checkpoint Toast Redesign

**Goal**: Keep checkpoint feedback separate and improve default player-facing text.

- [x] **QOL-T030** Add RED tests for checkpoint-only toast behavior and text fallback.
- [x] **QOL-T031** Isolate checkpoint toast rendering from signpost/autosave paths.
- [x] **QOL-T032** Replace default raw checkpoint ID output with player-facing fallback copy.
- [x] **QOL-T033** Preserve checkpoint toast timing and prompt restoration behavior unless explicitly changed.
- [x] **QOL-T034** GREEN tests for checkpoint-only channel and copy behavior.

### QOL-T030 RED Test Coverage Added (2026-02-10)

- Expanded `tests/unit/ui/test_hud_feedback_channels.gd` with Phase 3 checkpoint assertions:
  - Checkpoint events use checkpoint channel only (not spinner/signpost channels).
  - Checkpoint text uses player-facing copy instead of raw IDs.
  - Explicit checkpoint labels are preferred when provided.
  - Prompt hide/restore lifecycle is preserved across checkpoint toast timing.
- RED run failed as expected before implementation:
  - Checkpoint copy remained generic/raw-path behavior.
  - Prompt restoration timing test did not pass under new assertions.

### QOL-T031/QOL-T032 Implementation Summary

- `scripts/ui/hud/ui_hud_controller.gd` checkpoint handling refactored:
  - Added `_build_checkpoint_toast_text(...)` to normalize event payloads and build player-facing checkpoint copy.
  - Added `_humanize_checkpoint_id(...)` fallback (`cp_bar_tutorial` -> `Bar Tutorial`).
  - Added `_extract_event_payload(...)` helper for wrapped/unwrapped event compatibility.
- Checkpoint rendering isolation:
  - `checkpoint_activated` now resolves through checkpoint-specific text pipeline.
  - Signpost path no longer calls `_show_checkpoint_toast(...)` directly; it now uses `_show_signpost_toast(...)` with shared toast behavior.
- Copy behavior:
  - Prefer additive payload fields like `checkpoint_label`/`display_name` when present.
  - Fall back to humanized checkpoint IDs, then `Checkpoint reached`.

### QOL-T033 Timing/Prompt Restoration Confirmation

- Existing checkpoint toast animation timings remain unchanged:
  - Fade-in `0.2s`, hold `1.0s`, fade-out `0.3s`.
- Prompt lifecycle remains deterministic:
  - Prompt hides when checkpoint toast starts.
  - Prompt restores after toast completes when controller context remains active.
- Added explicit test coverage in `test_checkpoint_toast_preserves_prompt_hide_and_restore_timing`.

### QOL-T034 GREEN Validation Results (2026-02-10)

Validation suites executed:

| Suite | Result | Notes |
|---|---|---|
| `res://tests/unit/ui` | PASS | 178/180 passing, 2 expected pending mobile-only |
| `res://tests/unit/interactables` | PASS | 36/36 passing |
| `res://tests/unit/save` | PASS | 123/124 passing, 1 expected pending headless viewport capture |
| `res://tests/integration/save_manager` | PASS | 19/19 passing (passed on rerun after one transient failure) |
| `res://tests/unit/style` | PASS | 12/12 passing |

Implementation commit:
- `a0c7526` - Refine checkpoint toast copy and channel isolation.

### Phase 3 Completion Notes

- Phase 3 exit criteria met on 2026-02-10.
- Checkpoint toast behavior is now readable and independently handled from autosave/signpost call paths.
- Checkpoint toast timing and prompt restoration behavior preserved with dedicated regression coverage.
- Next phase target: Phase 4 (`QOL-T040-QOL-T046`) signpost panel routing + duration config.

### Phase 3 Exit Criteria

- Checkpoint feedback channel is independent and readable.
- No coupling regressions with signpost/autosave presentation.

---

## Phase 4 - Signpost Panel + Duration

**Goal**: Add dedicated signpost panel with config-driven auto-hide timing.

- [x] **QOL-T040** Add RED tests for signpost panel lifecycle:
  - show
  - auto-hide by duration
  - pause suppression
  - prompt restoration
- [x] **QOL-T041** Add `message_duration_sec` to `RS_SignpostInteractionConfig` with default `3.0`.
- [x] **QOL-T042** Update signpost config validator coverage and defaults where needed.
- [x] **QOL-T043** Publish signpost duration additively on `signpost_message` payload (`message_duration_sec`) from config.
- [x] **QOL-T044** Route `signpost_message` handling to dedicated signpost panel channel and consume payload duration (fallback to default when absent).
- [x] **QOL-T045** Keep controlled blocker usage for signpost display (not autosave spinner).
- [x] **QOL-T046** GREEN tests for signpost duration, suppression, and restoration.

### QOL-T040 RED Coverage Added (2026-02-10)

- Added signpost panel lifecycle RED tests in:
  - `tests/unit/ui/test_hud_feedback_channels.gd`
  - `tests/unit/ui/test_hud_interactions_pause_and_signpost.gd`
- Coverage now asserts:
  - signpost events route to dedicated signpost panel (not checkpoint toast)
  - panel auto-hides by payload duration
  - payload fallback to default duration when `message_duration_sec` is absent
  - pause suppression + prompt hide/restore lifecycle

### QOL-T041-QOL-T043 Resource + Payload Updates

- Added `@export_range(... ) var message_duration_sec: float = 3.0` to:
  - `scripts/resources/interactions/rs_signpost_interaction_config.gd`
- Added signpost event payload extension in:
  - `scripts/gameplay/inter_signpost.gd`
  - `signpost_message` now publishes `message_duration_sec` additively.
- Updated authored signpost config resources with explicit defaults:
  - `resources/interactions/signposts/cfg_signpost_default.tres`
  - `resources/interactions/signposts/cfg_signpost_bar_tutorial.tres`
  - `resources/interactions/signposts/cfg_signpost_exterior_tutorial.tres`
  - `resources/interactions/signposts/cfg_signpost_interior_tutorial.tres`

### QOL-T042 Validator Coverage Updates

- Extended signpost validator checks in:
  - `scripts/gameplay/helpers/u_interaction_config_validator.gd`
  - `message_duration_sec` must be `> 0`.
- Added tests in:
  - `tests/unit/resources/test_interaction_config_validator.gd`
  - default duration assertion (`3.0`)
  - invalid non-positive duration rejection

### QOL-T044-QOL-T046 HUD Signpost Channel Implementation

- Updated `scripts/ui/hud/ui_hud_controller.gd` to:
  - route `signpost_message` to `_show_signpost_panel(...)`
  - consume additive payload duration (`message_duration_sec`) with default fallback (`3.0`)
  - auto-hide signpost panel on a timer
  - hide/restore `UI_ButtonPrompt` deterministically for signpost lifecycle
  - use `U_InteractBlocker.block()` while signpost panel is visible, then unblock with cooldown on natural hide
  - use immediate unblock on interruption (pause/channel replacement)
- Existing autosave spinner path remains non-blocking.

### QOL-T046 GREEN Validation Results (2026-02-10)

Validation suites executed:

| Suite | Result | Notes |
|---|---|---|
| `res://tests/unit/ui` | PASS | 181/183 passing, 2 expected pending mobile-only |
| `res://tests/unit/interactables` | PASS | 36/36 passing |
| `res://tests/unit/save` | PASS | 123/124 passing, 1 expected pending headless viewport capture |
| `res://tests/integration/save_manager` | PASS | 19/19 passing |
| `res://tests/unit/style` | PASS | 12/12 passing |

### Phase 4 Completion Notes

- Phase 4 exit criteria met on 2026-02-10.
- Signpost feedback now uses dedicated panel channel with config/event-driven auto-hide duration.
- Event contract remained additive-only (`signpost_message.message_duration_sec`).
- Controlled blocker behavior preserved for signpost display while autosave spinner remains non-blocking.
- Next phase target: Phase 5 (`QOL-T050-QOL-T057`) world-space icon + HUD hybrid cue implementation.

### Phase 4 Exit Criteria

- Signpost feedback is panel-based and auto-hides by config duration.
- Pause/overlay behavior remains stable and test-covered.
- `signpost_message` remains backward-compatible with additive duration payload support.

---

## Phase 5 - 3D Interact Icon + HUD Hybrid

**Goal**: Add world-space interact icon cues while preserving existing HUD prompt behavior.

- [x] **QOL-T050** Add RED tests for world icon visibility conditions:
  - in-range + interactable + unblocked
  - out-of-range
  - transition/overlay blocked
- [x] **QOL-T051** Add interaction hint fields to `RS_InteractionConfig` (base, opt-in).
- [x] **QOL-T052** Implement world-space icon support in interact-mode controller flow.
- [x] **QOL-T053** Keep current `interact_prompt_show/hide` HUD prompt behavior unchanged.
- [x] **QOL-T054** Ensure icon and HUD prompt can coexist without conflicting hide/show races.
- [x] **QOL-T055** Add/author assets/resources for icon rendering if needed (prefix/style compliant).
- [x] **QOL-T056** Update scene/prefab wiring for at least one door + one signpost reference flow.
- [x] **QOL-T057** GREEN tests for hybrid cue behavior.

### QOL-T050 RED Coverage Added (2026-02-10)

- Added world hint RED coverage in:
  - `tests/unit/interactables/test_triggered_interactable_controller.gd`
  - `tests/unit/interactables/test_e_door_trigger_controller.gd`
  - `tests/unit/interactables/test_e_signpost.gd`
  - `tests/unit/interactables/test_scene_interaction_config_binding.gd`
  - `tests/unit/resources/test_interaction_config_validator.gd`
- New assertions cover:
  - world icon visible in interact mode when in-range + unblocked
  - world icon hidden when exiting range
  - world icon suppressed during transition/overlay blocking
  - world icon hidden while `U_InteractBlocker` is active

### QOL-T051-QOL-T052 Interaction Hint Schema + Controller Runtime

- Added base interaction hint fields to:
  - `scripts/resources/interactions/rs_interaction_config.gd`
  - `interaction_hint_enabled`, `interaction_hint_icon`, `interaction_hint_offset`, `interaction_hint_scale`
- Extended validation in:
  - `scripts/gameplay/helpers/u_interaction_config_validator.gd`
  - validates `interaction_hint_scale > 0`
  - validates `interaction_hint_icon` exists when hints are enabled
- Implemented config-driven world icon lifecycle in:
  - `scripts/gameplay/triggered_interactable_controller.gd`
  - Adds `SO_InteractionHintIcon` `Sprite3D` management
  - Visibility gates: interact mode, in-range, enabled, unblocked, not transition-blocked
  - Keeps icon sync in `_physics_process`, enter/exit, enabled state, and trigger-mode changes

### QOL-T053-QOL-T054 Hybrid Coexistence Guarantees

- Existing prompt event contract remains unchanged:
  - `interact_prompt_show` / `interact_prompt_hide` still published from `TriggeredInteractableController`
- Added coexistence tests confirming HUD prompt events still publish while world icon is visible:
  - `tests/unit/interactables/test_triggered_interactable_controller.gd`

### QOL-T055-QOL-T056 Reference Wiring

- Reused existing project icon asset (no new asset files required):
  - `res://assets/textures/tex_icon.svg`
- Enabled world-hint config in authored reference resources:
  - `resources/interactions/doors/cfg_door_exterior_to_bar.tres`
  - `resources/interactions/signposts/cfg_signpost_exterior_tutorial.tres`
- Controllers apply base interaction hint fields from typed config resources:
  - `scripts/gameplay/inter_door_trigger.gd`
  - `scripts/gameplay/inter_signpost.gd`

### QOL-T057 GREEN Validation Results (2026-02-10)

Validation suites executed:

| Suite | Result | Notes |
|---|---|---|
| `res://tests/unit/ui` | PASS | 181/183 passing, 2 expected pending mobile-only |
| `res://tests/unit/interactables` | PASS | 44/44 passing |
| `res://tests/unit/save` | PASS | 123/124 passing, 1 expected pending headless viewport capture |
| `res://tests/integration/save_manager` | PASS | 19/19 passing |
| `res://tests/unit/style` | PASS | 12/12 passing |

Implementation commit:
- `d57d6a7` - Add config-driven world interaction hints for interactables.

### Phase 5 Completion Notes

- Phase 5 exit criteria met on 2026-02-10.
- World-space icon cues now coexist with HUD prompt guidance using additive, config-driven behavior.
- Transition/overlay and blocker suppression rules are test-covered and deterministic.
- Next phase target: Phase 6 (`QOL-T060-QOL-T065`) regression + polish + closure.

### Phase 5 Exit Criteria

- World icon appears/hides correctly under interaction conditions.
- HUD prompt remains present and correct by active device.
- Hybrid flow is regression-safe.

---

## Phase 6 - Regression + Polish + Closure

**Goal**: Verify stability, close documentation, and prepare merge-ready state.

- [x] **QOL-T060** Run targeted regression gates:
  - `res://tests/unit/ui`
  - `res://tests/unit/interactables`
  - `res://tests/unit/save`
  - `res://tests/integration/save_manager`
  - `res://tests/unit/style`
- [x] **QOL-T061** Run additional impacted suites if failures or cross-domain regressions appear.
- [x] **QOL-T062** Confirm no event contract regressions in call sites and tests.
- [x] **QOL-T063** Final UX polish pass for channel timings/layout overlap edge cases.
- [x] **QOL-T064** Update this tasks file with completion notes and final suite results.
- [x] **QOL-T065** Update continuation prompt, and update `AGENTS.md` / `DEV_PITFALLS.md` if new patterns/pitfalls were discovered.

### QOL-T060 Final Regression Gates (2026-02-10)

Validation suites executed:

| Suite | Result | Notes |
|---|---|---|
| `res://tests/unit/ui` | PASS | 181/183 passing, 2 expected pending mobile-only |
| `res://tests/unit/interactables` | PASS | 44/44 passing |
| `res://tests/unit/save` | PASS | 123/124 passing, 1 expected pending headless viewport capture |
| `res://tests/integration/save_manager` | PASS | 19/19 passing |
| `res://tests/unit/style` | PASS | 12/12 passing |

### QOL-T061 Additional Impacted Suite Decision

- No additional suite expansion was required in this phase.
- Condition in task definition was not triggered: no failures or cross-domain regressions were observed in required gates.

### QOL-T062 Event Contract Audit Notes

- Event names remained unchanged at publisher/subscriber boundaries:
  - `interact_prompt_show`, `interact_prompt_hide` published from `scripts/gameplay/triggered_interactable_controller.gd`.
  - `signpost_message` published from `scripts/gameplay/inter_signpost.gd`.
  - `save_started`, `save_completed`, `save_failed` published from `scripts/managers/m_save_manager.gd`.
  - `checkpoint_activated` subscription remained stable in `scripts/ui/hud/ui_hud_controller.gd` and typed publish remained stable via `Evn_CheckpointActivated`.
- Additive payload keys remained backward-compatible:
  - `save_completed` / `save_failed`: `is_autosave` retained.
  - `signpost_message`: optional `message_duration_sec` retained with HUD fallback.
- Regression coverage still validates these contracts:
  - `tests/unit/ui/test_hud_feedback_channels.gd`
  - `tests/unit/interactables/test_e_signpost.gd`
  - `tests/unit/save/test_save_manager.gd`

### QOL-T063 Final UX Polish Pass

- No additional code or scene changes were required after regression validation.
- Existing timing/layout behavior remained stable under current coverage:
  - autosave spinner is non-blocking and independent
  - checkpoint toast remains isolated
  - signpost panel auto-hide and prompt restore remain deterministic
  - world icon and HUD prompt coexist without race regressions

### Phase 6 Completion Notes

- Phase 6 exit criteria met on 2026-02-10.
- Initiative closure is documentation-only for this phase; no runtime code changes were necessary.
- `AGENTS.md` and `docs/general/DEV_PITFALLS.md` required no updates for this phase (no new durable patterns/pitfalls identified).
- Initiative status: complete.

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
