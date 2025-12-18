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

## Next Phase (Phase 2)

Goal: Standardize dependency lookup patterns across the codebase (no new framework).

Standard chain (intent):
1. `@export` injection (tests)
2. `U_ServiceLocator.try_get_service(...)` (production)
3. Group lookup (only where needed for backward compatibility)

Suggested execution order:
1. Inventory all dependency lookups that bypass the standard chain (T120).
2. Decide the "preferred accessor" per dependency and record it (T121).
3. Apply the standard chain to worst offenders first (T122).
4. Add/adjust tests for dependency lookup changes (T123).
5. Add a short "Dependency Lookup Rule" section to DEV_PITFALLS.md if needed (T124).

Focus areas:
- State store: `U_StateUtils.get_store(node)` / `await_store_ready(...)`
- ECS manager: `U_ECSUtils.get_manager(node)`
- Optional managers: `U_ServiceLocator.try_get_service(StringName("..."))`
- Avoid direct field access from helpers (`manager._field`) → use helper methods instead

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

