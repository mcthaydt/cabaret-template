extends BaseTest

const CONDITION_CONSTANT := preload("res://scripts/resources/qb/conditions/rs_condition_constant.gd")

func test_returns_configured_score_regardless_of_context() -> void:
	var condition: Variant = CONDITION_CONSTANT.new()
	condition.score = 0.35

	assert_almost_eq(condition.evaluate({}), 0.35, 0.0001)
	assert_almost_eq(condition.evaluate({"any": "value"}), 0.35, 0.0001)

func test_default_score_is_one() -> void:
	var condition: Variant = CONDITION_CONSTANT.new()

	var score: float = condition.evaluate({})
	assert_eq(score, 1.0)
