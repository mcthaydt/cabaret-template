extends BaseTest

const ECS_MANAGER := preload("res://scripts/managers/m_ecs_manager.gd")
const InputComponentScript := preload("res://scripts/ecs/components/c_input_component.gd")
const RotateComponentScript := preload("res://scripts/ecs/components/c_rotate_to_input_component.gd")
const RotateSystemScript := preload("res://scripts/ecs/systems/s_rotate_to_input_system.gd")
const VCamComponentScript := preload("res://scripts/ecs/components/c_vcam_component.gd")
const OTSModeScript := preload("res://scripts/resources/display/vcam/rs_vcam_mode_ots.gd")
const OrbitModeScript := preload("res://scripts/resources/display/vcam/rs_vcam_mode_orbit.gd")
const U_VCAM_ACTIONS := preload("res://scripts/state/actions/u_vcam_actions.gd")

func _pump() -> void:
	await get_tree().process_frame

func _setup_context() -> Dictionary:
	# Create M_StateStore first (required by systems)
	var store := M_StateStore.new()
	store.settings = RS_StateStoreSettings.new()
	store.settings.enable_persistence = false
	store.gameplay_initial_state = RS_GameplayInitialState.new()
	add_child(store)
	autofree(store)
	await _pump()
	
	var manager := ECS_MANAGER.new()
	add_child(manager)
	await _pump()

	var entity := Node.new()
	entity.name = "E_RotateInputTest"
	manager.add_child(entity)
	autofree(entity)
	await _pump()

	var input: C_InputComponent = InputComponentScript.new()
	entity.add_child(input)
	await _pump()

	var target := Node3D.new()
	entity.add_child(target)
	await _pump()

	var component: C_RotateToInputComponent = RotateComponentScript.new()
	component.settings = RS_RotateToInputSettings.new()
	entity.add_child(component)
	await _pump()

	component.target_node_path = component.get_path_to(target)

	var system := RotateSystemScript.new()
	manager.add_child(system)
	await _pump()

	return {
		"store": store,
		"manager": manager,
		"input": input,
		"target": target,
		"component": component,
		"system": system,
	}

func test_rotates_right_input_to_positive_x() -> void:
	var context := await _setup_context()
	autofree_context(context)
	var input: C_InputComponent = context["input"]
	var target: Node3D = context["target"]
	var manager: M_ECSManager = context["manager"]

	input.set_move_vector(Vector2.RIGHT)
	manager._physics_process(1.0)

	var expected := -PI / 2.0
	assert_almost_eq(wrapf(target.rotation.y, -PI, PI), expected, 0.001)

func test_rotates_left_input_to_negative_x() -> void:
	var context := await _setup_context()
	autofree_context(context)
	var input: C_InputComponent = context["input"]
	var target: Node3D = context["target"]
	var manager: M_ECSManager = context["manager"]

	input.set_move_vector(Vector2.LEFT)
	manager._physics_process(1.0)

	var expected := PI / 2.0
	assert_almost_eq(wrapf(target.rotation.y, -PI, PI), expected, 0.001)

func test_rotate_component_has_no_input_nodepath_export() -> void:
	var component: C_RotateToInputComponent = RotateComponentScript.new()
	component.settings = RS_RotateToInputSettings.new()
	add_child(component)
	autofree(component)
	await _pump()

	var has_input_property := false
	for property in component.get_property_list():
		if property.name == "input_component_path":
			has_input_property = true
			break
	assert_false(has_input_property, "C_RotateToInputComponent should not expose input_component_path.")

func test_ots_lock_facing_to_camera_rotates_toward_camera_yaw_with_no_move_input() -> void:
	var context := await _setup_context()
	autofree_context(context)
	var target: Node3D = context["target"]
	var manager: M_ECSManager = context["manager"]
	var store: M_StateStore = context["store"]

	target.rotation.y = deg_to_rad(180.0)
	_create_active_camera(90.0)
	await _pump()
	var ots_mode: RS_VCamModeOTS = OTSModeScript.new()
	ots_mode.lock_facing_to_camera = true
	await _create_vcam_component(manager, StringName("cam_ots_lock"), ots_mode)
	_set_active_vcam(store, StringName("cam_ots_lock"), "ots")

	manager._physics_process(0.25)

	assert_almost_eq(rad_to_deg(wrapf(target.rotation.y, -PI, PI)), 90.0, 2.0)

func test_ots_lock_facing_to_camera_ignores_strafe_direction_changes() -> void:
	var context := await _setup_context()
	autofree_context(context)
	var input: C_InputComponent = context["input"]
	var target: Node3D = context["target"]
	var manager: M_ECSManager = context["manager"]
	var store: M_StateStore = context["store"]

	target.rotation.y = 0.0
	_create_active_camera(-45.0)
	await _pump()
	var ots_mode: RS_VCamModeOTS = OTSModeScript.new()
	ots_mode.lock_facing_to_camera = true
	await _create_vcam_component(manager, StringName("cam_ots_strafe_lock"), ots_mode)
	_set_active_vcam(store, StringName("cam_ots_strafe_lock"), "ots")

	input.set_move_vector(Vector2.LEFT)
	manager._physics_process(0.25)
	var left_yaw: float = wrapf(target.rotation.y, -PI, PI)

	input.set_move_vector(Vector2.RIGHT)
	manager._physics_process(0.25)
	var right_yaw: float = wrapf(target.rotation.y, -PI, PI)

	assert_almost_eq(rad_to_deg(left_yaw), -45.0, 2.0)
	assert_almost_eq(rad_to_deg(right_yaw), -45.0, 2.0)

func test_exit_ots_lock_reverts_to_move_direction_facing() -> void:
	var context := await _setup_context()
	autofree_context(context)
	var input: C_InputComponent = context["input"]
	var target: Node3D = context["target"]
	var manager: M_ECSManager = context["manager"]
	var store: M_StateStore = context["store"]

	_create_active_camera(0.0)
	await _pump()
	var ots_mode: RS_VCamModeOTS = OTSModeScript.new()
	ots_mode.lock_facing_to_camera = true
	await _create_vcam_component(manager, StringName("cam_ots_then_orbit"), ots_mode)
	await _create_vcam_component(manager, StringName("cam_orbit_follow"), OrbitModeScript.new())

	input.set_move_vector(Vector2.RIGHT)
	_set_active_vcam(store, StringName("cam_ots_then_orbit"), "ots")
	manager._physics_process(0.25)
	var ots_locked_yaw: float = wrapf(target.rotation.y, -PI, PI)

	_set_active_vcam(store, StringName("cam_orbit_follow"), "orbit")
	manager._physics_process(0.25)
	var orbit_move_yaw: float = wrapf(target.rotation.y, -PI, PI)

	assert_almost_eq(rad_to_deg(ots_locked_yaw), 0.0, 2.0)
	assert_almost_eq(rad_to_deg(orbit_move_yaw), -90.0, 2.0)

func _create_vcam_component(manager: M_ECSManager, vcam_id: StringName, mode: Resource) -> C_VCamComponent:
	var vcam_entity := Node3D.new()
	vcam_entity.name = "E_%sVcam" % String(vcam_id)
	manager.add_child(vcam_entity)
	autofree(vcam_entity)
	await _pump()

	var component := VCamComponentScript.new()
	component.vcam_id = vcam_id
	component.mode = mode
	vcam_entity.add_child(component)
	await _pump()
	return component

func _create_active_camera(yaw_degrees: float) -> Camera3D:
	var camera := Camera3D.new()
	camera.current = true
	camera.rotation.y = deg_to_rad(yaw_degrees)
	add_child_autofree(camera)
	return camera

func _set_active_vcam(store: M_StateStore, vcam_id: StringName, mode: String) -> void:
	store.dispatch(U_VCAM_ACTIONS.set_active_runtime(vcam_id, mode))
