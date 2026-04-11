extends GutTest

const C_CHARACTER_STATE_COMPONENT := preload("res://scripts/ecs/components/c_character_state_component.gd")

# RSRuleContext is the class under test. Since it doesn't exist yet (TDD RED),
# tests will fail at the load step and be marked as pending.

var _context_class: Script = null

func before_each() -> void:
	var script_path := "res://scripts/resources/ecs/rs_rule_context.gd"
	var script_obj: Variant = load(script_path)
	if script_obj is Script:
		_context_class = script_obj

# ============================================================================
# Key constants
# ============================================================================

func test_key_constants_are_stringname() -> void:
	if _context_class == null:
		pending("RSRuleContext not loaded — implement rs_rule_context.gd")
		return
	var context: RefCounted = _context_class.new()

	var key_constants: Array[String] = [
		"KEY_REDUX_STATE", "KEY_STATE", "KEY_STATE_STORE",
		"KEY_ENTITY_ID", "KEY_ENTITY_TAGS", "KEY_ENTITY",
		"KEY_COMPONENTS", "KEY_COMPONENT_DATA",
		"KEY_EVENT_NAME", "KEY_EVENT_PAYLOAD", "KEY_RULE_SCORE",
		"KEY_CAMERA_STATE_COMPONENT", "KEY_CAMERA_ENTITY_ID",
		"KEY_CAMERA_ENTITY_TAGS", "KEY_CAMERA_ENTITY",
		"KEY_MOVEMENT_COMPONENT", "KEY_VCAM_ACTIVE_MODE",
		"KEY_VCAM_IS_BLENDING", "KEY_VCAM_ACTIVE_VCAM_ID",
		"KEY_CHARACTER_STATE_COMPONENT", "KEY_IS_GAMEPLAY_ACTIVE",
		"KEY_IS_GROUNDED", "KEY_IS_MOVING", "KEY_IS_SPAWN_FROZEN",
		"KEY_IS_DEAD", "KEY_IS_INVINCIBLE", "KEY_HEALTH_PERCENT",
		"KEY_VERTICAL_STATE", "KEY_HAS_INPUT",
	]
	for key_name in key_constants:
		var value: Variant = context.get(key_name)
		assert_not_null(value, "%s should exist on RSRuleContext" % key_name)
		assert_true(value is StringName, "%s should be StringName, got %s" % [key_name, type_string(typeof(value))])

func test_key_constant_values_match_expected_strings() -> void:
	if _context_class == null:
		pending("RSRuleContext not loaded — implement rs_rule_context.gd")
		return
	var context: RefCounted = _context_class.new()

	assert_eq(context.get("KEY_REDUX_STATE"), &"redux_state")
	assert_eq(context.get("KEY_STATE"), &"state")
	assert_eq(context.get("KEY_STATE_STORE"), &"state_store")
	assert_eq(context.get("KEY_ENTITY_ID"), &"entity_id")
	assert_eq(context.get("KEY_ENTITY_TAGS"), &"entity_tags")
	assert_eq(context.get("KEY_ENTITY"), &"entity")
	assert_eq(context.get("KEY_COMPONENTS"), &"components")
	assert_eq(context.get("KEY_COMPONENT_DATA"), &"component_data")
	assert_eq(context.get("KEY_EVENT_NAME"), &"event_name")
	assert_eq(context.get("KEY_EVENT_PAYLOAD"), &"event_payload")
	assert_eq(context.get("KEY_RULE_SCORE"), &"rule_score")
	assert_eq(context.get("KEY_CAMERA_STATE_COMPONENT"), &"camera_state_component")
	assert_eq(context.get("KEY_CAMERA_ENTITY_ID"), &"camera_entity_id")
	assert_eq(context.get("KEY_CAMERA_ENTITY_TAGS"), &"camera_entity_tags")
	assert_eq(context.get("KEY_CAMERA_ENTITY"), &"camera_entity")
	assert_eq(context.get("KEY_MOVEMENT_COMPONENT"), &"movement_component")
	assert_eq(context.get("KEY_VCAM_ACTIVE_MODE"), &"vcam_active_mode")
	assert_eq(context.get("KEY_VCAM_IS_BLENDING"), &"vcam_is_blending")
	assert_eq(context.get("KEY_VCAM_ACTIVE_VCAM_ID"), &"vcam_active_vcam_id")
	assert_eq(context.get("KEY_CHARACTER_STATE_COMPONENT"), &"character_state_component")
	assert_eq(context.get("KEY_IS_GAMEPLAY_ACTIVE"), &"is_gameplay_active")
	assert_eq(context.get("KEY_IS_GROUNDED"), &"is_grounded")
	assert_eq(context.get("KEY_IS_MOVING"), &"is_moving")
	assert_eq(context.get("KEY_IS_SPAWN_FROZEN"), &"is_spawn_frozen")
	assert_eq(context.get("KEY_IS_DEAD"), &"is_dead")
	assert_eq(context.get("KEY_IS_INVINCIBLE"), &"is_invincible")
	assert_eq(context.get("KEY_HEALTH_PERCENT"), &"health_percent")
	assert_eq(context.get("KEY_VERTICAL_STATE"), &"vertical_state")
	assert_eq(context.get("KEY_HAS_INPUT"), &"has_input")

# ============================================================================
# Default values
# ============================================================================

func test_default_values() -> void:
	if _context_class == null:
		pending("RSRuleContext not loaded — implement rs_rule_context.gd")
		return
	var context: RefCounted = _context_class.new()

	# Common fields — defaults
	var empty_dict := {}
	assert_eq(context.get("redux_state"), empty_dict, "redux_state default should be {}")
	assert_null(context.get("state_store"), "state_store default should be null")
	assert_eq(context.get("entity_id"), &"", "entity_id default should be empty StringName")
	var empty_array := []
	assert_eq(context.get("entity_tags"), empty_array, "entity_tags default should be []")
	assert_null(context.get("entity"), "entity default should be null")
	assert_eq(context.get("components"), empty_dict, "components default should be {}")
	assert_eq(context.get("event_name"), &"", "event_name default should be empty StringName")
	assert_eq(context.get("event_payload"), empty_dict, "event_payload default should be {}")

	# Camera-specific defaults
	assert_null(context.get("camera_state_component"), "camera_state_component default should be null")
	assert_eq(context.get("camera_entity_id"), &"", "camera_entity_id default should be empty StringName")
	assert_eq(context.get("camera_entity_tags"), empty_array, "camera_entity_tags default should be []")
	assert_null(context.get("camera_entity"), "camera_entity default should be null")
	assert_null(context.get("movement_component"), "movement_component default should be null")
	assert_eq(context.get("vcam_active_mode"), &"", "vcam_active_mode default should be empty StringName")
	assert_false(context.get("vcam_is_blending"), "vcam_is_blending default should be false")
	assert_eq(context.get("vcam_active_vcam_id"), &"", "vcam_active_vcam_id default should be empty StringName")

	# Character-specific defaults
	assert_null(context.get("character_state_component"), "character_state_component default should be null")
	assert_true(context.get("is_gameplay_active"), "is_gameplay_active default should be true")
	assert_false(context.get("is_grounded"), "is_grounded default should be false")
	assert_false(context.get("is_moving"), "is_moving default should be false")
	assert_false(context.get("is_spawn_frozen"), "is_spawn_frozen default should be false")
	assert_false(context.get("is_dead"), "is_dead default should be false")
	assert_false(context.get("is_invincible"), "is_invincible default should be false")
	assert_almost_eq(float(context.get("health_percent")), 1.0, 0.001, "health_percent default should be 1.0")
	assert_eq(int(context.get("vertical_state")), 0, "vertical_state default should be 0")
	assert_false(context.get("has_input"), "has_input default should be false")

# ============================================================================
# to_dictionary() conversion
# ============================================================================

func test_to_dictionary_includes_set_fields() -> void:
	if _context_class == null:
		pending("RSRuleContext not loaded — implement rs_rule_context.gd")
		return
	var context: RefCounted = _context_class.new()

	context.set("redux_state", {"gameplay": {}})
	context.set("entity_id", StringName("player_1"))
	context.set("is_grounded", true)
	context.set("health_percent", 0.75)

	var dict: Dictionary = context.call("to_dictionary")

	assert_true(dict.has(StringName("redux_state")), "dictionary should have redux_state key")
	assert_true(dict.has(StringName("state")), "dictionary should have state alias")
	assert_true(dict.has(StringName("entity_id")), "dictionary should have entity_id key")
	assert_true(dict.has(StringName("is_grounded")), "dictionary should have is_grounded key")
	assert_true(dict.has(StringName("is_gameplay_active")), "dictionary should have is_gameplay_active (default true)")
	assert_true(dict.has(StringName("health_percent")), "dictionary should have health_percent key")

func test_to_dictionary_state_alias_points_to_redux_state() -> void:
	if _context_class == null:
		pending("RSRuleContext not loaded — implement rs_rule_context.gd")
		return
	var context: RefCounted = _context_class.new()

	var state_data := {"gameplay": {"active": true}}
	context.set("redux_state", state_data)

	var dict: Dictionary = context.call("to_dictionary")

	var redux_variant: Variant = dict.get(StringName("redux_state"))
	var state_variant: Variant = dict.get(StringName("state"))
	assert_true(redux_variant is Dictionary, "redux_state should be a Dictionary")
	assert_true(state_variant is Dictionary, "state should be a Dictionary")
	assert_eq(redux_variant, state_variant, "state and redux_state should reference the same value")

func test_to_dictionary_component_data_alias() -> void:
	if _context_class == null:
		pending("RSRuleContext not loaded — implement rs_rule_context.gd")
		return
	var context: RefCounted = _context_class.new()

	var components := {StringName("health"): "health_data"}
	context.set("components", components)

	var dict: Dictionary = context.call("to_dictionary")

	assert_true(dict.has(StringName("components")), "dictionary should have components key")
	assert_true(dict.has(StringName("component_data")), "dictionary should have component_data alias")
	assert_eq(dict.get(StringName("components")), dict.get(StringName("component_data")),
		"components and component_data should reference the same value")

func test_to_dictionary_uses_stringname_keys() -> void:
	if _context_class == null:
		pending("RSRuleContext not loaded — implement rs_rule_context.gd")
		return
	var context: RefCounted = _context_class.new()

	context.set("entity_id", StringName("player_1"))
	context.set("is_grounded", true)

	var dict: Dictionary = context.call("to_dictionary")

	# All keys in the dictionary should be StringName
	var keys: Array = dict.keys()
	for key_variant in keys:
		assert_true(key_variant is StringName,
			"dictionary key should be StringName, got %s (%s)" % [key_variant, type_string(typeof(key_variant))])

func test_to_dictionary_character_context_fields() -> void:
	if _context_class == null:
		pending("RSRuleContext not loaded — implement rs_rule_context.gd")
		return
	var context: RefCounted = _context_class.new()

	context.set("is_gameplay_active", false)
	context.set("is_grounded", true)
	context.set("is_moving", true)
	context.set("is_spawn_frozen", false)
	context.set("is_dead", false)
	context.set("is_invincible", true)
	context.set("health_percent", 0.5)
	context.set("vertical_state", C_CHARACTER_STATE_COMPONENT.VERTICAL_STATE_RISING)
	context.set("has_input", true)

	var dict: Dictionary = context.call("to_dictionary")

	assert_eq(dict.get(StringName("is_gameplay_active")), false)
	assert_eq(dict.get(StringName("is_grounded")), true)
	assert_eq(dict.get(StringName("is_moving")), true)
	assert_eq(dict.get(StringName("is_spawn_frozen")), false)
	assert_eq(dict.get(StringName("is_dead")), false)
	assert_eq(dict.get(StringName("is_invincible")), true)
	assert_almost_eq(float(dict.get(StringName("health_percent"))), 0.5, 0.001)
	assert_eq(int(dict.get(StringName("vertical_state"))), C_CHARACTER_STATE_COMPONENT.VERTICAL_STATE_RISING)
	assert_eq(dict.get(StringName("has_input")), true)

func test_to_dictionary_camera_context_fields() -> void:
	if _context_class == null:
		pending("RSRuleContext not loaded — implement rs_rule_context.gd")
		return
	var context: RefCounted = _context_class.new()

	context.set("camera_entity_id", StringName("camera"))
	context.set("vcam_active_mode", StringName("follow"))
	context.set("vcam_is_blending", true)
	context.set("vcam_active_vcam_id", StringName("vcam_1"))

	var dict: Dictionary = context.call("to_dictionary")

	assert_eq(dict.get(StringName("camera_entity_id")), StringName("camera"))
	assert_eq(dict.get(StringName("vcam_active_mode")), StringName("follow"))
	assert_eq(dict.get(StringName("vcam_is_blending")), true)
	assert_eq(dict.get(StringName("vcam_active_vcam_id")), StringName("vcam_1"))

func test_to_dictionary_event_context_fields() -> void:
	if _context_class == null:
		pending("RSRuleContext not loaded — implement rs_rule_context.gd")
		return
	var context: RefCounted = _context_class.new()

	context.set("event_name", StringName("player_damaged"))
	context.set("event_payload", {"damage": 25})

	var dict: Dictionary = context.call("to_dictionary")

	assert_eq(dict.get(StringName("event_name")), StringName("player_damaged"))
	var payload: Variant = dict.get(StringName("event_payload"))
	assert_true(payload is Dictionary)
	assert_eq((payload as Dictionary).get("damage"), 25)

# ============================================================================
# Extra keys (for runtime additions by effects)
# ============================================================================

func test_set_extra_and_get_extra() -> void:
	if _context_class == null:
		pending("RSRuleContext not loaded — implement rs_rule_context.gd")
		return
	var context: RefCounted = _context_class.new()

	context.call("set_extra", StringName("custom_key"), "custom_value")
	var value: Variant = context.call("get_extra", StringName("custom_key"))
	assert_eq(value, "custom_value")

func test_get_extra_returns_default_for_missing_key() -> void:
	if _context_class == null:
		pending("RSRuleContext not loaded — implement rs_rule_context.gd")
		return
	var context: RefCounted = _context_class.new()

	var value: Variant = context.call("get_extra", StringName("nonexistent"), "fallback")
	assert_eq(value, "fallback")

func test_to_dictionary_includes_extra_keys() -> void:
	if _context_class == null:
		pending("RSRuleContext not loaded — implement rs_rule_context.gd")
		return
	var context: RefCounted = _context_class.new()

	context.set("entity_id", StringName("player_1"))
	context.call("set_extra", StringName("custom_effect_key"), 42)

	var dict: Dictionary = context.call("to_dictionary")

	assert_true(dict.has(StringName("custom_effect_key")), "extra keys should appear in dictionary")
	assert_eq(dict.get(StringName("custom_effect_key")), 42)

# ============================================================================
# Omitted fields are not included in dictionary
# ============================================================================

func test_to_dictionary_omits_null_object_fields() -> void:
	if _context_class == null:
		pending("RSRuleContext not loaded — implement rs_rule_context.gd")
		return
	var context: RefCounted = _context_class.new()

	# Only set entity_id, leave all other fields at defaults
	context.set("entity_id", StringName("player_1"))

	var dict: Dictionary = context.call("to_dictionary")

	# entity_id should be present
	assert_true(dict.has(StringName("entity_id")))
	# Null fields should be omitted
	assert_false(dict.has(StringName("camera_state_component")), "null camera_state_component should be omitted")
	assert_false(dict.has(StringName("character_state_component")), "null character_state_component should be omitted")
	assert_false(dict.has(StringName("state_store")), "null state_store should be omitted")
	assert_false(dict.has(StringName("entity")), "null entity should be omitted")
	assert_false(dict.has(StringName("movement_component")), "null movement_component should be omitted")

func test_to_dictionary_omits_empty_stringname_fields() -> void:
	if _context_class == null:
		pending("RSRuleContext not loaded — implement rs_rule_context.gd")
		return
	var context: RefCounted = _context_class.new()

	# Set only one StringName field, leave others at default empty StringName
	context.set("entity_id", StringName("player_1"))

	var dict: Dictionary = context.call("to_dictionary")

	# entity_id is set, should be present
	assert_true(dict.has(StringName("entity_id")))
	# Empty StringName fields should be omitted
	assert_false(dict.has(StringName("event_name")), "empty event_name should be omitted")
	assert_false(dict.has(StringName("camera_entity_id")), "empty camera_entity_id should be omitted")
	assert_false(dict.has(StringName("vcam_active_mode")), "empty vcam_active_mode should be omitted")
	assert_false(dict.has(StringName("vcam_active_vcam_id")), "empty vcam_active_vcam_id should be omitted")

func test_to_dictionary_includes_character_boolean_defaults() -> void:
	if _context_class == null:
		pending("RSRuleContext not loaded — implement rs_rule_context.gd")
		return
	var context: RefCounted = _context_class.new()

	# Character state booleans always appear with their default values
	var dict: Dictionary = context.call("to_dictionary")

	assert_true(dict.has(StringName("is_gameplay_active")), "is_gameplay_active should always be present")
	assert_eq(dict.get(StringName("is_gameplay_active")), true)
	assert_true(dict.has(StringName("is_grounded")), "is_grounded should always be present")
	assert_eq(dict.get(StringName("is_grounded")), false)
	assert_true(dict.has(StringName("is_moving")), "is_moving should always be present")
	assert_true(dict.has(StringName("is_spawn_frozen")), "is_spawn_frozen should always be present")
	assert_true(dict.has(StringName("is_dead")), "is_dead should always be present")
	assert_true(dict.has(StringName("is_invincible")), "is_invincible should always be present")
	assert_true(dict.has(StringName("health_percent")), "health_percent should always be present")
	assert_true(dict.has(StringName("vertical_state")), "vertical_state should always be present")
	assert_true(dict.has(StringName("has_input")), "has_input should always be present")

# ============================================================================
# Full context round-trip: build context, convert, read back via U_RuleUtils
# ============================================================================

func test_to_dictionary_is_compatible_with_rule_utils_get_context_value() -> void:
	if _context_class == null:
		pending("RSRuleContext not loaded — implement rs_rule_context.gd")
		return
	var context: RefCounted = _context_class.new()

	context.set("entity_id", StringName("player_1"))
	context.set("is_grounded", true)
	context.set("health_percent", 0.75)

	var dict: Dictionary = context.call("to_dictionary")

	# U_RuleUtils.get_context_value should find values by string key lookup
	var U_RULE_UTILS := load("res://scripts/utils/ecs/u_rule_utils.gd")
	var rule_utils: RefCounted = U_RULE_UTILS.new()

	var entity_id: Variant = rule_utils.call("get_context_value", dict, "entity_id")
	assert_eq(entity_id, StringName("player_1"), "get_context_value should find StringName key by string lookup")

	var is_grounded: Variant = rule_utils.call("get_context_value", dict, "is_grounded")
	assert_eq(is_grounded, true, "get_context_value should find boolean value")

	var health: Variant = rule_utils.call("get_context_value", dict, "health_percent")
	assert_almost_eq(float(health), 0.75, 0.001, "get_context_value should find float value")

func test_to_dictionary_is_compatible_with_condition_component_field() -> void:
	if _context_class == null:
		pending("RSRuleContext not loaded — implement rs_rule_context.gd")
		return
	var context: RefCounted = _context_class.new()

	var components := {StringName("health"): "health_data"}
	context.set("components", components)

	var dict: Dictionary = context.call("to_dictionary")

	# RS_ConditionComponentField reads from "components" key
	assert_true(dict.has(StringName("components")), "should have components key")
	var components_variant: Variant = dict.get(StringName("components"))
	assert_true(components_variant is Dictionary, "components should be a Dictionary")

	# Should also have component_data alias
	assert_true(dict.has(StringName("component_data")), "should have component_data alias")