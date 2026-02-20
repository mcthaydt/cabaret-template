extends BaseTest

const QB_CONDITION := preload("res://scripts/resources/qb/rs_qb_condition.gd")
const QB_QUALITY_PROVIDER := preload("res://scripts/utils/qb/u_qb_quality_provider.gd")

class MockComponent extends RefCounted:
	var current_health: float = 75.0
	var nested: Dictionary = {
		"state": {
			"value": 42
		}
	}

func _make_condition(source: int, quality_path: String) -> Variant:
	var condition: Variant = QB_CONDITION.new()
	condition.source = source
	condition.quality_path = quality_path
	return condition

func test_read_quality_component_source_reads_dictionary_component_path() -> void:
	var condition: Variant = _make_condition(
		QB_CONDITION.Source.COMPONENT,
		"C_HealthComponent.current_health"
	)
	var context: Dictionary = {
		"components": {
			"C_HealthComponent": {
				"current_health": 55.0
			}
		}
	}

	var value: Variant = QB_QUALITY_PROVIDER.read_quality(condition, context)
	assert_eq(value, 55.0)

func test_read_quality_component_source_reads_object_properties_and_nested_path() -> void:
	var condition: Variant = _make_condition(
		QB_CONDITION.Source.COMPONENT,
		"C_HealthComponent.nested.state.value"
	)
	var component := MockComponent.new()
	var context: Dictionary = {
		"components": {
			"C_HealthComponent": component
		}
	}

	var value: Variant = QB_QUALITY_PROVIDER.read_quality(condition, context)
	assert_eq(value, 42)

func test_read_quality_component_source_supports_string_name_component_keys() -> void:
	var condition: Variant = _make_condition(
		QB_CONDITION.Source.COMPONENT,
		"C_HealthComponent.current_health"
	)
	var context: Dictionary = {
		"components": {
			StringName("C_HealthComponent"): {
				"current_health": 33.0
			}
		}
	}

	var value: Variant = QB_QUALITY_PROVIDER.read_quality(condition, context)
	assert_eq(value, 33.0)

func test_read_quality_component_source_returns_null_when_component_or_field_missing() -> void:
	var missing_component_condition: Variant = _make_condition(
		QB_CONDITION.Source.COMPONENT,
		"C_MissingComponent.current_health"
	)
	var context: Dictionary = {
		"components": {}
	}
	var missing_component_value: Variant = QB_QUALITY_PROVIDER.read_quality(missing_component_condition, context)
	assert_null(missing_component_value)

	var missing_field_condition: Variant = _make_condition(
		QB_CONDITION.Source.COMPONENT,
		"C_HealthComponent.missing_field"
	)
	var context_with_component: Dictionary = {
		"components": {
			"C_HealthComponent": {
				"current_health": 99.0
			}
		}
	}
	var missing_field_value: Variant = QB_QUALITY_PROVIDER.read_quality(missing_field_condition, context_with_component)
	assert_null(missing_field_value)

func test_read_quality_redux_source_reads_nested_slice_data() -> void:
	var condition: Variant = _make_condition(
		QB_CONDITION.Source.REDUX,
		"gameplay.paused"
	)
	var context: Dictionary = {
		"state": {
			"gameplay": {
				"paused": true
			}
		}
	}

	var value: Variant = QB_QUALITY_PROVIDER.read_quality(condition, context)
	assert_eq(value, true)

func test_read_quality_redux_source_supports_redux_state_context_key() -> void:
	var condition: Variant = _make_condition(
		QB_CONDITION.Source.REDUX,
		"scene.is_transitioning"
	)
	var context: Dictionary = {
		"redux_state": {
			"scene": {
				"is_transitioning": true
			}
		}
	}

	var value: Variant = QB_QUALITY_PROVIDER.read_quality(condition, context)
	assert_eq(value, true)

func test_read_quality_event_payload_reads_nested_data_and_empty_path() -> void:
	var condition: Variant = _make_condition(
		QB_CONDITION.Source.EVENT_PAYLOAD,
		"meta.source"
	)
	var context: Dictionary = {
		"event_payload": {
			"damage": 10.0,
			"meta": {
				"source": "hazard_zone"
			}
		}
	}

	var nested_value: Variant = QB_QUALITY_PROVIDER.read_quality(condition, context)
	assert_eq(nested_value, "hazard_zone")

	var full_payload_condition: Variant = _make_condition(
		QB_CONDITION.Source.EVENT_PAYLOAD,
		""
	)
	var full_payload: Variant = QB_QUALITY_PROVIDER.read_quality(full_payload_condition, context)
	assert_eq(full_payload, context["event_payload"])

func test_read_quality_entity_tag_source_returns_tags_or_tag_membership() -> void:
	var tags_context: Dictionary = {
		"entity_tags": [StringName("player"), StringName("controllable")]
	}

	var all_tags_condition: Variant = _make_condition(
		QB_CONDITION.Source.ENTITY_TAG,
		""
	)
	var all_tags: Variant = QB_QUALITY_PROVIDER.read_quality(all_tags_condition, tags_context)
	assert_eq(all_tags, tags_context["entity_tags"])

	var has_player_condition: Variant = _make_condition(
		QB_CONDITION.Source.ENTITY_TAG,
		"player"
	)
	var has_player: Variant = QB_QUALITY_PROVIDER.read_quality(has_player_condition, tags_context)
	assert_eq(has_player, true)

	var has_enemy_condition: Variant = _make_condition(
		QB_CONDITION.Source.ENTITY_TAG,
		"enemy"
	)
	var has_enemy: Variant = QB_QUALITY_PROVIDER.read_quality(has_enemy_condition, tags_context)
	assert_eq(has_enemy, false)

func test_read_quality_entity_tag_source_supports_tags_fallback_key() -> void:
	var condition: Variant = _make_condition(
		QB_CONDITION.Source.ENTITY_TAG,
		"npc"
	)
	var context: Dictionary = {
		"tags": [StringName("npc")]
	}

	var value: Variant = QB_QUALITY_PROVIDER.read_quality(condition, context)
	assert_eq(value, true)

func test_read_quality_custom_source_reads_direct_context_path() -> void:
	var condition: Variant = _make_condition(
		QB_CONDITION.Source.CUSTOM,
		"brain.is_dead"
	)
	var context: Dictionary = {
		"brain": {
			"is_dead": false
		}
	}

	var value: Variant = QB_QUALITY_PROVIDER.read_quality(condition, context)
	assert_eq(value, false)

func test_read_quality_returns_null_for_missing_paths_or_invalid_context_sections() -> void:
	var redux_condition: Variant = _make_condition(
		QB_CONDITION.Source.REDUX,
		"navigation.shell"
	)
	var bad_redux_context: Dictionary = {
		"state": "not-a-dictionary"
	}
	assert_null(QB_QUALITY_PROVIDER.read_quality(redux_condition, bad_redux_context))

	var component_condition: Variant = _make_condition(
		QB_CONDITION.Source.COMPONENT,
		"C_HealthComponent.current_health"
	)
	var bad_component_context: Dictionary = {
		"components": "not-a-dictionary"
	}
	assert_null(QB_QUALITY_PROVIDER.read_quality(component_condition, bad_component_context))

	var custom_condition: Variant = _make_condition(
		QB_CONDITION.Source.CUSTOM,
		"brain.missing"
	)
	assert_null(QB_QUALITY_PROVIDER.read_quality(custom_condition, {}))
