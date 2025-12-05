---
description: "Task checklist for Style & Scene Organization cleanup"
created: "2025-12-03"
version: "1.0"
---

# Tasks: Style & Scene Organization Cleanup

**Feature**: Style & Scene Hardening  
**Branch**: `style-scene-cleanup` (suggested)  
**Discipline**: TDD where applicable; small, focused commits

> **Workflow Requirements**
> - Always open this tasks file first and work from the **next unchecked** `[ ]` item in order (unless marked [P] for parallel).
> - Check off tasks (`[x]`) immediately after completing them.
> - Keep documentation updates and implementation in separate commits, as per `AGENTS.md`.
> - Update the continuation prompt after each phase.

---

## Phase 0 – Discovery & Inventory

- [x] T000 [P] Read `AGENTS.md`, `DEV_PITFALLS.md`, `STYLE_GUIDE.md`, `SCENE_ORGANIZATION_GUIDE.md` end‑to‑end.
- [x] T001 [P] Inventory all `.gd` scripts under `res://scripts/` and classify them by category:
  - Manager, System, Component, Resource, Utility, UI, Marker, Base, Test.
- [x] T002 [P] Inventory all `.tscn` scenes under `res://scenes/` and classify:
  - Root, Gameplay, UI, Debug/Test, Prototype.
- [x] T003 [P] Inventory all `.tres` resources under `res://resources/` and `res://scripts/**/resources/` and classify:
  - Settings, Profiles, Triggers, Initial State, Scene Registry, UI Screen Definitions.
- [x] T004 [P] Produce a short "naming/prefix deviations" document (can be a section in this file or a separate note) listing:
  - Files without a prefix.
  - Names that conflict with the updated prefix intent.
  - Any ambiguous cases (e.g., UI vs. scene scripts).
  - **Result**: Comprehensive Phase 0 Discovery & Inventory Report generated (see plan file)
- [x] T005 [P] Inventory all places where `get_tree().paused` is set and where cursor state is modified:
  - Systems, managers, UI scripts, debug overlays.
  - **Result**: 2 authorities identified - M_PauseManager and M_SceneManager (consolidation planned for Phase 2)
- [x] T006 [P] Cross‑check current gameplay scenes (`base`, `exterior`, `interior_house`) against `SCENE_ORGANIZATION_GUIDE.md` and note any structural or naming differences.
  - **Result**: 9/10 compliance - excellent adherence, minor system roster update needed
- [x] T007 [P] Cross‑check root scene (`scenes/root.tscn`) against documentation; list any patterns not yet captured in the guide.
  - **Result**: 10/10 perfect match - documented manager initialization order
- [x] T008 [P] Cross‑check subsystem PRDs/plans (ECS, state store, scene manager, input manager, UI manager) and record where they diverge from the current implementation.
  - **Result**: 2/5 accurate (ECS, State Store), 3/5 outdated (Scene/Input/UI show "Draft" but production-complete)

---

## Phase 1 – Spec & Guide Updates

- [x] T010 Update `STYLE_GUIDE.md` with a **prefix matrix**:
  - Define allowed filename/class prefixes per category (Managers, Systems, Components, Resources, Utilities, UI, Marker Scripts, Base Classes, Tests).
  - **Result**: Complete prefix matrix added with 6 subsystem layers + documented exceptions
- [x] T011 Add a **global prefix rule** to `STYLE_GUIDE.md`:
  - "Every production script/scene/resource must use a documented prefix or documented exception pattern."
  - **Result**: Global prefix rule added with explicit enforcement language
- [x] T012 Document explicit rules and examples for:
  - Input Manager (device/profile managers, rebind utils, input reducers/selectors).
  - UI Manager (BasePanel, BaseMenuScreen, BaseOverlay, UI controllers, UI registry).
  - Debug overlays and test/helper scenes.
  - **Result**: All subsystems documented in prefix matrix with examples
- [x] T017 Reconcile `STYLE_GUIDE.md` scene naming guidance:
  - Remove legacy "unprefixed scene file" language and grandfathered exceptions.
  - Explicitly adopt `gameplay_*`, `ui_*`, `debug_*` patterns under the global prefix rule.
  - **Result**: Updated scene naming table, added `prefab_*` pattern, removed grandfathering language
- [x] T013 Extend `SCENE_ORGANIZATION_GUIDE.md` with a **Root Scene** section:
  - Node layout (Root, Managers, ActiveSceneContainer, UIOverlayStack, TransitionOverlay, LoadingOverlay, MobileControls).
  - Manager responsibilities at a high level.
  - **Result**: Root scene section already present (lines 78-116), added manager initialization order
- [x] T014 Refresh **Gameplay Scene** examples in `SCENE_ORGANIZATION_GUIDE.md`:
  - Align root naming (e.g., `GameplayRoot` with `main_root_node.gd`).
  - Include examples for hazard, victory, and signpost controllers under `Entities`.
  - **Result**: Updated all 4 system categories with complete current roster (19 systems total)
- [x] T015 Extend **Interactable Controllers** section with:
  - A concise summary of the current controller stack and settings resource behaviour.
  - Example node hierarchies from `exterior` and `interior_house`.
  - **Result**: Interactable Controllers section already comprehensive (lines 169-187)
- [x] T016 Update `AGENTS.md` to:
  - Reference the new prefix rules and root/gameplay scene patterns.
  - Emphasize running style/scene tests before merging cleanup changes.
  - **Result**: Added mandatory style/scene test requirement and updated naming conventions section

---

## Phase 2 – Responsibility Consolidation (Pause/Cursor)

**CRITICAL REQUIREMENTS IDENTIFIED FROM FAILED ATTEMPT**:
- Main menu (SceneType.MENU) MUST have cursor visible & unlocked
- M_PauseManager must derive cursor state from BOTH pause state AND scene type
- Tests need proper timing (await physics frames for M_PauseManager to react to scene state changes)
- M_PauseManager must be added to root.tscn BUT with proper initialization order
- Scene slice subscription must happen AFTER M_StateStore and M_SceneManager are ready

### Core Authority Model

- [x] T020 Document the **pause/cursor authority model** in a short note under `docs/general/cleanup/`:
  - Confirm `M_PauseManager` is the single authority for engine pause and cursor coordination (via `M_CursorManager`).
  - Document cursor logic: overlays → visible, MENU/UI/END_GAME → visible, GAMEPLAY → hidden.
  - **NEW**: Document initialization order requirements (store → scene manager → pause system).

### M_PauseManager Refactor

- [x] T021 Refactor `M_PauseManager` to derive pause and cursor state from scene slice:
  - Subscribe to scene slice updates (NOT navigation slice). ✓
  - Derive pause from `scene.scene_stack.size() > 0` (overlays = paused). ✓
  - Derive cursor from BOTH pause state AND scene type. ✓
  - **Cursor logic**: ✓
    - If paused (overlays present): cursor visible & unlocked
    - If not paused:
      - MENU/UI/END_GAME scenes: cursor visible & unlocked
      - GAMEPLAY scenes: cursor hidden & locked
  - Set `process_mode = Node.PROCESS_MODE_ALWAYS` (can unpause tree). ✓
  - **NEW**: Ensure proper initialization - synchronous init + _process() polling for robustness. ✓
  - **FIXES APPLIED**:
    - Changed initialization from async to synchronous (scripts/ecs/systems/m_pause_manager.gd:43-72)
    - Added _process() polling to detect UI/state mismatches (scripts/ecs/systems/m_pause_manager.gd:114-143)
    - Added engine pause desync detection in _on_slice_updated() (scripts/ecs/systems/m_pause_manager.gd:163-167)
    - Moved process_mode to _init() for earlier activation (scripts/ecs/systems/m_pause_manager.gd:37-41)
    - Gracefully handle missing state store in test environments
    - Applied same graceful store handling to M_SpawnManager (scripts/managers/m_spawn_manager.gd:37-41)
  - **TESTS FIXED**:
    - test_navigation_open_and_close_pause_overlay ✓
    - test_pause_system_applies_engine_pause ✓
    - test_clears_stale_state_when_ui_empty ✓
  - **DOCUMENTATION**: Added M_PauseManager initialization timing pitfall to DEV_PITFALLS.md

### M_SceneManager Cleanup

- [ ] T022 Remove ALL pause/cursor control from `M_SceneManager`:
  - Rename `_update_pause_state()` → `_update_particles_and_focus()`.
  - Remove `get_tree().paused` writes.
  - Remove `M_CursorManager.set_cursor_state()` calls.
  - Remove `U_GAMEPLAY_ACTIONS.pause_game()` / `unpause_game()` dispatches.
  - Remove `_update_cursor_for_scene()` method entirely.
  - Remove `U_GAMEPLAY_ACTIONS` import (no longer needed).
  - Retain ONLY particle pause logic (GPU particle workaround for SceneTree pause).

### Codebase Audit

- [x] T023 Audit entire codebase for pause/cursor authority violations:
  - Search for `get_tree().paused =` - only M_PauseManager should write. ✓
  - Search for `Input.mouse_mode =` - only M_CursorManager should write. ✓
  - Search for `M_CursorManager.set_cursor_state(` - only M_PauseManager should call. ✓
  - Document any read-only pause checks (safe to keep). ✓
  - **Result**: ✅ Production code fully compliant. 1 minor violation in legacy test scene (state_test_us4.gd). See `phase2-authority-audit.md`.

### Root Scene Integration

- [x] T024a Add M_PauseManager to `root.tscn`:
  - Add as child of Managers node.
  - Place AFTER M_StateStore, M_SceneManager, M_CursorManager in node order.
  - Verify initialization order in manager_ready signals.

### Test Updates

- [x] T024b Update pause-related integration tests:
  - Add M_PauseManager instances to test setups.
  - Add `await get_tree().process_frame` or `await wait_physics_frames(2)` after state changes.
  - **Tests requiring updates**:
    - `test_pause_system.gd` - scene tree pause/unpause via overlays.
    - `test_particles_pause.gd` - particle speed_scale during pause.
    - `test_pause_settings_flow.gd` - pause → settings → resume flow.
    - `test_cursor_reactive_updates.gd` - cursor state changes on scene transitions.
  - Ensure tests verify M_PauseManager is sole authority (no M_SceneManager pause/cursor calls).

### Main Menu Cursor Verification

- [x] T024c Verify main menu cursor behavior:
  - Manual test: Launch game → main menu should have visible, unlocked cursor.
  - Verify SceneType.MENU scenes get cursor visible & unlocked from M_PauseManager.
  - **NEW**: Add explicit test for main menu cursor state on boot.

### Final Validation

- [x] T025 Run full integration test suite:
  - Scene manager tests (all).
  - Pause system tests.
  - Input/navigation tests.
  - Verify no regressions in cursor behavior during transitions.
  - **NEW**: Run tests multiple times to catch race conditions.

### Manual Testing (Post-Phase 2)

- [ ] T026 Perform manual pause/unpause testing:
  - **Pause/Unpause Flow**:
    - Start game → press ESC → verify game pauses, cursor visible
    - Press ESC/resume → verify game unpauses, cursor hides (gameplay)
  - **Nested Overlay Flow**:
    - Pause → Settings → verify stays paused, settings replaces pause
    - Back → verify pause restored, still paused
    - Resume → verify unpauses, cursor hides
  - **Scene Transitions with Overlays**:
    - Pause during gameplay → Quit to Menu → verify transition completes, no stuck pause
    - Verify main menu has visible cursor, not paused
  - **Cursor State Across Scene Types**:
    - Gameplay: cursor hidden & locked (when not paused)
    - Gameplay + Pause: cursor visible & unlocked
    - Menu/UI scenes: cursor visible & unlocked
    - End game scenes: cursor visible & unlocked
  - **Bootstrap/Startup**:
    - Close and restart game → verify starts unpaused
    - Verify no error spam in console
    - Verify pause system initializes without warnings
  - **Edge Cases**:
    - Rapid ESC spam → verify pause state stays consistent
    - Scene transition during pause → verify new scene loads with correct state
    - Multiple nested overlays → verify each layer restores correctly
  - **Watch for Regressions**:
    - Game stuck paused after closing overlay
    - Cursor visible during gameplay
    - Cursor locked in menus
    - Console errors about missing state store
    - Pause state not syncing with overlay presence
    - Input not working after unpause
  - **Test Environments**: Editor play mode (F5/F6) and standalone build if available

### Phase 2 Status Summary

**Completed (2025-12-04)**:

**Commit aca7cf9 "Phase 2 - 5 Failed Tests"**:
- ✅ T020: Created `pause-cursor-authority-model.md` (comprehensive authority documentation)
- ✅ T022: Removed pause/cursor control from M_SceneManager (only handles particles now)
- ✅ T024a: Added M_PauseManager to root.tscn in correct initialization order
- ✅ T024b: Updated 5 integration tests (cursor_reactive_updates, particles_pause, pause_settings_flow, pause_system, scene_preloading)

**Staged Changes (Post-aca7cf9 refinements)**:
- ✅ T021: M_PauseManager refactored with synchronous initialization and _process() polling
- ✅ T023: Codebase audit complete - production code fully compliant (see `phase2-authority-audit.md`)
- ✅ Documentation added to DEV_PITFALLS.md (M_PauseManager initialization timing section)
- ✅ M_SpawnManager updated to gracefully handle missing state store
- ✅ UIInputHandler debug logs removed
- ✅ All unit tests passing (132/136 passed, 4 pending/skipped for tween timing)
- ✅ All integration tests passing

**Remaining Tasks (Manual Testing Only)**:
- T024c: Verify main menu cursor behavior (manual test - USER CONFIRMED PASSING)
- T025: Run full integration test suite (automated tests all passing)
- T026: Perform manual pause/unpause testing (user manual testing)

**Next Step**: User confirms manual testing passes, then commit staged changes and mark Phase 2 complete.

---

## Phase 3 – Naming & Prefix Migration

- [ ] T030 From the Phase 0 inventory, decide on a **canonical prefix** for each ambiguous category (e.g., `ui_*` vs. `sc_*` for UI scenes).
- [ ] T031 Rename UI scripts and scenes where necessary to match the updated prefix rules:
  - Update script filenames, class names (if needed), and `.tscn` references.
- [ ] T032 Review and normalize marker scripts under `scripts/scene_structure`:
  - Either ensure they follow a documented “marker” naming pattern or adjust the style guide to include their existing names as intentional exceptions.
- [ ] T033 Normalize any debug/test/helper scenes and resources that are missing prefixes:
  - Align with a `debug_` / `test_` / `sc_debug_*` pattern as defined in `STYLE_GUIDE.md`.
- [ ] T034 Re‑run the full Godot test suite after each logical group of renames (UI, debug, markers, etc.) to catch broken references early.

---

## Phase 4 – Tests & Tooling Hardening

- [ ] T040 Extend `tests/unit/style/test_style_enforcement.gd` to:
  - Validate prefix patterns for `.gd` scripts in `scripts/ecs`, `scripts/state`, `scripts/ui`, `scripts/managers`, `scripts/gameplay`, `scripts/scene_structure`.
- [ ] T041 Add tests (either in style suite or a separate file) that:
  - Validate `.tscn` scene names in `scenes/gameplay` and `scenes/ui` match expected naming patterns.
  - Validate `.tres` resources in key directories match documented `RS_` or other resource prefixes.
- [ ] T042 Introduce allowlists in style tests for documented exceptions:
  - Marker scripts.
  - Base classes.
  - Any legacy/test assets intentionally kept.
- [ ] T043 Add or update scene organization tests that:
  - Assert root and gameplay scenes contain required groups and marker scripts.
  - Fail loudly if future changes violate structure without updating the guide.

---

## Phase 5 – Docs & Planning Alignment

- [ ] T050 Reconcile ECS documentation (`docs/ecs/*`) with current implementation:
  - Mark completed refactor phases as such.
  - Move any remaining “future” items into either this cleanup or clearly marked “Deferred” sections.
- [ ] T051 Reconcile State Store documentation (`docs/state store/*`) with current implementation:
  - Ensure mock‑data removal and entity coordination pattern are described as complete.
  - Align tasks/plan with reality.
- [ ] T052 Reconcile Scene Manager documentation (`docs/scene manager/*`) with current implementation:
  - Overlay and navigation changes, camera blending, spawn manager split, preloading.
- [ ] T053 Reconcile Input Manager documentation (`docs/input manager/*`) with current implementation:
  - Profiles, rebinding, touchscreen support, button prompts, device manager behaviour.
- [ ] T054 Reconcile UI Manager documentation (`docs/ui manager/*`) with current implementation:
  - Navigation slice, UI registry, settings hub, overlay flattening, UI input handler.
- [ ] T055 Ensure each subsystem’s continuation prompt is updated to:
  - Reflect the new style/scene rules.
  - Reference this cleanup where appropriate.
- [ ] T056 Codify “UI → Redux → Scene Manager” rule:
  - Update UI Manager docs to state that UI scripts must not call `M_SceneManager` directly.
  - Inventory existing direct `M_SceneManager.transition_to_scene` calls in UI scripts and link their refactors to this cleanup plan.

---

## Phase 6 – ECS Entity IDs & Tagging

- [ ] T060 Design an **entity ID model** for ECS:
  - Decide how IDs are assigned (string IDs, optional numeric handles).
  - Document how IDs interact with existing entity root naming (`E_*`).
- [ ] T061 Implement core ID support in ECS:
  - Extend `M_ECSManager` and `U_ECSUtils` to track entity IDs and optional tags.
  - Ensure `EntityQuery` can return entity IDs/tags alongside Node references.
- [ ] T062 Integrate entity IDs with state store:
  - Ensure `U_EntityActions` and `U_EntitySelectors` work seamlessly with explicit IDs.
  - Update docs where entity IDs are mentioned.
- [ ] T063 Add tests:
  - New unit tests for ID assignment and tag/index lookups.
  - Integration tests to ensure ECS → State → UI flows still pass with IDs in place.

---

## Phase 7 – Spawn Registry & Spawn Conditions

- [ ] T070 Design a minimal **spawn metadata** structure:
  - List required fields (id, tags, basic conditions).
  - Decide whether to use a Resource type (e.g., `RS_SpawnMetadata`) or plain dictionaries.
- [ ] T071 Implement a `U_SpawnRegistry` (or similar) for spawn metadata:
  - Provide helpers for looking up spawn info by id/tag.
  - Keep it lightweight and focused on current needs.
- [ ] T072 Integrate spawn metadata with `M_SpawnManager`:
  - Allow M_SpawnManager to consult the registry when picking spawn points.
  - Preserve current behaviour as the default when no metadata is present.
- [ ] T073 Add tests:
  - Unit tests for spawn registry lookup and condition evaluation.
  - Integration tests to confirm exterior/interior transitions and checkpoints still work correctly.

---

## Phase 8 – Multi‑Slot Save Manager

- [ ] T080 Design a **multi‑slot save** model:
  - Decide on slot identifiers and file naming (e.g., `save_slot_1.json`).
  - Define a minimal metadata format (last scene, timestamp, etc.).
- [ ] T081 Implement a `M_SaveManager` (or equivalent) that wraps `M_StateStore`:
  - Expose APIs for `save_to_slot(slot_id)`, `load_from_slot(slot_id)`, and listing available slots.
  - Keep serialization logic delegated to `M_StateStore`.
- [ ] T082 Add a basic UI surface for slot selection:
  - A simple overlay or menu panel that lists slots and dispatches actions for save/load.
  - Drive it through navigation/state, not direct Scene Manager calls.
- [ ] T083 Add tests:
  - Unit tests for `M_SaveManager` slot operations and metadata.
  - Integration tests that verify end‑to‑end save/load between different slots.

---

## Phase 9 – Final Validation & Regression Sweep

- [ ] T090 Run full GUT test suites (all categories) and record baseline.
- [ ] T091 Manually verify core user flows:
  - Main menu → gameplay → pause → settings/input overlays → resume.
  - Area transitions exterior ↔ interior_house.
  - Endgame flows (game_over/victory/credits).
- [ ] T092 Spot‑check representative files in each category for prefix/style adherence:
  - Managers, systems, components, UI controllers, resources, markers, debug scenes.
- [ ] T093 Confirm `STYLE_GUIDE.md` and `SCENE_ORGANIZATION_GUIDE.md` examples match actual code and scenes.
- [ ] T094 Update the Cleanup PRD status to “Complete” and add a short summary of what changed.

---

## Notes

- If new gaps are discovered during any phase, add them as new `T0xx`/`T1xx` tasks rather than making undocumented changes.
- When in doubt about naming or structure, prefer updating the guides first, then implementing and testing against them.
