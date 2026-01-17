class_name U_TransitionOrchestrator
extends RefCounted

## U_TransitionOrchestrator - Manages scene transition execution and lifecycle
##
## Phase 10B-2 (T135): Extracted from M_SceneManager to reduce complexity
## Handles transition state machine, effect execution, and scene swap sequencing
##
## Responsibilities:
## - Execute transition effects (fade/loading/instant)
## - Manage scene loading strategies (sync/async/cached)
## - Coordinate callbacks for scene swap and completion
## - Track progress for loading transitions
##
## Usage:
##   var orchestrator := U_TransitionOrchestrator.new()
##   orchestrator.execute_transition(request, scene_node, callbacks)

const U_TRANSITION_FACTORY := preload("res://scripts/scene_management/u_transition_factory.gd")
const Trans_Fade := preload("res://scripts/scene_management/transitions/trans_fade.gd")
const Trans_LoadingScreen := preload("res://scripts/scene_management/transitions/trans_loading_screen.gd")
const U_SCENE_REGISTRY := preload("res://scripts/scene_management/u_scene_registry.gd")

## Transition state
enum State {
	IDLE,
	EXECUTING,
	SWAPPING,
	COMPLETING
}

var _state: State = State.IDLE
var _current_progress: float = 0.0

## Execute a transition effect with coordinated callbacks
##
## Parameters:
##   transition_type: String - Type of transition ("fade", "loading", "instant")
##   scene_swap_callback: Callable() - Called when scene should be swapped
##   completion_callback: Callable() - Called when transition finishes
##   overlays: Dictionary with:
##     - transition_overlay: CanvasLayer for fade transitions
##     - loading_overlay: CanvasLayer for loading transitions
##   config: Dictionary with optional configuration (duration, etc.)
##
func execute_transition_effect(transition_type: String, scene_swap_callback: Callable, completion_callback: Callable, overlays: Dictionary, config: Dictionary = {}) -> void:
	_state = State.EXECUTING
	_current_progress = 0.0

	# Create transition effect via factory
	var transition_effect = U_TRANSITION_FACTORY.create_transition(transition_type)

	# Fallback to instant if transition type not found
	if transition_effect == null:
		transition_effect = U_TRANSITION_FACTORY.create_transition("instant")

	# Configure transition defaults (moved from M_SceneManager._configure_transition)
	# Fade transitions use shorter duration for responsive gameplay
	if transition_effect is Trans_Fade:
		var fade := transition_effect as Trans_Fade
		fade.duration = config.get("duration", 0.2) as float  # Default 0.2s for fast transitions
	elif transition_effect is Trans_LoadingScreen:
		var loading := transition_effect as Trans_LoadingScreen
		loading.min_duration = config.get("min_duration", 1.5) as float

	# Track completion state
	var transition_complete: Array = [false]

	# Wrap completion callback to track state
	var wrapped_completion := func() -> void:
		_state = State.COMPLETING
		transition_complete[0] = true
		if completion_callback != null and completion_callback.is_valid():
			completion_callback.call()

	# Wrap scene swap callback to track state and await async operations
	var wrapped_swap := func() -> void:
		_state = State.SWAPPING
		if scene_swap_callback != null and scene_swap_callback.is_valid():
			await scene_swap_callback.call()

	# Execute transition based on type
	if transition_effect is Trans_Fade:
		await _execute_fade_transition(transition_effect, overlays.get("transition_overlay"), wrapped_swap, wrapped_completion)
	elif transition_effect is Trans_LoadingScreen:
		var empty_progress := func(_p: float) -> void: pass
		_execute_loading_transition(transition_effect, overlays.get("loading_overlay"), wrapped_swap, wrapped_completion, empty_progress)
	else:
		await _execute_instant_transition(transition_effect, overlays.get("transition_overlay"), wrapped_swap, wrapped_completion)

	# Wait for transition to complete
	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		while not transition_complete[0]:
			await tree.process_frame

	# Finalize
	_state = State.IDLE

## Execute fade transition with async scene swap support
##
## The fade transition needs special handling because the scene swap can be async
## (scene loading, spawning, etc.), and we need the fade-in to wait for it to complete.
## We manually sequence: fade-out → async scene swap → fade-in
func _execute_fade_transition(effect: Trans_Fade, overlay: CanvasLayer, scene_swap: Callable, complete: Callable) -> void:
	# Handle null overlay gracefully (test environments may not have overlay set up)
	if overlay == null:
		push_warning("U_TransitionOrchestrator: overlay is null, executing instant transition")
		# Just do the scene swap and complete immediately
		await scene_swap.call()
		if complete.is_valid():
			complete.call()
		return

	# Execute fade-out and wait for completion
	var fade_out_signal := effect.execute_fade_out(overlay)
	if fade_out_signal != null:
		await fade_out_signal

	# Execute async scene swap
	await scene_swap.call()

	# Execute fade-in and wait for completion
	var fade_in_signal := effect.execute_fade_in(overlay, complete)
	if fade_in_signal != null:
		await fade_in_signal

## Execute loading screen transition
func _execute_loading_transition(effect: Trans_LoadingScreen, overlay: CanvasLayer, scene_swap: Callable, complete: Callable, progress: Callable) -> void:
	effect.mid_transition_callback = scene_swap
	# NOTE: Do NOT set progress_provider here. When progress_provider is set,
	# Trans_LoadingScreen uses real progress mode which polls the provider until >= 1.0.
	# Since the orchestrator passes an empty progress callback, the provider would
	# always return 0.0, causing an infinite loop. By NOT setting progress_provider,
	# Trans_LoadingScreen falls back to fake Tween-based progress animation which
	# completes reliably.

	# Use completion tracking to properly await the loading transition
	# Without this, the orchestrator returns immediately and the overlay can be freed
	# while Trans_LoadingScreen is still running its async operations
	var loading_complete: Array = [false]
	var wrapped_complete := func() -> void:
		loading_complete[0] = true
		if complete != null and complete.is_valid():
			complete.call()

	effect.execute(overlay, wrapped_complete)

	# Wait for loading transition to complete
	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		while not loading_complete[0]:
			await tree.process_frame

## Execute instant transition
func _execute_instant_transition(effect, overlay: CanvasLayer, scene_swap: Callable, complete: Callable) -> void:
	# Instant transitions must await scene swap so completion fires after spawn/async work.
	if effect != null:
		effect.execute(overlay, func() -> void: pass)

	if scene_swap != null and scene_swap.is_valid():
		await scene_swap.call()

	if complete != null and complete.is_valid():
		complete.call()

## Create progress callback for loading transitions
func _create_progress_callback(transition_effect, use_cached: bool) -> Callable:
	var current_progress: Array = [0.0]

	if transition_effect is Trans_LoadingScreen and not use_cached:
		var loading_transition := transition_effect as Trans_LoadingScreen
		return func(progress: float) -> void:
			var normalized_progress: float = clamp(progress, 0.0, 1.0)
			current_progress[0] = normalized_progress
			loading_transition.update_progress(normalized_progress * 100.0)
	else:
		# Cached scene or non-loading transition
		return func(progress: float) -> void:
			current_progress[0] = clamp(progress, 0.0, 1.0)

## Configure transition effect based on type
func _configure_transition(effect, transition_type: String) -> void:
	# Transition-specific configuration can be added here
	# Currently handled by factory, but kept for future extensibility
	pass

## Get current transition state
func get_state() -> State:
	return _state

## Get current progress (0.0 to 1.0)
func get_progress() -> float:
	return _current_progress
