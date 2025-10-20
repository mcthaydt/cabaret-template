extends BaseTest

const ECS_MANAGER := preload("res://scripts/managers/m_ecs_manager.gd")
const ECS_UTILS := preload("res://scripts/utils/u_ecs_utils.gd")

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

