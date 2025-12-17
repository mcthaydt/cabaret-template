---
description: "Continuation prompt for hotspot simplification pass (keep this current after each phase)"
created: "2025-12-17"
version: "1.0"
---

# Continuation Prompt: Hotspot Simplification Pass

## Current Status

- Phase 0 complete: baseline snapshot + extraction map + must-pass tests recorded in `docs/general/cleanup/hotspot-simplification-tasks.md`.
- No production code changes yet (docs-only milestone).

## Next Phase (Phase 1)

Goal: make `scripts/managers/m_scene_manager.gd` a thin coordinator by extracting 3–5 helpers under `scripts/scene_management/helpers/` without behavior changes.

Suggested execution order:
1. Decide helper list and write it into **Notes** (T110).
2. Extract transition queue (priority + dedupe + processing state).
3. Extract navigation reconciliation (navigation slice → base scene + overlay reconciliation).
4. Consider extracting container discovery/wiring if it keeps the manager readable.
5. Keep existing helpers as dependencies; avoid creating new singletons.

Guard rails to preserve:
- `transition_visual_complete` must still fire after visual completion.
- Dedupe logic: same `(scene_id, transition_type)` keeps higher priority.
- ServiceLocator-first dependency resolution must remain test-friendly.

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

