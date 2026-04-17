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
	var target_entries: Array[Dictionary] = _collect_target_entries()
	var all_detections: Array = get_components(DETECTION_COMPONENT_TYPE)
	if all_detections.is_empty():
		return

	var manager := get_manager()
	if manager == null:
		return

	for detection_variant in all_detections:
		if detection_variant == null or not (detection_variant is C_DetectionComponent):
			continue
		var detection: C_DetectionComponent = detection_variant as C_DetectionComponent

		var entity_root: Node = U_ECS_UTILS.find_entity_root(detection)
		if entity_root == null or not is_instance_valid(entity_root):
			continue

		var movement: C_MovementComponent = _find_movement_for_entity(manager, entity_root)
		if movement == null:
			continue

		_process_detection_for_component(entity_root, detection, movement, target_entries)

func _collect_target_entries() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var candidates: Array = query_entities(
		[MOVEMENT_COMPONENT_TYPE],
		[PLAYER_TAG_COMPONENT_TYPE]
	)
	for candidate_query_variant in candidates:
		if candidate_query_variant == null or not (candidate_query_variant is Object):
			continue
		var candidate_query: Object = candidate_query_variant as Object
		var movement_variant: Variant = candidate_query.call("get_component", MOVEMENT_COMPONENT_TYPE)
		if not (movement_variant is C_MOVEMENT_COMPONENT):
			continue
		var movement: C_MovementComponent = movement_variant
		var body: CharacterBody3D = movement.get_character_body()
		if body == null or not is_instance_valid(body):
			continue

		var entity_root: Node = null
		var entity_variant: Variant = candidate_query.get("entity")
		if entity_variant is Node:
			entity_root = U_ECS_UTILS.find_entity_root(entity_variant as Node)

		var entity_id: StringName = StringName("")
		var entity_instance_id: int = 0
		if entity_root != null:
			entity_id = U_ECS_UTILS.get_entity_id(entity_root)
			entity_instance_id = entity_root.get_instance_id()
		elif entity_variant is Node:
			entity_id = U_ECS_UTILS.get_entity_id(entity_variant as Node)
			entity_instance_id = (entity_variant as Node).get_instance_id()

		var tags: Array[StringName] = []
		if entity_root != null:
			tags = U_ECS_UTILS.get_entity_tags(entity_root)

		var has_player_tag: bool = false
		var player_tag_variant: Variant = candidate_query.call("get_component", PLAYER_TAG_COMPONENT_TYPE)
		if player_tag_variant is C_PLAYER_TAG_COMPONENT:
			has_player_tag = true

		results.append({
			"entity_id": entity_id,
			"entity_instance_id": entity_instance_id,
			"position": body.global_position,
			"tags": tags,
			"has_player_tag": has_player_tag,
		})
	return results

func _find_movement_for_entity(manager: I_ECSManager, entity_root: Node) -> C_MovementComponent:
	var entity_comps: Dictionary = manager.get_components_for_entity(entity_root)
	if entity_comps.is_empty():
		return null
	var movement_variant: Variant = entity_comps.get(MOVEMENT_COMPONENT_TYPE)
	if movement_variant is C_MovementComponent:
		return movement_variant as C_MovementComponent
	return null

func _process_detection_for_component(
	entity_root: Node,
	detection: C_DetectionComponent,
	movement: C_MovementComponent,
	target_entries: Array[Dictionary]
) -> void:
	var body: CharacterBody3D = movement.get_character_body()
	if body == null or not is_instance_valid(body):
		return

	var source_entity_id: StringName = U_ECS_UTILS.get_entity_id(entity_root)
	var source_entity_instance_id: int = entity_root.get_instance_id()

	var effective_radius: float = detection.detection_radius if not detection.is_player_in_range else detection.get_resolved_exit_radius()
	var nearest_target: Dictionary = _resolve_nearest_target(
		body.global_position,
		detection.detect_y_axis,
		effective_radius,
		detection.target_tag,
		target_entries,
		source_entity_id,
		source_entity_instance_id
	)
	var is_in_range: bool = bool(nearest_target.get("in_range", false))

	if is_in_range and not detection.is_player_in_range:
		detection.is_player_in_range = true
		detection.last_detected_player_entity_id = nearest_target.get("entity_id", StringName(""))
		var _dist: float = float(nearest_target.get("distance", 0.0))
		print("[DETECT] %s (%s/%s) → detected %s at dist %.1f" % [
			source_entity_id, detection.detection_role, detection.target_tag,
			detection.last_detected_player_entity_id, _dist])
		_dispatch_flag(detection.ai_flag_id, detection.enter_flag_value)
		_publish_enter_event(entity_root, detection, nearest_target)
		return

	if (not is_in_range) and detection.is_player_in_range:
		var _lost_id: StringName = detection.last_detected_player_entity_id
		detection.is_player_in_range = false
		detection.last_detected_player_entity_id = StringName("")
		var _exit_radius: float = detection.get_resolved_exit_radius()
		var _dist: float = float(nearest_target.get("distance", INF))
		print("[DETECT] %s (%s/%s) → lost %s (dist %.1f > exit_radius %.1f)" % [
			source_entity_id, detection.detection_role, detection.target_tag, _lost_id, _dist, _exit_radius])
		if detection.set_flag_on_exit:
			_dispatch_flag(detection.ai_flag_id, detection.exit_flag_value)

func _resolve_nearest_target(
	origin: Vector3,
	use_y_axis: bool,
	detection_radius: float,
	target_tag: StringName,
	target_entries: Array[Dictionary],
	source_entity_id: StringName,
	source_entity_instance_id: int
) -> Dictionary:
	var best_distance: float = INF
	var nearest_entity_id: StringName = StringName("")
	for entry_variant in target_entries:
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant as Dictionary
		if not _entry_matches_target(entry, target_tag):
			continue
		var entry_entity_id: StringName = entry.get("entity_id", StringName(""))
		var entry_entity_instance_id: int = int(entry.get("entity_instance_id", 0))
		if _is_same_entity(entry_entity_id, entry_entity_instance_id, source_entity_id, source_entity_instance_id):
			continue
		var player_position_variant: Variant = entry.get("position", null)
		if not (player_position_variant is Vector3):
			continue
		var player_position: Vector3 = player_position_variant as Vector3
		var distance: float = _distance(origin, player_position, use_y_axis)
		if distance >= best_distance:
			continue
		best_distance = distance
		nearest_entity_id = entry_entity_id

	return {
		"in_range": best_distance <= maxf(detection_radius, 0.0),
		"distance": best_distance,
		"entity_id": nearest_entity_id,
	}

func _is_same_entity(
	entry_entity_id: StringName,
	entry_entity_instance_id: int,
	source_entity_id: StringName,
	source_entity_instance_id: int
) -> bool:
	if source_entity_instance_id > 0 and entry_entity_instance_id > 0:
		return entry_entity_instance_id == source_entity_instance_id

	if source_entity_id != StringName("") and entry_entity_id != StringName(""):
		return entry_entity_id == source_entity_id

	return false

func _entry_matches_target(entry: Dictionary, target_tag: StringName) -> bool:
	if target_tag == StringName(""):
		return false
	if target_tag == StringName("player") and bool(entry.get("has_player_tag", false)):
		return true

	var tags_variant: Variant = entry.get("tags", [])
	if not (tags_variant is Array):
		return false
	for tag_variant in (tags_variant as Array):
		if StringName(str(tag_variant)) == target_tag:
			return true
	return false

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

func _publish_enter_event(entity_root: Node, detection: C_DetectionComponent, nearest_target: Dictionary) -> void:
	if detection.enter_event_name == StringName(""):
		return
	var payload: Dictionary = detection.enter_event_payload.duplicate(true)
	var source_entity_id: StringName = U_ECS_UTILS.get_entity_id(entity_root)
	payload["source_entity_id"] = source_entity_id
	payload["detected_player_entity_id"] = nearest_target.get("entity_id", StringName(""))
	U_ECSEventBus.publish(detection.enter_event_name, payload)

func _resolve_state_store() -> I_StateStore:
	_store = U_DependencyResolution.resolve_state_store(_store, state_store, self)
	return _store
