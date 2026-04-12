# Cross-System Cleanup — Tasks Checklist

**Branch**: TBD
**Status**: Not started
**Methodology**: TDD (Red-Green-Refactor) — tests written within each milestone, not deferred
**Scope**: Modularity, DRY, scalability, and designer-friendliness improvements across managers and ECS systems. No behavioral changes. All existing integration tests must stay green throughout.

---

## Purpose

Over time, managers and ECS systems have accumulated shared patterns that were implemented independently rather than abstracted. This cleanup is a targeted, backwards-compatible pass to:

1. **DRY** — Extract the rule evaluation pipeline, property readers, dependency resolution, and state snapshot helpers that are copy-pasted across 3–6 systems.
2. **Modularity** — Decompose god methods, separate mixed concerns, and enforce boundaries (selectors over direct state access, typed contexts over magic-string dictionaries).
3. **Scalability** — Replace hardcoded limits, flat dictionaries, and naming-convention coupling with data-driven patterns that grow without code changes.
4. **Designer-friendliness** — Move gameplay-feel constants from `const`/inline literals into `Resource` configs and eliminate fragile node-name conventions.

---

## Sequencing

`C1` lands first — eliminates the widest DRY violation (rule pipeline + property readers) and unblocks typed context work in C2.
`C2` depends on C1 — typed contexts need the property reader utilities extracted in C1.
`C3` is independent — dependency resolution extraction touches many files but is mechanical.
`C4` is independent — can overlap with C1–C3.
`C5` is independent of C2/C3 — wall visibility decomposition is internal, no typed context or shared resolution dependency.
`C6` is independent of C2/C3 — overlay extraction is internal to scene manager.
`C7` depends on C2 (typed contexts) and C3 (shared resolution).
`C8` is independent — selector enforcement for managers is self-contained.
`C9` depends on C4 (Resource config pattern established by BaseECSSystem snapshot method) — migrates constants to configs.
`C10` depends on C8 (selectors) and C3 (shared resolution) — replaces naming-convention coupling.
`C11` depends on C8 — extends selector enforcement to systems, helpers, interactables, and UI files once the manager patterns are established.
`C12` is independent of C1–C11 — post-processing pipeline refactor touches display manager helpers, display state, and shaders; no overlap with rule engine, selectors, or scene manager milestones. May run in parallel with any other milestone. See `docs/general/cleanup_v7/post-process-refactor-tasks.md` for the full checklist.

---

## Milestone C1: Rule Evaluation Pipeline Extraction — COMPLETE

**Completed**: 2026-04-11

**Summary**: `U_RuleEvaluator` (commits 1-5) was already in place — systems already delegated rule evaluation orchestration to it. Commit 6 extracted property reader utilities to `U_RuleUtils`, eliminating ~150 lines of duplicated code across 5 files. `U_RuleEvaluator` itself was updated to delegate property reads to `U_RuleUtils`.

- [x] **Commit 1** — Add rule evaluator tests (TDD RED): `tests/unit/ecs/systems/test_u_rule_evaluator.gd`
- [x] **Commit 2** — Implement `U_RuleEvaluator` (TDD GREEN): `scripts/utils/ecs/u_rule_evaluator.gd`
- [x] **Commit 3** — Refactor `s_camera_state_system.gd` to use `U_RuleEvaluator`
- [x] **Commit 4** — Refactor `s_character_state_system.gd` to use `U_RuleEvaluator`
- [x] **Commit 5** — Refactor `s_game_event_system.gd` to use `U_RuleEvaluator`
- [x] **Commit 6** — Extract property reader utilities to `U_RuleUtils`:
  - Created `scripts/utils/ecs/u_rule_utils.gd` with static methods: `read_string_property`, `read_string_name_property`, `read_bool_property`, `read_float_property`, `is_script_instance_of`, `object_has_property`, `variant_to_string_name`, `get_context_value`, `extract_event_names_from_rule` (with composite condition support).
  - Migrated `s_camera_state_system.gd`, `s_character_state_system.gd`, `s_game_event_system.gd` to use `U_RuleUtils`.
  - Migrated `u_vcam_runtime_context.gd` and `u_vcam_landing_impact.gd` to use `U_RuleUtils.variant_to_string_name`.
  - Updated `U_RuleEvaluator` to delegate property reads to `U_RuleUtils`.
  - Added `test_rule_systems_and_helpers_do_not_duplicate_property_readers` style enforcement grep test.
  - Created `tests/unit/ecs/test_u_rule_utils.gd` (44 tests, all green).

**C1 Retroactive Gap Fixes** (commit `56d63aee`):
- [x] **C1.7** — Add `read_array_property` and `read_int_property` to `U_RuleUtils` + tests. These methods were needed by QB pipeline utilities but were missing from the original C1 extraction.
- [x] **C1.8** — Migrate QB pipeline utilities (`u_rule_validator`, `u_rule_scorer`, `u_rule_selector`) to use `U_RuleUtils` instead of local `_read_*`/`_is_script_instance_of` methods. Deleted 10 local method definitions (~53 lines removed from `u_rule_validator` alone). Extended `test_rule_systems_and_helpers_do_not_duplicate_property_readers` to cover QB files and forbid `_read_array_property`/`_read_int_property`.

**C1 Verification**:
- [x] All new `U_RuleEvaluator` and `U_RuleUtils` tests green
- [x] Existing camera-state, character-state, game-event tests green (no behavior change)
- [x] Grep-based style test green (no local rule pipeline methods in the three systems)
- [x] `test_style_enforcement.gd` passes
- [x] `_variant_to_string_name` no longer defined in `u_vcam_runtime_context.gd` or `u_vcam_landing_impact.gd`
- [x] Zero `_read_string_property`/`_read_string_name_property`/`_read_bool_property`/`_read_float_property`/`_read_int_property`/`_read_array_property`/`_is_script_instance_of` in `scripts/utils/qb/` (style enforcement)

---

## Milestone C2: Typed Rule Context — COMPLETE

**Completed**: 2026-04-11

**Summary**: Created `RSRuleContext` (Resource) with 28 StringName key constants (following U_AITaskStateKeys pattern) and typed properties for all rule system context fields. Systems build RSRuleContext objects and convert to Dictionary via `to_dictionary()` for compatibility with QB conditions/effects. All bare string context key literals replaced with `RSRuleContext.KEY_*` constants. Full test suite (3993 passing, 0 failing) and style enforcement green.

- [x] **Commit 1** — Add context resource tests (TDD RED):
  - `tests/unit/ecs/resources/test_rs_rule_context.gd` — 18 tests covering key constants, default values, to_dictionary() conversion, StringName keys, extra keys, and U_RuleUtils compatibility.
- [x] **Commit 2** — Implement typed context (TDD GREEN):
  - `scripts/resources/ecs/rs_rule_context.gd` — `class_name RSRuleContext extends Resource` with 28 StringName key constants, typed properties with defaults, `to_dictionary()` method, and `set_extra`/`get_extra` for runtime key additions.
- [x] **Commit 3** — Migrate `s_camera_state_system.gd` to use `RSRuleContext`. Replace `_attach_camera_context` dictionary building with RSRuleContext construction. Replace `RULE_SCORE_CONTEXT_KEY` with `RSRuleContext.KEY_RULE_SCORE`.
- [x] **Commit 4** — Migrate `s_character_state_system.gd` to use `RSRuleContext`. Remove `StringName`/`String` dual-keying in `_context_key_for_context`. Replace all bare string context keys with `RSRuleContext.KEY_*` constants.
- [x] **Commit 5** — Migrate `s_game_event_system.gd` to use `RSRuleContext`. Replace `_build_tick_context` and `_build_event_context` dictionaries with RSRuleContext construction.

**C2 Retroactive Gap Fixes** (commits `56d63aee`, `baa5995d`):
- [x] **C2.6** — Add `KEY_BRAIN_COMPONENT` + `brain_component` property to `RSRuleContext`. Fix stale TDD RED comment in `test_rs_rule_context.gd:5`. Add 4 new tests for brain_component.
- [x] **C2.7** — Migrate `U_AIContextBuilder` to `RSRuleContext`. Rewrite `build()` to construct `RSRuleContext.new()`, set typed properties, return `.to_dictionary()`. Remove `_set_fallback_components`. Fix latent bug: AI context now produces `"state"` alias via `to_dictionary()`.
- [x] **C2.8** — Migrate `M_ObjectivesManager` and `M_SceneDirectorManager` to `RSRuleContext`. Fix latent bug: both managers' contexts now produce `"state"` alias via `to_dictionary()`, so QB conditions reading `context["state"]` work correctly.
- [x] **C2.9** — Expand style enforcement grep test for bare-string context keys. Add `u_ai_context_builder`, `m_objectives_manager`, `m_scene_director_manager` to scanned files. Add `test_context_builders_do_not_use_bare_string_context_keys` test.
- [x] **C2.10** — Migrate `RS_RULE_CONTEXT` preload pattern to `RSRuleContext` class reference. Replace `const RS_RULE_CONTEXT := preload(...)` with `const RSRuleContext := preload(...)` and `RS_RULE_CONTEXT.KEY_*`/`RS_RULE_CONTEXT.new()` with `RSRuleContext.KEY_*`/`RSRuleContext.new()` in all 3 rule systems. Update style enforcement allowed patterns.

**C2 Verification**:
- [x] All context resource tests green
- [x] All three rule systems' existing tests green
- [x] No bare string keys used for context field access in rule systems (grep test)
- [x] All 6 context builders (3 systems + AI builder + 2 managers) use `RSRuleContext` typed properties
- [x] Zero `RS_RULE_CONTEXT` references in `scripts/` (all migrated to `RSRuleContext`)
- [x] Stale TDD RED comment removed from `test_rs_rule_context.gd`

---

## Milestone C3: Shared Dependency Resolution — COMPLETE

**Completed**: 2026-04-11

**Summary**: Created `U_DependencyResolution` (RefCounted utility class) with two static methods: `resolve()` for generic cache→export→ServiceLocator resolution, and `resolve_state_store()` for state store resolution via U_StateUtils. Added `resolve_service()` convenience method to `BaseECSSystem`. Migrated 13 files (8 ECS systems, 3 managers, 2 interactables) from inline resolve patterns to the shared utility. Removed ~65 lines of duplicated code. Added style enforcement grep test verifying migrated files no longer contain inline `U_STATE_UTILS.try_get_store` calls.

- [x] **Commit 1** — Add resolution utility tests (TDD RED):
  - `tests/unit/core/test_u_dependency_resolution.gd` — 18 tests covering: cache hit, export fallback, ServiceLocator fallback, null when unavailable, freed object handling, state store specialization, null/freed owner handling.
- [x] **Commit 2** — Implement `U_DependencyResolution` (TDD GREEN):
  - `scripts/utils/core/u_dependency_resolution.gd` — `resolve(service_name, cached_value, exported_value)` for generic 3-step resolution; `resolve_state_store(cached_value, exported_value, owner)` for state store resolution via U_StateUtils.
- [x] **Commit 3** — Add `resolve_service` to `BaseECSSystem`, migrate all 8 ECS systems:
  - `scripts/ecs/base_ecs_system.gd` — added `resolve_service(service_name, cached_value, exported_value)` convenience method.
  - Migrated `_resolve_store`/`_resolve_state_store`/`_resolve_camera_manager` in all 8 systems to use `U_DependencyResolution`.
  - Removed unused `U_STATE_UTILS` and `U_SERVICE_LOCATOR` preloads from migrated systems.
- [x] **Commit 4** — Migrate manager and other resolution:
  - `m_vcam_manager` — replaced `_resolve_state_store`, `_resolve_camera_manager`, `_resolve_ecs_manager` with `U_DependencyResolution` calls.
  - `m_character_lighting_manager` — replaced `_resolve_dependencies` state_store and scene_manager resolution with `U_DependencyResolution`; kept ECS manager with `U_ECS_UTILS` fallback.
  - `m_run_coordinator_manager` — replaced `_resolve_store` with `U_DependencyResolution.resolve_state_store()` + ServiceLocator fallback.
  - `inter_victory_zone` — replaced `_resolve_store` with `U_DependencyResolution.resolve_state_store()`.
  - `inter_ai_demo_guard_barrier` — replaced `_resolve_store` with `U_DependencyResolution.resolve_state_store()`.
  - Note: `u_vcam_debug._resolve_state_store()` uses a Callable provider pattern (not cache→export→ServiceLocator) and `m_display_manager._await_store_ready_soft()` uses an async await pattern — these are architecturally different and were left as-is.
- [x] **C3 Verification** — Style enforcement grep test:
  - `test_migrated_files_do_not_duplicate_dependency_resolution_pattern` verifies 13 migrated files no longer contain inline `U_STATE_UTILS.try_get_store` or `U_StateUtils.try_get_store`.
- [x] All affected manager and system tests green
- [x] No local `_resolve_*` methods that duplicate the shared pattern (grep test)

---

## Milestone C4: State Snapshot Extraction to BaseECSSystem — COMPLETE

**Completed**: 2026-04-11

**Summary**: Extracted `_get_frame_state_snapshot` from 4 systems and `_resolve_redux_state` from 1 system into `BaseECSSystem.get_frame_state_snapshot()`. The base method tries the ECS manager's snapshot (skipping empty), falls back to state store via virtual `_resolve_state_store()`, and returns empty dict if neither is available. Each system overrides `_resolve_state_store()` to pass its `@export var state_store` or specialized resolution. Removed `_get_ecs_manager()` from wall_visibility_system (redundant with `get_manager()`). Removed ~85 lines of duplicated snapshot logic.

- [x] **Commit 1** — Add snapshot tests (TDD RED):
  - `tests/unit/ecs/test_base_ecs_system_snapshot.gd` — 10 tests covering manager snapshot, empty manager fallback, store fallback, ServiceLocator resolution, export override, integration.
- [x] **Commit 2** — Add `get_frame_state_snapshot` and `_resolve_state_store` to `BaseECSSystem` (TDD GREEN):
  - `scripts/ecs/base_ecs_system.gd` — `get_frame_state_snapshot()` tries manager (skips empty), falls back to `_resolve_state_store()`. Default `_resolve_state_store()` uses `U_DependencyResolution.resolve_state_store(null, null, self)`.
- [x] **Commit 3** — Migrate all five systems to use `get_frame_state_snapshot`:
  - `s_camera_state_system.gd` — removed `_get_frame_state_snapshot`, added `_resolve_state_store()` override delegating to `_resolve_store()`. Removed redundant emptiness check at call site.
  - `s_character_state_system.gd` — removed `_get_frame_state_snapshot`, added `_resolve_state_store()` override delegating to `_resolve_store()`. Removed redundant emptiness check at call site.
  - `s_vcam_system.gd` — removed `_get_frame_state_snapshot`, added `_resolve_state_store()` override using `_runtime_services_helper.resolve_state_store()`.
  - `s_wall_visibility_system.gd` — removed `_get_frame_state_snapshot` and `_get_ecs_manager()`. Existing `_resolve_state_store()` serves as the override. Removed `U_SERVICE_LOCATOR` preload.
  - `s_ai_behavior_system.gd` — removed `_resolve_redux_state()`, uses inherited `get_frame_state_snapshot()`. Added `_resolve_state_store()` override delegating to `_resolve_store()`.

**C4 Verification**:
- [x] All snapshot tests green
- [x] All five systems' existing tests green
- [x] No `_get_frame_state_snapshot` defined in any ECS system (grep test)

---

## Milestone C5: Wall Visibility System Decomposition — COMPLETE

**Completed**: 2026-04-11

**Summary**: Decomposed the 197-line `process_tick` god method into 9 focused methods, and replaced type-dispatch switches with a registry pattern. `process_tick` reduced from 197 lines to 49 lines.

- [x] **Commit 1** — Add method-level tests (TDD RED):
  - `tests/unit/ecs/systems/test_s_wall_visibility_system_decomposition.gd` — 25 tests covering: `_resolve_tick_data`, `_filter_rooms_by_aabb`, `_deduplicate_targets`, `_apply_wall_materials`, `_detect_roofs`, `_cleanup_stale_targets`, and process_tick line count verification.
- [x] **Commit 2** — Decompose `process_tick` (TDD GREEN):
  - Extracted `_resolve_tick_data`: consolidates state/camera/applier/player resolution into a Dictionary.
  - Extracted `_process_component_fade`: per-component two-pass fade computation.
  - Extracted `_apply_wall_materials`: mobile hide vs shader material application.
  - Extracted `_detect_roofs`: batch roof detection via `_is_roof_candidate_target`.
  - Renamed `_restore_stale_targets_inplace` → `_cleanup_stale_targets`.
  - Extracted `_filter_rooms_by_aabb` and `_deduplicate_targets` from `_prepare_tick_data`.
- [x] **Commit 3** — Replace type-dispatch switch with target type registry:
  - `_register_target_type_handler(type_name, aabb_resolver, half_extents_resolver)` for extensible target type resolution.
  - Two-tier matching: exact class match first (get_class), inheritance fallback second (is_class).
  - Per-type resolvers: `_resolve_csg_box_aabb`, `_resolve_mesh_aabb`, `_resolve_csg_shape_aabb`, `_resolve_csg_box_planar_half_extents`, `_resolve_mesh_planar_half_extents`.
  - 8 registry tests including custom handler registration for CSGCylinder3D and style enforcement.

**C5 Verification**:
- [x] All decomposition tests green (33 tests: 25 original + 8 registry)
- [x] Existing wall-visibility integration tests green (4 integration + 30 unit)
- [x] `process_tick` method under 60 lines (49 lines)

---

## Milestone C6: Scene Manager Overlay Extraction — COMPLETE

**Completed**: 2026-04-11

**Summary**: Commits 1-3 (overlay helper extraction) were already in place — `U_OverlayStackManager` already implements all overlay logic (push, pop, return stack, reconciliation, visibility) and is wired into `M_SceneManager`. Commit 4 decomposed the `_perform_transition` god method from 155 lines to 23 lines by extracting three focused methods.

- [x] **Commit 1** — Overlay helper tests: Already exist for `U_OverlayStackManager` (covered by existing `test_m_scene_manager.gd` overlay tests).
- [x] **Commit 2** — Extract overlay helper: `U_OverlayStackManager` already exists at `scripts/scene_management/helpers/u_overlay_stack_manager.gd` (365 lines, all overlay logic delegated).
- [x] **Commit 3** — Wire `M_SceneManager` to overlay helper: Already wired — `push_overlay`, `pop_overlay`, etc. delegate to `_overlay_helper` (a `U_OverlayStackManager` instance).
- [x] **Commit 4** — Decompose `_perform_transition` god method (155 lines → 23 lines):
  - Extracted `_prepare_transition_context(request, scene_path)` — cache check, progress callback, camera state capture, context Dictionary assembly.
  - Extracted `_execute_scene_swap(request, scene_path, transition_ctx)` — scene removal, loading (cached/async/sync), validation, camera blending, handler delegation, action dispatch. Replaces the 88-line `scene_swap_callback` closure.
  - Extracted `_finalize_camera_blend(transition_ctx)` — post-transition camera finalization with active blend tween guard.
  - Removed vestigial `scene_swap_complete` tracker (set but never read).
  - Added `tests/unit/scene_manager/test_m_scene_manager_decomposition.gd` (10 tests covering context keys, cache state, blend conditions, camera manager null guard, line count).

**C6 Verification**:
- [x] All overlay helper tests green (existing test_m_scene_manager.gd covers overlay push/pop/return)
- [x] Existing scene-manager tests green (no public API changes)
- [x] `_perform_transition` under 40 lines (23 lines, orchestration only)

---

## Milestone C7: Objectives Manager Namespace Support

**Goal**: Replace `_objectives_by_id` flat dictionary with namespace-aware storage so multiple objective sets can be active simultaneously. Currently `_load_objective_set_internal` replaces the entire previous set.

- [ ] **Commit 1** — Add namespace tests (TDD RED):
  - `tests/unit/managers/test_m_objectives_manager_namespaces.gd` — test loading a second objective set without replacing the first, evaluating across sets, and completing objectives in different namespaces.
- [ ] **Commit 2** — Implement namespace support (TDD GREEN):
  - `scripts/managers/m_objectives_manager.gd` — change `_objectives_by_id: Dictionary` to `_objective_sets: Dictionary[StringName, Dictionary]`, keyed by set ID. Update `_evaluate_active_objectives`, `_on_action_dispatched`, and all lookup methods to iterate active sets.
- [ ] **Commit 3** — Add selector/query methods for cross-set objective queries.

**C7 Verification**:
- [ ] All namespace tests green
- [ ] Existing objectives-manager tests green (backwards-compatible: single-set loads still work)
- [ ] Grep test: no direct `state.get("objectives", {})` outside selectors

---

## Milestone C8: Selector Enforcement — Managers

**Goal**: Eliminate the pattern of managers reaching into state slice internals by key path. All state reads outside reducers should go through `U_*_selectors`. This milestone covers **manager and helper files only**; systems, interactables, and UI are covered in C11.

**Scope** (17 files):
- `m_vcam_manager`, `m_save_manager`, `m_objectives_manager`, `m_scene_manager`, `m_display_manager`, `m_spawn_manager`, `m_vfx_manager`, `m_audio_manager`, `m_time_manager`, `m_localization_manager`, `m_screenshot_cache_manager`, `m_ui_input_handler`, `m_input_profile_manager`, `m_input_device_manager`, `m_scene_director_manager`, `u_autosave_scheduler`, `u_vcam_soft_zone`

**Existing selectors**: `get_player_entity_id` already exists in `u_entity_selectors.gd` — do not duplicate it. `u_gameplay_selectors.gd` only has 3 selectors (`is_paused`, `get_last_checkpoint`, `is_touch_look_active`) and needs many additions. No `u_scene_selectors.gd` exists yet — it needs to be created.

- [ ] **Commit 1** — Audit all 18 selector files and add missing selector methods:
  - `scripts/state/selectors/u_gameplay_selectors.gd` — add `get_playtime_seconds`, `get_player_health`, `get_target_spawn_point`, `get_last_victory_objective`, `get_entity_snapshot`, `get_ai_demo_flags`, etc.
  - Create `scripts/state/selectors/u_scene_selectors.gd` — add `get_current_scene_id`, `get_scene_stack`, `get_previous_scene_id`, `is_transitioning`, etc.
  - Add selectors for all slices where managers do direct access: `u_vcam_selectors.gd`, `u_navigation_selectors.gd`, `u_time_selectors.gd`, `u_settings_selectors.gd`, `u_objectives_selectors.gd`, `u_audio_selectors.gd`, `u_localization_selectors.gd`.
  - Note: `get_player_entity_id` already exists in `u_entity_selectors.gd` — reference it, don't duplicate.
- [ ] **Commit 2** — Migrate all 17 manager/helper files to use selectors instead of `state.get("`:
  - Replace `state.get("gameplay", {})["player_entity_id"]` with `U_EntitySelectors.get_player_entity_id(state)`.
  - Replace `state.get("gameplay", {}).get("playtime_seconds", 0)` with `U_GameplaySelectors.get_playtime_seconds(state)`.
  - Replace `state.get("objectives", {})` with `U_ObjectivesSelectors._get_slice(state)`.
  - Replace `state.get("scene", {})["current_scene_id"]` with `U_SceneSelectors.get_current_scene_id(state)`.
  - Replace all other `state.get("<slice>", {})` patterns in the 17 files.
- [ ] **Commit 3** — Add style enforcement grep test:
  - `tests/unit/style/test_style_enforcement.gd` — add test asserting no manager or helper file contains `state.get("` or `state["` outside of `m_state_store.gd` and reducers.

**C8 Verification**:
- [ ] All selector tests green
- [ ] All manager tests green (no behavioral change)
- [ ] Grep test: zero `state.get("` or `state["` occurrences in manager/helper files

---

## Milestone C9: Gameplay-Feel Constants → Resource Configs

**Goal**: Move hardcoded gameplay-feel constants from `const` and inline literals into `Resource` configs so designers can tune values without code changes. Applies to: wall-visibility fade/clip/room constants, camera shake/FOV constants, movement thresholds, spawn snap distances, character-lighting defaults, and display scale limits.

- [ ] **Commit 1** — Create config resource tests (TDD RED):
  - `tests/unit/resources/ecs/test_rs_wall_visibility_config.gd` — test config resource with all tuneable fields and defaults.
  - `tests/unit/resources/ecs/test_rs_camera_state_config.gd` — test config resource for shake/FOV params.
  - `tests/unit/resources/test_rs_spawn_config.gd` — test config resource for ground/hover snap distances.
- [ ] **Commit 2** — Implement config resources (TDD GREEN):
  - `scripts/resources/ecs/rs_wall_visibility_config.gd` — `class_name RS_WallVisibilityConfig extends Resource` with `@export` fields for `fade_dot_threshold`, `fade_speed`, `min_alpha`, `clip_height_offset`, `room_aabb_margin`, `corridor_occlusion_margin`, `invalidate_interval`, `mobile_tick_interval`, `roof_normal_dot_min`, `roof_height_margin`. All with current `const` values as defaults.
  - `scripts/resources/ecs/rs_camera_state_config.gd` — `class_name RS_CameraStateConfig extends Resource` with `@export` fields for shake parameters (`trauma_decay_rate`, `max_offset_x`, `max_offset_y`, `shake_frequency`, `shake_phase`), FOV clamps (`fov_min`, `fov_max`), and other tuneable values.
  - `scripts/resources/managers/rs_spawn_config.gd` — `class_name RS_SpawnConfig extends Resource` with `@export` fields for `ground_snap_max_distance`, `hover_snap_max_distance`, spawn conditions.
- [ ] **Commit 3** — Migrate `s_wall_visibility_system.gd` to use `RS_WallVisibilityConfig`. Replace `const` values with config reads (falling back to defaults).
- [ ] **Commit 4** — Migrate `s_camera_state_system.gd` to use `RS_CameraStateConfig`. Replace shake `const` values and scattered FOV clamp literals with config reads.
- [ ] **Commit 5** — Migrate `m_spawn_manager.gd` to use `RS_SpawnConfig`. Replace hardcoded `SPAWN_GROUND_SNAP_MAX_DISTANCE`, `SPAWN_HOVER_SNAP_MAX_DISTANCE`, and `SPAWN_CONDITION_*` enum.
- [ ] **Commit 6** — Migrate `m_character_lighting_manager.gd` default profile and `MOBILE_TICK_INTERVAL` to config.
- [ ] **Commit 7** — Migrate `m_display_manager.gd` `MIN_UI_SCALE`/`MAX_UI_SCALE` to config.

**C9 Verification**:
- [ ] All config resource tests green
- [ ] All affected system/manager tests green (no behavioral change — defaults match old `const` values)
- [ ] Each config resource is inspector-editable (has `@export` on all fields)

---

## Milestone C10: Entity Identification by Tags/Metadata (Kill Naming Conventions)

**Goal**: Replace fragile node-name-based entity identification patterns with tag/metadata lookups. Currently: `M_SpawnManager._find_player_entity` hardcodes `"E_Player"`, `BaseECSEntity._generate_id_from_name` strips `"E_"` prefix, `S_MovementSystem._infer_entity_type_from_name` matches strings, `M_VCamManager._resolve_mode_name` strips `"RS_VCamMode"` prefix. All of these break silently if naming conventions change and require programmer intervention for new types.

**Note**: `BaseECSEntity._generate_id_from_name` already has collision detection via `M_ECSManager.register_entity`, which appends instance IDs on collision. This existing safety net should be preserved — C10 adds tag/metadata lookup as the primary path, with name-based fallback retained.

- [ ] **Commit 1** — Add tag-based lookup tests (TDD RED):
  - `tests/unit/ecs/test_entity_tag_identification.gd` — test that entities can be found by tag rather than name prefix, test entity ID generation from metadata rather than name stripping.
- [ ] **Commit 2** — Implement tag-based lookups (TDD GREEN):
  - `scripts/ecs/u_entity_lookup.gd` — `class_name U_EntityLookup` with static methods `find_entity_by_tag(ecs_manager, tag)`, `find_entities_by_tag(ecs_manager, tag)`, `resolve_entity_id(entity)` that prefer metadata/component over name parsing, falling back to current behavior.
- [ ] **Commit 3** — Migrate `M_SpawnManager._find_player_entity` to use tag-based lookup. The spawn manager should find the player by a `player` tag, not by `"E_Player"` name prefix.
- [ ] **Commit 4** — Migrate `S_MovementSystem._infer_entity_type_from_name` to use tag/metadata lookup. Entity type should come from a component or tag, not string matching on node names.
- [ ] **Commit 5** — Migrate `M_VCamManager._resolve_mode_name` to use resource metadata or `resource_name` instead of stripping `"RS_VCamMode"` prefix.
- [ ] **Commit 6** — Update `BaseECSEntity._generate_id_from_name` to prefer a component-provided ID or metadata tag, with name-stripping as fallback only. Preserve the existing collision detection in `M_ECSManager.register_entity`.

**C10 Verification**:
- [ ] All entity lookup tests green
- [ ] All affected manager and system tests green
- [ ] Grep test: no `"E_Player"`, `"E_"` prefix assumptions, or `"RS_VCamMode"` prefix stripping in production code

---

## Milestone C11: Selector Enforcement — Systems, Helpers, Interactables, and UI

**Goal**: Extend C8's selector enforcement beyond managers to cover ECS systems, helper utilities, gameplay interactables, and UI files. These files also reach directly into state slices by key path.

**Scope** (11 files):
- ECS systems: `s_victory_handler_system`, `s_input_system`, `s_gamepad_vibration_system`, `base_event_sfx_system`
- Helpers: `u_vcam_runtime_context`, `u_vcam_debug`
- Interactables: `inter_victory_zone`, `inter_ai_demo_guard_barrier`
- UI: `ui_victory`, `ui_game_over`, `ui_gamepad_settings_overlay`

- [ ] **Commit 1** — Migrate ECS systems to use selectors:
  - `scripts/ecs/systems/s_victory_handler_system.gd` — replace `state.get("gameplay", {})` and `state.get("objectives", {})`.
  - `scripts/ecs/systems/s_input_system.gd` — replace `state.get("gameplay", {})`.
  - `scripts/ecs/systems/s_gamepad_vibration_system.gd` — replace `state.get("gameplay", {})`.
  - `scripts/ecs/base_event_sfx_system.gd` — replace `state.get("gameplay", {})`.
- [ ] **Commit 2** — Migrate helpers and interactables to use selectors:
  - `scripts/ecs/systems/helpers/u_vcam_runtime_context.gd` — replace `state.get("gameplay", {})`.
  - `scripts/ecs/systems/helpers/u_vcam_debug.gd` — replace `state.get("gameplay", {})`.
  - `scripts/gameplay/inter_victory_zone.gd` — replace `state.get("gameplay", {})` and `state.get("objectives", {})`.
  - `scripts/gameplay/inter_ai_demo_guard_barrier.gd` — replace `state.get("gameplay", {})`.
- [ ] **Commit 3** — Migrate UI files to use selectors:
  - `scripts/ui/menus/ui_victory.gd` — replace direct state access.
  - `scripts/ui/menus/ui_game_over.gd` — replace direct state access.
  - `scripts/ui/overlays/ui_gamepad_settings_overlay.gd` — replace direct state access.
- [ ] **Commit 4** — Expand style enforcement grep test to cover all production files (not just managers):
  - `tests/unit/style/test_style_enforcement.gd` — extend test to assert no file under `scripts/` (excluding `scripts/state/reducers/` and `scripts/state/selectors/`) contains `state.get("` or `state["`.

**C11 Verification**:
- [ ] All affected system/helper/interactable/UI tests green
- [ ] Grep test: zero `state.get("` or `state["` occurrences in production code outside of `m_state_store.gd`, reducers, and selectors

---

## Milestone C12: Post-Processing Pipeline Refactor

**Goal**: Collapse the post-process surface to exactly two passes (color grading + grain/dither) behind a new `U_PostProcessPipeline` coordinator that mimics `CompositorEffect` ergonomics in `gl_compatibility` mode, remove CRT entirely, rename cinema_grade → color_grading across the codebase, and enable color grading on mobile.

**Standalone doc**: Full 10-commit breakdown, critical file list, and verification steps live in `docs/general/cleanup_v7/post-process-refactor-tasks.md`. This pointer exists to keep C12 discoverable from the cleanup-v7 index; the standalone doc is the source of truth.

**Summary**:
- [ ] **Commit 1** (RED) — Pipeline + removal tests
- [ ] **Commit 2** (GREEN) — CRT state removal
- [ ] **Commit 3** (GREEN) — CRT UI/localization removal
- [ ] **Commit 4** (GREEN) — CRT shader removal
- [ ] **Commit 5** (GREEN) — Color grading rename, state layer
- [ ] **Commit 6** (GREEN) — Color grading rename, resources + registry
- [ ] **Commit 7** (GREEN) — Color grading rename, applier + debug + UI + localization (mobile PCK cache warning)
- [ ] **Commit 8** (GREEN) — Introduce `U_PostProcessPipeline`
- [ ] **Commit 9** (GREEN) — Enable color grading on mobile
- [ ] **Commit 10** (GREEN) — Style enforcement + legacy cleanup

---

## Cross-Cutting Concerns (Not Milestones — Address Opportunistically)

These patterns recur across many systems. Rather than dedicated milestones, address them during C1–C11 when touching the relevant files:

- **`Callable(self, "_update_particles_and_focus")` repeated 11 times in `m_scene_manager.gd`** — Extract once, pass by reference.
- **`M_DisplayManager` `_ensure_appliers()` called from 16 call sites plus `_ready`** — Initialize once in `_ready` or `_enter_tree`, or use lazy-init that guarantees single init.
- **`M_DisplayManager` three identical `_get_*_hash` methods** — Generic `_compute_slice_hash(slice_name) -> int`.
- **`U_GameplayReducer` `.duplicate(true)` boilerplate** — A `set_field(state, key, value)` helper would eliminate ~15 duplicate-and-set-one-field cases.
- **`U_GameplayReducer` damage/heal/death near-identical patterns** — A `_modify_health(state, entity_id, delta)` helper.
- **`M_SaveManager._build_metadata` reaching into multiple state slices** — Should use selectors (covered by C8).
- **`M_ObjectivesManager._on_action_dispatched` monolithic router** — Split into per-action handler methods.
- **`BaseECSSystem._warn_missing_manager_method` is dead code** — Delete.
- **`U_ECS_EVENT_BUS.publish()` duplicates the subscriber list on every publish call** — Consider copy-on-write or deferred dispatch to avoid one allocation per event dispatch.
- **`M_ECSManager.query_entities` and `query_entities_readonly` are near-duplicates** — Extract shared query logic, differ only in mutability and metrics recording.
- **`M_ECSManager._invalidate_query_cache` clears ALL entries** — Use scoped invalidation per component type.
- **`M_StateStore._input` handles two unrelated debug overlays** — The state debug overlay and cinema debug overlay are separate UI concerns that call `cursor_manager.set_cursor_state`. Extract to a dedicated debug overlay handler.
- **`M_StateStore._sync_navigation_initial_scene` bypasses the reducer/dispatch pattern** — Directly mutates `_state["navigation"]` instead of dispatching a proper navigation action.