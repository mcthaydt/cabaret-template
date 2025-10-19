extends BaseTest

const SessionActions := preload("res://scripts/state/actions/session_actions.gd")

func test_set_slot_creates_numeric_payload() -> void:
	var action: Dictionary = SessionActions.set_slot(2)
	assert_eq(action["type"], StringName("session/set_slot"))
	assert_eq(int(action["payload"]), 2)

func test_set_last_saved_tick_wraps_payload() -> void:
	var action: Dictionary = SessionActions.set_last_saved_tick(120)
	assert_eq(action["type"], StringName("session/set_last_saved_tick"))
	assert_eq(int(action["payload"]), 120)

func test_set_flag_embeds_key_and_value() -> void:
	var action: Dictionary = SessionActions.set_flag(StringName("tutorial_complete"), true)
	assert_eq(action["type"], StringName("session/set_flag"))
	assert_eq(action["payload"]["key"], StringName("tutorial_complete"))
	assert_true(action["payload"]["value"])

func test_clear_flag_sets_key_in_payload() -> void:
	var action: Dictionary = SessionActions.clear_flag(StringName("tutorial_complete"))
	assert_eq(action["type"], StringName("session/clear_flag"))
	assert_eq(action["payload"], StringName("tutorial_complete"))
