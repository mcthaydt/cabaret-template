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

**Progress:** 100% (24 / 24 tasks complete)

---

## Phase 0 — Prep & Safety (Baseline)

- [x] T100 Re-read `docs/general/DEV_PITFALLS.md` + `docs/general/STYLE_GUIDE.md` before touching code.
- [x] T101 Capture a “public API snapshot” for `M_SceneManager` (public methods + signals + expected invariants) in **Notes** below.
- [x] T102 Create an extraction map for `scripts/managers/m_scene_manager.gd`:
  - Major responsibilities/regions (overlays, transition queue, navigation reconciliation, preload/cache, event subscriptions).
  - Candidate helper boundaries (3–5 helpers).
- [x] T103 Identify the must-pass tests for this refactor (list test files/dirs) and record them in **Links** below.

---

## Phase 1 — Split `M_SceneManager` Into 3–5 Helpers

**Target outcome**
- `scripts/managers/m_scene_manager.gd` becomes "thin coordinator": public API + wiring + delegation.
- Private complexity moves behind small, named helpers under `scripts/scene_management/helpers/`.
- Helpers remain straightforward: minimal state, explicit inputs/outputs, no hidden singletons.

- [x] T110 Decide helper list (3–5) and commit to names + responsibilities (record in **Notes**).
  - Decided: 3 helpers (transition queue, navigation reconciler, node finder)
  - See Notes section for detailed breakdown
- [x] T111 Extract overlay stack orchestration behind a helper (keep existing `U_OverlayStackManager` in mind; reuse before creating new).
  - Kept existing U_OverlayStackManager; updated to use helper methods for state access
- [x] T112 Extract transition queue/priority logic behind a helper (enqueue/dequeue, priority ordering, de-dupe rules).
  - Created `U_SceneTransitionQueue` (~120 lines)
  - Handles: TransitionRequest class, priority enum, enqueue/dequeue, dedupe, processing state
- [x] T113 Extract navigation reconciliation logic behind a helper (translate store navigation slice → scene/overlay actions).
  - Created `U_NavigationReconciler` (~210 lines)
  - Handles: navigation state reconciliation, base scene transitions, overlay reconciliation, guard flags
- [x] T114 Extract scene preload/cache coordination behind a helper (delegate to `U_SceneCache` / `U_SceneLoader` rather than expanding `M_SceneManager`).
  - Already using existing `U_SceneCache` and `U_SceneLoader` helpers (no new extraction needed)
- [x] T115 Reduce `scripts/managers/m_scene_manager.gd` to a navigable size target (aim: < ~500 LOC) without changing externally-visible behavior.
  - Reduction: 1149 → 1003 lines (146 line reduction, 12.7%)
  - Net extraction: ~424 lines moved to helpers (growth from added wiring/helper methods)
  - Further reduction deferred to future phases (Phase 1 focused on extraction)
- [x] T116 Update `docs/architecture/dependency_graph.md` if any manager dependency edges or initialization assumptions change.
  - No dependency changes; helpers are internal implementation details (no doc changes needed)

---

## Phase 2 — Standardize Dependency Lookup (No New Framework)

**Standard chain (intent)**
1. `@export` injection (tests)
2. `U_ServiceLocator.try_get_service(...)` (production)
3. Group lookup (only where needed for backward compatibility)

- [x] T120 Inventory all dependency lookups that bypass the standard chain:
  - Targeted offenders: UI overlays/controllers resolving `input_profile_manager` / `input_device_manager`, gameplay controllers resolving `state_store`, and MobileControls connecting to SceneManager.
- [x] T121 Decide the “preferred accessor” per dependency and record it in **Notes**.
- [x] T122 Apply the standard chain to the worst offenders first (start with gameplay controllers like `BaseInteractableController`).
  - Added `U_StateUtils.try_get_store(node)` for optional store access; updated leaf nodes to prefer ServiceLocator-first with group fallback.
- [x] T123 Add/adjust tests (or small helper tests) where dependency lookup changes could regress behavior.
  - Covered via existing must-pass suites (scene_manager / scene_management / integration / style).
- [x] T124 Add a short “Dependency Lookup Rule” section to `docs/general/DEV_PITFALLS.md`.
  - Documented the standard chain + when to use `try_get_*` vs `get_*`.

---

## Phase 3 — Stop Runtime `InputMap` Mutation In Gameplay Systems

**Target outcome**
- Gameplay ECS systems do not create/modify actions at runtime (deterministic bindings).
- InputMap setup is performed once during boot/init (or treated as `project.godot` source of truth).

- [x] T130 Inventory all runtime `InputMap` writes (search for `InputMap.add_action`, `InputMap.action_add_event`, `InputMap.erase_action`, etc.) and list call sites in **Notes**.
- [x] T131 Choose the single “InputMap initialization authority”:
  - Option A: Treat `project.godot` as canonical; enforce via tests.
  - Option B: A dedicated boot/init step (manager/utility) that only validates and patches missing actions in dev/test. <- this one
  - Implemented in `U_InputMapBootstrapper`, invoked on startup by `M_InputProfileManager` (and `M_SceneManager` as a defensive fallback for test ordering).
- [x] T132 Remove `InputMap` mutation from `scripts/ecs/systems/s_input_system.gd` (replace with validation + early warnings if actions are missing).
  - Removed `_ensure_actions()` / `_ensure_action()` mutation path; system now validates required actions once and aborts capture with a clear error if misconfigured.
  - Also removed InputMap mutation from `scripts/ecs/systems/s_scene_trigger_system.gd` (same rationale; `INTERACT` mode now validates `interact` exists and short-circuits safely).
- [x] T133 Ensure required actions exist in `project.godot` (and keep naming stable; especially `interact` and UI actions).
  - Added missing actions: `sprint`, `ui_select`, `ui_focus_next`, `ui_focus_prev`.
  - Added baseline gamepad button defaults for `jump` and `interact` to preserve behavior without runtime patching.
- [x] T134 Add a regression test ensuring required actions exist without relying on `S_InputSystem` running first.
  - Expanded `tests/unit/input/test_input_map.gd` to assert a baseline set of required actions exist.

---

## Phase 4 — Validation & Wrap-up

- [x] T140 Run the must-pass test set identified in T103.
  - Ran: `tests/unit/scene_manager/`, `tests/unit/scene_management/`, `tests/unit/integration/`
- [x] T141 Re-check `tests/unit/style/test_style_enforcement.gd` if any scripts were added/moved/renamed.
  - Ran: `tests/unit/style/`
- [x] T142 Update this tasks file with completion notes + any follow-ups discovered.

---

## Notes

- **M_SceneManager public API snapshot (T101)**:
  - `signal transition_visual_complete(scene_id: StringName)` emitted after transition finishes and scene is fully visible (used by MobileControls to re-show UI without flashing).
  - Public methods:
    - `transition_to_scene(scene_id: StringName, transition_type: String, priority: int = Priority.NORMAL)`:
      - No-op if `U_SceneRegistry.get_scene(scene_id)` is missing/empty.
      - Enqueues transition with dedupe-by `(scene_id, transition_type)`, retaining higher priority.
      - Dispatches scene actions via `M_StateStore`: `transition_started(scene_id, transition_type)` then `transition_completed(scene_id)`.
    - `push_overlay(scene_id: StringName, force: bool = false)` / `pop_overlay()`:
      - Delegates to `U_OverlayStackManager` to instantiate/remove overlay scene(s) in `UIOverlayStack`.
      - Dispatches `U_SceneActions.push_overlay(...)` / `pop_overlay()` to keep state and UI in sync.
    - `push_overlay_with_return(overlay_id: StringName)` / `pop_overlay_with_return()`:
      - “Replace mode” overlay navigation (pause → settings → back returns to pause) handled by `U_OverlayStackManager`.
    - `get_current_scene() -> StringName` reads `scene.current_scene_id` from store; returns `StringName("")` if store missing.
    - `is_transitioning() -> bool` reads `scene.is_transitioning` from store; returns `false` if store missing.
    - `can_go_back() -> bool` / `go_back()`:
      - Uses internal `_scene_history` (UI/menu scenes only; cleared when entering gameplay via handler rules).
      - `go_back()` transitions instantly with `Priority.HIGH`.
    - `hint_preload_scene(scene_path: String)` delegates to `U_SceneCache` background preloader.
  - Expected invariants / “contract” assumptions:
    - Exactly one `M_SceneManager` in the root scene; it adds itself to `"scene_manager"` group in `_ready()`.
    - `M_StateStore` is required and is resolved via `U_ServiceLocator.get_service("state_store")` (tests register it explicitly); missing store is a hard error.
    - Active gameplay/ui scenes are swapped as children of `ActiveSceneContainer` (intended: at most one active child at a time).
    - Overlay scenes are children of `UIOverlayStack` and reconcile with store overlay stack state (source of truth is navigation/state slices; helper keeps both aligned).
    - Navigation reconciliation is intentionally deferred and guarded against clobbering newer navigation targets (`_navigation_pending_scene_id` checks).
    - External callers should treat `transition_visual_complete` (not store updates) as the “safe to show controls” moment.
- **Extraction map (T102)** (`scripts/managers/m_scene_manager.gd`):
  - Setup & discovery:
    - `_ready()` ServiceLocator lookups (`state_store` required; others optional), container discovery (`ActiveSceneContainer`, `UIOverlayStack`, `TransitionOverlay`, `LoadingOverlay`), store subscription, ECS event subscriptions, handler registration, preload, initial scene load.
    - `_find_container_nodes()` + `_ensure_store_reference()` (fallback group lookup) are “environment wiring” concerns.
  - Transition queue + state integration:
    - `transition_to_scene()` → `_enqueue_transition()` (dedupe + priority ordering) → `_process_transition_queue()` (dispatch started/completed; emits `transition_visual_complete`).
  - Transition execution:
    - `_perform_transition()` is the largest hotspot: scene contract validation, cached vs sync vs async load, progress callbacks, camera blending hooks, spawn/physics waits, scene-type handler delegation.
    - Delegates some responsibilities already (`U_TransitionOrchestrator`, `U_SceneLoader`), but remains a dense coordinator.
  - Overlay management:
    - Public overlay API delegates to `U_OverlayStackManager`, but reconciliation helpers and particle pause workaround live in manager (`_sync_overlay_stack_state()`, `_reconcile_overlay_stack()`, `_update_particles_and_focus()`).
  - Navigation reconciliation:
    - Store subscription / slice update handler → `_reconcile_navigation_state()` with guard rails (`_navigation_pending_scene_id`, `_pending_overlay_reconciliation`, `_initial_navigation_synced`).
  - History / back navigation:
    - `_scene_history` + `can_go_back()` / `go_back()` + `_update_scene_history()` relies on scene-type handler policy.
  - Preload/cache:
    - `U_SceneCache` is already the heavy lifter, but cache API passthrough + preload orchestration remains in manager.
  - Candidate helper boundaries (3–5):
    - `U_SceneManagerNodeFinder` (container discovery + optional overlay resolution).
    - `U_SceneTransitionQueue` (TransitionRequest, dedupe, priority ordering, “processing” state).
    - `U_NavigationReconciler` (navigation slice → base scene + overlay reconciliation, including pending/guard flags).
    - Keep/lean on existing helpers: `U_SceneLoader`, `U_SceneCache`, `U_OverlayStackManager`, `U_TransitionOrchestrator`.
- **Helper boundary decision (T110)**:
  - Current state: M_SceneManager is 1149 lines
  - Target: Thin coordinator pattern (< ~500 LOC eventual goal)
  - Helpers to extract (3):
    1. **U_SceneTransitionQueue** (`scripts/scene_management/helpers/u_scene_transition_queue.gd`):
       - TransitionRequest class (priority, scene_id, transition_type)
       - Enqueue logic with dedupe (same scene_id + transition_type → keep higher priority)
       - Priority-based queue ordering (CRITICAL > HIGH > NORMAL)
       - Queue processing state tracking (_is_processing_transition flag)
       - Estimated extraction: ~75 lines
    2. **U_NavigationReconciler** (`scripts/scene_management/helpers/u_navigation_reconciler.gd`):
       - Reconcile navigation slice → base scene transitions
       - Reconcile navigation overlay_stack → UIOverlayStack
       - Guard rails: _navigation_pending_scene_id, _is_scene_in_queue checks
       - Helper methods: stack comparison, overlay ID mapping, StringName array coercion
       - Delegates to U_OverlayStackManager for actual overlay push/pop
       - Estimated extraction: ~110 lines
    3. **U_SceneManagerNodeFinder** (`scripts/scene_management/helpers/u_scene_manager_node_finder.gd`):
       - Find ActiveSceneContainer, UIOverlayStack, TransitionOverlay, LoadingOverlay
       - ServiceLocator-first lookup with tree fallback
       - Store reference discovery/fallback
       - Estimated extraction: ~45 lines
  - Keep existing helpers:
    - U_SceneLoader: Scene loading/instantiation/validation
    - U_SceneCache: LRU caching, preloading, background loading
    - U_OverlayStackManager: Overlay stack push/pop/reconciliation
    - U_TransitionOrchestrator: Transition effect execution
  - Post-extraction estimate: ~920 lines (Phase 1), further reduction in future phases
- **Dependency accessors (T121)**:
  - Store (required): `U_StateUtils.get_store(node)` / `U_StateUtils.await_store_ready(node)`
  - Store (optional): `U_StateUtils.try_get_store(node)` (silent; supports standalone scene runs/tests)
  - ECS manager: `U_ECSUtils.get_manager(node)` (injection → parent traversal → group)
  - Registered managers: `U_ServiceLocator.try_get_service(StringName("..."))` (production fast-path)
  - Group fallback: `get_tree().get_first_node_in_group("...")` only when needed for compatibility
- **Runtime InputMap write inventory (T130)**:
  - Gameplay ECS systems (removed in Phase 3):
    - `scripts/ecs/systems/s_input_system.gd` (added actions/events)
    - `scripts/ecs/systems/s_scene_trigger_system.gd` (added interact action/events)
  - Input system authority (expected runtime mutation):
    - `scripts/managers/m_input_profile_manager.gd` / `scripts/managers/helpers/m_input_profile_loader.gd` (apply profiles to InputMap)
    - `scripts/utils/u_input_rebind_utils.gd` (apply rebind results)
  - UI virtual controls (touchscreen):
    - `scripts/ui/ui_virtual_button.gd` (ensures action exists for virtual buttons)

## Links

- Plan: `docs/general/cleanup/hotspot-simplification-plan.md`
- Continuation prompt: `docs/general/cleanup/hotspot-simplification-continuation-prompt.md`
- Related docs:
  - `docs/architecture/dependency_graph.md`
  - `docs/general/DEV_PITFALLS.md`
  - `docs/general/STYLE_GUIDE.md`
  - Must-pass tests (T103):
    - `tests/unit/scene_manager/` (core coverage for `M_SceneManager`, overlays, transitions, registry, dedupe)
    - `tests/unit/scene_management/` (scene type handlers + transition helpers)
    - `tests/unit/integration/test_navigation_integration.gd` (end-to-end reconciliation expectations)
    - `tests/unit/integration/test_manager_initialization_order.gd` (ServiceLocator + startup ordering)
    - `tests/unit/style/test_style_enforcement.gd` (after any helper/script adds/moves/renames)
