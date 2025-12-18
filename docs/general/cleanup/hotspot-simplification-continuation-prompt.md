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
- **Commit needed**: Phase 1 implementation changes ready for commit

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
- **Commit needed**: Phase 2 implementation changes ready for commit

## Next Phase (Phase 3)

Goal: Stop runtime `InputMap` mutation in gameplay systems (deterministic bindings).

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
