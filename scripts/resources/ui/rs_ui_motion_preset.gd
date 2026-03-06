@icon("res://assets/editor_icons/icn_resource.svg")
extends Resource
class_name RS_UIMotionPreset

## A single tween recipe used by UI motion sets.

@export var property_path: String = ""
@export var from_value: Variant = null
@export var to_value: Variant = null
@export var relative: bool = false

@export_range(0.0, 10.0, 0.01) var duration_sec: float = 0.2
@export_range(0.0, 10.0, 0.01) var delay_sec: float = 0.0
@export_range(0.0, 10.0, 0.01) var interval_sec: float = 0.0

@export var transition_type: Tween.TransitionType = Tween.TRANS_CUBIC
@export var ease_type: Tween.EaseType = Tween.EASE_IN_OUT
@export var parallel: bool = false

func is_interval_step() -> bool:
	return property_path.strip_edges().is_empty() and interval_sec > 0.0

func has_property_target() -> bool:
	return not property_path.strip_edges().is_empty()
