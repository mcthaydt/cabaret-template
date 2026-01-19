extends BaseTest

const ECS_MANAGER := preload("res://scripts/managers/m_ecs_manager.gd")
const ECS_UTILS := preload("res://scripts/utils/u_ecs_utils.gd")
const FLOATING_COMPONENT := preload("res://scripts/ecs/components/c_floating_component.gd")
const MOVEMENT_COMPONENT := preload("res://scripts/ecs/components/c_movement_component.gd")
const FLOATING_SETTINGS := preload("res://scripts/ecs/resources/rs_floating_settings.gd")
const CAMERA_MANAGER := preload("res://scripts/managers/m_camera_manager.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")

func before_each() -> void:
	U_SERVICE_LOCATOR.clear()
	ECS_UTILS.reset_warning_handler()

func after_each() -> void:
	ECS_UTILS.reset_warning_handler()
	U_SERVICE_LOCATOR.clear()

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

func test_find_entity_root_detects_ecs_entity() -> void:
	var manager: M_ECSManager = ECS_MANAGER.new()
	add_child(manager)
	autofree(manager)
	await get_tree().process_frame

	var entity_script := load("res://scripts/ecs/base_ecs_entity.gd")
	var entity := entity_script.new() as Node3D
	entity.name = "E_Base"
	manager.add_child(entity)
	autofree(entity)

	var component := Node.new()
	entity.add_child(component)
	autofree(component)
	await get_tree().process_frame

	var located := ECS_UTILS.find_entity_root(component)
	assert_eq(located, entity)
	assert_eq(manager.get_cached_entity_for(component), entity)

func test_find_entity_root_falls_back_to_prefix() -> void:
	var entity := Node3D.new()
	entity.name = "E_Prefixed"
	add_child(entity)
	autofree(entity)

	var component := Node.new()
	entity.add_child(component)
	autofree(component)

	var located := ECS_UTILS.find_entity_root(component)
	assert_eq(located, entity)

func test_find_entity_root_warns_when_missing() -> void:
	var warnings: Array = []
	ECS_UTILS.set_warning_handler(
		func(message: String) -> void:
			warnings.append(message)
	)

	var orphan := Node.new()
	add_child(orphan)
	autofree(orphan)

	var located := ECS_UTILS.find_entity_root(orphan, true)
	assert_null(located)
	assert_false(warnings.is_empty())
	var warning_text := String(warnings[0])
	assert_true(warning_text.find("no ECS entity root") != -1)

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

		var entity := Node.new()
		entity.name = "E_Floating_%d" % i
		add_child(entity)
		autofree(entity)

		var floating := FLOATING_COMPONENT.new()
		floating.settings = FLOATING_SETTINGS.new()
		entity.add_child(floating)
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

func test_get_singleton_from_group_returns_first_node() -> void:
	var group_name := StringName("test_singleton")
	var singleton := Node.new()
	singleton.add_to_group(group_name)
	add_child(singleton)
	autofree(singleton)

	var seeker := Node.new()
	add_child(seeker)
	autofree(seeker)
	await get_tree().process_frame

	var located := ECS_UTILS.get_singleton_from_group(seeker, group_name)
	assert_eq(located, singleton)

func test_get_singleton_from_group_returns_null_when_empty() -> void:
	var seeker := Node.new()
	add_child(seeker)
	autofree(seeker)
	await get_tree().process_frame

	var located := ECS_UTILS.get_singleton_from_group(seeker, StringName("nonexistent_group"), false)
	assert_null(located)

func test_get_nodes_from_group_returns_all_members() -> void:
	var group_name := StringName("spawn_points")
	var members: Array = []
	for i in range(3):
		var node := Node.new()
		node.add_to_group(group_name)
		add_child(node)
		autofree(node)
		members.append(node)

	var seeker := Node.new()
	add_child(seeker)
	autofree(seeker)
	await get_tree().process_frame

	var located: Array = ECS_UTILS.get_nodes_from_group(seeker, group_name)
	assert_eq(located.size(), members.size())
	for member in members:
		assert_true(located.has(member))

func test_get_active_camera_uses_viewport_camera_first() -> void:
	var camera := Camera3D.new()
	camera.current = true
	add_child(camera)
	autofree(camera)

	var seeker := Node.new()
	add_child(seeker)
	autofree(seeker)
	await get_tree().process_frame

	var active_camera := ECS_UTILS.get_active_camera(seeker)
	assert_eq(active_camera, camera)

func test_get_active_camera_uses_camera_manager_when_viewport_missing() -> void:
	var viewport := get_viewport()
	var existing_camera := viewport.get_camera_3d()
	if existing_camera != null:
		existing_camera.current = false
	await get_tree().process_frame

	var camera_manager := CAMERA_MANAGER.new()
	add_child(camera_manager)
	autofree(camera_manager)
	await get_tree().process_frame

	var camera := Camera3D.new()
	camera.current = false
	camera_manager.add_child(camera)
	camera_manager.register_main_camera(camera)
	await get_tree().process_frame

	var seeker := Node.new()
	add_child(seeker)
	autofree(seeker)
	await get_tree().process_frame

	var active_camera := ECS_UTILS.get_active_camera(seeker)
	assert_eq(active_camera, camera)

func test_get_active_camera_returns_null_when_missing() -> void:
	var viewport := get_viewport()
	var existing_camera := viewport.get_camera_3d()
	if existing_camera != null:
		existing_camera.current = false
	await get_tree().process_frame

	var seeker := Node.new()
	add_child(seeker)
	autofree(seeker)
	await get_tree().process_frame

	var active_camera := ECS_UTILS.get_active_camera(seeker)
	assert_null(active_camera)

func test_get_singleton_from_group_emits_warning_when_missing() -> void:
	var warnings: Array = []
	ECS_UTILS.set_warning_handler(
		func(message: String) -> void:
			warnings.append(message)
	)

	var seeker := Node.new()
	add_child(seeker)
	autofree(seeker)
	await get_tree().process_frame

	var located := ECS_UTILS.get_singleton_from_group(seeker, StringName("missing_group"))
	assert_null(located)
	assert_eq(warnings.size(), 1)
	assert_true(String(warnings[0]).contains("missing_group"))

func test_get_singleton_from_group_suppresses_warning_when_disabled() -> void:
	var warnings: Array = []
	ECS_UTILS.set_warning_handler(
		func(message: String) -> void:
			warnings.append(message)
	)

	var seeker := Node.new()
	add_child(seeker)
	autofree(seeker)
	await get_tree().process_frame

	var located := ECS_UTILS.get_singleton_from_group(seeker, StringName("missing_group"), false)
	assert_null(located)
	assert_true(warnings.is_empty())
