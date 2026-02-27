extends Node
class_name I_SpawnManager

## Interface for M_SpawnManager
##
## Implementations:
## - M_SpawnManager (production)

func spawn_player_at_point(_scene: Node, _spawn_point_id: StringName) -> bool:
	push_error("I_SpawnManager.spawn_player_at_point not implemented")
	return false

func initialize_scene_camera(_scene: Node) -> Camera3D:
	push_error("I_SpawnManager.initialize_scene_camera not implemented")
	return null

func spawn_at_last_spawn(_scene: Node) -> bool:
	push_error("I_SpawnManager.spawn_at_last_spawn not implemented")
	return false
