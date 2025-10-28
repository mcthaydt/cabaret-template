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
│  ├─ E_SpawnPoints (Node3D) [entities_group.gd]
│  │  ├─ E_PlayerSpawn (Node3D)
│  │  └─ E_CameraSpawn (Node3D)
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
- **Spawn Points:** Use `E_` prefix with descriptive names
  - `E_PlayerSpawn`, `E_CameraSpawn`, `E_SpawnPoints` (container)

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
- Entity root structure (`E_PlayerRoot` extending `BaseECSEntity`)
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

1. **Always extend `BaseECSEntity`** for entity roots
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
