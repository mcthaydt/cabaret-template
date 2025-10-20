# ECS Architecture Documentation

**Owner**: Development Team | **Last Updated**: 2025-10-20

---

## Table of Contents

1. [Overview](#1-overview)
2. [High-Level Architecture](#2-high-level-architecture)
3. [Component Breakdown](#3-component-breakdown)
4. [Data Flow](#4-data-flow)
5. [Integration Points](#5-integration-points)
6. [Key Patterns](#6-key-patterns)
7. [Example Flows](#7-example-flows)
8. [Current Limitations](#8-current-limitations)
9. [Summary](#9-summary)

---

## 1. Overview

### 1.1 What Is This System?

The ECS (Entity-Component-System) architecture is a data-oriented design pattern that separates game object data (Components) from behavior (Systems). This project implements a **scene-tree integrated ECS** where:

- **Entities** are represented by Godot scene nodes (typically `CharacterBody3D`)
- **Components** are node children that store data (`extends Node`, `class_name ECSComponent`)
- **Systems** are nodes that process components (`extends Node`, `class_name ECSSystem`)
- **M_ECSManager** is the central registry that tracks components and systems

### 1.2 Why This Architecture?

**Goals**:
- **Modularity**: Add/remove gameplay features without touching existing code
- **Composition**: Build complex entities from simple components
- **Testability**: Components and systems can be tested in isolation
- **Hot-reloading**: Change system logic without restarting the game
- **Separation of Concerns**: Data (components) separate from logic (systems)

**Trade-offs Accepted**:
- More boilerplate than traditional OOP (must create component + system files)
- Indirection through manager (systems query components via M_ECSManager)
- Scene tree dependency (entities must be nodes in scene)

### 1.3 Core Principles

1. **Components are data containers** - No game logic, only properties
2. **Systems are logic processors** - Stateless, operate on components
3. **Manager is the registry** - Central source of truth for all components/systems
4. **Auto-registration** - Components/systems self-discover the manager on `_ready()`
5. **Type-based queries** - Systems request components by type (`StringName`)

---

## 2. High-Level Architecture

### 2.1 System Diagram

```
Scene Tree
│
├─ CharacterBody3D (Entity: Player)
│  ├─ C_MovementComponent (data: velocity, speed, acceleration)
│  ├─ C_InputComponent (data: input_vector, jump_pressed)
│  ├─ C_JumpComponent (data: jump_velocity, ground_check_raycast_path)
│  └─ C_FloatingComponent (data: floating_enabled, floating_height)
│
├─ M_ECSManager (Centralized Registry)
│  ├─ _components: Dictionary[StringName, Array[ECSComponent]]
│  │   ├─ "C_MovementComponent" → [component1, component2, ...]
│  │   ├─ "C_InputComponent" → [component3, ...]
│  │   └─ ...
│  ├─ _systems: Array[ECSSystem]
│  │   ├─ S_InputSystem (order: 0)
│  │   ├─ S_MovementSystem (order: 100)
│  │   ├─ S_JumpSystem (order: 50)
│  │   └─ ...
│  └─ Signals: registered(component), unregistered(component)
│
├─ Systems (Process components every frame)
│  ├─ S_InputSystem → reads Input singleton, updates C_InputComponents
│  ├─ S_MovementSystem → reads C_InputComponent + C_MovementComponent, moves body
│  ├─ S_JumpSystem → reads C_InputComponent + C_JumpComponent, applies jump velocity
│  ├─ S_GravitySystem → applies gravity to C_MovementComponent.velocity
│  ├─ S_FloatingSystem → overrides gravity when C_FloatingComponent present
│  ├─ S_RotateToInputSystem → rotates body based on input direction
│  ├─ S_AlignWithSurfaceSystem → aligns visual mesh to surface normals
│  └─ S_LandingIndicatorSystem → projects landing indicator to ground
│
└─ Components (Attached to entities)
    ├─ ECSComponent (Base class)
    │   ├─ COMPONENT_TYPE: StringName (e.g., "C_MovementComponent")
    │   ├─ _manager: M_ECSManager (cached reference)
    │   └─ _locate_manager() → finds manager in scene tree
    ├─ C_MovementComponent
    ├─ C_InputComponent
    ├─ C_JumpComponent
    ├─ C_FloatingComponent
    ├─ C_AlignWithSurfaceComponent
    ├─ C_RotateToInputComponent
    └─ C_LandingIndicatorComponent
```

### 2.2 Data Flow Overview

```
[1] Scene Loads
     ↓
[2] M_ECSManager._ready() → joins "ecs_manager" group
     ↓
[3] Components._ready() → locate manager → register(self)
     ↓
[4] Systems._ready() → locate manager → cache reference
     ↓
[5] Game Loop: Godot calls _physics_process(delta) on all systems
     ↓
[6] Each System: _physics_process(delta) → process_tick(delta)
     ├─ get_components(COMPONENT_TYPE) → query manager
     ├─ for component in components:
     │   ├─ Read component data
     │   ├─ Apply logic
     │   └─ Write component data or call entity methods
     └─ emit signals if needed
     ↓
[7] Repeat [5-6] every frame
```

---

## 3. Component Breakdown

### 3.1 M_ECSManager

**Location**: `scripts/managers/m_ecs_manager.gd`

**Purpose**: Central registry for all components and systems. Provides type-based component queries.

**Key Properties**:
```gdscript
var _components: Dictionary = {}  # StringName → Array[ECSComponent]
var _systems: Array[ECSSystem] = []
```

**Key Methods**:

#### `register_component(component: ECSComponent) -> void`
```gdscript
# Lines 18-31
# Called automatically by components on _ready()
# Stores component in _components[component.COMPONENT_TYPE]
# Emits registered(component) signal
# Asserts if component is null or has no COMPONENT_TYPE
```

#### `unregister_component(component: ECSComponent) -> void`
```gdscript
# Lines 33-49
# Called automatically on component exit_tree
# Removes component from _components array
# Emits unregistered(component) signal
```

#### `get_components(component_type: StringName) -> Array`
```gdscript
# Lines 51-53
# Returns all components of given type
# Systems call this to query components
# Returns empty array if type not found
```

#### `_ready() -> void`
```gdscript
# Lines 12-16
# Ensures single instance per scene tree
# Joins "ecs_manager" group for discovery
```

**Signals**:
- `registered(component: ECSComponent)` - Fired when component registers
- `unregistered(component: ECSComponent)` - Fired when component unregisters

**Discovery Pattern**:
- Joins `"ecs_manager"` scene tree group on `_ready()`
- Components/systems find it via:
  1. Parent hierarchy walk (check `has_method("register_component")`)
  2. Fallback to `get_tree().get_nodes_in_group("ecs_manager")[0]`

---

### 3.2 ECSComponent (Base Class)

**Location**: `scripts/ecs/ecs_component.gd`

**Purpose**: Base class for all data components. Handles auto-registration with manager.

**Editor Customization**:
All components use the `@icon` decorator for visual organization in the Godot editor:
```gdscript
@icon("res://editor_icons/component.svg")
extends ECSComponent
class_name C_MovementComponent
```
This displays a custom icon in the scene tree and inspector for easy identification.

**Key Properties**:
```gdscript
const COMPONENT_TYPE := StringName("")  # Override in subclasses
var _manager: M_ECSManager = null  # Cached manager reference
```

**Key Methods**:

#### `_ready() -> void` (lines 17-38)
```gdscript
# Auto-locates M_ECSManager in scene tree
# Registers self with manager
# Caches manager reference for faster future access
# Subclasses override but must call super._ready()
```

#### `_locate_manager() -> M_ECSManager` (lines 40-55)
```gdscript
# Discovery algorithm:
# 1. Walk up parent hierarchy
# 2. Check if node has method "register_component" (duck typing)
# 3. If found, cache and return
# 4. If not found in parents, search scene tree group "ecs_manager"
# 5. Assert fails if no manager found (fail-fast philosophy)
```

#### `_exit_tree() -> void` (lines 57-60)
```gdscript
# Auto-unregisters from manager when component removed from scene
# Ensures no dangling references
```

**Lifecycle**:
```
Component added to scene
     ↓
_ready() called
     ↓
_locate_manager() searches scene tree
     ↓
manager.register_component(self)
     ↓
Component active (systems can query it)
     ↓
_exit_tree() called
     ↓
manager.unregister_component(self)
     ↓
Component destroyed
```

---

### 3.3 ECSSystem (Base Class)

**Location**: `scripts/ecs/ecs_system.gd`

**Purpose**: Base class for all logic systems. Provides component query API.

**Editor Customization**:
All systems use the `@icon` decorator for visual organization in the Godot editor:
```gdscript
@icon("res://editor_icons/system.svg")
extends ECSSystem
class_name S_MovementSystem
```
This displays a custom icon in the scene tree and inspector for easy identification.

**Key Properties**:
```gdscript
var _manager: M_ECSManager = null  # Cached manager reference
```

**Key Methods**:

#### `_ready() -> void` (lines 17-23)
```gdscript
# Locates M_ECSManager in scene tree
# Caches reference (does NOT register with manager)
# Subclasses override to add initialization logic
```

#### `_locate_manager() -> M_ECSManager` (lines 40-55)
```gdscript
# Same discovery algorithm as ECSComponent
# Systems locate manager but don't register themselves
# This is asymmetric: components register, systems don't
```

#### `get_components(component_type: StringName) -> Array` (lines 26-30)
```gdscript
# Wrapper around manager.get_components()
# Returns empty array if manager not found (graceful degradation)
# Convenience method to avoid typing _manager.get_components()
```

**System Processing Pattern**:
```gdscript
# Typical system implementation
# Note: Systems override process_tick(), not _physics_process() directly
# The base ECSSystem class wraps _physics_process() and calls process_tick()
func process_tick(delta: float) -> void:
    var input_components = get_components(C_InputComponent.COMPONENT_TYPE)
    var movement_components = get_components(C_MovementComponent.COMPONENT_TYPE)

    for input_comp in input_components:
        # Find matching movement component by entity
        var body = input_comp.get_character_body()
        for movement_comp in movement_components:
            if movement_comp.get_character_body() == body:
                # Apply logic: update movement_comp based on input_comp
                movement_comp.velocity = input_comp.input_vector * movement_comp.speed
```

---

### 3.4 Concrete Components

#### C_MovementComponent (`scripts/ecs/components/c_movement_component.gd`)

**Data**:
```gdscript
@export var velocity: Vector3 = Vector3.ZERO
@export var max_speed: float = 5.0
@export var acceleration: float = 50.0
@export var friction: float = 20.0
@export_node_path("Node") var character_body_path: NodePath
@export_node_path("Node") var input_component_path: NodePath  # Cross-reference
@export_node_path("Node") var support_component_path: NodePath  # Cross-reference
```

**Methods**:
- `get_character_body() -> CharacterBody3D` - Resolves NodePath to entity
- `get_input_component() -> C_InputComponent` - Resolves cross-reference
- `get_support_component()` - Returns floating component if present

**Used By**:
- `S_MovementSystem` - Applies velocity to character body
- `S_GravitySystem` - Modifies velocity.y
- `S_FloatingSystem` - Overrides velocity when floating

---

#### C_InputComponent (`scripts/ecs/components/c_input_component.gd`)

**Data**:
```gdscript
@export var input_vector: Vector2 = Vector2.ZERO
@export var jump_pressed: bool = false
@export var jump_just_pressed: bool = false
@export_node_path("Node") var character_body_path: NodePath
```

**Methods**:
- `get_character_body() -> CharacterBody3D`

**Used By**:
- `S_InputSystem` - Reads `Input` singleton, writes to component
- `S_MovementSystem` - Reads input_vector to calculate movement
- `S_JumpSystem` - Reads jump_pressed to trigger jump
- `S_RotateToInputSystem` - Reads input_vector for rotation

---

#### C_JumpComponent (`scripts/ecs/components/c_jump_component.gd`)

**Data**:
```gdscript
@export var jump_velocity: float = 5.0
@export var coyote_time: float = 0.1
@export var jump_buffer_time: float = 0.1
@export var gravity_scale: float = 1.0
@export_node_path("Node") var ground_check_raycast_path: NodePath
@export_node_path("Node") var character_body_path: NodePath
@export_node_path("Node") var input_component_path: NodePath  # Cross-reference
```

**Runtime State** (not @exported):
```gdscript
var time_since_grounded: float = 0.0
var time_since_jump_pressed: float = 999.0
```

**Used By**:
- `S_JumpSystem` - Implements coyote time, jump buffering, applies jump velocity

---

#### C_FloatingComponent (`scripts/ecs/components/c_floating_component.gd`)

**Data**:
```gdscript
@export var floating_enabled: bool = true
@export var floating_height: float = 1.0
@export var floating_spring_strength: float = 10.0
@export var floating_damping: float = 0.5
@export_node_path("Node") var ground_check_raycast_path: NodePath
@export_node_path("Node") var character_body_path: NodePath
@export var settings: FloatingSettings  # Optional settings resource
```

**Runtime State**:
```gdscript
var _debug_snapshot: Dictionary = {}  # For debugging
```

**Used By**:
- `S_FloatingSystem` - Applies spring force to maintain height above ground
- `S_GravitySystem` - Skips gravity when floating is active

---

#### C_AlignWithSurfaceComponent (`scripts/ecs/components/c_align_with_surface_component.gd`)

**Data**:
```gdscript
@export var align_enabled: bool = true
@export var align_speed: float = 5.0
@export_node_path("Node") var ground_check_raycast_path: NodePath
@export_node_path("Node") var character_body_path: NodePath
```

**Used By**:
- `S_AlignWithSurfaceSystem` - Smoothly aligns visual mesh with surface normals

---

#### C_RotateToInputComponent (`scripts/ecs/components/c_rotate_to_input_component.gd`)

**Data**:
```gdscript
@export var rotation_speed: float = 10.0
@export_node_path("Node") var character_body_path: NodePath
@export_node_path("Node") var input_component_path: NodePath
```

**Used By**:
- `S_RotateToInputSystem` - Rotates body to face input direction

---

### 3.5 Settings Resources (RS_*)

**Pattern**: Resource-Driven Configuration

All components use `Resource` classes (prefixed with `RS_`) to store configuration data. This pattern provides:
- **Inspector-friendly**: Edit values in Godot editor with real-time updates
- **Reusability**: Share settings between multiple component instances
- **Hot-reload**: Changes persist without recompiling
- **Serialization**: Saved as `.tres` files in `resources/` folder

**Location**: `scripts/ecs/resources/`

#### RS_MovementSettings (`rs_movement_settings.gd`)
```gdscript
extends Resource
class_name RS_MovementSettings

@export var max_speed: float = 6.0
@export var sprint_speed_multiplier: float = 1.5
@export var acceleration: float = 20.0
@export var deceleration: float = 25.0
@export var use_second_order_dynamics: bool = true
@export var response_frequency: float = 1.0
@export var damping_ratio: float = 0.5
@export var grounded_damping_multiplier: float = 1.5
@export var air_damping_multiplier: float = 0.75
@export var support_grace_time: float = 0.25
@export var air_control_scale: float = 0.3
@export var slope_limit_degrees: float = 50.0
```

#### RS_JumpSettings (`rs_jump_settings.gd`)
```gdscript
extends Resource
class_name RS_JumpSettings

@export var jump_force: float = 12.0
@export var coyote_time: float = 0.15
@export var max_air_jumps: int = 0
@export var jump_buffer_time: float = 0.15
@export var apex_coyote_time: float = 0.1
@export var apex_velocity_threshold: float = 0.1
```

#### RS_FloatingSettings (`rs_floating_settings.gd`)
```gdscript
extends Resource
class_name RS_FloatingSettings

@export var hover_height: float = 1.5
@export var hover_frequency: float = 3.0
@export var damping_ratio: float = 1.0
@export var max_up_speed: float = 20.0
@export var max_down_speed: float = 30.0
@export var fall_gravity: float = 60.0
@export var height_tolerance: float = 0.05
@export var settle_speed_tolerance: float = 0.1
@export var align_to_normal: bool = true
```

#### RS_RotateToInputSettings (`rs_rotate_to_input_settings.gd`)
```gdscript
extends Resource
class_name RS_RotateToInputSettings

@export var turn_speed_degrees: float = 720.0
@export var max_turn_speed_degrees: float = 1080.0
@export var use_second_order: bool = true
@export var rotation_frequency: float = 3.0
@export var rotation_damping: float = 1.0
```

#### RS_AlignSettings (`rs_align_settings.gd`)
```gdscript
extends Resource
class_name RS_AlignSettings

@export var smoothing_speed: float = 12.0
@export var align_only_when_supported: bool = true
@export var recent_support_tolerance: float = 0.2
@export var fallback_up_direction: Vector3 = Vector3.UP
```

#### RS_LandingIndicatorSettings (`rs_landing_indicator_settings.gd`)
```gdscript
extends Resource
class_name RS_LandingIndicatorSettings

@export var indicator_height_offset: float = 0.05
@export var ground_plane_height: float = 0.0
@export var max_projection_distance: float = 10.0
@export var ray_origin_lift: float = 0.15
@export var align_to_hit_normal: bool = true
@export_range(0, 2, 1) var normal_axis: int = 2  # 0=X, 1=Y, 2=Z
@export var normal_axis_positive: bool = false
```

**Usage Pattern**:
```gdscript
# In component
@export var settings: RS_MovementSettings

func _ready():
    if settings == null:
        push_error("Missing settings resource!")
        return

    # Access settings
    var speed = settings.max_speed
    var accel = settings.acceleration
```

**Default Instances**: Pre-configured `.tres` files in `resources/` folder:
- `movement_default.tres` → RS_MovementSettings
- `jump_default.tres` → RS_JumpSettings
- `floating_default.tres` → RS_FloatingSettings
- `rotate_default.tres` → RS_RotateToInputSettings
- `align_default.tres` → RS_AlignSettings
- `landing_indicator_default.tres` → RS_LandingIndicatorSettings

---

### 3.6 Concrete Systems

#### S_InputSystem (`scripts/ecs/systems/s_input_system.gd`)

**Purpose**: Reads Godot `Input` singleton, writes to `C_InputComponent`

**Processing**:
```gdscript
func process_tick(_delta: float) -> void:
    var input_components = get_components(C_InputComponent.COMPONENT_TYPE)

    for component in input_components:
        if component == null:
            continue

        # Read input actions
        var input_x := Input.get_axis("move_left", "move_right")
        var input_y := Input.get_axis("move_forward", "move_backward")

        # Write to component
        component.input_vector = Vector2(input_x, input_y)
        component.jump_just_pressed = Input.is_action_just_pressed("jump")
        component.jump_pressed = Input.is_action_pressed("jump")
```

**Execution Order**: First (reads input before other systems)

---

#### S_MovementSystem (`scripts/ecs/systems/s_movement_system.gd`)

**Purpose**: Applies movement based on input, handles acceleration/friction

**Processing** (lines 32-62):
```gdscript
func process_tick(delta: float) -> void:
    var movement_components = get_components(C_MovementComponent.COMPONENT_TYPE)

    for movement_comp in movement_components:
        if movement_comp == null:
            continue

        var body := movement_comp.get_character_body()
        var input_comp := movement_comp.get_input_component()

        if body == null or input_comp == null:
            continue

        # Calculate target velocity from input
        var input_dir := Vector3(input_comp.input_vector.x, 0, input_comp.input_vector.y)
        var target_velocity := input_dir * movement_comp.max_speed

        # Apply acceleration or friction
        if input_dir.length() > 0.01:
            movement_comp.velocity = movement_comp.velocity.lerp(
                target_velocity,
                movement_comp.acceleration * delta
            )
        else:
            movement_comp.velocity = movement_comp.velocity.lerp(
                Vector3.ZERO,
                movement_comp.friction * delta
            )

        # Apply velocity to body
        body.velocity = movement_comp.velocity
        body.move_and_slide()

        # Sync velocity back to component
        movement_comp.velocity = body.velocity
```

**Dependencies**: Requires `C_InputComponent` and `C_MovementComponent` on same entity

---

#### S_JumpSystem (`scripts/ecs/systems/s_jump_system.gd`)

**Purpose**: Implements jump logic with coyote time and jump buffering

**Processing** (lines 21-102):
```gdscript
func process_tick(delta: float) -> void:
    # Build body → floating_component map (to check if entity is floating)
    var floating_by_body := _build_floating_map()

    var jump_components = get_components(C_JumpComponent.COMPONENT_TYPE)

    for jump_comp in jump_components:
        if jump_comp == null:
            continue

        var body := jump_comp.get_character_body()
        var input_comp := jump_comp.get_input_component()
        var raycast := jump_comp.get_ground_check_raycast()

        if body == null or input_comp == null or raycast == null:
            continue

        # Skip if entity is floating
        if floating_by_body.has(body):
            continue

        # Update grounded state
        var is_grounded := raycast.is_colliding()
        if is_grounded:
            jump_comp.time_since_grounded = 0.0
        else:
            jump_comp.time_since_grounded += delta

        # Update jump buffer
        if input_comp.jump_just_pressed:
            jump_comp.time_since_jump_pressed = 0.0
        else:
            jump_comp.time_since_jump_pressed += delta

        # Check if can jump (coyote time + jump buffer)
        var can_jump := (
            jump_comp.time_since_grounded < jump_comp.coyote_time
            and jump_comp.time_since_jump_pressed < jump_comp.jump_buffer_time
        )

        # Apply jump
        if can_jump:
            body.velocity.y = jump_comp.jump_velocity
            jump_comp.time_since_jump_pressed = 999.0  # Consume jump
```

**Features**:
- **Coyote Time**: Can jump shortly after leaving ground
- **Jump Buffering**: Jump input registered before landing still triggers
- **Floating Check**: Entities with `C_FloatingComponent` can't jump

---

#### S_GravitySystem (`scripts/ecs/systems/s_gravity_system.gd`)

**Purpose**: Applies gravity to movement components (unless floating)

**Processing** (lines 23-53):
```gdscript
func process_tick(delta: float) -> void:
    # Build body → floating_component map
    var floating_by_body := _build_floating_map()

    var movement_components = get_components(C_MovementComponent.COMPONENT_TYPE)

    for movement_comp in movement_components:
        if movement_comp == null:
            continue

        var body := movement_comp.get_character_body()
        if body == null:
            continue

        # Skip if entity is floating
        if floating_by_body.has(body):
            continue

        # Apply gravity
        movement_comp.velocity.y += GRAVITY * delta
        body.velocity = movement_comp.velocity
```

**Interaction with Floating**: If entity has active floating component, gravity is disabled

---

#### S_FloatingSystem (`scripts/ecs/systems/s_floating_system.gd`)

**Purpose**: Maintains entity at specified height above ground using spring physics

**Processing** (lines 22-93):
```gdscript
func process_tick(delta: float) -> void:
    var floating_components = get_components(C_FloatingComponent.COMPONENT_TYPE)

    for floating_comp in floating_components:
        if floating_comp == null or not floating_comp.floating_enabled:
            continue

        var body := floating_comp.get_character_body()
        var raycast := floating_comp.get_ground_check_raycast()

        if body == null or raycast == null:
            continue

        if not raycast.is_colliding():
            continue

        # Calculate spring force
        var distance_to_ground := raycast.get_collision_point().distance_to(body.global_position)
        var height_error := floating_comp.floating_height - distance_to_ground

        # Spring force = k * x - d * v
        var spring_force := (
            height_error * floating_comp.floating_spring_strength
            - body.velocity.y * floating_comp.floating_damping
        )

        # Apply force
        body.velocity.y += spring_force * delta
        body.move_and_slide()

        # Debug snapshot
        floating_comp._debug_snapshot = {
            "distance_to_ground": distance_to_ground,
            "height_error": height_error,
            "spring_force": spring_force,
            "velocity_y": body.velocity.y,
        }
```

**Physics**: Implements spring-damper system for smooth floating

---

#### S_RotateToInputSystem (`scripts/ecs/systems/s_rotate_to_input_system.gd`)

**Purpose**: Rotates entity to face input direction

**Processing** (lines 10-37):
```gdscript
func process_tick(delta: float) -> void:
    var rotate_components = get_components(C_RotateToInputComponent.COMPONENT_TYPE)

    for rotate_comp in rotate_components:
        if rotate_comp == null:
            continue

        var body := rotate_comp.get_character_body()
        var input_comp := rotate_comp.get_input_component()

        if body == null or input_comp == null:
            continue

        if input_comp.input_vector.length() < 0.01:
            continue

        # Calculate target direction
        var input_dir := Vector3(input_comp.input_vector.x, 0, input_comp.input_vector.y)
        var target_rotation := atan2(input_dir.x, input_dir.z)

        # Lerp current rotation to target
        var current_rotation := body.rotation.y
        var new_rotation := lerp_angle(current_rotation, target_rotation, rotate_comp.rotation_speed * delta)

        body.rotation.y = new_rotation
```

---

## 4. Data Flow

### 4.1 Component Registration Flow

```
[1] Component node added to scene
         ↓
[2] Component._ready() called by Godot
         ↓
[3] _locate_manager() searches scene tree
         │
         ├─ [3a] Walk parent hierarchy
         │      Check: node.has_method("register_component")
         │      If found: return node
         │
         └─ [3b] Fallback: search scene tree group
                get_tree().get_nodes_in_group("ecs_manager")[0]
         ↓
[4] _manager = located_manager  (cache reference)
         ↓
[5] _manager.register_component(self)
         ↓
[6] Manager adds to _components[COMPONENT_TYPE]
         ↓
[7] Manager emits registered(component) signal
         ↓
[8] Component now queryable by systems
```

### 4.2 System Query Flow

```
[1] System._physics_process(delta) called
         ↓
[2] var components = get_components(C_MovementComponent.COMPONENT_TYPE)
         ↓
[3] get_components() → _manager.get_components()
         ↓
[4] Manager looks up _components[component_type]
         ↓
[5] Returns Array[ECSComponent] (may be empty)
         ↓
[6] System iterates array
         │
         ├─ for component in components:
         │      ├─ Check component != null
         │      ├─ Read component data (component.velocity)
         │      ├─ Apply logic
         │      └─ Write component data or call entity methods
         │
         └─ Continue next frame
```

### 4.3 Cross-Component Reference Resolution

**Problem**: Systems need to match components on the same entity.

**Current Pattern**: Components store `NodePath` to other components

**Example** (S_MovementSystem):
```
[1] Get all C_MovementComponents
         ↓
[2] For each movement_comp:
         ↓
[3] Call movement_comp.get_input_component()
         │
         ├─ if input_component_path.is_empty(): return null
         ├─ return get_node_or_null(input_component_path) as C_InputComponent
         │
         └─ Returns input component or null
         ↓
[4] Check if input_comp != null
         ↓
[5] Read input_comp.input_vector
         ↓
[6] Apply to movement_comp.velocity
```

**Limitation**: This creates tight coupling between components. See [§8 Current Limitations](#8-current-limitations).

### 4.4 Component Unregistration Flow

```
[1] Component node removed from scene
         ↓
[2] Component._exit_tree() called by Godot
         ↓
[3] Check: _manager != null
         ↓
[4] _manager.unregister_component(self)
         ↓
[5] Manager removes from _components[COMPONENT_TYPE] array
         ↓
[6] Manager emits unregistered(component) signal
         ↓
[7] Component destroyed by Godot
```

---

## 5. Integration Points

### 5.1 Scene Tree Setup

**Typical Scene Structure**:
```
Main Scene (Node)
├─ M_ECSManager (manager node)
│
├─ Player (CharacterBody3D) ← Entity
│  ├─ C_MovementComponent
│  ├─ C_InputComponent
│  ├─ C_JumpComponent
│  ├─ C_FloatingComponent
│  ├─ MeshInstance3D (visual)
│  └─ RayCast3D (ground check)
│
├─ S_InputSystem
├─ S_MovementSystem
├─ S_JumpSystem
├─ S_GravitySystem
├─ S_FloatingSystem
└─ S_RotateToInputSystem
```

**Setup Steps**:
1. Add `M_ECSManager` node to scene (anywhere in tree)
2. Add entity node (e.g., `CharacterBody3D`)
3. Add components as children of entity
4. Configure component @export properties in inspector:
   - Set `character_body_path` to `..` (parent)
   - Set cross-component paths (e.g., `input_component_path`)
5. Add system nodes to scene (anywhere in tree)
6. Systems automatically discover manager on scene load

### 5.2 Discovery Pattern

**How components/systems find M_ECSManager**:

**Step 1: Parent Hierarchy Walk** (preferred, faster)
```gdscript
func _locate_manager() -> M_ECSManager:
    var current_node: Node = get_parent()
    while current_node != null:
        if current_node.has_method("register_component"):
            return current_node
        current_node = current_node.get_parent()
    # ... fallback to step 2
```

**Step 2: Scene Tree Group Search** (fallback)
```gdscript
func _locate_manager() -> M_ECSManager:
    # ... parent walk failed
    var managers = get_tree().get_nodes_in_group("ecs_manager")
    if managers.size() > 0:
        return managers[0]
    # ... assert fails if still not found
```

**Why This Pattern?**
- **Flexible**: Manager can be anywhere in scene tree
- **Cached**: Result stored in `_manager` variable
- **Fail-Fast**: Asserts if manager not found (developer error)
- **No Singleton**: Avoids global state, testable

### 5.3 Lifecycle Order

**Scene Load**:
```
1. M_ECSManager._ready()       → joins "ecs_manager" group
2. Components._ready()          → locate manager, register
3. Systems._ready()             → locate manager, cache reference
4. Game loop starts
```

**Scene Unload**:
```
1. Game loop stops
2. Components._exit_tree()      → unregister from manager
3. Systems destroyed
4. M_ECSManager destroyed
```

**Hot-Reload** (F5 in editor):
```
1. Scene unloads (all nodes destroyed)
2. Scene reloads (new instances created)
3. All components re-register
4. Systems re-locate manager
```

### 5.4 Testing Integration

**Unit Testing Components**:
```gdscript
# tests/unit/ecs/components/test_movement_component.gd
extends GutTest

func test_movement_component_defaults():
    var component = C_MovementComponent.new()
    assert_eq(component.velocity, Vector3.ZERO)
    assert_eq(component.max_speed, 5.0)
```

**Integration Testing Systems**:
```gdscript
# tests/unit/ecs/systems/test_movement_system.gd
extends GutTest

func test_movement_system_applies_velocity():
    # Setup
    var manager = M_ECSManager.new()
    add_child(manager)
    await get_tree().process_frame

    var body = CharacterBody3D.new()
    add_child(body)

    var movement_comp = C_MovementComponent.new()
    movement_comp.character_body_path = movement_comp.get_path_to(body)
    body.add_child(movement_comp)
    await get_tree().process_frame

    var input_comp = C_InputComponent.new()
    input_comp.input_vector = Vector2(1, 0)
    body.add_child(input_comp)
    await get_tree().process_frame

    movement_comp.input_component_path = movement_comp.get_path_to(input_comp)

    var system = S_MovementSystem.new()
    add_child(system)
    await get_tree().process_frame

    # Execute
    system._physics_process(0.016)

    # Verify
    assert_true(movement_comp.velocity.x > 0, "Velocity should increase")
```

---

## 6. Key Patterns

### 6.1 Entity Abstraction via Scene Nodes

**Pattern**: Entities are represented by `CharacterBody3D` (or other `Node` types).

**Why Not Explicit Entity Class?**
- Leverages Godot's scene tree for hierarchy
- Entities get all node features (transform, parent/child, signals)
- No need for separate entity ID system

**Trade-off**: Entities must be in scene tree (can't have "abstract" entities).

### 6.2 Auto-Registration

**Pattern**: Components self-register on `_ready()`.

**Benefits**:
- No manual registration code needed
- Hot-reload friendly (components re-register automatically)
- Declarative (add component to scene = it's registered)

**Implementation**:
```gdscript
# In ECSComponent base class
func _ready() -> void:
    _manager = _locate_manager()
    if _manager:
        _manager.register_component(self)
```

### 6.3 Type-Based Component Queries

**Pattern**: Systems query components by `StringName` constant.

**Example**:
```gdscript
const COMPONENT_TYPE := StringName("C_MovementComponent")

# In system:
var components = get_components(C_MovementComponent.COMPONENT_TYPE)
```

**Benefits**:
- Fast lookup (Dictionary keyed by StringName)
- Type-safe (constant defined per component class)
- Easy to query (no complex filter predicates)

**Limitation**: Can only query one component type at a time (no multi-component queries).

### 6.4 Cross-Component NodePath References

**Pattern**: Components store `NodePath` to other required components.

**Example**:
```gdscript
# In C_MovementComponent
@export_node_path("Node") var input_component_path: NodePath

func get_input_component() -> C_InputComponent:
    if input_component_path.is_empty():
        return null
    return get_node_or_null(input_component_path) as C_InputComponent
```

**Benefits**:
- Works with Godot inspector (drag-and-drop node references)
- Serializable (saves with scene)

**Drawbacks**:
- **Tight Coupling**: Component knows about other specific component types
- **Manual Matching**: Systems must manually cross-reference components
- **Not Composable**: Can't easily swap input sources (player vs AI)

**See**: [§8 Current Limitations](#8-current-limitations) for improvement proposals.

### 6.5 Settings Resources

**Pattern**: Components optionally load settings from `Resource` files.

**Example**:
```gdscript
# In C_FloatingComponent
@export var settings: FloatingSettings

func _ready():
    super._ready()  # Register with manager
    if settings:
        floating_height = settings.height
        floating_spring_strength = settings.spring_strength
```

**Benefits**:
- Reusable configs across multiple entities
- Editor-friendly (edit in inspector, save as `.tres` file)
- Hot-reload friendly (change resource, see instant updates)

### 6.6 Component State Validation

**Pattern**: Components validate state in `_ready()` before registration.

**Example**:
```gdscript
# In C_JumpComponent._ready()
func _ready() -> void:
    if settings:
        # Validate settings exist
        if settings.jump_velocity == null:
            push_error("JumpComponent: settings.jump_velocity is null")
            return
    super._ready()  # Register only if valid
```

**Benefits**:
- Fail-fast on configuration errors
- Clear error messages in console
- Prevents invalid components from being registered

### 6.7 Scene Tree Scope & Cross-Tree References

**The Problem**: Components in `player_template.tscn` (instantiated) cannot reference nodes in `base_scene_template.tscn` (parent scene) via NodePath. Scene boundaries break NodePath references.

**Example**:
```
base_scene_template.tscn
├─ E_PlayerCamera (Camera3D)           ← In base scene
└─ E_Player (instance of player_template.tscn)
    └─ C_MovementComponent
        └─ camera_node_path: NodePath  ← Cannot reach E_PlayerCamera!
```

**NodePath Policy**:

| Reference Type | Scope | Method |
|----------------|-------|--------|
| ✅ Component → Body | Same entity subtree | NodePath export |
| ✅ Component → RayCast | Same entity subtree | NodePath export |
| ❌ Component → Another Component | Any scope | Use query system |
| ❌ Component → Cross-tree Node | Different scene file | Runtime discovery |

**Cross-Tree Resolution Patterns**:

#### 1. General Infrastructure (`U_ECSUtils`)

```gdscript
# For singletons (one instance per scene)
static func get_singleton_from_group(from_node: Node, group_name: String) -> Node:
    """Get first node from group (managers, main camera, main player, etc.)"""
    var nodes = from_node.get_tree().get_nodes_in_group(group_name)
    if nodes.size() > 0:
        return nodes[0]
    push_warning("U_ECSUtils: No node found in group '%s'" % group_name)
    return null

# For collections (multiple instances)
static func get_nodes_from_group(from_node: Node, group_name: String) -> Array:
    """Get all nodes from group (spawn points, enemies, collectibles, etc.)"""
    return from_node.get_tree().get_nodes_in_group(group_name)
```

#### 2. Standard Group Naming Convention

| Group Name | Purpose | Cardinality | Usage Example |
|------------|---------|-------------|---------------|
| `ecs_manager` | ECS manager singleton | 1 | `U_ECSUtils.get_manager(node)` |
| `main_camera` | Active gameplay camera | 1 | `U_ECSUtils.get_active_camera(node)` |
| `main_player` | Player entity root | 1 | `get_singleton_from_group(node, "main_player")` |
| `spawn_points` | Entity spawn locations | N | `get_nodes_from_group(node, "spawn_points")` |
| `interactables` | World objects for interaction | N | `get_nodes_from_group(node, "interactables")` |

**Convention**: Lowercase with underscores. Singletons prefixed with `main_`.

#### 3. Resolution Priority (for any cross-tree reference)

```
1. Native Godot API (if available)
   ├─ get_viewport().get_camera_3d()
   ├─ get_tree().current_scene
   └─ get_tree().root
        ↓
2. Group Discovery
   └─ get_tree().get_nodes_in_group("group_name")
        ↓
3. Parent Hierarchy (same-tree optimization)
   └─ Walk parents checking has_method() or is_instance_of()
        ↓
4. Fallback
   └─ Return null + warning
```

#### 4. Specialized Helpers Use General Pattern

```gdscript
# Camera helper (Godot API + group fallback)
static func get_active_camera(from_node: Node) -> Camera3D:
    """Get active camera (cross-tree safe)"""
    # Priority 1: Viewport's active camera (Godot's native "current" camera)
    var viewport = from_node.get_viewport()
    if viewport:
        var cam = viewport.get_camera_3d()
        if cam:
            return cam

    # Priority 2: Fallback to "main_camera" group
    return get_singleton_from_group(from_node, "main_camera") as Camera3D

# Manager helper (parent hierarchy + group fallback)
static func get_manager(from_node: Node) -> M_ECSManager:
    """Get ECS manager (same-tree optimization + cross-tree fallback)"""
    # Priority 1: Parent hierarchy (faster for same-tree)
    var current = from_node.get_parent()
    while current:
        if current.has_method("query_entities"):
            return current
        current = current.get_parent()

    # Priority 2: Fallback to group
    return get_singleton_from_group(from_node, "ecs_manager") as M_ECSManager
```

#### 5. Example: Camera Access with Override Pattern

```gdscript
# Component (optional same-subtree override)
@export_node_path("Camera3D") var camera_node_path: NodePath

# System (uses override OR runtime discovery)
func process_tick(delta: float) -> void:
    for entity in query_entities([C_MovementComponent.COMPONENT_TYPE]):
        var movement_comp = entity.get_component(C_MovementComponent.COMPONENT_TYPE)

        # Priority: 1) component override → 2) runtime discovery → 3) null
        var camera: Camera3D = null
        if movement_comp.camera_node_path:
            camera = movement_comp.get_node_or_null(movement_comp.camera_node_path)
        if not camera:
            camera = U_ECSUtils.get_active_camera(movement_comp)  # Cross-tree safe!

        if camera:
            # Use camera for movement rotation/aiming...
```

**Why This Matters**:

- **Scene Composition**: Templates instantiate other templates (player in base scene)
- **Prefabs**: Reusable entities work in any scene without manual wiring
- **Dynamic Spawning**: Runtime-spawned entities discover resources automatically
- **Decoupling**: Systems find resources without hardcoded scene structure

**Rule of Thumb**: If it's in a different scene file, use runtime discovery, not NodePath.

---

## 7. Example Flows

### 7.1 Player Jump (Complete Flow)

**Scenario**: Player presses jump button, character jumps.

**Flow**:
```
[Frame N: Jump Button Pressed]

1. S_InputSystem._process()
   ├─ Input.is_action_just_pressed("jump") → true
   ├─ Queries: get_components(C_InputComponent.COMPONENT_TYPE)
   ├─ Writes: input_comp.jump_just_pressed = true
   └─ Result: C_InputComponent.jump_just_pressed = true

2. S_JumpSystem._physics_process(delta)
   ├─ Queries: get_components(C_JumpComponent.COMPONENT_TYPE)
   ├─ For each jump_comp:
   │   ├─ var input_comp = jump_comp.get_input_component()
   │   ├─ var body = jump_comp.get_character_body()
   │   ├─ var raycast = jump_comp.get_ground_check_raycast()
   │   │
   │   ├─ Check: raycast.is_colliding() → true (on ground)
   │   ├─ Update: jump_comp.time_since_grounded = 0.0
   │   │
   │   ├─ Check: input_comp.jump_just_pressed → true
   │   ├─ Update: jump_comp.time_since_jump_pressed = 0.0
   │   │
   │   ├─ Check: can_jump = (time_since_grounded < coyote_time) → true
   │   ├─ Apply: body.velocity.y = jump_comp.jump_velocity
   │   └─ Consume: jump_comp.time_since_jump_pressed = 999.0
   │
   └─ Result: body.velocity.y = 5.0 (upward velocity)

3. S_GravitySystem._physics_process(delta)
   ├─ Queries: get_components(C_MovementComponent.COMPONENT_TYPE)
   ├─ Check: entity has C_FloatingComponent? → No
   ├─ Apply: movement_comp.velocity.y += GRAVITY * delta
   ├─ Sync: body.velocity = movement_comp.velocity
   └─ Result: Gravity will start pulling down next frame

[Frame N+1: In Air]

4. S_JumpSystem._physics_process(delta)
   ├─ Check: raycast.is_colliding() → false (in air)
   ├─ Update: jump_comp.time_since_grounded += delta (starts coyote timer)
   └─ Result: Can still jump within coyote_time window

5. S_GravitySystem._physics_process(delta)
   ├─ Apply: movement_comp.velocity.y += GRAVITY * delta
   └─ Result: Character decelerates upward, then falls

[Frame N+10: Landing]

6. S_JumpSystem._physics_process(delta)
   ├─ Check: raycast.is_colliding() → true (landed)
   ├─ Update: jump_comp.time_since_grounded = 0.0
   └─ Result: Ready to jump again
```

### 7.2 Player Movement (Complete Frame)

**Scenario**: Player holds right arrow key, character moves right.

**Flow** (single frame):
```
[_process(delta) - Runs before _physics_process]

1. S_InputSystem._process(delta)
   ├─ Input.get_axis("move_left", "move_right") → 1.0
   ├─ Input.get_axis("move_forward", "move_backward") → 0.0
   ├─ Writes: input_comp.input_vector = Vector2(1, 0)
   └─ Result: Input captured

[_physics_process(delta) - Runs after _process]

2. S_MovementSystem._physics_process(delta)
   ├─ Queries: get_components(C_MovementComponent.COMPONENT_TYPE)
   ├─ For each movement_comp:
   │   ├─ var input_comp = movement_comp.get_input_component()
   │   ├─ var body = movement_comp.get_character_body()
   │   │
   │   ├─ Calculate: input_dir = Vector3(1, 0, 0)
   │   ├─ Calculate: target_velocity = input_dir * max_speed = Vector3(5, 0, 0)
   │   │
   │   ├─ Lerp: movement_comp.velocity = lerp(current, target, acceleration * delta)
   │   │       = lerp(Vector3(0,0,0), Vector3(5,0,0), 50 * 0.016)
   │   │       = lerp(Vector3(0,0,0), Vector3(5,0,0), 0.8)
   │   │       = Vector3(4, 0, 0)
   │   │
   │   ├─ Apply: body.velocity = movement_comp.velocity
   │   ├─ Move: body.move_and_slide()
   │   └─ Sync: movement_comp.velocity = body.velocity
   │
   └─ Result: Character moves right at 4 m/s (accelerating toward 5 m/s)

3. S_RotateToInputSystem._process(delta)
   ├─ Queries: get_components(C_RotateToInputComponent.COMPONENT_TYPE)
   ├─ For each rotate_comp:
   │   ├─ var input_comp = rotate_comp.get_input_component()
   │   ├─ var body = rotate_comp.get_character_body()
   │   │
   │   ├─ Calculate: input_dir = Vector3(1, 0, 0)
   │   ├─ Calculate: target_rotation = atan2(1, 0) = 1.57 rad (90 degrees)
   │   │
   │   ├─ Lerp: new_rotation = lerp_angle(current, target, rotation_speed * delta)
   │   ├─ Apply: body.rotation.y = new_rotation
   │   │
   └─ Result: Character rotates to face right
```

### 7.3 Floating Character (System Interaction)

**Scenario**: Character with `C_FloatingComponent` hovers above ground.

**Flow**:
```
[Physics Tick]

1. S_FloatingSystem._physics_process(delta)
   ├─ Queries: get_components(C_FloatingComponent.COMPONENT_TYPE)
   ├─ For each floating_comp:
   │   ├─ Check: floating_comp.floating_enabled → true
   │   ├─ var raycast = floating_comp.get_ground_check_raycast()
   │   ├─ Check: raycast.is_colliding() → true
   │   │
   │   ├─ Calculate: distance_to_ground = raycast distance
   │   ├─ Calculate: height_error = floating_height - distance_to_ground
   │   │           = 1.0 - 0.8 = 0.2 (too low, need to rise)
   │   │
   │   ├─ Spring Force: k * x - d * v
   │   │   = 10 * 0.2 - 0.5 * body.velocity.y
   │   │   = 2.0 - (0.5 * -0.5)
   │   │   = 2.0 + 0.25 = 2.25 N (upward)
   │   │
   │   ├─ Apply: body.velocity.y += spring_force * delta
   │   │         = -0.5 + 2.25 * 0.016 = -0.464
   │   │
   │   ├─ Move: body.move_and_slide()
   │   └─ Debug: Update _debug_snapshot
   │
   └─ Result: Character rises slowly toward target height

2. S_GravitySystem._physics_process(delta)
   ├─ Queries: get_components(C_MovementComponent.COMPONENT_TYPE)
   ├─ For each movement_comp:
   │   ├─ var body = movement_comp.get_character_body()
   │   │
   │   ├─ Build: floating_by_body map
   │   ├─ Check: floating_by_body.has(body) → true
   │   │
   │   └─ Skip: Gravity NOT applied (floating active)
   │
   └─ Result: Floating overrides gravity

[Next Frame]
   Floating system continues adjusting height until:
   height_error ≈ 0 and velocity.y ≈ 0
   → Character hovers stably at floating_height
```

---

## 8. Current Limitations

### 8.1 No Multi-Component Queries

**Problem**: Systems can only query one component type at a time.

**Current Workaround** (manual cross-referencing):
```gdscript
# S_MovementSystem must manually match components
var movement_components = get_components(C_MovementComponent.COMPONENT_TYPE)
var input_components = get_components(C_InputComponent.COMPONENT_TYPE)

for movement_comp in movement_components:
    var input_comp = movement_comp.get_input_component()  # Manual lookup
    if input_comp != null:
        # Apply logic
```

**Desired API**:
```gdscript
# Query entities with BOTH components
var entities = query_entities([C_MovementComponent.COMPONENT_TYPE, C_InputComponent.COMPONENT_TYPE])

for entity in entities:
    var movement_comp = entity.get_component(C_MovementComponent.COMPONENT_TYPE)
    var input_comp = entity.get_component(C_InputComponent.COMPONENT_TYPE)
    # Both guaranteed non-null
```

**Impact**: **Critical for scalability**. Current approach doesn't scale beyond 2-3 component queries.

**Solution**: See `docs/ecs/refactor recommendations/ecs_refactor_recommendations.md` → Query System

---

### 8.2 Tight Component Coupling

**Problem**: Components store `NodePath` to other specific components.

**Example**:
```gdscript
# C_MovementComponent "knows" about C_InputComponent
@export_node_path("Node") var input_component_path: NodePath

func get_input_component() -> C_InputComponent:
    return get_node_or_null(input_component_path) as C_InputComponent
```

**Issues**:
- Can't swap input sources (player input vs AI input) without changing component
- Hard to create new movement types that use different inputs
- Components aren't truly composable

**Desired Pattern**: Systems wire components together, components don't know about each other.

**Solution**: See `docs/ecs/refactor recommendations/ecs_refactor_recommendations.md` → Decouple Components

---

### 8.3 No Event System

**Problem**: Systems can't communicate events without signals or direct coupling.

**Current State**: Only 2 signals total:
- `M_ECSManager.registered(component)`
- `M_ECSManager.unregistered(component)`

**Missing**: Domain events like:
- `entity_jumped` → Animation system plays jump animation
- `entity_landed` → Sound system plays landing sound
- `entity_damaged` → VFX system spawns damage particles

**Impact**: **Blocks emergent gameplay**. Can't implement systemic interactions without hardcoding.

**Solution**: See `docs/ecs/refactor recommendations/ecs_refactor_recommendations.md` → Event Bus

---

### 8.4 No System Execution Ordering

**Problem**: Systems execute in scene tree order (undefined in code).

**Current**: Relies on manual scene ordering (must remember to place S_InputSystem before S_MovementSystem).

**Desired**:
```gdscript
# In system definition
@export var execution_order: int = 0  # S_InputSystem = 0
@export var execution_group: StringName = "gameplay"

# Manager sorts systems by order automatically
```

**Impact**: Medium. Works for current simple systems, will break with more systems.

**Solution**: See `docs/ecs/refactor recommendations/ecs_refactor_recommendations.md` → System Ordering

---

### 8.5 No Entity Abstraction

**Problem**: No explicit entity concept—`CharacterBody3D` acts as implicit entity.

**Issues**:
- Can't have non-physical entities (UI elements, game logic)
- Hard to serialize entity state
- Can't query "all entities with X components" directly

**Current Pattern**: Components reference parent node as "entity".

**Desired Pattern**: Explicit entity ID, components belong to entity ID, systems query by entity.

**Impact**: Low for current use case (3D character controller), High for general ECS.

**Solution**: See `docs/ecs/refactor recommendations/ecs_refactor_recommendations.md` → Entity Tracking

---

### 8.6 Manual Body Deduplication

**Problem**: Multiple systems create `processed: Dictionary = {}` to prevent double-processing.

**Example** (S_JumpSystem, S_GravitySystem):
```gdscript
var floating_by_body: Dictionary = {}
for floating in get_components(C_FloatingComponent.COMPONENT_TYPE):
    var body = floating.get_character_body()
    floating_by_body[body] = floating
```

**Impact**: Low (works, just verbose).

**Solution**: Extract helper class `BodyTracker` or improve query system.

---

## 9. Summary

### 9.1 Strengths of Current Implementation

**✓ Clean Separation**: Components store data, systems process logic
**✓ Godot Integration**: Leverages scene tree naturally
**✓ Auto-Registration**: Components self-register on scene load
**✓ Testable**: Components/systems can be unit tested
**✓ Hot-Reload Friendly**: F5 in editor re-registers everything
**✓ Discoverable**: Manager found via scene tree (no singleton)
**✓ Fail-Fast**: Asserts catch configuration errors early

### 9.2 Current Feature Set

**Implemented**:
- Component/system base classes with lifecycle management
- Type-based component queries
- Manager discovery pattern (parent walk + scene tree group)
- Auto-registration/unregistration
- Cross-component NodePath references
- Settings resource integration
- Debug snapshots for components

**Additional Systems/Components** (exist but detailed docs pending refactor):
- S_AlignWithSurfaceSystem - Smoothly aligns visual mesh with ground normals
- S_LandingIndicatorSystem - Projects landing point indicator during jumps
- C_LandingIndicatorComponent - Manages landing visualization data

**Not Implemented** (see [§8](#8-current-limitations)):
- Multi-component queries
- Event bus for system communication
- System execution ordering
- Entity ID abstraction
- Component tags for categories

### 9.3 Next Steps

**For Production Use**:
1. **Implement query system** (highest impact for scalability)
2. **Add event bus** (enables emergent gameplay)
3. **Decouple components** (remove cross-component NodePaths)
4. **System ordering** (explicit execution order)

**For Code Quality**:
1. Extract duplicate helper patterns (see refactor recommendations)
2. Standardize null-safety checks
3. Add comprehensive API documentation
4. Create tutorial scenes/examples

### 9.4 Related Documentation

- **docs/ecs/for humans/ecs_ELI5.md** - Beginner-friendly explanation
- **docs/ecs/for humans/ecs_tradeoffs.md** - Pros/cons analysis
- **docs/ecs/refactor recommendations/ecs_refactor_recommendations.md** - Improvement proposals
- **tests/unit/ecs/** - Example usage in tests

---

**End of Architecture Documentation**
