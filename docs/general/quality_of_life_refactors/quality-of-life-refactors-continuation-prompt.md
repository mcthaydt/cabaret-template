# Quality of Life Refactors Continuation Prompt

## Current Status

- Initiative: Quality of Life Refactors (HUD feedback separation + hybrid interaction cues)
- Current phase: Phase 1 (Ready to Start)
- Primary tasks file: `docs/general/quality_of_life_refactors/quality-of-life-refactors-tasks.md`
- Task progress: 4/41 complete (`QOL-T001-QOL-T004` complete; `QOL-T010-QOL-T065` remaining)
- Last updated: 2026-02-10

## Phase 0 Completion Summary (2026-02-10)

- Completed baseline and invariant tasks:
  - `QOL-T001` baseline suite execution
  - `QOL-T002` coupling invariants capture
  - `QOL-T003` event contract compatibility constraints capture
  - `QOL-T004` pause/overlay/transition suppression invariants capture
- Required baseline suite status:
  - `res://tests/unit/ui`: PASS (170/172, 2 expected pending mobile-only tests)
  - `res://tests/unit/interactables`: PASS (36/36)
  - `res://tests/unit/save`: PASS (121/122, 1 expected pending headless viewport-capture test)
  - `res://tests/integration/save_manager`: PASS (19/19)
  - `res://tests/unit/style`: PASS (12/12)
- Baseline architecture findings recorded in tasks file:
  - Checkpoint/signpost/autosave currently share one toast rendering path in HUD.
  - Prompt suppression/restoration and `U_InteractBlocker` are coupled to toast lifecycle.
  - Event names are frozen; payload evolution remains additive-only.
  - Pause/overlay/transition suppression behavior is documented as regression guardrails for Phase 1+.

## Confirmed Product Decisions (Locked)

1. Feedback UX uses **functional split**:
  - Autosave: top-center spinner.
  - Checkpoint: dedicated checkpoint toast.
  - Signpost: dedicated signpost message panel.
2. Interactable discoverability uses **hybrid 3D + HUD**:
  - Keep HUD prompt (`UI_ButtonPrompt`) for explicit key/button instructions.
  - Add world-space 3D icon for in-range interactables.
3. Signpost message panel dismisses by **auto-hide after delay**.

## Planned Public Surface Changes

- HUD:
  - Add dedicated presentation channels in:
    - `scenes/ui/hud/ui_hud_overlay.tscn`
    - `scripts/ui/hud/ui_hud_controller.gd`
- Interaction resources:
  - `scripts/resources/interactions/rs_signpost_interaction_config.gd`:
    - add `message_duration_sec` (default `3.0`).
  - `scripts/resources/interactions/rs_interaction_config.gd`:
    - add interaction hint fields for world icon behavior.
- Event contracts:
  - No event name changes.
  - Additive payload extensions are allowed for this initiative where required:
    - `save_completed` includes `is_autosave`.
    - `save_failed` includes `is_autosave`.
    - `signpost_message` may include `message_duration_sec`.
  - Existing published/subscribed events must remain compatible:
    - `interact_prompt_show`
    - `interact_prompt_hide`
    - `signpost_message`
    - `save_started`
    - `save_completed`
    - `save_failed`
    - `checkpoint_activated`

## Required Reading (Do Not Skip)

1. `AGENTS.md`
2. `docs/general/DEV_PITFALLS.md`
3. `docs/general/STYLE_GUIDE.md`
4. `docs/general/quality_of_life_refactors/quality-of-life-refactors-tasks.md`
5. `docs/general/interactions_refactor/interactions-refactor-tasks.md` (format/discipline reference)
6. `docs/general/interactions_refactor/interactions-refactor-continuation-prompt.md` (handoff quality reference)

## Working Loop (Per Phase)

1. RED:
  - Add/adjust tests first for the next unchecked tasks.
2. GREEN:
  - Implement minimal code to satisfy the tests.
3. REFACTOR:
  - Clean internals, preserve contracts, and keep behavior deterministic.
4. Validate:
  - Run required test suites for that phase.
5. Document:
  - Update tasks file checkboxes/notes.
  - Update this continuation prompt with status and next action.
6. Commit discipline:
  - Commit implementation changes.
  - Commit documentation updates separately.

## Phase Progress Snapshot

- Phase 0 - Baseline and Invariants (`QOL-T001-QOL-T004`): Complete
- Phase 1 - HUD Channel Split Scaffolding (`QOL-T010-QOL-T014`): Ready to Start
- Phase 2 - Autosave Spinner (`QOL-T020-QOL-T025`): Not Started
- Phase 3 - Checkpoint Toast Redesign (`QOL-T030-QOL-T034`): Not Started
- Phase 4 - Signpost Panel + Duration (`QOL-T040-QOL-T046`): Not Started
- Phase 5 - 3D Interact Icon + HUD Hybrid (`QOL-T050-QOL-T057`): Not Started
- Phase 6 - Regression + Polish + Closure (`QOL-T060-QOL-T065`): Not Started

## Immediate Next Step

Start Phase 1 with `QOL-T010` by adding RED tests for independent HUD channel visibility state, then proceed with scaffold-only channel separation (`QOL-T011-QOL-T014`) without changing functional routing yet.

## Required Test Commands (Phase Advancement Gates)

- `tools/run_gut_suite.sh -gdir=res://tests/unit/ui -ginclude_subdirs=true -gexit`
- `tools/run_gut_suite.sh -gdir=res://tests/unit/interactables -ginclude_subdirs=true -gexit`
- `tools/run_gut_suite.sh -gdir=res://tests/unit/save -ginclude_subdirs=true -gexit`
- `tools/run_gut_suite.sh -gdir=res://tests/integration/save_manager -ginclude_subdirs=true -gexit`
- `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true -gexit`

Style suite is mandatory after any scene/resource structure change.

## Key Behavioral Targets (Acceptance Summary)

1. Autosave spinner is independent and non-blocking.
2. Checkpoint and signpost feedback no longer share one generic toast path.
3. Signpost panel auto-hides based on config duration and is pause/overlay safe.
4. 3D world icon and HUD prompt coexist without event contract break.
5. Interaction blocker is used only where intentional (not autosave spinner path).
6. Save/signpost payload additions remain additive and backward-compatible.

## Notes for Next Engineer/Agent

- Preserve current event payload compatibility; extend behavior in subscribers rather than renaming events.
- Keep world icon support config-driven to avoid controller-only one-offs.
- When introducing new exported resource fields, update defaults and test coverage in the same phase.
- Use Phase 0 invariants in `quality-of-life-refactors-tasks.md` as regression gates while splitting HUD channels.
- If new pitfalls or repeat mistakes are discovered, update:
  - `AGENTS.md`
  - `docs/general/DEV_PITFALLS.md`
