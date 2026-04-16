@icon("res://assets/editor_icons/icn_system.svg")
extends BaseECSSystem
class_name S_AIDetectionSystem

const C_DETECTION_COMPONENT := preload("res://scripts/ecs/components/c_detection_component.gd")
const C_MOVEMENT_COMPONENT := preload("res://scripts/ecs/components/c_movement_component.gd")
const C_PLAYER_TAG_COMPONENT := preload("res://scripts/ecs/components/c_player_tag_component.gd")
const U_ECS_UTILS := preload("res://scripts/utils/ecs/u_ecs_utils.gd")
const U_GAMEPLAY_ACTIONS := preload("res://scripts/state/actions/u_gameplay_actions.gd")

const DETECTION_COMPONENT_TYPE := C_DETECTION_COMPONENT.COMPONENT_TYPE
const MOVEMENT_COMPONENT_TYPE := C_MOVEMENT_COMPONENT.COMPONENT_TYPE
const PLAYER_TAG_COMPONENT_TYPE := C_PLAYER_TAG_COMPONENT.COMPONENT_TYPE

@export var state_store: I_StateStore = null

var _store: I_StateStore = null

func _init() -> void:
	execution_priority = -12

func get_phase() -> BaseECSSystem.SystemPhase:
	return BaseECSSystem.SystemPhase.PRE_PHYSICS

func process_tick(_delta: float) -> void:
	var player_entries: Array[Dictionary] = _collect_player_entries()
	var entities: Array = query_entities(
		[DETECTION_COMPONENT_TYPE, MOVEMENT_COMPONENT_TYPE]
	)
	if entities.is_empty():
		return

	for query_variant in entities:
		if query_variant == null or not (query_variant is Object):
			continue
		var query: Object = query_variant as Object
		var detection_variant: Variant = query.call("get_component", DETECTION_COMPONENT_TYPE)
		if not (detection_variant is C_DETECTION_COMPONENT):
			continue
		var movement_variant: Variant = query.call("get_component", MOVEMENT_COMPONENT_TYPE)
		if not (movement_variant is C_MOVEMENT_COMPONENT):
			continue

		var detection: C_DetectionComponent = detection_variant
		var movement: C_MovementComponent = movement_variant
		_process_detection(query, detection, movement, player_entries)

func _collect_player_entries() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var players: Array = query_entities(
		[PLAYER_TAG_COMPONENT_TYPE, MOVEMENT_COMPONENT_TYPE]
	)
	for player_query_variant in players:
		if player_query_variant == null or not (player_query_variant is Object):
			continue
		var player_query: Object = player_query_variant as Object
		var movement_variant: Variant = player_query.call("get_component", MOVEMENT_COMPONENT_TYPE)
		if not (movement_variant is C_MOVEMENT_COMPONENT):
			continue
		var movement: C_MovementComponent = movement_variant
		var body: CharacterBody3D = movement.get_character_body()
		if body == null or not is_instance_valid(body):
			continue

		var entity_id: StringName = StringName("")
		var entity_variant: Variant = player_query.get("entity")
		if entity_variant is Node:
			entity_id = U_ECS_UTILS.get_entity_id(entity_variant as Node)

		results.append({
			"entity_id": entity_id,
			"position": body.global_position,
		})
	return results

func _process_detection(
	query: Object,
	detection: C_DetectionComponent,
	movement: C_MovementComponent,
	player_entries: Array[Dictionary]
) -> void:
	var body: CharacterBody3D = movement.get_character_body()
	if body == null or not is_instance_valid(body):
		return

	var nearest_player: Dictionary = _resolve_nearest_player(
		body.global_position,
		detection.detect_y_axis,
		detection.detection_radius,
		player_entries
	)
	var is_in_range: bool = bool(nearest_player.get("in_range", false))

	if is_in_range and not detection.is_player_in_range:
		detection.is_player_in_range = true
		detection.last_detected_player_entity_id = nearest_player.get("entity_id", StringName(""))
		_dispatch_flag(detection.ai_flag_id, detection.enter_flag_value)
		_publish_enter_event(query, detection, nearest_player)
		return

	if (not is_in_range) and detection.is_player_in_range:
		detection.is_player_in_range = false
		detection.last_detected_player_entity_id = StringName("")
		if detection.set_flag_on_exit:
			_dispatch_flag(detection.ai_flag_id, detection.exit_flag_value)

func _resolve_nearest_player(
	origin: Vector3,
	use_y_axis: bool,
	detection_radius: float,
	player_entries: Array[Dictionary]
) -> Dictionary:
	var best_distance: float = INF
	var nearest_entity_id: StringName = StringName("")
	for entry_variant in player_entries:
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant as Dictionary
		var player_position_variant: Variant = entry.get("position", null)
		if not (player_position_variant is Vector3):
			continue
		var player_position: Vector3 = player_position_variant as Vector3
		var distance: float = _distance(origin, player_position, use_y_axis)
		if distance >= best_distance:
			continue
		best_distance = distance
		nearest_entity_id = entry.get("entity_id", StringName(""))

	return {
		"in_range": best_distance <= maxf(detection_radius, 0.0),
		"distance": best_distance,
		"entity_id": nearest_entity_id,
	}

func _distance(a: Vector3, b: Vector3, use_y_axis: bool) -> float:
	if use_y_axis:
		return a.distance_to(b)
	var offset_xz: Vector2 = Vector2(a.x - b.x, a.z - b.z)
	return offset_xz.length()

func _dispatch_flag(flag_id: StringName, flag_value: bool) -> void:
	if flag_id == StringName(""):
		return
	var store: I_StateStore = _resolve_state_store()
	if store == null:
		return
	store.dispatch(U_GAMEPLAY_ACTIONS.set_ai_demo_flag(flag_id, flag_value))

func _publish_enter_event(query: Object, detection: C_DetectionComponent, nearest_player: Dictionary) -> void:
	if detection.enter_event_name == StringName(""):
		return
	var payload: Dictionary = detection.enter_event_payload.duplicate(true)
	var source_entity_id: StringName = StringName("")
	var entity_variant: Variant = query.get("entity")
	if entity_variant is Node:
		source_entity_id = U_ECS_UTILS.get_entity_id(entity_variant as Node)
	payload["source_entity_id"] = source_entity_id
	payload["detected_player_entity_id"] = nearest_player.get("entity_id", StringName(""))
	U_ECSEventBus.publish(detection.enter_event_name, payload)

func _resolve_state_store() -> I_StateStore:
	_store = U_DependencyResolution.resolve_state_store(_store, state_store, self)
	return _store
