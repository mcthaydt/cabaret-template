# Time Manager - Tasks Checklist

**Branch**: `TimeManager`
**Status**: Planning complete — ready for implementation
**Methodology**: TDD (Red-Green-Refactor) — tests written within each phase, not deferred
**Reference**: `docs/time_manager/time-manager-plan.md`

---

## Phase 1: Core Refactor — Replace M_PauseManager

**Goal**: Drop-in replacement with identical external behavior. All 10 existing pause tests pass.

- [x] **Commit 1** — Create `u_pause_system.gd` + `test_time_manager.gd` with U_PauseSystem unit tests (TDD: stubs → tests RED → implement GREEN; 10 tests)
- [x] **Commit 2** — Create `i_time_manager.gd` (I_TimeManager interface)
- [ ] **Commit 3** — Create `m_time_manager.gd` + add M_TimeManager pause integration tests (TDD; 4 tests; port all logic from m_pause_manager.gd)
- [ ] **Commit 4** — Wire root.gd + scenes/root.tscn (rename node, dual ServiceLocator registration)
- [ ] **Commit 5** — Migrate 10 test files (mechanical M_PauseManager → M_TimeManager find-replace)
- [ ] **Commit 6** — Delete `m_pause_manager.gd` + `.uid`; run full pause test suite

**Phase 1 verification**:
- [ ] U_PauseSystem unit tests pass (10 tests)
- [ ] M_TimeManager pause integration tests pass (4 tests)
- [ ] All 10 existing pause integration tests pass
- [ ] `is_paused()` / `pause_state_changed` / cursor coordination unchanged
- [ ] `U_ServiceLocator.get_service("pause_manager")` returns M_TimeManager
- [ ] `test_style_enforcement.gd` passes
- [ ] `m_pause_manager.gd` deleted

---

## Phase 2: Timescale Support

**Goal**: Add timescale multiplier; ECS systems receive scaled delta.

- [ ] **Commit 1** — Create `u_timescale_controller.gd` + add U_TimescaleController unit tests to test file (TDD; 6 tests)
- [ ] **Commit 2** — Wire timescale into `m_time_manager.gd` + add timescale integration test (TDD; 1 test; replace stubs, emit `timescale_changed`)
- [ ] **Commit 3** — Update `m_ecs_manager.gd` (_physics_process lazy-lookups time_manager, passes scaled delta)

**Phase 2 verification**:
- [ ] U_TimescaleController unit tests pass (6 tests)
- [ ] M_TimeManager timescale integration test passes (1 test)
- [ ] `get_scaled_delta(1.0)` returns `0.5` when timescale is `0.5`
- [ ] Timescale clamped to `[0.01, 10.0]`
- [ ] `timescale_changed` signal emitted
- [ ] M_ECSManager passes scaled delta to all systems
- [ ] Fallback to raw delta when no time_manager available

---

## Phase 3: World Clock

**Goal**: In-game simulation clock; pauses with gameplay; configurable speed.

- [ ] **Commit 1** — Create `u_world_clock.gd` + add U_WorldClock unit tests to test file (TDD; 12 tests)
- [ ] **Commit 2** — Wire world clock into `m_time_manager.gd` + add world clock integration test (TDD; 1 test; `_physics_process` advance, replace stubs, `world_hour_changed` signal)

**Phase 3 verification**:
- [ ] U_WorldClock unit tests pass (12 tests)
- [ ] M_TimeManager world clock integration test passes (1 test)
- [ ] World clock advances during gameplay
- [ ] World clock stops when any pause channel active
- [ ] Hour/minute callbacks fire at correct transitions
- [ ] `world_hour_changed` signal emitted on hour change
- [ ] `is_daytime()` returns correct values
- [ ] `set_time()` / `set_speed()` work correctly

---

## Phase 4: Redux State & Persistence

**Goal**: `time` slice in Redux; world clock persists across saves; transient fields reset on load.

- [ ] **Commit 1** — Create `rs_time_initial_state.gd` + `cfg_time_initial_state.tres`
- [ ] **Commit 2** — Create `u_time_actions.gd` (U_TimeActions with `_static_init()` registration)
- [ ] **Commit 3** — Create `u_time_reducer.gd` (U_TimeReducer with `_with_values()` helper)
- [ ] **Commit 4** — Create `u_time_selectors.gd` (U_TimeSelectors static getters)
- [ ] **Commit 5** — Register `time` slice in `m_state_store.gd` + `u_state_slice_manager.gd` (14th param); wire `scenes/root.tscn`
- [ ] **Commit 6** — Wire store dispatches/hydration into `m_time_manager.gd` (`update_pause_state`, `update_timescale`, `update_world_time`, `gameplay.paused` mirror, startup/load reconciliation from `time` slice)

**Phase 4 verification**:
- [ ] `time` slice registered in M_StateStore
- [ ] Transient fields (`is_paused`, `active_channels`, `timescale`) reset on save/load
- [ ] Persisted fields (`world_hour`, `world_minute`, `world_total_minutes`, `world_day_count`, `world_time_speed`) survive save/load
- [ ] M_TimeManager rehydrates runtime timescale/world clock from `time` slice on startup and save/load
- [ ] `gameplay.paused` mirror syncs on every pause transition
- [ ] `is_daytime` recomputed by reducer from world_hour

---

## Phase 5: Documentation

**Goal**: AGENTS.md updated with Time Manager patterns.

- [ ] **Commit 1** — Update `AGENTS.md` (add Time Manager Patterns section; update ServiceLocator service list)

**Phase 5 verification**:
- [ ] All 34 new tests pass (verified across Phases 1–4)
- [ ] All existing integration tests pass
- [ ] AGENTS.md updated with Time Manager Patterns section
- [ ] ServiceLocator service list includes `"time_manager"`

---

## Final Completion Check

- [ ] All phases above marked complete
- [ ] Branch merged to main
- [ ] Continuation prompt updated to "Complete"
