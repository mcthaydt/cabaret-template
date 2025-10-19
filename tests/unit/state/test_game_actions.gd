extends BaseTest

const GameActions := preload("res://scripts/state/actions/game_actions.gd")

func test_add_score_creates_valid_action() -> void:
	var action: Dictionary = GameActions.add_score(10)
	assert_eq(action["type"], StringName("game/add_score"))
	assert_eq(int(action["payload"]), 10)

func test_level_up_action_uses_null_payload() -> void:
	var action: Dictionary = GameActions.level_up()
	assert_eq(action["type"], StringName("game/level_up"))
	assert_null(action["payload"])

func test_set_score_creates_action_with_numeric_payload() -> void:
	var action: Dictionary = GameActions.set_score(42)
	assert_eq(action["type"], StringName("game/set_score"))
	assert_eq(int(action["payload"]), 42)

func test_unlock_action_converts_payload_to_string_name() -> void:
	var action: Dictionary = GameActions.unlock("dash")
	assert_eq(action["type"], StringName("game/unlock"))
	assert_eq(action["payload"], StringName("dash"))
