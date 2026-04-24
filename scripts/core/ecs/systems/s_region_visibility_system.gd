@icon("res://assets/editor_icons/icn_system.svg")
extends BaseECSSystem
class_name S_RegionVisibilitySystem

const U_VCAM_SELECTORS := preload("res://scripts/core/state/selectors/u_vcam_selectors.gd")
const I_CAMERA_MANAGER := preload("res://scripts/core/interfaces/i_camera_manager.gd")
const I_StateStore := preload("res://scripts/core/interfaces/i_state_store.gd")
const RS_REGION_VISIBILITY_SETTINGS_SCRIPT := preload(
	"res://scripts/core/resources/display/vcam/rs_region_visibility_settings.gd"
)
const U_ROOM_FADE_MATERIAL_APPLIER := preload(
	"res://scripts/utils/lighting/u_room_fade_material_applier.gd"
)
const U_ENTITY_SELECTORS := preload("res://scripts/core/state/selectors/u_entity_selectors.gd")
const DEFAULT_REGION_VISIBILITY_SETTINGS := preload(
	"res://resources/display/vcam/cfg_default_region_visibility.tres"
)
const U_MOBILE_PLATFORM_DETECTOR := preload("res://scripts/utils/display/u_mobile_platform_detector.gd")
const U_PERF_PROBE := preload("res://scripts/utils/debug/u_perf_probe.gd")
const U_PERF_FADE_BYPASS := preload("res://scripts/utils/debug/u_perf_fade_bypass.gd")

const MOBILE_TICK_INTERVAL := 4

const REGION_VISIBILITY_TYPE := StringName("RegionVisibility")
const FADED_THRESHOLD := 0.95

@export var camera_manager: I_CAMERA_MANAGER = null
@export var state_store: I_StateStore = null

var material_applier: Variant = null

var _state_store: I_StateStore = null
var _material_applier: Variant = null
var _tracked_targets: Dictionary = {}
var _target_alpha_by_id: Dictionary = {}
var _active_region_tags: Array[StringName] = []
var _near_region_tags: Array[StringName] = []
var _region_alpha_by_tag: Dictionary = {}
var _filtered_targets_cache: Dictionary = {}  # int (component id) -> Array

var _perf_is_supported_calls: int = 0
var _is_mobile: bool = false
var _tick_counter: int = 0
var _perf_probe: U_PerfProbe = null
var _fade_probe: U_PerfProbe = null

func _init() -> void:
	execution_priority = 100
	_is_mobile = U_MOBILE_PLATFORM_DETECTOR.is_mobile()
	if DisplayServer.get_name() == "headless":
		_is_mobile = false
	U_PERF_FADE_BYPASS.reset()
	_perf_probe = U_PerfProbe.create("RegionVis", _is_mobile)
	_fade_probe = U_PerfProbe.create("RegionFadeApply", _is_mobile)

func get_phase() -> BaseECSSystem.SystemPhase:
	return BaseECSSystem.SystemPhase.CAMERA

func process_tick(delta: float) -> void:
	# Mobile throttle: skip frames to reduce CPU load
	_tick_counter += 1
	if _is_mobile and (_tick_counter % MOBILE_TICK_INTERVAL) != 0:
		return

	_perf_probe.start()
	var components: Array = get_components(REGION_VISIBILITY_TYPE)

	if components.is_empty():
		_restore_stale_targets({})
		return

	if _is_mobile and U_PERF_FADE_BYPASS.is_enabled():
		_restore_components_to_opaque(components)
		return

	var mode_info: Dictionary = _get_active_mode_info()
	if not bool(mode_info.get("is_orbit", false)):
		_restore_components_to_opaque(components)
		return

	var player_data: Dictionary = _resolve_player_position_data()
	var has_player: bool = not player_data.is_empty()
	var player_position: Vector3 = player_data.get("position", Vector3.ZERO) as Vector3

	var applier: Variant = _resolve_material_applier()
	if applier == null:
		return

	var active_targets: Dictionary = {}
	var resolved_delta: float = maxf(delta, 0.0)
	var new_active_tags: Array[StringName] = []
	var new_near_tags: Array[StringName] = []

	for component_variant in components:
		if component_variant == null or not is_instance_valid(component_variant):
			continue
		if not (component_variant is Object):
			continue
		var component: Object = component_variant as Object

		var targets: Array = _collect_mesh_targets(component)
		if targets.is_empty():
			continue

		var settings: Dictionary = _resolve_settings(component)
		var fade_speed: float = maxf(float(settings.get("fade_speed", 3.0)), 0.0)
		var min_alpha: float = clampf(float(settings.get("min_alpha", 0.0)), 0.0, 1.0)
		var near_alpha: float = clampf(float(settings.get("near_alpha", 0.5)), 0.0, 1.0)
		var aabb_grow: float = maxf(float(settings.get("aabb_grow", 3.0)), 0.0)
		var inner_aabb_grow: float = maxf(float(settings.get("inner_aabb_grow", 1.0)), 0.0)
		var aabb_vertical_shrink: float = maxf(float(settings.get("aabb_vertical_shrink", 0.5)), 0.0)

		var is_in_inner: bool = true
		var is_in_outer: bool = false
		if has_player:
			is_in_inner = _is_player_in_zone(component, targets, player_position, inner_aabb_grow, aabb_vertical_shrink)
			if not is_in_inner:
				is_in_outer = _is_player_in_zone(component, targets, player_position, aabb_grow, aabb_vertical_shrink)
		component.set("is_active_region", is_in_inner)
		component.set("is_near_region", is_in_outer)

		var region_tag: StringName = component.get("region_tag") as StringName
		if is_in_inner and region_tag != StringName(""):
			new_active_tags.append(region_tag)
		if is_in_outer and region_tag != StringName(""):
			new_near_tags.append(region_tag)

		var target_alpha: float
		if is_in_inner:
			target_alpha = 1.0
		elif is_in_outer:
			target_alpha = near_alpha
		else:
			target_alpha = min_alpha
		var current_alpha: float = float(component.get("current_alpha"))
		var next_alpha: float = current_alpha
		if fade_speed > 0.0:
			next_alpha = move_toward(next_alpha, target_alpha, fade_speed * resolved_delta)
		next_alpha = clampf(next_alpha, min_alpha, 1.0)
		component.set("current_alpha", next_alpha)

		if region_tag != StringName(""):
			_region_alpha_by_tag[region_tag] = next_alpha

		if next_alpha >= 1.0:
			continue

		_fade_probe.start()
		applier.apply_fade_material(targets)
		applier.update_fade_alpha(targets, next_alpha)
		_fade_probe.stop()
		for target_variant in targets:
			if not (target_variant is Node3D) or not is_instance_valid(target_variant):
				continue
			var target: Node3D = target_variant as Node3D
			var target_id: int = target.get_instance_id()
			active_targets[target_id] = target
			_target_alpha_by_id[target_id] = next_alpha

	_active_region_tags = new_active_tags
	_near_region_tags = new_near_tags
	_restore_stale_targets(active_targets)
	_perf_probe.stop()

func get_active_region_tags() -> Array[StringName]:
	return _active_region_tags.duplicate()

func get_near_region_tags() -> Array[StringName]:
	return _near_region_tags.duplicate()

func is_region_faded(region_tag: StringName) -> bool:
	if not _region_alpha_by_tag.has(region_tag):
		return false
	return float(_region_alpha_by_tag.get(region_tag, 1.0)) < FADED_THRESHOLD

func _exit_tree() -> void:
	_restore_stale_targets({})
	_target_alpha_by_id.clear()
	_near_region_tags.clear()
	_region_alpha_by_tag.clear()
	_filtered_targets_cache.clear()

func _resolve_state_store() -> I_StateStore:
	_state_store = U_DependencyResolution.resolve_state_store(_state_store, state_store, self) as I_StateStore
	return _state_store

func _resolve_material_applier() -> Variant:
	if material_applier != null:
		return material_applier
	if _material_applier != null:
		return _material_applier
	_material_applier = U_ROOM_FADE_MATERIAL_APPLIER.new()
	return _material_applier

func _get_active_mode_info() -> Dictionary:
	var store: I_StateStore = _resolve_state_store()
	if store == null:
		return {
			"has_store": false,
			"active_mode": "",
			"is_orbit": false,
		}

	var state: Dictionary = store.get_state()
	var active_mode: String = U_VCAM_SELECTORS.get_active_mode(state).to_lower()
	return {
		"has_store": true,
		"active_mode": active_mode,
		"is_orbit": active_mode == "orbit",
	}

func _resolve_player_position_data() -> Dictionary:
	var store: I_StateStore = _resolve_state_store()
	if store == null:
		return {}

	var state: Dictionary = store.get_state()
	var player_position: Variant = U_ENTITY_SELECTORS.get_player_position(state)
	if player_position is Vector3:
		return {"position": player_position as Vector3}
	return {}

func _resolve_settings(component: Object) -> Dictionary:
	var settings_resource: Variant = DEFAULT_REGION_VISIBILITY_SETTINGS
	var component_settings: Variant = component.get("settings")
	if component_settings != null and component_settings is Resource:
		var resource: Resource = component_settings as Resource
		if resource.get_script() == RS_REGION_VISIBILITY_SETTINGS_SCRIPT:
			settings_resource = resource

	if settings_resource != null and settings_resource.has_method("get_resolved_values"):
		var resolved_variant: Variant = settings_resource.call("get_resolved_values")
		if resolved_variant is Dictionary:
			return resolved_variant as Dictionary

	return {
		"fade_speed": 3.0,
		"min_alpha": 0.0,
		"near_alpha": 0.5,
		"aabb_grow": 6.0,
		"inner_aabb_grow": 1.0,
		"aabb_vertical_shrink": 0.5,
	}

func _collect_mesh_targets(component: Object) -> Array:
	if component == null:
		return []
	if not component.has_method("collect_mesh_targets"):
		return []

	var component_id: int = component.get_instance_id()
	var is_cache_valid: bool = component.has_method("is_target_cache_valid") and bool(component.call("is_target_cache_valid"))
	if is_cache_valid and _filtered_targets_cache.has(component_id):
		return _filtered_targets_cache[component_id] as Array

	var targets_variant: Variant = component.call("collect_mesh_targets")
	if not (targets_variant is Array):
		return []

	var targets: Array = []
	for target_variant in targets_variant as Array:
		_perf_is_supported_calls += 1
		if _is_supported_target(target_variant):
			targets.append(target_variant)
	_filtered_targets_cache[component_id] = targets
	return targets

func _is_player_in_zone(
	component: Object,
	targets: Array,
	player_position: Vector3,
	aabb_grow: float,
	aabb_vertical_shrink: float
) -> bool:
	var region_aabb: AABB = AABB()
	if component.has_method("get_region_aabb"):
		region_aabb = component.call("get_region_aabb") as AABB
	else:
		region_aabb = _resolve_aabb_from_targets(targets)

	var expanded: AABB = region_aabb.grow(aabb_grow)
	expanded.position.y = region_aabb.position.y - aabb_vertical_shrink
	expanded.size.y = region_aabb.size.y + aabb_vertical_shrink * 2.0
	return expanded.has_point(player_position)

func _resolve_aabb_from_targets(targets: Array) -> AABB:
	# Targets are pre-filtered by _collect_mesh_targets — skip redundant type checks.
	var first_valid: Node3D = null
	for target_variant in targets:
		if target_variant is Node3D and is_instance_valid(target_variant):
			first_valid = target_variant as Node3D
			break
	if first_valid == null:
		return AABB()

	var result: AABB = AABB(first_valid.global_position, Vector3.ZERO)
	for target_variant in targets:
		if not (target_variant is Node3D) or not is_instance_valid(target_variant):
			continue
		var target: Node3D = target_variant as Node3D
		result = result.expand(target.global_position)
	return result

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
		component.set("is_active_region", true)
		component.set("is_near_region", false)
		var targets: Array = _collect_mesh_targets(component)
		for target_variant in targets:
			if not (target_variant is Node3D) or not is_instance_valid(target_variant):
				continue
			var target: Node3D = target_variant as Node3D
			var target_id: int = target.get_instance_id()
			if seen_targets.has(target_id):
				continue
			seen_targets[target_id] = true
			_target_alpha_by_id.erase(target_id)
			restore_targets.append(target)

	for target_variant in _tracked_targets.values():
		if not (target_variant is Node3D) or not is_instance_valid(target_variant):
			continue
		var tracked_target: Node3D = target_variant as Node3D
		var tracked_id: int = tracked_target.get_instance_id()
		if seen_targets.has(tracked_id):
			continue
		seen_targets[tracked_id] = true
		_target_alpha_by_id.erase(tracked_id)
		restore_targets.append(tracked_target)

	var applier: Variant = _resolve_material_applier()
	if applier != null and not restore_targets.is_empty():
		applier.restore_original_materials(restore_targets)
	_tracked_targets.clear()
	_target_alpha_by_id.clear()
	_active_region_tags.clear()
	_near_region_tags.clear()
	_region_alpha_by_tag.clear()

func _restore_stale_targets(active_targets: Dictionary) -> void:
	var applier: Variant = _resolve_material_applier()
	if applier == null:
		_tracked_targets = active_targets.duplicate()
		return

	var stale_targets: Array = []
	for target_id_variant in _tracked_targets.keys():
		var target_id: int = int(target_id_variant)
		if active_targets.has(target_id):
			continue
		var target_variant: Variant = _tracked_targets.get(target_id, null)
		if target_variant is Node3D and is_instance_valid(target_variant):
			stale_targets.append(target_variant)
		_target_alpha_by_id.erase(target_id)

	if not stale_targets.is_empty():
		applier.restore_original_materials(stale_targets)

	_tracked_targets = active_targets.duplicate()

func _is_supported_target(target_variant: Variant) -> bool:
	if target_variant is MeshInstance3D:
		var mesh_target: MeshInstance3D = target_variant as MeshInstance3D
		return mesh_target != null and is_instance_valid(mesh_target)
	if target_variant is CSGShape3D:
		var csg_target: CSGShape3D = target_variant as CSGShape3D
		return csg_target != null and is_instance_valid(csg_target)
	return false
