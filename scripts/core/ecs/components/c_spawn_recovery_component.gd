@icon("res://assets/editor_icons/icn_component.svg")
extends BaseECSComponent
class_name C_SpawnRecoveryComponent

const COMPONENT_TYPE := StringName("C_SpawnRecoveryComponent")
const RS_SPAWN_RECOVERY_SETTINGS := preload("res://scripts/core/resources/ecs/rs_spawn_recovery_settings.gd")

@export var settings: RS_SpawnRecoverySettings = null

func _init() -> void:
	component_type = COMPONENT_TYPE

func _validate_required_settings() -> bool:
	if settings == null:
		push_error("C_SpawnRecoveryComponent missing settings; assign an RS_SpawnRecoverySettings resource.")
		return false
	if not (settings is RS_SPAWN_RECOVERY_SETTINGS):
		push_error("C_SpawnRecoveryComponent settings must be an RS_SpawnRecoverySettings resource.")
		return false
	return true
