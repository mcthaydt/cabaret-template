# Scene Trigger Settings Guide

## Overview

`RS_SceneTriggerSettings` is a resource class that defines the geometry and collision settings for scene trigger areas used by `C_SceneTriggerComponent`. This allows for flexible, reusable trigger configurations across different doors and area transitions.

## Purpose

- **Shape-Agnostic**: Supports both cylindrical and box-shaped triggers
- **Reusable**: Create trigger settings once, use across multiple scenes
- **Customizable**: Fine-tune trigger size, shape, and offset for different use cases
- **Optional**: Component provides sensible defaults if no settings are assigned

## Default Settings

The component uses these defaults if no explicit settings are provided:

```gdscript
shape_type = CYLINDER
cyl_radius = 1.0
cyl_height = 3.0
local_offset = Vector3(0, 1.5, 0)
player_mask = 1
```

These defaults work well for standard person-sized doors and triggers.

## Usage Patterns

### Pattern 1: Use Default Settings (Recommended for Standard Doors)

Simply add a `C_SceneTriggerComponent` without assigning settings:

```gdscript
# No settings property = uses component defaults
[node name="C_SceneTriggerComponent" type="Node" parent="Entities/E_DoorTrigger"]
script = ExtResource("trigger_component")
door_id = &"door_main"
target_scene_id = &"interior"
target_spawn_point = &"sp_entrance"
```

### Pattern 2: Reference Default Resource (Explicit)

Assign the default resource to make settings explicit and editable:

```gdscript
# Uses default resource (can be edited to affect all references)
[node name="C_SceneTriggerComponent" type="Node" parent="Entities/E_DoorTrigger"]
script = ExtResource("trigger_component")
door_id = &"door_main"
target_scene_id = &"interior"
target_spawn_point = &"sp_entrance"
settings = ExtResource("res://resources/triggers/rs_scene_trigger_settings.tres")
```

**When to use:**
- You want explicit documentation of trigger settings in the scene
- You might adjust the default resource later
- You want consistency across all standard triggers

### Pattern 3: Custom Settings Resource

Create a custom settings resource for special cases:

```gdscript
# Create: resources/triggers/rs_cylinder_wide_door_trigger_settings.tres
[resource]
shape_type = 1  # CYLINDER
cyl_radius = 1.0
cyl_height = 3.0
local_offset = Vector3(0, 1.5, 0)
player_mask = 1

# Reference in scene
[node name="C_SceneTriggerComponent" type="Node" parent="Entities/E_WideDoor"]
script = ExtResource("trigger_component")
door_id = &"door_wide"
target_scene_id = &"hall"
target_spawn_point = &"sp_entrance"
settings = ExtResource("res://resources/triggers/rs_cylinder_wide_door_trigger_settings.tres")
```

**When to use:**
- Wide doorways or portals that need a cylindrical detection volume
- Unusually tall/short triggers
- Custom collision masks (multiple player layers)
- Specific offset requirements

## Settings Properties

### Shape Type

```gdscript
enum ShapeType { BOX = 0, CYLINDER = 1 }
@export var shape_type: ShapeType = ShapeType.CYLINDER
```

- **CYLINDER**: Best for round doors, portals, cylindrical triggers
- **BOX**: Best for rectangular doorways, gates, wall passages

### Cylinder Parameters (when shape_type = CYLINDER)

```gdscript
@export var cyl_radius: float = 1.0  # Horizontal radius in meters
@export var cyl_height: float = 3.0  # Vertical height in meters
```

**Typical values:**
- Standard door: radius=1.0, height=3.0
- Wide portal: radius=2.0, height=3.5
- Small hatch: radius=0.5, height=2.0

### Box Parameters (when shape_type = BOX)

```gdscript
@export var box_size: Vector3 = Vector3(2.0, 3.0, 0.2)
```

**Typical values:**
- Standard door: Vector3(2, 3, 0.2) - 2m wide, 3m tall, 0.2m deep
- Wide gate: Vector3(4, 4, 0.5) - 4m wide, 4m tall, 0.5m deep
- Narrow passage: Vector3(1, 3, 0.3) - 1m wide, 3m tall, 0.3m deep

### Local Offset

```gdscript
@export var local_offset: Vector3 = Vector3(0, 1.5, 0)
```

Positions the trigger shape relative to the parent Node3D.
- Default `Vector3(0, 1.5, 0)` centers trigger at 1.5m height (waist-level)
- Adjust Y value to raise/lower trigger vertically
- Adjust X/Z to move trigger horizontally

### Player Mask

```gdscript
@export var player_mask: int = 1
```

Collision layer bitmask to detect player bodies.
- Default `1` assumes player is on layer 1
- Use `3` to detect layers 1 and 2 (binary: 0b11)
- Use `5` to detect layers 1 and 3 (binary: 0b101)

## Examples

### Example 1: Standard Door (Default Settings)

```gdscript
# exterior.tscn
[node name="E_DoorTrigger" type="Node3D" parent="Entities"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 5, 0, 0)

[node name="C_SceneTriggerComponent" type="Node" parent="Entities/E_DoorTrigger"]
script = ExtResource("trigger_component")
door_id = &"door_to_house"
target_scene_id = &"interior_house"
target_spawn_point = &"sp_entrance_from_exterior"
# No settings = uses defaults (Cylinder, r=1.0, h=3.0)
```

### Example 2: Wide Gate (Custom Box Settings)

```gdscript
# Create: resources/triggers/rs_trigger_wide_gate.tres
[resource]
script = ExtResource("rs_scene_trigger_settings")
shape_type = 0  # BOX
box_size = Vector3(5, 4, 0.3)
local_offset = Vector3(0, 2, 0)
player_mask = 1

# fortress_gate.tscn
[node name="E_GateTrigger" type="Node3D" parent="Entities"]

[node name="C_SceneTriggerComponent" type="Node" parent="Entities/E_GateTrigger"]
script = ExtResource("trigger_component")
door_id = &"gate_fortress"
target_scene_id = &"fortress_interior"
target_spawn_point = &"sp_gate_entrance"
settings = ExtResource("res://resources/triggers/rs_trigger_wide_gate.tres")
```

### Example 3: Small Hatch (Custom Cylinder Settings)

```gdscript
# Create: resources/triggers/rs_trigger_hatch.tres
[resource]
script = ExtResource("rs_scene_trigger_settings")
shape_type = 1  # CYLINDER
cyl_radius = 0.6
cyl_height = 2.5
local_offset = Vector3(0, 1.25, 0)
player_mask = 1

# basement_hatch.tscn
[node name="E_HatchTrigger" type="Node3D" parent="Entities"]

[node name="C_SceneTriggerComponent" type="Node" parent="Entities/E_HatchTrigger"]
script = ExtResource("trigger_component")
door_id = &"hatch_basement"
target_scene_id = &"basement"
target_spawn_point = &"sp_hatch_bottom"
settings = ExtResource("res://resources/triggers/rs_trigger_hatch.tres")
```

## Best Practices

1. **Use Defaults First**: Only create custom settings when defaults don't work
2. **Reuse Resources**: Create one resource per trigger "type" and reference it
3. **Name Descriptively**: `rs_cylinder_wide_door_trigger_settings.tres` is better than `trigger_1.tres`
4. **Match Visual Size**: Trigger shape should roughly match the door/portal visual
5. **Test Trigger Size**: Walk through triggers to verify detection area feels natural

## Resources Location

Standard location for trigger settings:

```
resources/
├── rs_scene_trigger_settings.tres          # Default settings (in resources/triggers/)
└── triggers/                               # Custom settings
    ├── rs_cylinder_wide_door_trigger_settings.tres
    ├── rs_trigger_wide_gate.tres
    └── rs_trigger_hatch.tres
```

## Related Components

- **C_SceneTriggerComponent** (`scripts/ecs/components/c_scene_trigger_component.gd`)
- **S_SceneTriggerSystem** (`scripts/ecs/systems/s_scene_trigger_system.gd`)
- **RS_SceneTriggerSettings** (`scripts/ecs/resources/rs_scene_trigger_settings.gd`)

## See Also

- [Scene Manager PRD](scene-manager-prd.md) - Overall architecture
- [Scene Manager Tasks](scene-manager-tasks.md) - Phase 6 implementation
- [Area Transitions](test_area_transitions.gd) - Integration tests
