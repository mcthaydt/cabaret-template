extends BaseTest

const CONDITION_COMPONENT_FIELD := preload("res://scripts/core/resources/qb/conditions/rs_condition_component_field.gd")

class MockHealthComponent extends RefCounted:
	var health_percent: float = 0.5
	var nested: Dictionary = {
		"stats": {
			"percent": 0.75
		}
	}
	var alive: bool = true

func _make_condition() -> Variant:
	var condition: Variant = CONDITION_COMPONENT_FIELD.new()
	condition.component_type = StringName("C_HealthComponent")
	condition.field_path = "health_percent"
	condition.range_min = 0.0
	condition.range_max = 1.0
	return condition

func test_numeric_field_normalizes_to_zero_to_one_range() -> void:
	var condition: Variant = _make_condition()
	condition.range_min = 0.0
	condition.range_max = 100.0
	var context: Dictionary = {
		"components": {
			"C_HealthComponent": {
				"health_percent": 50.0
			}
		}
	}

	var score: float = condition.evaluate(context)
	assert_almost_eq(score, 0.5, 0.0001)

func test_value_below_range_min_clamps_to_zero() -> void:
	var condition: Variant = _make_condition()
	condition.range_min = 0.0
	condition.range_max = 100.0
	var context: Dictionary = {
		"components": {
			"C_HealthComponent": {
				"health_percent": -10.0
			}
		}
	}

	var score: float = condition.evaluate(context)
	assert_eq(score, 0.0)

func test_value_above_range_max_clamps_to_one() -> void:
	var condition: Variant = _make_condition()
	condition.range_min = 0.0
	condition.range_max = 100.0
	var context: Dictionary = {
		"components": {
			"C_HealthComponent": {
				"health_percent": 120.0
			}
		}
	}

	var score: float = condition.evaluate(context)
	assert_eq(score, 1.0)

func test_bool_field_returns_binary_score() -> void:
	var condition: Variant = _make_condition()
	condition.field_path = "alive"
	var true_context: Dictionary = {
		"components": {
			"C_HealthComponent": {
				"alive": true
			}
		}
	}
	var false_context: Dictionary = {
		"components": {
			"C_HealthComponent": {
				"alive": false
			}
		}
	}

	var true_score: float = condition.evaluate(true_context)
	assert_eq(true_score, 1.0)

	var false_score: float = condition.evaluate(false_context)
	assert_eq(false_score, 0.0)

func test_nested_field_path_resolves_through_component_properties() -> void:
	var condition: Variant = _make_condition()
	condition.field_path = "nested.stats.percent"
	var component := MockHealthComponent.new()
	var context: Dictionary = {
		"components": {
			StringName("C_HealthComponent"): component
		}
	}

	var score: float = condition.evaluate(context)
	assert_almost_eq(score, 0.75, 0.0001)

func test_missing_component_in_context_returns_zero() -> void:
	var condition: Variant = _make_condition()
	var context: Dictionary = {
		"components": {}
	}

	var score: float = condition.evaluate(context)
	assert_eq(score, 0.0)

func test_missing_field_on_component_returns_zero() -> void:
	var condition: Variant = _make_condition()
	condition.field_path = "missing_field"
	var context: Dictionary = {
		"components": {
			"C_HealthComponent": {
				"health_percent": 0.8
			}
		}
	}

	var score: float = condition.evaluate(context)
	assert_eq(score, 0.0)

func test_range_min_equals_range_max_uses_division_guard() -> void:
	var condition: Variant = _make_condition()
	condition.range_min = 50.0
	condition.range_max = 50.0

	var at_min_context: Dictionary = {
		"components": {
			"C_HealthComponent": {
				"health_percent": 50.0
			}
		}
	}
	var below_min_context: Dictionary = {
		"components": {
			"C_HealthComponent": {
				"health_percent": 49.0
			}
		}
	}

	var at_min_score: float = condition.evaluate(at_min_context)
	assert_eq(at_min_score, 1.0)

	var below_min_score: float = condition.evaluate(below_min_context)
	assert_eq(below_min_score, 0.0)
