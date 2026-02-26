extends BaseTest

const CONDITION_COMPOSITE := preload("res://scripts/resources/qb/conditions/rs_condition_composite.gd")
const CONDITION_CONSTANT := preload("res://scripts/resources/qb/conditions/rs_condition_constant.gd")

func _make_constant(score: float) -> Variant:
	var condition: Variant = CONDITION_CONSTANT.new()
	condition.score = score
	return condition

func _make_composite(mode: int, children: Array[Resource]) -> Variant:
	var condition: Variant = CONDITION_COMPOSITE.new()
	condition.mode = mode
	condition.children = children.duplicate(true)
	return condition

func _make_curve(points: Array[Vector2]) -> Curve:
	var curve := Curve.new()
	for point in points:
		curve.add_point(point, 0.0, 0.0, Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR)
	return curve

func _make_deep_chain(levels: int) -> Variant:
	var current: Variant = _make_constant(1.0)
	for _i in range(levels):
		var children: Array[Resource] = []
		children.append(current)
		current = _make_composite(CONDITION_COMPOSITE.CompositeMode.ALL, children)
	return current

func test_all_mode_multiplies_child_scores() -> void:
	var condition: Variant = _make_composite(
		CONDITION_COMPOSITE.CompositeMode.ALL,
		[_make_constant(0.8), _make_constant(0.5)]
	)

	assert_almost_eq(condition.evaluate({}), 0.4, 0.0001)

func test_all_mode_short_circuits_to_zero_on_zero_score() -> void:
	var condition: Variant = _make_composite(
		CONDITION_COMPOSITE.CompositeMode.ALL,
		[_make_constant(0.7), _make_constant(0.0), _make_constant(1.0)]
	)

	assert_eq(condition.evaluate({}), 0.0)

func test_all_mode_returns_zero_when_child_is_null() -> void:
	var children: Array[Resource] = []
	children.append(_make_constant(1.0))
	children.append(null)
	var condition: Variant = _make_composite(CONDITION_COMPOSITE.CompositeMode.ALL, children)

	assert_eq(condition.evaluate({}), 0.0)

func test_any_mode_picks_max_score() -> void:
	var condition: Variant = _make_composite(
		CONDITION_COMPOSITE.CompositeMode.ANY,
		[_make_constant(0.2), _make_constant(0.6), _make_constant(0.4)]
	)

	assert_almost_eq(condition.evaluate({}), 0.6, 0.0001)

func test_any_mode_skips_null_children() -> void:
	var children: Array[Resource] = []
	children.append(_make_constant(0.2))
	children.append(null)
	children.append(_make_constant(0.7))
	var condition: Variant = _make_composite(CONDITION_COMPOSITE.CompositeMode.ANY, children)

	assert_almost_eq(condition.evaluate({}), 0.7, 0.0001)

func test_empty_children_returns_zero() -> void:
	var condition: Variant = _make_composite(CONDITION_COMPOSITE.CompositeMode.ANY, [])
	assert_eq(condition.evaluate({}), 0.0)

func test_nested_composites_evaluate_recursively() -> void:
	var nested_all: Variant = _make_composite(
		CONDITION_COMPOSITE.CompositeMode.ALL,
		[_make_constant(0.5), _make_constant(0.5)]
	)
	var root_any: Variant = _make_composite(
		CONDITION_COMPOSITE.CompositeMode.ANY,
		[nested_all, _make_constant(0.2)]
	)

	assert_almost_eq(root_any.evaluate({}), 0.25, 0.0001)

func test_nesting_depth_limit_returns_zero_when_exceeded() -> void:
	var root: Variant = _make_deep_chain(9)
	assert_eq(root.evaluate({}), 0.0)

func test_response_curve_applies_on_composite_score() -> void:
	var condition: Variant = _make_composite(
		CONDITION_COMPOSITE.CompositeMode.ALL,
		[_make_constant(0.5), _make_constant(1.0)]
	)
	condition.response_curve = _make_curve([
		Vector2(0.0, 0.0),
		Vector2(0.5, 0.8),
		Vector2(1.0, 1.0),
	])

	assert_almost_eq(condition.evaluate({}), 0.8, 0.05)

func test_invert_applies_after_composite_scoring() -> void:
	var condition: Variant = _make_composite(
		CONDITION_COMPOSITE.CompositeMode.ALL,
		[_make_constant(0.8)]
	)
	condition.invert = true

	assert_almost_eq(condition.evaluate({}), 0.2, 0.0001)

func test_children_apply_their_own_wrappers_before_parent_aggregation() -> void:
	var child: Variant = _make_constant(0.3)
	child.invert = true
	var condition: Variant = _make_composite(
		CONDITION_COMPOSITE.CompositeMode.ALL,
		[child, _make_constant(1.0)]
	)

	assert_almost_eq(condition.evaluate({}), 0.7, 0.0001)
