@icon("res://assets/core/editor_icons/icn_component.svg")
extends BaseECSComponent
class_name C_AIBrainComponent

const COMPONENT_TYPE := StringName("C_AIBrainComponent")
const SNAPSHOT_KEY_ENTITY_ID := &"entity_id"
const SNAPSHOT_KEY_GOAL_ID := &"goal_id"
const SNAPSHOT_KEY_TASK_ID := &"task_id"
const SNAPSHOT_KEY_ACTIVE_PATH := &"active_path"
const SNAPSHOT_KEY_BT_STATE_KEYS := &"bt_state_keys"
const SNAPSHOT_KEY_LAST_PLAN := &"last_plan"
const SNAPSHOT_KEY_LAST_PLAN_COST := &"last_plan_cost"
@export var brain_settings: RS_AIBrainSettings = null

var active_goal_id: StringName = StringName("")
var bt_state_bag: Dictionary = {}
var evaluation_timer: float = 0.0
var _debug_snapshot: Dictionary = {}

func _init() -> void:
	component_type = COMPONENT_TYPE

func _validate_required_settings() -> bool:
	if brain_settings == null:
		return false
	return true

func get_brain_settings() -> RS_AIBrainSettings:
	return brain_settings

func get_active_goal_id() -> StringName:
	return active_goal_id

func update_debug_snapshot(snapshot: Dictionary) -> void:
	_debug_snapshot = snapshot.duplicate(true)

func get_debug_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	var entity_id_variant: Variant = _debug_snapshot.get(SNAPSHOT_KEY_ENTITY_ID, StringName())
	if entity_id_variant is StringName or entity_id_variant is String:
		snapshot[SNAPSHOT_KEY_ENTITY_ID] = entity_id_variant
	var goal_id_variant: Variant = _debug_snapshot.get(SNAPSHOT_KEY_GOAL_ID, StringName())
	if goal_id_variant is StringName or goal_id_variant is String:
		snapshot[SNAPSHOT_KEY_GOAL_ID] = goal_id_variant
	var task_id_variant: Variant = _debug_snapshot.get(SNAPSHOT_KEY_TASK_ID, StringName())
	if task_id_variant is StringName or task_id_variant is String:
		snapshot[SNAPSHOT_KEY_TASK_ID] = task_id_variant
	snapshot[SNAPSHOT_KEY_ACTIVE_PATH] = _sanitize_active_path(_debug_snapshot.get(SNAPSHOT_KEY_ACTIVE_PATH, []))
	snapshot[SNAPSHOT_KEY_BT_STATE_KEYS] = bt_state_bag.size()
	_append_planner_debug(snapshot)
	return snapshot

func _sanitize_active_path(value: Variant) -> Array[String]:
	var active_path: Array[String] = []
	if not (value is Array):
		return active_path
	for step_variant in value as Array:
		var step_text: String = str(step_variant)
		if step_text.is_empty():
			continue
		active_path.append(step_text)
	return active_path

func _append_planner_debug(snapshot: Dictionary) -> void:
	for node_state_variant in bt_state_bag.values():
		if not (node_state_variant is Dictionary):
			continue
		var node_state: Dictionary = node_state_variant as Dictionary
		if node_state.has(SNAPSHOT_KEY_LAST_PLAN):
			snapshot[SNAPSHOT_KEY_LAST_PLAN] = node_state.get(SNAPSHOT_KEY_LAST_PLAN, [])
		if node_state.has(SNAPSHOT_KEY_LAST_PLAN_COST):
			snapshot[SNAPSHOT_KEY_LAST_PLAN_COST] = node_state.get(SNAPSHOT_KEY_LAST_PLAN_COST, null)
