extends BaseECSEvent
class_name Evn_DamageFlashRequest

## Event published when a system requests damage flash.
##
## Published by: S_DamageFlashPublisherSystem
## Subscribers: M_VFXManager

var entity_id: StringName
var intensity: float
var source: StringName

func _init(p_entity_id: StringName, p_intensity: float, p_source: StringName) -> void:
	entity_id = p_entity_id
	intensity = p_intensity
	source = p_source

	const U_ECS_UTILS := preload("res://scripts/utils/u_ecs_utils.gd")
	timestamp = U_ECS_UTILS.get_current_time()

	_payload = {
		"entity_id": entity_id,
		"intensity": intensity,
		"source": source
	}
