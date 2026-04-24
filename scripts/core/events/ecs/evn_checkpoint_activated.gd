extends BaseECSEvent
class_name Evn_CheckpointActivated

## Event published when a checkpoint is activated.
##
## Published by: S_CheckpointHandlerSystem
## Subscribers: UI_HudController (priority 0), S_CheckpointSoundSystem

var checkpoint_id: StringName
var spawn_point_id: StringName
var position: Vector3

func _init(p_checkpoint_id: StringName, p_spawn_point_id: StringName, p_position: Vector3 = Vector3.ZERO) -> void:
	checkpoint_id = p_checkpoint_id
	spawn_point_id = p_spawn_point_id
	position = p_position

	const U_ECS_UTILS := preload("res://scripts/utils/ecs/u_ecs_utils.gd")
	timestamp = U_ECS_UTILS.get_current_time()

	_payload = {
		"checkpoint_id": checkpoint_id,
		"spawn_point_id": spawn_point_id,
		"position": position
	}
