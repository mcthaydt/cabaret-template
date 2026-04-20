extends BaseTest

const RS_AI_BRAIN_SETTINGS_PATH := "res://scripts/resources/ai/brain/rs_ai_brain_settings.gd"
const LEGACY_BRAIN_RESOURCE_PATH := "res://resources/ai/woods/wolf/cfg_woods_wolf_brain.tres"

func _load_script(path: String) -> Script:
	var script_variant: Variant = load(path)
	assert_not_null(script_variant, "Expected script to exist: %s" % path)
	if script_variant == null or not (script_variant is Script):
		return null
	return script_variant as Script

func _get_property_definition(object: Object, property_name: String) -> Dictionary:
	for property_variant in object.get_property_list():
		if not (property_variant is Dictionary):
			continue
		var property: Dictionary = property_variant as Dictionary
		if str(property.get("name", "")) == property_name:
			return property
	return {}

func _assert_typed_property_hint(property_definition: Dictionary, expected_type: String, message: String) -> void:
	var hint_string: String = str(property_definition.get("hint_string", ""))
	assert_true(
		hint_string == expected_type or hint_string.ends_with(":%s" % expected_type),
		"%s (actual hint_string=%s)" % [message, hint_string]
	)

func test_brain_settings_exports_bt_root_and_not_legacy_goals() -> void:
	var brain_settings_script: Script = _load_script(RS_AI_BRAIN_SETTINGS_PATH)
	if brain_settings_script == null:
		return

	var brain_settings: Resource = brain_settings_script.new()
	var root_property: Dictionary = _get_property_definition(brain_settings, "root")
	assert_false(root_property.is_empty(), "RS_AIBrainSettings should expose a root property for BT entry node.")
	_assert_typed_property_hint(root_property, "RS_BTNode", "RS_AIBrainSettings.root should be typed RS_BTNode")

	var goals_property: Dictionary = _get_property_definition(brain_settings, "goals")
	assert_true(goals_property.is_empty(), "RS_AIBrainSettings should not expose legacy goals array after BT migration.")

func test_brain_settings_keeps_evaluation_interval() -> void:
	var brain_settings_script: Script = _load_script(RS_AI_BRAIN_SETTINGS_PATH)
	if brain_settings_script == null:
		return

	var brain_settings: Resource = brain_settings_script.new()
	assert_almost_eq(float(brain_settings.get("evaluation_interval")), 0.5, 0.0001)

func test_loading_legacy_goals_resource_pushes_migration_error_with_path() -> void:
	var resource_variant: Variant = load(LEGACY_BRAIN_RESOURCE_PATH)
	assert_not_null(resource_variant, "Expected legacy AI brain resource to load for migration check.")
	await get_tree().process_frame
	assert_push_error("cfg_woods_wolf_brain.tres")
