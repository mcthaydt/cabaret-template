@icon("res://assets/editor_icons/icn_utility.svg")
extends Resource

class_name RS_JumpSettings

@export var jump_force: float = 12.0
@export var coyote_time: float = 0.28
@export var max_air_jumps: int = 0
@export var jump_buffer_time: float = 0.28
@export var apex_coyote_time: float = 0.1
@export var apex_velocity_threshold: float = 0.1

## Minimum vertical distance required for a landing event to fire (filters ramp bounces)
@export var min_landing_fall_height: float = 0.5
## Minimum upward step height that still counts as a landing even if fall distance is small
@export var min_step_up_height: float = 0.5
## Minimum fall distance required (while airborne) for step-up landings
@export var min_step_up_fall_height: float = 0.05
