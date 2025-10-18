# Redux-Inspired State Store PRD

**Owner**: Development Team | **Updated**: 2025-10-18

## Summary

- **Vision**: A centralized, Redux-inspired state store that provides global state access across all game systems without singletons
- **Problem**: Current M_ECSManager is registry-only; no centralized application state for game progression, UI, saves, or cross-system communication. Teams avoid singletons but need global state access.
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
  - Given a S_MovementSystem, when player score changes, then it can select score from store state
  - Given a store action dispatch, when state changes affect components, then subscribed systems receive notifications
  - Given M_ECSManager, when components register, then store is notified via middleware

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
- Store discovery pattern matching M_ECSManager (parent hierarchy + scene tree group)
- Basic subscription system (subscribe to state changes)
- Integration with existing M_ECSManager (hybrid mode)
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
M_StateManager (Node in scene tree, discovered via "state_store" group)
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

Discovery Pattern (matches M_ECSManager):
- Components/Systems search parent hierarchy for node with get_store() method
- Fall back to scene tree group "state_store"
- Use duck-typing via has_method("dispatch") check

Integration Points:
- M_ECSManager subscribes to store state changes
- Systems can dispatch actions via get_store().dispatch()
- Components can select state via get_store().select()
- Store middleware can trigger ECS system updates
```

#### Key Classes

1. **M_StateManager** (extends Node): Core store with dispatch/subscribe/select, joins "state_store" group for discovery
2. **U_StateStoreUtils** (static class): Provides `get_store(from_node: Node)` for discovering M_StateManager in scene tree
3. **Action** (GDScript Dictionary): `{type: StringName, payload: Variant}`
4. **Reducer** (Callable): `func (state: Dictionary, action: Action) -> Dictionary`
5. **Middleware** (Callable): `func (store, next: Callable, action: Action)`
6. **Selector** (class): Memoized state reader with dependency tracking

#### File Structure

```
scripts/state/
├── store.gd                  # Core M_StateManager class
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
- Implement M_StateManager class with dispatch/subscribe
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

## Critical Design Decisions

This section documents key architectural choices that define how the M_StateManager system behaves.

### 1. Single Store Enforcement (Strict)

**Decision**: Only one M_StateManager instance allowed per scene tree. Multiple instances will self-destruct.

**Implementation**:
```gdscript
# In M_StateManager._ready()
func _ready():
	var existing = get_tree().get_nodes_in_group("state_store")
	if existing.size() > 0 and existing[0] != self:
		push_error("FATAL: Multiple M_StateManager instances detected. Only one allowed per scene tree.")
		queue_free()
		return
	add_to_group("state_store")
	_initialize_state()
```

**Rationale**: Prevents state fragmentation and developer confusion. Single source of truth.

### 2. Null Safety Policy (Fail-Fast)

**Decision**: Missing M_StateManager is a fatal error. Systems must assert store exists.

**Implementation**:
```gdscript
# In any system or component
func _ready():
	var store = U_StateStoreUtils.get_store(self)
	assert(store != null, "M_StateManager not found in scene tree. Add M_StateManager node to scene.")
	_store = store
```

**Rationale**: Catches configuration errors immediately rather than failing silently. Developers know exactly what's wrong.

### 3. State Access Performance (Safety Over Speed)

**Decision**: Always return deep copy of state via duplicate(true). Prevents accidental mutations.

**Implementation**:
```gdscript
# In M_StateManager
func get_state() -> Dictionary:
	return _state.duplicate(true)  # Deep copy for safety
```

**Performance Impact**: ~1ms for 10MB state tree. Trade-off accepted for correctness.

**Optimization**: Use select() for specific values instead of get_state() for full tree:
```gdscript
var score = store.select("game.score")  # Fast path: direct value access
```

### 4. State Structure (Normalized Redux-Style)

**Decision**: Flat state structure with entity IDs. Maximum 3-4 levels of nesting.

**Recommended Pattern**:
```gdscript
{
	"entities": {
		"players": {
			"player_1": {"health": 100, "inventory_id": "inv_1"}
		},
		"inventories": {
			"inv_1": {"items": ["item_sword", "item_shield"]}
		}
	},
	"game": {
		"score": 0,
		"level": 1
	},
	"ui": {
		"active_menu": "main"
	}
}
```

**Anti-Pattern (Avoid)**:
```gdscript
{
	"game": {
		"players": {
			"player_1": {
				"inventory": {  # Embedded instead of referenced
					"items": {
						"item_1": {  # Too deeply nested
							"properties": {"damage": 10}
						}
					}
				}
			}
		}
	}
}
```

**Rationale**: Flat structure enables fast selectors, avoids duplication, simplifies updates.

### 5. Scene Hierarchy Placement

**Decision**: M_StateManager placed in separate /Infrastructure branch, isolated from ECS and gameplay nodes.

**Scene Structure**:
```
Root
├─ Infrastructure
│  └─ M_StateManager  (joins "state_store" group)
├─ Gameplay
│  ├─ Player
│  └─ Environment
└─ Systems
   └─ M_ECSManager  (joins "ecs_manager" group)
```

**Rationale**: Clearly separates infrastructure from gameplay logic. Easy to locate and manage.

### 6. Time-Travel Debugging (Opt-In)

**Decision**: Time-travel disabled by default. Explicit opt-in required.

**Usage**:
```gdscript
# Enable time-travel for debugging session
var store = U_StateStoreUtils.get_store(self)
store.enable_time_travel(true)  # Starts recording history

# Later: step through history
store.step_backward()  # Undo last action
store.step_forward()   # Redo
```

**Memory Impact**: ~10MB for 1000 actions (configurable). Only allocate when needed.

**Rationale**: Saves memory in normal gameplay, enables powerful debugging when requested.

### 7. Testing Strategy (Integration-Style)

**Decision**: All tests use real M_StateManager instances. No mocking.

**Test Pattern**:
```gdscript
# In test_movement_system.gd
func test_score_affects_movement():
	var store = M_StateManager.new()
	add_child(store)  # Makes it discoverable

	var system = S_MovementSystem.new()
	add_child(system)

	store.dispatch(GameActions.set_score(100))
	system.process_tick(1.0)

	assert_eq(system.speed_multiplier, 1.5)  # Score boosts speed
```

**Rationale**: Integration tests catch real issues. Mocks hide integration bugs.

### 8. Persistence Control (Per-Reducer)

**Decision**: Reducers declare persistence via `.persistable` metadata property.

**Implementation**:
```gdscript
# In game_reducer.gd
static func reduce(state: Dictionary, action: Dictionary) -> Dictionary:
	# Reducer logic...
	pass

static func get_persistable() -> bool:
	return true  # This reducer's state will be saved

# In ui_reducer.gd (transient state)
static func get_persistable() -> bool:
	return false  # UI state not saved (e.g., active menu)
```

**Save/Load**:
```gdscript
# M_StateManager filters by persistable flag
store.save_state("user://savegame.json")  # Only saves persistable reducers
```

**Rationale**: Fine-grained control. Some state is session-only (UI), some persists (game progress).

### 9. Initialization Timing (Strict)

**Decision**: Calling get_store() before M_StateManager is ready is a fatal error.

**Implementation**:
```gdscript
# U_StateStoreUtils.get_store()
static func get_store(from_node: Node) -> M_StateManager:
	# Search logic...
	if store == null:
		assert(false, "M_StateManager not found. Ensure M_StateManager node exists in scene tree before accessing.")
	return store
```

**Recommendation**: Add M_StateManager to base scene template to ensure it's always present.

**Rationale**: Fail-fast catches setup errors during development, not in production.

### 10. Reducer Error Handling (Fail-Fast)

**Decision**: Errors in reducers crash the application immediately.

**Implementation**:
```gdscript
# In M_StateManager.dispatch()
func dispatch(action: Dictionary) -> void:
	var new_state = _state.duplicate(true)

	for reducer in _reducers:
		# No try/catch - let errors propagate and crash
		new_state = reducer.call(new_state, action)

	_state = new_state
	_notify_subscribers()
```

**Rationale**: Reducers must be pure and predictable. Errors indicate bugs that must be fixed immediately.

### 11. History Buffer Configuration

**Decision**: Configurable history size (default 1000 actions), only allocated when time-travel enabled.

**Configuration**:
```gdscript
store.enable_time_travel(true, max_history_size = 500)  # Reduce memory footprint
```

**Memory Calculation**:
- 100 actions: ~1MB
- 500 actions: ~5MB
- 1000 actions: ~10MB (default)

**Rationale**: Allows tuning memory usage based on debugging needs vs. constraints.

---

## Implementation Details (Batch 1 Specification)

This section provides technical implementation details for developers implementing Batch 1 (MVP).

### 1. Target Platform

**Godot Version**: 4.5 (confirmed from project.godot)
- Must be compatible with Godot 4.5 Forward Plus renderer
- Use GDScript features available in 4.5 only

### 2. Action Format

**Structure**: Standard GDScript Dictionary

```gdscript
# Action shape
{
	"type": StringName("game/add_score"),  # Action type (namespaced)
	"payload": 100  # Optional payload (any Variant)
}

# Access pattern (bracket notation required)
var action_type = action["type"]
var payload = action["payload"]

# DO NOT use dot notation (not supported on Dictionary)
# var action_type = action.type  # ✗ WRONG
```

**Rationale**: Keep it simple. No custom classes. Standard Dictionary with bracket access works everywhere.

### 3. Reducer Architecture

**Pattern**: Dictionary of slice reducers (keyed by state slice name)

**Store Structure**:
```gdscript
# In M_StateManager
var _reducers: Dictionary = {}  # Key: StringName (slice name), Value: Object (reducer)
var _state: Dictionary = {}  # Key: StringName (slice name), Value: Dictionary (slice state)
```

**Reducer Interface** (every reducer must implement):
```gdscript
# Example: game_reducer.gd
class_name GameReducer

static func get_slice_name() -> StringName:
	return "game"  # State slice key

static func get_initial_state() -> Dictionary:
	return {
		"score": 0,
		"level": 1,
		"unlocks": []
	}

static func get_persistable() -> bool:
	return true  # Save this slice to disk

static func reduce(state: Dictionary, action: Dictionary) -> Dictionary:
	match action["type"]:
		"game/add_score":
			var new_state = state.duplicate(true)
			new_state["score"] += action["payload"]
			return new_state
		"game/level_up":
			var new_state = state.duplicate(true)
			new_state["level"] += 1
			return new_state
		_:
			return state
```

**Reducer Registration** (auto-detect pattern):
```gdscript
# In M_StateManager or setup code
store.register_reducer(GameReducer)  # Calls get_slice_name() internally
store.register_reducer(UiReducer)
store.register_reducer(EcsReducer)
store.register_reducer(SessionReducer)
```

**Dispatch Logic**:
```gdscript
# In M_StateManager.dispatch()
func dispatch(action: Dictionary) -> void:
	var new_state = _state.duplicate(true)

	for slice_name in _reducers:
		var reducer = _reducers[slice_name]
		# Each reducer only sees its own slice
		new_state[slice_name] = reducer.reduce(new_state[slice_name], action)

	_state = new_state
	_state_version += 1  # Increment for memoization
	state_changed.emit(_state)  # Notify subscribers
```

**Rationale**: Clean separation of concerns. Each reducer owns its slice. Easy to implement per-reducer persistence.

### 4. State Change Notifications

**Pattern**: Godot signals with subscribe() wrapper

**Signals**:
```gdscript
# In M_StateManager
signal state_changed(state: Dictionary)
signal action_dispatched(action: Dictionary)
```

**Subscribe API** (convenience wrapper):
```gdscript
func subscribe(callback: Callable) -> Callable:
	state_changed.connect(callback)
	# Return unsubscribe function
	return func(): state_changed.disconnect(callback)

# Usage
var unsubscribe = store.subscribe(func(state):
	print("State changed: ", state["game"]["score"])
)
# Later: unsubscribe.call()
```

**Rationale**: Native Godot patterns (signals) with Redux-style subscribe API for convenience.

### 5. Selector Memoization

**Pattern**: State version counter (fast invalidation)

**Implementation**:
```gdscript
# In M_StateManager
var _state_version: int = 0  # Incremented on every dispatch

# In MemoizedSelector
class MemoizedSelector:
	var _selector_func: Callable
	var _last_version: int = -1
	var _cached_result: Variant

	func select(state: Dictionary, state_version: int) -> Variant:
		if state_version != _last_version:
			_cached_result = _selector_func.call(state)
			_last_version = state_version
		return _cached_result

# In M_StateManager.select()
func select(selector: MemoizedSelector) -> Variant:
	return selector.select(_state, _state_version)
```

**Rationale**: Version counter comparison is O(1) vs deep hash O(n). Simple and fast.

### 6. Persistence

**Checksum**: Simple hash() builtin

**Format**:
```json
{
	"checksum": 1234567890,
	"version": 1,
	"data": {
		"game": {"score": 100},
		"session": {"player_prefs": {}}
	}
}
```

**Implementation**:
```gdscript
# In persistence.gd
static func serialize_state(state: Dictionary, persistable_slices: Array[StringName]) -> String:
	# Filter to persistable slices only
	var filtered_state = {}
	for slice_name in persistable_slices:
		filtered_state[slice_name] = state[slice_name]

	var data = {"version": 1, "data": filtered_state}
	var json = JSON.stringify(data)
	var checksum = hash(json)

	var save_data = {"checksum": checksum, "version": 1, "data": filtered_state}
	return JSON.stringify(save_data)

static func deserialize_state(json_str: String) -> Dictionary:
	var parsed = JSON.parse_string(json_str)
	if parsed == null:
		push_error("Invalid JSON")
		return {}

	# Verify checksum
	var stored_checksum = parsed["checksum"]
	var data_json = JSON.stringify({"version": parsed["version"], "data": parsed["data"]})
	var computed_checksum = hash(data_json)

	if stored_checksum != computed_checksum:
		push_error("Checksum mismatch - corrupted save file")
		return {}

	return parsed["data"]
```

**Rationale**: hash() is fast, built-in, good enough for detecting corruption.

### 7. Code Style

**Indentation**: Tab characters only (project standard)
**Naming**: snake_case for functions/variables, PascalCase for classes
**Type Annotations**: Required for all public APIs

```gdscript
# Good
func dispatch(action: Dictionary) -> void:
	var new_state: Dictionary = _state.duplicate(true)
	_state_version += 1

# Bad (no types)
func dispatch(action):
	var new_state = _state.duplicate(true)
```

### 8. Testing Requirements

**Coverage**: 90%+ for scripts/state/* module

**Fail-Fast Testing**: Must test error paths
- Test U_StateStoreUtils.get_store() asserts when store missing
- Test reducer errors crash application
- Test multiple M_StateManager instances self-destruct

**Test Pattern**:
```gdscript
extends GutTest

func test_missing_store_crashes():
	# Create node tree without M_StateManager
	var node = Node.new()
	add_child(node)

	# Expect assertion failure
	# (GUT provides assert_signal_emitted or similar)
	# This will crash in production, validate in test environment
```

**Batch 1 Scope**: Core store + persistence + selectors + tests ONLY
- Stop after Batch 1 is green
- Review before proceeding to Batch 2

---

## Risks & Mitigation

### Risk 1: Performance Overhead

- **Impact**: Store dispatch adds latency to 60fps game loop
- **Mitigation**:
  - Profile early and often
  - Use object pooling for actions
  - Batch updates where possible
  - Defer non-critical updates to idle frames

### Risk 2: Migration Complexity

- **Impact**: Integrating with existing M_ECSManager could break working systems
- **Mitigation**:
  - Hybrid approach preserves M_ECSManager
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
✓ **Technically feasible**: Similar to existing M_ECSManager pattern, proven Redux architecture

---

## Example Usage

### Dispatching Actions

```gdscript
# From any system, component, or UI node
var store = U_StateStoreUtils.get_store(self)

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
var store = U_StateStoreUtils.get_store(self)

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
var store = U_StateStoreUtils.get_store(self)

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
