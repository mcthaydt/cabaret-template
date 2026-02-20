extends RefCounted
class_name U_QBQualityProvider

const QB_CONDITION := preload("res://scripts/resources/qb/rs_qb_condition.gd")
const U_QB_VARIANT_UTILS := preload("res://scripts/utils/qb/u_qb_variant_utils.gd")

static func read_quality(condition: Variant, context: Dictionary) -> Variant:
	if condition == null:
		return null
	if not (condition is Object):
		return null

	var source: int = U_QB_VARIANT_UTILS.get_int_property(condition, "source", QB_CONDITION.Source.CUSTOM)
	var quality_path: String = U_QB_VARIANT_UTILS.get_string_property(condition, "quality_path", "")

	match source:
		QB_CONDITION.Source.COMPONENT:
			return _read_component_quality(context, quality_path)
		QB_CONDITION.Source.REDUX:
			return _read_redux_quality(context, quality_path)
		QB_CONDITION.Source.EVENT_PAYLOAD:
			return _read_event_payload_quality(context, quality_path)
		QB_CONDITION.Source.ENTITY_TAG:
			return _read_entity_tag_quality(context, quality_path)
		QB_CONDITION.Source.CUSTOM:
			return _resolve_path(context, quality_path)
		_:
			return null

static func _read_component_quality(context: Dictionary, quality_path: String) -> Variant:
	if quality_path.is_empty():
		return null

	var segments: PackedStringArray = quality_path.split(".")
	if segments.is_empty():
		return null

	var component_key: String = segments[0]
	var component_map: Dictionary = U_QB_VARIANT_UTILS.get_dict(context, "components")
	if component_map.is_empty():
		component_map = U_QB_VARIANT_UTILS.get_dict(context, "component_data")
	if component_map.is_empty():
		return null

	var component_value: Variant = U_QB_VARIANT_UTILS.dict_get_string_or_name(component_map, component_key)
	if component_value == null:
		return null
	if segments.size() == 1:
		return component_value

	var remaining_path: String = ".".join(segments.slice(1))
	return _resolve_path_from_container(component_value, remaining_path)

static func _read_redux_quality(context: Dictionary, quality_path: String) -> Variant:
	var state: Dictionary = U_QB_VARIANT_UTILS.get_dict(context, "redux_state")
	if state.is_empty():
		state = U_QB_VARIANT_UTILS.get_dict(context, "state")
	if state.is_empty():
		return null

	if quality_path.is_empty():
		return state
	return _resolve_path_from_container(state, quality_path)

static func _read_event_payload_quality(context: Dictionary, quality_path: String) -> Variant:
	var event_payload: Dictionary = U_QB_VARIANT_UTILS.get_dict(context, "event_payload")
	if event_payload.is_empty():
		var event_envelope: Dictionary = U_QB_VARIANT_UTILS.get_dict(context, "event")
		var payload_variant: Variant = event_envelope.get("payload", null)
		if payload_variant is Dictionary:
			event_payload = payload_variant as Dictionary
	if event_payload.is_empty():
		return null

	if quality_path.is_empty():
		return event_payload
	return _resolve_path_from_container(event_payload, quality_path)

static func _read_entity_tag_quality(context: Dictionary, quality_path: String) -> Variant:
	var tags_variant: Variant = context.get("entity_tags", null)
	if tags_variant == null:
		tags_variant = context.get("tags", null)
	if not (tags_variant is Array):
		return null

	var tags: Array = tags_variant
	if quality_path.is_empty():
		return tags

	var tag_name: StringName = StringName(quality_path)
	for tag_variant in tags:
		if tag_variant == tag_name:
			return true
		var tag_text: String = String(tag_variant)
		if tag_text == quality_path:
			return true

	return false

static func _resolve_path(context: Dictionary, quality_path: String) -> Variant:
	if quality_path.is_empty():
		return null
	return _resolve_path_from_container(context, quality_path)

static func _resolve_path_from_container(container: Variant, quality_path: String) -> Variant:
	if quality_path.is_empty():
		return container

	var segments: PackedStringArray = quality_path.split(".")
	if segments.is_empty():
		return null

	var current: Variant = container
	for segment in segments:
		current = _resolve_next(current, segment)
		if current == null:
			return null
	return current

static func _resolve_next(current: Variant, segment: String) -> Variant:
	if current is Dictionary:
		var dictionary: Dictionary = current as Dictionary
		if dictionary.has(segment):
			return dictionary.get(segment)
		var segment_name: StringName = StringName(segment)
		if dictionary.has(segment_name):
			return dictionary.get(segment_name)
		return null

	if current is Array:
		var array_value: Array = current as Array
		if not segment.is_valid_int():
			return null
		var index: int = int(segment)
		if index < 0 or index >= array_value.size():
			return null
		return array_value[index]

	if current is Object:
		var object_value: Object = current as Object
		if U_QB_VARIANT_UTILS.object_has_property(object_value, segment):
			return object_value.get(segment)
		if object_value.has_method(segment):
			return object_value.call(segment)
		return null

	return null
