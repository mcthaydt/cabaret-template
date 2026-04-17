@icon("res://assets/editor_icons/icn_component.svg")
extends BaseECSComponent
class_name C_DetectionComponent

const COMPONENT_TYPE := StringName("C_DetectionComponent")

@export_group("Radius")
@export_range(0.1, 100.0, 0.1, "or_greater") var detection_radius: float = 8.0
@export_range(0.0, 100.0, 0.1, "or_greater") var detection_exit_radius: float = 0.0
@export var detect_y_axis: bool = false
@export var target_tag: StringName = StringName("player")

@export_group("Detection Role")
@export var detection_role: StringName = StringName("primary")

@export_group("Flag Dispatch")
@export var ai_flag_id: StringName = StringName("")
@export var enter_flag_value: bool = true
@export var set_flag_on_exit: bool = true
@export var exit_flag_value: bool = false

@export_group("Event Dispatch")
@export var enter_event_name: StringName = StringName("")
@export var enter_event_payload: Dictionary = {}

var is_player_in_range: bool = false
var last_detected_player_entity_id: StringName = StringName("")

func _init() -> void:
	component_type = COMPONENT_TYPE

func get_resolved_exit_radius() -> float:
	if detection_exit_radius > detection_radius:
		return detection_exit_radius
	return detection_radius

func _validate_required_settings() -> bool:
	if detection_radius <= 0.0:
		push_error("C_DetectionComponent detection_radius must be > 0.0.")
		return false
	return true
