@icon("res://assets/editor_icons/icn_manager.svg")
extends "res://scripts/interfaces/i_vcam_manager.gd"
class_name M_VCamManager

const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_STATE_UTILS := preload("res://scripts/state/utils/u_state_utils.gd")
const U_VCAM_ACTIONS := preload("res://scripts/state/actions/u_vcam_actions.gd")
const U_ECS_EVENT_BUS := preload("res://scripts/events/ecs/u_ecs_event_bus.gd")
const U_ECS_EVENT_NAMES := preload("res://scripts/events/ecs/u_ecs_event_names.gd")
const I_CAMERA_MANAGER := preload("res://scripts/interfaces/i_camera_manager.gd")
const I_ECS_MANAGER := preload("res://scripts/interfaces/i_ecs_manager.gd")
const RS_VCAM_BLEND_HINT_SCRIPT := preload("res://scripts/resources/display/vcam/rs_vcam_blend_hint.gd")
const U_VCAM_COLLISION_DETECTOR := preload("res://scripts/managers/helpers/u_vcam_collision_detector.gd")

const VCAM_OCCLUSION_COLLISION_MASK: int = 1 << 5

@export var state_store: I_StateStore = null
@export var camera_manager: I_CAMERA_MANAGER = null
@export var ecs_manager: I_ECS_MANAGER = null

var _state_store: I_StateStore = null
var _camera_manager: I_CAMERA_MANAGER = null
var _ecs_manager: I_ECS_MANAGER = null

var _vcams_by_id: Dictionary = {}
var _registered_vcams: Dictionary = {}
var _submitted_results: Dictionary = {}

var _active_vcam_id: StringName = StringName("")
var _previous_vcam_id: StringName = StringName("")
var _explicit_vcam_id: StringName = StringName("")
var _blend_progress: float = 1.0
var _is_blending_active: bool = false
var _blend_duration: float = 0.0
var _blend_elapsed: float = 0.0
var _last_physics_delta: float = 0.0
var _startup_blend_pending_vcam_id: StringName = StringName("")
var _startup_blend_active: bool = false
var _startup_blend_vcam_id: StringName = StringName("")
var _startup_blend_from_transform: Transform3D = Transform3D.IDENTITY
var _startup_blend_duration_sec: float = 0.0
var _startup_blend_elapsed_sec: float = 0.0
var _startup_blend_trans_type: int = int(Tween.TRANS_CUBIC)
var _startup_blend_ease_type: int = int(Tween.EASE_IN_OUT)
var _startup_blend_cut_on_distance_threshold: float = 0.0

func _ready() -> void:
	var service_name := StringName("vcam_manager")
	var existing := U_SERVICE_LOCATOR.try_get_service(service_name)
	if existing != self:
		U_SERVICE_LOCATOR.register(service_name, self)
	_state_store = _resolve_state_store()
	_camera_manager = _resolve_camera_manager()
	_ecs_manager = _resolve_ecs_manager()
	set_physics_process(true)
	_refresh_active_selection()

func _physics_process(_delta: float) -> void:
	_last_physics_delta = maxf(_delta, 0.0)
	_refresh_active_selection()

func register_vcam(vcam: Node) -> void:
	if vcam == null or not is_instance_valid(vcam):
		_report_issue("register_vcam received invalid vcam instance")
		return

	var resolved_vcam_id := _resolve_vcam_id(vcam)
	if resolved_vcam_id == StringName(""):
		_report_issue("register_vcam rejected component with empty vcam_id")
		return

	if _vcams_by_id.has(resolved_vcam_id):
		var existing: Variant = _vcams_by_id.get(resolved_vcam_id, null)
		if existing == vcam:
			return
		_report_issue("register_vcam rejected duplicate vcam_id '%s'" % String(resolved_vcam_id))
		return

	if _registered_vcams.has(vcam):
		var previous_id := _registered_vcams.get(vcam, StringName("")) as StringName
		if previous_id != StringName("") and _vcams_by_id.get(previous_id, null) == vcam:
			_vcams_by_id.erase(previous_id)

	_registered_vcams[vcam] = resolved_vcam_id
	_vcams_by_id[resolved_vcam_id] = vcam
	_refresh_active_selection()

func unregister_vcam(vcam: Node) -> void:
	if vcam == null or not is_instance_valid(vcam):
		return
	if not _registered_vcams.has(vcam):
		return

	var vcam_id := _registered_vcams.get(vcam, StringName("")) as StringName
	_registered_vcams.erase(vcam)
	if _vcams_by_id.get(vcam_id, null) == vcam:
		_vcams_by_id.erase(vcam_id)
	_submitted_results.erase(vcam_id)

	if _explicit_vcam_id == vcam_id:
		_explicit_vcam_id = StringName("")
	if _previous_vcam_id == vcam_id:
		_previous_vcam_id = StringName("")

	if _vcams_by_id.is_empty():
		_clear_runtime_state()
		return
	_refresh_active_selection()

func set_active_vcam(vcam_id: StringName, blend_duration: float = -1.0) -> void:
	if blend_duration >= 0.0:
		_blend_duration = maxf(blend_duration, 0.0)
		_blend_elapsed = 0.0

	if vcam_id == StringName(""):
		_explicit_vcam_id = StringName("")
		_refresh_active_selection()
		return

	if not _vcams_by_id.has(vcam_id):
		_report_issue("set_active_vcam ignored unknown vcam_id '%s'" % String(vcam_id))
		return

	_explicit_vcam_id = vcam_id
	_refresh_active_selection()

func get_active_vcam_id() -> StringName:
	return _active_vcam_id

func get_previous_vcam_id() -> StringName:
	return _previous_vcam_id

func submit_evaluated_camera(vcam_id: StringName, result: Dictionary) -> void:
	if vcam_id == StringName(""):
		return
	if result == null:
		return
	_submitted_results[vcam_id] = result.duplicate(true)
	_try_apply_active_submission(vcam_id)

func get_blend_progress() -> float:
	return _blend_progress

func is_blending() -> bool:
	return _is_blending_active

func get_active_vcam() -> Node:
	return _vcams_by_id.get(_active_vcam_id, null) as Node

func get_vcam(vcam_id: StringName) -> Node:
	return _vcams_by_id.get(vcam_id, null) as Node

func _refresh_active_selection() -> void:
	_prune_invalid_registrations()
	var next_active_id := _determine_next_active_id()
	if next_active_id == _active_vcam_id:
		return
	_set_active_vcam_internal(next_active_id)

func _determine_next_active_id() -> StringName:
	if _explicit_vcam_id != StringName(""):
		var explicit_vcam := _vcams_by_id.get(_explicit_vcam_id, null) as Node
		if _is_vcam_selectable(explicit_vcam):
			return _explicit_vcam_id
	_explicit_vcam_id = StringName("")
	return _select_highest_priority_vcam()

func _select_highest_priority_vcam() -> StringName:
	var best_vcam_id: StringName = StringName("")
	var best_priority: int = -2147483648

	for vcam_id_variant in _vcams_by_id.keys():
		var vcam_id := vcam_id_variant as StringName
		var vcam := _vcams_by_id.get(vcam_id, null) as Node
		if not _is_vcam_selectable(vcam):
			continue

		var vcam_priority := _get_vcam_priority(vcam)
		var choose_candidate := false
		if best_vcam_id == StringName(""):
			choose_candidate = true
		elif vcam_priority > best_priority:
			choose_candidate = true
		elif vcam_priority == best_priority and String(vcam_id) < String(best_vcam_id):
			choose_candidate = true

		if choose_candidate:
			best_vcam_id = vcam_id
			best_priority = vcam_priority

	return best_vcam_id

func _set_active_vcam_internal(next_vcam_id: StringName) -> void:
	var previous_vcam_id := _active_vcam_id
	_active_vcam_id = next_vcam_id
	_previous_vcam_id = previous_vcam_id
	_queue_startup_blend_if_needed(next_vcam_id, previous_vcam_id)

	var active_mode := _get_mode_name_for_vcam(next_vcam_id)
	_dispatch_active_runtime(next_vcam_id, active_mode)
	_publish_active_changed(next_vcam_id, previous_vcam_id, active_mode)

func _dispatch_active_runtime(vcam_id: StringName, mode_name: String) -> void:
	var store := _resolve_state_store()
	if store == null:
		return
	store.dispatch(U_VCAM_ACTIONS.set_active_runtime(vcam_id, mode_name))

func _publish_active_changed(vcam_id: StringName, previous_vcam_id: StringName, mode_name: String) -> void:
	U_ECS_EVENT_BUS.publish(U_ECS_EVENT_NAMES.EVENT_VCAM_ACTIVE_CHANGED, {
		"vcam_id": vcam_id,
		"previous_vcam_id": previous_vcam_id,
		"mode": mode_name,
	})

func _clear_runtime_state() -> void:
	var previous_vcam_id := _active_vcam_id
	_active_vcam_id = StringName("")
	_previous_vcam_id = StringName("")
	_explicit_vcam_id = StringName("")
	_submitted_results.clear()
	_blend_progress = 1.0
	_is_blending_active = false
	_blend_duration = 0.0
	_blend_elapsed = 0.0
	_last_physics_delta = 0.0
	_clear_startup_blend_state()
	_dispatch_active_runtime(StringName(""), "")
	if previous_vcam_id != StringName(""):
		_publish_active_changed(StringName(""), previous_vcam_id, "")

func _prune_invalid_registrations() -> void:
	var stale_vcams: Array = []
	for vcam_variant in _registered_vcams.keys():
		var vcam := vcam_variant as Node
		if vcam == null or not is_instance_valid(vcam):
			stale_vcams.append(vcam_variant)

	for stale_variant in stale_vcams:
		var stale_vcam := stale_variant as Node
		var stale_id := _registered_vcams.get(stale_vcam, StringName("")) as StringName
		_registered_vcams.erase(stale_vcam)
		if stale_id != StringName("") and _vcams_by_id.get(stale_id, null) == stale_vcam:
			_vcams_by_id.erase(stale_id)
		_submitted_results.erase(stale_id)

	if _explicit_vcam_id != StringName("") and not _vcams_by_id.has(_explicit_vcam_id):
		_explicit_vcam_id = StringName("")

func _is_vcam_selectable(vcam: Node) -> bool:
	if vcam == null:
		return false
	if not is_instance_valid(vcam):
		return false
	if "is_active" in vcam and not bool(vcam.get("is_active")):
		return false
	return true

func _resolve_vcam_id(vcam: Node) -> StringName:
	if vcam == null:
		return StringName("")
	if "vcam_id" in vcam:
		var id_variant: Variant = vcam.get("vcam_id")
		if id_variant is StringName:
			var typed_id := id_variant as StringName
			if typed_id != StringName(""):
				return typed_id
		var raw_id := String(id_variant)
		if not raw_id.is_empty():
			return StringName(raw_id)
	var fallback_id := String(vcam.name)
	if fallback_id.is_empty():
		return StringName("")
	return StringName(fallback_id.to_snake_case())

func _get_vcam_priority(vcam: Node) -> int:
	if vcam == null:
		return 0
	if "priority" in vcam:
		return int(vcam.get("priority"))
	return 0

func _get_mode_name_for_vcam(vcam_id: StringName) -> String:
	if vcam_id == StringName(""):
		return ""
	var vcam := _vcams_by_id.get(vcam_id, null) as Node
	if vcam == null or not is_instance_valid(vcam):
		return ""

	if vcam.has_method("get_mode_name"):
		return str(vcam.call("get_mode_name"))

	if "mode" not in vcam:
		return ""
	var mode_variant: Variant = vcam.get("mode")
	if not (mode_variant is Resource):
		return ""

	return _resolve_mode_name(mode_variant as Resource)

func _resolve_mode_name(mode: Resource) -> String:
	if mode == null:
		return ""
	var mode_script := mode.get_script() as Script
	if mode_script == null:
		return ""
	var global_name := mode_script.get_global_name()
	if not global_name.is_empty():
		if global_name.begins_with("RS_VCamMode"):
			return global_name.trim_prefix("RS_VCamMode").to_snake_case()
		return global_name.to_snake_case()
	var file_name := mode_script.resource_path.get_file().get_basename()
	if file_name.begins_with("rs_vcam_mode_"):
		return file_name.trim_prefix("rs_vcam_mode_")
	return file_name

func _resolve_state_store() -> I_StateStore:
	if _state_store != null and is_instance_valid(_state_store):
		return _state_store
	if state_store != null and is_instance_valid(state_store):
		_state_store = state_store
		return _state_store
	_state_store = U_STATE_UTILS.try_get_store(self)
	return _state_store

func _resolve_camera_manager() -> I_CAMERA_MANAGER:
	if _camera_manager != null and is_instance_valid(_camera_manager):
		return _camera_manager
	if camera_manager != null and is_instance_valid(camera_manager):
		_camera_manager = camera_manager
		return _camera_manager
	_camera_manager = U_SERVICE_LOCATOR.try_get_service(StringName("camera_manager")) as I_CAMERA_MANAGER
	return _camera_manager

func _resolve_ecs_manager() -> I_ECS_MANAGER:
	if _ecs_manager != null and is_instance_valid(_ecs_manager):
		return _ecs_manager
	if ecs_manager != null and is_instance_valid(ecs_manager):
		_ecs_manager = ecs_manager
		return _ecs_manager
	_ecs_manager = U_SERVICE_LOCATOR.try_get_service(StringName("ecs_manager")) as I_ECS_MANAGER
	return _ecs_manager

func _try_apply_active_submission(vcam_id: StringName) -> void:
	if vcam_id == StringName(""):
		return
	if vcam_id != _active_vcam_id:
		return

	var camera_mgr: I_CAMERA_MANAGER = _resolve_camera_manager()
	if camera_mgr == null:
		return
	if camera_mgr.is_blend_active():
		return
	_try_startup_blend_if_pending(vcam_id, camera_mgr)

	var result_variant: Variant = _submitted_results.get(vcam_id, {})
	if not (result_variant is Dictionary):
		return
	var result := result_variant as Dictionary
	var transform_variant: Variant = result.get("transform", null)
	if not (transform_variant is Transform3D):
		return
	var target_transform := transform_variant as Transform3D
	var applied_transform: Transform3D = _resolve_startup_blend_transform(vcam_id, target_transform)
	camera_mgr.apply_main_camera_transform(applied_transform)
	_publish_silhouette_update_request_for_active_vcam(vcam_id, applied_transform)

func _publish_silhouette_update_request_for_active_vcam(
	vcam_id: StringName,
	camera_transform: Transform3D
) -> void:
	var vcam := _vcams_by_id.get(vcam_id, null) as Node
	var entity_id: StringName = _resolve_silhouette_entity_id(vcam)
	var follow_target: Node3D = _resolve_follow_target_for_vcam(vcam)
	if follow_target == null or not is_instance_valid(follow_target):
		_publish_silhouette_update_request(entity_id, [], false)
		return

	var world: World3D = follow_target.get_world_3d()
	if world == null:
		_publish_silhouette_update_request(entity_id, [], false)
		return
	var space_state: PhysicsDirectSpaceState3D = world.direct_space_state
	if space_state == null:
		_publish_silhouette_update_request(entity_id, [], false)
		return

	var occluders_variant: Variant = U_VCAM_COLLISION_DETECTOR.detect_occluders(
		space_state,
		camera_transform.origin,
		follow_target.global_position,
		VCAM_OCCLUSION_COLLISION_MASK
	)
	var occluders: Array = []
	if occluders_variant is Array:
		occluders = (occluders_variant as Array).duplicate(false)
	_publish_silhouette_update_request(entity_id, occluders, true)

func _publish_silhouette_update_request(entity_id: StringName, occluders: Array, enabled: bool) -> void:
	var safe_occluders: Array = []
	for occluder_variant in occluders:
		if not (occluder_variant is GeometryInstance3D):
			continue
		var occluder := occluder_variant as GeometryInstance3D
		if occluder == null or not is_instance_valid(occluder):
			continue
		safe_occluders.append(occluder)

	U_ECS_EVENT_BUS.publish(U_ECS_EVENT_NAMES.EVENT_SILHOUETTE_UPDATE_REQUEST, {
		"entity_id": entity_id,
		"occluders": safe_occluders,
		"enabled": enabled,
	})

func _resolve_follow_target_for_vcam(vcam: Node) -> Node3D:
	if vcam == null or not is_instance_valid(vcam):
		return null
	if not vcam.has_method("get_follow_target"):
		return null
	var follow_target_variant: Variant = vcam.call("get_follow_target")
	if follow_target_variant is Node3D:
		var follow_target := follow_target_variant as Node3D
		if follow_target != null and is_instance_valid(follow_target):
			return follow_target
	return null

func _resolve_silhouette_entity_id(vcam: Node) -> StringName:
	if vcam != null and is_instance_valid(vcam) and "follow_target_entity_id" in vcam:
		var entity_id_variant: Variant = vcam.get("follow_target_entity_id")
		if entity_id_variant is StringName:
			var entity_id := entity_id_variant as StringName
			if entity_id != StringName(""):
				return entity_id
		var raw_id: String = str(entity_id_variant)
		if not raw_id.is_empty():
			return StringName(raw_id)
	return _resolve_player_entity_id()

func _resolve_player_entity_id() -> StringName:
	var store := _resolve_state_store()
	if store == null:
		return StringName("")
	var state: Dictionary = store.get_state()
	var gameplay_variant: Variant = state.get("gameplay", {})
	if not (gameplay_variant is Dictionary):
		return StringName("")
	var gameplay := gameplay_variant as Dictionary
	var player_entity_variant: Variant = gameplay.get("player_entity_id", "")
	var player_entity_text: String = str(player_entity_variant)
	if player_entity_text.is_empty():
		return StringName("")
	return StringName(player_entity_text)

func _queue_startup_blend_if_needed(next_vcam_id: StringName, previous_vcam_id: StringName) -> void:
	_clear_startup_blend_runtime()
	_startup_blend_pending_vcam_id = StringName("")
	if next_vcam_id == StringName(""):
		return
	# Startup blend is only applied for first activation in a scene.
	if previous_vcam_id == StringName(""):
		_startup_blend_pending_vcam_id = next_vcam_id

func _try_startup_blend_if_pending(vcam_id: StringName, camera_mgr: I_CAMERA_MANAGER) -> void:
	if vcam_id == StringName("") or camera_mgr == null:
		return
	if _startup_blend_active:
		return
	if _startup_blend_pending_vcam_id != vcam_id:
		return
	var settings: Dictionary = _resolve_startup_blend_settings(vcam_id)
	var duration_sec: float = float(settings.get("duration_sec", 0.0))
	if duration_sec <= 0.0:
		_startup_blend_pending_vcam_id = StringName("")
		return
	var main_camera: Camera3D = camera_mgr.get_main_camera()
	if main_camera == null or not is_instance_valid(main_camera):
		return
	_startup_blend_active = true
	_startup_blend_vcam_id = vcam_id
	_startup_blend_from_transform = main_camera.global_transform
	_startup_blend_duration_sec = duration_sec
	_startup_blend_elapsed_sec = 0.0
	_startup_blend_trans_type = int(settings.get("trans_type", int(Tween.TRANS_CUBIC)))
	_startup_blend_ease_type = int(settings.get("ease_type", int(Tween.EASE_IN_OUT)))
	_startup_blend_cut_on_distance_threshold = maxf(float(settings.get("cut_on_distance_threshold", 0.0)), 0.0)
	_startup_blend_pending_vcam_id = StringName("")

func _resolve_startup_blend_settings(vcam_id: StringName) -> Dictionary:
	var defaults := {
		"duration_sec": 0.0,
		"trans_type": int(Tween.TRANS_CUBIC),
		"ease_type": int(Tween.EASE_IN_OUT),
		"cut_on_distance_threshold": 0.0,
	}
	if vcam_id == StringName(""):
		return defaults
	var vcam := _vcams_by_id.get(vcam_id, null) as Node
	if vcam == null or not is_instance_valid(vcam):
		return defaults
	if not ("blend_hint" in vcam):
		return defaults
	var hint_variant: Variant = vcam.get("blend_hint")
	if not (hint_variant is Resource):
		return defaults
	var hint := hint_variant as Resource
	if hint.get_script() != RS_VCAM_BLEND_HINT_SCRIPT:
		return defaults
	defaults["duration_sec"] = maxf(float(hint.get("blend_duration")), 0.0)
	defaults["trans_type"] = int(hint.get("trans_type"))
	defaults["ease_type"] = int(hint.get("ease_type"))
	defaults["cut_on_distance_threshold"] = maxf(float(hint.get("cut_on_distance_threshold")), 0.0)
	return defaults

func _resolve_startup_blend_transform(vcam_id: StringName, target_transform: Transform3D) -> Transform3D:
	if not _startup_blend_active:
		return target_transform
	if _startup_blend_vcam_id != vcam_id:
		_clear_startup_blend_runtime()
		return target_transform
	var distance_to_target: float = _startup_blend_from_transform.origin.distance_to(target_transform.origin)
	if (
		_startup_blend_cut_on_distance_threshold > 0.0
		and distance_to_target > _startup_blend_cut_on_distance_threshold
	):
		_clear_startup_blend_runtime()
		return target_transform
	if _startup_blend_duration_sec <= 0.0:
		_clear_startup_blend_runtime()
		return target_transform

	var dt: float = _last_physics_delta
	if dt <= 0.0:
		dt = 1.0 / float(maxi(Engine.physics_ticks_per_second, 1))
	_startup_blend_elapsed_sec = minf(_startup_blend_elapsed_sec + dt, _startup_blend_duration_sec)
	var weight: float = _compute_startup_blend_weight(
		_startup_blend_elapsed_sec,
		_startup_blend_duration_sec,
		_startup_blend_trans_type,
		_startup_blend_ease_type
	)

	var from_basis: Basis = _startup_blend_from_transform.basis.orthonormalized()
	var to_basis: Basis = target_transform.basis.orthonormalized()
	var blended_basis: Basis = from_basis.slerp(to_basis, weight).orthonormalized()
	var blended_origin: Vector3 = _startup_blend_from_transform.origin.lerp(target_transform.origin, weight)
	var blended_transform := Transform3D(blended_basis, blended_origin)

	if _startup_blend_elapsed_sec >= _startup_blend_duration_sec:
		_clear_startup_blend_runtime()
		return target_transform
	return blended_transform

func _compute_startup_blend_weight(
	elapsed_sec: float,
	duration_sec: float,
	trans_type: int,
	ease_type: int
) -> float:
	if duration_sec <= 0.0:
		return 1.0
	var eased_value: Variant = Tween.interpolate_value(
		0.0,
		1.0,
		clampf(elapsed_sec, 0.0, duration_sec),
		duration_sec,
		trans_type,
		ease_type
	)
	if eased_value is float or eased_value is int:
		return clampf(float(eased_value), 0.0, 1.0)
	return clampf(elapsed_sec / duration_sec, 0.0, 1.0)

func _clear_startup_blend_runtime() -> void:
	_startup_blend_active = false
	_startup_blend_vcam_id = StringName("")
	_startup_blend_from_transform = Transform3D.IDENTITY
	_startup_blend_duration_sec = 0.0
	_startup_blend_elapsed_sec = 0.0
	_startup_blend_trans_type = int(Tween.TRANS_CUBIC)
	_startup_blend_ease_type = int(Tween.EASE_IN_OUT)
	_startup_blend_cut_on_distance_threshold = 0.0

func _clear_startup_blend_state() -> void:
	_startup_blend_pending_vcam_id = StringName("")
	_clear_startup_blend_runtime()

func _report_issue(message: String) -> void:
	print_verbose("M_VCamManager: %s" % message)
