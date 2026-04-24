extends BaseTest

const CONDITION_ENTITY_TAG := preload("res://scripts/core/resources/qb/conditions/rs_condition_entity_tag.gd")

func _make_condition() -> Variant:
	var condition: Variant = CONDITION_ENTITY_TAG.new()
	condition.tag_name = StringName("player")
	return condition

func test_tag_present_in_entity_tags_returns_one() -> void:
	var condition: Variant = _make_condition()
	var context: Dictionary = {
		"entity_tags": [StringName("player"), StringName("controllable")]
	}

	var score: float = condition.evaluate(context)
	assert_eq(score, 1.0)

func test_tag_absent_returns_zero() -> void:
	var condition: Variant = _make_condition()
	var context: Dictionary = {
		"entity_tags": [StringName("npc"), StringName("hostile")]
	}

	var score: float = condition.evaluate(context)
	assert_eq(score, 0.0)

func test_empty_entity_tags_returns_zero() -> void:
	var condition: Variant = _make_condition()
	var context: Dictionary = {
		"entity_tags": []
	}

	var score: float = condition.evaluate(context)
	assert_eq(score, 0.0)
