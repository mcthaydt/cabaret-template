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
  - **Result**: 2 authorities identified - S_PauseSystem and M_SceneManager (consolidation planned for Phase 2)
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

- [ ] T020 Document the **pause/cursor authority model** in a short note under `docs/general/cleanup/`:
  - Confirm `S_PauseSystem` is the single authority for engine pause and cursor coordination (via `M_CursorManager`).
- [ ] T021 Refactor `S_PauseSystem` to:
  - Derive pause state solely from navigation/state.
  - Set `get_tree().paused` and coordinate cursor via `M_CursorManager`.
- [ ] T022 Remove or deprecate direct pause/cursor control from `M_SceneManager`:
  - Ensure `_update_pause_state()` no longer sets `get_tree().paused` or dispatches gameplay pause actions.
  - Retain or adjust particle pause logic as needed, but base it on the centralized pause signal/state.
- [ ] T023 Audit other systems/managers for `get_tree().paused` usage and:
  - Remove any direct writes that conflict with the new model.
  - If a special case is truly required, document it in DEV_PITFALLS and tests.
- [ ] T024 Update pause‑related tests:
  - Scene Manager pause tests.
  - Input/Navigation pause tests.
  - ECS pause system tests.
  - Ensure they now assert behaviour via the centralized pause authority.

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
