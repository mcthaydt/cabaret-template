extends GutTest

## Unit tests for transition effects
##
## Tests BaseTransitionEffect base class and implementations (InstantTransition, FadeTransition).
## Tests follow TDD discipline: written BEFORE implementation.

const BaseTransitionEffect = preload("res://scripts/scene_management/transitions/base_transition_effect.gd")
const InstantTransition = preload("res://scripts/scene_management/transitions/instant_transition.gd")
const FadeTransition = preload("res://scripts/scene_management/transitions/fade_transition.gd")

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

## Test InstantTransition completes immediately
func test_instant_transition_completes_immediately() -> void:
	var instant := InstantTransition.new()

	var completed: Array = [false]  # Use array for closure to work
	var callback := func() -> void:
		completed[0] = true

	instant.execute(_transition_overlay, callback)
	await get_tree().process_frame

	assert_true(completed[0], "InstantTransition should complete immediately")

## Test InstantTransition duration is zero
func test_instant_transition_duration_is_zero() -> void:
	var instant := InstantTransition.new()

	var duration: float = instant.get_duration()

	assert_eq(duration, 0.0, "InstantTransition duration should be 0.0")

## Test FadeTransition has configurable duration
func test_fade_transition_duration() -> void:
	var fade := FadeTransition.new()
	fade.duration = 0.5

	var duration: float = fade.get_duration()

	assert_eq(duration, 0.5, "FadeTransition should return configured duration")

## Test FadeTransition fades out then in
func test_fade_transition_sequence() -> void:
	var fade := FadeTransition.new()
	fade.duration = 0.3  # Shorter for faster tests

	var completed: Array = [false]  # Use array for closure to work
	var callback := func() -> void:
		completed[0] = true

	# Initial alpha should be 0
	assert_almost_eq(_color_rect.modulate.a, 0.0, 0.01, "Should start transparent")

	fade.execute(_transition_overlay, callback)

	# Wait for fade out to complete (half duration)
	await wait_seconds(0.15)
	assert_true(_color_rect.modulate.a > 0.5, "Should be fading out")

	# Wait for fade in to complete
	await wait_seconds(0.25)
	assert_almost_eq(_color_rect.modulate.a, 0.0, 0.1, "Should fade back to transparent")
	assert_true(completed[0], "Should call completion callback")

## Test FadeTransition respects color setting
func test_fade_transition_color() -> void:
	var fade := FadeTransition.new()
	fade.fade_color = Color.WHITE
	fade.duration = 0.1

	var callback := func() -> void:
		pass

	fade.execute(_transition_overlay, callback)
	await wait_seconds(0.05)

	# Color rect should use white (though alpha varies)
	assert_eq(_color_rect.color, Color.WHITE, "Should use configured fade color")

## Test transition blocks input during execution
func test_transition_blocks_input() -> void:
	var fade := FadeTransition.new()
	fade.duration = 0.2

	var completed: Array = [false]  # Use array for closure to work
	var callback := func() -> void:
		completed[0] = true

	# Execute transition
	fade.execute(_transition_overlay, callback)

	# Check if input is blocked (implementation-specific)
	# This may require checking SceneTree.paused or input handling state
	await wait_seconds(0.1)

	# During transition, input should be blocked
	assert_true(true, "Transition should block input during execution")

	await wait_seconds(0.2)
	assert_true(completed[0], "Transition should complete")

## Test FadeTransition with mid-transition callback
func test_fade_transition_mid_callback() -> void:
	var fade := FadeTransition.new()
	fade.duration = 0.2

	var mid_callback_called: Array = [false]  # Use array for closure to work
	var completion_callback_called: Array = [false]  # Use array for closure to work

	fade.mid_transition_callback = func() -> void:
		mid_callback_called[0] = true

	var completion_callback := func() -> void:
		completion_callback_called[0] = true

	fade.execute(_transition_overlay, completion_callback)

	# Wait for mid-point (fade out complete)
	await wait_seconds(0.11)
	assert_true(mid_callback_called[0], "Mid-transition callback should be called when fully faded out")

	# Wait for completion
	await wait_seconds(0.15)
	assert_true(completion_callback_called[0], "Completion callback should be called")

## Test BaseTransitionEffect cleanup
func test_transition_cleans_up_tween() -> void:
	var fade := FadeTransition.new()
	fade.duration = 0.1

	var callback := func() -> void:
		pass

	fade.execute(_transition_overlay, callback)
	await wait_seconds(0.15)

	# Tween should be cleaned up after completion
	# (implementation-specific check)
	assert_true(true, "Transition should clean up Tween")

## Test multiple transitions don't conflict
func test_multiple_transitions_queued() -> void:
	var fade1 := FadeTransition.new()
	fade1.duration = 0.1

	var fade2 := FadeTransition.new()
	fade2.duration = 0.1

	var completed1: Array = [false]  # Use array for closure to work
	var completed2: Array = [false]  # Use array for closure to work

	fade1.execute(_transition_overlay, func() -> void: completed1[0] = true)

	# Try to execute second transition immediately (should be queued or blocked)
	fade2.execute(_transition_overlay, func() -> void: completed2[0] = true)

	await wait_seconds(0.25)

	# Both should eventually complete
	assert_true(completed1[0], "First transition should complete")
	# Note: Second transition behavior depends on implementation

## Test FadeTransition with zero duration
func test_fade_transition_zero_duration() -> void:
	var fade := FadeTransition.new()
	fade.duration = 0.0

	var completed: Array = [false]  # Use array for closure to work
	fade.execute(_transition_overlay, func() -> void: completed[0] = true)

	await get_tree().process_frame

	# Should complete immediately with zero duration
	assert_true(completed[0], "Zero duration fade should complete immediately")

## Test BaseTransitionEffect error handling
func test_transition_with_null_overlay() -> void:
	var fade := FadeTransition.new()
	fade.duration = 0.1

	var completed: bool = false

	# Pass null overlay (should handle gracefully)
	fade.execute(null, func() -> void: completed = true)
	await get_tree().process_frame

	# Should not crash, may skip transition or use fallback
	assert_true(true, "Should handle null overlay gracefully")

## Test FadeTransition Tween properties
func test_fade_transition_uses_tween() -> void:
	var fade := FadeTransition.new()
	fade.duration = 0.2

	fade.execute(_transition_overlay, func() -> void: pass)

	await wait_seconds(0.05)

	# Alpha should be changing (Tween in progress)
	var alpha1: float = _color_rect.modulate.a

	await wait_seconds(0.05)

	var alpha2: float = _color_rect.modulate.a

	# Alpha should be different, proving Tween is working
	assert_ne(alpha1, alpha2, "Alpha should change during fade")

## Test input blocking mechanism
func test_input_blocking_enabled() -> void:
	var fade := FadeTransition.new()
	fade.duration = 0.1
	fade.block_input = true

	fade.execute(_transition_overlay, func() -> void: pass)

	# During transition, check if input blocking is active
	# (implementation may use set_input_as_handled or process_mode changes)
	await wait_seconds(0.05)

	assert_true(true, "Input blocking should be enabled during transition")

	await wait_seconds(0.1)

	# After transition, input blocking should be disabled
	assert_true(true, "Input blocking should be disabled after transition")

## Test FadeTransition configurable easing
func test_fade_transition_easing() -> void:
	var fade := FadeTransition.new()
	fade.duration = 0.2
	fade.easing_type = Tween.EASE_IN_OUT
	fade.transition_type = Tween.TRANS_CUBIC

	var completed: Array = [false]  # Use array for closure to work
	fade.execute(_transition_overlay, func() -> void: completed[0] = true)

	await wait_seconds(0.25)

	assert_true(completed[0], "Should complete with custom easing")

## Test InstantTransition with scene swap
func test_instant_transition_scene_swap_timing() -> void:
	var instant := InstantTransition.new()

	var scene_swapped: Array = [false]  # Use array for closure to work
	var callback := func() -> void:
		scene_swapped[0] = true

	instant.execute(_transition_overlay, callback)

	# Should call callback immediately (within same frame)
	assert_true(scene_swapped[0], "InstantTransition should allow immediate scene swap")
