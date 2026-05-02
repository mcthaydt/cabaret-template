class_name U_ColorGradingRegistry
extends RefCounted

## Color Grading Registry
##
## Maps scene IDs to RS_SceneColorGrading resources using const preload arrays
## (mobile-safe). Call initialize() once at startup to populate the registry.


static var _scene_grades: Dictionary = {}
static var _neutral_grade: RS_SceneColorGrading = null

static func initialize() -> void:
	_register_scene_grades()

static func get_color_grading_for_scene(scene_id: StringName) -> RS_SceneColorGrading:
	var grade: Variant = _scene_grades.get(scene_id, null)
	if grade != null:
		return grade as RS_SceneColorGrading
	return _get_neutral_grade()

static func _get_neutral_grade() -> RS_SceneColorGrading:
	if _neutral_grade == null:
		_neutral_grade = RS_SceneColorGrading.new()
		_neutral_grade.scene_id = StringName("_neutral")
	return _neutral_grade

static func _register_scene_grades() -> void:
	_scene_grades.clear()

	var gameplay_base := preload("res://resources/core/display/color_gradings/cfg_color_grading_gameplay_base.tres") as RS_SceneColorGrading

	_scene_grades[StringName("demo_room")] = gameplay_base
