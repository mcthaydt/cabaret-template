# Phase 10B - Architectural Hardening Implementation Plan

## Overview

This plan implements all 9 sub-phases of Phase 10B (T130-T143) to improve modularity, testability, and scalability. Estimated effort: 4-6 weeks.

**Execution Order**: 10B-1 → 10B-5, then 10B-6 → 10B-9 (as recommended in tasks)

---

## Phase 10B-1: Manager Coupling Reduction (T130-T133)

### T130: Decouple S_HealthSystem from M_SceneManager

**Current State**:
- Line 20: `var _scene_manager: M_SceneManager = null`
- Lines 181-185: Direct call to `_scene_manager.transition_to_scene()`
- Line 12 in C_HealthComponent: `const EVENT_ENTITY_DEATH := StringName("entity_death")` (defined but unused)

**Implementation**:
1. Update `C_HealthComponent` to publish `entity_death` event in `_handle_death()` method
2. Update `S_HealthSystem` to publish event instead of calling scene manager:
   - Remove `_scene_manager` member variable (line 20)
   - Remove M_SceneManager import (line 15)
   - Publish `entity_death` event with payload: `{entity_id, entity_node, death_reason}`
3. Update `M_SceneManager` to subscribe to `entity_death` event in `_ready()`
   - Add handler: `_on_entity_death(event)` that calls `transition_to_scene("game_over", "fade", Priority.CRITICAL)`

**Files Modified**:
- `scripts/ecs/components/c_health_component.gd`
- `scripts/ecs/systems/s_health_system.gd` (remove lines 15, 20, 181-185)
- `scripts/managers/m_scene_manager.gd` (add event subscription)

**Tests**:
- Update `tests/unit/ecs/systems/test_s_health_system.gd` to verify event publishing (no manager needed)
- Update `tests/integration/scene_manager/test_scene_transitions.gd` to verify death transition via event

---

### T131: Decouple S_VictorySystem from M_SceneManager

**Current State**:
- Line 14: `var _scene_manager: M_SceneManager = null`
- Line 55: Direct call to `_scene_manager.transition_to_scene()`
- System already subscribes to `victory_triggered` event (line 28)

**Implementation**:
1. Remove direct scene manager dependency from S_VictorySystem:
   - Remove `_scene_manager` member variable (line 14)
   - Remove M_SceneManager import (line 8)
   - Remove transition call (line 55)
   - Publish new event: `victory_transition_requested` with payload: `{target_scene, priority}`
2. Update `M_SceneManager` to subscribe to `victory_transition_requested`
   - Add handler that executes the transition

**Files Modified**:
- `scripts/ecs/systems/s_victory_system.gd` (remove lines 8, 14, 55)
- `scripts/managers/m_scene_manager.gd` (add event subscription)

**Tests**:
- Update `tests/unit/ecs/systems/test_s_victory_system.gd` to verify event publishing
- Update `tests/integration/scene_manager/test_scene_transitions.gd` to verify victory transition

---

### T132: Decouple S_CheckpointSystem from direct Area3D connections

**Current State**: Already event-driven (publishes `checkpoint_zone_entered`)

**Implementation**:
- Review C_CheckpointComponent signal cleanup in `_exit_tree()` (lines 184-190)
- Verify no signal leaks
- No changes needed (already compliant)

**Files Modified**: None (verification only)

---

### T133: Add manager initialization assertions

**Current State**: All managers gracefully handle missing M_StateStore

**Implementation**:
1. Add assertions to manager `_ready()` methods:
   - `M_PauseManager._ready()`: Assert store exists after lookup
   - `M_SpawnManager._ready()`: Assert store exists after lookup
   - `M_CameraManager._ready()`: No store dependency (skip)

**Pattern**:
```gdscript
func _ready() -> void:
    super._ready()
    await get_tree().process_frame
    _store = U_StateUtils.get_store(self)
    assert(_store != null, "M_PauseManager requires M_StateStore in 'state_store' group")
```

**Files Modified**:
- `scripts/managers/m_pause_manager.gd`
- `scripts/managers/m_spawn_manager.gd`

**Tests**: Verify assertions fire in test environments without stores

---

## Phase 10B-2: Extract Transition Subsystem (T134-T136b)

### T134: Design TransitionOrchestrator abstraction

**Interface Design**:
```gdscript
# scripts/scene_management/transition_orchestrator.gd
class_name TransitionOrchestrator

func execute_transition(request: TransitionRequest, callbacks: Dictionary) -> void:
    # Lifecycle hooks:
    # 1. initialize() - Setup transition effect
    # 2. execute() - Run pre-swap animation
    # 3. on_scene_swap() - Callback for scene load
    # 4. on_complete() - Finalize transition
```

**Responsibilities**:
- Transition state machine (idle → executing → swapping → completing)
- Effect execution (fade/loading/instant)
- Scene swap sequencing
- Progress tracking callbacks

**Files Created**:
- `scripts/scene_management/transition_orchestrator.gd` (300-400 lines)

---

### T135: Create TransitionOrchestrator

**Implementation**:
1. Extract from `M_SceneManager._perform_transition()` (lines 411-600)
2. Methods:
   - `execute_transition(request, scene_node, callbacks)`
   - `_execute_fade_transition()`
   - `_execute_loading_transition()`
   - `_execute_instant_transition()`
   - `_handle_scene_swap(callback)`
   - `_finalize_transition(callback)`

**Handles**:
- All scene loading strategies (sync/async/cached)
- Progress tracking
- Camera blending coordination
- Closure-based callbacks for async operations

**Files Created**:
- `scripts/scene_management/transition_orchestrator.gd`

---

### T136a: Create i_transition_effect.gd interface

**Interface Design**:
```gdscript
# scripts/scene_management/i_transition_effect.gd
class_name I_TransitionEffect

# Interface methods (implement in subclasses):
func initialize(config: Dictionary) -> void:
    pass

func execute(layer: CanvasLayer, callback: Callable) -> void:
    pass

func on_scene_swap() -> void:
    pass

func on_complete() -> void:
    pass
```

**Files Created**:
- `scripts/scene_management/i_transition_effect.gd`

**Files Modified**:
- `scripts/scene_management/transitions/trans_fade.gd` (extend interface)
- `scripts/scene_management/transitions/trans_loading_screen.gd` (extend interface)
- `scripts/scene_management/transitions/trans_instant.gd` (extend interface)

---

### T136b: Refactor M_SceneManager to use TransitionOrchestrator

**Implementation**:
1. Remove transition logic from M_SceneManager (lines 411-600)
2. Add TransitionOrchestrator instance
3. Delegate to orchestrator:
   ```gdscript
   func _perform_transition(request: TransitionRequest) -> void:
       var callbacks := {
           "on_scene_load": _on_scene_loaded,
           "on_swap": _on_scene_swapped,
           "on_complete": _on_transition_complete
       }
       _transition_orchestrator.execute_transition(request, _loaded_scene, callbacks)
   ```

**Target**: Reduce M_SceneManager from 1120 → ~720 lines

**Files Modified**:
- `scripts/managers/m_scene_manager.gd` (remove 400+ lines, add orchestrator)

**Tests**:
- Update all scene_manager tests to work with new architecture
- Add `tests/unit/scene_management/test_transition_orchestrator.gd`

---

## Phase 10B-3: Scene Type Handler Pattern (T137a-T137c)

### T137a: Design ISceneTypeHandler interface

**Interface Design**:
```gdscript
# scripts/scene_management/i_scene_type_handler.gd
class_name I_SceneTypeHandler

func get_scene_type() -> int:
    return -1

func on_load(scene: Node, scene_id: StringName) -> void:
    pass

func on_unload(scene: Node, scene_id: StringName) -> void:
    pass

func get_required_managers() -> Array[StringName]:
    return []

func should_track_history() -> bool:
    return false

func get_shell_id() -> StringName:
    return StringName("")
```

**Files Created**:
- `scripts/scene_management/i_scene_type_handler.gd`

---

### T137b: Create scene type handlers

**Handlers to Create**:
1. `scripts/scene_management/handlers/gameplay_scene_handler.gd`
   - Returns: SceneType.GAMEPLAY, shell "gameplay", requires M_SpawnManager
2. `scripts/scene_management/handlers/menu_scene_handler.gd`
   - Returns: SceneType.MENU, shell "main_menu", track history
3. `scripts/scene_management/handlers/ui_scene_handler.gd`
   - Returns: SceneType.UI, no shell change, track history
4. `scripts/scene_management/handlers/endgame_scene_handler.gd`
   - Returns: SceneType.END_GAME, shell "endgame"

**Files Created**: 4 handler files

---

### T137c: Create SceneTypeHandlerRegistry

**Implementation**:
```gdscript
# scripts/scene_management/u_scene_type_handler_registry.gd
class_name U_SceneTypeHandlerRegistry

static var _handlers: Dictionary = {}

static func register_handler(scene_type: int, handler: I_SceneTypeHandler) -> void:
    _handlers[scene_type] = handler

static func get_handler(scene_type: int) -> I_SceneTypeHandler:
    return _handlers.get(scene_type)

static func initialize() -> void:
    register_handler(SceneType.GAMEPLAY, GameplaySceneHandler.new())
    register_handler(SceneType.MENU, MenuSceneHandler.new())
    # ... etc
```

**Files Created**:
- `scripts/scene_management/u_scene_type_handler_registry.gd`

**Files Modified**:
- `scripts/managers/m_scene_manager.gd`:
  - Replace `match scene_type:` blocks (lines 949, 978) with `handler.on_load()` calls
  - Call registry in `_ready()`

---

## Phase 10B-4: Input Device Abstraction (T138a-T138d)

### T138a: Design IInputSource interface

**Interface Design**:
```gdscript
# scripts/input/i_input_source.gd
class_name I_InputSource

func get_device_type() -> int:
    return -1

func get_priority() -> int:
    return 0

func get_stick_deadzone(stick: StringName) -> float:
    return 0.2

func is_active() -> bool:
    return false

func capture_input(delta: float) -> Dictionary:
    # Returns: {move_input: Vector2, look_input: Vector2, jump_pressed: bool, etc.}
    return {}

func get_device_id() -> int:
    return -1
```

**Files Created**:
- `scripts/input/i_input_source.gd`

---

### T138b: Create input source implementations

**Sources to Create**:
1. `scripts/input/sources/keyboard_mouse_source.gd`
   - Reads mouse motion, keyboard input
   - Priority: 1 (default)
2. `scripts/input/sources/gamepad_source.gd`
   - Reads joypad axes, buttons
   - Priority: 2 (overrides keyboard when active)
3. `scripts/input/sources/touchscreen_source.gd`
   - Reads MobileControls virtual joystick/buttons
   - Priority: 3 (highest - mobile exclusive)

**Files Created**: 3 source files

---

### T138c: Refactor M_InputDeviceManager to use IInputSource

**Implementation**:
1. Create `scripts/input/u_device_type_constants.gd`:
   ```gdscript
   class_name U_DeviceTypeConstants
   enum DeviceType { KEYBOARD_MOUSE = 0, GAMEPAD = 1, TOUCHSCREEN = 2 }
   ```
2. Update M_InputDeviceManager:
   - Remove local DeviceType enum (lines 12-16)
   - Import U_DeviceTypeConstants
   - Register sources at startup
   - Replace hardcoded checks with polymorphic `source.is_active()` calls

**Files Created**:
- `scripts/input/u_device_type_constants.gd`

**Files Modified**:
- `scripts/managers/m_input_device_manager.gd`
- `scripts/ecs/systems/s_input_system.gd` (import constants)

---

### T138d: Refactor S_InputSystem to use input sources

**Implementation**:
1. Extract device logic to sources (move to source classes)
2. S_InputSystem delegates to active source:
   ```gdscript
   func process_tick(delta: float) -> void:
       var active_source := _get_active_input_source()
       if active_source == null:
           return
       var input_data := active_source.capture_input(delta)
       _store.dispatch(U_GameplayActions.update_input(input_data))
   ```

**Target**: Reduce S_InputSystem from 412 → ~200 lines

**Files Modified**:
- `scripts/ecs/systems/s_input_system.gd` (extract device logic)

---

## Phase 10B-5: State Persistence Extraction (T139a-T139c)

### T139a: Create u_state_repository.gd

**Implementation**:
```gdscript
# scripts/state/utils/u_state_repository.gd
class_name U_StateRepository

static func save_state(filepath: String, state: Dictionary, slice_configs: Dictionary) -> Error:
    # Delegates to U_STATE_PERSISTENCE

static func load_state(filepath: String) -> Dictionary:
    # Returns loaded state or empty dict

static func setup_autosave(store: M_StateStore, interval: float) -> Timer:
    # Creates and configures autosave timer

static func should_autosave(settings: Dictionary) -> bool:
    # Checks enable_persistence flag
```

**Extract From**:
- M_StateStore lines 112-127 (auto-save logic)
- M_StateStore lines 455-466 (save/load methods)

**Files Created**:
- `scripts/state/utils/u_state_repository.gd` (200-250 lines)

---

### T139b: Create u_state_validator.gd

**Implementation**:
```gdscript
# scripts/state/utils/u_state_validator.gd
class_name U_StateValidator

static func normalize_loaded_state(state: Dictionary, registries: Dictionary) -> Dictionary:
    # Extract from M_StateStore._normalize_loaded_state()

static func validate_scene_reference(scene_id: StringName) -> bool:
    # Check U_SceneRegistry

static func validate_spawn_reference(spawn_id: StringName, scene_id: StringName) -> bool:
    # Check spawn exists in scene

static func sanitize_completed_areas(areas: Array) -> Array:
    # Dedupe and validate
```

**Extract From**:
- M_StateStore lines 249-267 (normalization)

**Files Created**:
- `scripts/state/utils/u_state_validator.gd`

---

### T139c: Refactor M_StateStore

**Implementation**:
1. Remove extracted logic
2. Delegate to utilities:
   ```gdscript
   func save_state(filepath: String) -> Error:
       return U_StateRepository.save_state(filepath, _state, _slice_configs)

   func load_state(filepath: String) -> Error:
       var loaded := U_StateRepository.load_state(filepath)
       loaded = U_StateValidator.normalize_loaded_state(loaded, {...})
       _merge_loaded_state(loaded)
       return OK
   ```

**Target**: Reduce M_StateStore from 529 → ~400 lines

**Files Modified**:
- `scripts/state/m_state_store.gd` (remove 130+ lines)

---

## Phase 10B-6: Unified Event Bus Enhancement (T140a-T140c)

### T140a: Extend U_ECSEventBus with typed events

**Typed Event Classes**:
```gdscript
# scripts/ecs/events/health_changed_event.gd
class_name HealthChangedEvent extends Resource
var entity_id: StringName
var old_health: float
var new_health: float
var damage_amount: float

# scripts/ecs/events/entity_death_event.gd
class_name EntityDeathEvent extends Resource
var entity_id: StringName
var entity_node: Node3D
var death_reason: String

# scripts/ecs/events/victory_triggered_event.gd
class_name VictoryTriggeredEvent extends Resource
var trigger_entity_id: StringName
var player_entity_id: StringName
var target_scene: StringName

# scripts/ecs/events/checkpoint_activated_event.gd
class_name CheckpointActivatedEvent extends Resource
var checkpoint_id: StringName
var spawn_point_id: StringName
var entity_id: StringName
```

**Event Priority Support**:
```gdscript
# In base_event_bus.gd
func subscribe(event_name: StringName, callback: Callable, priority: int = 0) -> Callable:
    # Higher priority = called first
    _subscribers[event_name].sort_custom(func(a, b): return a.priority > b.priority)
```

**Subscriber Validation**:
- Warn on duplicate subscriptions
- Track subscription source (for debugging)

**Files Created**:
- `scripts/ecs/events/health_changed_event.gd`
- `scripts/ecs/events/entity_death_event.gd`
- `scripts/ecs/events/victory_triggered_event.gd`
- `scripts/ecs/events/checkpoint_activated_event.gd`

**Files Modified**:
- `scripts/events/base_event_bus.gd` (add priority support)

---

### T140b: Document event taxonomy

**Create Documentation**:
```markdown
# docs/ecs/ecs_events.md

## Standard ECS Events

### Health & Combat
- `health_changed` (HealthChangedEvent) - Published by: C_HealthComponent
- `entity_death` (EntityDeathEvent) - Published by: C_HealthComponent
- Subscribers: S_GamepadVibrationSystem, M_SceneManager

### Victory & Checkpoints
- `victory_triggered` (VictoryTriggeredEvent) - Published by: C_VictoryTriggerComponent
- `checkpoint_activated` (CheckpointActivatedEvent) - Published by: S_CheckpointSystem
- Subscribers: M_SceneManager, S_VictorySystem

... (document all 19 events)
```

**Files Created**:
- `docs/ecs/ecs_events.md`

**Files Modified**:
- `docs/ecs/ecs_architecture.md` (link to events doc)

---

### T140c: Migrate remaining direct manager calls

**Audit**:
- Search for `_scene_manager.` calls (should be none after 10B-1)
- Search for `_store.dispatch()` calls that could be events
- M_SceneManager subscribes to all game flow events

**Implementation**:
- Verify 10B-1 complete (no system → manager calls)
- M_SceneManager becomes pure event subscriber

**Files Modified**: Verification only (no changes if 10B-1 complete)

---

## Phase 10B-7: Service Locator (T141a-T141c)

### T141a: Design ServiceLocator pattern

**Design**:
```gdscript
# scripts/core/service_locator.gd
class_name ServiceLocator

static var _services: Dictionary = {}
static var _dependencies: Dictionary = {}

static func register(service_name: StringName, instance: Node) -> void:
    _services[service_name] = instance

static func get_service(service_name: StringName) -> Node:
    if not _services.has(service_name):
        push_error("ServiceLocator: Service '%s' not registered" % service_name)
    return _services.get(service_name)

static func has(service_name: StringName) -> bool:
    return _services.has(service_name)

static func validate_all() -> bool:
    # Check all required dependencies exist
    for service_name in _dependencies:
        for dep in _dependencies[service_name]:
            if not _services.has(dep):
                push_error("ServiceLocator: Service '%s' requires '%s'" % [service_name, dep])
                return false
    return true
```

---

### T141b: Create service_locator.gd

**Implementation**:
- Central registry for managers
- Explicit registration at startup
- Dependency validation
- Make dependency graph visible

**Files Created**:
- `scripts/core/service_locator.gd`

---

### T141c: Migrate group lookups to ServiceLocator

**Pattern**:
```gdscript
# OLD:
var store := get_tree().get_nodes_in_group("state_store")[0] as M_StateStore

# NEW:
var store := ServiceLocator.get_service(StringName("state_store")) as M_StateStore
```

**Files Modified** (70+ occurrences across 34 files):
- Replace all group lookups with ServiceLocator calls
- Update U_StateUtils to use ServiceLocator

**Benefits**:
- Explicit dependencies
- Faster lookups (Dictionary vs tree traversal)
- Compile-time visibility of dependencies

---

## Phase 10B-8: Testing Infrastructure (T142a-T142c)

### T142a: Create manager interfaces

**Interfaces**:
```gdscript
# scripts/interfaces/i_state_store.gd
class_name I_StateStore
func dispatch(action: Dictionary) -> void: pass
func subscribe(callback: Callable) -> Callable: return func(): pass
func get_state() -> Dictionary: return {}
func get_slice(slice_name: StringName) -> Dictionary: return {}

# scripts/interfaces/i_scene_manager.gd
class_name I_SceneManager
func transition_to_scene(scene_id: StringName, transition_type: String = "", priority: int = 0) -> void: pass
func push_overlay(overlay_id: StringName) -> void: pass
func pop_overlay() -> void: pass

# scripts/interfaces/i_ecs_manager.gd
class_name I_ECSManager
func register_component(component: BaseECSComponent) -> void: pass
func get_components(type: StringName) -> Array: return []
func get_entity_by_id(entity_id: StringName) -> Node: return null
```

**Files Created**:
- `scripts/interfaces/i_state_store.gd`
- `scripts/interfaces/i_scene_manager.gd`
- `scripts/interfaces/i_ecs_manager.gd`

---

### T142b: Create mock implementations

**Mocks**:
```gdscript
# tests/mocks/mock_state_store.gd
class_name MockStateStore extends I_StateStore
var _state: Dictionary = {}
var _dispatched_actions: Array = []

func dispatch(action: Dictionary) -> void:
    _dispatched_actions.append(action)

func get_state() -> Dictionary:
    return _state.duplicate(true)

# tests/mocks/mock_scene_manager.gd
class_name MockSceneManager extends I_SceneManager
var transition_calls: Array = []

func transition_to_scene(scene_id: StringName, transition_type: String = "", priority: int = 0) -> void:
    transition_calls.append({scene_id: scene_id, type: transition_type})

# tests/mocks/mock_ecs_manager.gd
class_name MockECSManager extends I_ECSManager
var _components: Dictionary = {}

func register_component(component: BaseECSComponent) -> void:
    var type := component.component_type
    if not _components.has(type):
        _components[type] = []
    _components[type].append(component)
```

**Files Created**:
- `tests/mocks/mock_state_store.gd`
- `tests/mocks/mock_scene_manager.gd`
- `tests/mocks/mock_ecs_manager.gd`

---

### T142c: Update systems to depend on interfaces

**Pattern**:
```gdscript
# OLD:
class_name S_HealthSystem
var _scene_manager: M_SceneManager

# NEW:
class_name S_HealthSystem
@export var scene_manager: I_SceneManager  # Inject dependency

# Production (in scene):
health_system.scene_manager = $SceneManager

# Tests:
health_system.scene_manager = MockSceneManager.new()
```

**Files Modified**:
- Update all systems to accept injected dependencies
- Update production scenes to wire real implementations
- Update tests to inject mocks

**Result**: Systems 100% testable in isolation

---

## Phase 10B-9: Documentation & Contracts (T143a-T143c)

### T143a: Create ECS-State contract documentation

**Documentation**:
```markdown
# docs/architecture/ecs_state_contract.md

## ECS → State Dependencies

### Systems that Dispatch Actions
- S_HealthSystem → U_GameplayActions.trigger_death()
- S_CheckpointSystem → U_GameplayActions.set_last_checkpoint()
- S_VictorySystem → U_GameplayActions.mark_area_complete()
- S_InputSystem → U_GameplayActions.update_input()

### Systems that Read Selectors
- S_InputSystem → U_InputSelectors.get_active_device_type()
- S_JumpSystem → U_PhysicsSelectors.get_is_on_floor()
- S_LandingIndicatorSystem → U_PhysicsSelectors.get_velocity()

## State → ECS Dependencies
- M_PauseManager subscribes to navigation slice
- M_SpawnManager subscribes to gameplay slice
```

**Files Created**:
- `docs/architecture/ecs_state_contract.md`

---

### T143b: Create dependency graph visualization

**Documentation**:
```markdown
# docs/architecture/dependency_graph.md

## Manager Initialization Order
1. M_StateStore (main.tscn, first child)
2. M_CursorManager (depends on Input singleton)
3. M_SceneManager (depends on M_StateStore)
4. M_PauseManager (depends on M_StateStore, M_CursorManager)
5. M_SpawnManager (depends on M_StateStore)

## System → Manager Dependencies
- S_HealthSystem → M_SceneManager (via event)
- S_VictorySystem → M_SceneManager (via event)
- S_CheckpointSystem → M_StateStore (via dispatch)
- S_InputSystem → M_StateStore, M_InputDeviceManager
```

**ASCII Diagram**:
```
Root Scene (main.tscn)
├─ M_StateStore (singleton)
│  └─ Subscribers: M_PauseManager, M_SpawnManager, S_CheckpointSystem
├─ M_SceneManager
│  └─ Event Subscribers: entity_death, victory_triggered
└─ M_PauseManager
   └─ Depends on: M_StateStore, M_CursorManager
```

**Files Created**:
- `docs/architecture/dependency_graph.md`

---

### T143c: Add architectural decision records

**ADRs**:
```markdown
# docs/architecture/adr/ADR-001-redux-state-management.md
## Context
Need centralized state management for UI, gameplay, and persistence.

## Decision
Adopt Redux-style architecture with immutable state and reducer pattern.

## Consequences
+ Single source of truth
+ Time-travel debugging
+ Clear action flow
- Learning curve
- Boilerplate code

---

# docs/architecture/adr/ADR-002-ecs-node-based.md
## Context
Need flexible component system for gameplay entities.

## Decision
Use Node-based ECS with components as child nodes.

## Consequences
+ Godot editor integration
+ Scene composition
- Not cache-friendly (vs pure ECS)

---

# docs/architecture/adr/ADR-003-event-bus.md
## Context
Need decoupled communication between ECS and managers.

## Decision
Implement event bus for cross-system events.

## Consequences
+ Loose coupling
+ Easy to test
- Harder to trace flow

---

# docs/architecture/adr/ADR-004-service-locator.md
## Context
70+ group lookups scattered, dependencies invisible.

## Decision
Centralize manager lookup in ServiceLocator.

## Consequences
+ Explicit dependencies
+ Faster lookups
- Global state
```

**Files Created**:
- `docs/architecture/adr/ADR-001-redux-state-management.md`
- `docs/architecture/adr/ADR-002-ecs-node-based.md`
- `docs/architecture/adr/ADR-003-event-bus.md`
- `docs/architecture/adr/ADR-004-service-locator.md`

---

## Testing Strategy

### TDD Workflow
1. Write failing test for new abstraction
2. Implement minimum code to pass
3. Refactor for clarity
4. Repeat

### Test Coverage Targets
- Manager decoupling: 100% (all systems testable without managers)
- Transition orchestrator: 90% (edge cases, async handling)
- Scene type handlers: 100% (simple delegation)
- Input sources: 90% (device-specific logic)
- Service locator: 100% (lookup and validation)

### Integration Tests
- Full scene transitions with new orchestrator
- Device switching with new input sources
- Event flow: component → event bus → manager

---

## Migration Strategy

### Breaking Changes
1. **DeviceType enum centralization**:
   - Create U_DeviceTypeConstants first
   - Update both files simultaneously
   - Run tests to verify compatibility

2. **Manager interface injection**:
   - Create interfaces
   - Update systems to accept both interface and concrete (backward compatible)
   - Gradually migrate production scenes
   - Remove concrete type support after migration

3. **ServiceLocator group replacement**:
   - Add ServiceLocator registration first
   - Keep group lookups as fallback
   - Migrate file by file
   - Remove fallback after full migration

### Backward Compatibility
- Keep old APIs during migration
- Mark as deprecated with comments
- Remove in separate cleanup commit

---

## Rollback Plan

### If Issues Arise
1. **Per-phase rollback**: Each sub-phase is a separate commit batch
2. **Test failures**: Revert last commit, fix tests, re-commit
3. **Production issues**: Revert to last known-good commit before phase

### Safety Measures
- Run full test suite after each sub-phase
- Manual smoke test after 10B-2, 10B-4 (high-impact refactors)
- Keep `clean-up` branch separate from `main` until validation complete

---

## Critical Files Reference

### Phase 10B-1
- `scripts/ecs/systems/s_health_system.gd`
- `scripts/ecs/systems/s_victory_system.gd`
- `scripts/managers/m_scene_manager.gd`

### Phase 10B-2
- `scripts/managers/m_scene_manager.gd` (1120 lines → 720 lines)
- `scripts/scene_management/transition_orchestrator.gd` (new, 300-400 lines)

### Phase 10B-3
- `scripts/scene_management/handlers/*.gd` (4 new files)
- `scripts/scene_management/u_scene_type_handler_registry.gd` (new)

### Phase 10B-4
- `scripts/input/u_device_type_constants.gd` (new)
- `scripts/input/sources/*.gd` (3 new files)
- `scripts/ecs/systems/s_input_system.gd` (412 → 200 lines)

### Phase 10B-5
- `scripts/state/m_state_store.gd` (529 → 400 lines)
- `scripts/state/utils/u_state_repository.gd` (new, 200-250 lines)

### Phase 10B-6
- `scripts/ecs/events/*.gd` (4 new event classes)
- `docs/ecs/ecs_events.md` (new)

### Phase 10B-7
- `scripts/core/service_locator.gd` (new)
- 34 files with group lookups (migrate to ServiceLocator)

### Phase 10B-8
- `scripts/interfaces/*.gd` (3 new interfaces)
- `tests/mocks/*.gd` (3 new mocks)

### Phase 10B-9
- `docs/architecture/ecs_state_contract.md` (new)
- `docs/architecture/dependency_graph.md` (new)
- `docs/architecture/adr/*.md` (4 new ADRs)

---

## Plan Documentation Location

**Before starting execution**, copy this plan to permanent documentation:

```bash
cp /Users/mcthaydt/.claude/plans/jaunty-skipping-flame.md \
   docs/general/cleanup/phase-10b-implementation-plan.md
```

**Update references**:
1. Add link in `docs/general/cleanup/style-scene-cleanup-continuation-prompt.md`:
   - Under "Related Documents" section
   - Add: `- docs/general/cleanup/phase-10b-implementation-plan.md`

2. Add note in `docs/general/cleanup/style-scene-cleanup-tasks.md` before Phase 10B:
   ```markdown
   **Detailed implementation plan**: See `docs/general/cleanup/phase-10b-implementation-plan.md`
   ```

**During execution**:
- Use this plan as the detailed implementation guide
- Mark tasks in `style-scene-cleanup-tasks.md` as `[x]` when completed
- Update continuation prompt after each sub-phase

---

## Execution Checklist

- [ ] **Copy plan to permanent location** (`docs/general/cleanup/phase-10b-implementation-plan.md`)
- [ ] **Update documentation references** (continuation prompt, tasks file)
- [ ] **10B-1**: Decouple systems from managers (T130-T133)
- [ ] **10B-2**: Extract transition orchestrator (T134-T136b)
- [ ] **10B-3**: Create scene type handlers (T137a-T137c)
- [ ] **10B-4**: Abstract input devices (T138a-T138d)
- [ ] **10B-5**: Extract state persistence (T139a-T139c)
- [ ] **10B-6**: Enhance event bus (T140a-T140c)
- [ ] **10B-7**: Implement service locator (T141a-T141c)
- [ ] **10B-8**: Create testing infrastructure (T142a-T142c)
- [x] **10B-9**: Document architecture (T143a-T143c)

---

## Success Criteria

✅ All systems testable without concrete managers
✅ M_SceneManager reduced to ~700 lines
✅ S_InputSystem reduced to ~200 lines
✅ M_StateStore reduced to ~400 lines
✅ DeviceType enum centralized
✅ 19 events documented with typed classes
✅ Service locator replaces all group lookups
✅ Full test coverage maintained (500+ tests passing)
✅ Architecture documented with ADRs and diagrams
