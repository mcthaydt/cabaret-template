extends RefCounted
class_name U_UIMotion

const RS_UI_MOTION_PRESET := preload("res://scripts/core/resources/ui/rs_ui_motion_preset.gd")

static func play(node: Node, presets: Array[Resource]) -> Tween:
	if node == null:
		return null
	if presets.is_empty():
		return null
	if not is_instance_valid(node):
		return null

	var tween := node.create_tween()
	var step_count: int = 0

	for raw_preset: Resource in presets:
		if not (raw_preset is RS_UI_MOTION_PRESET):
			continue
		var preset: Resource = raw_preset
		if _append_step(tween, node, preset):
			step_count += 1

	if step_count <= 0:
		tween.kill()
		return null
	return tween

static func play_enter(node: Node, motion_set: Resource) -> Tween:
	if motion_set == null:
		return null
	if not ("enter" in motion_set):
		return null
	var presets: Array[Resource] = motion_set.enter
	return play(node, presets)

static func play_exit(node: Node, motion_set: Resource) -> Tween:
	if motion_set == null:
		return null
	if not ("exit" in motion_set):
		return null
	var presets: Array[Resource] = motion_set.exit
	return play(node, presets)

static func play_pulse(node: Node, motion_set: Resource) -> Tween:
	if motion_set == null:
		return null
	if not ("pulse" in motion_set):
		return null
	var presets: Array[Resource] = motion_set.pulse
	return play(node, presets)

static func append_step(tween: Tween, node: Node, preset: Resource) -> bool:
	if tween == null or node == null:
		return false
	if not (preset is RS_UI_MOTION_PRESET):
		return false
	return _append_step(tween, node, preset)

static func bind_interactive(control: Control, motion_set: Resource) -> void:
	if control == null or motion_set == null:
		return

	var on_hover_in := Callable(U_UIMotion, "_on_hover_in").bind(control, motion_set)
	if not control.mouse_entered.is_connected(on_hover_in):
		control.mouse_entered.connect(on_hover_in)

	var on_hover_out := Callable(U_UIMotion, "_on_hover_out").bind(control, motion_set)
	if not control.mouse_exited.is_connected(on_hover_out):
		control.mouse_exited.connect(on_hover_out)

	var on_focus_in := Callable(U_UIMotion, "_on_focus_in").bind(control, motion_set)
	if not control.focus_entered.is_connected(on_focus_in):
		control.focus_entered.connect(on_focus_in)

	var on_focus_out := Callable(U_UIMotion, "_on_focus_out").bind(control, motion_set)
	if not control.focus_exited.is_connected(on_focus_out):
		control.focus_exited.connect(on_focus_out)

	if control is BaseButton:
		var button := control as BaseButton
		var on_press := Callable(U_UIMotion, "_on_press").bind(button, motion_set)
		if not button.button_down.is_connected(on_press):
			button.button_down.connect(on_press)

static func _append_step(tween: Tween, node: Node, preset: Resource) -> bool:
	var parallel: bool = bool(preset.parallel)
	var track: Tween = tween.parallel() if parallel else tween

	var property_path: String = String(preset.property_path).strip_edges()
	if property_path.is_empty():
		var interval_sec: float = maxf(float(preset.interval_sec), 0.0)
		var delay_sec: float = maxf(float(preset.delay_sec), 0.0)
		var total_sec: float = interval_sec + delay_sec
		if total_sec <= 0.0:
			return false
		track.tween_interval(total_sec)
		return true

	var duration_sec: float = maxf(float(preset.duration_sec), 0.0)
	if duration_sec <= 0.0:
		return false

	var to_value: Variant = preset.to_value
	var tweener := track.tween_property(node, property_path, to_value, duration_sec)

	var has_from_value: bool = preset.from_value != null
	if has_from_value:
		tweener.from(preset.from_value)

	if bool(preset.relative):
		tweener.as_relative()

	var delay: float = maxf(float(preset.delay_sec), 0.0)
	if delay > 0.0:
		tweener.set_delay(delay)

	tweener.set_trans(int(preset.transition_type))
	tweener.set_ease(int(preset.ease_type))
	return true

static func _on_hover_in(control: Control, motion_set: Resource) -> void:
	if control == null or motion_set == null:
		return
	if not ("hover_in" in motion_set):
		return
	play(control, motion_set.hover_in)

static func _on_hover_out(control: Control, motion_set: Resource) -> void:
	if control == null or motion_set == null:
		return
	if not ("hover_out" in motion_set):
		return
	play(control, motion_set.hover_out)

static func _on_focus_in(control: Control, motion_set: Resource) -> void:
	if control == null or motion_set == null:
		return
	if not ("focus_in" in motion_set):
		return
	play(control, motion_set.focus_in)

static func _on_focus_out(control: Control, motion_set: Resource) -> void:
	if control == null or motion_set == null:
		return
	if not ("focus_out" in motion_set):
		return
	play(control, motion_set.focus_out)

static func _on_press(control: Control, motion_set: Resource) -> void:
	if control == null or motion_set == null:
		return
	if not ("press" in motion_set):
		return
	play(control, motion_set.press)
