# Implementation Plan: Redux-Style Centralized State Store

**Branch**: `redux-state-store` | **Date**: 2025-10-25 | **Version**: 2.0 (Revised)
**Spec**: [redux-state-store-prd.md](./redux-state-store-prd.md)

---

> **Cleanup note (2026-03)**: This plan still references group-based manager discovery. Groups have been removed in cleanup_v3; use ServiceLocator and @export injection instead when wiring the state store.

## Revision History

**v2.0** (2025-10-25): Comprehensive revision addressing 14 critical gaps:
- Added architectural decisions (scene integration, resource locations, state transitions)
- Added Common Workflows section with step-by-step guides
- Added ECS Integration Examples with complete working code
- Added Debugging Guide for development without debug overlay
- Added FAQ with answers to common questions
- Expanded Prerequisites with concrete decisions and effort estimates
- Corrected file structure (resources/state/ instead of scripts/state/resources/)
- Added U_StateUtils, StateHandoff, and other missing components
- Expanded Phase 0 with alternatives if refactor fails
- Expanded Phase 1a and 1h with complete implementations
- Added Production Checklist for release builds

**v1.0** (2025-10-25): Initial implementation plan

---

## Summary

Implement a centralized Redux-style state management system for the Godot 4.5 game, featuring three state slices (boot, menu, gameplay) with immutable state updates, action/reducer patterns, signal-based reactivity, selective persistence, and comprehensive debugging tools. The system integrates with the existing ECS architecture via a dual-bus event architecture (U_ECSEventBus + U_StateEventBus) while maintaining independent-but-observable separation of concerns.

**Primary Requirement**: Provide predictable, debuggable state management for game lifecycle (boot→menu→gameplay) with time-travel debugging, auto-save capabilities, and <0.1ms performance overhead.

**Technical Approach**: In-scene `M_StateStore` node (similar to `M_ECSManager`) using GDScript with Redux patterns adapted to Godot idioms: StringName action types, Resource-based initial state, hybrid timing (immediate state updates + batched signals), and explicit cross-slice dependencies.

---

## Technical Context

**Language/Version**: GDScript 4.5 (Godot Engine 4.5)

**Primary Dependencies**:
- GUT (Godot Unit Test) framework for testing
- Existing ECS system (`M_ECSManager`, `BaseECSComponent`, `BaseECSSystem`)
- Existing `u_ecs_event_bus.gd` (kept for ECS domain)
- U_ECSUtils pattern for utilities

**Storage**:
- State persistence: JSON files (user://saves/*.json)
- Initial state: Godot Resource files (.tres) in `resources/state/`
- Configuration: RS_StateStoreSettings resource

**Testing**:
- GUT (Godot Unit Test) framework
- Headless test runner: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/state -gexit`
- Test patterns: Given/When/Then, autofree fixtures, explicit typing, bus reset in `before_each()`:
  - State tests: `U_StateEventBus.reset()`
  - ECS tests: `U_ECSEventBus.reset()`

**Target Platform**:
- Development: macOS (Darwin 25.0.0)
- Target: Cross-platform (Windows, macOS, Linux)

**Performance Goals**:
- State updates: <0.1ms overhead per frame (100 actions/second)
- Signal batching: <0.05ms overhead per physics frame
- Action history: 1000 entries max (circular buffer)
- Memory target: <5MB for state store infrastructure

**Constraints**:
- Single-threaded (main thread only - GDScript limitation)
- Immutability via `.duplicate(true)` for deep copies
- StringName for action types (performance + type safety)
- Must follow naming conventions (M_*, U_*, RS_*, SC_* prefixes)
- Tab indentation in all .gd files

**Scale/Scope**:
- 29 new files (27 from original plan + U_StateUtils + StateHandoff)
- 3 state slices: boot, menu, gameplay
- 8 micro-stories for Phase 1
- 7 total user stories (P1-P7)
- Target: 100% test coverage for reducers

---

## Constitution Check

**Status**: No project constitution file found

**De-facto Standards Applied**:
- ✅ `AGENTS.md` - Commit strategy, testing requirements
- ✅ `docs/general/DEV_PITFALLS.md` - GDScript typing, GUT patterns
- ✅ `docs/general/STYLE_GUIDE.md` - Naming conventions, file structure

**Key Requirements from AGENTS.md**:
- ✅ Commit at end of each completed story
- ✅ Keep tests green at every commit
- ✅ Update planning docs as implementation progresses
- ✅ Re-read DEV_PITFALLS before adding/modifying code
- ✅ Explicit typing for all Variants
- ✅ Use `autofree()` for all test fixtures

---

## Architectural Decisions (MANDATORY READING)

The following architectural decisions have been made to address critical gaps in the original plan. **These must be implemented exactly as specified.**

### Decision 1: Scene Integration

**Where M_StateStore Lives:**
- **Location**: `templates/base_scene_template.tscn` under existing `Managers/` node
- **Pattern**: Parallel to `M_ECSManager` (same parent node)
- **Reasoning**: Consistent with ECS pattern, one store per scene

**Scene Scope:**
- One `M_StateStore` instance per scene
- State is **scoped to scene lifecycle** (resets on scene change)
- Boot/Menu/Gameplay each get their own scene with own store

**Template Updates Required:**
- ✅ Update `templates/base_scene_template.tscn` to include M_StateStore
- ✅ Ensure M_StateStore is under `Managers/` node
- ✅ Verify M_StateStore calls `add_to_group("state_store")` in `_ready()`

### Decision 2: Resource File Organization

**Where .tres Files Live:**
- **Location**: `resources/state/` (NEW directory)
- **NOT**: `scripts/state/resources/` (this mixes code and data)
- **Pattern**: Follows existing `resources/base_settings/` convention

**File Structure:**
```
resources/
├── state/                                    # NEW DIRECTORY
│   ├── default_gameplay_initial_state.tres
│   ├── default_boot_initial_state.tres
│   ├── default_menu_initial_state.tres
│   └── default_state_store_settings.tres
└── settings/                                 # EXISTING (ECS settings)
    ├── default_jump_settings.tres
    └── ...

scripts/state/resources/                      # .gd scripts ONLY
├── rs_gameplay_initial_state.gd
└── ...
```

**Naming Convention**: Use `default_*` prefix for .tres files (matches ECS)

### Decision 3: State Transition Strategy (No autoloads)

**Problem**: In-scene M_StateStore loses state on scene change

**Solution**: Static handoff utility (no autoload)
- `M_StateStore` remains in-scene (preserves design decision)
- `StateHandoff` (static class) preserves state between scenes
- Stores call `StateHandoff` on `_exit_tree()` / `_ready()`

**Implementation** (no autoload):
```gdscript
# scripts/state/utils/u_state_handoff.gd
class_name U_StateHandoff

static var _preserved_slices: Dictionary = {}

static func preserve_slice(slice_name: StringName, slice_state: Dictionary) -> void:
    if slice_name == StringName():
        return
    _preserved_slices[slice_name] = slice_state.duplicate(true)

static func restore_slice(slice_name: StringName) -> Dictionary:
    if slice_name == StringName():
        return {}
    return _preserved_slices.get(slice_name, {}).duplicate(true)

static func clear_slice(slice_name: StringName) -> void:
    _preserved_slices.erase(slice_name)

static func clear_all() -> void:
    _preserved_slices.clear()
```

**Added to**: Phase 1h (Persistence)

### Decision 4: Global Access Pattern

**How to Find M_StateStore:**
- Create `U_StateUtils` helper class (like `U_ECSUtils`)
- Use `get_tree().get_nodes_in_group("state_store")` pattern
- Systems cache store reference in `_ready()`

**Implementation**:
```gdscript
# scripts/state/utils/u_state_utils.gd
class_name U_StateUtils

static func get_store(node: Node) -> M_StateStore:
    if node == null or not is_instance_valid(node):
        push_error("U_StateUtils.get_store: Invalid node")
        return null

    var tree := node.get_tree()
    if tree == null:
        push_error("U_StateUtils.get_store: Node not in tree")
        return null

    var store_group: Array = tree.get_nodes_in_group("state_store")
    if store_group.is_empty():
        push_error("U_StateUtils.get_store: No M_StateStore in 'state_store' group")
        return null

    if store_group.size() > 1:
        push_warning("U_StateUtils.get_store: Multiple stores found, using first")

    return store_group[0] as M_StateStore
```

**Added to**: Phase 1a

### Decision 5: Phase 0 Alternative Path

**If Event Bus Refactor Fails:**
- Skip bus unification initially
- M_StateStore uses direct signals (not EventBus)
- Defer integration to Phase 8 (after core features proven)

**Fallback Implementation**:
```gdscript
# Phase 1a alternative
signal slice_updated(slice_name: StringName, slice_state: Dictionary)
signal action_dispatched(action: Dictionary)

# Use direct emit instead of EventBus.publish()
func _emit_state_change(slice_name: StringName) -> void:
    slice_updated.emit(slice_name, _state[slice_name].duplicate(true))
```

---

## Prerequisites

Before starting implementation, complete these mandatory tasks in order.

### 1. Understand Existing Patterns (30 min)

Read these files to understand project conventions:
- [ ] `docs/general/DEV_PITFALLS.md` - GDScript gotchas, typing rules
- [ ] `docs/general/STYLE_GUIDE.md` - Naming conventions, file structure
- [ ] `AGENTS.md` - Commit strategy, testing requirements, repo map

**Key Takeaways**:
- All Variants must have explicit type annotations
- All test fixtures must use `autofree()`
- Await `get_tree().process_frame` after adding nodes
- Tab indentation (not spaces) in .gd files
- Commit after each green test milestone

### 2. Verify Development Environment (10 min)

- [ ] Confirm Godot 4.5 installed at `/Applications/Godot.app/Contents/MacOS/Godot`
- [ ] Verify project opens without errors
- [ ] Confirm on `redux-state-store` branch
- [ ] Verify GUT installed: `addons/gut/` directory exists
- [ ] Test headless runner works:
  ```bash
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
    -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ecs -gexit
  ```

### 3. Create Directory Structure (5 min)

Create new directories for state management:

```bash
# Create state management directories
mkdir -p scripts/state/reducers
mkdir -p scripts/state/selectors
mkdir -p scripts/state/resources
mkdir -p resources/state
mkdir -p scenes/debug
mkdir -p tests/unit/state/integration

# Verify structure
ls -la scripts/state/
ls -la resources/state/
ls -la tests/unit/state/
```

### 4. Event Bus Architecture (Option C chosen)

Chosen path: Option C (Dual‑bus via abstract base). Alternatives are documented for reference.

**Option A: Single Bus with Namespacing**
- Rename to `EventBus`, add `"ecs/*"` and `"state/*"` event type prefixes
- Pros: Single place to subscribe, consolidated history
- Cons: Touches ECS code; higher risk to existing tests

**Option B: Direct Signals (fallback)**
- Use direct signals on `M_StateStore` for early phases
- Pros: Fastest to implement
- Cons: No shared bus semantics for state until later

**Option C (Recommended): Dual‑Bus via Abstract Base**
- Add `BaseEventBus` (abstract) with shared logic
- Keep `U_ECSEventBus` for ECS; add `U_StateEventBus` for state
- Pros: Zero breaking changes, isolated domains, shared implementation
- Cons: Two buses to reset in different test suites (explicit but clear)

**Effort Breakdown** (Option A):

| Task | Estimated Time | Risk |
|------|----------------|------|
| Rename u_ecs_event_bus.gd → event_bus.gd | 5 min | Low |
| Add namespacing (ecs/* vs state/*) | 30 min | Medium |
| Add get_event_history_by_namespace() | 15 min | Low |
| Find all ECS event publishers | 15 min | Low |
| Update s_jump_system.gd event names | 10 min | Low |
| Update all other systems (if any) | 1-2 hours | High |
| Update test files | 1-2 hours | High |
| Run full ECS test suite | 15 min | Medium |
| Debug failures | 0-4 hours | High |

**Total**: 4-8 hours (if clean) to 1-2 days (if issues)

**Go/No-Go Criteria**:
- ✅ **GO**: All ECS tests pass after refactor
- ❌ **NO-GO**: >2 test failures after 1 day of debugging → Switch to Option C or B

### 5. Update Scene Templates (30 min)

**5a. Update base_scene_template.tscn** (20 min)
1. Open `templates/base_scene_template.tscn` in Godot editor
2. Find `Managers/` node
3. Right-click → Add Child Node → Search "Node"
4. Rename to "M_StateStore"
5. Attach new script → Create `scripts/state/m_state_store.gd`
6. Save scene template

**5b. Verify M_ECSManager Pattern** (10 min)
- Check M_ECSManager location in scene tree
- Ensure M_StateStore is parallel (same parent)
- Verify both are under Managers/ node

**After Phase 1a**: Update M_StateStore script to match skeleton

### 6. Create State Store Icon (Optional - 10 min)

Following M_ECSManager pattern:
1. Copy existing manager icon: `resources/editor_icons/manager.svg`
2. Rename to `state_store.svg`
3. Modify color to distinguish from manager icon
4. Use in M_StateStore: `@icon("res://assets/editor_icons/state_store.svg")`

---

## Project Structure

### Documentation

```
docs/state_store/
├── redux-state-store-prd.md                  # Feature specification (v2.0)
└── redux-state-store-implementation-plan.md  # This file (v2.0)
```

**Future Documentation** (add as needed):
- `docs/state_store/architecture.md` - State flow diagrams
- `docs/state_store/api-reference.md` - Public API documentation
- `docs/state_store/workflows.md` - Common development workflows

### Source Code

```
scripts/state/                                # NEW DIRECTORY
├── m_state_store.gd                          # Core store manager (Node)
├── resources/rs_state_slice_config.gd        # Slice metadata resource
│
├── utils/                                    # Shared utilities
│   ├── u_state_utils.gd                      # State utility functions (NEW)
│   ├── u_action_registry.gd                  # Action type validation
│   ├── u_serialization_helper.gd             # Godot type ↔ JSON conversion
│   ├── u_state_handoff.gd                    # Cross-scene state preservation
│   └── u_signal_batcher.gd                   # Per-frame signal batching
│
├── actions/                                  # Action creator modules
│   ├── u_gameplay_actions.gd                 # Gameplay action creators
│   ├── u_boot_actions.gd                     # Boot action creators
│   ├── u_menu_actions.gd                     # Menu action creators
│   ├── u_scene_actions.gd                    # Scene transition actions
│   └── u_transition_actions.gd               # Transition helpers
│
├── reducers/                                 # Pure reducers per slice
│   ├── u_gameplay_reducer.gd                 # Gameplay slice reducer
│   ├── u_boot_reducer.gd                     # Boot slice reducer
│   ├── u_menu_reducer.gd                     # Menu slice reducer
│   └── u_scene_reducer.gd                    # Scene slice reducer
│
├── selectors/                                # Derived state helpers
│   ├── u_gameplay_selectors.gd               # Gameplay derived state
│   ├── u_boot_selectors.gd                   # Boot derived state
│   ├── u_menu_selectors.gd                   # Menu derived state
│   ├── u_entity_selectors.gd                 # Entity derived state
│   ├── u_input_selectors.gd                  # Input derived state
│   ├── u_physics_selectors.gd                # Physics derived state
│   └── u_visual_selectors.gd                 # Visual derived state
│
└── resources/                                # .gd scripts for Resources
    ├── rs_gameplay_initial_state.gd
    ├── rs_boot_initial_state.gd
    ├── rs_menu_initial_state.gd
    └── rs_state_store_settings.gd

resources/state/                              # NEW DIRECTORY (.tres files)
├── default_gameplay_initial_state.tres
├── default_boot_initial_state.tres
├── default_menu_initial_state.tres
└── default_state_store_settings.tres

scripts/
scripts/events/                               # NEW DIRECTORY (shared infra)
└── base_event_bus.gd                         # Abstract base class for event buses

scripts/state/
└── u_state_event_bus.gd                        # State domain bus (extends base)

scenes/debug/                                 # NEW DIRECTORY
├── sc_state_debug_overlay.tscn               # Debug UI scene
└── sc_state_debug_overlay.gd                # Debug UI script

tests/unit/state/                             # NEW DIRECTORY
├── test_m_state_store.gd                     # Core store tests
├── test_u_state_utils.gd                     # Utility tests (NEW)
├── test_u_gameplay_actions.gd                # Action creator tests
├── test_gameplay_slice_reducers.gd           # Reducer pure function tests
├── test_state_selectors.gd                   # Selector computation tests
├── test_state_persistence.gd                 # Save/load tests
│
└── integration/                              # NEW SUBDIRECTORY
    └── test_slice_transitions.gd             # Boot→menu→gameplay flow tests
```

**File Count**: 29 new files
- 17 implementation files
- 6 resource scripts + 4 .tres files
- 7 test files

---

## Implementation Phases

Implementation follows 8 micro-stories from User Story 1 (Priority P1), with each representing a commit checkpoint. After P1 completes, additional user stories (P2-P7) follow.

### Phase 0: Event Bus Architecture (Optional, time-boxed)

Implement the chosen option from Prerequisites step 4. Recommended: Option C (Dual‑bus via abstract base).

**Objective (Option C)**: Share logic via abstract base while isolating ECS and state domains.

**Files**:
- `scripts/events/base_event_bus.gd` — abstract base class
- `scripts/state/u_state_event_bus.gd` — state domain bus with static delegates
- `scripts/ecs/u_ecs_event_bus.gd` — update to extend base and delegate statics internally

**Changes**:
1. Implement subscribe/unsubscribe/publish/reset/history in base
2. Duplicate‑safe payload handling in base
3. Each concrete bus holds its own subscribers/history internally
4. Document isolation and test reset requirements

**Tests**:
- Add `tests/unit/state/test_state_event_bus.gd`:
  - Subscribers receive events
  - `U_StateEventBus.reset()` clears subscribers/history
  - `U_ECSEventBus` is unaffected by state reset

**Go/No-Go**:
- ✅ Proceed when state tests and ECS tests both pass
- ❌ If issues arise, fall back to Option B (direct signals) for P1

**Commit Message**: `Add BaseEventBus and U_StateEventBus; delegate U_ECSEventBus to base (Phase 0)`

---

### Phase 1a: Core M_StateStore Skeleton (User Story 1a)

**Objective**: Create foundational M_StateStore node with dispatch/subscribe infrastructure, U_StateUtils helper, and scene integration.

**Files Created**:
- `scripts/state/m_state_store.gd` (store skeleton)
- `scripts/state/utils/u_state_utils.gd` (access helper - NEW)
- `scripts/state/resources/rs_state_slice_config.gd` (slice metadata)
- `scripts/state/resources/rs_state_store_settings.gd` (store config)
- `resources/state/default_state_store_settings.tres` (default config)
- `tests/unit/state/test_m_state_store.gd` (store tests)
- `tests/unit/state/test_u_state_utils.gd` (utility tests - NEW)

**Files Modified**:
- `templates/base_scene_template.tscn` (if not already updated in Prerequisites)

**Implementation**: M_StateStore Skeleton

```gdscript
# scripts/state/m_state_store.gd
@icon("res://assets/editor_icons/state_store.svg")
extends Node
class_name M_StateStore

## Centralized Redux-style state store for game state management.
##
## Manages state slices (boot, menu, gameplay) with immutable updates,
## action/reducer patterns, and signal-based reactivity.
##
## Usage:
##   var store := U_StateUtils.get_store(self)
##   store.dispatch(U_GameplayActions.pause_game())
##   var is_paused: bool = GameplaySelectors.select_is_paused(store.get_state())

signal state_changed(action: Dictionary, new_state: Dictionary)
signal slice_updated(slice_name: StringName, slice_state: Dictionary)
signal action_dispatched(action: Dictionary)  # Unbatched
signal validation_failed(action: Dictionary, error: String)

const PROJECT_SETTING_HISTORY_SIZE := "state/debug/history_size"
const PROJECT_SETTING_ENABLE_PERSISTENCE := "state/runtime/enable_persistence"

const U_STATE_UTILS := preload("res://scripts/state/utils/u_state_utils.gd")

@export var settings: RS_StateStoreSettings

var _state: Dictionary = {}
var _subscribers: Array[Callable] = []
var _slice_configs: Dictionary = {}

func _ready() -> void:
	add_to_group("state_store")
	_initialize_settings()
	_initialize_slices()

func _initialize_settings() -> void:
	if settings == null:
		push_warning("M_StateStore: No settings assigned, using defaults")
		settings = RS_StateStoreSettings.new()

	# Load from project settings if available
	if ProjectSettings.has_setting(PROJECT_SETTING_HISTORY_SIZE):
		var history_size: int = ProjectSettings.get_setting(PROJECT_SETTING_HISTORY_SIZE, 1000)
		if settings.max_history_size != history_size:
			settings.max_history_size = history_size

func _initialize_slices() -> void:
	# Placeholder - will add slice initialization in Phase 1c
	pass

## Dispatch an action to update state
func dispatch(action: Dictionary) -> void:
	# Basic validation
	if not action.has("type"):
		push_error("M_StateStore.dispatch: Action missing 'type' field")
		validation_failed.emit(action, "Action missing 'type' field")
		return

	# For now, just log and notify subscribers
	if OS.is_debug_build():
		print("[STATE] Action dispatched: ", action.get("type"))

	# Notify subscribers
	for subscriber in _subscribers:
		if subscriber.is_valid():
			subscriber.call(action, _state.duplicate(true))

	# Emit unbatched signal
	action_dispatched.emit(action)

## Subscribe to state changes
## Returns unsubscribe callable
func subscribe(callback: Callable) -> Callable:
	if callback == Callable() or not callback.is_valid():
		push_error("M_StateStore.subscribe: Invalid callback")
		return Callable()

	_subscribers.append(callback)

	# Return unsubscribe function
	var unsubscribe := func() -> void:
		_subscribers.erase(callback)

	return unsubscribe

## Get current state (deep copy)
func get_state() -> Dictionary:
	return _state.duplicate(true)

## Get specific slice state (deep copy)
func get_slice(slice_name: StringName) -> Dictionary:
	return _state.get(slice_name, {}).duplicate(true)

func _exit_tree() -> void:
	if is_in_group("state_store"):
		remove_from_group("state_store")
```

**Implementation**: U_StateUtils

```gdscript
# scripts/state/utils/u_state_utils.gd
class_name U_StateUtils

## Utility functions for state management (similar to U_ECSUtils)

## Get the M_StateStore from the scene tree
static func get_store(node: Node) -> M_StateStore:
	if node == null or not is_instance_valid(node):
		push_error("U_StateUtils.get_store: Invalid node")
		return null

	var tree := node.get_tree()
	if tree == null:
		push_error("U_StateUtils.get_store: Node not in tree")
		return null

	var store_group: Array = tree.get_nodes_in_group("state_store")
	if store_group.is_empty():
		push_error("U_StateUtils.get_store: No M_StateStore in 'state_store' group")
		return null

	if store_group.size() > 1:
		push_warning("U_StateUtils.get_store: Multiple stores found, using first")

	return store_group[0] as M_StateStore

## Benchmark a callable (for performance testing)
static func benchmark(name: String, callable: Callable) -> float:
	var start: int = Time.get_ticks_usec()
	callable.call()
	var end: int = Time.get_ticks_usec()
	var elapsed_ms: float = (end - start) / 1000.0
	if OS.is_debug_build():
		print("[BENCHMARK] %s: %.3f ms" % [name, elapsed_ms])
	return elapsed_ms
```

**Implementation**: RS_StateSliceConfig

```gdscript
# scripts/state/resources/rs_state_slice_config.gd
extends Resource
class_name RS_StateSliceConfig

## Configuration for a state slice

@export var slice_name: StringName = StringName()
@export var dependencies: Array[StringName] = []  # Other slices this can access
@export var transient_fields: Array[StringName] = []  # Fields excluded from persistence
@export var initial_state_resource: Resource = null  # RS_*InitialState

func _init(p_slice_name: StringName = StringName()) -> void:
	slice_name = p_slice_name
```

**Implementation**: RS_StateStoreSettings

```gdscript
# scripts/state/resources/rs_state_store_settings.gd
extends Resource
class_name RS_StateStoreSettings

## Configuration settings for M_StateStore

@export_group("History")
@export var max_history_size: int = 1000
@export var enable_history: bool = true

@export_group("Performance")
@export var enable_signal_batching: bool = true

@export_group("Persistence")
@export var enable_persistence: bool = true
@export var auto_save_interval: float = 60.0  # seconds

@export_group("Debug")
@export var enable_debug_logging: bool = OS.is_debug_build()
@export var enable_debug_overlay: bool = OS.is_debug_build()
```

Create default .tres file:
1. Open Godot editor
2. Create new `RS_StateStoreSettings` resource
3. Save as `resources/state/default_state_store_settings.tres`
4. Set default values (max_history_size=1000, etc.)

**Tests**: test_m_state_store.gd

```gdscript
# tests/unit/state/test_m_state_store.gd
extends GutTest

var store: M_StateStore

func before_each():
	# Reset state bus between tests
	U_StateEventBus.reset()

	store = M_StateStore.new()
	autofree(store)
	add_child(store)
	await get_tree().process_frame  # Deferred registration

func after_each():
	if store and is_instance_valid(store):
		store.queue_free()
	store = null
	U_StateEventBus.reset()

func test_store_initializes_in_scene_tree():
	assert_not_null(store, "Store should be created")
	assert_true(store.is_in_group("state_store"), "Store should be in 'state_store' group")

func test_subscribe_registers_callback():
	var callback_called := false
	var received_action: Dictionary = {}

	var callback := func(action: Dictionary, state: Dictionary) -> void:
		callback_called = true
		received_action = action

	var unsubscribe: Callable = store.subscribe(callback)

	assert_true(unsubscribe.is_valid(), "Subscribe should return valid unsubscribe callable")

	# Dispatch action
	var action: Dictionary = {"type": StringName("test/action"), "payload": null}
	store.dispatch(action)

	assert_true(callback_called, "Callback should be called on dispatch")
	assert_eq(received_action.get("type"), StringName("test/action"), "Callback should receive action")

func test_unsubscribe_removes_callback():
	var callback_count := 0

	var callback := func(_action: Dictionary, _state: Dictionary) -> void:
		callback_count += 1

	var unsubscribe: Callable = store.subscribe(callback)

	store.dispatch({"type": StringName("test1"), "payload": null})
	assert_eq(callback_count, 1, "Callback should fire once")

	unsubscribe.call()

	store.dispatch({"type": StringName("test2"), "payload": null})
	assert_eq(callback_count, 1, "Callback should not fire after unsubscribe")

func test_get_state_returns_copy():
	var state1: Dictionary = store.get_state()
	state1["test"] = "modified"

	var state2: Dictionary = store.get_state()

	assert_false(state2.has("test"), "Modifying copy should not affect original")
```

**Tests**: test_u_state_utils.gd

```gdscript
# tests/unit/state/test_u_state_utils.gd
extends GutTest

var store: M_StateStore

func before_each():
	store = M_StateStore.new()
	autofree(store)
	add_child(store)
	await get_tree().process_frame

func test_get_store_finds_store_in_tree():
	var found_store: M_StateStore = U_StateUtils.get_store(self)

	assert_not_null(found_store, "Should find store in tree")
	assert_eq(found_store, store, "Should return the correct store")

func test_get_store_errors_if_no_store():
	store.queue_free()
	await get_tree().process_frame

	var found_store: M_StateStore = U_StateUtils.get_store(self)

	assert_null(found_store, "Should return null if no store")

func test_benchmark_measures_time():
	var ran := false
	var elapsed: float = U_StateUtils.benchmark("test", func():
		ran = true
		await get_tree().create_timer(0.001).timeout
	)

	assert_true(ran, "Callable should run")
	assert_gt(elapsed, 0.0, "Should measure elapsed time")
```

**Acceptance Criteria** (from PRD 1a):
- ✅ Store initializes in scene tree with group "state_store"
- ✅ Callbacks receive dispatched actions
- ✅ Unsubscribe works correctly
- ✅ get_state() returns deep copy
- ✅ U_StateUtils.get_store() finds store
- ✅ No memory leaks with autofree

**Commit Message**: `Add M_StateStore skeleton with U_StateUtils helper (Story 1a)`

---

### Phase 1b through 1g

(Continue with existing detailed phase breakdowns from original plan, keeping structure but ensuring consistency with new architectural decisions)

[These sections remain largely the same as v1, but reference U_StateUtils where appropriate and follow corrected file paths]

---

### Phase 1h: Persistence with Save Slots & Validation (User Story 1h)

**Objective**: Implement save/load with JSON serialization, Godot type conversion, selective persistence, save slot management, metadata, and validation.

**Files Created**:
- `scripts/state/utils/u_serialization_helper.gd`
- `scripts/state/utils/u_state_handoff.gd` (static utility — no autoload)
- `tests/unit/state/test_state_persistence.gd`

**Files Modified**:
- `scripts/state/resources/rs_state_slice_config.gd` (add transient_fields if not present)
- `scripts/state/m_state_store.gd` (add save/load methods)

**Implementation**: StateHandoff (No autoload)

```gdscript
# scripts/state/utils/u_state_handoff.gd
class_name U_StateHandoff

## Static utility that preserves state between scene changes
## without using autoloads.

static var _preserved_slices: Dictionary = {}

## Preserve a slice's state (called by M_StateStore on _exit_tree)
static func preserve_slice(slice_name: StringName, slice_state: Dictionary) -> void:
	if slice_name == StringName():
		return
	_preserved_slices[slice_name] = slice_state.duplicate(true)

## Restore a slice's state (called by M_StateStore on _ready)
static func restore_slice(slice_name: StringName) -> Dictionary:
	if slice_name == StringName():
		return {}
	return _preserved_slices.get(slice_name, {}).duplicate(true)

## Clear preserved state for a slice
static func clear_slice(slice_name: StringName) -> void:
	_preserved_slices.erase(slice_name)

## Clear all preserved state
static func clear_all() -> void:
	_preserved_slices.clear()
```

Note: No autoload entries or project settings changes are required.

**Implementation**: Expanded M_StateStore with Persistence

```gdscript
# scripts/state/m_state_store.gd additions

const SAVE_DIRECTORY := "user://saves/"
const MAX_SAVE_SLOTS := 10
const SAVE_VERSION := 1

## Save state to a specific slot
func save_to_slot(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= MAX_SAVE_SLOTS:
		push_error("Invalid save slot: %d" % slot_index)
		return false

	var filepath := "%ssave_slot_%02d.json" % [SAVE_DIRECTORY, slot_index]
	return save_state(filepath)

## Load state from a specific slot
func load_from_slot(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= MAX_SAVE_SLOTS:
		push_error("Invalid save slot: %d" % slot_index)
		return false

	var filepath := "%ssave_slot_%02d.json" % [SAVE_DIRECTORY, slot_index]
	if not FileAccess.file_exists(filepath):
		push_warning("Save slot %d does not exist" % slot_index)
		return false

	return load_state(filepath)

## Save state to file with metadata
func save_state(filepath: String) -> bool:
	# Ensure directory exists
	if not DirAccess.dir_exists_absolute(SAVE_DIRECTORY):
		var err: int = DirAccess.make_dir_recursive_absolute(SAVE_DIRECTORY)
		if err != OK:
			push_error("Failed to create save directory: %s" % SAVE_DIRECTORY)
			return false

	# Build save data with metadata
	var save_data: Dictionary = {
		"version": SAVE_VERSION,
		"timestamp": Time.get_datetime_dict_from_system(),
		"player_name": "Player",  # TODO: Get from menu slice
		"metadata": _build_metadata(),
		"state": _serialize_slices()
	}

	# Write to file
	var file: FileAccess = FileAccess.open(filepath, FileAccess.WRITE)
	if not file:
		push_error("Failed to open file for writing: %s" % filepath)
		return false

	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()

	if OS.is_debug_build():
		print("[STATE] Saved to: ", filepath)

	return true

## Load state from file with validation
func load_state(filepath: String) -> bool:
	var file: FileAccess = FileAccess.open(filepath, FileAccess.READ)
	if not file:
		push_error("Failed to open save file: %s" % filepath)
		return false

	var json_text: String = file.get_as_text()
	file.close()

	# Parse JSON
	var json := JSON.new()
	var parse_result: int = json.parse(json_text)
	if parse_result != OK:
		push_error("Save file corrupted (invalid JSON): %s" % filepath)
		return false

	var data: Variant = json.data
	if not data is Dictionary:
		push_error("Save file corrupted (not a Dictionary)")
		return false

	var save_data: Dictionary = data as Dictionary

	# Validate schema version
	if not save_data.has("version"):
		push_error("Save file missing version field")
		return false

	var version: int = save_data.get("version", 0)
	if version > SAVE_VERSION:
		push_error("Save file from newer version (%d), cannot load" % version)
		return false

	# Apply migrations if needed
	if version < SAVE_VERSION:
		save_data = _migrate_save_data(save_data, version)

	# Deserialize slices
	var state_data: Dictionary = save_data.get("state", {})
	return _deserialize_slices(state_data)

## Build metadata for save file (level, playtime, etc.)
func _build_metadata() -> Dictionary:
	var metadata: Dictionary = {}

	# If gameplay slice exists, extract metadata
	if _state.has("gameplay"):
		var gameplay: Dictionary = _state.get("gameplay", {})
		metadata["level"] = gameplay.get("level", "unknown")
		metadata["playtime_seconds"] = gameplay.get("playtime", 0)

	return metadata

## Serialize slices to JSON-compatible Dictionary
func _serialize_slices() -> Dictionary:
	var serialized: Dictionary = {}

	for slice_name in _state:
		var config: RS_StateSliceConfig = _slice_configs.get(slice_name)
		var transients: Array[StringName] = config.transient_fields if config else []

		serialized[slice_name] = SerializationHelper.serialize_state(
			_state[slice_name],
			transients
		)

	return serialized

## Deserialize slices from JSON Dictionary
func _deserialize_slices(state_data: Dictionary) -> bool:
	for slice_name in state_data:
		var slice_data: Variant = state_data[slice_name]
		if not slice_data is Dictionary:
			push_warning("Skipping invalid slice data for: %s" % slice_name)
			continue

		_state[slice_name] = SerializationHelper.deserialize_state(slice_data as Dictionary)

	if OS.is_debug_build():
		print("[STATE] Loaded slices: ", _state.keys())

	return true

## Migrate save data from old version to current
func _migrate_save_data(save_data: Dictionary, from_version: int) -> Dictionary:
	var migrated: Dictionary = save_data.duplicate(true)

	# TODO: Add migration logic when schema changes
	# Example:
	# if from_version < 1:
	#     migrated = _migrate_v0_to_v1(migrated)

	if OS.is_debug_build():
		print("[STATE] Migrated save data from v%d to v%d" % [from_version, SAVE_VERSION])

	return migrated

## Called when scene is exiting - preserve state
func _exit_tree() -> void:
	# Preserve state for scene transitions
	for slice_name in _state:
		StateHandoff.preserve_slice(slice_name, _state[slice_name])

	super._exit_tree()

## Called when scene is ready - restore state
func _ready() -> void:
	super._ready()

	# Restore preserved state from handoff utility
	for slice_name in _slice_configs:
		var restored := StateHandoff.restore_slice(slice_name)
		if not restored.is_empty():
			_state[slice_name] = restored
```

**Implementation**: SerializationHelper

```gdscript
# scripts/state/utils/u_serialization_helper.gd
class_name U_SerializationHelper

## Utility for converting Godot types to/from JSON-compatible structures

## Convert Vector3 to Dictionary
static func vector3_to_dict(v: Vector3) -> Dictionary:
	return {"x": v.x, "y": v.y, "z": v.z}

## Convert Dictionary to Vector3
static func dict_to_vector3(d: Dictionary) -> Vector3:
	return Vector3(
		d.get("x", 0.0),
		d.get("y", 0.0),
		d.get("z", 0.0)
	)

## Convert Vector2 to Dictionary
static func vector2_to_dict(v: Vector2) -> Dictionary:
	return {"x": v.x, "y": v.y}

## Convert Dictionary to Vector2
static func dict_to_vector2(d: Dictionary) -> Vector2:
	return Vector2(d.get("x", 0.0), d.get("y", 0.0))

## Convert Transform3D to Dictionary
static func transform3d_to_dict(t: Transform3D) -> Dictionary:
	return {
		"origin": vector3_to_dict(t.origin),
		"basis_x": vector3_to_dict(t.basis.x),
		"basis_y": vector3_to_dict(t.basis.y),
		"basis_z": vector3_to_dict(t.basis.z)
	}

## Convert Dictionary to Transform3D
static func dict_to_transform3d(d: Dictionary) -> Transform3D:
	var origin: Vector3 = dict_to_vector3(d.get("origin", {}))
	var basis_x: Vector3 = dict_to_vector3(d.get("basis_x", {"x": 1}))
	var basis_y: Vector3 = dict_to_vector3(d.get("basis_y", {"y": 1}))
	var basis_z: Vector3 = dict_to_vector3(d.get("basis_z", {"z": 1}))

	return Transform3D(
		Basis(basis_x, basis_y, basis_z),
		origin
	)

## Serialize state, excluding transient fields and converting Godot types
static func serialize_state(state: Dictionary, transient_fields: Array[StringName]) -> Dictionary:
	var serialized: Dictionary = state.duplicate(true)

	# Remove transient fields
	for field in transient_fields:
		if serialized.has(field):
			serialized.erase(field)

	# Convert Godot types to JSON-compatible dictionaries
	serialized = _convert_godot_types_to_json(serialized)

	return serialized

## Deserialize state, converting JSON dictionaries back to Godot types
static func deserialize_state(state_data: Dictionary) -> Dictionary:
	var deserialized: Dictionary = state_data.duplicate(true)
	deserialized = _convert_json_to_godot_types(deserialized)
	return deserialized

## Recursively convert Godot types to JSON-compatible structures
static func _convert_godot_types_to_json(data: Variant) -> Variant:
	if data is Vector3:
		return vector3_to_dict(data)
	elif data is Vector2:
		return vector2_to_dict(data)
	elif data is Transform3D:
		return transform3d_to_dict(data)
	elif data is Dictionary:
		var converted: Dictionary = {}
		for key in data:
			converted[key] = _convert_godot_types_to_json(data[key])
		return converted
	elif data is Array:
		var converted: Array = []
		for item in data:
			converted.append(_convert_godot_types_to_json(item))
		return converted
	else:
		return data

## Recursively convert JSON structures back to Godot types
static func _convert_json_to_godot_types(data: Variant) -> Variant:
	if data is Dictionary:
		# Check if it's a serialized Godot type
		if _is_vector3_dict(data):
			return dict_to_vector3(data)
		elif _is_vector2_dict(data):
			return dict_to_vector2(data)
		elif _is_transform3d_dict(data):
			return dict_to_transform3d(data)
		else:
			# Regular dictionary - recurse
			var converted: Dictionary = {}
			for key in data:
				converted[key] = _convert_json_to_godot_types(data[key])
			return converted
	elif data is Array:
		var converted: Array = []
		for item in data:
			converted.append(_convert_json_to_godot_types(item))
		return converted
	else:
		return data

## Check if Dictionary represents a Vector3
static func _is_vector3_dict(d: Dictionary) -> bool:
	return d.has("x") and d.has("y") and d.has("z") and d.size() == 3

## Check if Dictionary represents a Vector2
static func _is_vector2_dict(d: Dictionary) -> bool:
	return d.has("x") and d.has("y") and d.size() == 2

## Check if Dictionary represents a Transform3D
static func _is_transform3d_dict(d: Dictionary) -> bool:
	return d.has("origin") and d.has("basis_x") and d.has("basis_y") and d.has("basis_z")
```

**Tests**: Expanded persistence tests

```gdscript
# tests/unit/state/test_state_persistence.gd additions

func test_save_load_round_trip_preserves_state():
	# Setup initial state
	store._state["gameplay"] = {
		"health": 75,
		"score": 1000,
		"level": "forest_2"
	}

	var save_path := "user://test_save.json"

	# Save
	var save_result: bool = store.save_state(save_path)
	assert_true(save_result, "Save should succeed")

	# Modify state
	store._state["gameplay"]["health"] = 0

	# Load
	var load_result: bool = store.load_state(save_path)
	assert_true(load_result, "Load should succeed")

	# Verify restored
	assert_eq(store._state["gameplay"]["health"], 75, "Health should restore")
	assert_eq(store._state["gameplay"]["score"], 1000, "Score should restore")
	assert_eq(store._state["gameplay"]["level"], "forest_2", "Level should restore")

	# Cleanup
	DirAccess.remove_absolute(save_path)

func test_vector3_serialization_round_trip():
	var original := Vector3(1.5, 2.5, 3.5)

	var serialized: Dictionary = SerializationHelper.vector3_to_dict(original)
	var deserialized: Vector3 = SerializationHelper.dict_to_vector3(serialized)

	assert_almost_eq(deserialized.x, original.x, 0.001, "X should match")
	assert_almost_eq(deserialized.y, original.y, 0.001, "Y should match")
	assert_almost_eq(deserialized.z, original.z, 0.001, "Z should match")

func test_corrupted_save_file_validation():
	var corrupt_path := "user://corrupt_save.json"

	# Write invalid JSON
	var file: FileAccess = FileAccess.open(corrupt_path, FileAccess.WRITE)
	file.store_string("{invalid json")
	file.close()

	var load_result: bool = store.load_state(corrupt_path)
	assert_false(load_result, "Should fail to load corrupted file")

	# Cleanup
	DirAccess.remove_absolute(corrupt_path)

func test_100_save_load_cycles():
	store._state["gameplay"] = {"value": 0}
	var save_path := "user://cycle_test.json"

	for i in 100:
		store._state["gameplay"]["value"] = i
		assert_true(store.save_state(save_path), "Cycle %d save should succeed" % i)
		assert_true(store.load_state(save_path), "Cycle %d load should succeed" % i)
		assert_eq(store._state["gameplay"]["value"], i, "Cycle %d value should match" % i)

	# Cleanup
	DirAccess.remove_absolute(save_path)
```

**Acceptance Criteria** (from PRD 1h):
- ✅ State saves and loads without data loss
- ✅ Save slots work (save_to_slot/load_from_slot)
- ✅ Save file metadata included
- ✅ Corrupted files validated and rejected
- ✅ Transient fields excluded from JSON
- ✅ Godot types convert correctly (Vector3, Transform3D)
- ✅ 100 save/load cycles pass without corruption
- ✅ StateHandoff preserves state across scene changes

**Commit Message**: `Add state persistence with save slots, metadata, and validation (Story 1h)`

---

## Common Workflows

These step-by-step workflows guide you through common development tasks. **Use these as checklists** when adding new features.

### Workflow 1: How to Add a New Action

**Estimated Time**: 15-25 minutes

**Example Scenario**: Add `ACTION_UPDATE_AMMO` to gameplay slice

**Step 1: Add Action Constant & Creator** (5 min)

```gdscript
# scripts/state/actions/u_gameplay_actions.gd
const ACTION_UPDATE_AMMO := StringName("gameplay/update_ammo")

static func update_ammo(ammo: int) -> Dictionary:
	return {
		"type": ACTION_UPDATE_AMMO,
		"payload": {"ammo": ammo}
	}
```

**Step 2: Register Action** (1 min)

```gdscript
# scripts/state/m_state_store.gd _ready()
_action_registry.register_action(U_GameplayActions.ACTION_UPDATE_AMMO)
```

**Step 3: Update Initial State Resource** (2 min)

```gdscript
# scripts/state/resources/rs_gameplay_initial_state.gd
@export var default_ammo: int = 30  # Add field

func to_dictionary() -> Dictionary:
	return {
		# ... existing fields
		"ammo": default_ammo  # Add to dict
	}
```

Open `resources/state/default_gameplay_initial_state.tres` in Godot, set `default_ammo = 30`, save.

**Step 4: Add Reducer Case** (3 min)

```gdscript
# scripts/state/reducers/u_gameplay_reducer.gd
static func reduce(current_state: Dictionary, action: Dictionary) -> Dictionary:
	var next_state: Dictionary = current_state.duplicate(true)

	match action["type"]:
		# ... existing cases
		U_GameplayActions.ACTION_UPDATE_AMMO:
			var payload: Dictionary = action.get("payload", {})
			next_state["ammo"] = payload.get("ammo", 0)
		_:
			pass

	return next_state
```

**Step 5: Add Tests** (10 min)

```gdscript
# tests/unit/state/test_gameplay_slice_reducers.gd
func test_update_ammo_reduces_correctly():
	var initial: Dictionary = {"ammo": 30}
	var action: Dictionary = U_GameplayActions.update_ammo(15)

	var result: Dictionary = GameplayReducer.reduce(initial, action)

	assert_eq(result["ammo"], 15, "Ammo should update to 15")
	assert_eq(initial["ammo"], 30, "Original state unchanged (immutability)")
```

Run tests: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/state -gexit`

**Step 6 (Optional): Add Selector** (5 min)

```gdscript
# scripts/state/selectors/u_gameplay_selectors.gd
static func select_ammo(state: Dictionary) -> int:
	var gameplay: Dictionary = state.get("gameplay", {})
	return gameplay.get("ammo", 0)

static func select_is_out_of_ammo(state: Dictionary) -> bool:
	return select_ammo(state) <= 0
```

**Verification Checklist:**
- [ ] Action constant uses StringName
- [ ] Action creator returns typed Dictionary
- [ ] Action registered in M_StateStore._ready()
- [ ] Initial state resource updated (.gd and .tres)
- [ ] Reducer case added with proper immutability
- [ ] Test written and passing
- [ ] (Optional) Selector added if derived state needed

---

### Workflow 2: How to Subscribe to State from ECS System

**Estimated Time**: 10 minutes

**Example Scenario**: S_MovementSystem reads pause state

**Step 1: Add Store Reference** (2 min)

```gdscript
# scripts/ecs/systems/s_movement_system.gd
extends BaseECSSystem
class_name S_MovementSystem

var _state_store: M_StateStore
var _unsubscribe: Callable = Callable()
```

**Step 2: Find Store in _ready()** (3 min)

```gdscript
func _ready() -> void:
	super._ready()
	_locate_state_store()

func _locate_state_store() -> void:
	_state_store = U_StateUtils.get_store(self)
	if _state_store:
		_unsubscribe = _state_store.subscribe(_on_state_changed)
	else:
		push_warning("S_MovementSystem: No state store, movement will ignore pause")
```

**Step 3: Unsubscribe on Exit** (1 min)

```gdscript
func _exit_tree() -> void:
	if _unsubscribe.is_valid():
		_unsubscribe.call()
	super._exit_tree()
```

**Step 4: Read State in process_tick** (3 min)

```gdscript
func process_tick(delta: float) -> void:
	var manager := get_manager()
	if manager == null:
		return

	# Check pause state
	if _state_store:
		var state: Dictionary = _state_store.get_state()
		var is_paused: bool = GameplaySelectors.select_is_paused(state)
		if is_paused:
			return  # Skip processing when paused

	# ... normal movement processing
```

**Step 5 (Optional): React to Specific Actions** (2 min)

```gdscript
func _on_state_changed(action: Dictionary, new_state: Dictionary) -> void:
	match action.get("type"):
		U_GameplayActions.ACTION_PAUSE_GAME:
			print("Movement system detected pause")
		U_GameplayActions.ACTION_UNPAUSE_GAME:
			print("Movement system detected unpause")
```

**Verification Checklist:**
- [ ] Store reference declared as member variable
- [ ] U_StateUtils.get_store() called in _ready()
- [ ] Subscribe returns unsubscribe callable
- [ ] Unsubscribe called in _exit_tree()
- [ ] State accessed via selectors (not direct dictionary access)
- [ ] Null checks for store (graceful degradation if no store)

---

### Workflow 3: How to Dispatch Actions from Code

**Estimated Time**: 5 minutes

**Example Scenario**: Input system toggles pause on key press

**Step 1: Get Store Reference** (2 min)

```gdscript
# scripts/ecs/systems/s_input_system.gd
var _state_store: M_StateStore

func _ready() -> void:
	super._ready()
	_state_store = U_StateUtils.get_store(self)
```

**Step 2: Dispatch Action** (3 min)

```gdscript
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_handle_pause_toggle()

func _handle_pause_toggle() -> void:
	if not _state_store:
		push_warning("No state store, cannot toggle pause")
		return

	var current_state: Dictionary = _state_store.get_state()
	var is_paused: bool = GameplaySelectors.select_is_paused(current_state)

	if is_paused:
		_state_store.dispatch(U_GameplayActions.unpause_game())
	else:
		_state_store.dispatch(U_GameplayActions.pause_game())
```

**Verification Checklist:**
- [ ] Store null-checked before dispatch
- [ ] Action creator used (not raw dictionary)
- [ ] Current state queried if decision logic needed
- [ ] Selectors used for derived state checks

---

## ECS Integration Examples

Complete working examples showing how ECS systems integrate with the state store.

### Example 1: Movement System Reading Pause State

```gdscript
# scripts/ecs/systems/s_movement_system.gd
@icon("res://assets/editor_icons/system.svg")
extends BaseECSSystem
class_name S_MovementSystem

const MOVEMENT_TYPE := StringName("C_MovementComponent")

var _state_store: M_StateStore
var _unsubscribe: Callable = Callable()

func _ready() -> void:
	super._ready()
	_locate_state_store()

func _locate_state_store() -> void:
	_state_store = U_StateUtils.get_store(self)
	if _state_store:
		_unsubscribe = _state_store.subscribe(_on_state_changed)
		if OS.is_debug_build():
			print("[S_MovementSystem] Connected to state store")
	else:
		push_warning("S_MovementSystem: No state store found, movement will ignore pause state")

func _exit_tree() -> void:
	if _unsubscribe.is_valid():
		_unsubscribe.call()
	super._exit_tree()

func process_tick(delta: float) -> void:
	var manager := get_manager()
	if manager == null:
		return

	# Check pause state from store
	if _state_store:
		var state: Dictionary = _state_store.get_state()
		var is_paused: bool = GameplaySelectors.select_is_paused(state)
		if is_paused:
			return  # Skip movement processing when paused

	# Normal movement processing
	var components: Array = manager.get_components(MOVEMENT_TYPE)
	for component in components:
		_process_movement(component as C_MovementComponent, delta)

func _process_movement(component: C_MovementComponent, delta: float) -> void:
	# ... movement logic
	pass

func _on_state_changed(action: Dictionary, new_state: Dictionary) -> void:
	# Optional: React to specific state changes
	match action.get("type"):
		U_GameplayActions.ACTION_PAUSE_GAME:
			if OS.is_debug_build():
				print("[S_MovementSystem] Game paused, movement frozen")
		U_GameplayActions.ACTION_UNPAUSE_GAME:
			if OS.is_debug_build():
				print("[S_MovementSystem] Game unpaused, movement resumed")
```

**Key Patterns**:
- Store reference cached as member variable
- Subscription in _ready(), unsubscribe in _exit_tree()
- Graceful degradation if no store (null checks)
- State accessed via selectors (not direct dictionary)
- Optional callback for specific action reactions

---

### Example 2: Input System Dispatching Actions

```gdscript
# scripts/ecs/systems/s_input_system.gd
@icon("res://assets/editor_icons/system.svg")
extends BaseECSSystem
class_name S_InputSystem

const INPUT_TYPE := StringName("C_InputComponent")

var _state_store: M_StateStore

func _ready() -> void:
	super._ready()
	_state_store = U_StateUtils.get_store(self)
	if not _state_store:
		push_warning("S_InputSystem: No state store, pause functionality disabled")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_handle_pause_toggle()
	elif event.is_action_pressed("quicksave"):
		_handle_quicksave()

func _handle_pause_toggle() -> void:
	if not _state_store:
		return

	var current_state: Dictionary = _state_store.get_state()
	var is_paused: bool = GameplaySelectors.select_is_paused(current_state)

	if is_paused:
		_state_store.dispatch(U_GameplayActions.unpause_game())
	else:
		_state_store.dispatch(U_GameplayActions.pause_game())

func _handle_quicksave() -> void:
	if not _state_store:
		push_warning("Cannot quicksave: no state store")
		return

	var save_result: bool = _state_store.save_to_slot(0)  # Slot 0 = quicksave
	if save_result and OS.is_debug_build():
		print("[S_InputSystem] Quicksave successful")

func process_tick(_delta: float) -> void:
	# Process input components normally
	pass
```

**Key Patterns**:
- Store found once in _ready(), cached
- Actions dispatched based on input events
- Current state queried to make decisions (pause toggle)
- Null checks prevent errors if no store
- Quicksave uses store's save_to_slot() API

---

### Example 3: Avoiding Circular Dependencies

**Anti-Pattern** (AVOID):
```gdscript
# BAD: Circular dependency
# Action → State Change → Signal → System → Dispatch Same Action → Loop!

func _on_state_changed(action: Dictionary, new_state: Dictionary) -> void:
	if action["type"] == U_GameplayActions.ACTION_PLAYER_DIED:
		# DON'T DO THIS - creates infinite loop
		_state_store.dispatch(U_GameplayActions.game_over())
```

**Correct Pattern** (USE THIS):
```gdscript
# GOOD: Use selector to derive state, don't re-dispatch

func _on_state_changed(action: Dictionary, new_state: Dictionary) -> void:
	# Don't dispatch new action - just react to current state
	var is_game_over: bool = GameplaySelectors.select_is_game_over(new_state)
	if is_game_over:
		_show_game_over_screen()

# OR: Use reducer to handle derived state
# In u_gameplay_reducer.gd:
static func reduce(current_state: Dictionary, action: Dictionary) -> Dictionary:
	var next_state: Dictionary = current_state.duplicate(true)

	match action["type"]:
		U_GameplayActions.ACTION_PLAYER_DIED:
			next_state["player_alive"] = false
			# Derive game_over in reducer, not separate action
			next_state["game_over"] = _check_game_over_conditions(next_state)

	return next_state
```

**Guidelines**:
- ✅ Systems OBSERVE state changes (read-only)
- ✅ Systems DISPATCH actions based on game events (input, collisions, timers)
- ❌ Systems DON'T dispatch actions in response to state changes (circular)
- ✅ Use selectors to derive state
- ✅ Use reducers to compute dependent state

---

## Debugging Guide

How to debug state issues **before** Phase 2 debug overlay exists.

### Technique 1: Print Statements in Reducer

```gdscript
# scripts/state/reducers/u_gameplay_reducer.gd
static func reduce(current_state: Dictionary, action: Dictionary) -> Dictionary:
	if OS.is_debug_build():
		print("════════════════════════════════════════")
		print("[REDUCER] Action: ", action.get("type"))
		print("[REDUCER] Payload: ", action.get("payload"))
		print("[REDUCER] Current State: ", current_state)

	var next_state: Dictionary = current_state.duplicate(true)

	match action["type"]:
		# ... reducer logic
		_:
			pass

	if OS.is_debug_build():
		print("[REDUCER] Next State: ", next_state)
		print("════════════════════════════════════════")

	return next_state
```

### Technique 2: Print Statements in Dispatch

```gdscript
# scripts/state/m_state_store.gd
func dispatch(action: Dictionary) -> void:
	if OS.is_debug_build():
		print("[DISPATCH] ", action.get("type"), " | Payload: ", action.get("payload"))

	# ... validation and reducer logic
```

### Technique 3: Verify Action Registration

```gdscript
# scripts/state/m_state_store.gd _ready()
func _ready() -> void:
	# ... normal setup

	if OS.is_debug_build():
		print("[STORE] Registered actions: ", _action_registry._registered_types.keys())
```

### Technique 4: Track Signal Emissions

```gdscript
# In system's _on_state_changed callback
func _on_state_changed(action: Dictionary, new_state: Dictionary) -> void:
	if OS.is_debug_build():
		print("[%s] Received state change: %s" % [name, action.get("type")])
	# ... rest of callback
```

### Technique 5: Godot Debugger Breakpoints

**Where to Set Breakpoints**:
1. **Reducer match statement** - See which case is hit
2. **Dispatch validation** - Check if action is valid
3. **Subscriber callback** - Verify signal emission
4. **Selector functions** - Debug derived state computation

**How to Use**:
1. Open script in Godot editor
2. Click line number to set breakpoint (red dot appears)
3. Run scene (F5)
4. When breakpoint hits, inspect variables in Debugger panel
5. Step through code with F10 (next line) / F11 (step into)

### Technique 6: Remote Debugger for Headless Tests

```bash
# Run tests with remote debugger
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/state \
  --remote-debug tcp://127.0.0.1:6007
```

Then connect from Godot editor: Debug → Remote Debug

### Common Error Messages & Solutions

**Error**: "No M_StateStore found in 'state_store' group"
- **Cause**: Store not in scene tree or `add_to_group("state_store")` not called
- **Solution**: Check M_StateStore is in base_scene_template.tscn, verify _ready() calls add_to_group

**Error**: "Action missing 'type' field"
- **Cause**: Dispatching raw dictionary instead of using action creator
- **Solution**: Use U_GameplayActions.action_name() instead of `{"type": ...}`

**Error**: "Save file corrupted (invalid JSON)"
- **Cause**: Manual editing of save file or incomplete write
- **Solution**: Delete corrupted save file, investigate why write didn't complete

**Error**: "Multiple M_StateStore instances found"
- **Cause**: Store added to scene multiple times
- **Solution**: Check base_scene_template.tscn has only one M_StateStore under Managers/

**Error**: Variant type inference errors in tests
- **Cause**: Missing explicit type annotations
- **Solution**: Add type hints: `var action: Dictionary = ...` not `var action = ...`

---

## FAQ

### Q: How do I access state from an ECS system?

**A**: Use `U_StateUtils.get_store(self)` in `_ready()`, cache reference, access via `store.get_state()`.

```gdscript
var _state_store: M_StateStore

func _ready() -> void:
	_state_store = U_StateUtils.get_store(self)

func process_tick(delta: float) -> void:
	if _state_store:
		var state: Dictionary = _state_store.get_state()
		var is_paused: bool = GameplaySelectors.select_is_paused(state)
```

---

### Q: Where do .tres files go?

**A**: In `resources/state/` (NOT `scripts/state/resources/`). Follows ECS pattern of `resources/base_settings/*.tres`.

---

### Q: Why is my action not updating state?

**A**: Checklist:
1. Action registered? Check `_action_registry.register_action()` called
2. Reducer case added? Check `match action["type"]:` has your action
3. Reducer returning new state? Check `return next_state` not `return current_state`
4. Using `.duplicate(true)`? Check immutability preserved

Add print statements in reducer to debug (see Debugging Guide).

---

### Q: How do I prevent circular dependencies?

**A**:
- Systems OBSERVE state (read-only via selectors)
- Systems DISPATCH actions (based on game events, not state changes)
- DON'T dispatch actions in `_on_state_changed` callback
- Use reducers to compute dependent state, not chained actions

See "Example 3: Avoiding Circular Dependencies" in ECS Integration Examples.

---

### Q: What if Phase 0 (event bus refactor) breaks ECS?

**A**: Use fallback:
- Skip EventBus integration initially
- M_StateStore uses direct signals
- Defer bus unification to Phase 8
- See "Decision 5: Phase 0 Alternative Path" in Architectural Decisions

---

### Q: How do I inspect state during development?

**A**: Before debug overlay (Phase 2):
- Print statements in reducers/dispatch
- Godot debugger breakpoints
- Check action history: `store.get_action_history()`

After debug overlay:
- Press F3 to spawn SC_StateDebugOverlay
- View live state, action log, create snapshots

---

### Q: Should I use selectors or access state directly?

**A**: ALWAYS use selectors. Benefits:
- Encapsulation (state shape can change, selectors updated once)
- Reusability (same selector used in multiple systems)
- Testability (selectors are pure functions, easy to test)
- Documentation (selector name describes what it computes)

```gdscript
# GOOD
var is_paused: bool = GameplaySelectors.select_is_paused(state)

# BAD
var is_paused: bool = state.get("gameplay", {}).get("paused", false)
```

---

### Q: How do I know if my reducer is pure?

**A**: Pure function checklist:
- ✅ Same inputs always produce same outputs
- ✅ No side effects (no prints, no file I/O, no signals)
- ✅ Doesn't mutate inputs (uses `.duplicate(true)`)
- ✅ Doesn't depend on external state (time, random, globals)
- ✅ Only uses data from parameters

Test purity:
```gdscript
func test_reducer_is_pure():
	var state: Dictionary = {"health": 100}
	var action: Dictionary = U_GameplayActions.update_health(50)

	var result1: Dictionary = GameplayReducer.reduce(state, action)
	var result2: Dictionary = GameplayReducer.reduce(state, action)

	assert_eq(result1, result2, "Same inputs should produce same outputs")
	assert_eq(state["health"], 100, "Original state should be unchanged")
```

---

## Testing Strategy

(Keep existing Testing Strategy section from v1, add these critical patterns)

### Critical Test Pattern: Event Bus Reset (per domain)

**MANDATORY in every test file**:

```gdscript
extends GutTest

var store: M_StateStore

func before_each():
	# Clear state event bus between tests
	U_StateEventBus.reset()

	store = M_StateStore.new()
	autofree(store)
	add_child(store)
	await get_tree().process_frame

func after_each():
	if store and is_instance_valid(store):
		store.queue_free()
	store = null
	U_StateEventBus.reset()
```

**Why Critical**: Without a bus reset, subscriptions leak between tests causing mysterious failures. Use `U_ECSEventBus.reset()` in ECS test suites.

---

## Production Checklist

Before releasing builds with state store:

### Export Templates
- [ ] Exclude debug overlay from release builds
- [ ] Set `enable_debug_logging = false` in production
- [ ] Set `max_history_size` appropriately (100 for release vs 1000 for dev)

### Performance Verification
- [ ] Profile on target hardware (low-end devices)
- [ ] Verify <0.1ms overhead at 60fps
- [ ] Check memory usage with 1000-entry history
- [ ] Test with realistic state sizes (not just toy examples)

### Save File Validation
- [ ] Test corrupted save file handling
- [ ] Test save file from older version (migration)
- [ ] Test save file from newer version (reject gracefully)
- [ ] Verify save location works on all platforms

### Platform-Specific
- [ ] Test save file paths on Windows (user://...)
- [ ] Test save file paths on Linux
- [ ] Test save file paths on macOS
- [ ] Verify save directory creation on first run

### Feature Flags
- [ ] Add RS_StateStoreSettings.enabled master switch
- [ ] Add per-feature flags (history, persistence, debug overlay)
- [ ] Test disabling state store gracefully degrades

---

## Success Metrics

(Keep SC-001 through SC-008 from v1)

**Additional Success Criteria**:

- **SC-009**: Event bus refactor complete (or fallback used) - both ECS and state systems functional
- **SC-010**: All 8 micro-stories committed individually with passing tests
- **SC-011**: All naming conventions followed (M_*, U_*, RS_*, SC_*)
- **SC-012**: U_StateUtils.get_store() works from any node in tree
- **SC-013**: StateHandoff preserves state across scene transitions
- **SC-014**: Save slots, metadata, and validation working correctly
- **SC-015**: Complete ECS integration examples work as documented
- **SC-016**: All FAQ questions have verified answers

---

## Risks & Mitigations

(Keep existing risks from v1, add these)

### Risk 7: StateHandoff Leaks Memory

**Risk**: Preserved slices accumulate indefinitely if not cleared

**Mitigation**:
- StateHandoff.clear_all() on game exit to main menu
- Per-slice clear when slice no longer needed
- Monitor preserved_slices size in debug builds

**Monitoring**: Add debug print of preserved slice count

---

### Risk 8: Scene Template Corruption

**Risk**: Manually editing base_scene_template.tscn breaks M_StateStore setup

**Mitigation**:
- Document exact scene structure in Prerequisites
- Keep backup of working template
- Add verification test that instantiates template and checks for M_StateStore

**Monitoring**: Integration test checks M_StateStore exists in instantiated template

---

## Definition of Done

**For Each Micro-Story**:
- [ ] Code written following STYLE_GUIDE.md naming conventions
- [ ] Tests written following GUT patterns (autofree, explicit typing, bus reset in `before_each()`)
- [ ] All tests pass in headless mode
- [ ] DEV_PITFALLS.md re-read before coding
- [ ] Commit message follows pattern
- [ ] Git status clean

**For Phase 1 (User Story 1) Completion**:
- [ ] All 8 micro-stories committed individually
- [ ] U_StateUtils created and tested
- [ ] No autoloads required/used
- [ ] base_scene_template.tscn updated with M_StateStore
- [ ] Gameplay slice fully functional
- [ ] Action history maintaining 1000 entries
- [ ] Save/load with slots, metadata, validation working
- [ ] Performance benchmarks passing (<0.1ms)
- [ ] PRD updated with any deviations

**For Full Feature Completion (All 7 User Stories)**:
- [ ] All 3 slices implemented (boot, menu, gameplay)
- [ ] State transitions working (boot→menu→gameplay→menu)
- [ ] Debug overlay functional (F3 toggle)
- [ ] Time-travel snapshots working
- [ ] Integration tests passing
- [ ] Documentation complete (this plan + workflows)
- [ ] Production checklist verified

---

## Next Steps

1. **Review Prerequisites** (1 hour)
   - Read DEV_PITFALLS.md, STYLE_GUIDE.md, AGENTS.md
   - Create directory structure
   - Make event bus refactor decision (Phase 0 or fallback)

2. **Phase 0 Decision** (1 day max)
   - Attempt event bus refactor
   - Run ECS tests
   - **Go/No-Go**: Tests pass → Phase 1a | Tests fail → Fallback

3. **Phase 1a** (4 hours)
   - Create M_StateStore skeleton
   - Create U_StateUtils
   - Update base_scene_template.tscn
   - Write tests
   - **Commit**

4. **Phase 1b-1h** (Follow micro-story sequence)
   - One commit per micro-story
   - Tests green before each commit
   - ~1-2 days total

5. **Phase 2-7** (After Phase 1 complete)
   - Review PRD, adjust plan if needed
   - Proceed with remaining user stories

6. **Production Release** (After all phases)
   - Complete production checklist
   - Update AGENTS.md with state store patterns

---

**END OF IMPLEMENTATION PLAN**
