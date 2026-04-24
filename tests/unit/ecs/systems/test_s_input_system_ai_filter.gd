extends BaseTest

const S_INPUT_SYSTEM_PATH := "res://scripts/ecs/systems/s_input_system.gd"
const BASE_ECS_SYSTEM := preload("res://scripts/ecs/base_ecs_system.gd")
const MOCK_ECS_MANAGER := preload("res://tests/mocks/mock_ecs_manager.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")
const C_INPUT_COMPONENT := preload("res://scripts/ecs/components/c_input_component.gd")
const C_PLAYER_TAG_COMPONENT := preload("res://scripts/ecs/components/c_player_tag_component.gd")
const I_INPUT_SOURCE := preload("res://scripts/core/interfaces/i_input_source.gd")
const M_INPUT_DEVICE_MANAGER := preload("res://scripts/core/managers/m_input_device_manager.gd")

class InputSourceStub extends I_INPUT_SOURCE:
	var move_input: Vector2 = Vector2.ZERO
	var look_input: Vector2 = Vector2.ZERO
	var sprint_pressed: bool = false

	func capture_input(_delta: float) -> Dictionary:
		return {
			"move_input": move_input,
			"look_input": look_input,
			"camera_center_just_pressed": false,
			"jump_pressed": false,
			"jump_just_pressed": false,
			"sprint_pressed": sprint_pressed,
			"device_id": -1,
		}

class InputDeviceManagerStub extends M_INPUT_DEVICE_MANAGER:
	var source: I_INPUT_SOURCE = null

	func get_input_source_for_device(_device_type: int) -> I_INPUT_SOURCE:
		return source

func _load_script(path: String) -> Script:
	var script_variant: Variant = load(path)
	assert_not_null(script_variant, "Expected script to exist: %s" % path)
	if script_variant == null or not (script_variant is Script):
		return null
	return script_variant as Script

func _create_fixture() -> Dictionary:
	var system_script: Script = _load_script(S_INPUT_SYSTEM_PATH)
	if system_script == null:
		return {}

	var ecs_manager := MOCK_ECS_MANAGER.new()
	autofree(ecs_manager)
	var store := MOCK_STATE_STORE.new()
	autofree(store)

	var input_source := InputSourceStub.new()
	input_source.move_input = Vector2(0.75, -0.25)
	input_source.look_input = Vector2(1.0, 0.0)

	var input_device_manager := InputDeviceManagerStub.new()
	autofree(input_device_manager)
	input_device_manager.source = input_source

	var system_variant: Variant = system_script.new()
	assert_true(system_variant is BASE_ECS_SYSTEM, "S_InputSystem should extend BaseECSSystem")
	if not (system_variant is BaseECSSystem):
		return {}
	var system: BaseECSSystem = system_variant as BaseECSSystem
	autofree(system)
	system.state_store = store
	system.ecs_manager = ecs_manager
	system.set("_manager", ecs_manager)
	system.set("_actions_validated", true)
	system.set("_actions_valid", true)
	system.set("_input_device_manager", input_device_manager)

	var player_entity := Node3D.new()
	player_entity.name = "E_Player"
	autofree(player_entity)
	var player_input: C_InputComponent = C_INPUT_COMPONENT.new()
	player_entity.add_child(player_input)
	autofree(player_input)
	var player_tag: C_PlayerTagComponent = C_PLAYER_TAG_COMPONENT.new()
	player_entity.add_child(player_tag)
	autofree(player_tag)
	ecs_manager.add_component_to_entity(player_entity, player_input)
	ecs_manager.add_component_to_entity(player_entity, player_tag)

	var ai_entity := Node3D.new()
	ai_entity.name = "E_Agent"
	autofree(ai_entity)
	var ai_input: C_InputComponent = C_INPUT_COMPONENT.new()
	ai_entity.add_child(ai_input)
	autofree(ai_input)
	ecs_manager.add_component_to_entity(ai_entity, ai_input)

	return {
		"system": system,
		"store": store,
		"ecs_manager": ecs_manager,
		"player_input": player_input,
		"ai_input": ai_input,
	}

func test_input_system_skips_entities_without_player_tag() -> void:
	var fixture: Dictionary = _create_fixture()
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var system: BaseECSSystem = fixture["system"] as BaseECSSystem
	var ai_input: C_InputComponent = fixture["ai_input"] as C_InputComponent
	ai_input.set_move_vector(Vector2(0.2, 0.9))

	system.process_tick(0.016)

	assert_eq(ai_input.move_vector, Vector2(0.2, 0.9))

func test_input_system_still_writes_to_player_entity() -> void:
	var fixture: Dictionary = _create_fixture()
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var system: BaseECSSystem = fixture["system"] as BaseECSSystem
	var player_input: C_InputComponent = fixture["player_input"] as C_InputComponent

	system.process_tick(0.016)

	assert_almost_eq(player_input.move_vector.x, 0.75, 0.0001)
	assert_almost_eq(player_input.move_vector.y, -0.25, 0.0001)
