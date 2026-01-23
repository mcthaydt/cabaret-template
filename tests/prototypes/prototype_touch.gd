extends RefCounted

## Research prototype for validating touchscreen input handling.
##
## Feeds InputEventScreenTouch/Drag into a simple state container that emulates
## the virtual joystick + button layout planned for Phase 6. Provides helpers
## for multi-touch tracking and 60 FPS frame budget checks.

const TARGET_FRAME_TIME_MS := 16.67

var joystick_center: Vector2 = Vector2.ZERO
var joystick_radius: float = 120.0
var joystick_deadzone: float = 0.15

var _joystick_touch_id: int = -1
var _joystick_position: Vector2 = Vector2.ZERO
var _joystick_vector: Vector2 = Vector2.ZERO

var _button_regions: Dictionary = {}
var _button_states: Dictionary = {}
var _button_touch_ids: Dictionary = {}

func configure_virtual_joystick(center: Vector2, radius: float, deadzone: float = 0.15) -> void:
	joystick_center = center
	joystick_radius = max(radius, 1.0)
	joystick_deadzone = clampf(deadzone, 0.0, 0.95)

func register_button_region(button_name: StringName, region: Rect2) -> void:
	_button_regions[button_name] = region
	_button_states[button_name] = false

func process_touch_event(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_handle_touch_press(event.index, event.position)
		else:
			_handle_touch_release(event.index)
	elif event is InputEventScreenDrag:
		_handle_touch_drag(event.index, event.position)

func get_joystick_vector() -> Vector2:
	return _joystick_vector

func get_button_state(button_name: StringName) -> bool:
	return _button_states.get(button_name, false)

func get_active_buttons() -> Array[StringName]:
	var active: Array[StringName] = []
	for name in _button_states.keys():
		if _button_states[name]:
			active.append(name)
	return active

func evaluate_frame_timings(samples_ms: Array[float]) -> Dictionary:
	if samples_ms.is_empty():
		return {
			"average_ms": 0.0,
			"max_ms": 0.0,
			"min_ms": 0.0,
			"meets_target": true,
		}

	var total := 0.0
	var max_sample := -INF
	var min_sample := INF
	for sample_ms in samples_ms:
		var sanitized: float = max(sample_ms, 0.0)
		total += sanitized
		max_sample = max(max_sample, sanitized)
		min_sample = min(min_sample, sanitized)

	var average: float = total / samples_ms.size()
	return {
		"average_ms": average,
		"max_ms": max_sample,
		"min_ms": min_sample,
		"meets_target": max_sample <= TARGET_FRAME_TIME_MS,
	}

func snapshot_state() -> Dictionary:
	return {
		"joystick_id": _joystick_touch_id,
		"joystick_vector": _joystick_vector,
		"buttons": _button_states.duplicate(),
		"button_touch_ids": _button_touch_ids.duplicate(),
	}

func _handle_touch_press(touch_id: int, position: Vector2) -> void:
	if _joystick_touch_id == -1 and _is_within_joystick(position):
		_assign_joystick_touch(touch_id, position)
		return

	for button_name in _button_regions.keys():
		var region: Rect2 = _button_regions[button_name]
		if region.has_point(position):
			_button_touch_ids[touch_id] = button_name
			_button_states[button_name] = true
			return

	# If joystick already assigned but new touch occurs in joystick area, treat as button fallback.

func _handle_touch_release(touch_id: int) -> void:
	if touch_id == _joystick_touch_id:
		_reset_joystick()
		return

	if _button_touch_ids.has(touch_id):
		var button_name: StringName = _button_touch_ids[touch_id]
		_button_states[button_name] = false
		_button_touch_ids.erase(touch_id)

func _handle_touch_drag(touch_id: int, position: Vector2) -> void:
	if touch_id == _joystick_touch_id:
		_update_joystick(position)
	elif _button_touch_ids.has(touch_id):
		var button_name: StringName = _button_touch_ids[touch_id]
		var region: Rect2 = _button_regions.get(button_name, Rect2())
		_button_states[button_name] = region.has_point(position)

func _assign_joystick_touch(touch_id: int, position: Vector2) -> void:
	_joystick_touch_id = touch_id
	_update_joystick(position)

func _reset_joystick() -> void:
	_joystick_touch_id = -1
	_joystick_position = joystick_center
	_joystick_vector = Vector2.ZERO

func _update_joystick(position: Vector2) -> void:
	_joystick_position = position
	var offset := position - joystick_center
	var clamped := Vector2.ZERO
	if offset == Vector2.ZERO:
		clamped = Vector2.ZERO
	else:
		clamped = offset / joystick_radius
		if clamped.length() > 1.0:
			clamped = clamped.normalized()

	if clamped.length() < joystick_deadzone:
		_joystick_vector = Vector2.ZERO
	else:
		_joystick_vector = clamped

func _is_within_joystick(position: Vector2) -> bool:
	return (position - joystick_center).length() <= joystick_radius
