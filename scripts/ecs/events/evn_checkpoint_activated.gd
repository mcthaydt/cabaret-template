extends BaseECSEvent
class_name Evn_CheckpointActivated

## Event published when a checkpoint is activated.
##
## Published by: S_CheckpointSystem
## Subscribers: UI_HudController (priority 0)

var checkpoint_id: StringName
var spawn_point_id: StringName

func _init(p_checkpoint_id: StringName, p_spawn_point_id: StringName) -> void:
	checkpoint_id = p_checkpoint_id
	spawn_point_id = p_spawn_point_id

	const U_ECS_UTILS := preload("res://scripts/utils/u_ecs_utils.gd")
	timestamp = U_ECS_UTILS.get_current_time()

	_payload = {
		"checkpoint_id": checkpoint_id,
		"spawn_point_id": spawn_point_id
	}
