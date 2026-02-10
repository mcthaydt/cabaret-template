extends "res://scripts/scene_management/transitions/base_transition_effect.gd"
class_name Trans_LoadingScreen

const LOADING_SCREEN_SCENE := preload("res://scenes/ui/hud/ui_loading_screen.tscn")

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
var _temporarily_hidden_hud_nodes: Array[Node] = []

## Execute loading screen transition
##
## @param overlay: CanvasLayer - LoadingOverlay container
## @param callback: Callable - Completion callback
func execute(overlay: CanvasLayer, callback: Callable) -> void:
	if overlay == null:
		# Even without an overlay, we still need to perform the scene swap
		if mid_transition_callback.is_valid():
			await mid_transition_callback.call()
		if callback.is_valid():
			callback.call()
		return

	_loading_overlay = overlay
	_start_time = Time.get_ticks_msec() / 1000.0

	_temporarily_hidden_hud_nodes.clear()
	_hide_hud_layers()

	# Find loading screen UI
	_loading_screen = _find_loading_screen(overlay)
	if _loading_screen == null:
		_loading_screen = _ensure_loading_screen(overlay)
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
		await _execute_with_real_progress(overlay, callback, original_overlay_mode, original_screen_mode)
	else:
		# Use fake Tween-based progress
		await _execute_with_fake_progress(overlay, callback, original_overlay_mode, original_screen_mode)

## Execute with real async loading progress (Phase 8)
func _execute_with_real_progress(overlay: CanvasLayer, callback: Callable, original_overlay_mode: int, original_screen_mode: int) -> void:
	# Poll progress_provider until complete
	var mid_transition_fired: bool = false

	# Update status label
	if _status_label:
		_status_label.text = "Loading..."

	# Kick off scene swap immediately so async loading can report real progress
	if not mid_transition_fired and mid_transition_callback.is_valid():
		await mid_transition_callback.call()
		# Guard against overlay being freed during scene swap
		if is_instance_valid(overlay) and overlay.get_tree():
			_hide_hud_layers()
		mid_transition_fired = true

	while true:
		# Get current progress from provider
		var current_progress: float = 0.0
		if progress_provider.is_valid():
			current_progress = progress_provider.call()
		else:
			# Provider became invalid mid-transition, abort
			push_error("LoadingScreenTransition: Progress provider became invalid mid-transition")
			break

		# Update progress bar (convert 0.0-1.0 to 0.0-100.0)
		if _progress_bar:
			_progress_bar.value = current_progress * 100.0

		# Trigger mid-transition callback:
		# - At 50% threshold for async loading
		# - Immediately if progress hasn't changed (sync loading - needs callback to set progress)
		# Callback already fired above to start loading; no-op here

		# Check if complete
		if current_progress >= 1.0:
			break

		# Wait one frame before next poll
		# Guard against overlay being freed during polling
		if not is_instance_valid(overlay) or not overlay.get_tree():
			break
		await overlay.get_tree().process_frame

	# Enforce minimum duration before completing
	# Guard against overlay being freed during execution
	if not is_instance_valid(overlay):
		if callback.is_valid():
			callback.call()
		return
	await _enforce_minimum_duration_and_complete(overlay, callback, original_overlay_mode, original_screen_mode)

## Execute with fake Tween-based progress animation
func _execute_with_fake_progress(overlay: CanvasLayer, callback: Callable, original_overlay_mode: int, original_screen_mode: int) -> void:
	if _progress_bar == null:
		# No progress bar, just enforce minimum duration then complete
		# Guard against overlay being freed
		if not is_instance_valid(overlay):
			if callback.is_valid():
				callback.call()
			return
		await _enforce_minimum_duration_and_complete(overlay, callback, original_overlay_mode, original_screen_mode)
		return

	# Create Tween for progress animation using U_TweenManager for standard config
	_tween = U_TweenManager.create_transition_tween(overlay)

	# Phase 1: Animate 0→50% (fast preparation phase)
	var first_half_duration: float = min_duration * 0.3 # 30% of time for first half
	_tween.tween_property(_progress_bar, "value", 50.0, first_half_duration).from(0.0)

	# Phase 2: Mid-transition callback (scene swap at 50%)
	_tween.tween_callback(func() -> void:
		if mid_transition_callback.is_valid():
			await mid_transition_callback.call()
		_hide_hud_layers()
	)

	# Phase 3: Animate 50→100% (slower actual load phase)
	var second_half_duration: float = min_duration * 0.5 # 50% of time for second half
	_tween.tween_property(_progress_bar, "value", 100.0, second_half_duration).from(50.0)

	# Wait for tween to complete before calling completion
	await _tween.finished

	# Phase 4: Enforce minimum duration and complete
	await _enforce_minimum_duration_and_complete(overlay, callback, original_overlay_mode, original_screen_mode)

## Enforce minimum duration before hiding loading screen
func _enforce_minimum_duration_and_complete(overlay: CanvasLayer, callback: Callable, original_overlay_mode: int, original_screen_mode: int) -> void:
	var elapsed: float = (Time.get_ticks_msec() / 1000.0) - _start_time
	var remaining: float = min_duration - elapsed

	if remaining > 0.0:
		# If the overlay was freed while we were loading, skip any waiting and
		# complete immediately to avoid accessing a dead SceneTree.
		if not is_instance_valid(overlay):
			if callback.is_valid():
				callback.call()
			return

		# Wait remaining time
		if overlay.get_tree():
			# In headless mode, skip wall-clock based waiting because physics frames
			# can process much faster than real-time, causing test timeouts.
			# The minimum duration requirement is primarily for visual polish.
			if OS.has_feature("headless") or DisplayServer.get_name() == "headless":
				# Just yield a few frames to allow state updates to propagate
				await overlay.get_tree().process_frame
				await overlay.get_tree().process_frame
			else:
				# Use timer in normal mode for wall-clock based minimum duration
				var timer := overlay.get_tree().create_timer(remaining, true, false, true)
				await timer.timeout
		# else: No tree available, complete immediately (no wait)

	# Complete transition after minimum duration enforced
	# Guard against overlay being freed while waiting
	if not is_instance_valid(overlay):
		if callback.is_valid():
			callback.call()
		return

	_complete_transition(overlay, callback, original_overlay_mode, original_screen_mode)

## Complete the transition and clean up
func _complete_transition(overlay: CanvasLayer, callback: Callable, original_overlay_mode: int, original_screen_mode: int) -> void:
	# Hide loading overlay (guard against freed overlay)
	if is_instance_valid(overlay):
		overlay.visible = false

	_restore_hidden_hud_layers()

	# Restore process modes
	if is_instance_valid(overlay):
		overlay.process_mode = original_overlay_mode as Node.ProcessMode
	if _loading_screen and is_instance_valid(_loading_screen):
		_loading_screen.process_mode = original_screen_mode as Node.ProcessMode

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
	_temporarily_hidden_hud_nodes.clear()

## Update progress manually (for real async loading)
##
## @param progress: float - Progress value 0.0-100.0
func update_progress(progress: float) -> void:
	if _progress_bar:
		_progress_bar.value = clamp(progress, 0.0, 100.0)

## Hide HUD CanvasLayers while the loading screen is active
func _hide_hud_layers() -> void:
	var hud := _resolve_hud_controller()
	if hud == null:
		return

	_toggle_visibility(hud, false)
	if not _temporarily_hidden_hud_nodes.has(hud):
		_temporarily_hidden_hud_nodes.append(hud)

## Restore previously hidden HUD CanvasLayers
func _restore_hidden_hud_layers() -> void:
	if _temporarily_hidden_hud_nodes.is_empty():
		return

	for canvas_item in _temporarily_hidden_hud_nodes:
		if is_instance_valid(canvas_item):
			_toggle_visibility(canvas_item, true)
	_temporarily_hidden_hud_nodes.clear()

## Get a random loading tip
##
## @return String - Random tip from pool
func _get_random_tip() -> String:
	if loading_tips.is_empty():
		return "Loading..."

	var index: int = randi() % loading_tips.size()
	return loading_tips[index]

func _resolve_hud_controller() -> CanvasLayer:
	var scene_manager := U_ServiceLocator.try_get_service(StringName("scene_manager")) as I_SceneManager
	if scene_manager != null:
		var hud := scene_manager.get_hud_controller() as CanvasLayer
		if hud != null and is_instance_valid(hud):
			return hud
	return null

func _toggle_visibility(node: Node, is_visible: bool) -> void:
	if node == null:
		return
	if "visible" in node:
		node.set("visible", is_visible)
	elif node.has_method("show") and node.has_method("hide"):
		if is_visible:
			node.call("show")
		else:
			node.call("hide")

## Find LoadingScreen Control in overlay
func _find_loading_screen(overlay: CanvasLayer) -> Control:
	for child in overlay.get_children():
		if child is Control and child.name == "LoadingScreen":
			return child as Control
	return null

## Ensure a LoadingScreen instance exists on the overlay
func _ensure_loading_screen(overlay: CanvasLayer) -> Control:
	if LOADING_SCREEN_SCENE == null:
		return null

	var instance: Node = LOADING_SCREEN_SCENE.instantiate()
	if instance == null or not (instance is Control):
		return null

	var control_instance := instance as Control
	overlay.add_child(control_instance)
	return control_instance

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
