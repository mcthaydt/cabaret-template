extends BaseTest

const SYSTEM_PATH := "res://scripts/core/ecs/systems/s_wall_cutout_system.gd"
const CONFIG_PATH := "res://scripts/core/resources/ecs/rs_wall_cutout_config.gd"
const MOCK_ECS_MANAGER := preload("res://tests/mocks/mock_ecs_manager.gd")
const MOCK_CAMERA_MANAGER := preload("res://tests/mocks/mock_camera_manager.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")

const PARAM_PLAYER_POS := &"wall_cutout_player_pos"
const PARAM_CAMERA_POS := &"wall_cutout_camera_pos"
const PARAM_NEAR_RADIUS := &"wall_cutout_near_radius"
const PARAM_FAR_RADIUS := &"wall_cutout_far_radius"
const PARAM_FALLOFF := &"wall_cutout_falloff"
const PARAM_MIN_ALPHA := &"wall_cutout_min_alpha"

const PLAYER_ENTITY_ID := StringName("player")


class StubShaderWriter extends RefCounted:
	var values: Dictionary = {}
	func set_param(param_name: StringName, value: Variant) -> void:
		values[param_name] = value


func _system_script() -> Script:
	var script_obj := load(SYSTEM_PATH) as Script
	assert_not_null(script_obj, "S_WallCutoutSystem script should exist at %s" % SYSTEM_PATH)
	return script_obj


func _config_script() -> Script:
	var script_obj := load(CONFIG_PATH) as Script
	assert_not_null(script_obj, "RS_WallCutoutConfig script should load")
	return script_obj


func _make_config(near_r: float, far_r: float, falloff: float, min_a: float) -> Resource:
	var script_obj := _config_script()
	if script_obj == null:
		return null
	var config: Variant = script_obj.new()
	config.set("cone_near_radius", near_r)
	config.set("cone_far_radius", far_r)
	config.set("cone_falloff", falloff)
	config.set("cone_min_alpha", min_a)
	return config as Resource


func _create_fixture(camera_pos: Vector3, player_pos: Vector3, mode: String) -> Dictionary:
	var system_script := _system_script()
	if system_script == null:
		return {}

	var ecs_manager := MOCK_ECS_MANAGER.new()
	autofree(ecs_manager)

	var camera_manager := MOCK_CAMERA_MANAGER.new()
	autofree(camera_manager)
	var main_camera := Camera3D.new()
	main_camera.global_transform = Transform3D(Basis.IDENTITY, camera_pos)
	main_camera.current = true
	add_child(main_camera)
	autofree(main_camera)
	camera_manager.main_camera = main_camera

	var state_store := MOCK_STATE_STORE.new()
	autofree(state_store)
	state_store.set_slice("vcam", {"active_mode": mode})
	state_store.set_slice("gameplay", {
		"player_entity_id": "player",
		"entities": {
			"player": {
				"id": "player",
				"position": player_pos,
			},
		},
	})

	var system: Variant = system_script.new()
	autofree(system)
	system.ecs_manager = ecs_manager
	system.camera_manager = camera_manager
	system.state_store = state_store
	system.wall_cutout_config = _make_config(0.7, 3.0, 0.4, 0.1)
	var writer := StubShaderWriter.new()
	system.shader_writer = writer
	add_child(system)
	system.configure(ecs_manager)

	return {
		"system": system,
		"camera": main_camera,
		"state_store": state_store,
		"writer": writer,
	}


func _read_vec3(writer: StubShaderWriter, name: StringName) -> Vector3:
	var value: Variant = writer.values.get(name, null)
	if value is Vector3:
		return value
	return Vector3.ZERO


func _read_float(writer: StubShaderWriter, name: StringName) -> float:
	var value: Variant = writer.values.get(name, null)
	if value is float or value is int:
		return float(value)
	return 0.0


# ---- Tests ----

func test_system_script_loads() -> void:
	_system_script()


func test_writes_player_and_camera_position_globals_on_tick() -> void:
	var camera_pos := Vector3(10.0, 5.0, 0.0)
	var player_pos := Vector3(0.0, 1.0, 0.0)
	var fixture := _create_fixture(camera_pos, player_pos, "orbit")
	var system = fixture.get("system")
	var writer: StubShaderWriter = fixture.get("writer")
	assert_not_null(system)

	system.process_tick(0.1)

	assert_eq(_read_vec3(writer, PARAM_PLAYER_POS), player_pos,
		"Should push player position into wall_cutout_player_pos global.")
	assert_eq(_read_vec3(writer, PARAM_CAMERA_POS), camera_pos,
		"Should push camera position into wall_cutout_camera_pos global.")


func test_writes_config_radii_to_globals_on_tick() -> void:
	var fixture := _create_fixture(Vector3.ZERO, Vector3.ZERO, "orbit")
	var system = fixture.get("system")
	var writer: StubShaderWriter = fixture.get("writer")
	assert_not_null(system)

	system.process_tick(0.1)

	assert_almost_eq(_read_float(writer, PARAM_NEAR_RADIUS), 0.7, 0.0001)
	assert_almost_eq(_read_float(writer, PARAM_FAR_RADIUS), 3.0, 0.0001)
	assert_almost_eq(_read_float(writer, PARAM_FALLOFF), 0.4, 0.0001)
	assert_almost_eq(_read_float(writer, PARAM_MIN_ALPHA), 0.1, 0.0001)


func test_disables_cutout_via_sentinel_when_not_orbit_mode() -> void:
	var fixture := _create_fixture(Vector3(10, 5, 0), Vector3(0, 1, 0), "fixed")
	var system = fixture.get("system")
	var writer: StubShaderWriter = fixture.get("writer")
	assert_not_null(system)

	system.process_tick(0.1)

	var sentinel := _read_vec3(writer, PARAM_PLAYER_POS)
	assert_gt(sentinel.length(), 1000.0,
		"When not in orbit mode, player_pos should be a far sentinel so the cutout is effectively disabled. Got: %s" % str(sentinel))


func test_falls_back_to_default_config_when_export_missing() -> void:
	var system_script := _system_script()
	if system_script == null:
		return

	var ecs_manager := MOCK_ECS_MANAGER.new()
	autofree(ecs_manager)
	var camera_manager := MOCK_CAMERA_MANAGER.new()
	autofree(camera_manager)
	var main_camera := Camera3D.new()
	main_camera.current = true
	add_child(main_camera)
	autofree(main_camera)
	camera_manager.main_camera = main_camera
	var state_store := MOCK_STATE_STORE.new()
	autofree(state_store)
	state_store.set_slice("vcam", {"active_mode": "orbit"})
	state_store.set_slice("gameplay", {
		"player_entity_id": "player",
		"entities": {"player": {"id": "player", "position": Vector3.ZERO}},
	})

	var system: Variant = system_script.new()
	autofree(system)
	system.ecs_manager = ecs_manager
	system.camera_manager = camera_manager
	system.state_store = state_store
	var writer := StubShaderWriter.new()
	system.shader_writer = writer
	# Intentionally leave wall_cutout_config null.
	add_child(system)
	system.configure(ecs_manager)

	system.process_tick(0.1)

	assert_gt(_read_float(writer, PARAM_FAR_RADIUS), _read_float(writer, PARAM_NEAR_RADIUS),
		"With null config, system must fall back to default cfg_wall_cutout_config_default.tres so far > near.")
