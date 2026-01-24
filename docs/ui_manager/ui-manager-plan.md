# Implementation Plan: UI Navigation & Manager System

## Summary

- **Feature / area**: UI Navigation & Manager System (UI Manager)
- **Owner**: TBD
- **Current status**: M1–M6 implemented; M7 UX refinements and small architectural tweaks in progress (see ui-manager-tasks Phase 7)

This plan defines how to introduce a navigation/UI slice, a data‑driven UI registry, and state‑driven navigation on top of the existing Scene Manager, State Store, and Input Manager. The goal is to reach a state where UI and menu flows are as declarative and testable as ECS and state management, while keeping all existing flows working during the migration.

## Milestones

1. **M1 – Architecture & Data Model** – ✅ Define navigation slice schema and UI registry; document integration points and invariants.
2. **M2 – Navigation Slice & Selectors** – ✅ Implement navigation reducer and selectors (TDD), wire into `M_StateStore`.
3. **M3 – UI Registry & Screen Definitions** – ✅ Implement UI registry resources and loader; backfill definitions for existing screens/overlays.
4. **M4 – Scene Manager Integration (Reactive Mode)** – ✅ Teach `M_SceneManager` to read navigation/scene slices and keep the scene tree in sync, without breaking existing APIs.
5. **M5 – UI Panels & Controller Refactors** – Refactor key UI scenes to panel‑based, state‑driven patterns, removing direct Scene Manager calls where possible.
6. **M6 – UI Input Handler (Gamepad & Keyboard)** – Introduce a thin handler that maps `ui_*` actions into navigation actions, with consistent ESC/back semantics.
7. **M7 – Hardening & Regression Guardrails** – Comprehensive tests, docs alignment, and confirm “everything still works” across all flows.

## Work Breakdown

### M1 – Architecture & Data Model

- [ ] Define navigation/UI slice schema and ownership rules.
  - Notes: Decide whether to add a dedicated `navigation` slice or extend `scene` + `menu`. Clarify which reducers own which fields.
- [ ] Document UI screen/overlay/panel registry format.
  - Notes: Minimal fields: id, path, kind (BASE_SCENE/OVERLAY/PANEL), allowed contexts, close_mode, default focus.
- [ ] Capture integration invariants.
  - Notes: `M_SceneManager` enforces, but does not own, navigation state; navigation reducers never assume specific scene tree layout beyond existing containers/groups.

### M2 – Navigation Slice & Selectors

- [ ] Add navigation reducer and initial state resource.
  - Notes: Follow existing patterns (`RS_*InitialState`, `U_*Reducer`, `RS_StateSliceConfig`).
- [ ] Register navigation slice in `M_StateStore._initialize_slices()`.
- [ ] Implement navigation selectors (`U_NavigationSelectors`).
  - Notes: Derived questions like “is pause open?”, “what is top overlay?”, “which menu panel is active?” should be pure selectors.
- [ ] Unit tests for navigation reducer and selectors.

### M3 – UI Registry & Screen Definitions

- [ ] Implement `RS_UIScreenDefinition` resource type.
- [ ] Create `U_UIRegistry` static helper (similar to `U_SceneRegistry`).
- [ ] Add registry entries for existing UI:
  - Main menu, settings panel, pause menu, game over, victory, credits.
  - Overlays: pause, settings, input profile selector, gamepad/touchscreen settings, rebinding, edit touch controls.
- [ ] Unit tests for registry loading, validation, and basic lookup helpers.

### M4 – Scene Manager Integration (Reactive Mode)

- [ ] Add navigation/scene reconciliation helpers to `M_SceneManager`.
  - Notes: Compare desired navigation/scene state with actual tree; compute needed transitions/pushes/pops.
- [ ] Ensure reconciliation respects existing queueing, async loading, and camera/spawn logic.
- [ ] Add integration tests for key flows:
  - Main menu → gameplay hub → pause → settings overlay → back → gameplay.
  - Pause → rebinding overlay (“resume” behavior).
  - Endgame flows (game over, victory, credits → main menu).
- [ ] Preserve existing external APIs (`transition_to_scene`, `push_overlay`, etc.) during migration.

### M5 – UI Panels & Controller Refactors

- [ ] Identify and document reusable panels (SettingsPanel, CharacterSelectPanel, etc.).
- [ ] Introduce base classes for screens/overlays/panels (`BaseMenuScreen`, `BaseOverlay`, `BasePanel`) with common wiring:
  - process_mode, store access, back/close behavior, device detection hooks.
- [ ] Refactor core UI scenes:
  - `main_menu.tscn` → panel‑based, driven by `menu` + navigation selectors.
  - `pause_menu.tscn` → uses navigation actions instead of direct Scene Manager calls.
  - Overlays (settings, gamepad/touchscreen settings, rebinding, input profile selector) → declare close behavior via data and base classes.
- [ ] Add unit/integration tests for panel behavior (including gamepad focus behavior where feasible).

### M6 – UI Input Handler (Gamepad & Keyboard)

- [ ] Define the canonical set of `ui_*` actions for UI navigation.
- [ ] Implement a thin UI input handler:
  - Listens to `ui_*` actions.
  - Uses navigation selectors + scene type to dispatch navigation actions (open/close pause, open overlays, navigate back).
  - Integrates with `M_InputDeviceManager` and existing Input Manager patterns.
- [ ] Tests for input routing in different contexts (gameplay, pause, overlays, main menu).

### M7 – Hardening & Regression Guardrails

- [ ] Run full GUT suite; record baseline and post‑change counts.
- [ ] Add targeted integration tests for any regressions discovered during manual QA.
- [ ] Align documentation:
  - New docs under `docs/ui_manager/general` as needed.
  - Cross‑links from Scene Manager, State Store, and Input Manager docs.
- [ ] Confirm “everything still works”:
  - Manual validation of all existing flows with keyboard/mouse and gamepad.

## Testing Strategy

- **Unit Tests**
  - Navigation reducers, selectors, and registry helpers.
  - New base UI classes (behavior that can be tested headless).

- **Integration Tests**
  - Scene Manager reconciliation with navigation slice for key flows.
  - UI input handler routing `ui_*` actions into navigation actions correctly in different contexts.
  - End‑to‑end flows for pause, settings, and endgame paths.

## Risks & Mitigations

- **Risk**: Navigation slice and Scene Manager fight over responsibility.
  - Mitigation: Clearly document ownership boundaries in code and docs. Treat navigation slice as the declarative contract, Scene Manager as executor only.

- **Risk**: Complexity of reconciliation logic introduces subtle bugs.
  - Mitigation: Start with a minimal reconciliation scope (only overlays and a small set of scenes), add tests per flow, and expand coverage gradually.

- **Risk**: Refactoring UI controllers disrupts existing test scenes.
  - Mitigation: Introduce base classes and navigation gradually, keeping existing APIs and patterns available for tests; only migrate a few key controllers at a time.

## References

- Scene Manager PRD: `docs/scene_manager/scene-manager-prd.md`
- Scene Manager Plan: `docs/scene_manager/scene-manager-plan.md`
- State Store PRD: `docs/state_store/redux-state-store-prd.md`
- Input Manager PRD: `docs/input_manager/input-manager-prd.md`
- UI Manager Tasks: `docs/ui_manager/ui-manager-tasks.md`
