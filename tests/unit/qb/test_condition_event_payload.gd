extends BaseTest

const CONDITION_EVENT_PAYLOAD := preload("res://scripts/core/resources/qb/conditions/rs_condition_event_payload.gd")

func _make_condition() -> Variant:
	var condition: Variant = CONDITION_EVENT_PAYLOAD.new()
	condition.field_path = "damage"
	condition.match_mode = "exists"
	condition.range_min = 0.0
	condition.range_max = 100.0
	return condition

func test_exists_mode_returns_one_for_non_null_and_zero_for_null_or_missing() -> void:
	var condition: Variant = _make_condition()
	condition.field_path = "checkpoint"

	var present_context: Dictionary = {
		"event_payload": {
			"checkpoint": "cp_lobby"
		}
	}
	var null_context: Dictionary = {
		"event_payload": {
			"checkpoint": null
		}
	}
	var missing_context: Dictionary = {
		"event_payload": {}
	}

	assert_eq(condition.evaluate(present_context), 1.0)
	assert_eq(condition.evaluate(null_context), 0.0)
	assert_eq(condition.evaluate(missing_context), 0.0)

func test_normalize_mode_maps_numeric_field_to_zero_to_one() -> void:
	var condition: Variant = _make_condition()
	condition.match_mode = "normalize"
	condition.field_path = "damage"
	condition.range_min = 0.0
	condition.range_max = 200.0
	var context: Dictionary = {
		"event_payload": {
			"damage": 50.0
		}
	}

	var score: float = condition.evaluate(context)
	assert_almost_eq(score, 0.25, 0.0001)

func test_equals_mode_returns_one_for_matching_string() -> void:
	var condition: Variant = _make_condition()
	condition.match_mode = "equals"
	condition.field_path = "reason"
	condition.match_value_string = "fall_damage"
	var context: Dictionary = {
		"event_payload": {
			"reason": "fall_damage"
		}
	}

	var score: float = condition.evaluate(context)
	assert_eq(score, 1.0)

func test_missing_event_payload_in_context_returns_zero() -> void:
	var condition: Variant = _make_condition()
	var context: Dictionary = {}

	var score: float = condition.evaluate(context)
	assert_eq(score, 0.0)
