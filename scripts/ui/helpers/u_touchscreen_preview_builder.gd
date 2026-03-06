extends RefCounted
class_name U_TouchscreenPreviewBuilder

const PREVIEW_PADDING: float = 24.0
const BUTTON_SPACING: float = 12.0
const BUTTON_GRID_COLS: int = 2
const BUTTON_GRID_ROWS: int = 2
const MIN_SCALE: float = 0.01

func get_max_preview_scales(
	preview_container: Control,
	preview_joystick: Control,
	preview_buttons: Array
) -> Dictionary:
	var preview_size := _resolve_preview_size(preview_container)
	var available_width: float = max(preview_size.x - (PREVIEW_PADDING * 2.0), 1.0)
	var available_height: float = max(preview_size.y - (PREVIEW_PADDING * 2.0), 1.0)

	var base_joystick_size := _resolve_control_base_size(preview_joystick, Vector2(180, 180))
	var joystick_max: float = min(
		available_width / max(base_joystick_size.x, 1.0),
		available_height / max(base_joystick_size.y, 1.0)
	)

	var sample_button: Control = null
	if not preview_buttons.is_empty() and preview_buttons[0] is Control:
		sample_button = preview_buttons[0] as Control
	var base_button_size := _resolve_control_base_size(sample_button, Vector2(100, 100))
	var button_max_width: float = (
		available_width - (float(BUTTON_GRID_COLS - 1) * BUTTON_SPACING)
	) / max(float(BUTTON_GRID_COLS) * max(base_button_size.x, 1.0), 1.0)
	var button_max_height: float = (
		available_height - (float(BUTTON_GRID_ROWS - 1) * BUTTON_SPACING)
	) / max(float(BUTTON_GRID_ROWS) * max(base_button_size.y, 1.0), 1.0)
	var button_max: float = min(button_max_width, button_max_height)

	return {
		"joystick": max(joystick_max, MIN_SCALE),
		"button": max(button_max, MIN_SCALE),
	}

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

	var viewport_size := _resolve_preview_size(preview_container)

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
	var max_scales := get_max_preview_scales(preview_container, preview_joystick, preview_buttons)
	var joystick_max: float = float(max_scales.get("joystick", joystick_size))
	var button_max: float = float(max_scales.get("button", button_size))

	var clamped_joystick_size: float = clampf(joystick_size, MIN_SCALE, max(joystick_max, MIN_SCALE))
	var clamped_button_size: float = clampf(button_size, MIN_SCALE, max(button_max, MIN_SCALE))
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

	var preview_size := _resolve_preview_size(preview_container)

	if preview_joystick != null and is_instance_valid(preview_joystick):
		var base_joystick_size := _resolve_control_base_size(preview_joystick, Vector2(180, 180))
		var joystick_scaled: Vector2 = base_joystick_size * joystick_size
		preview_joystick.position = Vector2(
			PREVIEW_PADDING,
			max(PREVIEW_PADDING, preview_size.y - PREVIEW_PADDING - joystick_scaled.y)
		)

	var base_button_size: Vector2 = Vector2.ONE * 100.0
	if not preview_buttons.is_empty():
		var sample_button: Control = preview_buttons[0]
		if sample_button != null and is_instance_valid(sample_button):
			base_button_size = _resolve_control_base_size(sample_button, Vector2(100, 100))
	var button_scaled_size: Vector2 = base_button_size * button_size

	var grid_width: float = float(BUTTON_GRID_COLS) * button_scaled_size.x + float(BUTTON_GRID_COLS - 1) * BUTTON_SPACING
	var grid_height: float = float(BUTTON_GRID_ROWS) * button_scaled_size.y + float(BUTTON_GRID_ROWS - 1) * BUTTON_SPACING

	var grid_start_x: float = max(PREVIEW_PADDING, preview_size.x - PREVIEW_PADDING - grid_width)
	var grid_start_y: float = max(PREVIEW_PADDING, preview_size.y - PREVIEW_PADDING - grid_height)

	for index in preview_buttons.size():
		var button: Control = preview_buttons[index]
		if button == null or not is_instance_valid(button):
			continue
		var col: int = index % BUTTON_GRID_COLS
		var row: int = index / BUTTON_GRID_COLS
		button.position = Vector2(
			grid_start_x + float(col) * (button_scaled_size.x + BUTTON_SPACING),
			grid_start_y + float(row) * (button_scaled_size.y + BUTTON_SPACING)
		)

func _resolve_preview_size(preview_container: Control) -> Vector2:
	if preview_container == null:
		return Vector2(520, 220)
	var preview_size: Vector2 = preview_container.size
	if preview_size.is_zero_approx():
		preview_size = preview_container.custom_minimum_size
	if preview_size.is_zero_approx():
		preview_size = Vector2(520, 220)
	return preview_size

func _resolve_control_base_size(control: Control, fallback: Vector2) -> Vector2:
	if control == null or not is_instance_valid(control):
		return fallback
	var resolved: Vector2 = control.size
	if resolved.is_zero_approx():
		resolved = control.custom_minimum_size
	if resolved.is_zero_approx():
		resolved = fallback
	return resolved
