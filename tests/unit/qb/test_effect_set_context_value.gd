extends BaseTest

const EFFECT_SET_CONTEXT_VALUE := preload("res://scripts/core/resources/qb/effects/rs_effect_set_context_value.gd")

func test_writes_typed_value_to_context_dictionary_key() -> void:
	var effect: Variant = EFFECT_SET_CONTEXT_VALUE.new()
	effect.context_key = StringName("is_dead")
	effect.value_type = "bool"
	effect.bool_value = true
	var context: Dictionary = {}

	effect.execute(context)

	assert_eq(context.get("is_dead", false), true)

func test_all_value_types_write_correctly() -> void:
	var context: Dictionary = {}

	var float_effect: Variant = EFFECT_SET_CONTEXT_VALUE.new()
	float_effect.context_key = StringName("f")
	float_effect.value_type = "float"
	float_effect.float_value = 1.25
	float_effect.execute(context)
	assert_almost_eq(context.get("f", -1.0), 1.25, 0.0001)

	var int_effect: Variant = EFFECT_SET_CONTEXT_VALUE.new()
	int_effect.context_key = StringName("i")
	int_effect.value_type = "int"
	int_effect.int_value = 8
	int_effect.execute(context)
	assert_eq(context.get("i", -1), 8)

	var bool_effect: Variant = EFFECT_SET_CONTEXT_VALUE.new()
	bool_effect.context_key = StringName("b")
	bool_effect.value_type = "bool"
	bool_effect.bool_value = true
	bool_effect.execute(context)
	assert_eq(context.get("b", false), true)

	var string_effect: Variant = EFFECT_SET_CONTEXT_VALUE.new()
	string_effect.context_key = StringName("s")
	string_effect.value_type = "string"
	string_effect.string_value = "state"
	string_effect.execute(context)
	assert_eq(context.get("s", ""), "state")

	var string_name_effect: Variant = EFFECT_SET_CONTEXT_VALUE.new()
	string_name_effect.context_key = StringName("sn")
	string_name_effect.value_type = "string_name"
	string_name_effect.string_name_value = StringName("player")
	string_name_effect.execute(context)
	assert_eq(context.get("sn", StringName()), StringName("player"))
