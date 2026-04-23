extends BaseTest

const ECS_MANAGER := preload("res://scripts/managers/m_ecs_manager.gd")
const BASE_ECS_COMPONENT := preload("res://scripts/ecs/base_ecs_component.gd")
const C_AI_BRAIN_COMPONENT_PATH := "res://scripts/ecs/components/c_ai_brain_component.gd"
const RS_AI_BRAIN_SETTINGS_PATH := "res://scripts/resources/ai/brain/rs_ai_brain_settings.gd"
const RS_BT_NODE_PATH := "res://scripts/resources/bt/rs_bt_node.gd"

func _load_script(path: String) -> Script:
	var script_variant: Variant = load(path)
	assert_not_null(script_variant, "Expected script to exist: %s" % path)
	if script_variant == null or not (script_variant is Script):
		return null
	return script_variant as Script

func _add_manager() -> M_ECSManager:
	var manager: M_ECSManager = ECS_MANAGER.new()
	add_child(manager)
	autofree(manager)
	return manager

func _pump() -> void:
	await get_tree().process_frame

func test_component_type_constant() -> void:
	var component_script: Script = _load_script(C_AI_BRAIN_COMPONENT_PATH)
	if component_script == null:
		return

	var component_variant: Variant = component_script.new()
	assert_true(component_variant is BASE_ECS_COMPONENT, "C_AIBrainComponent should extend BaseECSComponent")
	if not (component_variant is BaseECSComponent):
		return
	var component: BaseECSComponent = component_variant as BaseECSComponent
	autofree(component)
	assert_eq(component.get_component_type(), StringName("C_AIBrainComponent"))

func test_brain_settings_export_is_assignable() -> void:
	var component_script: Script = _load_script(C_AI_BRAIN_COMPONENT_PATH)
	var settings_script: Script = _load_script(RS_AI_BRAIN_SETTINGS_PATH)
	if component_script == null or settings_script == null:
		return

	var component: BaseECSComponent = component_script.new()
	autofree(component)
	var brain_settings: Resource = settings_script.new()
	component.set("brain_settings", brain_settings)

	assert_eq(component.get("brain_settings"), brain_settings)
	var property_definition := _get_property_definition(component, "brain_settings")
	assert_eq(int(property_definition.get("type", -1)), TYPE_OBJECT)
	assert_eq(int(property_definition.get("hint", -1)), PROPERTY_HINT_RESOURCE_TYPE)
	assert_true(str(property_definition.get("hint_string", "")).contains("RS_AIBrainSettings"))

func test_registers_with_ecs_manager() -> void:
	var component_script: Script = _load_script(C_AI_BRAIN_COMPONENT_PATH)
	var settings_script: Script = _load_script(RS_AI_BRAIN_SETTINGS_PATH)
	if component_script == null or settings_script == null:
		return

	var manager := _add_manager()
	await _pump()

	var entity := Node.new()
	entity.name = "E_TestEntity"
	add_child(entity)
	autofree(entity)

	var component: BaseECSComponent = component_script.new()
	component.set("brain_settings", settings_script.new())
	entity.add_child(component)
	autofree(component)
	await _pump()

	var components := manager.get_components(StringName("C_AIBrainComponent"))
	assert_eq(components, [component])

func test_validate_required_settings_fails_without_brain_settings() -> void:
	var component_script: Script = _load_script(C_AI_BRAIN_COMPONENT_PATH)
	if component_script == null:
		return

	var manager := _add_manager()
	await _pump()

	var entity := Node.new()
	entity.name = "E_TestEntity"
	add_child(entity)
	autofree(entity)

	var component: BaseECSComponent = component_script.new()
	entity.add_child(component)
	autofree(component)
	await _pump()
	assert_push_error("C_AIBrainComponent missing brain_settings")

	var components := manager.get_components(StringName("C_AIBrainComponent"))
	assert_eq(components.size(), 0)
	assert_false(component.is_processing())
	assert_false(component.is_physics_processing())

func test_validate_required_settings_fails_with_wrong_brain_settings_type() -> void:
	var component_script: Script = _load_script(C_AI_BRAIN_COMPONENT_PATH)
	var wrong_settings_script: Script = _load_script(RS_BT_NODE_PATH)
	if component_script == null or wrong_settings_script == null:
		return

	var manager := _add_manager()
	await _pump()

	var entity := Node.new()
	entity.name = "E_TestEntity"
	add_child(entity)
	autofree(entity)

	var component: BaseECSComponent = component_script.new()
	component.set("brain_settings", wrong_settings_script.new())
	assert_null(component.get("brain_settings"), "Typed brain_settings should reject non-RS_AIBrainSettings assignment")
	entity.add_child(component)
	autofree(component)
	await _pump()
	assert_push_error("C_AIBrainComponent missing brain_settings")

	var components := manager.get_components(StringName("C_AIBrainComponent"))
	assert_eq(components.size(), 0)
	assert_false(component.is_processing())
	assert_false(component.is_physics_processing())

func _get_property_definition(object: Object, property_name: String) -> Dictionary:
	for property_variant in object.get_property_list():
		if not (property_variant is Dictionary):
			continue
		var property := property_variant as Dictionary
		if str(property.get("name", "")) == property_name:
			return property
	return {}

# --- R1: Typed field tests ---

func test_brain_settings_export_typed_rs_ai_brain_settings() -> void:
	var component_script: Script = _load_script(C_AI_BRAIN_COMPONENT_PATH)
	if component_script == null:
		return

	var component: BaseECSComponent = component_script.new()
	autofree(component)
	var prop := _get_property_definition(component, "brain_settings")
	_assert_typed_property_hint(prop, "RS_AIBrainSettings", false, "C_AIBrainComponent.brain_settings should be typed RS_AIBrainSettings")

func test_get_brain_settings_returns_typed() -> void:
	var component_script: Script = _load_script(C_AI_BRAIN_COMPONENT_PATH)
	var settings_script: Script = _load_script(RS_AI_BRAIN_SETTINGS_PATH)
	if component_script == null or settings_script == null:
		return

	var component: BaseECSComponent = component_script.new()
	autofree(component)
	var brain_settings: Resource = settings_script.new()
	component.set("brain_settings", brain_settings)

	assert_true(component.has_method("get_brain_settings"), "C_AIBrainComponent should have get_brain_settings() accessor")
	var result: Variant = component.call("get_brain_settings")
	assert_is(result, settings_script, "get_brain_settings() should return RS_AIBrainSettings")

func test_get_active_goal_id_returns_string_name() -> void:
	var component_script: Script = _load_script(C_AI_BRAIN_COMPONENT_PATH)
	if component_script == null:
		return

	var component: BaseECSComponent = component_script.new()
	autofree(component)
	assert_true(component.has_method("get_active_goal_id"), "C_AIBrainComponent should have get_active_goal_id() accessor")
	var result: Variant = component.call("get_active_goal_id")
	assert_true(result is StringName, "get_active_goal_id() should return StringName")

func test_get_debug_snapshot_returns_copy() -> void:
	var component_script: Script = _load_script(C_AI_BRAIN_COMPONENT_PATH)
	if component_script == null:
		return

	var component: BaseECSComponent = component_script.new()
	autofree(component)

	component.call("update_debug_snapshot", {
		"goal_id": StringName("patrol"),
		"task_id": StringName("move_to_detected"),
	})
	var snapshot_a: Dictionary = component.call("get_debug_snapshot")
	var snapshot_b: Dictionary = component.call("get_debug_snapshot")
	assert_eq(snapshot_a.get("goal_id"), StringName("patrol"), "First snapshot should contain goal_id")
	assert_eq(snapshot_b.get("goal_id"), StringName("patrol"), "Second snapshot should contain goal_id")
	assert_eq(snapshot_a.get("task_id"), StringName("move_to_detected"), "First snapshot should contain task_id")
	assert_eq(snapshot_b.get("task_id"), StringName("move_to_detected"), "Second snapshot should contain task_id")
	snapshot_a["goal_id"] = StringName("modified")
	assert_eq(component.call("get_debug_snapshot").get("goal_id"), StringName("patrol"), "Modifying returned snapshot should not affect internal state")

func _assert_typed_property_hint(property_definition: Dictionary, expected_type: String, expect_array: bool, message: String) -> void:
	var hint_string: String = str(property_definition.get("hint_string", ""))
	if expect_array:
		var is_human_readable: bool = hint_string == "Array[%s]" % expected_type
		var is_engine_encoded: bool = hint_string.ends_with(":%s" % expected_type)
		var is_non_exported_typed_array: bool = hint_string == expected_type
		assert_true(
			is_human_readable or is_engine_encoded or is_non_exported_typed_array,
			"%s (actual hint_string=%s)" % [message, hint_string]
		)
		return
	assert_true(
		hint_string == expected_type or hint_string.ends_with(":%s" % expected_type),
		"%s (actual hint_string=%s)" % [message, hint_string]
	)
