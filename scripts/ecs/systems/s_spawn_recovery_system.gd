@icon("res://assets/editor_icons/icn_system.svg")
extends BaseECSSystem
class_name S_SpawnRecoverySystem

const C_SPAWN_RECOVERY_COMPONENT := preload("res://scripts/ecs/components/c_spawn_recovery_component.gd")
const C_FLOATING_COMPONENT := preload("res://scripts/ecs/components/c_floating_component.gd")
const C_MOVEMENT_COMPONENT := preload("res://scripts/ecs/components/c_movement_component.gd")
const C_INPUT_COMPONENT := preload("res://scripts/ecs/components/c_input_component.gd")
const C_AI_BRAIN_COMPONENT := preload("res://scripts/demo/ecs/components/c_ai_brain_component.gd")
const C_PLAYER_TAG_COMPONENT := preload("res://scripts/ecs/components/c_player_tag_component.gd")
const RS_SPAWN_RECOVERY_SETTINGS := preload("res://scripts/core/resources/ecs/rs_spawn_recovery_settings.gd")
const I_SPAWN_MANAGER := preload("res://scripts/core/interfaces/i_spawn_manager.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_DEBUG_LOG_THROTTLE := preload("res://scripts/utils/debug/u_debug_log_throttle.gd")

const RECOVERY_TYPE := C_SPAWN_RECOVERY_COMPONENT.COMPONENT_TYPE
const FLOATING_TYPE := C_FLOATING_COMPONENT.COMPONENT_TYPE
const MOVEMENT_TYPE := C_MOVEMENT_COMPONENT.COMPONENT_TYPE
const INPUT_TYPE := C_INPUT_COMPONENT.COMPONENT_TYPE
const AI_BRAIN_TYPE := C_AI_BRAIN_COMPONENT.COMPONENT_TYPE
const PLAYER_TAG_TYPE := C_PLAYER_TAG_COMPONENT.COMPONENT_TYPE

@export var debug_spawn_recovery_logging: bool = false
@export_range(0.05, 5.0, 0.05) var debug_log_interval_sec: float = 0.25
@export var debug_entity_id: StringName = StringName("player")

var _startup_elapsed_by_entity: Dictionary = {}
var _unsupported_since_by_entity: Dictionary = {}
var _cooldown_until_by_entity: Dictionary = {}
var _recovery_disabled_entities: Dictionary = {}
var _debug_log_throttle: Variant = U_DEBUG_LOG_THROTTLE.new()

func _init() -> void:
	execution_priority = 75

func get_phase() -> BaseECSSystem.SystemPhase:
	return BaseECSSystem.SystemPhase.POST_PHYSICS

func process_tick(delta: float) -> void:
	_debug_log_throttle.tick(delta)

	var manager := get_manager()
	if manager == null:
		return

	var spawn_manager := U_SERVICE_LOCATOR.try_get_service(StringName("spawn_manager")) as I_SPAWN_MANAGER
	if spawn_manager == null:
		if debug_spawn_recovery_logging:
			_debug_log(StringName(""), "skip: spawn_manager unavailable")
		return

	var now: float = ECS_UTILS.get_current_time()
	var seen_entities: Dictionary = {}
	var entities := manager.query_entities(
		[RECOVERY_TYPE, FLOATING_TYPE, MOVEMENT_TYPE, INPUT_TYPE],
		[AI_BRAIN_TYPE, PLAYER_TAG_TYPE]
	)

	for entity_query in entities:
		var entity_id: StringName = _resolve_entity_id(entity_query)
		if entity_id == StringName():
			continue
		seen_entities[entity_id] = true

		if _recovery_disabled_entities.has(entity_id):
			continue

		var recovery_component: Variant = entity_query.get_component(RECOVERY_TYPE)
		var floating := entity_query.get_component(FLOATING_TYPE) as C_FloatingComponent
		var movement := entity_query.get_component(MOVEMENT_TYPE) as C_MovementComponent
		var input_component := entity_query.get_component(INPUT_TYPE) as C_InputComponent
		if recovery_component == null or floating == null or movement == null or input_component == null:
			_clear_runtime_state(entity_id)
			continue

		var settings_variant: Variant = recovery_component.get("settings")
		if settings_variant == null or not (settings_variant is RS_SPAWN_RECOVERY_SETTINGS):
			_clear_runtime_state(entity_id)
			continue
		var settings: Variant = settings_variant

		if not _startup_grace_elapsed(entity_id, delta, settings):
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
		var unsupported_delay_sec: float = maxf(float(settings.unsupported_delay_sec), 0.0)
		if now - unsupported_since < unsupported_delay_sec:
			continue

		var cooldown_until: float = float(_cooldown_until_by_entity.get(entity_id, 0.0))
		if now < cooldown_until:
			continue

		var entity_variant: Variant = entity_query.get("entity")
		var entity_node: Node = entity_variant as Node
		var scene_root: Node = _resolve_scene_root(entity_node)
		if scene_root == null:
			_set_recovery_cooldown(entity_id, settings, now)
			_debug_log(entity_id, "skip: scene root missing for recovery")
			continue

		var recovered: bool = false
		var is_player: bool = _is_player_entity(entity_id, entity_query, entity_node)
		var spawn_point_id: StringName = settings.spawn_point_id

		if is_player and spawn_point_id == StringName():
			recovered = spawn_manager.spawn_at_last_spawn(scene_root)
			if not recovered:
				_set_recovery_cooldown(entity_id, settings, now)
				_debug_log(entity_id, "spawn_manager.spawn_at_last_spawn failed")
				continue
		else:
			if spawn_point_id == StringName():
				_unsupported_since_by_entity.erase(entity_id)
				_cooldown_until_by_entity.erase(entity_id)
				continue

			if not _spawn_point_exists(scene_root, spawn_point_id):
				push_error(
					"S_SpawnRecoverySystem: spawn point '%s' missing for entity '%s' in scene '%s'; disabling recovery for this entity."
					% [spawn_point_id, entity_id, scene_root.name]
				)
				_recovery_disabled_entities[entity_id] = true
				continue

			recovered = spawn_manager.spawn_entity_at_point(scene_root, entity_id, spawn_point_id)
			if not recovered:
				_set_recovery_cooldown(entity_id, settings, now)
				_debug_log(entity_id, "spawn_manager.spawn_entity_at_point failed")
				continue

		input_component.set_move_vector(Vector2.ZERO)
		var body: CharacterBody3D = movement.get_character_body()
		if body != null:
			body.velocity = Vector3.ZERO

		var brain := entity_query.get_component(AI_BRAIN_TYPE) as C_AIBrainComponent
		_clear_ai_runtime_state(brain)

		_unsupported_since_by_entity.erase(entity_id)
		_set_recovery_cooldown(entity_id, settings, now)
		_debug_log(
			entity_id,
			"recovered unsupported_for=%.3fs spawn_point_id=%s player=%s"
			% [now - unsupported_since, spawn_point_id, str(is_player)]
		)

	_prune_runtime_state(seen_entities)

func _startup_grace_elapsed(entity_id: StringName, delta: float, settings: Variant) -> bool:
	var elapsed: float = float(_startup_elapsed_by_entity.get(entity_id, 0.0))
	elapsed += maxf(delta, 0.0)
	_startup_elapsed_by_entity[entity_id] = elapsed
	var startup_grace_period_sec: float = maxf(float(settings.startup_grace_period_sec), 0.0)
	return elapsed >= startup_grace_period_sec

func _set_recovery_cooldown(entity_id: StringName, settings: Variant, now: float) -> void:
	var cooldown: float = maxf(float(settings.recovery_cooldown_sec), 0.0)
	_cooldown_until_by_entity[entity_id] = now + cooldown

func _is_player_entity(entity_id: StringName, entity_query: Object, entity_node: Node) -> bool:
	if entity_id == StringName("player"):
		return true
	if entity_query != null:
		var player_tag := entity_query.get_component(PLAYER_TAG_TYPE) as C_PlayerTagComponent
		if player_tag != null:
			return true
	if entity_node != null:
		var tags: Array[StringName] = ECS_UTILS.get_entity_tags(entity_node)
		if tags.has(StringName("player")):
			return true
	return false

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
	_startup_elapsed_by_entity.erase(entity_id)
	_unsupported_since_by_entity.erase(entity_id)
	_cooldown_until_by_entity.erase(entity_id)
	_recovery_disabled_entities.erase(entity_id)

func _prune_runtime_state(seen_entities: Dictionary) -> void:
	_prune_dictionary(_startup_elapsed_by_entity, seen_entities)
	_prune_dictionary(_unsupported_since_by_entity, seen_entities)
	_prune_dictionary(_cooldown_until_by_entity, seen_entities)
	_prune_dictionary(_recovery_disabled_entities, seen_entities)

func _prune_dictionary(runtime_map: Dictionary, seen_entities: Dictionary) -> void:
	for key_variant in runtime_map.keys():
		if seen_entities.has(key_variant):
			continue
		runtime_map.erase(key_variant)

func _clear_ai_runtime_state(brain: C_AIBrainComponent) -> void:
	if brain == null:
		return

	# Reset BT runtime node state after recovery so movement/action state is rebuilt cleanly.
	brain.bt_state_bag = {}

	# Compatibility: clear legacy task-state fields only when present on the component.
	for property_variant in brain.get_property_list():
		if not (property_variant is Dictionary):
			continue
		var property: Dictionary = property_variant as Dictionary
		if str(property.get("name", "")) != "task_state":
			continue
		brain.set("task_state", {})
		break

func _consume_debug_log_budget(entity_id: StringName) -> bool:
	if not debug_spawn_recovery_logging:
		return false
	if debug_entity_id != StringName() and entity_id != debug_entity_id:
		return false
	return _debug_log_throttle.consume_budget(entity_id, maxf(debug_log_interval_sec, 0.05))

func _debug_log(entity_id: StringName, message: String) -> void:
	if not _consume_debug_log_budget(entity_id):
		return
	_debug_log_throttle.log_message("S_SpawnRecoverySystem[entity=%s] %s" % [str(entity_id), message])
