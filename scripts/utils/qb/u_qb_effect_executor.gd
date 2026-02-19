extends RefCounted
class_name U_QBEffectExecutor

const QB_CONDITION := preload("res://scripts/resources/qb/rs_qb_condition.gd")
const QB_EFFECT := preload("res://scripts/resources/qb/rs_qb_effect.gd")

static func execute_effect(effect: Variant, context: Dictionary) -> void:
	if effect == null:
		return
	if not (effect is Object):
		return

	var effect_type: int = _get_int_property(effect, "effect_type", QB_EFFECT.EffectType.SET_QUALITY)
	match effect_type:
		QB_EFFECT.EffectType.DISPATCH_ACTION:
			_execute_dispatch_action(effect, context)
		QB_EFFECT.EffectType.PUBLISH_EVENT:
			_execute_publish_event(effect, context)
		QB_EFFECT.EffectType.SET_COMPONENT_FIELD:
			_execute_set_component_field(effect, context)
		QB_EFFECT.EffectType.SET_QUALITY:
			_execute_set_quality(effect, context)
		_:
			push_warning("U_QBEffectExecutor: Unknown effect type: %s" % str(effect_type))

static func execute_effects(effects: Array, context: Dictionary) -> void:
	for effect_variant in effects:
		execute_effect(effect_variant, context)

static func _execute_dispatch_action(effect: Variant, context: Dictionary) -> void:
	var store: Variant = context.get("state_store", null)
	if store == null or not (store is I_StateStore):
		push_warning("U_QBEffectExecutor: DISPATCH_ACTION missing context.state_store")
		return

	var action_type: StringName = StringName(_get_string_property(effect, "target", ""))
	if action_type == &"":
		push_warning("U_QBEffectExecutor: DISPATCH_ACTION missing target")
		return

	var payload: Dictionary = _get_effect_payload(effect)
	var action: Dictionary = {
		"type": action_type,
		"payload": payload.duplicate(true),
	}
	store.dispatch(action)

static func _execute_publish_event(effect: Variant, context: Dictionary) -> void:
	var event_name: StringName = StringName(_get_string_property(effect, "target", ""))
	if event_name == &"":
		push_warning("U_QBEffectExecutor: PUBLISH_EVENT missing target")
		return

	var event_payload: Dictionary = _get_effect_payload(effect).duplicate(true)
	if context.has("entity_id") and not event_payload.has("entity_id"):
		event_payload["entity_id"] = context.get("entity_id")
	if context.has("event_payload"):
		var original_payload_variant: Variant = context.get("event_payload", null)
		if original_payload_variant is Dictionary:
			var original_payload: Dictionary = original_payload_variant as Dictionary
			for key in original_payload.keys():
				if not event_payload.has(key):
					event_payload[key] = original_payload.get(key)

	U_ECSEventBus.publish(event_name, event_payload)

static func _execute_set_component_field(effect: Variant, context: Dictionary) -> void:
	var target: String = _get_string_property(effect, "target", "")
	if target.is_empty() or target.find(".") == -1:
		push_warning("U_QBEffectExecutor: SET_COMPONENT_FIELD target must be Component.field")
		return

	var separator_index: int = target.find(".")
	var component_key: String = target.substr(0, separator_index)
	var field_name: String = target.substr(separator_index + 1)
	if component_key.is_empty() or field_name.is_empty():
		push_warning("U_QBEffectExecutor: SET_COMPONENT_FIELD target must be Component.field")
		return

	var components: Dictionary = _get_dict(context, "components")
	if components.is_empty():
		components = _get_dict(context, "component_data")
	if components.is_empty():
		push_warning("U_QBEffectExecutor: SET_COMPONENT_FIELD missing context.components")
		return

	var component: Variant = _dict_get_string_or_name(components, component_key)
	if component == null:
		push_warning("U_QBEffectExecutor: SET_COMPONENT_FIELD component '%s' missing" % component_key)
		return

	var payload: Dictionary = _get_effect_payload(effect)
	var operation_variant: Variant = payload.get("operation", StringName("set"))
	var operation: StringName = StringName(operation_variant)
	var value_type: int = int(payload.get("value_type", QB_CONDITION.ValueType.BOOL))
	var value: Variant = _get_payload_typed_value(effect, payload)

	if operation != StringName("set") and operation != StringName("add"):
		push_warning("U_QBEffectExecutor: SET_COMPONENT_FIELD invalid operation '%s'" % String(operation))
		return

	var current_value: Variant = _read_field_value(component, field_name)
	if current_value == null:
		push_warning("U_QBEffectExecutor: SET_COMPONENT_FIELD field '%s' missing" % field_name)
		return

	var next_value: Variant = value
	if operation == StringName("add"):
		if not _is_numeric(current_value) or not _is_numeric(value):
			push_warning("U_QBEffectExecutor: SET_COMPONENT_FIELD add requires numeric field/value")
			return
		next_value = float(current_value) + float(value)
		if current_value is int and value_type == QB_CONDITION.ValueType.INT:
			next_value = int(next_value)

	var clamped_result: Variant = _apply_numeric_clamp_if_needed(next_value, payload)
	if clamped_result == null and (payload.has("clamp_min") or payload.has("clamp_max")):
		push_warning("U_QBEffectExecutor: SET_COMPONENT_FIELD invalid numeric clamp")
		return
	if clamped_result != null:
		next_value = clamped_result

	if not _write_field_value(component, field_name, next_value):
		push_warning("U_QBEffectExecutor: SET_COMPONENT_FIELD failed writing '%s'" % field_name)

static func _execute_set_quality(effect: Variant, context: Dictionary) -> void:
	var quality_key: String = _get_string_property(effect, "target", "")
	if quality_key.is_empty():
		push_warning("U_QBEffectExecutor: SET_QUALITY missing target key")
		return

	var payload: Dictionary = _get_effect_payload(effect)
	var value: Variant = _get_payload_typed_value(effect, payload)
	context[quality_key] = value

static func _get_payload_typed_value(effect: Variant, payload: Dictionary) -> Variant:
	if effect is Object and effect.has_method("get_payload_typed_value"):
		return effect.call("get_payload_typed_value")

	var value_type: int = int(payload.get("value_type", QB_CONDITION.ValueType.BOOL))
	match value_type:
		QB_CONDITION.ValueType.FLOAT:
			return float(payload.get("value_float", 0.0))
		QB_CONDITION.ValueType.INT:
			return int(payload.get("value_int", 0))
		QB_CONDITION.ValueType.STRING:
			return String(payload.get("value_string", ""))
		QB_CONDITION.ValueType.BOOL:
			return bool(payload.get("value_bool", false))
		QB_CONDITION.ValueType.STRING_NAME:
			return StringName(payload.get("value_string_name", &""))
		_:
			return null

static func _read_field_value(component: Variant, field_name: String) -> Variant:
	if component is Dictionary:
		var dictionary: Dictionary = component as Dictionary
		if dictionary.has(field_name):
			return dictionary.get(field_name)
		var field_name_key: StringName = StringName(field_name)
		if dictionary.has(field_name_key):
			return dictionary.get(field_name_key)
		return null

	if component is Object:
		var object_value: Object = component as Object
		return object_value.get(field_name)

	return null

static func _write_field_value(component: Variant, field_name: String, value: Variant) -> bool:
	if component is Dictionary:
		var dictionary: Dictionary = component as Dictionary
		if dictionary.has(field_name):
			dictionary[field_name] = value
			return true
		var field_name_key: StringName = StringName(field_name)
		if dictionary.has(field_name_key):
			dictionary[field_name_key] = value
			return true
		return false

	if component is Object:
		var object_value: Object = component as Object
		if not _object_has_property(object_value, field_name):
			return false
		object_value.set(field_name, value)
		return true

	return false

static func _apply_numeric_clamp_if_needed(value: Variant, payload: Dictionary) -> Variant:
	if not payload.has("clamp_min") and not payload.has("clamp_max"):
		return null
	if not _is_numeric(value):
		return null

	var numeric_value: float = float(value)
	if payload.has("clamp_min"):
		var clamp_min: Variant = payload.get("clamp_min")
		if not _is_numeric(clamp_min):
			return null
		numeric_value = maxf(numeric_value, float(clamp_min))
	if payload.has("clamp_max"):
		var clamp_max: Variant = payload.get("clamp_max")
		if not _is_numeric(clamp_max):
			return null
		numeric_value = minf(numeric_value, float(clamp_max))

	if value is int:
		return int(numeric_value)
	return numeric_value

static func _is_numeric(value: Variant) -> bool:
	return value is int or value is float

static func _object_has_property(object_value: Object, property_name: String) -> bool:
	var property_list: Array = object_value.get_property_list()
	for property_info_variant in property_list:
		if not (property_info_variant is Dictionary):
			continue
		var property_info: Dictionary = property_info_variant as Dictionary
		var name_variant: Variant = property_info.get("name", "")
		if String(name_variant) == property_name:
			return true
	return false

static func _get_effect_payload(effect: Variant) -> Dictionary:
	if effect == null or not (effect is Object):
		return {}
	var payload: Variant = effect.get("payload")
	if payload is Dictionary:
		return payload as Dictionary
	return {}

static func _get_int_property(object_value: Variant, property_name: String, fallback: int) -> int:
	if object_value == null or not (object_value is Object):
		return fallback
	var value: Variant = object_value.get(property_name)
	if value == null:
		return fallback
	return int(value)

static func _get_string_property(object_value: Variant, property_name: String, fallback: String) -> String:
	if object_value == null or not (object_value is Object):
		return fallback
	var value: Variant = object_value.get(property_name)
	if value == null:
		return fallback
	if value is String:
		return value
	if value is StringName:
		return String(value)
	return fallback

static func _get_dict(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, null)
	if value is Dictionary:
		return value as Dictionary
	var key_name: StringName = StringName(key)
	var key_name_value: Variant = source.get(key_name, null)
	if key_name_value is Dictionary:
		return key_name_value as Dictionary
	return {}

static func _dict_get_string_or_name(dictionary: Dictionary, key: String) -> Variant:
	if dictionary.has(key):
		return dictionary.get(key)
	var key_name: StringName = StringName(key)
	if dictionary.has(key_name):
		return dictionary.get(key_name)
	return null
