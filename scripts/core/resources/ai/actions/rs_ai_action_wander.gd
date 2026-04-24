@icon("res://assets/editor_icons/icn_resource.svg")
extends I_AIAction
class_name RS_AIActionWander

const MOVE_TARGET_COMPONENT_TYPE := StringName("C_MoveTargetComponent")
const U_AI_ACTION_POSITION_RESOLVER := preload("res://scripts/utils/ai/u_ai_action_position_resolver.gd")
const HOME_ANCHOR_META_KEY := &"ai_home_anchor"

@export var home_radius: float = 6.0
@export var arrival_threshold: float = 0.5

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _init() -> void:
	_rng.randomize()

func start(context: Dictionary, task_state: Dictionary) -> void:
	var entity: Node3D = context.get("entity", null) as Node3D
	if entity == null:
		push_error("RS_AIActionWander.start: missing entity in context.")
		_mark_completed(context, task_state)
		return

	var home_position: Vector3 = _resolve_home_anchor(entity, context)
	task_state[U_AITaskStateKeys.WANDER_HOME] = home_position

	var target_position: Vector3 = _sample_target(home_position)
	var resolved_arrival_threshold: float = maxf(arrival_threshold, 0.0)
	_set_move_target_component_target(context, target_position, resolved_arrival_threshold)
	task_state[U_AITaskStateKeys.MOVE_TARGET] = target_position
	task_state[U_AITaskStateKeys.ARRIVAL_THRESHOLD] = resolved_arrival_threshold
	task_state[U_AITaskStateKeys.COMPLETED] = false
	print("[ACTION] %s Wander → target (%.1f, %.1f, %.1f)" % [
		_resolve_entity_label(context), target_position.x, target_position.y, target_position.z])

func tick(_context: Dictionary, _task_state: Dictionary, _delta: float) -> void:
	pass

func is_complete(context: Dictionary, task_state: Dictionary) -> bool:
	if bool(task_state.get(U_AITaskStateKeys.COMPLETED, false)):
		return true

	var target_variant: Variant = task_state.get(U_AITaskStateKeys.MOVE_TARGET, null)
	if not (target_variant is Vector3):
		_clear_move_target_component(context)
		task_state[U_AITaskStateKeys.COMPLETED] = true
		return true

	var current_position_variant: Variant = _resolve_current_position(context)
	if not (current_position_variant is Vector3):
		_clear_move_target_component(context)
		task_state[U_AITaskStateKeys.COMPLETED] = true
		return true

	var resolved_arrival_threshold: float = maxf(
		float(task_state.get(U_AITaskStateKeys.ARRIVAL_THRESHOLD, arrival_threshold)),
		0.0
	)
	var target_position: Vector3 = target_variant as Vector3
	var current_position: Vector3 = current_position_variant as Vector3
	var offset_xz: Vector2 = Vector2(
		target_position.x - current_position.x,
		target_position.z - current_position.z
	)
	var arrived: bool = offset_xz.length() <= resolved_arrival_threshold
	if arrived:
		print("[ACTION] %s Wander arrived" % _resolve_entity_label(context))
		_clear_move_target_component(context)
		task_state[U_AITaskStateKeys.COMPLETED] = true
	return arrived

func _sample_target(home_position: Vector3) -> Vector3:
	var radius: float = maxf(home_radius, 0.0) * sqrt(_rng.randf())
	var angle: float = _rng.randf_range(0.0, TAU)
	var offset: Vector3 = Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
	return home_position + offset

func _resolve_home_anchor(entity: Node3D, context: Dictionary) -> Vector3:
	var stored_home_variant: Variant = null
	if entity.has_meta(HOME_ANCHOR_META_KEY):
		stored_home_variant = entity.get_meta(HOME_ANCHOR_META_KEY)
	if stored_home_variant is Vector3:
		return stored_home_variant as Vector3
	var home_position: Vector3 = entity.global_position
	var actor_position: Variant = U_AI_ACTION_POSITION_RESOLVER.resolve_actor_position(context)
	if actor_position is Vector3:
		home_position = actor_position as Vector3
	entity.set_meta(HOME_ANCHOR_META_KEY, home_position)
	return home_position

func _resolve_current_position(context: Dictionary) -> Variant:
	return U_AI_ACTION_POSITION_RESOLVER.resolve_actor_position(context)

func _mark_completed(context: Dictionary, task_state: Dictionary) -> void:
	_clear_move_target_component(context)
	task_state.erase(U_AITaskStateKeys.MOVE_TARGET)
	task_state.erase(U_AITaskStateKeys.ARRIVAL_THRESHOLD)
	task_state[U_AITaskStateKeys.COMPLETED] = true

func _set_move_target_component_target(
	context: Dictionary,
	target_position_value: Vector3,
	arrival_threshold_value: float
) -> bool:
	var move_target_component: Object = _resolve_move_target_component(context)
	if move_target_component == null:
		return false
	move_target_component.set("target_position", target_position_value)
	move_target_component.set("arrival_threshold", maxf(arrival_threshold_value, 0.0))
	move_target_component.set("is_active", true)
	return true

func _clear_move_target_component(context: Dictionary) -> void:
	var move_target_component: Object = _resolve_move_target_component(context)
	if move_target_component == null:
		return
	move_target_component.set("is_active", false)

func _resolve_move_target_component(context: Dictionary) -> Object:
	var components_variant: Variant = context.get("components", null)
	if not (components_variant is Dictionary):
		return null
	var components: Dictionary = components_variant as Dictionary
	var move_target_component_variant: Variant = components.get(MOVE_TARGET_COMPONENT_TYPE, null)
	if not (move_target_component_variant is Object):
		return null
	return move_target_component_variant as Object

func _resolve_entity_label(context: Dictionary) -> String:
	var entity: Node = context.get("entity", null) as Node
	if entity != null and is_instance_valid(entity):
		return str(entity.name)
	return "?"
