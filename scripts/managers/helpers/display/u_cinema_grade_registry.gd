class_name U_CinemaGradeRegistry
extends RefCounted

## Cinema Grade Registry
##
## Maps scene IDs to RS_SceneCinemaGrade resources using const preload arrays
## (mobile-safe). Call initialize() once at startup to populate the registry.


static var _scene_grades: Dictionary = {}
static var _neutral_grade: RS_SceneCinemaGrade = null

static func initialize() -> void:
	_register_scene_grades()

static func get_cinema_grade_for_scene(scene_id: StringName) -> RS_SceneCinemaGrade:
	var grade: Variant = _scene_grades.get(scene_id, null)
	if grade != null:
		return grade as RS_SceneCinemaGrade
	return _get_neutral_grade()

static func _get_neutral_grade() -> RS_SceneCinemaGrade:
	if _neutral_grade == null:
		_neutral_grade = RS_SceneCinemaGrade.new()
		_neutral_grade.scene_id = StringName("_neutral")
	return _neutral_grade

static func _register_scene_grades() -> void:
	_scene_grades.clear()

	var gameplay_base := preload("res://resources/display/cinema_grades/cfg_cinema_grade_gameplay_base.tres") as RS_SceneCinemaGrade
	var alleyway := preload("res://resources/display/cinema_grades/cfg_cinema_grade_alleyway.tres") as RS_SceneCinemaGrade
	var exterior := preload("res://resources/display/cinema_grades/cfg_cinema_grade_exterior.tres") as RS_SceneCinemaGrade
	var interior_bar := preload("res://resources/display/cinema_grades/cfg_cinema_grade_interior_bar.tres") as RS_SceneCinemaGrade
	var interior_house := preload("res://resources/display/cinema_grades/cfg_cinema_grade_interior_house.tres") as RS_SceneCinemaGrade

	_scene_grades[StringName("gameplay_base")] = gameplay_base
	_scene_grades[StringName("alleyway")] = alleyway
	_scene_grades[StringName("exterior")] = exterior
	_scene_grades[StringName("interior_bar")] = interior_bar
	_scene_grades[StringName("interior_house")] = interior_house
