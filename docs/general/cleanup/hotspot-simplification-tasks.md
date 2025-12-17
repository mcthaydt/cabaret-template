---
description: "Task checklist for hotspot simplification (SceneManager split, dependency lookup consistency, InputMap determinism)"
created: "2025-12-17"
version: "1.0"
---

# Tasks: Hotspot Simplification Pass

**Goal**: Make the codebase easier to navigate and reason about by shrinking the biggest hotspot (`M_SceneManager`), making dependency lookup consistent, and removing runtime `InputMap` mutation from gameplay systems.

**Non-goals**
- No feature changes or gameplay behavior changes (refactor-only unless a bug is discovered).
- No new architecture frameworks; prefer small helper extraction and existing patterns.
- No “clever” abstractions that hide control flow.

**Progress:** 0% (0 / 18 tasks complete)

---

## Phase 0 — Prep & Safety (Baseline)

- [ ] T100 Re-read `docs/general/DEV_PITFALLS.md` + `docs/general/STYLE_GUIDE.md` before touching code.
- [ ] T101 Capture a “public API snapshot” for `M_SceneManager` (public methods + signals + expected invariants) in **Notes** below.
- [ ] T102 Create an extraction map for `scripts/managers/m_scene_manager.gd`:
  - Major responsibilities/regions (overlays, transition queue, navigation reconciliation, preload/cache, event subscriptions).
  - Candidate helper boundaries (3–5 helpers).
- [ ] T103 Identify the must-pass tests for this refactor (list test files/dirs) and record them in **Links** below.

---

## Phase 1 — Split `M_SceneManager` Into 3–5 Helpers

**Target outcome**
- `scripts/managers/m_scene_manager.gd` becomes “thin coordinator”: public API + wiring + delegation.
- Private complexity moves behind small, named helpers under `scripts/scene_management/helpers/`.
- Helpers remain straightforward: minimal state, explicit inputs/outputs, no hidden singletons.

- [ ] T110 Decide helper list (3–5) and commit to names + responsibilities (record in **Notes**).
  - Suggested buckets: overlay stack, transition queue, navigation reconciliation, scene preload/cache.
- [ ] T111 Extract overlay stack orchestration behind a helper (keep existing `U_OverlayStackManager` in mind; reuse before creating new).
- [ ] T112 Extract transition queue/priority logic behind a helper (enqueue/dequeue, priority ordering, de-dupe rules).
- [ ] T113 Extract navigation reconciliation logic behind a helper (translate store navigation slice → scene/overlay actions).
- [ ] T114 Extract scene preload/cache coordination behind a helper (delegate to `U_SceneCache` / `U_SceneLoader` rather than expanding `M_SceneManager`).
- [ ] T115 Reduce `scripts/managers/m_scene_manager.gd` to a navigable size target (aim: < ~500 LOC) without changing externally-visible behavior.
- [ ] T116 Update `docs/architecture/dependency_graph.md` if any manager dependency edges or initialization assumptions change.

---

## Phase 2 — Standardize Dependency Lookup (No New Framework)

**Standard chain (intent)**
1. `@export` injection (tests)
2. `U_ServiceLocator.try_get_service(...)` (production)
3. Group lookup (only where needed for backward compatibility)

- [ ] T120 Inventory all dependency lookups that bypass the standard chain:
  - `get_nodes_in_group(...)`, parent traversal, direct `get_tree()` searches.
  - Focus on: `state_store`, `scene_manager`, `ecs_manager`, `input_device_manager`, `spawn_manager`, `camera_manager`.
- [ ] T121 Decide the “preferred accessor” per dependency and record it in **Notes**:
  - Store: `U_StateUtils.get_store(node)` / `await_store_ready(...)`
  - ECS manager: `U_ECSUtils.get_manager(node)`
  - Optional managers: `U_ServiceLocator.try_get_service(StringName("..."))`
- [ ] T122 Apply the standard chain to the worst offenders first (start with gameplay controllers like `BaseInteractableController`).
- [ ] T123 Add/adjust tests (or small helper tests) where dependency lookup changes could regress behavior (focus on “works in tests without root” and “works in production via ServiceLocator”).
- [ ] T124 Add a short “Dependency Lookup Rule” section to `docs/general/DEV_PITFALLS.md` (only if new pitfalls are discovered during refactor).

---

## Phase 3 — Stop Runtime `InputMap` Mutation In Gameplay Systems

**Target outcome**
- Gameplay ECS systems do not create/modify actions at runtime (deterministic bindings).
- InputMap setup is performed once during boot/init (or treated as `project.godot` source of truth).

- [ ] T130 Inventory all runtime `InputMap` writes (search for `InputMap.add_action`, `InputMap.action_add_event`, `InputMap.erase_action`, etc.) and list call sites in **Notes**.
- [ ] T131 Choose the single “InputMap initialization authority”:
  - Option A: Treat `project.godot` as canonical; enforce via tests.
  - Option B: A dedicated boot/init step (manager/utility) that only validates and patches missing actions in dev/test. <- this one
- [ ] T132 Remove `InputMap` mutation from `scripts/ecs/systems/s_input_system.gd` (replace with validation + early warnings if actions are missing).
- [ ] T133 Ensure required actions exist in `project.godot` (and keep naming stable; especially `interact` and UI actions).
- [ ] T134 Add a regression test ensuring required actions exist without relying on `S_InputSystem` running first.

---

## Phase 4 — Validation & Wrap-up

- [ ] T140 Run the must-pass test set identified in T103.
- [ ] T141 Re-check `tests/unit/style/test_style_enforcement.gd` if any scripts were added/moved/renamed.
- [ ] T142 Update this tasks file with completion notes + any follow-ups discovered.

---

## Notes

- **M_SceneManager public API snapshot (T101)**:
  - (fill in)
- **Helper boundary decision (T110)**:
  - (fill in)
- **Dependency accessors (T121)**:
  - (fill in)
- **Runtime InputMap write inventory (T130)**:
  - (fill in)

## Links

- Plan:
- Continuation prompt:
- Related docs:
  - `docs/architecture/dependency_graph.md`
  - `docs/general/DEV_PITFALLS.md`
  - `docs/general/STYLE_GUIDE.md`
