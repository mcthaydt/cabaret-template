extends BaseTest

const QB_CONDITION := preload("res://scripts/resources/qb/rs_qb_condition.gd")
const QB_RULE_EVALUATOR := preload("res://scripts/utils/qb/u_qb_rule_evaluator.gd")

func _make_condition(
	operator: int,
	value_type: int,
	value: Variant,
	negate: bool = false
) -> Variant:
	var condition: Variant = QB_CONDITION.new()
	condition.operator = operator
	condition.value_type = value_type
	condition.negate = negate

	match value_type:
		QB_CONDITION.ValueType.FLOAT:
			condition.value_float = float(value)
		QB_CONDITION.ValueType.INT:
			condition.value_int = int(value)
		QB_CONDITION.ValueType.STRING:
			condition.value_string = String(value)
		QB_CONDITION.ValueType.BOOL:
			condition.value_bool = bool(value)
		QB_CONDITION.ValueType.STRING_NAME:
			condition.value_string_name = StringName(value)

	return condition

func test_equals_operator_supports_typed_values() -> void:
	var float_condition: Variant = _make_condition(
		QB_CONDITION.Operator.EQUALS,
		QB_CONDITION.ValueType.FLOAT,
		2.5
	)
	assert_true(QB_RULE_EVALUATOR.evaluate_condition(float_condition, 2.5))

	var int_condition: Variant = _make_condition(
		QB_CONDITION.Operator.EQUALS,
		QB_CONDITION.ValueType.INT,
		7
	)
	assert_true(QB_RULE_EVALUATOR.evaluate_condition(int_condition, 7))

	var string_condition: Variant = _make_condition(
		QB_CONDITION.Operator.EQUALS,
		QB_CONDITION.ValueType.STRING,
		"gameplay"
	)
	assert_true(QB_RULE_EVALUATOR.evaluate_condition(string_condition, "gameplay"))

	var bool_condition: Variant = _make_condition(
		QB_CONDITION.Operator.EQUALS,
		QB_CONDITION.ValueType.BOOL,
		true
	)
	assert_true(QB_RULE_EVALUATOR.evaluate_condition(bool_condition, true))

	var string_name_condition: Variant = _make_condition(
		QB_CONDITION.Operator.EQUALS,
		QB_CONDITION.ValueType.STRING_NAME,
		&"player"
	)
	assert_true(QB_RULE_EVALUATOR.evaluate_condition(string_name_condition, &"player"))

func test_not_equals_operator_returns_inverse() -> void:
	var condition: Variant = _make_condition(
		QB_CONDITION.Operator.NOT_EQUALS,
		QB_CONDITION.ValueType.INT,
		10
	)
	assert_true(QB_RULE_EVALUATOR.evaluate_condition(condition, 9))
	assert_false(QB_RULE_EVALUATOR.evaluate_condition(condition, 10))

func test_numeric_relational_operators_support_float_and_int() -> void:
	var gt_condition: Variant = _make_condition(
		QB_CONDITION.Operator.GREATER_THAN,
		QB_CONDITION.ValueType.FLOAT,
		2.5
	)
	assert_true(QB_RULE_EVALUATOR.evaluate_condition(gt_condition, 3.0))
	assert_false(QB_RULE_EVALUATOR.evaluate_condition(gt_condition, 2.0))

	var lt_condition: Variant = _make_condition(
		QB_CONDITION.Operator.LESS_THAN,
		QB_CONDITION.ValueType.INT,
		5
	)
	assert_true(QB_RULE_EVALUATOR.evaluate_condition(lt_condition, 4))
	assert_false(QB_RULE_EVALUATOR.evaluate_condition(lt_condition, 5))

	var gte_condition: Variant = _make_condition(
		QB_CONDITION.Operator.GTE,
		QB_CONDITION.ValueType.FLOAT,
		1.0
	)
	assert_true(QB_RULE_EVALUATOR.evaluate_condition(gte_condition, 1.0))

	var lte_condition: Variant = _make_condition(
		QB_CONDITION.Operator.LTE,
		QB_CONDITION.ValueType.INT,
		10
	)
	assert_true(QB_RULE_EVALUATOR.evaluate_condition(lte_condition, 10))
	assert_false(QB_RULE_EVALUATOR.evaluate_condition(lte_condition, 11))

func test_has_and_not_has_support_arrays_and_dictionary_keys() -> void:
	var has_array_condition: Variant = _make_condition(
		QB_CONDITION.Operator.HAS,
		QB_CONDITION.ValueType.STRING_NAME,
		&"player"
	)
	assert_true(QB_RULE_EVALUATOR.evaluate_condition(has_array_condition, [StringName("player"), StringName("character")]))
	assert_false(QB_RULE_EVALUATOR.evaluate_condition(has_array_condition, [StringName("npc")]))

	var has_dict_condition: Variant = _make_condition(
		QB_CONDITION.Operator.HAS,
		QB_CONDITION.ValueType.STRING,
		"spawn_point"
	)
	assert_true(QB_RULE_EVALUATOR.evaluate_condition(has_dict_condition, {"spawn_point": true}))

	var not_has_condition: Variant = _make_condition(
		QB_CONDITION.Operator.NOT_HAS,
		QB_CONDITION.ValueType.STRING,
		"paused"
	)
	assert_true(QB_RULE_EVALUATOR.evaluate_condition(not_has_condition, {"shell": "gameplay"}))
	assert_false(QB_RULE_EVALUATOR.evaluate_condition(not_has_condition, {"paused": true}))

func test_boolean_operators_handle_truthiness_checks() -> void:
	var true_condition: Variant = _make_condition(
		QB_CONDITION.Operator.IS_TRUE,
		QB_CONDITION.ValueType.BOOL,
		true
	)
	assert_true(QB_RULE_EVALUATOR.evaluate_condition(true_condition, true))
	assert_false(QB_RULE_EVALUATOR.evaluate_condition(true_condition, false))

	var false_condition: Variant = _make_condition(
		QB_CONDITION.Operator.IS_FALSE,
		QB_CONDITION.ValueType.BOOL,
		false
	)
	assert_true(QB_RULE_EVALUATOR.evaluate_condition(false_condition, false))
	assert_false(QB_RULE_EVALUATOR.evaluate_condition(false_condition, true))

func test_string_and_string_name_value_types_support_cross_comparison() -> void:
	var string_condition: Variant = _make_condition(
		QB_CONDITION.Operator.EQUALS,
		QB_CONDITION.ValueType.STRING,
		"gameplay"
	)
	assert_true(QB_RULE_EVALUATOR.evaluate_condition(string_condition, &"gameplay"))

	var string_name_condition: Variant = _make_condition(
		QB_CONDITION.Operator.EQUALS,
		QB_CONDITION.ValueType.STRING_NAME,
		&"checkpoint"
	)
	assert_true(QB_RULE_EVALUATOR.evaluate_condition(string_name_condition, "checkpoint"))

func test_negate_inverts_condition_result() -> void:
	var condition: Variant = _make_condition(
		QB_CONDITION.Operator.EQUALS,
		QB_CONDITION.ValueType.BOOL,
		true,
		true
	)
	assert_false(QB_RULE_EVALUATOR.evaluate_condition(condition, true))
	assert_true(QB_RULE_EVALUATOR.evaluate_condition(condition, false))

func test_null_and_type_mismatch_return_false_for_relational_checks() -> void:
	var condition: Variant = _make_condition(
		QB_CONDITION.Operator.GREATER_THAN,
		QB_CONDITION.ValueType.FLOAT,
		1.0
	)
	assert_false(QB_RULE_EVALUATOR.evaluate_condition(condition, null))
	assert_false(QB_RULE_EVALUATOR.evaluate_condition(condition, "not-a-number"))

func test_evaluate_all_conditions_requires_all_matches() -> void:
	var paused_condition: Variant = _make_condition(
		QB_CONDITION.Operator.IS_TRUE,
		QB_CONDITION.ValueType.BOOL,
		true
	)
	paused_condition.quality_path = "gameplay.paused"

	var shell_condition: Variant = _make_condition(
		QB_CONDITION.Operator.EQUALS,
		QB_CONDITION.ValueType.STRING,
		"gameplay"
	)
	shell_condition.quality_path = "navigation.shell"

	var conditions: Array = [paused_condition, shell_condition]
	var matching_context := {
		"gameplay.paused": true,
		"navigation.shell": "gameplay",
	}
	assert_true(QB_RULE_EVALUATOR.evaluate_all_conditions(conditions, matching_context))

	var non_matching_context := {
		"gameplay.paused": false,
		"navigation.shell": "gameplay",
	}
	assert_false(QB_RULE_EVALUATOR.evaluate_all_conditions(conditions, non_matching_context))

func test_evaluate_all_conditions_returns_true_for_empty_array() -> void:
	assert_true(QB_RULE_EVALUATOR.evaluate_all_conditions([], {}))
