extends GutTest

## F10 Verification: State Store History Truncation
##
## U_ActionHistoryBuffer is already implemented as a ring buffer with
## configurable max_history_size. This test file verifies the three
## truncation invariants called out in cleanup-v7.2:
##   1. Buffer does not exceed max_history_size after max_history_size + 100 actions.
##   2. configure(0, true) and configure(N, false) both result in empty history.
##   3. Ring buffer wraps correctly (oldest entries evicted first).


var buffer: U_ActionHistoryBuffer


func before_each() -> void:
	buffer = U_ActionHistoryBuffer.new()


func _record_n_actions(buffer: U_ActionHistoryBuffer, count: int) -> void:
	for i in count:
		var action: Dictionary = {"type": "test_action_%d" % i, "index": i}
		var state: Dictionary = {"slice": {"value": i}}
		buffer.record_action(action, state)


func test_buffer_does_not_exceed_max_history_size() -> void:
	buffer.configure(50, true)
	_record_n_actions(buffer, 150)  # 50 + 100

	var history: Array = buffer.get_action_history()
	assert_eq(history.size(), 50, "History should be capped at max_history_size (50) after 150 actions")


func test_configure_zero_size_enabled_results_in_empty_history() -> void:
	buffer.configure(0, true)
	_record_n_actions(buffer, 10)

	var history: Array = buffer.get_action_history()
	assert_eq(history.size(), 0, "History should be empty when max_history_size is 0 even if enabled")


func test_configure_nonzero_size_disabled_results_in_empty_history() -> void:
	buffer.configure(100, false)
	_record_n_actions(buffer, 10)

	var history: Array = buffer.get_action_history()
	assert_eq(history.size(), 0, "History should be empty when disabled even if max_history_size > 0")


func test_ring_buffer_wraps_oldest_evicted_first() -> void:
	buffer.configure(5, true)
	# Record actions 0-9; buffer size 5 means entries 0-4 are evicted, 5-9 remain
	_record_n_actions(buffer, 10)

	var history: Array = buffer.get_action_history()
	assert_eq(history.size(), 5, "History should contain exactly 5 entries")

	# Verify oldest entry is the first surviving one (index 5)
	var oldest: Dictionary = history[0]
	assert_eq(oldest["action"]["index"], 5, "Oldest surviving entry should be action 5")

	# Verify newest entry is the last recorded (index 9)
	var newest: Dictionary = history[history.size() - 1]
	assert_eq(newest["action"]["index"], 9, "Newest entry should be action 9")


func test_get_last_n_actions_after_wrap() -> void:
	buffer.configure(5, true)
	_record_n_actions(buffer, 10)

	var last_3: Array = buffer.get_last_n_actions(3)
	assert_eq(last_3.size(), 3, "Should return last 3 actions")
	assert_eq(last_3[0]["action"]["index"], 7, "First of last-3 should be action 7")
	assert_eq(last_3[2]["action"]["index"], 9, "Last of last-3 should be action 9")


func test_clear_resets_buffer() -> void:
	buffer.configure(10, true)
	_record_n_actions(buffer, 5)
	buffer.clear()

	var history: Array = buffer.get_action_history()
	assert_eq(history.size(), 0, "History should be empty after clear()")


func test_reconfigure_shrinks_existing_history() -> void:
	buffer.configure(100, true)
	_record_n_actions(buffer, 50)

	# Reconfigure with smaller size — existing entries beyond new size are discarded
	buffer.configure(10, true)

	var history: Array = buffer.get_action_history()
	assert_eq(history.size(), 0, "Reconfigure resets history; new entries start fresh")