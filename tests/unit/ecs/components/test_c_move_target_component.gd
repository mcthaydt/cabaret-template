extends BaseTest

const BASE_ECS_COMPONENT := preload("res://scripts/ecs/base_ecs_component.gd")
const C_MOVE_TARGET_COMPONENT_PATH := "res://scripts/ecs/components/c_move_target_component.gd"

func _load_script(path: String) -> Script:
	var script_variant: Variant = load(path)
	assert_not_null(script_variant, "Expected script to exist: %s" % path)
	if script_variant == null or not (script_variant is Script):
		return null
	return script_variant as Script

func test_component_type_constant() -> void:
	var component_script: Script = _load_script(C_MOVE_TARGET_COMPONENT_PATH)
	if component_script == null:
		return

	var component_variant: Variant = component_script.new()
	assert_true(component_variant is BASE_ECS_COMPONENT, "C_MoveTargetComponent should extend BaseECSComponent")
	if not (component_variant is BaseECSComponent):
		return
	var component: BaseECSComponent = component_variant as BaseECSComponent
	autofree(component)
	assert_eq(component.get_component_type(), StringName("C_MoveTargetComponent"))

func test_target_position_default_zero() -> void:
	var component_script: Script = _load_script(C_MOVE_TARGET_COMPONENT_PATH)
	if component_script == null:
		return

	var component: BaseECSComponent = component_script.new()
	autofree(component)
	assert_eq(component.get("target_position"), Vector3.ZERO)

func test_arrival_threshold_default() -> void:
	var component_script: Script = _load_script(C_MOVE_TARGET_COMPONENT_PATH)
	if component_script == null:
		return

	var component: BaseECSComponent = component_script.new()
	autofree(component)
	assert_almost_eq(float(component.get("arrival_threshold")), 0.5, 0.0001)

func test_is_active_toggle() -> void:
	var component_script: Script = _load_script(C_MOVE_TARGET_COMPONENT_PATH)
	if component_script == null:
		return

	var component: BaseECSComponent = component_script.new()
	autofree(component)
	component.set("is_active", true)
	assert_true(bool(component.get("is_active")))
	component.set("is_active", false)
	assert_false(bool(component.get("is_active")))
