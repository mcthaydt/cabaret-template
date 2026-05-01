@icon("res://assets/core/editor_icons/icn_system.svg")
extends BaseECSSystem
class_name S_WallCutoutSystem

const I_CAMERA_MANAGER := preload("res://scripts/core/interfaces/i_camera_manager.gd")
const I_StateStore := preload("res://scripts/core/interfaces/i_state_store.gd")
const U_VCAM_SELECTORS := preload("res://scripts/core/state/selectors/u_vcam_selectors.gd")
const U_ENTITY_SELECTORS := preload("res://scripts/core/state/selectors/u_entity_selectors.gd")
const U_DEBUG_LOG_THROTTLE := preload("res://scripts/core/utils/debug/u_debug_log_throttle.gd")
const RS_WALL_CUTOUT_CONFIG_SCRIPT := preload("res://scripts/core/resources/ecs/rs_wall_cutout_config.gd")
const DEFAULT_WALL_CUTOUT_CONFIG := preload("res://resources/core/base_settings/gameplay/cfg_wall_cutout_config_default.tres")
const DEFAULT_WALL_CUTOUT_MATERIAL := preload("res://assets/core/materials/mat_wall_cutout.tres")

const PARAM_PLAYER_POS := &"wall_cutout_player_pos"
const PARAM_DISC_RADIUS := &"wall_cutout_disc_radius"
const PARAM_DISC_FALLOFF := &"wall_cutout_disc_falloff"
const PARAM_DISC_MIN_ALPHA := &"wall_cutout_disc_min_alpha"
const DEBUG_KEY_TICK := &"tick"
const DEBUG_PLAYER_VISUAL_HEIGHT_METERS := 1.6

# Far-off position used to disable the cutout when the camera is not in orbit
# mode. The shader projects this through the view+projection matrices and the
# resulting screen position will be far outside any reasonable disc radius, so
# every fragment passes through opaque.
const DISABLED_SENTINEL := Vector3(1.0e6, 1.0e6, 1.0e6)

@export var camera_manager: I_CAMERA_MANAGER = null
@export var state_store: I_StateStore = null
@export var wall_cutout_config: Resource = null
## The shared ShaderMaterial that walls use. The system pushes per-frame uniform
## values (player position, disc radii, alpha) onto this material so every wall
## referencing it sees the same values. Defaults to mat_wall_cutout.tres.
@export var wall_cutout_material: ShaderMaterial = null
@export var debug_wall_cutout_logging: bool = false
@export_range(0.05, 5.0, 0.05) var debug_log_interval_sec: float = 0.25

# Test seam: an object exposing `set_param(name, value)`. Defaults to a thin
# wrapper around the shared ShaderMaterial. Tests inject a stub to observe
# pushes without needing a real material.
var shader_writer: Variant = null

var _camera_manager: I_CAMERA_MANAGER = null
var _state_store: I_StateStore = null
var _debug_log_throttle: Variant = U_DEBUG_LOG_THROTTLE.new()


func _init() -> void:
	execution_priority = 110


func _resolve_shader_writer() -> Variant:
	if shader_writer != null:
		return shader_writer
	var material: ShaderMaterial = wall_cutout_material
	if material == null:
		material = DEFAULT_WALL_CUTOUT_MATERIAL
	shader_writer = _MaterialShaderWriter.new(material)
	return shader_writer


class _MaterialShaderWriter extends RefCounted:
	var _material: ShaderMaterial

	func _init(material: ShaderMaterial) -> void:
		_material = material

	func set_param(param_name: StringName, value: Variant) -> void:
		if _material == null:
			return
		_material.set_shader_parameter(param_name, value)


func process_tick(delta: float) -> void:
	_debug_log_throttle.tick(delta)
	var config_values: Dictionary = _resolve_config_values()

	var state: Dictionary = _get_state()
	if not _is_orbit_mode(state):
		_push_disc_params(config_values)
		_push_player_position(DISABLED_SENTINEL)
		_debug_log_status("disabled: non-orbit mode", DISABLED_SENTINEL, DISABLED_SENTINEL, config_values, state)
		return

	var player_pos_data: Dictionary = _resolve_player_position_from_state(state)
	if player_pos_data.is_empty():
		_push_disc_params(config_values)
		_push_player_position(DISABLED_SENTINEL)
		_debug_log_status("disabled: player position missing", DISABLED_SENTINEL, DISABLED_SENTINEL, config_values, state)
		return
	var player_position: Vector3 = player_pos_data["position"] as Vector3
	var cutout_center: Vector3 = _resolve_cutout_center_position(player_position, config_values)
	var adjusted_values: Dictionary = _resolve_runtime_disc_params(config_values, player_position)
	_push_disc_params(adjusted_values)
	_push_player_position(cutout_center)
	_debug_log_status("active", player_position, cutout_center, adjusted_values, state)


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
		"disc_max_radius": 0.32,
		"disc_falloff": 0.05,
		"disc_center_height_offset": 0.85,
		"disc_player_height_meters": DEBUG_PLAYER_VISUAL_HEIGHT_METERS,
		"disc_target_height_coverage": 1.2,
		"disc_min_alpha": 0.18,
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
		"disc_max_radius": clampf(float(config_resource.get("disc_max_radius")), 0.0, 1.0),
		"disc_falloff": maxf(float(config_resource.get("disc_falloff")), 0.0),
		"disc_center_height_offset": maxf(float(config_resource.get("disc_center_height_offset")), 0.0),
		"disc_player_height_meters": maxf(float(config_resource.get("disc_player_height_meters")), 0.0),
		"disc_target_height_coverage": maxf(float(config_resource.get("disc_target_height_coverage")), 0.0),
		"disc_min_alpha": clampf(float(config_resource.get("disc_min_alpha")), 0.0, 1.0),
	}


# --- Runtime parameter helpers ---

func _resolve_cutout_center_position(player_position: Vector3, config_values: Dictionary) -> Vector3:
	var center_height_offset: float = float(config_values.get("disc_center_height_offset", 0.0))
	return player_position + Vector3.UP * center_height_offset


func _resolve_runtime_disc_params(config_values: Dictionary, player_position: Vector3) -> Dictionary:
	var values := config_values.duplicate()
	var camera: Camera3D = _resolve_active_camera()
	var estimated_height_px: float = _estimate_player_screen_height_px(
		camera,
		player_position,
		float(config_values.get("disc_player_height_meters", DEBUG_PLAYER_VISUAL_HEIGHT_METERS))
	)
	var viewport_height: float = _resolve_camera_viewport_height(camera)
	values["disc_radius"] = _resolve_disc_radius_for_estimated_height_px(
		float(config_values.get("disc_radius", 0.12)),
		viewport_height,
		estimated_height_px,
		float(config_values.get("disc_target_height_coverage", 1.0)),
		float(config_values.get("disc_max_radius", 1.0))
	)
	return values


func _resolve_disc_radius_for_estimated_height_px(
	base_radius: float,
	viewport_height: float,
	estimated_height_px: float,
	target_height_coverage: float,
	max_radius: float
) -> float:
	var clamped_base: float = clampf(base_radius, 0.0, 1.0)
	var resolved_max: float = clampf(maxf(max_radius, clamped_base), 0.0, 1.0)
	if viewport_height <= 0.0 or estimated_height_px <= 0.0 or target_height_coverage <= 0.0:
		return clampf(clamped_base, 0.0, resolved_max)
	var dynamic_radius: float = (estimated_height_px * target_height_coverage * 0.5) / viewport_height
	return clampf(maxf(clamped_base, dynamic_radius), 0.0, resolved_max)


func _estimate_player_screen_height_px(
	camera: Camera3D,
	player_position: Vector3,
	player_height_meters: float
) -> float:
	if camera == null or not is_instance_valid(camera):
		return 0.0
	if player_height_meters <= 0.0:
		return 0.0
	if camera.is_position_behind(player_position):
		return 0.0
	var player_top := player_position + Vector3.UP * player_height_meters
	if camera.is_position_behind(player_top):
		return 0.0
	return camera.unproject_position(player_position).distance_to(camera.unproject_position(player_top))


func _resolve_camera_viewport_height(camera: Camera3D) -> float:
	if camera == null or not is_instance_valid(camera):
		return 0.0
	var viewport := camera.get_viewport()
	if viewport == null:
		return 0.0
	return viewport.get_visible_rect().size.y


# --- Global shader parameter helpers ---

func _push_disc_params(values: Dictionary) -> void:
	var writer: Variant = _resolve_shader_writer()
	writer.set_param(PARAM_DISC_RADIUS, values["disc_radius"])
	writer.set_param(PARAM_DISC_FALLOFF, values["disc_falloff"])
	writer.set_param(PARAM_DISC_MIN_ALPHA, values["disc_min_alpha"])


func _push_player_position(pos: Vector3) -> void:
	_resolve_shader_writer().set_param(PARAM_PLAYER_POS, pos)


# --- Diagnostic logging ---

func _debug_log_status(
	status: String,
	player_position: Vector3,
	cutout_center: Vector3,
	config_values: Dictionary,
	state: Dictionary
) -> void:
	if not debug_wall_cutout_logging:
		return
	if not _debug_log_throttle.consume_budget(DEBUG_KEY_TICK, maxf(debug_log_interval_sec, 0.05)):
		return

	var camera: Camera3D = _resolve_active_camera()
	var viewport_size := Vector2.ZERO
	var cutout_screen := Vector2.ZERO
	var player_view_z := INF
	var camera_player_distance := INF
	var origin_behind_camera := false
	var hole_radius_px := 0.0
	var estimated_player_height_px := 0.0
	var hole_to_height_ratio := 0.0

	if camera != null and is_instance_valid(camera):
		var viewport := camera.get_viewport()
		if viewport != null:
			viewport_size = viewport.get_visible_rect().size
		if viewport_size.y > 0.0:
			hole_radius_px = float(config_values.get("disc_radius", 0.0)) * viewport_size.y
		origin_behind_camera = camera.is_position_behind(cutout_center)
		if not origin_behind_camera:
			cutout_screen = camera.unproject_position(cutout_center)
		estimated_player_height_px = _estimate_player_screen_height_px(
			camera,
			player_position,
			float(config_values.get("disc_player_height_meters", DEBUG_PLAYER_VISUAL_HEIGHT_METERS))
		)
		if estimated_player_height_px > 0.0:
			hole_to_height_ratio = (hole_radius_px * 2.0) / estimated_player_height_px
		var view_player: Vector3 = camera.global_transform.affine_inverse() * player_position
		player_view_z = view_player.z
		camera_player_distance = camera.global_position.distance_to(player_position)

	var mode: String = U_VCAM_SELECTORS.get_active_mode(state) if not state.is_empty() else ""
	print(
		"[WallCutoutDebug] status=%s mode=%s player_pos=%s cutout_center=%s radius=%.3f falloff=%.3f min_alpha=%.3f viewport=%s hole_radius_px=%.1f cutout_screen_px=%s est_player_height_px=%.1f hole_diameter_to_est_height=%.2f camera_player_dist=%.3f player_view_z=%.3f behind_camera=%s camera=%s" % [
			status,
			mode,
			str(player_position),
			str(cutout_center),
			float(config_values.get("disc_radius", 0.0)),
			float(config_values.get("disc_falloff", 0.0)),
			float(config_values.get("disc_min_alpha", 0.0)),
			str(viewport_size),
			hole_radius_px,
			str(cutout_screen),
			estimated_player_height_px,
			hole_to_height_ratio,
			camera_player_distance,
			player_view_z,
			str(origin_behind_camera),
			_debug_describe_camera(camera),
		]
	)


func _resolve_active_camera() -> Camera3D:
	var manager: I_CAMERA_MANAGER = _resolve_camera_manager()
	if manager != null:
		var main_camera: Camera3D = manager.get_main_camera()
		if main_camera != null and is_instance_valid(main_camera):
			return main_camera
	var viewport := get_viewport()
	if viewport == null:
		return null
	return viewport.get_camera_3d()


func _debug_describe_camera(camera: Camera3D) -> String:
	if camera == null or not is_instance_valid(camera):
		return "<none>"
	if camera.is_inside_tree():
		return str(camera.get_path())
	return String(camera.name)
