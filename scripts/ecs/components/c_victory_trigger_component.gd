@icon("res://assets/editor_icons/icn_component.svg")
extends BaseECSComponent
class_name C_VictoryTriggerComponent

const EVENT_VICTORY_ZONE_ENTERED := StringName("victory_zone_entered")

const COMPONENT_TYPE := StringName("C_VictoryTriggerComponent")
const PLAYER_TAG_COMPONENT := StringName("C_PlayerTagComponent")
const DEBUG_VICTORY_TRACE := true

enum VictoryType {
	LEVEL_COMPLETE = 0,
	GAME_COMPLETE = 1
}

@export var objective_id: StringName = StringName("")
@export var area_id: String = ""
@export var victory_type: VictoryType = VictoryType.LEVEL_COMPLETE
@export var trigger_once: bool = true
@export_node_path("Area3D") var area_path: NodePath

var is_triggered: bool = false

var _area: Area3D = null
var _player_inside: bool = false
var _last_body: Node3D = null

func _init() -> void:
	component_type = COMPONENT_TYPE

func _debug_log(message: String) -> void:
	if not DEBUG_VICTORY_TRACE:
		return
	print("[VictoryDebug][C_VictoryTriggerComponent] %s" % message)

func _victory_type_to_string(value: int) -> String:
	match value:
		VictoryType.LEVEL_COMPLETE:
			return "LEVEL_COMPLETE"
		VictoryType.GAME_COMPLETE:
			return "GAME_COMPLETE"
		_:
			return "UNKNOWN(%s)" % str(value)

func _ready() -> void:
	super._ready()
	_resolve_area()
	_debug_log(
		"ready objective_id=%s area_id=%s victory_type=%s trigger_once=%s is_triggered=%s instance_id=%s"
		% [
			str(objective_id),
			area_id,
			_victory_type_to_string(int(victory_type)),
			str(trigger_once),
			str(is_triggered),
			str(get_instance_id()),
		]
	)

func _exit_tree() -> void:
	if _area != null and is_instance_valid(_area):
		if _area.body_entered.is_connected(_on_body_entered):
			_area.body_entered.disconnect(_on_body_entered)
		if _area.body_exited.is_connected(_on_body_exited):
			_area.body_exited.disconnect(_on_body_exited)
	_area = null

func _resolve_area() -> void:
	if not area_path.is_empty():
		_area = get_node_or_null(area_path) as Area3D

	if _area == null:
		_area = _find_area_child()

	if _area == null:
		_area = Area3D.new()
		_area.name = "VictoryArea"
		add_child(_area)

	_configure_area()

func _find_area_child() -> Area3D:
	for child in get_children():
		var area := child as Area3D
		if area != null:
			return area
	return null

func _configure_area() -> void:
	if _area == null:
		return
	_area.monitoring = true
	_area.monitorable = true
	if not _area.body_entered.is_connected(_on_body_entered):
		_area.body_entered.connect(_on_body_entered)
	if not _area.body_exited.is_connected(_on_body_exited):
		_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if not _is_player(body):
		return
	_player_inside = true
	_last_body = body
	_debug_log(
		"player_entered objective_id=%s area_id=%s victory_type=%s trigger_once=%s is_triggered=%s body=%s"
		% [
			str(objective_id),
			area_id,
			_victory_type_to_string(int(victory_type)),
			str(trigger_once),
			str(is_triggered),
			str(body.name) if body != null else "<null>",
		]
	)
	_publish_zone_entered(body)
	if _can_publish_trigger():
		_publish_victory_triggered(body)
	else:
		_debug_log("skipped victory_triggered publish because trigger_once is already consumed")

func _on_body_exited(body: Node3D) -> void:
	if not _is_player(body):
		return
	_player_inside = false

func _is_player(body: Node3D) -> bool:
	if body == null:
		return false
	var entity := ECS_UTILS.find_entity_root(body)
	if entity == null:
		return false
	var manager := get_manager()
	if manager == null:
		return false
	var comps: Dictionary = manager.get_components_for_entity(entity)
	return comps.has(PLAYER_TAG_COMPONENT) and comps.get(PLAYER_TAG_COMPONENT) != null

func get_trigger_area() -> Area3D:
	return _area

func is_player_inside() -> bool:
	return _player_inside

func set_triggered() -> void:
	if trigger_once and is_triggered:
		return
	is_triggered = true
	# Note: Do NOT publish event here - creates infinite loop with rule/handler flow.
	# Event is already published by _on_body_entered → _publish_victory_triggered

func _can_publish_trigger() -> bool:
	if trigger_once and is_triggered:
		return false
	return true

func _publish_zone_entered(body: Node3D) -> void:
	_debug_log("publishing event=%s entity_id=%s" % [
		str(EVENT_VICTORY_ZONE_ENTERED),
		str(ECS_UTILS.get_entity_id(body)),
	])
	U_ECSEventBus.publish(EVENT_VICTORY_ZONE_ENTERED, {
		"entity_id": ECS_UTILS.get_entity_id(body),
		"trigger_node": self,
		"body": body,
	})

func _publish_victory_triggered(body: Node3D, force: bool = false) -> void:
	if trigger_once and is_triggered and not force:
		_debug_log("blocked victory_triggered publish because trigger_once=true and trigger already consumed")
		return
	_debug_log("publishing typed victory_triggered entity_id=%s objective_id=%s area_id=%s" % [
		str(ECS_UTILS.get_entity_id(body)),
		str(objective_id),
		area_id,
	])
	var victory_event := Evn_VictoryTriggered.new(
		ECS_UTILS.get_entity_id(body),
		self,
		body
	)
	U_ECSEventBus.publish_typed(victory_event)
