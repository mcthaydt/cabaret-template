extends BaseTest

const ECS_MANAGER := preload("res://scripts/managers/m_ecs_manager.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")
const CHARACTER_RULE_MANAGER := preload("res://scripts/ecs/systems/s_character_rule_manager.gd")
const MOVEMENT_SYSTEM := preload("res://scripts/ecs/systems/s_movement_system.gd")
const C_CHARACTER_STATE_COMPONENT := preload("res://scripts/ecs/components/c_character_state_component.gd")
const C_MOVEMENT_COMPONENT := preload("res://scripts/ecs/components/c_movement_component.gd")
const C_INPUT_COMPONENT := preload("res://scripts/ecs/components/c_input_component.gd")

class FakeBody extends CharacterBody3D:
	var move_called: bool = false
	var grounded: bool = false

	@warning_ignore("native_method_override")
	func move_and_slide() -> bool:
		move_called = true
		return true

	@warning_ignore("native_method_override")
	func is_on_floor() -> bool:
		return grounded

func _pump() -> void:
	await get_tree().process_frame

func _set_gate_state(store: MockStateStore, paused: bool, shell: String, transitioning: bool) -> void:
	store.set_slice(StringName("gameplay"), {"paused": paused})
	store.set_slice(StringName("navigation"), {"shell": shell})
	store.set_slice(StringName("scene"), {"is_transitioning": transitioning})

func _setup_fixture() -> Dictionary:
	var store := MOCK_STATE_STORE.new()
	autofree(store)
	_set_gate_state(store, false, "gameplay", false)

	var manager := ECS_MANAGER.new()
	add_child(manager)
	autofree(manager)
	await _pump()

	var entity := Node3D.new()
	entity.name = "E_Player"
	manager.add_child(entity)
	autofree(entity)
	await _pump()

	var body := FakeBody.new()
	body.name = "Body"
	entity.add_child(body)
	autofree(body)
	await _pump()

	var character_state := C_CHARACTER_STATE_COMPONENT.new()
	entity.add_child(character_state)
	autofree(character_state)
	await _pump()

	var movement_component := C_MOVEMENT_COMPONENT.new()
	movement_component.settings = RS_MovementSettings.new()
	entity.add_child(movement_component)
	autofree(movement_component)
	await _pump()

	var input_component := C_INPUT_COMPONENT.new()
	entity.add_child(input_component)
	autofree(input_component)
	await _pump()

	var rule_manager := CHARACTER_RULE_MANAGER.new()
	rule_manager.state_store = store
	rule_manager.ecs_manager = manager
	manager.add_child(rule_manager)
	autofree(rule_manager)
	await _pump()

	var movement_system := MOVEMENT_SYSTEM.new()
	movement_system.state_store = store
	movement_system.ecs_manager = manager
	manager.add_child(movement_system)
	autofree(movement_system)
	await _pump()

	return {
		"store": store,
		"manager": manager,
		"body": body,
		"input_component": input_component,
		"character_state": character_state,
	}

func test_brain_data_gates_movement_when_paused_then_allows_when_active() -> void:
	var fixture: Dictionary = await _setup_fixture()
	var store: MockStateStore = fixture["store"] as MockStateStore
	var manager: M_ECSManager = fixture["manager"] as M_ECSManager
	var body: FakeBody = fixture["body"] as FakeBody
	var input_component: C_InputComponent = fixture["input_component"] as C_InputComponent
	var character_state: C_CharacterStateComponent = fixture["character_state"] as C_CharacterStateComponent

	input_component.set_move_vector(Vector2.RIGHT)
	body.velocity = Vector3.ZERO
	body.move_called = false

	_set_gate_state(store, true, "gameplay", false)
	manager._physics_process(0.1)

	assert_false(character_state.is_gameplay_active, "Paused state should set brain-data gate to inactive")
	assert_false(body.move_called, "Movement system should early-out when brain-data gate is inactive")
	assert_almost_eq(body.velocity.x, 0.0, 0.001)

	body.move_called = false
	_set_gate_state(store, false, "gameplay", false)
	manager._physics_process(0.1)

	assert_true(character_state.is_gameplay_active, "Unpaused gameplay shell should set brain-data gate active")
	assert_true(body.move_called, "Movement system should process when brain-data gate is active")
	assert_true(body.velocity.x > 0.0, "Movement should apply horizontal velocity once gate is active")
