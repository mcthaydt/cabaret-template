---
description: "Implementation plan for hotspot simplification (SceneManager helpers, dependency lookup consistency, InputMap determinism)"
created: "2025-12-17"
version: "1.0"
---

# Plan: Hotspot Simplification Pass

## Intent

Refactor-only pass to reduce hotspots (primarily `M_SceneManager`), standardize dependency lookup, and remove runtime `InputMap` mutation from gameplay systems without changing behavior.

## Constraints (Do Not Break)

- Keep `M_SceneManager` public API stable (methods + signal) and preserve queue/overlay semantics.
- Prefer extraction into small helpers over new “frameworks”.
- Preserve existing dependency injection patterns for tests (`@export` on systems, ServiceLocator fallbacks).

## Phases

### Phase 0 — Prep & Safety (Baseline)

- Capture `M_SceneManager` public API snapshot + invariants.
- Create extraction map and pick a helper decomposition target.
- Identify must-pass tests for fast regression loops.

### Phase 1 — Split `M_SceneManager` Into Helpers

Target: `scripts/managers/m_scene_manager.gd` becomes a thin coordinator; complexity moves to `scripts/scene_management/helpers/`.

Suggested helper boundaries:
- Transition queue/priority + de-dupe (`TransitionRequest` lifecycle).
- Navigation reconciliation (`navigation` slice → scene/overlay actions).
- Root/container discovery wiring (ActiveSceneContainer/UIOverlayStack/overlays).

Keep/lean on existing helpers:
- `U_SceneLoader`, `U_SceneCache`, `U_OverlayStackManager`, `U_TransitionOrchestrator`.

### Phase 2 — Dependency Lookup Consistency

Apply standard chain (intent):
1. `@export` injection (tests)
2. `U_ServiceLocator.try_get_service(...)` (production)
3. Group lookup / parent traversal only as a compatibility fallback

Start with gameplay controllers and other “leaf” nodes.

### Phase 3 — InputMap Determinism

- Inventory runtime `InputMap` writes.
- Replace gameplay-system mutation with validation + warnings.
- Ensure required actions exist in `project.godot` + add regression coverage.

### Phase 4 — Validation & Wrap-up

- Run must-pass tests and `tests/unit/style/test_style_enforcement.gd` after any add/move/rename.
- Update tasks/continuation prompt with completion notes + follow-ups.

## Must-Pass Tests (Fast Loop)

- `tests/unit/scene_manager/`
- `tests/unit/scene_management/`
- `tests/unit/integration/test_navigation_integration.gd`
- `tests/unit/integration/test_manager_initialization_order.gd`
- `tests/unit/style/test_style_enforcement.gd`

