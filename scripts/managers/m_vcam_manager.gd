@icon("res://assets/editor_icons/icn_manager.svg")
extends "res://scripts/interfaces/i_vcam_manager.gd"
class_name M_VCamManager

const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_VCAM_ACTIONS := preload("res://scripts/state/actions/u_vcam_actions.gd")
const U_VFX_SELECTORS := preload("res://scripts/state/selectors/u_vfx_selectors.gd")
const U_ENTITY_SELECTORS := preload("res://scripts/state/selectors/u_entity_selectors.gd")
const U_ECS_EVENT_BUS := preload("res://scripts/events/ecs/u_ecs_event_bus.gd")
const U_ECS_EVENT_NAMES := preload("res://scripts/events/ecs/u_ecs_event_names.gd")
const I_CAMERA_MANAGER := preload("res://scripts/interfaces/i_camera_manager.gd")
const I_ECS_MANAGER := preload("res://scripts/interfaces/i_ecs_manager.gd")
const RS_VCAM_BLEND_HINT_SCRIPT := preload("res://scripts/resources/display/vcam/rs_vcam_blend_hint.gd")
const U_VCAM_COLLISION_DETECTOR := preload("res://scripts/managers/helpers/u_vcam_collision_detector.gd")
const U_VCAM_BLEND_MANAGER := preload("res://scripts/managers/helpers/u_vcam_blend_manager.gd")
const C_ROOM_FADE_GROUP_COMPONENT_SCRIPT := preload(
	"res://scripts/ecs/components/c_room_fade_group_component.gd"
)

const VCAM_OCCLUSION_COLLISION_MASK: int = 1 << 5
const DEBUG_OCCLUSION_MAX_PATHS: int = 8
const OCCLUSION_DETECT_INTERVAL_FRAMES: int = 2
const OCCLUSION_POSITION_THRESHOLD: float = 0.05

@export var state_store: I_StateStore = null
@export var camera_manager: I_CAMERA_MANAGER = null
@export var ecs_manager: I_ECS_MANAGER = null
@export var debug_occlusion_logging: bool = false
@export var debug_occlusion_log_interval_frames: int = 1
@export var debug_occlusion_target_filter: StringName = StringName("")

var _state_store: I_StateStore = null
var _camera_manager: I_CAMERA_MANAGER = null
var _ecs_manager: I_ECS_MANAGER = null

var _vcams_by_id: Dictionary = {}
var _registered_vcams: Dictionary = {}
var _submitted_results: Dictionary = {}

var _active_vcam_id: StringName = StringName("")
var _previous_vcam_id: StringName = StringName("")
var _explicit_vcam_id: StringName = StringName("")
var _pending_blend_duration_override: float = -1.0
var _blend_manager: Variant = U_VCAM_BLEND_MANAGER.new()
var _blend_trans_type: int = int(Tween.TRANS_LINEAR)  # Compatibility test probe
var _blend_ease_type: int = int(Tween.EASE_IN_OUT)  # Compatibility test probe
var _last_applied_frame: int = -1
var _last_valid_applied_result: Dictionary = {}
var _last_physics_delta: float = 0.0
var _occluder_results_cache: Array = []
var _silhouette_clear_published: bool = false
var _occlusion_frame_counter: int = 0
var _last_occlusion_camera_pos: Vector3 = Vector3.ZERO
var _last_occlusion_target_pos: Vector3 = Vector3.ZERO
var _is_mobile: bool = false

func _ready() -> void:
	var service_name := StringName("vcam_manager")
	var existing := U_SERVICE_LOCATOR.try_get_service(service_name)
	if existing != self:
		U_SERVICE_LOCATOR.register(service_name, self)
	_is_mobile = OS.has_feature("mobile")
	_state_store = _resolve_state_store()
	_camera_manager = _resolve_camera_manager()
	_ecs_manager = _resolve_ecs_manager()
	set_physics_process(true)
	_refresh_active_selection()

func _physics_process(_delta: float) -> void:
	_last_physics_delta = maxf(_delta, 0.0)
	_refresh_active_selection()
	_advance_live_blend(_last_physics_delta)
	_try_apply_for_current_frame()

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
		if _blend_manager.is_active():
			_record_recovery("blend_both_invalid")
		_clear_runtime_state()
		return
	if _blend_manager.is_active():
		return
	_refresh_active_selection()

func set_active_vcam(vcam_id: StringName, blend_duration: float = -1.0) -> void:
	if vcam_id == StringName(""):
		_pending_blend_duration_override = maxf(blend_duration, 0.0) if blend_duration >= 0.0 else -1.0
		_explicit_vcam_id = StringName("")
		_refresh_active_selection()
		_pending_blend_duration_override = -1.0
		return

	if not _vcams_by_id.has(vcam_id):
		_report_issue("set_active_vcam ignored unknown vcam_id '%s'" % String(vcam_id))
		return

	_pending_blend_duration_override = maxf(blend_duration, 0.0) if blend_duration >= 0.0 else -1.0
	_explicit_vcam_id = vcam_id
	_refresh_active_selection()
	_pending_blend_duration_override = -1.0

func get_active_vcam_id() -> StringName:
	return _active_vcam_id

func get_previous_vcam_id() -> StringName:
	if _blend_manager.is_active() and _blend_manager.has_from_snapshot_result():
		return StringName("")
	return _previous_vcam_id

func submit_evaluated_camera(vcam_id: StringName, result: Dictionary) -> void:
	if vcam_id == StringName(""):
		return
	if result == null:
		return
	_submitted_results[vcam_id] = {
		"result": result.duplicate(true),
		"frame": Engine.get_physics_frames(),
	}
	_try_apply_for_current_frame()

func get_blend_progress() -> float:
	return _blend_manager.get_progress()

func is_blending() -> bool:
	return _blend_manager.is_active()

func get_active_vcam() -> Node:
	return _vcams_by_id.get(_active_vcam_id, null) as Node

func get_vcam(vcam_id: StringName) -> Node:
	return _vcams_by_id.get(vcam_id, null) as Node

func _refresh_active_selection() -> void:
	_prune_invalid_registrations()
	_recover_invalid_live_blend_members()
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
	var blend_duration_override: float = _pending_blend_duration_override
	_pending_blend_duration_override = -1.0
	_active_vcam_id = next_vcam_id
	_previous_vcam_id = previous_vcam_id
	_last_applied_frame = -1
	_queue_startup_blend_if_needed(next_vcam_id, previous_vcam_id)

	var active_mode := _get_mode_name_for_vcam(next_vcam_id)
	_dispatch_active_runtime(next_vcam_id, active_mode)
	_configure_live_blend_transition(previous_vcam_id, next_vcam_id, blend_duration_override)
	_publish_active_changed(next_vcam_id, previous_vcam_id, active_mode)

func _configure_live_blend_transition(
	from_vcam_id: StringName,
	to_vcam_id: StringName,
	duration_override: float
) -> void:
	if from_vcam_id == to_vcam_id:
		return
	if to_vcam_id == StringName("") or from_vcam_id == StringName(""):
		_blend_manager.configure_transition(from_vcam_id, to_vcam_id, {})
		_sync_blend_debug_cache()
		return
	if not _vcams_by_id.has(from_vcam_id):
		_blend_manager.configure_transition(from_vcam_id, StringName(""), {})
		_sync_blend_debug_cache()
		return
	var settings: Dictionary = _resolve_live_blend_settings(to_vcam_id, duration_override)

	var reentrant_snapshot: Dictionary = {}
	if _blend_manager.is_active():
		reentrant_snapshot = _capture_reentrant_blend_snapshot()

	var configure_result: Dictionary = _blend_manager.configure_transition(
		from_vcam_id,
		to_vcam_id,
		settings,
		reentrant_snapshot
	)
	_sync_blend_debug_cache()
	var status: String = str(configure_result.get("status", ""))
	if status == "started":
		_dispatch_blend_started(from_vcam_id)
		_publish_blend_started(from_vcam_id, to_vcam_id, float(configure_result.get("duration", 0.0)))
		return
	if status == "completed":
		_dispatch_blend_complete()
		_publish_blend_completed(to_vcam_id)

func _resolve_live_blend_settings(vcam_id: StringName, duration_override: float) -> Dictionary:
	var settings: Dictionary = _resolve_startup_blend_settings(vcam_id)
	var duration_sec: float = maxf(float(settings.get("duration_sec", 0.0)), 0.0)
	if duration_override >= 0.0:
		duration_sec = maxf(duration_override, 0.0)
	settings["duration_sec"] = duration_sec
	return settings

func _capture_reentrant_blend_snapshot() -> Dictionary:
	if not _last_valid_applied_result.is_empty():
		return _last_valid_applied_result.duplicate(true)

	var current_frame: int = Engine.get_physics_frames()
	var blended_result: Dictionary = _resolve_blend_result_for_frame(current_frame)
	if not blended_result.is_empty():
		return blended_result.duplicate(true)

	var active_result: Dictionary = _get_submitted_result_for_frame(_active_vcam_id, current_frame)
	if not active_result.is_empty():
		return active_result.duplicate(true)
	return {}

func _advance_live_blend(delta: float) -> void:
	var advance_result: Dictionary = _blend_manager.advance(delta)
	_sync_blend_debug_cache()
	var status: String = str(advance_result.get("status", ""))
	if status == "":
		return
	if status == "progress":
		_dispatch_blend_progress(float(advance_result.get("progress", _blend_manager.get_progress())))
		return
	if status == "completed":
		_dispatch_blend_complete()
		_publish_blend_completed(_active_vcam_id)

func _recover_invalid_live_blend_members() -> void:
	if not _blend_manager.is_active():
		return

	var has_to_vcam: bool = _active_vcam_id != StringName("") and _vcams_by_id.has(_active_vcam_id)
	var has_from_vcam: bool = true
	if not _blend_manager.has_from_snapshot_result():
		has_from_vcam = _previous_vcam_id != StringName("") and _vcams_by_id.has(_previous_vcam_id)

	var recovery_result: Dictionary = _blend_manager.recover_invalid_members(has_to_vcam, has_from_vcam)
	_sync_blend_debug_cache()
	if recovery_result.is_empty():
		return

	_record_recovery(str(recovery_result.get("reason", "")))
	_dispatch_blend_complete()
	if bool(recovery_result.get("publish_completed_event", false)):
		_publish_blend_completed(_active_vcam_id)

func _sync_blend_debug_cache() -> void:
	_blend_trans_type = int(_blend_manager.get_transition_type())
	_blend_ease_type = int(_blend_manager.get_ease_type())

func _dispatch_active_runtime(vcam_id: StringName, mode_name: String) -> void:
	var store := _resolve_state_store()
	if store == null:
		return
	store.dispatch(U_VCAM_ACTIONS.set_active_runtime(vcam_id, mode_name))

func _dispatch_blend_started(previous_vcam_id: StringName) -> void:
	var store := _resolve_state_store()
	if store == null:
		return
	store.dispatch(U_VCAM_ACTIONS.start_blend(previous_vcam_id))

func _dispatch_blend_progress(progress: float) -> void:
	var store := _resolve_state_store()
	if store == null:
		return
	store.dispatch(U_VCAM_ACTIONS.update_blend(progress))

func _dispatch_blend_complete() -> void:
	var store := _resolve_state_store()
	if store == null:
		return
	store.dispatch(U_VCAM_ACTIONS.complete_blend())

func _record_recovery(reason: String) -> void:
	var store := _resolve_state_store()
	if store != null:
		store.dispatch(U_VCAM_ACTIONS.record_recovery(reason))
	U_ECS_EVENT_BUS.publish(U_ECS_EVENT_NAMES.EVENT_VCAM_RECOVERY, {
		"reason": reason,
		"vcam_id": _active_vcam_id,
		"active_vcam_id": _active_vcam_id,
		"previous_vcam_id": _previous_vcam_id,
	})

func _publish_active_changed(vcam_id: StringName, previous_vcam_id: StringName, mode_name: String) -> void:
	U_ECS_EVENT_BUS.publish(U_ECS_EVENT_NAMES.EVENT_VCAM_ACTIVE_CHANGED, {
		"vcam_id": vcam_id,
		"previous_vcam_id": previous_vcam_id,
		"mode": mode_name,
	})

func _publish_blend_started(from_vcam_id: StringName, to_vcam_id: StringName, duration: float) -> void:
	U_ECS_EVENT_BUS.publish(U_ECS_EVENT_NAMES.EVENT_VCAM_BLEND_STARTED, {
		"from_vcam_id": from_vcam_id,
		"to_vcam_id": to_vcam_id,
		"duration": duration,
	})

func _publish_blend_completed(vcam_id: StringName) -> void:
	U_ECS_EVENT_BUS.publish(U_ECS_EVENT_NAMES.EVENT_VCAM_BLEND_COMPLETED, {
		"vcam_id": vcam_id,
	})

func _clear_runtime_state() -> void:
	var previous_vcam_id := _active_vcam_id
	_clear_all_silhouettes(_resolve_player_entity_id())
	_active_vcam_id = StringName("")
	_previous_vcam_id = StringName("")
	_explicit_vcam_id = StringName("")
	_submitted_results.clear()
	_blend_manager.clear()
	_sync_blend_debug_cache()
	_last_physics_delta = 0.0
	_pending_blend_duration_override = -1.0
	_last_applied_frame = -1
	_last_valid_applied_result.clear()
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

## Resolve a display name for the given vcam mode resource (C10 migration).
##
## Lookup order:
##   1. resource_name property (set in inspector, no prefix convention required)
##   2. "mode_name" metadata (set via set_meta)
##   3. Script global_name prefix-stripping ("RS_VCamMode" → snake_case fallback)
##   4. Filename prefix-stripping ("rs_vcam_mode_" → remainder fallback)
func _resolve_mode_name(mode: Resource) -> String:
	if mode == null:
		return ""

	if not mode.resource_name.is_empty():
		return mode.resource_name

	if mode.has_meta("mode_name"):
		return str(mode.get_meta("mode_name"))

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
	_state_store = U_DependencyResolution.resolve_state_store(_state_store, state_store, self)
	return _state_store

func _resolve_camera_manager() -> I_CAMERA_MANAGER:
	_camera_manager = U_DependencyResolution.resolve(&"camera_manager", _camera_manager, camera_manager) as I_CAMERA_MANAGER
	return _camera_manager

func _resolve_ecs_manager() -> I_ECS_MANAGER:
	_ecs_manager = U_DependencyResolution.resolve(&"ecs_manager", _ecs_manager, ecs_manager) as I_ECS_MANAGER
	return _ecs_manager

func _try_apply_for_current_frame() -> void:
	if _active_vcam_id == StringName(""):
		return
	var frame_id: int = Engine.get_physics_frames()

	var camera_mgr: I_CAMERA_MANAGER = _resolve_camera_manager()
	if camera_mgr == null:
		return
	if camera_mgr.is_blend_active():
		_clear_silhouettes_for_vcam(_active_vcam_id)
		return

	var result: Dictionary = _resolve_result_for_frame(frame_id)
	if result.is_empty():
		return
	var transform_variant: Variant = result.get("transform", null)
	if not (transform_variant is Transform3D):
		return

	var target_transform := transform_variant as Transform3D
	var applied_transform: Transform3D = target_transform
	if not _blend_manager.is_active():
		_try_startup_blend_if_pending(_active_vcam_id, camera_mgr)
		applied_transform = _blend_manager.resolve_startup_transform(
			_active_vcam_id,
			target_transform,
			_last_physics_delta
		)

	camera_mgr.apply_main_camera_transform(applied_transform)
	_last_applied_frame = frame_id
	_last_valid_applied_result = result.duplicate(true)
	_publish_silhouette_update_request_for_active_vcam(_active_vcam_id, applied_transform)

func _resolve_result_for_frame(frame_id: int) -> Dictionary:
	if _active_vcam_id == StringName(""):
		return {}
	if _blend_manager.is_active():
		return _resolve_blend_result_for_frame(frame_id)
	return _get_submitted_result_for_frame(_active_vcam_id, frame_id)

func _resolve_blend_result_for_frame(frame_id: int) -> Dictionary:
	var to_result: Dictionary = _get_submitted_result_for_frame(_active_vcam_id, frame_id)
	if to_result.is_empty():
		return {}

	var from_result: Dictionary = {}
	if not _blend_manager.has_from_snapshot_result():
		if _previous_vcam_id == StringName(""):
			return to_result
		from_result = _get_submitted_result_for_frame(_previous_vcam_id, frame_id)
		if from_result.is_empty():
			return {}

	var blended_result: Dictionary = _blend_manager.resolve_blend_result(from_result, to_result)
	if _blend_manager.consume_completed_on_cut_with_publish():
		_dispatch_blend_complete()
		_publish_blend_completed(_active_vcam_id)
	return blended_result

func _get_submitted_result_for_frame(vcam_id: StringName, frame_id: int) -> Dictionary:
	if vcam_id == StringName(""):
		return {}
	var entry_variant: Variant = _submitted_results.get(vcam_id, {})
	if not (entry_variant is Dictionary):
		return {}
	var entry: Dictionary = entry_variant as Dictionary
	var submitted_frame: int = int(entry.get("frame", -1))
	if submitted_frame != frame_id:
		return {}
	var result_variant: Variant = entry.get("result", {})
	if result_variant is Dictionary:
		return result_variant as Dictionary
	return {}

func _publish_silhouette_update_request_for_active_vcam(
	vcam_id: StringName,
	camera_transform: Transform3D
) -> void:
	var vcam := _vcams_by_id.get(vcam_id, null) as Node
	var entity_id: StringName = _resolve_silhouette_entity_id(vcam)
	var follow_target: Node3D = _resolve_follow_target_for_vcam(vcam)
	var emit_debug_logs: bool = _should_emit_occlusion_debug(vcam_id, follow_target)
	var debug_context: String = _build_occlusion_debug_context(vcam_id, follow_target)

	if not _is_occlusion_silhouette_enabled():
		_debug_log_occlusion(
			emit_debug_logs,
			"%s clear reason=vfx_toggle_off entity_id=%s" % [debug_context, str(entity_id)]
		)
		_clear_all_silhouettes(entity_id)
		return

	if _blend_manager.is_active():
		_debug_log_occlusion(
			emit_debug_logs,
			"%s clear reason=blend_active entity_id=%s" % [debug_context, str(entity_id)]
		)
		_clear_all_silhouettes(entity_id)
		return

	if follow_target == null or not is_instance_valid(follow_target):
		_debug_log_occlusion(
			emit_debug_logs,
			"%s clear reason=no_follow_target entity_id=%s" % [debug_context, str(entity_id)]
		)
		_clear_all_silhouettes(entity_id)
		return

	# --- Throttle: frame-skip ---
	_occlusion_frame_counter += 1
	var cam_pos: Vector3 = camera_transform.origin
	var tgt_pos: Vector3 = follow_target.global_position
	var cam_moved: bool = _last_occlusion_camera_pos.distance_to(cam_pos) >= OCCLUSION_POSITION_THRESHOLD
	var tgt_moved: bool = _last_occlusion_target_pos.distance_to(tgt_pos) >= OCCLUSION_POSITION_THRESHOLD
	var is_interval_frame: bool = (_occlusion_frame_counter % OCCLUSION_DETECT_INTERVAL_FRAMES) == 0
	if not is_interval_frame and not cam_moved and not tgt_moved:
		return

	_last_occlusion_camera_pos = cam_pos
	_last_occlusion_target_pos = tgt_pos

	var occluders := _detect_occluders_for_silhouette(
		camera_transform,
		follow_target,
		emit_debug_logs,
		debug_context
	)
	var safe_occluders := _sanitize_occluders(occluders, emit_debug_logs, debug_context)
	_debug_log_occlusion_summary(
		emit_debug_logs,
		debug_context,
		cam_pos,
		tgt_pos,
		occluders,
		safe_occluders
	)

	_publish_silhouette_update_request(entity_id, safe_occluders, true)
	_silhouette_clear_published = false

func _detect_occluders_for_silhouette(
	camera_transform: Transform3D,
	follow_target: Node3D,
	debug_enabled: bool = false,
	debug_context: String = ""
) -> Array:
	_occluder_results_cache.clear()
	if follow_target == null or not is_instance_valid(follow_target):
		return _occluder_results_cache
	var world: World3D = follow_target.get_world_3d()
	if world == null:
		return _occluder_results_cache
	var space_state: PhysicsDirectSpaceState3D = world.direct_space_state
	if space_state == null:
		return _occluder_results_cache

	var occluders_variant: Variant = U_VCAM_COLLISION_DETECTOR.detect_occluders(
		space_state,
		camera_transform.origin,
		follow_target.global_position,
		VCAM_OCCLUSION_COLLISION_MASK,
		debug_enabled,
		debug_context
	)
	if not (occluders_variant is Array):
		return _occluder_results_cache
	for occluder_variant in occluders_variant as Array:
		_occluder_results_cache.append(occluder_variant)
	return _occluder_results_cache

func _sanitize_occluders(
	occluders: Array,
	debug_enabled: bool = false,
	debug_context: String = ""
) -> Array:
	var safe_occluders: Array = []
	for occluder_variant in occluders:
		if not (occluder_variant is GeometryInstance3D):
			_debug_log_occlusion(
				debug_enabled,
				"%s sanitize skip reason=not_geometry value=%s" % [debug_context, str(occluder_variant)]
			)
			continue
		var occluder := occluder_variant as GeometryInstance3D
		if occluder == null or not is_instance_valid(occluder):
			_debug_log_occlusion(
				debug_enabled,
				"%s sanitize skip reason=invalid_geometry value=%s" % [debug_context, str(occluder_variant)]
			)
			continue
		var room_fade_state: Dictionary = _get_occluder_room_fade_state(occluder)
		if bool(room_fade_state.get("is_faded", false)):
			_debug_log_occlusion(
				debug_enabled,
				"%s sanitize skip reason=room_faded occluder=%s alpha=%.3f room_fade=%s" % [
					debug_context,
					str(occluder.get_path()),
					float(room_fade_state.get("alpha", 1.0)),
					str(room_fade_state.get("component_path", "")),
				]
			)
			continue
		safe_occluders.append(occluder)
	return safe_occluders

func _is_occluder_room_faded(occluder: GeometryInstance3D) -> bool:
	var room_fade_state: Dictionary = _get_occluder_room_fade_state(occluder)
	return bool(room_fade_state.get("is_faded", false))

func _get_occluder_room_fade_state(occluder: GeometryInstance3D) -> Dictionary:
	var parent := occluder.get_parent()
	if parent == null:
		return {
			"is_faded": false,
		}
	for child_variant in parent.get_children():
		if child_variant == null or not is_instance_valid(child_variant):
			continue
		if not (child_variant is Node):
			continue
		var child := child_variant as Node
		if child.get_script() != C_ROOM_FADE_GROUP_COMPONENT_SCRIPT:
			continue
		var alpha: float = float(child.get("current_alpha"))
		return {
			"is_faded": alpha < 1.0,
			"alpha": alpha,
			"component_path": str(child.get_path()),
		}
	return {
		"is_faded": false,
	}

func _clear_silhouettes_for_vcam(vcam_id: StringName) -> void:
	var vcam := _vcams_by_id.get(vcam_id, null) as Node
	_clear_all_silhouettes(_resolve_silhouette_entity_id(vcam))

func _clear_all_silhouettes(entity_id: StringName) -> void:
	if _silhouette_clear_published:
		return
	_publish_silhouette_update_request(entity_id, [], false)
	_silhouette_clear_published = true
	_occlusion_frame_counter = 0
	_last_occlusion_camera_pos = Vector3.ZERO
	_last_occlusion_target_pos = Vector3.ZERO

func _is_occlusion_silhouette_enabled() -> bool:
	if _is_mobile:
		return false
	var store := _resolve_state_store()
	if store == null:
		return true
	return U_VFX_SELECTORS.is_occlusion_silhouette_enabled(store.get_state())

func _publish_silhouette_update_request(entity_id: StringName, occluders: Array, enabled: bool) -> void:
	U_ECS_EVENT_BUS.publish(U_ECS_EVENT_NAMES.EVENT_SILHOUETTE_UPDATE_REQUEST, {
		"entity_id": entity_id,
		"occluders": occluders,
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
	var player_entity_text: String = U_ENTITY_SELECTORS.get_player_entity_id(state)
	if player_entity_text.is_empty():
		return StringName("")
	return StringName(player_entity_text)

func _queue_startup_blend_if_needed(next_vcam_id: StringName, previous_vcam_id: StringName) -> void:
	_blend_manager.queue_startup_blend(next_vcam_id, previous_vcam_id)

func _try_startup_blend_if_pending(vcam_id: StringName, camera_mgr: I_CAMERA_MANAGER) -> void:
	if vcam_id == StringName("") or camera_mgr == null:
		return
	var settings: Dictionary = _resolve_startup_blend_settings(vcam_id)
	var main_camera: Camera3D = camera_mgr.get_main_camera()
	if main_camera == null or not is_instance_valid(main_camera):
		return
	_blend_manager.start_startup_blend_if_pending(
		vcam_id,
		main_camera.global_transform,
		settings
	)

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

func _should_emit_occlusion_debug(vcam_id: StringName, follow_target: Node3D = null) -> bool:
	if not debug_occlusion_logging:
		return false
	var interval_frames: int = maxi(debug_occlusion_log_interval_frames, 1)
	var current_frame: int = Engine.get_physics_frames()
	if current_frame % interval_frames != 0:
		return false
	var filter_text: String = str(debug_occlusion_target_filter)
	if filter_text.is_empty():
		return true
	if str(vcam_id) == filter_text:
		return true
	if follow_target == null or not is_instance_valid(follow_target):
		return false
	var target_name: String = follow_target.name
	var target_path: String = str(follow_target.get_path())
	if target_name == filter_text:
		return true
	return target_path.contains(filter_text)

func _build_occlusion_debug_context(vcam_id: StringName, follow_target: Node3D) -> String:
	var target_path: String = "<none>"
	if follow_target != null and is_instance_valid(follow_target):
		target_path = str(follow_target.get_path())
	return "frame=%d vcam=%s target=%s" % [
		Engine.get_physics_frames(),
		str(vcam_id),
		target_path,
	]

func _debug_log_occlusion_summary(
	enabled: bool,
	context: String,
	from: Vector3,
	to: Vector3,
	raw_occluders: Array,
	safe_occluders: Array
) -> void:
	if not enabled:
		return
	_debug_log_occlusion(
		true,
		"%s ray_mode=single_center_ray from=%s to=%s distance=%.3f raw_count=%d safe_count=%d" % [
			context,
			str(from),
			str(to),
			from.distance_to(to),
			raw_occluders.size(),
			safe_occluders.size(),
		]
	)
	_debug_log_occlusion(
		true,
		"%s raw_paths=%s" % [context, str(_collect_occluder_paths(raw_occluders))]
	)
	_debug_log_occlusion(
		true,
		"%s safe_paths=%s" % [context, str(_collect_occluder_paths(safe_occluders))]
	)

func _collect_occluder_paths(occluders: Array) -> Array[String]:
	var paths: Array[String] = []
	for occluder_variant in occluders:
		if paths.size() >= DEBUG_OCCLUSION_MAX_PATHS:
			break
		if not (occluder_variant is GeometryInstance3D):
			continue
		var occluder := occluder_variant as GeometryInstance3D
		if occluder == null or not is_instance_valid(occluder):
			continue
		paths.append(str(occluder.get_path()))
	return paths

func _debug_log_occlusion(enabled: bool, message: String) -> void:
	if not enabled:
		return
	print("[VCAM_OCCLUSION][VCamManager] %s" % message)

func _report_issue(message: String) -> void:
	print_verbose("M_VCamManager: %s" % message)
