extends RefCounted
class_name U_AIContextBuilder

const RSRuleContext := preload("res://scripts/resources/ecs/rs_rule_context.gd")
const C_DETECTION_COMPONENT := preload("res://scripts/ecs/components/c_detection_component.gd")
const U_ECS_UTILS := preload("res://scripts/utils/ecs/u_ecs_utils.gd")

const BRAIN_COMPONENT_TYPE := C_AIBrainComponent.COMPONENT_TYPE
const DETECTION_COMPONENT_TYPE := C_DETECTION_COMPONENT.COMPONENT_TYPE

func build(
	entity_query: Object,
	brain: C_AIBrainComponent,
	redux_state: Dictionary,
	store: I_StateStore,
	manager: I_ECSManager
) -> Dictionary:
	var rule_context: RefCounted = RSRuleContext.new()
	rule_context.brain_component = brain
	rule_context.redux_state = redux_state

	if store != null and is_instance_valid(store):
		rule_context.state_store = store

	if entity_query == null:
		rule_context.components = {BRAIN_COMPONENT_TYPE: brain}
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
			rule_context.components = {BRAIN_COMPONENT_TYPE: brain}
	else:
		rule_context.components = {BRAIN_COMPONENT_TYPE: brain}

	return rule_context.to_dictionary()

func _inject_role_keyed_detection(components: Dictionary, entity: Node, manager: I_ECSManager) -> void:
	if manager == null:
		return
	var all_detections: Array = manager.get_components(DETECTION_COMPONENT_TYPE)
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
			components[DETECTION_COMPONENT_TYPE] = detection
			continue
		var role_key: StringName = StringName(String(DETECTION_COMPONENT_TYPE) + ":" + String(role))
		components[role_key] = detection

func context_key_for_context(context: Dictionary) -> StringName:
	var entity_id_variant: Variant = context.get(RSRuleContext.KEY_ENTITY_ID, StringName())
	if entity_id_variant is StringName:
		return entity_id_variant as StringName
	if entity_id_variant is String:
		var entity_id_text: String = entity_id_variant as String
		if entity_id_text.is_empty():
			return StringName()
		return StringName(entity_id_text)
	return StringName()