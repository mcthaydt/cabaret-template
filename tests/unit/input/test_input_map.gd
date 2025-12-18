extends GutTest

func test_required_actions_exist_in_project_input_map() -> void:
	var required := [
		StringName("move_left"),
		StringName("move_right"),
		StringName("move_forward"),
		StringName("move_backward"),
		StringName("jump"),
		StringName("sprint"),
		StringName("interact"),
		StringName("pause"),
		StringName("ui_accept"),
		StringName("ui_select"),
		StringName("ui_cancel"),
		StringName("ui_left"),
		StringName("ui_right"),
		StringName("ui_up"),
		StringName("ui_down"),
		StringName("ui_pause"),
		StringName("ui_focus_next"),
		StringName("ui_focus_prev"),
	]

	var missing: Array[StringName] = []
	for action in required:
		if not InputMap.has_action(action):
			missing.append(action)

	assert_true(missing.is_empty(), "Project InputMap missing actions: %s" % [missing])
