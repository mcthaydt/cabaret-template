extends RefCounted
class_name U_ObjectiveEventLog

const U_ECS_UTILS := preload("res://scripts/utils/ecs/u_ecs_utils.gd")

const EVENT_ACTIVATED := "activated"
const EVENT_COMPLETED := "completed"
const EVENT_FAILED := "failed"
const EVENT_DEPENDENCY_MET := "dependency_met"
const EVENT_CONDITION_CHECKED := "condition_checked"

static func create_entry(
	objective_id: StringName,
	event_type: String,
	details: Dictionary = {}
) -> Dictionary:
	return {
		"objective_id": objective_id,
		"event_type": event_type,
		"timestamp": U_ECS_UTILS.get_current_time(),
		"details": details.duplicate(true),
	}

static func format_log(entries: Array) -> String:
	if entries.is_empty():
		return ""

	var lines: PackedStringArray = PackedStringArray()
	for entry_variant in entries:
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		var objective_id: StringName = _to_string_name(entry.get("objective_id", StringName("")))
		var event_type: String = str(entry.get("event_type", ""))
		var timestamp: float = _to_float(entry.get("timestamp", 0.0))
		var details: Dictionary = {}
		var details_variant: Variant = entry.get("details", {})
		if details_variant is Dictionary:
			details = (details_variant as Dictionary).duplicate(true)

		var line: String = "[%0.3f] %s %s" % [timestamp, String(objective_id), event_type]
		if not details.is_empty():
			line += " | " + _format_details(details)
		lines.append(line)

	return "\n".join(lines)

static func _format_details(details: Dictionary) -> String:
	var keys: Array[String] = []
	for key_variant in details.keys():
		keys.append(str(key_variant))
	keys.sort()

	var parts: PackedStringArray = PackedStringArray()
	for key in keys:
		var value: Variant = details.get(key, details.get(StringName(key), null))
		parts.append("%s=%s" % [key, str(value)])
	return ", ".join(parts)

static func _to_string_name(value: Variant) -> StringName:
	if value is StringName:
		return value
	if value is String:
		return StringName(value)
	return StringName("")

static func _to_float(value: Variant) -> float:
	if value is float:
		return value
	if value is int:
		return float(value)
	return 0.0
