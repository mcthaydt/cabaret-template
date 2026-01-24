@icon("res://assets/editor_icons/resource.svg")
extends Resource
class_name RS_SceneTriggerSettings

## Scene Trigger Settings
## Defines geometry and filtering for a trigger Area3D used by C_SceneTriggerComponent.

enum ShapeType { BOX = 0, CYLINDER = 1 }

@export var shape_type: ShapeType = ShapeType.CYLINDER

# Cylinder params (Y-up)
@export var cyl_radius: float = 1.0
@export var cyl_height: float = 3.0

# Box params
@export var box_size: Vector3 = Vector3(2.0, 3.0, 0.2)

# Local offset for the CollisionShape3D relative to the door/entity
@export var local_offset: Vector3 = Vector3(0, 1.5, 0)

# Collision mask to detect player bodies (default expects player on layer 1)
@export var player_mask: int = 1

# Runtime behaviour toggles
@export var enable_on_ready: bool = true
@export var ignore_initial_overlap: bool = true
@export var toggle_visuals_on_enable: bool = true

var _arm_delay_physics_frames: int = 1

@export var arm_delay_physics_frames: int:
	get:
		return _arm_delay_physics_frames
	set(value):
		_arm_delay_physics_frames = max(0, value)
