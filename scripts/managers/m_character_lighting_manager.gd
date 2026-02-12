@icon("res://assets/editor_icons/icn_manager.svg")
extends "res://scripts/interfaces/i_character_lighting_manager.gd"
class_name M_CharacterLightingManager

const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_STATE_UTILS := preload("res://scripts/state/utils/u_state_utils.gd")
const U_ECS_UTILS := preload("res://scripts/utils/ecs/u_ecs_utils.gd")
const U_CHARACTER_LIGHTING_BLEND_MATH := preload("res://scripts/utils/lighting/u_character_lighting_blend_math.gd")
const U_CHARACTER_LIGHTING_MATERIAL_APPLIER := preload("res://scripts/utils/lighting/u_character_lighting_material_applier.gd")
const U_SCENE_SELECTORS := preload("res://scripts/state/selectors/u_scene_selectors.gd")
const U_NAVIGATION_SELECTORS := preload("res://scripts/state/selectors/u_navigation_selectors.gd")
const SERVICE_NAME := StringName("character_lighting_manager")
const STATE_SERVICE := StringName("state_store")
const SCENE_SERVICE := StringName("scene_manager")
const ECS_SERVICE := StringName("ecs_manager")
const TAG_CHARACTER := StringName("character")
const ACTION_SCENE_SWAPPED := StringName("scene/swapped")
const SCENE_SLICE := StringName("scene")
const NAVIGATION_SLICE := StringName("navigation")
const GAMEPLAY_SHELL := StringName("gameplay")
const ACTIVE_SCENE_CONTAINER_NAME := "ActiveSceneContainer"
const LIGHTING_NODE_NAME := "Lighting"
const SETTINGS_NODE_NAME := "CharacterLightingSettings"
const INFLUENCE_ENTER_THRESHOLD := 0.02
const INFLUENCE_EXIT_THRESHOLD := 0.01
const DEFAULT_PROFILE := {
	"tint": Color(1.0, 1.0, 1.0, 1.0),
	"intensity": 1.0,
	"blend_smoothing": 0.15,
}

@export var state_store: I_StateStore = null
@export var scene_manager: I_SceneManager = null
@export var ecs_manager: Node = null

var _scene_default_profile: Resource = null
var _scene_default_profile_resolved: Dictionary = DEFAULT_PROFILE.duplicate(true)
var _zones: Array[Node] = []
var _character_entities: Array[Node] = []
var _registered_zones: Array[Node] = []
var _is_enabled: bool = true
var _state_store: I_StateStore = null
var _scene_manager: I_SceneManager = null
var _ecs_manager: Node = null
var _material_applier := U_CHARACTER_LIGHTING_MATERIAL_APPLIER.new()
var _scene_cache_dirty: bool = true
var _store_action_connected: bool = false
var _manual_scene_default_profile: bool = false
var _character_lighting_history: Dictionary = {} # character instance_id -> {tint, intensity}
var _character_zone_hysteresis: Dictionary = {} # character instance_id -> {zone_key: is_active}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_resolve_dependencies()
	_connect_store_action_signal()
	var existing := U_SERVICE_LOCATOR.try_get_service(SERVICE_NAME)
	if existing != self:
		U_SERVICE_LOCATOR.register(SERVICE_NAME, self)
	_scene_cache_dirty = true

func _exit_tree() -> void:
	_disconnect_store_action_signal()
	_material_applier.restore_all_materials()
	_clear_all_runtime_state()
	_registered_zones.clear()
	_zones.clear()
	_character_entities.clear()
	_state_store = null
	_scene_manager = null
	_ecs_manager = null

func set_scene_default_profile(profile: Resource) -> void:
	_scene_default_profile = profile
	_manual_scene_default_profile = profile != null
	_scene_default_profile_resolved = _resolve_profile_values(profile)
	_scene_cache_dirty = false

func register_zone(zone: Node) -> void:
	if zone == null:
		return
	if _registered_zones.has(zone):
		return
	_registered_zones.append(zone)
	_scene_cache_dirty = true

func unregister_zone(zone: Node) -> void:
	if zone == null:
		return
	_registered_zones.erase(zone)
	_scene_cache_dirty = true

func refresh_scene_bindings() -> void:
	_scene_cache_dirty = true
	_clear_all_runtime_state()
	_refresh_scene_cache()

func set_character_lighting_enabled(enabled: bool) -> void:
	_is_enabled = enabled

func _physics_process(_delta: float) -> void:
	_resolve_dependencies()
	_connect_store_action_signal()

	if not _is_enabled:
		_material_applier.restore_all_materials()
		_clear_all_runtime_state()
		return

	if _scene_cache_dirty:
		_refresh_scene_cache()

	_prune_invalid_zones()
	_update_character_entities()

	if _is_transition_blocked():
		_material_applier.restore_all_materials()
		_clear_all_runtime_state()
		return

	_apply_lighting_to_characters()

func _prune_invalid_zones() -> void:
	var active: Array[Node] = []
	for zone in _zones:
		if zone == null:
			continue
		if not is_instance_valid(zone):
			continue
		active.append(zone)
	_zones = active

func _resolve_dependencies() -> void:
	if state_store != null and is_instance_valid(state_store):
		_state_store = state_store
	elif _state_store == null or not is_instance_valid(_state_store):
		_state_store = U_STATE_UTILS.try_get_store(self)
		if _state_store == null:
			_state_store = U_SERVICE_LOCATOR.try_get_service(STATE_SERVICE) as I_StateStore

	if scene_manager != null and is_instance_valid(scene_manager):
		_scene_manager = scene_manager
	elif _scene_manager == null or not is_instance_valid(_scene_manager):
		_scene_manager = U_SERVICE_LOCATOR.try_get_service(SCENE_SERVICE) as I_SceneManager

	if ecs_manager != null and is_instance_valid(ecs_manager):
		_ecs_manager = ecs_manager
	elif _ecs_manager == null or not is_instance_valid(_ecs_manager):
		_ecs_manager = U_ECS_UTILS.get_manager(self)
		if _ecs_manager == null:
			_ecs_manager = U_SERVICE_LOCATOR.try_get_service(ECS_SERVICE)

func _connect_store_action_signal() -> void:
	if _store_action_connected:
		return
	if _state_store == null:
		return
	if not _state_store.has_signal("action_dispatched"):
		return
	_state_store.action_dispatched.connect(_on_action_dispatched)
	_store_action_connected = true

func _disconnect_store_action_signal() -> void:
	if not _store_action_connected:
		return
	if _state_store != null and _state_store.has_signal("action_dispatched"):
		if _state_store.action_dispatched.is_connected(_on_action_dispatched):
			_state_store.action_dispatched.disconnect(_on_action_dispatched)
	_store_action_connected = false

func _on_action_dispatched(action: Dictionary) -> void:
	var action_type: Variant = action.get("type", StringName(""))
	if action_type != ACTION_SCENE_SWAPPED:
		return
	_scene_cache_dirty = true

func _refresh_scene_cache() -> void:
	var discovered_zones := _discover_scene_zones()
	var merged: Array[Node] = []
	for zone in _registered_zones:
		if zone == null or not is_instance_valid(zone):
			continue
		if not merged.has(zone):
			merged.append(zone)
	for zone in discovered_zones:
		if zone == null or not is_instance_valid(zone):
			continue
		if not merged.has(zone):
			merged.append(zone)
	_zones = merged

	if not _manual_scene_default_profile:
		_scene_default_profile = _discover_scene_default_profile()
	_scene_default_profile_resolved = _resolve_profile_values(_scene_default_profile)
	_scene_cache_dirty = false

func _discover_scene_zones() -> Array[Node]:
	var active_scene := _get_active_scene_root()
	if active_scene == null:
		return []
	var lighting := active_scene.get_node_or_null(LIGHTING_NODE_NAME)
	if lighting == null:
		return []
	return _collect_zones_recursive(lighting)

func _collect_zones_recursive(node: Node) -> Array[Node]:
	var found: Array[Node] = []
	if node.has_method("get_influence_weight") and node.has_method("get_zone_metadata"):
		found.append(node)
	for child in node.get_children():
		if child is Node:
			var nested := _collect_zones_recursive(child as Node)
			for nested_zone in nested:
				if not found.has(nested_zone):
					found.append(nested_zone)
	return found

func _discover_scene_default_profile() -> Resource:
	var active_scene := _get_active_scene_root()
	if active_scene == null:
		return null
	var lighting := active_scene.get_node_or_null(LIGHTING_NODE_NAME)
	if lighting == null:
		return null
	var settings := lighting.get_node_or_null(SETTINGS_NODE_NAME)
	if settings == null:
		return null

	if "default_profile" in settings:
		var default_profile_variant: Variant = settings.get("default_profile")
		if default_profile_variant is Resource:
			return default_profile_variant as Resource

	if "profile" in settings:
		var profile_variant: Variant = settings.get("profile")
		if profile_variant is Resource:
			return profile_variant as Resource

	if settings.has_method("get_default_profile"):
		var resolved_variant: Variant = settings.call("get_default_profile")
		if resolved_variant is Resource:
			return resolved_variant as Resource
	return null

func _get_active_scene_root() -> Node:
	var container := _find_active_scene_container()
	if container == null:
		return null
	var children := container.get_children()
	for child_variant in children:
		if child_variant is Node:
			var child := child_variant as Node
			if is_instance_valid(child):
				return child
	return null

func _find_active_scene_container() -> Node:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return null

	var scoped_container := _find_scoped_active_scene_container()
	if scoped_container != null:
		return scoped_container

	return tree.root.find_child(ACTIVE_SCENE_CONTAINER_NAME, true, false)

func _find_scoped_active_scene_container() -> Node:
	var current: Node = self
	while current != null:
		var by_path := current.get_node_or_null("GameViewportContainer/GameViewport/ActiveSceneContainer")
		if by_path != null:
			return by_path
		var by_name := current.get_node_or_null(ACTIVE_SCENE_CONTAINER_NAME)
		if by_name != null:
			return by_name
		current = current.get_parent()
	return null

func _resolve_profile_values(profile: Resource) -> Dictionary:
	if profile != null and profile.has_method("get_resolved_values"):
		var resolved_variant: Variant = profile.call("get_resolved_values")
		if resolved_variant is Dictionary:
			var resolved := resolved_variant as Dictionary
			var blended := U_CHARACTER_LIGHTING_BLEND_MATH.blend_zone_profiles([], resolved)
			blended.erase("sources")
			return blended
	var fallback := U_CHARACTER_LIGHTING_BLEND_MATH.blend_zone_profiles([], DEFAULT_PROFILE)
	fallback.erase("sources")
	return fallback

func _update_character_entities() -> void:
	var discovered := _discover_character_entities()

	for previous in _character_entities:
		if previous == null:
			continue
		if not is_instance_valid(previous):
			continue
		if discovered.has(previous):
			continue
		_material_applier.restore_character_materials(previous)
		_clear_character_runtime_state(previous)

	_character_entities = discovered
	_prune_character_runtime_state(_collect_live_character_ids(discovered))

func _discover_character_entities() -> Array[Node]:
	var resolved: Array[Node] = []
	if _ecs_manager == null:
		return resolved
	if not _ecs_manager.has_method("get_entities_by_tag"):
		return resolved

	var entities_variant: Variant = _ecs_manager.call("get_entities_by_tag", TAG_CHARACTER)
	if not (entities_variant is Array):
		return resolved

	var entities := entities_variant as Array
	for entity_variant in entities:
		if not (entity_variant is Node):
			continue
		var entity := entity_variant as Node
		if entity == null or not is_instance_valid(entity):
			continue
		resolved.append(entity)
	return resolved

func _apply_lighting_to_characters() -> void:
	for character in _character_entities:
		var character_node := character as Node
		if character_node == null:
			continue
		if not is_instance_valid(character_node):
			continue
		if not (character_node is Node3D):
			_material_applier.restore_character_materials(character_node)
			_clear_character_runtime_state(character_node)
			continue

		var character_node_3d := character_node as Node3D
		var character_id: int = character_node.get_instance_id()
		var body_node := _find_character_body_node(character_node_3d)
		var world_position: Vector3 = _resolve_sampling_position(character_node_3d, body_node)
		var zone_inputs: Array = []
		var observed_zone_keys: Array[String] = []
		for zone in _zones:
			if zone == null or not is_instance_valid(zone):
				continue
			var metadata_variant: Variant = zone.call("get_zone_metadata")
			if not (metadata_variant is Dictionary):
				continue
			var metadata := metadata_variant as Dictionary
			var stable_key := _resolve_zone_stable_key(metadata)
			if not stable_key.is_empty():
				observed_zone_keys.append(stable_key)

			var influence_variant: Variant = zone.call("get_influence_weight", world_position)
			var influence_raw: float = _to_float(influence_variant, 0.0)
			var influence: float = _apply_influence_hysteresis(character_id, stable_key, influence_raw)
			if influence <= 0.0:
				continue
			zone_inputs.append({
				"zone_id": metadata.get("zone_id", StringName("")),
				"priority": int(metadata.get("priority", 0)),
				"weight": influence,
				"profile": metadata.get("profile", {}),
			})
		_prune_character_zone_hysteresis(character_id, observed_zone_keys)

		var blended := U_CHARACTER_LIGHTING_BLEND_MATH.blend_zone_profiles(
			zone_inputs,
			_scene_default_profile_resolved
		)
		var stabilized := _apply_temporal_smoothing(character_id, blended)
		var effective_tint: Color = stabilized.get("tint", Color(1.0, 1.0, 1.0, 1.0))
		var effective_intensity: float = _to_float(stabilized.get("intensity", 1.0), 1.0)
		_material_applier.apply_character_lighting(
			character_node,
			Color(1.0, 1.0, 1.0, 1.0),
			effective_tint,
			effective_intensity
		)

func _is_transition_blocked() -> bool:
	if _state_store != null:
		var scene_slice: Dictionary = _state_store.get_slice(SCENE_SLICE)
		if U_SCENE_SELECTORS.is_transitioning(scene_slice):
			return true
		var scene_stack: Array = U_SCENE_SELECTORS.get_scene_stack(scene_slice)
		if not scene_stack.is_empty():
			return true

		var navigation_slice: Dictionary = _state_store.get_slice(NAVIGATION_SLICE)
		var shell: StringName = U_NAVIGATION_SELECTORS.get_shell(navigation_slice)
		if shell != GAMEPLAY_SHELL:
			return true

	if _scene_manager != null and _scene_manager.is_transitioning():
		return true

	return false

func _to_float(value: Variant, fallback: float) -> float:
	if value is float:
		return value
	if value is int:
		return float(value)
	return fallback

func _resolve_zone_stable_key(metadata: Dictionary) -> String:
	var stable_key_variant: Variant = metadata.get("stable_key", "")
	if stable_key_variant is String:
		var stable_key := stable_key_variant as String
		if not stable_key.is_empty():
			return stable_key
	elif stable_key_variant is StringName:
		var stable_name := stable_key_variant as StringName
		if not stable_name.is_empty():
			return String(stable_name)

	var zone_id_variant: Variant = metadata.get("zone_id", StringName(""))
	if zone_id_variant is StringName:
		var zone_id_name := zone_id_variant as StringName
		if not zone_id_name.is_empty():
			return String(zone_id_name)
	elif zone_id_variant is String:
		var zone_id := zone_id_variant as String
		if not zone_id.is_empty():
			return zone_id

	return ""

func _apply_influence_hysteresis(character_id: int, zone_key: String, raw_influence: float) -> float:
	var clamped_influence := clampf(raw_influence, 0.0, 1.0)
	if zone_key.is_empty():
		return clamped_influence

	var state_variant: Variant = _character_zone_hysteresis.get(character_id, {})
	var state: Dictionary = {}
	if state_variant is Dictionary:
		state = state_variant as Dictionary

	var was_active := bool(state.get(zone_key, false))
	var is_active: bool = was_active
	if was_active:
		is_active = clamped_influence >= INFLUENCE_EXIT_THRESHOLD
	else:
		is_active = clamped_influence >= INFLUENCE_ENTER_THRESHOLD

	state[zone_key] = is_active
	_character_zone_hysteresis[character_id] = state

	if is_active:
		return clamped_influence
	return 0.0

func _prune_character_zone_hysteresis(character_id: int, observed_zone_keys: Array[String]) -> void:
	var state_variant: Variant = _character_zone_hysteresis.get(character_id, {})
	if not (state_variant is Dictionary):
		return
	var state := state_variant as Dictionary
	var pruned: Dictionary = {}
	for key in observed_zone_keys:
		if state.has(key):
			pruned[key] = state[key]
	_character_zone_hysteresis[character_id] = pruned

func _apply_temporal_smoothing(character_id: int, blended: Dictionary) -> Dictionary:
	var target_tint: Color = blended.get("tint", Color(1.0, 1.0, 1.0, 1.0))
	var target_intensity: float = _to_float(blended.get("intensity", 1.0), 1.0)
	var smoothing: float = clampf(_to_float(blended.get("blend_smoothing", 0.0), 0.0), 0.0, 1.0)

	var previous_variant: Variant = _character_lighting_history.get(character_id, null)
	if previous_variant is Dictionary:
		var previous := previous_variant as Dictionary
		var previous_tint: Color = target_tint
		var previous_tint_variant: Variant = previous.get("tint", target_tint)
		if previous_tint_variant is Color:
			previous_tint = previous_tint_variant as Color
		var previous_intensity: float = _to_float(previous.get("intensity", target_intensity), target_intensity)
		var blend_alpha := clampf(1.0 - smoothing, 0.0, 1.0)
		target_tint = previous_tint.lerp(target_tint, blend_alpha)
		target_intensity = lerpf(previous_intensity, target_intensity, blend_alpha)

	_character_lighting_history[character_id] = {
		"tint": target_tint,
		"intensity": target_intensity,
	}
	return {
		"tint": target_tint,
		"intensity": target_intensity,
	}

func _collect_live_character_ids(characters: Array[Node]) -> Dictionary:
	var ids: Dictionary = {}
	for character in characters:
		if character == null:
			continue
		if not is_instance_valid(character):
			continue
		ids[character.get_instance_id()] = true
	return ids

func _prune_character_runtime_state(live_character_ids: Dictionary) -> void:
	var stale_history: Array[int] = []
	for key in _character_lighting_history.keys():
		var character_id := int(key)
		if live_character_ids.has(character_id):
			continue
		stale_history.append(character_id)
	for character_id in stale_history:
		_character_lighting_history.erase(character_id)

	var stale_hysteresis: Array[int] = []
	for key in _character_zone_hysteresis.keys():
		var character_id := int(key)
		if live_character_ids.has(character_id):
			continue
		stale_hysteresis.append(character_id)
	for character_id in stale_hysteresis:
		_character_zone_hysteresis.erase(character_id)

func _clear_character_runtime_state(character_node: Node) -> void:
	if character_node == null:
		return
	var character_id := character_node.get_instance_id()
	_character_lighting_history.erase(character_id)
	_character_zone_hysteresis.erase(character_id)

func _clear_all_runtime_state() -> void:
	_character_lighting_history.clear()
	_character_zone_hysteresis.clear()

func _resolve_sampling_position(character_node: Node3D, body_node: CharacterBody3D) -> Vector3:
	if body_node != null and is_instance_valid(body_node):
		return body_node.global_position
	return character_node.global_position

func _find_character_body_node(character_node: Node3D) -> CharacterBody3D:
	if character_node is CharacterBody3D:
		return character_node as CharacterBody3D

	var direct_body := character_node.get_node_or_null("Player_Body")
	if direct_body is CharacterBody3D:
		return direct_body as CharacterBody3D

	var recursive_body := character_node.find_child("Player_Body", true, false)
	if recursive_body is CharacterBody3D:
		return recursive_body as CharacterBody3D

	var components := character_node.get_node_or_null("Components")
	if components == null:
		return null

	for component_variant in components.get_children():
		if not (component_variant is Node):
			continue
		var component := component_variant as Node
		if not component.has_method("get_character_body"):
			continue
		var body_variant: Variant = component.call("get_character_body")
		if body_variant is CharacterBody3D:
			var body_node := body_variant as CharacterBody3D
			if body_node != null and is_instance_valid(body_node):
				return body_node

	return null
