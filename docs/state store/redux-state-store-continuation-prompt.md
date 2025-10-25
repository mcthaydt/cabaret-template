# Redux State Store – Continuation Guide

## Project Status (2025-10-25)

The Redux-style centralized state store implementation is **ready for implementation**. The feature branch `redux-state-store` has comprehensive planning documentation and is waiting for development to begin.

**Current Status**: Planning complete (v2.0) with PRD, implementation plan, and detailed task breakdown.

**Phase 0 Decision**: **Option C - Dual-bus via abstract base** (CONFIRMED)

## Before Resuming Implementation

1. **Re-read the quick guidance docs**:
   - `AGENTS.md` - Commit strategy, testing requirements, repo map
   - `docs/general/DEV_PITFALLS.md` - GDScript typing, GUT patterns, common pitfalls
   - `docs/general/STYLE_GUIDE.md` - Naming conventions, file structure, code standards

2. **Review state store planning material**:
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
- [ ] Read the Prerequisites section in the implementation plan
- [ ] Review the Architectural Decisions (MANDATORY READING)
- [ ] Understand the MVP strategy

## Implementation Path

### Phase 0: Event Bus Architecture (Option C - ACTIVE)

**Tasks (from redux-state-store-tasks.md T026C-T031C)**:

1. Create directory `scripts/events/`
2. Create `scripts/events/event_bus_base.gd` (abstract base with shared logic)
3. Create `scripts/state/state_event_bus.gd` (state domain bus extending base)
4. Update `scripts/ecs/ecs_event_bus.gd` to extend base (preserves existing API)
5. Add tests for state bus isolation and reset behavior
6. Commit Phase 0C

**Key Benefits of Option C**:
- Zero breaking changes to existing ECS code
- Isolated domains (ECS vs State) with separate subscribers/histories
- Shared implementation in `EventBusBase`
- Clean test isolation: `StateStoreEventBus.reset()` vs `ECSEventBus.reset()`

### Phase 1: User Story 1 (Core Gameplay Slice) - 8 Micro-stories

After Phase 0 completes, implement these sequentially:

1. **Phase 1a**: Core M_StateStore Skeleton with U_StateUtils
2. **Phase 1b**: Action Registry with StringName Validation
3. **Phase 1c**: Gameplay Slice Reducer Infrastructure
4. **Phase 1d**: Type-Safe Action Creators
5. **Phase 1e**: Selector System with Cross-Slice Dependencies
6. **Phase 1f**: Signal Emission with Per-Frame Batching
7. **Phase 1g**: Action Logging with 1000-Entry History
8. **Phase 1h**: Persistence with Transient Field Marking and StateHandoff

Each micro-story follows TDD: Write tests → Verify tests fail → Implement → Verify tests pass → In-game validation → Commit

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

1. **Start Phase 0 (Option C)** (1-2 hours estimated):
   - Create `EventBusBase` abstract class
   - Create `StateStoreEventBus` concrete implementation
   - Update `ECSEventBus` to extend base
   - Write tests for bus isolation
   - Run ALL tests (state + ECS) to verify no regressions
   - Commit when green

2. **Start Phase 1a** (4 hours estimated):
   - Create M_StateStore skeleton
   - Create U_StateUtils helper
   - Update base_scene_template.tscn
   - Write tests, commit when green

3. **Continue through Phases 1b-1h** sequentially (1-2 days total)

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
