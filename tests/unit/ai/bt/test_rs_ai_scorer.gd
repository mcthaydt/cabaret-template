extends GutTest

const RS_AI_SCORER_CONSTANT_PATH := "res://scripts/resources/ai/bt/scorers/rs_ai_scorer_constant.gd"
const RS_AI_SCORER_CONDITION_PATH := "res://scripts/resources/ai/bt/scorers/rs_ai_scorer_condition.gd"
const RS_AI_SCORER_CONTEXT_FIELD_PATH := "res://scripts/resources/ai/bt/scorers/rs_ai_scorer_context_field.gd"
const RS_CONDITION_CONSTANT_PATH := "res://scripts/resources/qb/conditions/rs_condition_constant.gd"

func _load_script(path: String) -> Script:
	assert_true(FileAccess.file_exists(path), "Expected script file to exist: %s" % path)
	if not FileAccess.file_exists(path):
		return null
	var script_variant: Variant = load(path)
	assert_not_null(script_variant, "Expected script to load: %s" % path)
	if script_variant == null or not (script_variant is Script):
		return null
	return script_variant as Script

func _new_resource(path: String) -> Resource:
	var script: Script = _load_script(path)
	if script == null:
		return null
	var instance_variant: Variant = script.new()
	assert_not_null(instance_variant, "Expected resource to instantiate: %s" % path)
	if instance_variant == null:
		return null
	return instance_variant as Resource

func _new_condition_constant(score: float) -> Resource:
	var condition: Resource = _new_resource(RS_CONDITION_CONSTANT_PATH)
	if condition == null:
		return null
	condition.set("score", score)
	return condition

func test_constant_scorer_returns_configured_value() -> void:
	var scorer: Resource = _new_resource(RS_AI_SCORER_CONSTANT_PATH)
	if scorer == null:
		return
	scorer.set("value", 2.75)
	var score: Variant = scorer.call("score", {})
	assert_almost_eq(float(score), 2.75, 0.0001)

func test_condition_scorer_returns_if_true_value_when_condition_is_positive() -> void:
	var scorer: Resource = _new_resource(RS_AI_SCORER_CONDITION_PATH)
	var condition: Resource = _new_condition_constant(1.0)
	if scorer == null or condition == null:
		return
	scorer.set("condition", condition)
	scorer.set("if_true", 9.0)
	scorer.set("if_false", 1.5)

	var score: Variant = scorer.call("score", {})
	assert_almost_eq(float(score), 9.0, 0.0001)

func test_condition_scorer_returns_if_false_value_when_condition_is_zero() -> void:
	var scorer: Resource = _new_resource(RS_AI_SCORER_CONDITION_PATH)
	var condition: Resource = _new_condition_constant(0.0)
	if scorer == null or condition == null:
		return
	scorer.set("condition", condition)
	scorer.set("if_true", 9.0)
	scorer.set("if_false", 1.5)

	var score: Variant = scorer.call("score", {})
	assert_almost_eq(float(score), 1.5, 0.0001)

func test_context_field_scorer_multiplies_resolved_context_value() -> void:
	var scorer: Resource = _new_resource(RS_AI_SCORER_CONTEXT_FIELD_PATH)
	if scorer == null:
		return
	scorer.set("path", "metrics.threat")
	scorer.set("multiplier", 3.0)

	var context: Dictionary = {
		"metrics": {
			"threat": 2.0,
		}
	}
	var score: Variant = scorer.call("score", context)
	assert_almost_eq(float(score), 6.0, 0.0001)

func test_context_field_scorer_invalid_path_returns_zero_and_pushes_error() -> void:
	var scorer: Resource = _new_resource(RS_AI_SCORER_CONTEXT_FIELD_PATH)
	if scorer == null:
		return
	scorer.set("path", "metrics.missing")
	scorer.set("multiplier", 3.0)

	var context: Dictionary = {
		"metrics": {
			"threat": 2.0,
		}
	}
	var score: Variant = scorer.call("score", context)
	assert_almost_eq(float(score), 0.0, 0.0001)
	assert_push_error("RS_AIScorerContextField.score: unable to resolve path 'metrics.missing'")
