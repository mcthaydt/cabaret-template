extends BaseTest

const ECS_MANAGER := preload("res://scripts/managers/m_ecs_manager.gd")
const ECS_UTILS := preload("res://scripts/utils/u_ecs_utils.gd")
const FLOATING_COMPONENT := preload("res://scripts/ecs/components/c_floating_component.gd")
const MOVEMENT_COMPONENT := preload("res://scripts/ecs/components/c_movement_component.gd")
const FLOATING_SETTINGS := preload("res://scripts/ecs/resources/rs_floating_settings.gd")

func test_get_manager_returns_parent_manager() -> void:
	var manager: M_ECSManager = ECS_MANAGER.new()
	add_child(manager)
	autofree(manager)
	await get_tree().process_frame

	var subject := Node.new()
	manager.add_child(subject)
	autofree(subject)

	var located := ECS_UTILS.get_manager(subject)
	assert_eq(located, manager)

func test_get_manager_falls_back_to_ecs_manager_group() -> void:
	var manager: M_ECSManager = ECS_MANAGER.new()
	add_child(manager)
	autofree(manager)
	await get_tree().process_frame

	var container := Node.new()
	add_child(container)
	autofree(container)

	var subject := Node.new()
	container.add_child(subject)
	autofree(subject)

	var located := ECS_UTILS.get_manager(subject)
	assert_eq(located, manager)

func test_get_manager_returns_null_when_manager_missing() -> void:
	var subject := Node.new()
	add_child(subject)
	autofree(subject)

	var located := ECS_UTILS.get_manager(subject)
	assert_null(located)

func test_get_current_time_returns_seconds() -> void:
	var before: float = float(Time.get_ticks_msec()) / 1000.0
	var current_time: float = ECS_UTILS.get_current_time()
	var after: float = float(Time.get_ticks_msec()) / 1000.0

	assert_eq(typeof(current_time), TYPE_FLOAT)
	assert_true(current_time >= before)
	assert_true(current_time <= after)

func test_map_components_by_body_groups_components() -> void:
	var manager: M_ECSManager = ECS_MANAGER.new()
	add_child(manager)
	autofree(manager)
	await get_tree().process_frame

	var bodies: Array = []
	var components: Array = []
	for i in range(3):
		var body := CharacterBody3D.new()
		add_child(body)
		autofree(body)
		bodies.append(body)

		var floating := FLOATING_COMPONENT.new()
		floating.settings = FLOATING_SETTINGS.new()
		add_child(floating)
		autofree(floating)

		floating.character_body_path = floating.get_path_to(body)
		await get_tree().process_frame
		components.append(floating)

	var mapping: Dictionary = ECS_UTILS.map_components_by_body(manager, FLOATING_COMPONENT.COMPONENT_TYPE)
	assert_eq(mapping.size(), 3)
	for index in range(bodies.size()):
		var body: CharacterBody3D = bodies[index]
		var component: C_FloatingComponent = mapping.get(body, null)
		assert_eq(component, components[index])
