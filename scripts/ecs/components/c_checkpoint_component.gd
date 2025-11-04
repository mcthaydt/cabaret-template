@icon("res://resources/editor_icons/component.svg")
extends BaseECSComponent
class_name C_CheckpointComponent

const COMPONENT_TYPE := StringName("C_CheckpointComponent")

## Checkpoint Component (Phase 12.3b - T265)
##
## Marks a location as a checkpoint where the player can respawn after death.
## Unlike spawn points linked to doors, checkpoints are independent mid-scene markers.
##
## Usage:
## 1. Add C_CheckpointComponent to a Node3D in your scene
## 2. Add an Area3D child for collision detection
## 3. Set checkpoint_id (unique ID) and spawn_point_id (where to spawn)
## 4. S_CheckpointSystem will detect player entry and update last_checkpoint
##
## Example:
##   CheckpointNode (Node3D)
##   ├─ C_CheckpointComponent (checkpoint_id="cp_safe_room", spawn_point_id="sp_safe_room")
##   └─ Area3D (for collision detection)
##
## Integration:
## - S_CheckpointSystem queries for C_CheckpointComponent
## - On player collision: updates gameplay.last_checkpoint
## - M_SpawnManager.spawn_at_last_spawn() uses last_checkpoint > target_spawn_point > sp_default

## Unique identifier for this checkpoint (for debugging/save data)
@export var checkpoint_id: StringName = StringName("")

## Spawn point ID where player should respawn when using this checkpoint
@export var spawn_point_id: StringName = StringName("")

## Whether this checkpoint has been activated by the player
@export var is_activated: bool = false

## Timestamp when checkpoint was last activated (for debugging)
@export var last_activated_time: float = 0.0

func _ready() -> void:
	super._ready()

	# Validate configuration
	if checkpoint_id.is_empty():
		push_warning("C_CheckpointComponent: checkpoint_id is empty. Set a unique ID for this checkpoint.")

	if spawn_point_id.is_empty():
		push_error("C_CheckpointComponent: spawn_point_id is required. Player won't know where to spawn!")

	# Check for Area3D child
	var area: Area3D = _find_area3d_child()
	if area == null:
		push_error("C_CheckpointComponent: No Area3D child found. Add an Area3D for collision detection.")

## Find Area3D child node (for validation)
func _find_area3d_child() -> Area3D:
	for child in get_children():
		if child is Area3D:
			return child as Area3D
	return null

## Activate this checkpoint (called by S_CheckpointSystem)
func activate() -> void:
	is_activated = true
	last_activated_time = Time.get_ticks_msec() / 1000.0
