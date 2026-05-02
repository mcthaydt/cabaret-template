@icon("res://assets/core/editor_icons/icn_environment.svg")
extends Node3D
class_name L_GlobalZone

@export var profile: Resource = null

func get_influence_weight(_world_position: Vector3) -> float:
	return 1.0

func get_zone_metadata() -> Dictionary:
	var zone_id := StringName(String(name).to_lower())
	var stable_key := String(zone_id)
	if is_inside_tree():
		stable_key = "%s::%s" % [String(get_path()), String(zone_id)]

	var profile_dict: Dictionary = {}
	if profile != null and profile.has_method("get_resolved_values"):
		var values: Variant = profile.call("get_resolved_values")
		if values is Dictionary:
			profile_dict = (values as Dictionary).duplicate(true)

	return {
		"zone_id": zone_id,
		"stable_key": stable_key,
		"priority": 0,
		"blend_weight": 1.0,
		"profile": profile_dict.duplicate(true),
	}
