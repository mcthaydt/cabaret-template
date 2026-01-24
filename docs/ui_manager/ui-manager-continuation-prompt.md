# UI Manager Implementation Guide & Continuation Prompt

## Overview

This guide directs you to implement the UI Manager / Navigation feature by following the tasks outlined in the documentation in sequential order.

**Branch**: `main`
**Status**: ✅ Phase 6 complete; Phase 7 in progress – Core UI Manager implementation finished; UX refinements underway (T070–T076, T079, T080 complete)

---

## 🎯 CURRENT STATUS: Phase 6 Complete, Phase 7 In Progress

- PRD: `docs/ui_manager/ui-manager-prd.md` – feature definition, goals, non‑goals.
- Plan: `docs/ui_manager/ui-manager-plan.md` – milestones and phases.
- Tasks: `docs/ui_manager/ui-manager-tasks.md` – checklist (32/54 tasks complete; Phases 0-6 done, Phase 7 partially complete).
- Data Model: `docs/ui_manager/general/data-model.md` – navigation + registry schema, overlay semantics, input/action model.
- Flows & Input: `docs/ui_manager/general/flows-and-input.md` – key flows, canonical ui_* actions, and context-based routing matrix.

### What Changed in Phase 6

**T062 - Documentation** (commit `8894d33`):
- Updated `AGENTS.md` with UI Manager patterns (navigation state, actions, registry, base classes)
- Added UI Manager integration to Scene Manager, State Store, and Input Manager PRDs
- Documented 6 common pitfalls in `DEV_PITFALLS.md` with code examples

**T063 - Code Cleanup** (commit `82c8f08`):
- Removed ~191 lines of diagnostic code across 5 files
- Verified with grep: zero diagnostic prints remaining
- All 135 state tests passing

**Tests Added/Updated**:
- All existing navigation tests continue to pass
- No new test coverage needed (cleanup only)

### What Changed in Phase 7 (So Far)

**T070 / T071 / T074 / T075 – Input & Navigation UX**  
- Joystick navigation now uses a standardized deadzone and repeat behavior (stick repeater + focus configurator).  
- Menu options scroll smoothly while directional input is held.  
- MobileControls visibility is correctly tied to active device + pause/navigation state; controls no longer reappear after exiting menus with gamepad.  
- Rebind controls overlay has gamepad-accessible scroll areas and improved focus wiring.

**T072 – Context-Aware Settings Visibility (Pause Menu)**  
- Pause menu dynamically hides/shows Gamepad vs Touchscreen settings buttons based on active device (`M_InputDeviceManager` + `U_InputSelectors`).  
- When switching from touchscreen to gamepad while paused:
  - Analog navigation state is reset.  
  - Focus is explicitly snapped back to the Resume button.  
  - The first gamepad navigation input after the switch is consumed, so “waking” the controller with a stick nudge does not move selection.  
- All existing UI tests still pass; behavior validated on mobile + gamepad.

**T076 – Context-Sensitive Rebind Controls**  
- Rebind Controls overlay now filters displayed bindings by active device type (keyboard/mouse vs gamepad) using `U_InputSelectors.get_active_device_type()`, while still falling back to all bindings if filtering would otherwise hide valid entries.  
- Pause menu hides the Rebind Controls entry when the active device is TOUCHSCREEN so touch-only players are not shown a non-functional rebind flow.

**T079 / T080 – Overlay Flattening & Back Behavior**  
- Navigation slice now maintains a single active overlay ID plus an `overlay_return_stack`, so settings/input overlays replace rather than stack on top of pause while still supporting “return to previous overlay” semantics where needed.  
- `UIInputHandler` and base overlays route `ui_cancel` / `ui_pause` through navigation actions so Cancel consistently exits the current overlay or returns to the prior screen in main menu, gameplay, and endgame shells, matching the flows document.

---

## Instructions  **YOU MUST DO THIS - NON-NEGOTIABLE**

### 1. Review Project Foundations

- `AGENTS.md` – Project conventions and patterns.
- `docs/general/DEV_PITFALLS.md` – Common mistakes to avoid.
- `docs/general/STYLE_GUIDE.md` – Code style and naming requirements.
- Scene Manager docs:
  - `docs/scene_manager/scene-manager-prd.md`
  - `docs/scene_manager/scene-manager-plan.md`
  - `docs/scene_manager/scene-manager-tasks.md`
- State Store docs:
  - `docs/state_store/redux-state-store-prd.md`
  - `docs/state_store/redux-state-store-implementation-plan.md`
  - `docs/state_store/redux-state-store-tasks.md`
- Input Manager docs:
  - `docs/input_manager/input-manager-prd.md`
  - `docs/input_manager/input-manager-plan.md`
  - `docs/input_manager/input-manager-tasks.md`

### 2. Review UI Manager Documentation

- `docs/ui_manager/ui-manager-prd.md` – Full UI Manager specification.
- `docs/ui_manager/ui-manager-plan.md` – Implementation plan with phase breakdown.
- `docs/ui_manager/ui-manager-tasks.md` – Task list and phases.
- `docs/ui_manager/general/data-model.md` – Navigation and UI registry data model.
- `docs/ui_manager/general/flows-and-input.md` – Flow narratives and input routing matrix.

### 3. Understand Existing Architecture

- `scripts/managers/m_scene_manager.gd` – Scene transitions, overlays, pause.
- `scripts/state/m_state_store.gd` – Redux store and slice registration.
- `scripts/state/reducers/u_scene_reducer.gd` – Scene slice reducer.
- `scripts/state/reducers/u_menu_reducer.gd` – Menu slice reducer.
- `scripts/managers/m_input_device_manager.gd` – Device detection and signals.
- `scripts/ui/*` – Current UI controllers and overlays (main menu, pause, settings, endgame, input).

### 4. Execute UI Manager Tasks in Order

Work through the tasks in `ui-manager-tasks.md` sequentially:

1. **Phase 0** (T001–T003): Architecture & Data Model ✅
2. **Phase 1** (T010–T014): Navigation State & Selectors ✅
3. **Phase 2** (T020–T024): UI Registry & Screen Definitions ✅
4. **Phase 3** (T030–T033): Scene Manager Integration (Reactive Mode) ✅
5. **Phase 4** (T040–T045): UI Panels & Controller Refactors ✅
6. **Phase 5** (T050–T052): UI Input Handler (Gamepad & Keyboard) ✅
7. **Phase 6** (T060–T063): Hardening & Regression Guardrails ✅
8. **Phase 7** (T070–T080): UX Refinements & Polish 🚧

### 5. Follow TDD Discipline

For each task:

1. Write the test first (unit or integration).
2. Run the test and verify it fails for the expected reason.
3. Implement the minimal code to make it pass.
4. Run the test suite and verify it passes.
5. Commit with a clear, focused message.

### 6. Preserve Compatibility (“Everything Still Works”)

You MUST:

- Keep existing Scene Manager, State Store, Input Manager, HUD, and MobileControls flows working at all times.
- Avoid breaking external APIs (`M_SceneManager.transition_to_scene`, `push_overlay`, etc.) during migration.
- Update tests and docs only when behavior changes are intentional and explicitly approved.
- Use selectors and navigation state as the **only** place new UI logic reads “where are we in the UI?”.

---

## Critical Notes

- **No Autoloads**: UI Manager must follow the existing pattern (root scene + in‑scene managers). Navigation reducers live in the state store; Scene Manager remains scene‑tree based.
- **State-First Architecture**: Navigation and UI state are declarative. Reducers + registry define behavior; managers enforce it.
- **Immutable State**: Follow existing Redux patterns (`.duplicate(true)`, pure reducers).
- **Input Contracts**: UI controllers must rely on `ui_*` actions, not hardcoded keycodes or gamepad buttons. Input Manager remains responsible for mapping hardware to `ui_*`.
- **Style & Organization**: Follow `docs/general/STYLE_GUIDE.md` and `docs/general/SCENE_ORGANIZATION_GUIDE.md`
- **Cleanup Project**: See `docs/general/cleanup/style-scene-cleanup-continuation-prompt.md` for architectural improvements
- **UI → Redux → Scene Manager Rule**: UI scripts must NOT call `M_SceneManager` directly - use Redux actions instead (see T056)

---

## Known Issues / Phase 7 Focus

Phase 7 addresses UX refinements discovered during testing:

**Input & Navigation Issues:**
- T070: Joystick menu navigation requires exact/hard press (sensitivity issue)
- T071: Menu options don't cycle when directional input held
- T075: Rebind controls scrollbars not fully accessible via gamepad

**Context-Aware UI:**
- T072: Gamepad settings visibility and touchscreen settings visibility tuned to match actual device and platform state (hub-based, not tabbed)
- T076: Rebind controls shows device-appropriate bindings and hides the flow for touch-only contexts
- T077: Input profiles now show per-profile binding previews in the selector overlay (players can see core actions before applying a profile)
- T078: Gamepad UI needs visual button glyphs (Xbox/PS)

**Architecture & UX:**
- T073: Original “tabbed SettingsPanel” consolidation concept is intentionally deferred; current architecture uses a Settings Hub plus dedicated overlays/scenes for each settings area
- T079: ✅ Overlays now replace instead of stacking (flattened overlay navigation via navigation slice)
- T080: Cancel button doesn't exit menu consistently

**Bug Fixes:**
- T074: Mobile touchscreen controls appear after exiting menu with gamepad

## Next Steps

To continue with Phase 7:

1. Review the Phase 7 tasks in `ui-manager-tasks.md` (T070–T080)
2. Prioritize based on severity (bugs first, then UX, then architecture)
3. Consider tackling T079 (flatten UI) early as it may impact other tasks
4. Each task follows the same TDD discipline as previous phases
