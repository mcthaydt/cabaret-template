@icon("res://assets/editor_icons/icn_system.svg")
extends BaseECSSystem
class_name S_AINavigationSystem

const C_AI_BRAIN_COMPONENT := preload("res://scripts/ecs/components/c_ai_brain_component.gd")
const C_INPUT_COMPONENT := preload("res://scripts/ecs/components/c_input_component.gd")
const C_MOVEMENT_COMPONENT := preload("res://scripts/ecs/components/c_movement_component.gd")
const U_AI_TASK_STATE_KEYS := preload("res://scripts/utils/ai/u_ai_task_state_keys.gd")
const U_ECS_UTILS := preload("res://scripts/utils/ecs/u_ecs_utils.gd")

const BRAIN_COMPONENT_TYPE := C_AI_BRAIN_COMPONENT.COMPONENT_TYPE
const INPUT_COMPONENT_TYPE := C_INPUT_COMPONENT.COMPONENT_TYPE
const MOVEMENT_COMPONENT_TYPE := C_MOVEMENT_COMPONENT.COMPONENT_TYPE
const DEFAULT_ARRIVAL_THRESHOLD := 0.5

@export var debug_ai_navigation_logging: bool = false
@export var debug_ai_render_probe_logging: bool = false
@export_range(0.05, 5.0, 0.05) var debug_log_interval_sec: float = 0.25
@export var debug_entity_id: StringName = StringName("patrol_drone")
@export_range(0.0, 1.0, 0.05) var navigation_throttle_interval: float = 0.1

var _debug_log_cooldowns: Dictionary = {}
var _empty_query_log_cooldown_sec: float = 0.0
var _nav_timer_by_entity: Dictionary = {}

func _init() -> void:
	execution_priority = -5

func process_tick(delta: float) -> void:
	_tick_debug_log_cooldowns(delta)
	var entities: Array = query_entities([
		BRAIN_COMPONENT_TYPE,
		INPUT_COMPONENT_TYPE,
		MOVEMENT_COMPONENT_TYPE,
	])
	if entities.is_empty():
		_debug_log_empty_navigation_query()
		return

	for entity_query_variant in entities:
		if entity_query_variant == null or not (entity_query_variant is Object):
			continue
		var entity_query: Object = entity_query_variant as Object
		if not entity_query.has_method("get_component"):
			continue

		var entity_id: StringName = _resolve_entity_id(entity_query)

		# Per-entity throttle: skip direction computation if interval hasn't elapsed
		if navigation_throttle_interval > 0.0:
			var accumulated: float = float(_nav_timer_by_entity.get(entity_id, 0.0))
			accumulated += delta
			_nav_timer_by_entity[entity_id] = accumulated
			if accumulated < navigation_throttle_interval:
				continue  # keep last move_vector set on input component
			_nav_timer_by_entity[entity_id] = 0.0

		var input_component_variant: Variant = entity_query.call("get_component", INPUT_COMPONENT_TYPE)
		if not (input_component_variant is C_InputComponent):
			_debug_log_navigation(entity_id, "skip: missing C_InputComponent", entity_query)
			continue
		var input_component: C_InputComponent = input_component_variant as C_InputComponent

		var brain_component_variant: Variant = entity_query.call("get_component", BRAIN_COMPONENT_TYPE)
		if brain_component_variant == null or not (brain_component_variant is Object):
			input_component.set_move_vector(Vector2.ZERO)
			_debug_log_navigation(entity_id, "move_vector=ZERO reason=missing C_AIBrainComponent", entity_query)
			continue

		var task_state_variant: Variant = (brain_component_variant as Object).get("task_state")
		if not (task_state_variant is Dictionary):
			input_component.set_move_vector(Vector2.ZERO)
			_debug_log_navigation(entity_id, "move_vector=ZERO reason=task_state is not Dictionary", entity_query)
			continue
		var task_state: Dictionary = task_state_variant as Dictionary
		var move_target_source: String = str(task_state.get(U_AI_TASK_STATE_KEYS.MOVE_TARGET_SOURCE, ""))
		var move_target_reason: String = str(task_state.get(U_AI_TASK_STATE_KEYS.MOVE_TARGET_RESOLUTION_REASON, ""))
		var move_target_used_fallback: bool = bool(task_state.get(U_AI_TASK_STATE_KEYS.MOVE_TARGET_USED_FALLBACK, false))

		var target_variant: Variant = task_state.get(U_AI_TASK_STATE_KEYS.MOVE_TARGET, null)
		if not (target_variant is Vector3):
			input_component.set_move_vector(Vector2.ZERO)
			_debug_log_navigation(
				entity_id,
				"move_vector=ZERO reason=missing %s source=%s resolution_reason=%s fallback=%s"
				% [str(U_AI_TASK_STATE_KEYS.MOVE_TARGET), move_target_source, move_target_reason, str(move_target_used_fallback)],
				entity_query
			)
			continue
		var target_position: Vector3 = target_variant as Vector3
		var arrival_threshold: float = _resolve_arrival_threshold(
			task_state.get(U_AI_TASK_STATE_KEYS.ARRIVAL_THRESHOLD, DEFAULT_ARRIVAL_THRESHOLD)
		)

		var movement_component_variant: Variant = entity_query.call("get_component", MOVEMENT_COMPONENT_TYPE)
		if not (movement_component_variant is C_MovementComponent):
			input_component.set_move_vector(Vector2.ZERO)
			_debug_log_navigation(entity_id, "move_vector=ZERO reason=missing C_MovementComponent", entity_query)
			continue
		var movement_component: C_MovementComponent = movement_component_variant as C_MovementComponent

		var body: CharacterBody3D = movement_component.get_character_body()
		if body == null:
			_debug_log_navigation(entity_id, "skip: movement body is null", entity_query, movement_component)
			continue

		var current_position: Vector3 = body.global_position
		var delta_xz := Vector2(target_position.x - current_position.x, target_position.z - current_position.z)
		if delta_xz.length() <= arrival_threshold:
			input_component.set_move_vector(Vector2.ZERO)
			_debug_log_navigation(
				entity_id,
				"move_vector=ZERO reason=target reached target=%s current=%s threshold=%.3f"
				% [str(target_position), str(current_position), arrival_threshold],
				entity_query,
				movement_component
			)
			continue

		var world_direction := Vector3(delta_xz.x, 0.0, delta_xz.y).normalized()
		var move_vector := Vector2(world_direction.x, world_direction.z)
		if move_vector.length() > 1.0:
			move_vector = move_vector.normalized()
		input_component.set_move_vector(move_vector)
		_debug_log_navigation(
			entity_id,
			"move_vector=%s target=%s current=%s threshold=%.3f source=%s resolution_reason=%s fallback=%s"
			% [
				str(move_vector),
				str(target_position),
				str(current_position),
				arrival_threshold,
				move_target_source,
				move_target_reason,
				str(move_target_used_fallback),
			],
			entity_query,
			movement_component
		)

func _resolve_arrival_threshold(value: Variant) -> float:
	if value is float or value is int:
		return maxf(float(value), 0.0)
	return DEFAULT_ARRIVAL_THRESHOLD

func _resolve_entity_id(entity_query: Object) -> StringName:
	if entity_query == null:
		return StringName()

	if entity_query.has_method("get_entity_id"):
		var id_variant: Variant = entity_query.call("get_entity_id")
		if id_variant is StringName:
			return id_variant as StringName
		if id_variant is String:
			var text: String = id_variant
			if not text.is_empty():
				return StringName(text)

	var entity_variant: Variant = entity_query.get("entity")
	if entity_variant is Node:
		return U_ECS_UTILS.get_entity_id(entity_variant as Node)

	return StringName()

func _tick_debug_log_cooldowns(delta: float) -> void:
	_empty_query_log_cooldown_sec = maxf(_empty_query_log_cooldown_sec - maxf(delta, 0.0), 0.0)
	if _debug_log_cooldowns.is_empty():
		return
	var step: float = maxf(delta, 0.0)
	for key_variant in _debug_log_cooldowns.keys():
		var cooldown: float = float(_debug_log_cooldowns.get(key_variant, 0.0))
		cooldown = maxf(cooldown - step, 0.0)
		_debug_log_cooldowns[key_variant] = cooldown

func _consume_debug_log_budget(entity_id: StringName) -> bool:
	if not debug_ai_navigation_logging:
		return false
	if debug_entity_id != StringName() and entity_id != debug_entity_id:
		return false
	var cooldown: float = float(_debug_log_cooldowns.get(entity_id, 0.0))
	if cooldown > 0.0:
		return false
	_debug_log_cooldowns[entity_id] = maxf(debug_log_interval_sec, 0.05)
	return true

func _debug_log_navigation(
	entity_id: StringName,
	message: String,
	entity_query: Object = null,
	movement_component: C_MovementComponent = null
) -> void:
	if not _consume_debug_log_budget(entity_id):
		return
	var render_probe: String = ""
	if debug_ai_render_probe_logging:
		render_probe = _build_render_probe(entity_query, movement_component)
	print("S_AINavigationSystem[entity=%s] %s%s" % [str(entity_id), message, render_probe])

func _debug_log_empty_navigation_query() -> void:
	if not debug_ai_navigation_logging:
		return
	if _empty_query_log_cooldown_sec > 0.0:
		return
	_empty_query_log_cooldown_sec = maxf(debug_log_interval_sec, 0.05)
	print("S_AINavigationSystem: query_entities([C_AIBrainComponent, C_InputComponent, C_MovementComponent]) returned 0 entities")

func _build_render_probe(entity_query: Object, movement_component: C_MovementComponent) -> String:
	var entity: Node = null
	var entity_path: String = "<null>"
	if entity_query != null:
		var entity_variant: Variant = entity_query.get("entity")
		if entity_variant is Node:
			entity = entity_variant as Node
	if entity != null and is_instance_valid(entity):
		entity_path = str(entity.get_path())

	var body: CharacterBody3D = null
	if movement_component != null:
		body = movement_component.get_character_body()
	if body == null:
		body = _find_character_body_recursive(entity)

	var body_visible: bool = false
	var body_visible_in_tree: bool = false
	var body_position: Vector3 = Vector3.ZERO
	if body != null and is_instance_valid(body):
		body_visible = body.visible
		body_visible_in_tree = body.is_visible_in_tree()
		body_position = body.global_position

	var visual_node: Node3D = _resolve_visual_node(entity, body)
	var visual_path: String = "<null>"
	var visual_type: String = "null"
	var visual_visible: bool = false
	var visual_visible_in_tree: bool = false
	var visual_transparency: Variant = "n/a"
	var visual_layers: Variant = "n/a"
	if visual_node != null and is_instance_valid(visual_node):
		visual_path = str(visual_node.get_path())
		visual_type = visual_node.get_class()
		visual_visible = visual_node.visible
		visual_visible_in_tree = visual_node.is_visible_in_tree()
		if visual_node is GeometryInstance3D:
			var geometry: GeometryInstance3D = visual_node as GeometryInstance3D
			visual_transparency = geometry.transparency
			visual_layers = geometry.layers

	return (
		" probe(entity_path=%s body_visible=%s body_visible_tree=%s body_pos=%s visual_path=%s visual_type=%s visual_visible=%s visual_visible_tree=%s visual_transparency=%s visual_layers=%s)"
		% [
			entity_path,
			str(body_visible),
			str(body_visible_in_tree),
			str(body_position),
			visual_path,
			visual_type,
			str(visual_visible),
			str(visual_visible_in_tree),
			str(visual_transparency),
			str(visual_layers),
		]
	)

func _resolve_visual_node(entity: Node, body: CharacterBody3D) -> Node3D:
	var search_root: Node = body
	if search_root == null:
		search_root = entity
	if search_root == null:
		return null

	var named_visual: Node = search_root.get_node_or_null("Visual")
	if named_visual is Node3D:
		return named_visual as Node3D
	return _find_first_geometry_recursive(search_root)

func _find_character_body_recursive(node: Node) -> CharacterBody3D:
	if node == null:
		return null
	if node is CharacterBody3D:
		return node as CharacterBody3D

	for child_variant in node.get_children():
		var child: Node = child_variant as Node
		if child == null:
			continue
		var found: CharacterBody3D = _find_character_body_recursive(child)
		if found != null:
			return found
	return null

func _find_first_geometry_recursive(node: Node) -> Node3D:
	if node == null:
		return null
	if node is MeshInstance3D:
		return node as MeshInstance3D
	if node is CSGShape3D:
		return node as CSGShape3D

	for child_variant in node.get_children():
		var child: Node = child_variant as Node
		if child == null:
			continue
		var found: Node3D = _find_first_geometry_recursive(child)
		if found != null:
			return found
	return null
