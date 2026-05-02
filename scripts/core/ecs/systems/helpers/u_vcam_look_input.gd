extends RefCounted
class_name U_VCamLookInput
const U_DEBUG_LOG_THROTTLE := preload("res://scripts/core/utils/debug/u_debug_log_throttle.gd")

const DEFAULT_LOOK_INPUT_DEADZONE: float = 0.02
const DEFAULT_LOOK_INPUT_HOLD_SEC: float = 0.06
const DEFAULT_LOOK_INPUT_RELEASE_DECAY: float = 25.0

var debug_enabled: bool = false
var _look_input_filter_state: Dictionary = {}  # StringName -> {filtered_input, hold_timer_sec, input_active, raw_input_active}
var _debug_log_throttle: Variant = U_DEBUG_LOG_THROTTLE.new()

func filter_look_input(
	vcam_id: StringName,
	raw_look_input: Vector2,
	response_values: Dictionary,
	delta: float
) -> Vector2:
	if response_values.is_empty():
		var raw_active_without_response: bool = not raw_look_input.is_zero_approx()
		_look_input_filter_state[vcam_id] = {
			"filtered_input": raw_look_input,
			"hold_timer_sec": 0.0,
			"input_active": raw_active_without_response,
			"raw_input_active": raw_active_without_response,
		}
		return raw_look_input

	var deadzone: float = maxf(
		float(response_values.get("look_input_deadzone", DEFAULT_LOOK_INPUT_DEADZONE)),
		0.0
	)
	var hold_sec: float = maxf(
		float(response_values.get("look_input_hold_sec", DEFAULT_LOOK_INPUT_HOLD_SEC)),
		0.0
	)
	var release_decay: float = maxf(
		float(response_values.get("look_input_release_decay", DEFAULT_LOOK_INPUT_RELEASE_DECAY)),
		0.0
	)

	var state_variant: Variant = _look_input_filter_state.get(vcam_id, {})
	var filtered_input: Vector2 = Vector2.ZERO
	var hold_timer_sec: float = 0.0
	var input_active: bool = false
	var previous_raw_input_active: bool = false
	var previous_filtered_input: Vector2 = Vector2.ZERO
	var previous_input_active: bool = false
	if state_variant is Dictionary:
		var state := state_variant as Dictionary
		var filtered_variant: Variant = state.get("filtered_input", Vector2.ZERO)
		if filtered_variant is Vector2:
			filtered_input = filtered_variant as Vector2
			previous_filtered_input = filtered_input
		hold_timer_sec = maxf(float(state.get("hold_timer_sec", 0.0)), 0.0)
		input_active = bool(state.get("input_active", false))
		previous_input_active = input_active
		previous_raw_input_active = bool(state.get("raw_input_active", false))

	var has_raw_input: bool = is_active(raw_look_input, response_values)
	if has_raw_input:
		filtered_input = raw_look_input
		hold_timer_sec = hold_sec
		input_active = true
	else:
		hold_timer_sec = maxf(hold_timer_sec - maxf(delta, 0.0), 0.0)
		if hold_timer_sec <= 0.0:
			if release_decay > 0.0 and delta > 0.0:
				var decay_factor: float = clampf(release_decay * delta, 0.0, 1.0)
				filtered_input = filtered_input.lerp(Vector2.ZERO, decay_factor)
			else:
				filtered_input = Vector2.ZERO
		input_active = is_active(filtered_input, response_values)
		if not input_active and filtered_input.length_squared() <= deadzone * deadzone:
			filtered_input = Vector2.ZERO

	_debug_log_look_filter_state_transition(
		vcam_id,
		raw_look_input,
		filtered_input,
		has_raw_input,
		previous_raw_input_active,
		previous_input_active,
		input_active,
		previous_filtered_input,
		hold_timer_sec,
		deadzone,
		hold_sec,
		release_decay
	)
	_look_input_filter_state[vcam_id] = {
		"filtered_input": filtered_input,
		"hold_timer_sec": hold_timer_sec,
		"input_active": input_active,
		"raw_input_active": has_raw_input,
	}
	return filtered_input

func is_active(look_input: Vector2, response_values: Dictionary) -> bool:
	if response_values.is_empty():
		return not look_input.is_zero_approx()
	var deadzone: float = maxf(
		float(response_values.get("look_input_deadzone", DEFAULT_LOOK_INPUT_DEADZONE)),
		0.0
	)
	return look_input.length_squared() > deadzone * deadzone

func prune(active_vcam_ids: Array) -> void:
	var keep_ids: Dictionary = {}
	for vcam_id_variant in active_vcam_ids:
		var keep_id: StringName = StringName(str(vcam_id_variant))
		if keep_id == StringName(""):
			continue
		keep_ids[keep_id] = true

	var stale_ids: Array[StringName] = []
	for vcam_id_variant in _look_input_filter_state.keys():
		var vcam_id: StringName = vcam_id_variant as StringName
		if keep_ids.has(vcam_id):
			continue
		stale_ids.append(vcam_id)

	for stale_id in stale_ids:
		_look_input_filter_state.erase(stale_id)

func clear_all() -> void:
	_look_input_filter_state.clear()

func clear_for_vcam(vcam_id: StringName) -> void:
	_look_input_filter_state.erase(vcam_id)

func get_state_snapshot() -> Dictionary:
	return _look_input_filter_state.duplicate(true)

func _debug_log_look_filter_state_transition(
	vcam_id: StringName,
	raw_look_input: Vector2,
	filtered_look_input: Vector2,
	raw_input_active: bool,
	previous_raw_input_active: bool,
	previous_filtered_active: bool,
	filtered_active: bool,
	previous_filtered_input: Vector2,
	hold_timer_sec: float,
	deadzone: float,
	hold_sec: float,
	release_decay: float
) -> void:
	if not debug_enabled:
		return

	var raw_changed: bool = previous_raw_input_active != raw_input_active
	var filtered_changed: bool = previous_filtered_active != filtered_active
	var release_tail_active: bool = (
		not raw_input_active
		and filtered_active
		and hold_timer_sec <= 0.0
		and filtered_look_input.length() > deadzone
	)
	if not raw_changed and not filtered_changed and not release_tail_active:
		return

	_debug_log_throttle.log_message(
		"U_VCamLookInput[debug] look_filter: vcam_id=%s raw=%s raw_active=%s filtered=%s prev_filtered=%s filtered_active=%s->%s hold_timer=%.4f deadzone=%.4f hold=%.4f decay=%.4f"
		% [
			String(vcam_id),
			str(raw_look_input),
			str(raw_input_active),
			str(filtered_look_input),
			str(previous_filtered_input),
			str(previous_filtered_active),
			str(filtered_active),
			hold_timer_sec,
			deadzone,
			hold_sec,
			release_decay,
		]
	)
