# Cross-System Cleanup V7 — Implementation Guide & Continuation Prompt

## Overview

This guide directs you to implement the Cross-System Cleanup (V7) by following the tasks outlined in `docs/general/cleanup_v7/cleanup-v7-tasks.md` in sequential order. C12 (Post-Processing Pipeline Refactor) is included as the final milestone and runs *after* C11; its full checklist lives in `docs/general/cleanup_v7/post-process-refactor-tasks.md`.

**Branch**: GOAP-AI
**Status**: C1-C11 complete; C12 next
**Next Task**: Begin C12 (Post-Processing Pipeline Refactor) per `docs/general/cleanup_v7/post-process-refactor-tasks.md`
**Planned Follow-up After C12**: Begin `docs/general/cleanup_v7/cleanup-v7.2-tasks.md`

---

## Current Status: C11 Complete

- **C1 (Rule Evaluation Pipeline Extraction)**: COMPLETE — `U_RuleEvaluator` already orchestrated the rule pipeline (commits 1-5 pre-existing). Commit 6 extracted property reader utilities to `U_RuleUtils`, removing ~150 lines of duplication across 5 files. Retroactive gap fixes (C1.7–C1.8): added `read_array_property` and `read_int_property` to `U_RuleUtils`, migrated QB pipeline utilities (`u_rule_validator`, `u_rule_scorer`, `u_rule_selector`) to use `U_RuleUtils` instead of local `_read_*` methods, deleted ~53 lines of duplicated code from `u_rule_validator` alone. All tests green, style enforcement passes.

- **C2 (Typed Rule Context)**: COMPLETE — Created `RSRuleContext` (Resource) with 28 StringName key constants and typed properties for all rule system context fields. Systems build RSRuleContext objects and convert to Dictionary via `to_dictionary()` for QB condition/effect compatibility. Eliminated StringName/String dual-keying in `s_character_state_system`. Retroactive gap fixes (C2.6–C2.10): added `KEY_BRAIN_COMPONENT` for AI context, migrated `U_AIContextBuilder`, `M_ObjectivesManager`, and `M_SceneDirectorManager` to `RSRuleContext` (fixing latent "state" alias bug), expanded bare-string-key style enforcement to all 6 context builders, migrated `RS_RULE_CONTEXT` preload pattern to `RSRuleContext` class reference in all 3 rule systems. All tests green, style enforcement passes.
- **C3 (Shared Dependency Resolution)**: COMPLETE — `U_DependencyResolution` is in place, migrated across ECS systems/managers/interactables/helpers, and style checks enforce no inline duplicate `try_get_store` resolution patterns in migrated files.
- **C4 (State Snapshot Extraction)**: COMPLETE — `BaseECSSystem.get_frame_state_snapshot()` + `_resolve_state_store()` override contract adopted by the five target systems; local `_get_frame_state_snapshot` duplicates removed.
- **C5 (Wall Visibility Decomposition)**: COMPLETE — `S_WallVisibilitySystem.process_tick` decomposed into focused methods and registry-driven type handling; decomposition + integration tests green.
- **C6 (Scene Manager Overlay Extraction)**: COMPLETE — overlay behavior delegated to `U_OverlayStackManager`; `_perform_transition` decomposed and retroactive fixes landed for typed `U_TransitionState` callback state + `I_CameraManager.is_blend_active()` handoff checks.
- **C7 (Objectives Manager Namespace Support)**: COMPLETE — Replaced `_objectives_by_id` flat dictionary with `_objective_sets` namespace-aware storage. Multiple objective sets can be active simultaneously. Added `unload_objective_set()`, `active_set_ids` array to store, cross-set selectors (`get_active_set_ids`, `get_statuses_snapshot`, `get_completed_objectives`), and grep test enforcing selector usage.
- **C8 (Selector Enforcement — Managers)**: COMPLETE — audited selector coverage, created/expanded slice selectors (including `u_scene_selectors.gd`), migrated all 17 manager/helper target files to selectors, removed duplicate `get_player_entity_id` from `u_gameplay_selectors.gd` to keep `u_entity_selectors.gd` canonical, and finalized manager-style enforcement for direct `state.get(...)` / `state[...]` access with token-aware matching.
- **C9 (Gameplay-Feel Constants → Resource Configs)**: COMPLETE — added RED tests for config resources, implemented `RS_WallVisibilityConfig`, `RS_CameraStateConfig`, and `RS_SpawnConfig`, then migrated `s_wall_visibility_system`, `s_camera_state_system`, `m_spawn_manager`, `m_character_lighting_manager`, and `m_display_manager` to resource-backed tuning. Added `RS_CharacterLightingConfig` and `RS_DisplayConfig` for character-lighting/display manager defaults. Post-C9 audit gap fixes landed: config resolvers now use canonical default `.tres` resources (no per-tick `.new()` allocations), manager/template config assignments are wired in scenes, wall-visibility config fallbacks fully drive fade defaults when component settings are unset, and display reducer UI-scale clamps now read config bounds.
- **C10 (Entity Identification by Tags/Metadata)**: COMPLETE — All 6 commits done. Created `U_EntityLookup` static utility; migrated `M_SpawnManager._find_player_entity`, `S_MovementSystem._get_entity_type`, `M_VCamManager._resolve_mode_name`, and `C_VCamComponent.get_mode_name` to tag/metadata-first with name-based fallbacks; extended `BaseECSEntity.get_entity_id` with metadata lookup step. 568 manager, 10 movement, 23 spawn integration, and 27 entity-ID tests all green.

- **C11 (Selector Enforcement — Systems, Helpers, Interactables, and UI)**: COMPLETE — All 4 commits done. Added new selectors (`U_GameplaySelectors.get_completed_areas/get_game_completed/get_death_count`, `U_InputSelectors.get_input_state_snapshot`, `U_SettingsSelectors.get_accessibility_settings`). Migrated 9 files: `s_victory_handler_system`, `s_gamepad_vibration_system`, `s_input_system` (missed C8 violation), `u_vcam_runtime_context`, `u_vcam_debug`, `inter_ai_demo_guard_barrier`, `ui_victory`, `ui_game_over`, `ui_gamepad_settings_overlay`. Expanded style enforcement to all production dirs with explicit deferred list for 11 not-yet-migrated files + 3 false-positive vcam internal-state files. 4217/4217 tests green.

- **Task checklist**: `docs/general/cleanup_v7/cleanup-v7-tasks.md` — 12-milestone TDD cleanup plan (C1–C12) targeting DRY, modularity, scalability, designer-friendliness, and post-processing pipeline simplification across managers and ECS systems.
- **C12 standalone doc**: `docs/general/cleanup_v7/post-process-refactor-tasks.md` — post-processing pipeline refactor (10 commits), scheduled after C11 completes.
- **V7.2 follow-up doc**: `docs/general/cleanup_v7/cleanup-v7.2-tasks.md` — scheduled to start after C12 lands.
- **Scope**: No behavioral changes except (a) CRT removal and (b) color grading becoming mobile-enabled (both gated behind C12). All existing integration tests must stay green throughout.

---

## Problem Statement

Over time, managers and ECS systems have accumulated shared patterns that were implemented independently rather than abstracted. The cleanup addresses four categories:

### DRY Violations (Highest Priority)
- **Rule evaluation pipeline** — `_refresh_active_rules`, `_get_applicable_rules`, `_apply_state_gates`, `_execute_effects`, `_mark_fired_rules`, `_resolve_rule_id` are copy-pasted across `s_camera_state_system`, `s_character_state_system`, and `s_game_event_system` (~300 lines duplicated). Note: `U_RuleScorer`, `U_RuleSelector`, and `U_RuleStateTracker` are already shared — `U_RuleEvaluator` extracts the orchestration that calls into these.
- **Property reader utilities** — `_read_string_property`, `_read_string_name_property`, `_read_bool_property`, `_read_float_property`, `_is_script_instance_of`, `_object_has_property`, `_variant_to_string_name`, `_get_context_value`, `_extract_event_names_from_rule` are triple-duplicated across the three rule systems (some in only 2 of 3). `_variant_to_string_name` is also duplicated in `u_vcam_runtime_context.gd` and `u_vcam_landing_impact.gd`.
- **Dependency resolution** — The "check private cache → check export → fallback to ServiceLocator" pattern is repeated across 17 methods in 13 files (8 ECS systems, 3 managers, 2 gameplay interactables, 1 helper, 1 coordinator).
- **State snapshot** — `_get_frame_state_snapshot` is near-identical in 5 systems (s_wall_visibility_system, s_camera_state_system, s_character_state_system, s_vcam_system, s_ai_behavior_system) with 3 variants.

### Modularity Issues
- `s_wall_visibility_system.process_tick` is a 200-line god method handling 6+ distinct concerns.
- `m_scene_manager._perform_transition` is a 155-line method with an 88-line closure capturing the entire manager's state.
- `m_scene_manager` mixes overlay management with scene transitions (no shared data).
- `m_objectives_manager._on_action_dispatched` is a monolithic action router.
- `m_character_lighting_manager._physics_process` mixes zone discovery, character discovery, and lighting application.
- `m_state_store._input` handles two unrelated debug overlays and calls `cursor_manager.set_cursor_state`.
- `m_state_store._sync_navigation_initial_scene` bypasses the reducer/dispatch pattern by directly mutating `_state["navigation"]`.
- `m_ecs_manager.query_entities` and `query_entities_readonly` are near-duplicates.

### Scalability Issues
- ~~`m_objectives_manager._objectives_by_id` is a flat dictionary — loading a new set replaces the previous one entirely.~~ (Fixed in C7: now uses `_objective_sets` namespace-aware storage)
- `m_ecs_manager._invalidate_query_cache` clears ALL cache entries on any component change.
- Context dictionaries in rule systems use magic-string keys with no schema or type safety.
- `m_scene_manager._scene_history` grows without bound.
- `m_ecs_manager` tag system uses linear scan with no secondary index.

### Designer-Friendliness Issues
- Gameplay-feel constants (`const` and inline literals) across wall visibility, camera, movement, spawn, character lighting, and display systems are not inspector-editable.
- Entity identification relies on node name conventions (`"E_Player"` prefix, `"RS_VCamMode"` prefix stripping).
- Transition types are magic strings (`"fade"`, `"instant"`, `"loading"`).
- Objective types require code changes to add custom event behavior.

---

## Plan Snapshot Note

Milestone checklists below are the original implementation-plan scaffold and may still contain unchecked boxes from kickoff drafting. Treat `docs/general/cleanup_v7/cleanup-v7-tasks.md` as the authoritative completion source for C1-C9 status and verification counts.

---

## Milestone C1: Rule Evaluation Pipeline Extraction

**Goal**: Extract the shared rule evaluation lifecycle across `s_camera_state_system`, `s_character_state_system`, and `s_game_event_system`. `U_RuleEvaluator` is a composed utility — systems call pipeline steps at appropriate points in their own lifecycle, matching the existing `U_RuleScorer`/`U_RuleSelector`/`U_RuleStateTracker` pattern.

- [ ] **Commit 1** — Add rule evaluator tests (TDD RED)
- [ ] **Commit 2** — Implement `U_RuleEvaluator` (TDD GREEN)
- [ ] **Commit 3** — Refactor `s_camera_state_system.gd` to use `U_RuleEvaluator`
- [ ] **Commit 4** — Refactor `s_character_state_system.gd` to use `U_RuleEvaluator`
- [ ] **Commit 5** — Refactor `s_game_event_system.gd` to use `U_RuleEvaluator`
- [ ] **Commit 6** — Extract property reader utilities to `U_RuleUtils` (including `u_vcam_runtime_context` and `u_vcam_landing_impact` callers)

**C1 Verification**:
- [ ] All new `U_RuleEvaluator` and `U_RuleUtils` tests green
- [ ] Existing camera-state, character-state, game-event tests green (no behavior change)
- [ ] Grep-based style test green (no local rule pipeline methods in the three systems)
- [ ] `test_style_enforcement.gd` passes
- [ ] `_variant_to_string_name` no longer defined in `u_vcam_runtime_context.gd` or `u_vcam_landing_impact.gd`

---

## Milestone C2: Typed Rule Context

**Goal**: Replace flat `Dictionary`-with-magic-string-keys context pattern with a typed context resource (`RS_RuleContext`).

- [ ] **Commit 1** — Add context resource tests (TDD RED)
- [ ] **Commit 2** — Implement `RSRuleContext` (TDD GREEN)
- [ ] **Commit 3** — Migrate `s_camera_state_system.gd` to use `RSRuleContext`
- [ ] **Commit 4** — Migrate `s_character_state_system.gd` to use `RSRuleContext`
- [ ] **Commit 5** — Migrate `s_game_event_system.gd` to use `RSRuleContext`

**C2 Verification**:
- [ ] All context resource tests green
- [ ] All three rule systems' existing tests green
- [ ] No bare string keys used for context field access in rule systems (grep test)

---

## Milestone C3: Shared Dependency Resolution

**Goal**: Extract the "check private cache → check export → fallback to ServiceLocator" pattern into a shared utility. Scope: 17 methods across 13 files (8 ECS systems, 3 managers, 2 gameplay interactables, 1 helper, 1 coordinator).

- [ ] **Commit 1** — Add resolution utility tests (TDD RED)
- [ ] **Commit 2** — Implement `U_DependencyResolution` (TDD GREEN)
- [ ] **Commit 3** — Add `resolve_service` to `BaseECSSystem`, migrate all 8 ECS systems
- [ ] **Commit 4** — Migrate managers, interactables, and helpers (m_vcam_manager, m_character_lighting_manager, m_display_manager, inter_victory_zone, inter_ai_demo_guard_barrier, u_vcam_debug, m_run_coordinator_manager)

**C3 Verification**:
- [ ] All resolution utility tests green
- [ ] All affected manager and system tests green
- [ ] No local `_resolve_*` methods that duplicate the shared pattern (grep test)

---

## Milestone C4: State Snapshot Extraction to BaseECSSystem

**Goal**: Extract `_get_frame_state_snapshot` (near-identical across 5 systems, 3 variants) into `BaseECSSystem`.

- [ ] **Commit 1** — Add snapshot tests (TDD RED)
- [ ] **Commit 2** — Add `get_frame_state_snapshot` to `BaseECSSystem` (TDD GREEN)
- [ ] **Commit 3** — Migrate all five systems to use inherited method (s_wall_visibility_system, s_camera_state_system, s_character_state_system, s_vcam_system, s_ai_behavior_system)

**C4 Verification**:
- [ ] All snapshot tests green
- [ ] All five systems' existing tests green
- [ ] No `_get_frame_state_snapshot` defined in any ECS system (grep test)

---

## Milestone C5: Wall Visibility System Decomposition

**Goal**: Break up `s_wall_visibility_system.process_tick` (200-line god method) into focused methods.

- [ ] **Commit 1** — Add method-level tests (TDD RED)
- [ ] **Commit 2** — Decompose `process_tick` (TDD GREEN)
- [ ] **Commit 3** — Replace type-dispatch switch with registry pattern

**C5 Verification**:
- [ ] All decomposition tests green
- [ ] Existing wall-visibility integration tests green
- [ ] `process_tick` method under 60 lines

---

## Milestone C6: Scene Manager Overlay Extraction

**Goal**: Separate overlay management from `m_scene_manager.gd` into `U_OverlayHelper`. Decompose `_perform_transition` (155 lines, 88-line closure).

- [ ] **Commit 1** — Add overlay helper tests (TDD RED)
- [ ] **Commit 2** — Extract `U_OverlayHelper` (TDD GREEN)
- [ ] **Commit 3** — Wire `M_SceneManager` to `U_OverlayHelper`
- [ ] **Commit 4** — Decompose `_perform_transition` god method

**C6 Verification**:
- [ ] All overlay helper tests green
- [ ] Existing scene-manager tests green
- [ ] `_perform_transition` under 40 lines (orchestration only)

---

## Milestone C7: Objectives Manager Namespace Support

**Goal**: Replace `_objectives_by_id` flat dictionary with namespace-aware storage so multiple objective sets can be active simultaneously.

- [ ] **Commit 1** — Add namespace tests (TDD RED)
- [ ] **Commit 2** — Implement namespace support (TDD GREEN)
- [ ] **Commit 3** — Add cross-set selector/query methods

**C7 Verification**:
- [ ] All namespace tests green
- [ ] Existing objectives-manager tests green (backwards-compatible)
- [ ] Grep test: no direct `state.get("objectives", {})` outside selectors

---

## Milestone C8: Selector Enforcement — Managers — COMPLETE

**Goal**: All state reads outside reducers go through `U_*_selectors`. No `state.get("slice", {})["key"]`. This milestone targets manager/helper files first; systems/interactables/UI migration continues in C11.

- [x] **Commit 1** — Audit all 18 selector files, add missing selectors, create `u_scene_selectors.gd`
- [x] **Commit 2** — Migrate all 17 manager/helper files to use selectors
- [x] **Commit 3** — Add style enforcement grep test for managers
- [x] **C8 audit gap-fix addendum** — Migrated `s_input_system` and `base_event_sfx_system` early (C11 subset) to align with new selector helpers.

**C8 Verification**:
- [x] All selector tests green (`tests/unit/state/test_c8_selector_enforcement.gd` — 50/50)
- [x] All manager tests green (`tools/run_gut_suite.sh -gdir=res://tests/unit/managers -ginclude_subdirs=true` — 568/568)
- [x] Grep test: zero `state.get("` or `state["` occurrences in manager/helper files

---

## Milestone C9: Gameplay-Feel Constants → Resource Configs

**Goal**: Move hardcoded gameplay-feel constants into `Resource` configs so designers can tune values without code changes.

- [x] **Commit 1** — Create config resource tests (TDD RED)
- [x] **Commit 2** — Implement config resources (TDD GREEN): `RS_WallVisibilityConfig`, `RS_CameraStateConfig`, `RS_SpawnConfig`
- [x] **Commit 3** — Migrate `s_wall_visibility_system.gd`
- [x] **Commit 4** — Migrate `s_camera_state_system.gd`
- [x] **Commit 5** — Migrate `m_spawn_manager.gd`
- [x] **Commit 6** — Migrate `m_character_lighting_manager.gd`
- [x] **Commit 7** — Migrate `m_display_manager.gd`

**C9 Verification**:
- [x] All config resource tests green
- [x] All affected system/manager tests green (defaults match old `const` values)
- [x] Each config resource is inspector-editable (has `@export` on all fields)
- [x] Audit gap fixes green: wall-visibility fallback config test, display reducer config clamp tests, new manager-config resource tests, and style enforcement.

---

## Milestone C10: Entity Identification by Tags/Metadata — COMPLETE

**Completed**: 2026-04-12

**Goal**: Replace fragile node-name-based entity identification with tag/metadata lookups. `BaseECSEntity._generate_id_from_name` already has collision detection via `M_ECSManager.register_entity` (appends instance IDs on collision) — preserve this safety net.

- [x] **Commit 1** — Add tag-based lookup tests (TDD RED)
- [x] **Commit 2** — Implement `U_EntityLookup` (TDD GREEN)
- [x] **Commit 3** — Migrate `M_SpawnManager._find_player_entity`
- [x] **Commit 4** — Migrate `S_MovementSystem._infer_entity_type_from_name`
- [x] **Commit 5** — Migrate `M_VCamManager._resolve_mode_name`
- [x] **Commit 6** — Update `BaseECSEntity._generate_id_from_name` (tag/metadata primary, name-stripping fallback)

**C10 Verification**:
- [x] All entity lookup tests green (4/4)
- [x] All affected manager/system tests green (568 managers; 10 movement; 14 spawn integration; 30 entity IDs)
- [x] Primary entity identification paths use tags/metadata first; naming-convention code remains only as explicit fallback paths
- [x] `u_scene_loader.find_player_in_scene` migrated to tag-first (post-audit gap fix); `m_scene_manager._find_player_in_scene` dead code removed
- [x] `BaseECSEntity.get_entity_id` metadata path covered by 3 tests (priority, export-wins, empty-string fallback)
- [x] Spawn manager tag path covered by 2 integration tests (tag success, prefix fallback)
- Note: `i_scene_contract._validate_gameplay_scene` intentionally retains `"E_Player"` scene-contract checks

---

## Milestone C11: Selector Enforcement — Systems, Helpers, Interactables, and UI — COMPLETE

**Completed**: 2026-04-12

**Summary**: Extended C8's selector enforcement to 11 target files. Added new selectors: `U_GameplaySelectors.get_completed_areas/get_game_completed/get_death_count`, `U_InputSelectors.get_input_state_snapshot`, `U_SettingsSelectors.get_accessibility_settings`. Also fixed a missed C8 violation in `s_input_system._update_accessibility_from_state`. Style enforcement test now covers all production dirs (scripts/ecs, gameplay, ui, managers, scene_management, utils, core) with an explicit deferred list for 11 not-yet-migrated files and 3 false-positive vcam files that use local dicts named `state`.

- [x] **Commit 1** — Migrate ECS systems: `s_victory_handler_system`, `s_gamepad_vibration_system`, fix `s_input_system`
- [x] **Commit 2** — Migrate helpers and interactables: `u_vcam_runtime_context`, `u_vcam_debug`, `inter_ai_demo_guard_barrier` (inter_victory_zone was already clean)
- [x] **Commit 3** — Migrate UI files: `ui_victory`, `ui_game_over`, `ui_gamepad_settings_overlay`
- [x] **Commit 4** — Expand style enforcement grep test to all production files

**C11 Verification**:
- [x] All affected system/helper/interactable/UI tests green (4217/4217 total)
- [x] Grep test: `test_all_production_files_use_selectors_for_state_access` passes (32/32 style tests)
- [x] Explicit deferred list remains documented in style enforcement for post-C11 follow-up migration

---

## Milestone C12: Post-Processing Pipeline Refactor

**Goal**: Collapse the gameplay-visible post-process surface to exactly two passes (color grading + grain/dither) behind a new `U_PostProcessPipeline` coordinator that mimics `CompositorEffect` ergonomics in `gl_compatibility` mode, remove CRT entirely, rename cinema_grade → color_grading across the codebase, and enable color grading on mobile.

**Scheduling**: C12 runs *after* C1–C11 are complete. It is architecturally independent of every earlier milestone (no overlap with rule engine, selectors, dependency resolution, or scene-manager work), but placing it at the end keeps the cleanup-v7 branch's display-layer churn isolated from the state/ECS churn in C1–C11 and gives a single clean review surface for the post-processing pipeline.

**Standalone doc**: Full commit-by-commit checklist, critical file list, architecture notes, and verification steps live in `docs/general/cleanup_v7/post-process-refactor-tasks.md`. That doc is the source of truth; this section is a summary.

- [ ] **Commit 1** (RED) — Add pipeline + removal tests (`test_u_post_process_pipeline.gd`, extend `test_style_enforcement.gd`)
- [ ] **Commit 2** (GREEN) — Delete CRT from state layer (actions, selectors, reducer, initial state, preset values, 3 preset `.tres` files)
- [ ] **Commit 3** (GREEN) — Delete CRT from UI/localization (display settings tab, VFX overlay, option catalog, 5 locale files)
- [ ] **Commit 4** (GREEN) — Strip CRT from shaders + applier (combined shader → `sh_grain_dither.gdshader`, delete `sh_crt_shader.gdshader`, remove `crt_*` setters, drop legacy effect constants)
- [ ] **Commit 5** (GREEN) — Rename cinema_grade → color_grading in state layer (actions, selectors, reducer keys)
- [ ] **Commit 6** (GREEN) — Rename resources + registry (scene resource class, registry, 5 scene grade `.tres` files)
- [ ] **Commit 7** (GREEN) — Rename applier + debug + UI + localization; update references in display/scene managers and perf monitor; flag mobile PCK cache warning
- [ ] **Commit 8** (GREEN) — Introduce `U_PostProcessPipeline`; migrate both surviving appliers onto it; unify `fg_time` frame counter
- [ ] **Commit 9** (GREEN) — Enable color grading on mobile (drop `_is_mobile` force-disable; flip mobile test polarity; perf-probe fallback noted)
- [ ] **Commit 10** (GREEN) — Finalize style enforcement (grep assertions from Commit 1 now pass); add pipeline-singular-entry-point test; delete dead code

**C12 Verification**:
- [ ] `test_u_post_process_pipeline.gd` green
- [ ] `grep -r "cinema_grade" scripts/` zero hits
- [ ] `grep -r "crt_\|chromatic_aberration\|scanline\|curvature" scripts/` zero hits in post-process contexts
- [ ] No file outside `u_post_process_pipeline.gd` constructs `ColorRect` children under `PostProcessOverlay`
- [ ] Runtime validation: desktop per-scene grading visually identical to pre-refactor; mobile color grading applies and stays within frame budget (~1.5ms cap on reference hardware)
- [ ] Color-blind filter regression-clean (untouched by refactor)

---

## Cross-Cutting Concerns (Address Opportunistically During C1–C11)

- `Callable(self, "_update_particles_and_focus")` repeated 11 times in `m_scene_manager.gd` — extract once
- `M_DisplayManager._ensure_appliers()` called from 16 call sites plus `_ready` — init once in `_ready` or use lazy-init with guaranteed single init
- Three identical `_get_*_hash` methods in `M_DisplayManager` — generic `_compute_slice_hash`
- `U_GameplayReducer.duplicate(true)` boilerplate — `set_field(state, key, value)` helper
- `U_GameplayReducer` damage/heal/death near-identical patterns — `_modify_health(state, entity_id, delta)`
- `M_SaveManager._build_metadata` reaching into state internals — use selectors (covered by C8)
- `M_ObjectivesManager._on_action_dispatched` monolithic router — split per-action handlers
- `BaseECSSystem._warn_missing_manager_method` is dead code — delete
- `U_ECS_EVENT_BUS.publish()` duplicates the subscriber list (.duplicate()) on every publish call — consider copy-on-write or deferred dispatch
- `M_ECSManager.query_entities` and `query_entities_readonly` near-duplicates — extract shared query logic
- `M_ECSManager._invalidate_query_cache` clears ALL entries — scoped invalidation per component type
- `M_StateStore._input` handles two unrelated debug overlays + cursor_manager call — extract to dedicated debug overlay handler
- `M_StateStore._sync_navigation_initial_scene` bypasses reducer/dispatch — should dispatch a proper navigation action
- `M_StateStore._initialize_slices` passes 17 positional arguments to `U_STATE_SLICE_MANAGER.initialize_slices` — should use a config object

---

## Instructions — YOU MUST DO THIS - NON-NEGOTIABLE

### 1. Review Project Foundations

- `AGENTS.md` — Project conventions, ECS guidelines, QB v2 patterns.
- `docs/general/DEV_PITFALLS.md` — Common mistakes to avoid.
- `docs/general/STYLE_GUIDE.md` — Code style, naming prefixes, formatting requirements.

### 2. Review Cleanup Task Checklist

- `docs/general/cleanup_v7/cleanup-v7-tasks.md` — Full milestone details with commit-level checkboxes.

### 3. Understand Existing Architecture

Study these for the patterns being refactored:

- `scripts/ecs/systems/s_camera_state_system.gd` — QB v2 rule evaluation pipeline (the primary duplication target for C1).
- `scripts/ecs/systems/s_character_state_system.gd` — QB v2 rule evaluation pipeline (second duplication source).
- `scripts/ecs/systems/s_game_event_system.gd` — QB v2 rule evaluation pipeline (third duplication source).
- `scripts/ecs/base_ecs_system.gd` — Base system class, will gain `get_frame_state_snapshot` in C4 and `resolve_service` in C3.
- `scripts/managers/m_scene_manager.gd` — Overlay extraction target (C6).
- `scripts/managers/m_vcam_manager.gd` — Dependency resolution migration target (C3).
- `scripts/managers/m_character_lighting_manager.gd` — Dependency resolution migration target (C3).
- `scripts/managers/m_objectives_manager.gd` — Namespace support target (C7).
- `scripts/managers/m_display_manager.gd` — Hash deduplication + config migration target (C9).
- `scripts/managers/m_spawn_manager.gd` — Tag lookup migration target (C10).
- `scripts/managers/m_state_store.gd` — Selector enforcement boundary (C8).
- `scripts/ecs/systems/s_wall_visibility_system.gd` — God method decomposition target (C5).

Study these for the shared utility pattern (already established by R3/R4 in the AI refactor):

- `scripts/utils/ai/u_ai_goal_selector.gd` — Example of focused collaborator utility extracted from a monolithic system.
- `scripts/utils/ai/u_ai_task_runner.gd` — Example of focused collaborator utility.
- `scripts/utils/debug/u_debug_log_throttle.gd` — Example of shared utility extracted from duplicated code.
- `scripts/utils/debug/u_ai_render_probe.gd` — Example of shared utility extracted from duplicated code.
- `scripts/utils/ai/u_ai_task_state_keys.gd` — Example of magic-string key registry (C2 follows this pattern).
- `scripts/utils/qb/u_rule_scorer.gd` — Already shared across all three rule systems. C1 extracts the orchestration that calls INTO this.
- `scripts/utils/qb/u_rule_selector.gd` — Already shared across all three rule systems.
- `scripts/utils/qb/u_rule_state_tracker.gd` — Already shared across all three rule systems.

Study these for the config resource pattern (C9 will follow this):

- `scripts/resources/ecs/rs_wall_visibility_config.gd` (to be created)
- `scripts/resources/ecs/rs_camera_state_config.gd` (to be created)
- `scripts/resources/managers/rs_spawn_config.gd` (to be created)

### 4. Execute Cleanup Milestones in Order

Work through C1–C12 sequentially, respecting dependency graph:

- **C1** → Rule Evaluation Pipeline Extraction (unblocks C2)
- **C2** → Typed Rule Context (depends on C1 property readers)
- **C3** → Shared Dependency Resolution (independent, can overlap with C1–C2)
- **C4** → State Snapshot Extraction (independent, can overlap)
- **C5** → Wall Visibility Decomposition (independent of C2/C3, internal decomposition)
- **C6** → Scene Manager Overlay Extraction (independent of C2/C3, internal decomposition)
- **C7** → Objectives Namespace Support (depends on C2, C3)
- **C8** → Selector Enforcement — Managers (independent)
- **C9** → Config Resources (depends on C4 pattern)
- **C10** → Entity Tag Identification (depends on C8, C3)
- **C11** → Selector Enforcement — Systems/Helpers/Interactables/UI (depends on C8)
- **C12** → Post-Processing Pipeline Refactor (independent of C1–C11; scheduled last to isolate display-layer churn from state/ECS churn). Source of truth: `docs/general/cleanup_v7/post-process-refactor-tasks.md`.

### 5. Follow TDD Discipline

For each milestone:

1. Write the test first (unit or integration).
2. Run the test and verify it fails for the expected reason.
3. Implement the minimal code to make it pass.
4. Run the full test suite and verify no regressions.
5. Run `tests/unit/style/test_style_enforcement.gd` after any file creation or rename.
6. Commit with a clear, focused message.

### 6. Preserve Compatibility

You MUST:

- Keep all existing ECS systems, QB v2 consumers, state management flows, and manager APIs working.
- Follow existing composition patterns — compose shared utilities, do not create deep inheritance hierarchies.
- Maintain the existing `I_*` interface contracts and `M_*Manager` public APIs.
- Ensure all `@export` fields on new config resources have defaults matching the current `const` values so behavior is unchanged.
- Use `U_ECSEventBus` for event publishing (do not introduce direct signal connections where events already exist).
- Register new utilities following the `U_` prefix convention and new resources following the `RS_` prefix convention per `STYLE_GUIDE.md`.

---

## Key Design Decisions

- **Compose, don't inherit**: `U_RuleEvaluator` is a composed utility class, not a base class. Systems call pipeline steps (`evaluator.refresh()`, `evaluator.subscribe()`, `evaluator.evaluate()`) at the appropriate points in their own lifecycle. This matches the established `U_RuleScorer`/`U_RuleSelector`/`U_RuleStateTracker` pattern.
- **`U_RuleEvaluator` orchestrates, not replaces**: `U_RuleScorer`, `U_RuleSelector`, and `U_RuleStateTracker` are already shared across all three rule systems. `U_RuleEvaluator` extracts the orchestration that calls INTO these (refresh → subscribe → evaluate → gates → effects → mark_fired), not the scoring/selection/tracking themselves.
- **Backwards-compatible defaults**: All new `RS_*Config` resources must ship with `@export` values matching the current `const` values so no existing scene or test breaks.
- **Selector enforcement is phased**: C8+C11 enforce selector-first state reads for targeted manager/system/helper/interactable/UI scopes, with a small explicit deferred list in `test_style_enforcement.gd` tracked for post-C11 cleanup.
- **Context resources replace magic dictionaries**: After C2, rule systems build typed `RSRuleContext` objects instead of ad-hoc `Dictionary` instances with string keys.
- **Tag/metadata lookup is primary, not exclusive**: After C10, primary entity identification uses tags/metadata. Explicit naming fallbacks remain in selected compatibility/validation paths (`BaseECSEntity`, spawn/scene-loader fallbacks, and scene-contract validation) to avoid breaking legacy content.
- **Overlay helper is extracted, not moved**: C6 extracts overlay logic into `U_OverlayHelper` but `M_SceneManager` still owns the public API. Callers are unaffected.
- **Namespace objectives are additive**: C7 makes `_objectives_by_id` namespace-aware but single-set loading still works. The `load_objective_set` API is unchanged; multi-set loading is opt-in.
- **C8/C11 split**: C8 covers 17 manager/helper files first to establish the selector pattern, then C11 extends it to 11 system/helper/interactable/UI files.

---

## Critical Notes

- **No Autoloads**: Follow existing patterns. Managers live under the `Managers` node and register with `U_ServiceLocator`.
- **Style & Organization**: Follow `docs/general/STYLE_GUIDE.md` and node naming prefixes (`S_`, `C_`, `RS_`, `U_`, `I_`, `E_`, `M_`).
- **Update Docs After Each Milestone**: Update `cleanup-v7-tasks.md` completion notes and this continuation prompt after completing each milestone.
- **Test Suite Command**: `tools/run_gut_suite.sh` (or `tools/run_gut_suite.sh -gtest=res://tests/unit/...` for targeted suites).
- **Style Test**: `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd`
- **`_get_frame_state_snapshot` has 3 variants**: The common pattern (camera, character, AI behavior) uses `_resolve_store()`. Wall-visibility adds emptiness validation. VCam uses `_runtime_services_helper.resolve_state_store()`. C4 must handle all three.
- **`M_StateStore.dispatch` creates ONE shared deep copy**: The original concern about "deep copy per subscriber" was wrong — the code already shares a single snapshot. The real publish-concern is `U_ECS_EVENT_BUS.publish()` creating a subscriber list `.duplicate()` on every call.
- **`Callable(self, "_update_particles_and_focus")` has 11 call sites**: Not 7 as originally estimated.
- **`_initialize_slices` passes 17 positional arguments**: Not 15 as originally estimated.

---

## Next Steps

1. **Begin C12** — Post-Processing Pipeline Refactor per `docs/general/cleanup_v7/post-process-refactor-tasks.md`. C12 is the last milestone of cleanup-v7.
2. After C12 completes, run a full regression suite (desktop + mobile, including the C12 runtime validation steps) and review before merging.
3. Begin cleanup-v7.2 using `docs/general/cleanup_v7/cleanup-v7.2-tasks.md` only after the C12 work and regression pass are complete.
4. Opportunistically address cross-cutting concerns listed at the bottom of this document when touching relevant files during C12.
5. The 11 deferred selector-enforcement files (in `test_all_production_files_use_selectors_for_state_access` allowed list) should be migrated in a follow-up pass after C12 lands.
