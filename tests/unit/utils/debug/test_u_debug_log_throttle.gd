extends GutTest

const U_DEBUG_LOG_THROTTLE_PATH := "res://scripts/core/utils/debug/u_debug_log_throttle.gd"


func _new_throttle() -> Variant:
	var script_variant: Variant = load(U_DEBUG_LOG_THROTTLE_PATH)
	assert_not_null(script_variant, "Expected script to exist: %s" % U_DEBUG_LOG_THROTTLE_PATH)
	if script_variant == null or not (script_variant is Script):
		return null
	var script_obj: Script = script_variant as Script
	return script_obj.new()


func test_consume_budget_returns_true_when_cooldown_zero() -> void:
	var throttle: Variant = _new_throttle()
	if throttle == null:
		return
	assert_true(throttle.consume_budget(&"npc", 0.5))


func test_consume_budget_returns_false_during_cooldown() -> void:
	var throttle: Variant = _new_throttle()
	if throttle == null:
		return
	assert_true(throttle.consume_budget(&"npc", 0.5))
	assert_false(throttle.consume_budget(&"npc", 0.5))


func test_tick_decrements_cooldowns() -> void:
	var throttle: Variant = _new_throttle()
	if throttle == null:
		return
	assert_true(throttle.consume_budget(&"npc", 1.0))
	throttle.tick(0.5)
	assert_false(throttle.consume_budget(&"npc", 1.0))
	throttle.tick(0.5)
	assert_true(throttle.consume_budget(&"npc", 1.0))


func test_multiple_keys_tracked_independently() -> void:
	var throttle: Variant = _new_throttle()
	if throttle == null:
		return
	assert_true(throttle.consume_budget(&"npc_a", 1.0))
	assert_true(throttle.consume_budget(&"npc_b", 0.25))
	throttle.tick(0.3)
	assert_false(throttle.consume_budget(&"npc_a", 1.0))
	assert_true(throttle.consume_budget(&"npc_b", 0.25))


func test_clear_resets_all_keys() -> void:
	var throttle: Variant = _new_throttle()
	if throttle == null:
		return
	assert_true(throttle.consume_budget(&"npc", 1.0))
	throttle.clear()
	assert_true(throttle.consume_budget(&"npc", 1.0))


func test_log_message_method_exists_and_does_not_throw() -> void:
	var throttle: Variant = _new_throttle()
	if throttle == null:
		return
	assert_true(throttle.has_method("log_message"), "U_DebugLogThrottle must expose log_message()")
	throttle.log_message("test message from throttle")
	assert_true(true, "log_message should complete without error")
