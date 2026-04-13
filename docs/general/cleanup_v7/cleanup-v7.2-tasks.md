# Cross-System Cleanup V7.2 — Follow-up Tasks Checklist

**Branch**: GOAP-AI
**Status**: Not started (queued after cleanup-v7 C12 post-processing milestone)
**Methodology**: TDD (Red-Green-Refactor) — tests written within each milestone, not deferred
**Scope**: Targeted follow-ups to cleanup-v7 (`cleanup-v7-tasks.md`) addressing gaps surfaced during a deep-dive architectural review. Mostly backwards-compatible. Behavioral changes are gated to specific commits and called out explicitly (F4 strict validator default flip, F5 grep-test enforcement). All existing integration tests must stay green throughout.

**Relationship to cleanup-v7**: This doc is a **follow-up** to `cleanup-v7-tasks.md`, not a replacement. F1 supplements C6 (SceneManager decomposition) without editing C6. F8 extends C5's wall-visibility decomposition pattern to the other two large ECS systems. The other milestones are independent of v7 scope. Scheduling decision: start this v7.2 plan after C12 (`post-process-refactor-tasks.md`) is complete and regression-tested.

---

## Purpose

The cleanup-v7 plan (C1–C12) does a thorough job of DRY, modularity, scalability, and designer-friendliness across managers and ECS systems. A subsequent architectural review surfaced eight concrete weaknesses that C1–C12 does **not** address:

1. **A cross-manager reflection hole that actively bypasses an existing interface method** (`m_scene_manager.gd:683` reads `_camera_manager.get("_camera_blend_tween")` when `I_CameraManager.is_blend_active()` already exists at `i_camera_manager.gd:30`).
2. **A per-dispatch full-state deep copy floor** in `M_StateStore.dispatch()` that bypasses the store's own versioned cache.
3. **Two parallel mutation paths** that bypass the reducer/history/validator pipeline.
4. **An advisory-only slice-dependency validator** that fails open, letting declarations drift silently.
5. **An unresolved communication-channel taxonomy** (Redux vs `U_ECSEventBus` vs Godot signals) that drives most of the "contract-by-comment" growth in `AGENTS.md`.
6. **Process-global `U_ServiceLocator` state** with last-write-wins `register()` and no per-test scope, causing recurring test pollution patterns documented in the auto-memory.
7. **Type erasure on `RS_Rule.conditions`/`effects: Array[Resource]`** — authoring errors surface as "rule scored 0.0" with no stack trace.
8. **Two more ~550-line ECS systems** (`s_vcam_system.gd`, `s_camera_state_system.gd`) that C5 does not target.

The doc closes with a non-numbered reflection on `AGENTS.md` sprawl and a proposed restructuring direction.

---

## Sequencing

- Run this plan after C12 (`post-process-refactor-tasks.md`) completes and passes regression; do not start v7.2 in parallel with C12.
- `F1` is independent — can run in parallel with or after cleanup-v7 `C6`.
- `F2`, `F3`, `F4` all touch `m_state_store.gd`; run sequentially (F2 → F3 → F4) to avoid merge contention.
- `F5` depends on `F3` having cleaned up the parallel mutation paths first (the channel taxonomy is cleaner to enforce once state mutation is single-sourced).
- `F6` is independent.
- `F7` is independent — blocked only on a one-commit parser feasibility investigation.
- `F8` is independent — follows `C5`'s decomposition pattern once `C5` lands.
- `F9` is independent — refactors the core ECS system lifecycle loop.
- `F10` is independent — small addition to `m_state_store.gd` action tracking.
- `F11` is independent — targets event bus memory hygiene.

---

## Milestone F1: SceneManager C6 Supplement — Camera Blend Interface + Closure State Object

**Goal**: Close the two gaps in cleanup-v7 `C6` (Scene Manager Overlay Extraction) that are not currently on the checklist:

1. **Replace the cross-manager private-member reflection** at `m_scene_manager.gd:683` (`_camera_manager.get("_camera_blend_tween")`) with the existing `I_CameraManager.is_blend_active()` interface method. The reflection hole is actively bypassing an API that already exists.
2. **Replace the three `Array`-wrapper mutable-capture workarounds** in `_perform_transition` (`:553, :558, :571`) with a proper typed transition-state object. These exist because GDScript lambdas can't capture mutable locals; every transition bug becomes a two-step debug.

**Reused existing APIs**:
- `I_CameraManager.is_blend_active()` at `scripts/interfaces/i_camera_manager.gd:30` — already declared, the reflection path is ignoring it.
- `I_CameraManager.apply_main_camera_transform(Transform3D)` at `:24`, `finalize_blend_to_scene(Node)` at `:52`.

**Scope**:
- `scripts/managers/m_scene_manager.gd` — `_perform_transition` (`:538-691`), specifically `:681-687` (reflection) and `:553, :558, :571` (Array wrappers).
- `scripts/managers/m_camera_manager.gd` — verify `is_blend_active()` returns live-tween state equivalent to the current reflection check.
- New: `scripts/scene_management/helpers/u_transition_state.gd` — small `RefCounted` value object with typed fields: `progress: float`, `scene_swap_complete: bool`, `new_scene_ref: Node`, `old_camera_state: Variant`, `should_blend: bool`.

**Commits**:
- [ ] **Commit 1** (RED) — Regression tests:
  - `tests/unit/managers/test_m_scene_manager_blend_handoff.gd` — test that `_perform_transition` queries `I_CameraManager.is_blend_active()` and does not call `get("_camera_blend_tween")` on the camera manager.
  - `tests/unit/scene_management/helpers/test_u_transition_state.gd` — test typed field lifecycle (defaults, mutation, reset).
  - `tests/unit/style/test_style_enforcement.gd` — add grep assertion: `m_scene_manager.gd` contains zero matches of `_camera_blend_tween` or `Array = \[` mutable-capture patterns.
- [ ] **Commit 2** (GREEN) — Introduce `U_TransitionState` and thread it through `_perform_transition`. Replace the three `Array`-wrapper captures with typed fields on the state object. Closures read/write the state object via reference. No behavior change.
- [ ] **Commit 3** (GREEN) — Replace the reflection check at `m_scene_manager.gd:681-684`:
  ```gdscript
  # Before
  var active_tween: Tween = _camera_manager.get("_camera_blend_tween")
  has_active_blend = active_tween != null and active_tween.is_running()

  # After
  has_active_blend = _camera_manager.is_blend_active()
  ```
  Verify `M_CameraManager.is_blend_active()` implementation exercises the same live-tween semantics the reflection path was checking.
- [ ] **Commit 4** (GREEN) — Enable the style-enforcement grep assertion from Commit 1 in CI.

**F1 Verification**:
- [ ] All new tests green.
- [ ] Existing scene-transition integration tests green.
- [ ] Grep `_camera_blend_tween` across `scripts/managers/m_scene_manager.gd` returns zero matches.
- [ ] Grep `Array = \[` in `_perform_transition` returns zero matches.
- [ ] `test_style_enforcement.gd` passes.

**Dependency note**: Safe to run in parallel with `C6`. If `C6` has already merged, F1 applies on top of the decomposed `_perform_transition`. If F1 lands first, `C6` Commit 4 decomposition simply preserves the typed state object.

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
- [ ] **Commit 1** (RED) — Dispatch-path tests:
  - `tests/unit/state/test_m_state_store_dispatch_sharing.gd`:
    - Test 1: With N (=5) subscribers, only one `duplicate(true)` occurs per dispatch. Mechanism: wrap `_state` in a probe that counts `duplicate` calls, or observe that all subscribers receive the same Dictionary reference by mutating a field on one and asserting the others see it (subscribers treat state as read-only per the existing `:468` comment, so the test exploits that contract intentionally).
    - Test 2: With zero subscribers, no snapshot build occurs at all.
    - Test 3: Benchmark — dispatch 1000 no-op actions with 5 subscribers and assert total deep-copy count is <= 1000 (one per dispatch), not 5000 (one per subscriber per dispatch).
- [ ] **Commit 2** (GREEN) — Refactor `dispatch()`:
  - Bump `_state_version` once after reducer application.
  - Invalidate `_cached_state_snapshot` so the next `get_state()` rebuilds.
  - Obtain a single snapshot via the existing cached `get_state()` path.
  - Pass the same snapshot reference to every subscriber.
  - Document the subscriber contract (already implicit at `:468`): "subscribers treat state as read-only."
- [ ] **Commit 3** (GREEN) — Skip the snapshot build entirely when `_subscribers.is_empty()`. This removes the one remaining copy when nobody is listening.

**F2 Verification**:
- [ ] All new tests green.
- [ ] Dispatch benchmark shows one `duplicate(true)` per dispatch with subscribers, zero without.
- [ ] Existing store/reducer tests green.
- [ ] No observable behavior change for subscribers (snapshot contents identical).

---

## Milestone F3: StateStore — Eliminate Parallel Mutation Paths

**Goal**: All mutations to `_state` must flow through `dispatch()` so that action history, version bumping, validator, and signal batching stay consistent. Two bypass paths currently exist:

1. **`_sync_navigation_initial_scene`** directly mutates `_state["navigation"]` (~`:131-147`). Already listed as a cleanup-v7 cross-cutting bullet (line 345 of `cleanup-v7-tasks.md`) but not scheduled.
2. **Direct `slice_updated.emit(slice_name, _state[slice_name])`** at `m_state_store.gd:684` emits slice updates from the reducer apply path without going through `action_dispatched`, the history buffer, or the cached-snapshot invalidation. Additional emission sites at `:259, :486, :636`.

The divergence is subtle: a subscriber listening on `slice_updated` will see state that `action_history_buffer` does not record.

**Scope**:
- `scripts/state/m_state_store.gd`:
  - `_sync_navigation_initial_scene` (~`:131-147`).
  - `slice_updated.emit` sites at `:259, :486, :636, :684`.
- `scripts/state/actions/u_navigation_actions.gd` — add `sync_initial_scene(scene_id: StringName)` action.
- `scripts/state/reducers/u_navigation_reducer.gd` — handle the new action type.

**Commits**:
- [ ] **Commit 1** (RED) — Invariant tests:
  - `tests/unit/state/test_m_state_store_single_mutation_path.gd`:
    - Test that `_sync_navigation_initial_scene` produces an `action_dispatched` signal with the new action type.
    - Test that every `slice_updated` emission is paired with an `action_dispatched` in the same frame (subscribe to both, record per-frame tuples, assert 1:1 pairing).
    - Test that `action_history_buffer` records the same count of actions that `slice_updated` observers see slices for.
- [ ] **Commit 2** (GREEN) — Convert `_sync_navigation_initial_scene`:
  - Add `U_NavigationActions.sync_initial_scene(scene_id)`.
  - Add the reducer branch in `u_navigation_reducer.gd`.
  - Replace the direct `_state["navigation"][...] = ...` mutations with `dispatch(U_NavigationActions.sync_initial_scene(...))`.
- [ ] **Commit 3** (GREEN) — Audit `slice_updated.emit` sites (`:259, :486, :636, :684`). Each site must be:
  - Reached only from `_flush_signal_batcher` / the batched dispatch path, **or**
  - Replaced with a dispatch that goes through the reducer chain, **or**
  - Annotated with an explicit invariant comment citing why the direct emission is safe (e.g., "batched flush — version already bumped by caller").
- [ ] **Commit 4** (GREEN) — Add a grep-based style test forbidding `_state[` mutations outside `m_state_store.gd` utility paths and reducers.

**F3 Verification**:
- [ ] No `slice_updated` emission without a paired `action_dispatched` in the same frame.
- [ ] `_sync_navigation_initial_scene` no longer directly mutates `_state`.
- [ ] `action_history_buffer` count matches `slice_updated` observer count.
- [ ] Grep test green.
- [ ] Existing store tests green.

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
- New: `docs/adr/0001-channel-taxonomy.md` — the decision record (formatted as an ADR: Context / Decision / Consequences).
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
2. **No test scoping** — tests must manually `clear()` in `before_each`. This is the root cause of several recurring test-failure patterns in `MEMORY.md`:
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

Tests wrap `before_each` / `after_each` with scope push/pop; production is unchanged (scope stack is empty, default behavior preserved).

**Scope**:
- `scripts/core/u_service_locator.gd`.
- All test `before_each` blocks that currently call `U_ServiceLocator.clear()` (grep across `tests/unit/**`).
- `scripts/root.gd` — audit `_register_if_exists` call sites at `:50-78` to confirm no production path intentionally replaces (it should be idempotent).

**Commits**:
- [ ] **Commit 1** (RED):
  - `tests/unit/core/test_u_service_locator_conflict.gd` — test that `register()` twice with different instances pushes an error and keeps the first registration; `register_or_replace()` succeeds.
  - `tests/unit/core/test_u_service_locator_scope.gd` — test that `push_scope()` → register → `pop_scope()` reveals previously registered services unchanged.
- [ ] **Commit 2** (GREEN) — Implement fail-on-conflict `register()` and `register_or_replace()`. Audit `root.gd:50-78` — confirm it's idempotent. If any production path legitimately replaces, switch it to `register_or_replace`.
- [ ] **Commit 3** (GREEN) — Implement `push_scope` / `pop_scope`. Migrate the test harness (root `before_each` helpers) to use scopes instead of `clear()`.
- [ ] **Commit 4** (GREEN) — Migrate `U_StateHandoff` and `M_DisplayManager._ensure_appliers()` follow-ups (both listed in `MEMORY.md` as recurring test-failure patterns rooted in module-level state) to the scope pattern where applicable. Lazy-init appliers only when the manager is in-tree.

**F6 Verification**:
- [ ] Duplicate-register test green.
- [ ] Scope-isolation test green.
- [ ] Full test suite green with `clear()` calls removed from `before_each` (scopes replace them).
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

## Milestone F8: `S_VCamSystem` + `S_CameraStateSystem` Decomposition

**Goal**: Extend cleanup-v7 `C5`'s wall-visibility decomposition approach to the other two large ECS systems:
- `s_vcam_system.gd` — **556 lines**
- `s_camera_state_system.gd` — **557 lines**

`C5` only targets `s_wall_visibility_system.gd` (1005 lines), leaving two more ~550-line systems with mixed concerns untouched.

**Scope**:
- `scripts/ecs/systems/s_vcam_system.gd` — `process_tick` mixes per-vCam evaluation, runtime-state reseeding, response smoothing, soft-zone, ground-relative, orbit effects, invalid-target recovery, and blend handoff.
- `scripts/ecs/systems/s_camera_state_system.gd` — mixes rule evaluation, FOV composition, landing-impact application, and state-store writes.

**Reuse existing helpers** (do not create new ones — push more logic into these):
- `scripts/ecs/systems/helpers/u_vcam_runtime_context.gd`
- `scripts/ecs/systems/helpers/u_vcam_runtime_state.gd`
- `scripts/ecs/systems/helpers/u_vcam_effect_pipeline.gd`
- `scripts/ecs/systems/helpers/u_vcam_response_smoother.gd`
- `scripts/ecs/systems/helpers/u_vcam_orbit_effects.gd`
- `scripts/ecs/systems/helpers/u_vcam_landing_impact.gd`
- `scripts/ecs/systems/helpers/u_vcam_rotation.gd`

For `S_CameraStateSystem`, consider extracting `u_camera_state_rule_applier.gd` to own rule-evaluation-into-component-writes if no existing helper fits.

**Commits**:
- [ ] **Commit 1** (RED) — Method-level decomposition tests for both systems:
  - `tests/unit/ecs/systems/test_s_vcam_system_decomposition.gd` — test extracted methods/helpers independently (runtime resolution, blend routing, response smoothing invocation, recovery routing).
  - `tests/unit/ecs/systems/test_s_camera_state_system_decomposition.gd` — test FOV composition, landing-impact application, and rule-result-to-component-write independently.
- [ ] **Commit 2** (GREEN) — Decompose `S_VCamSystem.process_tick` into orchestration + delegated helper calls. Target: `process_tick` under 80 lines. Push per-vCam state management into `u_vcam_runtime_state.gd`, effect application into `u_vcam_effect_pipeline.gd`, and recovery routing into a new small helper if needed.
- [ ] **Commit 3** (GREEN) — Decompose `S_CameraStateSystem.process_tick` similarly. Target: under 80 lines. Extract the FOV composition math and landing-impact writes.
- [ ] **Commit 4** (GREEN) — Style enforcement:
  - `tests/unit/style/test_style_enforcement.gd` — assert each of the three largest ECS systems (`s_wall_visibility_system`, `s_vcam_system`, `s_camera_state_system`) has `process_tick` under 80 lines (post-C5 and post-F8).
  - Assert total file size for `s_vcam_system.gd` and `s_camera_state_system.gd` is under 400 lines.

**F8 Verification**:
- [ ] All existing vCam and camera-state integration tests green.
- [ ] `s_vcam_system.gd` and `s_camera_state_system.gd` each under ~400 lines total.
- [ ] `process_tick` method under 80 lines in both systems.
- [ ] Style enforcement test green.

**Dependency note**: Follows cleanup-v7 `C5` — run F8 after C5 lands so the same decomposition pattern can be applied consistently to all three large systems.

---

## Milestone F9: Explicit ECS System Execution Phasing

**Goal**: Make ECS system execution order deterministic and explicit. Currently, systems run via `_physics_process`, relying on SceneTree order or registration order. This causes 1-frame jitters if, for instance, cameras evaluate before movement solves.

**Scope**:
- `scripts/managers/m_ecs_manager.gd`
- `scripts/ecs/base_ecs_system.gd`
- `scripts/interfaces/i_ecs_manager.gd`
- Update all existing `S_*` system scripts to declare a phase.

**Commits**:
- [ ] **Commit 1** (RED) — Add tests in `test_m_ecs_manager_phasing.gd` asserting systems evaluate in strictly defined phase order regardless of registration sequence.
- [ ] **Commit 2** (GREEN) — Introduce `SystemPhase` enum (e.g., `INPUT`, `PRE_PHYSICS`, `PHYSICS_SOLVE`, `POST_PHYSICS`, `CAMERA`, `VFX`). Modify `BaseECSSystem` to export or return its phase.
- [ ] **Commit 3** (GREEN) — Modify `M_ECSManager` to own the loop: register systems into phase-buckets, and iterate those buckets in order during `_physics_process`. Systems no longer use their own `_physics_process`.
- [ ] **Commit 4** (GREEN) — Assign explicit phases to all current systems.

**F9 Verification**:
- [ ] Phasing tests green.
- [ ] Existing ECS tests green.
- [ ] No ECS system uses `_physics_process` directly (style enforcement grep).

---

## Milestone F10: State Store History Truncation

**Goal**: Prevent infinite memory growth in the state store. `M_StateStore` maintains an `action_history_buffer`. If unchecked, long play sessions will eventually OOM.

**Scope**:
- `scripts/state/m_state_store.gd`
- `scripts/resources/state/rs_state_store_settings.gd`

**Commits**:
- [ ] **Commit 1** (RED) — Add test `test_m_state_store_history_truncation.gd` asserting the buffer does not exceed a configured maximum length.
- [ ] **Commit 2** (GREEN) — Add `max_history_length` to `RS_StateStoreSettings` (e.g., 500). Update `action_history_buffer` append logic to pop the oldest action when capacity is reached.
- [ ] **Commit 3** (GREEN) — Optional: disable history recording entirely if `OS.has_feature("release")` and a `record_history_in_release` flag is false.

**F10 Verification**:
- [ ] Truncation tests green.
- [ ] Buffer length stays <= max configured length during main-menu-to-gameplay loop.

---

## Milestone F11: Event Bus "Zombie" Prevention (WeakRef Subscriptions)

**Goal**: Prevent memory leaks and invalid callable crashes in `U_ECSEventBus`. If entities subscribe but are `queue_free()`'d without unsubscribing, the bus leaks references or crashes on dispatch.

**Scope**:
- `scripts/events/u_ecs_event_bus.gd` (or equivalent location)

**Commits**:
- [ ] **Commit 1** (RED) — Add test `test_u_ecs_event_bus_zombies.gd` where an object subscribes, is `free()`'d or `queue_free()`'d, and an event is published. Assert the bus cleans it up and doesn't crash.
- [ ] **Commit 2** (GREEN) — Refactor `U_ECSEventBus` subscriber storage to use `WeakRef` or safely check `is_instance_valid(callable.get_object())` before invoking.
- [ ] **Commit 3** (GREEN) — Add periodic sweep or publish-time pruning to remove dead callables from the subscriber arrays.
- [ ] **Commit 4** (GREEN) — Revisit the subscriber list allocation issue (`.duplicate()` per call). Implement copy-on-write or deferred execution to avoid allocations.

**F11 Verification**:
- [ ] Zombie cleanup tests green.
- [ ] Existing event bus tests green.

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
