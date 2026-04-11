extends RefCounted
class_name U_RuleUtils

const CONDITION_EVENT_NAME_SCRIPT := preload("res://scripts/resources/qb/conditions/rs_condition_event_name.gd")
const CONDITION_COMPOSITE_SCRIPT := preload("res://scripts/resources/qb/conditions/rs_condition_composite.gd")

## Reads a String property from an object. Returns the fallback if the object is null,
## the property doesn't exist, or the value is not a String/StringName.
static func read_string_property(object_value: Variant, property_name: String, fallback: String = "") -> String:
	if object_value == null or not (object_value is Object):
		return fallback
	var value: Variant = (object_value as Object).get(property_name)
	if value is String:
		return value
	if value is StringName:
		return String(value)
	return fallback

## Reads a StringName property from an object. Returns empty StringName if the object is null,
## the property doesn't exist, or the value is not a String/StringName.
static func read_string_name_property(object_value: Variant, property_name: String) -> StringName:
	if object_value == null or not (object_value is Object):
		return StringName()
	var value: Variant = (object_value as Object).get(property_name)
	if value is StringName:
		return value
	if value is String:
		return StringName(value)
	return StringName()

## Reads a bool property from an object. Returns the fallback if the object is null,
## the property doesn't exist, or the value is not a bool.
static func read_bool_property(object_value: Variant, property_name: String, fallback: bool = false) -> bool:
	if object_value == null or not (object_value is Object):
		return fallback
	var value: Variant = (object_value as Object).get(property_name)
	if value is bool:
		return value
	return fallback

## Reads a float property from an object. Returns the fallback if the object is null,
## the property doesn't exist, or the value is not numeric.
static func read_float_property(object_value: Variant, property_name: String, fallback: float = 0.0) -> float:
	if object_value == null or not (object_value is Object):
		return fallback
	var value: Variant = (object_value as Object).get(property_name)
	if value is float or value is int:
		return float(value)
	return fallback

## Checks whether an object's script inherits from the given script reference
## by walking the script inheritance chain.
static func is_script_instance_of(object_value: Object, script_ref: Script) -> bool:
	if object_value == null:
		return false
	if script_ref == null:
		return false

	var current: Variant = object_value.get_script()
	while current != null and current is Script:
		if current == script_ref:
			return true
		current = (current as Script).get_base_script()
	return false

## Checks whether an object has a property with the given name by scanning
## its property list.
static func object_has_property(object_value: Object, property_name: String) -> bool:
	if object_value == null:
		return false
	var properties: Array[Dictionary] = object_value.get_property_list()
	for property_info in properties:
		var name_value: Variant = property_info.get("name", "")
		if str(name_value) == property_name:
			return true
	return false

## Converts a Variant to StringName. Returns StringName for StringName/String inputs,
## empty StringName for empty strings, and empty StringName for non-string types.
static func variant_to_string_name(value: Variant) -> StringName:
	if value is StringName:
		return value as StringName
	if value is String:
		var text: String = value
		if text.is_empty():
			return StringName()
		return StringName(text)
	return StringName()

## Retrieves a value from a dictionary by key, checking both String and StringName
## forms of the key. Returns null if neither key is found.
static func get_context_value(dictionary: Dictionary, key: String) -> Variant:
	if dictionary.has(key):
		return dictionary.get(key)

	var key_name: StringName = StringName(key)
	if dictionary.has(key_name):
		return dictionary.get(key_name)

	return null

## Extracts all event names from a rule's conditions, including nested composite conditions.
## Deduplicates results and skips non-event-name conditions.
static func extract_event_names_from_rule(rule_variant: Variant) -> Array[StringName]:
	var event_names: Array[StringName] = []
	if rule_variant == null or not (rule_variant is Object):
		return event_names

	var conditions_variant: Variant = (rule_variant as Object).get("conditions")
	if not (conditions_variant is Array):
		return event_names

	for condition_variant in conditions_variant as Array:
		_collect_event_names_from_condition(condition_variant, event_names)

	return event_names

## Recursively collects event names from a condition, handling both
## RS_ConditionEventName and nested RS_ConditionComposite conditions.
static func _collect_event_names_from_condition(condition_variant: Variant, event_names: Array[StringName]) -> void:
	if condition_variant == null or not (condition_variant is Object):
		return
	var condition_object: Object = condition_variant as Object

	if is_script_instance_of(condition_object, CONDITION_EVENT_NAME_SCRIPT):
		var condition_event_name: StringName = read_string_name_property(
			condition_object,
			"expected_event_name"
		)
		if condition_event_name == StringName():
			return
		if event_names.has(condition_event_name):
			return
		event_names.append(condition_event_name)
		return

	if not is_script_instance_of(condition_object, CONDITION_COMPOSITE_SCRIPT):
		return

	var children_variant: Variant = condition_object.get("children")
	if not (children_variant is Array):
		return

	for child_condition_variant in children_variant as Array:
		_collect_event_names_from_condition(child_condition_variant, event_names)