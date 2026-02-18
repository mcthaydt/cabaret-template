# Time Manager - Tasks Checklist

**Branch**: `TimeManager`
**Status**: Complete — all phases finished
**Methodology**: TDD (Red-Green-Refactor) — tests written within each phase, not deferred
**Reference**: `docs/time_manager/time-manager-plan.md`

---

## Phase 1: Core Refactor — Replace M_PauseManager

**Goal**: Drop-in replacement with identical external behavior. All 10 existing pause tests pass.

- [x] **Commit 1** — Create `u_pause_system.gd` + `test_time_manager.gd` with U_PauseSystem unit tests (TDD: stubs → tests RED → implement GREEN; 10 tests)
- [x] **Commit 2** — Create `i_time_manager.gd` (I_TimeManager interface)
- [x] **Commit 3** — Create `m_time_manager.gd` + add M_TimeManager pause integration tests (TDD; 4 tests; port all logic from m_pause_manager.gd)
- [x] **Commit 4** — Wire root.gd + scenes/root.tscn (rename node, dual ServiceLocator registration)
- [x] **Commit 5** — Migrate 10 test files (mechanical M_PauseManager → M_TimeManager find-replace)
- [x] **Commit 6** — Delete `m_pause_manager.gd` + `.uid`; run full pause test suite

**Phase 1 verification**:
- [x] U_PauseSystem unit tests pass (10 tests)
- [x] M_TimeManager pause integration tests pass (4 tests)
- [x] All 10 existing pause integration tests pass
- [x] `is_paused()` / `pause_state_changed` / cursor coordination unchanged
- [x] `U_ServiceLocator.get_service("pause_manager")` returns M_TimeManager
- [x] `test_style_enforcement.gd` passes
- [x] `m_pause_manager.gd` deleted

---

## Phase 2: Timescale Support

**Goal**: Add timescale multiplier; ECS systems receive scaled delta.

- [x] **Commit 1** — Create `u_timescale_controller.gd` + add U_TimescaleController unit tests to test file (TDD; 6 tests)
- [x] **Commit 2** — Wire timescale into `m_time_manager.gd` + add timescale integration test (TDD; 1 test; replace stubs, emit `timescale_changed`)
- [x] **Commit 3** — Update `m_ecs_manager.gd` (_physics_process lazy-lookups time_manager, passes scaled delta)

**Phase 2 verification**:
- [x] U_TimescaleController unit tests pass (6 tests)
- [x] M_TimeManager timescale integration test passes (1 test)
- [x] `get_scaled_delta(1.0)` returns `0.5` when timescale is `0.5`
- [x] Timescale clamped to `[0.01, 10.0]`
- [x] `timescale_changed` signal emitted
- [x] M_ECSManager passes scaled delta to all systems
- [x] Fallback to raw delta when no time_manager available

---

## Phase 3: World Clock

**Goal**: In-game simulation clock; pauses with gameplay; configurable speed.

- [x] **Commit 1** — Create `u_world_clock.gd` + add U_WorldClock unit tests to test file (TDD; 12 tests)
- [x] **Commit 2** — Wire world clock into `m_time_manager.gd` + add world clock integration test (TDD; 1 test; `_physics_process` advance, replace stubs, `world_hour_changed` signal)

**Phase 3 verification**:
- [x] U_WorldClock unit tests pass (12 tests)
- [x] M_TimeManager world clock integration test passes (1 test)
- [x] World clock advances during gameplay
- [x] World clock stops when any pause channel active
- [x] Hour/minute callbacks fire at correct transitions
- [x] `world_hour_changed` signal emitted on hour change
- [x] `is_daytime()` returns correct values
- [x] `set_time()` / `set_speed()` work correctly

---

## Phase 4: Redux State & Persistence

**Goal**: `time` slice in Redux; world clock persists across saves; transient fields reset on load.

- [x] **Commit 1** — Create `rs_time_initial_state.gd` + `cfg_time_initial_state.tres`
- [x] **Commit 2** — Create `u_time_actions.gd` (U_TimeActions with `_static_init()` registration)
- [x] **Commit 3** — Create `u_time_reducer.gd` (U_TimeReducer with `_with_values()` helper)
- [x] **Commit 4** — Create `u_time_selectors.gd` (U_TimeSelectors static getters)
- [x] **Commit 5** — Register `time` slice in `m_state_store.gd` + `u_state_slice_manager.gd` (14th param); wire `scenes/root.tscn`
- [x] **Commit 6** — Wire store dispatches/hydration into `m_time_manager.gd` (`update_pause_state`, `update_timescale`, `update_world_time`, `gameplay.paused` mirror, startup/load reconciliation from `time` slice)

**Phase 4 verification**:
- [x] `time` slice registered in M_StateStore
- [x] Transient fields (`is_paused`, `active_channels`, `timescale`) reset on save/load
- [x] Persisted fields (`world_hour`, `world_minute`, `world_total_minutes`, `world_day_count`, `world_time_speed`) survive save/load
- [x] M_TimeManager rehydrates runtime timescale/world clock from `time` slice on startup and save/load
- [x] `gameplay.paused` mirror syncs on every pause transition
- [x] `is_daytime` recomputed by reducer from world_hour

---

## Phase 5: Documentation

**Goal**: AGENTS.md updated with Time Manager patterns.

- [x] **Commit 1** — Update `AGENTS.md` (add Time Manager Patterns section; update ServiceLocator service list)

**Phase 5 verification**:
- [x] All 34 new tests pass (verified across Phases 1–4)
- [x] All existing integration tests pass
- [x] AGENTS.md updated with Time Manager Patterns section
- [x] ServiceLocator service list includes `"time_manager"`

---

## Final Completion Check

- [x] All phases above marked complete
- [ ] Branch merged to main
- [x] Continuation prompt updated to "Complete"
