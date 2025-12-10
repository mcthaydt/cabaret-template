---
description: "Implementation plan for Style & Scene Organization cleanup"
created: "2025-12-03"
version: "1.0"
---

# Style & Scene Cleanup – Implementation Plan

## Phases Overview

1. **Phase 0 – Discovery & Inventory**
2. **Phase 1 – Spec & Guide Updates**
3. **Phase 2 – Responsibility Consolidation (Pause/Cursor)**
4. **Phase 3 – Naming & Prefix Migration**
5. **Phase 4 – Tests & Tooling Hardening**
6. **Phase 5 – Docs & Planning Alignment**
7. **Phase 6 – ECS Entity IDs & Tagging**
8. **Phase 7 – Spawn Registry & Spawn Conditions**
9. **Phase 8 – Multi‑Slot Save Manager**
10. **Phase 9 – Final Validation & Regression Sweep**

Each phase should be executed with TDD where applicable and small, focused commits (implementation and documentation separated per AGENTS.md).

---

## Phase 0 – Discovery & Inventory

**Goal**: Establish a precise map of all current deviations and edge cases before changing anything.

- Enumerate all `.gd`, `.tscn`, `.tres` files in:
  - `res://scripts/`
  - `res://scenes/`
  - `res://resources/`
- Categorize by directory and expected prefix category:
  - Managers, systems, components, resources, utilities, UI, debug, scene_structure, tests.
- Identify:
  - Files/classes without prefixes.
  - Files/classes with prefixes that do not match their category.
  - Scenes/resources whose names don’t align with their classes.
- Inventory pause/cursor responsibilities:
  - Where `get_tree().paused` is set.
  - Where cursor visibility/lock is toggled.
  - Where gameplay pause flags are written.
- Cross‑check:
  - `STYLE_GUIDE.md` and `SCENE_ORGANIZATION_GUIDE.md` vs. actual code/scenes.
  - PRDs/plans vs. current implementations (note discrepancies, but do not fix yet).

Output: A short “current state” doc or section in tasks describing exactly what needs to change.

---

## Phase 1 – Spec & Guide Updates

**Goal**: Update written standards before changing code, so the implementation has a clear target.

- Extend `STYLE_GUIDE.md`:
  - Add a **prefix matrix** that:
    - Lists all categories (Managers, Systems, Components, Resources, Utilities, UI Controllers, Scene Scripts, Marker Scripts, Base Classes, Tests).
    - Defines allowed filename/class prefixes for each category.
  - Add a **global rule**: every production file must match one of the documented prefix families or exception patterns.
  - Add examples for:
    - Input Manager (device manager, profile manager, rebind utils, serialization).
    - UI Manager (BasePanel, BaseMenuScreen, BaseOverlay, screen controllers, registries).
    - Debug overlays and test/helper scenes.
- Extend `SCENE_ORGANIZATION_GUIDE.md`:
  - Add a **Root Scene** section:
    - Node layout for `scenes/root.tscn`.
    - Role of `Managers`, `ActiveSceneContainer`, `UIOverlayStack`, `TransitionOverlay`, `LoadingOverlay`, `MobileControls`.
  - Update **Gameplay Scene** examples:
    - Reflect actual root naming (`GameplayRoot` or documented equivalent) and marker scripts.
    - Include examples of `E_Hazards`, `E_Objectives`, and signpost controllers with `visual_paths`.
  - Clarify **Interactable Controllers**:
    - Summarize the `E_*` pattern and its relationship to ECS components.
- Add explicit reference in AGENTS/PRDs that new work must follow these updated guides.

No runtime code changes in this phase; only documentation.

---

## Phase 2 – Responsibility Consolidation (Pause/Cursor)

**Goal**: Make pause and cursor control single‑sourced and architecture‑aligned, with `M_PauseManager` as the authority.

- Document the final authority model:
  - `M_PauseManager` is the canonical owner of:
    - Engine pause (`get_tree().paused`).
    - Pause state propagation (signals, store fields).
    - Cursor coordination via `M_CursorManager`.
- Update code:
  - Refactor `M_PauseManager` to:
    - Derive pause from the `navigation` slice (already partly implemented).
    - Apply engine pause and call into `M_CursorManager` as needed.
  - Remove or deprecate direct pause/cursor responsibilities from:
    - `M_SceneManager._update_pause_state()` (ensuring it only manages overlay stack, particles, etc.).
    - Any other systems/managers that set `get_tree().paused` or manage cursor state based on local logic.
- Update tests:
  - Adjust Scene Manager, Input, UI, and Pause tests to:
    - Drive pause flows via navigation actions.
    - Assert that only the designated pause authority manipulates `get_tree().paused`.

This phase should not change user‑visible behaviour; it just centralizes responsibility.

---

## Phase 3 – Naming & Prefix Migration

**Goal**: Bring all code, scenes, and resources into alignment with the updated prefix rules.

- For each category from Phase 0:
  - Propose renames where necessary (scripts, scenes, resources).
  - For base/marker scripts:
    - Either rename to match a new `Base*` or `Marker*` prefix pattern, or
    - Document them as exceptions in the style guide and ensure tests are aware of these exceptions.
- Use a **conservative, incremental approach**:
  - Rename a small set of files at a time (e.g., UI scripts first, then debug, then scene_structure).
  - After each set:
    - Fix up `.tscn` and `.tres` references.
    - Run the full test suite.
  - Prefer editor/open‑and‑save operations where Godot can safely update references.
- Consider whether any public `class_name`s must remain stable for external scripts/tests and adjust migration accordingly (keep class names where possible, rename files only).

Output: All runtime code/assets adhere to the documented naming/prefix rules or documented exceptions.

---

## Phase 4 – Tests & Tooling Hardening

**Goal**: Ensure new rules are enforced continuously by automated tests.

- Extend `tests/unit/style/test_style_enforcement.gd` (or add sibling suites) to:
  - Validate that all `.gd` scripts in key directories:
    - Start with an allowed prefix for their category, or
    - Match an exception pattern (e.g., `main_root_node.gd`, `entities_group.gd`, `base_*`).
  - Optionally, ensure `class_name` matches or is compatible with the file prefix.
- Add scene organization tests (if not already in place) that:
  - Validate gameplay scenes contain required groups and marker scripts.
  - Validate root scene contains required managers and containers.
- Consider adding a small CLI/check script (or GUT test) that can be run as part of CI to enforce prefix and scene organization rules.

No new gameplay logic in this phase; purely enforcement.

---

## Phase 5 – Docs & Planning Alignment

**Goal**: Eliminate drift between PRDs/plans/tasks and actual implementation.

- For each major subsystem:
  - **ECS** – `docs/ecs/*`
  - **State Store** – `docs/state store/*`
  - **Scene Manager** – `docs/scene manager/*`
  - **Input Manager** – `docs/input manager/*`
  - **UI Manager** – `docs/ui manager/*`
  - Reconcile:
    - PRDs: Mark completed phases/features as such, remove outdated “not implemented yet” text.
    - Plans: Annotate cancelled/deferred items explicitly.
    - Tasks: Ensure all completed work is checked `[x]`, and any remaining style/scene work is either:
      - Moved into this cleanup’s task list, or
      - Clearly marked as “deferred, not planned”.
- Update AGENTS and DEV_PITFALLS:
  - Add references to the updated style and scene rules.
  - Emphasize the “check tasks + continuation prompt” discipline for cleanup work as well.

---

## Phase 6 – ECS Entity IDs & Tagging

**Goal**: Introduce explicit entity IDs and optional tagging/indexing to the ECS layer, and integrate them with state snapshots.

- Design an **entity ID model**:
  - Decide how entity IDs are derived/assigned (e.g., stable string IDs, optional numeric handles).
  - Define how IDs are stored on components/entities and exposed to systems.
- Update ECS core:
  - Extend `M_ECSManager` and `U_ECSUtils` to track/entity IDs and optional tags.
  - Ensure `U_EntityQuery` can surface IDs/tags cleanly.
- Integrate with state store:
  - Ensure `U_EntityActions` / `U_EntitySelectors` and `RS_GameplayInitialState` can work with the new ID model without breaking existing flows.
- Add tests:
  - Unit tests for ID assignment, lookup by ID, and basic tagging.
  - Integration tests that confirm ECS → State → UI flows still function with explicit IDs.

---

## Phase 7 – Spawn Registry & Spawn Conditions

**Goal**: Add a simple spawn registry and condition layer on top of the existing `M_SpawnManager`.

- Design spawn metadata (T080):
  - Represent spawn metadata as a dedicated Resource script `rs_spawn_metadata.gd` with `class_name RS_SpawnMetadata` (not plain dictionaries) so spawns are editor‑friendly and covered by existing `RS_` style rules.
  - Required fields:
    - `spawn_id: StringName` – stable identifier for the spawn point (matches the spawn marker’s ID/name used by `M_SpawnManager`).
    - `tags: Array[StringName]` – optional categorisation tags (e.g., `default`, `checkpoint`, `door_target`, `debug`).
    - `priority: int` – simple integer tie‑breaker when multiple candidates are valid; higher priority wins.
    - `condition: int` – enum `SpawnCondition` with values `ALWAYS`, `CHECKPOINT_ONLY`, `DISABLED` to cover basic activation rules without quest logic.
  - Conditions stay intentionally minimal in this phase; more complex predicates (quest flags, story beats, etc.) can be layered on later without changing existing metadata.
- Implement a spawn registry:
  - Add a `U_SpawnRegistry` or equivalent static helper for describing spawn points and tags.
  - Integrate with `M_SpawnManager` where appropriate (without over‑engineering for quests yet).
- Conditions:
  - Implement a minimal “condition” concept (e.g., always/never, or simple flags) that can be extended later for quests.
- Tests:
  - Unit tests for registry lookups and basic condition evaluation.
  - Integration tests to ensure existing spawn behaviour (default, checkpoint, door‑target) still works.

---

## Phase 8 – Multi‑Slot Save Manager

**Goal**: Wrap `M_StateStore.save_state/load_state` in a dedicated save manager with multi‑slot support and basic UI.

- Design a `M_SaveManager` (or similar):
  - Decide slot identifiers and on‑disk layout (e.g., `user://save_slot_1.json`, with lightweight metadata).
- Implement manager:
  - Provide APIs for save/load by slot and listing available slots.
  - Delegate actual serialization to `M_StateStore`’s existing save/load methods.
- UI integration:
  - Add a minimal UI overlay or menu panel for selecting slots (can be developer‑centric at first).
  - Wire the UI through navigation/state actions, not directly to Scene Manager.
- Tests:
  - Unit tests for save/load by slot and metadata handling.
  - Integration tests confirming that picking a slot round‑trips state correctly.

---

## Phase 9 – Final Validation & Regression Sweep

**Goal**: Confirm the cleanup delivered on the PRD’s acceptance criteria and did not introduce regressions.

- Run full GUT suites:
  - ECS, state, managers, input, UI, scene_manager, style, and integration tests.
- Manually verify:
  - Core flows (main menu → gameplay → pause → settings/input flows → resume).
  - Area transitions (exterior ↔ interior).
  - Endgame flows (death → game over → retry/menu, victory → credits → menu).
- Spot‑check:
  - Naming/prefixes for new/changed files.
  - Root and gameplay scene hierarchies against `SCENE_ORGANIZATION_GUIDE.md`.
- If any issues are found:
  - Add them as concrete tasks to the cleanup tasks file.
  - Fix them in small, well‑scoped follow‑ups.

Once this phase passes, update the Cleanup PRD’s status to “Complete” and mark the project as at 10/10 for modularity, scalability, architecture, and adherence to style/scene guides.
