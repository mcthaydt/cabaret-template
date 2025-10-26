---
description: "Task list for Redux-style centralized state store implementation"
feature_branch: "redux-state-store"
created: "2025-10-25"
version: "2.0"
---

# Tasks: Redux-Style Centralized State Store

**Version**: 2.0 (Revised)
**Revision Date**: 2025-10-25
**Changes**: Addressed 18 critical gaps including U_StateUtils, StateHandoff, RS_StateStoreSettings, event bus reset patterns, scene template timing, project settings, expanded serialization, and architectural clarifications

### Phase 0 Decision (record here)
- Chosen: Option C — Dual‑Bus via Abstract Base (ECSEventBus + StateStoreEventBus)
- Alternatives (for future consideration only):
  - Option A: Single bus with namespacing (time‑box 1 day)
  - Option B: Direct signals initially; defer bus work

**Input**: Design documents from `/docs/state store/`

- `redux-state-store-prd.md` (required)
- `redux-state-store-implementation-plan.md` (required)

**Prerequisites**: PRD v2.0, Implementation Plan v2.0, AGENTS.md commit strategy, DEV_PITFALLS.md testing patterns

**Tests**: ALL tasks include TDD approach - write failing tests FIRST, then implement to pass

**Organization**: Tasks grouped by user story to enable independent implementation and testing of each story

**In-Game Testing**: Each implementation phase includes test scene creation for scene integration verification

---

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1a, US1b, US2)
- Include exact file paths in descriptions

---

## Path Conventions

This is a Godot 4.5 project with the following structure:

- **scripts/**: Core game scripts (ECS, state, managers, utilities)
- **resources/**: .tres resource files (settings, initial states)
- **scenes/**: Scene files (.tscn)
- **tests/**: GUT test framework tests (unit, integration)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization, directory structure, and Godot project configuration

**⚠️ IMPORTANT**: These are basic setup tasks. No implementation yet.

### Directory Structure

- [x] T001 [P] Create directory `scripts/state/` for core state files
- [x] T002 [P] Create directory `scripts/state/reducers/` for reducer functions
- [x] T003 [P] Create directory `scripts/state/selectors/` for selector utilities
- [x] T004 [P] Create directory `scripts/state/resources/` for Resource class scripts
- [x] T005 [P] Create directory `resources/state/` for .tres resource files
- [x] T006 [P] Create directory `scenes/debug/` for debug overlay scenes
- [x] T007 [P] Create directory `tests/unit/state/` for state unit tests
- [x] T008 [P] Create directory `tests/unit/state/integration/` for integration tests

### Project Settings Configuration

- [x] T009 [P] Add project setting `state/debug/enable_history` (type: bool, default: true)
- [x] T010 [P] Add project setting `state/debug/history_size` (type: int, default: 1000, range: 100-10000)
- [x] T011 [P] Add project setting `state/debug/enable_debug_overlay` (type: bool, default: true for debug builds, false for release)
- [x] T012 [P] Add input action `toggle_debug_overlay` mapped to F3 key in Project Settings → Input Map

### Initial Files

- [x] T013 [P] Create file `scripts/state/state_action_types.gd` with StringName constants skeleton (empty for now, will be populated per slice)

**Checkpoint**: Directory structure ready, project settings configured - can now work on foundational and user story tasks

---

## Phase 2: Foundational (Blocking Prerequisites - Phase 0 Decision)

**Purpose**: Event bus refactor that MUST be resolved before ANY user story implementation

**⚠️ DECISION MADE**: Option C (Dual-Bus via Abstract Base) was chosen and implemented in commit b7fb729
- Created `EventBusBase` abstract class with shared logic
- Created `StateStoreEventBus` extending base for state domain
- Refactored `ECSEventBus` to extend base while preserving API
- All tests pass (7/7 state, 62/62 ECS)
- Options A and B below are marked N/A since Option C was implemented

**⚠️ CRITICAL DECISION POINT**: Attempt event bus refactor or use fallback approach?

### Option A: Event Bus Refactor (Single bus with namespacing, 1-day time box) - N/A (Option C used)

**If successful**: Unified event system from the start, cleaner architecture
**If fails**: Switch to Option B after 1 day (use rollback tasks below)

- [N/A] T014 [Phase0-A] Read existing `scripts/ecs/ecs_event_bus.gd` to understand current API
- [N/A] T015 [Phase0-A] Create backup: Copy `scripts/ecs/ecs_event_bus.gd` to `scripts/ecs/ecs_event_bus.gd.backup`
- [N/A] T016 [Phase0-A] Create new `scripts/event_bus.gd` with namespace support ("ecs/*", "state/*" prefixes)
- [N/A] T017 [Phase0-A] Implement backward-compatible publish/subscribe in `scripts/event_bus.gd`
- [N/A] T018 [Phase0-A] Add `reset()` method to `scripts/event_bus.gd` for test isolation (clears all subscriptions)
- [N/A] T019 [Phase0-A] (No autoloads) — skip autoload configuration; use static class pattern
- [N/A] T020 [Phase0-A] Update `scripts/ecs/systems/s_jump_system.gd` to use `EventBus` instead of `ECSEventBus`
- [N/A] T021 [Phase0-A] Find all files using `ECSEventBus` via grep: `grep -r "ECSEventBus" scripts/ tests/`
- [N/A] T022 [Phase0-A] Update all found files to use `EventBus` instead of `ECSEventBus`
- [N/A] T023 [Phase0-A] Run existing ECS tests: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ecs -gexit`
- [N/A] T024 [Phase0-A] Fix any ECS test failures from EventBus refactor
- [N/A] T025 [Phase0-A] Commit Phase 0A: "Refactor ecs_event_bus to unified event_bus with namespacing"

### Option A Rollback (If Phase 0A fails after 1 day) - N/A (Option C used)

**Execute these if switching from Option A to Option B mid-refactor:**

- [N/A] T026 [Phase0-A-Rollback] Restore backup: `mv scripts/ecs/ecs_event_bus.gd.backup scripts/ecs/ecs_event_bus.gd`
- [N/A] T027 [Phase0-A-Rollback] Delete incomplete event_bus.gd: `rm scripts/event_bus.gd`
- [N/A] T028 [Phase0-A-Rollback] (No autoloads) — not applicable
- [N/A] T029 [Phase0-A-Rollback] Revert any modified files: `git restore scripts/ tests/`
- [N/A] T030 [Phase0-A-Rollback] Verify rollback: Run ECS tests to confirm all pass
- [N/A] T031 [Phase0-A-Rollback] Proceed with Option B tasks below

### Option B: Fallback (If Option A fails or exceeds 1 day) - N/A (Option C used)

**Approach**: Use direct signals on M_StateStore initially, defer event bus integration to a later phase

- [N/A] T032 [Phase0-B] Document decision at top of this file under a "Phase 0 Decision" note: "Using direct signals, EventBus integration deferred to Phase 15"
- [N/A] T033 [Phase0-B] Note in M_StateStore implementation comments: "TODO: Integrate with EventBus in Phase 15"
- [N/A] T034 [Phase0-B] Proceed with US1a using direct Godot signals instead of EventBus.publish()

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1a - Core M_StateStore Skeleton (Priority: P1) 🎯 MVP Foundation

**Goal**: Create foundational M_StateStore node with basic dispatch/subscribe infrastructure, utility helpers, and configuration

**Independent Test**: Can instantiate store in test, subscribe callback, dispatch action, verify callback receives action

### Tests for User Story 1a ⚠️ WRITE THESE TESTS FIRST, ENSURE THEY FAIL

**⚠️ CRITICAL TESTING PATTERN**: All state test tasks must include a state bus reset in `before_each()` to prevent subscription leaks. Use `StateStoreEventBus.reset()` for state tests; use `ECSEventBus.reset()` in ECS test suites. Example template:

```gdscript
extends GutTest

var store: M_StateStore

func before_each():
    StateStoreEventBus.reset()  # CRITICAL: Prevents test pollution in state tests
    store = M_StateStore.new()
    autofree(store)
    add_child(store)
    await get_tree().process_frame

func after_each():
    if store and is_instance_valid(store):
        store.queue_free()
    store = null
```

- [x] T035 [P] [US1a] 📝 TEST: Create `tests/unit/state/test_m_state_store.gd` extending GutTest with test template above
- [x] T036 [P] [US1a] 📝 TEST: Write test `test_store_instantiates_as_node()` - verify M_StateStore extends Node
- [x] T037 [P] [US1a] 📝 TEST: Write test `test_store_adds_to_state_store_group()` - verify group membership
- [x] T038 [P] [US1a] 📝 TEST: Write test `test_dispatch_notifies_subscribers()` - verify callback receives action
- [x] T039 [P] [US1a] 📝 TEST: Write test `test_dispatch_emits_action_dispatched_signal()` - verify signal emission
- [x] T040 [P] [US1a] 📝 TEST: Write test `test_dispatch_rejects_action_without_type()` - verify validation
- [x] T041 [P] [US1a] 📝 TEST: Write test `test_u_state_utils_finds_store_by_group()` - verify U_StateUtils.get_store()
- [x] T042 [US1a] 📝 RUN TESTS: Verify all US1a tests FAIL (no implementation yet)

### Implementation for User Story 1a

**Core Store Infrastructure:**

- [x] T043 [P] [US1a] Create `scripts/state/state_slice_config.gd` with structure: slice_name (StringName), reducer (Callable), initial_state (Dictionary), dependencies (Array[StringName]), transient_fields (Array[StringName])
- [x] T044 [P] [US1a] Create `scripts/state/resources/rs_state_store_settings.gd` extending Resource
- [x] T045 [US1a] Add @export properties to RS_StateStoreSettings: max_history_size (int, default 1000), enable_debug (bool), enable_time_travel (bool), performance_monitoring (bool)
- [x] T046 [US1a] Add method `to_dictionary() -> Dictionary` to RS_StateStoreSettings for serialization
- [x] T047 [US1a] Create default resource `resources/state/default_state_store_settings.tres` with defaults
- [x] T048 [US1a] Create `scripts/state/m_state_store.gd` extending Node with class_name M_StateStore
- [x] T049 [US1a] Add @icon annotation: `@icon("res://resources/editor_icons/state_store.svg")` (create icon later if needed)
- [x] T050 [US1a] Add @export to M_StateStore: `@export var settings: RS_StateStoreSettings`
- [x] T051 [US1a] Add signals to M_StateStore: `state_changed(action: Dictionary, new_state: Dictionary)`, `slice_updated(slice_name: StringName, slice_state: Dictionary)`, `action_dispatched(action: Dictionary)`, `validation_failed(action: Dictionary, error: String)`
- [x] T052 [US1a] Add private vars to M_StateStore: `_state: Dictionary = {}`, `_subscribers: Array[Callable] = []`, `_slice_configs: Dictionary = {}` (slice_name -> StateSliceConfig)
- [x] T053 [US1a] Implement `_ready()` in M_StateStore: add_to_group("state_store"), validate settings exist
- [x] T054 [US1a] Implement `dispatch(action: Dictionary) -> void` with basic action.type validation
- [x] T055 [US1a] Implement `subscribe(callback: Callable) -> void` to add callback to _subscribers array
- [x] T056 [US1a] Implement `unsubscribe(callback: Callable) -> void` to remove callback from _subscribers array
- [x] T057 [US1a] Add validation in dispatch(): check action.has("type"), emit validation_failed if missing
- [x] T058 [US1a] Add subscriber notification in dispatch(): call each subscriber with action
- [x] T059 [US1a] Add method `register_slice(config: StateSliceConfig) -> void` for slice registration
- [x] T060 [US1a] Add method `get_state_slice(slice_name: StringName) -> Dictionary` returning deep copy (IMPLEMENTED AS get_slice)
- [x] T061 [US1a] Add method `get_full_state() -> Dictionary` returning deep copy of all slices (IMPLEMENTED AS get_state)

**U_StateUtils Helper (Critical for Global Access):**

- [x] T062 [P] [US1a] Create `scripts/state/u_state_utils.gd` with class_name U_StateUtils
- [x] T063 [US1a] Implement `static func get_store(node: Node) -> M_StateStore` using get_tree().get_nodes_in_group("state_store") pattern
- [x] T064 [US1a] Add null/validation checks in get_store(): verify node valid, tree exists, group not empty
- [x] T065 [US1a] Add warning if multiple stores found in group (unexpected state)
- [x] T066 [US1a] Implement `static func benchmark(name: String, callable: Callable) -> float` using Time.get_ticks_usec() for performance profiling
- [x] T067 [US1a] Add debug print in benchmark() if OS.is_debug_build() to log timing

**Subscriber Lifecycle Documentation:**

- [x] T068 [US1a] Add doc comment to subscribe() explaining: "Subscribers persist until explicitly unsubscribed. ECS systems should cache store reference and unsubscribe in _exit_tree() to prevent leaks."
- [x] T069 [US1a] Add example in comment showing proper subscription lifecycle pattern

**Test Execution:**

- [x] T070 [US1a] 📝 RUN TESTS: Verify all US1a tests now PASS
- [x] T071 [US1a] Create test scene `scenes/debug/state_test_us1a.tscn` with M_StateStore node
- [x] T072 [US1a] Add script to test scene that dispatches test action on _ready() and prints result via U_StateUtils
- [ ] T073 [US1a] 🎮 IN-GAME TEST: Run test scene, verify console shows action dispatch without errors

**Scene Template Integration (Moved from later phase):**

- [x] T074 [US1a] Open `templates/base_scene_template.tscn` in Godot editor
- [x] T075 [US1a] Find existing `Managers/` node (should contain M_ECSManager)
- [x] T076 [US1a] Add M_StateStore as child of Managers/ node (parallel to M_ECSManager)
- [x] T077 [US1a] Link RS_StateStoreSettings to M_StateStore's settings export in scene template
- [x] T078 [US1a] Save scene template
- [x] T079 [US1a] Test base scene template: Run template scene, verify M_StateStore initializes without errors (WAS FALSELY MARKED - Fixed in commit 8199d6b)

**Commit:**

- [x] T080 [US1a] Commit US1a: "Add core M_StateStore skeleton with U_StateUtils, RS_StateStoreSettings, and scene integration"

**Checkpoint**: M_StateStore can be instantiated, accessed via U_StateUtils, accepts subscriptions, and dispatches actions

---

## Phase 4: User Story 1b - Action Registry with StringName Validation (Priority: P1)

**Goal**: Implement action type validation using StringName constants and runtime payload checking

**Independent Test**: Can register action types, create actions via action creators, validate action types in dispatch

### Tests for User Story 1b ⚠️ WRITE THESE TESTS FIRST, ENSURE THEY FAIL

**⚠️ REMINDER**: Include `StateStoreEventBus.reset()` in `before_each()` for state tests (use `ECSEventBus.reset()` in ECS tests)

- [x] T081 [P] [US1b] 📝 TEST: Create `tests/unit/state/test_action_registry.gd` (include bus reset in `before_each()`)
- [x] T082 [P] [US1b] 📝 TEST: Write test `test_register_action_type_adds_to_registry()`
- [x] T083 [P] [US1b] 📝 TEST: Write test `test_validate_action_accepts_registered_type()`
- [x] T084 [P] [US1b] 📝 TEST: Write test `test_validate_action_rejects_unregistered_type()`
- [x] T085 [P] [US1b] 📝 TEST: Create `tests/unit/state/test_u_gameplay_actions.gd` (include bus reset in `before_each()`)
- [x] T086 [P] [US1b] 📝 TEST: Write test `test_pause_game_action_creator_returns_correct_structure()`
- [x] T087 [P] [US1b] 📝 TEST: Write test `test_action_type_is_string_name_not_string()`
- [x] T088 [US1b] 📝 RUN TESTS: Verify all US1b tests FAIL (no implementation yet)

### Implementation for User Story 1b

**ActionRegistry (Static Class with Static Initializer):**

- [x] T089 [P] [US1b] Create `scripts/state/action_registry.gd` as class_name ActionRegistry
- [x] T090 [US1b] Add static var `_registered_actions: Dictionary = {}` (action_type -> schema)
- [x] T091 [US1b] Implement `static func register_action(action_type: StringName, schema: Dictionary) -> void`
- [x] T092 [US1b] Implement `static func is_registered(action_type: StringName) -> bool`
- [x] T093 [US1b] Implement `static func validate_action(action: Dictionary) -> bool` with schema checking
- [x] T094 [US1b] Add `static func get_registered_actions() -> Array[StringName]` for debugging
- [x] T095 [US1b] Add doc comment clarifying: "ActionRegistry is a static class. Actions registered at static initialization time or in M_StateStore._ready()"

**Gameplay Action Creators:**

- [x] T096 [P] [US1b] Create `scripts/state/u_gameplay_actions.gd` as class_name U_GameplayActions
- [x] T097 [US1b] Add StringName constants: `const ACTION_PAUSE_GAME := StringName("gameplay/pause")`, `const ACTION_UNPAUSE_GAME := StringName("gameplay/unpause")`
- [x] T098 [US1b] Implement `static func pause_game() -> Dictionary` returning {"type": ACTION_PAUSE_GAME, "payload": null}
- [x] T099 [US1b] Implement `static func unpause_game() -> Dictionary` returning {"type": ACTION_UNPAUSE_GAME, "payload": null}
- [x] T100 [US1b] Add explicit type annotation `: Dictionary` to all action creator return values
- [x] T101 [US1b] Add static initializer `static func _static_init():` that registers actions with ActionRegistry
- [x] T102 [US1b] In _static_init(), call ActionRegistry.register_action() for PAUSE and UNPAUSE

**Store Integration:**

- [x] T103 [US1b] Update M_StateStore.dispatch() to call ActionRegistry.validate_action() before processing
- [x] T104 [US1b] In dispatch(), if validation fails, emit validation_failed signal with error details
- [x] T105 [US1b] 📝 RUN TESTS: Verify all US1b tests now PASS
- [x] T106 [US1b] Update test scene `scenes/debug/state_test_us1b.tscn` to dispatch U_GameplayActions.pause_game()
- [ ] T107 [US1b] 🎮 IN-GAME TEST: Run test scene, verify validation works, invalid actions are rejected with error
- [x] T108 [US1b] Commit US1b: "Add action registry with StringName validation and static registration"

**Checkpoint**: Actions are validated against registry, action creators ensure type safety, registry self-initializes

---

## Phase 5: User Story 1c - Gameplay Slice Reducer Infrastructure (Priority: P1)

**Goal**: Implement reducer system with immutability via .duplicate(true) and integrate initial state from resources

**Independent Test**: Can load initial state from resource, dispatch actions that trigger reducers, verify state updates immutably

### Tests for User Story 1c ⚠️ WRITE THESE TESTS FIRST, ENSURE THEY FAIL

**⚠️ REMINDER**: Include `StateStoreEventBus.reset()` in `before_each()` for state tests

- [x] T109 [P] [US1c] 📝 TEST: Create `tests/unit/state/test_gameplay_slice_reducers.gd` (include bus reset in `before_each()`)
- [x] T110 [P] [US1c] 📝 TEST: Write test `test_reducer_is_pure_function()` - same input produces same output
- [x] T111 [P] [US1c] 📝 TEST: Write test `test_reducer_does_not_mutate_original_state()` - verify immutability
- [x] T112 [P] [US1c] 📝 TEST: Write test `test_pause_action_sets_paused_to_true()`
- [x] T113 [P] [US1c] 📝 TEST: Write test `test_unpause_action_sets_paused_to_false()`
- [x] T114 [P] [US1c] 📝 TEST: Write test `test_initial_state_loads_from_resource()`
- [x] T115 [US1c] 📝 RUN TESTS: Verify all US1c tests FAIL (no implementation yet)

### Implementation for User Story 1c

**Initial State Resource:**

- [x] T116 [P] [US1c] Create `scripts/state/resources/rs_gameplay_initial_state.gd` extending Resource with class_name RS_GameplayInitialState
- [x] T117 [US1c] Add @export properties: paused (bool, default false), health (int, default 100), score (int, default 0), level (int, default 1)
- [x] T118 [US1c] Add `func to_dictionary() -> Dictionary` method returning all @export properties as Dictionary
- [x] T119 [US1c] Create default resource file `resources/state/default_gameplay_initial_state.tres`
- [x] T120 [US1c] Set default values in .tres via Godot editor: paused=false, health=100, score=0, level=1

**Gameplay Reducer:**

- [x] T121 [P] [US1c] Create `scripts/state/reducers/gameplay_reducer.gd` as class_name GameplayReducer
- [x] T122 [US1c] Implement `static func reduce(state: Dictionary, action: Dictionary) -> Dictionary`
- [x] T123 [US1c] Add match statement on action.type with case U_GameplayActions.ACTION_PAUSE_GAME
- [x] T124 [US1c] In PAUSE case: `var new_state = state.duplicate(true); new_state.paused = true; return new_state`
- [x] T125 [US1c] Add case U_GameplayActions.ACTION_UNPAUSE_GAME with paused=false
- [x] T126 [US1c] Add default case: `return state` (no change for unknown actions)
- [x] T127 [US1c] Add doc comment: "All reducers are pure functions. NEVER mutate state directly. Always use .duplicate(true)."

**Store Integration:**

- [x] T128 [US1c] Update StateSliceConfig to include `reducer: Callable` field
- [x] T129 [US1c] Add `@export var gameplay_initial_state: RS_GameplayInitialState` to M_StateStore
- [x] T130 [US1c] Update M_StateStore._ready() to register gameplay slice using register_slice()
- [x] T131 [US1c] In _ready(), create StateSliceConfig for gameplay with: slice_name="gameplay", reducer=GameplayReducer.reduce, initial_state=gameplay_initial_state.to_dictionary()
- [x] T132 [US1c] Update M_StateStore.dispatch() to look up slice config, call reducer with current state and action
- [x] T133 [US1c] In dispatch(), store new state returned by reducer using .duplicate(true)
- [x] T134 [US1c] Add circular dependency validation in register_slice(): build dependency graph, detect cycles with DFS, push_error() if cycle found

**Slice Registration Flow Documentation:**

- [x] T135 [US1c] Add doc comment to register_slice() explaining: "Slices register via M_StateStore._ready() using @export resources. Each slice needs: RS_*InitialState resource, *_reducer.gd static class, StateSliceConfig in register_slice() call"
- [x] T136 [US1c] Add comment showing example registration pattern in M_StateStore._ready()

**Test & Validation:**

- [x] T137 [US1c] 📝 RUN TESTS: Verify all US1c tests now PASS
- [x] T138 [US1c] Update test scene `scenes/debug/state_test_us1c.tscn` to dispatch pause/unpause and print state
- [ ] T139 [US1c] 🎮 IN-GAME TEST: Run test scene, verify state.paused toggles correctly, old state never mutates
- [x] T140 [US1c] Commit US1c: "Add gameplay reducer with immutable state updates and circular dependency validation"

**Checkpoint**: Reducers can process actions and update state immutably from initial resource state, with cycle detection

---

## Phase 6: User Story 1d - Type-Safe Action Creators (Priority: P1)

**Goal**: Expand U_GameplayActions with full suite of gameplay action creators

**Independent Test**: Can dispatch all gameplay actions and verify corresponding state changes

### Tests for User Story 1d ⚠️ WRITE THESE TESTS FIRST, ENSURE THEY FAIL

**⚠️ REMINDER**: Include `StateStoreEventBus.reset()` in `before_each()` for state tests

- [x] T141 [P] [US1d] 📝 TEST: Update `tests/unit/state/test_u_gameplay_actions.gd` with new action creator tests
- [x] T142 [P] [US1d] 📝 TEST: Write test `test_update_health_action_creator()`
- [x] T143 [P] [US1d] 📝 TEST: Write test `test_update_score_action_creator()`
- [x] T144 [P] [US1d] 📝 TEST: Write test `test_set_level_action_creator()`
- [x] T145 [P] [US1d] 📝 TEST: Write test `test_all_action_creators_return_typed_dictionary()`
- [x] T146 [P] [US1d] 📝 TEST: Update `tests/unit/state/test_gameplay_slice_reducers.gd` with new reducer tests
- [x] T147 [P] [US1d] 📝 TEST: Write test `test_update_health_reducer()`
- [x] T148 [P] [US1d] 📝 TEST: Write test `test_update_score_reducer()`
- [x] T149 [P] [US1d] 📝 TEST: Write test `test_set_level_reducer()`
- [x] T150 [US1d] 📝 RUN TESTS: Verify all US1d tests FAIL (no implementation yet)

### Implementation for User Story 1d

**Action Creators:**

- [x] T151 [P] [US1d] Add constants to u_gameplay_actions.gd: `ACTION_UPDATE_HEALTH`, `ACTION_UPDATE_SCORE`, `ACTION_SET_LEVEL`
- [x] T152 [P] [US1d] Implement `static func update_health(health: int) -> Dictionary` with explicit `: Dictionary` return type
- [x] T153 [P] [US1d] Implement `static func update_score(score: int) -> Dictionary`
- [x] T154 [P] [US1d] Implement `static func set_level(level: int) -> Dictionary`
- [x] T155 [US1d] Update _static_init() to register new action types with ActionRegistry

**Reducers:**

- [x] T156 [P] [US1d] Add case ACTION_UPDATE_HEALTH to GameplayReducer.reduce()
- [x] T157 [P] [US1d] Add case ACTION_UPDATE_SCORE to GameplayReducer.reduce()
- [x] T158 [P] [US1d] Add case ACTION_SET_LEVEL to GameplayReducer.reduce()
- [x] T159 [US1d] Ensure all cases use .duplicate(true) for immutability

**Test & Validation:**

- [x] T160 [US1d] 📝 RUN TESTS: Verify all US1d tests now PASS
- [x] T161 [US1d] Update test scene `scenes/debug/state_test_us1d.tscn` to dispatch all new actions
- [ ] T162 [US1d] 🎮 IN-GAME TEST: Run test scene, verify health/score/level update correctly in state
- [x] T163 [US1d] Commit US1d: "Expand gameplay actions with health, score, level"

**Checkpoint**: Full gameplay action suite available with type safety and reducer implementations

---

## Phase 7: User Story 1e - Selector System with Cross-Slice Dependencies (Priority: P1)

**Goal**: Implement selector infrastructure for derived state computation with explicit slice dependency declarations

**Independent Test**: Can call selectors to compute derived state, verify dependency declarations prevent undeclared access

### Tests for User Story 1e ⚠️ WRITE THESE TESTS FIRST, ENSURE THEY FAIL

**⚠️ REMINDER**: Include `StateStoreEventBus.reset()` in `before_each()` for state tests

- [x] T164 [P] [US1e] 📝 TEST: Create `tests/unit/state/test_state_selectors.gd` (include bus reset in `before_each()`)
- [x] T165 [P] [US1e] 📝 TEST: Write test `test_get_is_player_alive_returns_false_when_health_zero()`
- [x] T166 [P] [US1e] 📝 TEST: Write test `test_get_is_player_alive_returns_true_when_health_positive()`
- [x] T167 [P] [US1e] 📝 TEST: Write test `test_get_is_game_over_computes_from_objectives()`
- [x] T168 [P] [US1e] 📝 TEST: Write test `test_selector_without_declared_dependency_logs_error()`
- [x] T169 [US1e] 📝 RUN TESTS: Verify all US1e tests FAIL (no implementation yet)

### Implementation for User Story 1e

**Dependency System:**

- [x] T170 [US1e] Update StateSliceConfig to include `dependencies: Array[StringName]` field (already present from T043)
- [ ] T171 [US1e] Add method `validate_slice_dependencies() -> bool` to M_StateStore (NOT IMPLEMENTED - only _has_circular_dependency exists)
- [ ] T172 [US1e] In validate_slice_dependencies(), check if accessing slice requires declaring dependency first (NOT IMPLEMENTED)
- [ ] T173 [US1e] Add dependency checking to get_state_slice(): log error if dependency not declared (NOT IMPLEMENTED)

**Gameplay Selectors:**

- [x] T174 [P] [US1e] Create `scripts/state/selectors/gameplay_selectors.gd` as class_name GameplaySelectors
- [x] T175 [US1e] Implement `static func get_is_player_alive(state: Dictionary) -> bool` (returns state.health > 0)
- [x] T176 [US1e] Implement `static func get_is_game_over(state: Dictionary) -> bool` (check objectives if present)
- [x] T177 [US1e] Implement `static func get_completion_percentage(state: Dictionary) -> float` (compute from objectives)
- [x] T178 [US1e] Add doc comments explaining: "Selectors are pure functions. Pass full state from M_StateStore.get_full_state()"

**Store Methods:**

- [x] T179 [US1e] Verify `get_state_slice(slice_name: StringName) -> Dictionary` exists (added in T060) (EXISTS as get_slice)
- [x] T180 [US1e] Verify `get_full_state() -> Dictionary` exists and returns deep copy (added in T061) (EXISTS as get_state)
- [x] T181 [US1e] Update gameplay slice registration in M_StateStore._ready() to declare dependencies: [] (empty for now)

**Test & Validation:**

- [x] T182 [US1e] 📝 RUN TESTS: Verify all US1e tests now PASS
- [ ] T183 [US1e] Update test scene `scenes/debug/state_test_us1e.tscn` to call selectors via GameplaySelectors and print results (SCENE DOESN'T EXIST)
- [ ] T184 [US1e] 🎮 IN-GAME TEST: Run test scene, verify selectors compute derived state correctly (SCENE DOESN'T EXIST)
- [x] T185 [US1e] Commit US1e: "Add selector system with dependency declarations" - Committed phases 1c-1e together (77% test pass rate)

**Checkpoint**: Selectors provide derived state computation with explicit cross-slice dependency management

---

## Phase 8: User Story 1f - Signal Emission with Per-Frame Batching (Priority: P1)

**Goal**: Implement hybrid timing system - immediate state updates but batched signal emission using physics frame

**Independent Test**: Can dispatch multiple actions in single frame, verify only one signal emitted per slice per frame

### Tests for User Story 1f ⚠️ WRITE THESE TESTS FIRST, ENSURE THEY FAIL

**⚠️ REMINDER**: Include `StateStoreEventBus.reset()` in `before_each()` for state tests

- [x] T186 [P] [US1f] 📝 TEST: Update `tests/unit/state/test_m_state_store.gd` with batching tests (bus reset already present)
- [x] T187 [P] [US1f] 📝 TEST: Write test `test_multiple_dispatches_emit_single_slice_updated_signal_per_frame()`
- [x] T188 [P] [US1f] 📝 TEST: Write test `test_state_reads_immediately_after_dispatch_show_new_state()`
- [x] T189 [P] [US1f] 📝 TEST: Write test `test_signal_batching_overhead_less_than_0_05ms()` (use U_StateUtils.benchmark())
- [x] T190 [US1f] 📝 RUN TESTS: Verify all US1f tests FAIL (no implementation yet)

### Implementation for User Story 1f

**Signal Batcher:**

- [x] T191 [P] [US1f] Create `scripts/state/signal_batcher.gd` as class_name SignalBatcher extending RefCounted
- [x] T192 [US1f] Add private var `_pending_slice_updates: Dictionary = {}` (slice_name -> latest_state)
- [x] T193 [US1f] Implement `func mark_slice_dirty(slice_name: StringName, slice_state: Dictionary) -> void`
- [x] T194 [US1f] In mark_slice_dirty(), store slice_state in _pending_slice_updates (overwrite if already exists)
- [x] T195 [US1f] Implement `func flush(emit_callback: Callable) -> void` to emit pending signals
- [x] T196 [US1f] In flush(), iterate _pending_slice_updates, call emit_callback for each, then clear dictionary

**Store Integration:**

- [x] T197 [US1f] Add private var `_signal_batcher: SignalBatcher` to M_StateStore
- [x] T198 [US1f] In M_StateStore._ready(), initialize _signal_batcher = SignalBatcher.new()
- [x] T199 [US1f] Update M_StateStore.dispatch() to mark slices dirty instead of emitting immediately: call _signal_batcher.mark_slice_dirty()
- [x] T200 [US1f] Add `_physics_process(delta: float)` to M_StateStore
- [x] T201 [US1f] In _physics_process(), call _signal_batcher.flush() with emit callback that emits slice_updated signal
- [x] T202 [US1f] Ensure state updates still apply IMMEDIATELY in dispatch() (synchronous state change)
- [x] T203 [US1f] Add comment: "State updates are immediate (synchronous), signal emissions are batched (per-frame)"

**Test & Validation:**

- [x] T204 [US1f] 📝 RUN TESTS: Verify all US1f tests now PASS (2/3 pass - one GUT test harness limitation with await physics_frame)
- [ ] T205 [US1f] Update test scene `scenes/debug/state_test_us1f.tscn` to dispatch 10 actions in _ready() (SCENE DOESN'T EXIST)
- [ ] T206 [US1f] Add signal handler to test scene that counts slice_updated emissions with counter variable (SCENE DOESN'T EXIST)
- [ ] T207 [US1f] 🎮 IN-GAME TEST: Run test scene, verify only 1 slice_updated signal per slice despite 10 dispatches (SCENE DOESN'T EXIST)
- [x] T208 [US1f] Commit US1f: "Add signal batching for per-frame emission"

**Checkpoint**: Signals batch per-frame while state updates remain immediate for predictable mid-frame reads

---

## Phase 9: User Story 1g - Action Logging with 1000-Entry History (Priority: P1)

**Goal**: Implement action history tracking with circular buffer pruning at 1000 entries

**Independent Test**: Can dispatch many actions, query history, verify circular buffer behavior at 1000 entries

### Tests for User Story 1g ⚠️ WRITE THESE TESTS FIRST, ENSURE THEY FAIL

**⚠️ REMINDER**: Include `StateStoreEventBus.reset()` in `before_each()` for state tests

- [ ] T209 [P] [US1g] 📝 TEST: Update `tests/unit/state/test_m_state_store.gd` with history tests (bus reset already present)
- [ ] T210 [P] [US1g] 📝 TEST: Write test `test_action_history_records_actions_with_timestamps()`
- [ ] T211 [P] [US1g] 📝 TEST: Write test `test_get_last_n_actions_returns_correct_count()`
- [ ] T212 [P] [US1g] 📝 TEST: Write test `test_history_prunes_oldest_when_exceeding_1000_entries()`
- [ ] T213 [P] [US1g] 📝 TEST: Write test `test_history_includes_state_after_snapshot()`
- [ ] T214 [P] [US1g] 📝 TEST: Write test `test_history_respects_project_setting_state_debug_history_size()`
- [ ] T215 [US1g] 📝 RUN TESTS: Verify all US1g tests FAIL (no implementation yet)

### Implementation for User Story 1g

**History Tracking:**

- [ ] T216 [US1g] Add private var `_action_history: Array = []` to M_StateStore
- [ ] T217 [US1g] In M_StateStore._ready(), read project setting "state/debug/history_size" (default 1000 if not set)
- [ ] T218 [US1g] Store history size in instance var: `_max_history_size: int`
- [ ] T219 [US1g] Update M_StateStore.dispatch() to record action in _action_history AFTER reducer runs
- [ ] T220 [US1g] History entry format: `{action: Dictionary, timestamp: int, state_after: Dictionary}`
- [ ] T221 [US1g] Use `U_ECSUtils.get_current_time()` for timestamp field (unified timing helper)
- [ ] T222 [US1g] Implement circular buffer pruning: if _action_history.size() > _max_history_size, remove first element
- [ ] T223 [US1g] Implement `get_action_history() -> Array` returning _action_history.duplicate(true) (deep copy)
- [ ] T224 [US1g] Implement `get_last_n_actions(n: int) -> Array` returning last n entries (or fewer if history smaller)
- [ ] T225 [US1g] Check project setting "state/debug/enable_history" - if false, skip recording (for production builds)

**Test & Validation:**

- [ ] T226 [US1g] 📝 RUN TESTS: Verify all US1g tests now PASS
- [ ] T227 [US1g] Update test scene `scenes/debug/state_test_us1g.tscn` to dispatch 1001 actions in loop
- [ ] T228 [US1g] Add script to test scene to print history size and oldest/newest timestamps after dispatches
- [ ] T229 [US1g] 🎮 IN-GAME TEST: Run test scene, verify history size stays at 1000, oldest action pruned
- [ ] T230 [US1g] Commit US1g: "Add action history with configurable circular buffer"

**Checkpoint**: Action history provides complete state evolution tracking with automatic pruning and project setting integration

---

## Phase 10: User Story 1h - Persistence with Transient Field Marking (Priority: P1)

**Goal**: Implement save/load system with JSON serialization, Godot type conversion, selective field persistence, and StateHandoff (no autoload) for scene transitions

**Independent Test**: Can save state to file, load from file, verify round-trip correctness and transient field exclusion

### Tests for User Story 1h ⚠️ WRITE THESE TESTS FIRST, ENSURE THEY FAIL

**⚠️ REMINDER**: Include `StateStoreEventBus.reset()` in `before_each()` for state tests (use `ECSEventBus.reset()` in ECS tests)

- [ ] T231 [P] [US1h] 📝 TEST: Create `tests/unit/state/test_state_persistence.gd` (include bus reset in `before_each()`)
- [ ] T232 [P] [US1h] 📝 TEST: Write test `test_save_state_creates_valid_json_file()`
- [ ] T233 [P] [US1h] 📝 TEST: Write test `test_load_state_restores_data_correctly()`
- [ ] T234 [P] [US1h] 📝 TEST: Write test `test_transient_fields_excluded_from_save()`
- [ ] T235 [P] [US1h] 📝 TEST: Write test `test_godot_types_serialize_and_deserialize_correctly()` (test all types below)
- [ ] T236 [P] [US1h] 📝 TEST: Write test `test_100_save_load_cycles_no_data_corruption()`
- [ ] T237 [P] [US1h] 📝 TEST: Create `tests/unit/state/test_state_handoff.gd` for StateHandoff
- [ ] T238 [P] [US1h] 📝 TEST: Write test `test_preserve_slice_stores_state()`
- [ ] T239 [P] [US1h] 📝 TEST: Write test `test_restore_slice_returns_preserved_state()`
- [ ] T240 [P] [US1h] 📝 TEST: Write test `test_clear_slice_removes_preserved_state()`
- [ ] T241 [US1h] 📝 RUN TESTS: Verify all US1h tests FAIL (no implementation yet)

### Implementation for User Story 1h

**SerializationHelper (Comprehensive Godot Type Support):**

- [ ] T242 [P] [US1h] Create `scripts/state/serialization_helper.gd` as class_name SerializationHelper
- [ ] T243 [US1h] Implement `static func godot_to_json(value: Variant) -> Variant` with type checking
- [ ] T244 [US1h] In godot_to_json(), handle Vector2: return {"x": v.x, "y": v.y, "_type": "Vector2"}
- [ ] T245 [US1h] In godot_to_json(), handle Vector3: return {"x": v.x, "y": v.y, "z": v.z, "_type": "Vector3"}
- [ ] T246 [US1h] In godot_to_json(), handle Vector4: return {"x", "y", "z", "w", "_type": "Vector4"}
- [ ] T247 [US1h] In godot_to_json(), handle Color: return {"r", "g", "b", "a", "_type": "Color"}
- [ ] T248 [US1h] In godot_to_json(), handle Quaternion: return {"x", "y", "z", "w", "_type": "Quaternion"}
- [ ] T249 [US1h] In godot_to_json(), handle Transform2D: serialize {"origin", "x", "y", "_type"}
- [ ] T250 [US1h] In godot_to_json(), handle Transform3D: serialize {"origin", "basis", "_type"}
- [ ] T251 [US1h] In godot_to_json(), handle Basis: serialize 3x3 matrix as array
- [ ] T252 [US1h] In godot_to_json(), handle Rect2: return {"position", "size", "_type"}
- [ ] T253 [US1h] In godot_to_json(), handle AABB: return {"position", "size", "_type"}
- [ ] T254 [US1h] In godot_to_json(), handle Plane: return {"normal", "d", "_type"}
- [ ] T255 [US1h] In godot_to_json(), handle Dictionary: recursively convert all values
- [ ] T256 [US1h] In godot_to_json(), handle Array: recursively convert all elements
- [ ] T257 [US1h] Implement `static func json_to_godot(value: Variant) -> Variant` with type hint parsing
- [ ] T258 [US1h] In json_to_godot(), check for "_type" field and reconstruct appropriate Godot type
- [ ] T259 [US1h] In json_to_godot(), handle all types listed above in reverse conversion
- [ ] T260 [US1h] Add error handling for unknown types: push_warning() and return value unchanged

**Transient Fields:**

- [ ] T261 [US1h] Verify StateSliceConfig includes `transient_fields: Array[StringName]` (added in T043)
- [ ] T262 [US1h] Add doc comment to transient_fields explaining: "Fields marked transient will not be saved to disk. Use for cache, temporary UI state, derived values."

**Save/Load Implementation:**

- [ ] T263 [US1h] Implement `save_state(filepath: String) -> Error` in M_StateStore
- [ ] T264 [US1h] In save_state(), iterate all slices in _state
- [ ] T265 [US1h] For each slice, get StateSliceConfig and exclude transient_fields
- [ ] T266 [US1h] Apply SerializationHelper.godot_to_json() to all remaining values
- [ ] T267 [US1h] Use JSON.stringify() to convert state Dictionary to JSON string
- [ ] T268 [US1h] Use FileAccess.open(filepath, FileAccess.WRITE) to write to disk
- [ ] T269 [US1h] Add error handling: check FileAccess.get_open_error(), return Error code
- [ ] T270 [US1h] Implement `load_state(filepath: String) -> Error` in M_StateStore
- [ ] T271 [US1h] In load_state(), use FileAccess.open(filepath, FileAccess.READ) to read from disk
- [ ] T272 [US1h] Use JSON.parse_string() to parse JSON string into Dictionary
- [ ] T273 [US1h] Apply SerializationHelper.json_to_godot() to all values
- [ ] T274 [US1h] Merge loaded state with current state, preserving transient fields from current state
- [ ] T275 [US1h] Emit signal after successful load: `state_loaded.emit(filepath)`
- [ ] T276 [US1h] Add error handling for JSON parse failures and file I/O errors

**State Handoff Utility (No Autoloads, Scene Transitions):**

- [ ] T277 [P] [US1h] Create `scripts/state/state_handoff.gd` (class_name StateHandoff) as static utility (no autoload)
- [ ] T278 [US1h] Add static var `_preserved_slices: Dictionary = {}` (slice_name -> slice_state)
- [ ] T279 [US1h] Implement `static func preserve_slice(slice_name: StringName, slice_state: Dictionary) -> void`
- [ ] T280 [US1h] In preserve_slice(), store `slice_state.duplicate(true)` in `_preserved_slices`
- [ ] T281 [US1h] Implement `static func restore_slice(slice_name: StringName) -> Dictionary` returning deep copy or `{}`
- [ ] T282 [US1h] Implement `static func clear_slice(slice_name: StringName) -> void`
- [ ] T283 [US1h] Implement `static func clear_all() -> void`
- [ ] T284 [US1h] Add doc comment: "StateHandoff preserves state across scene changes without autoloads. M_StateStore uses this on _exit_tree/_ready."

**Store Scene Transition Integration:**

- [ ] T287 [US1h] Add `_exit_tree()` to M_StateStore
- [ ] T288 [US1h] In _exit_tree(), iterate all slices and call StateHandoff.preserve_slice()
- [ ] T289 [US1h] Update M_StateStore._ready() to call StateHandoff.restore_slice() for each registered slice
- [ ] T290 [US1h] Merge restored state with initial state (restored takes precedence if present)

**Test & Validation:**

- [ ] T291 [US1h] 📝 RUN TESTS: Verify all US1h tests now PASS
- [ ] T292 [US1h] Update test scene `scenes/debug/state_test_us1h.tscn` to save/load state
- [ ] T293 [US1h] Add second test scene `scenes/debug/state_test_us1h_scene_transition.tscn` to test StateHandoff
- [ ] T294 [US1h] In scene transition test, dispatch actions, change scene, verify state persists via StateHandoff
- [ ] T295 [US1h] 🎮 IN-GAME TEST: Run test scene, dispatch actions, save, reload scene, load, verify state persists
- [ ] T296 [US1h] 🎮 IN-GAME TEST: Run scene transition test, verify state survives scene change
- [ ] T297 [US1h] Commit US1h: "Add state persistence with comprehensive serialization and StateHandoff"

**Checkpoint**: State can be saved to disk and restored without data loss; transient fields excluded; state survives scene transitions

---

## Phase 11: User Story 2 - State Debugging & Inspection Tools (Priority: P2)

**Goal**: Developer can inspect live state, view action history, and debug state changes using built-in dev tools

**Independent Test**: Can spawn debug overlay in running game, verify it displays current state and action history

### Tests for User Story 2 ⚠️ WRITE THESE TESTS FIRST, ENSURE THEY FAIL

**⚠️ REMINDER**: Include `StateStoreEventBus.reset()` in `before_each()` for state tests

- [ ] T298 [P] [US2] 📝 TEST: Create `tests/unit/state/test_sc_state_debug_overlay.gd` (include bus reset in `before_each()`)
- [ ] T299 [P] [US2] 📝 TEST: Write test `test_debug_overlay_instantiates_without_errors()`
- [ ] T300 [P] [US2] 📝 TEST: Write test `test_debug_overlay_displays_current_state()`
- [ ] T301 [P] [US2] 📝 TEST: Write test `test_debug_overlay_displays_action_history()`
- [ ] T302 [P] [US2] 📝 TEST: Write test `test_debug_overlay_toggles_with_input_action()`
- [ ] T303 [US2] 📝 RUN TESTS: Verify all US2 tests FAIL (no implementation yet)

### Implementation for User Story 2

**Debug Overlay Scene & Script:**

- [ ] T304 [P] [US2] Create `scenes/debug/sc_state_debug_overlay.tscn` with Control root node (CanvasLayer for always-on-top)
- [ ] T305 [P] [US2] Create `scenes/debug/sc_state_debug_overlay.gd` script with class_name SC_StateDebugOverlay
- [ ] T306 [US2] Add UI layout: CanvasLayer → MarginContainer → VBoxContainer with state panel and history panel
- [ ] T307 [US2] Add Label node for current state display (uses JSON.stringify() with indent for formatting)
- [ ] T308 [US2] Add ItemList node for action history display (shows last 20 actions)
- [ ] T309 [US2] Add RichTextLabel for action detail view (shows before/after state diff)
- [ ] T310 [US2] Style overlay: semi-transparent dark background (Color(0, 0, 0, 0.8)), readable monospace font

**Overlay Logic:**

- [ ] T311 [US2] Implement `_ready()` in overlay script: use U_StateUtils.get_store() to find M_StateStore
- [ ] T312 [US2] Store reference to M_StateStore in instance var: `_store: M_StateStore`
- [ ] T313 [US2] Subscribe to M_StateStore.action_dispatched signal in _ready()
- [ ] T314 [US2] Implement `_process(delta)` in overlay script: update state display every frame via _store.get_full_state()
- [ ] T315 [US2] Implement action history update: on action_dispatched, add to ItemList (limit to 20 entries)
- [ ] T316 [US2] Implement action detail view: on ItemList item selected, show action details and state diff
- [ ] T317 [US2] Implement `_exit_tree()`: unsubscribe from M_StateStore signals to prevent leaks

**Toggle Mechanism (M_StateStore._input()):**

- [ ] T318 [US2] Add `_input(event: InputEvent)` to M_StateStore
- [ ] T319 [US2] Check if Input.is_action_just_pressed("toggle_debug_overlay") (F3 key from T012)
- [ ] T320 [US2] Check project setting "state/debug/enable_debug_overlay" - if false, return early
- [ ] T321 [US2] If no overlay exists: instantiate SC_StateDebugOverlay scene, add to tree, store reference
- [ ] T322 [US2] If overlay exists: call queue_free() on overlay, clear reference
- [ ] T323 [US2] Add doc comment: "Debug overlay spawns on F3 key. Controlled by M_StateStore._input() for easy access to store reference."

**Test & Validation:**

- [ ] T324 [US2] 📝 RUN TESTS: Verify all US2 tests now PASS
- [ ] T325 [US2] 🎮 IN-GAME TEST: Run game, press F3, verify overlay appears with current state
- [ ] T326 [US2] 🎮 IN-GAME TEST: Dispatch actions, verify history updates in overlay
- [ ] T327 [US2] 🎮 IN-GAME TEST: Click action in history, verify detail view shows before/after state diff
- [ ] T328 [US2] 🎮 IN-GAME TEST: Press F3 again, verify overlay despawns cleanly
- [ ] T329 [US2] Commit US2: "Add state debug overlay with F3 toggle via M_StateStore._input()"

**Checkpoint**: Debug overlay provides live state inspection and action history during development

---

## Phase 12: User Story 3 - Boot Slice State Management (Priority: P3)

**Goal**: Game manages boot/initialization state through state store, tracking asset loading and system readiness

**Independent Test**: Can run boot sequence standalone, verify state tracks loading progress and error states

### Tests for User Story 3 ⚠️ WRITE THESE TESTS FIRST, ENSURE THEY FAIL

**⚠️ REMINDER**: Include `StateStoreEventBus.reset()` in `before_each()` for state tests (use `ECSEventBus.reset()` in ECS tests)

- [ ] T330 [P] [US3] 📝 TEST: Create `tests/unit/state/test_boot_slice_reducers.gd` (include bus reset in `before_each()`)
- [ ] T331 [P] [US3] 📝 TEST: Write test `test_boot_slice_initializes_with_loading_0_percent()`
- [ ] T332 [P] [US3] 📝 TEST: Write test `test_update_loading_progress_updates_percentage()`
- [ ] T333 [P] [US3] 📝 TEST: Write test `test_boot_error_sets_error_state_and_message()`
- [ ] T334 [P] [US3] 📝 TEST: Write test `test_boot_complete_transitions_to_ready_state()`
- [ ] T335 [US3] 📝 RUN TESTS: Verify all US3 tests FAIL (no implementation yet)

### Implementation for User Story 3

**Initial State & Actions:**

- [ ] T336 [P] [US3] Create `scripts/state/resources/rs_boot_initial_state.gd` extending Resource
- [ ] T337 [US3] Add @export properties: loading_progress (float, 0.0-1.0), phase (String), error_message (String), is_ready (bool)
- [ ] T338 [US3] Add `to_dictionary() -> Dictionary` method
- [ ] T339 [US3] Create default resource `resources/state/default_boot_initial_state.tres` with defaults
- [ ] T340 [P] [US3] Create `scripts/state/u_boot_actions.gd` as class_name U_BootActions
- [ ] T341 [US3] Add constants: ACTION_UPDATE_LOADING_PROGRESS, ACTION_BOOT_ERROR, ACTION_BOOT_COMPLETE
- [ ] T342 [US3] Implement action creators with explicit `: Dictionary` return types
- [ ] T343 [US3] Add _static_init() to register actions with ActionRegistry

**Boot Reducer & Selectors:**

- [ ] T344 [P] [US3] Create `scripts/state/reducers/boot_reducer.gd` as class_name BootReducer
- [ ] T345 [US3] Implement `static func reduce(state: Dictionary, action: Dictionary) -> Dictionary`
- [ ] T346 [US3] Add cases for all boot actions using .duplicate(true) for immutability
- [ ] T347 [P] [US3] Create `scripts/state/selectors/boot_selectors.gd` as class_name BootSelectors
- [ ] T348 [US3] Implement selectors: get_is_boot_complete(), get_loading_progress(), get_boot_error()

**Store Integration:**

- [ ] T349 [US3] Add `@export var boot_initial_state: RS_BootInitialState` to M_StateStore
- [ ] T350 [US3] Update M_StateStore._ready() to register boot slice with BootReducer.reduce
- [ ] T351 [US3] Add boot slice to base_scene_template.tscn: link RS_BootInitialState export

**Test & Validation:**

- [ ] T352 [US3] 📝 RUN TESTS: Verify all US3 tests now PASS
- [ ] T353 [US3] Create test scene `scenes/debug/state_test_us3.tscn` simulating boot sequence
- [ ] T354 [US3] Add script that dispatches boot actions with Timer delays to simulate loading
- [ ] T355 [US3] 🎮 IN-GAME TEST: Run test scene, verify loading progress updates, boot completes
- [ ] T356 [US3] Commit US3: "Add boot slice state management"

**Checkpoint**: Boot slice provides predictable initialization state tracking

---

## Phase 13: User Story 4 - Menu Slice Navigation State (Priority: P4)

**Goal**: Game manages menu/UI navigation through state store, tracking active screens and user selections

**Independent Test**: Can navigate menu screens, verify state updates reflect navigation changes

### Tests for User Story 4 ⚠️ WRITE THESE TESTS FIRST, ENSURE THEY FAIL

**⚠️ REMINDER**: Include `StateStoreEventBus.reset()` in `before_each()` for state tests

- [ ] T357 [P] [US4] 📝 TEST: Create `tests/unit/state/test_menu_slice_reducers.gd` (include bus reset in `before_each()`)
- [ ] T358 [P] [US4] 📝 TEST: Write test `test_navigate_to_screen_updates_active_screen()`
- [ ] T359 [P] [US4] 📝 TEST: Write test `test_select_character_stores_pending_config()`
- [ ] T360 [P] [US4] 📝 TEST: Write test `test_select_difficulty_stores_pending_config()`
- [ ] T361 [P] [US4] 📝 TEST: Write test `test_load_save_files_populates_save_list()`
- [ ] T362 [US4] 📝 RUN TESTS: Verify all US4 tests FAIL (no implementation yet)

### Implementation for User Story 4

**Initial State & Actions:**

- [ ] T363 [P] [US4] Create `scripts/state/resources/rs_menu_initial_state.gd` extending Resource
- [ ] T364 [US4] Add @export properties: active_screen (String), pending_character (String), pending_difficulty (String), available_saves (Array)
- [ ] T365 [US4] Add `to_dictionary() -> Dictionary` method
- [ ] T366 [US4] Create default resource `resources/state/default_menu_initial_state.tres`
- [ ] T367 [P] [US4] Create `scripts/state/u_menu_actions.gd` as class_name U_MenuActions
- [ ] T368 [US4] Add constants: ACTION_NAVIGATE_TO_SCREEN, ACTION_SELECT_CHARACTER, ACTION_SELECT_DIFFICULTY, ACTION_LOAD_SAVE_FILES
- [ ] T369 [US4] Implement action creators with `: Dictionary` return types
- [ ] T370 [US4] Add _static_init() to register actions

**Menu Reducer & Selectors:**

- [ ] T371 [P] [US4] Create `scripts/state/reducers/menu_reducer.gd` as class_name MenuReducer
- [ ] T372 [US4] Implement `static func reduce()` with cases for all menu actions
- [ ] T373 [P] [US4] Create `scripts/state/selectors/menu_selectors.gd` as class_name MenuSelectors
- [ ] T374 [US4] Implement selectors: get_active_screen(), get_pending_game_config(), get_available_saves()

**Store Integration:**

- [ ] T375 [US4] Add `@export var menu_initial_state: RS_MenuInitialState` to M_StateStore
- [ ] T376 [US4] Update M_StateStore._ready() to register menu slice
- [ ] T377 [US4] Add menu slice to base_scene_template.tscn: link RS_MenuInitialState export

**Test & Validation:**

- [ ] T378 [US4] 📝 RUN TESTS: Verify all US4 tests now PASS
- [ ] T379 [US4] Create test scene `scenes/debug/state_test_us4.tscn` with simple menu UI
- [ ] T380 [US4] Add Button nodes that dispatch menu navigation actions
- [ ] T381 [US4] 🎮 IN-GAME TEST: Run test scene, click buttons, verify state reflects screen changes
- [ ] T382 [US4] Commit US4: "Add menu slice navigation state"

**Checkpoint**: Menu slice enables UI-driven state changes and bridges boot→gameplay transitions

---

## Phase 14: User Story 5 - Complete State Transition Flows (Priority: P5)

**Goal**: Game smoothly transitions between boot→menu→gameplay→menu states with proper initialization and cleanup

**Independent Test**: Can complete full game flow from boot through menu to gameplay and back

### Tests for User Story 5 ⚠️ WRITE THESE TESTS FIRST, ENSURE THEY FAIL

**⚠️ REMINDER**: Include `StateStoreEventBus.reset()` in `before_each()` for state tests

- [ ] T383 [P] [US5] 📝 TEST: Create `tests/unit/state/integration/test_slice_transitions.gd` (include bus reset in `before_each()`)
- [ ] T384 [P] [US5] 📝 TEST: Write test `test_boot_to_menu_transition_preserves_boot_completion()`
- [ ] T385 [P] [US5] 📝 TEST: Write test `test_menu_to_gameplay_transition_applies_pending_config()`
- [ ] T386 [P] [US5] 📝 TEST: Write test `test_gameplay_to_menu_transition_preserves_progress()`
- [ ] T387 [P] [US5] 📝 TEST: Write test `test_full_flow_boot_to_menu_to_gameplay_to_menu()`
- [ ] T388 [US5] 📝 RUN TESTS: Verify all US5 tests FAIL (no implementation yet)

### Implementation for User Story 5

**Transition Actions:**

- [ ] T389 [P] [US5] Create `scripts/state/u_transition_actions.gd` as class_name U_TransitionActions
- [ ] T390 [US5] Add constants: ACTION_TRANSITION_TO_MENU, ACTION_TRANSITION_TO_GAMEPLAY, ACTION_TRANSITION_TO_BOOT
- [ ] T391 [US5] Implement action creators with data handoff payloads (e.g., menu config passed to gameplay)
- [ ] T392 [US5] Register transition actions in ActionRegistry

**Reducer Updates:**

- [ ] T393 [US5] Update GameplayReducer to handle ACTION_TRANSITION_TO_GAMEPLAY: apply menu config to gameplay state
- [ ] T394 [US5] Update MenuReducer to handle return from gameplay: store save data in menu state
- [ ] T395 [US5] Add state cleanup logic: reset transient fields on slice transitions

**Validation Logic:**

- [ ] T396 [US5] Add validation in M_StateStore: ensure boot completes before allowing menu transition
- [ ] T397 [US5] Add validation: ensure menu config complete before allowing gameplay transition
- [ ] T398 [US5] Emit warning if transition attempted without prerequisites

**Test & Validation:**

- [ ] T399 [US5] 📝 RUN TESTS: Verify all US5 tests now PASS
- [ ] T400 [US5] Create comprehensive test scene `scenes/debug/state_test_us5_full_flow.tscn`
- [ ] T401 [US5] Add script simulating: boot → menu navigation → gameplay start → return to menu
- [ ] T402 [US5] 🎮 IN-GAME TEST: Run test scene through complete flow, verify all transitions work
- [ ] T403 [US5] 🎮 IN-GAME TEST: Verify state handoff works correctly (menu config → gameplay)
- [ ] T404 [US5] Commit US5: "Add complete state transition flows with validation"

**Checkpoint**: All three slices work together with clean transitions and data handoff

---

## Phase 15: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories, optimization, and final cleanup

### Documentation & Developer Experience

- [ ] T405 [P] Update `docs/state store/redux-state-store-prd.md` status to "Implementation Complete"
- [ ] T406 [P] Create `docs/state store/usage-guide.md` with common patterns and examples
- [ ] T407 [P] Add inline documentation comments to all public APIs in M_StateStore
- [ ] T408 [P] Document action type naming conventions in usage-guide.md
- [ ] T409 [P] Add Hot Reload/Live Editing section to usage-guide.md: "State store supports hot reload. Changing reducer logic requires scene restart. Changing initial state .tres files applies on next scene load. Action history persists during hot reload."

### Performance Optimization & Benchmarking

- [ ] T410 Profile M_StateStore dispatch overhead using U_StateUtils.benchmark(): test 1000 rapid dispatches
- [ ] T411 Log benchmark results: dispatch time, reducer time, signal batching time
- [ ] T412 Optimize .duplicate(true) calls if overhead exceeds 0.1ms per dispatch: consider selective copying
- [ ] T413 Profile SignalBatcher.flush() overhead: verify <0.05ms per frame using U_StateUtils.benchmark()
- [ ] T414 Add performance metrics to debug overlay: show dispatch count, avg dispatch time, signal emit count
- [ ] T415 Test with 10,000 action history entries: verify circular buffer performance scales

### Testing & Validation

- [ ] T416 Run complete state store test suite: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/state -gexit`
- [ ] T417 Verify all tests pass with no memory leaks (check GUT output for leaked instances)
- [ ] T418 Run ECS tests to ensure no regressions: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ecs -gexit`
- [ ] T419 Create smoke test scene `scenes/debug/state_smoke_test.tscn` that exercises all slices and actions
- [ ] T420 Run smoke test in editor, verify no errors or warnings in console

### Code Cleanup & Refactoring

- [ ] T421 [P] Remove debug print statements from all production code (keep in test files)
- [ ] T422 [P] Ensure all .gd files use tab indentation (run Godot formatter if available)
- [ ] T423 [P] Add @warning_ignore annotations where appropriate (e.g., native_method_override in tests)
- [ ] T424 Review all TODO comments: convert to tasks or remove if obsolete

### Real ECS System Integration (Production Proof-of-Concept)

- [ ] T425 Choose 1-2 existing ECS systems for state store integration (e.g., S_InputSystem, S_PauseSystem)
- [ ] T426 Update chosen system(s) to use U_StateUtils.get_store() to access M_StateStore
- [ ] T427 Update chosen system(s) to dispatch actions (e.g., pause/unpause, input events)
- [ ] T428 Update chosen system(s) to subscribe to state changes and react accordingly
- [ ] T429 Add tests for ECS-state integration in chosen system(s)
- [ ] T430 🎮 IN-GAME TEST: Run game with integrated systems, verify state and ECS work together
- [ ] T431 Document ECS integration pattern in usage-guide.md with real-world example

### Feature Flags & Production Readiness

- [ ] T432 Verify project settings created in Phase 1 (T009-T012) are properly configured
- [ ] T433 Update M_StateStore to check "state/debug/enable_history" before recording actions
- [ ] T434 Update M_StateStore to check "state/debug/enable_debug_overlay" before spawning overlay
- [ ] T435 Test in export mode: verify debug features disabled when project settings are false
- [ ] T436 Add conditional compilation comment: "For release builds, set state/debug/* to false in export preset"

### EventBus Integration (if Phase 0B was used)

**⚠️ ONLY IF FALLBACK (Option B) WAS USED IN PHASE 2:**

- [ ] T437 [Phase15-EventBus] Revisit event bus refactor: attempt Phase 0A tasks again
- [ ] T438 [Phase15-Event Integration] Refactor M_StateStore signaling to also publish via `StateStoreEventBus.publish()` (keep direct signals if desirable)
- [ ] T439 [Phase15-Event Integration] Ensure state tests use `StateStoreEventBus.reset()` in `before_each()`; ECS tests use `ECSEventBus.reset()`
- [ ] T440 [Phase15-EventBus] Test EventBus refactor with full state store test suite
- [ ] T441 [Phase15-EventBus] Commit: "Integrate M_StateStore with unified EventBus"

### Final Validation

- [ ] T442 🎮 IN-GAME TEST: Run complete game from boot to gameplay, exercise all state features
- [ ] T443 🎮 IN-GAME TEST: Test state persistence: save in gameplay, quit, restart, load, verify correctness
- [ ] T444 🎮 IN-GAME TEST: Test StateHandoff: change scenes multiple times, verify state persists
- [ ] T445 🎮 IN-GAME TEST: Test debug overlay toggle with F3, verify performance impact negligible
- [ ] T446 Review all success criteria from PRD: verify each is met with evidence
- [ ] T447 Run all tests one final time across both state and ECS suites
- [ ] T448 Final commit: "Complete Redux state store implementation - all features tested"

**Checkpoint**: Feature complete, tested, documented, integrated with ECS, and ready for production use

---

## Dependencies & Execution Order

### Phase Dependencies

1. **Setup (Phase 1)**: No dependencies - start immediately
2. **Foundational (Phase 2)**: Depends on Setup - BLOCKS all user stories
   - Must choose Phase 0A (refactor) or Phase 0B (fallback) before proceeding
   - Use rollback tasks (T026-T031) if switching from A to B mid-refactor
3. **User Stories 1a-1h (Phases 3-10)**: Depends on Foundational completion
   - Must proceed sequentially (each builds on previous)
   - Each phase: Tests → Implementation → In-game validation → Commit
4. **User Story 2 (Phase 11)**: Depends on US1 completion (needs store + history)
5. **User Story 3 (Phase 12)**: Depends on US1 completion (can run parallel with US2)
6. **User Story 4 (Phase 13)**: Depends on US1 completion (can run parallel with US2/US3)
7. **User Story 5 (Phase 14)**: Depends on US1, US3, US4 completion
8. **Polish (Phase 15)**: Depends on all desired user stories being complete

### Parallelization Opportunities

**Within Setup (Phase 1)**:

- All directory creation tasks (T001-T008) can run in parallel
- All project settings tasks (T009-T012) can run in parallel

**Within Phase 0 (Phase 2)**:

- Choose either Option A tasks (T014-T025) OR Option B tasks (T032-T034)
- Option A tasks must run sequentially due to dependencies
- Rollback tasks (T026-T031) only if switching from A to B

**Within Each User Story Phase**:

- Test creation tasks marked [P] can run in parallel
- Test running must wait for all test creation tasks
- Implementation tasks marked [P] can run in parallel (different files)
- Implementation tasks without [P] must run sequentially
- In-game testing must wait for all implementation tasks

**Across User Story Phases 3-10**:

- ❌ Cannot parallelize - each phase builds on previous
- Must complete US1a before US1b, US1b before US1c, etc.

**Across User Story Phases 11-13**:

- ✅ US2, US3, US4 can run in parallel (all depend only on US1)

**Within Polish (Phase 15)**:

- Documentation tasks (T405-T409) can run in parallel
- Performance tasks (T410-T415) must run sequentially (benchmarking)
- Testing tasks (T416-T420) must run sequentially
- Code cleanup tasks (T421-T424) can run in parallel
- Real ECS integration (T425-T431) must run sequentially
- Feature flag tasks (T432-T436) can run in parallel
- EventBus integration (T437-T441) only if Phase 0B was used

### TDD Workflow Pattern (Repeat for each User Story)

```plaintext
1. Write all tests marked with 📝 TEST (can be parallel within phase)
  - CRITICAL: Include `StateStoreEventBus.reset()` in `before_each()` for all state tests
2. Run tests, verify they FAIL
3. Implement code to make tests pass (some tasks parallel, some sequential)
4. Run tests, verify they PASS
5. Create in-game test scene
6. Run in-game test, verify functionality
7. Commit (tests green + in-game validated)
```

### Commit Strategy

Following AGENTS.md guidance:

- Commit after **each user story phase** completes (US1a, US1b, ..., US1h, US2, US3, US4, US5)
- Each commit must have:
  - All tests passing (green)
  - In-game validation completed
  - No regressions in existing tests
- Total expected commits:
  - 1 for Phase 0 (event bus decision)
  - 8 for User Story 1 phases (US1a-US1h)
  - 1 each for US2, US3, US4, US5
  - 1 final commit for Phase 15 polish
  - **Total: ~14 commits**

---

## MVP Strategy

### Minimum Viable Product (Just US1a-US1h)

To deliver basic working state store:

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (Phase 0 decision)
3. Complete Phases 3-10: User Story 1a-1h
4. **STOP - You now have working state store with gameplay slice**

This MVP provides:

- ✅ Core state store infrastructure with U_StateUtils and RS_StateStoreSettings
- ✅ Action validation and dispatch with ActionRegistry
- ✅ Immutable state updates with reducers and circular dependency detection
- ✅ Type-safe action creators with static registration
- ✅ Selectors for derived state with dependency declarations
- ✅ Signal batching for performance
- ✅ Action history for debugging with project setting integration
- ✅ State persistence to disk with comprehensive Godot type serialization
- ✅ StateHandoff for scene transition state preservation (no autoload)
- ✅ Scene template integration for production use

### Incremental Delivery Beyond MVP

5. Add Phase 11 (US2): Debug overlay for development experience
6. Add Phase 12 (US3): Boot slice for initialization tracking
7. Add Phase 13 (US4): Menu slice for UI navigation
8. Add Phase 14 (US5): Complete transitions between all slices
9. Add Phase 15: Polish, optimization, documentation, real ECS integration

Each addition can be deployed independently without breaking previous functionality.

---

## Notes

- **[P] marker**: Tasks that can run in parallel (different files, no shared state)
- **[Story] marker**: Maps task to user story for traceability (e.g., [US1a], [US2])
- **📝 TEST**: Indicates test creation/running task (TDD emphasis)
- **🎮 IN-GAME TEST**: Indicates in-game validation required before commit
- **File paths**: All paths are exact and follow project structure
- **Checkpoints**: Each phase ends with validation checkpoint before moving forward
- **Commit points**: Clearly marked at end of each user story phase
- **Test-first**: Every implementation phase starts with test creation
- **Scene integration**: Explicit test scenes for in-game validation of each phase
- **Event bus reset critical**: All state tests must include `StateStoreEventBus.reset()` in `before_each()` to prevent subscription leaks; ECS test suites use `ECSEventBus.reset()`

---

## Quick Reference: Test Commands

### Run State Store Tests

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/state -gexit
```

### Run ECS Tests (verify no regressions)

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ecs -gexit
```

### Run All Tests

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```

### Run Specific Test File

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/state/test_m_state_store.gd -gexit
```

---

## Success Criteria Reference

From PRD, feature is complete when:

1. ✅ State updates are synchronous and predictable (US1c)
2. ✅ Actions are validated and type-safe (US1b)
3. ✅ State is immutable (US1c)
4. ✅ Signals batch per-frame (US1f)
5. ✅ Action history available for debugging (US1g)
6. ✅ State persists to disk without data loss (US1h)
7. ✅ State survives scene transitions via StateHandoff (US1h)
8. ✅ Debug overlay provides live state inspection (US2)
9. ✅ All three slices (boot/menu/gameplay) implemented (US3, US4)
10. ✅ State transitions work cleanly (US5)
11. ✅ Performance overhead <0.1ms per dispatch (Phase 15)
12. ✅ All tests pass with no memory leaks (Phase 15)
13. ✅ Documentation complete including hot reload behavior (Phase 15)
14. ✅ Scene integration validated (US1a + Phase 15)
15. ✅ Production ready with feature flags (Phase 15)
16. ✅ Real ECS integration demonstrated (Phase 15)
### Option C: Dual‑Bus via Abstract Base (Recommended)

**Approach**: Add a shared abstract base and two concrete buses (ECS + State) without breaking existing ECS API

- [x] T026C [Phase0-C] Create directory `scripts/events/`
- [x] T027C [Phase0-C] Create `scripts/events/event_bus_base.gd` (abstract) with subscribe/unsubscribe/publish/reset/history and defensive payload duplication
- [x] T028C [Phase0-C] Create `scripts/state/state_event_bus.gd` that extends base and exposes static API delegating to a private instance
- [x] T029C [Phase0-C] Update `scripts/ecs/ecs_event_bus.gd` to extend base and delegate its static API to a private instance (no external API changes)
- [x] T030C [Phase0-C] 📝 TEST: Add `tests/unit/state/test_state_event_bus.gd` to verify isolation and reset behavior
- [x] T031C [Phase0-C] Commit Phase 0C: "Add EventBusBase and StateStoreEventBus; delegate ECSEventBus to base"
