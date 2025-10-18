# Project Musical Parakeet - Style Guide & Naming Conventions

## Overview

This document defines the naming conventions and coding standards for the Project Musical Parakeet Godot game project. The goal is to ensure consistency, improve code readability, enable efficient autocomplete grouping, and prevent naming conflicts.

## Core Philosophy

We use a **prefix + suffix** naming convention that provides:
- **Autocomplete grouping** - Type prefix to see all items of that category
- **Instant identification** - Immediately know what type of class you're working with
- **Self-documenting code** - Names clearly describe both category and purpose
- **Conflict prevention** - Prefixes prevent naming collisions

---

## Naming Convention Rules

### Class Names: `Prefix_PascalCaseSuffix`

| Category | Prefix | Suffix | Example |
|----------|--------|--------|---------|
| **Systems** | `S_` | `System` | `S_MovementSystem` |
| **Components** | `C_` | `Component` | `C_MovementComponent` |
| **Managers** | `M_` | `Manager` | `M_ECSManager` |
| **Resources/Settings** | `RS_` | `Settings` | `RS_MovementSettings` |
| **Utilities** | `U_` | `Utils` | `U_ActionUtils` |
| **Scenes** | `SC_` | `Scene` | `SC_PlayerScene` |
| **Shaders** | `SH_` | `Shader` | `SH_WaterShader` |
| **Tools** | `T_` | `Tool` | `T_LevelEditorTool` |
| **Plugins** | `P_` | `Plugin` | `P_CustomPlugin` |
| **Base Classes** | *(none)* | descriptive | `ECSSystem`, `ECSComponent` |

### File Names: `prefix_snake_case_suffix.gd`

| Category | Pattern | Example |
|----------|---------|---------|
| **Systems** | `s_*_system.gd` | `s_movement_system.gd` |
| **Components** | `c_*_component.gd` | `c_movement_component.gd` |
| **Managers** | `m_*_manager.gd` | `m_ecs_manager.gd` |
| **Resources** | `rs_*_settings.gd` | `rs_movement_settings.gd` |
| **Utilities** | `u_*_utils.gd` | `u_action_utils.gd` |
| **Scene Scripts** | `sc_*_scene.gd` | `sc_player_scene.gd` |
| **Shaders** | `sh_*_shader.gdshader` | `sh_water_shader.gdshader` |
| **Tools** | `t_*_tool.gd` | `t_level_editor_tool.gd` |
| **Plugins** | `p_*_plugin.gd` | `p_custom_plugin.gd` |
| **Base Classes** | `snake_case.gd` | `ecs_system.gd` |
| **Test Files** | `test_*.gd` | `test_s_movement_system.gd` |

### Methods & Functions: `snake_case`

```gdscript
func process_tick(delta: float) -> void:
    pass

func get_component(type: StringName) -> ECSComponent:
    return null

func _ready() -> void:
    pass
```

### Variables & Properties: `snake_case`

```gdscript
# Public properties
var velocity: Vector3
var max_speed: float = 6.0
@export var component_type: StringName

# Private members (prefix with underscore)
var _manager: M_ECSManager
var _components: Dictionary
var _is_initialized: bool = false
```

### Constants: `UPPER_SNAKE_CASE`

```gdscript
const COMPONENT_TYPE := StringName("C_MovementComponent")
const MAX_JUMP_HEIGHT: float = 2.0
const DEFAULT_GRAVITY: float = 9.8
```

### Directories: `snake_case` (plural)

```
scripts/
├── ecs/
│   ├── components/
│   ├── systems/
│   └── resources/
├── state/
├── scenes/
├── shaders/
├── tools/
└── utils/

tests/
└── unit/
    └── ecs/
        ├── systems/
        └── components/
```

---

## Complete Examples

### System Example

**File:** `scripts/ecs/systems/s_movement_system.gd`

```gdscript
class_name S_MovementSystem
extends ECSSystem

const SYSTEM_TYPE := StringName("S_MovementSystem")
const MOVEMENT_COMPONENT := StringName("C_MovementComponent")

var _ecs_manager: M_ECSManager

func _ready() -> void:
    super._ready()
    _locate_manager()

func process_tick(delta: float) -> void:
    var components = _ecs_manager.get_components(MOVEMENT_COMPONENT)
    for component in components:
        _process_movement(component, delta)

func _process_movement(component: C_MovementComponent, delta: float) -> void:
    # Movement logic here
    pass
```

### Component Example

**File:** `scripts/ecs/components/c_movement_component.gd`

```gdscript
class_name C_MovementComponent
extends ECSComponent

const COMPONENT_TYPE := StringName("C_MovementComponent")

@export var settings: RS_MovementSettings
@export var character_body_path: NodePath

var _character_body: CharacterBody3D
var _velocity: Vector3 = Vector3.ZERO

func _ready() -> void:
    super._ready()
    _character_body = get_node(character_body_path)

func get_velocity() -> Vector3:
    return _velocity

func set_velocity(new_velocity: Vector3) -> void:
    _velocity = new_velocity
```

### Resource Example

**File:** `scripts/ecs/resources/rs_movement_settings.gd`

```gdscript
class_name RS_MovementSettings
extends Resource

@export_group("Speed")
@export var max_speed: float = 6.0
@export var sprint_multiplier: float = 1.5
@export var acceleration: float = 10.0
@export var deceleration: float = 8.0

@export_group("Air Control")
@export var air_control: float = 0.3
@export var air_acceleration: float = 5.0
```

### Manager Example

**File:** `scripts/ecs/m_ecs_manager.gd`

```gdscript
class_name M_ECSManager
extends Node

var _components: Dictionary = {}
var _systems: Array[ECSSystem] = []

func register_component(component: ECSComponent) -> void:
    var type = component.component_type
    if not _components.has(type):
        _components[type] = []
    _components[type].append(component)

func get_components(type: StringName) -> Array:
    return _components.get(type, [])
```

### Utility Example

**File:** `scripts/state/u_action_utils.gd`

```gdscript
class_name U_ActionUtils

static func create_action(type: StringName, payload: Variant = null) -> Dictionary:
    return {
        "type": type,
        "payload": payload
    }

static func is_valid_action(action: Variant) -> bool:
    return action is Dictionary and action.has("type")
```

### Scene Script Example

**File:** `scripts/scenes/sc_player_scene.gd`

```gdscript
class_name SC_PlayerScene
extends Node3D

@export var movement_component: C_MovementComponent
@export var input_component: C_InputComponent

func _ready() -> void:
    _setup_components()

func _setup_components() -> void:
    # Scene-specific setup logic
    pass
```

### Shader Example

**File:** `shaders/sh_water_shader.gdshader`

```glsl
shader_type spatial;

uniform vec4 water_color: source_color = vec4(0.1, 0.3, 0.5, 0.8);
uniform float wave_speed: hint_range(0.0, 2.0) = 1.0;

void fragment() {
    ALBEDO = water_color.rgb;
    ALPHA = water_color.a;
}
```

### Tool Script Example

**File:** `scripts/tools/t_level_editor_tool.gd`

```gdscript
@tool
class_name T_LevelEditorTool
extends EditorPlugin

func _enter_tree() -> void:
    # Initialize tool
    pass

func _exit_tree() -> void:
    # Clean up tool
    pass
```

---

## Prefix Legend

| Prefix | Meaning | Purpose | Examples |
|--------|---------|---------|----------|
| `S_` | **System** | ECS systems that process entities each frame | `S_MovementSystem`, `S_GravitySystem` |
| `C_` | **Component** | ECS components that hold entity data | `C_MovementComponent`, `C_JumpComponent` |
| `M_` | **Manager** | Singleton/autoload managers that orchestrate systems | `M_ECSManager`, `M_StateManager` |
| `RS_` | **Resource/Settings** | Godot Resource classes for configuration | `RS_MovementSettings`, `RS_JumpSettings` |
| `U_` | **Utility** | Static helper classes with utility functions | `U_ActionUtils`, `U_ReducerUtils` |
| `SC_` | **Scene** | Scene-specific scripts attached to scene roots | `SC_PlayerScene`, `SC_MainMenuScene` |
| `SH_` | **Shader** | Custom shader scripts | `SH_WaterShader`, `SH_ToonShader` |
| `T_` | **Tool** | Editor tool scripts (@tool annotation) | `T_LevelEditorTool`, `T_AssetImporter` |
| `P_` | **Plugin** | Editor plugin scripts | `P_CustomPlugin`, `P_WorkflowPlugin` |

---

## Special Cases & Exceptions

### Base Classes (No Prefix)
Abstract or base classes that define interfaces should NOT have prefixes:
- `ECSSystem` - Base class for all systems
- `ECSComponent` - Base class for all components
- `Resource` - Godot built-in

### Godot Built-ins (No Prefix)
Never prefix Godot's built-in classes:
- `Node`, `Node3D`, `CharacterBody3D`
- `Resource`, `RefCounted`
- `Vector3`, `Transform3D`

### Third-Party Code (No Changes)
**IMPORTANT:** Do NOT rename or refactor code in the `addons/` folder:
- Third-party plugins and assets maintain their original naming
- Only apply our conventions to code we create
- When referencing addon code, use their naming conventions

### Test Files
Test files use `test_` prefix followed by the class being tested:
- `test_s_movement_system.gd`
- `test_c_movement_component.gd`
- `test_m_ecs_manager.gd`

### Scene Files (.tscn)
Scene files use descriptive snake_case names without prefixes:
- `player_character.tscn`
- `main_scene.tscn`
- `debug_hud.tscn`

Note: If a scene has a dedicated script, the script uses `SC_` prefix, but the scene file itself does not.

---

## Refactoring Plan

### Overview
This plan covers the complete refactoring of existing code to match the new naming conventions.

**Scope:** `scripts/`, `tests/` directories only
**Excluded:** `addons/` folder (third-party code)
**Estimated Impact:** ~40-50 files
**Risk Level:** Medium (extensive renaming, but tests will catch issues)

### Phase 1: Documentation
- [x] Create `STYLE_GUIDE.md` (this document)

### Phase 2: Rename Systems (8 files)
- [ ] `movement_system.gd` → `s_movement_system.gd`
  - Update class name to `S_MovementSystem`
  - Update SYSTEM_TYPE constant
  - Update COMPONENT_TYPE references (e.g., `C_MovementComponent`)
- [ ] `gravity_system.gd` → `s_gravity_system.gd`
  - Update class name to `S_GravitySystem`
- [ ] `jump_system.gd` → `s_jump_system.gd`
  - Update class name to `S_JumpSystem`
- [ ] `floating_system.gd` → `s_floating_system.gd`
  - Update class name to `S_FloatingSystem`
- [ ] `rotate_to_input_system.gd` → `s_rotate_to_input_system.gd`
  - Update class name to `S_RotateToS_InputSystem`
- [ ] `align_with_surface_system.gd` → `s_align_with_surface_system.gd`
  - Update class name to `S_AlignWithSurfaceSystem`
- [ ] `landing_indicator_system.gd` → `s_landing_indicator_system.gd`
  - Update class name to `S_LandingIndicatorSystem`
- [ ] `input_system.gd` → `s_input_system.gd`
  - Update class name to `S_InputSystem`

### Phase 3: Rename Components (7 files)
- [ ] `movement_component.gd` → `c_movement_component.gd`
  - Update class name to `C_MovementComponent`
  - Update COMPONENT_TYPE constant
- [ ] `input_component.gd` → `c_input_component.gd`
  - Update class name to `C_InputComponent`
- [ ] `jump_component.gd` → `c_jump_component.gd`
  - Update class name to `C_JumpComponent`
- [ ] `floating_component.gd` → `c_floating_component.gd`
  - Update class name to `C_FloatingComponent`
- [ ] `rotate_to_input_component.gd` → `c_rotate_to_input_component.gd`
  - Update class name to `C_RotateToC_InputComponent`
- [ ] `align_with_surface_component.gd` → `c_align_with_surface_component.gd`
  - Update class name to `C_AlignWithSurfaceComponent`
- [ ] `landing_indicator_component.gd` → `c_landing_indicator_component.gd`
  - Update class name to `C_LandingIndicatorComponent`

### Phase 4: Rename Resources/Settings (6 files)
- [ ] `movement_settings.gd` → `rs_movement_settings.gd`
  - Update class name to `RS_MovementSettings`
- [ ] `jump_settings.gd` → `rs_jump_settings.gd`
  - Update class name to `RS_JumpSettings`
- [ ] `floating_settings.gd` → `rs_floating_settings.gd`
  - Update class name to `RS_FloatingSettings`
- [ ] `rotate_to_input_settings.gd` → `rs_rotate_to_input_settings.gd`
  - Update class name to `RS_RotateToInputSettings`
- [ ] `align_settings.gd` → `rs_align_settings.gd`
  - Update class name to `RS_AlignSettings`
- [ ] `landing_indicator_settings.gd` → `rs_landing_indicator_settings.gd`
  - Update class name to `RS_LandingIndicatorSettings`

### Phase 5: Rename Manager (1 file)
- [ ] `ecs_manager.gd` → `m_ecs_manager.gd`
  - Update class name to `M_ECSManager`
  - Update all references in systems and components

### Phase 6: Rename State Utilities (5 files)
- [ ] `store.gd` → `m_state_manager.gd`
  - Update class name to `M_StateManager`
- [ ] `action_utils.gd` → `u_action_utils.gd`
  - Update class name to `U_ActionUtils`
- [ ] `reducer_utils.gd` → `u_reducer_utils.gd`
  - Update class name to `U_ReducerUtils`
- [ ] `store_utils.gd` → `u_store_utils.gd`
  - Update class name to `U_StoreUtils`
- [ ] `selector.gd` → `u_selector_utils.gd`
  - Update class name to `U_SelectorUtils`

### Phase 7: Update References in Code
- [ ] Update all `@export` NodePath references
- [ ] Update all type checking (e.g., `component is C_MovementComponent` → `component is C_MovementComponent`)
- [ ] Update all StringName constants for component/system types
- [ ] Update scene files (.tscn) if they reference scripts
- [ ] Search for hardcoded string references
- [ ] Update any preload() statements

### Phase 8: Rename & Update Tests (6 files)
- [ ] `test_movement_system.gd` → `test_s_movement_system.gd`
- [ ] `test_gravity_system.gd` → `test_s_gravity_system.gd`
- [ ] `test_jump_system.gd` → `test_s_jump_system.gd`
- [ ] `test_floating_system.gd` → `test_s_floating_system.gd`
- [ ] `test_rotate_system.gd` → `test_s_rotate_to_input_system.gd`
- [ ] `test_landing_indicator_system.gd` → `test_s_landing_indicator_system.gd`
- [ ] Update all class instantiation in tests
- [ ] Update all assertions and type checks

### Phase 9: Update Documentation
- [ ] Update `AGENTS.md` with new naming conventions
- [ ] Update any inline documentation
- [ ] Update README if it exists
- [ ] Add examples to docs showing new naming

### Phase 10: Validation & Testing
- [ ] Run all unit tests
- [ ] Check for compilation errors in Godot
- [ ] Search codebase for old class names (regex search)
- [ ] Verify scene files load correctly
- [ ] Test in-game functionality

---

## Benefits Summary

### For Development
- **Autocomplete Efficiency**: Type `S_` to see all systems, `C_` for components
- **Quick Scanning**: Instantly identify what type of class you're looking at
- **No Name Conflicts**: `S_Movement` and `C_Movement` can coexist peacefully
- **Team Consistency**: Clear rules prevent style debates

### For Maintenance
- **Self-Documenting**: Code is more readable without extensive comments
- **Easier Refactoring**: Find all systems/components/etc. easily with prefix search
- **Onboarding**: New developers understand structure immediately
- **Debugging**: Stack traces clearly show system vs component calls

### For Collaboration
- **Code Reviews**: Easier to spot incorrect usage
- **Merge Conflicts**: Less likely due to clear organization
- **Feature Work**: Easy to find related code by prefix
- **Testing**: Clear separation makes unit testing obvious

---

## Enforcement

### Code Review Checklist
- [ ] All new classes follow prefix+suffix convention
- [ ] File names match class names (snake_case conversion)
- [ ] No prefixes on base classes or Godot built-ins
- [ ] No changes to `addons/` folder
- [ ] Test files properly named with `test_` prefix
- [ ] Constants use UPPER_SNAKE_CASE
- [ ] Private members prefixed with `_`

### IDE Setup Recommendations
1. Configure Godot script templates with proper prefixes
2. Use code snippets for common patterns
3. Enable warnings for naming convention violations (if available)
4. Set up file templates for new systems/components

### Automated Checks
Consider adding pre-commit hooks or CI checks for:
- Class name matches file name (with proper case conversion)
- Proper prefix usage
- No modifications to addons/
- Test files have test_ prefix

---

## Migration Strategy

### Step-by-Step Approach
1. **Branch Creation**: Create dedicated `naming-convention-refactor` branch
2. **Documentation First**: Ensure this guide is approved by all team members
3. **Phase Execution**: Complete one phase at a time
4. **Testing**: Run full test suite after each phase
5. **Code Review**: Have at least one other developer review changes
6. **Merge**: Only merge when all tests pass and no errors in Godot editor

### Rollback Plan
- Keep original branch until new naming is confirmed stable
- Tag the commit before refactoring begins
- Document any issues encountered during migration

### Communication
- Notify team before starting refactor
- Share progress updates after each phase
- Document any unexpected issues or decisions made

---

## Common Patterns & Best Practices

### Naming Component Type Constants
Always use StringName with the full prefixed class name:
```gdscript
# Good
const COMPONENT_TYPE := StringName("C_MovementComponent")

# Bad
const COMPONENT_TYPE := StringName("C_MovementComponent")
const COMPONENT_TYPE := "C_MovementComponent"  # Not a StringName
```

### Referencing Other Classes
Use the full prefixed class name:
```gdscript
# Good
var movement_component: C_MovementComponent
var ecs_manager: M_ECSManager

# Bad
var movement_component: C_MovementComponent
```

### Exporting Properties
Export properties don't need prefixes in the variable name:
```gdscript
# Good
@export var settings: RS_MovementSettings
@export var manager: M_ECSManager

# Bad (redundant)
@export var movement_settings: RS_MovementSettings
@export var ecs_manager: M_ECSManager
```

### Private Members
Private members use underscore prefix, not class prefix:
```gdscript
# Good
var _manager: M_ECSManager
var _velocity: Vector3

# Bad
var _m_manager: M_ECSManager  # Double prefix is redundant
```

---

## Questions & Answers

### Q: Do I prefix variables that hold prefixed classes?
**A:** No, only the class itself has the prefix. Variable names remain descriptive snake_case.
```gdscript
# Good
var movement: C_MovementComponent

# Redundant
var c_movement: C_MovementComponent
```

### Q: What about auto-loaded singletons?
**A:** Autoload singleton names in Project Settings should match the class name:
- Class: `M_ECSManager`
- Autoload name: `M_ECSManager` or `M_ECSManager` (your choice)

### Q: Should test class names have prefixes?
**A:** No, test classes follow the pattern `TestS_MovementSystem` or similar. The file has `test_` prefix.

### Q: What if a class doesn't fit any category?
**A:** Discuss with the team. Most classes should fit into one of the existing categories. If truly needed, propose a new prefix.

### Q: Can I abbreviate long names?
**A:** Prefer clarity over brevity. `S_RotateToS_InputSystem` is better than `S_R2ISystem`.

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-10-18 | Initial style guide created with prefix+suffix conventions |

---

## Appendix: Quick Reference Card

```
CLASS PREFIXES:
  S_  = System         (ECS systems)
  C_  = Component      (ECS components)
  M_  = Manager        (Singletons/managers)
  RS_ = Resource/Settings
  U_  = Utils          (Static helpers)
  SC_ = Scene          (Scene scripts)
  SH_ = Shader         (Custom shaders)
  T_  = Tool           (@tool scripts)
  P_  = Plugin         (Editor plugins)

FILE PREFIXES:
  s_  = system
  c_  = component
  m_  = manager
  rs_ = resource/settings
  u_  = utils
  sc_ = scene
  sh_ = shader
  t_  = tool
  p_  = plugin
  test_ = test files

CASING:
  Classes:   PascalCase with Prefix_Suffix
  Files:     snake_case with prefix_suffix.gd
  Methods:   snake_case
  Variables: snake_case
  Private:   _snake_case
  Constants: UPPER_SNAKE_CASE

EXCLUSIONS:
  ✓ Apply to scripts/, tests/
  ✗ Do NOT apply to addons/
  ✗ Do NOT prefix Godot built-ins
  ✗ Do NOT prefix base classes
```

---

**Last Updated:** 2025-10-18
**Version:** 1.0
**Status:** Active - Ready for Implementation
