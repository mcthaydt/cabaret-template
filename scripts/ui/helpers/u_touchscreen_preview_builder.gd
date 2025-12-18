extends RefCounted
class_name U_TouchscreenPreviewBuilder

func build_preview(
	preview_container: Control,
	virtual_joystick_scene: PackedScene,
	virtual_button_scene: PackedScene,
	out_preview_joystick: Array,
	out_preview_buttons: Array
) -> void:
	if preview_container == null:
		return

	for child in preview_container.get_children():
		child.queue_free()

	out_preview_buttons.clear()
	out_preview_joystick.clear()

	var viewport_size: Vector2 = preview_container.size
	if viewport_size.is_zero_approx():
		viewport_size = Vector2(400, 220)

	var joystick_instance := virtual_joystick_scene.instantiate()
	if joystick_instance is Control:
		preview_container.add_child(joystick_instance)
		joystick_instance.name = "PreviewJoystick"
		joystick_instance.process_mode = Node.PROCESS_MODE_DISABLED
		joystick_instance.position = Vector2(40, viewport_size.y - 140)
		out_preview_joystick.append(joystick_instance)

	var actions := [
		StringName("jump"),
		StringName("sprint"),
		StringName("interact"),
		StringName("pause")
	]

	for index in actions.size():
		var button_instance := virtual_button_scene.instantiate()
		if button_instance is Control:
			preview_container.add_child(button_instance)
			button_instance.name = "PreviewButton_%s" % String(actions[index])
			if "action" in button_instance:
				button_instance.action = actions[index]
			if button_instance.has_method("_refresh_label"):
				button_instance._refresh_label()
			button_instance.process_mode = Node.PROCESS_MODE_DISABLED
			out_preview_buttons.append(button_instance)

func update_preview_from_sliders(
	preview_container: Control,
	preview_joystick: Control,
	preview_buttons: Array,
	joystick_size: float,
	button_size: float,
	joystick_opacity: float,
	button_opacity: float,
	joystick_deadzone: float
) -> void:
	var clamped_joystick_size: float = max(joystick_size, 0.01)
	var clamped_button_size: float = max(button_size, 0.01)
	var clamped_joystick_opacity: float = clampf(joystick_opacity, 0.0, 1.0)
	var clamped_button_opacity: float = clampf(button_opacity, 0.0, 1.0)
	var clamped_deadzone: float = clampf(joystick_deadzone, 0.0, 1.0)

	if preview_joystick != null and is_instance_valid(preview_joystick):
		preview_joystick.scale = Vector2.ONE * clamped_joystick_size
		var color: Color = preview_joystick.modulate
		color.a = clamped_joystick_opacity
		preview_joystick.modulate = color
		if "deadzone" in preview_joystick:
			preview_joystick.deadzone = clamped_deadzone

	for button in preview_buttons:
		if button == null or not is_instance_valid(button):
			continue
		button.scale = Vector2.ONE * clamped_button_size
		var button_color: Color = button.modulate
		button_color.a = clamped_button_opacity
		button.modulate = button_color

	_update_preview_positions(
		preview_container,
		preview_joystick,
		preview_buttons,
		clamped_joystick_size,
		clamped_button_size
	)

func _update_preview_positions(
	preview_container: Control,
	preview_joystick: Control,
	preview_buttons: Array,
	joystick_size: float,
	button_size: float
) -> void:
	if preview_container == null:
		return

	var preview_size: Vector2 = preview_container.size
	if preview_size.is_zero_approx():
		preview_size = Vector2(520, 220)

	if preview_joystick != null and is_instance_valid(preview_joystick):
		var base_joystick_size: Vector2 = preview_joystick.size
		if base_joystick_size.is_zero_approx():
			base_joystick_size = preview_joystick.custom_minimum_size
		var joystick_scaled: Vector2 = base_joystick_size * joystick_size
		var padding: float = 24.0
		preview_joystick.position = Vector2(
			padding,
			max(padding, preview_size.y - padding - joystick_scaled.y)
		)

	var button_padding: float = 24.0
	var button_spacing: float = 12.0
	var base_button_size: Vector2 = Vector2.ONE * 100.0
	if not preview_buttons.is_empty():
		var sample_button: Control = preview_buttons[0]
		if sample_button != null and is_instance_valid(sample_button):
			base_button_size = sample_button.size
			if base_button_size.is_zero_approx():
				base_button_size = sample_button.custom_minimum_size
	var button_scaled_size: Vector2 = base_button_size * button_size

	var grid_cols: int = 2
	var grid_rows: int = 2
	var grid_width: float = float(grid_cols) * button_scaled_size.x + float(grid_cols - 1) * button_spacing
	var grid_height: float = float(grid_rows) * button_scaled_size.y + float(grid_rows - 1) * button_spacing

	var grid_start_x: float = max(button_padding, preview_size.x - button_padding - grid_width)
	var grid_start_y: float = max(button_padding, preview_size.y - button_padding - grid_height)

	for index in preview_buttons.size():
		var button: Control = preview_buttons[index]
		if button == null or not is_instance_valid(button):
			continue
		var col: int = index % grid_cols
		var row: int = index / grid_cols
		button.position = Vector2(
			grid_start_x + float(col) * (button_scaled_size.x + button_spacing),
			grid_start_y + float(row) * (button_scaled_size.y + button_spacing)
		)

