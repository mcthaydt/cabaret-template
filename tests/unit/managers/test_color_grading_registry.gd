extends GutTest

## Unit tests for U_ColorGradingRegistry
##
## Validates:
## - Known scene IDs return their configured grade resources after initialize()
## - Unknown scene IDs return a safe neutral fallback
## - Neutral grade has all resource defaults (no crashes, sane values)
## - Preloaded resources are non-null for all five registered scenes
## - Re-initializing does not break subsequent lookups

const U_COLOR_GRADING_REGISTRY := preload("res://scripts/core/managers/helpers/display/u_color_grading_registry.gd")
const RS_SCENE_COLOR_GRADING := preload("res://scripts/core/resources/display/rs_scene_color_grading.gd")

func before_each() -> void:
	U_COLOR_GRADING_REGISTRY.initialize()


func test_known_scene_returns_non_null_grade() -> void:
	var grade := U_COLOR_GRADING_REGISTRY.get_color_grading_for_scene(StringName("alleyway"))
	assert_not_null(grade, "Known scene 'alleyway' should return a non-null grade")


func test_known_scene_grade_is_correct_type() -> void:
	var grade := U_COLOR_GRADING_REGISTRY.get_color_grading_for_scene(StringName("bar"))
	assert_true(grade is RS_SCENE_COLOR_GRADING, "Grade should be RS_SceneColorGrading")


func test_all_registered_scenes_return_non_null_grades() -> void:
	var known_ids := [
		StringName("gameplay_base"),
		StringName("alleyway"),
		StringName("exterior"),
		StringName("bar"),
		StringName("interior_house"),
	]
	for scene_id in known_ids:
		var grade := U_COLOR_GRADING_REGISTRY.get_color_grading_for_scene(scene_id)
		assert_not_null(grade, "Scene '%s' should return a non-null grade" % str(scene_id))


func test_unknown_scene_returns_neutral_grade() -> void:
	var grade := U_COLOR_GRADING_REGISTRY.get_color_grading_for_scene(StringName("nonexistent_scene"))
	assert_not_null(grade, "Unknown scene should return neutral grade, not null")


func test_neutral_grade_has_neutral_scene_id() -> void:
	var grade := U_COLOR_GRADING_REGISTRY.get_color_grading_for_scene(StringName("nonexistent_scene"))
	assert_eq(grade.scene_id, StringName("_neutral"), "Neutral grade should have scene_id '_neutral'")


func test_empty_scene_id_returns_neutral_grade() -> void:
	var grade := U_COLOR_GRADING_REGISTRY.get_color_grading_for_scene(StringName(""))
	assert_not_null(grade, "Empty scene ID should return neutral grade, not null")
	assert_eq(grade.scene_id, StringName("_neutral"), "Empty scene ID should produce neutral grade")


func test_neutral_grade_has_default_exposure() -> void:
	var grade := U_COLOR_GRADING_REGISTRY.get_color_grading_for_scene(StringName("unknown"))
	assert_almost_eq(grade.exposure, 0.0, 0.001, "Neutral grade exposure should be 0.0")


func test_neutral_grade_has_default_contrast() -> void:
	var grade := U_COLOR_GRADING_REGISTRY.get_color_grading_for_scene(StringName("unknown"))
	assert_almost_eq(grade.contrast, 1.0, 0.001, "Neutral grade contrast should be 1.0")


func test_neutral_grade_has_default_saturation() -> void:
	var grade := U_COLOR_GRADING_REGISTRY.get_color_grading_for_scene(StringName("unknown"))
	assert_almost_eq(grade.saturation, 1.0, 0.001, "Neutral grade saturation should be 1.0")


func test_neutral_grade_to_dictionary_is_valid() -> void:
	var grade := U_COLOR_GRADING_REGISTRY.get_color_grading_for_scene(StringName("unknown"))
	var dict := grade.to_dictionary()
	assert_true(dict is Dictionary, "to_dictionary() should return a Dictionary")
	assert_true(dict.has("color_grading_filter_mode"),
		"Neutral dictionary should contain color_grading_filter_mode")
	assert_true(dict.has("color_grading_exposure"),
		"Neutral dictionary should contain color_grading_exposure")
	assert_true(dict.has("color_grading_contrast"),
		"Neutral dictionary should contain color_grading_contrast")


func test_neutral_grade_to_dictionary_has_zero_filter_mode() -> void:
	var grade := U_COLOR_GRADING_REGISTRY.get_color_grading_for_scene(StringName("unknown"))
	var dict := grade.to_dictionary()
	assert_eq(int(dict.get("color_grading_filter_mode", -1)), 0,
		"Neutral grade filter_mode should be 0 (none)")


func test_reinitialize_preserves_known_scene_lookups() -> void:
	U_COLOR_GRADING_REGISTRY.initialize()
	var grade := U_COLOR_GRADING_REGISTRY.get_color_grading_for_scene(StringName("bar"))
	assert_not_null(grade, "Re-initializing should still return grade for 'bar'")
