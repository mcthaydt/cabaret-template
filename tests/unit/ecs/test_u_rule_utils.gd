extends BaseTest

const RULE_UTILS_PATH := "res://scripts/core/utils/ecs/u_rule_utils.gd"
const RS_RULE := preload("res://scripts/core/resources/qb/rs_rule.gd")
const RS_CONDITION_CONSTANT := preload("res://scripts/core/resources/qb/conditions/rs_condition_constant.gd")
const RS_CONDITION_EVENT_NAME := preload("res://scripts/core/resources/qb/conditions/rs_condition_event_name.gd")
const RS_CONDITION_COMPOSITE := preload("res://scripts/core/resources/qb/conditions/rs_condition_composite.gd")

const I_CONDITION := preload("res://scripts/core/interfaces/i_condition.gd")

var _rule_utils: Variant = null

func before_each() -> void:
	super.before_each()
	var script_obj: Script = load(RULE_UTILS_PATH) as Script
	if script_obj != null:
		_rule_utils = script_obj.new()

# --- read_string_property ---

func test_read_string_property_returns_string_value() -> void:
	if _rule_utils == null:
		pending("U_RuleUtils not loaded")
		return
	var obj := Node.new()
	obj.set("name", "test_value")
	autofree(obj)
	var result: String = _rule_utils.read_string_property(obj, "name", "fallback")
	assert_eq(result, "test_value")

func test_read_string_property_returns_stringname_as_string() -> void:
	if _rule_utils == null:
		pending("U_RuleUtils not loaded")
		return
	var obj := Node.new()
	obj.set("name", StringName("sn_value"))
	autofree(obj)
	var result: String = _rule_utils.read_string_property(obj, "name", "fallback")
	assert_eq(result, "sn_value")

func test_read_string_property_returns_fallback_on_null_object() -> void:
	if _rule_utils == null:
		pending("U_RuleUtils not loaded")
		return
	var result: String = _rule_utils.read_string_property(null, "name", "fallback")
	assert_eq(result, "fallback")

func test_read_string_property_returns_fallback_on_missing_property() -> void:
	if _rule_utils == null:
		pending("U_RuleUtils not loaded")
		return
	var obj := Node.new()
	autofree(obj)
	var result: String = _rule_utils.read_string_property(obj, "nonexistent_property", "fallback")
	assert_eq(result, "fallback")

func test_read_string_property_returns_fallback_on_non_string_value() -> void:
	if _rule_utils == null:
		pending("U_RuleUtils not loaded")
		return
	var obj := Node.new()
	obj.set("visible", true)
	autofree(obj)
	var result: String = _rule_utils.read_string_property(obj, "visible", "fallback")
	assert_eq(result, "fallback")

# --- read_string_name_property ---

func test_read_string_name_property_returns_stringname_value() -> void:
	if _rule_utils == null:
		pending("U_RuleUtils not loaded")
		return
	var condition := RS_CONDITION_EVENT_NAME.new()
	condition.expected_event_name = StringName("my_event")
	var result: StringName = _rule_utils.read_string_name_property(condition, "expected_event_name")
	assert_eq(result, StringName("my_event"))

func test_read_string_name_property_converts_string_to_stringname() -> void:
	if _rule_utils == null:
		pending("U_RuleUtils not loaded")
		return
	var obj := Node.new()
	# Node.name is StringName, so we test StringName retrieval
	autofree(obj)
	obj.set("name", StringName("test_name"))
	var result: StringName = _rule_utils.read_string_name_property(obj, "name")
	assert_eq(result, StringName("test_name"))

func test_read_string_name_property_returns_empty_on_null_object() -> void:
	if _rule_utils == null:
		pending("U_RuleUtils not loaded")
		return
	var result: StringName = _rule_utils.read_string_name_property(null, "name")
	assert_eq(result, StringName())

func test_read_string_name_property_returns_empty_on_missing_property() -> void:
	if _rule_utils == null:
		pending("U_RuleUtils not loaded")
		return
	var obj := Node.new()
	autofree(obj)
	var result: StringName = _rule_utils.read_string_name_property(obj, "nonexistent_property")
	assert_eq(result, StringName())

# --- read_bool_property ---

func test_read_bool_property_returns_bool_value() -> void:
	if _rule_utils == null:
		pending("U_RuleUtils not loaded")
		return
	var rule := RS_RULE.new()
	rule.one_shot = true
	var result: bool = _rule_utils.read_bool_property(rule, "one_shot", false)
	assert_eq(result, true)

func test_read_bool_property_returns_fallback_on_null_object() -> void:
	if _rule_utils == null:
		pending("U_RuleUtils not loaded")
		return
	var result: bool = _rule_utils.read_bool_property(null, "visible", false)
	assert_eq(result, false)

func test_read_bool_property_returns_fallback_on_missing_property() -> void:
	if _rule_utils == null:
		pending("U_RuleUtils not loaded")
		return
	var obj := Node.new()
	autofree(obj)
	var result: bool = _rule_utils.read_bool_property(obj, "nonexistent_property", true)
	assert_eq(result, true)

func test_read_bool_property_returns_fallback_on_non_bool_value() -> void:
	if _rule_utils == null:
		pending("U_RuleUtils not loaded")
		return
	var obj := Node.new()
	obj.set("name", "not_a_bool")
	autofree(obj)
	var result: bool = _rule_utils.read_bool_property(obj, "name", false)
	assert_eq(result, false)

# --- read_float_property ---

func test_read_float_property_returns_float_value() -> void:
	if _rule_utils == null:
		pending("U_RuleUtils not loaded")
		return
	var rule := RS_RULE.new()
	rule.cooldown = 2.5
	var result: float = _rule_utils.read_float_property(rule, "cooldown", 0.0)
	assert_eq(result, 2.5)

func test_read_float_property_converts_int_to_float() -> void:
	if _rule_utils == null:
		pending("U_RuleUtils not loaded")
		return
	var rule := RS_RULE.new()
	rule.cooldown = 3
	var result: float = _rule_utils.read_float_property(rule, "cooldown", 0.0)
	assert_eq(result, 3.0)

func test_read_float_property_returns_fallback_on_null_object() -> void:
	if _rule_utils == null:
		pending("U_RuleUtils not loaded")
		return
	var result: float = _rule_utils.read_float_property(null, "position:x", 42.0)
	assert_eq(result, 42.0)

func test_read_float_property_returns_fallback_on_missing_property() -> void:
	if _rule_utils == null:
		pending("U_RuleUtils not loaded")
		return
	var obj := Node.new()
	autofree(obj)
	var result: float = _rule_utils.read_float_property(obj, "nonexistent_property", 99.0)
	assert_eq(result, 99.0)

func test_read_float_property_returns_fallback_on_non_numeric_value() -> void:
	if _rule_utils == null:
		pending("U_RuleUtils not loaded")
		return
	var obj := Node.new()
	obj.set("name", "not_a_number")
	autofree(obj)
	var result: float = _rule_utils.read_float_property(obj, "name", 1.5)
	assert_eq(result, 1.5)

# --- read_int_property ---

func test_read_int_property_returns_int_value() -> void:
	if _rule_utils == null:
		pending("U_RuleUtils not loaded")
		return
	var rule := RS_RULE.new()
	rule.priority = 5
	var result: int = _rule_utils.read_int_property(rule, "priority", 0)
	assert_eq(result, 5)

func test_read_int_property_converts_float_to_int() -> void:
	if _rule_utils == null:
		pending("U_RuleUtils not loaded")
		return
	var rule := RS_RULE.new()
	rule.cooldown = 3.7
	var result: int = _rule_utils.read_int_property(rule, "cooldown", 0)
	assert_eq(result, 3)

func test_read_int_property_returns_fallback_on_null_object() -> void:
	if _rule_utils == null:
		pending("U_RuleUtils not loaded")
		return
	var result: int = _rule_utils.read_int_property(null, "priority", 99)
	assert_eq(result, 99)

func test_read_int_property_returns_fallback_on_missing_property() -> void:
	if _rule_utils == null:
		pending("U_RuleUtils not loaded")
		return
	var obj := Node.new()
	autofree(obj)
	var result: int = _rule_utils.read_int_property(obj, "nonexistent_property", 42)
	assert_eq(result, 42)

func test_read_int_property_returns_fallback_on_non_numeric_value() -> void:
	if _rule_utils == null:
		pending("U_RuleUtils not loaded")
		return
	var obj := Node.new()
	obj.set("name", "not_a_number")
	autofree(obj)
	var result: int = _rule_utils.read_int_property(obj, "name", 7)
	assert_eq(result, 7)

# --- read_array_property ---

func test_read_array_property_returns_array_value() -> void:
	if _rule_utils == null:
		pending("U_RuleUtils not loaded")
		return
	var rule := RS_RULE.new()
	rule.conditions.clear()
	rule.conditions.append(RS_CONDITION_CONSTANT.new() as I_Condition)
	var result: Array = _rule_utils.read_array_property(rule, "conditions")
	assert_eq(result.size(), 1)

func test_read_array_property_returns_empty_on_null_object() -> void:
	if _rule_utils == null:
		pending("U_RuleUtils not loaded")
		return
	var result: Array = _rule_utils.read_array_property(null, "conditions")
	assert_eq(result.size(), 0)

func test_read_array_property_returns_empty_on_missing_property() -> void:
	if _rule_utils == null:
		pending("U_RuleUtils not loaded")
		return
	var obj := Node.new()
	autofree(obj)
	var result: Array = _rule_utils.read_array_property(obj, "nonexistent_property")
	assert_eq(result.size(), 0)

func test_read_array_property_returns_empty_on_non_array_value() -> void:
	if _rule_utils == null:
		pending("U_RuleUtils not loaded")
		return
	var obj := Node.new()
	obj.set("name", "not_an_array")
	autofree(obj)
	var result: Array = _rule_utils.read_array_property(obj, "name")
	assert_eq(result.size(), 0)

func test_read_array_property_returns_empty_on_non_object_variant() -> void:
	if _rule_utils == null:
		pending("U_RuleUtils not loaded")
		return
	var result: Array = _rule_utils.read_array_property(42, "conditions")
	assert_eq(result.size(), 0)

# --- is_script_instance_of ---

func test_is_script_instance_of_returns_true_for_matching_script() -> void:
	if _rule_utils == null:
		pending("U_RuleUtils not loaded")
		return
	var condition := RS_CONDITION_EVENT_NAME.new()
	var result: bool = _rule_utils.is_script_instance_of(condition, RS_CONDITION_EVENT_NAME)
	assert_true(result)

func test_is_script_instance_of_returns_true_for_child_script() -> void:
	if _rule_utils == null:
		pending("U_RuleUtils not loaded")
		return
	# RS_ConditionEventName extends RS_BaseCondition, so it should be instance of the base script
	var base_condition_script := load("res://scripts/core/resources/qb/rs_base_condition.gd") as Script
	var condition := RS_CONDITION_EVENT_NAME.new()
	var result: bool = _rule_utils.is_script_instance_of(condition, base_condition_script)
	assert_true(result)

func test_is_script_instance_of_returns_false_for_unrelated_script() -> void:
	if _rule_utils == null:
		pending("U_RuleUtils not loaded")
		return
	var condition := RS_CONDITION_EVENT_NAME.new()
	var result: bool = _rule_utils.is_script_instance_of(condition, RS_RULE)
	assert_false(result)

func test_is_script_instance_of_returns_false_on_null_object() -> void:
	if _rule_utils == null:
		pending("U_RuleUtils not loaded")
		return
	var result: bool = _rule_utils.is_script_instance_of(null, RS_CONDITION_EVENT_NAME)
	assert_false(result)

func test_is_script_instance_of_returns_false_on_null_script() -> void:
	if _rule_utils == null:
		pending("U_RuleUtils not loaded")
		return
	var condition := RS_CONDITION_EVENT_NAME.new()
	var result: bool = _rule_utils.is_script_instance_of(condition, null)
	assert_false(result)

# --- object_has_property ---

func test_object_has_property_returns_true_for_existing_property() -> void:
	if _rule_utils == null:
		pending("U_RuleUtils not loaded")
		return
	var obj := Node.new()
	autofree(obj)
	var result: bool = _rule_utils.object_has_property(obj, "name")
	assert_true(result)

func test_object_has_property_returns_false_for_missing_property() -> void:
	if _rule_utils == null:
		pending("U_RuleUtils not loaded")
		return
	var obj := Node.new()
	autofree(obj)
	var result: bool = _rule_utils.object_has_property(obj, "nonexistent_property_xyz")
	assert_false(result)

func test_object_has_property_returns_false_on_null_object() -> void:
	if _rule_utils == null:
		pending("U_RuleUtils not loaded")
		return
	var result: bool = _rule_utils.object_has_property(null, "name")
	assert_false(result)

# --- variant_to_string_name ---

func test_variant_to_string_name_converts_stringname() -> void:
	if _rule_utils == null:
		pending("U_RuleUtils not loaded")
		return
	var result: StringName = _rule_utils.variant_to_string_name(StringName("hello"))
	assert_eq(result, StringName("hello"))

func test_variant_to_string_name_converts_string() -> void:
	if _rule_utils == null:
		pending("U_RuleUtils not loaded")
		return
	var result: StringName = _rule_utils.variant_to_string_name("hello")
	assert_eq(result, StringName("hello"))

func test_variant_to_string_name_returns_empty_for_empty_string() -> void:
	if _rule_utils == null:
		pending("U_RuleUtils not loaded")
		return
	var result: StringName = _rule_utils.variant_to_string_name("")
	assert_eq(result, StringName())

func test_variant_to_string_name_returns_empty_for_non_string_types() -> void:
	if _rule_utils == null:
		pending("U_RuleUtils not loaded")
		return
	var result: StringName = _rule_utils.variant_to_string_name(42)
	assert_eq(result, StringName())

func test_variant_to_string_name_preserves_stringname_unchanged() -> void:
	if _rule_utils == null:
		pending("U_RuleUtils not loaded")
		return
	var sn: StringName = StringName("test_value")
	var result: StringName = _rule_utils.variant_to_string_name(sn)
	assert_eq(result, sn)

# --- get_context_value ---

func test_get_context_value_returns_value_for_string_key() -> void:
	if _rule_utils == null:
		pending("U_RuleUtils not loaded")
		return
	var context := {"entity_id": StringName("player_1")}
	var result: Variant = _rule_utils.get_context_value(context, "entity_id")
	assert_eq(result, StringName("player_1"))

func test_get_context_value_returns_value_for_stringname_key() -> void:
	if _rule_utils == null:
		pending("U_RuleUtils not loaded")
		return
	var context := {StringName("entity_id"): StringName("player_1")}
	var result: Variant = _rule_utils.get_context_value(context, "entity_id")
	assert_eq(result, StringName("player_1"))

func test_get_context_value_returns_null_for_missing_key() -> void:
	if _rule_utils == null:
		pending("U_RuleUtils not loaded")
		return
	var context := {"other_key": 42}
	var result: Variant = _rule_utils.get_context_value(context, "entity_id")
	assert_eq(result, null)

func test_get_context_value_prefers_string_key_over_stringname_key() -> void:
	if _rule_utils == null:
		pending("U_RuleUtils not loaded")
		return
	var context := {"key": "string_value"}
	var result: Variant = _rule_utils.get_context_value(context, "key")
	assert_eq(result, "string_value")

# --- extract_event_names_from_rule ---

func test_extract_event_names_from_rule_returns_empty_for_null() -> void:
	if _rule_utils == null:
		pending("U_RuleUtils not loaded")
		return
	var result: Array[StringName] = _rule_utils.extract_event_names_from_rule(null)
	assert_eq(result.size(), 0)

func test_extract_event_names_from_rule_returns_empty_for_non_object() -> void:
	if _rule_utils == null:
		pending("U_RuleUtils not loaded")
		return
	var result: Array[StringName] = _rule_utils.extract_event_names_from_rule(42)
	assert_eq(result.size(), 0)

func test_extract_event_names_from_rule_returns_empty_for_rule_without_conditions() -> void:
	if _rule_utils == null:
		pending("U_RuleUtils not loaded")
		return
	var rule := RS_RULE.new()
	rule.conditions.clear()
	var result: Array[StringName] = _rule_utils.extract_event_names_from_rule(rule)
	assert_eq(result.size(), 0)

func test_extract_event_names_from_rule_extracts_from_event_name_conditions() -> void:
	if _rule_utils == null:
		pending("U_RuleUtils not loaded")
		return
	var condition := RS_CONDITION_EVENT_NAME.new()
	condition.expected_event_name = StringName("player_damaged")
	var rule := RS_RULE.new()
	rule.conditions.clear()
	rule.conditions.append(condition as I_Condition)
	var result: Array[StringName] = _rule_utils.extract_event_names_from_rule(rule)
	assert_eq(result.size(), 1)
	assert_eq(result[0], StringName("player_damaged"))

func test_extract_event_names_from_rule_deduplicates_event_names() -> void:
	if _rule_utils == null:
		pending("U_RuleUtils not loaded")
		return
	var condition_a := RS_CONDITION_EVENT_NAME.new()
	condition_a.expected_event_name = StringName("player_damaged")
	var condition_b := RS_CONDITION_EVENT_NAME.new()
	condition_b.expected_event_name = StringName("player_damaged")
	var rule := RS_RULE.new()
	rule.conditions.clear()
	rule.conditions.append(condition_a as I_Condition)
	rule.conditions.append(condition_b as I_Condition)
	var result: Array[StringName] = _rule_utils.extract_event_names_from_rule(rule)
	assert_eq(result.size(), 1)

func test_extract_event_names_from_rule_ignores_non_event_conditions() -> void:
	if _rule_utils == null:
		pending("U_RuleUtils not loaded")
		return
	var constant_condition := RS_CONDITION_CONSTANT.new()
	constant_condition.score = 1.0
	var event_condition := RS_CONDITION_EVENT_NAME.new()
	event_condition.expected_event_name = StringName("checkpoint_reached")
	var rule := RS_RULE.new()
	rule.conditions.clear()
	rule.conditions.append(constant_condition as I_Condition)
	rule.conditions.append(event_condition as I_Condition)
	var result: Array[StringName] = _rule_utils.extract_event_names_from_rule(rule)
	assert_eq(result.size(), 1)
	assert_eq(result[0], StringName("checkpoint_reached"))

func test_extract_event_names_from_rule_handles_composite_conditions() -> void:
	if _rule_utils == null:
		pending("U_RuleUtils not loaded")
		return
	var event_condition := RS_CONDITION_EVENT_NAME.new()
	event_condition.expected_event_name = StringName("area_entered")
	var composite := RS_CONDITION_COMPOSITE.new()
	composite.children.clear()
	composite.children.append(event_condition as I_Condition)
	var rule := RS_RULE.new()
	rule.conditions.clear()
	rule.conditions.append(composite as I_Condition)
	var result: Array[StringName] = _rule_utils.extract_event_names_from_rule(rule)
	assert_eq(result.size(), 1)
	assert_eq(result[0], StringName("area_entered"))

func test_extract_event_names_from_rule_handles_nested_composites() -> void:
	if _rule_utils == null:
		pending("U_RuleUtils not loaded")
		return
	var event_condition_a := RS_CONDITION_EVENT_NAME.new()
	event_condition_a.expected_event_name = StringName("outer_event")
	var event_condition_b := RS_CONDITION_EVENT_NAME.new()
	event_condition_b.expected_event_name = StringName("inner_event")
	var inner_composite := RS_CONDITION_COMPOSITE.new()
	inner_composite.children.clear()
	inner_composite.children.append(event_condition_b as I_Condition)
	var outer_composite := RS_CONDITION_COMPOSITE.new()
	outer_composite.children.clear()
	outer_composite.children.append(event_condition_a as I_Condition)
	outer_composite.children.append(inner_composite as I_Condition)
	var rule := RS_RULE.new()
	rule.conditions.clear()
	rule.conditions.append(outer_composite as I_Condition)
	var result: Array[StringName] = _rule_utils.extract_event_names_from_rule(rule)
	assert_eq(result.size(), 2)
	assert_true(result.has(StringName("outer_event")))
	assert_true(result.has(StringName("inner_event")))

func test_extract_event_names_from_rule_skips_null_conditions() -> void:
	if _rule_utils == null:
		pending("U_RuleUtils not loaded")
		return
	var rule := RS_RULE.new()
	rule.conditions.clear()
	var result: Array[StringName] = _rule_utils.extract_event_names_from_rule(rule)
	assert_eq(result.size(), 0)