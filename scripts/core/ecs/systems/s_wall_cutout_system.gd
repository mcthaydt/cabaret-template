@icon("res://assets/core/editor_icons/icn_system.svg")
extends BaseECSSystem
class_name S_WallCutoutSystem

const I_CAMERA_MANAGER := preload("res://scripts/core/interfaces/i_camera_manager.gd")
const I_StateStore := preload("res://scripts/core/interfaces/i_state_store.gd")
const U_VCAM_SELECTORS := preload("res://scripts/core/state/selectors/u_vcam_selectors.gd")
const U_ENTITY_SELECTORS := preload("res://scripts/core/state/selectors/u_entity_selectors.gd")
const RS_WALL_CUTOUT_CONFIG_SCRIPT := preload("res://scripts/core/resources/ecs/rs_wall_cutout_config.gd")
const DEFAULT_WALL_CUTOUT_CONFIG := preload("res://resources/core/base_settings/gameplay/cfg_wall_cutout_config_default.tres")

const PARAM_PLAYER_POS := &"wall_cutout_player_pos"
const PARAM_CAMERA_POS := &"wall_cutout_camera_pos"
const PARAM_NEAR_RADIUS := &"wall_cutout_near_radius"
const PARAM_FAR_RADIUS := &"wall_cutout_far_radius"
const PARAM_FALLOFF := &"wall_cutout_falloff"
const PARAM_MIN_ALPHA := &"wall_cutout_min_alpha"

# Far-off position used to disable the cutout when the camera is not in orbit mode.
const DISABLED_SENTINEL := Vector3(1.0e6, 1.0e6, 1.0e6)

@export var camera_manager: I_CAMERA_MANAGER = null
@export var state_store: I_StateStore = null
@export var wall_cutout_config: Resource = null

# Test seam: an object exposing `set_param(name, value)`. Defaults to a thin
# RenderingServer wrapper. Tests inject a stub to observe pushes without depending
# on headless RenderingServer behavior.
var shader_writer: Variant = null

var _camera_manager: I_CAMERA_MANAGER = null
var _state_store: I_StateStore = null


func _init() -> void:
	execution_priority = 110


func _resolve_shader_writer() -> Variant:
	if shader_writer != null:
		return shader_writer
	shader_writer = _RenderingServerShaderWriter.new()
	return shader_writer


class _RenderingServerShaderWriter extends RefCounted:
	func set_param(param_name: StringName, value: Variant) -> void:
		RenderingServer.global_shader_parameter_set(param_name, value)


func process_tick(_delta: float) -> void:
	var config_values: Dictionary = _resolve_config_values()
	_push_cone_params(config_values)

	var camera: Camera3D = _resolve_active_camera()
	if camera == null:
		_push_player_position(DISABLED_SENTINEL)
		return
	var camera_pos: Vector3 = camera.global_transform.origin
	_push_camera_position(camera_pos)

	var state: Dictionary = _get_state()
	if not _is_orbit_mode(state):
		_push_player_position(DISABLED_SENTINEL)
		return

	var player_pos_data: Dictionary = _resolve_player_position_from_state(state)
	if player_pos_data.is_empty():
		_push_player_position(DISABLED_SENTINEL)
		return
	_push_player_position(player_pos_data["position"])


# --- Dependency resolution ---

func _resolve_camera_manager() -> I_CAMERA_MANAGER:
	_camera_manager = U_DependencyResolution.resolve(&"camera_manager", _camera_manager, camera_manager) as I_CAMERA_MANAGER
	return _camera_manager


func _resolve_state_store() -> I_StateStore:
	_state_store = U_DependencyResolution.resolve_state_store(_state_store, state_store, self) as I_StateStore
	return _state_store


func _resolve_active_camera() -> Camera3D:
	var manager: I_CAMERA_MANAGER = _resolve_camera_manager()
	if manager != null:
		var manager_camera: Camera3D = manager.get_main_camera()
		if manager_camera != null and is_instance_valid(manager_camera):
			return manager_camera
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return null
	var viewport_camera: Camera3D = viewport.get_camera_3d()
	if viewport_camera == null or not is_instance_valid(viewport_camera):
		return null
	return viewport_camera


func _get_state() -> Dictionary:
	var state: Dictionary = get_frame_state_snapshot()
	if state.is_empty():
		var store: I_StateStore = _resolve_state_store()
		if store != null:
			state = store.get_state()
	return state


func _is_orbit_mode(state: Dictionary) -> bool:
	if state.is_empty():
		return false
	return U_VCAM_SELECTORS.get_active_mode(state).to_lower() == "orbit"


func _resolve_player_position_from_state(state: Dictionary) -> Dictionary:
	if state.is_empty():
		return {}
	var player_id: String = U_ENTITY_SELECTORS.get_player_entity_id(state)
	if player_id.is_empty():
		return {}
	var entity: Dictionary = U_ENTITY_SELECTORS.get_entity(state, player_id)
	if entity.is_empty():
		return {}
	var position_variant: Variant = entity.get("position", null)
	if position_variant is Vector3:
		return {"position": position_variant as Vector3}
	return {}


func _resolve_config_values() -> Dictionary:
	var defaults := {
		"cone_near_radius": 0.5,
		"cone_far_radius": 2.5,
		"cone_falloff": 0.5,
		"cone_min_alpha": 0.0,
	}
	var config_variant: Variant = wall_cutout_config
	if config_variant == null:
		config_variant = DEFAULT_WALL_CUTOUT_CONFIG
	if config_variant == null or not (config_variant is Resource):
		return defaults

	var config_resource: Resource = config_variant as Resource
	if config_resource.get_script() != RS_WALL_CUTOUT_CONFIG_SCRIPT:
		return defaults

	return {
		"cone_near_radius": maxf(float(config_resource.get("cone_near_radius")), 0.0),
		"cone_far_radius": maxf(float(config_resource.get("cone_far_radius")), 0.0),
		"cone_falloff": maxf(float(config_resource.get("cone_falloff")), 0.0),
		"cone_min_alpha": clampf(float(config_resource.get("cone_min_alpha")), 0.0, 1.0),
	}


# --- Global shader parameter helpers ---

func _push_cone_params(values: Dictionary) -> void:
	var writer: Variant = _resolve_shader_writer()
	writer.set_param(PARAM_NEAR_RADIUS, values["cone_near_radius"])
	writer.set_param(PARAM_FAR_RADIUS, values["cone_far_radius"])
	writer.set_param(PARAM_FALLOFF, values["cone_falloff"])
	writer.set_param(PARAM_MIN_ALPHA, values["cone_min_alpha"])


func _push_camera_position(pos: Vector3) -> void:
	_resolve_shader_writer().set_param(PARAM_CAMERA_POS, pos)


func _push_player_position(pos: Vector3) -> void:
	_resolve_shader_writer().set_param(PARAM_PLAYER_POS, pos)
