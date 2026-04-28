# Cross-System Cleanup V8 — Continuation Prompt

## Overview

Implements `docs/history/cleanup_v8/cleanup-v8-tasks.md` in phase order with TDD discipline. V8 is the follow-up to V7.2, addressing structural/organizational debt rather than internal architectural issues.

**Branch**: `cleanup-v8` (off `main`, after `GOAP-AI` merged via PR #16).
**Status**: Phases 1–4 complete. Phase 5 not started (deferred to last per sequencing plan). Phase 6 **COMPLETE** (P6.1–P6.13). Phase 7 **COMPLETE** (P7.1–P7.8). Phase 8 not started.
**Next Task**: Phase 8 — LLM-First UI Menu Builders.
**Prerequisite**: V7.2 complete (`e015aff2`). Phase 4 complete (`cbf0fd61`). All 18 P3.5 extension recipes complete (`b0c5b1cd`).

---

## Scope Summary

Seven phases bundled for one goal: make the template LLM-friendly, modular, and ship-ready as a reusable base.

1. **Phase 1 — AI Rewrite (utility-scored BTs).** COMPLETE. Replace GOAP + HTN with behavior trees. Net ~300 LOC reduction.
2. **Phase 2 — Debug/Perf Extraction.** COMPLETE through P2.4. No bare `print()` in managers/systems enforced.
3. **Phase 3 — Docs Split.** COMPLETE. `AGENTS.md` is a 58-line routing index. All 18 extension recipes shipped. ADR structure in place.
4. **Phase 4 — Template vs Demo Split.** COMPLETE (P4.1–P4.10). Scripts, resources, scenes, and assets all split into `core/` and `demo/`. Style suite 89/89.
5. **Phase 5 — Base Scene.** NOT STARTED. Deferred to last (easiest once code is organized).
6. **Phase 6 — LLM-First Fluent Builders.** COMPLETE (P6.1–P6.13). Replace `.tres` resource authoring with GDScript builder APIs across BT trees, scene registry, input profiles, and QB rules. P6.13 gap-patch backfill removal + constant migrations (`64210f85`–`279fcc33`). Reference plan: `~/.claude/plans/stateless-tickling-meerkat.md`.
7. **Phase 7 — EditorScript + PackedScene Builders.** COMPLETE (P7.1–P7.8). Hand-authored `.tscn` creation replaced with programmatic GDScript builder APIs (`U_EditorPrefabBuilder`, `U_EditorBlockoutBuilder`, `U_EditorShapeFactory`). 21 builder scripts under `scripts/demo/editors/`. ADR-0012 (Editor Builder Pattern). Style suite 94/94. Reference plan: `~/.claude/plans/lets-add-a-new-humming-kay.md`.
8. **Phase 8 — LLM-First UI Menu Builders.** NOT STARTED. Fluent builders for settings tabs and menu screens to replace `@onready`-heavy `.tscn` UI authoring.

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
- **Phase 6**: COMPLETE (P6.1–P6.13). P6.1 complete (`10310f00`–`ec14181a`). P6.2 complete (`a4c41434`–`a23270b1`). P6.3 complete (`d0c1224a`–`0cd59475`). P6.4 complete (`4a1218f1`–`c6608c79`). P6.5 complete (`6e9e7b6a`–`e28d0c30`, gap-patched `5a176f9a`–`b29e3618`). P6.6 complete (`f3806172`–`fb576449`). P6.7 complete (`a33d1153`–`0b69200f`). P6.8 complete (`4d680390`–`deac3004`). P6.9 complete (`df1deff5`–`cfdd907a`, loader tests `a16b0783`). P6.10 complete (`eb7f37c0`–`20e28d54`). P6.11 complete (`7dc8a7aa`–`8a21f645`). P6.12 complete (`1148e2f5`): ADR 0011 Builder Pattern Taxonomy + builders.md extension recipe + style enforcement update. P6.13 complete (`64210f85`–`279fcc33`): backfill removal, `RS_ConditionComposite.CompositeMode` constants, `RS_EffectSetField.OP_SET/OP_ADD` constants, `TRIGGER`/`OP`/`MATCH` constant swaps in rules + AI behaviors.
- **Phase 7**: COMPLETE (P7.1–P7.8). P7.1 complete (`1cc1e11c`, `a309ff3a`) — builder root creation + fluent API. P7.2 complete (`2bf624ba`) — ECS component wiring. P7.3 complete (`761d5a0d`) — visuals, collision & children. P7.4 complete (`fe595fc6`) — save & EditorScript adapter. P7.5 complete (`9a792b43`) — blockout builder core CSG API. P7.6 complete (`6c340624`) — blockout builder materials, environment & save. P7.7 complete (`b3e81551`–`0be92548`) — all 21 prefab builder scripts. P7.8 complete (`e26cc256`, `5c7f1fce`, `3bb5a0fa`) — `U_EditorShapeFactory` extraction (251→193 LOC), 7 additional builder scripts, ADR-0012, style suite 94/94.

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
| P6.7 | Scene Registry Migration | Replace scene registry `.tres` with builder script | COMPLETE (`a33d1153`–`0b69200f`). Manifest `u_scene_manifest.gd` with all 24 entries. Loader wired. All `.tres` removed. |
| P6.8 | Input Profile Builder (`U_InputProfileBuilder`) | Fluent builder for input profiles |
| P6.9 | Input Profile Migration | Replace input profile `.tres` files with builder scripts |
| P6.10 | QB Rule Builder (`U_QBRuleBuilder`) | Fluent builder for QB rules and conditions | COMPLETE. Static factory; 9 condition factories, 4 effect factories, rule builder; type-detected values; headless-safe array bypass; 30/30 tests green.
| P6.11 | QB Rule Migration | Replace QB rule `.tres` files with builder scripts | COMPLETE (eb7f37c0–8a21f645). 12 `br_*_rule.gd` builder scripts live under `scripts/core/qb/rules/`; 3 ECS systems load rules via `_build_rules_from_scripts`; all `.tres` deleted; 14 integration tests green.
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
- `sequence/selector/utility_selector` use `_sanitize_children` + `_children` bypass — `Object.set()` with typed `Array[RS_BTNode]` exports silently coerces to empty in headless runs (established GDScript 4.6 pitfall).

**Result**: style suite 91/91; full suite 4617/4617 passing; 16 new builder tests all green.

---

## P6.3 — AI BT Factory (`U_AIBTFactory`) — COMPLETE

**Commits**: `d0c1224a`–`0cd59475` (3 commits + docs).

**Key implementation notes**:
- `U_AIBTFactory` lives in `scripts/core/utils/ai/` (no BT_UTILS_DIR token restrictions).
- Action factories create the inner `I_AIAction` resource, configure its exports, then delegate to `U_BTBuilder.action()`.
- Condition factories create the inner `I_Condition` resource, configure its exports, then delegate to `U_BTBuilder.condition()`.
- `composite_all/any` use `_sanitize_children` + `_children` bypass — same typed Array[I_Condition] export pitfall as composites in U_BTBuilder.
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

## P6.10 — QB Rule Builder (`U_QBRuleBuilder`) — COMPLETE

**Commits**: Commit 1 (RED) `test_u_qb_rule_builder.gd`, Commit 2 (GREEN) `u_qb_rule_builder.gd`.

**Key implementation notes**:
- `U_QBRuleBuilder` extends `RefCounted` with `class_name`, all `static func` — matches `U_BTBuilder` and `U_AIBTFactory` pattern.
- Condition factories: `event_name`, `event_payload`, `component_field`, `redux_field`, `entity_tag`, `context_field`, `constant`, `composite_all`, `composite_any`.
- Effect factories: `publish_event`, `set_field`, `set_context`, `dispatch_action`.
- `rule(rule_id, conditions, effects, config)` creates `RS_Rule`, applies `config` dict for `trigger_mode`, `score_threshold`, `decision_group`, `priority`, `cooldown`, `one_shot`, `requires_rising_edge`, `description`.
- Headless-safe typed-array bypass: `rule()` calls `_sanitize_conditions()` / `_sanitize_effects()` via `call()` then `.set("_conditions", ...)` / `.set("_effects", ...)` — same pitfall bypass as U_BTBuilder/U_AIBTFactory.
- Composite factories use `_sanitize_children` + `.set("_children", ...)` bypass — same as U_AIBTFactory.`composite_all`/`composite_any`.
- `set_field` and `set_context` value type detection: `bool` before `int` (bool is subtype of int in GDScript 4.x), then `float`, `StringName`, `String`, `Vector2`, `Vector3`.
- `set_field` config supports: `operation`, `use_context_value`, `context_value_path`, `scale_by_rule_score`, `rule_score_context_path`, `use_clamp`, `clamp_min`, `clamp_max`.
- 9 condition + 4 effect + 1 rule factory + 2 value-helpers = ~141 lines; under 200-line LOC cap.

**Result**: 30/30 tests passing, 218 asserts; full suite 4755/4763 (8 pre-existing pending, 0 failures).

---

## Sequencing

```
Phase 1 ──┬── Phase 2 (independent, complete)
          ├── Phase 3 (independent, docs-only, complete)
          └── Phase 4 ── Phase 5 (not started, deferred to last)
                     └── Phase 6 (complete, P6.1–P6.13)
                        ├── Phase 7 (complete, P7.1–P7.8)
                        └── Phase 8 (not started)
```

---

## Phase 7 Milestone Summary

| # | Milestone | Content |
|---|---|---|
| P7.1 | U_EditorPrefabBuilder: Root Creation & Fluent API | `create_root`, `inherit_from`, `set_entity_id`, `set_tags`, `build` | COMPLETE |
| P7.2 | U_EditorPrefabBuilder: ECS Component Wiring | `add_ecs_component`, `add_ecs_component_by_path`, settings + inline properties | COMPLETE |
| P7.3 | U_EditorPrefabBuilder: Visuals, Collision & Children | CSG/mesh visuals, collision shapes, markers, child scenes, property overrides | COMPLETE |
| P7.4 | U_EditorPrefabBuilder: Save & EditorScript Adapter | `save()`, owner propagation, `add_child_to`, `add_child_scene_to` | COMPLETE |
| P7.5 | U_EditorBlockoutBuilder: Core CSG API | `create_root`, CSG primitives, spawn points, markers, `execute_custom` | COMPLETE |
| P7.6 | U_EditorBlockoutBuilder: Materials, Environment & Save | Material helpers, directional light, world env, `save()`, arena blockout demo | COMPLETE |
| P7.7 | Prefab Migration | All 21 demo prefab builder scripts migrated | COMPLETE |
| P7.8 | Style Compliance, ADR & Cleanup | `U_EditorShapeFactory` extraction, LOC caps, ADR-0012 | COMPLETE |

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

Two candidate next phases — user chooses:

1. **Phase 5 — Base Scene cleanup** (deferred to last per original plan). Audit all `.tscn` files, define canonical base scene, migrate demo content, delete temp/fake scenes.
2. **Phase 8 — LLM-First UI Menu Builders.** Replace `@onready`-heavy settings/menu scripts with `U_SettingsTabBuilder`, `U_UIMenuBuilder`, and `U_UISettingsCatalog` fluent builders. Depends on Phase 6 (already complete). Can proceed in parallel with Phase 5.

---

## Phase 7 — EditorScript + PackedScene Builders — COMPLETE

**Reference plan**: `~/.claude/plans/lets-add-a-new-humming-kay.md`.

**Goal**: Replace hand-authored `.tscn` creation with programmatic GDScript builder APIs. Two `RefCounted` builders (`U_EditorPrefabBuilder`, `U_EditorBlockoutBuilder`) provide fluent APIs for constructing scene trees. Thin `@tool extends EditorScript` wrappers in `scripts/demo/editors/` invoke them and call `save()`. 21 demo prefab builder scripts migrated.

**Key design decisions**:
- Builders extend `RefCounted` (not `EditorScript`) for headless GUT testability.
- `U_EditorPrefabBuilder` handles both character prefabs (inheriting from `tmpl_character.tscn`) and static objects (fresh `StaticBody3D` roots).
- `U_EditorBlockoutBuilder` handles CSG level blockouts with spawn points, lights, and environment.
- `U_EditorShapeFactory` extracted from `U_EditorPrefabBuilder` to stay under 200-line LOC cap.
- EditorScript wrappers are 5-line thin adapters: instantiate builder, call fluent API, call `save()`.
- Migration mirrors P6.5 approach: create builder → verify parity → keep `.tscn` as generated artifact.
- ADR-0012 documents the editor builder pattern decision.

**Directory structure**:
- `scripts/core/utils/editors/` — Builder infrastructure (template-reusable)
- `scripts/demo/editors/` — EditorScript recipes (demo-specific)
- `tests/unit/editors/` — GUT tests

---

## P7.1 — U_EditorPrefabBuilder: Root Creation & Fluent API — COMPLETE

**Commits**: `1cc1e11c` (RED), `a309ff3a` (GREEN).

**Key implementation notes**:
- `U_EditorPrefabBuilder` extends `RefCounted` with `class_name` (headless-testable, matches P6 builder conventions).
- `create_root(node_type, name)` uses `ClassDB.instantiate(node_type)` — works for any Godot node class.
- `inherit_from(scene_path)` uses `PackedScene.instantiate(PackedScene.GEN_EDIT_STATE_MAIN)` to preserve editable children in editor.
- `set_tags` accepts `Array` (not `Array[StringName]`) to avoid headless `.call()` type-coercion failures when passing untyped Arrays from tests.
- `build()` returns `_root` directly; `push_error` + return `null` if no root set.
- 45 lines total; under 200-line LOC cap.

**Result**: 9/9 tests passing, 41 asserts; style suite 92/92; full suite 0 regressions.

---

## P7.2 — U_EditorPrefabBuilder: ECS Component Wiring — COMPLETE

**Commits**: `2bf624ba` (RED+GREEN combined).

**Key implementation notes**:
- `add_ecs_component(script, settings, properties)` creates a `Node` under a `Components` container, attaches the script, assigns `settings` export if present, then applies inline property overrides.
- `add_ecs_component_by_path(script_path, settings_path, properties)` loads script/settings by path and delegates to `add_ecs_component`.
- Component node name defaults to `COMPONENT_TYPE` constant from the script; falls back to script filename base name if constant is null.
- `set("settings", settings)` is used instead of direct property assignment to avoid type-coercion issues in headless mode.
- 83 lines total builder + 97 lines tests; under 200-line LOC cap.

**Result**: 14/14 tests passing, 75 asserts; style suite 92/92; full suite 0 regressions.

---

## P7.3 — U_EditorPrefabBuilder: Visuals, Collision & Children — COMPLETE

**Commits**: `761d5a0d` (RED+GREEN combined).

**Key implementation notes**:
- `add_visual_mesh(name, material, scale)` — creates `MeshInstance3D` with `BoxMesh`, optional `material_override`.
- `add_collision_capsule(radius, height, shape_name)` — creates `CollisionShape3D` with `CapsuleShape3D`.
- `add_marker(name)` — creates `Marker3D`.
- `override_property(node_path, property, value)` — sets any property via `set()` on existing node (`.` = root).
- `add_child_scene(scene_path, child_name)` — loads `PackedScene`, instantiates with `GEN_EDIT_STATE`, renames.
- All methods guard against null root, return self for fluent chaining.
- 149 lines total builder + 280 lines tests; under 200-line builder LOC cap.

**Result**: 19/19 tests passing, 99 asserts; style suite 92/92; full suite 0 regressions.

---

## P7.4 — U_EditorPrefabBuilder: Save & EditorScript Adapter — COMPLETE

**Commits**: `fe595fc6` (GREEN).

**Key implementation notes**:
- `save()` with owner propagation, wolf prefab EditorScript demo.
- `add_child_to` + `add_child_scene_to` builder methods added (`bb6c88aa`).

---

## P7.5 — U_EditorBlockoutBuilder: Core CSG API — COMPLETE

**Commits**: `9a792b43` (GREEN).

**Key implementation notes**:
- `create_root`, CSG primitives (`add_csg_box`, `add_csg_sphere`, `add_csg_cylinder`), spawn points, markers, `execute_custom`, `build()`, `save()`.

---

## P7.6 — U_EditorBlockoutBuilder: Materials, Environment & Save — COMPLETE

**Commits**: `6c340624` (GREEN).

**Key implementation notes**:
- Material helpers, `add_directional_light()`, `add_world_environment()`, arena blockout demo.

---

## P7.7 — Prefab Migration — COMPLETE

All 21 builder scripts under `scripts/demo/editors/`:
- Static object prefabs: `build_prefab_woods_stone.gd`, `build_prefab_woods_water.gd`, `build_prefab_woods_stockpile.gd`, `build_prefab_woods_tree.gd`, `build_prefab_woods_construction_site.gd`
- Character prefabs: `build_prefab_woods_wolf.gd`, `build_prefab_woods_rabbit.gd`, `build_prefab_woods_builder.gd`, `build_prefab_demo_npc.gd`
- Core gameplay: `build_prefab_character.gd`, `build_prefab_checkpoint_safe_zone.gd`, `build_prefab_death_zone.gd`, `build_prefab_door_trigger.gd`, `build_prefab_goal_zone.gd`, `build_prefab_spike_trap.gd`
- Scene prefabs: `build_prefab_alleyway.gd`, `build_prefab_bar.gd`
- Player: `build_prefab_player.gd`, `build_prefab_player_body.gd`, `build_prefab_player_ragdoll.gd`
- Sub-prefab: `build_prefab_demo_npc_body.gd`

Builder API extensions: `add_csg_box`, `add_csg_sphere`, `add_csg_cylinder`, `add_collision_box` added in P7.7a. `add_child_to` + `add_child_scene_to` added in P7.4.

---

## P7.8 — Style Compliance, ADR & Cleanup — COMPLETE

**Commits**: `e26cc256`, `5c7f1fce`, `3bb5a0fa`.

- Extracted `U_EditorShapeFactory` from `U_EditorPrefabBuilder` to fix 251→193 LOC violation.
- Added style enforcement tests for builder LOC caps.
- Authored 7 additional builder scripts for core gameplay prefabs.
- ADR-0012 Editor Builder Pattern (not ADR-0010 — ADR-0010 is base-scene).
- Fixed Godot 3.x Transform3D constructor syntax for Godot 4.x.
- Transformed `int` literal fixes and Unicode arrow fixes in builder scripts.
- Style suite **94/94**.
