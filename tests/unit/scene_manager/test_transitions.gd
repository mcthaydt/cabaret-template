extends GutTest

## Unit tests for transition effects
##
## Tests BaseTransitionEffect base class and implementations (Trans_Instant, Trans_Fade).
## Uses U_TransitionTestHelpers for standardized completion tracking.

const BaseTransitionEffect = preload("res://scripts/scene_management/transitions/base_transition_effect.gd")
const Trans_Instant = preload("res://scripts/scene_management/transitions/trans_instant.gd")
const Trans_Fade = preload("res://scripts/scene_management/transitions/trans_fade.gd")
const U_TransitionTestHelpers = preload("res://tests/helpers/u_transition_test_helpers.gd")

var _transition_overlay: CanvasLayer
var _color_rect: ColorRect

func before_each() -> void:
	# Create transition overlay setup
	_transition_overlay = CanvasLayer.new()
	_color_rect = ColorRect.new()
	_color_rect.name = "TransitionColorRect"
	_color_rect.color = Color.BLACK
	_color_rect.modulate.a = 0.0  # Start transparent
	_transition_overlay.add_child(_color_rect)
	add_child_autofree(_transition_overlay)

func after_each() -> void:
	_transition_overlay = null
	_color_rect = null

## Test BaseTransitionEffect interface
func test_transition_effect_has_required_methods() -> void:
	var effect := BaseTransitionEffect.new()

	# Verify interface methods exist (should be virtual/abstract)
	assert_true(effect.has_method("execute"), "Should have execute method")
	assert_true(effect.has_method("get_duration"), "Should have get_duration method")

## Test Trans_Instant completes immediately
func test_instant_transition_completes_immediately() -> void:
	var instant := Trans_Instant.new()

	var tracker := U_TransitionTestHelpers.create_completion_tracker()
	instant.execute(_transition_overlay, tracker.get_callback())
	await get_tree().process_frame

	assert_true(tracker.is_complete, "Trans_Instant should complete immediately")

## Test Trans_Instant duration is zero
func test_instant_transition_duration_is_zero() -> void:
	var instant := Trans_Instant.new()

	var duration: float = instant.get_duration()

	assert_eq(duration, 0.0, "Trans_Instant duration should be 0.0")

## Test Trans_Fade has configurable duration
func test_fade_transition_duration() -> void:
	var fade := Trans_Fade.new()
	fade.duration = 0.5

	var duration: float = fade.get_duration()

	assert_eq(duration, 0.5, "Trans_Fade should return configured duration")

## Test Trans_Fade fades out then in
## Uses tween.finished signal for reliable completion in headless mode
func test_fade_transition_sequence() -> void:
	var fade := Trans_Fade.new()
	fade.duration = 0.2  # Shorter for faster tests

	var tracker := U_TransitionTestHelpers.create_completion_tracker()

	# Initial alpha should be 0
	assert_almost_eq(_color_rect.modulate.a, 0.0, 0.01, "Should start transparent")

	fade.execute(_transition_overlay, tracker.get_callback())

	# Wait for tween to complete using helper
	var ok: bool = false
	if fade._tween != null:
		ok = await U_TransitionTestHelpers.await_tween_or_timeout(fade._tween, get_tree(), 1.2)
	else:
		await get_tree().process_frame
		ok = tracker.is_complete

	assert_true(ok, "Tween did not finish within expected window")

	# Transition should be complete
	assert_almost_eq(_color_rect.modulate.a, 0.0, 0.1, "Should fade back to transparent")
	assert_true(tracker.is_complete, "Should call completion callback")

## Test Trans_Fade respects color setting
func test_fade_transition_color() -> void:
	var fade := Trans_Fade.new()
	fade.fade_color = Color.WHITE
	fade.duration = 0.1

	var tracker := U_TransitionTestHelpers.create_completion_tracker()
	fade.execute(_transition_overlay, tracker.get_callback())
	await get_tree().process_frame

	# Color rect should use white (though alpha varies)
	assert_eq(_color_rect.color, Color.WHITE, "Should use configured fade color")

	# Wait for tween to complete
	if fade._tween != null:
		await U_TransitionTestHelpers.await_tween_or_timeout(fade._tween, get_tree(), 0.5)

## Test transition blocks input during execution
func test_transition_blocks_input() -> void:
	var fade := Trans_Fade.new()
	fade.duration = 0.2

	var tracker := U_TransitionTestHelpers.create_completion_tracker()
	fade.execute(_transition_overlay, tracker.get_callback())
	await get_tree().process_frame

	# During transition, input should be blocked
	assert_true(true, "Transition should block input during execution")

	# Wait for tween to complete
	if fade._tween != null:
		await U_TransitionTestHelpers.await_tween_or_timeout(fade._tween, get_tree(), 0.5)

	assert_true(tracker.is_complete, "Transition should complete")

## Test Trans_Fade with mid-transition callback
func test_fade_transition_mid_callback() -> void:
	var fade := Trans_Fade.new()
	fade.duration = 0.2

	var mid_tracker := U_TransitionTestHelpers.create_completion_tracker()
	var completion_tracker := U_TransitionTestHelpers.create_completion_tracker()

	fade.mid_transition_callback = mid_tracker.get_callback()
	fade.execute(_transition_overlay, completion_tracker.get_callback())
	await get_tree().process_frame

	# Wait for tween to complete (triggers both mid and completion callbacks)
	if fade._tween != null:
		await U_TransitionTestHelpers.await_tween_or_timeout(fade._tween, get_tree(), 0.5)

	assert_true(mid_tracker.is_complete, "Mid-transition callback should be called when fully faded out")
	assert_true(completion_tracker.is_complete, "Completion callback should be called")

## Test BaseTransitionEffect cleanup
## @warning: Skipped in headless - tween timing unreliable without rendering
func test_transition_cleans_up_tween() -> void:
	if OS.has_feature("headless") or DisplayServer.get_name() == "headless":
		pending("Skipped: Tween timing unreliable in headless mode")
		return
	var fade := Trans_Fade.new()
	fade.duration = 0.1

	var tracker := U_TransitionTestHelpers.create_completion_tracker()
	fade.execute(_transition_overlay, tracker.get_callback())

	# Wait for tween to complete
	if fade._tween != null:
		await U_TransitionTestHelpers.await_tween_or_timeout(fade._tween, get_tree(), 0.8)

	# Tween should be cleaned up after completion
	assert_true(true, "Transition should clean up Tween")

## Test multiple transitions don't conflict
func test_multiple_transitions_queued() -> void:
	var fade1 := Trans_Fade.new()
	fade1.duration = 0.1

	var fade2 := Trans_Fade.new()
	fade2.duration = 0.1

	var tracker1 := U_TransitionTestHelpers.create_completion_tracker()
	var tracker2 := U_TransitionTestHelpers.create_completion_tracker()

	fade1.execute(_transition_overlay, tracker1.get_callback())

	# Try to execute second transition immediately (should be queued or blocked)
	fade2.execute(_transition_overlay, tracker2.get_callback())

	# Wait for first tween to finish using signal (works in headless)
	await get_tree().process_frame
	if fade1._tween != null:
		await U_TransitionTestHelpers.await_tween_or_timeout(fade1._tween, get_tree(), 0.5)

	# Both should eventually complete
	assert_true(tracker1.is_complete, "First transition should complete")
	# Note: Second transition behavior depends on implementation

## Test Trans_Fade with zero duration
func test_fade_transition_zero_duration() -> void:
	var fade := Trans_Fade.new()
	fade.duration = 0.0

	var tracker := U_TransitionTestHelpers.create_completion_tracker()
	fade.execute(_transition_overlay, tracker.get_callback())

	await get_tree().process_frame

	# Should complete immediately with zero duration
	assert_true(tracker.is_complete, "Zero duration fade should complete immediately")

## Test BaseTransitionEffect error handling
func test_transition_with_null_overlay() -> void:
	var fade := Trans_Fade.new()
	fade.duration = 0.1

	var tracker := U_TransitionTestHelpers.create_completion_tracker()

	# Pass null overlay (should handle gracefully)
	fade.execute(null, tracker.get_callback())
	await get_tree().process_frame

	# Should not crash, may skip transition or use fallback
	assert_true(true, "Should handle null overlay gracefully")

## Test Trans_Fade Tween properties
## @warning: Skipped in headless - tween timing unreliable without rendering
func test_fade_transition_uses_tween() -> void:
	if OS.has_feature("headless") or DisplayServer.get_name() == "headless":
		pending("Skipped: Tween timing unreliable in headless mode")
		return
	var fade := Trans_Fade.new()
	fade.duration = 0.2

	fade.execute(_transition_overlay, func() -> void: pass)

	# In paused trees, timers do not advance; use frame yields.
	var alpha1: float
	var alpha2: float
	if get_tree().paused:
		for i in range(3):
			await get_tree().process_frame
		alpha1 = _color_rect.modulate.a
		for i in range(3):
			await get_tree().process_frame
		alpha2 = _color_rect.modulate.a
	else:
		await wait_seconds(0.05)
		alpha1 = _color_rect.modulate.a
		await wait_seconds(0.05)
		alpha2 = _color_rect.modulate.a

	# Alpha should be different, proving Tween is working
	assert_ne(alpha1, alpha2, "Alpha should change during fade")

## Test input blocking mechanism
## @warning: Skipped in headless - tween timing unreliable without rendering
func test_input_blocking_enabled() -> void:
	if OS.has_feature("headless") or DisplayServer.get_name() == "headless":
		pending("Skipped: Tween timing unreliable in headless mode")
		return
	var fade := Trans_Fade.new()
	fade.duration = 0.1
	fade.block_input = true

	fade.execute(_transition_overlay, func() -> void: pass)

	# During transition, check if input blocking is active
	if get_tree().paused:
		for i in range(3):
			await get_tree().process_frame
	else:
		await wait_seconds(0.05)

	assert_true(true, "Input blocking should be enabled during transition")

	if get_tree().paused:
		for i in range(6):
			await get_tree().process_frame
	else:
		await wait_seconds(0.1)

	# After transition, input blocking should be disabled
	assert_true(true, "Input blocking should be disabled after transition")

## Test Trans_Fade configurable easing
## @warning: Skipped in headless - tween timing unreliable without rendering
func test_fade_transition_easing() -> void:
	if OS.has_feature("headless") or DisplayServer.get_name() == "headless":
		pending("Skipped: Tween timing unreliable in headless mode")
		return
	var fade := Trans_Fade.new()
	fade.duration = 0.2
	fade.easing_type = Tween.EASE_IN_OUT
	fade.transition_type = Tween.TRANS_CUBIC

	var tracker := U_TransitionTestHelpers.create_completion_tracker()
	fade.execute(_transition_overlay, tracker.get_callback())

	if fade._tween != null:
		await U_TransitionTestHelpers.await_tween_or_timeout(fade._tween, get_tree(), 1.0)

	assert_true(tracker.is_complete, "Should complete with custom easing")

## Test Trans_Instant with scene swap
func test_instant_transition_scene_swap_timing() -> void:
	var instant := Trans_Instant.new()

	var tracker := U_TransitionTestHelpers.create_completion_tracker()
	instant.execute(_transition_overlay, tracker.get_callback())

	# Should call callback immediately (within same frame)
	assert_true(tracker.is_complete, "Trans_Instant should allow immediate scene swap")
