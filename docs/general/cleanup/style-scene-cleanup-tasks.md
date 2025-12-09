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

- [x] T026 Perform manual pause/unpause testing:
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

- [x] T030 From the Phase 0 inventory, decide on a **canonical prefix** for each ambiguous category (e.g., `ui_*` vs. `sc_*` for UI scenes).
- [x] T031 Rename UI scripts and scenes where necessary to match the updated prefix rules:
  - Update script filenames, class names (if needed), and `.tscn` references.
- [x] T032 Review and normalize marker scripts under `scripts/scene_structure`:
  - Either ensure they follow a documented "marker" naming pattern or adjust the style guide to include their existing names as intentional exceptions.
- [x] T033 Normalize any debug/test/helper scenes and resources that are missing prefixes:
  - Align with a `debug_` / `test_` / `sc_debug_*` pattern as defined in `STYLE_GUIDE.md`.
- [x] T034 Re‑run the full Godot test suite after each logical group of renames (UI, debug, markers, etc.) to catch broken references early.

### Phase 3 Comprehensive Audit Results (2025-12-05)

**Audit Scope:** Entire codebase (scripts/, scenes/, resources/) excluding addons and docs
**Completion Date:** December 5, 2025
**Overall Compliance:** 91% (scripts: 95.4%, scenes: ~80%, resources: 100%)

#### Scripts Audit Summary (175 files)

**Compliance:** 95.4% (167/175 files compliant)
**Violations:** 8 total

**Critical Issues (1):**
1. `scripts/ui/ui_input_handler.gd` → Should be `scripts/managers/m_ui_input_handler.gd`
   - Miscategorized as UI controller when it's actually a manager
   - Requires file move + rename + all reference updates
   - Breaking change

**High Priority Issues (7):**
2-8. Missing `class_name` declarations in UI controllers:
   - `ui_main_menu.gd` → Add `class_name UI_MainMenu`
   - `ui_credits.gd` → Add `class_name UI_Credits`
   - `ui_game_over.gd` → Add `class_name UI_GameOver`
   - `ui_victory.gd` → Add `class_name UI_Victory`
   - `ui_pause_menu.gd` → Add `class_name UI_PauseMenu`
   - `ui_settings_menu.gd` → Add `class_name UI_SettingsMenu`
   - `ui_hud_controller.gd` → Add `class_name UI_HudController`
   - Non-breaking, safe to add

**Documentation Updates Needed:**
- Add `scripts/ui/utils/u_analog_stick_repeater.gd` to STYLE_GUIDE.md exceptions table
  - Specialized UI navigation helper that doesn't fit standard categorization
  - Similar to existing exceptions like `base_event_bus.gd`

**Strengths:**
- ✅ All managers, systems, components follow naming conventions (100%)
- ✅ All state actions, reducers, selectors follow conventions (100%)
- ✅ All utilities, resources, entity controllers follow conventions (100%)
- ✅ Tab indentation correct throughout (100%)
- ✅ Marker scripts properly exempted (13 files)
- ✅ Base classes properly documented as exceptions (8 files)

#### Scenes Audit Summary (40+ files)

**Compliance:** ~80% (major patterns correct, structural issues present)
**Violations:** 16 total (5 critical, 6 high, 6 medium, 2 low)

**Critical Issues (5):**
1. **Prefab scene naming** - 5 files missing `prefab_*` prefix:
   - `scenes/hazards/death_zone.tscn` → `scenes/prefabs/prefab_death_zone.tscn`
   - `scenes/hazards/spike_trap.tscn` → `scenes/prefabs/prefab_spike_trap.tscn`
   - `scenes/objectives/checkpoint_safe_zone.tscn` → `scenes/prefabs/prefab_checkpoint_safe_zone.tscn`
   - `scenes/objectives/door_trigger.tscn` → `scenes/prefabs/prefab_door_trigger.tscn`
   - `scenes/objectives/goal_zone.tscn` → `scenes/prefabs/prefab_goal_zone.tscn`
   - Impact: Breaks documented `prefab_*` pattern (AGENTS.md line 101, STYLE_GUIDE.md line 71)

**High Severity Issues (6):**
2. **Spawn point hierarchy violations** in ALL 3 gameplay scenes:
   - `gameplay_base.tscn`, `gameplay_exterior.tscn`, `gameplay_interior_house.tscn`
   - Actual: `GameplayRoot/SP_SpawnPoints` (top-level)
   - Expected: `GameplayRoot/Entities/SP_SpawnPoints` (per SCENE_ORGANIZATION_GUIDE.md lines 64-66)
   - Impact: Breaks documented scene organization standard

3. **Camera entity naming** inconsistent in 2 scenes:
   - `gameplay_exterior.tscn` and `gameplay_interior_house.tscn` use `E_Camera`
   - Expected: `E_CameraRoot` (per templates and guide)
   - `gameplay_base.tscn` correctly uses `E_CameraRoot`

**Medium Severity Issues (6):**
4. **Entity container naming** - 3 instances use `E_` prefix incorrectly:
   - `E_Hazards` in exterior and interior (should be `Hazards`)
   - `E_Objectives` in interior (should be `Objectives`)
   - Per guide line 275: only individual entities use `E_` prefix, not containers

5. **UIInputHandler naming** in `root.tscn`:
   - Node name: `UIInputHandler`
   - Expected: `M_UIInputHandler`
   - Matches script naming issue #1 above

6. **Base scene template outdated**:
   - Contains `M_StateStore`, `M_CursorManager` in gameplay scene
   - These now live in `root.tscn` per Phase 2 architecture
   - Template will mislead developers

**Note on Spawn Point Scripts:**
- Individual `sp_*` nodes correctly have `spawn_points_group.gd` marker scripts attached
- This provides editor icons and is the standard pattern for marker scripts
- NOT a violation - working as intended

**Low Severity Issues (3):**
7. **M_GameplayInitializer inconsistency**:
   - Present in `gameplay_base.tscn` and `gameplay_exterior.tscn`
   - Missing in `gameplay_interior_house.tscn`
   - Not documented in SCENE_ORGANIZATION_GUIDE.md

**Strengths:**
- ✅ All gameplay scenes correctly prefixed with `gameplay_*` (100%)
- ✅ All UI scenes correctly prefixed with `ui_*` (100%)
- ✅ Debug scenes correctly prefixed with `debug_*` (100%)
- ✅ Marker script usage perfect (100%)
- ✅ System categorization correct (Core/Physics/Movement/Feedback) (100%)
- ✅ System priority values correct (100%)
- ✅ Node naming (SO_, Env_, S_, M_) correct (100%)
- ✅ Spawn point naming (`sp_*` lowercase) correct (100%)

**Note on M_PauseManager:**
- Not present in any gameplay scenes
- Per current Phase 2 architecture, M_PauseManager lives in `root.tscn` only
- SCENE_ORGANIZATION_GUIDE.md may need update (lines 146 show it in Core systems, but this appears outdated)

#### Resources Audit Summary (57 files)

**Compliance:** 100% - EXEMPLARY ✅
**Violations:** 0

**Perfect Adherence:**
- ✅ All 57 .tres files have proper `script = ExtResource(...)` declarations (100%)
- ✅ All file naming patterns correct (100%)
- ✅ All directory organization correct (100%)
- ✅ UI screen definitions: 11/11 follow `*_screen.tres` or `*_overlay.tres` pattern
- ✅ Scene registry entries: 11/11 properly named and organized
- ✅ Settings resources: 10/10 use appropriate suffixes
- ✅ State resources: 9/9 correctly structured
- ✅ Trigger resources: 7/7 follow `rs_*` prefix pattern
- ✅ Input resources: 9/9 properly categorized in subdirectories

**Status:** Model implementation - no changes needed

#### Phase 3 Action Items (Prioritized)

**Priority 1 - Breaking Changes (Must Coordinate):**
- [x] T035 Refactor `ui_input_handler.gd` → `m_ui_input_handler.gd`:
  - Move file from `scripts/ui/` to `scripts/managers/`
  - Update class name: `UIInputHandler` → `M_UIInputHandler`
  - Update all preload() statements and type hints
  - Update `root.tscn` node name and script attachment
  - Run full test suite to verify no breakage
  - **Estimated Time:** 30-60 minutes
  - **Impact:** Breaking change, requires thorough testing

**Priority 2 - Non-Breaking Quick Wins:**
- [x] T036 Add missing `class_name` declarations to 7 UI controllers:
  - Safe, non-breaking additions
  - Improves autocomplete and type safety
  - **Estimated Time:** 5 minutes

**Priority 3 - Scene Structure Fixes:**
- [x] T037 Rename 5 prefab scenes and consolidate:
  - Move to unified `scenes/prefabs/` directory
  - Add `prefab_*` prefix to all hazard/objective scenes
  - Update all scene references
  - **Estimated Time:** 20-30 minutes

- [x] T038 Fix spawn point hierarchy in 3 gameplay scenes:
  - Move `SP_SpawnPoints` under `Entities` node
  - **Estimated Time:** 10 minutes
  - **Note:** Individual spawn point marker scripts are correct (for editor icons)

- [x] T039 Standardize entity naming:
  - Rename `E_Camera` → `E_CameraRoot` in exterior and interior
  - Rename `E_Hazards` → `Hazards`, `E_Objectives` → `Objectives`
  - **Estimated Time:** 10 minutes

**Priority 4 - Documentation Updates:**
- [x] T040a Update STYLE_GUIDE.md:
  - Add `u_analog_stick_repeater.gd` to exceptions table
  - **Estimated Time:** 2 minutes

- [x] T040b Update SCENE_ORGANIZATION_GUIDE.md:
  - Clarify M_PauseManager location (root.tscn vs gameplay scenes)
  - Document M_GameplayInitializer if standard, or note as experimental
  - **Estimated Time:** 10 minutes

- [x] T040c Update base scene template:
  - Remove `M_StateStore`, `M_CursorManager` from template
  - Align with Phase 2 architecture
  - **Estimated Time:** 5 minutes

#### Compliance Summary by Directory

| Directory | Compliance Rate | Status | Action Needed |
|-----------|----------------|--------|---------------|
| `scripts/` | 95.4% | Excellent | 8 minor fixes |
| `resources/` | 100% | Exemplary | None ✅ |
| `scenes/ui/` | 100% | Excellent | None ✅ |
| `scenes/gameplay/` | ~70% | Needs Work | Structure fixes |
| `scenes/prefabs/` | 0% (wrong location) | Critical | Rename + move |
| `scenes/debug/` | 100% | Excellent | None ✅ |

**Overall Assessment:** Strong foundation with targeted fixes needed in gameplay scene structure and UI input handler categorization. Resources directory is exemplary. Most violations are organizational (hierarchy, naming) rather than functional.

---

## Phase 4 – Tests & Tooling Hardening

- [x] T040 Extend `tests/unit/style/test_style_enforcement.gd` to:
  - Validate prefix patterns for `.gd` scripts in `scripts/ecs`, `scripts/state`, `scripts/ui`, `scripts/managers`, `scripts/gameplay`, `scripts/scene_structure`.
  - **Result**: ✅ Comprehensive prefix validation implemented with directory-specific rules (tests/unit/style/test_style_enforcement.gd:169-183)
- [x] T041 Add tests (either in style suite or a separate file) that:
  - Validate `.tscn` scene names in `scenes/gameplay` and `scenes/ui` match expected naming patterns.
  - Validate `.tres` resources in key directories match documented `RS_` or other resource prefixes.
  - **Result**: ✅ Scene naming validation (test_scenes_follow_naming_conventions) and resource validation (test_resources_follow_naming_conventions) implemented (tests/unit/style/test_style_enforcement.gd:185-229)
- [x] T042 Introduce allowlists in style tests for documented exceptions:
  - Marker scripts.
  - Base classes.
  - Any legacy/test assets intentionally kept.
  - **Result**: ✅ Complete exception lists implemented: BASE_CLASS_EXCEPTIONS, MARKER_SCRIPT_EXCEPTIONS, INTERFACE_EXCEPTIONS, EVENT_BUS_EXCEPTIONS, UTILITY_EXCEPTIONS, TRANSITION_EXCEPTIONS (tests/unit/style/test_style_enforcement.gd:24-73)
- [x] T043 Add or update scene organization tests that:
  - Assert root and gameplay scenes contain required groups and marker scripts.
  - Fail loudly if future changes violate structure without updating the guide.
  - **Result**: ✅ Root structure test (test_scene_organization_root_structure) validates required managers and containers. Gameplay structure test (test_scene_organization_gameplay_structure) validates organizational nodes and spawn point placement (tests/unit/style/test_style_enforcement.gd:231-291)

### Phase 4 Status Summary

**Completed (2025-12-08)**:

**Implementation**:
- ✅ T040: Comprehensive prefix validation with directory-specific rules
- ✅ T041: Scene and resource naming pattern validation
- ✅ T042: Complete exception allowlists for all documented categories
- ✅ T043: Scene organization structure tests for root and gameplay scenes

**Test Coverage Added**:
1. `test_scripts_follow_prefix_conventions()` - Validates all scripts follow STYLE_GUIDE.md prefix matrix
2. `test_scenes_follow_naming_conventions()` - Validates scene files use correct prefixes (gameplay_, ui_, prefab_, debug_)
3. `test_resources_follow_naming_conventions()` - Validates UI screen definitions follow naming patterns
4. `test_scene_organization_root_structure()` - Validates root.tscn contains required managers and containers
5. `test_scene_organization_gameplay_structure()` - Validates gameplay scenes follow SCENE_ORGANIZATION_GUIDE.md structure

**Test Results**: All 7 tests passing (18 assertions total)
- ✅ Prefix compliance: 100% (all production scripts follow documented patterns)
- ✅ Scene naming: 100% (gameplay, UI, prefab, debug scenes all compliant)
- ✅ Scene structure: 100% (root and gameplay scenes match documentation)

**Files Modified**:
- `tests/unit/style/test_style_enforcement.gd` - Extended with 5 new tests and comprehensive validation logic

**Next Step**: Phase 5 - Docs & Planning Alignment

---

## Phase 5 – Docs & Planning Alignment

- [x] T050 Reconcile ECS documentation (`docs/ecs/*`) with current implementation:
  - ✅ Marked refactor as COMPLETE in PRD/plan (Batches 1-4 complete, debugger tooling de-scoped)
  - ✅ Updated continuation prompt with completion summary
  - ✅ All future items clearly marked as deferred
- [x] T051 Reconcile State Store documentation (`docs/state store/*`) with current implementation:
  - ✅ PRD already marked PRODUCTION READY (Phases 1-16.5 complete, mock data removed)
  - ✅ Entity coordination pattern documented and complete
  - ✅ Tasks/plan aligned with reality
- [x] T052 Reconcile Scene Manager documentation (`docs/scene manager/*`) with current implementation:
  - ✅ Marked as PRODUCTION READY in PRD (all phases complete, post-hardening complete)
  - ✅ Continuation prompt already shows completion status
  - ✅ All features (overlay, navigation, camera blending, spawn manager, preloading) implemented
- [x] T053 Reconcile Input Manager documentation (`docs/input manager/*`) with current implementation:
  - ✅ Marked as PRODUCTION READY in PRD
  - ✅ All features (profiles, rebinding, touchscreen, button prompts, device manager) implemented
- [x] T054 Reconcile UI Manager documentation (`docs/ui manager/*`) with current implementation:
  - ✅ Marked as PRODUCTION READY in PRD
  - ✅ All features (navigation slice, UI registry, settings hub, overlay management) implemented
- [x] T055 Ensure each subsystem's continuation prompt is updated to:
  - ✅ ECS: Added Style & Scene Organization section referencing STYLE_GUIDE, SCENE_ORGANIZATION_GUIDE, cleanup project
  - ✅ State Store: Added references to style guides and cleanup project
  - ✅ Scene Manager: Added Critical Notes referencing style/organization guides
  - ✅ Input Manager: Added Style & Organization section
  - ✅ UI Manager: Added style references and UI→Redux→Scene Manager rule note
- [x] T056 Codify "UI → Redux → Scene Manager" rule:
  - ✅ Added "Architectural Rule: UI → Redux → Scene Manager" section to `docs/ui manager/ui-manager-prd.md`
  - ✅ Documented core principle with correct/incorrect examples
  - ✅ Explained rationale (single source of truth, testability, predictability, consistency)
  - ✅ Inventoried 4 violations:
    1. `ui_settings_menu.gd` (lines 14, 185-188)
    2. `ui_input_profile_selector.gd` (lines 13, 161-164)
    3. `ui_input_rebinding_overlay.gd` (lines 14, 740-743)
    4. `ui_touchscreen_settings_overlay.gd` (lines 456-457)
  - ✅ Linked refactoring to this cleanup plan

---

## Phase 6 – ECS Entity IDs & Tagging

### Design Decisions (Approved 2025-12-08)

| Decision | Choice |
|----------|--------|
| ID Assignment | Auto-generated from node name (`E_Player` → `player`), with manual override via export |
| ID Scope | Required for all entities |
| State Store Integration | Loosely coupled (systems manually sync when needed) |
| Tagging | Multiple freeform tags (`Array[StringName]`) |

### T060: Design Entity ID Model ✅ COMPLETE

- [x] T060a Define ID format: `StringName`, auto-generated by stripping `E_` prefix and lowercasing
- [x] T060b Define uniqueness handling: Duplicate IDs get instance ID suffix (e.g., `player_12345`)
- [x] T060c Define tag format: `Array[StringName]` with freeform tags
- [x] T060d Document in plan file: `/Users/mcthaydt/.claude/plans/zesty-sleeping-alpaca.md`

### T061: Implement Core ID Support in ECS

**Step 1: Update `scripts/ecs/base_ecs_entity.gd`**

- [ ] T061a Add const preload at top (following BaseECSComponent pattern):
  ```gdscript
  const U_ECS_UTILS := preload("res://scripts/utils/u_ecs_utils.gd")
  ```
- [ ] T061b Add export variables:
  ```gdscript
  @export var entity_id: StringName = StringName("")
  @export var tags: Array[StringName] = []
  ```
- [ ] T061c Add `get_entity_id() -> StringName`:
  - If `entity_id` is empty, call `_generate_id_from_name()` and cache result
  - Return cached `entity_id`
- [ ] T061d Add `_generate_id_from_name() -> StringName`:
  - Get node name
  - Strip `E_` prefix if present
  - Convert to lowercase
  - Return as `StringName`
- [ ] T061e Add `set_entity_id(id: StringName) -> void` for manager to update on duplicate
- [ ] T061f Add tag methods:
  - `get_tags() -> Array[StringName]` (returns duplicate)
  - `has_tag(tag: StringName) -> bool`
  - `add_tag(tag: StringName) -> void` (appends if not present, notifies manager)
  - `remove_tag(tag: StringName) -> void` (erases if present, notifies manager)
- [ ] T061g Add `_notify_tags_changed() -> void`:
  - Get manager via `U_ECS_UTILS.get_manager(self)` (use const preload from T061a)
  - Call `manager.update_entity_tags(self)` if manager exists

**Step 2: Update `scripts/managers/m_ecs_manager.gd`**

- [ ] T061h Add new member variables:
  ```gdscript
  var _entities_by_id: Dictionary = {}  # StringName → Node
  var _entities_by_tag: Dictionary = {}  # StringName → Array[Node]
  var _registered_entities: Dictionary = {}  # Node → StringName (entity_id)
  ```
- [ ] T061i Define event constants (at top of file):
  ```gdscript
  const EVENT_ENTITY_REGISTERED := StringName("entity_registered")
  const EVENT_ENTITY_UNREGISTERED := StringName("entity_unregistered")
  ```
- [ ] T061j Add `register_entity(entity: Node) -> void`:
  - Return early if null or already registered
  - Get entity ID via `_get_entity_id(entity)`
  - Handle duplicate: append `_%d` suffix with instance ID, log warning, call `entity.set_entity_id()`
  - Add to `_entities_by_id[entity_id] = entity`
  - Add to `_registered_entities[entity] = entity_id`
  - Call `_index_entity_tags(entity)`
  - Publish event: `U_ECSEventBus.publish(EVENT_ENTITY_REGISTERED, {"entity_id": entity_id, "entity": entity})`
- [ ] T061k Add `unregister_entity(entity: Node) -> void`:
  - Return early if null or not registered
  - Get entity_id from `_registered_entities[entity]`
  - Erase from `_entities_by_id`
  - Erase from `_registered_entities`
  - Call `_unindex_entity_tags(entity)`
  - Publish event: `U_ECSEventBus.publish(EVENT_ENTITY_UNREGISTERED, {"entity_id": entity_id, "entity": entity})`
- [ ] T061l Add `get_entity_by_id(id: StringName) -> Node`:
  - Return `_entities_by_id.get(id, null)`
- [ ] T061m Add `get_entities_by_tag(tag: StringName) -> Array[Node]`:
  - Return array of valid entities from `_entities_by_tag[tag]`
  - Filter out invalid instances
- [ ] T061n Add `get_entities_by_tags(tags: Array[StringName], match_all: bool = false) -> Array[Node]`:
  - If `match_all`: entity must have ALL tags
  - If not `match_all`: entity must have ANY tag
  - Deduplicate results
- [ ] T061o Add `get_all_entity_ids() -> Array[StringName]`:
  - Return keys of `_entities_by_id`
- [ ] T061p Add `update_entity_tags(entity: Node) -> void`:
  - Return early if not registered
  - Call `_unindex_entity_tags(entity)`
  - Call `_index_entity_tags(entity)`
- [ ] T061q Add helper methods:
  - `_get_entity_id(entity: Node) -> StringName` - call entity method or fallback to name-based generation
  - `_index_entity_tags(entity: Node) -> void` - add entity to tag arrays
  - `_unindex_entity_tags(entity: Node) -> void` - remove entity from tag arrays
  - `_get_entity_tags(entity: Node) -> Array[StringName]` - call entity method
  - `_entity_has_tag(entity: Node, tag: StringName) -> bool` - call entity method
- [ ] T061r Modify `_track_component()`:
  - After finding entity root, call `register_entity(entity)` if not already registered
  - This auto-registers entities when their first component registers

**Step 3: Update `scripts/utils/u_ecs_utils.gd`**

- [ ] T061s Add `static func get_entity_id(entity: Node) -> StringName`:
  - Call `entity.get_entity_id()` if method exists
  - Fallback: generate from name
- [ ] T061t Add `static func get_entity_tags(entity: Node) -> Array[StringName]`:
  - Call `entity.get_tags()` if method exists
  - Fallback: return empty array

**Step 4: Update `scripts/utils/u_entity_query.gd`**

- [ ] T061u Add `func get_entity_id() -> StringName`:
  - Return `U_ECSUtils.get_entity_id(entity)`
- [ ] T061v Add `func get_tags() -> Array[StringName]`:
  - Return `U_ECSUtils.get_entity_tags(entity)`
- [ ] T061w Add `func has_tag(tag: StringName) -> bool`:
  - Return `get_tags().has(tag)`

### T062: Integrate Entity IDs with State Store

**Step 1: Update `scripts/state/actions/u_entity_actions.gd`**

- [ ] T062a Modify `update_entity_snapshot(entity_id: Variant, snapshot: Dictionary)`:
  - Convert `entity_id` to String: `String(entity_id) if entity_id is StringName else str(entity_id)`
  - This allows passing both `StringName` and `String` IDs
- [ ] T062b Modify `remove_entity(entity_id: Variant)`:
  - Same StringName → String conversion
- [ ] T062c Modify `update_entity_physics()`:
  - Same StringName → String conversion for entity_id parameter

**Step 2: Update `scripts/state/selectors/u_entity_selectors.gd`**

- [ ] T062d Modify `get_entity(state: Dictionary, entity_id: Variant)`:
  - Convert `entity_id` to String before dictionary lookup
- [ ] T062e Modify `get_entity_position()`, `get_entity_velocity()`, `get_entity_rotation()`:
  - Update to use Variant entity_id parameter
- [ ] T062f Modify `is_entity_on_floor()`, `is_entity_moving()`:
  - Update to use Variant entity_id parameter
- [ ] T062g Modify `get_entity_type()`, `get_entity_health()`, `get_entity_max_health()`:
  - Update to use Variant entity_id parameter

**Step 3: Add snapshot builder to `scripts/utils/u_ecs_utils.gd`**

- [ ] T062h Add `static func build_entity_snapshot(entity: Node) -> Dictionary`:
  - Include `entity_id` (as String)
  - Include `tags` (as Array[String])
  - Include `position`, `rotation` if Node3D
  - Include `velocity`, `is_on_floor` if CharacterBody3D
  - Return snapshot dictionary

### T063: Add Tests

**Create `tests/unit/ecs/test_entity_ids.gd`**

- [ ] T063a Create test file following project patterns:
  - Extend `BaseTest` (not GutTest)
  - Add const preloads at top:
    ```gdscript
    const ECS_MANAGER := preload("res://scripts/managers/m_ecs_manager.gd")
    const ECS_ENTITY := preload("res://scripts/ecs/base_ecs_entity.gd")
    const ECS_COMPONENT := preload("res://scripts/ecs/base_ecs_component.gd")
    ```
  - `before_each()`: reset event bus with `U_ECSEventBus.reset()`
  - Helper `_spawn_manager() -> M_ECSManager`: create manager, add_child, autofree, return
  - Helper `_spawn_entity(node_name: String) -> Node3D`: create Node3D, set name, attach script, add_child, autofree, return

- [ ] T063b Add ID generation tests:
  - `test_entity_id_generated_from_name()`: E_Player → "player"
  - `test_entity_id_strips_e_prefix()`: E_Goblin_1 → "goblin_1"
  - `test_entity_id_lowercase()`: E_PLAYER → "player"
  - `test_entity_id_manual_override()`: set entity_id = "hero", verify lookup works

- [ ] T063c Add duplicate ID tests:
  - `test_duplicate_id_gets_suffix()`: two E_Player entities, verify both registered with different IDs
  - `test_duplicate_id_logs_warning()`: verify push_warning called (use GUT's assert_called if available)

- [ ] T063d Add tag tests:
  - `test_entity_tags_indexed()`: entity with tags, verify `get_entities_by_tag` returns it
  - `test_entity_multiple_tags()`: entity with 3 tags, verify appears in all 3 tag lookups
  - `test_get_entities_by_tags_any()`: match_all=false returns entities with ANY tag
  - `test_get_entities_by_tags_all()`: match_all=true returns only entities with ALL tags

- [ ] T063e Add registration/unregistration tests:
  - `test_entity_registered_on_component_add()`: add component to entity, verify entity auto-registered
  - `test_entity_unregister_removes_from_indexes()`: unregister, verify not in ID or tag lookups
  - `test_entity_events_published()`: verify `entity_registered`/`entity_unregistered` events published to `U_ECSEventBus`
    - Use `U_ECSEventBus.get_event_history()` to verify events
    - Call `U_ECSEventBus.reset()` in `before_each()` to clear history

- [ ] T063f Add tag modification tests:
  - `test_add_tag_updates_index()`: add_tag(), verify in tag lookup
  - `test_remove_tag_updates_index()`: remove_tag(), verify not in tag lookup

- [ ] T063g Run tests: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ecs -gtest=test_entity_ids -gexit`

### T064: Migrate Existing Entities (Templates, Prefabs, Scenes)

**Verify and update ALL existing entities with new entity_id and tags fields**

All entities inherit from `base_ecs_entity.gd` (directly or via `base_volume_controller.gd`):
- **Templates**: E_PlayerRoot, E_CameraRoot
- **Prefabs**: E_Checkpoint_SafeZone, E_DeathZone, E_SpikeTrap, E_GoalZone, E_DoorTrigger
- **Scene instances**: E_FinalGoal, E_TutorialSign (in gameplay scenes)

#### Step 1: Templates (T064a-b)

- [ ] T064a Migrate **player_template.tscn**:
  - Open `templates/player_template.tscn` in editor
  - Verify `E_PlayerRoot` shows new export variables (entity_id, tags)
  - Set `entity_id = StringName("player")` (explicit, not auto-generated "playerroot")
  - Set `tags = [StringName("player")]`
  - Save and verify no errors

- [ ] T064b Migrate **camera_template.tscn**:
  - Open `templates/camera_template.tscn` in editor
  - Verify `E_CameraRoot` shows new export variables
  - Set `entity_id = StringName("camera")` (explicit, not "cameraroot")
  - Set `tags = [StringName("camera")]`
  - Save and verify no errors

#### Step 2: Prefabs (T064c-g)

- [ ] T064c Migrate **prefab_checkpoint_safe_zone.tscn**:
  - Open prefab in editor
  - Verify `E_Checkpoint_SafeZone` shows new export variables
  - Set `entity_id = StringName("checkpoint_safezone")` (or leave auto-generated)
  - Set `tags = [StringName("checkpoint"), StringName("objective")]`
  - Save

- [ ] T064d Migrate **prefab_death_zone.tscn**:
  - Open prefab in editor
  - Set `entity_id = StringName("deathzone")` (or leave auto-generated)
  - Set `tags = [StringName("hazard"), StringName("death")]`
  - Save

- [ ] T064e Migrate **prefab_spike_trap.tscn**:
  - Open prefab in editor
  - Set `entity_id = StringName("spiketrap")` (or leave auto-generated)
  - Set `tags = [StringName("hazard"), StringName("trap")]`
  - Save

- [ ] T064f Migrate **prefab_goal_zone.tscn**:
  - Open prefab in editor
  - Set `entity_id = StringName("goalzone")` (or leave auto-generated)
  - Set `tags = [StringName("objective"), StringName("goal")]`
  - Save

- [ ] T064g Migrate **prefab_door_trigger.tscn**:
  - Open prefab in editor
  - Set `entity_id = StringName("doortrigger")` (or leave auto-generated)
  - Set `tags = [StringName("trigger"), StringName("door")]`
  - Save

#### Step 3: Gameplay Scene Instances (T064h-i)

- [ ] T064h Update **gameplay_exterior.tscn** entity instances:
  - Open `scenes/gameplay/gameplay_exterior.tscn`
  - For each E_* instance that is NOT a template instance (E_Player, E_CameraRoot):
    - `E_FinalGoal`: Set `entity_id = StringName("finalgoal")`, `tags = [StringName("objective"), StringName("endgame")]`
    - `E_TutorialSign`: Set `entity_id = StringName("tutorial_exterior")`, `tags = [StringName("interactable"), StringName("tutorial")]`
    - `E_SpikeTrapA`, `E_SpikeTrapB`: Instances inherit from prefab (already has tags)
    - `E_Checkpoint_SafeZone`, `E_DeathZone`, `E_DoorTrigger`: Instances inherit from prefabs
  - Save

- [ ] T064i Update **gameplay_interior_house.tscn** entity instances:
  - Open `scenes/gameplay/gameplay_interior_house.tscn`
  - `E_TutorialSign_Interior`: Set `entity_id = StringName("tutorial_interior")`, `tags = [StringName("interactable"), StringName("tutorial")]`
  - `E_GoalZone`, `E_DeathZone`, `E_DoorTrigger`: Instances inherit from prefabs
  - Save

#### Step 4: Verification (T064j-k)

- [ ] T064j Test base scene template integration:
  - Load `templates/base_scene_template.tscn`
  - Verify `E_Player` instance (from player_template) has entity_id = "player"
  - Verify `E_CameraRoot` instance has entity_id = "camera"
  - Run the scene and check entity registration via M_ECSManager
  - Verify all entities registered with correct IDs

- [ ] T064k Test gameplay scenes:
  - Load `scenes/gameplay/gameplay_exterior.tscn`
  - Run scene, open debugger or console
  - Verify all entities registered with M_ECSManager
  - Verify entity IDs and tags are correct
  - Verify no duplicate ID warnings
  - Repeat for `gameplay_interior_house.tscn`

#### Step 5: Documentation (T064l)

- [ ] T064l Document entity ID mappings in `docs/ecs/ecs_architecture.md`:
  - Add table of all entity types with their IDs and tags
  - Templates: E_PlayerRoot → "player", E_CameraRoot → "camera"
  - Prefabs: E_Checkpoint_SafeZone → "checkpoint_safezone", etc.
  - Scene instances: E_FinalGoal → "finalgoal", E_TutorialSign → "tutorial_exterior", etc.
  - Document tagging strategy (hazard, objective, interactable, etc.)

### Documentation Updates (After Implementation)

- [ ] T063h Update `docs/ecs/ecs_architecture.md`:
  - Section 8.5 "No Entity Abstraction" → mark as RESOLVED
  - Add new section documenting entity ID and tag system
- [ ] T063i Update `AGENTS.md`:
  - Add entity ID/tag patterns to "ECS Guidelines" section
- [ ] T063j Update this file:
  - Mark all T060-T064 tasks complete
  - Add completion summary

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

## Phase 8 – Large File Splitting for Maintainability

**Goal**: Split files over 400 lines into smaller, more maintainable units (~400 lines max)

| File | Current | Target | Helpers |
|------|---------|--------|---------|
| `m_scene_manager.gd` | 1,565 | ~400 | 4 |
| `ui_input_rebinding_overlay.gd` | 1,254 | ~400 | 3 |
| `m_state_store.gd` | 809 | ~400 | 2 |
| `u_input_rebind_utils.gd` | 509 | ~180 | 2 |
| `m_ecs_manager.gd` | 500 | ~380 | 1 |
| `m_input_profile_manager.gd` | 480 | ~350 | 1 |
| `u_scene_registry.gd` | 460 | ~330 | 1 |
| `ui_touchscreen_settings_overlay.gd` | 451 | ~330 | 1 |

### Phase 8A: Scene Manager Split (1,565 → ~400 lines)

- [ ] T080a Create `scripts/scene_management/helpers/u_scene_cache.gd`:
  - Extract: `_is_scene_cached`, `_get_cached_scene`, `_add_to_cache`, `_check_cache_pressure`, `_evict_cache_lru`, `_get_cache_memory_usage`
  - Extract: `_preload_critical_scenes`, `_start_background_load_polling`, `hint_preload_scene`
  - Include cache member variables: `_scene_cache`, `_cache_access_times`, `_background_loads`, `_max_cached_scenes`, `_max_cache_memory`

- [ ] T080b Create `scripts/scene_management/helpers/u_scene_loader.gd`:
  - Extract: `_load_scene`, `_load_scene_async`, `_add_scene`, `_remove_current_scene`
  - Extract: `_validate_scene_contract`, `_find_player_in_scene`, `_unfreeze_player_physics`

- [ ] T080c Create `scripts/scene_management/helpers/u_overlay_stack_manager.gd`:
  - Extract: `push_overlay`, `pop_overlay`, `push_overlay_with_return`, `pop_overlay_with_return`
  - Extract: `_configure_overlay_scene`, `_get_top_overlay_id`, `_restore_focus_to_top_overlay`, `_find_first_focusable_in`
  - Extract: `_reconcile_overlay_stack`, `_get_overlay_scene_ids_from_ui`, `_overlay_stacks_match`, `_update_overlay_visibility`

- [ ] T080d Refactor `m_scene_manager.gd` to use helpers:
  - Add const preloads for all 3 new helpers
  - Replace extracted methods with delegation calls
  - Keep: Node lifecycle, store subscription, transition queue, public API wrappers, signals
  - Verify ~400 lines remaining

- [ ] T080e Update external references to M_SceneManager:
  - Search for `M_SceneManager.` calls and verify still work
  - Search for `hint_preload_scene` calls and update if signature changed

- [ ] T080f Run scene manager tests:
  - `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration/scene_manager -gexit`
  - `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/scene_management -gexit`

### Phase 8B: Input Rebinding Overlay Split (1,254 → ~400 lines)

- [ ] T081a Create `scripts/ui/helpers/u_rebind_action_list_builder.gd`:
  - Extract: `_build_action_rows`, `_collect_actions`, `_categorize_actions`, `_format_action_name`, `_add_spacer`
  - Extract: `ACTION_CATEGORIES` constant, `EXCLUDED_ACTIONS` constant
  - Extract: `_refresh_bindings`, `_populate_binding_visuals`, `_get_event_device_type`

- [ ] T081b Create `scripts/ui/helpers/u_rebind_capture_handler.gd`:
  - Extract: `_begin_capture`, `_cancel_capture`, `_input`, `_handle_captured_event`
  - Extract: `_apply_binding`, `_build_final_target_events`, `_build_final_conflict_events`
  - Extract: `_get_action_events`, `_append_unique_event`, `_clone_event`, `_events_match`

- [ ] T081c Create `scripts/ui/helpers/u_rebind_focus_navigation.gd`:
  - Extract: `_configure_focus_neighbors`, `_apply_focus`, `_navigate`, `_navigate_focus`
  - Extract: `_cycle_row_button`, `_cycle_bottom_button`, `_focus_next_action`, `_focus_previous_action`
  - Extract: `_ensure_row_visible`, `_connect_row_focus_handlers`

- [ ] T081d Refactor `ui_input_rebinding_overlay.gd` to use helpers:
  - Add const preloads for all 3 new helpers
  - Replace extracted methods with delegation calls
  - Keep: Node references, lifecycle, signal connections, profile manager integration, dialogs
  - Verify ~400 lines remaining

- [ ] T081e Run input rebinding tests:
  - `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/input -gexit`
  - `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration/input -gexit`

### Phase 8C: State Store Split (809 → ~400 lines)

- [ ] T082a Create `scripts/state/utils/u_state_persistence.gd`:
  - Extract: `save_state`, `load_state`
  - Extract: `_normalize_loaded_state`, `_normalize_scene_slice`, `_normalize_gameplay_slice`
  - Extract: `_normalize_spawn_reference`, `_as_string_name`, `_is_scene_registered`
  - Include: DEFAULT_SCENE_ID, DEFAULT_SPAWN_POINT, SPAWN_PREFIX, CHECKPOINT_PREFIX constants

- [ ] T082b Create `scripts/state/utils/u_state_slice_manager.gd`:
  - Extract: `register_slice`, `validate_slice_dependencies`, `_has_circular_dependency`
  - Extract: `_initialize_slices`, `_apply_reducers`

- [ ] T082c Refactor `m_state_store.gd` to use helpers:
  - Add const preloads for both new helpers
  - Replace extracted methods with delegation calls
  - Keep: `dispatch`, `subscribe`, `get_state`, `get_slice`, StateHandoff, debug overlay, performance metrics
  - Verify ~400 lines remaining

- [ ] T082d Run state store tests:
  - `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/state -gexit`
  - `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration/state -gexit`

### Phase 8D: Input Rebind Utils Split (509 → ~180 lines)

- [ ] T083a Create `scripts/utils/u_input_event_serialization.gd`:
  - Extract: `event_to_dict`, `dict_to_event`
  - Extract: All `_*_to_dict` and `_dict_to_*` helper methods

- [ ] T083b Create `scripts/utils/u_input_event_display.gd`:
  - Extract: `format_event_label`, `_format_joypad_button_label`, `_format_joypad_axis_label`
  - Extract: `get_texture_for_event`

- [ ] T083c Refactor `u_input_rebind_utils.gd` to use helpers:
  - Add const preloads for both new utilities
  - Replace extracted methods with delegation calls
  - Keep: `ValidationResult`, `validate_rebind`, `rebind_action`, `get_conflicting_action`, `is_reserved_action`
  - Verify ~180 lines remaining

- [ ] T083d Update external references:
  - Search for `U_InputRebindUtils.event_to_dict` and update to use new utility
  - Search for `U_InputRebindUtils.format_event_label` and update to use new utility
  - Run input tests to verify

### Phase 8E: Minor Splits

#### ECS Manager (500 → ~380 lines)

- [ ] T084a Create `scripts/ecs/helpers/u_ecs_query_metrics.gd`:
  - Extract: `_record_query_metrics`, `_compare_query_metrics`, `_enforce_query_metric_capacity`
  - Extract: `_compare_metric_keys_by_recency`, `get_query_metrics`, `clear_query_metrics`

- [ ] T084b Refactor `m_ecs_manager.gd` to use helper and run ECS tests

#### Input Profile Manager (480 → ~350 lines)

- [ ] T085a Create `scripts/managers/helpers/u_input_profile_loader.gd`:
  - Extract: `_load_available_profiles`, `load_profile`, `_apply_profile_to_input_map`
  - Extract: `_apply_profile_accessibility`, `_is_same_device_type`

- [ ] T085b Refactor `m_input_profile_manager.gd` to use helper and run tests

#### Scene Registry (460 → ~330 lines)

- [ ] T086a Create `scripts/scene_management/helpers/u_scene_registry_loader.gd`:
  - Extract: `_load_resource_entries`, `_load_entries_from_dir`, `_backfill_default_gameplay_scenes`

- [ ] T086b Refactor `u_scene_registry.gd` to use helper and run tests

#### Touchscreen Settings Overlay (451 → ~330 lines)

- [ ] T087a Create `scripts/ui/helpers/u_touchscreen_preview_builder.gd`:
  - Extract: Preview building and positioning logic

- [ ] T087b Refactor `ui_touchscreen_settings_overlay.gd` to use helper and run tests

### Phase 8F: Validation & Documentation

- [ ] T088a Run full test suite:
  - `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -ginclude_subdirs -gexit`
  - Document any failures and fix

- [ ] T088b Verify line counts:
  - Confirm all split files are under 400 lines
  - Confirm original files are reduced to target sizes

- [ ] T089a Update STYLE_GUIDE.md:
  - Add new `helpers/` subdirectory patterns
  - Document helper file naming convention (`u_*_helper.gd` or `u_*_builder.gd`)

- [ ] T089b Update AGENTS.md:
  - Add note about helper extraction pattern for large files
  - Reference new helper locations in Repo Map

---

## Phase 9 – Multi‑Slot Save Manager

- [ ] T090 Design a **multi‑slot save** model:
  - Decide on slot identifiers and file naming (e.g., `save_slot_1.json`).
  - Define a minimal metadata format (last scene, timestamp, etc.).
- [ ] T091 Implement a `M_SaveManager` (or equivalent) that wraps `M_StateStore`:
  - Expose APIs for `save_to_slot(slot_id)`, `load_from_slot(slot_id)`, and listing available slots.
  - Keep serialization logic delegated to `M_StateStore`.
- [ ] T092 Add a basic UI surface for slot selection:
  - A simple overlay or menu panel that lists slots and dispatches actions for save/load.
  - Drive it through navigation/state, not direct Scene Manager calls.
- [ ] T093 Add tests:
  - Unit tests for `M_SaveManager` slot operations and metadata.
  - Integration tests that verify end‑to‑end save/load between different slots.

---

## Phase 10 – Final Validation & Regression Sweep

- [ ] T100 Run full GUT test suites (all categories) and record baseline.
- [ ] T101 Manually verify core user flows:
  - Main menu → gameplay → pause → settings/input overlays → resume.
  - Area transitions exterior ↔ interior_house.
  - Endgame flows (game_over/victory/credits).
- [ ] T102 Spot‑check representative files in each category for prefix/style adherence:
  - Managers, systems, components, UI controllers, resources, markers, debug scenes.
- [ ] T103 Confirm `STYLE_GUIDE.md` and `SCENE_ORGANIZATION_GUIDE.md` examples match actual code and scenes.
- [ ] T104 Update the Cleanup PRD status to "Complete" and add a short summary of what changed.

---

## Notes

- If new gaps are discovered during any phase, add them as new `T0xx`/`T1xx` tasks rather than making undocumented changes.
- When in doubt about naming or structure, prefer updating the guides first, then implementing and testing against them.
