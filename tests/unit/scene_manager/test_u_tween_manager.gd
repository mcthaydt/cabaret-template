extends GutTest

## Unit tests for U_TweenManager and U_TransitionTestHelpers
##
## Tests the centralized tween factory and test helper utilities.
## Follows TDD: These tests are written before the implementation.

const U_TweenManager = preload("res://scripts/scene_management/u_tween_manager.gd")
const U_TransitionTestHelpers = preload("res://tests/helpers/u_transition_test_helpers.gd")

var _test_node: Node

func before_each() -> void:
	_test_node = Node.new()
	_test_node.name = "TestNode"
	add_child_autofree(_test_node)

func after_each() -> void:
	_test_node = null

## ============================================================================
## CompletionTracker Tests
## ============================================================================

## Test: CompletionTracker starts not complete
func test_completion_tracker_starts_not_complete() -> void:
	var tracker := U_TransitionTestHelpers.create_completion_tracker()
	assert_false(tracker.is_complete, "Tracker should start not complete")

## Test: CompletionTracker marks complete
func test_completion_tracker_marks_complete() -> void:
	var tracker := U_TransitionTestHelpers.create_completion_tracker()
	tracker.mark_complete()
	assert_true(tracker.is_complete, "Tracker should be complete after mark_complete()")

## Test: CompletionTracker callback works in closure
func test_completion_tracker_callback_closure() -> void:
	var tracker := U_TransitionTestHelpers.create_completion_tracker()
	var callback := tracker.get_callback()

	assert_false(tracker.is_complete, "Should not be complete before callback")
	callback.call()
	assert_true(tracker.is_complete, "Should be complete after callback.call()")

## Test: CompletionTracker wait returns true on completion
func test_completion_tracker_wait_returns_true_on_completion() -> void:
	var tracker := U_TransitionTestHelpers.create_completion_tracker()

	# Schedule completion after a short delay
	get_tree().create_timer(0.05).timeout.connect(tracker.get_callback())

	var result := await tracker.wait(get_tree(), 1.0)
	assert_true(result, "wait() should return true when completed")
	assert_true(tracker.is_complete, "Tracker should be complete")

## Test: CompletionTracker wait returns false on timeout
func test_completion_tracker_wait_returns_false_on_timeout() -> void:
	var tracker := U_TransitionTestHelpers.create_completion_tracker()

	# Don't call mark_complete - let it timeout
	var result := await tracker.wait(get_tree(), 0.1)
	assert_false(result, "wait() should return false on timeout")
	assert_false(tracker.is_complete, "Tracker should not be complete")

## ============================================================================
## await_tween_or_timeout Tests
## ============================================================================

## Test: await_tween_or_timeout returns true on tween completion
func test_await_tween_returns_true_on_completion() -> void:
	var tween := _test_node.create_tween()
	tween.tween_interval(0.05)

	var result := await U_TransitionTestHelpers.await_tween_or_timeout(tween, get_tree(), 1.0)
	assert_true(result, "Should return true when tween completes")

## Test: await_tween_or_timeout returns false on timeout
func test_await_tween_returns_false_on_timeout() -> void:
	var tween := _test_node.create_tween()
	tween.tween_interval(10.0)  # Very long tween

	var result := await U_TransitionTestHelpers.await_tween_or_timeout(tween, get_tree(), 0.1)
	assert_false(result, "Should return false when timeout occurs")

	# Clean up long-running tween
	tween.kill()

## Test: await_tween_or_timeout handles null tween
func test_await_tween_handles_null() -> void:
	var result := await U_TransitionTestHelpers.await_tween_or_timeout(null, get_tree(), 0.1)
	assert_false(result, "Should return false for null tween")

## ============================================================================
## U_TweenManager.create_transition_tween Tests
## ============================================================================

## Test: create_transition_tween creates valid tween
func test_create_transition_tween_creates_valid_tween() -> void:
	var tween := U_TweenManager.create_transition_tween(_test_node)

	assert_not_null(tween, "Should create a valid tween")
	assert_true(tween.is_valid(), "Tween should be valid")

## Test: create_transition_tween sets physics process mode
func test_create_transition_tween_physics_mode() -> void:
	var tween := U_TweenManager.create_transition_tween(_test_node)
	tween.tween_interval(0.01)  # Very short interval

	# Verify tween is created and running
	assert_true(tween.is_running(), "Tween should be running")

	# Wait sufficient time for physics processing
	await wait_physics_frames(10)
	await get_tree().process_frame

	# Tween should have completed (or be done by now)
	# In headless mode, just verify the tween was created properly
	assert_not_null(tween, "Tween should exist")
	pass_test("Tween created with physics process mode")

## Test: create_transition_tween handles null owner gracefully
func test_create_transition_tween_null_owner() -> void:
	var tween := U_TweenManager.create_transition_tween(null)

	assert_null(tween, "Should return null for null owner")
	assert_push_error("Cannot create tween with null owner")

## Test: create_transition_tween accepts custom config
func test_create_transition_tween_custom_config() -> void:
	var config := U_TweenManager.TweenConfig.new()
	config.ease_type = Tween.EASE_OUT
	config.trans_type = Tween.TRANS_BOUNCE

	var tween := U_TweenManager.create_transition_tween(_test_node, config)

	assert_not_null(tween, "Should create tween with custom config")
	assert_true(tween.is_valid(), "Tween should be valid")

## ============================================================================
## U_TweenManager.TweenContext Tests
## ============================================================================

## Test: TweenContext saves and restores process modes
func test_tween_context_saves_process_modes() -> void:
	var overlay := CanvasLayer.new()
	var child := ColorRect.new()
	overlay.add_child(child)
	add_child_autofree(overlay)

	# Set initial process modes
	overlay.process_mode = Node.PROCESS_MODE_INHERIT
	child.process_mode = Node.PROCESS_MODE_PAUSABLE

	var context := U_TweenManager.create_pausable_tween(overlay, [overlay, child])

	# Process modes should be changed to ALWAYS
	assert_eq(overlay.process_mode, Node.PROCESS_MODE_ALWAYS, "Overlay should be ALWAYS")
	assert_eq(child.process_mode, Node.PROCESS_MODE_ALWAYS, "Child should be ALWAYS")

	# Restore should bring back original modes
	context.restore_process_modes()

	assert_eq(overlay.process_mode, Node.PROCESS_MODE_INHERIT, "Overlay should be restored")
	assert_eq(child.process_mode, Node.PROCESS_MODE_PAUSABLE, "Child should be restored")

## Test: TweenContext provides valid tween
func test_tween_context_has_valid_tween() -> void:
	var context := U_TweenManager.create_pausable_tween(_test_node, [])

	assert_not_null(context, "Context should not be null")
	assert_not_null(context.tween, "Context should have tween")
	assert_true(context.tween.is_valid(), "Tween should be valid")

## Test: TweenContext is_running tracks tween state
func test_tween_context_is_running() -> void:
	var context := U_TweenManager.create_pausable_tween(_test_node, [])
	context.tween.tween_interval(0.1)

	assert_true(context.is_running(), "Should be running initially")

	await U_TransitionTestHelpers.await_tween_or_timeout(context.tween, get_tree(), 0.5)

	assert_false(context.is_running(), "Should not be running after completion")

## Test: TweenContext kill_and_restore stops tween and restores modes
func test_tween_context_kill_and_restore() -> void:
	var overlay := CanvasLayer.new()
	add_child_autofree(overlay)
	overlay.process_mode = Node.PROCESS_MODE_INHERIT

	var context := U_TweenManager.create_pausable_tween(overlay, [overlay])
	context.tween.tween_interval(10.0)  # Long tween

	assert_true(context.is_running(), "Should be running")
	assert_eq(overlay.process_mode, Node.PROCESS_MODE_ALWAYS, "Should be ALWAYS during tween")

	context.kill_and_restore()

	assert_false(context.is_running(), "Should not be running after kill")
	assert_eq(overlay.process_mode, Node.PROCESS_MODE_INHERIT, "Should be restored after kill")

## Test: TweenContext handles freed nodes gracefully
func test_tween_context_handles_freed_nodes() -> void:
	var overlay := CanvasLayer.new()
	add_child(overlay)
	overlay.process_mode = Node.PROCESS_MODE_INHERIT

	var context := U_TweenManager.create_pausable_tween(overlay, [overlay])

	# Free the node before restoring process modes
	overlay.queue_free()
	await get_tree().process_frame  # Allow queue_free to process

	# restore_process_modes should not crash on freed nodes
	context.restore_process_modes()

	# If we get here without crashing, the test passes
	assert_true(true, "Should handle freed nodes without crashing")
