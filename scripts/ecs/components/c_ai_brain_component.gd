@icon("res://assets/editor_icons/icn_component.svg")
extends BaseECSComponent
class_name C_AIBrainComponent

const COMPONENT_TYPE := StringName("C_AIBrainComponent")
const RS_AI_BRAIN_SETTINGS := preload("res://scripts/resources/ai/rs_ai_brain_settings.gd")

@export_custom(PROPERTY_HINT_RESOURCE_TYPE, "RS_AIBrainSettings") var brain_settings: Resource = null

var active_goal_id: StringName = StringName("")
var current_task_queue: Array[Resource] = []
var current_task_index: int = 0
var task_state: Dictionary = {}
var evaluation_timer: float = 0.0

func _init() -> void:
	component_type = COMPONENT_TYPE

func _validate_required_settings() -> bool:
	if brain_settings == null:
		push_error("C_AIBrainComponent missing brain_settings; assign an RS_AIBrainSettings resource.")
		return false
	if not (brain_settings is RS_AI_BRAIN_SETTINGS):
		push_error("C_AIBrainComponent brain_settings must be an RS_AIBrainSettings resource.")
		return false
	return true
