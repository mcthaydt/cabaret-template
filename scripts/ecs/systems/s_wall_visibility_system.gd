@icon("res://assets/editor_icons/icn_system.svg")
extends BaseECSSystem
class_name S_WallVisibilitySystem

const U_VCAM_SELECTORS := preload("res://scripts/state/selectors/u_vcam_selectors.gd")
const I_CAMERA_MANAGER := preload("res://scripts/interfaces/i_camera_manager.gd")
const I_STATE_STORE := preload("res://scripts/interfaces/i_state_store.gd")
const RS_ROOM_FADE_SETTINGS_SCRIPT := preload("res://scripts/resources/display/vcam/rs_room_fade_settings.gd")
const U_WALL_VISIBILITY_MATERIAL_APPLIER := preload("res://scripts/utils/lighting/u_wall_visibility_material_applier.gd")
const U_ENTITY_SELECTORS := preload("res://scripts/state/selectors/u_entity_selectors.gd")
const U_PERF_PROBE := preload("res://scripts/utils/debug/u_perf_probe.gd")
const U_PERF_FADE_BYPASS := preload("res://scripts/utils/debug/u_perf_fade_bypass.gd")
const U_MOBILE_PLATFORM_DETECTOR := preload("res://scripts/utils/display/u_mobile_platform_detector.gd")
const DEFAULT_ROOM_FADE_SETTINGS := preload("res://resources/display/vcam/cfg_default_room_fade.tres")

const ROOM_FADE_GROUP_TYPE := StringName("RoomFadeGroup")
const MIN_NORMAL_LENGTH_SQUARED := 0.000001
const THIN_AXIS_SIZE_EPSILON := 0.0001
const DEFAULT_CLIP_HEIGHT_OFFSET := 1.5
const INVALIDATE_INTERVAL := 30
const MOBILE_TICK_INTERVAL := 4
const OCCLUSION_CORRIDOR_MARGIN := 2.0
const OCCLUSION_CORRIDOR_MIN_RADIUS := 0.8
const OCCLUSION_CORRIDOR_SEGMENT_EPSILON := 0.000001
const ROOF_NORMAL_DOT_MIN := 0.9
const ROOF_HEIGHT_MARGIN := 0.5
const MOBILE_HIDE_FADE_THRESHOLD := 0.01

@export var camera_manager: I_CAMERA_MANAGER = null
@export var state_store: I_STATE_STORE = null
@export var mobile_tick_interval: int = MOBILE_TICK_INTERVAL
@export var desktop_tick_interval: int = 1
@export var min_fade: float = 0.0
@export var mobile_hide_walls_instead_of_fade: bool = false

var material_applier: Variant = null
var duplicate_target_warning_handler: Callable = Callable()

var _camera_manager: I_CAMERA_MANAGER = null
var _state_store: I_STATE_STORE = null
var _material_applier: Variant = null
var _tracked_targets: Dictionary = {}
var _target_fade_by_id: Dictionary = {}
var _invalidate_tick_counter: int = 0
var _is_mobile: bool = false
var _tick_counter: int = 0
var _perf_probe: U_PerfProbe = null
var _shader_probe: U_PerfProbe = null
var _cached_normals: Dictionary = {}
var _cached_half_extents: Dictionary = {}
var _cached_aabbs: Dictionary = {}
var _cached_transform_hashes: Dictionary = {}
var _filtered_targets_by_component: Dictionary = {}
var _filtered_targets_valid: Dictionary = {}
var _seen_this_frame: Dictionary = {}
var _original_visibility_by_id: Dictionary = {}

# Pooled parallel arrays for Pass 1 (avoids per-target Dictionary allocation)
var _pooled_targets: Array = []
var _pooled_target_ids: Array[int] = []
var _pooled_normals: Array = []
var _pooled_fades_before_corridor: Array[float] = []
var _pooled_corridor_passes: Array[bool] = []
var _pooled_is_roof: Array[bool] = []


func _init() -> void:
	execution_priority = 110
	_is_mobile = U_MOBILE_PLATFORM_DETECTOR.is_mobile()
	if DisplayServer.get_name() == "headless":
		_is_mobile = false
	U_PERF_FADE_BYPASS.reset()
	if _is_mobile:
		desktop_tick_interval = 1
	_perf_probe = U_PerfProbe.create("WallVis", _is_mobile)
	_shader_probe = U_PerfProbe.create("WallVisShader", _is_mobile)


func on_configured() -> void:
	_camera_manager = _resolve_camera_manager()


func process_tick(delta: float) -> void:
	var components: Array = get_components(ROOM_FADE_GROUP_TYPE)

	if components.is_empty():
		_restore_stale_targets_inplace({})
		return

	if _is_mobile and U_PERF_FADE_BYPASS.is_enabled():
		_restore_components_to_opaque(components)
		return

	# Tick throttling: skip frames on both mobile and desktop
	_tick_counter += 1
	var tick_interval: int = mobile_tick_interval if _is_mobile else desktop_tick_interval
	if tick_interval > 1 and (_tick_counter % tick_interval) != 0:
		return

	_perf_probe.start()
	# Use shared frame snapshot instead of independent store.get_state() calls
	var state: Dictionary = get_frame_state_snapshot()
	var mode_info: Dictionary = _get_active_mode_info_from_state(state)
	if not bool(mode_info.get("is_orbit", false)):
		_restore_components_to_opaque(components)
		return

	var main_camera: Camera3D = _resolve_active_camera()
	if main_camera == null or not is_instance_valid(main_camera):
		_restore_stale_targets_inplace({})
		return

	var applier: Variant = _resolve_material_applier()
	if applier == null:
		return
	var use_mobile_hide_mode: bool = _is_mobile_hide_mode()

	var camera_forward: Vector3 = -main_camera.global_transform.basis.z
	var camera_position: Vector3 = main_camera.global_transform.origin
	var resolved_delta: float = maxf(delta, 0.0) * float(tick_interval)  # compensate for skipped frames
	var player_data: Dictionary = _resolve_player_position_data_from_state(state)
	var has_player: bool = player_data.has("position")
	var player_position: Vector3 = player_data.get("position", Vector3.ZERO) as Vector3

	_invalidate_tick_counter += 1
	if _invalidate_tick_counter % INVALIDATE_INTERVAL == 0:
		applier.invalidate_externally_removed()

	var tick_data: Dictionary = _prepare_tick_data(components, player_data)
	var filtered_components: Array = tick_data.get("filtered_components", []) as Array
	var owned_targets_by_component: Dictionary = tick_data.get("owned_targets_by_component", {})

	_seen_this_frame.clear()

	for component_variant in filtered_components:
		if component_variant == null or not is_instance_valid(component_variant):
			continue
		if not (component_variant is Object):
			continue
		var component: Object = component_variant as Object
		var component_id: int = component.get_instance_id()

		var owned_targets_variant: Variant = owned_targets_by_component.get(component_id, [])
		var targets: Array = []
		if owned_targets_variant is Array:
			targets = owned_targets_variant as Array
		if targets.is_empty():
			continue

		if use_mobile_hide_mode:
			if applier.has_method("restore_original_materials"):
				applier.restore_original_materials(targets)
		else:
			_shader_probe.start()
			applier.apply_visibility_material(targets)

		var clip_height_offset: float = DEFAULT_CLIP_HEIGHT_OFFSET
		if component.has_method("get"):
			var offset_variant: Variant = component.get("clip_height_offset")
			if offset_variant is float or offset_variant is int:
				clip_height_offset = float(offset_variant)

		var clip_y: float = 100.0
		if has_player:
			clip_y = player_position.y + clip_height_offset

		var settings: Dictionary = _resolve_settings(component)
		var threshold: float = clampf(float(settings.get("fade_dot_threshold", 0.3)), 0.0, 1.0)
		var fade_speed: float = maxf(float(settings.get("fade_speed", 4.0)), 0.0)
		var max_fade: float = clampf(1.0 - min_fade, 0.0, 1.0)
		var initial_component_fade: float = clampf(1.0 - float(component.get("current_alpha")), 0.0, max_fade)
		var component_fade_sum: float = 0.0
		var component_fade_count: int = 0

		# Pass 1: compute raw fade values using pooled parallel arrays
		# (avoids per-target Dictionary allocation)
		_pooled_targets.clear()
		_pooled_target_ids.clear()
		_pooled_normals.clear()
		_pooled_fades_before_corridor.clear()
		_pooled_corridor_passes.clear()
		_pooled_is_roof.clear()

		var bucket_has_corridor_hit: Dictionary = {}
		var component_has_non_roof_fade: bool = false

		for target_variant in targets:
			if not (target_variant is Node3D) or not is_instance_valid(target_variant):
				continue
			var target: Node3D = target_variant as Node3D
			var target_id: int = target.get_instance_id()

			var target_normal: Vector3
			var current_transform_hash: int = _compute_transform_hash(target)
			if _cached_normals.has(target_id) and _cached_transform_hashes.get(target_id, -1) == current_transform_hash:
				target_normal = _cached_normals[target_id] as Vector3
			else:
				target_normal = _resolve_target_world_normal(component, target, targets.size())
				_cached_normals[target_id] = target_normal
				_cached_transform_hashes[target_id] = current_transform_hash

			var target_fade_before_corridor: float = _resolve_directional_fade(
				camera_forward, target_normal, threshold
			)
			var corridor_pass: bool = true
			if has_player:
				corridor_pass = _passes_camera_player_occlusion_corridor(
					target, camera_position, player_position
				)
				if corridor_pass:
					var bucket_key: String = _resolve_normal_bucket_key(target_normal)
					bucket_has_corridor_hit[bucket_key] = true

			var is_roof: bool = _is_roof_candidate_target(
				target, target_normal, has_player, player_position
			)

			_pooled_targets.append(target)
			_pooled_target_ids.append(target_id)
			_pooled_normals.append(target_normal)
			_pooled_fades_before_corridor.append(target_fade_before_corridor)
			_pooled_corridor_passes.append(corridor_pass)
			_pooled_is_roof.append(is_roof)

			if target_fade_before_corridor > 0.0 and not is_roof:
				component_has_non_roof_fade = true

		# Pass 2: resolve effective fade per target (corridor + bucket + roof).
		var pool_size: int = _pooled_targets.size()
		for i in range(pool_size):
			var target: Node3D = _pooled_targets[i] as Node3D
			if target == null or not is_instance_valid(target):
				continue
			var target_id: int = _pooled_target_ids[i]

			var target_fade: float = _pooled_fades_before_corridor[i]
			var corridor_pass: bool = _pooled_corridor_passes[i]
			var is_roof: bool = _pooled_is_roof[i]
			var target_normal: Vector3 = _pooled_normals[i] as Vector3
			var bucket_key: String = _resolve_normal_bucket_key(target_normal)

			# Corridor check: if target would fade but fails corridor and no bucket hit, stay opaque.
			target_fade = _resolve_effective_target_fade_for_corridor(
				target_fade, corridor_pass, has_player, bucket_key, bucket_has_corridor_hit
			)

			# Roof handling: roofs inherit min fade when non-roof targets are fading.
			if is_roof and component_has_non_roof_fade:
				target_fade = maxf(target_fade, min_fade)

			# Clamp fade so walls never fully dissolve to zero visibility.
			target_fade = minf(target_fade, max_fade)

			var current_fade: float = initial_component_fade
			if _target_fade_by_id.has(target_id):
				current_fade = float(_target_fade_by_id.get(target_id, initial_component_fade))
			var next_fade: float = current_fade
			if fade_speed > 0.0:
				next_fade = move_toward(next_fade, target_fade, fade_speed * resolved_delta)
			next_fade = clampf(next_fade, 0.0, max_fade)

			_target_fade_by_id[target_id] = next_fade
			if use_mobile_hide_mode:
				_apply_mobile_visibility_state(target, target_id, next_fade)
			else:
				applier.update_uniforms(target, clip_y, next_fade)
				_shader_probe.stop()
			_seen_this_frame[target_id] = target

			component_fade_sum += next_fade
			component_fade_count += 1

		if component_fade_count > 0:
			var avg_fade: float = component_fade_sum / float(component_fade_count)
			component.set("current_alpha", 1.0 - avg_fade)

	_restore_stale_targets_inplace(_seen_this_frame)
	_perf_probe.stop()


func _exit_tree() -> void:
	_restore_stale_targets_inplace({})
	_target_fade_by_id.clear()
	_cached_normals.clear()
	_cached_half_extents.clear()
	_cached_aabbs.clear()
	_cached_transform_hashes.clear()
	_filtered_targets_by_component.clear()
	_filtered_targets_valid.clear()
	_seen_this_frame.clear()
	_original_visibility_by_id.clear()
	_pooled_targets.clear()
	_pooled_target_ids.clear()
	_pooled_normals.clear()
	_pooled_fades_before_corridor.clear()
	_pooled_corridor_passes.clear()
	_pooled_is_roof.clear()


# --- Room filtering and target ownership ---

func _prepare_tick_data(components: Array, player_data: Dictionary) -> Dictionary:
	var has_player: bool = player_data.has("position")
	var player_position: Vector3 = player_data.get("position", Vector3.ZERO) as Vector3
	var do_room_filter: bool = has_player and components.size() > 1

	var targets_by_component_id: Dictionary = {}
	var matching_components: Array = []

	for component_variant in components:
		if component_variant == null or not is_instance_valid(component_variant):
			continue
		if not (component_variant is Object):
			continue
		var component: Object = component_variant as Object
		var targets: Array = _collect_mesh_targets(component)
		if targets.is_empty():
			continue
		var component_id: int = component.get_instance_id()
		targets_by_component_id[component_id] = targets

		if do_room_filter:
			var room_aabb: AABB = _resolve_aabb_from_validated_targets(targets)
			var expanded: AABB = room_aabb.grow(2.0)
			expanded.position.y = room_aabb.position.y - 0.5
			expanded.size.y = room_aabb.size.y + 1.0
			if expanded.has_point(player_position):
				matching_components.append(component_variant)
		else:
			matching_components.append(component_variant)

	if do_room_filter and matching_components.is_empty():
		matching_components = components

	# Assign ownership: each target belongs to exactly one component.
	var owned_targets_by_component: Dictionary = {}
	var owner_component_by_target_id: Dictionary = {}
	var warning_pairs: Dictionary = {}

	for component_variant in matching_components:
		if component_variant == null or not is_instance_valid(component_variant):
			continue
		if not (component_variant is Object):
			continue
		var component: Object = component_variant as Object
		var component_id: int = component.get_instance_id()
		var targets_variant: Variant = targets_by_component_id.get(component_id, null)
		if targets_variant == null or not (targets_variant is Array):
			continue
		var targets: Array = targets_variant as Array

		var owned_targets: Array = []
		var seen_targets_for_component: Dictionary = {}
		for target_variant in targets:
			if not (target_variant is Node3D):
				continue
			var target: Node3D = target_variant as Node3D
			if not is_instance_valid(target):
				continue
			var target_id: int = target.get_instance_id()
			if seen_targets_for_component.has(target_id):
				continue
			seen_targets_for_component[target_id] = true

			if not owner_component_by_target_id.has(target_id):
				owner_component_by_target_id[target_id] = component
				owned_targets.append(target)
				continue

			var owner_variant: Variant = owner_component_by_target_id.get(target_id, null)
			var owner_component := owner_variant as Object
			if owner_component == null or not is_instance_valid(owner_component):
				owner_component_by_target_id[target_id] = component
				owned_targets.append(target)
				continue
			if owner_component == component:
				continue

			_warn_duplicate_target_ownership_once_per_tick(
				component, owner_component, target, warning_pairs
			)

		if not owned_targets.is_empty():
			owned_targets_by_component[component_id] = owned_targets

	return {
		"filtered_components": matching_components,
		"owned_targets_by_component": owned_targets_by_component,
	}


func _warn_duplicate_target_ownership_once_per_tick(
	component: Object,
	owner_component: Object,
	target: Node3D,
	warning_pairs: Dictionary
) -> void:
	if component == null or owner_component == null or target == null:
		return
	var pair_key: String = "%d:%d" % [target.get_instance_id(), component.get_instance_id()]
	if warning_pairs.has(pair_key):
		return
	warning_pairs[pair_key] = true
	var message := (
		"S_WallVisibilitySystem: duplicate target ownership skipped for target=%s owner=%s skipped=%s"
		% [_describe_node(target), _describe_object(owner_component), _describe_object(component)]
	)
	_emit_duplicate_target_warning(message)


func _emit_duplicate_target_warning(message: String) -> void:
	if duplicate_target_warning_handler.is_valid():
		duplicate_target_warning_handler.call(message)
		return
	push_warning(message)


func _resolve_aabb_from_validated_targets(targets: Array) -> AABB:
	var aabb: AABB = AABB()
	var initialized: bool = false
	for target_variant in targets:
		if not (target_variant is Node3D) or not is_instance_valid(target_variant):
			continue
		var target: Node3D = target_variant as Node3D
		var target_aabb: AABB = _resolve_target_aabb(target)
		if target_aabb.size == Vector3.ZERO:
			continue
		if not initialized:
			aabb = target_aabb
			initialized = true
		else:
			aabb = aabb.merge(target_aabb)
	if not initialized:
		aabb = AABB(Vector3.ZERO, Vector3.ONE)
	return aabb


func _resolve_target_aabb(target: Node3D) -> AABB:
	var target_id: int = target.get_instance_id()
	var transform_hash: int = _compute_transform_hash(target)
	if _cached_aabbs.has(target_id) and _cached_transform_hashes.get(target_id, -1) == transform_hash:
		return _cached_aabbs[target_id] as AABB
	var result: AABB = _resolve_target_aabb_uncached(target)
	_cached_aabbs[target_id] = result
	return result


func _resolve_target_aabb_uncached(target: Node3D) -> AABB:
	if target is CSGBox3D:
		var csg: CSGBox3D = target as CSGBox3D
		var half: Vector3 = csg.size.abs() * 0.5
		return AABB(csg.global_position - half, csg.size.abs())
	elif target is MeshInstance3D:
		var mesh_instance: MeshInstance3D = target as MeshInstance3D
		if mesh_instance.mesh != null:
			var mesh_aabb: AABB = mesh_instance.mesh.get_aabb()
			return mesh_instance.global_transform * mesh_aabb
	elif target is CSGShape3D:
		return AABB(target.global_position - Vector3.ONE * 0.5, Vector3.ONE)
	return AABB(target.global_position - Vector3.ONE * 0.5, Vector3.ONE)


# --- Directional fade ---

func _resolve_directional_fade(
	camera_forward: Vector3,
	wall_normal: Vector3,
	threshold: float
) -> float:
	var dot_value: float = camera_forward.dot(wall_normal)
	if dot_value > threshold:
		return 1.0
	return 0.0


# --- Corridor ---

func _passes_camera_player_occlusion_corridor(
	target: Node3D,
	camera_position: Vector3,
	player_position: Vector3
) -> bool:
	if target == null or not is_instance_valid(target):
		return false

	var camera_planar := Vector2(camera_position.x, camera_position.z)
	var player_planar := Vector2(player_position.x, player_position.z)
	var segment: Vector2 = player_planar - camera_planar
	var segment_length_sq: float = segment.length_squared()
	if segment_length_sq <= OCCLUSION_CORRIDOR_SEGMENT_EPSILON:
		return true

	var target_planar: Vector2 = _resolve_target_nearest_corridor_point(
		target, camera_planar, segment, segment_length_sq
	)

	var to_target: Vector2 = target_planar - camera_planar
	var segment_t: float = to_target.dot(segment) / segment_length_sq
	if segment_t < 0.0 or segment_t > 1.0:
		return false

	var closest_point: Vector2 = camera_planar + segment * segment_t
	var distance_to_segment: float = target_planar.distance_to(closest_point)
	return distance_to_segment <= maxf(OCCLUSION_CORRIDOR_MARGIN, OCCLUSION_CORRIDOR_MIN_RADIUS)


func _resolve_target_nearest_corridor_point(
	target: Node3D,
	seg_a: Vector2,
	segment: Vector2,
	segment_length_sq: float
) -> Vector2:
	var center := Vector2(target.global_position.x, target.global_position.z)
	var half_extents: Vector2 = _resolve_target_planar_half_extents(target)
	if half_extents == Vector2.ZERO:
		return center

	var to_center: Vector2 = center - seg_a
	var t: float = clampf(to_center.dot(segment) / segment_length_sq, 0.0, 1.0)
	var line_point: Vector2 = seg_a + segment * t

	var min_bound: Vector2 = center - half_extents
	var max_bound: Vector2 = center + half_extents
	return Vector2(
		clampf(line_point.x, min_bound.x, max_bound.x),
		clampf(line_point.y, min_bound.y, max_bound.y)
	)


func _resolve_target_planar_half_extents(target: Node3D) -> Vector2:
	var target_id: int = target.get_instance_id()
	var transform_hash: int = _compute_transform_hash(target)
	if _cached_half_extents.has(target_id) and _cached_transform_hashes.get(target_id, -1) == transform_hash:
		return _cached_half_extents[target_id] as Vector2
	var result: Vector2 = _resolve_target_planar_half_extents_uncached(target)
	_cached_half_extents[target_id] = result
	return result


func _resolve_target_planar_half_extents_uncached(target: Node3D) -> Vector2:
	if target is CSGBox3D:
		var csg: CSGBox3D = target as CSGBox3D
		var half: Vector3 = csg.size.abs() * 0.5
		var bx: Basis = csg.global_basis
		var world_half_x: float = half.x * absf(bx.x.x) + half.z * absf(bx.z.x)
		var world_half_z: float = half.x * absf(bx.x.z) + half.z * absf(bx.z.z)
		return Vector2(world_half_x, world_half_z)
	elif target is MeshInstance3D:
		var mesh: MeshInstance3D = target as MeshInstance3D
		if mesh.mesh != null:
			var half: Vector3 = mesh.mesh.get_aabb().size.abs() * 0.5
			var bx: Basis = mesh.global_basis
			var world_half_x: float = half.x * absf(bx.x.x) + half.z * absf(bx.z.x)
			var world_half_z: float = half.x * absf(bx.x.z) + half.z * absf(bx.z.z)
			return Vector2(world_half_x, world_half_z)
	return Vector2.ZERO


# --- Bucket continuity ---

func _resolve_effective_target_fade_for_corridor(
	target_fade_before_corridor: float,
	corridor_pass: bool,
	has_player_position: bool,
	bucket_key: String,
	bucket_has_corridor_hit: Dictionary
) -> float:
	var resolved_fade: float = target_fade_before_corridor
	if has_player_position:
		if corridor_pass:
			# Corridor grants fading: wall is between camera and player regardless of facing.
			resolved_fade = maxf(resolved_fade, 1.0)
		elif resolved_fade > 0.0:
			# Corridor revokes fading unless bucket continuity preserves it.
			var bucket_continuity_hit: bool = bool(bucket_has_corridor_hit.get(bucket_key, false))
			if not bucket_continuity_hit:
				resolved_fade = 0.0
	return resolved_fade


func _resolve_normal_bucket_key(normal: Vector3) -> String:
	var abs_normal := Vector3(absf(normal.x), absf(normal.y), absf(normal.z))
	if abs_normal.x >= abs_normal.y and abs_normal.x >= abs_normal.z:
		return "+x" if normal.x > 0.0 else "-x"
	if abs_normal.y >= abs_normal.x and abs_normal.y >= abs_normal.z:
		return "+y" if normal.y > 0.0 else "-y"
	return "+z" if normal.z > 0.0 else "-z"


# --- Roof handling ---

func _is_roof_candidate_target(
	target: Node3D,
	target_normal: Vector3,
	has_player_position: bool,
	player_position: Vector3
) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if absf(target_normal.y) < ROOF_NORMAL_DOT_MIN:
		return false
	if not has_player_position:
		return false
	return target.global_position.y > (player_position.y + ROOF_HEIGHT_MARGIN)


# --- Normal resolution ---

func _resolve_target_world_normal(component: Object, target: Node3D, target_count: int) -> Vector3:
	var component_normal: Vector3 = _resolve_world_normal(component)
	if target == null or not is_instance_valid(target):
		return component_normal
	if target_count <= 1:
		return component_normal

	var csg_axis_normal: Vector3 = _resolve_csg_box_thin_axis_normal(component, target)
	if csg_axis_normal != Vector3.ZERO:
		return csg_axis_normal

	var component_origin: Vector3 = _resolve_component_origin(component, target)
	var inward_raw: Vector3 = component_origin - target.global_position
	var inward_planar: Vector3 = inward_raw
	inward_planar.y = 0.0
	if inward_planar.length_squared() <= MIN_NORMAL_LENGTH_SQUARED:
		return component_normal
	return inward_planar.normalized()


func _resolve_csg_box_thin_axis_normal(component: Object, target: Node3D) -> Vector3:
	if not (target is CSGBox3D):
		return Vector3.ZERO
	var csg_box: CSGBox3D = target as CSGBox3D
	if csg_box == null or not is_instance_valid(csg_box):
		return Vector3.ZERO

	var axis_candidates: Array = _resolve_csg_box_thin_axis_world_candidates(csg_box)
	if axis_candidates.is_empty():
		return Vector3.ZERO

	var component_origin: Vector3 = _resolve_component_origin(component, target)
	var inward_direction_3d: Vector3 = component_origin - target.global_position
	var inward_direction_planar: Vector3 = inward_direction_3d
	inward_direction_planar.y = 0.0
	var inward_direction: Vector3 = inward_direction_planar
	if inward_direction.length_squared() <= MIN_NORMAL_LENGTH_SQUARED:
		inward_direction = inward_direction_3d
	if inward_direction.length_squared() <= MIN_NORMAL_LENGTH_SQUARED:
		return Vector3.ZERO
	inward_direction = inward_direction.normalized()

	var first_axis_variant: Variant = axis_candidates[0]
	if not (first_axis_variant is Vector3):
		return Vector3.ZERO
	var best_axis: Vector3 = first_axis_variant as Vector3
	var best_axis_alignment: float = absf(best_axis.dot(inward_direction))

	for axis_variant in axis_candidates:
		if not (axis_variant is Vector3):
			continue
		var axis: Vector3 = axis_variant as Vector3
		var alignment: float = absf(axis.dot(inward_direction))
		if alignment > best_axis_alignment:
			best_axis = axis
			best_axis_alignment = alignment

	if best_axis.dot(inward_direction) < 0.0:
		best_axis = -best_axis
	if best_axis.length_squared() <= MIN_NORMAL_LENGTH_SQUARED:
		return Vector3.ZERO
	return best_axis.normalized()


func _resolve_csg_box_thin_axis_world_candidates(csg_box: CSGBox3D) -> Array:
	if csg_box == null or not is_instance_valid(csg_box):
		return []
	var size: Vector3 = csg_box.size.abs()
	var smallest_axis_size: float = minf(size.x, minf(size.y, size.z))
	var axes: Array = []
	if absf(size.x - smallest_axis_size) <= THIN_AXIS_SIZE_EPSILON:
		axes.append(csg_box.global_basis.x.normalized())
	if absf(size.y - smallest_axis_size) <= THIN_AXIS_SIZE_EPSILON:
		axes.append(csg_box.global_basis.y.normalized())
	if absf(size.z - smallest_axis_size) <= THIN_AXIS_SIZE_EPSILON:
		axes.append(csg_box.global_basis.z.normalized())
	return axes


func _resolve_world_normal(component: Object) -> Vector3:
	if component == null:
		return Vector3.FORWARD
	if component.has_method("get_fade_normal_world"):
		var normal_variant: Variant = component.call("get_fade_normal_world")
		if normal_variant is Vector3:
			return normal_variant as Vector3
	return Vector3.FORWARD


func _resolve_component_origin(component: Object, fallback_target: Node3D) -> Vector3:
	if component is Node3D:
		return (component as Node3D).global_position
	if component is Node:
		var parent := (component as Node).get_parent() as Node3D
		if parent != null and is_instance_valid(parent):
			return parent.global_position
	if fallback_target != null:
		return fallback_target.global_position
	return Vector3.ZERO


# --- Dependency resolution ---

func _resolve_camera_manager() -> I_CAMERA_MANAGER:
	_camera_manager = U_DependencyResolution.resolve(&"camera_manager", _camera_manager, camera_manager) as I_CAMERA_MANAGER
	return _camera_manager


func _resolve_state_store() -> I_STATE_STORE:
	_state_store = U_DependencyResolution.resolve_state_store(_state_store, state_store, self) as I_STATE_STORE
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


func _resolve_material_applier() -> Variant:
	if material_applier != null:
		return material_applier
	if _material_applier != null:
		return _material_applier
	_material_applier = U_WALL_VISIBILITY_MATERIAL_APPLIER.new()
	return _material_applier


func _get_active_mode_info() -> Dictionary:
	var state: Dictionary = get_frame_state_snapshot()
	return _get_active_mode_info_from_state(state)


func _get_active_mode_info_from_state(state: Dictionary) -> Dictionary:
	if state.is_empty():
		return {"has_store": false, "active_mode": "", "is_orbit": false}
	var active_mode: String = U_VCAM_SELECTORS.get_active_mode(state).to_lower()
	return {"has_store": true, "active_mode": active_mode, "is_orbit": active_mode == "orbit"}


func _resolve_player_position_data() -> Dictionary:
	var state: Dictionary = get_frame_state_snapshot()
	return _resolve_player_position_data_from_state(state)


func _resolve_player_position_data_from_state(state: Dictionary) -> Dictionary:
	if state.is_empty():
		var store: I_STATE_STORE = _resolve_state_store()
		if store == null:
			return {}
		state = store.get_state()
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


func _resolve_settings(component: Object) -> Dictionary:
	var settings_resource: Variant = DEFAULT_ROOM_FADE_SETTINGS
	var component_settings: Variant = component.get("settings")
	if component_settings != null and component_settings is Resource:
		var resource: Resource = component_settings as Resource
		if resource.get_script() == RS_ROOM_FADE_SETTINGS_SCRIPT:
			settings_resource = resource
	if settings_resource != null and settings_resource.has_method("get_resolved_values"):
		var resolved_variant: Variant = settings_resource.call("get_resolved_values")
		if resolved_variant is Dictionary:
			return resolved_variant as Dictionary
	return {"fade_dot_threshold": 0.3, "fade_speed": 4.0, "min_alpha": 0.05}


func _collect_mesh_targets(component: Object) -> Array:
	if component == null:
		return []
	var component_id: int = component.get_instance_id()
	var cache_is_valid: bool = component.has_method("is_target_cache_valid") and component.call("is_target_cache_valid")
	if cache_is_valid and _filtered_targets_valid.get(component_id, false):
		if _filtered_targets_by_component.has(component_id):
			return _filtered_targets_by_component[component_id] as Array
	if not component.has_method("collect_mesh_targets"):
		return []
	var targets_variant: Variant = component.call("collect_mesh_targets")
	if not (targets_variant is Array):
		return []
	var targets: Array = []
	for target_variant in targets_variant as Array:
		if _is_supported_target(target_variant):
			targets.append(target_variant)
	_filtered_targets_by_component[component_id] = targets
	_filtered_targets_valid[component_id] = true
	return targets


func _is_supported_target(target_variant: Variant) -> bool:
	if target_variant is MeshInstance3D:
		var mesh_target: MeshInstance3D = target_variant as MeshInstance3D
		return mesh_target != null and is_instance_valid(mesh_target)
	if target_variant is CSGShape3D:
		var csg_target: CSGShape3D = target_variant as CSGShape3D
		return csg_target != null and is_instance_valid(csg_target)
	return false


# --- Restore / cleanup ---

func _restore_stale_targets_inplace(active_targets: Dictionary) -> void:
	var applier: Variant = _resolve_material_applier()
	var stale_targets: Array = []
	var stale_ids: Array = []
	for target_id_variant in _tracked_targets.keys():
		var target_id: int = int(target_id_variant)
		if active_targets.has(target_id):
			continue
		var target_variant: Variant = _tracked_targets.get(target_id, null)
		if target_variant is Node3D and is_instance_valid(target_variant):
			stale_targets.append(target_variant)
		stale_ids.append(target_id)

	if not stale_targets.is_empty():
		if applier != null:
			applier.restore_original_materials(stale_targets)
		for target_variant in stale_targets:
			if not (target_variant is Node3D) or not is_instance_valid(target_variant):
				continue
			var stale_target: Node3D = target_variant as Node3D
			_restore_target_visibility(stale_target, stale_target.get_instance_id())
		for stale_id in stale_ids:
			_target_fade_by_id.erase(stale_id)
			_cached_normals.erase(stale_id)
			_cached_half_extents.erase(stale_id)
			_cached_aabbs.erase(stale_id)
			_cached_transform_hashes.erase(stale_id)
			_original_visibility_by_id.erase(stale_id)

	# Update tracking in-place: add new, remove stale
	for target_id_variant in active_targets.keys():
		var target_id: int = int(target_id_variant)
		if not _tracked_targets.has(target_id):
			_tracked_targets[target_id] = active_targets[target_id]
	for stale_id in stale_ids:
		_tracked_targets.erase(stale_id)


func _restore_components_to_opaque(components: Array) -> void:
	var restore_targets: Array = []
	var seen_targets: Dictionary = {}

	for component_variant in components:
		if component_variant == null or not is_instance_valid(component_variant):
			continue
		if not (component_variant is Object):
			continue
		var component: Object = component_variant as Object
		component.set("current_alpha", 1.0)
		var targets: Array = _collect_mesh_targets(component)
		for target_variant in targets:
			if not (target_variant is Node3D) or not is_instance_valid(target_variant):
				continue
			var target: Node3D = target_variant as Node3D
			var target_id: int = target.get_instance_id()
			if seen_targets.has(target_id):
				continue
			seen_targets[target_id] = true
			_target_fade_by_id.erase(target_id)
			_restore_target_visibility(target, target_id)
			restore_targets.append(target)

	for target_variant in _tracked_targets.values():
		if not (target_variant is Node3D) or not is_instance_valid(target_variant):
			continue
		var tracked_target: Node3D = target_variant as Node3D
		var tracked_id: int = tracked_target.get_instance_id()
		if seen_targets.has(tracked_id):
			continue
		seen_targets[tracked_id] = true
		_target_fade_by_id.erase(tracked_id)
		_cached_normals.erase(tracked_id)
		_cached_half_extents.erase(tracked_id)
		_cached_aabbs.erase(tracked_id)
		_cached_transform_hashes.erase(tracked_id)
		_restore_target_visibility(tracked_target, tracked_id)
		restore_targets.append(tracked_target)

	var applier: Variant = _resolve_material_applier()
	if applier != null and not restore_targets.is_empty():
		applier.restore_original_materials(restore_targets)
	_tracked_targets.clear()
	_target_fade_by_id.clear()
	_cached_normals.clear()
	_cached_half_extents.clear()
	_cached_aabbs.clear()
	_cached_transform_hashes.clear()
	_filtered_targets_by_component.clear()
	_filtered_targets_valid.clear()
	_original_visibility_by_id.clear()


func _is_mobile_hide_mode() -> bool:
	return _is_mobile and mobile_hide_walls_instead_of_fade


func _apply_mobile_visibility_state(target: Node3D, target_id: int, fade_amount: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not _original_visibility_by_id.has(target_id):
		_original_visibility_by_id[target_id] = target.visible
	var should_hide: bool = fade_amount > MOBILE_HIDE_FADE_THRESHOLD
	if should_hide:
		target.visible = false
		return
	_restore_target_visibility(target, target_id)


func _restore_target_visibility(target: Node3D, target_id: int) -> void:
	if target == null or not is_instance_valid(target):
		_original_visibility_by_id.erase(target_id)
		return
	if _original_visibility_by_id.has(target_id):
		target.visible = bool(_original_visibility_by_id.get(target_id, true))
		_original_visibility_by_id.erase(target_id)


# --- Utility ---

func _describe_node(node: Node) -> String:
	if node == null:
		return "<null>"
	if not is_instance_valid(node):
		return "<freed>"
	return "%s:%s" % [node.name, node.get_class()]


func _describe_object(obj: Object) -> String:
	if obj == null:
		return "<null>"
	if not is_instance_valid(obj):
		return "<freed>"
	return "%s:%s" % [obj.name, obj.get_class()]


func _compute_transform_hash(target: Node3D) -> int:
	if target == null or not is_instance_valid(target):
		return 0
	return hash(target.global_transform)
