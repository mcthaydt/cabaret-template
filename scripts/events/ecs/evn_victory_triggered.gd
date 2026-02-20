extends BaseECSEvent
class_name Evn_VictoryTriggered

## Event published when player enters victory zone.
##
## Published by: C_VictoryTriggerComponent
## Subscribers: S_GameRuleManager (for rule-driven validation flow), S_VictorySoundSystem

var entity_id: StringName
var trigger_node: Node
var body: Node3D

func _init(p_entity_id: StringName, p_trigger_node: Node, p_body: Node3D) -> void:
	entity_id = p_entity_id
	trigger_node = p_trigger_node
	body = p_body

	const U_ECS_UTILS := preload("res://scripts/utils/ecs/u_ecs_utils.gd")
	timestamp = U_ECS_UTILS.get_current_time()

	_payload = {
		"entity_id": entity_id,
		"trigger_node": trigger_node,
		"body": body
	}
