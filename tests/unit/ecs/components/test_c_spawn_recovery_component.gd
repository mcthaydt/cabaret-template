extends BaseTest

const ECS_MANAGER := preload("res://scripts/managers/m_ecs_manager.gd")
const BASE_ECS_COMPONENT := preload("res://scripts/ecs/base_ecs_component.gd")
const C_SPAWN_RECOVERY_COMPONENT_PATH := "res://scripts/ecs/components/c_spawn_recovery_component.gd"
const RS_SPAWN_RECOVERY_SETTINGS_PATH := "res://scripts/resources/ecs/rs_spawn_recovery_settings.gd"

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

func _get_property_definition(object: Object, property_name: String) -> Dictionary:
	for property_variant in object.get_property_list():
		if not (property_variant is Dictionary):
			continue
		var property := property_variant as Dictionary
		if str(property.get("name", "")) == property_name:
			return property
	return {}

func test_component_type_constant() -> void:
	var component_script: Script = _load_script(C_SPAWN_RECOVERY_COMPONENT_PATH)
	if component_script == null:
		return

	var component_variant: Variant = component_script.new()
	assert_true(component_variant is BASE_ECS_COMPONENT, "C_SpawnRecoveryComponent should extend BaseECSComponent")
	if not (component_variant is BaseECSComponent):
		return
	var component: BaseECSComponent = component_variant as BaseECSComponent
	autofree(component)
	assert_eq(component.get_component_type(), StringName("C_SpawnRecoveryComponent"))

func test_settings_export_assignable() -> void:
	var component_script: Script = _load_script(C_SPAWN_RECOVERY_COMPONENT_PATH)
	var settings_script: Script = _load_script(RS_SPAWN_RECOVERY_SETTINGS_PATH)
	if component_script == null or settings_script == null:
		return

	var component: BaseECSComponent = component_script.new()
	autofree(component)
	var settings: Resource = settings_script.new()
	component.set("settings", settings)

	assert_eq(component.get("settings"), settings)
	var property_definition := _get_property_definition(component, "settings")
	assert_eq(int(property_definition.get("type", -1)), TYPE_OBJECT)
	assert_eq(int(property_definition.get("hint", -1)), PROPERTY_HINT_RESOURCE_TYPE)
	assert_true(str(property_definition.get("hint_string", "")).contains("Resource"))

func test_validates_required_settings_with_rs_spawn_recovery_settings() -> void:
	var component_script: Script = _load_script(C_SPAWN_RECOVERY_COMPONENT_PATH)
	var settings_script: Script = _load_script(RS_SPAWN_RECOVERY_SETTINGS_PATH)
	if component_script == null or settings_script == null:
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
	assert_push_error("C_SpawnRecoveryComponent missing settings")

	var settings_component: BaseECSComponent = component_script.new()
	settings_component.set("settings", settings_script.new())
	entity.add_child(settings_component)
	autofree(settings_component)
	await _pump()

	var components := manager.get_components(StringName("C_SpawnRecoveryComponent"))
	assert_eq(components.size(), 1)
	assert_eq(components[0], settings_component)
