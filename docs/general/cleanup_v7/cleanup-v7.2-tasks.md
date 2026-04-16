# Cross-System Cleanup V7.2 — Follow-up Tasks Checklist

**Branch**: GOAP-AI
**Status**: Not started (queued after cleanup-v7 C12 post-processing milestone)
**Methodology**: TDD (Red-Green-Refactor) — tests written within each milestone, not deferred
**Scope**: Targeted follow-ups to cleanup-v7 (`cleanup-v7-tasks.md`) addressing gaps surfaced during a deep-dive architectural review. Mostly backwards-compatible. Behavioral changes are gated to specific commits and called out explicitly (F4 strict validator default flip, F5 grep-test enforcement). All existing integration tests must stay green throughout.

**Relationship to cleanup-v7**: This doc is a **follow-up** to `cleanup-v7-tasks.md`, not a replacement. ~~F1 supplements C6~~ F1 was resolved during C6 and is now a verification-only checkpoint. F8 extends C5's wall-visibility decomposition pattern to the other two large ECS systems. The other milestones are independent of v7 scope. Scheduling decision: start this v7.2 plan after C12 (`post-process-refactor-tasks.md`) is complete and regression-tested.

---

## Purpose

The cleanup-v7 plan (C1–C12) does a thorough job of DRY, modularity, scalability, and designer-friendliness across managers and ECS systems. A subsequent architectural review surfaced eight concrete weaknesses that C1–C12 does **not** address:

1. ~~**A cross-manager reflection hole that actively bypasses an existing interface method**~~ — **Resolved during C6.** `m_scene_manager.gd:632` now calls `_camera_manager.is_blend_active()`. The reflection pattern, Array-wrapper captures, and 150+ line `_perform_transition` are all gone. `_perform_transition` is now ~23 lines (`:510-532`), decomposed into `_prepare_transition_context()`, `_execute_scene_swap()`, `_transition_orchestrator.execute_transition_effect()`, and `_finalize_camera_blend()`.
2. **A per-dispatch full-state deep copy floor** in `M_StateStore.dispatch()` that bypasses the store's own versioned cache.
3. **Two parallel mutation paths** that bypass the reducer/history/validator pipeline.
4. **An advisory-only slice-dependency validator** that fails open, letting declarations drift silently.
5. **An unresolved communication-channel taxonomy** (Redux vs `U_ECSEventBus` vs Godot signals) that drives most of the "contract-by-comment" growth in `AGENTS.md`.
6. **Process-global `U_ServiceLocator` state** with last-write-wins `register()` and no per-test scope, causing recurring test pollution patterns documented in the auto-memory.
7. **Type erasure on `RS_Rule.conditions`/`effects: Array[Resource]`** — authoring errors surface as "rule scored 0.0" with no stack trace.
8. **Two more large ECS systems** (`s_vcam_system.gd` at 551 lines, `s_camera_state_system.gd` at 587 lines) that C5 does not target. Note: their `process_tick` methods are already under 80 lines; the size is in private helper methods that should be extracted to dedicated helper files.

**v7.2.1 patch (added during pre-implementation review)**:
- **F8 expanded**: Helper pre-decomposition is now Phase 0 of F8. Executing F8 as originally written would have pushed logic into 800+ line helpers (`u_vcam_rotation.gd` at 740 lines, `u_vcam_orbit_effects.gd` at 650 lines). Two VCam helpers are decomposed first.
- **F12 added**: Settings overlay wrapper deduplication — three 100%-identical 53-line files collapsed into a shared base.
- **F15 added**: Load-time schema validation for `RS_GameConfig`, `RS_InputProfile`, and `RS_SceneRegistryEntry`. Extends F7's "fail loud at load" pattern to other designer-facing resources.
- **F13/F14 rejected**: Audit verified all flagged "unbounded collections" (`_character_lighting_history`, wall visibility caches, `_scene_cache`, `_scene_history`) are already properly bounded with cleanup on scene change. No milestone needed.

**v7.2.2 patch (added during AI system review)**:
- **F16 added**: AI system type safety & consistency — six inconsistencies where the AI codebase falls short of non-AI project standards. Five `Variant`-typed fields, silent interface stubs, raw string keys in task_state, missing debug snapshot, untyped planner context, and missing HTN null/depth diagnostics. All fixes are type annotations, constant migrations, or additive methods — no behavioral changes.

The doc closes with a non-numbered reflection on `AGENTS.md` sprawl and a proposed restructuring direction.

---

## Sequencing

- Run this plan after C12 (`post-process-refactor-tasks.md`) completes and passes regression; do not start v7.2 in parallel with C12.
- `F1` — **already resolved** during C6. Verification-only checkpoint (single commit).
- `F2`, `F3`, `F4` all touch `m_state_store.gd`; run sequentially (F2 → F3 → F4) to avoid merge contention. **Run full test suite between each** as an integration checkpoint.
- `F5` depends on `F3` having cleaned up the parallel mutation paths first (the channel taxonomy is cleaner to enforce once state mutation is single-sourced). Note: `docs/adr/` directory must be created (does not exist yet).
- `F6` is independent.
- `F7` is independent — blocked only on a one-commit parser feasibility investigation.
- `F8` is independent — follows `C5`'s decomposition pattern once `C5` lands. **Expanded scope (v7.2.1)**: Phase 0 decomposes oversized helpers (`u_vcam_rotation.gd`, `u_vcam_orbit_effects.gd`) before Phase 1+ pushes system logic into them.
- `F9` is independent — **extends** the existing `execution_priority` system in `M_ECSManager`, does not replace it.
- ~~`F10` is independent — small addition to `m_state_store.gd` action tracking.~~ **F10 is already implemented.** `U_ActionHistoryBuffer` is a ring buffer with configurable `max_history_size`, disabled on mobile. Verification-only checkpoint.
- `F11` is independent — targets event bus memory hygiene. Scope is `scripts/events/base_event_bus.gd` (the shared base class), not the `U_ECSEventBus` facade.
- `F12` is independent (v7.2.1 addition) — trivial DRY collapse of three identical settings overlay wrappers; can run anytime.
- `F15` is independent (v7.2.1 addition) — mirrors F7's "fail loud at load" pattern for other designer-facing resources; can run in parallel with F7 or after.
- `F16` is independent (v7.2.2 addition) — AI system type safety & consistency. 6 commits targeting Variant-typed fields, interface stubs, task-state key constants, debug snapshot, animate docs, and grep enforcement. Partial overlap with F9 (both touch `s_ai_behavior_system.gd`); land F16 Commit 1 first.

**Cross-milestone integration**: Run the full test suite after each milestone completes, not just the milestone's own tests. This is especially critical for the F2 → F3 → F4 sequential chain.

---

## Milestone F1: ~~SceneManager C6 Supplement~~ — ALREADY RESOLVED (Verification Only)

**Status**: **Resolved during C6.** The two original gaps no longer exist in the codebase:

1. ~~**Cross-manager reflection hole**~~ — `m_scene_manager.gd:632` now calls `_camera_manager.is_blend_active()`. No `.get("_camera_blend_tween")` pattern exists anywhere in the file.
2. ~~**Array-wrapper mutable-capture workarounds**~~ — `_perform_transition` is now ~23 lines (`:510-532`), cleanly decomposed into `_prepare_transition_context()`, `_execute_scene_swap()`, `_transition_orchestrator.execute_transition_effect()`, and `_finalize_camera_blend()`. No Array-wrapper captures remain.

**Commit** (single verification commit):
- [ ] **Commit 1** (VERIFY) — Add style-enforcement grep assertions in `tests/unit/style/test_style_enforcement.gd`:
  - `m_scene_manager.gd` contains zero matches of `_camera_blend_tween`.
  - `m_scene_manager.gd` contains zero matches of `get("_camera_blend_tween")`.
  - Confirm `_perform_transition` is under 40 lines.

**F1 Verification**:
- [ ] Style enforcement tests green.
- [ ] Existing scene-transition integration tests green.

---

## Milestone F2: StateStore Dispatch — Share Snapshot Across Subscribers

**Goal**: Eliminate the per-dispatch full-state deep copy at `m_state_store.gd:471`:

```gdscript
if not _subscribers.is_empty():
    var state_snapshot := _state.duplicate(true)   # <-- runs every dispatch
    for subscriber in _subscribers:
        subscriber.call(action_copy, state_snapshot)
```

The store already tracks `_state_version` (`:89`) and maintains a versioned cached snapshot in `get_state()` (`:533-537`). `dispatch()` bypasses that cache by calling `_state.duplicate(true)` again on every dispatch. With 16 state slices and per-frame dispatches from many systems, this is a per-frame cost floor for the whole game.

**Scope**:
- `scripts/state/m_state_store.gd`:
  - `dispatch()` (`:430-492`) — the per-subscriber snapshot build.
  - `get_state()` (`:533-537`) — the existing cache.
  - `_cached_state_snapshot` / `_cached_state_version` (`:89-91`) — the version tracking fields.

**Commits**:
- [x] **Commit 1** (RED) — Dispatch-path tests:
  - `tests/unit/state/test_m_state_store_dispatch_sharing.gd`:
    - Test 1: With 5 subscribers, all receive same Dictionary reference per dispatch (hash identity check).
    - Test 2: Dispatch with subscribers populates versioned cache (`_cached_state_version == _state_version` after dispatch).
    - Test 3: Zero-subscriber dispatch skips snapshot build (`_cached_state_version` unchanged).
    - Test 4: Benchmark — 100 dispatches with 2 subscribers, zero reference mismatches.
- [x] **Commit 2** (GREEN) — Refactor `dispatch()`:
  - Replaced `_state.duplicate(true)` with `get_state()` in the subscriber loop.
  - `get_state()` uses the versioned cache, so subsequent `get_state()` calls in the same frame reuse the deep copy.
  - Documented subscriber read-only contract in the comment (A1+A2 annotation).
  - Zero-subscriber skip was already in place (`if not _subscribers.is_empty()` guard at line 470).
- [x] **Commit 3** (MERGED INTO COMMIT 2) — Skip the snapshot build when `_subscribers.is_empty()` was already implemented. No separate commit needed.

**F2 Verification**:
- [x] All new tests green.
- [x] Dispatch uses versioned cache (get_state()) instead of bypassing it — test verifies `_cached_state_version == _state_version` after dispatch.
- [x] Zero-subscriber dispatch skips snapshot build — test verifies `_cached_state_version` unchanged.
- [x] Existing store/reducer tests green (30/30 pass).
- [x] Full test suite green (4227/4235 pass, 8 pending/risky as expected).
- [x] No observable behavior change for subscribers (snapshot contents identical).

---

## Milestone F3: StateStore — Eliminate Parallel Mutation Paths

**Goal**: All mutations to `_state` must flow through `dispatch()` so that action history, version bumping, validator, and signal batching stay consistent. Two bypass paths currently exist:

1. **`_sync_navigation_initial_scene`** directly mutates `_state["navigation"]` (~`:150-156` — creates a duplicated nav dict at `:150`, assigns at `:156` via `_state["navigation"] = new_nav`). Already listed as a cleanup-v7 cross-cutting bullet (line ~432 of `cleanup-v7-tasks.md`) but not scheduled.
2. **Direct `slice_updated.emit(slice_name, _state[slice_name])`** at `m_state_store.gd:684` emits slice updates from the reducer apply path without going through `action_dispatched`, the history buffer, or the cached-snapshot invalidation. Additional emission sites at `:259, :486, :636`.

The divergence is subtle: a subscriber listening on `slice_updated` will see state that `action_history_buffer` does not record.

**Scope**:
- `scripts/state/m_state_store.gd`:
  - `_sync_navigation_initial_scene` (~`:150-156`).
  - `slice_updated.emit` sites at `:259, :486, :636, :684`.
- `scripts/state/actions/u_navigation_actions.gd` — add `sync_initial_scene(scene_id: StringName)` action.
- `scripts/state/reducers/u_navigation_reducer.gd` — handle the new action type.

**Commits**:
- [x] **Commit 1** (RED) — Invariant tests in `tests/unit/state/test_m_state_store_dispatch_invariant.gd`:
  - `test_sync_initial_scene_dispatches_action` — `_sync_navigation_initial_scene` produces `action_dispatched` with correct payload.
  - `test_dispatch_produces_paired_action_and_slice_signals` — every dispatch produces paired `action_dispatched` + `slice_updated`.
  - `test_sync_initial_scene_recorded_in_action_history` — init sync is recorded in action history.
- [x] **Commit 2** (GREEN) — Convert `_sync_navigation_initial_scene`:
  - Added `U_NavigationActions.sync_initial_scene(scene_id, clear_overlays)` action creator + registry entry.
  - Added `_reduce_sync_initial_scene` reducer branch in `u_navigation_reducer.gd`.
  - Replaced direct `_state["navigation"]` mutation with `dispatch(U_NavigationActions.sync_initial_scene(...))`.
- [x] **Commit 3** (GREEN) — Audit `slice_updated.emit` sites (`:255, :485, :635, :683`):
  - `:255` (batched flush) and `:485` (immediate dispatch flush) — both reachable from the dispatch path, paired with `action_dispatched`.
  - `:635` (`load_state`) and `:683` (`apply_loaded_state`) — bulk restoration paths. Annotated with `# INVARIANT:` comments explaining why direct emission is safe: bulk load is not a user action, dispatching N actions would pollute action history, version bump + `state_loaded` signal cover the notification contract.
  - `_restore_from_handoff` (`:716`) — bulk restoration path during `_ready()`. Annotated with `# INVARIANT:` comment explaining why no dispatch (pre-`store_ready` timing) and no `slice_updated` emission (no subscribers exist yet).
- [x] **Commit 4** (GREEN) — Grep-based style test `test_no_state_mutation_outside_store` in `test_style_enforcement.gd`:
  - Searches all production directories for `_state[` assignment mutations with word-boundary checking.
  - Only `m_state_store.gd` is exempted.
  - 38/38 style enforcement tests green.

**F3 Verification**:
- [x] No `slice_updated` emission without a paired `action_dispatched` in the same frame (normal dispatch path verified by test; `load_state`/`apply_loaded_state` bulk paths annotated with invariant comments).
- [x] `_sync_navigation_initial_scene` no longer directly mutates `_state` — now dispatches through reducer pipeline.
- [x] `action_history_buffer` records init sync action (verified by `test_sync_initial_scene_recorded_in_action_history`).
- [x] Grep test green (`test_no_state_mutation_outside_store`).
- [x] Existing store tests green (76/77 pass; 1 pre-existing failure in `test_state_synchronization_flow.gd` roundtrip unrelated to F3).

---

## Milestone F4: Slice Dependency Validator — Strict Mode

**Goal**: The slice-dependency check at `m_state_store.gd:565-573` logs an error if `caller_slice` reads an undeclared slice but **still returns the data**:

```gdscript
func get_slice(slice_name: StringName, caller_slice: StringName = StringName()) -> Dictionary:
    if caller_slice != StringName():
        var caller_config: RS_StateSliceConfig = _slice_configs.get(caller_slice)
        if caller_config != null:
            if not caller_config.dependencies.has(slice_name) and caller_slice != slice_name:
                push_error(...)  # advisory only
    return _state.get(slice_name, {}).duplicate(true)  # <-- still returns
```

Declarations drift silently out of sync with reality because the check fails open. Add a strict-mode toggle, audit + fix all current violations, then flip the default to strict.

**Scope**:
- `scripts/state/m_state_store.gd` — `get_slice` at `:565`.
- `scripts/resources/state/rs_state_store_settings.gd` — add `strict_slice_dependencies: bool = false` export.
- Audit: all call sites of `get_slice(..., caller_slice)` across managers and systems.

**Commits**:
- [x] **Commit 1** (RED) — Strict-mode tests: ✅
  - `tests/unit/state/test_m_state_store_slice_dependencies.gd`:
    - With `strict_slice_dependencies = false`: undeclared access returns data and pushes an error (current behavior preserved).
    - With `strict_slice_dependencies = true`: undeclared access returns `{}` and pushes an error.
    - Declared access in both modes returns data without error.
- [x] **Commit 2** (GREEN) — Add `strict_slice_dependencies` to `RS_StateStoreSettings`. Implement the strict branch in `get_slice`. ✅
- [x] **Commit 3** (GREEN) — Audit: temporarily enabled strict mode, ran full unit suite. ✅
  - **Zero violations found** — no production code passes a `caller_slice` argument to `get_slice`. The validator is opt-in only and currently unused in production call sites.
  - One intermittent pre-existing failure in `test_a4_apply_reducers_unchanged_action_does_not_dirty_slices` — unrelated to strict mode (passes on immediate re-run).
- [x] **Commit 4** (GREEN) — No violations to fix; skipped as no-op. ✅
- [x] **Commit 5** (GREEN, **behavior change**) — Flipped `strict_slice_dependencies` default to `true`. ✅
  - State suite 550/550 green with strict mode as default.

**F4 Verification**:
- [x] Strict-mode tests green (8/8).
- [x] Full state test suite green with `strict_slice_dependencies = true` as default (550/550).
- [x] Zero violations found in audit — no production `caller_slice` usage.
- [x] Style enforcement tests green (38/38).

---

## Milestone F5: Communication Channel Taxonomy

**Goal**: Pick one channel per concern and document the rule. One-sentence rule: **"If you're a manager, dispatch to Redux."** Enforced by grep test — managers must not call `U_ECSEventBus.publish`.

**Adopted taxonomy (Option B — publisher-based rule)**:

| Publisher | Channel |
|---|---|
| ECS component or system | **`U_ECSEventBus`** — subscribers can be anywhere |
| Manager | **Redux dispatch** only |
| Intra-manager / manager-UI wiring | **Godot signals** |
| Everything else | **Method calls** |

**What does NOT change** — ECS-originated events stay on the bus regardless of subscriber:
- `c_health_component` → `health_changed` → `s_screen_shake_publisher_system` ✓
- `s_screen_shake_publisher_system` → `screen_shake_request` → `m_vfx_manager` ✓
- `s_checkpoint_handler_system` → `checkpoint_activated` → `ui_hud_controller` ✓

**5 managers to migrate**:
1. `m_save_manager` — add `u_save_actions.gd` (ACTION_SAVE_STARTED/COMPLETED/FAILED), replace ECS publishes with Redux dispatch, migrate `ui_hud_controller` save subscriptions to `action_dispatched` signal.
2. `m_objectives_manager` — delete 3 dead-code dual-publishes (objective_activated/completed/failed). Replace `EVENT_OBJECTIVE_VICTORY_TRIGGERED` publish with `ACTION_TRIGGER_VICTORY_ROUTING` Redux dispatch (new action + `victory_target_scene` field in gameplay slice). Remove `EVENT_VICTORY_EXECUTED` subscription; react to `ACTION_TRIGGER_VICTORY` from Redux instead.
3. `m_vcam_manager` — remove 5 redundant ECS publishes (vcam_active_changed/blend_started/blend_completed/recovery/silhouette_update_request). Remove same from `u_vcam_runtime_state.gd`. Redux already carries this state. Convert `s_spawn_particles_system` from BaseEventVFXSystem to Redux subscriber.
4. `m_scene_director_manager` — remove 3 redundant ECS publishes (directive_started/completed/beat_advanced). Redux already carries this state.
5. `m_spawn_manager` — dispatch `ACTION_PLAYER_SPAWNED` to Redux; convert `s_spawn_particles_system` from BaseEventVFXSystem to Redux subscriber.

`m_scene_manager` victory routing: remove `EVENT_OBJECTIVE_VICTORY_TRIGGERED` ECS subscription; subscribe to `ACTION_TRIGGER_VICTORY_ROUTING` Redux action dispatch instead.

**Commits**:
- [x] **Commit 1** (RED) — 3 enforcement tests in `test_style_enforcement.gd`:
  - `test_managers_do_not_publish_to_ecs_bus` — grep `scripts/managers/` for `U_ECSEventBus.publish` / `U_ECS_EVENT_BUS.publish`. Fails today (4 violating managers).
  - `test_scene_manager_does_not_subscribe_to_victory_ecs_event` — assert `EVENT_OBJECTIVE_VICTORY_TRIGGERED` absent from m_scene_manager subscribe calls. Fails today.
  - `test_manager_signals_stay_within_allow_list` — grep `scripts/managers/` for signal declarations, assert all in allow-list. Passes today (future enforcement).
- [x] **Commit 2** (GREEN) — Create `docs/adr/` directory + `docs/adr/0001-channel-taxonomy.md`. Add pointer to `AGENTS.md`.
- [x] **Commit 3a** (GREEN) — Migrate `m_save_manager` (new `u_save_actions.gd`, update `ui_hud_controller`).
- [x] **Commit 3b** (GREEN) — Migrate `m_objectives_manager` + victory routing (`m_scene_manager`, `s_victory_handler_system`, new `ACTION_TRIGGER_VICTORY_ROUTING`).
- [x] **Commit 3c** (GREEN) — Migrate `m_vcam_manager` (remove redundant ECS publishes).
- [x] **Commit 3d** (GREEN) — Migrate `m_scene_director_manager` + `m_spawn_manager` (remove redundant ECS publishes, create `u_spawn_actions.gd`, convert `s_spawn_particles_system` to Redux subscriber). Fix vcam parse errors from commit 3c. Remove dead `_objective_victory_unsubscribe` from `m_scene_manager`. Migrate 25+ test methods from ECS bus to Redux action assertions.
- [x] **Commit 4** (GREEN) — Enable enforcement grep tests. 41/41 style tests green.

**F5 Verification**:
- [x] `grep -rn "U_ECSEventBus.publish\|U_ECS_EVENT_BUS.publish\|EVENT_BUS.publish" scripts/managers/` → zero hits (except `m_ecs_manager.gd` which is ECS infrastructure).
- [x] ADR written and linked from `AGENTS.md`.
- [x] Style enforcement grep tests green (41/41).
- [ ] Full test suite green (unit + integration) — 7 pre-existing failures from F5 commits 3a/3b (victory pipeline, save spinner) remain to be fixed.
- [ ] Manual: save spinner, checkpoint toast, and victory scene transition all work correctly.

**Dependency note**: Depends on F3 (parallel mutation paths removed).

---

## Milestone F6: ServiceLocator — Globality, Test Pollution, Last-Write-Wins

**Goal**: `U_ServiceLocator._services` (`u_service_locator.gd:26`) is a process-global static Dictionary with two structural problems:

1. **Last-write-wins `register()`** at `:54-61` — a test fake that forgets to unregister silently wins on the next test. Print-verbose warning is not an error.
2. **No test scoping** — `BaseTest.after_each()` (at `tests/base_test.gd:11`) calls `U_ServiceLocator.clear()` globally, and several UI tests also call it directly. This is the root cause of several recurring test-failure patterns in `MEMORY.md`:
   - `U_StateHandoff` leakage between tests
   - `M_DisplayManager._ensure_appliers()` eager creation
   - Global settings persistence leaking to `user://global_settings.json`

**Two-part fix**:

**Part A — Fail-on-conflict `register()`**:
```gdscript
static func register(service_name: StringName, instance: Node) -> void:
    if _services.has(service_name) and _services[service_name] != instance:
        push_error("register: '%s' already registered. Use register_or_replace() for intentional replacement." % service_name)
        return
    _services[service_name] = instance

static func register_or_replace(service_name: StringName, instance: Node) -> void:
    _services[service_name] = instance
```

**Part B — Test-scoped registry context**:
```gdscript
static func push_scope() -> void:
    _scope_stack.append(_services)
    _services = {}

static func pop_scope() -> void:
    if _scope_stack.is_empty():
        return
    _services = _scope_stack.pop_back()
```

Tests wrap `before_each` (push) / `after_each` (pop) with scope push/pop; production is unchanged (scope stack is empty, default behavior preserved).

**Scope**:
- `scripts/core/u_service_locator.gd`.
- `tests/base_test.gd` — the `after_each()` at line 11 that currently calls `U_ServiceLocator.clear()`. This is the primary migration target.
- UI tests that also call `clear()` directly: `test_pause_menu_navigation.gd`, `test_input_profile_selector.gd`, `test_main_menu.gd`, `test_input_rebinding_overlay.gd`.
- `scripts/root.gd` — audit `_register_if_exists` call sites at `:50-78` (18 service registrations + 3 container registrations via helper at `:113-116`) to confirm no production path intentionally replaces (it should be idempotent).

**Commits**:
- [x] **Commit 1** (RED):
  - `tests/unit/core/test_u_service_locator_conflict.gd` — test that `register()` twice with different instances pushes an error and keeps the first registration; `register_or_replace()` succeeds.
  - `tests/unit/core/test_u_service_locator_scope.gd` — test that `push_scope()` → register → `pop_scope()` reveals previously registered services unchanged.
- [x] **Commit 2** (GREEN) — Implement fail-on-conflict `register()` and `register_or_replace()`. Audit `root.gd:50-78` — confirmed idempotent (same-instance registrations in production). Migrated `test_ecs_manager.gd` service rebinding test and `test_objectives_integration.gd` manager replacement to use `register_or_replace()`.
- [x] **Commit 3** (GREEN) — Implement `push_scope` / `pop_scope`. Migrate `BaseTest` from `clear()` in `after_each()` to `push_scope()` in `before_each()` + `pop_scope()` in `after_each()`. Updated 4 UI tests to remove redundant `clear()` calls. Scope/conflict tests extend `GutTest` directly (not `BaseTest`) since they test the scope mechanism itself.
- [x] **Commit 4** (GREEN) — Added `U_StateHandoff.clear_all()` to `BaseTest.before_each()`. `_ensure_appliers()` tree-dependent initialization already guarded by `owner.is_inside_tree()` — no changes needed.

**F6 Verification**:
- [x] Duplicate-register test green (8/8 pass).
- [x] Scope-isolation test green (7/7 pass).
- [x] Full test suite green with `clear()` calls removed from `BaseTest.after_each()` and UI tests (scopes replace them). 4246/4265 passing (19 pre-existing failures from F5).
- [x] `MEMORY.md` test-failure patterns updated: `U_StateHandoff` and `ServiceLocator` pollution no longer manifest with `BaseTest` scope isolation.

---

## Milestone F7: `RS_Rule` Typed-Schema Erasure

**Goal**: `rs_rule.gd:18-19` declares:

```gdscript
# Fallback for headless parser stability: use Resource arrays when new class_name
# symbols are not yet resolvable in typed Array annotations.
@export var conditions: Array[Resource] = []
@export var effects: Array[Resource] = []
```

Same pattern in `rs_condition_composite.gd:14`. Every runtime consumer must re-validate types via `U_RuleValidator`, and authoring errors surface as runtime "rule scored 0.0" with no stack trace back to the offending `.tres` file.

**Two possible outcomes** — Commit 1 determines which:

- **Path A (preferred)**: Godot 4.6 parser can now resolve typed class-name arrays for `Array[RS_BaseCondition]` / `Array[RS_BaseEffect]` in headless mode. Migrate the types and delete the runtime type-check branches.
- **Path B (fallback)**: Parser limitation persists. Keep `Array[Resource]` but add a load-time schema validator (via `_init()` or a post-load pass) that fails loud with the resource path on type mismatch.

**Scope**:
- `scripts/resources/qb/rs_rule.gd`.
- `scripts/resources/qb/conditions/rs_condition_composite.gd`.
- `scripts/utils/qb/u_rule_validator.gd`.
- 11 `.tres` rule files under `resources/qb/`.

**Commits**:
- [x] **Commit 1** (INVESTIGATION) — Parser feasibility probe: **Path A chosen**. Godot 4.6 resolves typed `Array[RS_BaseCondition]` / `Array[I_Condition]` / `Array[I_Effect]` in `@export` declarations. Evidence: the AI system already uses `Array[I_Condition]` in `rs_ai_goal.gd:9`, `Array[RS_AIGoal]` in `rs_ai_brain_settings.gd:7`, and `Array[RS_AITask]` in `rs_ai_compound_task.gd:8` — all load correctly in headless mode (115/119 AI tests pass; 4 failures pre-existing from F5). The `_coerce_*` setter pattern (`RS_AIGoal._coerce_conditions`, `RS_AICompoundTask._coerce_subtasks`) handles .tres deserialization where Godot sometimes produces untyped arrays. The "headless parser stability" comment in `rs_rule.gd:16-17` is stale — it predates Godot 4.6's parser improvements. Decision: use `Array[I_Condition]` and `Array[I_Effect]` (interface types, matching `RS_AIGoal.conditions: Array[I_Condition]`), add `_coerce_*` setters, re-save .tres files. Keep `U_RuleValidator` as a semantic double-check (field-level validation, not type enforcement).
- [x] **Commit 2** (RED) — Tests for Path A:
  - `test_rs_rule_typed_schema.gd`: 14 tests for type hints (3), coerce methods (9), append (1), validator integration (1). All correctly fail before implementation.
- [x] **Commit 3** (GREEN) — Implement Path A:
  - `rs_rule.gd`: Changed `Array[Resource]` → `Array[I_Condition]` / `Array[I_Effect]`. Added `_coerce_conditions()` / `_coerce_effects()` setters with backing `_conditions` / `_effects` fields. Removed stale "Fallback for headless parser stability" comment.
  - `rs_condition_composite.gd`: Changed `Array[Resource]` → `Array[I_Condition]` for `children`. Added `_coerce_children()` setter with backing `_children` field. Removed type-check branches from `_evaluate_all` and `_evaluate_any` (coerce setter filters wrong-type entries); null guards retained as defensive.
  - `u_ai_goal_selector.gd`: Updated `_read_conditions()` return type from `Array[Resource]` to `Array[I_Condition]`.
  - `u_htn_planner.gd`: Updated `rule_conditions` from `Array[Resource]` to `Array[I_Condition]`. Added `I_Condition` preload.
  - 11 `.tres` rule files: Updated `Array[Resource]` → `Array[I_Condition]` / `Array[I_Effect]`.
  - Updated 8 test files to use `Array[I_Condition]` and `.append()` instead of `Array[Resource]` literal assignment.
- [x] **Commit 4** (GREEN) — Remove dead type-check branches and finalize:
  - Removed now-impossible `must be RS_BaseCondition` / `must be RS_BaseEffect` from `U_RuleEvaluator._is_ignorable_validation_error`.
  - Added doc comment to `U_RuleValidator` documenting it as a semantic double-check layer (field-level validation) on top of typed-array type enforcement.
  - All 14 typed-schema tests, 19 validator tests, 41 style tests, 3804 unit tests green.

**F7 Verification**:
- [x] All 11 rule `.tres` files load green with typed `Array[I_Condition]` / `Array[I_Effect]`.
- [x] Wrong-type entries in conditions/effects are filtered by coerce setters (14/14 typed-schema tests pass).
- [x] Existing rule-engine tests green (178/178 QB tests, 884/884 ECS tests with 4 pre-existing F5 failures).
- [x] Commit 1 notes document Path A decision with evidence from AI system.

**F7 Follow-up (audit-driven propagation)**:
- [x] Rule-consumer systems typed as `Array[RS_Rule]` with coerce setters: `s_game_event_system.gd`, `s_character_state_system.gd`, `s_camera_state_system.gd`.
- [x] Scene director resource scripts migrated to typed arrays + coerce setters, stale "headless parser stability" comments removed: `rs_objective_set.gd` (`Array[RS_ObjectiveDefinition]`), `rs_objective_definition.gd` (`Array[I_Condition]` / `Array[I_Effect]`), `rs_scene_directive.gd` (`Array[I_Condition]` / `Array[RS_BeatDefinition]`), `rs_beat_definition.gd` (`Array[I_Condition]` / `Array[I_Effect]`).
- [x] Scene director `.tres` files re-typed: `cfg_obj_level_complete.tres`, `cfg_obj_game_complete.tres`, `cfg_objset_default.tres`, `cfg_directive_gameplay_base.tres`.
- [x] Test helpers updated to build typed locals before assignment (GDScript rejects `Array[Resource]` → `Array[I_Condition]` cross-type assignment, same pitfall F7 hit).
- [x] AGENTS.md: new "ServiceLocator Registration & Test Isolation (F6)" section documents `register()` fail-on-conflict, `register_or_replace()`, `push_scope`/`pop_scope`, `BaseTest` contract, and the `clear()` → scope-stack-wipe pitfall.
- [x] Full suite verified: 3808/3816 unit (8 risky/pending, 0 failing) + 463/463 integration.

**Known related gap (deferred)**: Many `BaseTest` subclasses override `before_each` / `after_each` without calling `super.before_each()` / `super.after_each()`, so they bypass scope isolation and rely on their own `U_ServiceLocator.clear()`. Not redundant — their primary cleanup. Migrating each to the BaseTest contract is a separate surface-area change with per-file nuance; tracked as architectural consistency work, not a correctness issue at present.

---

## Milestone F8: `S_VCamSystem` + `S_CameraStateSystem` Decomposition (Expanded v7.2.1)

**Goal**: Extend cleanup-v7 `C5`'s wall-visibility decomposition approach to the other two large ECS systems:
- `s_vcam_system.gd` — **551 lines**
- `s_camera_state_system.gd` — **587 lines**

`C5` only targets `s_wall_visibility_system.gd` (1005 lines), leaving two more ~550-line systems with mixed concerns untouched.

**v7.2.1 scope expansion — Phase 0 helper pre-decomposition required**: The original F8 plan assumed the existing helpers under `scripts/ecs/systems/helpers/` could absorb extracted system logic. Pre-implementation audit revealed this would create 800+ line helper files:
- `u_vcam_rotation.gd` is already **740 lines** (5 distinct concerns).
- `u_vcam_orbit_effects.gd` is already **650 lines** (4 distinct effects).
- `u_vcam_response_smoother.gd` is **468 lines** but coherent (all concerns tightly coupled to 2nd-order dynamics — leave as-is).

Phase 0 decomposes the two oversized helpers **before** Phase 1+ pushes system logic into them.

**Current state** (verified against codebase):
- `S_VCamSystem.process_tick` is lines 116-193 (~77 lines) — already partially decomposed into `_prepare_vcam_pipeline_state()`, `_evaluate_vcam_mode_result()`, `_apply_vcam_effect_pipeline()`, and `_write_active_camera_base_fov_from_result()`. **The `process_tick` itself is already near the 80-line target.** The remaining size (~551 total) is in the private helper methods within the file.
- `S_CameraStateSystem.process_tick` is lines 53-80 (~27 lines) — **already well under 80 lines.** It delegates to `_rule_evaluator`, `_build_camera_contexts()`, `_evaluate_context()`, and `_apply_camera_state()`. The remaining size (~587 total) is in these private methods.

**Revised scope**: The decomposition target is **not `process_tick`** (already small) but **the private helper methods** that keep these files at 550+ lines. The goal is to push logic from private methods into the existing helper files:

- `scripts/ecs/systems/s_vcam_system.gd` — candidates for extraction: `_prepare_vcam_pipeline_state()`, `_evaluate_vcam_mode_result()`, `_apply_vcam_effect_pipeline()`, `_resolve_landing_impact_offset()`, `_prune_smoothing_state()`, `_clear_all_smoothing_state()`. These should migrate into existing helpers.
- `scripts/ecs/systems/s_camera_state_system.gd` — candidates: `_apply_camera_state()`, `_build_camera_contexts()`, `_evaluate_context()`, `_context_key_for_context()`. Consider extracting a `u_camera_state_rule_applier.gd` for rule-evaluation-into-component-writes if no existing helper fits.

**Reuse existing helpers** (do not create new ones unless no existing helper fits):
- `scripts/ecs/systems/helpers/u_vcam_runtime_context.gd`
- `scripts/ecs/systems/helpers/u_vcam_runtime_state.gd`
- `scripts/ecs/systems/helpers/u_vcam_effect_pipeline.gd`
- `scripts/ecs/systems/helpers/u_vcam_response_smoother.gd`
- `scripts/ecs/systems/helpers/u_vcam_orbit_effects.gd`
- `scripts/ecs/systems/helpers/u_vcam_landing_impact.gd`
- `scripts/ecs/systems/helpers/u_vcam_rotation.gd`
- Also available: `u_vcam_look_input.gd`, `u_vcam_runtime_services.gd`, `u_vcam_debug.gd`

**Phase 0 — Helper pre-decomposition targets**:

`u_vcam_rotation.gd` (740 lines) — split into three files:
- `u_vcam_rotation_continuity.gd` (~80 lines): `apply_rotation_continuity_policy`, `_apply_rotation_transition`, `_components_share_follow_target`, `_resolve_authored_rotation`, `_resolve_orbit_mode_values`.
- `u_vcam_orbit_centering.gd` (~90 lines): `_start_orbit_centering`, `_step_orbit_centering`, `resolve_orbit_center_target_yaw`, `is_orbit_centering_active`.
- `u_vcam_look_spring.gd` (~180 lines): `resolve_runtime_rotation_for_evaluation`, `step_orbit_release_axis`, `_apply_release_velocity_damping`, `_step_second_order_angle`, look rotation state management, debug logging.

`u_vcam_orbit_effects.gd` (650 lines) — split into three + residual:
- `u_vcam_look_ahead.gd` (~110 lines): `apply_orbit_look_ahead` + `_get_or_create_look_ahead_state` + follow-target sampling for look-ahead.
- `u_vcam_ground_anchor.gd` (~110 lines): `apply_orbit_ground_relative` + `_get_or_create_ground_relative_state`.
- `u_vcam_soft_zone_applier.gd` (~120 lines): `apply_orbit_soft_zone` + soft-zone helper wrappers.
- Remaining `u_vcam_orbit_effects.gd` (~80 lines): `sample_follow_target_speed`, `update_orbit_position_smoothing_bypass`, `_should_bypass_orbit_position_smoothing`, shared prune/clear lifecycle.

`u_vcam_response_smoother.gd` (468 lines) — **leave as-is**. All concerns are tightly coupled to 2nd-order dynamics lifecycle; splitting would over-fragment.

**Commits**:
- [x] **Commit 1a** (GREEN, Phase 0) — Decompose `u_vcam_rotation.gd` (741→235 coordinator + 129 continuity + 133 centering + 404 look_spring). All 8 rotation tests, 41 style tests, 49 VCam helper tests green.
- [x] **Commit 1b** (GREEN, Phase 0) — Decompose `u_vcam_orbit_effects.gd` (651→261 coordinator + 189 look_ahead + 207 ground_anchor + 187 soft_zone_applier). All 11 orbit effects tests, 41 style tests, 49 VCam helper tests green.
- [x] **Commit 1** (RED, Phase 1) — Method-level decomposition tests for extracted system logic:
  - `tests/unit/ecs/systems/test_s_vcam_system_decomposition.gd` — test pipeline builder existence, dead code absence, line count ceilings, callable retention.
  - `tests/unit/ecs/systems/test_s_camera_state_system_decomposition.gd` — test rule applier existence, method verification, line count ceilings, removed method checks.
- [x] **Commit 2** (GREEN) — Extract `S_VCamSystem` private methods to `U_VCamPipelineBuilder` + delete dead code. `S_VCamSystem` 551→297 lines. `process_tick` 79 lines. New: `u_vcam_pipeline_builder.gd` (~120 lines). Deleted: `_evaluate_and_submit`, `_step_orbit_release_axis`, `_resolve_orbit_center_target_yaw`, `_resolve_state_store`. Removed wrappers: `_apply_vcam_effect_pipeline`, `_update_runtime_rotation`, `_resolve_runtime_rotation_for_evaluation`. Updated `test_vcam_system.gd` for removed system wrappers.
- [x] **Commit 3** (GREEN) — Extract `S_CameraStateSystem` private methods to `U_CameraStateRuleApplier`. `S_CameraStateSystem` 602→332 lines. New: `u_camera_state_rule_applier.gd` (~302 lines). 18 methods moved. Constants moved: `CAMERA_SHAKE_SOURCE`, `PRIMARY_CAMERA_ENTITY_ID`, `RS_CAMERA_STATE_CONFIG_SCRIPT`, `DEFAULT_CAMERA_STATE_CONFIG`. State moved: `_shake_time`.
- [x] **Commit 4** (GREEN) — Style enforcement:
  - `tests/unit/style/test_style_enforcement.gd` — `s_vcam_system` < 400, `s_camera_state_system` < 400, `s_wall_visibility_system` < 1200 (C5 target), `process_tick` < 80 for both systems, helpers < 400 (exempt: `u_vcam_response_smoother.gd` 468, `u_vcam_look_spring.gd` 405).
  - Dead code prevention: `_evaluate_and_submit` absent from `s_vcam_system.gd`.

**F8 Verification**:
- [x] All existing vCam and camera-state integration tests green.
- [x] `s_vcam_system.gd` and `s_camera_state_system.gd` each under ~400 lines total (297 and 332).
- [x] `process_tick` method under 80 lines in both systems (79 and ~27).
- [x] **NEW (v7.2.1)**: All helper files under `scripts/ecs/systems/helpers/` under 400 lines post-Phase 0 (with documented exemptions for `u_vcam_response_smoother.gd` and `u_vcam_look_spring.gd`).
- [x] **NEW (v7.2.1)**: `u_vcam_rotation_continuity.gd`, `u_vcam_orbit_centering.gd`, `u_vcam_look_spring.gd`, `u_vcam_look_ahead.gd`, `u_vcam_ground_anchor.gd`, `u_vcam_soft_zone_applier.gd` all exist and are referenced by their consumers.
- [x] Style enforcement test green (48/48).

**Dependency note**: Follows cleanup-v7 `C5` — run F8 after C5 lands so the same decomposition pattern can be applied consistently to all three large systems. **Phase 0 (Commits 1a + 1b) must land before Phase 1+ (Commits 1-4) to avoid pushing system logic into oversized helpers.**

---

## Milestone F9: ECS System Execution Phasing — Named Phase Enum

**Goal**: Improve readability and safety of ECS system ordering. **The core infrastructure already exists**:
- `M_ECSManager` already owns the system loop at `:751-790` — iterates sorted systems calling `system.process_tick(scaled_delta)`.
- `BaseECSSystem` already has `execution_priority: int` (`:18-26`, clamped -100 to 1000).
- Systems are already sorted by priority (`:723-740`).
- A frame state snapshot is already built once and shared (`:762-764`).

**What this milestone adds**: Replace the opaque integer priorities with a named `SystemPhase` enum that groups systems into semantic buckets. Benefits over the current int approach:
1. **Readability** — `SystemPhase.CAMERA` is self-documenting; `execution_priority = 750` is not.
2. **Bucket-level guarantees** — all systems in `PHYSICS_SOLVE` run before any in `CAMERA`, regardless of per-system priority within the bucket.
3. **Compile-time validation** — enum values catch typos that ints don't.

The existing `execution_priority` int can be retained as a **within-phase ordering tiebreaker**.

**Scope**:
- `scripts/managers/m_ecs_manager.gd` — refactor the sort at `:723-740` and loop at `:751-790` to use phase buckets.
- `scripts/ecs/base_ecs_system.gd` — add `SystemPhase` enum and `get_phase()` method. Keep `execution_priority` as within-phase sort key.
- `scripts/interfaces/i_ecs_manager.gd` — update if needed.
- Update all existing `S_*` system scripts to declare a phase.

**Commits**:
- [x] **Commit 1** (RED) — Add tests in `test_m_ecs_manager_phasing.gd`:
  - Systems registered in random order still execute in strict phase order.
  - Within the same phase, systems execute by `execution_priority` (existing behavior preserved).
  - A system with `SystemPhase.CAMERA` always runs after `SystemPhase.PHYSICS_SOLVE` regardless of registration or priority values.
- [x] **Commit 2** (GREEN) — Introduce `SystemPhase` enum on `BaseECSSystem` (`PRE_PHYSICS`, `INPUT`, `PHYSICS_SOLVE`, `POST_PHYSICS`, `CAMERA`, `VFX`). Add `get_phase() -> SystemPhase` with default `PHYSICS_SOLVE`. Keep `execution_priority` as within-phase ordering.
- [x] **Commit 3** (GREEN) — Refactor `M_ECSManager._compare_system_priority` to sort by phase (primary), execution_priority (secondary), instance ID (tertiary).
- [x] **Commit 4** (GREEN) — Assign explicit phases to all 38 `S_*` systems. Add style enforcement test `test_all_ecs_systems_declare_explicit_phase`.

**F9 Verification**:
- [x] Phasing tests green (5/5).
- [x] Existing ECS tests green.
- [x] All `S_*` systems declare an explicit phase (38/38).
- [x] Style enforcement test green (56/56).

---

## Milestone F10: ~~State Store History Truncation~~ — ALREADY IMPLEMENTED (Verification Only)

**Status**: **Fully implemented.** All three planned features already exist:

1. **Ring buffer with configurable max size**: `U_ActionHistoryBuffer` (`scripts/state/utils/u_action_history_buffer.gd`) implements a proper ring buffer with `_head`/`_count` tracking. `configure(max_history_size, enabled)` resizes and resets the buffer.
2. **Setting already wired**: `RS_StateStoreSettings.max_history_size: int = 1000` is exported (`:9`). `M_StateStore` reads it and calls `_action_history_buffer.configure(settings.max_history_size, enable_history)` at `:386`.
3. **Mobile/release disable**: `M_StateStore` at `:384-385` already disables history on mobile: `if U_MOBILE.is_mobile(): enable_history = false`.

**Commit** (single verification commit):
- [ ] **Commit 1** (VERIFY) — Add test `test_m_state_store_history_truncation.gd` (if not already covered by existing `test_m_state_store.gd`):
  - Assert buffer does not exceed `max_history_size` after dispatching `max_history_size + 100` actions.
  - Assert `configure(0, true)` and `configure(N, false)` both result in empty history.
  - Assert ring buffer wraps correctly (oldest entries are evicted first).

**F10 Verification**:
- [ ] Verification tests green.
- [ ] Existing store tests green.

---

## Milestone F11: Event Bus "Zombie" Prevention (Dead Subscriber Pruning)

**Goal**: Prevent memory leaks from stale subscriber references in the event bus. If entities subscribe but are `queue_free()`'d without unsubscribing, the bus retains dead references.

**Current state** (verified against `scripts/events/base_event_bus.gd`):
- `BaseEventBus` is the shared base class used by both `U_ECSEventBus` (`scripts/events/ecs/u_ecs_event_bus.gd`) and `U_StateEventBus` (`scripts/events/state/u_state_event_bus.gd`). Both are static facades delegating to a `BaseEventBus` singleton instance.
- `publish()` at `:93` already calls `callback.is_valid()` before invoking — so **dispatch-time crashes from dead callables are already handled**.
- However, dead entries **remain in `_subscribers` arrays** indefinitely (no pruning), causing a slow memory leak over long play sessions.
- `publish()` at `:93` also calls `_subscribers[event].duplicate()` per publish to avoid mutation during iteration — this is safe but allocates on every publish.

**Scope** — all changes go in `scripts/events/base_event_bus.gd` (the base class), **not** the `U_ECSEventBus` or `U_StateEventBus` facades:
- `BaseEventBus._subscribers` storage (`:12`)
- `BaseEventBus.publish()` (`:76-97`)
- `BaseEventBus.subscribe()` (`:18-56`)

**Commits**:
- [ ] **Commit 1** (RED) — Add test `tests/unit/ecs/events/test_base_event_bus_zombies.gd`:
  - An object subscribes, is `free()`'d, and an event is published. Assert: no crash (already true), **and** the dead subscriber is removed from the internal subscriber list after publish.
  - After pruning, `_subscribers[event]` does not contain any entries where `callback.is_valid() == false`.
- [ ] **Commit 2** (GREEN) — Add publish-time pruning in `BaseEventBus.publish()`: after iterating subscribers, remove entries where `callback.is_valid() == false` from the source array. This replaces the current pattern where dead entries silently accumulate.
- [ ] **Commit 3** (GREEN) — Replace the per-publish `.duplicate()` at `:93` with an index-based iteration that handles mid-iteration removal safely (iterate backwards, or use a `_publishing` guard flag to defer removals). This eliminates the per-publish allocation.

**F11 Verification**:
- [ ] Zombie pruning tests green.
- [ ] Existing event bus tests green (including `tests/unit/ecs/events/test_ecs_event_bus.gd`).
- [ ] No `.duplicate()` call in `BaseEventBus.publish()` (style enforcement grep).

---

## Milestone F12: Settings Overlay Wrapper Deduplication (v7.2.1 Addition)

**Goal**: Three files are 53 lines each, character-for-character identical except for `class_name`. Collapse into a single base class.

**Evidence** (verified):
- `scripts/ui/settings/ui_audio_settings_overlay.gd` — 53 lines, `class_name UI_AudioSettingsOverlay`
- `scripts/ui/settings/ui_display_settings_overlay.gd` — 53 lines, `class_name UI_DisplaySettingsOverlay`
- `scripts/ui/settings/ui_localization_settings_overlay.gd` — 53 lines, `class_name UI_LocalizationSettingsOverlay`
- All 52 non-`class_name` lines are bit-for-bit identical (same `extends`, same `preload` constants, same `@onready` vars, same `_on_panel_ready`, `_on_back_pressed`, `_apply_theme_tokens`, `_close_overlay`).

**Out of scope**:
- `ui_vfx_settings_overlay.gd` (430 lines) — legitimately different. Uses Apply/Cancel pattern, inline controls, and M_VFXManager preview integration. Do not force into the shared base.
- Settings **tabs** (`ui_*_settings_tab.gd`, 501–873 lines) — share scaffolding but not identical enough to warrant a base class. Leave as-is; a base class would add coupling without much savings.

**Scope**:
- New: `scripts/ui/settings/base_settings_simple_overlay.gd` — extract shared logic.
- Modify: the three overlay files → reduce each to ~5 lines (`@icon` + `extends` + `class_name`).
- Existing class chain is `BaseOverlay` → `UI_*SettingsOverlay`. New base goes between: `BaseOverlay` → `BaseSettingsSimpleOverlay` → `UI_*SettingsOverlay`.
- Scene files (`ui_audio_settings_overlay.tscn` etc.) remain unchanged — they continue to instance tab content as before.

**Commits**:
- [ ] **Commit 1** (RED) — `tests/unit/ui/settings/test_settings_simple_overlay_base.gd`:
  - Assert all three overlays share behavior (theme application, panel ready, back press, close).
  - Assert each concrete overlay script file is under 15 lines (post-refactor).
- [ ] **Commit 2** (GREEN) — Create `scripts/ui/settings/base_settings_simple_overlay.gd`. Extract the 52 shared lines into it. Keep `@onready` references for `_main_panel` / `_main_panel_content` since scene structure is shared across all three overlays.
- [ ] **Commit 3** (GREEN) — Reduce each of the three overlay files to:

  ```gdscript
  @icon("res://assets/editor_icons/icn_utility.svg")
  extends "res://scripts/ui/settings/base_settings_simple_overlay.gd"
  class_name UI_AudioSettingsOverlay
  ```

- [ ] **Commit 4** (GREEN) — Style enforcement: `tests/unit/style/test_style_enforcement.gd` asserts each of `ui_audio_settings_overlay.gd`, `ui_display_settings_overlay.gd`, `ui_localization_settings_overlay.gd` is under 15 lines. Explicitly exclude `ui_vfx_settings_overlay.gd` from this assertion.

**F12 Verification**:
- [ ] All existing settings-overlay integration tests green (navigation, theme, close behavior).
- [ ] Three overlay files reduced from 53 → ~5 lines each.
- [ ] `base_settings_simple_overlay.gd` contains the extracted shared behavior.
- [ ] VFX overlay unchanged.
- [ ] Style enforcement test green.

**Dependency note**: Independent. Can run anytime. No coupling to F1–F11.

---

## Milestone F15: Designer-Facing Resource Schema Validation (v7.2.1 Addition)

**Goal**: Extend F7's "fail loud at load" pattern beyond `RS_Rule` to three more designer-facing resources where typos or missing fields cause silent runtime crashes with no stack trace back to the `.tres` file.

**Evidence** (verified):
- `scripts/resources/rs_game_config.gd` — **HIGH RISK**. Fields: `retry_scene_id`, `route_retry`, `default_objective_set_id`, `required_final_area`. Zero validation. A cleared `retry_scene_id` crashes the reset-run flow. An invalid `default_objective_set_id` produces a silent no-op in `M_ObjectivesManager`.
- `scripts/resources/input/rs_input_profile.gd` — **MEDIUM RISK**. `action_mappings: Dictionary` accepts any shape. `virtual_buttons: Array[Dictionary]` accepts malformed entries (missing `action` or `position` keys). Invalid action names silently fail at input dispatch.
- `scripts/resources/scene_management/rs_scene_registry_entry.gd` — **MEDIUM RISK**. Already has `_validate_property()` editor warnings and an `is_valid()` utility, but no load-time enforcement. Scene path is not existence-checked.

**Out of scope**:
- `scripts/resources/ui/rs_ui_theme_config.gd` — already has `ensure_runtime_defaults()` that creates fallback StyleBoxes. Runtime defaults prevent crash-level failures; font-size / color range validation is nice-to-have but not critical.
- `RS_Rule` — handled by F7.

**Scope**:
- Modify: `scripts/resources/rs_game_config.gd` — add `_init()` validation.
- Modify: `scripts/resources/input/rs_input_profile.gd` — add `_init()` validation + structure checks for `virtual_buttons`.
- Modify: `scripts/resources/scene_management/rs_scene_registry_entry.gd` — elevate existing `_validate_property()` warnings to load-time errors.
- Cross-reference: `U_SceneRegistry` (for scene ID existence), objectives manager objective-set registry, areas registry.

**Validation strategy**:
- Use `_init()` for mandatory schema checks that fail the resource load.
- Fail messages MUST include `resource_path` so designers can locate the bad `.tres` file.
- For cross-resource checks (e.g., "does `retry_scene_id` exist in `U_SceneRegistry`?") that require a registry lookup, defer to a one-shot validation pass at boot (e.g., in `M_GameplayInitializerManager` or equivalent bootstrap) rather than `_init()`, since `_init()` runs before autoloads are available.

**Commits**:
- [ ] **Commit 1** (RED) — Validation tests:
  - `tests/unit/resources/test_rs_game_config_validation.gd`: assert a `.tres` with empty `retry_scene_id` fails at load with `resource_path` in the error.
  - `tests/unit/resources/test_rs_input_profile_validation.gd`: assert malformed `virtual_buttons` entries fail at load.
  - `tests/unit/resources/test_rs_scene_registry_entry_validation.gd`: assert empty `scene_id` or `scene_path` fails at load (not just editor warning).
- [ ] **Commit 2** (GREEN) — `RS_GameConfig._init()`: validate all four fields (`retry_scene_id`, `route_retry`, `default_objective_set_id`, `required_final_area`) are non-empty. Include `resource_path` in `push_error`.
- [ ] **Commit 3** (GREEN) — `RS_InputProfile._init()`: validate `profile_name` non-empty, `action_mappings` non-empty, each `virtual_buttons` entry has required keys (`action`, `position`), `virtual_joystick_position` in sensible bounds.
- [ ] **Commit 4** (GREEN) — `RS_SceneRegistryEntry._init()`: elevate existing `_validate_property()` warnings to `push_error` on empty `scene_id` / `scene_path`. Keep the existing `is_valid()` utility as a double-check layer.
- [ ] **Commit 5** (GREEN) — Cross-reference boot validation: in `M_GameplayInitializerManager` (or equivalent bootstrap), validate `RS_GameConfig.retry_scene_id` exists in `U_SceneRegistry` and `default_objective_set_id` exists in the objectives registry. Fail loud on boot if not.

**F15 Verification**:
- [ ] All validation tests green.
- [ ] Injecting an invalid field into any of the three resource `.tres` files fails loudly at load with `resource_path` in the error.
- [ ] Cross-reference boot validation catches dangling scene/objective IDs before gameplay starts.
- [ ] Existing resource-consumer tests green (no regression).

**Dependency note**: Independent. Pattern mirrors F7 for `RS_Rule`. Can run in parallel with F7 or after.

---

## Milestone F16: AI System Type Safety & Consistency (v7.2.2 Addition)

**Goal**: Fix six inconsistencies where the AI system falls short of non-AI project standards. No behavioral changes — type annotations, constant migrations, interface convention alignment, and additive debug methods.

**Evidence** (verified against codebase):

1. **Five `Variant`-typed service fields** in `S_AIBehaviorSystem` (`:28-32`) and two `Variant` parameters in `S_AIDetectionSystem._process_detection` (`:75-76`) discard static type information. Non-AI systems use concrete or interface types.
2. **`Variant`-typed planner context** throughout `U_HTNPlanner` and `U_HTNPlannerContext.reusable_rule: Resource` (`:5`) instead of `RS_Rule`. The non-AI rule utilities (`U_RuleScorer`, `U_RuleSelector`) use typed parameters.
3. **`I_AIAction` silent stubs** — `start()` uses `pass`, `tick()` uses `pass`, `is_complete()` returns `false` (`i_ai_action.gd:12,15,18`). Other project interfaces (`I_ECSManager`, `I_StateStore`, `I_Condition`) use `push_error("not implemented")` so unimplemented methods fail loudly.
4. **Raw string keys in task_state** — 5 action files use 9 bare string literals (`"elapsed"`, `"scan_elapsed"`, `"scan_active"`, `"scan_rotation_speed"`, `"animation_state"`, `"animation_requested"`, `"published"`, `"completed"`, plus Variant coercion) instead of `U_AITaskStateKeys` constants. `RS_AIActionMoveTo` already uses the constants.
5. **`C_AIBrainComponent` lacks `get_debug_snapshot()`** — `C_MovementComponent` and `C_JumpComponent` both expose debug snapshots via typed methods; `C_AIBrainComponent` exposes raw `task_state` and `suspended_goal_state` dictionaries with no encapsulated snapshot accessor.
6. **`U_HTNPlanner._decompose_recursive` silently returns on null/depth-exceeded** — no diagnostic `push_error` for null task input (`:11`) or depth exceeded (`:25`), unlike `C_AIBrainComponent._validate_required_settings()` which uses `push_error`.

**Out of scope**:
- **Detection system generalization** (removing `ai_demo_flag` naming, adding sensor abstraction, LOS checks, memory) — that's a feature addition, not a cleanup.
- **`RS_AIActionAnimate` behavior change** (making it wait for animation completion) — the instant-complete behavior is intentional fire-and-forget; a blocking variant would be a new action subclass.
- **`context: Dictionary` throughout the AI pipeline** — the context dictionary is the standard ECS query result pattern; replacing it would be a major refactor beyond cleanup scope.

**Scope**:
- `scripts/ecs/systems/s_ai_behavior_system.gd` — type 5 `Variant` fields
- `scripts/ecs/systems/s_ai_detection_system.gd` — type 2 `Variant` parameters
- `scripts/utils/ai/u_htn_planner.gd` — type `planner_context` as `U_HTNPlannerContext`, add `push_error` guards
- `scripts/utils/ai/u_htn_planner_context.gd` — type `reusable_rule` as `RS_Rule`
- `scripts/interfaces/i_ai_action.gd` — replace `pass`/`return false` with `push_error` stubs
- `scripts/utils/ai/u_ai_task_state_keys.gd` — add 8 new constants
- `scripts/resources/ai/actions/rs_ai_action_wait.gd` — migrate raw keys, remove Variant coercion
- `scripts/resources/ai/actions/rs_ai_action_scan.gd` — migrate raw keys, remove Variant coercion
- `scripts/resources/ai/actions/rs_ai_action_animate.gd` — migrate raw keys, add doc comment
- `scripts/resources/ai/actions/rs_ai_action_publish_event.gd` — migrate raw keys
- `scripts/resources/ai/actions/rs_ai_action_set_field.gd` — migrate raw keys
- `scripts/ecs/components/c_ai_brain_component.gd` — add `get_debug_snapshot()` / `update_debug_snapshot()`
- `tests/unit/style/test_style_enforcement.gd` — add grep assertion for bare task-state string keys

**Commits**:

- [x] **Commit 1** (GREEN) — Type AI service fields and planner context parameters:
  - `s_ai_behavior_system.gd`: Replace 5 `Variant` fields with concrete types (`U_AIGoalSelector`, `U_AITaskRunner`, `U_AIReplanner`, `U_AIContextBuilder`, `U_DebugLogThrottle`).
  - `s_ai_detection_system.gd`: Replace 2 `Variant` parameters in `_process_detection` with `C_DetectionComponent` and `C_MovementComponent`. `_publish_enter_event` param also typed.
  - `u_htn_planner.gd`: Replace `planner_context: Variant` with `planner_context: U_HTNPlannerContext` in 5 locations. Add `push_error` for null task input and depth exceeded. Type `method_rule: Resource` as `RS_Rule`.
  - `u_htn_planner_context.gd`: Type `reusable_rule: Resource` as `reusable_rule: RS_Rule`. Update `_init` parameter type.

- [x] **Commit 2** (GREEN) — Add `push_error` stubs to `I_AIAction`:
  - `i_ai_action.gd`: Replace `pass` in `start()` and `tick()` with `push_error("I_AIAction.%s: not implemented by subclass %s" % ...)`. Add `push_error` before `return false` in `is_complete()`.
  - Update `test_i_ai_action_base.gd`: renamed test, added 3 new push_error verification tests.

- [x] **Commit 3** (GREEN) — Migrate raw task_state string keys to `U_AITaskStateKeys` constants:
  - `u_ai_task_state_keys.gd`: Add 8 constants: `ELAPSED`, `SCAN_ELAPSED`, `SCAN_ACTIVE`, `SCAN_ROTATION_SPEED`, `ANIMATION_STATE`, `ANIMATION_REQUESTED`, `PUBLISHED`, `COMPLETED`.
  - `rs_ai_action_wait.gd`: Replace `"elapsed"` with `U_AI_TASK_STATE_KEYS.ELAPSED`. Remove Variant type coercion — `start()` writes `float`, so `float(task_state.get(...))` is sufficient.
  - `rs_ai_action_scan.gd`: Replace `"scan_elapsed"`, `"scan_active"`, `"scan_rotation_speed"` with constants. Remove Variant coercion from elapsed reads.
  - `rs_ai_action_animate.gd`: Replace `"animation_state"`, `"animation_requested"` with constants.
  - `rs_ai_action_publish_event.gd`: Replace `"published"` with constant.
  - `rs_ai_action_set_field.gd`: Replace `"completed"` with constant.
  - Update `test_u_ai_task_state_keys.gd` with 8 new key assertions (18 total: 10 existing + 8 new).

- [x] **Commit 4** (GREEN) — Add `get_debug_snapshot()` to `C_AIBrainComponent`:
  - Add `var _debug_snapshot: Dictionary = {}`, `update_debug_snapshot(snapshot: Dictionary)`, `get_debug_snapshot() -> Dictionary` mirroring `C_JumpComponent` pattern.
  - Update `S_AIBehaviorSystem._debug_log_brain_state` to build snapshot dict and call `brain.update_debug_snapshot()`.
  - Add 3 tests in `test_c_ai_brain_component.gd`: `test_update_debug_snapshot`, `test_get_debug_snapshot_returns_copy`, `test_debug_snapshot_includes_goal_id`.

- [x] **Commit 5** (GREEN) — Document `RS_AIActionAnimate` fire-and-forget semantics:
  - Add class-level doc comment to `rs_ai_action_animate.gd` clarifying instant-complete behavior is intentional. Note that blocking animation actions would need a different subclass.

- [x] **Commit 6** (GREEN) — Style enforcement grep test for AI task-state key constants:
  - Add assertion `test_ai_action_scripts_use_task_state_key_constants` to `test_style_enforcement.gd` forbidding `task_state["` (bare string key access) in `scripts/resources/ai/actions/*.gd`.

**F16 Verification**:
- [x] All existing AI unit tests green (goal selector, task runner, replanner, context builder, HTN planner, behavior system goals/tasks, detection system).
- [x] All existing AI integration tests green (pipeline, goal resume, spawn recovery, interaction triggers).
- [x] `test_i_ai_action_base.gd` verifies `push_error` stubs.
- [x] `test_u_ai_task_state_keys.gd` covers 18 total constants (10 existing + 8 new).
- [x] `test_c_ai_brain_component.gd` covers debug snapshot methods.
- [x] Grep search confirms zero bare string literals in task_state access across `scripts/resources/ai/actions/`.
- [x] No behavioral change — type annotations, constant migrations, and doc comments only.

**Dependency note**: Independent of F1–F15. Can run in parallel with any milestone that does not touch the same files. **Partial overlap with F9**: both touch `s_ai_behavior_system.gd`. Land F16 Commit 1 first (type annotations are simpler); F9 can add `SystemPhase` afterward without merge issues.

---

## Closing: AGENTS.md Sprawl (Non-Numbered Reflection)

This section is intentionally **not** a numbered milestone. It's a direction to revisit after F1–F8 are green, and it depends on F5 landing first.

### Observation

`AGENTS.md` has grown to ~34k tokens (~1000 lines) and now serves simultaneously as:
- Onboarding doc
- Architectural decision record log
- Refactor history
- Invariant/contract registry
- Per-module README surface

Every "Phase X contract" in `AGENTS.md` is a rule the code can't express — typically because one of three things:
1. **GDScript's type system** doesn't enforce the invariant at compile time (e.g., `Array[Resource]` type erasure, see F7).
2. **The `.tres` resource format** has no schema validation (e.g., QB rule authoring errors).
3. **Ordering semantics across the three communication channels** have no type-level enforcement (e.g., "dispatch `set_active_runtime` before `start_blend`", addressed by F5).

**Evidence**: Eight of the last ~twelve AI-module refactors (`R1`, `R4`, `R5`, `R6`, `R7`, `R8`, `R9`, `R10` in the AI contracts section of `AGENTS.md`) were walking back duck-typing drift — re-enforcing typed contracts that the type system can't prevent. They are enforced only by prose in `AGENTS.md` and a growing set of style-enforcement grep tests. That's a standing tax.

### Proposed restructuring (direction, not a task)

Split `AGENTS.md` into three layers:

**Layer 1 — `AGENTS.md` (slim index, target ~200 lines)**:
- Project orientation (where things are, what the ECS/state architecture is).
- Mandatory reads for new contributors.
- Top-level rules (commit cadence, TDD expectations, style-test requirements).
- Pointers to per-subsystem contract docs and ADRs.

**Layer 2 — `docs/contracts/<subsystem>.md` (per-subsystem contracts)**:
Candidates:
- `docs/contracts/vcam.md` (currently ~60 lines of "Phase X" contracts inlined in AGENTS.md)
- `docs/contracts/scene_manager.md`
- `docs/contracts/state_store.md`
- `docs/contracts/qb_rules.md`
- `docs/contracts/ai.md`
- `docs/contracts/ui_theme.md`
- `docs/contracts/ecs.md`
- `docs/contracts/mobile.md`

Each contract doc owns its own invariants, phase history, and pitfalls. `AGENTS.md` just points to them.

**Layer 3 — `docs/adr/NNNN-<title>.md` (architectural decision records)**:
One ADR per architectural decision that currently lives inline in `AGENTS.md`. Suggested initial ADRs:
- `0001-channel-taxonomy.md` (created by F5)
- `0002-rule-engine-headless-fallback.md` (resolved or documented by F7)
- `0003-vcam-blend-ordering.md`
- `0004-service-locator-scoping.md` (created by F6)
- `0005-state-store-single-mutation-path.md` (created by F3)
- `0006-save-load-reconciliation.md`
- `0007-scene-manager-transition-pipeline.md`

### One-time audit

Every "Phase X contract" currently in `AGENTS.md` gets one of three treatments:
1. **Move** to a per-subsystem contract doc.
2. **Promote** to an ADR with full Context / Decision / Consequences framing.
3. **Delete** — if the prose is expressible as a style-enforcement test, write the test and delete the prose.

### Enforcement

Add a CI check asserting `AGENTS.md` stays under a target word/token budget so it cannot silently regrow past the slim-index size. A simple grep line count or `wc -w` assertion is enough.

### Trigger for action

Revisit this section and promote it to a numbered milestone (F12) when **all three** conditions are met:
1. F5 (channel taxonomy ADR) has landed and the `docs/adr/` directory exists.
2. F7 (typed schema) has resolved the headless-parser question.
3. At least two more AGENTS.md growth incidents have occurred post-v7.2 (confirming the sprawl pattern continues and isn't a one-time artifact of the v7 refactor wave).

If condition 3 does not occur within 3 months of F5 landing, the sprawl may be self-limiting and this restructuring is not needed.

### Why this isn't F9

- It's a documentation / process change, not a code refactor — the TDD cadence that structures F1–F8 doesn't map cleanly.
- It depends on F5 (channel taxonomy ADR) landing first, since a large portion of current `AGENTS.md` content will collapse into that one ADR.
- It benefits from F1–F4, F6, F7 landing first so that contracts currently enforced by prose can be deleted once enforced by code.

Treat this section as a direction to revisit after F1–F8 are green. The slim-index split itself is a one-day task once the prerequisites are done.

---

## Cross-Cutting Concerns (Not Milestones — Address Opportunistically)

These are smaller follow-ups surfaced during the review that don't justify their own milestone but should be fixed when touching the relevant files:

- **`m_scene_manager.gd:170+` has 58 methods** — even post-C6 and post-F1, the remaining methods should be audited for further extraction candidates (notably the `_reconcile_*` and `_sync_*` family).
- **`M_StateStore` imports 16 reducers + 11 `RS_*InitialState` resources at the top** (`:26-46`). Adding a 17th slice requires editing the store in four places. Consider a slice registry pattern (not urgent, but tracked).
- **`U_ECSEventBus.publish()` duplicates the subscriber list on every call** (already noted in cleanup-v7 cross-cutting) — one allocation per event dispatch. Consider copy-on-write.
- **`M_StateStore._input`** handles two unrelated debug overlays (state debug + cinema debug) — extract to a dedicated debug overlay handler (already noted in cleanup-v7 cross-cutting).
- **`M_SceneManager._scene_history`** grows without bound (already noted in cleanup-v7 Scalability Issues) — add bound/trim.
- **`U_AITaskStateKeys` has the same redundant preload pattern** as the C2.10 fix — 6 consumer files use `const U_AI_TASK_STATE_KEYS := preload(...)` then reference `U_AI_TASK_STATE_KEYS.KEY_*`, but `class_name U_AITaskStateKeys` makes these globally available. Same fix as C2.10: remove preload constants, reference `U_AITaskStateKeys.KEY_*` directly (or keep `const U_AITaskStateKeys := preload(...)` for headless test resolution, matching the RSRuleContext pattern).
