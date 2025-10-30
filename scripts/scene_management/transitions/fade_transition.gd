extends "res://scripts/scene_management/transitions/base_transition_effect.gd"
class_name FadeTransition

## Fade transition effect
##
## Fades out to a color, then fades back in.
## Uses Tween to animate the TransitionColorRect's modulate.a property.
##
## Sequence:
## 1. Fade out: alpha 0.0 → 1.0 (duration/2)
## 2. Call mid_transition_callback (if set)
## 3. Fade in: alpha 1.0 → 0.0 (duration/2)
## 4. Call completion callback

## Transition duration in seconds
@export var duration: float = 1.0

## Color to fade to (default black)
@export var fade_color: Color = Color.BLACK

## Block input during transition
@export var block_input: bool = true

## Tween easing type
@export var easing_type: Tween.EaseType = Tween.EASE_IN_OUT

## Tween transition type
@export var transition_type: Tween.TransitionType = Tween.TRANS_CUBIC

## Optional callback at mid-point (when fully faded out)
var mid_transition_callback: Callable

## Internal Tween reference
var _tween: Tween = null

## Execute fade transition
##
## @param overlay: CanvasLayer containing TransitionColorRect
## @param callback: Callable to invoke when transition completes
func execute(overlay: CanvasLayer, callback: Callable) -> void:
	if overlay == null:
		print_debug("FadeTransition: overlay is null, skipping transition")
		callback.call()
		return

	# Find TransitionColorRect
	var color_rect: ColorRect = _find_color_rect(overlay)
	if color_rect == null:
		push_error("FadeTransition: TransitionColorRect not found in overlay")
		callback.call()
		return

	# Set fade color
	color_rect.color = fade_color

	# Handle zero duration
	if duration <= 0.0:
		# Instant transition - call callbacks immediately
		if mid_transition_callback != Callable():
			mid_transition_callback.call()
		callback.call()
		return

	# Create Tween
	_tween = overlay.create_tween()
	_tween.set_ease(easing_type)
	_tween.set_trans(transition_type)

	# Calculate half duration
	var half_duration: float = duration / 2.0

	# Fade out (alpha 0 → 1)
	_tween.tween_property(color_rect, "modulate:a", 1.0, half_duration).from(0.0)

	# Mid-point callback
	_tween.tween_callback(func() -> void:
		if mid_transition_callback != Callable():
			mid_transition_callback.call()
	)

	# Fade in (alpha 1 → 0)
	_tween.tween_property(color_rect, "modulate:a", 0.0, half_duration).from(1.0)

	# Completion callback
	_tween.tween_callback(func() -> void:
		_cleanup_tween()
		callback.call()
	)

## Find TransitionColorRect in overlay
func _find_color_rect(overlay: CanvasLayer) -> ColorRect:
	for child in overlay.get_children():
		if child is ColorRect and child.name == "TransitionColorRect":
			return child as ColorRect
	return null

## Clean up Tween reference
func _cleanup_tween() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null

## Get duration of transition
func get_duration() -> float:
	return duration
