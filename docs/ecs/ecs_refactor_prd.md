# ECS Architecture Refactor PRD

**Owner**: Development Team | **Updated**: 2025-10-21

## Summary

- **Vision**: A scalable, decoupled ECS architecture that enables emergent systemic gameplay through multi-component queries, event-driven communication, and composable system design
- **Problem**: Current ECS implementation blocks emergent gameplay with single-component queries, tight NodePath coupling between components, no event system for cross-system communication, and manual system execution ordering
- **Success**: 100% of systems use multi-component queries, zero NodePath cross-references between components, <1ms query performance at 60fps, emergent gameplay interactions working (e.g., jump → dust particles → environmental reaction)
- **Timeline**: 2-3 weeks for complete refactor across 4 batches
- **Progress** (current): Stories 1.1–2.6 complete — `U_ECSUtils` centralizes manager/time/body helpers, `_validate_required_settings()` enforces component setup, `M_ECSManager.get_components()` prunes nulls, all systems consume the shared utilities, `EntityQuery` now wraps entity/component results, `M_ECSManager` tracks entity-to-component maps via `get_components_for_entity()`, `query_entities()` returns `EntityQuery` results for required/optional component sets, `S_MovementSystem`/`S_JumpSystem` consume those queries, query caching keeps repeated lookups under budget (`tests/unit/ecs/test_ecs_manager.gd` via GUT `-gselect=test_ecs_manager -gexit`), Story 3.1 delivered the static `ECSEventBus` publish/subscribe API with timestamped payloads, and Story 3.2 added the rolling event history buffer with debugging helpers (`get_event_history()`, `set_history_limit()`, `clear_history()`) validated via `tests/unit/ecs/test_ecs_event_bus.gd` (GUT `-gdir=res://tests/unit/ecs -gselect=test_ecs_event_bus -gexit`)

## Requirements

### Users

- **Primary**: Game developers building the character controller with systemic, emergent gameplay
- **Pain Points**:
  - Cannot query entities with multiple components (e.g., "all entities with Movement AND Input AND Floating")
  - Components tightly coupled via NodePath exports (movement_comp knows about input_comp)
  - No event system - systems can't communicate without tight coupling
  - Manual system execution order - no explicit priority system
  - Code duplication across systems (manager location, time utils, body mapping)
  - Debugging state requires manual logging across multiple components
  - Scene setup requires manually wiring NodePaths in inspector for every entity

### Stories

#### Epic 1: Code Quality Refactors

**Story**: As a developer, I want to eliminate code duplication so that the ECS codebase is maintainable and DRY

**Acceptance Criteria**:
- Given duplicate manager location code in 5+ systems, when I use `U_ECSUtils.get_manager()`, then manager discovery is centralized
- Given duplicate time utilities in 6+ systems, when I use `U_ECSUtils.get_current_time()`, then time access is consistent
- Given settings validation duplicated across components, when I use `ECSComponent._validate_required_settings()`, then validation is standardized
- Given body mapping code duplicated in 2+ systems, when I use `U_ECSUtils.map_components_by_body()`, then mapping is reusable
- Given inconsistent null safety checks, when M_ECSManager filters components, then systems never receive null components

**Priority**: P0 (Must Have - Quick Wins)

---

#### Epic 2: Multi-Component Query System

**Story**: As a system, I want to query entities with multiple components so that I can implement complex systemic interactions

**Acceptance Criteria**:
- Given M_ECSManager with registered components, when I call `query_entities([C_Movement, C_Input])`, then I receive all entities having BOTH components
- Given a query result, when I access `entity_query.get_component(C_Movement)`, then I get the movement component without manual cross-reference
- Given a query with optional components, when I query `([C_Movement], [C_Floating])`, then I get entities with Movement, optionally with Floating
- Given query execution at 60fps, when systems query every frame, then query time is <1ms
- Given 100+ entities with 7+ components each, when querying, then performance remains <1ms

**Priority**: P0 (Must Have - CRITICAL for Emergent Gameplay)

**Example Use Case**:
```gdscript
# Current (manual cross-reference):
func process_tick(delta):
    for movement_comp in get_components(C_MovementComponent.COMPONENT_TYPE):
        var input_comp = movement_comp.get_input_component()  # NodePath coupling!
        if input_comp == null: continue
        # Process...

# After (query-based):
func process_tick(delta):
    for entity in query_entities([C_MovementComponent.COMPONENT_TYPE, C_InputComponent.COMPONENT_TYPE]):
        var movement_comp = entity.get_component(C_MovementComponent.COMPONENT_TYPE)
        var input_comp = entity.get_component(C_InputComponent.COMPONENT_TYPE)
        # Both guaranteed to exist, no null checks needed!
```

---

#### Epic 3: Event Bus System

**Story**: As a system, I want to publish and subscribe to gameplay events so that systems can react to each other without tight coupling

**Acceptance Criteria**:
- Given ECSEventBus singleton, when S_JumpSystem publishes "entity_jumped" event, then subscribed systems (S_ParticleSystem, S_AnimationSystem, S_SoundSystem) receive the event
- Given event publication, when multiple systems subscribe to same event, then all receive notification in priority order
- Given event with payload, when published, then subscribers receive full context (entity, component data, timestamp)
- Given event dispatch at 60fps, when 100+ events per frame, then dispatch time is <0.5ms per event
- Given event history, when debugging, then I can inspect last 1000 events with full payload

**Priority**: P0 (Must Have - Enables Systemic Interactions)

**Example Use Case**:
```gdscript
# In S_JumpSystem
func process_tick(delta):
    # ...jump logic...
    if did_jump:
        ECSEventBus.publish("entity_jumped", {
            "entity": body,
            "velocity": jump_velocity,
            "position": body.global_position
        })

# In S_ParticleSystem
func _ready():
    ECSEventBus.subscribe("entity_jumped", _on_entity_jumped)

func _on_entity_jumped(event_data: Dictionary):
    spawn_dust_particles(event_data.position)

# In S_SoundSystem
func _ready():
    ECSEventBus.subscribe("entity_jumped", _on_entity_jumped)

func _on_entity_jumped(event_data: Dictionary):
    play_jump_sound(event_data.entity)
```

---

#### Epic 4: Component Decoupling

**Story**: As a developer, I want components to be independent data containers so that I can compose entities flexibly without hardcoded dependencies

**Acceptance Criteria**:
- Given C_MovementComponent, when I inspect its exports, then there are NO NodePath exports to other components (NOTE: Only component→component NodePaths removed; NodePaths to bodies/raycasts within **same entity subtree** remain; **cross-tree references use runtime discovery** via groups/viewport APIs)
- Given entity with Movement + Input + Floating components, when systems query, then they find components via query system not NodePaths
- Given existing scenes (player_template.tscn), when migrated, then all component→component NodePath exports are removed
- Given component deletion in editor, when removed from entity, then no broken NodePath references remain
- Given new entity creation, when adding components, then no manual NodePath wiring required

**Priority**: P1 (Should Have - Improves Maintainability)

**Before/After**:
```gdscript
# BEFORE (C_MovementComponent - tightly coupled):
@export_node_path("C_InputComponent") var input_component_path: NodePath
@export_node_path("C_FloatingComponent") var support_component_path: NodePath

func get_input_component() -> C_InputComponent:
    return get_node_or_null(input_component_path)

# AFTER (C_MovementComponent - decoupled):
# No NodePath exports!
# Systems use queries to find related components
```

---

#### Epic 5: System Execution Ordering

**Story**: As a developer, I want explicit system execution order so that physics calculations happen in correct sequence

**Acceptance Criteria**:
- Given systems with priority values, when M_ECSManager processes frame, then systems execute in priority order (lower number = earlier)
- Given S_InputSystem with priority 0, when frame starts, then it executes before S_MovementSystem (priority 50)
- Given priority conflict, when two systems have same priority, then registration order determines execution
- Given system ordering documentation, when adding new system, then I know where it fits in execution pipeline
- Given debug mode, when enabled, then system execution order is logged each frame

**Priority**: P1 (Should Have - Explicit > Implicit)

**Example**:
```gdscript
# scripts/ecs/ecs_system.gd
@export var execution_priority: int = 100  # Lower = earlier

# M_ECSManager sorts systems by priority before _physics_process
func _physics_process(delta):
    for system in _sorted_systems:  # Sorted by execution_priority
        system.process_tick(delta)
```

---

#### Epic 6: Component Tags & Entity Tracking

**Story**: As a developer, I want to categorize entities and track them efficiently so that I can query by gameplay semantics not just component types

**Acceptance Criteria**:
- Given entity with tags ["player", "controllable"], when I query `query_entities_by_tag("player")`, then I get player entity
- Given entity ID system, when I query, then results include stable entity IDs not just E_* root node references
- Given entity spawned/destroyed, when tracked, then query results automatically update
- Given entity component added/removed, when tracked, then query cache invalidates correctly

**Priority**: P2 (Nice to Have - Future Enhancement)

---

### Features

#### P0 (Must Have - MVP for Emergent Gameplay)

- Multi-component query system (`M_ECSManager.query_entities()`)
- EntityQuery class with component filters (required, optional)
- QueryResult with component accessors (`get_component()`, `has_component()`)
- Event bus singleton (ECSEventBus) with pub/sub API
- Event history buffer (last 1000 events for debugging)
- Code quality refactors (extract duplicates, validation, helpers)
- Migration of 2-3 systems to query-based approach (proof-of-concept)
- Scene migration for player_template.tscn (remove NodePath exports)
- Unit tests for query system and event bus (GUT framework)

#### P1 (Should Have - Full Feature Set)

- Component decoupling (remove all NodePath cross-references)
- System execution priority API (`@export var execution_priority: int`)
- M_ECSManager system sorting by priority
- Query performance optimization (caching, filtering)
- Event bus middleware (validation, logging, metrics)
- Migration guide for remaining systems
- Scene template updates (base_scene_template.tscn)
- Integration tests with full game loop
- Debug tools (query inspector, event log viewer)

#### P2 (Nice to Have - Future Enhancements)

- Entity ID abstraction (stable IDs beyond Node references)
- Component tag system (semantic categorization)
- Query by tags (`query_entities_by_tag()`)
- Entity lifecycle events (spawned, destroyed, registered, unregistered)
- Query result caching with automatic invalidation
- Hot-reload support (preserve queries during code changes)
- Multi-query composition (AND, OR, NOT filters)
- Excluded component filters for queries (query entities WITHOUT specific components)
- Component archetype optimization (data-oriented storage)
- Network sync integration (future multiplayer)

## Technical

### Architecture

#### Before (Current State)

```
M_ECSManager
├─ _components: Dictionary[StringName, Array[Component]]
│  ├─ "C_MovementComponent" → [comp1, comp2, ...]
│  ├─ "C_InputComponent" → [comp1, comp2, ...]
│  └─ ...
├─ register_component(component)
├─ unregister_component(component)
└─ get_components(type: StringName) → Array[Component]

Systems Query Pattern:
- S_MovementSystem queries "C_MovementComponent" only
- Manually finds related components via NodePath:
  - movement_comp.get_input_component() → NodePath to C_InputComponent
  - movement_comp.get_support_component() → NodePath to C_FloatingComponent
- Problem: Tight coupling, no multi-component semantics

Component Structure:
- C_MovementComponent has @export NodePath to C_InputComponent, C_FloatingComponent
- Manual wiring required in Godot inspector for every entity
- Brittle: Deleting component breaks NodePath references
```

#### After (Refactored State)

```
M_ECSManager
├─ _components: Dictionary[StringName, Array[ECSComponent]]  # Unchanged
├─ _entity_component_map: Dictionary[Node, Dictionary[StringName, ECSComponent]]
│  └─ E_* root node → {"C_MovementComponent": comp, "C_InputComponent": comp, ...}
├─ register_component(component)
├─ unregister_component(component)
├─ get_components(type: StringName) → Array[Component]  # Legacy API
└─ query_entities(required: Array[StringName], optional: Array[StringName] = []) → Array[EntityQuery]

EntityQuery (new class):
├─ entity: Node  # The E_* root node (scene organization node)
├─ components: Dictionary[StringName, ECSComponent]
├─ get_component(type: StringName) → Component
├─ has_component(type: StringName) → bool
└─ get_all_components() → Dictionary[StringName, Component]

ECSEventBus (purely static class - no Node, no scene tree):
├─ static _subscribers: Dictionary[StringName, Array[Callable]]
├─ static _event_history: Array[Dictionary]  # Last 1000 events
├─ static publish(event_name: StringName, payload: Variant)
├─ static subscribe(event_name: StringName, callback: Callable) → Callable
├─ static unsubscribe(event_name: StringName, callback: Callable)
├─ static get_event_history() → Array[Dictionary]
├─ static clear_history() -> void
└─ static set_history_limit(limit: int) -> void

Systems Query Pattern (new):
- S_MovementSystem queries ["C_MovementComponent", "C_InputComponent"]
- Returns EntityQuery objects with both components guaranteed present
- No manual NodePath lookups, no null checks for required components
- Optional components checked via entity.has_component()

Component Structure (decoupled):
- C_MovementComponent has NO @export NodePath to other components
- Systems use queries to find related components
- Inspector cleaner, no manual NodePath wiring
- Resilient: Component deletion doesn't break references (queries automatically filter)
```

#### Integration Flow

```
[1] Component Registration (Unchanged)
    Component._ready() → M_ECSManager.register_component()
         ↓
    Manager adds to _components[type] AND _entity_component_map[entity][type]
         ↓
    Manager emits registered(component) signal

[2] System Queries (NEW)
    System.process_tick(delta)
         ↓
    entities = query_entities([C_Movement, C_Input], [C_Floating])
         ↓
    Manager builds EntityQuery objects:
        - Find all entities with Movement component
        - Filter to only entities also having Input component
        - Optionally check for Floating component
        - Return EntityQuery wrappers

[3] Event Publication (NEW)
    System detects gameplay event (e.g., jump)
         ↓
    ECSEventBus.publish("entity_jumped", {entity: body, velocity: v})
         ↓
    EventBus notifies all subscribers to "entity_jumped"
         ↓
    Subscribers (ParticleSystem, SoundSystem, AnimationSystem) react

[4] Execution Order (NEW)
    M_ECSManager._physics_process(delta)
         ↓
    Sort systems by execution_priority (once per frame or on system add)
         ↓
    for system in _sorted_systems:
        system.process_tick(delta)
```

---

### Key Classes

#### 1. EntityQuery

```gdscript
# scripts/ecs/entity_query.gd
class_name EntityQuery

var entity: Node  # The E_* root node (scene organization node)
var components: Dictionary[StringName, ECSComponent]  # StringName → ECSComponent

func get_component(type: StringName) -> Component:
    """Get required component (guaranteed to exist for required queries)"""
    return components.get(type)

func has_component(type: StringName) -> bool:
    """Check if optional component exists"""
    return components.has(type)

func get_all_components() -> Dictionary:
    """Return all components on this entity"""
    return components
```

#### 2. ECSEventBus

```gdscript
# scripts/ecs/ecs_event_bus.gd
# Purely static class (NOT a Node, NOT in scene tree)
class_name ECSEventBus

static var _subscribers: Dictionary = {}  # StringName → Array[Callable]
static var _event_history: Array[Dictionary] = []
static var _max_history_size: int = 1000

static func publish(event_name: StringName, payload: Variant = null) -> void:
    """Publish event to all subscribers"""
    var event: Dictionary = {
        "name": event_name,
        "payload": _duplicate_payload(payload),
        "timestamp": U_ECSUtils.get_current_time()
    }
    _append_to_history(event)

    if _subscribers.has(event_name):
        for callback in _subscribers[event_name]:
            callback.call(event)

static func subscribe(event_name: StringName, callback: Callable) -> Callable:
    """Subscribe to event, returns unsubscribe function"""
    if not _subscribers.has(event_name):
        _subscribers[event_name] = []
    _subscribers[event_name].append(callback)

    return func(): unsubscribe(event_name, callback)

static func unsubscribe(event_name: StringName, callback: Callable) -> void:
    """Unsubscribe from event"""
    if _subscribers.has(event_name):
        _subscribers[event_name].erase(callback)

static func get_event_history() -> Array[Dictionary]:
    """Get recent event history for debugging"""
    return _event_history.duplicate(true)

static func clear_history() -> void:
    _event_history.clear()

static func set_history_limit(limit: int) -> void:
    _max_history_size = max(limit, 1)
    _trim_history()

static func _append_to_history(event: Dictionary) -> void:
    _event_history.append(event.duplicate(true))
    _trim_history()

static func _trim_history() -> void:
    while _event_history.size() > _max_history_size:
        _event_history.pop_front()

static func _duplicate_payload(payload: Variant) -> Variant:
    if payload is Dictionary:
        return payload.duplicate(true)
    if payload is Array:
        return payload.duplicate(true)
    return payload
```

#### 3. M_ECSManager (Enhanced)

```gdscript
# scripts/managers/m_ecs_manager.gd - NEW METHODS
func query_entities(
    required: Array[StringName],
    optional: Array[StringName] = []
) -> Array[EntityQuery]:
    """Query entities with multiple component requirements"""
    var results: Array[EntityQuery] = []

    # Start with smallest component set for performance
    var smallest_set = _get_smallest_component_set(required)

    for component in smallest_set:
        var entity = _get_entity_for_component(component)
        if entity == null: continue

        # Check if entity has all required components
        if not _entity_has_all_components(entity, required):
            continue

        # Build component dictionary for this entity
        var entity_components = {}
        for type in required:
            entity_components[type] = _entity_component_map[entity][type]
        for type in optional:
            if _entity_component_map[entity].has(type):
                entity_components[type] = _entity_component_map[entity][type]

        # Create EntityQuery result
        var query = EntityQuery.new()
        query.entity = entity
        query.components = entity_components
        results.append(query)

    return results
```

#### 4. U_ECSUtils (New Utility Class)

```gdscript
# scripts/utils/u_ecs_utils.gd
class_name U_ECSUtils

static func get_manager(from_node: Node) -> M_ECSManager:
    """Find ECS manager in scene tree (parent hierarchy or group)"""
    # Walk parent hierarchy
    var current = from_node.get_parent()
    while current != null:
        if current.has_method("register_component") and current.has_method("query_entities"):
            return current
        current = current.get_parent()

    # Fallback to scene tree group
    var managers = from_node.get_tree().get_nodes_in_group("ecs_manager")
    if managers.size() > 0:
        return managers[0]

    push_error("U_ECSUtils: Could not locate M_ECSManager")
    return null

static func get_current_time() -> float:
    """Get current game time in seconds"""
    return float(Time.get_ticks_msec()) / 1000.0

static func map_components_by_body(
    manager: M_ECSManager,
    component_type: StringName
) -> Dictionary:
    """Build map of CharacterBody3D → Component for fast lookup"""
    var result = {}
    for component in manager.get_components(component_type):
        if component == null: continue
        var body = component.get_character_body()
        if body != null:
            result[body] = component
    return result
```

---

### File Structure

```
scripts/ecs/
├── ecs_component.gd           # Base component class (existing)
├── ecs_system.gd              # Base system class (existing, enhanced)
├── entity_query.gd            # NEW: Query result wrapper
├── ecs_event_bus.gd           # NEW: Event system singleton
├── u_ecs_utils.gd             # NEW: Shared utilities
├── components/                # Component implementations (existing)
│   ├── c_movement_component.gd        # MODIFIED: Remove NodePath exports
│   ├── c_input_component.gd           # MODIFIED: Uses U_ECSUtils.get_current_time()
│   ├── c_jump_component.gd            # MODIFIED: Remove NodePath exports
│   ├── c_floating_component.gd        # Unchanged
│   ├── c_align_with_surface_component.gd  # Unchanged
│   ├── c_rotate_to_input_component.gd # MODIFIED: Remove NodePath exports
│   └── c_landing_indicator_component.gd # MODIFIED: Remove NodePath exports
├── systems/                   # System implementations (existing)
│   ├── s_input_system.gd              # MODIFIED: Use queries
│   ├── s_movement_system.gd           # MODIFIED: Use queries + events
│   ├── s_jump_system.gd               # MODIFIED: Use queries + publish events
│   ├── s_gravity_system.gd            # MODIFIED: Use queries
│   ├── s_floating_system.gd           # MODIFIED: Use queries
│   ├── s_rotate_to_input_system.gd    # MODIFIED: Use queries
│   ├── s_align_with_surface_system.gd # MODIFIED: Use queries
│   └── s_landing_indicator_system.gd  # MODIFIED: Use queries
└── managers/
    └── m_ecs_manager.gd       # MODIFIED: Add query_entities(), entity tracking
```

---

### Performance Requirements

- **Query Latency**: <1ms for query_entities() with 100+ entities and 7+ component types at 60fps
- **Event Dispatch**: <0.5ms per event publication to 10+ subscribers
- **Entity Tracking**: <2ms to build/update entity-component map per frame
- **System Sorting**: <0.1ms to sort systems by priority (cached after add/remove)
- **Memory Overhead**: <500KB additional memory for query caching and event history (1000 events)

### Security & Data Integrity

- **Query Safety**: query_entities() never returns null components for required parameters
- **Event Validation**: Event names follow naming convention (lowercase_with_underscores)
- **History Limits**: Event history capped at 1000 events (rolling buffer) to prevent memory bloat
- **Priority Bounds**: System execution_priority clamped to [0, 1000] range to prevent integer overflow
- **Component Lifecycle**: Query results automatically invalid if component unregistered mid-frame

---

## Godot Editor & Scene Integration

### Scene Migration Overview

**Problem**: Existing scenes (player_template.tscn, base_scene_template.tscn) hardcode NodePath exports in components, requiring manual inspector wiring for every entity.

**Solution**: Remove NodePath exports, use query system for component discovery. Scenes become self-configuring.

### Migration Checklist

#### 1. Component Script Updates

**Before** (`c_movement_component.gd`):
```gdscript
@export_node_path("C_InputComponent") var input_component_path: NodePath
@export_node_path("C_FloatingComponent") var support_component_path: NodePath

func get_input_component() -> C_InputComponent:
    return get_node_or_null(input_component_path)

func get_support_component() -> C_FloatingComponent:
    return get_node_or_null(support_component_path)
```

**After** (`c_movement_component.gd`):
```gdscript
# NO NodePath exports!
# Systems use queries to find related components
```

**Action Items**:
- [ ] Remove `@export_node_path()` declarations from all components
- [ ] Remove `get_*_component()` helper methods
- [ ] Update component tests to use query-based discovery

---

#### 2. System Script Updates

**Before** (`s_movement_system.gd`):
```gdscript
func process_tick(delta: float) -> void:
    var movement_components = get_components(C_MovementComponent.COMPONENT_TYPE)

    for movement_comp in movement_components:
        if movement_comp == null: continue

        # Manual cross-reference via NodePath
        var input_comp = movement_comp.get_input_component()
        var support_comp = movement_comp.get_support_component()

        if input_comp == null: continue
        # Process...
```

**After** (`s_movement_system.gd`):
```gdscript
func process_tick(delta: float) -> void:
    # Query entities with Movement AND Input components
    var entities = query_entities(
        [C_MovementComponent.COMPONENT_TYPE, C_InputComponent.COMPONENT_TYPE],
        [C_FloatingComponent.COMPONENT_TYPE]  # Optional
    )

    for entity in entities:
        # Both components guaranteed to exist for required types
        var movement_comp = entity.get_component(C_MovementComponent.COMPONENT_TYPE)
        var input_comp = entity.get_component(C_InputComponent.COMPONENT_TYPE)
        var support_comp = entity.get_component(C_FloatingComponent.COMPONENT_TYPE)  # May be null

        # Process... (no null checks needed for required components!)
```

**Action Items**:
- [ ] Migrate S_MovementSystem to query-based (proof-of-concept)
- [ ] Migrate S_JumpSystem, S_GravitySystem, S_FloatingSystem, S_RotateToInputSystem
- [ ] Add event publication to S_JumpSystem (emit "entity_jumped")
- [ ] Update system tests to use queries

---

#### 3. Scene File Updates (player_template.tscn)

**Before** (inspector shows NodePath exports):
```
[node name="C_MovementComponent" parent="Components"]
input_component_path = NodePath("../C_InputComponent")          # Manual wiring!
support_component_path = NodePath("../C_FloatingComponent")     # Manual wiring!
```

**After** (inspector clean, no NodePath exports):
```
[node name="C_MovementComponent" parent="Components"]
# No NodePath exports, self-configuring via queries
```

**Migration Steps**:
1. Open `templates/player_template.tscn` in Godot editor
2. Select each component node (C_MovementComponent, C_JumpComponent, etc.)
3. Inspector will show NodePath exports - these can be ignored (no longer used)
4. Save scene (exports disappear once component scripts updated)
5. Test: Run scene, verify systems still find components via queries

**Action Items**:
- [ ] Update player_template.tscn (remove NodePath wiring)
- [ ] Update base_scene_template.tscn
- [ ] Create migration guide document with screenshots
- [ ] Record video tutorial showing before/after editor workflow

---

#### 4. Inspector Workflow Changes

**Before**:
1. Add component to entity
2. Open inspector
3. Manually wire NodePath exports to other components
4. Repeat for every entity instance
5. Risk: Deleting component breaks NodePaths in other components

**After**:
1. Add component to entity
2. Done! (No wiring needed)
3. Systems automatically find components via queries
4. Resilient: Deleting component doesn't break other components

**Inspector UI**:
- **Before**: Inspector cluttered with NodePath exports
- **After**: Inspector shows only data properties (@export var max_speed, jump_force, etc.)

---

#### 5. Debug Tools Integration

**Query Inspector** (new tool):
- Shows active queries each frame
- Displays which entities match which queries
- Performance metrics per query

**Event Log Viewer** (new tool):
- Shows last 1000 events with timestamps
- Filter by event name
- Inspect event payloads
- Export event history to JSON for bug reproduction

**Implementation**:
- [ ] Create `addons/ecs_debugger/` editor plugin
- [ ] Add bottom panel with tabs: "Queries", "Events", "System Order"
- [ ] Hook into M_ECSManager and ECSEventBus for real-time data
- [ ] Add "Copy Event History" button for bug reports

---

## Success

### Primary KPIs

- **Adoption**: 100% of systems use query_entities() for multi-component logic
- **Decoupling**: Zero NodePath cross-references between components in production code
- **Performance**: Query execution <1ms average at 60fps with 100+ entities
- **Emergent Gameplay**: At least 3 systemic interactions working (e.g., jump → particles + sound + camera shake)

### Secondary Metrics

- **Test Coverage**: >90% code coverage for ECS module (systems, components, manager, queries, events)
- **Developer Velocity**: 50% reduction in time to add new systemic interactions (no manual wiring)
- **Scene Setup Time**: 70% reduction in scene wiring time (no NodePath exports)
- **Bug Reduction**: 80% reduction in "broken NodePath" bugs (no cross-references)

### Analytics Tracking

- **Query Metrics**: Query frequency, query time, entity count per query
- **Event Metrics**: Event publish frequency, subscriber count, event payload size
- **System Metrics**: Execution order, execution time per system, frame budget usage
- **Cache Metrics**: Query cache hit rate, invalidation frequency

---

## Implementation

### Phase 1: Code Quality Refactors (Week 1, Days 1-2)

**Goal**: Eliminate code duplication, improve maintainability

**Deliverables**:
- U_ECSUtils class with manager discovery, time utilities, body mapping
- ECSComponent base class with settings validation
- M_ECSManager with null filtering
- All systems refactored to use utilities
- Unit tests for new utilities

---

### Phase 2: Multi-Component Query System (Week 1-2, Days 3-7)

**Goal**: Implement query system, migrate 2-3 systems as proof-of-concept

**Deliverables**:
- EntityQuery class
- M_ECSManager.query_entities() implementation
- Entity-component map tracking
- Query performance optimization
- S_MovementSystem migrated to queries
- S_JumpSystem migrated to queries
- Unit tests for query system
- Integration tests with multiple systems

---

### Phase 3: Event Bus + Component Decoupling (Week 2, Days 1-4)

**Goal**: Enable system communication, remove NodePath coupling

**Deliverables**:
- ECSEventBus singleton
- Event subscription/publication API
- Event history buffer
- S_JumpSystem publishes "entity_jumped" event
- S_ParticleSystem, S_SoundSystem subscribe to events
- Remove all NodePath exports from components
- Migrate remaining systems to query-based approach
- Scene template updates (player_template.tscn)
- Migration guide document

---

### Phase 4: System Ordering + Polish (Week 2-3, Days 5-7)

**Goal**: Explicit execution order, debug tools, documentation

**Deliverables**:
- System execution priority API
- M_ECSManager system sorting
- Debug tools (query inspector, event log viewer)
- Scene migration validation
- Performance profiling
- Full documentation
- Tutorial video

---

### Team Requirements

- **Size**: 1-2 developers
- **Skills**:
  - Strong GDScript experience
  - ECS architecture patterns
  - Godot 4.x scene tree and editor integration
  - Unit testing with GUT
  - Performance profiling
- **Commitment**: 2-3 weeks full-time

---

## Risks & Mitigation

### Risk 1: Query Performance Overhead

- **Impact**: Query system adds latency to 60fps game loop
- **Mitigation**:
  - Profile early and often
  - Cache query results where possible
  - Use smallest component set as query starting point
  - Optimize entity-component map lookups (Dictionary access is O(1))
  - Benchmark with 100+ entities continuously

---

### Risk 2: Migration Breaks Existing Functionality

- **Impact**: Removing NodePath exports breaks current gameplay
- **Mitigation**:
  - Incremental migration (system by system)
  - Hybrid support: Keep get_components() for legacy systems
  - Comprehensive regression tests
  - Feature flag for rollback
  - Test in isolated branch before merging

---

### Risk 3: Event Bus Introduces New Coupling

- **Impact**: Systems become tightly coupled to event names/payloads
- **Mitigation**:
  - Document event contracts (name, payload structure)
  - Use StringName constants for event names (no magic strings)
  - Event validation in debug mode
  - Centralized event registry
  - Versioned event payloads (handle schema changes)

---

### Risk 4: Scene Migration Complexity

- **Impact**: Manual scene updates error-prone, time-consuming
- **Mitigation**:
  - Create migration script (automate NodePath removal)
  - Comprehensive migration checklist
  - Video tutorial showing step-by-step process
  - Test scene migration with copies before modifying originals
  - Git commit after each successful scene migration

---

## Example Usage

### Before: Tight Coupling via NodePaths

```gdscript
# scripts/ecs/components/c_movement_component.gd
@export_node_path("C_InputComponent") var input_component_path: NodePath
@export_node_path("C_FloatingComponent") var support_component_path: NodePath

func get_input_component() -> C_InputComponent:
    return get_node_or_null(input_component_path)

# scripts/ecs/systems/s_movement_system.gd
func process_tick(delta: float) -> void:
    var movement_components = get_components(C_MovementComponent.COMPONENT_TYPE)

    for movement_comp in movement_components:
        if movement_comp == null: continue

        var input_comp = movement_comp.get_input_component()  # NodePath lookup
        if input_comp == null: continue  # Null check required

        var body = movement_comp.get_character_body()
        if body == null: continue

        # Finally, process movement...
```

**Problems**:
- Manual NodePath wiring in inspector for every entity
- Brittle: Deleting C_InputComponent breaks NodePath reference
- Null checks everywhere
- No semantic query (can't say "all entities with Movement AND Input AND Floating")

---

### After: Decoupled via Queries

```gdscript
# scripts/ecs/components/c_movement_component.gd
# NO NodePath exports! Clean, simple data container.

# scripts/ecs/systems/s_movement_system.gd
func process_tick(delta: float) -> void:
    # Query entities with Movement AND Input (required), optionally Floating
    var entities = query_entities(
        [C_MovementComponent.COMPONENT_TYPE, C_InputComponent.COMPONENT_TYPE],
        [C_FloatingComponent.COMPONENT_TYPE]
    )

    for entity in entities:
        # Guaranteed: Movement and Input components exist (no null checks!)
        var movement_comp = entity.get_component(C_MovementComponent.COMPONENT_TYPE)
        var input_comp = entity.get_component(C_InputComponent.COMPONENT_TYPE)

        # Optional: Check if entity is floating
        var is_floating = entity.has_component(C_FloatingComponent.COMPONENT_TYPE)

        var body = entity.entity  # E_* root node (scene organization)

        # Process movement...
```

**Benefits**:
- No manual wiring (self-configuring)
- Resilient (component deletion doesn't break queries)
- No null checks for required components
- Semantic queries express intent clearly
- Systems independent of component structure

---

### Event System Example

```gdscript
# scripts/ecs/systems/s_jump_system.gd
func process_tick(delta: float) -> void:
    var entities = query_entities(
        [C_JumpComponent.COMPONENT_TYPE, C_InputComponent.COMPONENT_TYPE]
    )

    for entity in entities:
        var jump_comp = entity.get_component(C_JumpComponent.COMPONENT_TYPE)
        var input_comp = entity.get_component(C_InputComponent.COMPONENT_TYPE)
        var body = entity.entity

        # Check if can jump...
        if can_jump(jump_comp, input_comp, body):
            body.velocity.y = jump_comp.jump_velocity

            # 🎉 Publish event for other systems to react
            ECSEventBus.publish("entity_jumped", {
                "entity": body,
                "velocity": body.velocity,
                "position": body.global_position,
                "jump_force": jump_comp.jump_velocity,
                "timestamp": U_ECSUtils.get_current_time()
            })

# scripts/ecs/systems/s_particle_system.gd
func _ready():
    ECSEventBus.subscribe("entity_jumped", _on_entity_jumped)

func _on_entity_jumped(event_data: Dictionary):
    # Spawn dust particles at jump location
    spawn_dust_particles(event_data.position)

# scripts/ecs/systems/s_sound_system.gd
func _ready():
    ECSEventBus.subscribe("entity_jumped", _on_entity_jumped)

func _on_entity_jumped(event_data: Dictionary):
    # Play jump sound
    play_jump_sound(event_data.entity)

# scripts/ecs/systems/s_camera_system.gd
func _ready():
    ECSEventBus.subscribe("entity_jumped", _on_entity_jumped)

func _on_entity_jumped(event_data: Dictionary):
    # Camera shake on jump
    apply_camera_shake(0.1, event_data.jump_force)
```

**Emergent Gameplay**: A single jump action triggers particles + sound + camera shake without S_JumpSystem knowing about those systems. New systems can subscribe to "entity_jumped" without modifying existing code.

---

This PRD provides a complete blueprint for refactoring the ECS architecture to enable emergent gameplay through decoupled, composable systems with multi-component queries and event-driven communication.
