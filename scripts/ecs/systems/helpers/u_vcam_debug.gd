extends RefCounted
class_name U_VCamDebug

const U_ECS_UTILS := preload("res://scripts/utils/ecs/u_ecs_utils.gd")
const U_VCAM_UTILS := preload("res://scripts/utils/display/u_vcam_utils.gd")

const MAX_DEBUG_ISSUES: int = 64
const MIN_LOG_INTERVAL_SEC: float = 0.05

var _enabled: bool = false
var _log_interval_sec: float = 0.25
var _rotation_log_cooldown_sec: float = 0.0
var _state_log_cooldown_sec: float = 0.0
var _state_store_provider: Callable = Callable()

var _debug_issues: Array[String] = []
var _debug_follow_target_ids: Dictionary = {}  # StringName -> int
var _debug_look_ahead_motion_state: Dictionary = {}  # StringName -> bool
var _debug_soft_zone_status: Dictionary = {}  # StringName -> String
var _debug_landing_offset_status: int = -1  # -1 unknown, 0 inactive, 1 active
var _debug_last_look_input_by_vcam: Dictionary = {}  # StringName -> Vector2

func configure(enabled: bool, log_interval_sec: float) -> void:
	_enabled = enabled
	_log_interval_sec = maxf(log_interval_sec, MIN_LOG_INTERVAL_SEC)

func set_state_store_provider(provider: Callable) -> void:
	_state_store_provider = provider

func tick(delta: float) -> void:
	if not _enabled:
		return
	_rotation_log_cooldown_sec = maxf(_rotation_log_cooldown_sec - maxf(delta, 0.0), 0.0)
	_state_log_cooldown_sec = maxf(_state_log_cooldown_sec - maxf(delta, 0.0), 0.0)

func get_debug_issues() -> Array[String]:
	return _debug_issues.duplicate()

func report_issue(message: String) -> void:
	if _debug_issues.size() >= MAX_DEBUG_ISSUES:
		_debug_issues.remove_at(0)
	_debug_issues.append(message)
	print_verbose("S_VCamSystem: %s" % message)

func prune(active_vcam_ids: Array) -> void:
	_prune_debug_dictionary(_debug_follow_target_ids, active_vcam_ids)
	_prune_debug_dictionary(_debug_look_ahead_motion_state, active_vcam_ids)
	_prune_debug_dictionary(_debug_soft_zone_status, active_vcam_ids)
	_prune_debug_dictionary(_debug_last_look_input_by_vcam, active_vcam_ids)

func clear_all() -> void:
	_debug_follow_target_ids.clear()
	_debug_look_ahead_motion_state.clear()
	_debug_soft_zone_status.clear()
	_debug_landing_offset_status = -1
	_debug_last_look_input_by_vcam.clear()

func clear_for_vcam(vcam_id: StringName) -> void:
	_debug_follow_target_ids.erase(vcam_id)
	_debug_look_ahead_motion_state.erase(vcam_id)
	_debug_soft_zone_status.erase(vcam_id)
	_debug_last_look_input_by_vcam.erase(vcam_id)

func log_follow_target_resolution(
	vcam_id: StringName,
	component: Object,
	follow_target: Node3D
) -> void:
	if not _enabled:
		return
	var target_id: int = U_VCAM_UTILS.get_node_instance_id(follow_target)
	var previous_target_id: int = int(_debug_follow_target_ids.get(vcam_id, -1))
	if previous_target_id == target_id:
		return
	_debug_follow_target_ids[vcam_id] = target_id

	var resolved_path: String = "<null>"
	if follow_target != null and is_instance_valid(follow_target):
		resolved_path = String(follow_target.get_path())
	var configured_path: String = String(component.get("follow_target_path") if component != null else NodePath(""))
	var fallback_entity_id: String = String(component.get("follow_target_entity_id") if component != null else StringName(""))
	var fallback_tag: String = String(component.get("follow_target_tag") if component != null else StringName(""))
	print(
		"S_VCamSystem[debug] follow_target: vcam_id=%s configured_path=%s fallback_entity_id=%s fallback_tag=%s resolved_path=%s resolved_id=%d"
		% [
			String(vcam_id),
			configured_path,
			fallback_entity_id,
			fallback_tag,
			resolved_path,
			target_id,
		]
	)

func log_look_ahead_motion_state(
	vcam_id: StringName,
	is_moving: bool,
	follow_target: Node3D,
	movement_velocity: Vector3,
	desired_offset: Vector3
) -> void:
	if not _enabled:
		return
	var had_state: bool = _debug_look_ahead_motion_state.has(vcam_id)
	var previous_state: bool = bool(_debug_look_ahead_motion_state.get(vcam_id, false))
	_debug_look_ahead_motion_state[vcam_id] = is_moving
	if had_state and previous_state == is_moving:
		return

	var gameplay_is_moving: bool = false
	var gameplay_velocity: Vector3 = Vector3.ZERO
	var gameplay_entity_id: StringName = StringName("")
	if follow_target != null and is_instance_valid(follow_target):
		var entity: Node = U_ECS_UTILS.find_entity_root(follow_target)
		if entity != null and is_instance_valid(entity):
			gameplay_entity_id = U_ECS_UTILS.get_entity_id(entity)
			var store := _resolve_state_store()
			if store != null:
				var state: Dictionary = store.get_state()
				var entity_state: Dictionary = U_EntitySelectors.get_entity(state, gameplay_entity_id)
				if not entity_state.is_empty():
					gameplay_is_moving = bool(entity_state.get("is_moving", false))
					var velocity_variant: Variant = entity_state.get("velocity", Vector3.ZERO)
					if velocity_variant is Vector3:
						gameplay_velocity = velocity_variant as Vector3

	print(
		"S_VCamSystem[debug] look_ahead_motion: vcam_id=%s is_moving=%s movement_speed=%.5f desired_offset_len=%.5f gameplay_entity_id=%s gameplay_is_moving=%s gameplay_velocity=%s"
		% [
			String(vcam_id),
			str(is_moving),
			movement_velocity.length(),
			desired_offset.length(),
			String(gameplay_entity_id),
			str(gameplay_is_moving),
			str(gameplay_velocity),
		]
	)

func log_soft_zone_status(vcam_id: StringName, status: String, correction: Vector3) -> void:
	if not _enabled:
		return
	var previous_status: String = String(_debug_soft_zone_status.get(vcam_id, ""))
	if previous_status == status:
		return
	_debug_soft_zone_status[vcam_id] = status

	print(
		"S_VCamSystem[debug] soft_zone: vcam_id=%s status=%s correction_len=%.5f correction=%s"
		% [
			String(vcam_id),
			status,
			correction.length(),
			str(correction),
		]
	)

func log_soft_zone_metrics(vcam_id: StringName, correction_result: Dictionary, correction: Vector3) -> void:
	if not _enabled:
		return
	var normalized_variant: Variant = correction_result.get("normalized_screen_pos", Vector2.ZERO)
	var corrected_variant: Variant = correction_result.get("corrected_normalized_pos", Vector2.ZERO)
	var dead_zone_variant: Variant = correction_result.get("dead_zone_state", {})
	var normalized_screen_pos: Vector2 = normalized_variant as Vector2 if normalized_variant is Vector2 else Vector2.ZERO
	var corrected_normalized_pos: Vector2 = corrected_variant as Vector2 if corrected_variant is Vector2 else Vector2.ZERO
	var dead_zone_state: Dictionary = dead_zone_variant as Dictionary if dead_zone_variant is Dictionary else {}
	log_rotation(
		vcam_id,
		"soft_zone_metrics norm=%s corrected=%s correction_len=%.5f dead_zone={x:%s,y:%s}"
		% [
			str(normalized_screen_pos),
			str(corrected_normalized_pos),
			correction.length(),
			str(bool(dead_zone_state.get("x", false))),
			str(bool(dead_zone_state.get("y", false))),
		]
	)

func log_look_input_transition(vcam_id: StringName, look_input: Vector2) -> void:
	if not _enabled:
		return
	var previous_variant: Variant = _debug_last_look_input_by_vcam.get(vcam_id, Vector2.ZERO)
	var previous_input: Vector2 = previous_variant as Vector2 if previous_variant is Vector2 else Vector2.ZERO
	var previously_active: bool = not previous_input.is_zero_approx()
	var currently_active: bool = not look_input.is_zero_approx()

	if previously_active and not currently_active:
		print(
			"S_VCamSystem[debug] look_input_stop: vcam_id=%s previous=%s prev_len=%.5f"
			% [String(vcam_id), str(previous_input), previous_input.length()]
		)
	elif not previously_active and currently_active:
		print(
			"S_VCamSystem[debug] look_input_start: vcam_id=%s current=%s len=%.5f"
			% [String(vcam_id), str(look_input), look_input.length()]
		)
	elif not currently_active and look_input.length_squared() > 0.0:
		log_rotation(
			vcam_id,
			"look_input_noise raw=%s len=%.6f"
			% [str(look_input), look_input.length()]
		)

	_debug_last_look_input_by_vcam[vcam_id] = look_input

func log_position_smoothing_gate_transition(
	vcam_id: StringName,
	mode_script: Script,
	has_active_look_input: bool,
	raw_position: Vector3,
	follow_dynamics: Variant,
	follow_target_speed_mps: float,
	enable_speed: float,
	disable_speed: float,
	previous_bypass: bool,
	current_bypass: bool
) -> void:
	if not _enabled:
		return
	var cached_position: Vector3 = raw_position
	if follow_dynamics != null and follow_dynamics.has_method("get_value"):
		var cached_variant: Variant = follow_dynamics.call("get_value")
		if cached_variant is Vector3:
			cached_position = cached_variant as Vector3
	var mode_label: String = _get_debug_mode_label(mode_script)
	print(
		"S_VCamSystem[debug] smoothing_gate: vcam_id=%s mode=%s active_input=%s bypass=%s->%s speed=%.4f thresholds=(%.4f,%.4f) raw_pos=%s cached_pos=%s offset_len=%.5f"
		% [
			String(vcam_id),
			mode_label,
			str(has_active_look_input),
			str(previous_bypass),
			str(current_bypass),
			follow_target_speed_mps,
			enable_speed,
			disable_speed,
			str(raw_position),
			str(cached_position),
			raw_position.distance_to(cached_position),
		]
	)

func log_landing_offset_state(landing_offset: Vector3) -> void:
	if not _enabled:
		return
	var status: int = 1 if not landing_offset.is_zero_approx() else 0
	if _debug_landing_offset_status == status:
		return
	_debug_landing_offset_status = status
	print(
		"S_VCamSystem[debug] landing_offset: status=%s offset_len=%.5f offset=%s"
		% [
			"active" if status == 1 else "inactive",
			landing_offset.length(),
			str(landing_offset),
		]
	)

func log_rotation(vcam_id: StringName, message: String) -> void:
	if not _enabled:
		return
	if _rotation_log_cooldown_sec > 0.0:
		return
	_rotation_log_cooldown_sec = _log_interval_sec
	print("S_VCamSystem[debug] %s: %s" % [str(vcam_id), message])

func log_vcam_state(message: String, active_vcam_id: StringName, look_input: Vector2) -> void:
	if not _enabled:
		return
	if _state_log_cooldown_sec > 0.0:
		return
	_state_log_cooldown_sec = _log_interval_sec
	print(
		"S_VCamSystem[debug] state: %s active_vcam_id=%s look_input=%s"
		% [message, str(active_vcam_id), str(look_input)]
	)

func _resolve_state_store() -> I_StateStore:
	if not _state_store_provider.is_valid():
		return null
	var store_variant: Variant = _state_store_provider.call()
	if store_variant == null:
		return null
	if not (store_variant is I_StateStore):
		return null
	return store_variant as I_StateStore

func _prune_debug_dictionary(debug_map: Dictionary, active_vcam_ids: Array) -> void:
	var keep_ids: Dictionary = {}
	for vcam_id_variant in active_vcam_ids:
		var keep_id: StringName = StringName(str(vcam_id_variant))
		if keep_id == StringName(""):
			continue
		keep_ids[keep_id] = true

	var stale_ids: Array[StringName] = []
	for vcam_id_variant in debug_map.keys():
		var vcam_id := vcam_id_variant as StringName
		if keep_ids.has(vcam_id):
			continue
		stale_ids.append(vcam_id)

	for stale_id in stale_ids:
		debug_map.erase(stale_id)

func _get_debug_mode_label(mode_script: Script) -> String:
	if mode_script == null:
		return "<null>"
	var global_name: String = mode_script.get_global_name()
	if not global_name.is_empty():
		return global_name
	var resource_path: String = mode_script.resource_path
	if not resource_path.is_empty():
		return resource_path.get_file().get_basename()
	return "<anonymous>"
