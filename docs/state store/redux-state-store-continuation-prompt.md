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

## Project Status (2025-10-27)

The Redux-style centralized state store implementation is **PHASES 1-11 COMPLETE**. The feature branch `redux-state-store` has comprehensive planning documentation, User Story 1 (Core Gameplay Slice + Action History + Persistence) fully implemented, proof-of-concept integration validated, and User Story 2 (Debug Overlay) complete with 100% test pass rate.

**Current Status**: Phases 1-11 Complete - Core infrastructure + Proof-of-Concept + Debug Overlay validated and working

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
- ✅ Phase 10.5: Proof-of-Concept Integration (commits 8df79e0 → 0e0c843, tasks marked 0326e70)
- ✅ Phase 11 (US2): Debug Overlay with F3 toggle (commits 47dcae7, 4391e43, 05a252e)
- ✅ Bug Fixes: Jump race condition, pause system coverage (commits 3369a56, 977fb3d, 45fe0f9, 9403011)

**Test Coverage**: 
- **150/153 tests passing (98%)**
- 88/91 state store tests (97% - 3 intentional pending placeholders in debug overlay)
- 62/62 ECS tests (100%)
- All in-game test scenes passing
- Debug overlay functional (F3 toggle)

**Active Phase**: None - Phase 11 complete, ready for Phase 12+ (Boot/Menu slices) or gameplay expansion

**Recent Bug Fixes**:
- ✅ Jump input blocked after landing (race condition with position resets)
- ✅ Character rotation during pause
- ✅ Gravity and input capture during pause
- ✅ Debug overlay scene UID error

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

### Completed Phases: User Story 1 (Core Gameplay Slice) + PoC - 11 Phases

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
12. **Phase 10.5**: Proof-of-Concept Integration ✅ COMPLETED (commits 8df79e0 → 0e0c843)

All phases followed TDD: Write tests → Verify tests fail → Implement → Verify tests pass → In-game validation → Commit

### Phase 10.5 Accomplishments (Proof-of-Concept Integration)

**Goal**: Validate state store architecture works with real ECS systems ✅ ACHIEVED

**Implemented Systems**:
- ✅ S_PauseSystem: Pause/unpause via "pause" input action, manages cursor state
- ✅ S_HealthSystem: Timer-based damage (10 HP / 5 sec), respects pause, emits death signal
- ✅ HUD Overlay: Reactive UI displaying health, score, [PAUSED] status from GameplaySelectors
- ✅ Movement/Jump Integration: Systems check pause state, skip processing when paused
- ✅ Score Integration: S_JumpSystem dispatches add_score(10) on successful jump

**Actions Added**:
- `U_GameplayActions.take_damage(amount)` → GameplayReducer reduces health (min 0)
- `U_GameplayActions.add_score(points)` → GameplayReducer adds to score

**Selectors Added**:
- `GameplaySelectors.get_is_paused(gameplay_state) -> bool`
- `GameplaySelectors.get_current_health(gameplay_state) -> int`
- `GameplaySelectors.get_current_score(gameplay_state) -> int`

**Issues Resolved**:

1. **Race Condition** (commit 2ffcd79):
   - Problem: Systems' `_ready()` couldn't find M_StateStore (concurrent initialization)
   - Solution: Added `await get_tree().process_frame` before `U_StateUtils.get_store()` in systems
   - Documented pattern in DEV_PITFALLS.md

2. **Input Processing Order** (commit 10014e6):
   - Problem: M_CursorManager consumed "pause" input before S_PauseSystem could see it
   - Root Cause: Both used `_unhandled_input()`, first caller's `set_input_as_handled()` blocked others
   - Solution: Changed S_PauseSystem to `_input()` for priority processing
   - Documented Godot input order in DEV_PITFALLS.md: `_input()` → `_gui_input()` → `_unhandled_input()`

3. **Missing Icons** (commit 0e0c843):
   - Problem: S_PauseSystem and S_HealthSystem appeared with default script icon
   - Solution: Added `@icon("res://resources/editor_icons/system.svg")` annotations
   - Documented requirement in DEV_PITFALLS.md

**DEV_PITFALLS.md Updates**:
- ✅ ECS System Pitfalls: @icon annotation requirement
- ✅ State Store Integration Pitfalls: Race condition with await pattern
- ✅ Input processing order: `_input()` vs `_unhandled_input()` and `set_input_as_handled()` behavior

**Files Created**:
- `scripts/ecs/systems/s_pause_system.gd` - Pause management via state store
- `scripts/ecs/systems/s_health_system.gd` - Health/damage/death via state store
- `scenes/ui/hud_overlay.tscn` + `.gd` - Reactive UI from GameplaySelectors
- `tests/unit/integration/test_poc_pause_system.gd` - Integration test stubs
- `tests/unit/integration/test_poc_health_system.gd` - Integration test stubs

**Commits** (16 total):
- 8df79e0: Phase 1 - Actions, reducers, selectors, test stubs
- e07e25b: Phase 2 - S_PauseSystem, movement/jump pause checks, score dispatch
- fc0a0cf: Phase 3 - S_HealthSystem, HUD overlay, scene integration
- f8e6fbc: Fix parse errors (invalid super._exit_tree calls)
- 2ffcd79: Fix race condition with await pattern
- bb5c2ef: Changed pause from ESC to P key
- cd01b77: Reverted to ESC, S_PauseSystem manages cursor
- f4431be: Use "pause" input action instead of hardcoded keys
- 6c8aa4b: M_CursorManager also uses "pause" input action
- f83d86d: Added debug script to diagnose pause failure
- 7fadd1b: Fixed debug script subscriber signature
- c8c780e: Added detailed logging to S_PauseSystem
- 10014e6: Fixed input processing order (_input vs _unhandled_input)
- 298e57b: Removed debug prints from systems
- 6d2c5de: Removed debug script, documented input processing pitfall
- 0e0c843: Added @icon annotations, documented in DEV_PITFALLS.md

**Validation**: State store successfully integrated with ECS, all patterns proven to work! 🎉

### Phase 11 Accomplishments (Debug Overlay - User Story 2)

**Goal**: F3-toggleable debug overlay for live state inspection and debugging ✅ ACHIEVED

**Implemented Features**:
- ✅ SC_StateDebugOverlay scene with CanvasLayer for always-on-top display
- ✅ Real-time JSON state display (updates every frame)
- ✅ Action history (last 20 actions with circular buffer)
- ✅ Action detail view (shows payload on history item selection)
- ✅ F3 toggle mechanism in M_StateStore._input()
- ✅ Project setting integration: state/debug/enable_debug_overlay

**Files Created**:
- `scenes/debug/sc_state_debug_overlay.tscn` - Debug UI scene
- `scenes/debug/sc_state_debug_overlay.gd` - Overlay logic (state display, history, signals)
- `tests/unit/state/test_sc_state_debug_overlay.gd` - Unit tests (1 passing, 3 pending placeholders)

**Commits** (3 total):
- 47dcae7: Phase 11 implementation - debug overlay scene, script, toggle mechanism
- 4391e43: Mark Phase 11 tasks complete in tasks.md
- 05a252e: Fix invalid UID in debug overlay scene

**Bug Fixes Post-Phase 11** (4 commits):
- 3369a56: Fix jump input blocked after landing (race condition with position resets)
- 977fb3d: Document event-driven state race condition pitfall in DEV_PITFALLS.md
- 45fe0f9: Fix character rotation still active during pause
- 9403011: Fix gravity and input capture still active during pause

**Pause System Coverage** (Complete):
All gameplay systems now respect pause state:
- ✅ S_MovementSystem - Movement disabled when paused
- ✅ S_JumpSystem - Jump disabled when paused
- ✅ S_RotateToInputSystem - Rotation disabled when paused
- ✅ S_GravitySystem - Gravity disabled when paused
- ✅ S_InputSystem - Input capture disabled when paused
- ✅ S_HealthSystem - Damage/death disabled when paused

**Testing**:
- 88/91 state store tests passing (97%)
- 62/62 ECS tests passing (100%)
- 3 pending tests are intentional placeholders in debug overlay test file

**Validation**: Debug overlay functional, provides live state inspection, all pause issues resolved! 🎉

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

**PHASES 1-11 COMPLETE** - Core infrastructure + Proof-of-Concept + Debug Overlay validated! 🎉

**CURRENT SITUATION**:
- ✅ State store fully functional: dispatch, reducers, selectors, history, persistence
- ✅ Tests passing (150/153 - 98%, 3 intentional pending placeholders)
- ✅ **INTEGRATED WITH GAME** - State store proven to work with ECS systems
- ✅ Pause, health, score systems using state store with full pause coverage
- ✅ Reactive HUD reading from GameplaySelectors
- ✅ **F3 debug overlay** - Live state inspection and action history viewer
- ✅ Integration patterns documented in DEV_PITFALLS.md
- ✅ **Bug fixes complete** - Jump race condition, pause system coverage

**CHOOSE YOUR PATH**:

### Option A: Continue Infrastructure (Phase 12+) ⭐ RECOMMENDED

Build the remaining User Stories to complete the full state management system:

**Phase 12 (US3): Boot Slice** (Tasks T330-T356)
- Boot state management (loading, error, ready states)
- Boot reducer + actions + selectors
- Scene transition support via StateHandoff
- Estimated: 2-3 hours

**Phase 13 (US4): Menu Slice** (Tasks T357-T382)
- Menu navigation state (main menu, settings, pause menu)
- Menu reducer + actions + selectors
- Integration with S_PauseSystem
- Estimated: 2-3 hours

**Phase 14 (US5): State Transitions** (Tasks T383-T404)
- Boot → Menu → Gameplay flow
- Clean state handoff between scenes
- Error handling and recovery
- Estimated: 2-3 hours

**Phase 15: Polish & Documentation** (Tasks T405-T448)
- Usage guide with integration patterns
- Performance benchmarks
- Migration guide for existing systems
- Complete example scenes
- Estimated: 3-4 hours

**Total Remaining**: ~9-12 hours to complete full infrastructure

**Benefits**:
- Complete state management system ready for any game feature
- Consistent patterns for all state needs (boot/menu/gameplay)
- Debug tools already available (F3 overlay)
- Clean architecture for future development

**Start Here**: Open `redux-state-store-tasks.md`, find Phase 12 (Task T330), begin with boot slice

### Option B: Expand Gameplay Features

Use state store with real gameplay systems:

**Potential Features**:
- Collision-based damage system (integrate with S_HealthSystem)
- Collectible items for score (coins, gems, powerups)
- Level progression (load/save current level)
- Inventory system (items, equipment)
- Enemy AI state management
- Save/load game system with multiple slots

**Benefits**:
- Immediate game value
- Validates architecture with complex real-world usage
- Discovers edge cases and patterns
- Builds gameplay faster

**Drawbacks**:
- Deviates from planned infrastructure
- Debug overlay would still be useful for troubleshooting
- Boot/Menu management deferred

**Start Here**: Choose a gameplay feature and design how it integrates with state store

### Option C: Documentation & Examples

Polish the PoC and create comprehensive integration guide:

**Tasks**:
- Document S_PauseSystem pattern (system + cursor + state coordination)
- Document S_HealthSystem pattern (timer-based with pause support)
- Document HUD pattern (reactive UI from selectors)
- Create migration guide (converting existing systems to use state)
- Performance benchmarking (state updates, signal batching overhead)
- Add more integration tests for PoC systems

**Benefits**:
- Makes state store accessible to other developers
- Clear patterns for future integrations
- Performance baselines established
- Production-ready documentation

**Drawbacks**:
- Delays feature development
- Infrastructure still incomplete (no debug overlay, boot/menu)

**Start Here**: Create `docs/state store/integration-guide.md` with PoC patterns

### Recommendation: Option A (Continue Infrastructure) ⭐

**Reasoning**:
1. Architecture is proven (Phase 10.5 validates it works)
2. Only ~9-12 hours to complete remaining infrastructure
3. Debug overlay already complete (helps with future debugging)
4. Boot/Menu slices needed for complete game flow
5. Better to finish infrastructure now while patterns are fresh

**Immediate Next Step**:
1. Open `redux-state-store-tasks.md`
2. Find Phase 12 section (Boot Slice)
3. Start with Task T330 (first boot slice task)
4. Follow TDD approach as before
5. Check off tasks and commit regularly

The state store is validated, has working debug tools, and ready to be completed! 🚀

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
