@icon("res://assets/editor_icons/icn_resource.svg")
extends Resource
class_name RS_AIBrainSettings

const LEGACY_FIELD_GOALS := &"goals"
const MIGRATION_ERROR_TEMPLATE := "RS_AIBrainSettings migration required: legacy goals field found in %s"

@export var root: RS_BTNode = null
@export var evaluation_interval: float = 0.5
var _legacy_goals_detected: bool = false

func _set(property: StringName, _value: Variant) -> bool:
	if property != LEGACY_FIELD_GOALS:
		return false
	_legacy_goals_detected = true
	call_deferred("_report_legacy_goals_migration_error")
	return true

func _report_legacy_goals_migration_error() -> void:
	if not _legacy_goals_detected:
		return
	_legacy_goals_detected = false
	var source_path: String = resource_path
	if source_path.is_empty():
		source_path = "<unsaved_resource>"
	push_error(MIGRATION_ERROR_TEMPLATE % source_path)
