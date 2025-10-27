# Redux State Store – Continuation Guide

## 🚨 CRITICAL WORKFLOW REQUIREMENT 🚨

**YOU MUST FOLLOW `redux-state-store-tasks.md` LINE BY LINE**

Before doing ANYTHING else, read this requirement:

1. **ALWAYS open `redux-state-store-tasks.md` FIRST** before starting any work
2. **Find the next unchecked task `[ ]` in sequence** - do NOT skip around
3. **Check off the task `[x]` IMMEDIATELY after completing it** - use the Edit tool
4. **Commit the updated tasks.md** regularly (every 5-10 tasks, or at phase boundaries)
5. **NEVER work on a task that isn't in the tasks.md file**
6. **NEVER skip tasks** - follow them in order unless marked [P] (parallel-safe)
7. **🚨 AFTER COMPLETING EACH PHASE: Update THIS continuation prompt** with new status, commits, and next phase

**Why this matters:**
- The task list is the SINGLE SOURCE OF TRUTH for what needs to be done
- TodoWrite is for session memory only - tasks.md is the permanent record
- Checking off tasks as you go prevents duplicate work and context loss
- Updating this prompt after each phase keeps status synchronized
- This was explicitly requested and previously ignored - DO NOT IGNORE IT AGAIN

**Workflow example:**
```
1. Read redux-state-store-tasks.md
2. Find next unchecked task: [ ] T035 Create test_m_state_store.gd
3. Complete the task: Create the file
4. Edit tasks.md: Change [ ] to [x] for T035
5. Continue to T036, repeat
6. After completing several tasks, commit tasks.md with implementation
7. After completing a phase (e.g., Phase 1a), update THIS FILE:
   - Update "Current Status" section
   - Add completed phase to "Completed Phases" list
   - Update "Active Phase" to next phase
   - Update "Next Steps" section
   - Commit the updated continuation prompt
```

If you are ever unsure what to do next, **read the tasks.md file** and find the next `[ ]` checkbox.

---

## Project Status (2025-10-26)

The Redux-style centralized state store implementation is **PHASES 1-10 COMPLETE**. The feature branch `redux-state-store` has comprehensive planning documentation and User Story 1 (Core Gameplay Slice + Action History + Persistence) fully implemented and tested with 100% test pass rate.

**Current Status**: Phases 1-10 (US1a-US1h) Complete - All core infrastructure implemented, validated, and ready for integration

**Phase 0 Decision**: **Option C - Dual-bus via abstract base** (IMPLEMENTED ✅)

**Completed Phases**:
- ✅ Phase 0C: EventBusBase architecture (commit b7fb729)
- ✅ Phase 1 (Setup): All directories, project settings, base files
- ✅ Phase 3 (US1a): M_StateStore skeleton + U_StateUtils (commit 77e6618)
- ✅ Phase 4 (US1b): ActionRegistry + U_GameplayActions (commit 45cde3c)
- ✅ Phase 5 (US1c): Gameplay reducer with immutable state (commit 8e1e42d)
- ✅ Phase 6 (US1d): Type-safe action creators (commit 8e1e42d)
- ✅ Phase 7 (US1e): Selector system with dependencies (commit 8e1e42d)
- ✅ Phase 8 (US1f): Signal batching for per-frame emission (commit c198ece)
- ✅ Phase 9 (US1g): Action history with circular buffer (commit 7c562ec)
- ✅ Phase 10 (US1h): Persistence + StateHandoff (commit 20ecc64)
- ✅ Test fixes: 100% pass rate achieved (commits 077e66b, 5d12444)
- ✅ Documentation: Testing patterns + coverage (commit ac64f5c)
- ✅ Tasks.md updated with current status (commit 18d7bed)

**Test Coverage**: 
- **149/149 tests passing (100%)**
- 87/87 state store tests (100%)
- 62/62 ECS tests (100%)
- All in-game test scenes passing

**Active Phase**: Phase 10.5 (Proof-of-Concept Integration) - **RECOMMENDED NEXT STEP**

## Before Resuming Implementation

1. **🚨 FIRST: Open `redux-state-store-tasks.md`**:
   - This is your ONLY work queue
   - Find the next `[ ]` checkbox
   - Do NOT proceed without reading the tasks file

2. **Re-read the quick guidance docs**:
   - `AGENTS.md` - Commit strategy, testing requirements, repo map
   - `docs/general/DEV_PITFALLS.md` - GDScript typing, GUT patterns, common pitfalls
   - `docs/general/STYLE_GUIDE.md` - Naming conventions, file structure, code standards

3. **Review state store planning material**:
   - `docs/state store/redux-state-store-prd.md` (v2.0) - Feature specification and requirements
   - `docs/state store/redux-state-store-implementation-plan.md` (v2.0) - Detailed implementation guide with architectural decisions
   - `docs/state store/redux-state-store-tasks.md` (v2.0) - Granular task breakdown by phase

3. **Understand the architecture**:
   - In-scene `M_StateStore` node (parallel to `M_ECSManager`)
   - **Dual-bus architecture**: `EventBusBase` (abstract) → `ECSEventBus` + `StateStoreEventBus` (concrete)
   - Three state slices: boot, menu, gameplay
   - Redux-style dispatch/reducer pattern with immutable updates
   - Signal batching (immediate state updates, per-frame signal emissions)
   - Save/load with JSON serialization and Godot type conversion
   - StateHandoff utility for scene transitions (no autoloads)

## Quick Start Checklist

Before starting implementation:

- [x] Confirm you're on the `redux-state-store` branch
- [x] **Phase 0 decision made: Option C (Dual-bus via abstract base)**
- [x] Read the Prerequisites section in the implementation plan
- [x] Review the Architectural Decisions (MANDATORY READING)
- [x] Understand the MVP strategy
- [x] **🚨 CRITICAL: Understand that redux-state-store-tasks.md is the SINGLE SOURCE OF TRUTH**
- [x] **🚨 CRITICAL: Must check off tasks [ ] → [x] as they are completed**
- [x] **🚨 CRITICAL: Must commit task file updates regularly**

## Phases 1-10 Accomplishments

### ✅ Completed Implementation (Phases 0-10, US1a-US1h)

**Core Infrastructure:**
- M_StateStore node with dispatch/subscribe pattern
- ActionRegistry with StringName validation and static registration
- StateSliceConfig with dependency declarations and transient fields
- SignalBatcher for per-frame emission
- U_StateUtils for global store access (get_store, benchmark)
- RS_StateStoreSettings resource with project settings integration
- Circular dependency detection with DFS

**Gameplay Slice:**
- RS_GameplayInitialState resource (paused, health, score, level)
- GameplayReducer with immutable .duplicate(true) updates
- U_GameplayActions with 5 action creators (pause, unpause, update_health, update_score, set_level)
- GameplaySelectors for derived state (get_is_player_alive, get_is_game_over, get_completion_percentage)

**Action History (Phase 9):**
- Circular buffer with configurable size (default 1000 entries)
- Timestamp tracking using U_ECSUtils.get_current_time()
- get_action_history() and get_last_n_actions(n) methods
- Project settings integration: state/debug/enable_history, state/debug/history_size
- History format: {action, timestamp, state_after}

**Persistence & StateHandoff (Phase 10):**
- SerializationHelper: Godot type conversion (Vector2/3/4, Color, Quaternion, Transform2D/3D, Rect2, AABB, Plane, Basis)
- save_state(filepath) and load_state(filepath) methods
- Transient field support (excluded from save/load)
- StateHandoff static utility for scene transition state preservation (no autoload)
- Automatic state preservation in _exit_tree() and restoration in _ready()

**Runtime Dependency Validation:**
- validate_slice_dependencies() method
- Optional caller_slice parameter in get_slice()
- Logs errors for undeclared dependencies
- Allows self-access without declaring dependency

**Test Coverage:**
- **149/149 unit tests passing (100%)**
- 87/87 state store tests (100%)
- 62/62 ECS tests (100%)
- 8 in-game test scenes passing:
  - state_test_us1a.tscn - Core skeleton
  - state_test_us1b.tscn - Action validation
  - state_test_us1c.tscn - Reducer immutability
  - state_test_us1d.tscn - Action creators
  - state_test_us1e.tscn - Selectors
  - state_test_us1f.tscn - Signal batching
  - state_test_us1g.tscn - Action history
  - state_test_us1h.tscn - Persistence & StateHandoff

**Documentation:**
- Lambda closure limitation added to DEV_PITFALLS.md
- GUT testing patterns documented (assert_push_error, warning handling, static state cleanup)
- Test coverage status: 149/149 passing (100%)
- Tasks.md updated with current status and proof-of-concept phase

**Key Architectural Decisions:**
- State updates: Immediate (synchronous)
- Signal emissions: Batched (per physics frame)
- No autoloads: M_StateStore is in-scene node, StateHandoff is static class
- Event bus: Dual-bus (ECSEventBus + StateStoreEventBus via EventBusBase)
- Immutability: .duplicate(true) in all reducers
- Persistence: JSON with comprehensive Godot type serialization

## Implementation Path

### Phase 0: Event Bus Architecture (Option C - ✅ COMPLETED)

**Status**: Implemented in commit b7fb729

**Completed**:
1. ✅ Created directory `scripts/events/`
2. ✅ Created `scripts/events/event_bus_base.gd` (abstract base with shared logic)
3. ✅ Created `scripts/state/state_event_bus.gd` (state domain bus extending base)
4. ✅ Updated `scripts/ecs/ecs_event_bus.gd` to extend base (preserves existing API)
5. ✅ Added tests for state bus isolation and reset behavior (7/7 passing)
6. ✅ Committed Phase 0C

**Key Benefits Achieved**:
- Zero breaking changes to existing ECS code (62/62 ECS tests still pass)
- Isolated domains (ECS vs State) with separate subscribers/histories
- Shared implementation in `EventBusBase` with lazy initialization
- Clean test isolation: `StateStoreEventBus.reset()` vs `ECSEventBus.reset()`

### Completed Phases: User Story 1 (Core Gameplay Slice) - 10 Phases

All phases complete with 100% test pass rate:

1. **Phase 0C**: EventBusBase architecture ✅ COMPLETED (commit b7fb729)
2. **Phase 3 (US1a)**: Core M_StateStore Skeleton with U_StateUtils ✅ COMPLETED (commit 77e6618)
3. **Phase 4 (US1b)**: Action Registry with StringName Validation ✅ COMPLETED (commit 45cde3c)
4. **Phase 5 (US1c)**: Gameplay Slice Reducer Infrastructure ✅ COMPLETED (commit 8e1e42d)
5. **Phase 6 (US1d)**: Type-Safe Action Creators ✅ COMPLETED (commit 8e1e42d)
6. **Phase 7 (US1e)**: Selector System with Cross-Slice Dependencies ✅ COMPLETED (commit 8e1e42d)
7. **Phase 8 (US1f)**: Signal Emission with Per-Frame Batching ✅ COMPLETED (commit c198ece)
8. **Phase 9 (US1g)**: Action Logging with 1000-Entry History ✅ COMPLETED (commit 7c562ec)
9. **Phase 10 (US1h)**: Persistence with Transient Field Marking and StateHandoff ✅ COMPLETED (commit 20ecc64)
10. **Test Fixes**: 100% pass rate achieved ✅ COMPLETED (commits 077e66b, 5d12444)
11. **Documentation**: Testing patterns and coverage ✅ COMPLETED (commit ac64f5c)

All phases followed TDD: Write tests → Verify tests fail → Implement → Verify tests pass → In-game validation → Commit

### Next Phase: Proof-of-Concept Integration (Phase 10.5)

**Goal**: Validate state store architecture with minimal real gameplay systems

**Approach**: Small, focused integration with pause, health, and score systems + simple HUD

See "Next Steps" section above for detailed guidance.

## Key Architectural Points

**Event Bus Architecture (Option C)**:
- `EventBusBase` (abstract) contains shared subscribe/unsubscribe/publish/reset/history logic
- `ECSEventBus` extends base, delegates static API to private instance, preserves existing API
- `StateStoreEventBus` extends base, exposes static API for state domain
- Completely isolated: ECS and State have separate subscribers and histories

**CRITICAL - No Autoloads**:
- M_StateStore is an **in-scene node**, not an autoload
- Use `U_StateUtils.get_store(node)` to access store from any node
- StateHandoff is a **static class**, not an autoload
- Event buses are **static classes**, not autoloads

**Event Bus Reset Pattern**:
- State tests MUST include `StateStoreEventBus.reset()` in `before_each()`
- ECS tests use `ECSEventBus.reset()` in `before_each()`
- This prevents subscription leaks between tests

**Scene Integration**:
- M_StateStore lives in `templates/base_scene_template.tscn` under `Managers/` node
- Resources (.tres files) go in `resources/state/` (NOT `scripts/state/resources/`)

## Next Steps

**PHASES 1-10 COMPLETE** - All core state store infrastructure implemented and tested with 100% pass rate!

**CURRENT SITUATION**:
- ✅ State store fully functional: dispatch, reducers, selectors, history, persistence
- ✅ All tests passing (149/149 - 100%)
- ❌ **NOT INTEGRATED WITH GAME** - State store exists but isn't used by any gameplay systems
- ❌ No health/score/pause systems using state store
- ❌ No UI reading from state

**RECOMMENDED NEXT PHASE**: Phase 10.5 (Proof-of-Concept Integration) ⭐

**Why Proof-of-Concept First?**
- Phases 1-10 built infrastructure without real-world usage
- Integration validates architecture works with actual ECS systems
- Discover issues NOW rather than after building Phase 11+ (Debug Overlay, Boot/Menu)
- Provides concrete integration patterns for future developers
- Small scope: 2-3 simple systems, ~1-2 hours of work

**What Phase 10.5 Includes** (47 tasks: T298-T344):

1. **Pause System**: ESC key toggles pause via state store, movement/jump check pause state
2. **Health System**: Damage over time (every 5 seconds, -10 HP), death signal at 0 health
3. **Score System**: +10 points per jump, tracked via state store
4. **Simple HUD**: Displays health, score, pause status from GameplaySelectors
5. **Integration Tests**: Verify ECS + State interop with proper bus reset patterns

**How to Start**:

1. **Open `redux-state-store-tasks.md`**
2. **Find Phase 10.5 section** (starts around line 708)
3. **Find task T298** (first test task in Phase 10.5)
4. **Follow TDD approach**: Write tests first, verify they fail, implement, verify pass
5. **Check off tasks `[x]` immediately after completing**
6. **Commit tasks.md + implementation** after completing phase

**Estimated time for Phase 10.5**: 1-2 hours (small, focused integration)

**After Proof-of-Concept**:
- **If successful**: Choose between Phase 11+ (Debug Overlay, Boot/Menu) OR expand gameplay features
- **If issues found**: Fix architectural problems before building more infrastructure
- **If pattern works**: Document integration approach in usage guide

**Alternative Paths** (NOT RECOMMENDED until after PoC):
- Phase 11 (US2): Debug Overlay with F3 toggle
- Phases 12-14 (US3-US5): Boot/Menu slices and state transitions
- Phase 15: Polish, optimization, documentation

## Reference Documents

- **Planning**: `redux-state-store-prd.md`, `redux-state-store-implementation-plan.md`
- **Tasks**: `redux-state-store-tasks.md` (see Phase 0 section, T026C-T031C)
- **Code Standards**: `AGENTS.md`, `docs/general/DEV_PITFALLS.md`, `docs/general/STYLE_GUIDE.md`

## Test Commands

```bash
# Run state store tests (after Phase 1a+)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/state -gexit

# Run ECS tests (verify no regressions after Phase 0)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ecs -gexit

# Run all tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```

## Phase 0 Implementation Notes

Per the implementation plan, Phase 0C should:

1. Create `EventBusBase` with:
   - Private instance management for subscribers/history
   - `subscribe()`, `unsubscribe()`, `publish()`, `reset()`, `get_history()`
   - Defensive payload `.duplicate(true)` for safety

2. `StateStoreEventBus` should:
   - Extend `EventBusBase`
   - Expose static API delegating to private instance
   - Used exclusively by state store and state tests

3. `ECSEventBus` should:
   - Extend `EventBusBase`
   - Preserve existing public API (no breaking changes)
   - Delegate internally to base implementation

Happy coding!
