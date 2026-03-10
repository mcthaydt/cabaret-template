@icon("res://assets/editor_icons/icn_resource.svg")
extends Resource
class_name RS_VCamResponse

const MIN_FREQUENCY_HZ: float = 0.0001

@export var follow_frequency: float = 3.0
@export var follow_damping: float = 0.7
@export var follow_initial_response: float = 1.0

@export var rotation_frequency: float = 4.0
@export var rotation_damping: float = 1.0
@export var rotation_initial_response: float = 1.0

func get_resolved_values() -> Dictionary:
	return {
		"follow_frequency": maxf(follow_frequency, MIN_FREQUENCY_HZ),
		"follow_damping": maxf(follow_damping, 0.0),
		"follow_initial_response": follow_initial_response,
		"rotation_frequency": maxf(rotation_frequency, MIN_FREQUENCY_HZ),
		"rotation_damping": maxf(rotation_damping, 0.0),
		"rotation_initial_response": rotation_initial_response,
	}
