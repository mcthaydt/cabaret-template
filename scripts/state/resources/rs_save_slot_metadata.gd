@icon("res://resources/editor_icons/resource.svg")
extends Resource
class_name RS_SaveSlotMetadata

## Serialized metadata describing a save slot (manual or auto).
##
## Stored in the save envelope under the `metadata` key and designed to be
## JSON-friendly (StringName values are encoded as strings).

enum SlotType {
	MANUAL = 0,
	AUTO = 1,
}

@export var slot_id: int = 0
@export_enum("Manual:0", "Auto:1") var slot_type: int = SlotType.MANUAL

@export var scene_id: StringName = StringName("")
@export var scene_name: String = ""

@export var timestamp: float = 0.0
@export var formatted_timestamp: String = ""

@export var play_time_seconds: float = 0.0

@export var player_health: float = 0.0
@export var player_max_health: float = 0.0
@export var death_count: int = 0

@export var completed_areas: Array[String] = []
@export var completion_percentage: float = -1.0  # -1.0 = unknown sentinel (V1)

@export var is_empty: bool = true
@export var file_path: String = ""
@export var file_version: int = 0

func to_dictionary() -> Dictionary:
	return {
		"slot_id": slot_id,
		"slot_type": slot_type,
		"scene_id": String(scene_id),
		"scene_name": scene_name,
		"timestamp": timestamp,
		"formatted_timestamp": formatted_timestamp,
		"play_time_seconds": play_time_seconds,
		"player_health": player_health,
		"player_max_health": player_max_health,
		"death_count": death_count,
		"completed_areas": completed_areas.duplicate(),
		"completion_percentage": completion_percentage,
		"is_empty": is_empty,
		"file_path": file_path,
		"file_version": file_version,
	}

func from_dictionary(data: Dictionary) -> void:
	slot_id = int(data.get("slot_id", 0))
	slot_type = int(data.get("slot_type", SlotType.MANUAL))

	var scene_id_value: Variant = data.get("scene_id", "")
	if scene_id_value is StringName:
		scene_id = scene_id_value
	else:
		scene_id = StringName(str(scene_id_value))

	scene_name = str(data.get("scene_name", ""))
	timestamp = float(data.get("timestamp", 0.0))
	formatted_timestamp = str(data.get("formatted_timestamp", ""))

	play_time_seconds = float(data.get("play_time_seconds", 0.0))

	player_health = float(data.get("player_health", 0.0))
	player_max_health = float(data.get("player_max_health", 0.0))
	death_count = int(data.get("death_count", 0))

	var areas_value: Variant = data.get("completed_areas", [])
	if areas_value is Array:
		var src := areas_value as Array
		var safe: Array[String] = []
		for area in src:
			safe.append(str(area))
		completed_areas = safe
	else:
		completed_areas = []

	completion_percentage = float(data.get("completion_percentage", -1.0))
	is_empty = bool(data.get("is_empty", true))
	file_path = str(data.get("file_path", ""))
	file_version = int(data.get("file_version", 0))

func get_display_summary() -> String:
	if is_empty:
		return "Empty"

	var scene_part := "%s (%s)" % [scene_name, String(scene_id)]
	var hp_part := "%s/%s" % [_format_float(player_health), _format_float(player_max_health)]
	var areas_part := "%d" % completed_areas.size()
	return "%s | %s | %ss | HP %s | Deaths %d | Areas %s" % [
		scene_part,
		formatted_timestamp,
		_format_float(play_time_seconds),
		hp_part,
		death_count,
		areas_part,
	]

static func _format_float(value: float) -> String:
	if is_zero_approx(value - round(value)):
		return str(int(round(value)))
	return str(value)
