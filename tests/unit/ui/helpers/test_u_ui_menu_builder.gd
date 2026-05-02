extends GutTest

const BUILDER_PATH := "res://scripts/core/ui/helpers/u_ui_menu_builder.gd"
const RS_UI_THEME_CONFIG := preload("res://scripts/core/resources/ui/rs_ui_theme_config.gd")
const U_UI_THEME_BUILDER := preload("res://scripts/core/ui/utils/u_ui_theme_builder.gd")

var _pressed: Array[String] = []

func before_each() -> void:
	U_UI_THEME_BUILDER.active_config = null
	_pressed.clear()

func after_each() -> void:
	U_UI_THEME_BUILDER.active_config = null

func test_builder_constructs_title_buttons_back_and_focus() -> void:
	var builder_script := _get_builder_script()
	if builder_script == null:
		return
	var config := RS_UI_THEME_CONFIG.new()
	config.heading = 39
	config.section_header = 17
	U_UI_THEME_BUILDER.active_config = config

	var menu := Control.new()
	add_child_autofree(menu)
	var builder = builder_script.new(menu)
	assert_eq(builder.set_title(&"menu.main.title"), builder, "set_title should be fluent")
	builder \
		.add_button(&"menu.main.continue", _on_continue_pressed) \
		.add_button_group([
			{"key": &"menu.main.settings", "callback": _on_settings_pressed},
			{"key": &"menu.main.quit", "callback": _on_quit_pressed},
		]) \
		.set_back_button(&"common.back", _on_back_pressed) \
		.set_background_dim(Color(0.1, 0.1, 0.2, 0.7)) \
		.build()

	var title := _find_first(menu, Label) as Label
	var buttons := _collect_buttons(menu)
	assert_not_null(title, "Title should exist")
	assert_eq(title.get_theme_font_size(&"font_size"), config.heading, "Title should use heading token")
	assert_eq(buttons.size(), 4, "Three menu buttons plus back button should exist")
	assert_eq(buttons[0].get_theme_font_size(&"font_size"), config.section_header, "Buttons should use section_header")
	assert_ne(buttons[0].focus_neighbor_bottom, NodePath(), "Focus neighbors should be configured")

	buttons[0].pressed.emit()
	buttons[1].pressed.emit()
	buttons[2].pressed.emit()
	buttons[3].pressed.emit()
	assert_eq(_pressed, ["continue", "settings", "quit", "back"], "Callbacks should be wired")

func test_builder_refresh_methods_reapply_tokens_and_localization() -> void:
	var builder_script := _get_builder_script()
	if builder_script == null:
		return
	var menu := Control.new()
	add_child_autofree(menu)
	var builder = builder_script.new(menu).set_title(&"menu.pause.title").add_button(&"menu.pause.resume", _on_continue_pressed)
	builder.build()

	var config := RS_UI_THEME_CONFIG.new()
	config.heading = 44
	config.section_header = 12
	builder.apply_theme_tokens(config)
	builder.localize_labels()

	var title := _find_first(menu, Label) as Label
	var button := _collect_buttons(menu)[0]
	assert_eq(title.get_theme_font_size(&"font_size"), 44, "apply_theme_tokens should refresh title")
	assert_eq(button.get_theme_font_size(&"font_size"), 12, "apply_theme_tokens should refresh button")
	assert_eq(title.text, "menu.pause.title", "localize_labels should keep fallback key text")

func _get_builder_script() -> GDScript:
	if not ResourceLoader.exists(BUILDER_PATH):
		assert_true(false, "U_UIMenuBuilder script should exist")
		return null
	var builder_script := load(BUILDER_PATH) as GDScript
	assert_not_null(builder_script, "U_UIMenuBuilder script should load")
	return builder_script

func _collect_buttons(node: Node) -> Array[Button]:
	var buttons: Array[Button] = []
	if node is Button:
		buttons.append(node as Button)
	for child in node.get_children():
		buttons.append_array(_collect_buttons(child))
	return buttons

func _find_first(node: Node, type: Variant) -> Node:
	if is_instance_of(node, type):
		return node
	for child in node.get_children():
		var result := _find_first(child, type)
		if result != null:
			return result
	return null

func _on_continue_pressed() -> void:
	_pressed.append("continue")

func _on_settings_pressed() -> void:
	_pressed.append("settings")

func _on_quit_pressed() -> void:
	_pressed.append("quit")

func _on_back_pressed() -> void:
	_pressed.append("back")
