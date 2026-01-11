extends BaseECSEvent
class_name Evn_DamageFlashRequest

## Event requesting damage flash VFX effect.
##
## Published by: VFX publisher systems (S_DamageFlashPublisherSystem)
## Subscribers: M_VFXManager

var entity_id: StringName
var intensity: float
var source: StringName

func _init(p_entity_id: StringName, p_intensity: float = 1.0, p_source: StringName = StringName("")) -> void:
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
