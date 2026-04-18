extends RefCounted
class_name U_AIContextAssembler

const C_DETECTION_COMPONENT := preload("res://scripts/ecs/components/c_detection_component.gd")
const C_AI_BRAIN_COMPONENT := preload("res://scripts/ecs/components/c_ai_brain_component.gd")
const RS_RULE_CONTEXT := preload("res://scripts/resources/ecs/rs_rule_context.gd")
const U_ECS_UTILS := preload("res://scripts/utils/ecs/u_ecs_utils.gd")

func build_context(
	entity_query: Object,
	brain: C_AIBrainComponent,
	redux_state: Dictionary,
	store: I_StateStore,
	manager: I_ECSManager
) -> Dictionary:
	var brain_type := C_AI_BRAIN_COMPONENT.COMPONENT_TYPE
	var rule_context: RSRuleContext = RS_RULE_CONTEXT.new()
	rule_context.brain_component = brain
	rule_context.redux_state = redux_state
	if store != null and is_instance_valid(store):
		rule_context.state_store = store
	if entity_query == null:
		rule_context.components = {brain_type: brain}
		return rule_context.to_dictionary()

	var entity_variant: Variant = entity_query.get("entity")
	if entity_variant is Node:
		var entity: Node = entity_variant as Node
		rule_context.entity = entity
		rule_context.entity_id = U_ECS_UTILS.get_entity_id(entity)

		var components: Dictionary = {}
		if manager != null:
			components = manager.get_components_for_entity_readonly(entity)
		if components.is_empty() and entity_query.has_method("get_all_components"):
			var query_components_variant: Variant = entity_query.call("get_all_components")
			if query_components_variant is Dictionary:
				components = query_components_variant as Dictionary
		if not components.is_empty():
			_inject_role_keyed_detection(components, entity, manager)
			rule_context.components = components
		else:
			rule_context.components = {brain_type: brain}
	else:
		rule_context.components = {brain_type: brain}

	return rule_context.to_dictionary()

func _inject_role_keyed_detection(components: Dictionary, entity: Node, manager: I_ECSManager) -> void:
	var detect_type := C_DETECTION_COMPONENT.COMPONENT_TYPE
	if manager == null:
		return
	var all_detections: Array = manager.get_components(detect_type)
	if all_detections.size() <= 1:
		return
	for detection_variant in all_detections:
		if detection_variant == null or not (detection_variant is C_DetectionComponent):
			continue
		var detection: C_DetectionComponent = detection_variant as C_DetectionComponent
		if not is_instance_valid(detection):
			continue
		var detection_root: Node = U_ECS_UTILS.find_entity_root(detection)
		if detection_root != entity:
			continue
		var role: StringName = detection.detection_role
		if role == StringName("") or role == StringName("primary"):
			components[detect_type] = detection
			continue
		var role_key: StringName = StringName(String(detect_type) + ":" + String(role))
		components[role_key] = detection

func resolve_root_id(root: RS_BTNode, fallback_prefix: String) -> StringName:
	if root == null:
		return StringName()
	var resource_name_str: String = root.resource_name.strip_edges()
	if not resource_name_str.is_empty():
		return StringName(resource_name_str)
	return StringName("%s%d" % [fallback_prefix, root.node_id])
