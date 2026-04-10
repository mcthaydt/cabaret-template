extends RefCounted
class_name U_AIContextBuilder

const U_ECS_UTILS := preload("res://scripts/utils/ecs/u_ecs_utils.gd")

const BRAIN_COMPONENT_TYPE := C_AIBrainComponent.COMPONENT_TYPE

func build(
	entity_query: Object,
	brain: C_AIBrainComponent,
	redux_state: Dictionary,
	store: I_StateStore,
	manager: I_ECSManager
) -> Dictionary:
	var context: Dictionary = {
		"brain_component": brain,
		"redux_state": redux_state,
	}
	context["state"] = context["redux_state"]

	if store != null and is_instance_valid(store):
		context["state_store"] = store

	if entity_query == null:
		_set_fallback_components(context, brain)
		return context

	var entity_variant: Variant = entity_query.get("entity")
	if entity_variant is Node:
		var entity: Node = entity_variant as Node
		context["entity"] = entity
		context["entity_id"] = U_ECS_UTILS.get_entity_id(entity)

		var components: Dictionary = {}
		if manager != null:
			components = manager.get_components_for_entity_readonly(entity)
		if components.is_empty() and entity_query.has_method("get_all_components"):
			var query_components_variant: Variant = entity_query.call("get_all_components")
			if query_components_variant is Dictionary:
				components = query_components_variant as Dictionary
		if not components.is_empty():
			context["components"] = components
			context["component_data"] = components

	if not context.has("components"):
		_set_fallback_components(context, brain)

	return context

func context_key_for_context(context: Dictionary) -> StringName:
	var entity_id_variant: Variant = context.get("entity_id", StringName())
	if entity_id_variant is StringName:
		return entity_id_variant as StringName
	if entity_id_variant is String:
		var entity_id_text: String = entity_id_variant as String
		if entity_id_text.is_empty():
			return StringName()
		return StringName(entity_id_text)
	return StringName()

func _set_fallback_components(context: Dictionary, brain: C_AIBrainComponent) -> void:
	var fallback_components: Dictionary = {
		BRAIN_COMPONENT_TYPE: brain,
	}
	context["components"] = fallback_components
	context["component_data"] = fallback_components
