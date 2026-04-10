extends BaseTest

const ECS_MANAGER := preload("res://scripts/managers/m_ecs_manager.gd")
const BASE_ECS_COMPONENT := preload("res://scripts/ecs/base_ecs_component.gd")
const C_AI_BRAIN_COMPONENT_PATH := "res://scripts/ecs/components/c_ai_brain_component.gd"
const RS_AI_BRAIN_SETTINGS_PATH := "res://scripts/resources/ai/rs_ai_brain_settings.gd"
const RS_AI_GOAL_PATH := "res://scripts/resources/ai/rs_ai_goal.gd"

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

func test_runtime_state_defaults() -> void:
	var component_script: Script = _load_script(C_AI_BRAIN_COMPONENT_PATH)
	if component_script == null:
		return

	var component: BaseECSComponent = component_script.new()
	autofree(component)
	assert_eq(component.get("active_goal_id"), StringName(""))

	var task_queue_variant: Variant = component.get("current_task_queue")
	assert_true(task_queue_variant is Array)
	if task_queue_variant is Array:
		var task_queue: Array = task_queue_variant as Array
		assert_eq(task_queue.size(), 0)

	assert_eq(component.get("current_task_index"), 0)

	var task_state_variant: Variant = component.get("task_state")
	assert_true(task_state_variant is Dictionary)
	if task_state_variant is Dictionary:
		var task_state: Dictionary = task_state_variant as Dictionary
		assert_eq(task_state.size(), 0)

	assert_almost_eq(float(component.get("evaluation_timer")), 0.0, 0.0001)

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
	var wrong_settings_script: Script = _load_script(RS_AI_GOAL_PATH)
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
	entity.add_child(component)
	autofree(component)
	await _pump()
	assert_push_error("C_AIBrainComponent brain_settings must be an RS_AIBrainSettings resource.")

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
	assert_eq(str(prop.get("hint_string", "")), "RS_AIBrainSettings", "C_AIBrainComponent.brain_settings hint_string should be RS_AIBrainSettings (not @export_custom)")

func test_current_task_queue_typed_rs_ai_primitive_task() -> void:
	var component_script: Script = _load_script(C_AI_BRAIN_COMPONENT_PATH)
	if component_script == null:
		return

	var component: BaseECSComponent = component_script.new()
	autofree(component)
	var prop := _get_property_definition(component, "current_task_queue")
	assert_eq(str(prop.get("hint_string", "")), "Array[RS_AIPrimitiveTask]", "C_AIBrainComponent.current_task_queue hint_string should be Array[RS_AIPrimitiveTask]")

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

func test_get_current_task_returns_typed() -> void:
	var component_script: Script = _load_script(C_AI_BRAIN_COMPONENT_PATH)
	if component_script == null:
		return

	var component: BaseECSComponent = component_script.new()
	autofree(component)
	assert_true(component.has_method("get_current_task"), "C_AIBrainComponent should have get_current_task() accessor")
	var result: Variant = component.call("get_current_task")
	# When queue is empty, should return null
	assert_null(result, "get_current_task() should return null when queue is empty")
