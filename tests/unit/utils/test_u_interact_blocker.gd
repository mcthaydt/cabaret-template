extends BaseTest


## Regression test for interact blocking during toast display
## Tests the U_InteractBlocker utility that prevents interaction spam during UI feedback

func before_each() -> void:
	super.before_each()
	# Clean up any previous state
	U_InteractBlocker.cleanup()

func after_each() -> void:
	# Ensure cleanup after each test
	U_InteractBlocker.cleanup()
	super.after_each()

## Test: Initial state should be unblocked
func test_initial_state_is_unblocked() -> void:
	assert_false(U_InteractBlocker.is_blocked(), "Initial state should be unblocked")

## Test: Block method sets blocked state to true
func test_block_sets_blocked_state() -> void:
	U_InteractBlocker.block()
	assert_true(U_InteractBlocker.is_blocked(), "Should be blocked after calling block()")

## Test: Force unblock immediately clears blocked state
func test_force_unblock_clears_state_immediately() -> void:
	U_InteractBlocker.block()
	assert_true(U_InteractBlocker.is_blocked(), "Should be blocked")

	U_InteractBlocker.force_unblock()
	assert_false(U_InteractBlocker.is_blocked(), "Should be unblocked after force_unblock()")

## Test: Unblock with zero cooldown clears state immediately
func test_unblock_with_zero_cooldown() -> void:
	U_InteractBlocker.block()
	assert_true(U_InteractBlocker.is_blocked(), "Should be blocked")

	U_InteractBlocker.unblock_with_cooldown(0.0)
	assert_false(U_InteractBlocker.is_blocked(), "Should be unblocked immediately with 0.0 cooldown")

## Test: Unblock with negative cooldown clears state immediately
func test_unblock_with_negative_cooldown() -> void:
	U_InteractBlocker.block()
	assert_true(U_InteractBlocker.is_blocked(), "Should be blocked")

	U_InteractBlocker.unblock_with_cooldown(-1.0)
	assert_false(U_InteractBlocker.is_blocked(), "Should be unblocked immediately with negative cooldown")

## Test: Unblock with cooldown keeps blocked state during cooldown period
func test_unblock_with_cooldown_stays_blocked_during_cooldown() -> void:
	U_InteractBlocker.block()
	assert_true(U_InteractBlocker.is_blocked(), "Should be blocked")

	# Start cooldown (short duration for test speed)
	U_InteractBlocker.unblock_with_cooldown(0.1)

	# Should still be blocked immediately after calling unblock_with_cooldown
	assert_true(U_InteractBlocker.is_blocked(), "Should still be blocked during cooldown period")

## Test: Unblock with cooldown clears state after cooldown expires
func test_unblock_with_cooldown_clears_after_timeout() -> void:
	U_InteractBlocker.block()
	assert_true(U_InteractBlocker.is_blocked(), "Should be blocked")

	# Start cooldown
	var cooldown_duration := 0.15
	U_InteractBlocker.unblock_with_cooldown(cooldown_duration)

	# Wait for cooldown to expire (add extra buffer for timer overhead)
	await get_tree().create_timer(cooldown_duration + 0.1).timeout

	assert_false(U_InteractBlocker.is_blocked(), "Should be unblocked after cooldown expires")

## Test: Multiple block calls keep blocked state
func test_multiple_block_calls() -> void:
	U_InteractBlocker.block()
	assert_true(U_InteractBlocker.is_blocked(), "Should be blocked")

	U_InteractBlocker.block()
	assert_true(U_InteractBlocker.is_blocked(), "Should still be blocked after second block call")

	U_InteractBlocker.block()
	assert_true(U_InteractBlocker.is_blocked(), "Should still be blocked after third block call")

## Test: Block cancels pending cooldown
func test_block_cancels_pending_cooldown() -> void:
	U_InteractBlocker.block()
	assert_true(U_InteractBlocker.is_blocked(), "Should be blocked")

	# Start cooldown
	U_InteractBlocker.unblock_with_cooldown(0.1)

	# Wait a bit but not full cooldown duration
	await get_tree().create_timer(0.05).timeout

	# Call block again (should cancel the cooldown timer)
	U_InteractBlocker.block()
	assert_true(U_InteractBlocker.is_blocked(), "Should still be blocked")

	# Wait past original cooldown duration
	await get_tree().create_timer(0.1).timeout

	# Should STILL be blocked because block() cancelled the cooldown
	assert_true(U_InteractBlocker.is_blocked(), "Should still be blocked after cancelling cooldown")

## Test: Force unblock cancels pending cooldown
func test_force_unblock_cancels_pending_cooldown() -> void:
	U_InteractBlocker.block()
	assert_true(U_InteractBlocker.is_blocked(), "Should be blocked")

	# Start cooldown
	U_InteractBlocker.unblock_with_cooldown(0.2)

	# Immediately force unblock (should cancel cooldown timer)
	U_InteractBlocker.force_unblock()
	assert_false(U_InteractBlocker.is_blocked(), "Should be unblocked immediately")

	# Wait past cooldown duration
	await get_tree().create_timer(0.25).timeout

	# Should STILL be unblocked (cooldown was cancelled)
	assert_false(U_InteractBlocker.is_blocked(), "Should still be unblocked after cancelling cooldown")

## Test: Cleanup clears all state
func test_cleanup_clears_all_state() -> void:
	U_InteractBlocker.block()
	U_InteractBlocker.unblock_with_cooldown(0.5)

	U_InteractBlocker.cleanup()

	assert_false(U_InteractBlocker.is_blocked(), "Should be unblocked after cleanup")

	# Wait to ensure no cooldown timer fires
	await get_tree().create_timer(0.6).timeout
	assert_false(U_InteractBlocker.is_blocked(), "Should still be unblocked after cleanup")

## Test: Typical toast workflow (block -> cooldown -> unblock)
func test_typical_toast_workflow() -> void:
	# Simulate toast appearing
	U_InteractBlocker.block()
	assert_true(U_InteractBlocker.is_blocked(), "Should be blocked when toast appears")

	# Simulate toast hiding and starting cooldown (0.3s as per implementation)
	U_InteractBlocker.unblock_with_cooldown(0.3)
	assert_true(U_InteractBlocker.is_blocked(), "Should stay blocked during cooldown")

	# Wait half the cooldown
	await get_tree().create_timer(0.15).timeout
	assert_true(U_InteractBlocker.is_blocked(), "Should still be blocked mid-cooldown")

	# Wait for remaining cooldown
	await get_tree().create_timer(0.2).timeout
	assert_false(U_InteractBlocker.is_blocked(), "Should be unblocked after cooldown completes")

## Test: Rapid toast succession (new toast during cooldown)
func test_rapid_toast_succession() -> void:
	# First toast
	U_InteractBlocker.block()
	U_InteractBlocker.unblock_with_cooldown(0.2)

	# Wait a bit
	await get_tree().create_timer(0.1).timeout

	# Second toast appears during first toast's cooldown
	U_InteractBlocker.block()
	assert_true(U_InteractBlocker.is_blocked(), "Should be blocked for second toast")

	# Start second cooldown
	U_InteractBlocker.unblock_with_cooldown(0.2)

	# Wait past first cooldown duration (should not unblock because new cooldown started)
	await get_tree().create_timer(0.15).timeout
	assert_true(U_InteractBlocker.is_blocked(), "Should still be blocked during second cooldown")

	# Wait for second cooldown to complete
	await get_tree().create_timer(0.1).timeout
	assert_false(U_InteractBlocker.is_blocked(), "Should be unblocked after second cooldown")

## Test: Pause scenario (force unblock clears everything)
func test_pause_scenario_force_unblock() -> void:
	# Toast appears
	U_InteractBlocker.block()
	U_InteractBlocker.unblock_with_cooldown(0.3)

	# Wait a bit
	await get_tree().create_timer(0.1).timeout
	assert_true(U_InteractBlocker.is_blocked(), "Should be blocked during cooldown")

	# Player pauses game - force unblock
	U_InteractBlocker.force_unblock()
	assert_false(U_InteractBlocker.is_blocked(), "Should be unblocked when paused")

	# Wait past original cooldown
	await get_tree().create_timer(0.3).timeout
	assert_false(U_InteractBlocker.is_blocked(), "Should still be unblocked (cooldown was cancelled)")
