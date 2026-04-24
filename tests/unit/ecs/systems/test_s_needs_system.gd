extends BaseTest

const S_NEEDS_SYSTEM_PATH := "res://scripts/demo/ecs/systems/s_needs_system.gd"
const C_NEEDS_COMPONENT_PATH := "res://scripts/demo/ecs/components/c_needs_component.gd"
const RS_NEEDS_SETTINGS_PATH := "res://scripts/core/resources/ecs/rs_needs_settings.gd"

const BASE_ECS_SYSTEM := preload("res://scripts/core/ecs/base_ecs_system.gd")
const BASE_ECS_ENTITY := preload("res://scripts/core/ecs/base_ecs_entity.gd")
const BASE_ECS_COMPONENT := preload("res://scripts/core/ecs/base_ecs_component.gd")
const MOCK_ECS_MANAGER := preload("res://tests/mocks/mock_ecs_manager.gd")

func _load_required_script(path: String) -> Script:
	var script_variant: Variant = load(path)
	assert_not_null(script_variant, "Expected script to exist: %s" % path)
	if script_variant == null or not (script_variant is Script):
		return null
	return script_variant as Script

func _create_system_fixture() -> Dictionary:
	var system_script: Script = _load_required_script(S_NEEDS_SYSTEM_PATH)
	if system_script == null:
		return {}

	var system_variant: Variant = system_script.new()
	assert_true(system_variant is BASE_ECS_SYSTEM, "S_NeedsSystem should extend BaseECSSystem")
	if not (system_variant is BaseECSSystem):
		return {}

	var system: BaseECSSystem = system_variant as BaseECSSystem
	add_child_autofree(system)

	var ecs_manager: MockECSManager = MOCK_ECS_MANAGER.new()
	autofree(ecs_manager)
	system.ecs_manager = ecs_manager
	system.configure(ecs_manager)

	var root := Node3D.new()
	add_child_autofree(root)

	return {
		"system": system,
		"ecs_manager": ecs_manager,
		"root": root,
	}

func _create_needs_component(
	component_script: Script,
	settings_script: Script,
	initial_hunger: float,
	decay_per_second: float
) -> BaseECSComponent:
	var component_variant: Variant = component_script.new()
	assert_true(component_variant is BASE_ECS_COMPONENT, "C_NeedsComponent should extend BaseECSComponent")
	if not (component_variant is BaseECSComponent):
		return null

	var component: BaseECSComponent = component_variant as BaseECSComponent
	var settings: Resource = settings_script.new()
	settings.set("initial_hunger", initial_hunger)
	settings.set("decay_per_second", decay_per_second)
	component.set("settings", settings)
	component.set("hunger", initial_hunger)
	return component

func _register_entity_with_needs(
	fixture: Dictionary,
	name: String,
	component: BaseECSComponent
) -> BaseECSEntity:
	var root: Node3D = fixture.get("root") as Node3D
	var ecs_manager: MockECSManager = fixture.get("ecs_manager") as MockECSManager

	var entity: BaseECSEntity = BASE_ECS_ENTITY.new()
	entity.name = name
	root.add_child(entity)
	autofree(entity)

	entity.add_child(component)
	autofree(component)
	ecs_manager.add_component_to_entity(entity, component)
	return entity

func test_hunger_decays_by_decay_per_second_times_delta() -> void:
	var fixture: Dictionary = _create_system_fixture()
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var component_script: Script = _load_required_script(C_NEEDS_COMPONENT_PATH)
	var settings_script: Script = _load_required_script(RS_NEEDS_SETTINGS_PATH)
	if component_script == null or settings_script == null:
		return

	var needs: BaseECSComponent = _create_needs_component(component_script, settings_script, 0.9, 0.25)
	if needs == null:
		return
	_register_entity_with_needs(fixture, "E_Wolf", needs)

	var system: BaseECSSystem = fixture.get("system") as BaseECSSystem
	system.process_tick(2.0)

	assert_almost_eq(float(needs.get("hunger")), 0.4, 0.0001)

func test_hunger_clamps_at_zero_after_decay() -> void:
	var fixture: Dictionary = _create_system_fixture()
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var component_script: Script = _load_required_script(C_NEEDS_COMPONENT_PATH)
	var settings_script: Script = _load_required_script(RS_NEEDS_SETTINGS_PATH)
	if component_script == null or settings_script == null:
		return

	var needs: BaseECSComponent = _create_needs_component(component_script, settings_script, 0.1, 0.8)
	if needs == null:
		return
	_register_entity_with_needs(fixture, "E_Rabbit", needs)

	var system: BaseECSSystem = fixture.get("system") as BaseECSSystem
	system.process_tick(1.0)

	assert_eq(float(needs.get("hunger")), 0.0)

func test_multiple_entities_decay_independently() -> void:
	var fixture: Dictionary = _create_system_fixture()
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var component_script: Script = _load_required_script(C_NEEDS_COMPONENT_PATH)
	var settings_script: Script = _load_required_script(RS_NEEDS_SETTINGS_PATH)
	if component_script == null or settings_script == null:
		return

	var wolf_needs: BaseECSComponent = _create_needs_component(component_script, settings_script, 1.0, 0.5)
	var deer_needs: BaseECSComponent = _create_needs_component(component_script, settings_script, 0.2, 0.1)
	if wolf_needs == null or deer_needs == null:
		return

	_register_entity_with_needs(fixture, "E_Wolf", wolf_needs)
	_register_entity_with_needs(fixture, "E_Deer", deer_needs)

	var system: BaseECSSystem = fixture.get("system") as BaseECSSystem
	system.process_tick(1.0)

	assert_almost_eq(float(wolf_needs.get("hunger")), 0.5, 0.0001)
	assert_almost_eq(float(deer_needs.get("hunger")), 0.1, 0.0001)
