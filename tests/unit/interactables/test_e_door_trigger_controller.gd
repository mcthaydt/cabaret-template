extends BaseTest

const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")
const RS_SCENE_INITIAL_STATE := preload("res://scripts/resources/state/rs_scene_initial_state.gd")
const RS_GAMEPLAY_INITIAL_STATE := preload("res://scripts/resources/state/rs_gameplay_initial_state.gd")

## Minimal stub SceneManager for unit tests
class TestSceneManager:
	extends Node

	class PriorityWrapper:
		var NORMAL: int = 0
		var HIGH: int = 1
		var CRITICAL: int = 2

	var Priority := PriorityWrapper.new()
	var transition_calls: Array = []

	func transition_to_scene(scene_id: StringName, transition_type: String, priority: int = 0) -> void:
		transition_calls.append({
			"scene_id": scene_id,
			"transition_type": transition_type,
			"priority": priority,
		})

	func is_transitioning() -> bool:
		return false

class TestSceneTriggerComponent:
	extends C_SceneTriggerComponent

	var trigger_called: bool = false

	func trigger_interact() -> void:
		trigger_called = true
		super.trigger_interact()

func _pump_frames(count: int = 1) -> void:
	for _i in count:
		await get_tree().process_frame

func before_each() -> void:
	# Provide a minimal state store so C_SceneTriggerComponent can dispatch actions
	var store := M_STATE_STORE.new()
	store.scene_initial_state = RS_SCENE_INITIAL_STATE.new()
	store.gameplay_initial_state = RS_GAMEPLAY_INITIAL_STATE.new()
	add_child(store)
	autofree(store)

	# Provide a minimal scene manager stub for transition calls
	var mgr := TestSceneManager.new()
	add_child(mgr)
	autofree(mgr)

	await _pump_frames(1)

	# Register services with ServiceLocator so components can find them
	U_ServiceLocator.register(StringName("state_store"), store)
	U_ServiceLocator.register(StringName("scene_manager"), mgr)

func after_each() -> void:
	U_ServiceLocator.clear()

func _create_controller() -> Inter_DoorTrigger:
	var controller := Inter_DoorTrigger.new()
	controller.component_factory = Callable(self, "_create_scene_trigger_stub")
	controller.door_id = StringName("door_test")
	controller.target_scene_id = StringName("scene_test")
	controller.target_spawn_point = StringName("spawn_test")
	add_child(controller)
	autofree(controller)
	await _pump_frames(3)
	return controller

func _create_scene_trigger_stub() -> TestSceneTriggerComponent:
	return TestSceneTriggerComponent.new()

func test_creates_component_and_links_area() -> void:
	var controller := await _create_controller()
	var component := _find_component(controller)

	assert_not_null(component, "Door controller should instantiate a scene trigger component.")

	assert_eq(component.door_id, StringName("door_test"))
	assert_eq(component.target_scene_id, StringName("scene_test"))
	assert_eq(component.target_spawn_point, StringName("spawn_test"))

	assert_eq(component.trigger_mode, C_SceneTriggerComponent.TriggerMode.INTERACT, "Component should run in INTERACT mode under controller supervision.")

	var area := controller.get_trigger_area()
	assert_not_null(area, "Controller should expose the trigger Area3D.")
	assert_true(component._trigger_area == area, "Component should reuse controller-managed trigger area.")

func test_activation_calls_component_trigger() -> void:
	var controller := await _create_controller()
	var component := _find_component(controller) as TestSceneTriggerComponent
	assert_not_null(component, "Stub component expected for activation test.")

	# Validate minimal environment
	assert_not_null(U_ServiceLocator.try_get_service(StringName("state_store")),
		"State store should be registered for transition dispatch")
	assert_not_null(U_ServiceLocator.try_get_service(StringName("scene_manager")),
		"Scene manager stub should be registered for transition calls")

	component.trigger_called = false
	var dummy_player := _make_dummy_player()
	controller._on_activated(dummy_player)
	assert_true(component.trigger_called, "Activated door should delegate to component.trigger_interact().")

func _find_component(controller: Node) -> C_SceneTriggerComponent:
	for child in controller.get_children():
		if child is C_SceneTriggerComponent:
			return child as C_SceneTriggerComponent
	return null

func _make_dummy_player() -> Node3D:
	var node := Node3D.new()
	add_child(node)
	autofree(node)
	return node
