extends BaseTest

const CONDITION_REDUX_FIELD := preload("res://scripts/resources/qb/conditions/rs_condition_redux_field.gd")

func _make_condition() -> Variant:
	var condition: Variant = CONDITION_REDUX_FIELD.new()
	condition.state_path = "gameplay.health_percent"
	condition.match_mode = "normalize"
	condition.range_min = 0.0
	condition.range_max = 100.0
	return condition

func test_normalize_mode_maps_numeric_value_to_zero_to_one() -> void:
	var condition: Variant = _make_condition()
	var context: Dictionary = {
		"redux_state": {
			"gameplay": {
				"health_percent": 50.0
			}
		}
	}

	var score: float = condition.evaluate(context)
	assert_almost_eq(score, 0.5, 0.0001)

func test_equals_mode_returns_binary_match_for_strings() -> void:
	var condition: Variant = _make_condition()
	condition.match_mode = "equals"
	condition.state_path = "navigation.shell"
	condition.match_value_string = "gameplay"

	var matching_context: Dictionary = {
		"redux_state": {
			"navigation": {
				"shell": "gameplay"
			}
		}
	}
	var non_matching_context: Dictionary = {
		"redux_state": {
			"navigation": {
				"shell": "menu"
			}
		}
	}

	assert_eq(condition.evaluate(matching_context), 1.0)
	assert_eq(condition.evaluate(non_matching_context), 0.0)

func test_equals_mode_matches_bool_true_with_true_string() -> void:
	var condition: Variant = _make_condition()
	condition.match_mode = "equals"
	condition.state_path = "time.is_paused"
	condition.match_value_string = "true"
	var context: Dictionary = {
		"redux_state": {
			"time": {
				"is_paused": true
			}
		}
	}

	var score: float = condition.evaluate(context)
	assert_eq(score, 1.0)

func test_not_equals_mode_returns_inverse_match() -> void:
	var condition: Variant = _make_condition()
	condition.match_mode = "not_equals"
	condition.state_path = "navigation.shell"
	condition.match_value_string = "gameplay"

	var non_matching_context: Dictionary = {
		"redux_state": {
			"navigation": {
				"shell": "menu"
			}
		}
	}
	var matching_context: Dictionary = {
		"redux_state": {
			"navigation": {
				"shell": "gameplay"
			}
		}
	}

	assert_eq(condition.evaluate(non_matching_context), 1.0)
	assert_eq(condition.evaluate(matching_context), 0.0)

func test_nested_state_path_resolves() -> void:
	var condition: Variant = _make_condition()
	condition.state_path = "gameplay.completed_areas.1"
	condition.match_mode = "equals"
	condition.match_value_string = "bar"
	var context: Dictionary = {
		"redux_state": {
			"gameplay": {
				"completed_areas": ["lobby", "bar"]
			}
		}
	}

	var score: float = condition.evaluate(context)
	assert_eq(score, 1.0)

func test_missing_state_path_returns_zero() -> void:
	var condition: Variant = _make_condition()
	condition.state_path = "gameplay.missing_field"
	var context: Dictionary = {
		"redux_state": {
			"gameplay": {
				"health_percent": 50.0
			}
		}
	}

	var score: float = condition.evaluate(context)
	assert_eq(score, 0.0)
