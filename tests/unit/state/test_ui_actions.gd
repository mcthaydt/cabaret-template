extends BaseTest

const UiActions := preload("res://scripts/state/actions/ui_actions.gd")

func test_open_menu_wraps_string_name_payload() -> void:
	var action: Dictionary = UiActions.open_menu("pause")
	assert_eq(action["type"], StringName("ui/open_menu"))
	assert_eq(action["payload"], StringName("pause"))

func test_close_menu_returns_action_with_null_payload() -> void:
	var action: Dictionary = UiActions.close_menu()
	assert_eq(action["type"], StringName("ui/close_menu"))
	assert_null(action["payload"])

func test_set_setting_embeds_key_and_value() -> void:
	var action: Dictionary = UiActions.set_setting("music_volume", 0.3)
	assert_eq(action["type"], StringName("ui/set_setting"))
	assert_eq(action["payload"]["key"], "music_volume")
	assert_eq(action["payload"]["value"], 0.3)
