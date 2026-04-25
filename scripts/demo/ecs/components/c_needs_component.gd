@icon("res://assets/core/editor_icons/icn_component.svg")
extends BaseECSComponent
class_name C_NeedsComponent

const COMPONENT_TYPE := StringName("C_NeedsComponent")

@export var settings: RS_NeedsSettings = null

var hunger: float = 1.0
var thirst: float = 1.0

func _init() -> void:
	component_type = COMPONENT_TYPE

func _validate_required_settings() -> bool:
	if settings == null:
		push_error("C_NeedsComponent missing settings; assign an RS_NeedsSettings resource.")
		return false
	return true

func _on_required_settings_ready() -> void:
	hunger = clampf(settings.initial_hunger, 0.0, 1.0)
	thirst = clampf(settings.initial_thirst, 0.0, 1.0)
