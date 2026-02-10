# Quality of Life Refactors Continuation Prompt

## Current Status

- Initiative: Quality of Life Refactors (HUD feedback separation + hybrid interaction cues)
- Current phase: Phase 6 (Ready to Start)
- Primary tasks file: `docs/general/quality_of_life_refactors/quality-of-life-refactors-tasks.md`
- Task progress: 35/41 complete (`QOL-T001-QOL-T004`, `QOL-T010-QOL-T014`, `QOL-T020-QOL-T025`, `QOL-T030-QOL-T034`, `QOL-T040-QOL-T046`, `QOL-T050-QOL-T057` complete; `QOL-T060-QOL-T065` remaining)
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

## Phase 1 Completion Summary (2026-02-10)

- Completed channel-split scaffolding tasks:
  - `QOL-T010` RED tests for independent HUD channel visibility + parity guard
  - `QOL-T011` HUD scene channel nodes added (autosave spinner + signpost panel + preserved checkpoint toast)
  - `QOL-T012` HUD controller refactor to channel-specific show/hide helper surface
  - `QOL-T013` Baseline-visible behavior preserved (signpost/autosave events still routed to checkpoint toast)
  - `QOL-T014` GREEN validation across required gate suites
- New test coverage:
  - `tests/unit/ui/test_hud_feedback_channels.gd`
- Required gate suite status after Phase 1:
  - `res://tests/unit/ui`: PASS (172/174, 2 expected pending mobile-only tests)
  - `res://tests/unit/interactables`: PASS (36/36)
  - `res://tests/unit/save`: PASS (121/122, 1 expected pending headless viewport-capture test)
  - `res://tests/integration/save_manager`: PASS (19/19)
  - `res://tests/unit/style`: PASS (12/12)
- Implementation commit:
  - `c231a2d` - Add HUD feedback channel scaffolding and tests.

## Phase 2 Completion Summary (2026-02-10)

- Completed autosave spinner tasks:
  - `QOL-T020` RED tests for spinner lifecycle + channel isolation + blocker/manual guards
  - `QOL-T021` autosave event routing moved to spinner-only channel
  - `QOL-T022` additive payload extension for `save_completed`/`save_failed` (`is_autosave`)
  - `QOL-T023` non-blocking spinner behavior validated (`U_InteractBlocker` unaffected)
  - `QOL-T024` manual save/load behavior parity confirmed
  - `QOL-T025` GREEN validation across required gate suites
- New/expanded tests:
  - `tests/unit/ui/test_hud_feedback_channels.gd`
  - `tests/unit/save/test_save_manager.gd`
- Required gate suite status after Phase 2:
  - `res://tests/unit/ui`: PASS (175/177, 2 expected pending mobile-only tests)
  - `res://tests/unit/interactables`: PASS (36/36)
  - `res://tests/unit/save`: PASS (123/124, 1 expected pending headless viewport-capture test)
  - `res://tests/integration/save_manager`: PASS (19/19)
  - `res://tests/unit/style`: PASS (12/12)
- Implementation commit:
  - `e35bc12` - Route autosave feedback to spinner and add payload flags.

## Phase 3 Completion Summary (2026-02-10)

- Completed checkpoint toast redesign tasks:
  - `QOL-T030` RED tests for checkpoint channel-only behavior, copy fallback, and prompt lifecycle
  - `QOL-T031` checkpoint rendering isolation from signpost/autosave call paths
  - `QOL-T032` player-facing checkpoint text fallback (humanized IDs + explicit label preference)
  - `QOL-T033` checkpoint timing/prompt restoration parity preserved with dedicated assertions
  - `QOL-T034` GREEN validation across required gate suites
- Updated test coverage:
  - `tests/unit/ui/test_hud_feedback_channels.gd`
- Required gate suite status after Phase 3:
  - `res://tests/unit/ui`: PASS (178/180, 2 expected pending mobile-only tests)
  - `res://tests/unit/interactables`: PASS (36/36)
  - `res://tests/unit/save`: PASS (123/124, 1 expected pending headless viewport-capture test)
  - `res://tests/integration/save_manager`: PASS (19/19; passed on rerun after one transient failure)
  - `res://tests/unit/style`: PASS (12/12)
- Implementation commit:
  - `a0c7526` - Refine checkpoint toast copy and channel isolation.

## Phase 4 Completion Summary (2026-02-10)

- Completed signpost panel + duration tasks:
  - `QOL-T040` RED tests for signpost panel lifecycle (show, auto-hide, pause suppression, prompt restoration)
  - `QOL-T041` Added `message_duration_sec` to `RS_SignpostInteractionConfig` (default `3.0`)
  - `QOL-T042` Added signpost duration validator rule + resource validator tests
  - `QOL-T043` Added additive `message_duration_sec` payload publish from `Inter_Signpost`
  - `QOL-T044` Routed `signpost_message` to dedicated signpost panel with payload/default duration handling
  - `QOL-T045` Preserved controlled blocker behavior for signpost path while keeping autosave spinner non-blocking
  - `QOL-T046` GREEN validation across required gate suites
- Updated test coverage:
  - `tests/unit/ui/test_hud_feedback_channels.gd`
  - `tests/unit/ui/test_hud_interactions_pause_and_signpost.gd`
  - `tests/unit/interactables/test_e_signpost.gd`
  - `tests/unit/resources/test_interaction_config_validator.gd`
- Required gate suite status after Phase 4:
  - `res://tests/unit/ui`: PASS (181/183, 2 expected pending mobile-only tests)
  - `res://tests/unit/interactables`: PASS (36/36)
  - `res://tests/unit/save`: PASS (123/124, 1 expected pending headless viewport-capture test)
  - `res://tests/integration/save_manager`: PASS (19/19)
  - `res://tests/unit/style`: PASS (12/12)
- Implementation commit:
  - `d9ef6b3` - Route signpost feedback to timed panel and duration payload.

## Phase 5 Completion Summary (2026-02-10)

- Completed world-icon + hybrid cue tasks:
  - `QOL-T050` RED tests for world icon visibility conditions (in-range, out-of-range, transition/overlay blocked, interact-blocked)
  - `QOL-T051` Added interaction hint fields to `RS_InteractionConfig`
  - `QOL-T052` Implemented world icon lifecycle in `TriggeredInteractableController`
  - `QOL-T053` Preserved `interact_prompt_show/hide` contract and behavior
  - `QOL-T054` Added coexistence coverage for world icon + HUD prompt event flow
  - `QOL-T055` Reused existing icon asset (`tex_icon.svg`) for world hints
  - `QOL-T056` Updated door + signpost reference interaction configs for world hints
  - `QOL-T057` GREEN validation across required gate suites
- Updated test coverage:
  - `tests/unit/interactables/test_triggered_interactable_controller.gd`
  - `tests/unit/interactables/test_e_door_trigger_controller.gd`
  - `tests/unit/interactables/test_e_signpost.gd`
  - `tests/unit/interactables/test_scene_interaction_config_binding.gd`
  - `tests/unit/resources/test_interaction_config_validator.gd`
- Required gate suite status after Phase 5:
  - `res://tests/unit/ui`: PASS (181/183, 2 expected pending mobile-only tests)
  - `res://tests/unit/interactables`: PASS (44/44)
  - `res://tests/unit/save`: PASS (123/124, 1 expected pending headless viewport-capture test)
  - `res://tests/integration/save_manager`: PASS (19/19)
  - `res://tests/unit/style`: PASS (12/12)
- Implementation commit:
  - `d57d6a7` - Add config-driven world interaction hints for interactables.

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
- Phase 1 - HUD Channel Split Scaffolding (`QOL-T010-QOL-T014`): Complete
- Phase 2 - Autosave Spinner (`QOL-T020-QOL-T025`): Complete
- Phase 3 - Checkpoint Toast Redesign (`QOL-T030-QOL-T034`): Complete
- Phase 4 - Signpost Panel + Duration (`QOL-T040-QOL-T046`): Complete
- Phase 5 - 3D Interact Icon + HUD Hybrid (`QOL-T050-QOL-T057`): Complete
- Phase 6 - Regression + Polish + Closure (`QOL-T060-QOL-T065`): Ready to Start

## Immediate Next Step

Start Phase 6 with `QOL-T060` by running final regression gates and capturing closure notes (`QOL-T060-QOL-T065`), including final event-contract audit and initiative completion docs updates.

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
- Keep Phase 2 spinner routing, Phase 3 checkpoint copy behavior, Phase 4 signpost panel/duration behavior, and Phase 5 world-hint coexistence behavior stable during closure/polish work.
- If new pitfalls or repeat mistakes are discovered, update:
  - `AGENTS.md`
  - `docs/general/DEV_PITFALLS.md`
