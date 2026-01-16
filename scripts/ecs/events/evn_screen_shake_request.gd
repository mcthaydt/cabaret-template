extends BaseECSEvent
class_name Evn_ScreenShakeRequest

## Event published when a system requests screen shake.
##
## Published by: S_ScreenShakePublisherSystem
## Subscribers: M_VFXManager

var entity_id: StringName
var trauma_amount: float
var source: StringName

func _init(p_entity_id: StringName, p_trauma_amount: float, p_source: StringName) -> void:
	entity_id = p_entity_id
	trauma_amount = p_trauma_amount
	source = p_source

	const U_ECS_UTILS := preload("res://scripts/utils/u_ecs_utils.gd")
	timestamp = U_ECS_UTILS.get_current_time()

	_payload = {
		"entity_id": entity_id,
		"trauma_amount": trauma_amount,
		"source": source
	}
