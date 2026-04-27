# Cross-System Cleanup V8 — Continuation Prompt

## Overview

Implements `docs/history/cleanup_v8/cleanup-v8-tasks.md` in phase order with TDD discipline. V8 is the follow-up to V7.2, addressing structural/organizational debt rather than internal architectural issues.

**Branch**: `cleanup-v8` (off `main`, after `GOAP-AI` merged via PR #16).
**Status**: Phases 1–4 complete. Phase 5 not started (deferred to last per sequencing plan). Phase 6 in progress — P6.1 complete, P6.2 complete, P6.3 complete, P6.4 complete, P6.5 complete, P6.6 complete. Phase 7 not started.
**Next Task**: P6.7 — Scene Registry Migration. Phase 7 queued after P6.12.
**Prerequisite**: V7.2 complete (`e015aff2`). Phase 4 complete (`cbf0fd61`). All 18 P3.5 extension recipes complete (`b0c5b1cd`). P6.1 complete (`ec14181a`). P6.2 complete (`a23270b1`). P6.3 complete (`0cd59475`). P6.4 complete (`c6608c79`). P6.5 complete (`e28d0c30`). P6.6 complete (`fb576449`).

---

## Scope Summary

Seven phases bundled for one goal: make the template LLM-friendly, modular, and ship-ready as a reusable base.

1. **Phase 1 — AI Rewrite (utility-scored BTs).** COMPLETE. Replace GOAP + HTN with behavior trees. Net ~300 LOC reduction.
2. **Phase 2 — Debug/Perf Extraction.** COMPLETE through P2.4. No bare `print()` in managers/systems enforced.
3. **Phase 3 — Docs Split.** COMPLETE. `AGENTS.md` is a 58-line routing index. All 18 extension recipes shipped. ADR structure in place.
4. **Phase 4 — Template vs Demo Split.** COMPLETE (P4.1–P4.10). Scripts, resources, scenes, and assets all split into `core/` and `demo/`. Style suite 89/89.
5. **Phase 5 — Base Scene.** NOT STARTED. Deferred to last (easiest once code is organized).
6. **Phase 6 — LLM-First Fluent Builders.** IN PROGRESS. Replace `.tres` resource authoring with GDScript builder APIs across BT trees, scene registry, input profiles, and QB rules. Reference plan: `~/.claude/plans/stateless-tickling-meerkat.md`.
7. **Phase 7 — EditorScript + PackedScene Builders.** NOT STARTED. Replace hand-authored `.tscn` creation with programmatic GDScript builder APIs (`U_EditorPrefabBuilder`, `U_EditorBlockoutBuilder`). Migrate all demo prefabs to builder scripts. Reference plan: `~/.claude/plans/lets-add-a-new-humming-kay.md`.

---

## Current Status

- **Phase 1**: COMPLETE (P1.1–P1.10). Full BT framework, planner, brain component refactor, all 6 creature BTs migrated, legacy GOAP/HTN deleted.
- **Phase 2**: COMPLETE through P2.4 (`28702b95`). Style recheck 83/83.
- **Phase 3**: COMPLETE. P3.0–P3.6 landed. All 18 extension recipes shipped. `AGENTS.md` is routing index. `DEV_PITFALLS.md` deleted and redistributed into pitfall topic files. ADRs at `docs/architecture/adr/`.
- **Phase 4**: COMPLETE (P4.1–P4.10, `cbf0fd61`).
  - P4.1–P4.4: Scripts split. All scripts in `scripts/core/` or `scripts/demo/`. Core-never-imports-demo enforced.
  - P4.5: Resources & scenes audit (`72272902`).
  - P4.6: ~170 core `.tres` → `resources/core/` (`2f753915`–`7c33705b`).
  - P4.7: Core scenes → `scenes/core/`, demo scenes → `scenes/demo/` (`f66a7ce7`–`ef5d8e07`).
  - P4.8: Demo audio/models/textures → `assets/demo/` (`fece8d8c`).
  - P4.9: Core-never-references-demo enforcement tests; 6 violations fixed (`a85d963b`).
  - P4.10: `prototype_grids_png` → `assets/demo/textures/`; `editor_icons` → `assets/core/`; remaining core dirs → `assets/core/` (`bfc64316`–`58e4263e`).
  - Style suite: **89/89** after P4.10.
- **Phase 5**: NOT STARTED. Deferred to last.
- **Phase 6**: IN PROGRESS. P6.1 complete (`10310f00`–`ec14181a`). P6.2 complete (`a4c41434`–`a23270b1`). P6.3 complete (`d0c1224a`–`0cd59475`). P6.4 complete (`4a1218f1`–`c6608c79`). P6.5 complete (`6e9e7b6a`–`e28d0c30`). P6.6 complete (`f3806172`–`fb576449`). Style suite 92/92. Full suite 4679/4687 (8 pre-existing pending).
- **Phase 7**: NOT STARTED. Planned after P6.12. Reference plan: `~/.claude/plans/lets-add-a-new-humming-kay.md`.

---

## Phase 6 Milestone Summary

| # | Milestone | Content |
|---|---|---|
| P6.1 | RS_BTScoredNode + Utility Selector Update | New decorator wrapping child+scorer; utility selector detects scored nodes |
| P6.2 | BT Structural Builder (`U_BTBuilder`) | Static factory class for all BT node types; no AI imports |
| P6.3 | AI BT Factory (`U_AIBTFactory`) | AI-specific convenience factories (creatures, scorers, conditions) |
| P6.4 | Script-Backed Brain Settings (`RS_AIBrainScriptSettings`) | Brain settings that return a root built by a GDScript factory |
| P6.5 | BT Migration — `.tres` → Builder Scripts | Replace all creature BT `.tres` files with builder scripts |
| P6.6 | Scene Registry Builder (`U_SceneRegistryBuilder`) | Fluent builder for scene registry configuration |
| P6.7 | Scene Registry Migration | Replace scene registry `.tres` with builder script |
| P6.8 | Input Profile Builder (`U_InputProfileBuilder`) | Fluent builder for input profiles |
| P6.9 | Input Profile Migration | Replace input profile `.tres` files with builder scripts |
| P6.10 | QB Rule Builder (`U_QBRuleBuilder`) | Fluent builder for QB rules and conditions |
| P6.11 | QB Rule Migration | Replace QB rule `.tres` files with builder scripts |
| P6.12 | ADR + Extension Recipes | ADR for builder pattern; P6 extension recipe |

---

## P6.1 — RS_BTScoredNode + Utility Selector Update — COMPLETE

**Commits**: `10310f00`–`ec14181a` (5 commits + docs).

**Key implementation note**: `_score_child()` in `RS_BTUtilitySelector` uses duck-typing (`"scorer" in child`) instead of `child is RS_BTScoredNode`. This avoids a headless-mode parse error for newly created .gd files that lack UID registration. Duck-typing is equally correct and more idiomatic GDScript.

**Result**: style suite 90/90; full suite 4601/4601 passing; 7 new scored-node tests + 4 new utility-selector scored-node tests all green.

---

## P6.2 — BT Structural Builder (`U_BTBuilder`) — COMPLETE

**Commits**: `a4c41434`–`a23270b1` (3 commits + docs).

**Key implementation notes**:
- `planner()` omitted — `RS_BTPlanner*` is a forbidden token in `BT_UTILS_DIR`; planner factory goes in `U_AIBTFactory` (P6.3).
- `scored()` returns `RS_BTDecorator` (not `RS_BTScoredNode`) — `rs_bt_scored_node.gd` has no UID, so its class name can't be resolved as a type annotation in headless.
- `sequence/selector/utility_selector` use `_coerce_children` + `_children` bypass — `Object.set()` with typed `Array[RS_BTNode]` exports silently coerces to empty in headless runs (established GDScript 4.6 pitfall).

**Result**: style suite 91/91; full suite 4617/4617 passing; 16 new builder tests all green.

---

## P6.3 — AI BT Factory (`U_AIBTFactory`) — COMPLETE

**Commits**: `d0c1224a`–`0cd59475` (3 commits + docs).

**Key implementation notes**:
- `U_AIBTFactory` lives in `scripts/core/utils/ai/` (no BT_UTILS_DIR token restrictions).
- Action factories create the inner `I_AIAction` resource, configure its exports, then delegate to `U_BTBuilder.action()`.
- Condition factories create the inner `I_Condition` resource, configure its exports, then delegate to `U_BTBuilder.condition()`.
- `composite_all/any` use `_coerce_children` + `_children` bypass — same typed Array[I_Condition] export pitfall as composites in U_BTBuilder.
- `planner()` creates `RS_BTPlanner` directly — the one factory U_BTBuilder cannot host due to `RS_BTPlanner*` being a forbidden token in BT_UTILS_DIR.
- `set_field(path, value)` detects value type via `is` checks; `bool` must be checked before `int` (bool is a subtype of int in GDScript 4.x).
- All static methods; 144 lines total (well under 200-line LOC cap).

**Result**: style suite 92/92; full suite 4640/4648 (8 pre-existing pending); 21 new factory tests all green.

---

## P6.4 — Script-Backed Brain Settings (`RS_AIBrainScriptSettings`) — COMPLETE

**Commits**: `4a1218f1`–`c6608c79` (4 commits + docs).

**Key implementation notes**:
- `RS_AIBrainSettings.get_root()` is a virtual returning `root` by default; subclasses override.
- `RS_AIBrainScriptSettings.get_root()` checks `root != null` first (cached/pre-assigned), then instantiates `builder_script`, calls `build()`, type-checks result with `is RS_BTNode`, caches in `root`.
- `u_ai_bt_task_label_resolver.gd` also accessed `brain_settings.root` directly; updated alongside `s_ai_behavior_system.gd` in commit 4.
- Dynamic GDScript creation (GDScript.new() + reload()) used in tests for mock builder scripts — no fixture files needed.
- `root` serves as both the export and the in-memory cache; `RS_BTNode` has a UID so `is RS_BTNode` is safe in headless.

**Result**: style suite 92/92; full suite 4651/4659 (8 pre-existing pending); 11 new script-settings tests all green.

---

## P6.5 — BT Migration — `.tres` → Builder Scripts — COMPLETE

**Commits**: `6e9e7b6a`–`e28d0c30` (5 commits).

**Key implementation notes**:
- Commit 1 (RED): integration tests in `tests/unit/ai/integration/` — one `test_*_behavior.gd` per creature, testing builder script output directly (no `.tres` comparison).
- Commit 2 (GREEN): 6 builder scripts under `scripts/demo/ai/trees/` — each extends `RefCounted`, has `build() -> RS_BTNode`.
- Commit 3 (GREEN): `cfg_*_brain_script.tres` files for all 6 creatures, each a `RS_AIBrainScriptSettings` pointing to its builder.
- Commit 4 (GREEN): all demo scenes + tests rewired to `_script.tres` files.
- Commit 5 (GREEN): deleted 6 original `cfg_*_brain.tres` files; wolf + rabbit `brain_bt` tests deleted (covered by behavior tests); patrol/sentry/guide/builder `brain_bt` tests updated to call `get_root()` instead of accessing `.root`; `_assert_brain_root_contract` updated to call `get_root()` and drop `resource_name` check; `patrol_drone_behavior.gd` sets `root.resource_name = "patrol_drone_bt_root"` for `active_goal_id` parity in `test_ai_demo_power_core`.

**Result**: style suite 92/92; full suite 4679/4687 (8 pre-existing pending); 0 failures.

---

## P6.6 — Scene Registry Builder (`U_SceneRegistryBuilder`) — COMPLETE

**Commits**: `f3806172` (RED), `fb576449` (GREEN).

**Key implementation notes**:
- `U_SceneRegistryBuilder` lives in `scripts/core/utils/scene/u_scene_registry_builder.gd` (new `scene` subdirectory under `utils/`).
- Instance-based RefCounted class (not static) — maintains `_entries: Dictionary` and `_last_id: StringName` internal state.
- `register(scene_id, path)` creates a new entry with defaults: GAMEPLAY type (1), "fade" transition, priority 0; sets `_last_id`.
- `with_type/with_transition/with_preload` guard with `_entries.has(_last_id)` before mutating.
- `build()` returns `_entries.duplicate(true)` — same-shape entries as `U_SceneRegistry._scenes`.
- All methods return `self` for fluent chaining.
- 34 lines total; 10 new tests all green.

**Result**: style suite 92/92; 10/10 builder tests green.

---

## Sequencing

```
Phase 1 ──┬── Phase 2 (independent, complete)
          ├── Phase 3 (independent, docs-only, complete)
          └── Phase 4 ── Phase 5 (not started, deferred to last)
                     └── Phase 6 (in progress: P6.1 → P6.2 → ... → P6.12)
                        └── Phase 7 (not started: P7.1 → ... → P7.8)
```

---

## Phase 7 Milestone Summary

| # | Milestone | Content |
|---|---|---|
| P7.1 | U_EditorPrefabBuilder: Root Creation & Fluent API | `create_root`, `inherit_from`, `set_entity_id`, `set_tags`, `build` |
| P7.2 | U_EditorPrefabBuilder: ECS Component Wiring | `add_ecs_component`, `add_ecs_component_by_path`, settings + inline properties |
| P7.3 | U_EditorPrefabBuilder: Visuals, Collision & Children | CSG/mesh visuals, collision shapes, markers, child scenes, property overrides |
| P7.4 | U_EditorPrefabBuilder: Save & EditorScript Adapter | `save()`, owner propagation, wolf prefab EditorScript demo |
| P7.5 | U_EditorBlockoutBuilder: Core CSG API | `create_root`, CSG primitives, spawn points, markers, `execute_custom` |
| P7.6 | U_EditorBlockoutBuilder: Materials, Environment & Save | Material helpers, directional light, world env, `save()`, arena blockout demo |
| P7.7 | Prefab Migration | All 12 demo prefabs migrated to builder scripts; original .tscn deleted |
| P7.8 | Style Compliance, ADR & Cleanup | Style enforcement tests, ADR-0010, docs update |

---

## TDD Discipline

For every milestone:

1. Write the test first (unit or integration).
2. Run the test and verify it fails for the expected reason.
3. Implement the minimum to make it pass.
4. Run the full test suite and verify no regressions.
5. Run `tests/unit/style/test_style_enforcement.gd` after any file creation, rename, or move.
6. Commit with a focused message marked `(RED)` or `(GREEN)`.

Test command: `tools/run_gut_suite.sh` (or `-gtest=<path>` for targeted runs).

---

## Critical Notes

- **No Autoloads**: Managers live under the `Managers` node and register via `U_ServiceLocator`.
- **Style & Organization**: Follow `docs/guides/STYLE_GUIDE.md` and prefix conventions. New BT resources follow `RS_BT*` / `U_BT*` naming.
- **Update Docs After Each Milestone**: Update `cleanup-v8-tasks.md` completion notes and this continuation prompt after each milestone. Commit doc updates separately from implementation.
- **Phase 3 doc authorization**: Extension recipes + decision ADRs need per-commit user sign-off.
- **Phase 5 is last**: Base scene cleanup is easiest once all code is organized. Do not start until Phase 6 is complete or user explicitly requests it.
- **Phase 6 migration is destructive**: Each `.tres` deletion commit is atomic and revertable. Run full suite + visual parity check before deleting.
- **Core/demo boundary in Phase 6**: BT structural builder (`U_BTBuilder`) lives in `scripts/core/utils/bt/` (no AI imports). AI-specific factories (`U_AIBTFactory`) live in `scripts/core/utils/ai/`.
- **Phase 7 builder classes are RefCounted**: `U_EditorPrefabBuilder` and `U_EditorBlockoutBuilder` extend `RefCounted` (not `EditorScript`) for headless GUT testability. EditorScript wrappers in `scripts/demo/editors/` are thin adapters.
- **Phase 7 core/demo boundary**: Builder infrastructure lives in `scripts/core/utils/editors/`. Demo EditorScript recipes live in `scripts/demo/editors/`. Tests live in `tests/unit/editors/`.
- **Phase 7 migration is destructive**: Each `.tscn` deletion commit is atomic and revertable. Run full suite + visual parity check before deleting.

---

## Next Steps

1. **P6.7 Commit 1 (RED)** — Integration test in `tests/unit/scene_management/test_u_scene_registry_migration.gd`:
   - Loads the builder manifest script (`scripts/demo/scene_management/scene_manifest.gd`) and calls `build()`.
   - Verifies the produced Dictionary contains entries for all current non-critical demo scenes (alleyway, bar, interior_house, game_over, victory, credits, gameplay_base).
   - Each entry has correct scene_id, path, scene_type, default_transition, preload_priority matching the existing `.tres` files.
2. **P6.7 Commit 2 (GREEN)** — Create `scripts/demo/scene_management/scene_manifest.gd`:
   - Extends `RefCounted`, has `build() -> Dictionary`.
   - Uses `U_SceneRegistryBuilder` to register all demo scenes.
   - Replace the `.tres` entries currently loaded by `U_SceneRegistryLoader._load_resource_entries()`.
3. **P6.7 Commit 3 (GREEN)** — Wire `scene_manifest.gd` into `U_SceneRegistryLoader`:
   - Instantiate manifest, call `build()`, iterate entries, call `_register_scene_from_dict()`.
   - Keep mobile-compatible: no DirAccess scanning.
4. **P6.7 Commit 4 (GREEN)** — Delete original `.tres` scene registry entries; remove `PRELOADED_SCENE_REGISTRY_ENTRIES` const preloads from loader.
5. Keep docs/history references archived; new evergreen guidance belongs under `docs/guides/` or `docs/systems/`.

---

## Phase 7 — EditorScript + PackedScene Builders — NOT STARTED

**Reference plan**: `~/.claude/plans/lets-add-a-new-humming-kay.md`.

**Goal**: Replace hand-authored `.tscn` creation with programmatic GDScript builder APIs. Two new RefCounted builders (`U_EditorPrefabBuilder`, `U_EditorBlockoutBuilder`) provide fluent APIs for constructing scene trees. Thin `@tool extends EditorScript` wrappers in `scripts/demo/editors/` invoke them and call `save()`. All 12 demo prefabs migrate from `.tscn` to builder scripts.

**Key design decisions**:
- Builders extend `RefCounted` (not `EditorScript`) for headless GUT testability.
- `U_EditorPrefabBuilder` handles both character prefabs (inheriting from `tmpl_character.tscn`) and static objects (fresh `StaticBody3D` roots).
- `U_EditorBlockoutBuilder` handles CSG level blockouts with spawn points, lights, and environment.
- EditorScript wrappers are 5-line thin adapters: instantiate builder, call fluent API, call `save()`.
- Migration mirrors P6.5 approach: create builder → verify parity → delete original `.tscn`.

**Directory structure**:
- `scripts/core/utils/editors/` — Builder infrastructure (template-reusable)
- `scripts/demo/editors/` — EditorScript recipes (demo-specific)
- `tests/unit/editors/` — GUT tests

---

## P7.1 — U_EditorPrefabBuilder: Root Creation & Fluent API — NOT STARTED

**Files**:
- NEW `scripts/core/utils/editors/u_editor_prefab_builder.gd`
- NEW `tests/unit/editors/test_u_editor_prefab_builder.gd`

**Commit 1 (RED)** — Write tests for:
- `create_root("Node3D", "TestRoot")` produces Node3D named "TestRoot"
- `create_root("StaticBody3D", "TestStatic")` produces StaticBody3D
- `inherit_from(tmpl_character_path)` produces instanced scene with inherited children
- `set_entity_id(&"wolf")` and `set_tags([&"predator"])` set metadata on root
- Fluent API: each method returns `self`
- `build()` returns root node
- Error: calling `build()` before `create_root()` or `inherit_from()` returns null/pushes error

**Commit 2 (GREEN)** — Implement:
- `U_EditorPrefabBuilder` extends RefCounted
- `_root: Node` internal state
- `create_root(node_type: String, name: String)` — creates node by class name
- `inherit_from(scene_path: String)` — loads PackedScene, instantiates with `GEN_EDIT_STATE_MAIN`
- `set_entity_id(id: StringName)` — sets entity_id on root
- `set_tags(tags: Array[StringName])` — sets tags on root
- `build() -> Node` — returns root
- Private `_ensure_components_container()` — finds or creates "Components" node

---

## P7.2 — U_EditorPrefabBuilder: ECS Component Wiring — NOT STARTED

**Files**: MODIFY `u_editor_prefab_builder.gd`, MODIFY tests.

**Commit 3 (RED)** — Write tests for:
- `add_ecs_component(script, null, {})` adds Node under Components with script attached
- `add_ecs_component(script, settings_resource, {})` assigns settings export
- `add_ecs_component(script, null, {"detection_radius": 14.0})` sets inline properties
- `add_ecs_component_by_path(script_path, settings_path, {})` loads and wires both
- Multiple components added sequentially are all present

**Commit 4 (GREEN)** — Implement:
- `add_ecs_component(script: Script, settings: Resource = null, properties: Dictionary = {}) -> U_EditorPrefabBuilder`
- `add_ecs_component_by_path(script_path: String, settings_path: String = "", properties: Dictionary = {}) -> U_EditorPrefabBuilder`

---

## P7.3 — U_EditorPrefabBuilder: Visuals, Collision & Children — NOT STARTED

**Files**: MODIFY `u_editor_prefab_builder.gd`, MODIFY tests.

**Commit 5 (RED)** — Write tests for visual, collision, marker, and child-scene methods.

**Commit 6 (GREEN)** — Implement:
- `add_visual_csg()`, `add_visual_mesh()`, `add_collision_capsule()`, `add_collision_box()`, `add_child_scene()`, `add_marker()`, `override_property()`

---

## P7.4 — U_EditorPrefabBuilder: Save & EditorScript Adapter — NOT STARTED

**Files**: MODIFY `u_editor_prefab_builder.gd`, MODIFY tests, NEW `scripts/demo/editors/editor_build_wolf_prefab.gd`.

**Commit 7 (RED)** — Write test for `build()` producing a tree that `PackedScene.pack()` accepts.

**Commit 8 (GREEN)** — Implement `save()`, owner propagation, create wolf prefab EditorScript demo.

---

## P7.5 — U_EditorBlockoutBuilder: Core CSG API — NOT STARTED

**Files**: NEW `scripts/core/utils/editors/u_editor_blockout_builder.gd`, NEW `tests/unit/editors/test_u_editor_blockout_builder.gd`.

**Commit 9 (RED)** — Write tests for CSG primitives, spawn points, markers, `execute_custom`.

**Commit 10 (GREEN)** — Implement `U_EditorBlockoutBuilder` with all CSG methods, `build()`, `save()`.

---

## P7.6 — U_EditorBlockoutBuilder: Materials, Environment & Save — NOT STARTED

**Files**: MODIFY `u_editor_blockout_builder.gd`, MODIFY tests, NEW `scripts/demo/editors/editor_build_arena_blockout.gd`.

**Commit 11 (RED)** — Write tests for materials, lights, environment, collision flags.

**Commit 12 (GREEN)** — Implement material helper, `add_directional_light()`, `add_world_environment()`, arena blockout demo.

---

## P7.7 — Prefab Migration — NOT STARTED

Migrate all 12 demo prefabs from `.tscn` to builder scripts. Character prefabs (wolf, rabbit, builder, demo_npc) inherit from tmpl_character. Static prefabs (tree, water, stone, stockpile, construction_site) use fresh roots. Scene prefabs (alleyway, bar) as applicable. Each migration: create builder → verify parity → delete original.

---

## P7.8 — Style Compliance, ADR & Cleanup — NOT STARTED

**Commit 16 (GREEN)** — Add style enforcement: line caps, naming, import boundaries.

**Commit 17 (DOCS)** — ADR-0010, continuation prompt update, task checklist update.
