# Redux-Inspired State Store PRD

**Owner**: Development Team | **Updated**: 2025-10-18

## Summary

- **Vision**: A centralized, Redux-inspired state store that provides global state access across all game systems without singletons
- **Problem**: Current ECSManager is registry-only; no centralized application state for game progression, UI, saves, or cross-system communication. Teams avoid singletons but need global state access.
- **Success**: 100% of systems can access game/UI/session state through store actions with <5ms dispatch latency at 60fps
- **Timeline**: Completing today

## Requirements

### Users

- **Primary**: Game developers working on the September25Project character controller
- **Pain Points**:
  - Cannot access game state (scores, unlocks) from systems without passing through component queries
  - No centralized UI state management (menus, HUD, settings)
  - No save/load infrastructure for session persistence
  - Systems cannot communicate cross-cutting concerns without tight coupling
  - Debugging state changes requires manual logging across multiple systems

### Stories

#### Epic 1: Core Store Infrastructure

- **Story**: As a developer, I want to dispatch actions through a central store so that state updates are predictable and traceable
- **Acceptance Criteria**:
  - Given a registered reducer, when I dispatch an action, then the state updates according to reducer logic
  - Given store initialization, when the game starts, then default state is loaded from registered reducers
  - Given any system/component, when it needs state, then it can access the store via `get_store()` method

#### Epic 2: ECS Integration

- **Story**: As an ECS system, I want to read/write state through the store so that I can access global game state without singletons
- **Acceptance Criteria**:
  - Given a MovementSystem, when player score changes, then it can select score from store state
  - Given a store action dispatch, when state changes affect components, then subscribed systems receive notifications
  - Given ECSManager, when components register, then store is notified via middleware

#### Epic 3: Time-Travel Debugging

- **Story**: As a developer, I want to replay action history so that I can debug complex state bugs
- **Acceptance Criteria**:
  - Given 100 dispatched actions, when I enable time-travel mode, then I can step backward/forward through state
  - Given a bug report, when I export action history, then I can replay it to reproduce the issue
  - Given any state, when I inspect history, then I see all actions that led to current state

#### Epic 4: State Persistence

- **Story**: As a player, I want my game progress saved automatically so that I can resume where I left off
- **Acceptance Criteria**:
  - Given game state changes, when auto-save triggers, then state is serialized to disk as JSON/binary
  - Given a saved game file, when loading, then store rehydrates to previous state
  - Given sensitive data (settings), when saving, then only whitelisted state slices are persisted

#### Epic 5: Middleware System

- **Story**: As a developer, I want to intercept actions so that I can add logging, validation, and async operations
- **Acceptance Criteria**:
  - Given registered middleware, when action dispatches, then middleware chain executes in order
  - Given a logging middleware, when any action fires, then it logs action type, payload, and timestamp
  - Given async middleware, when dispatching, then it can perform side effects (API calls, file I/O)

#### Epic 6: Selectors & Memoization

- **Story**: As a system, I want to compute derived state efficiently so that I don't recalculate on every frame
- **Acceptance Criteria**:
  - Given a memoized selector, when state hasn't changed, then cached result is returned
  - Given derived state (e.g., "is player grounded"), when querying at 60fps, then computation cost is <0.1ms
  - Given multiple selectors, when they depend on same slice, then they share cache invalidation

### Features

#### P0 (Must Have - MVP)

- Core store class (`scripts/state/store.gd`) with scene tree group registration
- Static utility class (`scripts/state/store_utils.gd`) for store discovery from any node
- Action dispatch system with type-safe action creators
- Reducer registration and state tree management
- Store discovery pattern matching ECSManager (parent hierarchy + scene tree group)
- Basic subscription system (subscribe to state changes)
- Integration with existing ECSManager (hybrid mode)
- Automatic JSON serialization for save/load
- Basic selector API for reading state
- Unit tests with GUT framework

#### P1 (Should Have - Full Feature Set)

- Middleware infrastructure (compose multiple middleware)
- Time-travel debugging with action history buffer
- DevTools GUI panel (in-editor state inspector)
- Async action support (thunks)
- Memoized selectors with cache invalidation
- State slice whitelisting for persistence
- Store signals (`state_changed`, `action_dispatched`)
- Performance monitoring middleware (dispatch timing)

#### P2 (Nice to Have - Future Enhancements)

- Redux DevTools protocol compatibility
- State migration system (for version upgrades)
- Undo/redo commands API
- State snapshot diffing tool
- Hot-reload support (preserve state during code changes)
- Multi-store support (nested stores for sub-systems)
- Batch action dispatching (optimize rapid updates)
- Network sync middleware (future multiplayer)

## Technical

### Architecture

```
StateStore (Node in scene tree, discovered via "state_store" group)
├─ State Tree (Dictionary)
│  ├─ game: {score, level, unlocks}
│  ├─ ui: {active_menu, settings}
│  ├─ ecs: {component_registry, system_state}
│  └─ session: {player_prefs, save_slot}
├─ Reducers (Array[Callable])
├─ Middleware (Array[Callable])
├─ Subscribers (Array[Callable])
├─ History (Array[Action]) [time-travel]
└─ Selectors (Dictionary[StringName, MemoizedSelector])

Discovery Pattern (matches ECSManager):
- Components/Systems search parent hierarchy for node with get_store() method
- Fall back to scene tree group "state_store"
- Use duck-typing via has_method("dispatch") check

Integration Points:
- ECSManager subscribes to store state changes
- Systems can dispatch actions via get_store().dispatch()
- Components can select state via get_store().select()
- Store middleware can trigger ECS system updates
```

#### Key Classes

1. **StateStore** (extends Node): Core store with dispatch/subscribe/select, joins "state_store" group for discovery
2. **StateStoreUtils** (static class): Provides `get_store(from_node: Node)` for discovering StateStore in scene tree
3. **Action** (GDScript Dictionary): `{type: StringName, payload: Variant}`
4. **Reducer** (Callable): `func (state: Dictionary, action: Action) -> Dictionary`
5. **Middleware** (Callable): `func (store, next: Callable, action: Action)`
6. **Selector** (class): Memoized state reader with dependency tracking

#### File Structure

```
scripts/state/
├── store.gd                  # Core StateStore class
├── store_utils.gd            # Static utilities (get_store discovery)
├── action.gd                 # Action helpers (create_action, is_action)
├── reducer.gd                # Reducer utilities (combine_reducers)
├── middleware.gd             # Middleware helpers (apply_middleware)
├── selector.gd               # MemoizedSelector class
├── persistence.gd            # Save/load serialization
├── reducers/                 # Built-in reducers
│   ├── game_reducer.gd
│   ├── ui_reducer.gd
│   ├── ecs_reducer.gd
│   └── session_reducer.gd
├── middleware/               # Built-in middleware
│   ├── logger_middleware.gd
│   ├── persistence_middleware.gd
│   └── ecs_bridge_middleware.gd
└── actions/                  # Action creators
    ├── game_actions.gd
    ├── ui_actions.gd
    └── session_actions.gd
```

### Performance Requirements

- **Dispatch Latency**: <5ms per action at 60fps (16.67ms frame budget)
- **Selector Computation**: <0.1ms for memoized selectors (cache hits)
- **State Tree Size**: Support up to 10MB state tree without lag
- **History Buffer**: 1000 actions max (rolling buffer for time-travel)
- **Save/Load Time**: <100ms for JSON serialization (not blocking main thread)

### Security & Data Integrity

- **Immutability**: Reducers must return new state dictionaries (enforce in tests)
- **Type Safety**: Actions validated against registered action schemas
- **Save File Validation**: Checksum verification on load to prevent corruption
- **Whitelist Persistence**: Only approved state slices saved to disk (no sensitive data leaks)

## Success

### Primary KPIs

- **Adoption**: 100% of new systems use store for global state
- **Performance**: Action dispatch <5ms average
- **Reliability**: Zero state corruption bugs in production

### Secondary Metrics

- **Test Coverage**: >90% code coverage for state/* module
- **Developer Velocity**: 50% reduction in time to add global state features
- **Debug Time**: 70% reduction in state-related bug investigation time (via time-travel)

### Analytics Tracking

- **Dispatch Metrics**: Action type frequency, dispatch timing, middleware execution time
- **Selector Performance**: Cache hit rate, computation time, dependency chain depth
- **Persistence**: Save/load frequency, serialization size, error rates
- **History Buffer**: Buffer size utilization, time-travel usage frequency

## Implementation

### Phase 1: MVP (Core Functionality)

**Core Store + Actions/Reducers**
- Implement StateStore class with dispatch/subscribe
- Create reducer registration system
- Build action creator helpers
- Integrate StoreManager AutoLoad
- Write 20+ unit tests (GUT framework)

**ECS Integration + Persistence**
- Add ECS bridge middleware (dispatch to systems)
- Implement store locator pattern (find via scene tree)
- Build persistence layer (JSON save/load)
- Migrate 2-3 existing systems to use store
- Test save/load with 1000+ actions

**Selectors + Refinement**
- Implement MemoizedSelector class
- Add selector dependency tracking
- Performance optimization (profile at 60fps)
- Documentation + examples
- Integration testing with full game loop

### Phase 2: Full Feature Set

**Middleware + Logging**
- Middleware composition pipeline
- Logger middleware (debug output)
- Performance monitoring middleware
- Async thunk support

**Time-Travel Debugging**
- Action history buffer (rolling 1000 actions)
- Replay/undo/redo API
- DevTools panel UI (Godot editor plugin)
- State diff visualization

**Polish + Advanced Features**
- State migration system
- Hot-reload support
- Batch dispatch optimization
- Full documentation + video tutorial

### Team Requirements

- **Size**: 1-2 developers
- **Skills**:
  - Strong GDScript experience
  - Redux/state management patterns
  - Godot 4.x scene tree architecture
  - Unit testing with GUT
- **Commitment**: Full implementation today

## Risks & Mitigation

### Risk 1: Performance Overhead

- **Impact**: Store dispatch adds latency to 60fps game loop
- **Mitigation**:
  - Profile early and often
  - Use object pooling for actions
  - Batch updates where possible
  - Defer non-critical updates to idle frames

### Risk 2: Migration Complexity

- **Impact**: Integrating with existing ECSManager could break working systems
- **Mitigation**:
  - Hybrid approach preserves ECSManager
  - Incremental migration (system by system)
  - Comprehensive regression tests
  - Feature flag for rollback

### Risk 3: State Tree Growth

- **Impact**: Unbounded state tree causes memory bloat
- **Mitigation**:
  - State slice limits (max size per reducer)
  - Garbage collection for transient state
  - Monitoring middleware tracks tree size
  - Normalize relational data (avoid duplication)

### Risk 4: Serialization Failures

- **Impact**: Cannot save/load game progress
- **Mitigation**:
  - Whitelist approach (explicit save schemas)
  - Fallback to last good save
  - Incremental saves (not full state dumps)
  - Extensive save/load tests

---

## Validation Checklist

✓ **Problem quantified**: Systems cannot access game/UI/session state; no singleton alternative
✓ **Requirements testable**: All ACs have measurable outcomes (dispatch time, cache hits, coverage)
✓ **Success measurable**: Primary KPIs with clear targets
✓ **Technically feasible**: Similar to existing ECSManager pattern, proven Redux architecture

---

## Example Usage

### Dispatching Actions

```gdscript
# From any system, component, or UI node
var store = StateStoreUtils.get_store(self)

# Dispatch a simple action
store.dispatch({
	"type": "game/add_score",
	"payload": 100
})

# Using action creators
var action = GameActions.add_score(100)
store.dispatch(action)
```

### Creating Reducers

```gdscript
# game_reducer.gd
static func reduce(state: Dictionary, action: Dictionary) -> Dictionary:
	match action.type:
		"game/add_score":
			var new_state = state.duplicate(true)
			new_state.score += action.payload
			return new_state
		"game/level_up":
			var new_state = state.duplicate(true)
			new_state.level += 1
			return new_state
		_:
			return state
```

### Using Selectors

```gdscript
# From a system
var store = StateStoreUtils.get_store(self)

# Direct selection
var score = store.select("game.score")

# Memoized selector
var high_score_selector = MemoizedSelector.new(func(state):
	return state.game.score > state.game.high_score
)

if store.select(high_score_selector):
	print("New high score!")
```

### Subscribing to Changes

```gdscript
# Get store reference
var store = StateStoreUtils.get_store(self)

# Subscribe to state changes
store.subscribe(func(state):
	print("Score changed: ", state.game.score)
)

# Subscribe to specific actions
store.subscribe_to_action("game/add_score", func(action):
	print("Added score: ", action.payload)
)
```

---

This PRD provides a complete blueprint for implementing a production-ready Redux-inspired state store that integrates seamlessly with your existing ECS architecture while avoiding singleton patterns.
