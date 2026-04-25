@icon("res://assets/core/editor_icons/icn_resource.svg")
extends Resource
class_name RS_VCamBlendHint

@export_range(0.0, 10.0, 0.01) var blend_duration: float = 1.0
@export var ease_type: Tween.EaseType = Tween.EASE_IN_OUT
@export var trans_type: Tween.TransitionType = Tween.TRANS_CUBIC
@export_range(0.0, 1000.0, 0.01) var cut_on_distance_threshold: float = 0.0

func is_instant_cut() -> bool:
	return blend_duration <= 0.0

