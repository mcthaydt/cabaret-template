@icon("res://assets/editor_icons/icn_system.svg")
extends BaseECSSystem
class_name S_VCamSystem

const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_STATE_UTILS := preload("res://scripts/state/utils/u_state_utils.gd")
const U_INPUT_SELECTORS := preload("res://scripts/state/selectors/u_input_selectors.gd")
const U_VCAM_MODE_EVALUATOR := preload("res://scripts/managers/helpers/u_vcam_mode_evaluator.gd")
const U_VCAM_SOFT_ZONE := preload("res://scripts/managers/helpers/u_vcam_soft_zone.gd")
const U_ECS_UTILS := preload("res://scripts/utils/ecs/u_ecs_utils.gd")
const U_SECOND_ORDER_DYNAMICS := preload("res://scripts/utils/math/u_second_order_dynamics.gd")
const U_SECOND_ORDER_DYNAMICS_3D := preload("res://scripts/utils/math/u_second_order_dynamics_3d.gd")
const I_VCAM_MANAGER := preload("res://scripts/interfaces/i_vcam_manager.gd")
const I_CAMERA_MANAGER := preload("res://scripts/interfaces/i_camera_manager.gd")
const C_VCAM_COMPONENT := preload("res://scripts/ecs/components/c_vcam_component.gd")
const C_CAMERA_STATE_COMPONENT := preload("res://scripts/ecs/components/c_camera_state_component.gd")
const C_MOVEMENT_COMPONENT_SCRIPT := preload("res://scripts/ecs/components/c_movement_component.gd")
const C_CHARACTER_STATE_COMPONENT_SCRIPT := preload("res://scripts/ecs/components/c_character_state_component.gd")
const RS_VCAM_MODE_ORBIT_SCRIPT := preload("res://scripts/resources/display/vcam/rs_vcam_mode_orbit.gd")
const RS_VCAM_MODE_FIRST_PERSON_SCRIPT := preload("res://scripts/resources/display/vcam/rs_vcam_mode_first_person.gd")
const RS_VCAM_MODE_OTS_SCRIPT := preload("res://scripts/resources/display/vcam/rs_vcam_mode_ots.gd")
const RS_VCAM_MODE_FIXED_SCRIPT := preload("res://scripts/resources/display/vcam/rs_vcam_mode_fixed.gd")
const RS_VCAM_RESPONSE_SCRIPT := preload("res://scripts/resources/display/vcam/rs_vcam_response.gd")
const RS_VCAM_SOFT_ZONE_SCRIPT := preload("res://scripts/resources/display/vcam/rs_vcam_soft_zone.gd")

const CAMERA_STATE_TYPE := C_CAMERA_STATE_COMPONENT.COMPONENT_TYPE
const PRIMARY_CAMERA_ENTITY_ID := StringName("camera")
const OTS_MIN_CAMERA_DISTANCE: float = 0.1
const LOOK_AHEAD_MOVEMENT_EPSILON_SQ: float = 0.000001
const IDLE_LOOK_SETTLE_DEG_PER_HZ: float = 20.0
const MIN_IDLE_LOOK_SETTLE_DEG_PER_SEC: float = 45.0
const DEFAULT_LOOK_INPUT_DEADZONE: float = 0.02
const DEFAULT_LOOK_INPUT_HOLD_SEC: float = 0.06
const DEFAULT_LOOK_INPUT_RELEASE_DECAY: float = 25.0
const DEFAULT_LOOK_RELEASE_YAW_DAMPING: float = 10.0
const DEFAULT_LOOK_RELEASE_PITCH_DAMPING: float = 12.0
const DEFAULT_LOOK_RELEASE_STOP_THRESHOLD: float = 0.05
const ORBIT_RELEASE_SIGN_FLIP_SETTLE_ERROR_DEG: float = 0.25
const DEFAULT_ORBIT_LOOK_BYPASS_ENABLE_SPEED: float = 0.15
const DEFAULT_ORBIT_LOOK_BYPASS_DISABLE_SPEED: float = 0.3
const ORBIT_CENTER_DURATION_SEC: float = 0.3

@export var state_store: I_StateStore = null
@export var vcam_manager: I_VCAM_MANAGER = null
@export var debug_rotation_logging: bool = false
@export_range(0.05, 5.0, 0.05) var debug_rotation_log_interval_sec: float = 0.25

var _state_store: I_StateStore = null
var _vcam_manager: Node = null
var _path_follow_helpers: Dictionary = {}  # StringName -> PathFollow3D
var _follow_dynamics: Dictionary = {}  # StringName -> U_SecondOrderDynamics3D
var _rotation_dynamics: Dictionary = {}  # StringName -> {x, y, z}
var _smoothing_metadata: Dictionary = {}  # StringName -> {mode_script, follow_target_id, response_signature}
var _look_rotation_state: Dictionary = {}  # StringName -> {smoothed_yaw, smoothed_pitch, yaw_velocity, pitch_velocity, mode_script, follow_target_id, response_signature}
var _rotation_target_cache: Dictionary = {}  # StringName -> Vector3 (unwrapped radians)
var _look_ahead_state: Dictionary = {}  # StringName -> {follow_target_id, last_target_position, current_offset, smoothing_hz, dynamics}
var _ground_relative_state: Dictionary = {}  # StringName -> {follow_target_id, ground_anchor_y, ground_anchor_target_y, follow_anchor_y_offset, last_ground_reference_y, was_grounded, blend_hz, dynamics}
var _first_person_strafe_tilt_state: Dictionary = {}  # StringName -> {dynamics, smoothing_hz}
var _ots_collision_state: Dictionary = {}  # StringName -> {follow_target_id, recovery_speed_hz, current_distance, dynamics}
var _look_input_filter_state: Dictionary = {}  # StringName -> {filtered_input, hold_timer_sec, input_active}
var _follow_target_motion_state: Dictionary = {}  # StringName -> {follow_target_id, last_position, speed_mps}
var _orbit_no_look_input_timers: Dictionary = {}  # StringName -> float seconds
var _orbit_centering_state: Dictionary = {}  # StringName -> {start_yaw,start_pitch,target_yaw,target_pitch,elapsed_sec,duration_sec}
var _soft_zone_dead_zone_state: Dictionary = {}  # StringName -> {x: bool, y: bool}
var _debug_issues: Array[String] = []
var _last_active_vcam_id: StringName = StringName("")
var _landing_recovery_dynamics = null
var _landing_recovery_state_id: int = 0
var _landing_recovery_frequency_hz: float = -1.0
var _debug_rotation_log_cooldown_sec: float = 0.0
var _debug_state_log_cooldown_sec: float = 0.0
var _debug_follow_target_ids: Dictionary = {}  # StringName -> int
var _debug_look_ahead_motion_state: Dictionary = {}  # StringName -> bool
var _debug_soft_zone_status: Dictionary = {}  # StringName -> String reason/state
var _debug_landing_offset_status: int = -1  # -1 unknown, 0 inactive, 1 active
var _debug_last_look_input_by_vcam: Dictionary = {}  # StringName -> Vector2
var _debug_position_smoothing_bypass_by_vcam: Dictionary = {}  # StringName -> bool
var _debug_last_look_spring_stage_by_vcam: Dictionary = {}  # StringName -> String

func process_tick(delta: float) -> void:
	if debug_rotation_logging:
		_debug_rotation_log_cooldown_sec = maxf(_debug_rotation_log_cooldown_sec - maxf(delta, 0.0), 0.0)
		_debug_state_log_cooldown_sec = maxf(_debug_state_log_cooldown_sec - maxf(delta, 0.0), 0.0)
	var manager := _resolve_vcam_manager()
	if manager == null:
		_debug_log_vcam_state("blocked: no vcam_manager service", StringName(""), Vector2.ZERO)
		_last_active_vcam_id = StringName("")
		return

	var active_vcam_id: StringName = manager.get_active_vcam_id()
	if active_vcam_id == StringName(""):
		_debug_log_vcam_state("blocked: active_vcam_id is empty", StringName(""), Vector2.ZERO)
		_last_active_vcam_id = StringName("")
		return

	var vcam_index: Dictionary = _build_vcam_index()
	if vcam_index.is_empty():
		_debug_log_vcam_state("blocked: vcam_index is empty", active_vcam_id, Vector2.ZERO)
		_last_active_vcam_id = StringName("")
		return
	_prune_path_helpers(vcam_index)
	_prune_smoothing_state(vcam_index)
	_apply_rotation_continuity_policy(active_vcam_id, vcam_index, manager)

	var look_input: Vector2 = _read_look_input()
	var move_input: Vector2 = _read_move_input()
	var camera_center_just_pressed: bool = _read_camera_center_just_pressed()
	_debug_log_vcam_state("tick", active_vcam_id, look_input)
	var landing_offset: Vector3 = _resolve_landing_impact_offset(delta)
	_evaluate_and_submit(
		active_vcam_id,
		vcam_index,
		look_input,
		move_input,
		camera_center_just_pressed,
		landing_offset,
		manager,
		delta
	)

	if not manager.is_blending():
		return

	var previous_vcam_id: StringName = manager.get_previous_vcam_id()
	if previous_vcam_id == StringName("") or previous_vcam_id == active_vcam_id:
		return
	_evaluate_and_submit(
		previous_vcam_id,
		vcam_index,
		look_input,
		move_input,
		false,
		landing_offset,
		manager,
		delta
	)

func get_debug_issues() -> Array[String]:
	return _debug_issues.duplicate()

func _exit_tree() -> void:
	_teardown_path_helpers()
	_clear_all_smoothing_state()
	_clear_landing_impact_recovery_state()
	_look_ahead_state.clear()
	_ground_relative_state.clear()
	_orbit_no_look_input_timers.clear()
	_soft_zone_dead_zone_state.clear()
	_last_active_vcam_id = StringName("")

func _apply_rotation_continuity_policy(
	active_vcam_id: StringName,
	vcam_index: Dictionary,
	manager: I_VCAM_MANAGER
) -> void:
	if _last_active_vcam_id == active_vcam_id:
		return

	var incoming_component := vcam_index.get(active_vcam_id, null) as C_VCamComponent
	if incoming_component == null or not is_instance_valid(incoming_component):
		_last_active_vcam_id = active_vcam_id
		return

	var outgoing_vcam_id: StringName = manager.get_previous_vcam_id()
	if outgoing_vcam_id == StringName("") or outgoing_vcam_id == active_vcam_id:
		outgoing_vcam_id = _last_active_vcam_id
	if outgoing_vcam_id == StringName("") or outgoing_vcam_id == active_vcam_id:
		_last_active_vcam_id = active_vcam_id
		return

	var outgoing_component := vcam_index.get(outgoing_vcam_id, null) as C_VCamComponent
	if outgoing_component == null or not is_instance_valid(outgoing_component):
		_last_active_vcam_id = active_vcam_id
		return

	_apply_rotation_transition(outgoing_component, incoming_component)
	_last_active_vcam_id = active_vcam_id

func _apply_rotation_transition(outgoing_component: C_VCamComponent, incoming_component: C_VCamComponent) -> void:
	if outgoing_component == null or incoming_component == null:
		return
	if outgoing_component.mode == null or incoming_component.mode == null:
		return

	var outgoing_mode_script := outgoing_component.mode.get_script() as Script
	var incoming_mode_script := incoming_component.mode.get_script() as Script
	if outgoing_mode_script == null or incoming_mode_script == null:
		return

	if outgoing_mode_script == incoming_mode_script:
		_apply_same_mode_rotation_transition(outgoing_component, incoming_component)
		return

	if (
		outgoing_mode_script == RS_VCAM_MODE_ORBIT_SCRIPT
		and incoming_mode_script == RS_VCAM_MODE_FIRST_PERSON_SCRIPT
	):
		incoming_component.runtime_yaw = outgoing_component.runtime_yaw
		incoming_component.runtime_pitch = 0.0
		return

	if (
		outgoing_mode_script == RS_VCAM_MODE_FIRST_PERSON_SCRIPT
		and incoming_mode_script == RS_VCAM_MODE_ORBIT_SCRIPT
	):
		incoming_component.runtime_yaw = outgoing_component.runtime_yaw
		incoming_component.runtime_pitch = 0.0
		return

	if (
		outgoing_mode_script == RS_VCAM_MODE_FIXED_SCRIPT
		and (
			incoming_mode_script == RS_VCAM_MODE_ORBIT_SCRIPT
			or incoming_mode_script == RS_VCAM_MODE_FIRST_PERSON_SCRIPT
		)
	):
		var authored_angles: Vector2 = _resolve_authored_rotation(incoming_component.mode)
		incoming_component.runtime_yaw = authored_angles.x
		incoming_component.runtime_pitch = 0.0

func _apply_same_mode_rotation_transition(
	outgoing_component: C_VCamComponent,
	incoming_component: C_VCamComponent
) -> void:
	if _components_share_follow_target(outgoing_component, incoming_component):
		incoming_component.runtime_yaw = outgoing_component.runtime_yaw
		incoming_component.runtime_pitch = outgoing_component.runtime_pitch
		return

	var authored_angles: Vector2 = _resolve_authored_rotation(incoming_component.mode)
	incoming_component.runtime_yaw = authored_angles.x
	incoming_component.runtime_pitch = authored_angles.y

func _components_share_follow_target(
	outgoing_component: C_VCamComponent,
	incoming_component: C_VCamComponent
) -> bool:
	if outgoing_component == null or incoming_component == null:
		return false

	var outgoing_target: Node3D = _resolve_follow_target(outgoing_component)
	var incoming_target: Node3D = _resolve_follow_target(incoming_component)
	if outgoing_target == null or incoming_target == null:
		return false
	return _get_node_instance_id(outgoing_target) == _get_node_instance_id(incoming_target)

func _resolve_authored_rotation(mode: Resource) -> Vector2:
	if mode == null:
		return Vector2.ZERO

	var mode_script := mode.get_script() as Script
	if mode_script == RS_VCAM_MODE_ORBIT_SCRIPT:
		var orbit_values: Dictionary = _resolve_mode_values(mode, {
			"authored_yaw": 0.0,
			"authored_pitch": 0.0,
		})
		return Vector2(
			float(orbit_values.get("authored_yaw", 0.0)),
			float(orbit_values.get("authored_pitch", 0.0))
		)

	return Vector2.ZERO

func _evaluate_and_submit(
	vcam_id: StringName,
	vcam_index: Dictionary,
	look_input: Vector2,
	move_input: Vector2,
	camera_center_just_pressed: bool,
	landing_offset: Vector3,
	manager: I_VCAM_MANAGER,
	delta: float
) -> void:
	var component := vcam_index.get(vcam_id, null) as C_VCamComponent
	if component == null or not is_instance_valid(component):
		return

	var mode: Resource = component.mode
	if mode == null:
		return

	var follow_target: Node3D = _resolve_follow_target(component)
	_debug_log_follow_target_resolution(vcam_id, component, follow_target)
	var fixed_anchor: Node3D = component.get_fixed_anchor()
	if _is_path_fixed_mode(mode):
		fixed_anchor = _resolve_or_create_path_anchor(component, follow_target)
		if fixed_anchor == null:
			return

	var response_values: Dictionary = _resolve_component_response_values(component)
	var filtered_look_input: Vector2 = _resolve_filtered_look_input(
		vcam_id,
		look_input,
		response_values,
		delta
	)
	var has_active_look_input: bool = _is_filtered_look_input_active(
		filtered_look_input,
		response_values
	)
	_update_runtime_rotation(
		vcam_id,
		component,
		mode,
		follow_target,
		look_input,
		has_active_look_input,
		camera_center_just_pressed,
		delta
	)
	if _is_orbit_centering_active(vcam_id):
		has_active_look_input = false
	_debug_log_look_input_transition(vcam_id, filtered_look_input)
	var runtime_rotation: Vector2 = _resolve_runtime_rotation_for_evaluation(
		vcam_id,
		component,
		mode,
		follow_target,
		response_values,
		has_active_look_input,
		delta
	)
	var look_at_target: Node3D = component.get_look_at_target()
	var result: Dictionary = U_VCAM_MODE_EVALUATOR.evaluate(
		mode,
		follow_target,
		look_at_target,
		runtime_rotation.x,
		runtime_rotation.y,
		fixed_anchor
	)
	if result.is_empty():
		return
	result = _apply_first_person_strafe_tilt(vcam_id, mode, result, move_input, delta)
	result = _apply_ots_collision_avoidance(vcam_id, mode, follow_target, result, delta)
	var look_ahead_result: Dictionary = _apply_orbit_look_ahead(
		vcam_id,
		component,
		mode,
		follow_target,
		result,
		has_active_look_input,
		delta
	)
	var ground_relative_result: Dictionary = _apply_orbit_ground_relative(
		vcam_id,
		component,
		mode,
		follow_target,
		look_ahead_result,
		response_values,
		delta
	)
	var soft_zone_result: Dictionary = _apply_orbit_soft_zone(
		vcam_id,
		component,
		mode,
		follow_target,
		ground_relative_result,
		delta
	)
	var smoothed_result: Dictionary = _apply_response_smoothing(
		vcam_id,
		component,
		mode,
		follow_target,
		soft_zone_result,
		delta,
		has_active_look_input
	)
	var final_result: Dictionary = _apply_landing_impact_offset(smoothed_result, landing_offset)
	if vcam_id == manager.get_active_vcam_id():
		_write_active_camera_base_fov_from_result(final_result)
	manager.submit_evaluated_camera(vcam_id, final_result)

func _apply_landing_impact_offset(result: Dictionary, landing_offset: Vector3) -> Dictionary:
	if landing_offset.is_zero_approx():
		_debug_log_landing_offset_state(landing_offset)
		return result
	_debug_log_landing_offset_state(landing_offset)
	return _apply_position_offset(result, landing_offset)

func _apply_first_person_strafe_tilt(
	vcam_id: StringName,
	mode: Resource,
	result: Dictionary,
	move_input: Vector2,
	delta: float
) -> Dictionary:
	if mode == null or result.is_empty():
		return result

	var mode_script := mode.get_script() as Script
	if mode_script != RS_VCAM_MODE_FIRST_PERSON_SCRIPT:
		_clear_first_person_strafe_tilt_state_for_vcam(vcam_id)
		return result

	var transform_variant: Variant = result.get("transform", null)
	if not (transform_variant is Transform3D):
		return result

	var first_person_values: Dictionary = _resolve_mode_values(mode, {
		"strafe_tilt_angle": 0.0,
		"strafe_tilt_smoothing": 6.0,
	})
	var strafe_tilt_angle: float = maxf(float(first_person_values.get("strafe_tilt_angle", 0.0)), 0.0)
	if strafe_tilt_angle <= 0.0:
		_clear_first_person_strafe_tilt_state_for_vcam(vcam_id)
		return result

	var strafe_tilt_smoothing: float = maxf(float(first_person_values.get("strafe_tilt_smoothing", 6.0)), 0.0)
	var clamped_lateral_input: float = clampf(move_input.x, -1.0, 1.0)
	var target_roll_deg: float = clamped_lateral_input * strafe_tilt_angle
	var smoothed_roll_deg: float = target_roll_deg

	if strafe_tilt_smoothing > 0.0 and delta > 0.0:
		var state: Dictionary = _ensure_first_person_strafe_tilt_state(vcam_id, strafe_tilt_smoothing)
		var dynamics_variant: Variant = state.get("dynamics", null)
		if dynamics_variant != null:
			smoothed_roll_deg = float(dynamics_variant.step(target_roll_deg, delta))
	else:
		_clear_first_person_strafe_tilt_state_for_vcam(vcam_id)

	var transformed := transform_variant as Transform3D
	var roll_rad: float = deg_to_rad(smoothed_roll_deg)
	transformed.basis = transformed.basis.rotated(transformed.basis.z, roll_rad).orthonormalized()
	var tilted_result: Dictionary = result.duplicate(true)
	tilted_result["transform"] = transformed
	return tilted_result

func _ensure_first_person_strafe_tilt_state(vcam_id: StringName, smoothing_hz: float) -> Dictionary:
	var existing_state_variant: Variant = _first_person_strafe_tilt_state.get(vcam_id, {})
	if existing_state_variant is Dictionary:
		var existing_state := existing_state_variant as Dictionary
		var existing_hz: float = float(existing_state.get("smoothing_hz", -1.0))
		var existing_dynamics: Variant = existing_state.get("dynamics", null)
		if existing_dynamics != null and is_equal_approx(existing_hz, smoothing_hz):
			return existing_state

		var initial_roll_deg: float = 0.0
		if existing_dynamics != null and existing_dynamics.has_method("get_value"):
			initial_roll_deg = float(existing_dynamics.call("get_value"))
		var rebuilt_state: Dictionary = {
			"dynamics": U_SECOND_ORDER_DYNAMICS.new(smoothing_hz, 1.0, 1.0, initial_roll_deg),
			"smoothing_hz": smoothing_hz,
		}
		_first_person_strafe_tilt_state[vcam_id] = rebuilt_state
		return rebuilt_state

	var created_state: Dictionary = {
		"dynamics": U_SECOND_ORDER_DYNAMICS.new(smoothing_hz, 1.0, 1.0, 0.0),
		"smoothing_hz": smoothing_hz,
	}
	_first_person_strafe_tilt_state[vcam_id] = created_state
	return created_state

func _clear_first_person_strafe_tilt_state_for_vcam(vcam_id: StringName) -> void:
	_first_person_strafe_tilt_state.erase(vcam_id)

func _apply_ots_collision_avoidance(
	vcam_id: StringName,
	mode: Resource,
	follow_target: Node3D,
	result: Dictionary,
	delta: float
) -> Dictionary:
	if mode == null or result.is_empty():
		_clear_ots_collision_state_for_vcam(vcam_id)
		return result

	var mode_script := mode.get_script() as Script
	if mode_script != RS_VCAM_MODE_OTS_SCRIPT:
		_clear_ots_collision_state_for_vcam(vcam_id)
		return result
	if follow_target == null or not is_instance_valid(follow_target):
		_clear_ots_collision_state_for_vcam(vcam_id)
		return result

	var transform_variant: Variant = result.get("transform", null)
	if not (transform_variant is Transform3D):
		_clear_ots_collision_state_for_vcam(vcam_id)
		return result
	var desired_transform := transform_variant as Transform3D

	var world: World3D = follow_target.get_world_3d()
	if world == null:
		_clear_ots_collision_state_for_vcam(vcam_id)
		return result
	var space_state: PhysicsDirectSpaceState3D = world.direct_space_state
	if space_state == null:
		_clear_ots_collision_state_for_vcam(vcam_id)
		return result

	var mode_values: Dictionary = _resolve_mode_values(mode, {
		"shoulder_offset": Vector3.ZERO,
		"camera_distance": 0.0,
		"collision_probe_radius": 0.15,
		"collision_recovery_speed": 8.0,
	})
	var cast_origin: Vector3 = _resolve_ots_collision_cast_origin(desired_transform, follow_target, mode_values)
	var cast_offset: Vector3 = desired_transform.origin - cast_origin
	var desired_distance: float = cast_offset.length()
	if desired_distance <= 0.0:
		_clear_ots_collision_state_for_vcam(vcam_id)
		return result

	var probe_radius: float = maxf(float(mode_values.get("collision_probe_radius", 0.15)), 0.0)
	var recovery_speed_hz: float = maxf(float(mode_values.get("collision_recovery_speed", 8.0)), 0.0001)
	var follow_target_id: int = _get_node_instance_id(follow_target)
	var state: Dictionary = _get_or_create_ots_collision_state(
		vcam_id,
		follow_target_id,
		desired_distance,
		recovery_speed_hz
	)
	var dynamics: Variant = state.get("dynamics", null)

	var hit_data: Dictionary = _resolve_ots_collision_hit_distance(
		space_state,
		follow_target,
		cast_origin,
		cast_offset,
		probe_radius
	)
	var has_hit: bool = bool(hit_data.get("hit", false))
	var hit_distance: float = float(hit_data.get("distance", desired_distance))
	var target_distance: float = desired_distance
	if has_hit:
		target_distance = clampf(hit_distance - probe_radius, OTS_MIN_CAMERA_DISTANCE, desired_distance)

	var resolved_distance: float = target_distance
	if dynamics != null and delta > 0.0:
		resolved_distance = float(dynamics.step(target_distance, delta))
	if has_hit:
		resolved_distance = minf(resolved_distance, target_distance)
	resolved_distance = clampf(resolved_distance, OTS_MIN_CAMERA_DISTANCE, desired_distance)
	if is_nan(resolved_distance) or is_inf(resolved_distance):
		resolved_distance = target_distance

	state["current_distance"] = resolved_distance
	_ots_collision_state[vcam_id] = state

	var adjusted_transform := desired_transform
	adjusted_transform.origin = cast_origin + cast_offset.normalized() * resolved_distance
	var adjusted_result: Dictionary = result.duplicate(true)
	adjusted_result["transform"] = adjusted_transform
	return adjusted_result

func _resolve_ots_collision_cast_origin(
	desired_transform: Transform3D,
	follow_target: Node3D,
	mode_values: Dictionary
) -> Vector3:
	var fallback_origin: Vector3 = follow_target.global_position
	if mode_values.is_empty():
		return fallback_origin

	var shoulder_offset_variant: Variant = mode_values.get("shoulder_offset", Vector3.ZERO)
	if shoulder_offset_variant is Vector3:
		var shoulder_offset := shoulder_offset_variant as Vector3
		if not is_nan(shoulder_offset.y) and not is_inf(shoulder_offset.y):
			# Keep collision origin on the target centerline while lifting to shoulder height.
			# This avoids floor-origin overlap and prevents near-hit clamps from collapsing into shoulder geometry.
			return fallback_origin + (Vector3.UP * shoulder_offset.y)

	var camera_distance: float = maxf(float(mode_values.get("camera_distance", 0.0)), 0.0)
	if camera_distance <= 0.0:
		return fallback_origin

	var back_direction: Vector3 = desired_transform.basis.z
	if back_direction.length_squared() <= 0.000001:
		return fallback_origin
	return desired_transform.origin - back_direction.normalized() * camera_distance

func _get_or_create_ots_collision_state(
	vcam_id: StringName,
	follow_target_id: int,
	initial_distance: float,
	recovery_speed_hz: float
) -> Dictionary:
	var state_variant: Variant = _ots_collision_state.get(vcam_id, {})
	var state: Dictionary = {}
	if state_variant is Dictionary:
		state = (state_variant as Dictionary).duplicate(true)

	var current_distance: float = maxf(float(state.get("current_distance", initial_distance)), OTS_MIN_CAMERA_DISTANCE)
	var previous_target_id: int = int(state.get("follow_target_id", 0))
	var previous_recovery_hz: float = float(state.get("recovery_speed_hz", -1.0))
	var dynamics: Variant = state.get("dynamics", null)
	if state.is_empty() or previous_target_id != follow_target_id:
		current_distance = maxf(initial_distance, OTS_MIN_CAMERA_DISTANCE)
		dynamics = U_SECOND_ORDER_DYNAMICS.new(recovery_speed_hz, 1.0, 1.0, current_distance)
	elif dynamics == null or not is_equal_approx(previous_recovery_hz, recovery_speed_hz):
		dynamics = U_SECOND_ORDER_DYNAMICS.new(recovery_speed_hz, 1.0, 1.0, current_distance)

	state["follow_target_id"] = follow_target_id
	state["recovery_speed_hz"] = recovery_speed_hz
	state["current_distance"] = current_distance
	state["dynamics"] = dynamics
	return state

func _resolve_ots_collision_hit_distance(
	space_state: PhysicsDirectSpaceState3D,
	follow_target: Node3D,
	cast_origin: Vector3,
	cast_offset: Vector3,
	probe_radius: float
) -> Dictionary:
	var cast_distance: float = cast_offset.length()
	if cast_distance <= 0.0:
		return {
			"hit": false,
			"distance": 0.0,
		}

	var cast_direction: Vector3 = cast_offset / cast_distance
	var exclude_rids: Array[RID] = _build_ots_collision_exclude_rids(follow_target)
	if probe_radius <= 0.0:
		return _resolve_ots_collision_hit_distance_with_ray(
			space_state,
			cast_origin,
			cast_direction,
			cast_distance,
			exclude_rids
		)

	var shape := SphereShape3D.new()
	shape.radius = probe_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, cast_origin)
	query.motion = cast_direction * cast_distance
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = exclude_rids

	var overlap_query := PhysicsShapeQueryParameters3D.new()
	overlap_query.shape = shape
	overlap_query.transform = Transform3D(Basis.IDENTITY, cast_origin)
	overlap_query.collide_with_areas = false
	overlap_query.collide_with_bodies = true
	overlap_query.exclude = exclude_rids
	var initial_overlaps: Array[Dictionary] = space_state.intersect_shape(overlap_query, 1)
	if not initial_overlaps.is_empty():
		return {
			"hit": true,
			"distance": 0.0,
		}

	var motion_result: PackedFloat32Array = space_state.cast_motion(query)
	if motion_result.size() == 0:
		return {
			"hit": false,
			"distance": cast_distance,
		}
	var safe_fraction: float = clampf(float(motion_result[0]), 0.0, 1.0)
	if safe_fraction >= 1.0:
		return {
			"hit": false,
			"distance": cast_distance,
		}
	return {
		"hit": true,
		"distance": maxf(cast_distance * safe_fraction, 0.0),
	}

func _resolve_ots_collision_hit_distance_with_ray(
	space_state: PhysicsDirectSpaceState3D,
	cast_origin: Vector3,
	cast_direction: Vector3,
	cast_distance: float,
	exclude_rids: Array[RID]
) -> Dictionary:
	var ray_to: Vector3 = cast_origin + cast_direction * cast_distance
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(cast_origin, ray_to)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = exclude_rids
	var hit: Dictionary = space_state.intersect_ray(query)
	if hit.is_empty():
		return {
			"hit": false,
			"distance": cast_distance,
		}

	var hit_position_variant: Variant = hit.get("position", ray_to)
	if not (hit_position_variant is Vector3):
		return {
			"hit": false,
			"distance": cast_distance,
		}
	var hit_position := hit_position_variant as Vector3
	return {
		"hit": true,
		"distance": maxf(cast_origin.distance_to(hit_position), 0.0),
	}

func _build_ots_collision_exclude_rids(follow_target: Node3D) -> Array[RID]:
	var exclude_rids: Array[RID] = []
	var entity_root: Node = U_ECS_UTILS.find_entity_root(follow_target)
	if entity_root != null and is_instance_valid(entity_root):
		var entity_collision := entity_root as CollisionObject3D
		if entity_collision != null:
			_append_unique_collision_rid(exclude_rids, entity_collision)

	# Follow targets are often non-collision anchors under CharacterBody3D.
	# Walk parent chain so we still exclude the owning player body.
	var current: Node = follow_target
	while current != null:
		var chain_collision := current as CollisionObject3D
		if chain_collision != null:
			_append_unique_collision_rid(exclude_rids, chain_collision)
		if entity_root != null and current == entity_root:
			break
		current = current.get_parent()

	var follow_collision := follow_target as CollisionObject3D
	if follow_collision != null:
		_append_unique_collision_rid(exclude_rids, follow_collision)
	if exclude_rids.is_empty():
		var follow_body: CharacterBody3D = _find_character_body_recursive(follow_target)
		if follow_body != null and is_instance_valid(follow_body):
			_append_unique_collision_rid(exclude_rids, follow_body)
	return exclude_rids

func _append_unique_collision_rid(exclude_rids: Array[RID], collision_object: CollisionObject3D) -> void:
	if collision_object == null or not is_instance_valid(collision_object):
		return
	var rid: RID = collision_object.get_rid()
	if not rid.is_valid():
		return
	if exclude_rids.has(rid):
		return
	exclude_rids.append(rid)

func _clear_ots_collision_state_for_vcam(vcam_id: StringName) -> void:
	_ots_collision_state.erase(vcam_id)

func _resolve_landing_impact_offset(delta: float) -> Vector3:
	var camera_state: Object = _resolve_primary_camera_state_component()
	if camera_state == null:
		_clear_landing_impact_recovery_state()
		return Vector3.ZERO

	var current_offset: Vector3 = _read_camera_state_vector3(camera_state, "landing_impact_offset", Vector3.ZERO)
	if current_offset.is_zero_approx():
		_clear_landing_impact_recovery_state()
		return Vector3.ZERO

	var recovery_speed_hz: float = maxf(
		_get_camera_state_float(
			camera_state,
			"landing_impact_recovery_speed",
			C_CAMERA_STATE_COMPONENT.DEFAULT_LANDING_IMPACT_RECOVERY_SPEED
		),
		0.0
	)
	if recovery_speed_hz <= 0.0:
		_clear_landing_impact_recovery_state()
		return current_offset

	var camera_state_id: int = camera_state.get_instance_id()
	var needs_rebuild: bool = (
		_landing_recovery_dynamics == null
		or _landing_recovery_state_id != camera_state_id
		or not is_equal_approx(_landing_recovery_frequency_hz, recovery_speed_hz)
	)
	if needs_rebuild:
		_landing_recovery_dynamics = U_SECOND_ORDER_DYNAMICS_3D.new(
			recovery_speed_hz,
			1.0,
			1.0,
			current_offset
		)
		_landing_recovery_state_id = camera_state_id
		_landing_recovery_frequency_hz = recovery_speed_hz
		if delta <= 0.0:
			return current_offset

	var recovered_offset: Vector3 = _landing_recovery_dynamics.step(Vector3.ZERO, delta)
	if recovered_offset.length_squared() <= 0.000001:
		recovered_offset = Vector3.ZERO
		_clear_landing_impact_recovery_state()

	_write_camera_state_vector3(camera_state, "landing_impact_offset", recovered_offset)
	return recovered_offset

func _clear_landing_impact_recovery_state() -> void:
	_landing_recovery_dynamics = null
	_landing_recovery_state_id = 0
	_landing_recovery_frequency_hz = -1.0

func _resolve_primary_camera_state_component() -> Object:
	var queries: Array = query_entities([CAMERA_STATE_TYPE])
	var fallback: Object = null
	for query_variant in queries:
		if query_variant == null or not (query_variant is Object):
			continue
		var query: Object = query_variant as Object
		if not query.has_method("get_component"):
			continue
		var camera_state_variant: Variant = query.call("get_component", CAMERA_STATE_TYPE)
		if not (camera_state_variant is Object):
			continue
		var camera_state: Object = camera_state_variant as Object
		if fallback == null:
			fallback = camera_state
		if _is_primary_camera_query(query):
			return camera_state
	return fallback

func _write_active_camera_base_fov_from_result(result: Dictionary) -> void:
	if result.is_empty():
		return

	var fov_variant: Variant = result.get("fov", null)
	if not (fov_variant is float or fov_variant is int):
		return

	var fov_value: float = float(fov_variant)
	if is_nan(fov_value) or is_inf(fov_value):
		return

	var camera_state: Object = _resolve_primary_camera_state_component()
	if camera_state == null:
		return
	if not _object_has_property(camera_state, "base_fov"):
		return

	camera_state.set("base_fov", clampf(fov_value, 1.0, 179.0))

func _is_primary_camera_query(query: Object) -> bool:
	if query.has_method("get_entity_id"):
		var entity_id: StringName = _variant_to_string_name(query.call("get_entity_id"))
		if entity_id == PRIMARY_CAMERA_ENTITY_ID:
			return true
	if query.has_method("get_tags"):
		var tags_variant: Variant = query.call("get_tags")
		if tags_variant is Array:
			var tags: Array = tags_variant as Array
			return tags.has(PRIMARY_CAMERA_ENTITY_ID) or tags.has(String(PRIMARY_CAMERA_ENTITY_ID))
	return false

func _get_camera_state_float(camera_state: Object, property_name: String, fallback: float) -> float:
	if camera_state == null:
		return fallback
	if not _object_has_property(camera_state, property_name):
		return fallback
	var value: Variant = camera_state.get(property_name)
	if value is float or value is int:
		return float(value)
	return fallback

func _read_camera_state_vector3(camera_state: Object, property_name: String, fallback: Vector3) -> Vector3:
	if camera_state == null:
		return fallback
	if not _object_has_property(camera_state, property_name):
		return fallback
	var value: Variant = camera_state.get(property_name)
	if value is Vector3:
		return value as Vector3
	return fallback

func _write_camera_state_vector3(camera_state: Object, property_name: String, value: Vector3) -> void:
	if camera_state == null:
		return
	if not _object_has_property(camera_state, property_name):
		return
	camera_state.set(property_name, value)

func _object_has_property(object_value: Object, property_name: String) -> bool:
	var properties: Array[Dictionary] = object_value.get_property_list()
	for property_info in properties:
		var name_variant: Variant = property_info.get("name", "")
		if str(name_variant) == property_name:
			return true
	return false

func _variant_to_string_name(value: Variant) -> StringName:
	if value is StringName:
		return value as StringName
	if value is String:
		var text: String = value
		if text.is_empty():
			return StringName("")
		return StringName(text)
	return StringName("")

func _build_vcam_index() -> Dictionary:
	var index: Dictionary = {}
	var components: Array = get_components(C_VCAM_COMPONENT.COMPONENT_TYPE)
	for entry in components:
		var component := entry as C_VCamComponent
		if component == null:
			continue
		var vcam_id: StringName = _resolve_component_vcam_id(component)
		if vcam_id == StringName(""):
			continue
		if index.has(vcam_id):
			continue
		index[vcam_id] = component
	return index

func _resolve_component_vcam_id(component: C_VCamComponent) -> StringName:
	if component == null:
		return StringName("")
	if component.vcam_id != StringName(""):
		return component.vcam_id
	var fallback_id := String(component.name)
	if fallback_id.is_empty():
		return StringName("")
	return StringName(fallback_id.to_snake_case())

func _resolve_follow_target(component: C_VCamComponent) -> Node3D:
	if component == null:
		return null

	var node_target: Node3D = component.get_follow_target()
	if node_target != null and is_instance_valid(node_target):
		return node_target

	var manager_ref: I_ECSManager = get_manager()
	if manager_ref == null:
		return null

	if component.follow_target_entity_id != StringName(""):
		var entity_target: Node = manager_ref.get_entity_by_id(component.follow_target_entity_id)
		var resolved_entity_target: Node3D = _resolve_entity_target(entity_target)
		if resolved_entity_target != null:
			return resolved_entity_target

	if component.follow_target_tag == StringName(""):
		return null

	var tagged_entities: Array[Node] = manager_ref.get_entities_by_tag(component.follow_target_tag)
	if tagged_entities.is_empty():
		return null

	var valid_targets: Array[Node3D] = []
	for entity in tagged_entities:
		var resolved: Node3D = _resolve_entity_target(entity)
		if resolved == null:
			continue
		valid_targets.append(resolved)

	if valid_targets.is_empty():
		return null
	if valid_targets.size() > 1:
		_report_issue(
			"follow_target_tag '%s' resolved multiple entities; using first match" % String(component.follow_target_tag)
		)
	return valid_targets[0]

func _resolve_entity_target(entity: Node) -> Node3D:
	if entity == null or not is_instance_valid(entity):
		return null
	if entity is Node3D:
		return entity as Node3D
	var body_target := entity.get_node_or_null("Body") as Node3D
	if body_target != null and is_instance_valid(body_target):
		return body_target
	return null

func _update_runtime_rotation(
	vcam_id: StringName,
	component: C_VCamComponent,
	mode: Resource,
	follow_target: Node3D,
	look_input: Vector2,
	has_look_input: bool,
	camera_center_just_pressed: bool,
	delta: float
) -> void:
	if component == null or mode == null:
		return

	var mode_script := mode.get_script() as Script
	if mode_script == RS_VCAM_MODE_ORBIT_SCRIPT:
		var orbit_values: Dictionary = _resolve_mode_values(mode, {
			"allow_player_rotation": true,
			"lock_x_rotation": false,
			"lock_y_rotation": true,
			"rotation_speed": 0.0,
		})
		if not bool(orbit_values.get("allow_player_rotation", true)):
			_orbit_no_look_input_timers.erase(vcam_id)
			_orbit_centering_state.erase(vcam_id)
			return

		var lock_x_rotation: bool = bool(orbit_values.get("lock_x_rotation", false))
		var lock_y_rotation: bool = bool(orbit_values.get("lock_y_rotation", true))
		if lock_x_rotation:
			component.runtime_yaw = 0.0
			_orbit_centering_state.erase(vcam_id)
		if lock_y_rotation:
			component.runtime_pitch = 0.0

		if camera_center_just_pressed and not lock_x_rotation:
			_start_orbit_centering(vcam_id, component, mode, follow_target)
		if _step_orbit_centering(vcam_id, component, delta):
			_orbit_no_look_input_timers[vcam_id] = 0.0
			return

		var rotation_speed: float = maxf(float(orbit_values.get("rotation_speed", 0.0)), 0.0)
		if has_look_input:
			var previous_yaw: float = component.runtime_yaw
			var previous_pitch: float = component.runtime_pitch
			if not lock_x_rotation:
				component.runtime_yaw += look_input.x * rotation_speed
			if not lock_y_rotation:
				component.runtime_pitch += look_input.y * rotation_speed
			_debug_log_rotation(
				vcam_id,
				"orbit input=%s allow=%s lock_x=%s lock_y=%s speed=%.3f yaw=%.3f->%.3f pitch=%.3f->%.3f"
				% [
					str(look_input),
					str(bool(orbit_values.get("allow_player_rotation", true))),
					str(lock_x_rotation),
					str(lock_y_rotation),
					rotation_speed,
					previous_yaw,
					component.runtime_yaw,
					previous_pitch,
					component.runtime_pitch,
				]
			)
			_orbit_no_look_input_timers[vcam_id] = 0.0
			return
		if lock_y_rotation:
			_orbit_no_look_input_timers.erase(vcam_id)
			return

		var no_look_timer: float = float(_orbit_no_look_input_timers.get(vcam_id, 0.0))
		no_look_timer += maxf(delta, 0.0)
		_orbit_no_look_input_timers[vcam_id] = no_look_timer

		var response_values: Dictionary = _resolve_component_response_values(component)
		var auto_level_speed: float = maxf(float(response_values.get("auto_level_speed", 0.0)), 0.0)
		if auto_level_speed <= 0.0:
			return
		var auto_level_delay: float = maxf(float(response_values.get("auto_level_delay", 1.0)), 0.0)
		if no_look_timer < auto_level_delay:
			return
		component.runtime_pitch = move_toward(
			component.runtime_pitch,
			0.0,
			auto_level_speed * maxf(delta, 0.0)
		)
		return

	_orbit_no_look_input_timers.erase(vcam_id)
	_orbit_centering_state.erase(vcam_id)
	if not has_look_input:
		return
	if mode_script == RS_VCAM_MODE_FIRST_PERSON_SCRIPT:
		var first_person_values: Dictionary = _resolve_mode_values(mode, {
			"look_multiplier": 1.0,
		})
		var look_multiplier: float = maxf(float(first_person_values.get("look_multiplier", 1.0)), 0.0001)
		var previous_fp_yaw: float = component.runtime_yaw
		var previous_fp_pitch: float = component.runtime_pitch
		component.runtime_yaw += look_input.x * look_multiplier
		component.runtime_pitch += look_input.y * look_multiplier
		_debug_log_rotation(
			vcam_id,
			"first_person input=%s multiplier=%.3f yaw=%.3f->%.3f pitch=%.3f->%.3f"
			% [
				str(look_input),
				look_multiplier,
				previous_fp_yaw,
				component.runtime_yaw,
				previous_fp_pitch,
				component.runtime_pitch,
			]
		)

func _start_orbit_centering(
	vcam_id: StringName,
	component: C_VCamComponent,
	mode: Resource,
	follow_target: Node3D
) -> void:
	if component == null or mode == null:
		return

	var start_yaw: float = component.runtime_yaw
	var start_pitch: float = component.runtime_pitch
	var target_yaw: float = _resolve_orbit_center_target_yaw(mode, follow_target, start_yaw)
	_orbit_centering_state[vcam_id] = {
		"start_yaw": start_yaw,
		"start_pitch": start_pitch,
		"target_yaw": target_yaw,
		"target_pitch": start_pitch,
		"elapsed_sec": 0.0,
		"duration_sec": ORBIT_CENTER_DURATION_SEC,
	}

func _step_orbit_centering(vcam_id: StringName, component: C_VCamComponent, delta: float) -> bool:
	if component == null:
		return false

	var state_variant: Variant = _orbit_centering_state.get(vcam_id, {})
	if not (state_variant is Dictionary):
		return false
	var state := state_variant as Dictionary
	if state.is_empty():
		return false

	var start_yaw: float = float(state.get("start_yaw", component.runtime_yaw))
	var start_pitch: float = float(state.get("start_pitch", component.runtime_pitch))
	var target_yaw: float = float(state.get("target_yaw", start_yaw))
	var target_pitch: float = float(state.get("target_pitch", start_pitch))
	var duration_sec: float = maxf(float(state.get("duration_sec", ORBIT_CENTER_DURATION_SEC)), 0.0001)
	var elapsed_sec: float = float(state.get("elapsed_sec", 0.0))
	if delta > 0.0:
		elapsed_sec += delta
	state["elapsed_sec"] = elapsed_sec
	_orbit_centering_state[vcam_id] = state

	var raw_t: float = clampf(elapsed_sec / duration_sec, 0.0, 1.0)
	var smooth_t: float = raw_t * raw_t * (3.0 - (2.0 * raw_t))
	var yaw_delta: float = wrapf(target_yaw - start_yaw, -180.0, 180.0)
	component.runtime_yaw = start_yaw + (yaw_delta * smooth_t)
	component.runtime_pitch = lerpf(start_pitch, target_pitch, smooth_t)

	if raw_t >= 1.0:
		component.runtime_yaw = start_yaw + yaw_delta
		component.runtime_pitch = target_pitch
		_orbit_centering_state.erase(vcam_id)
	return true

func _resolve_orbit_center_target_yaw(
	mode: Resource,
	follow_target: Node3D,
	current_runtime_yaw: float
) -> float:
	if mode == null:
		return current_runtime_yaw

	var authored_yaw: float = 0.0
	var orbit_values: Dictionary = _resolve_mode_values(mode, {
		"authored_yaw": 0.0,
	})
	authored_yaw = float(orbit_values.get("authored_yaw", 0.0))

	if follow_target == null or not is_instance_valid(follow_target):
		return current_runtime_yaw

	var behind_direction: Vector3 = follow_target.global_transform.basis.z
	var planar_length_sq: float = (behind_direction.x * behind_direction.x) + (behind_direction.z * behind_direction.z)
	if planar_length_sq <= 0.000001:
		return current_runtime_yaw

	var target_total_yaw: float = rad_to_deg(atan2(behind_direction.x, behind_direction.z))
	var target_runtime_yaw: float = target_total_yaw - authored_yaw
	return current_runtime_yaw + wrapf(target_runtime_yaw - current_runtime_yaw, -180.0, 180.0)

func _is_orbit_centering_active(vcam_id: StringName) -> bool:
	var state_variant: Variant = _orbit_centering_state.get(vcam_id, {})
	if not (state_variant is Dictionary):
		return false
	return not (state_variant as Dictionary).is_empty()

func _apply_orbit_look_ahead(
	vcam_id: StringName,
	component: C_VCamComponent,
	mode: Resource,
	follow_target: Node3D,
	result: Dictionary,
	has_active_look_input: bool,
	delta: float
) -> Dictionary:
	if component == null or mode == null:
		return result
	if mode.get_script() != RS_VCAM_MODE_ORBIT_SCRIPT:
		_clear_look_ahead_state_for_vcam(vcam_id)
		return result
	if follow_target == null or not is_instance_valid(follow_target):
		_clear_look_ahead_state_for_vcam(vcam_id)
		return result

	var response_values: Dictionary = _resolve_component_response_values(component)
	var look_ahead_distance: float = maxf(float(response_values.get("look_ahead_distance", 0.0)), 0.0)
	if look_ahead_distance <= 0.0:
		_clear_look_ahead_state_for_vcam(vcam_id)
		return result
	if has_active_look_input:
		_clear_look_ahead_state_for_vcam(vcam_id)
		return result

	var target_id: int = _get_node_instance_id(follow_target)
	if target_id == 0:
		_clear_look_ahead_state_for_vcam(vcam_id)
		return result

	var current_position: Vector3 = follow_target.global_position
	var state: Dictionary = _get_or_create_look_ahead_state(vcam_id, target_id, current_position)
	state["last_target_position"] = current_position

	var velocity_sample: Dictionary = _resolve_look_ahead_movement_velocity(follow_target)
	var has_velocity: bool = bool(velocity_sample.get("has_velocity", false))
	var velocity_variant: Variant = velocity_sample.get("velocity", Vector3.ZERO)
	var velocity: Vector3 = velocity_variant as Vector3 if velocity_variant is Vector3 else Vector3.ZERO
	var planar_velocity := Vector3(velocity.x, 0.0, velocity.z)
	if (not has_velocity) or planar_velocity.length_squared() <= LOOK_AHEAD_MOVEMENT_EPSILON_SQ:
		_debug_log_look_ahead_motion_state(vcam_id, false, follow_target, planar_velocity, Vector3.ZERO)
		state["current_offset"] = Vector3.ZERO
		state["dynamics"] = null
		state["smoothing_hz"] = -1.0
		_look_ahead_state[vcam_id] = state
		return result

	var desired_offset: Vector3 = planar_velocity.normalized() * look_ahead_distance
	_debug_log_look_ahead_motion_state(vcam_id, true, follow_target, planar_velocity, desired_offset)

	var smoothing_hz: float = maxf(float(response_values.get("look_ahead_smoothing", 3.0)), 0.0)
	var current_offset: Vector3 = state.get("current_offset", Vector3.ZERO) as Vector3
	var smoothed_offset: Vector3 = desired_offset
	if smoothing_hz > 0.0:
		var rebuild_dynamics: bool = (
			not state.has("dynamics")
			or state.get("dynamics", null) == null
			or not is_equal_approx(float(state.get("smoothing_hz", -1.0)), smoothing_hz)
		)
		if rebuild_dynamics:
			state["dynamics"] = U_SECOND_ORDER_DYNAMICS_3D.new(smoothing_hz, 1.0, 0.0, current_offset)
			state["smoothing_hz"] = smoothing_hz
		var dynamics = state.get("dynamics", null)
		if dynamics != null:
			smoothed_offset = dynamics.step(desired_offset, maxf(delta, 0.0))
	else:
		state["dynamics"] = null
		state["smoothing_hz"] = 0.0

	if smoothed_offset.length_squared() > (look_ahead_distance * look_ahead_distance):
		smoothed_offset = smoothed_offset.normalized() * look_ahead_distance

	state["current_offset"] = smoothed_offset
	_look_ahead_state[vcam_id] = state

	if smoothed_offset.is_zero_approx():
		return result
	return _apply_position_offset(result, smoothed_offset)

func _resolve_look_ahead_movement_velocity(follow_target: Node3D) -> Dictionary:
	if follow_target == null or not is_instance_valid(follow_target):
		return {"has_velocity": false, "velocity": Vector3.ZERO}

	var entity: Node = U_ECS_UTILS.find_entity_root(follow_target)
	if entity != null and is_instance_valid(entity):
		var entity_id: StringName = U_ECS_UTILS.get_entity_id(entity)
		var state_velocity: Dictionary = _read_gameplay_entity_velocity(entity_id)
		if bool(state_velocity.get("has_velocity", false)):
			return state_velocity

		var movement_velocity: Dictionary = _read_entity_movement_component_velocity(entity)
		if bool(movement_velocity.get("has_velocity", false)):
			return movement_velocity

		var body_velocity: Dictionary = _read_entity_character_body_velocity(entity)
		if bool(body_velocity.get("has_velocity", false)):
			return body_velocity

	return _read_character_body_velocity(follow_target)

func _read_gameplay_entity_velocity(entity_id: StringName) -> Dictionary:
	if entity_id == StringName(""):
		return {"has_velocity": false, "velocity": Vector3.ZERO}

	var store := _resolve_state_store()
	if store == null:
		return {"has_velocity": false, "velocity": Vector3.ZERO}

	var state: Dictionary = store.get_state()
	var gameplay_variant: Variant = state.get("gameplay", {})
	if not (gameplay_variant is Dictionary):
		return {"has_velocity": false, "velocity": Vector3.ZERO}
	var gameplay := gameplay_variant as Dictionary

	var entities_variant: Variant = gameplay.get("entities", {})
	if not (entities_variant is Dictionary):
		return {"has_velocity": false, "velocity": Vector3.ZERO}
	var entities := entities_variant as Dictionary

	var entity_state_variant: Variant = entities.get(String(entity_id), null)
	if not (entity_state_variant is Dictionary):
		return {"has_velocity": false, "velocity": Vector3.ZERO}
	var entity_state := entity_state_variant as Dictionary
	if not entity_state.has("velocity"):
		return {"has_velocity": false, "velocity": Vector3.ZERO}

	var velocity_variant: Variant = entity_state.get("velocity", Vector3.ZERO)
	if velocity_variant is Vector3:
		return {
			"has_velocity": true,
			"velocity": velocity_variant as Vector3,
		}
	if velocity_variant is Vector2:
		var velocity_2d := velocity_variant as Vector2
		return {
			"has_velocity": true,
			"velocity": Vector3(velocity_2d.x, 0.0, velocity_2d.y),
		}
	return {"has_velocity": false, "velocity": Vector3.ZERO}

func _read_entity_movement_component_velocity(entity: Node) -> Dictionary:
	var movement_component: Node = _find_node_with_script(entity, C_MOVEMENT_COMPONENT_SCRIPT)
	if movement_component == null:
		return {"has_velocity": false, "velocity": Vector3.ZERO}
	if not movement_component.has_method("get_horizontal_dynamics_velocity"):
		return {"has_velocity": false, "velocity": Vector3.ZERO}

	var velocity_variant: Variant = movement_component.call("get_horizontal_dynamics_velocity")
	if not (velocity_variant is Vector2):
		return {"has_velocity": false, "velocity": Vector3.ZERO}
	var velocity_2d := velocity_variant as Vector2
	return {
		"has_velocity": true,
		"velocity": Vector3(velocity_2d.x, 0.0, velocity_2d.y),
	}

func _read_entity_character_body_velocity(entity: Node) -> Dictionary:
	var character_body: CharacterBody3D = _find_character_body_recursive(entity)
	if character_body == null or not is_instance_valid(character_body):
		return {"has_velocity": false, "velocity": Vector3.ZERO}
	return {
		"has_velocity": true,
		"velocity": character_body.velocity,
	}

func _read_character_body_velocity(node: Node) -> Dictionary:
	if not (node is CharacterBody3D):
		return {"has_velocity": false, "velocity": Vector3.ZERO}
	var body := node as CharacterBody3D
	return {
		"has_velocity": true,
		"velocity": body.velocity,
	}

func _find_node_with_script(root: Node, script: Script) -> Node:
	if root == null or script == null:
		return null
	if root.get_script() == script:
		return root

	for child_variant in root.get_children():
		var child := child_variant as Node
		if child == null:
			continue
		var found: Node = _find_node_with_script(child, script)
		if found != null:
			return found
	return null

func _find_character_body_recursive(root: Node) -> CharacterBody3D:
	if root == null:
		return null
	if root is CharacterBody3D:
		return root as CharacterBody3D

	for child_variant in root.get_children():
		var child := child_variant as Node
		if child == null:
			continue
		var found: CharacterBody3D = _find_character_body_recursive(child)
		if found != null and is_instance_valid(found):
			return found
	return null

func _get_or_create_look_ahead_state(
	vcam_id: StringName,
	follow_target_id: int,
	current_position: Vector3
) -> Dictionary:
	var state_variant: Variant = _look_ahead_state.get(vcam_id, {})
	var state: Dictionary = {}
	if state_variant is Dictionary:
		state = (state_variant as Dictionary).duplicate(true)

	var previous_target_id: int = int(state.get("follow_target_id", 0))
	if state.is_empty() or previous_target_id != follow_target_id:
		state = {
			"follow_target_id": follow_target_id,
			"last_target_position": current_position,
			"current_offset": Vector3.ZERO,
			"smoothing_hz": -1.0,
			"dynamics": null,
		}
		_look_ahead_state[vcam_id] = state
	return state

func _clear_look_ahead_state_for_vcam(vcam_id: StringName) -> void:
	_look_ahead_state.erase(vcam_id)

func _apply_orbit_ground_relative(
	vcam_id: StringName,
	component: C_VCamComponent,
	mode: Resource,
	follow_target: Node3D,
	result: Dictionary,
	response_values: Dictionary,
	delta: float
) -> Dictionary:
	if component == null or mode == null:
		_clear_ground_relative_state_for_vcam(vcam_id)
		return result
	if mode.get_script() != RS_VCAM_MODE_ORBIT_SCRIPT:
		_clear_ground_relative_state_for_vcam(vcam_id)
		return result
	if follow_target == null or not is_instance_valid(follow_target):
		_clear_ground_relative_state_for_vcam(vcam_id)
		return result
	if response_values.is_empty():
		_clear_ground_relative_state_for_vcam(vcam_id)
		return result
	if not bool(response_values.get("ground_relative_enabled", false)):
		_clear_ground_relative_state_for_vcam(vcam_id)
		return result

	var transform_variant: Variant = result.get("transform", null)
	if not (transform_variant is Transform3D):
		return result

	var follow_target_id: int = _get_node_instance_id(follow_target)
	if follow_target_id == 0:
		_clear_ground_relative_state_for_vcam(vcam_id)
		return result

	var follow_y: float = follow_target.global_position.y
	var state: Dictionary = _get_or_create_ground_relative_state(vcam_id, follow_target_id, follow_y)

	var grounded: bool = _resolve_follow_target_grounded_state(follow_target)
	var probe_max_distance: float = maxf(float(response_values.get("ground_probe_max_distance", 0.0)), 0.0)
	var ground_reference_y: float = follow_y
	var has_ground_reference: bool = false
	if grounded:
		var probe_result: Dictionary = _probe_ground_reference_height(follow_target, probe_max_distance)
		has_ground_reference = bool(probe_result.get("valid", false))
		if has_ground_reference:
			ground_reference_y = float(probe_result.get("height", follow_y))

	var initialized: bool = bool(state.get("initialized", false))
	var ground_anchor_y: float = float(state.get("ground_anchor_y", follow_y))
	var ground_anchor_target_y: float = float(state.get("ground_anchor_target_y", ground_anchor_y))
	var follow_anchor_y_offset: float = float(state.get("follow_anchor_y_offset", 0.0))
	var last_ground_reference_y: float = float(state.get("last_ground_reference_y", ground_anchor_target_y))
	var was_grounded: bool = bool(state.get("was_grounded", grounded))
	var blend_hz: float = maxf(float(response_values.get("ground_anchor_blend_hz", 0.0)), 0.0)
	var previous_blend_hz: float = float(state.get("blend_hz", -1.0))
	var dynamics: Variant = state.get("dynamics", null)
	var reset_dynamics: bool = false
	if not initialized:
		if grounded and has_ground_reference:
			# First real grounded contact — initialize anchor from actual ground surface.
			ground_anchor_y = ground_reference_y
			ground_anchor_target_y = ground_reference_y
			follow_anchor_y_offset = follow_y - ground_reference_y
			last_ground_reference_y = ground_reference_y
			initialized = true
			reset_dynamics = true
		else:
			# Still airborne or no probe hit — keep strict no-op while uninitialized.
			ground_anchor_y = follow_y
			ground_anchor_target_y = follow_y
			follow_anchor_y_offset = 0.0
			dynamics = null
			state["initialized"] = false
			state["follow_target_id"] = follow_target_id
			state["ground_anchor_y"] = ground_anchor_y
			state["ground_anchor_target_y"] = ground_anchor_target_y
			state["follow_anchor_y_offset"] = follow_anchor_y_offset
			state["last_ground_reference_y"] = last_ground_reference_y
			state["was_grounded"] = grounded
			state["blend_hz"] = blend_hz
			state["dynamics"] = dynamics
			_ground_relative_state[vcam_id] = state
			return result
	elif grounded and has_ground_reference and not was_grounded:
		var reanchor_min_height_delta: float = maxf(
			float(response_values.get("ground_reanchor_min_height_delta", 0.0)),
			0.0
		)
		var landing_height_delta: float = absf(ground_reference_y - last_ground_reference_y)
		if landing_height_delta >= reanchor_min_height_delta:
			ground_anchor_target_y = ground_reference_y
			follow_anchor_y_offset = follow_y - ground_reference_y
			last_ground_reference_y = ground_reference_y
			reset_dynamics = true

	if blend_hz <= 0.0:
		dynamics = null
		ground_anchor_y = ground_anchor_target_y
	else:
		var needs_rebuild: bool = (
			dynamics == null
			or not is_equal_approx(previous_blend_hz, blend_hz)
			or reset_dynamics
		)
		if needs_rebuild:
			dynamics = U_SECOND_ORDER_DYNAMICS.new(blend_hz, 1.0, 1.0, ground_anchor_y)
		if delta > 0.0 and dynamics != null:
			ground_anchor_y = float(dynamics.step(ground_anchor_target_y, delta))
		else:
			ground_anchor_y = ground_anchor_target_y
	if is_nan(ground_anchor_y) or is_inf(ground_anchor_y):
		ground_anchor_y = ground_anchor_target_y
	if is_nan(ground_anchor_target_y) or is_inf(ground_anchor_target_y):
		ground_anchor_target_y = ground_anchor_y

	state["initialized"] = initialized
	state["follow_target_id"] = follow_target_id
	state["ground_anchor_y"] = ground_anchor_y
	state["ground_anchor_target_y"] = ground_anchor_target_y
	state["follow_anchor_y_offset"] = follow_anchor_y_offset
	state["last_ground_reference_y"] = last_ground_reference_y
	state["was_grounded"] = grounded
	state["blend_hz"] = blend_hz
	state["dynamics"] = dynamics
	_ground_relative_state[vcam_id] = state

	var anchored_follow_y: float = ground_anchor_y + follow_anchor_y_offset
	var y_offset: float = anchored_follow_y - follow_y
	if absf(y_offset) <= 0.000001:
		return result
	return _apply_position_offset(result, Vector3(0.0, y_offset, 0.0))

func _get_or_create_ground_relative_state(
	vcam_id: StringName,
	follow_target_id: int,
	follow_y: float
) -> Dictionary:
	var state_variant: Variant = _ground_relative_state.get(vcam_id, {})
	var state: Dictionary = {}
	if state_variant is Dictionary:
		state = (state_variant as Dictionary).duplicate(true)

	var previous_target_id: int = int(state.get("follow_target_id", 0))
	if state.is_empty() or previous_target_id != follow_target_id:
		state = {
			"initialized": false,
			"follow_target_id": follow_target_id,
			"ground_anchor_y": follow_y,
			"ground_anchor_target_y": follow_y,
			"follow_anchor_y_offset": 0.0,
			"last_ground_reference_y": follow_y,
			"was_grounded": false,
			"blend_hz": -1.0,
			"dynamics": null,
		}
		_ground_relative_state[vcam_id] = state
	return state

func _clear_ground_relative_state_for_vcam(vcam_id: StringName) -> void:
	_ground_relative_state.erase(vcam_id)

func _resolve_follow_target_grounded_state(follow_target: Node3D) -> bool:
	if follow_target == null or not is_instance_valid(follow_target):
		return false

	var entity_root: Node = U_ECS_UTILS.find_entity_root(follow_target)
	if entity_root != null and is_instance_valid(entity_root):
		var entity_id: StringName = U_ECS_UTILS.get_entity_id(entity_root)
		var state_grounded: Dictionary = _read_gameplay_entity_is_on_floor(entity_id)
		if bool(state_grounded.get("has_value", false)):
			return bool(state_grounded.get("is_on_floor", false))

		var character_state: Node = _find_node_with_script(entity_root, C_CHARACTER_STATE_COMPONENT_SCRIPT)
		if character_state != null and _object_has_property(character_state, "is_grounded"):
			var grounded_variant: Variant = character_state.get("is_grounded")
			if grounded_variant is bool:
				return grounded_variant as bool
			if grounded_variant is int:
				return int(grounded_variant) != 0

	var body: CharacterBody3D = _find_character_body_recursive(follow_target)
	if body == null or not is_instance_valid(body):
		return false
	return body.is_on_floor()

func _read_gameplay_entity_is_on_floor(entity_id: StringName) -> Dictionary:
	if entity_id == StringName(""):
		return {"has_value": false, "is_on_floor": false}

	var store := _resolve_state_store()
	if store == null:
		return {"has_value": false, "is_on_floor": false}

	var state: Dictionary = store.get_state()
	var gameplay_variant: Variant = state.get("gameplay", {})
	if not (gameplay_variant is Dictionary):
		return {"has_value": false, "is_on_floor": false}
	var gameplay := gameplay_variant as Dictionary

	var entities_variant: Variant = gameplay.get("entities", {})
	if not (entities_variant is Dictionary):
		return {"has_value": false, "is_on_floor": false}
	var entities := entities_variant as Dictionary

	var entity_state_variant: Variant = entities.get(String(entity_id), null)
	if not (entity_state_variant is Dictionary):
		return {"has_value": false, "is_on_floor": false}
	var entity_state := entity_state_variant as Dictionary
	if not entity_state.has("is_on_floor"):
		return {"has_value": false, "is_on_floor": false}

	var on_floor_variant: Variant = entity_state.get("is_on_floor", false)
	if on_floor_variant is bool:
		return {"has_value": true, "is_on_floor": on_floor_variant as bool}
	if on_floor_variant is int:
		return {"has_value": true, "is_on_floor": int(on_floor_variant) != 0}
	return {"has_value": false, "is_on_floor": false}

func _probe_ground_reference_height(follow_target: Node3D, max_distance: float) -> Dictionary:
	if follow_target == null or not is_instance_valid(follow_target):
		return {"valid": false, "height": 0.0}
	if max_distance <= 0.0:
		return {"valid": false, "height": follow_target.global_position.y}

	var fallback_height: float = follow_target.global_position.y
	var world: World3D = follow_target.get_world_3d()
	if world == null:
		return {"valid": true, "height": fallback_height}
	var space_state: PhysicsDirectSpaceState3D = world.direct_space_state
	if space_state == null:
		return {"valid": true, "height": fallback_height}

	var ray_from: Vector3 = follow_target.global_position + (Vector3.UP * 0.1)
	var ray_to: Vector3 = ray_from + (Vector3.DOWN * max_distance)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_from, ray_to)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var entity_root: Node = U_ECS_UTILS.find_entity_root(follow_target)
	var exclude_rids: Array[RID] = []
	if entity_root != null and is_instance_valid(entity_root):
		var entity_collision := entity_root as CollisionObject3D
		if entity_collision != null:
			exclude_rids.append(entity_collision.get_rid())
	var follow_collision := follow_target as CollisionObject3D
	if follow_collision != null:
		var follow_rid: RID = follow_collision.get_rid()
		if not exclude_rids.has(follow_rid):
			exclude_rids.append(follow_rid)
	if exclude_rids.is_empty():
		var follow_body: CharacterBody3D = _find_character_body_recursive(follow_target)
		if follow_body != null and is_instance_valid(follow_body):
			exclude_rids.append(follow_body.get_rid())
	query.exclude = exclude_rids

	var hit: Dictionary = space_state.intersect_ray(query)
	if hit.is_empty():
		return {"valid": true, "height": fallback_height}
	var hit_position_variant: Variant = hit.get("position", Vector3.ZERO)
	if not (hit_position_variant is Vector3):
		return {"valid": true, "height": fallback_height}
	var hit_position := hit_position_variant as Vector3
	return {"valid": true, "height": hit_position.y}

func _apply_orbit_soft_zone(
	vcam_id: StringName,
	component: C_VCamComponent,
	mode: Resource,
	follow_target: Node3D,
	result: Dictionary,
	delta: float
) -> Dictionary:
	if component == null or mode == null:
		_debug_log_soft_zone_status(vcam_id, "skipped_missing_component_or_mode", Vector3.ZERO)
		return result
	if mode.get_script() != RS_VCAM_MODE_ORBIT_SCRIPT:
		_clear_soft_zone_dead_zone_state_for_vcam(vcam_id)
		_debug_log_soft_zone_status(vcam_id, "skipped_non_orbit_mode", Vector3.ZERO)
		return result
	if follow_target == null or not is_instance_valid(follow_target):
		_clear_soft_zone_dead_zone_state_for_vcam(vcam_id)
		_debug_log_soft_zone_status(vcam_id, "skipped_missing_follow_target", Vector3.ZERO)
		return result
	if component.soft_zone == null:
		_clear_soft_zone_dead_zone_state_for_vcam(vcam_id)
		_debug_log_soft_zone_status(vcam_id, "skipped_no_soft_zone_resource", Vector3.ZERO)
		return result
	if component.soft_zone.get_script() != RS_VCAM_SOFT_ZONE_SCRIPT:
		_clear_soft_zone_dead_zone_state_for_vcam(vcam_id)
		_debug_log_soft_zone_status(vcam_id, "skipped_invalid_soft_zone_resource", Vector3.ZERO)
		return result

	var transform_variant: Variant = result.get("transform", null)
	if not (transform_variant is Transform3D):
		_debug_log_soft_zone_status(vcam_id, "skipped_missing_transform", Vector3.ZERO)
		return result
	var desired_transform := transform_variant as Transform3D

	var projection_camera: Camera3D = _resolve_projection_camera()
	if projection_camera == null:
		_debug_log_soft_zone_status(vcam_id, "skipped_missing_projection_camera", Vector3.ZERO)
		return result

	var dead_zone_state: Dictionary = _get_soft_zone_dead_zone_state(vcam_id)
	var correction_result: Dictionary = U_VCAM_SOFT_ZONE.compute_camera_correction_with_state(
		projection_camera,
		follow_target.global_position,
		desired_transform,
		component.soft_zone as Resource,
		delta,
		dead_zone_state
	)
	var next_state_variant: Variant = correction_result.get("dead_zone_state", dead_zone_state)
	if next_state_variant is Dictionary:
		_soft_zone_dead_zone_state[vcam_id] = (next_state_variant as Dictionary).duplicate(true)
	var correction_variant: Variant = correction_result.get("correction", Vector3.ZERO)
	if not (correction_variant is Vector3):
		return result
	var correction := correction_variant as Vector3
	_debug_log_soft_zone_metrics(vcam_id, correction_result, correction)
	if correction.is_zero_approx():
		_debug_log_soft_zone_status(vcam_id, "inactive_zero_correction", correction)
		return result
	_debug_log_soft_zone_status(vcam_id, "active_correction", correction)
	return _apply_position_offset(result, correction)

func _resolve_projection_camera() -> Camera3D:
	var camera_manager_service := U_SERVICE_LOCATOR.try_get_service(StringName("camera_manager")) as I_CAMERA_MANAGER
	if camera_manager_service != null and is_instance_valid(camera_manager_service):
		var main_camera: Camera3D = camera_manager_service.get_main_camera()
		if main_camera != null and is_instance_valid(main_camera):
			return main_camera

	var viewport: Viewport = get_viewport()
	if viewport == null:
		return null
	var viewport_camera: Camera3D = viewport.get_camera_3d()
	if viewport_camera == null or not is_instance_valid(viewport_camera):
		return null
	return viewport_camera

func _get_soft_zone_dead_zone_state(vcam_id: StringName) -> Dictionary:
	var state_variant: Variant = _soft_zone_dead_zone_state.get(vcam_id, {})
	if state_variant is Dictionary:
		return (state_variant as Dictionary).duplicate(true)
	return {
		"x": false,
		"y": false,
	}

func _clear_soft_zone_dead_zone_state_for_vcam(vcam_id: StringName) -> void:
	_soft_zone_dead_zone_state.erase(vcam_id)

func _resolve_component_response_values(component: C_VCamComponent) -> Dictionary:
	if component == null:
		return {}
	var response := component.response as Resource
	if response == null:
		return {}
	if response.get_script() != RS_VCAM_RESPONSE_SCRIPT:
		return {}
	return _resolve_response_values(response)

func _resolve_filtered_look_input(
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

	var has_raw_input: bool = _is_filtered_look_input_active(raw_look_input, response_values)
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
		input_active = _is_filtered_look_input_active(filtered_input, response_values)
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

func _is_filtered_look_input_active(look_input: Vector2, response_values: Dictionary) -> bool:
	if response_values.is_empty():
		return not look_input.is_zero_approx()
	var deadzone: float = maxf(
		float(response_values.get("look_input_deadzone", DEFAULT_LOOK_INPUT_DEADZONE)),
		0.0
	)
	return look_input.length_squared() > deadzone * deadzone

func _sample_follow_target_speed(vcam_id: StringName, follow_target: Node3D, delta: float) -> float:
	if follow_target == null or not is_instance_valid(follow_target):
		_follow_target_motion_state.erase(vcam_id)
		return 0.0
	if delta <= 0.0:
		return 0.0

	var follow_target_id: int = _get_node_instance_id(follow_target)
	if follow_target_id == 0:
		_follow_target_motion_state.erase(vcam_id)
		return 0.0

	var current_position: Vector3 = follow_target.global_position
	var state_variant: Variant = _follow_target_motion_state.get(vcam_id, {})
	if not (state_variant is Dictionary):
		_follow_target_motion_state[vcam_id] = {
			"follow_target_id": follow_target_id,
			"last_position": current_position,
			"speed_mps": 0.0,
		}
		return 0.0

	var state := (state_variant as Dictionary).duplicate(true)
	var previous_target_id: int = int(state.get("follow_target_id", 0))
	if previous_target_id != follow_target_id:
		_follow_target_motion_state[vcam_id] = {
			"follow_target_id": follow_target_id,
			"last_position": current_position,
			"speed_mps": 0.0,
		}
		return 0.0

	var previous_position: Vector3 = state.get("last_position", current_position) as Vector3
	var displacement: Vector3 = current_position - previous_position
	var horizontal_displacement := Vector3(displacement.x, 0.0, displacement.z)
	var speed_mps: float = horizontal_displacement.length() / delta
	state["follow_target_id"] = follow_target_id
	state["last_position"] = current_position
	state["speed_mps"] = speed_mps
	_follow_target_motion_state[vcam_id] = state
	return speed_mps

func _should_bypass_orbit_position_smoothing(
	vcam_id: StringName,
	mode_script: Script,
	has_active_look_input: bool,
	follow_target_speed_mps: float,
	response_values: Dictionary
) -> bool:
	if mode_script != RS_VCAM_MODE_ORBIT_SCRIPT:
		return false
	if not has_active_look_input:
		return false

	var enable_speed: float = maxf(
		float(response_values.get("orbit_look_bypass_enable_speed", DEFAULT_ORBIT_LOOK_BYPASS_ENABLE_SPEED)),
		0.0
	)
	var disable_speed: float = maxf(
		float(response_values.get("orbit_look_bypass_disable_speed", DEFAULT_ORBIT_LOOK_BYPASS_DISABLE_SPEED)),
		enable_speed
	)
	var was_bypassing: bool = bool(_debug_position_smoothing_bypass_by_vcam.get(vcam_id, false))
	if was_bypassing:
		return follow_target_speed_mps <= disable_speed
	return follow_target_speed_mps <= enable_speed

func _apply_position_offset(result: Dictionary, offset: Vector3) -> Dictionary:
	var transform_variant: Variant = result.get("transform", null)
	if not (transform_variant is Transform3D):
		return result
	var transform := transform_variant as Transform3D
	var offset_result: Dictionary = result.duplicate(true)
	var offset_transform := transform
	offset_transform.origin += offset
	offset_result["transform"] = offset_transform
	return offset_result

func _resolve_mode_values(mode: Resource, fallback: Dictionary) -> Dictionary:
	var resolved_values: Dictionary = {}
	if mode.has_method("get_resolved_values"):
		var resolved_variant: Variant = mode.call("get_resolved_values")
		if resolved_variant is Dictionary:
			resolved_values = (resolved_variant as Dictionary).duplicate(true)
	if resolved_values.is_empty():
		return fallback.duplicate(true)
	return resolved_values

func _is_path_fixed_mode(mode: Resource) -> bool:
	if mode == null:
		return false
	var mode_script := mode.get_script() as Script
	if mode_script != RS_VCAM_MODE_FIXED_SCRIPT:
		return false
	var fixed_values: Dictionary = _resolve_mode_values(mode, {"use_path": false})
	return bool(fixed_values.get("use_path", false))

func _resolve_or_create_path_anchor(component: C_VCamComponent, follow_target: Node3D) -> Node3D:
	if component == null:
		return null

	var path_node: Path3D = component.get_path_node()
	if path_node == null or not is_instance_valid(path_node):
		return null

	var vcam_id: StringName = _resolve_component_vcam_id(component)
	if vcam_id == StringName(""):
		return null

	var helper := _path_follow_helpers.get(vcam_id, null) as PathFollow3D
	if helper == null or not is_instance_valid(helper):
		helper = PathFollow3D.new()
		helper.name = "PathFollow_%s" % String(vcam_id)
		path_node.add_child(helper)
		_path_follow_helpers[vcam_id] = helper
	elif helper.get_parent() != path_node:
		if helper.get_parent() != null:
			helper.get_parent().remove_child(helper)
		path_node.add_child(helper)

	if follow_target == null or not is_instance_valid(follow_target):
		return null
	if path_node.curve == null:
		return null

	var local_target_position: Vector3 = path_node.to_local(follow_target.global_position)
	helper.progress = path_node.curve.get_closest_offset(local_target_position)
	return helper

func _prune_path_helpers(vcam_index: Dictionary) -> void:
	var stale_ids: Array[StringName] = []
	for vcam_id_variant in _path_follow_helpers.keys():
		var vcam_id := vcam_id_variant as StringName
		var helper := _path_follow_helpers.get(vcam_id, null) as PathFollow3D
		if helper == null or not is_instance_valid(helper):
			stale_ids.append(vcam_id)
			continue
		if not vcam_index.has(vcam_id):
			stale_ids.append(vcam_id)
			helper.queue_free()
			continue

	for stale_id in stale_ids:
		_path_follow_helpers.erase(stale_id)

func _prune_smoothing_state(vcam_index: Dictionary) -> void:
	var stale_ids: Array[StringName] = []

	for vcam_id_variant in _follow_dynamics.keys():
		var vcam_id := vcam_id_variant as StringName
		if vcam_index.has(vcam_id):
			continue
		stale_ids.append(vcam_id)

	for vcam_id_variant in _rotation_dynamics.keys():
		var vcam_id := vcam_id_variant as StringName
		if vcam_index.has(vcam_id):
			continue
		if stale_ids.has(vcam_id):
			continue
		stale_ids.append(vcam_id)

	for vcam_id_variant in _smoothing_metadata.keys():
		var vcam_id := vcam_id_variant as StringName
		if vcam_index.has(vcam_id):
			continue
		if stale_ids.has(vcam_id):
			continue
		stale_ids.append(vcam_id)

	for vcam_id_variant in _look_ahead_state.keys():
		var vcam_id := vcam_id_variant as StringName
		if vcam_index.has(vcam_id):
			continue
		if stale_ids.has(vcam_id):
			continue
		stale_ids.append(vcam_id)

	for vcam_id_variant in _ground_relative_state.keys():
		var vcam_id := vcam_id_variant as StringName
		if vcam_index.has(vcam_id):
			continue
		if stale_ids.has(vcam_id):
			continue
		stale_ids.append(vcam_id)

	for vcam_id_variant in _first_person_strafe_tilt_state.keys():
		var vcam_id := vcam_id_variant as StringName
		if vcam_index.has(vcam_id):
			continue
		if stale_ids.has(vcam_id):
			continue
		stale_ids.append(vcam_id)

	for vcam_id_variant in _ots_collision_state.keys():
		var vcam_id := vcam_id_variant as StringName
		if vcam_index.has(vcam_id):
			continue
		if stale_ids.has(vcam_id):
			continue
		stale_ids.append(vcam_id)

	for vcam_id_variant in _look_input_filter_state.keys():
		var vcam_id := vcam_id_variant as StringName
		if vcam_index.has(vcam_id):
			continue
		if stale_ids.has(vcam_id):
			continue
		stale_ids.append(vcam_id)

	for vcam_id_variant in _follow_target_motion_state.keys():
		var vcam_id := vcam_id_variant as StringName
		if vcam_index.has(vcam_id):
			continue
		if stale_ids.has(vcam_id):
			continue
		stale_ids.append(vcam_id)

	for vcam_id_variant in _orbit_no_look_input_timers.keys():
		var vcam_id := vcam_id_variant as StringName
		if vcam_index.has(vcam_id):
			continue
		if stale_ids.has(vcam_id):
			continue
		stale_ids.append(vcam_id)

	for vcam_id_variant in _orbit_centering_state.keys():
		var vcam_id := vcam_id_variant as StringName
		if vcam_index.has(vcam_id):
			continue
		if stale_ids.has(vcam_id):
			continue
		stale_ids.append(vcam_id)

	for vcam_id_variant in _soft_zone_dead_zone_state.keys():
		var vcam_id := vcam_id_variant as StringName
		if vcam_index.has(vcam_id):
			continue
		if stale_ids.has(vcam_id):
			continue
		stale_ids.append(vcam_id)

	for vcam_id_variant in _look_rotation_state.keys():
		var vcam_id := vcam_id_variant as StringName
		if vcam_index.has(vcam_id):
			continue
		if stale_ids.has(vcam_id):
			continue
		stale_ids.append(vcam_id)

	for stale_id in stale_ids:
		_clear_smoothing_state_for_vcam(stale_id)
		_clear_first_person_strafe_tilt_state_for_vcam(stale_id)
		_clear_ots_collision_state_for_vcam(stale_id)
		_orbit_centering_state.erase(stale_id)
		_clear_soft_zone_dead_zone_state_for_vcam(stale_id)

func _teardown_path_helpers() -> void:
	for helper_variant in _path_follow_helpers.values():
		var helper := helper_variant as PathFollow3D
		if helper == null or not is_instance_valid(helper):
			continue
		helper.queue_free()
	_path_follow_helpers.clear()

func _clear_all_smoothing_state() -> void:
	_follow_dynamics.clear()
	_rotation_dynamics.clear()
	_smoothing_metadata.clear()
	_look_rotation_state.clear()
	_rotation_target_cache.clear()
	_look_ahead_state.clear()
	_ground_relative_state.clear()
	_first_person_strafe_tilt_state.clear()
	_ots_collision_state.clear()
	_look_input_filter_state.clear()
	_follow_target_motion_state.clear()
	_orbit_no_look_input_timers.clear()
	_orbit_centering_state.clear()
	_debug_follow_target_ids.clear()
	_debug_look_ahead_motion_state.clear()
	_debug_soft_zone_status.clear()
	_debug_landing_offset_status = -1
	_debug_last_look_input_by_vcam.clear()
	_debug_position_smoothing_bypass_by_vcam.clear()
	_debug_last_look_spring_stage_by_vcam.clear()

func _clear_smoothing_state_for_vcam(vcam_id: StringName) -> void:
	_follow_dynamics.erase(vcam_id)
	_rotation_dynamics.erase(vcam_id)
	_smoothing_metadata.erase(vcam_id)
	_look_rotation_state.erase(vcam_id)
	_rotation_target_cache.erase(vcam_id)
	_look_ahead_state.erase(vcam_id)
	_ground_relative_state.erase(vcam_id)
	_look_input_filter_state.erase(vcam_id)
	_follow_target_motion_state.erase(vcam_id)
	_orbit_no_look_input_timers.erase(vcam_id)
	_debug_follow_target_ids.erase(vcam_id)
	_debug_look_ahead_motion_state.erase(vcam_id)
	_debug_soft_zone_status.erase(vcam_id)
	_debug_last_look_input_by_vcam.erase(vcam_id)
	_debug_position_smoothing_bypass_by_vcam.erase(vcam_id)
	_debug_last_look_spring_stage_by_vcam.erase(vcam_id)

func _resolve_runtime_rotation_for_evaluation(
	vcam_id: StringName,
	component: C_VCamComponent,
	mode: Resource,
	follow_target: Node3D,
	response_values: Dictionary,
	has_active_look_input: bool,
	delta: float
) -> Vector2:
	if component == null or mode == null:
		return Vector2.ZERO

	var target_rotation := Vector2(component.runtime_yaw, component.runtime_pitch)
	var mode_script := mode.get_script() as Script
	if not _is_look_rotation_smoothing_mode(mode_script):
		_clear_look_rotation_state_for_vcam(vcam_id)
		return target_rotation
	if response_values.is_empty():
		_clear_look_rotation_state_for_vcam(vcam_id)
		return target_rotation

	var rotation_frequency: float = maxf(float(response_values.get("rotation_frequency", 0.0)), 0.0)
	if rotation_frequency <= 0.0:
		_clear_look_rotation_state_for_vcam(vcam_id)
		return target_rotation
	var rotation_damping: float = maxf(float(response_values.get("rotation_damping", 0.0)), 0.0)

	var follow_target_id: int = _get_node_instance_id(follow_target)
	var response_signature: Array[float] = _build_response_signature(response_values)
	var state: Dictionary = _get_look_rotation_state(vcam_id)
	if (
		state.is_empty()
		or _did_mode_change(state, mode_script)
		or _did_follow_target_change(state, follow_target_id)
		or _did_response_change(state, response_signature)
	):
		_set_look_rotation_state(
			vcam_id,
			target_rotation,
			Vector2.ZERO,
			mode_script,
			follow_target_id,
			response_signature,
			has_active_look_input
		)
		_debug_log_look_spring_stage_transition(
			vcam_id,
			"reseed",
			has_active_look_input,
			target_rotation,
			target_rotation,
			Vector2.ZERO
		)
		_debug_log_look_spring_state(
			vcam_id,
			"reseed",
			has_active_look_input,
			target_rotation,
			target_rotation,
			Vector2.ZERO,
			rotation_frequency,
			rotation_damping,
			delta
		)
		return target_rotation

	var smoothed_rotation: Vector2 = Vector2(
		float(state.get("smoothed_yaw", target_rotation.x)),
		float(state.get("smoothed_pitch", target_rotation.y))
	)
	var rotation_velocity: Vector2 = Vector2(
		float(state.get("yaw_velocity", 0.0)),
		float(state.get("pitch_velocity", 0.0))
	)
	var previous_input_active: bool = bool(state.get("input_active", has_active_look_input))
	if previous_input_active and not has_active_look_input and mode_script != RS_VCAM_MODE_ORBIT_SCRIPT:
		smoothed_rotation = target_rotation
		rotation_velocity = Vector2.ZERO
	if delta <= 0.0:
		return smoothed_rotation

	var step_dt: float = minf(maxf(delta, 0.0), U_SECOND_ORDER_DYNAMICS.MAX_STEP_DELTA_SEC)
	if not has_active_look_input:
		if mode_script == RS_VCAM_MODE_ORBIT_SCRIPT:
			var release_yaw_damping: float = maxf(
				float(response_values.get("look_release_yaw_damping", DEFAULT_LOOK_RELEASE_YAW_DAMPING)),
				0.0
			)
			var release_pitch_damping: float = maxf(
				float(response_values.get("look_release_pitch_damping", DEFAULT_LOOK_RELEASE_PITCH_DAMPING)),
				0.0
			)
			var release_stop_threshold: float = maxf(
				float(response_values.get("look_release_stop_threshold", DEFAULT_LOOK_RELEASE_STOP_THRESHOLD)),
				0.0
			)
			var yaw_release_step: Dictionary = _step_orbit_release_axis(
				vcam_id,
				"yaw",
				smoothed_rotation.x,
				target_rotation.x,
				rotation_velocity.x,
				rotation_frequency,
				rotation_damping,
				release_yaw_damping,
				release_stop_threshold,
				step_dt
			)
			var pitch_release_step: Dictionary = _step_orbit_release_axis(
				vcam_id,
				"pitch",
				smoothed_rotation.y,
				target_rotation.y,
				rotation_velocity.y,
				rotation_frequency,
				rotation_damping,
				release_pitch_damping,
				release_stop_threshold,
				step_dt
			)
			smoothed_rotation = Vector2(
				float(yaw_release_step.get("value", target_rotation.x)),
				float(pitch_release_step.get("value", target_rotation.y))
			)
			rotation_velocity = Vector2(
				float(yaw_release_step.get("velocity", 0.0)),
				float(pitch_release_step.get("velocity", 0.0))
			)
			_set_look_rotation_state(
				vcam_id,
				smoothed_rotation,
				rotation_velocity,
				mode_script,
				follow_target_id,
				response_signature,
				has_active_look_input
			)
			_debug_log_look_spring_stage_transition(
				vcam_id,
				"orbit_release",
				has_active_look_input,
				target_rotation,
				smoothed_rotation,
				rotation_velocity
			)
			_debug_log_look_spring_state(
				vcam_id,
				"orbit_release",
				has_active_look_input,
				target_rotation,
				smoothed_rotation,
				rotation_velocity,
				rotation_frequency,
				rotation_damping,
				delta
			)
			return smoothed_rotation

		var idle_settle_speed_deg_per_sec: float = maxf(
			rotation_frequency * IDLE_LOOK_SETTLE_DEG_PER_HZ,
			MIN_IDLE_LOOK_SETTLE_DEG_PER_SEC
		)
		var max_idle_step_deg: float = idle_settle_speed_deg_per_sec * step_dt
		smoothed_rotation = Vector2(
			_move_toward_angle_degrees(smoothed_rotation.x, target_rotation.x, max_idle_step_deg),
			_move_toward_angle_degrees(smoothed_rotation.y, target_rotation.y, max_idle_step_deg)
		)
		rotation_velocity = Vector2.ZERO
		_set_look_rotation_state(
			vcam_id,
			smoothed_rotation,
			rotation_velocity,
			mode_script,
			follow_target_id,
			response_signature,
			has_active_look_input
		)
		_debug_log_look_spring_stage_transition(
			vcam_id,
			"idle_settle",
			has_active_look_input,
			target_rotation,
			smoothed_rotation,
			rotation_velocity
		)
		_debug_log_look_spring_state(
			vcam_id,
			"idle_settle",
			has_active_look_input,
			target_rotation,
			smoothed_rotation,
			rotation_velocity,
			rotation_frequency,
			rotation_damping,
			delta
		)
		return smoothed_rotation

	var yaw_step: Dictionary = _step_second_order_angle(
		smoothed_rotation.x,
		target_rotation.x,
		rotation_velocity.x,
		rotation_frequency,
		rotation_damping,
		step_dt
	)
	var pitch_step: Dictionary = _step_second_order_angle(
		smoothed_rotation.y,
		target_rotation.y,
		rotation_velocity.y,
		rotation_frequency,
		rotation_damping,
		step_dt
	)
	var yaw_value: float = float(yaw_step.get("value", target_rotation.x))
	var yaw_velocity_value: float = float(yaw_step.get("velocity", 0.0))
	var pitch_value: float = float(pitch_step.get("value", target_rotation.y))
	var pitch_velocity_value: float = float(pitch_step.get("velocity", 0.0))
	smoothed_rotation = Vector2(yaw_value, pitch_value)
	rotation_velocity = Vector2(yaw_velocity_value, pitch_velocity_value)
	_set_look_rotation_state(
		vcam_id,
		smoothed_rotation,
		rotation_velocity,
		mode_script,
		follow_target_id,
		response_signature,
		has_active_look_input
	)
	_debug_log_look_spring_stage_transition(
		vcam_id,
		"step",
		has_active_look_input,
		target_rotation,
		smoothed_rotation,
		rotation_velocity
	)
	_debug_log_look_spring_state(
		vcam_id,
		"step",
		has_active_look_input,
		target_rotation,
		smoothed_rotation,
		rotation_velocity,
		rotation_frequency,
		rotation_damping,
		delta
	)
	return smoothed_rotation

func _step_orbit_release_axis(
	vcam_id: StringName,
	axis_label: String,
	current_value: float,
	target_value: float,
	current_velocity: float,
	frequency_hz: float,
	damping_ratio: float,
	release_damping: float,
	stop_threshold: float,
	delta: float
) -> Dictionary:
	var error_before: float = wrapf(target_value - current_value, -180.0, 180.0)
	var axis_step: Dictionary = _step_second_order_angle(
		current_value,
		target_value,
		current_velocity,
		frequency_hz,
		damping_ratio,
		delta
	)
	var next_value: float = float(axis_step.get("value", target_value))
	var velocity_before_damping: float = float(axis_step.get("velocity", 0.0))
	var next_velocity: float = velocity_before_damping
	next_velocity = _apply_release_velocity_damping(
		next_velocity,
		release_damping,
		stop_threshold,
		delta
	)
	if is_equal_approx(next_velocity, 0.0):
		var remaining_error: float = absf(wrapf(target_value - next_value, -180.0, 180.0))
		var settle_epsilon: float = maxf(stop_threshold * maxf(delta, 0.0), 0.0001)
		_debug_log_orbit_release_clamp(
			vcam_id,
			axis_label,
			velocity_before_damping,
			next_velocity,
			stop_threshold,
			release_damping,
			remaining_error,
			settle_epsilon,
			delta
		)
		if remaining_error <= settle_epsilon:
			next_value = target_value
	var error_after: float = wrapf(target_value - next_value, -180.0, 180.0)
	var crossed_target: bool = error_before * error_after < 0.0
	if crossed_target and absf(error_before) <= ORBIT_RELEASE_SIGN_FLIP_SETTLE_ERROR_DEG:
		next_value = target_value
		next_velocity = 0.0

	return {
		"value": next_value,
		"velocity": next_velocity,
	}

func _apply_release_velocity_damping(
	velocity: float,
	damping_per_sec: float,
	stop_threshold: float,
	delta: float
) -> float:
	var next_velocity: float = velocity
	var resolved_damping: float = maxf(damping_per_sec, 0.0)
	var resolved_threshold: float = maxf(stop_threshold, 0.0)
	if resolved_damping > 0.0 and delta > 0.0:
		next_velocity *= exp(-resolved_damping * delta)
	if absf(next_velocity) <= resolved_threshold:
		return 0.0
	return next_velocity

func _step_second_order_angle(
	current_value: float,
	target_value: float,
	current_velocity: float,
	frequency_hz: float,
	damping_ratio: float,
	delta: float
) -> Dictionary:
	var omega: float = TAU * maxf(frequency_hz, 0.0)
	if omega <= 0.0:
		return {
			"value": target_value,
			"velocity": 0.0,
		}

	var error: float = wrapf(target_value - current_value, -180.0, 180.0)
	var accel: float = (omega * omega * error) - (2.0 * damping_ratio * omega * current_velocity)
	var next_velocity: float = current_velocity + accel * delta
	var next_value: float = current_value + next_velocity * delta
	if is_nan(next_value) or is_inf(next_value):
		next_value = target_value
	if is_nan(next_velocity) or is_inf(next_velocity):
		next_velocity = 0.0

	return {
		"value": next_value,
		"velocity": next_velocity,
	}

func _move_toward_angle_degrees(current_value: float, target_value: float, max_delta: float) -> float:
	var delta_to_target: float = wrapf(target_value - current_value, -180.0, 180.0)
	var clamped_delta: float = clampf(delta_to_target, -max_delta, max_delta)
	return current_value + clamped_delta

func _is_look_rotation_smoothing_mode(mode_script: Script) -> bool:
	return mode_script == RS_VCAM_MODE_ORBIT_SCRIPT or mode_script == RS_VCAM_MODE_FIRST_PERSON_SCRIPT

func _get_look_rotation_state(vcam_id: StringName) -> Dictionary:
	var state_variant: Variant = _look_rotation_state.get(vcam_id, {})
	if state_variant is Dictionary:
		return (state_variant as Dictionary).duplicate(true)
	return {}

func _set_look_rotation_state(
	vcam_id: StringName,
	smoothed_rotation: Vector2,
	rotation_velocity: Vector2,
	mode_script: Script,
	follow_target_id: int,
	response_signature: Array[float],
	input_active: bool
) -> void:
	_look_rotation_state[vcam_id] = {
		"smoothed_yaw": smoothed_rotation.x,
		"smoothed_pitch": smoothed_rotation.y,
		"yaw_velocity": rotation_velocity.x,
		"pitch_velocity": rotation_velocity.y,
		"mode_script": mode_script,
		"follow_target_id": follow_target_id,
		"response_signature": response_signature.duplicate(),
		"input_active": input_active,
	}

func _clear_look_rotation_state_for_vcam(vcam_id: StringName) -> void:
	_look_rotation_state.erase(vcam_id)
	_debug_last_look_spring_stage_by_vcam.erase(vcam_id)

func _apply_response_smoothing(
	vcam_id: StringName,
	component: C_VCamComponent,
	mode: Resource,
	follow_target: Node3D,
	raw_result: Dictionary,
	delta: float,
	has_active_look_input: bool
) -> Dictionary:
	if component == null:
		return raw_result
	if mode == null:
		return raw_result

	var raw_transform_variant: Variant = raw_result.get("transform", null)
	if not (raw_transform_variant is Transform3D):
		return raw_result
	var raw_transform := raw_transform_variant as Transform3D

	var response := component.response as Resource
	if response == null:
		_clear_smoothing_state_for_vcam(vcam_id)
		return raw_result
	if response.get_script() != RS_VCAM_RESPONSE_SCRIPT:
		_clear_smoothing_state_for_vcam(vcam_id)
		return raw_result

	var response_values: Dictionary = _resolve_response_values(response)
	var response_signature: Array[float] = _build_response_signature(response_values)
	var mode_script := mode.get_script() as Script
	var follow_target_id: int = _get_node_instance_id(follow_target)
	var follow_target_speed_mps: float = _sample_follow_target_speed(vcam_id, follow_target, delta)
	var raw_euler: Vector3 = raw_transform.basis.get_euler()
	var target_euler: Vector3 = _resolve_unwrapped_target_euler(vcam_id, raw_euler)
	var metadata: Dictionary = _get_smoothing_metadata(vcam_id)
	var has_state: bool = _follow_dynamics.has(vcam_id) and _rotation_dynamics.has(vcam_id)
	var response_changed: bool = _did_response_change(metadata, response_signature)

	if not has_state or response_changed:
		_create_smoothing_state(vcam_id, response_values, raw_transform.origin, target_euler)
		_set_smoothing_metadata(vcam_id, mode_script, follow_target_id, response_signature)
		return raw_result

	var mode_changed: bool = _did_mode_change(metadata, mode_script)
	var target_changed: bool = _did_follow_target_change(metadata, follow_target_id)
	if mode_changed or target_changed:
		_reset_smoothing_state(vcam_id, raw_transform.origin, target_euler)
		_set_smoothing_metadata(vcam_id, mode_script, follow_target_id, response_signature)
		return raw_result

	_set_smoothing_metadata(vcam_id, mode_script, follow_target_id, response_signature)
	return _step_smoothing_state(
		vcam_id,
		raw_result,
		raw_transform,
		target_euler,
		mode_script,
		delta,
		has_active_look_input,
		response_values,
		follow_target_speed_mps
	)

func _step_smoothing_state(
	vcam_id: StringName,
	raw_result: Dictionary,
	raw_transform: Transform3D,
	target_euler: Vector3,
	mode_script: Script,
	delta: float,
	has_active_look_input: bool,
	response_values: Dictionary,
	follow_target_speed_mps: float
) -> Dictionary:
	var follow_dynamics: Variant = _follow_dynamics.get(vcam_id, null)
	if follow_dynamics == null:
		return raw_result

	var rotation_entry_variant: Variant = _rotation_dynamics.get(vcam_id, {})
	if not (rotation_entry_variant is Dictionary):
		return raw_result
	var rotation_entry := rotation_entry_variant as Dictionary

	var bypass_non_fixed_position_smoothing: bool = _should_bypass_orbit_position_smoothing(
		vcam_id,
		mode_script,
		has_active_look_input,
		follow_target_speed_mps,
		response_values
	)
	var bypass_enable_speed: float = maxf(
		float(response_values.get("orbit_look_bypass_enable_speed", DEFAULT_ORBIT_LOOK_BYPASS_ENABLE_SPEED)),
		0.0
	)
	var bypass_disable_speed: float = maxf(
		float(response_values.get("orbit_look_bypass_disable_speed", DEFAULT_ORBIT_LOOK_BYPASS_DISABLE_SPEED)),
		bypass_enable_speed
	)
	var has_previous_bypass_state: bool = _debug_position_smoothing_bypass_by_vcam.has(vcam_id)
	var previous_bypass_variant: Variant = _debug_position_smoothing_bypass_by_vcam.get(
		vcam_id,
		bypass_non_fixed_position_smoothing
	)
	var previous_bypass: bool = bool(previous_bypass_variant)
	_debug_position_smoothing_bypass_by_vcam[vcam_id] = bypass_non_fixed_position_smoothing
	if previous_bypass != bypass_non_fixed_position_smoothing:
		_debug_log_position_smoothing_gate_transition(
			vcam_id,
			mode_script,
			has_active_look_input,
			raw_transform.origin,
			follow_dynamics,
			follow_target_speed_mps,
			bypass_enable_speed,
			bypass_disable_speed,
			previous_bypass,
			bypass_non_fixed_position_smoothing
		)

	# Orbit look input intentionally bypasses follow-position smoothing while rotating.
	# When input is released, reset to current raw position so the first smoothed tick does not pop.
	var released_orbit_bypass_this_tick: bool = (
		has_previous_bypass_state
		and previous_bypass
		and not bypass_non_fixed_position_smoothing
		and mode_script == RS_VCAM_MODE_ORBIT_SCRIPT
	)
	if released_orbit_bypass_this_tick:
		follow_dynamics.reset(raw_transform.origin)
		_debug_log_rotation(
			vcam_id,
			"smoothing_gate_handoff: orbit bypass released, resetting follow dynamics to raw position"
		)
		return raw_result

	if bypass_non_fixed_position_smoothing:
		follow_dynamics.reset(raw_transform.origin)
		return raw_result

	var smooth_position: Vector3 = follow_dynamics.step(raw_transform.origin, delta)
	if mode_script != RS_VCAM_MODE_FIXED_SCRIPT:
		var smooth_transform_non_fixed := Transform3D(raw_transform.basis.orthonormalized(), smooth_position)
		var non_fixed_result: Dictionary = raw_result.duplicate(true)
		non_fixed_result["transform"] = smooth_transform_non_fixed
		return non_fixed_result

	var smooth_x: float = _step_rotation_axis(rotation_entry, StringName("x"), target_euler.x, delta)
	var smooth_y: float = _step_rotation_axis(rotation_entry, StringName("y"), target_euler.y, delta)
	var smooth_z: float = _step_rotation_axis(rotation_entry, StringName("z"), target_euler.z, delta)
	var smooth_basis: Basis = _compose_basis_from_euler(Vector3(smooth_x, smooth_y, smooth_z))

	var smooth_transform := Transform3D(smooth_basis, smooth_position)
	var smoothed_result: Dictionary = raw_result.duplicate(true)
	smoothed_result["transform"] = smooth_transform
	return smoothed_result

func _create_smoothing_state(
	vcam_id: StringName,
	response_values: Dictionary,
	initial_position: Vector3,
	initial_euler: Vector3
) -> void:
	var follow_frequency: float = float(response_values.get("follow_frequency", 3.0))
	var follow_damping: float = float(response_values.get("follow_damping", 0.7))
	var follow_response: float = float(response_values.get("follow_initial_response", 1.0))
	var rotation_frequency: float = float(response_values.get("rotation_frequency", 4.0))
	var rotation_damping: float = float(response_values.get("rotation_damping", 1.0))
	var rotation_response: float = float(response_values.get("rotation_initial_response", 1.0))

	_follow_dynamics[vcam_id] = U_SECOND_ORDER_DYNAMICS_3D.new(
		follow_frequency,
		follow_damping,
		follow_response,
		initial_position
	)
	_rotation_dynamics[vcam_id] = {
		"x": U_SECOND_ORDER_DYNAMICS.new(rotation_frequency, rotation_damping, rotation_response, initial_euler.x),
		"y": U_SECOND_ORDER_DYNAMICS.new(rotation_frequency, rotation_damping, rotation_response, initial_euler.y),
		"z": U_SECOND_ORDER_DYNAMICS.new(rotation_frequency, rotation_damping, rotation_response, initial_euler.z),
	}
	_rotation_target_cache[vcam_id] = initial_euler

func _reset_smoothing_state(vcam_id: StringName, position: Vector3, euler: Vector3) -> void:
	var follow_dynamics: Variant = _follow_dynamics.get(vcam_id, null)
	if follow_dynamics != null:
		follow_dynamics.reset(position)

	var rotation_entry_variant: Variant = _rotation_dynamics.get(vcam_id, {})
	if rotation_entry_variant is Dictionary:
		var rotation_entry := rotation_entry_variant as Dictionary
		_reset_rotation_axis(rotation_entry, StringName("x"), euler.x)
		_reset_rotation_axis(rotation_entry, StringName("y"), euler.y)
		_reset_rotation_axis(rotation_entry, StringName("z"), euler.z)

	_rotation_target_cache[vcam_id] = euler

func _step_rotation_axis(rotation_entry: Dictionary, key: StringName, target: float, delta: float) -> float:
	var axis_dynamics: Variant = rotation_entry.get(key, null)
	if axis_dynamics == null:
		return target
	return float(axis_dynamics.step(target, delta))

func _reset_rotation_axis(rotation_entry: Dictionary, key: StringName, value: float) -> void:
	var axis_dynamics: Variant = rotation_entry.get(key, null)
	if axis_dynamics == null:
		return
	axis_dynamics.reset(value)

func _resolve_response_values(response: Resource) -> Dictionary:
	var resolved_values: Dictionary = {}
	if response.has_method("get_resolved_values"):
		var resolved_variant: Variant = response.call("get_resolved_values")
		if resolved_variant is Dictionary:
			resolved_values = (resolved_variant as Dictionary).duplicate(true)

	if resolved_values.is_empty():
		resolved_values = {
			"follow_frequency": maxf(float(response.get("follow_frequency")), 0.0001),
			"follow_damping": maxf(float(response.get("follow_damping")), 0.0),
			"follow_initial_response": float(response.get("follow_initial_response")),
			"rotation_frequency": maxf(float(response.get("rotation_frequency")), 0.0001),
			"rotation_damping": maxf(float(response.get("rotation_damping")), 0.0),
			"rotation_initial_response": float(response.get("rotation_initial_response")),
			"look_ahead_distance": maxf(float(response.get("look_ahead_distance")), 0.0),
			"look_ahead_smoothing": maxf(float(response.get("look_ahead_smoothing")), 0.0),
			"auto_level_speed": maxf(float(response.get("auto_level_speed")), 0.0),
			"auto_level_delay": maxf(float(response.get("auto_level_delay")), 0.0),
			"look_input_deadzone": maxf(
				float(response.get("look_input_deadzone")),
				0.0
			),
			"look_input_hold_sec": maxf(
				float(response.get("look_input_hold_sec")),
				0.0
			),
			"look_input_release_decay": maxf(
				float(response.get("look_input_release_decay")),
				0.0
			),
			"look_release_yaw_damping": maxf(
				float(response.get("look_release_yaw_damping")),
				0.0
			),
			"look_release_pitch_damping": maxf(
				float(response.get("look_release_pitch_damping")),
				0.0
			),
			"look_release_stop_threshold": maxf(
				float(response.get("look_release_stop_threshold")),
				0.0
			),
			"orbit_look_bypass_enable_speed": maxf(
				float(response.get("orbit_look_bypass_enable_speed")),
				0.0
			),
			"orbit_look_bypass_disable_speed": maxf(
				float(response.get("orbit_look_bypass_disable_speed")),
				0.0
			),
			"ground_relative_enabled": bool(response.get("ground_relative_enabled")),
			"ground_reanchor_min_height_delta": maxf(
				float(response.get("ground_reanchor_min_height_delta")),
				0.0
			),
			"ground_probe_max_distance": maxf(
				float(response.get("ground_probe_max_distance")),
				0.0
			),
			"ground_anchor_blend_hz": maxf(
				float(response.get("ground_anchor_blend_hz")),
				0.0
			),
		}
		var resolved_disable_speed: float = maxf(
			float(resolved_values.get("orbit_look_bypass_disable_speed", DEFAULT_ORBIT_LOOK_BYPASS_DISABLE_SPEED)),
			float(resolved_values.get("orbit_look_bypass_enable_speed", DEFAULT_ORBIT_LOOK_BYPASS_ENABLE_SPEED))
		)
		resolved_values["orbit_look_bypass_disable_speed"] = resolved_disable_speed
	return resolved_values

func _build_response_signature(response_values: Dictionary) -> Array[float]:
	return [
		float(response_values.get("follow_frequency", 3.0)),
		float(response_values.get("follow_damping", 0.7)),
		float(response_values.get("follow_initial_response", 1.0)),
		float(response_values.get("rotation_frequency", 4.0)),
		float(response_values.get("rotation_damping", 1.0)),
		float(response_values.get("rotation_initial_response", 1.0)),
		float(response_values.get("look_input_deadzone", DEFAULT_LOOK_INPUT_DEADZONE)),
		float(response_values.get("look_input_hold_sec", DEFAULT_LOOK_INPUT_HOLD_SEC)),
		float(response_values.get("look_input_release_decay", DEFAULT_LOOK_INPUT_RELEASE_DECAY)),
		float(response_values.get("look_release_yaw_damping", DEFAULT_LOOK_RELEASE_YAW_DAMPING)),
		float(response_values.get("look_release_pitch_damping", DEFAULT_LOOK_RELEASE_PITCH_DAMPING)),
		float(response_values.get("look_release_stop_threshold", DEFAULT_LOOK_RELEASE_STOP_THRESHOLD)),
		float(response_values.get("orbit_look_bypass_enable_speed", DEFAULT_ORBIT_LOOK_BYPASS_ENABLE_SPEED)),
		float(response_values.get("orbit_look_bypass_disable_speed", DEFAULT_ORBIT_LOOK_BYPASS_DISABLE_SPEED)),
		1.0 if bool(response_values.get("ground_relative_enabled", false)) else 0.0,
		float(response_values.get("ground_reanchor_min_height_delta", 0.0)),
		float(response_values.get("ground_probe_max_distance", 0.0)),
		float(response_values.get("ground_anchor_blend_hz", 0.0)),
	]

func _get_smoothing_metadata(vcam_id: StringName) -> Dictionary:
	var metadata_variant: Variant = _smoothing_metadata.get(vcam_id, {})
	if metadata_variant is Dictionary:
		return (metadata_variant as Dictionary).duplicate(true)
	return {}

func _set_smoothing_metadata(
	vcam_id: StringName,
	mode_script: Script,
	follow_target_id: int,
	response_signature: Array[float]
) -> void:
	_smoothing_metadata[vcam_id] = {
		"mode_script": mode_script,
		"follow_target_id": follow_target_id,
		"response_signature": response_signature.duplicate(),
	}

func _did_mode_change(metadata: Dictionary, mode_script: Script) -> bool:
	if metadata.is_empty():
		return false
	var previous_mode_variant: Variant = metadata.get("mode_script", null)
	if previous_mode_variant == null:
		return mode_script != null
	var previous_mode := previous_mode_variant as Script
	return previous_mode != mode_script

func _did_follow_target_change(metadata: Dictionary, follow_target_id: int) -> bool:
	if metadata.is_empty():
		return false
	var previous_target_id: int = int(metadata.get("follow_target_id", 0))
	return previous_target_id != follow_target_id

func _did_response_change(metadata: Dictionary, response_signature: Array[float]) -> bool:
	if metadata.is_empty():
		return false
	var previous_signature_variant: Variant = metadata.get("response_signature", [])
	if not (previous_signature_variant is Array):
		return true
	var previous_signature := previous_signature_variant as Array
	if previous_signature.size() != response_signature.size():
		return true
	for index in range(response_signature.size()):
		if not is_equal_approx(float(previous_signature[index]), response_signature[index]):
			return true
	return false

func _resolve_unwrapped_target_euler(vcam_id: StringName, target_euler: Vector3) -> Vector3:
	if not _rotation_target_cache.has(vcam_id):
		_rotation_target_cache[vcam_id] = target_euler
		return target_euler

	var previous_target := _rotation_target_cache.get(vcam_id, target_euler) as Vector3
	var unwrapped_target := Vector3(
		_unwrap_angle_to_reference(target_euler.x, previous_target.x),
		_unwrap_angle_to_reference(target_euler.y, previous_target.y),
		_unwrap_angle_to_reference(target_euler.z, previous_target.z)
	)
	_rotation_target_cache[vcam_id] = unwrapped_target
	return unwrapped_target

func _unwrap_angle_to_reference(target_angle: float, reference_angle: float) -> float:
	return reference_angle + wrapf(target_angle - reference_angle, -PI, PI)

func _get_node_instance_id(node: Node) -> int:
	if node == null:
		return 0
	if not is_instance_valid(node):
		return 0
	return node.get_instance_id()

func _compose_basis_from_euler(euler: Vector3) -> Basis:
	var basis := Basis.IDENTITY
	basis = basis.rotated(Vector3.UP, euler.y)
	basis = basis.rotated(basis.x, euler.x)
	basis = basis.rotated(basis.z, euler.z)
	return basis.orthonormalized()

func _resolve_vcam_manager() -> I_VCAM_MANAGER:
	if _vcam_manager != null and is_instance_valid(_vcam_manager):
		return _vcam_manager as I_VCAM_MANAGER

	if vcam_manager != null and is_instance_valid(vcam_manager):
		_vcam_manager = vcam_manager
		return _vcam_manager as I_VCAM_MANAGER

	var service: Node = U_SERVICE_LOCATOR.try_get_service(StringName("vcam_manager"))
	if service == null or not is_instance_valid(service):
		return null
	if not (service is I_VCAM_MANAGER):
		return null

	_vcam_manager = service
	return _vcam_manager as I_VCAM_MANAGER

func _resolve_state_store() -> I_StateStore:
	if _state_store != null and is_instance_valid(_state_store):
		return _state_store
	if state_store != null and is_instance_valid(state_store):
		_state_store = state_store
		return _state_store
	_state_store = U_STATE_UTILS.try_get_store(self)
	return _state_store

func _read_look_input() -> Vector2:
	var store := _resolve_state_store()
	if store == null:
		return Vector2.ZERO
	var state: Dictionary = store.get_state()
	return U_INPUT_SELECTORS.get_look_input(state)

func _read_move_input() -> Vector2:
	var store := _resolve_state_store()
	if store == null:
		return Vector2.ZERO
	var state: Dictionary = store.get_state()
	return U_INPUT_SELECTORS.get_move_input(state)

func _read_camera_center_just_pressed() -> bool:
	var store := _resolve_state_store()
	if store == null:
		return false
	var state: Dictionary = store.get_state()
	return U_INPUT_SELECTORS.is_camera_center_just_pressed(state)

func _debug_log_follow_target_resolution(
	vcam_id: StringName,
	component: C_VCamComponent,
	follow_target: Node3D
) -> void:
	if not debug_rotation_logging:
		return
	var target_id: int = _get_node_instance_id(follow_target)
	var previous_target_id: int = int(_debug_follow_target_ids.get(vcam_id, -1))
	if previous_target_id == target_id:
		return
	_debug_follow_target_ids[vcam_id] = target_id

	var resolved_path: String = "<null>"
	if follow_target != null and is_instance_valid(follow_target):
		resolved_path = String(follow_target.get_path())
	var configured_path: String = String(component.follow_target_path)
	var fallback_entity_id: String = String(component.follow_target_entity_id)
	var fallback_tag: String = String(component.follow_target_tag)
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

func _debug_log_look_ahead_motion_state(
	vcam_id: StringName,
	is_moving: bool,
	follow_target: Node3D,
	movement_velocity: Vector3,
	desired_offset: Vector3
) -> void:
	if not debug_rotation_logging:
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
				var gameplay_entities: Dictionary = state.get("gameplay", {}).get("entities", {})
				var entity_state: Dictionary = gameplay_entities.get(String(gameplay_entity_id), {})
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

func _debug_log_soft_zone_status(vcam_id: StringName, status: String, correction: Vector3) -> void:
	if not debug_rotation_logging:
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

func _debug_log_soft_zone_metrics(vcam_id: StringName, correction_result: Dictionary, correction: Vector3) -> void:
	if not debug_rotation_logging:
		return
	var normalized_variant: Variant = correction_result.get("normalized_screen_pos", Vector2.ZERO)
	var corrected_variant: Variant = correction_result.get("corrected_normalized_pos", Vector2.ZERO)
	var dead_zone_variant: Variant = correction_result.get("dead_zone_state", {})
	var normalized_screen_pos: Vector2 = normalized_variant as Vector2 if normalized_variant is Vector2 else Vector2.ZERO
	var corrected_normalized_pos: Vector2 = corrected_variant as Vector2 if corrected_variant is Vector2 else Vector2.ZERO
	var dead_zone_state: Dictionary = dead_zone_variant as Dictionary if dead_zone_variant is Dictionary else {}
	_debug_log_rotation(
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

func _debug_log_look_input_transition(vcam_id: StringName, look_input: Vector2) -> void:
	if not debug_rotation_logging:
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
		_debug_log_rotation(
			vcam_id,
			"look_input_noise raw=%s len=%.6f"
			% [str(look_input), look_input.length()]
		)

	_debug_last_look_input_by_vcam[vcam_id] = look_input

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
	if not debug_rotation_logging:
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

	print(
		"S_VCamSystem[debug] look_filter: vcam_id=%s raw=%s raw_active=%s filtered=%s prev_filtered=%s filtered_active=%s->%s hold_timer=%.4f deadzone=%.4f hold=%.4f decay=%.4f"
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

func _debug_log_look_spring_stage_transition(
	vcam_id: StringName,
	stage: String,
	has_active_look_input: bool,
	target_rotation: Vector2,
	smoothed_rotation: Vector2,
	rotation_velocity: Vector2
) -> void:
	if not debug_rotation_logging:
		return
	var previous_stage: String = String(_debug_last_look_spring_stage_by_vcam.get(vcam_id, ""))
	if previous_stage == stage:
		return
	_debug_last_look_spring_stage_by_vcam[vcam_id] = stage
	var yaw_error_deg: float = wrapf(target_rotation.x - smoothed_rotation.x, -180.0, 180.0)
	var pitch_error_deg: float = wrapf(target_rotation.y - smoothed_rotation.y, -180.0, 180.0)
	print(
		"S_VCamSystem[debug] look_spring_stage: vcam_id=%s stage=%s prev=%s active_input=%s error_deg=(%.3f,%.3f) vel=(%.3f,%.3f)"
		% [
			String(vcam_id),
			stage,
			previous_stage,
			str(has_active_look_input),
			yaw_error_deg,
			pitch_error_deg,
			rotation_velocity.x,
			rotation_velocity.y,
		]
	)

func _debug_log_orbit_release_clamp(
	vcam_id: StringName,
	axis_label: String,
	velocity_before_damping: float,
	velocity_after_damping: float,
	stop_threshold: float,
	release_damping: float,
	remaining_error: float,
	settle_epsilon: float,
	delta: float
) -> void:
	if not debug_rotation_logging:
		return
	if not is_equal_approx(velocity_after_damping, 0.0):
		return
	if absf(velocity_before_damping) <= 0.0:
		return
	print(
		"S_VCamSystem[debug] orbit_release_clamp: vcam_id=%s axis=%s vel_before=%.6f vel_after=%.6f threshold=%.6f damping=%.4f remaining_error=%.6f settle_epsilon=%.6f dt=%.4f"
		% [
			String(vcam_id),
			axis_label,
			velocity_before_damping,
			velocity_after_damping,
			stop_threshold,
			release_damping,
			remaining_error,
			settle_epsilon,
			delta,
		]
	)

func _debug_log_look_spring_state(
	vcam_id: StringName,
	stage: String,
	has_active_look_input: bool,
	target_rotation: Vector2,
	smoothed_rotation: Vector2,
	rotation_velocity: Vector2,
	rotation_frequency: float,
	rotation_damping: float,
	delta: float
) -> void:
	if not debug_rotation_logging:
		return
	var yaw_error_deg: float = wrapf(target_rotation.x - smoothed_rotation.x, -180.0, 180.0)
	var pitch_error_deg: float = wrapf(target_rotation.y - smoothed_rotation.y, -180.0, 180.0)
	if has_active_look_input and absf(yaw_error_deg) < 0.1 and absf(pitch_error_deg) < 0.1:
		return
	_debug_log_rotation(
		vcam_id,
		"look_spring stage=%s active_input=%s target=%s smoothed=%s error_deg=(%.3f,%.3f) vel=(%.3f,%.3f) f=%.3f z=%.3f dt=%.4f"
		% [
			stage,
			str(has_active_look_input),
			str(target_rotation),
			str(smoothed_rotation),
			yaw_error_deg,
			pitch_error_deg,
			rotation_velocity.x,
			rotation_velocity.y,
			rotation_frequency,
			rotation_damping,
			delta,
		]
	)

func _debug_log_position_smoothing_gate_transition(
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
	if not debug_rotation_logging:
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

func _debug_log_landing_offset_state(landing_offset: Vector3) -> void:
	if not debug_rotation_logging:
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

func _report_issue(message: String) -> void:
	if _debug_issues.size() >= 64:
		_debug_issues.remove_at(0)
	_debug_issues.append(message)
	print_verbose("S_VCamSystem: %s" % message)

func _debug_log_rotation(vcam_id: StringName, message: String) -> void:
	if not debug_rotation_logging:
		return
	if _debug_rotation_log_cooldown_sec > 0.0:
		return
	var interval: float = maxf(debug_rotation_log_interval_sec, 0.05)
	_debug_rotation_log_cooldown_sec = interval
	print("S_VCamSystem[debug] %s: %s" % [str(vcam_id), message])

func _debug_log_vcam_state(message: String, active_vcam_id: StringName, look_input: Vector2) -> void:
	if not debug_rotation_logging:
		return
	if _debug_state_log_cooldown_sec > 0.0:
		return
	var interval: float = maxf(debug_rotation_log_interval_sec, 0.05)
	_debug_state_log_cooldown_sec = interval
	print(
		"S_VCamSystem[debug] state: %s active_vcam_id=%s look_input=%s"
		% [message, str(active_vcam_id), str(look_input)]
	)
