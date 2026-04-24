@icon("res://assets/editor_icons/icn_component.svg")
extends BaseECSComponent
class_name C_CharacterStateComponent

const COMPONENT_TYPE := StringName("C_CharacterStateComponent")

const VERTICAL_STATE_FALLING: int = -1
const VERTICAL_STATE_GROUNDED: int = 0
const VERTICAL_STATE_RISING: int = 1

@export var is_gameplay_active: bool = true
@export var is_grounded: bool = false
@export var is_moving: bool = false
@export var is_spawn_frozen: bool = false
@export var is_dead: bool = false
@export var is_invincible: bool = false
@export_range(0.0, 1.0, 0.001) var health_percent: float = 1.0
@export var vertical_state: int = VERTICAL_STATE_GROUNDED
@export var has_input: bool = false

func _init() -> void:
	component_type = COMPONENT_TYPE

func set_health_percent(value: float) -> void:
	health_percent = clampf(value, 0.0, 1.0)

func get_snapshot() -> Dictionary:
	return {
		"is_gameplay_active": is_gameplay_active,
		"is_grounded": is_grounded,
		"is_moving": is_moving,
		"is_spawn_frozen": is_spawn_frozen,
		"is_dead": is_dead,
		"is_invincible": is_invincible,
		"health_percent": health_percent,
		"vertical_state": vertical_state,
		"has_input": has_input,
	}
