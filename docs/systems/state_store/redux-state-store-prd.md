# Feature Specification: Redux-Style Centralized State Store

**Feature Branch**: `redux-state-store`
**Created**: 2025-10-25
**Last Updated**: 2025-12-08
**Version**: 3.1
**Status**: ✅ **PRODUCTION READY** - All Phases Complete (16.5/16.5), Mock Data Removed, All Tests Passing
**Input**: User description: "I want to build out a centralized state store inspired by redux toolkit with boot/menu/gameplay slices for our state foundation"

## Recent Updates

### Phase 16.5 (2025-10-27): Mock Data Removal
**Status**: Complete ✅

Removed all test-only mock data from production state structure:
- **Removed fields**: `health`, `score`, `level` from `RS_GameplayInitialState`
- **Removed actions**: `update_health()`, `update_score()`, `set_level()`, `take_damage()`, `add_score()`
- **Removed selectors**: `get_current_health()`, `get_current_score()`, `get_is_player_alive()`, `get_is_game_over()`, `get_completion_percentage()`
- **Removed systems**: `S_HealthSystem` (PoC only)
- **Removed tests**: `test_poc_health_system.gd` and 6 visual test scenes
- **Refactored**: All remaining tests and documentation to use production data (pause/unpause, entity snapshots)

Production state now contains only real fields used by actual game systems. See `docs/state_store/mock-data-removal-plan.md` for details.

## Architecture & Integration

### Event Bus Integration
We use an abstract base with two concrete buses (no autoload changes, no breaking changes):

- `scripts/events/base_event_bus.gd` (abstract) — shared implementation for subscribe/publish/history
- `scripts/events/ecs/u_ecs_event_bus.gd` (concrete) — ECS‑domain bus, preserves current public API
- `scripts/events/state/u_state_event_bus.gd` (concrete) — State‑domain bus, used only by state store and its tests

This isolates subscribers and histories between ECS and State, while sharing one implementation. If a single bus is later preferred, namespaced events remain a viable alternative, but dual‑bus avoids cross‑domain coupling.

### State Store Lifecycle
`M_StateStore` is an **in-scene node** (like `M_ECSManager`), not an autoload singleton. Each scene that needs state management instantiates its own store. This pattern:
- Enables scene-specific state isolation
- Allows state to cleanly reset between scene transitions
- Follows established ECS architecture patterns
- Facilitates testing (each test can create an isolated store)

### Signal Batching Strategy
State updates apply **immediately** when dispatched (synchronous reducer execution), but signal emissions **batch per physics frame**. This hybrid approach:
- Maintains predictable state for mid-frame reads
- Prevents signal spam during rapid action sequences
- Ensures ECS systems see consistent state during `process_tick(delta)`
- Limits signals to max 1 per slice per frame

### Cross-Slice Dependencies
Selectors can access state across multiple slices, but dependencies must be **explicitly declared** in slice configuration. This provides:
- Flexibility for features like "Resume Level 5" in menu (reads gameplay state)
- Explicit coupling documentation via declared dependencies
- Easier debugging of state relationships
- Foundation for future dependency graph validation

## Naming Conventions

All state management code follows the project's prefix+suffix naming conventions defined in `docs/general/STYLE_GUIDE.md`:

| Component | Class Name | File Name | Example |
|-----------|------------|-----------|---------|
| State Store | `M_StateStore` | `m_state_store.gd` | Manager pattern |
| Action Creators | `U_GameplayActions` | `actions/u_gameplay_actions.gd` | Utility pattern (suffix "Actions" permitted) |
| Initial State | `RS_GameplayInitialState` | `rs_gameplay_initial_state.gd` | Resource pattern |
| Debug Overlay | `SC_StateDebugOverlay` | `sc_state_debug_overlay.gd` | Scene pattern |
| Tests | `TestMStateStore` | `test_m_state_store.gd` | Test pattern |

**Action Type Constants**: All action types use `StringName` for performance and type safety:
```gdscript
const ACTION_PAUSE_GAME := StringName("gameplay/pause")
const ACTION_UPDATE_HEALTH := StringName("gameplay/update_health")
```

## Testing Infrastructure

### GUT Test Framework
All state store tests use GUT (Godot Unit Test) framework with project-standard commands:
```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/state -gexit
```

Note on event bus resets in tests:
- State store tests: call `U_StateEventBus.reset()`
- ECS tests: call `U_ECSEventBus.reset()`

### Critical Testing Requirements
- **Autofree everything**: All nodes instantiated in tests must use `autofree()`/`autofree_context()` to prevent memory leaks
- **Explicit typing**: All Variants (from `Callable.call()`, action payloads, etc.) require explicit type annotations
- **Deferred operations**: After adding store to scene tree, `await get_tree().process_frame` before assertions
- **Warning suppression**: Tests that mock engine methods need `@warning_ignore("native_method_override")`
- **Tab indentation**: All `.gd` files use tabs, not spaces

### Test Organization
```
tests/unit/state/
├── test_m_state_store.gd            # Core store functionality
├── test_u_gameplay_actions.gd       # Action creator validation
├── test_gameplay_slice_reducers.gd  # Reducer pure function tests
├── test_state_selectors.gd          # Selector computation tests
├── test_state_persistence.gd        # Save/load serialization tests
└── integration/
    └── test_slice_transitions.gd    # Boot→menu→gameplay flows
```

## Implementation Files

This feature will create the following new files:

### Core State System
- `scripts/state/m_state_store.gd` - Central state store manager
- `scripts/events/base_event_bus.gd` - Abstract base for event buses
- `scripts/events/state/u_state_event_bus.gd` - Concrete state store event bus (uses base)

### Action Creators (Utilities)
- `scripts/state/actions/u_gameplay_actions.gd` - Gameplay action creators
- `scripts/state/actions/u_boot_actions.gd` - Boot sequence action creators
- `scripts/state/actions/u_menu_actions.gd` - Menu navigation action creators
- `scripts/state/actions/u_scene_actions.gd` - Scene transition action creators
- `scripts/state/actions/u_transition_actions.gd` - Cross-scene transition helpers

### Reducers
- `scripts/state/reducers/u_gameplay_reducer.gd` - Gameplay slice reducer
- `scripts/state/reducers/u_boot_reducer.gd` - Boot slice reducer
- `scripts/state/reducers/u_menu_reducer.gd` - Menu slice reducer
- `scripts/state/reducers/u_scene_reducer.gd` - Scene management slice reducer

### Selectors
- `scripts/state/selectors/u_gameplay_selectors.gd` - Gameplay state selectors
- `scripts/state/selectors/u_boot_selectors.gd` - Boot state selectors
- `scripts/state/selectors/u_menu_selectors.gd` - Menu state selectors
- `scripts/state/selectors/u_entity_selectors.gd` - Entity-derived selectors
- `scripts/state/selectors/u_input_selectors.gd` - Input-derived selectors
- `scripts/state/selectors/u_visual_selectors.gd` - Visual feedback selectors
- `scripts/state/selectors/u_physics_selectors.gd` - Physics integration selectors

### Initial State Resources
- `scripts/state/resources/rs_gameplay_initial_state.gd` (+.tres) - Gameplay default state
- `scripts/state/resources/rs_boot_initial_state.gd` (+.tres) - Boot default state
- `scripts/state/resources/rs_menu_initial_state.gd` (+.tres) - Menu default state
- `scripts/state/resources/rs_state_store_settings.gd` (+.tres) - Store config (history size, debug mode, etc.)

### Support Systems
- `scripts/state/utils/u_action_registry.gd` - Action type validation system
- `scripts/state/utils/u_signal_batcher.gd` - Per-frame signal batching
- `scripts/state/utils/u_serialization_helper.gd` - Godot type ↔ JSON conversion
- `scripts/state/utils/u_state_handoff.gd` - Cross-scene state preservation
- `scripts/state/resources/rs_state_slice_config.gd` - Slice metadata (dependencies, transient fields)

### Debug Tools
- `scenes/debug/sc_state_debug_overlay.tscn` - Debug UI scene
- `scenes/debug/sc_state_debug_overlay.gd` - Debug UI script

### Tests
- `tests/unit/state/test_m_state_store.gd`
- `tests/unit/state/test_u_gameplay_actions.gd`
- `tests/unit/state/test_gameplay_slice_reducers.gd`
- `tests/unit/state/test_state_selectors.gd`
- `tests/unit/state/test_state_persistence.gd`
- `tests/unit/state/integration/test_slice_transitions.gd`

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Core Store + Gameplay Slice Golden Template (Priority: P1)

Developer creates a fully-functional gameplay state slice demonstrating all Redux-Toolkit patterns (reducers, actions, selectors, persistence, testing) that serves as the architectural template for future slices.

**Why this priority**: This establishes the foundational architecture and proves all patterns work before scaling to other slices. Having one complete, well-tested slice ensures consistent patterns and catches design issues early.

**Independent Test**: Can be fully tested by dispatching gameplay actions (pause/unpause, update player stats, modify objectives) and verifying state changes through selectors without any menu or boot functionality. Delivers immediate value by managing runtime game state.

**IMPORTANT**: Per `AGENTS.md`, this story is broken into **8 micro-stories** for incremental commits. Each micro-story represents a logical, test-green milestone:

---

#### User Story 1a - Core M_StateStore Skeleton (Commit #1)

**Objective**: Create foundational `M_StateStore` node with in-scene setup, basic dispatch/subscribe infrastructure, and minimal tests.

**Deliverables**:
- `scripts/state/m_state_store.gd` - Store class extending `Node`
- `scripts/state/resources/rs_state_slice_config.gd` - Slice metadata structure (plain class, not Resource)
- Basic `dispatch(action)` method (no reducers yet, just logs action)
- Basic `subscribe(callback)` method for registering observers
- `tests/unit/state/test_m_state_store.gd` - Tests for store instantiation and subscription

**Acceptance**:
- **Given** a scene with `M_StateStore` node, **When** store initializes, **Then** it registers with scene tree successfully
- **Given** a callback subscribed to store, **When** an action is dispatched, **Then** callback receives action (even though state doesn't change yet)
- **Given** store runs in test, **When** `autofree()` releases it, **Then** no memory leaks occur

---

#### User Story 1b - Action Registry with StringName Validation (Commit #2)

**Objective**: Implement action type validation using `StringName` constants and runtime payload checking.

**Deliverables**:
- `scripts/state/utils/u_action_registry.gd` - Action type registry and validator
- `scripts/state/actions/u_gameplay_actions.gd` - Action creator utilities with constants
- Action validation in `M_StateStore.dispatch()`
- `tests/unit/state/test_u_gameplay_actions.gd` - Action creator tests

**Acceptance**:
- **Given** a registered action type `ACTION_PAUSE_GAME`, **When** I call `U_GameplayActions.pause_game()`, **Then** it returns `{"type": StringName("gameplay/pause"), "payload": null}`
- **Given** an unregistered action type, **When** dispatched, **Then** store logs error and emits `validation_failed` signal
- **Given** action with incorrect payload shape, **When** validated, **Then** registry catches error with clear message

---

#### User Story 1c - Gameplay Slice Reducer Infrastructure (Commit #3)

**Objective**: Implement reducer system with immutability via `.duplicate(true)` and integrate initial state from resources.

**Deliverables**:
- `scripts/state/reducers/gameplay_reducer.gd` - Reducer with switch-case for action types
- `scripts/state/resources/rs_gameplay_initial_state.gd` - Default gameplay state script
- `resources/state/cfg_default_gameplay_initial_state.tres` - Default gameplay state data
- Reducer registration in `M_StateStore`
- State update logic in `dispatch()` using `.duplicate(true)`
- `tests/unit/state/test_gameplay_slice_reducers.gd` - Reducer pure function tests

**Acceptance**:
- **Given** initial gameplay state, **When** `ACTION_PAUSE_GAME` dispatched, **Then** state.paused becomes true and previous state unchanged
- **Given** gameplay reducer, **When** called with same state and action twice, **Then** produces identical results (pure function)
- **Given** state loaded from `RS_GameplayInitialState.tres`, **When** store initializes, **Then** gameplay slice starts with resource defaults

---

#### User Story 1d - Type-Safe Action Creators (Commit #4)

**Objective**: Expand `U_GameplayActions` with full suite of gameplay action creators following project patterns.

**Deliverables**:
- Complete action creators for: pause/unpause, update_health, update_score, update_inventory, set_level, etc.
- All action creators return typed `Dictionary` with explicit annotations
- Constants for all action types using `StringName`
- Expanded tests validating all action creators

**Acceptance**:
- **Given** `U_GameplayActions.update_health(50)`, **When** called, **Then** returns `{"type": StringName("gameplay/update_health"), "payload": {"health": 50}}`
- **Given** all gameplay actions, **When** dispatched through store, **Then** appropriate reducers update state correctly
- **Given** typed action dictionary, **When** used in tests, **Then** no Variant inference errors occur

---

#### User Story 1e - Selector System with Cross-Slice Dependencies (Commit #5)

**Objective**: Implement selector infrastructure for derived state computation with explicit slice dependency declarations.

**Deliverables**:
- `scripts/state/selectors/u_gameplay_selectors.gd` - Selector utility functions
- Dependency declaration in `RS_StateSliceConfig`
- Selectors: `get_is_player_alive()`, `get_is_game_over()`, `get_completion_percentage()`, etc.
- `tests/unit/state/test_state_selectors.gd` - Selector computation tests

**Acceptance**:
- **Given** gameplay state with `health: 0`, **When** `get_is_player_alive()` called, **Then** returns `false`
- **Given** gameplay state with `objectives: {"main": true, "side": false}`, **When** `get_is_game_over()` called, **Then** computes correctly from objective completion
- **Given** selector that needs boot state, **When** dependency not declared, **Then** clear error guides developer to add dependency

---

#### User Story 1f - Signal Emission with Per-Frame Batching (Commit #6)

**Objective**: Implement hybrid timing system - immediate state updates but batched signal emission using physics frame.

**Deliverables**:
- `scripts/state/utils/u_signal_batcher.gd` - Per-frame signal batching system
- Integration with `M_StateStore._physics_process()`
- Signals: `state_changed(action, new_state)`, `slice_updated(slice_name, slice_state)`
- Signal batching tests

**Acceptance**:
- **Given** 10 actions dispatched in single frame, **When** physics frame completes, **Then** only 1 `slice_updated` signal emitted per changed slice
- **Given** action dispatched, **When** read state immediately after dispatch, **Then** state reflects change (not deferred to next frame)
- **Given** signal batching, **When** measured overhead, **Then** adds less than 0.05ms per frame

---

#### User Story 1g - Action Logging with 1000-Entry History (Commit #7)

**Objective**: Implement action history tracking with circular buffer pruning at 1000 entries, including timestamps and state snapshots.

**Deliverables**:
- Action history array with circular buffer logic
- Timestamp recording using `U_ECSUtils.get_current_time()`
- History access methods: `get_action_history()`, `get_last_n_actions(n)`
- Pruning logic when history exceeds 1000 entries
- History tests

**Acceptance**:
- **Given** sequence of actions dispatched, **When** `get_action_history()` called, **Then** returns array of `{action, timestamp, state_after}` entries
- **Given** 1001 actions dispatched, **When** checking history size, **Then** oldest action pruned, history size remains 1000
- **Given** action log, **When** inspected in tests, **Then** can trace exact state evolution for debugging

---

#### User Story 1h - Persistence with Transient Field Marking (Commit #8)

**Objective**: Implement save/load system with JSON serialization, Godot type conversion, and selective field persistence.

**Deliverables**:
- `scripts/state/utils/u_serialization_helper.gd` - Godot type ↔ JSON conversion (Vector3 → {x,y,z}, etc.)
- Transient field marking in `RS_StateSliceConfig`
- `save_state(filepath)` and `load_state(filepath)` methods
- `tests/unit/state/test_state_persistence.gd` - Save/load round-trip tests

**Acceptance**:
- **Given** gameplay state with `health: 75`, **When** saved to disk and loaded, **Then** health restores to 75 without data loss
- **Given** transient field `_internal_cache`, **When** state saved, **Then** field excluded from JSON, doesn't persist
- **Given** state with Vector3 position, **When** serialized, **Then** converts to `{"x": 1.0, "y": 2.0, "z": 3.0}` and deserializes correctly
- **Given** 100 save/load cycles, **When** tested, **Then** no data corruption occurs

---

### Overall P1 Acceptance Scenarios

After completing all 8 micro-stories, the complete User Story 1 must satisfy:

1. **Given** an initialized state store, **When** I dispatch a gameplay action (e.g., `update_player_health`), **Then** the gameplay slice state updates correctly and observers are notified via batched signals
2. **Given** gameplay state with player stats, **When** I call a selector (e.g., `get_is_player_alive()`), **Then** derived state is computed correctly from base state
3. **Given** a sequence of gameplay actions, **When** I inspect the action log, **Then** I can see every state change with action type, timestamp, and before/after state (up to 1000 entries)
4. **Given** gameplay state changes during physics loop, **When** I measure performance, **Then** state updates add less than 0.1ms overhead per frame
5. **Given** gameplay state with inventory/stats, **When** I trigger manual save, **Then** state persists to disk and can be restored without data loss

---

### User Story 2 - State Debugging & Inspection Tools (Priority: P2)

Developer can inspect live state, view action history, and debug state changes using built-in dev tools during development and testing.

**Why this priority**: Makes the store "predictable and debuggable" - one of the primary success criteria. Without debugging tools, the benefits of Redux patterns are limited.

**Independent Test**: Can test by instantiating `SC_StateDebugOverlay` scene in running game, dispatching actions, and verifying that action log, state snapshots, and live state inspection all display correctly. Works independently of which slices exist.

**Implementation**: Debug overlay is a **separate scene** (`SC_StateDebugOverlay.tscn`) spawned on demand (not an autoload). This keeps it out of production builds and allows toggling via debug key (e.g., F3).

**Acceptance Scenarios**:

1. **Given** the game is running with debug mode enabled, **When** I press F3 to spawn the debug overlay, **Then** I see current state for all slices in a readable format
2. **Given** multiple state changes have occurred, **When** I view the action log in the overlay, **Then** I see chronological list of actions with timestamps and state diffs
3. **Given** I'm debugging a state issue, **When** I click on a historical action in the overlay, **Then** I can see the exact state before and after that action
4. **Given** overlay is spawned, **When** I press F3 again, **Then** overlay is removed from scene tree and resources freed

---

### User Story 3 - Boot Slice State Management (Priority: P3)

Game manages boot/initialization state through the state store, tracking asset loading, config validation, system readiness, and error states.

**Why this priority**: Completes the "state transitions" goal by adding the entry point of the game lifecycle. Boot slice is simpler than menu, making it a good next step after gameplay.

**Independent Test**: Can test boot slice independently by creating a minimal scene that only goes through boot states without menu or gameplay. Delivers value by making initialization predictable and debuggable.

**Acceptance Scenarios**:

1. **Given** game starts, **When** boot sequence begins, **Then** boot slice state tracks loading progress from 0% to 100%
2. **Given** a required asset fails to load, **When** boot slice detects the failure, **Then** state transitions to error state with appropriate error message
3. **Given** all boot dependencies are ready, **When** boot completes, **Then** state transitions from "boot" to "ready_for_menu" phase

---

### User Story 4 - Menu Slice Navigation State (Priority: P4)

Game manages menu/UI navigation through state store, tracking active screens, user selections, save file management, and menu transitions.

**Why this priority**: Completes the three-slice foundation. Menu slice demonstrates UI-driven state changes and bridges boot→gameplay transitions.

**Independent Test**: Can test menu slice with a standalone menu scene that doesn't require gameplay. Delivers value by making UI navigation state explicit and reversible.

**Acceptance Scenarios**:

1. **Given** user is on main menu, **When** user navigates to settings screen, **Then** menu slice state updates `active_screen` and other systems can react to this change
2. **Given** user selects character and difficulty, **When** these selections are made, **Then** menu slice stores pending game configuration that gameplay slice will use on game start
3. **Given** multiple save files exist, **When** user views save selection screen, **Then** menu slice state contains list of available saves with metadata

---

### User Story 5 - Complete State Transition Flows (Priority: P5)

Game smoothly transitions between boot→menu→gameplay→menu states with proper initialization, cleanup, and state handoff between slices.

**Why this priority**: Integrates all three slices into coherent game lifecycle. This is where "state transitions" goal is fully realized.

**Independent Test**: Can test by creating integration tests that trigger full state flow sequences and verify each slice handles transitions correctly. Delivers full game lifecycle management.

**Acceptance Scenarios**:

1. **Given** boot completes successfully, **When** state transitions to menu, **Then** boot slice becomes inactive, menu slice initializes, and UI responds correctly
2. **Given** user starts game from menu, **When** state transitions to gameplay, **Then** menu pending selections transfer to gameplay slice, gameplay initializes, and game scene loads
3. **Given** user exits to menu from gameplay, **When** state transitions, **Then** gameplay state is preserved (for resume), menu reactivates, and UI returns to appropriate screen

---

### User Story 6 - Selective State Persistence (Priority: P6)

Game persists state to disk with multiple strategies: manual save points, auto-save on changes, selective slice persistence, and full state snapshots.

**Why this priority**: Addresses "save/load and state persistence" goal. Builds on fully-working state store to add serialization layer.

**Independent Test**: Can test persistence independently by saving/loading state without running full game. Mock different save scenarios and verify integrity.

**Acceptance Scenarios**:

1. **Given** gameplay state changes (e.g., health update), **When** auto-save is enabled for gameplay slice, **Then** state automatically persists to disk without blocking gameplay
2. **Given** user triggers manual save at checkpoint, **When** save action dispatches, **Then** full snapshot of persistent state is written with timestamp and slot identifier
3. **Given** user loads a saved game, **When** state store hydrates from disk, **Then** gameplay slice restores correctly and game resumes from saved state

---

### User Story 7 - Time-Travel Debugging (Priority: P7)

Developer can rewind state to previous points in time, replay action sequences, and inspect how state evolved to debug complex state issues.

**Why this priority**: Final piece of "time-travel debugging and state inspection" goal. Advanced feature that leverages immutable state history.

**Independent Test**: Can test time-travel by recording action sequences in unit tests, rewinding, and verifying state matches historical snapshots. Works independently of game content.

**Snapshot Strategy**: Snapshots are created **on-demand only** (manual developer trigger via debug overlay or API call). This minimizes memory overhead while still enabling powerful debugging when needed. Automatic snapshots (every Nth action) can be added later if needed.

**Acceptance Scenarios**:

1. **Given** developer triggers manual snapshot, **When** state continues to change, **Then** snapshot preserves exact state at snapshot time
2. **Given** a sequence of actions has been recorded with snapshots, **When** developer triggers state rewind to snapshot N, **Then** state reverts to exact state at snapshot N
3. **Given** a bug was reproduced with recorded actions, **When** developer replays action sequence from snapshot, **Then** actions replay in order and state progresses identically to original sequence
4. **Given** developer is inspecting state history in debug overlay, **When** stepping through actions one-by-one, **Then** state inspector shows state transitions for each individual action
5. **Given** no snapshots have been manually created, **When** checking memory usage, **Then** only action history (1000 entries) consumes memory, not full state snapshots

---

### Edge Cases

- **What happens when a reducer returns invalid state shape (e.g., missing required keys)?**
  - Runtime validation logs error, returns previous state unchanged, and emits `validation_failed` signal with details
  - Action is logged in history with `{action, error: "validation_failed", state: previous_state}`

- **How does the store handle rapid action dispatches during physics loop (e.g., 100+ actions in single frame)?**
  - Actions process synchronously immediately (state updates on dispatch)
  - Signals batch per-frame: max 1 `slice_updated` signal per slice per frame
  - Performance tests verify <0.1ms total overhead even with 100 actions/second
  - If 1000+ actions in single frame, consider logging performance warning

- **What happens if ECS systems and state store updates create circular dependencies?**
  - Independent-but-observable architecture prevents tight coupling
  - ECS systems subscribe to state changes via signals (read-only observation)
  - State reducers are pure functions that never call ECS APIs directly
  - If circular pattern detected (action → state change → signal → system → dispatch same action), system should guard against it

- **How do event buses handle both ECS and state events without conflicts?**
  - Recommended: dual‑bus separation. ECS uses `U_ECSEventBus`; state store uses `U_StateEventBus`. Subscribers and histories are isolated by design.
  - Alternative: single bus with namespaced StringNames (e.g., `"ecs/*"`, `"state/*"`) if consolidation is desired later.
  - Event payloads remain domain‑specific: ECS events carry component refs; state events carry actions/state diffs.

- **What happens when selector has circular dependency on slices (e.g., Menu depends on Gameplay, Gameplay depends on Menu)?**
  - Slice config validation detects circular dependencies at initialization
  - Store logs error and refuses to start: `"Circular slice dependency detected: menu → gameplay → menu"`
  - Developer must refactor to break cycle (extract shared state, use events instead of selectors, etc.)

- **What happens when loading persisted state with incompatible schema (e.g., after game update)?**
  - State migration system validates schema version from JSON metadata
  - Applies sequential migrations if version < current_version
  - Falls back to default initial state with warning if migration fails
  - Future enhancement: migration scripts registered per version (v1→v2, v2→v3, etc.)

- **How does store handle state access from multiple threads?**
  - Store is single-threaded (main thread only)
  - GDScript doesn't have thread-safe collections, so state access restricted to main thread
  - If background thread needs state, it must signal main thread to dispatch action
  - Consider future enhancement: immutable state snapshots can be safely read from threads

- **What happens when signal batching causes observer to miss intermediate states?**
  - By design: signals batch to prevent spam, observers see final frame state only
  - If intermediate states needed, observer must check action history
  - Debug overlay can show all intermediate states via action log
  - Critical observers can subscribe to unbatched `action_dispatched` signal (advanced use)

- **How does serialization handle Godot types that don't convert cleanly to JSON (e.g., Callable, Object refs)?**
  - SerializationHelper has explicit type whitelist: Vector3, Transform3D, Color, etc.
  - Unsupported types (Callable, Node refs, Resources) log error during save
  - Best practice: state should only contain JSON-safe primitives and whitelisted Godot types
  - Complex objects should be referenced by ID/path strings, not direct references

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a centralized state store as in-scene node (M_StateStore) that manages boot, menu, and gameplay state slices
- **FR-002**: System MUST implement Redux-style dispatch/reducer pattern where actions are dispatched to update state immutably
- **FR-003**: System MUST provide type-safe action creators (e.g., `GameplayActions.update_player_health(new_health)`) instead of raw dictionaries
- **FR-004**: System MUST emit signals when state changes, allowing ECS systems and UI to subscribe and react to state updates
- **FR-005**: System MUST support selectors that compute derived state from base state (e.g., `get_is_player_alive()` from health value)
- **FR-006**: System MUST implement Immer-style "mutating" API that uses `.duplicate(true)` under the hood to maintain immutability
- **FR-007**: System MUST log all dispatched actions with timestamps for debugging and inspection
- **FR-008**: System MUST maintain action history for time-travel debugging and state replay
- **FR-009**: System MUST validate state shape after each reducer and handle invalid states gracefully
- **FR-010**: System MUST support both manual save points and auto-save strategies for state persistence
- **FR-011**: System MUST serialize and deserialize state to/from JSON for save file persistence
- **FR-012**: System MUST allow selective persistence (e.g., gameplay slice persists, menu transitions don't)
- **FR-013**: System MUST add less than 0.1ms overhead per state update during physics loop
- **FR-014**: Gameplay slice MUST track player stats (health, score, inventory), session metadata (level, elapsed time), pause state, and objectives status
- **FR-015**: Boot slice MUST track asset loading progress, config validation status, system dependencies readiness, and error/fallback states
- **FR-016**: Menu slice MUST track active screen, user selections, save file management, and menu animation states
- **FR-017**: System MUST provide debug overlay UI for live state inspection, action log viewing, and state snapshot browsing
- **FR-018**: System MUST support state transition flows between boot→menu→gameplay→menu with proper cleanup and initialization
- **FR-019**: System MUST be observable by ECS systems without creating tight coupling (independent-but-observable architecture)
- **FR-020**: System MUST provide comprehensive unit tests for all reducers following Given/When/Then pattern
- **FR-021**: Action history MUST prune to maximum 1000 entries using circular buffer to prevent memory leaks
- **FR-022**: All state management classes MUST follow project naming conventions: M_* (managers), U_* (utilities), RS_* (resources), SC_* (scenes)
- **FR-023**: All action types MUST use StringName constants (not strings) and be validated by ActionRegistry before dispatch
- **FR-024**: Signal emission MUST batch per physics frame with maximum 1 signal per slice per frame to prevent spam
- **FR-025**: State persistence MUST support transient field marking via RS_StateSliceConfig to exclude runtime-only fields from saves
- **FR-026**: Godot-specific types (Vector3, Transform3D, Color, etc.) MUST convert to/from JSON dictionaries via SerializationHelper
- **FR-027**: Initial state for each slice MUST load from RS_*InitialState resources (.tres files) following ECS settings pattern
- **FR-028**: Cross-slice selector access MUST declare explicit dependencies in RS_StateSliceConfig to document coupling
- **FR-029**: Event bus architecture MUST be one of:
  - Preferred: dual‑bus via `BaseEventBus` with `U_ECSEventBus` and `U_StateEventBus` (isolated domains, shared implementation), or
  - Alternative: single bus with namespaced event types (`"ecs/*"`, `"state/*"`). Direct signals are acceptable for initial delivery if bus work is deferred.
- **FR-030**: Time-travel snapshots MUST be created only on manual developer trigger (not automatic) to minimize memory overhead

### Key Entities *(include if feature involves data)*

- **M_StateStore** (`Node`): Central store manager (in-scene node) managing all state slices, handling dispatch, running reducers, emitting signals, maintaining history. Analogous to M_ECSManager for state.

- **Action** (`Dictionary`): Represents state change intent with structure:
  ```gdscript
  {
    "type": StringName,     # e.g., StringName("gameplay/update_health")
    "payload": Variant      # e.g., {"health": 50} or null
  }
  ```

- **Reducer** (`Callable` or static function): Pure function with signature `func reduce(current_state: Dictionary, action: Dictionary) -> Dictionary`. Takes current state and action, returns new state without mutating inputs. Uses `.duplicate(true)` for immutability.

- **Slice**: Named portion of state tree (e.g., `"gameplay"`, `"boot"`, `"menu"`) with:
  - Own reducer function
  - Initial state from RS_*InitialState resource
  - RS_StateSliceConfig defining dependencies and transient fields

- **Navigation Slice**: Dedicated Redux slice managing UI location and overlay stack management. Fully transient (not persisted to saves).
  - **Reducer**: `U_NavigationReducer`
  - **Purpose**: UI location and overlay stack management
  - **State Shape**:
    ```gdscript
    {
      "shell": StringName,              # "main_menu" | "gameplay" | "endgame"
      "base_scene_id": StringName,      # Current scene ID
      "overlay_stack": Array[StringName], # Stack of overlay IDs
      "active_menu_panel": StringName   # Active panel (e.g., "menu/main")
    }
    ```
  - **Key Actions**: `NAV/OPEN_PAUSE`, `NAV/CLOSE_PAUSE`, `NAV/OPEN_OVERLAY`, `NAV/CLOSE_TOP_OVERLAY`, `NAV/SET_MENU_PANEL`
  - See: `docs/ui_manager/ui-manager-prd.md`

- **RS_StateSliceConfig** (plain class): Configuration for a state slice declaring:
  - `slice_name: StringName` - Unique slice identifier
  - `dependencies: Array[StringName]` - Other slices this selector can access
  - `transient_fields: Array[StringName]` - Fields excluded from persistence (e.g., `"_cache"`)
  - `initial_state_resource: RS_*InitialState` - Default state resource

- **ActionRegistry**: Validates action types and payloads before dispatch. Maintains:
  - Registered action types (StringName constants)
  - Payload shape validators (optional, for type safety)
  - Validation error reporting

- **U_SignalBatcher**: Queues signal emissions and batches them per physics frame:
  - Integrates with `M_StateStore._physics_process(delta)`
  - Tracks which slices changed during frame
  - Emits max 1 `slice_updated(slice_name, slice_state)` per slice per frame
  - Provides unbatched `action_dispatched(action)` for advanced use cases

- **SerializationHelper**: Converts Godot types to/from JSON-compatible dictionaries:
  - `vector3_to_dict(v: Vector3) -> Dictionary` returns `{x, y, z}`
  - `dict_to_vector3(d: Dictionary) -> Vector3`
  - Supports: Vector3, Vector2, Transform3D, Basis, Color, Rect2, AABB, Plane, Quaternion
  - Whitelist approach: unsupported types (Callable, Node refs) log errors

- **Selector** (`static function`): Pure function computing derived state from base state:
  - Signature: `func select_is_player_alive(state: Dictionary) -> bool`
  - Can access multiple slices if dependencies declared
  - Examples: `get_is_player_alive()`, `get_completion_percentage()`, `get_can_resume_game()`

- **Subscription** (`Callable`): Callback registered with store, executed when state changes:
  - Signature: `func on_state_change(action: Dictionary, new_state: Dictionary) -> void`
  - Receives both action that caused change and resulting state
  - Can unsubscribe via returned token/ID

- **State Snapshot**: Point-in-time copy of entire state created on manual trigger:
  - Structure: `{timestamp: int, action_index: int, state: Dictionary}`
  - Created only when developer explicitly calls `create_snapshot()`
  - Used for time-travel debugging (rewind to snapshot)

- **Action Creator** (`static function`): Type-safe factory for action dictionaries:
  - Returns `Dictionary` with explicit type annotation
  - Example: `static func pause_game() -> Dictionary: return {"type": ACTION_PAUSE, "payload": null}`
  - Lives in `U_*Actions` utility classes

- **RS_*InitialState** (`Resource`): Godot resource defining default state for a slice:
  - Editable in Godot inspector (follows ECS settings pattern)
  - Saved as `.tres` files in `resources/state/`
  - Loaded at store initialization to set slice initial state
  - Example fields: `@export var default_health: int = 100`

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Adding new state field follows clear 5-step pattern (1. add to RS_*InitialState resource, 2. add reducer case, 3. add action creator with StringName constant, 4. add selector if needed, 5. add test) and takes less than 5 minutes

- **SC-002**: Every state change is logged with action type, timestamp, and can be inspected in debug overlay (F3) or via `get_action_history()` API. Action history maintains exactly 1000 entries via circular buffer.

- **SC-003**: State updates measured in physics loop add less than 0.1ms per frame overhead (tested with 100 actions/second stress test). Signal batching adds less than 0.05ms additional overhead.

- **SC-004**: 100% unit test coverage for all reducer functions with Given/When/Then scenarios following GUT framework patterns (autofree, explicit typing, deferred operations).

- **SC-005**: Developers can reproduce any state-related bug by replaying recorded action sequence from logs. Time-travel snapshots enable rewind to specific points when manually triggered.

- **SC-006**: State store passes integration tests demonstrating boot→menu→gameplay→menu transitions work correctly with proper slice initialization and cleanup.

- **SC-007**: Save/load functionality successfully persists and restores gameplay state without data corruption across 100 test cycles. Godot types (Vector3, Transform3D) serialize/deserialize correctly via SerializationHelper.

- **SC-008**: Type safety patterns catch common mistakes (wrong action type, missing payload fields, incorrect reducer signature) with clear error messages in development. ActionRegistry validates all dispatched actions against registered types.

- **SC-009**: Dual‑bus architecture in place: `U_ECSEventBus` and `U_StateEventBus` both extend `BaseEventBus`, isolating domains while sharing implementation. Namespaced single‑bus remains an alternative, not required.

- **SC-010**: All 8 micro-stories for User Story 1 (P1) committed individually with passing tests. Each commit represents a logical, test-green milestone following `AGENTS.md` requirements.

- **SC-011**: All state management files follow project naming conventions: M_StateStore, U_GameplayActions, RS_GameplayInitialState, SC_StateDebugOverlay, test_m_state_store.gd.

- **SC-012**: Cross-slice dependencies are explicitly declared in RS_StateSliceConfig. Circular dependencies detected at initialization and prevented with clear error messages.

- **SC-013**: Transient fields (e.g., runtime caches) are excluded from persistence when marked in RS_StateSliceConfig. Save files only contain persistable game state.

- **SC-014**: Debug overlay (SC_StateDebugOverlay) can be spawned/removed on demand via F3 key. Overlay shows live state, action history, and allows manual snapshot creation without impacting production builds.
