# Scene Organization Guide

## Overview

This guide documents the standardized scene tree organization used throughout Project Musical Parakeet. Following these conventions ensures consistency, maintainability, and clarity across all gameplay scenes.

## Table of Contents

1. [Standardized Node Tree Structure](#standardized-node-tree-structure)
2. [System Categories](#system-categories)
3. [Marker Scripts](#marker-scripts)
4. [Node Naming Conventions](#node-naming-conventions)
5. [Example Scenes](#example-scenes)
6. [Best Practices](#best-practices)
7. [Single‑Entity Controllers](#single-entity-controllers)
   1. [Checkpoint (E_Checkpoint_SafeZone)](#checkpoint-e_checkpoint_safezone)
   2. [Reusable Volume Settings](#reusable-volume-settings)
   3. [Repeatable Migration Checklist](#repeatable-migration-checklist)

---

## Standardized Node Tree Structure

All gameplay scenes should follow this hierarchy:

```
Main (Node3D) [main_root_node.gd]
├─ SceneObjects (Node3D) [scene_objects_group.gd]
│  ├─ SO_Floor (CSGBox3D)
│  ├─ SO_Block (CSGBox3D)
│  └─ ... (static scene geometry)
│
├─ Environment (Node) [environment_group.gd]
│  ├─ Env_WorldEnvironment (WorldEnvironment)
│  └─ Env_DirectionalLight3D (DirectionalLight3D)
│
├─ Systems (Node) [systems_group.gd]
│  ├─ Core (Node) [systems_core_group.gd]
│  │  ├─ S_InputSystem (priority: 0)
│  │  └─ S_PauseSystem (priority: 5)
│  │
│  ├─ Physics (Node) [systems_physics_group.gd]
│  │  ├─ S_GravitySystem (priority: 60)
│  │  └─ S_JumpSystem (priority: 75)
│  │
│  ├─ Movement (Node) [systems_movement_group.gd]
│  │  ├─ S_MovementSystem (priority: 50)
│  │  ├─ S_FloatingSystem (priority: 70)
│  │  ├─ S_RotateToInputSystem (priority: 80)
│  │  └─ S_AlignWithSurfaceSystem (priority: 90)
│  │
│  └─ Feedback (Node) [systems_feedback_group.gd]
│     ├─ S_LandingIndicatorSystem (priority: 110)
│     ├─ S_JumpParticlesSystem (priority: 120)
│     ├─ S_JumpSoundSystem (priority: 121)
│     └─ S_LandingParticlesSystem (priority: 122)
│
├─ Managers (Node) [managers_group.gd]
│  ├─ M_ECSManager
│  ├─ M_CursorManager
│  └─ M_StateStore
│
├─ Entities (Node) [entities_group.gd]
│  ├─ SP_SpawnPoints (Node3D) [spawn_points_group.gd]
│  │  ├─ sp_entrance_from_exterior (Node3D)
│  │  └─ sp_exit_from_house (Node3D)
│  ├─ E_Player (player_template.tscn instance)
│  └─ E_CameraRoot (camera_template.tscn instance)
│
└─ HUD (CanvasLayer or Control)
   └─ (UI elements)
```

---

## System Categories

Systems are organized into **four functional categories** for better visual organization and understanding:

### Core Systems
**Purpose:** Fundamental game control
**Color:** Blue (`#4890e0`)
**Marker Script:** `systems_core_group.gd`
**Icon:** `systems_core.svg`

**Systems:**
- `S_InputSystem` (priority: 0) - Input capture and processing
- `S_PauseSystem` (priority: 5) - Pause/unpause state management

### Physics Systems
**Purpose:** Physics simulation
**Color:** Purple (`#a848e0`)
**Marker Script:** `systems_physics_group.gd`
**Icon:** `systems_physics.svg`

**Systems:**
- `S_GravitySystem` (priority: 60) - Gravity application
- `S_JumpSystem` (priority: 75) - Jump mechanics

### Movement Systems
**Purpose:** Character locomotion and positioning
**Color:** Teal (`#48e0a8`)
**Marker Script:** `systems_movement_group.gd`
**Icon:** `systems_movement.svg`

**Systems:**
- `S_MovementSystem` (priority: 50) - Horizontal movement
- `S_FloatingSystem` (priority: 70) - Floating/hovering mechanics
- `S_RotateToInputSystem` (priority: 80) - Rotation to input direction
- `S_AlignWithSurfaceSystem` (priority: 90) - Surface alignment

### Feedback Systems
**Purpose:** Visual indicators, particles, audio
**Color:** Orange (`#e07848`)
**Marker Script:** `systems_feedback_group.gd`
**Icon:** `systems_feedback.svg`

**Systems:**
- `S_LandingIndicatorSystem` (priority: 110) - Landing position indicator
- `S_JumpParticlesSystem` (priority: 120) - Jump particle effects
- `S_JumpSoundSystem` (priority: 121) - Jump sound effects
- `S_LandingParticlesSystem` (priority: 122) - Landing particle effects

---

## Interactable Controllers

Interactables (doors, checkpoints, hazards, victory goals, signposts) are authored as single `E_*` nodes that extend controller scripts under `scripts/gameplay/`:

- Base stack: `base_volume_controller.gd`, `base_interactable_controller.gd`, `triggered_interactable_controller.gd`
- Concrete controllers: `e_door_trigger_controller.gd`, `e_checkpoint_zone.gd`, `e_hazard_zone.gd`, `e_victory_zone.gd`, `e_signpost.gd`

Controllers automatically resolve or create the `Area3D` volume, configure the matching `C_*` ECS component, and apply `RS_SceneTriggerSettings`. **Do not** hand-author component children or duplicate Area nodes—authoring a single controller node keeps scenes consistent.

- Volume tuning flows through `settings: RS_SceneTriggerSettings`
- Triggered controllers publish `interact_prompt_show` / `interact_prompt_hide` via `U_ECSEventBus` for HUD prompts
- Signposts publish `signpost_message` events (HUD reuses checkpoint toast UI)
- Fixture scenes (`exterior.tscn`, `interior_house.tscn`) now inline controller nodes; `gameplay_base.tscn` is the gameplay entry hub
- `settings` resources are duplicated automatically when you assign a shared `.tres`; edits stay local to the scene. Leave the inspector copy as-is—no manual “Make Unique” step required.
- Passive volumes (hazards, checkpoints, victory zones) enable spawn-inside detection by default. Keep `ignore_initial_overlap = false` so re-enabling a controller re-registers overlapping players safely.
- Doors and other INTERACT prompts keep `ignore_initial_overlap = true` to avoid immediately retriggering when the player spawns at a door.
- Use `visual_paths` to toggle meshes, lights, and particles when controllers enable/disable. Place visuals as children of the controller (`DoorVisual`, `GlowLight`, etc.) and reference them via exported paths instead of adding extra logic nodes.
- Controllers run with `process_mode = PROCESS_MODE_ALWAYS` and refuse to activate while the scene manager (or state slice) is transitioning. If an activation seems ignored, verify `M_SceneManager.is_transitioning()` is false.

---

## Marker Scripts

Marker scripts provide visual organization in the Godot editor via custom `@icon` annotations. They contain no logic—only an icon reference and documentation.

### Available Marker Scripts

| Script | Purpose | Icon | Location |
|--------|---------|------|----------|
| `main_root_node.gd` | Scene root marker | `main_root.svg` | `scripts/scene_structure/` |
| `scene_objects_group.gd` | Static geometry group | `scene_objects.svg` | `scripts/scene_structure/` |
| `environment_group.gd` | Lighting/environment group | `environment.svg` | `scripts/scene_structure/` |
| `systems_group.gd` | Systems container | `system.svg` | `scripts/scene_structure/` |
| `systems_core_group.gd` | Core systems group | `systems_core.svg` | `scripts/scene_structure/` |
| `systems_physics_group.gd` | Physics systems group | `systems_physics.svg` | `scripts/scene_structure/` |
| `systems_movement_group.gd` | Movement systems group | `systems_movement.svg` | `scripts/scene_structure/` |
| `systems_feedback_group.gd` | Feedback systems group | `systems_feedback.svg` | `scripts/scene_structure/` |
| `managers_group.gd` | Managers group | `manager.svg` | `scripts/scene_structure/` |
| `entities_group.gd` | Entities group | `entities.svg` | `scripts/scene_structure/` |
| `components_group.gd` | Components group (within entities) | `component.svg` | `scripts/scene_structure/` |

### Creating New Marker Scripts

When adding new organizational groups:

1. Create a new `.gd` file in `scripts/scene_structure/`
2. Use this template:

```gdscript
@icon("res://resources/editor_icons/your_icon.svg")
extends Node

## Marker script for [Category Name] ([brief description]).
##
## Purpose:
## - [Purpose 1]
## - [Purpose 2]
```

3. Create a corresponding SVG icon in `resources/editor_icons/`
4. Update this guide with the new marker script

---

## Node Naming Conventions

All nodes should use **descriptive names with category prefixes** for clarity:

| Category | Prefix | Example | Notes |
|----------|--------|---------|-------|
| **Entities** | `E_` | `E_Player`, `E_CameraRoot` | Entity root nodes |
| **Systems** | `S_` | `S_MovementSystem`, `S_JumpSystem` | ECS system nodes |
| **Components** | `C_` | `C_MovementComponent`, `C_JumpComponent` | ECS component nodes (within entities) |
| **Managers** | `M_` | `M_ECSManager`, `M_StateStore` | Manager singleton nodes |
| **Scene Objects** | `SO_` | `SO_Floor`, `SO_Block` | Static geometry |
| **Environment** | `Env_` | `Env_WorldEnvironment`, `Env_DirectionalLight3D` | Lighting/environment nodes |
| **UI** | `HUD` or `UI_` | `HUD`, `UI_PauseMenu` | User interface elements |
| **Scene Files** | *(none)* | `player_template.tscn`, `base_scene_template.tscn` | snake_case, descriptive |

### Special Cases

- **Category Group Nodes:** Use descriptive names without prefixes
  - `Systems`, `Managers`, `Entities`, `SceneObjects`, `Environment`, `Core`, `Physics`, `Movement`, `Feedback`
- **Spawn Points:** Use named Node3D markers under `SP_SpawnPoints` that describe the entry/exit.
  - Examples: `sp_entrance_from_exterior`, `sp_exit_from_house`
  - Do not use generic markers like `E_PlayerSpawn` or `E_CameraSpawn`.
  - Container uses `SP_` prefix to indicate non-entity grouping.

---

## Example Scenes

### Base Scene Template

**File:** `templates/base_scene_template.tscn`

This is the **reference implementation** for all gameplay scenes. It demonstrates:
- Complete system category organization
- Proper use of marker scripts
- Standard node naming
- System priority values
- Manager setup
- Entity instantiation

**When to Use:**
- Starting a new gameplay level
- Creating test scenes
- Prototyping new features

### Player Template

**File:** `templates/player_template.tscn`

Entity template showing:
- Entity root structure (`E_PlayerRoot` extending `ECSEntity`)
- Character body setup
- Component organization within `Components` group
- Component configuration with settings resources

**When to Use:**
- Creating new player variants
- Adding new controllable characters
- Understanding component wiring

### Camera Template

**File:** `templates/camera_template.tscn`

Camera entity showing:
- Camera node setup
- Entity structure for non-physical entities
- Third-person camera configuration

---

## Best Practices

### Scene Creation

1. **Start with a template:** Always copy from `base_scene_template.tscn` for new levels
2. **Use marker scripts:** Apply appropriate marker scripts to organizational nodes
3. **Follow naming conventions:** Use prefixes consistently
4. **Document deviations:** If you must deviate from the standard structure, document why

### System Organization

1. **Place systems in correct categories:**
   - Input/control → **Core**
   - Physics simulation → **Physics**
   - Character movement → **Movement**
   - Visual/audio feedback → **Feedback**

2. **Set execution priorities correctly:**
   - Input systems: 0-10
   - Movement preparation: 50-59
   - Physics simulation: 60-79
   - Movement application: 80-99
   - Visual feedback: 100-119
   - Audio/particles: 120-129

3. **Keep related systems together** within their category

### Entity Structure

1. **Always extend `ECSEntity`** for entity roots
2. **Use `Components` group** to organize components within entities
3. **Wire component NodePaths** in the scene editor
4. **Assign settings resources** to components that require them

### Maintainability

1. **Update this guide** when adding new organizational patterns
2. **Create new marker scripts** for new organizational groups
3. **Review existing scenes** periodically for consistency
4. **Document exceptions** when standard structure doesn't fit

### When to Add New Categories

Consider adding a new system category when:
- You have 4+ related systems that form a coherent group
- The systems serve a distinct phase in the game loop
- Visual separation would improve clarity
- The category is stable (not experimental)

**Process:**
1. Create new marker script in `scripts/scene_structure/`
2. Create matching icon in `resources/editor_icons/`
3. Update this guide with new category documentation
4. Update existing scenes to use new category
5. Communicate changes to team

---

## Single-Entity Controllers

Some interactable entities (doors, checkpoints, goals, hazards) are easier to author and maintain when they are a single `E_*` node with a thin controller script. The controller ensures the required ECS component exists and is configured at runtime, eliminating the need for nested component nodes or hand-authored `Area3D` children.

This pattern mirrors the existing `E_FinalGoal` and should be used going forward.

### Checkpoint (E_Checkpoint_SafeZone)

Target result: `E_Checkpoint_SafeZone` is a single node with a controller; no visible `C_*` child, no authored `Area3D`.

1) Make the component self‑sufficient
- File: `scripts/ecs/components/c_checkpoint_component.gd`
- Add exports and helpers:
  - `@export_node_path("Area3D") var area_path`
  - `@export var settings: RS_SceneTriggerSettings`
  - `func get_trigger_area() -> Area3D`
  - `func set_enabled(enabled: bool)`
- Behavior: If `area_path` is empty and no authored area is found, the component creates its own `Area3D + CollisionShape3D` from `settings` (box/cylinder, size, offset, mask).

2) Create a thin controller
- File: `scripts/gameplay/checkpoint_zone.gd` (extends `ECSEntity`)
- Exports: `checkpoint_id`, `spawn_point_id`, optional `area_path`, and `settings`.
- On `_ready()`: find or create a `C_CheckpointComponent` child and apply the exports.
- Provides `get_trigger_area()` and `set_enabled()` pass‑throughs for state‑driven gating.

3) Update the scene
- File: `scenes/gameplay/exterior.tscn`
- On `E_Checkpoint_SafeZone`:
  - Set script to `scripts/gameplay/checkpoint_zone.gd`.
  - Set `checkpoint_id`, `spawn_point_id`, and assign a `settings` resource.
  - Remove authored `C_CheckpointComponent` and `Area3D/CollisionShape3D` children.

Notes & pitfalls
- Tabs only in `.gd` files (see `DEV_PITFALLS.md`).
- In `.tres`, reference the script explicitly (don’t rely on `class_name`) to avoid “Cannot get class” errors.
- Systems (e.g., `S_CheckpointSystem`) continue to discover components normally; no system change required.

### Reusable Volume Settings

Use a small Resource to drive volume creation consistently across components.

- File: `scripts/ecs/resources/rs_scene_trigger_settings.gd`
- Example preset: `resources/triggers/rs_checkpoint_box_2x3x2.tres`
  - Script reference included in the resource file
  - Fields: `shape_type`, `box_size`/`cyl_radius`+`cyl_height`, `local_offset`, `player_mask`

### Repeatable Migration Checklist

Use this for doors, hazards, goals, and future interactables:
- Ensure the ECS component can auto‑create/resolve its `Area3D + CollisionShape3D` and exposes `get_trigger_area()`/`set_enabled()`.
- Add a thin controller script that:
  - Exports per‑instance fields and a `settings` Resource
  - Creates (or finds) the component on `_ready()` and applies exports
- In the scene: attach the controller to the `E_*` node, set exports, assign the settings resource, remove authored component/area children.
- Validate in editor logs (no parse errors), then at runtime.

## Scene Manager Integration (Future)

The upcoming Scene Manager system will:
- Use `root.tscn` as persistent container
- Load gameplay scenes into `ActiveSceneContainer` node
- Maintain per-scene `M_ECSManager` instances
- Preserve this organizational structure

**Compatibility:** The current scene structure is designed to work seamlessly with the Scene Manager. No reorganization will be required when the Scene Manager is implemented.

---

## Quick Reference

### Standard Scene Hierarchy
```
Main
├─ SceneObjects
├─ Environment
├─ Systems
│  ├─ Core
│  ├─ Physics
│  ├─ Movement
│  └─ Feedback
├─ Managers
├─ Entities
└─ HUD
```

### Node Prefix Quick Lookup
- `E_` = Entity
- `S_` = System
- `C_` = Component
- `M_` = Manager
- `SO_` = Scene Object
- `Env_` = Environment
- `HUD` / `UI_` = User Interface

### Priority Ranges
- **0-10:** Input/control
- **50-59:** Movement prep
- **60-79:** Physics
- **80-99:** Movement
- **100-119:** Visual
- **120-129:** Audio/particles

---

## Related Documentation

- **Style Guide:** `docs/general/STYLE_GUIDE.md` - Naming conventions for scripts
- **ECS Architecture:** `docs/ecs/ECS_ARCHITECTURE.md` - ECS system details
- **Dev Pitfalls:** `docs/general/DEV_PITFALLS.md` - Common issues and solutions

---

**Last Updated:** 2025-01-28
**Maintained By:** Development Team
