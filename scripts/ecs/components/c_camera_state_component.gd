@icon("res://assets/editor_icons/icn_component.svg")
extends BaseECSComponent
class_name C_CameraStateComponent

const COMPONENT_TYPE := StringName("C_CameraStateComponent")

const DEFAULT_TARGET_FOV: float = 75.0
const UNSET_BASE_FOV: float = 0.0
const DEFAULT_SHAKE_TRAUMA: float = 0.0
const DEFAULT_FOV_BLEND_SPEED: float = 2.0
const DEFAULT_LANDING_IMPACT_OFFSET: Vector3 = Vector3.ZERO
const DEFAULT_LANDING_IMPACT_RECOVERY_SPEED: float = 8.0
const DEFAULT_SPEED_FOV_BONUS: float = 0.0
const DEFAULT_SPEED_FOV_MAX_BONUS: float = 15.0

@export_range(1.0, 179.0, 0.1) var target_fov: float = DEFAULT_TARGET_FOV
@export_range(0.0, 179.0, 0.1) var base_fov: float = UNSET_BASE_FOV
@export_range(0.0, 1.0, 0.001) var shake_trauma: float = DEFAULT_SHAKE_TRAUMA
@export_range(0.0, 20.0, 0.1) var fov_blend_speed: float = DEFAULT_FOV_BLEND_SPEED
@export var landing_impact_offset: Vector3 = DEFAULT_LANDING_IMPACT_OFFSET
@export_range(0.0, 60.0, 0.1) var landing_impact_recovery_speed: float = DEFAULT_LANDING_IMPACT_RECOVERY_SPEED
@export_range(0.0, 60.0, 0.1) var speed_fov_bonus: float = DEFAULT_SPEED_FOV_BONUS
@export_range(0.0, 60.0, 0.1) var speed_fov_max_bonus: float = DEFAULT_SPEED_FOV_MAX_BONUS

func _init() -> void:
	component_type = COMPONENT_TYPE

func set_target_fov(value: float) -> void:
	target_fov = clampf(value, 1.0, 179.0)

func set_base_fov(value: float) -> void:
	if value <= 1.0:
		base_fov = UNSET_BASE_FOV
		return
	base_fov = clampf(value, 1.0, 179.0)

func set_shake_trauma(value: float) -> void:
	shake_trauma = clampf(value, 0.0, 1.0)

func add_shake_trauma(amount: float) -> void:
	set_shake_trauma(shake_trauma + amount)

func set_fov_blend_speed(value: float) -> void:
	fov_blend_speed = maxf(value, 0.0)

func reset_state() -> void:
	target_fov = DEFAULT_TARGET_FOV
	base_fov = UNSET_BASE_FOV
	shake_trauma = DEFAULT_SHAKE_TRAUMA
	fov_blend_speed = DEFAULT_FOV_BLEND_SPEED
	landing_impact_offset = DEFAULT_LANDING_IMPACT_OFFSET
	landing_impact_recovery_speed = DEFAULT_LANDING_IMPACT_RECOVERY_SPEED
	speed_fov_bonus = DEFAULT_SPEED_FOV_BONUS
	speed_fov_max_bonus = DEFAULT_SPEED_FOV_MAX_BONUS

func get_snapshot() -> Dictionary:
	return {
		"target_fov": target_fov,
		"base_fov": base_fov,
		"shake_trauma": shake_trauma,
		"fov_blend_speed": fov_blend_speed,
		"landing_impact_offset": landing_impact_offset,
		"landing_impact_recovery_speed": landing_impact_recovery_speed,
		"speed_fov_bonus": speed_fov_bonus,
		"speed_fov_max_bonus": speed_fov_max_bonus,
	}
