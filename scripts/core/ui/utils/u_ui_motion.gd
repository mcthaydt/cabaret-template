extends RefCounted
class_name U_UIMotion

const RS_UI_MOTION_PRESET := preload("res://scripts/core/resources/ui/rs_ui_motion_preset.gd")

const ACTIVE_TWEEN_META := &"_ui_motion_active_tween"
const POSITION_X_BASE_META := &"_ui_motion_position_x_base"
const POSITION_Y_BASE_META := &"_ui_motion_position_y_base"

static func play(node: Node, presets: Array[Resource]) -> Tween:
	if node == null:
		return null
	if presets.is_empty():
		return null
	if not is_instance_valid(node):
		return null

	_stop_active_tween(node)
	var tween := node.create_tween()
	var step_count: int = 0
	var cleanup_meta_keys: Array[StringName] = []

	for raw_preset: Resource in presets:
		if not (raw_preset is RS_UI_MOTION_PRESET):
			continue
		var preset: Resource = raw_preset
		if _append_step(tween, node, preset, cleanup_meta_keys):
			step_count += 1

	if step_count <= 0:
		tween.kill()
		return null
	node.set_meta(ACTIVE_TWEEN_META, tween)
	tween.finished.connect(_on_tween_finished.bind(node, tween, cleanup_meta_keys), CONNECT_ONE_SHOT)
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
	return _append_step(tween, node, preset, [])

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

static func _append_step(tween: Tween, node: Node, preset: Resource, cleanup_meta_keys: Array[StringName]) -> bool:
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

	var from_value: Variant = preset.from_value
	var to_value: Variant = preset.to_value
	if node is Control and _is_control_position_axis(property_path) and not bool(preset.relative):
		var base_axis_value := _get_or_store_control_position_axis_base(
			node as Control,
			property_path,
			cleanup_meta_keys
		)
		if _is_number(from_value):
			from_value = base_axis_value + float(from_value)
		if _is_number(to_value):
			to_value = base_axis_value + float(to_value)

	var tweener := track.tween_property(node, property_path, to_value, duration_sec)

	var has_from_value: bool = from_value != null
	if has_from_value:
		tweener.from(from_value)

	if bool(preset.relative):
		tweener.as_relative()

	var delay: float = maxf(float(preset.delay_sec), 0.0)
	if delay > 0.0:
		tweener.set_delay(delay)

	tweener.set_trans(int(preset.transition_type))
	tweener.set_ease(int(preset.ease_type))
	return true

static func _is_control_position_axis(property_path: String) -> bool:
	return property_path == "position:x" or property_path == "position:y"

static func _get_or_store_control_position_axis_base(
	control: Control,
	property_path: String,
	cleanup_meta_keys: Array[StringName]
) -> float:
	var meta_key := POSITION_X_BASE_META if property_path == "position:x" else POSITION_Y_BASE_META
	if control.has_meta(meta_key):
		return float(control.get_meta(meta_key))
	var base_value := control.position.x if property_path == "position:x" else control.position.y
	control.set_meta(meta_key, base_value)
	if not cleanup_meta_keys.has(meta_key):
		cleanup_meta_keys.append(meta_key)
	return base_value

static func _is_number(value: Variant) -> bool:
	return value is int or value is float

static func _stop_active_tween(node: Node) -> void:
	if not node.has_meta(ACTIVE_TWEEN_META):
		return
	var active_tween: Variant = node.get_meta(ACTIVE_TWEEN_META)
	if active_tween is Tween and is_instance_valid(active_tween):
		(active_tween as Tween).kill()
	node.remove_meta(ACTIVE_TWEEN_META)

static func _on_tween_finished(node: Node, tween: Tween, cleanup_meta_keys: Array[StringName]) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node.has_meta(ACTIVE_TWEEN_META) and node.get_meta(ACTIVE_TWEEN_META) == tween:
		node.remove_meta(ACTIVE_TWEEN_META)
	for meta_key in cleanup_meta_keys:
		if node.has_meta(meta_key):
			node.remove_meta(meta_key)

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
