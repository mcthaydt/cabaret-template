extends "res://scripts/scene_management/transitions/base_transition_effect.gd"
class_name LoadingScreenTransition

## Loading screen transition effect
##
## Shows a loading screen with progress bar, tips, and spinner during scene transitions.
## Supports both real progress (via progress_provider callback) and fake progress (Tween animation).
## Enforces a minimum display duration to prevent jarring flashes.
##
## Adapter Pattern:
## - If progress_provider is set and valid, uses real async loading progress
## - Otherwise, uses fake Tween-based progress animation
##
## Sequence:
## 1. Show loading screen, display random tip
## 2. Animate progress 0→50% (or use real progress updates)
## 3. Call mid_transition_callback at 50% (scene swap)
## 4. Animate 50→100%, enforce min_duration
## 5. Hide loading screen, call completion callback

## Minimum display duration in seconds (prevents jarring flashes)
@export var min_duration: float = 1.5

## Loading tips pool (random tip shown each load)
var loading_tips: Array[String] = [
	"Tip: Press ESC to pause the game",
	"Tip: Use WASD to move and Space to jump",
	"Tip: Explore thoroughly to find hidden areas",
	"Tip: Your progress is automatically saved",
	"Tip: Adjust settings anytime from the pause menu"
]

## Progress provider callback (for real async loading)
## Signature: func() -> float (returns 0.0-1.0 progress)
## If not set or invalid, uses fake progress animation
var progress_provider: Callable

## Optional callback at mid-point (when progress reaches 50%)
var mid_transition_callback: Callable

## Internal references
var _loading_overlay: CanvasLayer = null
var _loading_screen: Control = null
var _progress_bar: ProgressBar = null
var _tip_label: Label = null
var _status_label: Label = null
var _tween: Tween = null
var _start_time: float = 0.0

## Execute loading screen transition
##
## @param overlay: CanvasLayer - LoadingOverlay container
## @param callback: Callable - Completion callback
func execute(overlay: CanvasLayer, callback: Callable) -> void:
	if overlay == null:
		print_debug("LoadingScreenTransition: overlay is null, skipping transition")
		if callback.is_valid():
			callback.call()
		return

	_loading_overlay = overlay
	_start_time = Time.get_ticks_msec() / 1000.0

	# Find loading screen UI
	_loading_screen = _find_loading_screen(overlay)
	if _loading_screen == null:
		push_error("LoadingScreenTransition: LoadingScreen not found in overlay")
		if callback.is_valid():
			callback.call()
		return

	# Find UI elements
	_progress_bar = _find_progress_bar(_loading_screen)
	_tip_label = _find_tip_label(_loading_screen)
	_status_label = _find_status_label(_loading_screen)

	if _progress_bar == null:
		push_warning("LoadingScreenTransition: ProgressBar not found, progress won't be visible")

	# Ensure transition runs even if SceneTree is paused
	var original_overlay_mode: int = overlay.process_mode
	var original_screen_mode: int = _loading_screen.process_mode
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_loading_screen.process_mode = Node.PROCESS_MODE_ALWAYS

	# Show loading overlay
	overlay.visible = true

	# Display random tip
	if _tip_label:
		_tip_label.text = _get_random_tip()

	# Reset progress bar
	if _progress_bar:
		_progress_bar.value = 0.0

	# Check if we have real progress provider
	if progress_provider.is_valid():
		# Use real progress from async loading
		_execute_with_real_progress(overlay, callback, original_overlay_mode, original_screen_mode)
	else:
		# Use fake Tween-based progress
		_execute_with_fake_progress(overlay, callback, original_overlay_mode, original_screen_mode)

## Execute with real async loading progress
func _execute_with_real_progress(overlay: CanvasLayer, callback: Callable, original_overlay_mode: int, original_screen_mode: int) -> void:
	# Poll progress_provider until complete
	# This will be implemented in Phase 8 when we add ResourceLoader.load_threaded_*
	# For now, fall back to fake progress
	push_warning("LoadingScreenTransition: Real progress not yet implemented, using fake progress")
	_execute_with_fake_progress(overlay, callback, original_overlay_mode, original_screen_mode)

## Execute with fake Tween-based progress animation
func _execute_with_fake_progress(overlay: CanvasLayer, callback: Callable, original_overlay_mode: int, original_screen_mode: int) -> void:
	if _progress_bar == null:
		# No progress bar, just enforce minimum duration then complete
		_enforce_minimum_duration_and_complete(overlay, callback, original_overlay_mode, original_screen_mode)
		return

	# Create Tween for progress animation
	_tween = overlay.create_tween()
	_tween.set_ease(Tween.EASE_IN_OUT)
	_tween.set_trans(Tween.TRANS_CUBIC)

	# Phase 1: Animate 0→50% (fast preparation phase)
	var first_half_duration: float = min_duration * 0.3  # 30% of time for first half
	_tween.tween_property(_progress_bar, "value", 50.0, first_half_duration).from(0.0)

	# Phase 2: Mid-transition callback (scene swap at 50%)
	_tween.tween_callback(func() -> void:
		if mid_transition_callback.is_valid():
			mid_transition_callback.call()
	)

	# Phase 3: Animate 50→100% (slower actual load phase)
	var second_half_duration: float = min_duration * 0.5  # 50% of time for second half
	_tween.tween_property(_progress_bar, "value", 100.0, second_half_duration).from(50.0)

	# Phase 4: Enforce minimum duration and complete
	_tween.finished.connect(func() -> void:
		_enforce_minimum_duration_and_complete(overlay, callback, original_overlay_mode, original_screen_mode)
	)

## Enforce minimum duration before hiding loading screen
func _enforce_minimum_duration_and_complete(overlay: CanvasLayer, callback: Callable, original_overlay_mode: int, original_screen_mode: int) -> void:
	var elapsed: float = (Time.get_ticks_msec() / 1000.0) - _start_time
	var remaining: float = min_duration - elapsed

	if remaining > 0.0:
		# Wait remaining time using timer connection
		if overlay.get_tree():
			var timer := overlay.get_tree().create_timer(remaining, true, false, true)
			timer.timeout.connect(func() -> void:
				_complete_transition(overlay, callback, original_overlay_mode, original_screen_mode)
			)
		else:
			# No tree available, complete immediately
			_complete_transition(overlay, callback, original_overlay_mode, original_screen_mode)
	else:
		# Already exceeded minimum duration, complete immediately
		_complete_transition(overlay, callback, original_overlay_mode, original_screen_mode)

## Complete the transition and clean up
func _complete_transition(overlay: CanvasLayer, callback: Callable, original_overlay_mode: int, original_screen_mode: int) -> void:
	# Hide loading overlay
	overlay.visible = false

	# Restore process modes
	overlay.process_mode = original_overlay_mode
	if _loading_screen:
		_loading_screen.process_mode = original_screen_mode

	# Call completion callback
	if callback.is_valid():
		callback.call()

	# Clear references
	_tween = null
	_loading_overlay = null
	_loading_screen = null
	_progress_bar = null
	_tip_label = null
	_status_label = null

## Update progress manually (for real async loading)
##
## @param progress: float - Progress value 0.0-100.0
func update_progress(progress: float) -> void:
	if _progress_bar:
		_progress_bar.value = clamp(progress, 0.0, 100.0)

## Get a random loading tip
##
## @return String - Random tip from pool
func _get_random_tip() -> String:
	if loading_tips.is_empty():
		return "Loading..."

	var index: int = randi() % loading_tips.size()
	return loading_tips[index]

## Find LoadingScreen Control in overlay
func _find_loading_screen(overlay: CanvasLayer) -> Control:
	for child in overlay.get_children():
		if child is Control and child.name == "LoadingScreen":
			return child as Control
	return null

## Find ProgressBar in loading screen
func _find_progress_bar(loading_screen: Control) -> ProgressBar:
	# Search in VBoxContainer
	var center_container: CenterContainer = loading_screen.get_node_or_null("CenterContainer")
	if center_container:
		var vbox: VBoxContainer = center_container.get_node_or_null("VBoxContainer")
		if vbox:
			var progress_bar: ProgressBar = vbox.get_node_or_null("ProgressBar")
			if progress_bar:
				return progress_bar
	return null

## Find TipLabel in loading screen
func _find_tip_label(loading_screen: Control) -> Label:
	var center_container: CenterContainer = loading_screen.get_node_or_null("CenterContainer")
	if center_container:
		var vbox: VBoxContainer = center_container.get_node_or_null("VBoxContainer")
		if vbox:
			var tip_label: Label = vbox.get_node_or_null("TipLabel")
			if tip_label:
				return tip_label
	return null

## Find StatusLabel in loading screen
func _find_status_label(loading_screen: Control) -> Label:
	var center_container: CenterContainer = loading_screen.get_node_or_null("CenterContainer")
	if center_container:
		var vbox: VBoxContainer = center_container.get_node_or_null("VBoxContainer")
		if vbox:
			var status_label: Label = vbox.get_node_or_null("StatusLabel")
			if status_label:
				return status_label
	return null

## Get duration of transition
func get_duration() -> float:
	return min_duration
