extends BaseTest

const C_NEEDS_COMPONENT_PATH := "res://scripts/demo/ecs/components/c_needs_component.gd"
const RS_NEEDS_SETTINGS_PATH := "res://scripts/core/resources/ecs/rs_needs_settings.gd"

func _load_required_script(path: String) -> Script:
	var script_variant: Variant = load(path)
	assert_not_null(script_variant, "Expected script to exist: %s" % path)
	if script_variant == null or not (script_variant is Script):
		return null
	return script_variant as Script

func _instantiate_component(component_script: Script) -> BaseECSComponent:
	var component_variant: Variant = component_script.new()
	assert_true(component_variant is BaseECSComponent, "C_NeedsComponent should extend BaseECSComponent")
	if not (component_variant is BaseECSComponent):
		return null
	return component_variant as BaseECSComponent

func _create_component_with_settings(initial_hunger: float) -> BaseECSComponent:
	var component_script: Script = _load_required_script(C_NEEDS_COMPONENT_PATH)
	var settings_script: Script = _load_required_script(RS_NEEDS_SETTINGS_PATH)
	if component_script == null or settings_script == null:
		return null

	var component: BaseECSComponent = _instantiate_component(component_script)
	if component == null:
		return null

	var settings: Resource = settings_script.new()
	settings.set("initial_hunger", initial_hunger)
	component.set("settings", settings)
	return component

func test_component_type_constant() -> void:
	var component_script: Script = _load_required_script(C_NEEDS_COMPONENT_PATH)
	if component_script == null:
		return

	var constants := component_script.get_script_constant_map()
	assert_eq(constants.get("COMPONENT_TYPE", StringName("")), StringName("C_NeedsComponent"))

func test_validate_required_settings_rejects_null_settings() -> void:
	var component_script: Script = _load_required_script(C_NEEDS_COMPONENT_PATH)
	if component_script == null:
		return

	var component: BaseECSComponent = _instantiate_component(component_script)
	if component == null:
		return
	autofree(component)

	var is_valid: bool = component._validate_required_settings()
	assert_false(is_valid)
	assert_push_error("C_NeedsComponent missing settings")

func test_hunger_initializes_from_settings_initial_hunger() -> void:
	var component: BaseECSComponent = _create_component_with_settings(0.35)
	if component == null:
		return

	var entity := Node3D.new()
	entity.name = "E_TestEntity"
	add_child_autofree(entity)
	entity.add_child(component)
	await get_tree().process_frame

	assert_almost_eq(float(component.get("hunger")), 0.35, 0.0001)

func test_hunger_initialization_clamps_to_range_zero_to_one() -> void:
	var entity := Node3D.new()
	entity.name = "E_TestEntity"
	add_child_autofree(entity)

	var component_low: BaseECSComponent = _create_component_with_settings(-0.25)
	if component_low == null:
		return
	entity.add_child(component_low)
	await get_tree().process_frame
	assert_eq(float(component_low.get("hunger")), 0.0)

	var component_high: BaseECSComponent = _create_component_with_settings(1.8)
	if component_high == null:
		return
	entity.add_child(component_high)
	await get_tree().process_frame
	assert_eq(float(component_high.get("hunger")), 1.0)
