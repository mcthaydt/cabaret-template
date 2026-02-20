@icon("res://assets/editor_icons/icn_system.svg")
extends BaseQBRuleManager
class_name S_CameraRuleManager

const C_CAMERA_STATE_COMPONENT := preload("res://scripts/ecs/components/c_camera_state_component.gd")

const CAMERA_STATE_TYPE := C_CAMERA_STATE_COMPONENT.COMPONENT_TYPE
const DEFAULT_RULE_DEFINITIONS := [
	preload("res://resources/qb/camera/cfg_camera_shake_rule.tres"),
	preload("res://resources/qb/camera/cfg_camera_zone_fov_rule.tres"),
]

func get_default_rule_definitions() -> Array:
	return DEFAULT_RULE_DEFINITIONS.duplicate()

func _get_tick_contexts(_delta: float) -> Array:
	return _build_camera_contexts({})

func _on_event_received(event_name: StringName, event_data: Dictionary) -> void:
	var payload: Dictionary = {}
	if event_data.has("payload") and event_data["payload"] is Dictionary:
		payload = (event_data["payload"] as Dictionary).duplicate(true)
	elif event_data is Dictionary:
		payload = event_data.duplicate(true)

	var event_context: Dictionary = _build_event_context(event_name, payload)
	var contexts: Array = _build_camera_contexts(event_context)
	if contexts.is_empty():
		_ensure_context_dependencies(event_context)
		_evaluate_rules_for_context(event_context, QB_RULE.TriggerMode.EVENT, event_name)
		return

	_evaluate_contexts(contexts, QB_RULE.TriggerMode.EVENT, event_name)

func _build_camera_contexts(base_context: Dictionary) -> Array:
	var contexts: Array = []
	var store: I_StateStore = _resolve_store()
	var redux_state: Dictionary = {}
	if store != null:
		redux_state = store.get_state()

	var entities: Array = query_entities([CAMERA_STATE_TYPE])
	for entity_query_variant in entities:
		var entity_query: Object = entity_query_variant as Object
		if entity_query == null:
			continue
		if not entity_query.has_method("get_component"):
			continue

		var camera_state: Variant = entity_query.call("get_component", CAMERA_STATE_TYPE)
		if camera_state == null:
			continue

		var context: Dictionary = base_context.duplicate(true)
		_attach_camera_context(context, entity_query, camera_state, redux_state, store)
		contexts.append(context)

	return contexts

func _attach_camera_context(
	context: Dictionary,
	entity_query: Object,
	camera_state: Variant,
	redux_state: Dictionary,
	store: I_StateStore
) -> void:
	context["camera_state_component"] = camera_state
	var components: Dictionary = {}
	components[CAMERA_STATE_TYPE] = camera_state
	var camera_state_type_key: String = String(CAMERA_STATE_TYPE)
	if not components.has(camera_state_type_key):
		components[camera_state_type_key] = camera_state
	context["components"] = components
	context["component_data"] = components
	context["redux_state"] = redux_state.duplicate(true)
	context["state"] = context["redux_state"]
	if store != null:
		context["state_store"] = store

	if entity_query.has_method("get_entity_id"):
		var camera_entity_id: Variant = entity_query.call("get_entity_id")
		context["camera_entity_id"] = camera_entity_id
		if not context.has("entity_id"):
			context["entity_id"] = camera_entity_id
	if entity_query.has_method("get_tags"):
		var camera_tags: Variant = entity_query.call("get_tags")
		context["camera_entity_tags"] = camera_tags
		if not context.has("entity_tags"):
			context["entity_tags"] = camera_tags

	var camera_entity: Variant = entity_query.get("entity")
	if camera_entity != null:
		context["camera_entity"] = camera_entity
		if not context.has("entity"):
			context["entity"] = camera_entity

func _resolve_store() -> I_StateStore:
	if state_store != null:
		return state_store
	return U_STATE_UTILS.try_get_store(self)
