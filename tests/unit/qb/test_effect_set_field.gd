extends BaseTest

const EFFECT_SET_FIELD := preload("res://scripts/resources/qb/effects/rs_effect_set_field.gd")

func _make_effect() -> Variant:
	var effect: Variant = EFFECT_SET_FIELD.new()
	effect.component_type = StringName("C_TestComponent")
	effect.field_name = StringName("float_field")
	effect.operation = "set"
	effect.value_type = "float"
	effect.float_value = 0.0
	return effect

func _make_context(component_value: Variant) -> Dictionary:
	return {
		"components": {
			"C_TestComponent": component_value
		}
	}

func test_set_operation_writes_literal_float_value_to_component_field() -> void:
	var effect: Variant = _make_effect()
	effect.float_value = 0.5
	var component: Dictionary = {
		"float_field": 0.0
	}
	var context: Dictionary = _make_context(component)

	effect.execute(context)

	assert_almost_eq(component.get("float_field", -1.0), 0.5, 0.0001)

func test_add_operation_adds_to_existing_component_field_value() -> void:
	var effect: Variant = _make_effect()
	effect.operation = "add"
	effect.float_value = 0.5
	var component: Dictionary = {
		"float_field": 1.25
	}
	var context: Dictionary = _make_context(component)

	effect.execute(context)

	assert_almost_eq(component.get("float_field", -1.0), 1.75, 0.0001)

func test_clamp_applies_when_use_clamp_is_true() -> void:
	var effect: Variant = _make_effect()
	effect.float_value = 2.0
	effect.use_clamp = true
	effect.clamp_min = 0.0
	effect.clamp_max = 1.0
	var component: Dictionary = {
		"float_field": 0.0
	}
	var context: Dictionary = _make_context(component)

	effect.execute(context)

	assert_almost_eq(component.get("float_field", -1.0), 1.0, 0.0001)

func test_use_context_value_reads_value_from_context_path() -> void:
	var effect: Variant = _make_effect()
	effect.use_context_value = true
	effect.context_value_path = "event_payload.damage"
	var component: Dictionary = {
		"float_field": 0.0
	}
	var context: Dictionary = _make_context(component)
	context["event_payload"] = {
		"damage": 0.75
	}

	effect.execute(context)

	assert_almost_eq(component.get("float_field", -1.0), 0.75, 0.0001)

func test_missing_component_in_context_is_no_op() -> void:
	var effect: Variant = _make_effect()
	effect.float_value = 0.5
	var context: Dictionary = {
		"components": {}
	}

	effect.execute(context)

	assert_eq((context.get("components", {}) as Dictionary).size(), 0)

func test_all_value_types_resolve_correctly() -> void:
	var component: Dictionary = {
		"float_field": 0.0,
		"int_field": 0,
		"bool_field": false,
		"string_field": "",
		"string_name_field": StringName("")
	}
	var context: Dictionary = _make_context(component)

	var float_effect: Variant = _make_effect()
	float_effect.field_name = StringName("float_field")
	float_effect.value_type = "float"
	float_effect.float_value = 1.5
	float_effect.execute(context)
	assert_almost_eq(component.get("float_field", -1.0), 1.5, 0.0001)

	var int_effect: Variant = _make_effect()
	int_effect.field_name = StringName("int_field")
	int_effect.value_type = "int"
	int_effect.int_value = 7
	int_effect.execute(context)
	assert_eq(component.get("int_field", -1), 7)

	var bool_effect: Variant = _make_effect()
	bool_effect.field_name = StringName("bool_field")
	bool_effect.value_type = "bool"
	bool_effect.bool_value = true
	bool_effect.execute(context)
	assert_eq(component.get("bool_field", false), true)

	var string_effect: Variant = _make_effect()
	string_effect.field_name = StringName("string_field")
	string_effect.value_type = "string"
	string_effect.string_value = "hello"
	string_effect.execute(context)
	assert_eq(component.get("string_field", ""), "hello")

	var string_name_effect: Variant = _make_effect()
	string_name_effect.field_name = StringName("string_name_field")
	string_name_effect.value_type = "string_name"
	string_name_effect.string_name_value = StringName("player")
	string_name_effect.execute(context)
	assert_eq(component.get("string_name_field", StringName()), StringName("player"))
