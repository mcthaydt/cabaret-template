@icon("res://assets/editor_icons/icn_component.svg")
extends BaseECSComponent
class_name C_NeedsComponent

const COMPONENT_TYPE := StringName("C_NeedsComponent")
const RS_NEEDS_SETTINGS := preload("res://scripts/resources/ecs/rs_needs_settings.gd")

@export var settings: Resource = null

var hunger: float = 1.0

func _init() -> void:
	component_type = COMPONENT_TYPE

func _validate_required_settings() -> bool:
	if settings == null:
		push_error("C_NeedsComponent missing settings; assign an RS_NeedsSettings resource.")
		return false
	if not (settings is RS_NEEDS_SETTINGS):
		push_error("C_NeedsComponent settings must be an RS_NeedsSettings resource.")
		return false
	return true

func _on_required_settings_ready() -> void:
	hunger = clampf(settings.initial_hunger, 0.0, 1.0)
