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
- [ ] **Commit 1** (RED) — Strict-mode tests:
  - `tests/unit/state/test_m_state_store_slice_dependencies.gd`:
    - With `strict_slice_dependencies = false`: undeclared access returns data and pushes an error (current behavior preserved).
    - With `strict_slice_dependencies = true`: undeclared access returns `{}` and pushes an error.
    - Declared access in both modes returns data without error.
- [ ] **Commit 2** (GREEN) — Add `strict_slice_dependencies` to `RS_StateStoreSettings`. Implement the strict branch in `get_slice`.
- [ ] **Commit 3** (GREEN) — Audit: temporarily enable strict mode at test-harness level, run the full test suite, catalog every violation into a scratch file. Do not fix yet.
- [ ] **Commit 4** (GREEN) — Fix each cataloged violation. Two fix paths per violation:
  - Declare the missing dependency in the caller's `RS_StateSliceConfig.dependencies`, **or**
  - Remove the undeclared access (refactor to a selector or a legitimate channel).
  Leave `strict_slice_dependencies` default at `false` until the audit is clean.
- [ ] **Commit 5** (GREEN, **behavior change**) — Flip the default:
  ```gdscript
  @export var strict_slice_dependencies: bool = true
  ```
  This is the one explicit behavior-change commit in F4. Runs after audit + fixes are green. Any late-discovered violation fails fast at runtime instead of drifting.

**F4 Verification**:
- [ ] Strict-mode tests green.
- [ ] Full test suite green with `strict_slice_dependencies = true` as default.
- [ ] Zero `push_error` for undeclared slice access during normal gameplay boot + main-menu round-trip.
- [ ] New slice dependencies properly declared in `RS_StateSliceConfig`.

---

## Milestone F5: Communication Channel Taxonomy

**Goal**: Pick one channel per concern and document the rule. Without this, every new feature re-litigates Redux vs `U_ECSEventBus` vs Godot signal, and `AGENTS.md` keeps accumulating "Phase X ordering contract" notes.

**Evidence of the problem (measured at the start of v7.2)**:
- **278** `store.dispatch` / `_store.dispatch` call sites
- **24** `U_ECSEventBus.publish` + **22** `U_ECSEventBus.subscribe` sites
- Godot signals on `M_ECSManager` (`component_added/removed`), `M_StateStore` (`slice_updated`, `action_dispatched`), `M_SceneManager` (`transition_visual_complete`)
- `m_scene_manager.gd` uses **all four at once** — dispatches `scene_swapped`, emits `transition_visual_complete`, subscribes to `EVENT_OBJECTIVE_VICTORY_TRIGGERED`, and calls `U_ServiceLocator.try_get_service` for camera manager fallback

**Proposed rule** (to be documented in a new ADR):

| Concern | Channel |
|---|---|
| Durable cross-frame state (anything reducible, anything a UI reads from state) | **Redux dispatch** only |
| Fire-and-forget transient notifications (VFX/SFX requests, one-shot events that don't belong in state) | **`U_ECSEventBus`** |
| Intra-component / intra-manager wiring (signal-based reactivity between a component and its owner) | **Godot signals** |
| Everything else | **Method calls** |

**Scope**:
- New: `docs/adr/0001-channel-taxonomy.md` — the decision record (formatted as an ADR: Context / Decision / Consequences). **Note: `docs/adr/` directory does not exist yet — create it in Commit 2.**
- `AGENTS.md` — add a slim "Channel taxonomy" pointer referencing the ADR (no detail duplication).
- `tests/unit/style/test_style_enforcement.gd` — new grep assertions:
  - No `U_ECSEventBus.publish` with event names matching patterns that look like durable state (`*_state`, `*_set`, `*_progress`, `*_changed` where the name describes state rather than an event).
  - Manager classes (files under `scripts/managers/`) should not declare `signal` members intended for cross-manager communication; cross-manager talk uses Redux or the ECS bus.
  - (Allow-list exceptions: `M_StateStore.slice_updated`, `M_StateStore.action_dispatched`, `M_StateStore.store_ready`, `M_ECSManager.component_added/removed`, `M_SceneManager.transition_visual_complete` — these are documented exceptions to the rule.)

**Commits**:
- [ ] **Commit 1** (RED) — Style enforcement tests for the channel rule. Start with them failing against current code.
- [ ] **Commit 2** (GREEN) — Write `docs/adr/0001-channel-taxonomy.md`. Add the pointer to `AGENTS.md`. Review with the team/self before migration.
- [ ] **Commit 3** (GREEN) — Audit current violations. For each `U_ECSEventBus.publish` that looks like durable state, migrate to a reducer+action. For each manager `signal` that exists for cross-manager talk, migrate to an action or an ECS-bus event. Update the allow-list for documented intentional exceptions.
- [ ] **Commit 4** (GREEN) — Enable the grep tests in CI. Zero violations at land.

**F5 Verification**:
- [ ] ADR written and linked from `AGENTS.md`.
- [ ] Style enforcement grep tests green.
- [ ] At least one concrete migration committed as an example (candidate: `m_scene_manager` victory routing — consolidate the Redux/ECS-bus/signal trio into one channel).
- [ ] Existing test suite green.

**Dependency note**: Depends on F3 (parallel mutation paths removed) so the "Redux is the only state channel" rule is enforceable without exception.

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
- [ ] **Commit 1** (RED):
  - `tests/unit/core/test_u_service_locator_conflict.gd` — test that `register()` twice with different instances pushes an error and keeps the first registration; `register_or_replace()` succeeds.
  - `tests/unit/core/test_u_service_locator_scope.gd` — test that `push_scope()` → register → `pop_scope()` reveals previously registered services unchanged.
- [ ] **Commit 2** (GREEN) — Implement fail-on-conflict `register()` and `register_or_replace()`. Audit `root.gd:50-78` — confirm it's idempotent. If any production path legitimately replaces, switch it to `register_or_replace`.
- [ ] **Commit 3** (GREEN) — Implement `push_scope` / `pop_scope`. Migrate the test harness: replace `U_ServiceLocator.clear()` in `BaseTest.after_each()` with `push_scope()` in `BaseTest.before_each()` and `pop_scope()` in `BaseTest.after_each()`. Update the UI tests that call `clear()` directly to rely on the base class scoping instead.
- [ ] **Commit 4** (GREEN) — Migrate `U_StateHandoff` and `M_DisplayManager._ensure_appliers()` follow-ups (both listed in `MEMORY.md` as recurring test-failure patterns rooted in module-level state) to the scope pattern where applicable. Lazy-init appliers only when the manager is in-tree.

**F6 Verification**:
- [ ] Duplicate-register test green.
- [ ] Scope-isolation test green.
- [ ] Full test suite green with `clear()` calls removed from `BaseTest.after_each()` and UI tests (scopes replace them).
- [ ] `MEMORY.md` test-failure patterns for `U_StateHandoff` and `_ensure_appliers` no longer manifest.

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
- [ ] **Commit 1** (INVESTIGATION) — Parser feasibility probe:
  - Create a scratch resource file using `@export var conditions: Array[RS_BaseCondition] = []`.
  - Load headless (`godot --headless`) and in-editor.
  - Record the result in this milestone's notes.
  - Decide Path A or Path B.
- [ ] **Commit 2** (RED) — Tests for the chosen path:
  - **Path A**: A `.tres` file with a wrong-type entry fails to load with a specific parser error.
  - **Path B**: The load-time schema validator catches a mis-typed entry and reports the resource path in the error.
- [ ] **Commit 3** (GREEN) — Implement the chosen path:
  - **Path A**: Change `Array[Resource]` to `Array[RS_BaseCondition]` / `Array[RS_BaseEffect]` / `Array[RS_BaseCondition]` (composite). Re-save all 11 `.tres` rule files.
  - **Path B**: Add `_init()` override on `RS_Rule` and `RS_ConditionComposite` that calls a static schema-check utility. Fail with `resource_path` in the message.
- [ ] **Commit 4** (GREEN) — Remove the "Fallback for headless parser stability" comment from both resource files. For Path A, delete now-dead runtime type-check branches from `U_RuleValidator`. For Path B, keep `U_RuleValidator` but document that it's now a double-check layer.

**F7 Verification**:
- [ ] All 11 rule `.tres` files still load green in headless + editor.
- [ ] Injecting a type error into any `.tres` file fails loudly at load with a resource path, not at runtime "rule scored 0.0".
- [ ] Existing rule-engine tests green.
- [ ] Commit 1 notes clearly document which path was taken and why.

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
- [ ] **Commit 1a** (GREEN, Phase 0) — Decompose `u_vcam_rotation.gd` into `u_vcam_rotation_continuity.gd`, `u_vcam_orbit_centering.gd`, and `u_vcam_look_spring.gd`. Update `u_vcam_effect_pipeline.gd` and `s_vcam_system.gd` imports. All existing VCam integration tests must stay green.
- [ ] **Commit 1b** (GREEN, Phase 0) — Decompose `u_vcam_orbit_effects.gd` into `u_vcam_look_ahead.gd`, `u_vcam_ground_anchor.gd`, `u_vcam_soft_zone_applier.gd`, and the residual `u_vcam_orbit_effects.gd`. Update imports. All existing VCam integration tests must stay green.
- [ ] **Commit 1** (RED, Phase 1) — Method-level decomposition tests for extracted system logic:
  - `tests/unit/ecs/systems/test_s_vcam_system_decomposition.gd` — test the pipeline/mode/effect methods independently via their helper classes after extraction.
  - `tests/unit/ecs/systems/test_s_camera_state_system_decomposition.gd` — test `_apply_camera_state` logic, context building, and rule-result-to-component-write independently.
- [ ] **Commit 2** (GREEN) — Extract `S_VCamSystem` private methods into existing (now smaller) helpers. Target: total file under 400 lines. `process_tick` stays as-is (already under 80 lines). Identify which private methods map to which helper by matching concerns (e.g., `_resolve_landing_impact_offset` → `u_vcam_landing_impact.gd`, `_prune_smoothing_state` → `u_vcam_response_smoother.gd`).
- [ ] **Commit 3** (GREEN) — Extract `S_CameraStateSystem` private methods similarly. Target: total file under 400 lines. If no existing helper fits `_apply_camera_state` / `_evaluate_context`, create `u_camera_state_rule_applier.gd`.
- [ ] **Commit 4** (GREEN) — Style enforcement:
  - `tests/unit/style/test_style_enforcement.gd` — assert each of the three largest ECS systems (`s_wall_visibility_system`, `s_vcam_system`, `s_camera_state_system`) has `process_tick` under 80 lines (post-C5 and post-F8).
  - Assert total file size for `s_vcam_system.gd` and `s_camera_state_system.gd` is under 400 lines.
  - **NEW (v7.2.1)**: Assert every `.gd` file under `scripts/ecs/systems/helpers/` is under 400 lines. This codifies the invariant that helpers stay small so future system extraction can't regress them.

**F8 Verification**:
- [ ] All existing vCam and camera-state integration tests green.
- [ ] `s_vcam_system.gd` and `s_camera_state_system.gd` each under ~400 lines total.
- [ ] `process_tick` method under 80 lines in both systems.
- [ ] **NEW (v7.2.1)**: All helper files under `scripts/ecs/systems/helpers/` under 400 lines post-Phase 0.
- [ ] **NEW (v7.2.1)**: `u_vcam_rotation_continuity.gd`, `u_vcam_orbit_centering.gd`, `u_vcam_look_spring.gd`, `u_vcam_look_ahead.gd`, `u_vcam_ground_anchor.gd`, `u_vcam_soft_zone_applier.gd` all exist and are referenced by their consumers.
- [ ] Style enforcement test green.

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
- [ ] **Commit 1** (RED) — Add tests in `test_m_ecs_manager_phasing.gd`:
  - Systems registered in random order still execute in strict phase order.
  - Within the same phase, systems execute by `execution_priority` (existing behavior preserved).
  - A system with `SystemPhase.CAMERA` always runs after `SystemPhase.PHYSICS_SOLVE` regardless of registration or priority values.
- [ ] **Commit 2** (GREEN) — Introduce `SystemPhase` enum on `BaseECSSystem` (e.g., `INPUT`, `PRE_PHYSICS`, `PHYSICS_SOLVE`, `POST_PHYSICS`, `CAMERA`, `VFX`). Add `get_phase() -> SystemPhase` with a default phase. Keep `execution_priority` as within-phase ordering.
- [ ] **Commit 3** (GREEN) — Refactor `M_ECSManager` sort/loop to group by phase first, then sort within phase by `execution_priority`. The manager already owns the loop — this just changes the sort key.
- [ ] **Commit 4** (GREEN) — Assign explicit phases to all current `S_*` systems based on their current `execution_priority` values. Verify ordering didn't change.

**F9 Verification**:
- [ ] Phasing tests green.
- [ ] Existing ECS tests green.
- [ ] All `S_*` systems declare an explicit phase.
- [ ] No ECS system uses `_physics_process` directly (style enforcement grep — verify this is already true).

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
