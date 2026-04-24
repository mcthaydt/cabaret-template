@icon("res://assets/editor_icons/icn_component.svg")
extends BaseECSComponent
class_name C_ResourceNodeComponent

const COMPONENT_TYPE := StringName("C_ResourceNodeComponent")

@export var settings: RS_ResourceNodeSettings = null

var current_amount: int = 0
var reserved_by_entity_id: StringName = StringName("")
var regrow_timer: float = 0.0

func _init() -> void:
	component_type = COMPONENT_TYPE

func _validate_required_settings() -> bool:
	if settings == null:
		push_error("C_ResourceNodeComponent missing settings; assign an RS_ResourceNodeSettings resource.")
		return false
	return true

func _on_required_settings_ready() -> void:
	current_amount = settings.initial_amount

func is_available() -> bool:
	return current_amount > 0 and reserved_by_entity_id == StringName("")

func harvest(qty: int) -> int:
	var taken := mini(qty, current_amount)
	current_amount -= taken
	return taken

func clear_reservation() -> void:
	reserved_by_entity_id = StringName("")

func clear_reservation_if_owned(entity_id: StringName) -> void:
	if reserved_by_entity_id == entity_id:
		reserved_by_entity_id = StringName("")
