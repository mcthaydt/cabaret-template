# Cross-System Cleanup V7.2 — Implementation Guide & Continuation Prompt

## Overview

This guide directs you to implement Cross-System Cleanup V7.2 by following the tasks outlined in `docs/general/cleanup_v7/cleanup-v7.2-tasks.md` in sequential order, respecting the dependency graph documented below. V7.2 is the follow-up to V7 (C1–C12), addressing eight concrete architectural weaknesses that C1–C12 did not target, plus three additions (F8 Phase 0, F12, F15) surfaced during pre-implementation review.

**Branch**: GOAP-AI
**Status**: F4 complete — **F5 planned, ready to implement** (Communication Channel Taxonomy).
**Next Task**: Begin **F5 Commit 1** (RED grep tests) per `docs/general/cleanup_v7/cleanup-v7.2-tasks.md`.
**Prerequisite**: Full C1–C12 test suite green (desktop + mobile) before starting F2.

---

## Current Status: F4 Complete, F5 Next

F1–F4 are complete. The task file `docs/general/cleanup_v7/cleanup-v7.2-tasks.md` is the authoritative source for commit-level checklists; this continuation prompt is a working index and context bank.

- **F1 (SceneManager C6 Supplement)**: **ALREADY RESOLVED** during C6. Verification-only checkpoint (single commit adding style-enforcement grep assertions).
- **F2 (StateStore Dispatch — Share Snapshot)**: **COMPLETE**. Dispatch now uses `get_state()` instead of `_state.duplicate(true)`, populating the versioned cache. Zero-subscriber skip already in place.
- **F3 (StateStore — Eliminate Parallel Mutation Paths)**: **COMPLETE**. `_sync_navigation_initial_scene` now dispatches through reducer pipeline. All `slice_updated.emit` sites audited — bulk-load paths annotated with invariant comments. Style enforcement test forbids `_state[` mutations outside `m_state_store.gd`.
- **F4 (Slice Dependency Validator — Strict Mode)**: **COMPLETE**. `strict_slice_dependencies: bool = true` added to `RS_StateStoreSettings`; `get_slice` returns `{}` on undeclared access in strict mode. Audit found zero violations (no production code passes `caller_slice`). Default flipped to `true`. State suite 550/550 green.
- **F5 (Communication Channel Taxonomy)**: NOT STARTED. Depends on F3. Requires creating `docs/adr/` directory.
- **F5 (Communication Channel Taxonomy)**: NOT STARTED. Depends on F3. Requires creating `docs/adr/` directory.
- **F6 (ServiceLocator Scoping)**: NOT STARTED.
- **F7 (RS_Rule Typed-Schema Erasure)**: NOT STARTED. Gated on one-commit parser feasibility investigation (Path A vs Path B).
- **F8 (VCam + CameraState Decomposition — **Expanded v7.2.1**)**: NOT STARTED. **Phase 0 (Commits 1a/1b) decomposes oversized helpers before Phase 1+ pushes system logic into them.**
- **F9 (ECS System Execution Phasing)**: NOT STARTED. Extends existing `execution_priority` system.
- **F10 (State Store History Truncation)**: **ALREADY IMPLEMENTED**. Verification-only checkpoint.
- **F11 (Event Bus Zombie Prevention)**: NOT STARTED. Scope is `BaseEventBus`, not the `U_ECSEventBus` facade.
- **F12 (Settings Overlay Deduplication — v7.2.1 Addition)**: NOT STARTED. Independent, trivial DRY collapse.
- **F15 (Designer-Facing Resource Schema Validation — v7.2.1 Addition)**: NOT STARTED. Mirrors F7's pattern for three more resources.
- **F16 (AI System Type Safety & Consistency — v7.2.2 Addition)**: NOT STARTED. Independent. 6 commits: type Variant fields, push_error stubs, task-state key constants, debug snapshot, animate docs, grep enforcement.

---

## v7.2.1 Patch (Pre-Implementation Review Additions)

Before execution begins, the v7.2 plan received three additions and one rejection. All are documented in `cleanup-v7.2-tasks.md`:

- **F8 expanded (Phase 0)**: Original F8 would have pushed system logic into 800+ line helpers. Phase 0 decomposes `u_vcam_rotation.gd` (740 → three ~80/90/180-line files) and `u_vcam_orbit_effects.gd` (650 → three ~110-line files + 80-line residual) **before** Phase 1+ extracts system-level logic. `u_vcam_response_smoother.gd` (468 lines) is coherent and explicitly left alone.
- **F12 added**: Three settings overlay wrappers (`ui_audio_settings_overlay.gd`, `ui_display_settings_overlay.gd`, `ui_localization_settings_overlay.gd`) are 53 lines each, character-for-character identical except `class_name`. Collapsed into a single `base_settings_simple_overlay.gd`. `ui_vfx_settings_overlay.gd` is legitimately different (Apply/Cancel + inline controls) and stays out of scope.
- **F15 added**: Load-time schema validation for `RS_GameConfig` (HIGH risk — zero validation on `retry_scene_id`, `route_retry`, `default_objective_set_id`, `required_final_area`), `RS_InputProfile` (MEDIUM risk — malformed `virtual_buttons` entries), `RS_SceneRegistryEntry` (MEDIUM risk — editor-only warnings, no load-time enforcement). `RS_UIThemeConfig` is out of scope because `ensure_runtime_defaults()` already prevents crash-level failures.
- **F13/F14 rejected**: Pre-implementation audit verified `_character_lighting_history`, `_character_zone_hysteresis`, `S_WallVisibilitySystem` geometry caches, `U_SceneCache`, and `_scene_history` **all have proper cleanup** (per-character pruning, per-frame stale eviction, LRU + 100MB cap, clear on gameplay entry). No memory-leak milestone needed.

---

## v7.2.2 Patch (AI System Review Addition)

After the v7.2.1 additions, a deep-dive review of the AI system identified six inconsistencies where the AI codebase falls short of the non-AI project standards:

1. **Five `Variant`-typed service fields** in `S_AIBehaviorSystem` (`:28-32`) and two `Variant` parameters in `S_AIDetectionSystem` (`:75-76`) discard static type information.
2. **`Variant`-typed planner context** throughout `U_HTNPlanner` and `U_HTNPlannerContext.reusable_rule: Resource` instead of `RS_Rule`.
3. **`I_AIAction` silent stubs** — `pass` and `return false` instead of `push_error("not implemented")` matching `I_ECSManager`/`I_StateStore`/`I_Condition`.
4. **Raw string keys in task_state** — 5 action files use 9 bare string literals instead of `U_AITaskStateKeys` constants. `RS_AIActionMoveTo` already uses the constants.
5. **`C_AIBrainComponent` lacks `get_debug_snapshot()`** — `C_MovementComponent` and `C_JumpComponent` expose debug snapshots; brain component exposes raw dictionaries.
6. **`U_HTNPlanner._decompose_recursive` silently returns on null/depth-exceeded** — no `push_error` diagnostic.

**F16 added**: AI System Type Safety & Consistency. 6 commits: type Variant fields, push_error stubs, task-state key constants, debug snapshot, animate docs, grep enforcement. All fixes are type annotations, constant migrations, or additive methods — no behavioral changes.

---

## Problem Statement

Eight concrete weaknesses surfaced during a deep-dive architectural review after C1–C12:

1. **~~Cross-manager reflection hole~~** — Resolved during C6.
2. **Per-dispatch full-state deep copy floor** in `M_StateStore.dispatch()` that bypasses the versioned cache. Per-frame cost floor for every subscriber.
3. **Two parallel mutation paths** that bypass the reducer/history/validator pipeline (`_sync_navigation_initial_scene` direct mutation + four direct `slice_updated.emit` sites).
4. **Advisory-only slice-dependency validator** that fails open — declarations drift silently out of sync.
5. **Unresolved communication-channel taxonomy** (Redux vs `U_ECSEventBus` vs Godot signals) driving most "contract-by-comment" growth in `AGENTS.md`.
6. **Process-global `U_ServiceLocator` state** with last-write-wins `register()` and no per-test scope — root cause of multiple recurring test-failure patterns in `MEMORY.md`.
7. **Type erasure on `RS_Rule.conditions`/`effects: Array[Resource]`** — authoring errors surface as silent runtime "rule scored 0.0" with no stack trace.
8. **Two more large ECS systems** (`s_vcam_system.gd` at 551 lines, `s_camera_state_system.gd` at 587 lines) not targeted by C5.

The doc closes with a non-numbered reflection on `AGENTS.md` sprawl (not a milestone — revisit after F1–F8 land).

---

## Milestone F1: SceneManager C6 Supplement — ALREADY RESOLVED

**Goal**: Verification-only checkpoint. Both original gaps (reflection hole + Array-wrapper captures) were resolved during C6.

- [ ] **Commit 1** (VERIFY) — Add style-enforcement grep assertions in `tests/unit/style/test_style_enforcement.gd`:
  - `m_scene_manager.gd` contains zero matches of `_camera_blend_tween`.
  - `m_scene_manager.gd` contains zero matches of `get("_camera_blend_tween")`.
  - `_perform_transition` under 40 lines.

**F1 Verification**:
- [ ] Style enforcement tests green.
- [ ] Existing scene-transition integration tests green.

---

## Milestone F2: StateStore Dispatch — Share Snapshot Across Subscribers ✅

**Goal**: Eliminate the per-dispatch full-state deep copy at `m_state_store.gd:471` by using the store's existing versioned cache. With 16 slices and per-frame dispatches, this is a per-frame cost floor.

- [x] **Commit 1** (RED) — Dispatch-path tests: 5-subscriber reference identity, dispatch-populates-versioned-cache, zero-subscriber skip, 100-dispatch benchmark.
- [x] **Commit 2** (GREEN) — Refactor `dispatch()` to use `get_state()` instead of `_state.duplicate(true)`. Document the read-only subscriber contract (A1+A2 comment). Zero-subscriber skip already in place (`if not _subscribers.is_empty()` guard).
- [x] **Commit 3** (MERGED INTO COMMIT 2) — Skip was already implemented; no separate commit needed.

**F2 Verification**:
- [x] All new tests green (4/4).
- [x] Dispatch populates versioned cache (`_cached_state_version == _state_version` after dispatch with subscribers).
- [x] Zero-subscriber dispatch skips snapshot build (`_cached_state_version` unchanged).
- [x] Existing store/reducer tests green (30/30).
- [x] Full test suite green (4227/4235, 8 pending/risky as expected).
- [x] No observable behavior change for subscribers (snapshot contents identical).

---

## Milestone F3: StateStore — Eliminate Parallel Mutation Paths ✅

**Goal**: All mutations to `_state` must flow through `dispatch()` so that action history, version bumping, validator, and signal batching stay consistent.

- [x] **Commit 1** (RED) — Invariant tests in `test_m_state_store_dispatch_invariant.gd`: sync-initial-scene dispatches action; dispatch produces paired `action_dispatched` + `slice_updated`; init sync recorded in action history.
- [x] **Commit 2** (GREEN) — Added `U_NavigationActions.sync_initial_scene()` action + reducer branch; replaced direct `_state` mutation with `dispatch()`.
- [x] **Commit 3** (GREEN) — Audited all `slice_updated.emit` sites. Batched flush (`:255`) and immediate dispatch flush (`:485`) are dispatch-path. `load_state` (`:635`), `apply_loaded_state` (`:683`), and `_restore_from_handoff` (`:716`) annotated with `# INVARIANT:` comments explaining why direct mutation/emission is safe for bulk restoration.
- [x] **Commit 4** (GREEN) — Added `test_no_state_mutation_outside_store` style enforcement test (38/38 pass). Grep-based check forbids `_state[` assignment mutations outside `m_state_store.gd`.

**F3 Verification**:
- [x] No `slice_updated` emission without a paired `action_dispatched` in the same frame (normal path verified; bulk paths annotated).
- [x] `_sync_navigation_initial_scene` no longer directly mutates `_state`.
- [x] `action_history_buffer` records init sync action.
- [x] Grep test green.
- [x] Existing store tests green (76/77; 1 pre-existing failure unrelated to F3).

---

## Milestone F4: Slice Dependency Validator — Strict Mode ✅

**Goal**: The slice-dependency check at `m_state_store.gd:565-573` logs an error but **still returns the data**. Add strict-mode toggle, audit + fix violations, then flip default.

- [x] **Commit 1** (RED) — Strict-mode tests for both modes.
- [x] **Commit 2** (GREEN) — Add `strict_slice_dependencies: bool = false` to `RS_StateStoreSettings`. Implement strict branch.
- [x] **Commit 3** (GREEN) — Audit: enable strict mode at test-harness level, catalog every violation into a scratch file. No fixes yet.
- [x] **Commit 4** (GREEN) — No violations to fix; skipped as no-op (zero production `caller_slice` usage).
- [x] **Commit 5** (GREEN, **BEHAVIOR CHANGE**) — Flipped `strict_slice_dependencies` default to `true`.

**F4 Verification**:
- [x] Strict-mode tests green (8/8).
- [x] Full state test suite green with strict mode as default (550/550).
- [x] Zero violations found in audit — no production `caller_slice` usage.

**⚠ Commit 5 was the one explicit behavior-change commit in F4.** Full suite green before landing.

---

## Milestone F5: Communication Channel Taxonomy

**Goal**: Enforce "if you're a manager, dispatch to Redux." Managers must not call `U_ECSEventBus.publish`. ECS-originated events stay on the bus regardless of subscriber. Rule documented in `docs/adr/0001-channel-taxonomy.md` and enforced by grep test in CI.

**Taxonomy (Option B — publisher-based)**:
- ECS component/system → `U_ECSEventBus` (subscribers can be anywhere)
- Manager → Redux dispatch only
- Manager-UI wiring → Godot signals
- Everything else → method calls

**4 managers to migrate**: `m_save_manager` (new save actions), `m_objectives_manager` (delete 3 dead-code publishes + migrate victory routing to `ACTION_TRIGGER_VICTORY_ROUTING`), `m_vcam_manager` (remove 4 redundant ECS publishes), `m_scene_director_manager` (remove 3 redundant ECS publishes). `m_scene_manager` moves from ECS subscription to Redux for victory routing.

- [ ] **Commit 1** (RED) — 3 grep tests: managers-don't-publish (fails), scene-manager-no-victory-ECS-sub (fails), manager-signals-allow-list (passes).
- [ ] **Commit 2** (GREEN) — `docs/adr/0001-channel-taxonomy.md` + `AGENTS.md` pointer.
- [ ] **Commit 3a** (GREEN) — `m_save_manager` + new `u_save_actions.gd` + `ui_hud_controller` migration.
- [ ] **Commit 3b** (GREEN) — `m_objectives_manager` + victory routing (`m_scene_manager`, `s_victory_handler_system`, `ACTION_TRIGGER_VICTORY_ROUTING`).
- [ ] **Commit 3c** (GREEN) — `m_vcam_manager` redundant ECS publishes removed.
- [ ] **Commit 3d** (GREEN) — `m_scene_director_manager` redundant ECS publishes removed.
- [ ] **Commit 4** (GREEN) — Enable enforcement. 41/41 style tests green.

**Dependency note**: Depends on F3.

---

## Milestone F6: ServiceLocator — Globality, Test Pollution, Last-Write-Wins

**Goal**: Fix two structural problems with `U_ServiceLocator._services`: last-write-wins `register()` and no test scope (root cause of multiple recurring test-failure patterns in `MEMORY.md`).

- [ ] **Commit 1** (RED) — Conflict test + scope-isolation test.
- [ ] **Commit 2** (GREEN) — Implement fail-on-conflict `register()` + `register_or_replace()`. Audit `root.gd:50-78` for idempotency.
- [ ] **Commit 3** (GREEN) — Implement `push_scope` / `pop_scope`. Migrate `BaseTest` to use scope push/pop instead of `clear()`. Update UI tests that call `clear()` directly.
- [ ] **Commit 4** (GREEN) — Migrate `U_StateHandoff` and `M_DisplayManager._ensure_appliers()` follow-ups to the scope pattern where applicable.

**F6 Verification**:
- [ ] Duplicate-register test green.
- [ ] Scope-isolation test green.
- [ ] Full test suite green with `clear()` calls removed from `BaseTest.after_each()`.
- [ ] `MEMORY.md` test-failure patterns for `U_StateHandoff` and `_ensure_appliers` no longer manifest.

---

## Milestone F7: `RS_Rule` Typed-Schema Erasure

**Goal**: Replace `Array[Resource]` fallback on `RS_Rule.conditions`/`effects` with typed arrays OR a load-time schema validator (whichever the Godot 4.6 parser supports).

- [ ] **Commit 1** (INVESTIGATION) — Parser feasibility probe (Path A vs Path B). Document decision in milestone notes.
- [ ] **Commit 2** (RED) — Tests for the chosen path.
- [ ] **Commit 3** (GREEN) — Implement chosen path (typed arrays OR load-time validator).
- [ ] **Commit 4** (GREEN) — Remove "Fallback for headless parser stability" comment. For Path A, delete now-dead runtime type-check branches. For Path B, keep `U_RuleValidator` as a double-check layer.

**F7 Verification**:
- [ ] All 11 rule `.tres` files load green in headless + editor.
- [ ] Injecting a type error into any `.tres` file fails loudly at load with a resource path.
- [ ] Existing rule-engine tests green.
- [ ] Commit 1 notes clearly document which path was taken and why.

---

## Milestone F8: `S_VCamSystem` + `S_CameraStateSystem` Decomposition (Expanded v7.2.1)

**Goal**: Extend C5's pattern to the other two large systems. **Phase 0 decomposes oversized helpers first** so Phase 1+ can push system logic into them without creating 800+ line helper files.

**Phase 0 helper pre-decomposition**:

- [ ] **Commit 1a** (GREEN) — Decompose `u_vcam_rotation.gd` (740 lines) into:
  - `u_vcam_rotation_continuity.gd` (~80 lines): rotation-transition methods.
  - `u_vcam_orbit_centering.gd` (~90 lines): orbit "look behind" centering animation.
  - `u_vcam_look_spring.gd` (~180 lines): 2nd-order spring dynamics + release damping + debug.
  Update `u_vcam_effect_pipeline.gd` and `s_vcam_system.gd` imports. All existing VCam tests green.
- [ ] **Commit 1b** (GREEN) — Decompose `u_vcam_orbit_effects.gd` (650 lines) into:
  - `u_vcam_look_ahead.gd` (~110 lines).
  - `u_vcam_ground_anchor.gd` (~110 lines).
  - `u_vcam_soft_zone_applier.gd` (~120 lines).
  - Residual `u_vcam_orbit_effects.gd` (~80 lines): sampling + bypass + prune.
  Update imports. All existing VCam tests green.

**Phase 1+ system extraction**:

- [ ] **Commit 1** (RED) — Method-level decomposition tests for extracted logic.
- [ ] **Commit 2** (GREEN) — Extract `S_VCamSystem` private methods into (now smaller) helpers. Target: file under 400 lines.
- [ ] **Commit 3** (GREEN) — Extract `S_CameraStateSystem` private methods. Target: file under 400 lines. Create `u_camera_state_rule_applier.gd` if no existing helper fits.
- [ ] **Commit 4** (GREEN) — Style enforcement:
  - `process_tick` methods under 80 lines in all three large systems (C5 + F8).
  - System files `s_vcam_system.gd` / `s_camera_state_system.gd` under 400 lines.
  - **NEW (v7.2.1)**: Every `.gd` file under `scripts/ecs/systems/helpers/` under 400 lines.

**F8 Verification**:
- [ ] All existing VCam and camera-state integration tests green.
- [ ] System files under ~400 lines total.
- [ ] `process_tick` under 80 lines in both systems.
- [ ] All helper files under 400 lines.
- [ ] New helpers (`u_vcam_rotation_continuity`, `u_vcam_orbit_centering`, `u_vcam_look_spring`, `u_vcam_look_ahead`, `u_vcam_ground_anchor`, `u_vcam_soft_zone_applier`) all exist and are referenced by consumers.
- [ ] Style enforcement test green.

**Dependency note**: Follows C5. **Phase 0 (Commits 1a + 1b) must land before Phase 1+ (Commits 1-4).**

---

## Milestone F9: ECS System Execution Phasing — Named Phase Enum

**Goal**: Replace opaque integer `execution_priority` with a named `SystemPhase` enum. Keep `execution_priority` as within-phase tiebreaker.

- [ ] **Commit 1** (RED) — Phasing tests in `test_m_ecs_manager_phasing.gd`.
- [ ] **Commit 2** (GREEN) — Introduce `SystemPhase` enum on `BaseECSSystem` (`INPUT`, `PRE_PHYSICS`, `PHYSICS_SOLVE`, `POST_PHYSICS`, `CAMERA`, `VFX`).
- [ ] **Commit 3** (GREEN) — Refactor `M_ECSManager` sort/loop to group by phase first, then by `execution_priority`.
- [ ] **Commit 4** (GREEN) — Assign explicit phases to all existing `S_*` systems based on current priority values. Verify ordering didn't change.

**F9 Verification**:
- [ ] Phasing tests green.
- [ ] Existing ECS tests green.
- [ ] All `S_*` systems declare an explicit phase.
- [ ] No ECS system uses `_physics_process` directly (style enforcement).

---

## Milestone F10: State Store History Truncation — ALREADY IMPLEMENTED

**Goal**: Verification-only checkpoint. `U_ActionHistoryBuffer` is a ring buffer with configurable `max_history_size`, disabled on mobile.

- [ ] **Commit 1** (VERIFY) — Add `test_m_state_store_history_truncation.gd` (if not already covered):
  - Buffer does not exceed `max_history_size` after dispatching `max_history_size + 100` actions.
  - `configure(0, true)` and `configure(N, false)` both result in empty history.
  - Ring buffer wraps correctly (oldest entries evicted first).

**F10 Verification**:
- [ ] Verification tests green.
- [ ] Existing store tests green.

---

## Milestone F11: Event Bus "Zombie" Prevention (Dead Subscriber Pruning)

**Goal**: Prune dead subscriber callables from `BaseEventBus._subscribers` at publish time. Scope is `scripts/events/base_event_bus.gd` (shared base), **not** the `U_ECSEventBus` facade.

- [ ] **Commit 1** (RED) — `tests/unit/ecs/events/test_base_event_bus_zombies.gd`: dead subscriber removed after publish; no entries with `callback.is_valid() == false` in `_subscribers`.
- [ ] **Commit 2** (GREEN) — Publish-time pruning in `BaseEventBus.publish()`.
- [ ] **Commit 3** (GREEN) — Replace per-publish `.duplicate()` at `:93` with index-based iteration safe for mid-iteration removal.

**F11 Verification**:
- [ ] Zombie pruning tests green.
- [ ] Existing event bus tests green (including `test_ecs_event_bus.gd`).
- [ ] No `.duplicate()` call in `BaseEventBus.publish()` (style enforcement).

---

## Milestone F12: Settings Overlay Wrapper Deduplication (v7.2.1 Addition)

**Goal**: Three 53-line overlay wrappers are character-for-character identical except `class_name`. Collapse into a single base class.

- [ ] **Commit 1** (RED) — `test_settings_simple_overlay_base.gd`: all three overlays share behavior; each concrete script under 15 lines post-refactor.
- [ ] **Commit 2** (GREEN) — Create `scripts/ui/settings/base_settings_simple_overlay.gd` with the 52 shared lines.
- [ ] **Commit 3** (GREEN) — Reduce each of the three overlay files to ~5 lines (`@icon` + `extends` + `class_name`).
- [ ] **Commit 4** (GREEN) — Style enforcement: each simple overlay under 15 lines. `ui_vfx_settings_overlay.gd` explicitly excluded.

**F12 Verification**:
- [ ] Existing settings-overlay integration tests green (navigation, theme, close).
- [ ] Three overlay files reduced from 53 → ~5 lines each.
- [ ] `base_settings_simple_overlay.gd` contains extracted shared behavior.
- [ ] VFX overlay unchanged.
- [ ] Style enforcement test green.

**Dependency note**: Independent.

---

## Milestone F15: Designer-Facing Resource Schema Validation (v7.2.1 Addition)

**Goal**: Extend F7's "fail loud at load" pattern to `RS_GameConfig` (HIGH risk), `RS_InputProfile` (MEDIUM), `RS_SceneRegistryEntry` (MEDIUM). `RS_UIThemeConfig` is out of scope (runtime defaults already prevent crashes).

- [ ] **Commit 1** (RED) — Validation tests for all three resources (assert empty/malformed fields fail at load with `resource_path` in error).
- [ ] **Commit 2** (GREEN) — `RS_GameConfig._init()`: validate four fields non-empty. Include `resource_path` in `push_error`.
- [ ] **Commit 3** (GREEN) — `RS_InputProfile._init()`: validate `profile_name`, `action_mappings`, `virtual_buttons` structure, `virtual_joystick_position` bounds.
- [ ] **Commit 4** (GREEN) — `RS_SceneRegistryEntry._init()`: elevate existing `_validate_property()` warnings to `push_error` on empty `scene_id` / `scene_path`.
- [ ] **Commit 5** (GREEN) — Cross-reference boot validation in `M_GameplayInitializerManager` (or equivalent): validate `retry_scene_id` exists in `U_SceneRegistry` and `default_objective_set_id` exists in objectives registry. Fail loud on boot.

**F15 Verification**:
- [ ] All validation tests green.
- [ ] Injecting an invalid field into any of the three `.tres` files fails loudly at load with `resource_path`.
- [ ] Cross-reference boot validation catches dangling scene/objective IDs before gameplay starts.
- [ ] Existing resource-consumer tests green.

**Dependency note**: Independent. Pattern mirrors F7. Can run in parallel with F7 or after.

---

## Milestone F16: AI System Type Safety & Consistency (v7.2.2 Addition)

**Goal**: Fix six inconsistencies where the AI system falls short of non-AI project standards. No behavioral changes.

**6 commits**:

- [ ] **Commit 1** (GREEN) — Type AI service fields and planner context parameters:
  - `s_ai_behavior_system.gd`: Replace 5 `Variant` fields with `U_AIGoalSelector`, `U_AITaskRunner`, `U_AIReplanner`, `U_AIContextBuilder`, `U_DebugLogThrottle`.
  - `s_ai_detection_system.gd`: Replace 2 `Variant` params with `C_DetectionComponent`, `C_MovementComponent`.
  - `u_htn_planner.gd`: Type `planner_context: Variant` as `U_HTNPlannerContext`. Add `push_error` for null task and depth exceeded.
  - `u_htn_planner_context.gd`: Type `reusable_rule: Resource` as `RS_Rule`. Update `_init` param type.

- [ ] **Commit 2** (GREEN) — Add `push_error` stubs to `I_AIAction`:
  - Replace `pass` in `start()`/`tick()` with `push_error("I_AIAction.%s: not implemented by subclass %s" % [method, str(resource_name)])`. Add `push_error` before `return false` in `is_complete()`.
  - Update `test_i_ai_action_base.gd` to verify stubs produce `push_error`.

- [ ] **Commit 3** (GREEN) — Migrate raw task_state string keys to `U_AITaskStateKeys` constants:
  - Add 8 constants: `ELAPSED`, `SCAN_ELAPSED`, `SCAN_ACTIVE`, `SCAN_ROTATION_SPEED`, `ANIMATION_STATE`, `ANIMATION_REQUESTED`, `PUBLISHED`, `COMPLETED`.
  - Update 5 action files: `rs_ai_action_wait.gd`, `rs_ai_action_scan.gd`, `rs_ai_action_animate.gd`, `rs_ai_action_publish_event.gd`, `rs_ai_action_set_field.gd`.
  - Remove Variant type coercion in `rs_ai_action_wait.gd` and `rs_ai_action_scan.gd` (unnecessary since `start()` writes `float`).
  - Update `test_u_ai_task_state_keys.gd` with 8 new key assertions.

- [ ] **Commit 4** (GREEN) — Add `get_debug_snapshot()` to `C_AIBrainComponent`:
  - Add `_debug_snapshot`, `update_debug_snapshot()`, `get_debug_snapshot()` mirroring `C_JumpComponent`.
  - Update `S_AIBehaviorSystem._debug_log_brain_state` to build snapshot and call `brain.update_debug_snapshot()`.
  - Add tests: `test_update_debug_snapshot`, `test_get_debug_snapshot_returns_copy`, `test_debug_snapshot_includes_goal_id`.

- [ ] **Commit 5** (GREEN) — Document `RS_AIActionAnimate` fire-and-forget semantics:
  - Add class-level doc comment clarifying instant-complete behavior is intentional.

- [ ] **Commit 6** (GREEN) — Style enforcement grep test for AI task-state key constants:
  - Forbid `task_state["` (bare string key access) in `scripts/resources/ai/actions/*.gd`.

**F16 Verification**:
- [ ] All existing AI unit tests green.
- [ ] All existing AI integration tests green.
- [ ] `test_i_ai_action_base.gd` verifies `push_error` stubs.
- [ ] `test_u_ai_task_state_keys.gd` covers 18 total constants (10 existing + 8 new).
- [ ] `test_c_ai_brain_component.gd` covers debug snapshot methods.
- [ ] Grep confirms zero bare string literals in task_state access across `scripts/resources/ai/actions/`.
- [ ] No behavioral change.

**Dependency note**: Independent of F1–F15. Partial overlap with F9 (both touch `s_ai_behavior_system.gd`). Land F16 Commit 1 first; F9 can add `SystemPhase` afterward.

---

## Dependency Graph / Sequencing

- **F1** → verification-only, first to land (single commit).
- **F2 → F3 → F4** → sequential chain, all touch `m_state_store.gd`. Run full test suite between each.
- **F5** → depends on F3 (single-mutation-path invariant must hold before channel taxonomy is enforceable).
- **F6** → independent.
- **F7** → independent, gated on Commit 1 parser-feasibility investigation.
- **F8** → depends on C5. **Phase 0 (Commits 1a/1b) before Phase 1+.** Extends C5's pattern.
- **F9** → independent, extends existing `execution_priority` system (does not replace it).
- **F10** → verification-only.
- **F11** → independent.
- **F12** → independent.
- **F15** → independent, mirrors F7's pattern.
- **F16** → independent (v7.2.2 addition). Partial overlap with F9 (both touch `s_ai_behavior_system.gd`); land F16 Commit 1 first.

**Cross-milestone integration**: Run full test suite after each milestone completes. Critical for the F2 → F3 → F4 chain.

---

## Follow TDD Discipline

For each milestone:

1. Write the test first (unit or integration).
2. Run the test and verify it fails for the expected reason.
3. Implement the minimal code to make it pass.
4. Run the full test suite and verify no regressions.
5. Run `tests/unit/style/test_style_enforcement.gd` after any file creation or rename.
6. Commit with a clear, focused message.

---

## Preserve Compatibility

You MUST:

- Keep all existing ECS systems, QB v2 consumers, state management flows, and manager APIs working.
- Follow existing composition patterns — compose shared utilities, do not create deep inheritance hierarchies. The `base_settings_simple_overlay.gd` class in F12 is the exception because the overlay hierarchy is already inheritance-based (`BaseOverlay` → `BaseMenuScreen` → `BasePanel` → `Control`).
- Maintain existing `I_*` interface contracts and `M_*Manager` public APIs.
- Ensure new `@export` fields on validated resources ship with defaults matching current values so no existing scene or test breaks.
- Register new utilities following the `U_` prefix convention and new resources following the `RS_` prefix convention per `STYLE_GUIDE.md`.

---

## Key Design Decisions

- **Subscriber contract is read-only**: F2 relies on the existing implicit contract (`m_state_store.gd:468`) that subscribers treat state as read-only. Document this explicitly in F2 Commit 2.
- **Bulk-load paths bypass dispatch by design**: F3's `load_state` and `apply_loaded_state` emit `slice_updated` without `action_dispatched` because they are bulk restoration operations, not user actions. Annotated with `# INVARIANT:` comments. Going through dispatch would pollute action history with N implementation-detail actions per logical load.
- **Strict mode is opt-in first, default later**: F4 flips the strict-slice-dependency default to `true` only in Commit 5, after the audit-and-fix pass is green. This is the one explicit behavior-change commit in v7.2.
- **ADR-first for channel taxonomy**: F5 writes the ADR before migrating violations, so the rule is documented before enforcement starts.
- **Scope push/pop preserves production behavior**: F6's scope stack is empty in production; production `U_ServiceLocator.register()` behavior is unchanged. Test isolation is opt-in via `push_scope`/`pop_scope` in `BaseTest`.
- **Phase enum composes with priority**: F9's `SystemPhase` enum provides bucket-level ordering; `execution_priority` remains the within-phase tiebreaker. Existing systems keep their integer priorities as the secondary sort key.
- **Helper size invariant**: F8's Phase 0 establishes a 400-line ceiling for every `.gd` file under `scripts/ecs/systems/helpers/`. Codified in style enforcement so future system extraction can't regress it.
- **Overlay base class is new, but scene files are untouched**: F12 introduces `base_settings_simple_overlay.gd` between `BaseOverlay` and the three concrete overlays. The `.tscn` scene files continue to instance tab content as before.
- **Resource validation is `_init()` + boot cross-check**: F15 uses `_init()` for local schema checks (fail at load with `resource_path`) and defers cross-registry checks (e.g., "does `retry_scene_id` exist in `U_SceneRegistry`?") to a one-shot boot validation pass, because `_init()` runs before autoloads are available.
- **F16 has no behavioral changes**: All commits are type annotations, constant migrations, interface stubs matching project convention, or additive debug methods. The only "observable" change is `push_error` output from `I_AIAction` stubs, which only fires if a subclass fails to override — a scenario that already produces incorrect behavior (silently no-oping).
- **F16 debug snapshot mirrors `C_JumpComponent`**: Same `.duplicate(true)` copy semantics, same `update_debug_snapshot`/`get_debug_snapshot` method pair.
- **F16 Variant coercion cleanup is safe**: `start()` writes `float` values to task_state; the runtime type is guaranteed. The `is float or is int` guard in `rs_ai_action_wait.gd` and `rs_ai_action_scan.gd` is unnecessary defensive code that becomes removable once keys are constants.
- **F16 overlap with F9**: Both touch `s_ai_behavior_system.gd`. F16 Commit 1 only changes type annotations on lines 28–32; F9 will add a `SystemPhase` declaration. Land F16 Commit 1 first for a clean merge.

---

## Critical Notes

- **No Autoloads**: Follow existing patterns. Managers live under the `Managers` node and register with `U_ServiceLocator`.
- **Style & Organization**: Follow `docs/general/STYLE_GUIDE.md` and node naming prefixes (`S_`, `C_`, `RS_`, `U_`, `I_`, `E_`, `M_`).
- **Update Docs After Each Milestone**: Per AGENTS.md's mandatory pattern — update `cleanup-v7.2-tasks.md` completion notes and this continuation prompt after completing each milestone. Commit doc updates separately from implementation.
- **Test Suite Command**: `tools/run_gut_suite.sh` (or `tools/run_gut_suite.sh -gtest=res://tests/unit/...` for targeted suites).
- **Style Test**: `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd`
- **`docs/adr/` directory must be created in F5 Commit 2** — it does not exist yet. ADR numbering starts at `0001-channel-taxonomy.md`.
- **F4 Commit 5 is the one behavior-change commit in v7.2** — strict-slice-dependency default flip. Run full suite before landing.
- **F8 Phase 0 Commits (1a + 1b) must land before Phase 1+** — otherwise system extraction pushes logic into 800+ line helpers.
- **F7 Commit 1 is an investigation commit** — record the Path A vs Path B decision and rationale in the milestone notes before writing tests or implementation.
- **F11 targets `BaseEventBus`, not `U_ECSEventBus`** — the shared base class is the fix site. Both `U_ECSEventBus` and `U_StateEventBus` facades inherit the behavior.
- **F1 and F10 are verification-only** — single-commit checkpoints confirming the original concerns were resolved during C6 and a prior cleanup respectively.
- **F13/F14 are not milestones** — the "unbounded collections" concerns were audited and rejected. Do not re-open this scope. Rationale lives in `cleanup-v7.2-tasks.md` Purpose section.

---

## Next Steps

1. ~~Confirm C12 has landed and full regression pass is green.~~ ✅ Done.
2. **F1 verification** — single-commit style-enforcement assertions confirming C6 gaps stay closed (can land anytime as checkpoint).
3. ~~**Begin F2** — StateStore dispatch snapshot sharing.~~ ✅ **Complete.** Dispatch now uses `get_state()` instead of `_state.duplicate(true)`.
4. ~~**Begin F3** — StateStore eliminate parallel mutation paths.~~ ✅ **Complete.** `_sync_navigation_initial_scene` dispatches through reducer; `slice_updated.emit` sites audited with invariant comments; style enforcement test added.
5. **Begin F4** — Slice dependency validator strict mode. Next milestone in the F2→F3→F4 sequential chain.
6. F5 after F3 lands (cleaner to enforce channel taxonomy once state mutation is single-sourced).
7. F6, F7, F8 (incl. Phase 0), F9, F11, F12, F15, F16 can be scheduled independently.
8. F10 verification checkpoint can run any time.
9. F16 Commit 1 should land before F9 (both touch `s_ai_behavior_system.gd`; type annotations are simpler).
10. After F1–F8 are green and F5 has landed, revisit the closing `AGENTS.md` sprawl reflection to decide whether to promote it to a future F-milestone.
11. Update `MEMORY.md` test-failure patterns section after F6 lands — the `U_StateHandoff` and `_ensure_appliers` entries should no longer manifest once scope-based test isolation replaces `U_ServiceLocator.clear()`.
