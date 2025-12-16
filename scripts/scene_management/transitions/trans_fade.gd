extends "res://scripts/scene_management/transitions/base_transition_effect.gd"
class_name Trans_Fade

## Fade transition effect
##
## Fades out to a color, then fades back in.
## Uses U_TweenManager for standardized tween configuration and lifecycle.
##
## Sequence:
## 1. Fade out: alpha 0.0 → 1.0 (duration/2)
## 2. Call mid_transition_callback (if set)
## 3. Fade in: alpha 1.0 → 0.0 (duration/2)
## 4. Call completion callback

const U_TweenManager = preload("res://scripts/scene_management/u_tween_manager.gd")

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

## Internal Tween reference (for backwards compatibility with tests)
var _tween: Tween = null

## TweenContext for process mode management (execute() only)
var _tween_context: U_TweenManager.TweenContext = null

## Execute fade-out only (for orchestrator sequencing)
##
## Returns a Signal that emits when fade-out completes
func execute_fade_out(overlay: CanvasLayer) -> Signal:
	var color_rect: ColorRect = _find_color_rect(overlay)
	if color_rect == null:
		push_error("FadeTransition: TransitionColorRect not found in overlay")
		# Return a dummy signal that emits immediately
		var dummy_signal := Signal()
		call_deferred("emit_signal", "dummy_completed")
		return dummy_signal

	# Set fade color
	color_rect.color = fade_color

	# Block input during transition
	if block_input:
		color_rect.mouse_filter = Control.MOUSE_FILTER_STOP

	# Ensure transition advances even if the SceneTree is paused
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	color_rect.process_mode = Node.PROCESS_MODE_ALWAYS

	# Create fade-out tween with custom config to match exports
	var config := U_TweenManager.TweenConfig.new()
	config.ease_type = easing_type
	config.trans_type = transition_type
	_tween = U_TweenManager.create_transition_tween(overlay, config)

	# Fade out (alpha 0 → 1)
	var half_duration: float = duration / 2.0
	_tween.tween_property(color_rect, "modulate:a", 1.0, half_duration).from(0.0)

	return _tween.finished

## Execute fade-in only (for orchestrator sequencing)
##
## Returns a Signal that emits when fade-in completes
func execute_fade_in(overlay: CanvasLayer, callback: Callable) -> Signal:
	var color_rect: ColorRect = _find_color_rect(overlay)
	if color_rect == null:
		push_error("FadeTransition: TransitionColorRect not found in overlay")
		if callback.is_valid():
			callback.call()
		# Return a dummy signal
		var dummy_signal := Signal()
		call_deferred("emit_signal", "dummy_completed")
		return dummy_signal

	# Create fade-in tween with custom config
	var config := U_TweenManager.TweenConfig.new()
	config.ease_type = easing_type
	config.trans_type = transition_type
	_tween = U_TweenManager.create_transition_tween(overlay, config)

	# Fade in (alpha 1 → 0)
	var half_duration: float = duration / 2.0
	_tween.tween_property(color_rect, "modulate:a", 0.0, half_duration).from(1.0)

	# Restore input and process modes on completion
	_tween.finished.connect(func() -> void:
		color_rect.mouse_filter = Control.MOUSE_FILTER_PASS
		overlay.process_mode = Node.PROCESS_MODE_INHERIT
		color_rect.process_mode = Node.PROCESS_MODE_INHERIT
		if callback.is_valid():
			callback.call()
		_tween = null
	)

	return _tween.finished

## Execute fade transition
##
## @param overlay: CanvasLayer containing TransitionColorRect
## @param callback: Callable to invoke when transition completes
func execute(overlay: CanvasLayer, callback: Callable) -> void:
	if overlay == null:
		if callback.is_valid():
			callback.call()
		return

	# Find TransitionColorRect
	var color_rect: ColorRect = _find_color_rect(overlay)
	if color_rect == null:
		push_error("FadeTransition: TransitionColorRect not found in overlay")
		if callback.is_valid():
			callback.call()
		return

	# Set fade color
	color_rect.color = fade_color

	# Save original mouse filter for restoration
	var original_mouse_filter := color_rect.mouse_filter
	if block_input:
		color_rect.mouse_filter = Control.MOUSE_FILTER_STOP

	# Handle zero duration
	if duration <= 0.0:
		# Instant transition - call callbacks immediately
		if mid_transition_callback.is_valid():
			mid_transition_callback.call()
		color_rect.mouse_filter = original_mouse_filter
		if callback.is_valid():
			callback.call()
		return

	# Create pausable tween with automatic process mode save/restore
	# Uses TweenContext to handle the common save-ALWAYS-restore pattern
	var config := U_TweenManager.TweenConfig.new()
	config.ease_type = easing_type
	config.trans_type = transition_type
	_tween_context = U_TweenManager.create_pausable_tween(overlay, [overlay, color_rect], config)
	_tween = _tween_context.tween

	# On finish: restore process modes and input, call completion
	_tween.finished.connect(func() -> void:
		color_rect.mouse_filter = original_mouse_filter
		_tween_context.restore_process_modes()
		if callback.is_valid():
			callback.call()
		_tween = null
		_tween_context = null
	)

	# Calculate half duration
	var half_duration: float = duration / 2.0

	# Fade out (alpha 0 → 1)
	_tween.tween_property(color_rect, "modulate:a", 1.0, half_duration).from(0.0)

	# Mid-point callback - call synchronously (orchestrator handles async sequencing)
	_tween.tween_callback(func() -> void:
		if mid_transition_callback.is_valid():
			mid_transition_callback.call()
	)

	# Fade in (alpha 1 → 0)
	_tween.tween_property(color_rect, "modulate:a", 0.0, half_duration).from(1.0)

	# Completion handled via `finished` connection above.

## Find TransitionColorRect in overlay
func _find_color_rect(overlay: CanvasLayer) -> ColorRect:
	for child in overlay.get_children():
		if child is ColorRect and child.name == "TransitionColorRect":
			return child as ColorRect
	return null

## Clean up Tween reference
func _cleanup_tween() -> void:
	# Deprecated: do not kill the tween prematurely; it prevents `finished` from emitting.
	# Keep this method for API compatibility but perform no action.
	return

## Get duration of transition
func get_duration() -> float:
	return duration
