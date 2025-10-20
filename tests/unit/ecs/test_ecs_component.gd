extends BaseTest

const ECS_MANAGER := preload("res://scripts/managers/m_ecs_manager.gd")
const ECS_COMPONENT := preload("res://scripts/ecs/ecs_component.gd")
const JUMP_COMPONENT := preload("res://scripts/ecs/components/c_jump_component.gd")
const JUMP_SETTINGS := preload("res://scripts/ecs/resources/rs_jump_settings.gd")

class TestInvalidComponent extends ECS_COMPONENT:
	const TYPE := StringName("C_TestInvalidComponent")
	var validated: bool = false
	var missing_called: bool = false

	func _init() -> void:
		component_type = TYPE

	func _validate_required_settings() -> bool:
		validated = true
		return false

	func _on_required_settings_missing() -> void:
		missing_called = true
		super._on_required_settings_missing()

class TestValidComponent extends ECS_COMPONENT:
	const TYPE := StringName("C_TestValidComponent")
	var validated: bool = false
	var ready_called: bool = false

	func _init() -> void:
		component_type = TYPE

	func _validate_required_settings() -> bool:
		validated = true
		return true

	func _on_required_settings_ready() -> void:
		ready_called = true

func _spawn_manager() -> M_ECSManager:
	var manager: M_ECSManager = ECS_MANAGER.new()
	add_child(manager)
	autofree(manager)
	return manager

func _await_frame() -> void:
	await get_tree().process_frame

func test_validation_failure_prevents_registration() -> void:
	var manager := _spawn_manager()
	await _await_frame()

	var component := TestInvalidComponent.new()
	manager.add_child(component)
	autofree(component)
	await _await_frame()

	assert_true(component.validated)
	assert_true(component.missing_called)
	var registered := manager.get_components(TestInvalidComponent.TYPE)
	assert_eq(registered.size(), 0)
	assert_false(component.is_processing())
	assert_false(component.is_physics_processing())

func test_validation_success_registers_component() -> void:
	var manager := _spawn_manager()
	await _await_frame()

	var component := TestValidComponent.new()
	manager.add_child(component)
	autofree(component)
	await _await_frame()

	assert_true(component.validated)
	assert_true(component.ready_called)
	var registered := manager.get_components(TestValidComponent.TYPE)
	assert_eq(registered, [component])

func test_jump_component_requires_settings() -> void:
	var manager := _spawn_manager()
	await _await_frame()

	var jump := JUMP_COMPONENT.new()
	manager.add_child(jump)
	autofree(jump)
	await _await_frame()
	assert_push_error("C_JumpComponent missing settings")

	var components := manager.get_components(JUMP_COMPONENT.COMPONENT_TYPE)
	assert_eq(components.size(), 0)

func test_jump_component_initializes_air_jump_count_on_validation() -> void:
	var manager := _spawn_manager()
	await _await_frame()

	var jump := JUMP_COMPONENT.new()
	jump.settings = JUMP_SETTINGS.new()
	manager.add_child(jump)
	autofree(jump)
	await _await_frame()

	var components := manager.get_components(JUMP_COMPONENT.COMPONENT_TYPE)
	assert_eq(components, [jump])
	assert_eq(jump._air_jumps_remaining, jump.settings.max_air_jumps)
