extends GutTest

const LoadingScreenTransition = preload("res://scripts/scene_management/transitions/loading_screen_transition.gd")

var _overlay: CanvasLayer

func before_each() -> void:
	_overlay = CanvasLayer.new()
	add_child_autofree(_overlay)

func after_each() -> void:
	_overlay = null

## Real-progress path: mid callback should fire immediately and progress should advance
func test_loading_real_progress_mid_callback_and_updates() -> void:
	var transition := LoadingScreenTransition.new()
	transition.min_duration = 0.05

	var progress: Array = [0.0]
	# Provide real progress via provider
	transition.progress_provider = func() -> float:
		return progress[0]

	var mid_called: Array = [false]
	transition.mid_transition_callback = func() -> void:
		mid_called[0] = true

	var completed: Array = [false]
	var completion := func() -> void:
		completed[0] = true

	transition.execute(_overlay, completion)
	await get_tree().process_frame

	# Mid-callback should already be fired to start loading
	assert_true(mid_called[0], "Mid-transition callback should fire immediately for real progress")

	# Advance progress to completion and wait
	progress[0] = 1.0
	var start_ms: int = Time.get_ticks_msec()
	while not completed[0] and (Time.get_ticks_msec() - start_ms) < 800:
		await get_tree().process_frame

	assert_true(completed[0], "Transition should complete when progress reaches 1.0")

## Fake path (no provider): should enforce minimum duration
func test_loading_fake_progress_enforces_min_duration() -> void:
	var transition := LoadingScreenTransition.new()
	transition.min_duration = 0.1

	var completed: Array = [false]
	var completion := func() -> void:
		completed[0] = true

	var start_sec: float = Time.get_ticks_msec() / 1000.0
	transition.execute(_overlay, completion)

	# Wait for completion or timeout
	var start_ms: int = Time.get_ticks_msec()
	while not completed[0] and (Time.get_ticks_msec() - start_ms) < 1200:
		await get_tree().process_frame

	var elapsed: float = (Time.get_ticks_msec() / 1000.0) - start_sec
	assert_true(completed[0], "Fake loading should complete")
	assert_true(elapsed >= transition.min_duration - 0.01, "Fake loading should last at least min_duration")

