extends GutTest

const Trans_LoadingScreen = preload("res://scripts/scene_management/transitions/trans_loading_screen.gd")
const U_TransitionTestHelpers = preload("res://tests/helpers/u_transition_test_helpers.gd")

var _overlay: CanvasLayer

func before_each() -> void:
	_overlay = CanvasLayer.new()
	add_child_autofree(_overlay)

func after_each() -> void:
	_overlay = null

## Real-progress path: mid callback should fire immediately and progress should advance
func test_loading_real_progress_mid_callback_and_updates() -> void:
	var transition := Trans_LoadingScreen.new()
	transition.min_duration = 0.05

	# Note: progress uses Array pattern intentionally - it's a mutable float value, not completion tracking
	var progress: Array = [0.0]
	# Provide real progress via provider
	transition.progress_provider = func() -> float:
		return progress[0]

	var mid_tracker := U_TransitionTestHelpers.create_completion_tracker()
	transition.mid_transition_callback = mid_tracker.get_callback()

	var completion_tracker := U_TransitionTestHelpers.create_completion_tracker()

	transition.execute(_overlay, completion_tracker.get_callback())
	await get_tree().process_frame

	# Mid-callback should already be fired to start loading
	assert_true(mid_tracker.is_complete, "Mid-transition callback should fire immediately for real progress")

	# Advance progress to completion and wait
	progress[0] = 1.0
	var ok := await completion_tracker.wait(get_tree(), 0.8)

	assert_true(ok and completion_tracker.is_complete, "Transition should complete when progress reaches 1.0")

## Fake path (no provider): should enforce minimum duration
## @warning: Skipped in headless - wall-clock timing unreliable
func test_loading_fake_progress_enforces_min_duration() -> void:
	var display_name := DisplayServer.get_name().to_lower()
	if OS.has_feature("headless") or OS.has_feature("server") or display_name == "headless" or display_name == "dummy":
		pending("Skipped: Wall-clock timing unreliable in headless mode")
		return

	var transition := Trans_LoadingScreen.new()
	transition.min_duration = 0.1

	var tracker := U_TransitionTestHelpers.create_completion_tracker()

	var start_sec: float = Time.get_ticks_msec() / 1000.0
	transition.execute(_overlay, tracker.get_callback())

	# Wait for completion or timeout
	var ok := await tracker.wait(get_tree(), 1.2)

	var elapsed: float = (Time.get_ticks_msec() / 1000.0) - start_sec
	assert_true(ok and tracker.is_complete, "Fake loading should complete")
	assert_true(elapsed >= transition.min_duration - 0.01, "Fake loading should last at least min_duration")
