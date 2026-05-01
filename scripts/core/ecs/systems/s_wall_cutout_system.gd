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
const PARAM_DISC_RADIUS := &"wall_cutout_disc_radius"
const PARAM_DISC_FALLOFF := &"wall_cutout_disc_falloff"
const PARAM_DISC_MIN_ALPHA := &"wall_cutout_disc_min_alpha"

# Far-off position used to disable the cutout when the camera is not in orbit
# mode. The shader projects this through the view+projection matrices and the
# resulting screen position will be far outside any reasonable disc radius, so
# every fragment passes through opaque.
const DISABLED_SENTINEL := Vector3(1.0e6, 1.0e6, 1.0e6)

@export var camera_manager: I_CAMERA_MANAGER = null
@export var state_store: I_StateStore = null
@export var wall_cutout_config: Resource = null

# Test seam: an object exposing `set_param(name, value)`. Defaults to a thin
# RenderingServer wrapper. Tests inject a stub to observe pushes without
# depending on headless RenderingServer behavior for global shader parameters.
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
	_push_disc_params(config_values)

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
		"disc_radius": 0.12,
		"disc_falloff": 0.05,
		"disc_min_alpha": 0.0,
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
		"disc_radius": clampf(float(config_resource.get("disc_radius")), 0.0, 1.0),
		"disc_falloff": maxf(float(config_resource.get("disc_falloff")), 0.0),
		"disc_min_alpha": clampf(float(config_resource.get("disc_min_alpha")), 0.0, 1.0),
	}


# --- Global shader parameter helpers ---

func _push_disc_params(values: Dictionary) -> void:
	var writer: Variant = _resolve_shader_writer()
	writer.set_param(PARAM_DISC_RADIUS, values["disc_radius"])
	writer.set_param(PARAM_DISC_FALLOFF, values["disc_falloff"])
	writer.set_param(PARAM_DISC_MIN_ALPHA, values["disc_min_alpha"])


func _push_player_position(pos: Vector3) -> void:
	_resolve_shader_writer().set_param(PARAM_PLAYER_POS, pos)
