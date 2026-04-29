# Phase 5 — Builder-Backed Base Scene + 2.5D Demo Entry Cleanup

**Date**: 2026-04-29
**Branch**: `cleanup-v8`
**Predecessors**: Phases 1–4, 6–8 all COMPLETE

---

## 1. Goal

Clean the template's scene tree to reflect its identity as a 2.5D game template. One canonical builder-backed base scene (`tmpl_base_scene.tscn`), one clean blockout room as the demo entry point, and all legacy demo/temp scenes deleted.

---

## 2. Scope Boundaries

**In Phase 5:**
- Scene inventory with keep/delete classification
- Extend `tmpl_base_scene.tscn` with 2.5D-oriented Node3D container structure
- One blockout room (4 walls, roof, floor, spawn) via `U_EditorBlockoutBuilder`
- Rewire scene manifest/registry to boot to the new room
- Delete all 28 `scenes/demo/*.tscn` + all 21 `scripts/demo/editors/build_*.gd`
- Inventory consistency test

**Deferred to later phases:**
- Directional sprite characters
- Stepped camera rotation
- Camera-relative movement
- Dialogue, narrative, cutscene, encounter loops

---

## 3. Milestones

### P5.1 — Scene Inventory

**Commit 1 (doc):** `docs/history/cleanup_v8/phase5-scene-inventory.md`

Classification:
| Category | Files | Count |
|---|---|---|
| Keep (core base/template) | `scenes/core/templates/*.tscn` | 4 |
| Keep (core gameplay) | `scenes/core/gameplay/*.tscn` | 2 |
| Keep (core prefab) | `scenes/core/prefabs/*.tscn` | 8 |
| Keep (core debug) | `scenes/core/debug/*.tscn` | 2 |
| Keep (core UI) | `scenes/core/ui/**/*.tscn` | ~23 |
| Keep (core root) | `scenes/core/root.tscn` | 1 |
| Keep (demo -- new) | P5.3 blockout room scene | 1 |
| Delete | All `scenes/demo/**/*.tscn` | 28 |
| Delete | `scripts/demo/editors/build_*.gd` | 21 |

**Commit 2 (RED):** Inventory consistency test asserts disk matches inventory.

### P5.2 — Canonical Base Scene (2.5D-Oriented)

**Commit 1 (RED):** Integration test loads `tmpl_base_scene.tscn`, verifies Node3D world container with child markers for CameraRig, SpawnPoints, SceneObjects, Environment.

**Commit 2 (GREEN):** Extend `tmpl_base_scene.tscn` with Node3D container and marker children.

### P5.3 — Builder-Backed Demo Entry Rebuild

**Commit 1 (RED):** Smoke test: manifest's sole GAMEPLAY entry loads from base template, has `sp_default`, has camera, no fake/temp deps.

**Commit 2 (GREEN):** Blockout builder script -- 4 walls, roof, floor, spawn point via `U_EditorBlockoutBuilder`.

**Commit 3 (GREEN):** Rewire manifest (strip all demo entries, add room), registry (remove door pairings), config (retry_scene_id), splash screen (remove ai_showcase preload).

### P5.4 — Prefab Normalization

No-op unless core prefabs need adjustment. Builder smoke tests if changes made.

### P5.5 — Temp/Fake Scene Deletion

**Commit 1:** Atomic commit deleting all delete-classified files. Inventory test turns GREEN.

---

## 4. Files Changed/Deleted

| Action | Path | Reason |
|---|---|---|
| CREATE | `docs/history/cleanup_v8/phase5-scene-inventory.md` | P5.1 inventory doc |
| CREATE | `tests/unit/style/test_scene_inventory_consistency.gd` | P5.1 consistency test |
| CREATE | `tests/integration/test_base_scene_contract.gd` | P5.2 integration test |
| CREATE | `tests/integration/test_demo_entry_smoke.gd` | P5.3 smoke test |
| CREATE | `scripts/demo/editors/build_gameplay_demo_room.gd` | P5.3 blockout builder |
| CREATE | `scenes/demo/gameplay/gameplay_demo_room.tscn` | P5.3 generated scene |
| MODIFY | `scenes/core/templates/tmpl_base_scene.tscn` | P5.2 2.5D container structure |
| MODIFY | `scripts/core/scene_management/u_scene_manifest.gd` | P5.3 strip demo entries, add room |
| MODIFY | `scripts/core/scene_management/u_scene_registry.gd` | P5.3 remove door pairings |
| MODIFY | `resources/core/cfg_game_config.tres` | P5.3 update retry_scene_id |
| MODIFY | `scripts/core/ui/menus/ui_splash_screen.gd` | P5.3 remove ai_showcase preload |
| DELETE | `scenes/demo/` (all 28 .tscn) | P5.5 cut legacy demo |
| DELETE | `scripts/demo/editors/build_*.gd` (21 files) | P5.5 cut legacy builders |

---

## 5. Commit Sequence

| # | Phase | Markers | Summary |
|---|---|---|---|
| 1 | P5.1 | -- | phase5-scene-inventory.md |
| 2 | P5.1 | (RED) | Inventory consistency test |
| 3 | P5.2 | (RED) | Base scene contract integration test |
| 4 | P5.2 | (GREEN) | Extend tmpl_base_scene.tscn with Node3D/2.5D containers |
| 5 | P5.3 | (RED) | Demo-entry smoke test |
| 6 | P5.3 | (GREEN) | Blockout builder script for demo room |
| 7 | P5.3 | (GREEN) | Rewire manifest, registry, config, splash |
| 8 | P5.4 | -- | Prefab normalization (no-op or adjustments) |
| 9 | P5.5 | (GREEN) | Delete legacy demo scenes + builder scripts |

---

## Verification Checklist

- [ ] P5.2 base scene test green against `tmpl_base_scene.tscn`
- [ ] P5.3 smoke test green -- boots from main menu into the blockout room
- [ ] P5.1 inventory consistency test green -- disk matches inventory exactly
- [ ] P5.4 builder smoke tests green (or no-op)
- [ ] Style enforcement green
- [ ] Full test suite green (minus pre-existing flaky)
- [ ] `docs/systems/2_5d/2_5d-template-pivot-plan.md` remains unchanged
- [ ] No orphaned `.tscn` files
- [ ] `scripts/demo/editors/` contains only `build_gameplay_demo_room.gd`
