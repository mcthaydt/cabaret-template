@icon("res://assets/editor_icons/icn_component.svg")
extends BaseECSComponent
class_name C_AIBrainComponent

const COMPONENT_TYPE := StringName("C_AIBrainComponent")
const SNAPSHOT_KEY_ACTIVE_PATH := &"active_path"
const SNAPSHOT_KEY_BT_STATE_KEYS := &"bt_state_keys"
@export var brain_settings: RS_AIBrainSettings = null

var active_goal_id: StringName = StringName("")
var bt_state_bag: Dictionary = {}
var evaluation_timer: float = 0.0
var _debug_snapshot: Dictionary = {}

func _init() -> void:
	component_type = COMPONENT_TYPE

func _validate_required_settings() -> bool:
	if brain_settings == null:
		push_error("C_AIBrainComponent missing brain_settings; assign an RS_AIBrainSettings resource.")
		return false
	return true

func get_brain_settings() -> RS_AIBrainSettings:
	return brain_settings

func get_active_goal_id() -> StringName:
	return active_goal_id

func get_current_task() -> RS_AIPrimitiveTask:
	return null

func update_debug_snapshot(snapshot: Dictionary) -> void:
	_debug_snapshot = snapshot.duplicate(true)

func get_debug_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	snapshot[SNAPSHOT_KEY_ACTIVE_PATH] = _coerce_active_path(_debug_snapshot.get(SNAPSHOT_KEY_ACTIVE_PATH, []))
	snapshot[SNAPSHOT_KEY_BT_STATE_KEYS] = bt_state_bag.size()
	return snapshot

func _coerce_active_path(value: Variant) -> Array[String]:
	var active_path: Array[String] = []
	if not (value is Array):
		return active_path
	for step_variant in value as Array:
		var step_text: String = str(step_variant)
		if step_text.is_empty():
			continue
		active_path.append(step_text)
	return active_path
