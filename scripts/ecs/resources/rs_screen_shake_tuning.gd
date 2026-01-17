extends Resource
class_name RS_ScreenShakeTuning

@export_group("Decay")
@export var trauma_decay_rate: float = 2.0

@export_group("Damage")
@export var damage_min_trauma: float = 0.3
@export var damage_max_trauma: float = 0.6
@export var damage_max_value: float = 100.0

@export_group("Landing")
@export var landing_threshold: float = 15.0
@export var landing_max_speed: float = 30.0
@export var landing_min_trauma: float = 0.2
@export var landing_max_trauma: float = 0.4

@export_group("Death")
@export var death_trauma: float = 0.5

func calculate_damage_trauma(damage_amount: float) -> float:
	if damage_amount <= 0.0:
		return 0.0
	var damage_ratio: float = clampf(damage_amount / damage_max_value, 0.0, 1.0)
	return lerpf(damage_min_trauma, damage_max_trauma, damage_ratio)

func calculate_landing_trauma(fall_speed: float) -> float:
	if fall_speed <= landing_threshold:
		return 0.0
	var speed_ratio: float = clampf(
		(fall_speed - landing_threshold) / (landing_max_speed - landing_threshold),
		0.0,
		1.0
	)
	return lerpf(landing_min_trauma, landing_max_trauma, speed_ratio)
