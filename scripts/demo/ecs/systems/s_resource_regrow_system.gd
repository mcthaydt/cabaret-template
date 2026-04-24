@icon("res://assets/editor_icons/icn_system.svg")
extends BaseECSSystem
class_name S_ResourceRegrowSystem

const C_RESOURCE_NODE_COMPONENT := preload("res://scripts/demo/ecs/components/c_resource_node_component.gd")

func _init() -> void:
	execution_priority = -5

func get_phase() -> SystemPhase:
	return SystemPhase.POST_PHYSICS

func process_tick(delta: float) -> void:
	var manager := get_manager()
	if manager == null:
		return
	var components: Array = get_components(C_RESOURCE_NODE_COMPONENT.COMPONENT_TYPE)
	if components.is_empty():
		return
	for component_variant in components:
		if component_variant == null or not is_instance_valid(component_variant as Object):
			continue
		var resource_node: C_ResourceNodeComponent = component_variant as C_ResourceNodeComponent
		if resource_node == null:
			continue
		if resource_node.settings == null:
			continue
		var regrow_seconds: float = maxf(resource_node.settings.regrow_seconds, 0.0)
		if regrow_seconds <= 0.0:
			continue
		if resource_node.current_amount > 0:
			resource_node.regrow_timer = 0.0
			continue
		resource_node.regrow_timer += maxf(delta, 0.0)
		if resource_node.regrow_timer >= regrow_seconds:
			resource_node.current_amount = resource_node.settings.initial_amount
			resource_node.regrow_timer = 0.0
			resource_node.clear_reservation()
