extends BaseECSEvent
class_name Evn_HealthChanged

## Event published when an entity's health changes (damage or heal).
##
## Published by: C_HealthComponent
## Subscribers: None (state-driven)

var entity_id: StringName
var previous_health: float
var new_health: float
var is_dead: bool

func _init(p_entity_id: StringName, p_previous: float, p_new: float, p_is_dead: bool) -> void:
	entity_id = p_entity_id
	previous_health = p_previous
	new_health = p_new
	is_dead = p_is_dead

	const U_ECS_UTILS := preload("res://scripts/utils/ecs/u_ecs_utils.gd")
	timestamp = U_ECS_UTILS.get_current_time()

	_payload = {
		"entity_id": entity_id,
		"previous_health": previous_health,
		"new_health": new_health,
		"is_dead": is_dead
	}
