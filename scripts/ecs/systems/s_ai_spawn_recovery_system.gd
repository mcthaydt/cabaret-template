@icon("res://assets/editor_icons/icn_system.svg")
extends BaseECSSystem
class_name S_AISpawnRecoverySystem

const C_AI_BRAIN_COMPONENT := preload("res://scripts/ecs/components/c_ai_brain_component.gd")
const C_FLOATING_COMPONENT := preload("res://scripts/ecs/components/c_floating_component.gd")
const C_MOVEMENT_COMPONENT := preload("res://scripts/ecs/components/c_movement_component.gd")
const C_INPUT_COMPONENT := preload("res://scripts/ecs/components/c_input_component.gd")
const RS_AI_BRAIN_SETTINGS := preload("res://scripts/resources/ai/rs_ai_brain_settings.gd")
const I_SPAWN_MANAGER := preload("res://scripts/interfaces/i_spawn_manager.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")

const BRAIN_TYPE := C_AI_BRAIN_COMPONENT.COMPONENT_TYPE
const FLOATING_TYPE := C_FLOATING_COMPONENT.COMPONENT_TYPE
const MOVEMENT_TYPE := C_MOVEMENT_COMPONENT.COMPONENT_TYPE
const INPUT_TYPE := C_INPUT_COMPONENT.COMPONENT_TYPE

@export var debug_ai_spawn_recovery_logging: bool = false
@export_range(0.05, 5.0, 0.05) var debug_log_interval_sec: float = 0.25
@export var debug_entity_id: StringName = StringName("patrol_drone")
@export_range(0.0, 5.0, 0.1) var startup_grace_period_sec: float = 1.0

var _unsupported_since_by_entity: Dictionary = {}
var _cooldown_until_by_entity: Dictionary = {}
var _recovery_disabled_entities: Dictionary = {}
var _debug_log_cooldowns: Dictionary = {}
var _startup_elapsed: float = 0.0

func _init() -> void:
	execution_priority = 75

func process_tick(delta: float) -> void:
	_tick_debug_log_cooldowns(delta)

	if _startup_elapsed < startup_grace_period_sec:
		_startup_elapsed += maxf(delta, 0.0)
		return

	var manager := get_manager()
	if manager == null:
		return

	var spawn_manager := U_SERVICE_LOCATOR.try_get_service(StringName("spawn_manager")) as I_SPAWN_MANAGER
	if spawn_manager == null:
		if debug_ai_spawn_recovery_logging:
			_debug_log(StringName(""), "skip: spawn_manager unavailable")
		return

	var now: float = ECS_UTILS.get_current_time()
	var seen_entities: Dictionary = {}
	var entities := manager.query_entities([
		BRAIN_TYPE,
		FLOATING_TYPE,
		MOVEMENT_TYPE,
		INPUT_TYPE,
	])

	for entity_query in entities:
		var entity_id: StringName = _resolve_entity_id(entity_query)
		if entity_id == StringName():
			continue
		seen_entities[entity_id] = true

		if _recovery_disabled_entities.has(entity_id):
			continue

		var brain: C_AIBrainComponent = entity_query.get_component(BRAIN_TYPE)
		var floating: C_FloatingComponent = entity_query.get_component(FLOATING_TYPE)
		var movement: C_MovementComponent = entity_query.get_component(MOVEMENT_TYPE)
		var input_component: C_InputComponent = entity_query.get_component(INPUT_TYPE)
		if brain == null or floating == null or movement == null or input_component == null:
			_clear_runtime_state(entity_id)
			continue

		if not (brain.brain_settings is RS_AI_BRAIN_SETTINGS):
			_clear_runtime_state(entity_id)
			continue

		var brain_settings: RS_AIBrainSettings = brain.brain_settings as RS_AIBrainSettings
		var spawn_point_id: StringName = brain_settings.respawn_spawn_point_id
		if spawn_point_id == StringName():
			_clear_runtime_state(entity_id)
			continue

		var support_grace_time: float = 0.0
		if movement.settings != null:
			support_grace_time = maxf(movement.settings.support_grace_time, 0.0)
		var has_support: bool = floating.has_recent_support(now, support_grace_time)
		if has_support:
			_unsupported_since_by_entity.erase(entity_id)
			continue

		if not _unsupported_since_by_entity.has(entity_id):
			_unsupported_since_by_entity[entity_id] = now
		var unsupported_since: float = float(_unsupported_since_by_entity.get(entity_id, now))
		var unsupported_delay_sec: float = maxf(brain_settings.respawn_unsupported_delay_sec, 0.0)
		if now - unsupported_since < unsupported_delay_sec:
			continue

		var cooldown_until: float = float(_cooldown_until_by_entity.get(entity_id, 0.0))
		if now < cooldown_until:
			continue

		var entity_variant: Variant = entity_query.get("entity")
		var entity_node: Node = entity_variant as Node
		var scene_root: Node = _resolve_scene_root(entity_node)
		if scene_root == null:
			_set_recovery_cooldown(entity_id, brain_settings, now)
			_debug_log(entity_id, "skip: scene root missing for recovery")
			continue

		if not _spawn_point_exists(scene_root, spawn_point_id):
			push_error(
				"S_AISpawnRecoverySystem: spawn point '%s' missing for entity '%s' in scene '%s'; disabling recovery for this entity."
				% [spawn_point_id, entity_id, scene_root.name]
			)
			_recovery_disabled_entities[entity_id] = true
			continue

		var recovered: bool = spawn_manager.spawn_entity_at_point(scene_root, entity_id, spawn_point_id)
		if not recovered:
			_set_recovery_cooldown(entity_id, brain_settings, now)
			_debug_log(entity_id, "spawn_manager.spawn_entity_at_point failed")
			continue

		input_component.set_move_vector(Vector2.ZERO)
		var body: CharacterBody3D = movement.get_character_body()
		if body != null:
			body.velocity = Vector3.ZERO
		brain.task_state = {}

		_unsupported_since_by_entity.erase(entity_id)
		_set_recovery_cooldown(entity_id, brain_settings, now)
		_debug_log(
			entity_id,
			"recovered to spawn_point_id=%s unsupported_for=%.3fs"
			% [spawn_point_id, now - unsupported_since]
		)

	_prune_runtime_state(seen_entities)

func _set_recovery_cooldown(entity_id: StringName, brain_settings: RS_AIBrainSettings, now: float) -> void:
	var cooldown: float = maxf(brain_settings.respawn_recovery_cooldown_sec, 0.0)
	_cooldown_until_by_entity[entity_id] = now + cooldown

func _resolve_scene_root(entity: Node) -> Node:
	var current: Node = entity
	while current != null:
		var spawn_points_root: Node = current.get_node_or_null("Entities/SpawnPoints")
		if spawn_points_root != null:
			return current
		current = current.get_parent()

	if entity != null and entity.get_tree() != null:
		var current_scene: Node = entity.get_tree().current_scene
		if current_scene != null and current_scene.get_node_or_null("Entities/SpawnPoints") != null:
			return current_scene

	return null

func _spawn_point_exists(scene_root: Node, spawn_point_id: StringName) -> bool:
	if scene_root == null or spawn_point_id == StringName():
		return false

	var matches: Array = []
	_find_nodes_by_name(scene_root, spawn_point_id, matches)
	if matches.is_empty():
		return false
	return matches[0] is Node3D

func _find_nodes_by_name(node: Node, target_name: StringName, results: Array) -> void:
	if node == null:
		return
	if node.name == target_name:
		results.append(node)

	for child in node.get_children():
		var child_node := child as Node
		if child_node == null:
			continue
		_find_nodes_by_name(child_node, target_name, results)

func _resolve_entity_id(entity_query: Object) -> StringName:
	if entity_query == null:
		return StringName()

	if entity_query.has_method("get_entity_id"):
		var id_variant: Variant = entity_query.call("get_entity_id")
		if id_variant is StringName:
			return id_variant as StringName
		if id_variant is String:
			var id_text: String = id_variant
			if not id_text.is_empty():
				return StringName(id_text)

	var entity_variant: Variant = entity_query.get("entity")
	if entity_variant is Node:
		return ECS_UTILS.get_entity_id(entity_variant as Node)

	return StringName()

func _clear_runtime_state(entity_id: StringName) -> void:
	_unsupported_since_by_entity.erase(entity_id)
	_cooldown_until_by_entity.erase(entity_id)
	_recovery_disabled_entities.erase(entity_id)

func _prune_runtime_state(seen_entities: Dictionary) -> void:
	_prune_dictionary(_unsupported_since_by_entity, seen_entities)
	_prune_dictionary(_cooldown_until_by_entity, seen_entities)
	_prune_dictionary(_recovery_disabled_entities, seen_entities)

func _prune_dictionary(runtime_map: Dictionary, seen_entities: Dictionary) -> void:
	for key_variant in runtime_map.keys():
		if seen_entities.has(key_variant):
			continue
		runtime_map.erase(key_variant)

func _tick_debug_log_cooldowns(delta: float) -> void:
	if _debug_log_cooldowns.is_empty():
		return

	var step: float = maxf(delta, 0.0)
	for key_variant in _debug_log_cooldowns.keys():
		var cooldown: float = float(_debug_log_cooldowns.get(key_variant, 0.0))
		cooldown = maxf(cooldown - step, 0.0)
		_debug_log_cooldowns[key_variant] = cooldown

func _consume_debug_log_budget(entity_id: StringName) -> bool:
	if not debug_ai_spawn_recovery_logging:
		return false
	if debug_entity_id != StringName() and entity_id != debug_entity_id:
		return false

	var cooldown: float = float(_debug_log_cooldowns.get(entity_id, 0.0))
	if cooldown > 0.0:
		return false

	_debug_log_cooldowns[entity_id] = maxf(debug_log_interval_sec, 0.05)
	return true

func _debug_log(entity_id: StringName, message: String) -> void:
	if not _consume_debug_log_budget(entity_id):
		return
	print("S_AISpawnRecoverySystem[entity=%s] %s" % [str(entity_id), message])
