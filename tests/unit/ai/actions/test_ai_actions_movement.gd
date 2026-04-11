extends BaseTest

const ACTION_MOVE_TO_PATH := "res://scripts/resources/ai/actions/rs_ai_action_move_to.gd"
const ACTION_SCAN_PATH := "res://scripts/resources/ai/actions/rs_ai_action_scan.gd"
const ACTION_ANIMATE_PATH := "res://scripts/resources/ai/actions/rs_ai_action_animate.gd"
const C_MOVE_TARGET_COMPONENT := preload("res://scripts/ecs/components/c_move_target_component.gd")

func _load_script(path: String) -> Script:
	var script_variant: Variant = load(path)
	assert_not_null(script_variant, "Expected script to exist: %s" % path)
	if script_variant == null or not (script_variant is Script):
		return null
	return script_variant as Script

func _assert_vector3_almost_eq(actual: Vector3, expected: Vector3, epsilon: float = 0.0001) -> void:
	assert_almost_eq(actual.x, expected.x, epsilon)
	assert_almost_eq(actual.y, expected.y, epsilon)
	assert_almost_eq(actual.z, expected.z, epsilon)

func _new_move_target_component() -> Variant:
	return C_MOVE_TARGET_COMPONENT.new()

func test_move_to_action_sets_target_in_task_state() -> void:
	var action_script: Script = _load_script(ACTION_MOVE_TO_PATH)
	if action_script == null:
		return

	var action: Resource = action_script.new()
	action.set("target_position", Vector3(3.0, 0.0, 2.0))

	var context: Dictionary = {}
	var task_state: Dictionary = {}
	action.start(context, task_state)

	assert_true(task_state.has("ai_move_target"))
	var target_variant: Variant = task_state.get("ai_move_target", Vector3.ZERO)
	assert_true(target_variant is Vector3)
	if target_variant is Vector3:
		_assert_vector3_almost_eq(target_variant as Vector3, Vector3(3.0, 0.0, 2.0))

func test_move_to_action_routes_to_move_target_component_when_present() -> void:
	var action_script: Script = _load_script(ACTION_MOVE_TO_PATH)
	if action_script == null:
		return

	var action: Resource = action_script.new()
	action.set("target_position", Vector3(3.0, 0.0, 2.0))
	action.set("arrival_threshold", 0.27)
	var move_target_component: Variant = _new_move_target_component()
	autofree(move_target_component)

	var context: Dictionary = {
		"components": {
			C_MOVE_TARGET_COMPONENT.COMPONENT_TYPE: move_target_component,
		},
	}
	var task_state: Dictionary = {}
	action.start(context, task_state)

	var is_active_variant: Variant = move_target_component.get("is_active")
	assert_true(is_active_variant is bool and bool(is_active_variant))
	var target_position_variant: Variant = move_target_component.get("target_position")
	assert_true(target_position_variant is Vector3)
	if target_position_variant is Vector3:
		_assert_vector3_almost_eq(target_position_variant as Vector3, Vector3(3.0, 0.0, 2.0))
	var arrival_threshold_variant: Variant = move_target_component.get("arrival_threshold")
	assert_true(arrival_threshold_variant is float or arrival_threshold_variant is int)
	assert_almost_eq(float(arrival_threshold_variant), 0.27, 0.0001)

func test_move_to_start_writes_arrival_threshold_to_task_state() -> void:
	var action_script: Script = _load_script(ACTION_MOVE_TO_PATH)
	if action_script == null:
		return

	var action: Resource = action_script.new()
	action.set("target_position", Vector3(2.0, 0.0, 1.0))
	action.set("arrival_threshold", 0.27)

	var context: Dictionary = {}
	var task_state: Dictionary = {}
	action.start(context, task_state)

	assert_true(task_state.has("ai_arrival_threshold"))
	assert_almost_eq(float(task_state.get("ai_arrival_threshold", -1.0)), 0.27, 0.0001)

func test_move_to_action_completes_when_within_threshold() -> void:
	var action_script: Script = _load_script(ACTION_MOVE_TO_PATH)
	if action_script == null:
		return

	var action: Resource = action_script.new()
	action.set("target_position", Vector3(1.0, 0.0, 1.0))
	action.set("arrival_threshold", 0.5)

	var context: Dictionary = {
		"entity_position": Vector3(1.2, 5.0, 1.1),
	}
	var task_state: Dictionary = {}
	action.start(context, task_state)

	assert_true(action.is_complete(context, task_state))

func test_move_to_action_completion_deactivates_move_target_component() -> void:
	var action_script: Script = _load_script(ACTION_MOVE_TO_PATH)
	if action_script == null:
		return

	var action: Resource = action_script.new()
	action.set("target_position", Vector3(1.0, 0.0, 1.0))
	action.set("arrival_threshold", 0.5)
	var move_target_component: Variant = _new_move_target_component()
	autofree(move_target_component)

	var context: Dictionary = {
		"entity_position": Vector3(1.2, 5.0, 1.1),
		"components": {
			C_MOVE_TARGET_COMPONENT.COMPONENT_TYPE: move_target_component,
		},
	}
	var task_state: Dictionary = {}
	action.start(context, task_state)
	var is_active_variant: Variant = move_target_component.get("is_active")
	assert_true(is_active_variant is bool and bool(is_active_variant))

	assert_true(action.is_complete(context, task_state))
	var inactive_variant: Variant = move_target_component.get("is_active")
	assert_true(inactive_variant is bool and not bool(inactive_variant))

func test_move_to_action_stays_active_when_far() -> void:
	var action_script: Script = _load_script(ACTION_MOVE_TO_PATH)
	if action_script == null:
		return

	var action: Resource = action_script.new()
	action.set("target_position", Vector3(8.0, 0.0, 0.0))
	action.set("arrival_threshold", 0.5)

	var context: Dictionary = {
		"entity_position": Vector3.ZERO,
	}
	var task_state: Dictionary = {}
	action.start(context, task_state)

	assert_false(action.is_complete(context, task_state))

func test_move_to_action_resolves_waypoint_index() -> void:
	var action_script: Script = _load_script(ACTION_MOVE_TO_PATH)
	if action_script == null:
		return

	var action: Resource = action_script.new()
	action.set("target_position", Vector3(99.0, 0.0, 99.0))
	action.set("waypoint_index", 1)

	var context: Dictionary = {
		"waypoints": [
			Vector3(1.0, 0.0, 0.0),
			Vector3(7.0, 0.0, -2.0),
		],
	}
	var task_state: Dictionary = {}
	action.start(context, task_state)

	var target_variant: Variant = task_state.get("ai_move_target", Vector3.ZERO)
	assert_true(target_variant is Vector3)
	if target_variant is Vector3:
		_assert_vector3_almost_eq(target_variant as Vector3, Vector3(7.0, 0.0, -2.0))

func test_move_to_action_resolves_target_node_path_from_entity_context() -> void:
	var action_script: Script = _load_script(ACTION_MOVE_TO_PATH)
	if action_script == null:
		return

	var action: Resource = action_script.new()
	action.set("target_position", Vector3(99.0, 0.0, 99.0))
	action.set("target_node_path", NodePath("TargetMarker"))

	var root := Node3D.new()
	add_child_autofree(root)
	var entity := Node3D.new()
	entity.name = "E_TestAgent"
	root.add_child(entity)
	var target := Node3D.new()
	target.name = "TargetMarker"
	entity.add_child(target)
	target.global_position = Vector3(12.0, 2.0, -4.0)

	var context: Dictionary = {
		"entity": entity,
	}
	var task_state: Dictionary = {}
	action.start(context, task_state)

	var target_variant: Variant = task_state.get("ai_move_target", Vector3.ZERO)
	assert_true(target_variant is Vector3)
	if target_variant is Vector3:
		_assert_vector3_almost_eq(target_variant as Vector3, Vector3(12.0, 2.0, -4.0))

func test_move_to_action_target_node_path_falls_back_to_owner_node() -> void:
	var action_script: Script = _load_script(ACTION_MOVE_TO_PATH)
	if action_script == null:
		return

	var action: Resource = action_script.new()
	action.set("target_position", Vector3(99.0, 0.0, 99.0))
	action.set("target_node_path", NodePath("TargetMarker"))

	var root := Node3D.new()
	add_child_autofree(root)
	var owner_node := Node3D.new()
	owner_node.name = "OwnerNode"
	root.add_child(owner_node)
	var target := Node3D.new()
	target.name = "TargetMarker"
	owner_node.add_child(target)
	target.global_position = Vector3(-3.0, 1.5, 8.0)

	var context: Dictionary = {
		"owner_node": owner_node,
	}
	var task_state: Dictionary = {}
	action.start(context, task_state)

	var target_variant: Variant = task_state.get("ai_move_target", Vector3.ZERO)
	assert_true(target_variant is Vector3)
	if target_variant is Vector3:
		_assert_vector3_almost_eq(target_variant as Vector3, Vector3(-3.0, 1.5, 8.0))

func test_move_to_action_target_node_path_falls_back_to_direct_target_node() -> void:
	var action_script: Script = _load_script(ACTION_MOVE_TO_PATH)
	if action_script == null:
		return

	var action: Resource = action_script.new()
	action.set("target_position", Vector3(99.0, 0.0, 99.0))
	action.set("target_node_path", NodePath("MissingNode"))

	var root := Node3D.new()
	add_child_autofree(root)
	var direct_target := Node3D.new()
	direct_target.name = "DirectTarget"
	root.add_child(direct_target)
	direct_target.global_position = Vector3(5.0, 0.25, -6.0)

	var context: Dictionary = {
		"target_node": direct_target,
	}
	var task_state: Dictionary = {}
	action.start(context, task_state)

	var target_variant: Variant = task_state.get("ai_move_target", Vector3.ZERO)
	assert_true(target_variant is Vector3)
	if target_variant is Vector3:
		_assert_vector3_almost_eq(target_variant as Vector3, Vector3(5.0, 0.25, -6.0))

func test_scan_action_completes_after_duration() -> void:
	var action_script: Script = _load_script(ACTION_SCAN_PATH)
	if action_script == null:
		return

	var action: Resource = action_script.new()
	action.set("scan_duration", 0.4)
	action.set("rotation_speed", 2.0)

	var context: Dictionary = {}
	var task_state: Dictionary = {}
	action.start(context, task_state)

	assert_true(bool(task_state.get("scan_active", false)))
	assert_almost_eq(float(task_state.get("scan_rotation_speed", -1.0)), 2.0, 0.0001)

	action.tick(context, task_state, 0.1)
	assert_false(action.is_complete(context, task_state))
	action.tick(context, task_state, 0.3)
	assert_true(action.is_complete(context, task_state))
	assert_false(bool(task_state.get("scan_active", true)))

func test_animate_stub_sets_state_field() -> void:
	var action_script: Script = _load_script(ACTION_ANIMATE_PATH)
	if action_script == null:
		return

	var action: Resource = action_script.new()
	action.set("animation_state", StringName("alert"))

	var context: Dictionary = {}
	var task_state: Dictionary = {}
	action.start(context, task_state)

	assert_eq(task_state.get("animation_state", StringName()), StringName("alert"))

func test_animate_stub_completes_immediately() -> void:
	var action_script: Script = _load_script(ACTION_ANIMATE_PATH)
	if action_script == null:
		return

	var action: Resource = action_script.new()
	action.set("animation_state", StringName("scan"))

	var context: Dictionary = {}
	var task_state: Dictionary = {}
	action.start(context, task_state)

	assert_true(action.is_complete(context, task_state))
