---
description: "Continuation prompt for hotspot simplification pass (keep this current after each phase)"
created: "2025-12-17"
version: "1.0"
---

# Continuation Prompt: Hotspot Simplification Pass

## Current Status

- **Phase 0 complete**: Baseline snapshot + extraction map + must-pass tests recorded.
- **Phase 1 complete (2025-12-17)**: Extracted 3 helpers under `scripts/scene_management/helpers/`:
  1. **U_SceneTransitionQueue** (~120 lines): Transition queue with priority ordering, dedupe logic, processing state tracking
  2. **U_NavigationReconciler** (~210 lines): Navigation slice reconciliation, base scene transitions, overlay stack reconciliation, guard flags
  3. **U_SceneManagerNodeFinder** (~94 lines): Container discovery (ActiveSceneContainer, UIOverlayStack, overlays), ServiceLocator-first lookup, store reference fallback
- **Results**:
  - Line count: 1149 → 1003 (146 line reduction, 12.7%)
  - Behavior preserved: All guard rails maintained (transition_visual_complete timing, dedupe logic, ServiceLocator-first resolution)
  - Test compatibility: Updated test_transition_dedupe.gd to use helper-based API
- **Committed**: Phase 1 implementation + docs are in git (`8232207`).

## Phase 2 Complete (2025-12-18)

Goal: Standardize dependency lookup patterns across the codebase (no new framework).

- **Lookup chain applied to worst offenders**:
  - Added `U_StateUtils.try_get_store(node)` for silent optional store lookup (injection → ServiceLocator → group).
  - Updated key UI/gameplay “leaf” nodes to prefer `U_ServiceLocator.try_get_service(...)` with group fallback where needed:
    - Input managers: `input_profile_manager`, `input_device_manager`
    - Scene manager signal hookup (`UI_MobileControls`)
  - Updated door trigger (`C_SceneTriggerComponent`) to resolve `scene_manager` via ServiceLocator then group fallback (and fixed inconsistent indentation).
- **Must-pass tests**: Ran and passing:
  - `tests/unit/style/`
  - `tests/unit/scene_management/`
  - `tests/unit/scene_manager/`
  - `tests/unit/integration/`
- **Committed**: Phase 2 implementation is in git (`2b4c67e`), with docs follow-up (`fe09fc1`).

## Phase 3 Complete (2025-12-18)

Goal: Stop runtime `InputMap` mutation in gameplay systems (deterministic bindings).

- **InputMap boot/init authority (Option B)**:
  - Added `scripts/input/u_input_map_bootstrapper.gd` to centralize the required-action set and dev/test-only patching.
  - `M_InputProfileManager` now calls the bootstrapper on startup to avoid brittle missing-action states in dev/test.
- **Gameplay systems no longer mutate InputMap**:
  - `S_InputSystem` now validates required actions once and aborts capture (with a clear error) if misconfigured.
  - `S_SceneTriggerSystem` no longer creates/binds the `interact` action; it validates and short-circuits safely.
- **Project bindings are deterministic**:
  - Updated `project.godot` to include `sprint`, `ui_select`, `ui_focus_next`, `ui_focus_prev` and baseline gamepad bindings for `jump`/`interact`.
- **Regression coverage**:
  - Expanded `tests/unit/input/test_input_map.gd` to assert required actions exist without relying on gameplay systems running first.

- **Must-pass tests**: Ran and passing:
  - `tests/unit/input/`
  - `tests/unit/ecs/systems/`
  - `tests/unit/input_manager/`
  - `tests/unit/style/`

- **Commit needed**: Phase 3 implementation + docs updates are ready for commit (docs commit must be separate from implementation).

## Must-Pass Tests

- `tests/unit/scene_manager/`
- `tests/unit/scene_management/`
- `tests/unit/integration/test_navigation_integration.gd`
- `tests/unit/integration/test_manager_initialization_order.gd`
- `tests/unit/style/test_style_enforcement.gd` (after any helper/script adds/moves/renames)

## Notes / Reminders

- Before editing production code, re-check `docs/general/DEV_PITFALLS.md` and `docs/general/STYLE_GUIDE.md`.
- After completing each phase, update:
  - `docs/general/cleanup/hotspot-simplification-tasks.md` (checkboxes + completion notes)
  - `docs/general/cleanup/hotspot-simplification-continuation-prompt.md`
  - Any impacted planning docs (e.g., `docs/architecture/dependency_graph.md`) if assumptions change
- Commit documentation updates separately from implementation commits.
