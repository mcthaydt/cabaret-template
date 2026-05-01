extends BaseTest

const SYSTEM_PATH := "res://scripts/core/ecs/systems/s_wall_cutout_system.gd"
const CONFIG_PATH := "res://scripts/core/resources/ecs/rs_wall_cutout_config.gd"
const SHADER_PATH := "res://assets/core/shaders/sh_wall_cutout.gdshader"
const MOCK_ECS_MANAGER := preload("res://tests/mocks/mock_ecs_manager.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")

const PARAM_PLAYER_POS := &"wall_cutout_player_pos"
const PARAM_DISC_RADIUS := &"wall_cutout_disc_radius"
const PARAM_DISC_FALLOFF := &"wall_cutout_disc_falloff"
const PARAM_DISC_MIN_ALPHA := &"wall_cutout_disc_min_alpha"


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


func _make_config(
	radius: float,
	falloff: float,
	min_a: float,
	center_offset: float = 0.0,
	target_coverage: float = 1.0,
	max_radius: float = 1.0,
	player_height: float = 1.6
) -> Resource:
	var script_obj := _config_script()
	if script_obj == null:
		return null
	var config: Variant = script_obj.new()
	config.set("disc_radius", radius)
	config.set("disc_falloff", falloff)
	config.set("disc_min_alpha", min_a)
	config.set("disc_center_height_offset", center_offset)
	config.set("disc_target_height_coverage", target_coverage)
	config.set("disc_max_radius", max_radius)
	config.set("disc_player_height_meters", player_height)
	return config as Resource


func _create_fixture(player_pos: Vector3, mode: String) -> Dictionary:
	var system_script := _system_script()
	if system_script == null:
		return {}

	var ecs_manager := MOCK_ECS_MANAGER.new()
	autofree(ecs_manager)

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
	system.state_store = state_store
	system.wall_cutout_config = _make_config(0.2, 0.07, 0.1)
	system.debug_wall_cutout_logging = false
	var writer := StubShaderWriter.new()
	system.shader_writer = writer
	add_child(system)
	system.configure(ecs_manager)

	return {
		"system": system,
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


func test_writes_player_position_global_on_tick() -> void:
	var player_pos := Vector3(0.0, 1.0, 0.0)
	var fixture := _create_fixture(player_pos, "orbit")
	var system = fixture.get("system")
	var writer: StubShaderWriter = fixture.get("writer")
	assert_not_null(system)

	system.process_tick(0.1)

	assert_eq(_read_vec3(writer, PARAM_PLAYER_POS), player_pos,
		"Should push player position into wall_cutout_player_pos global.")


func test_writes_visual_center_position_when_config_has_height_offset() -> void:
	var player_pos := Vector3(0.0, 1.0, 0.0)
	var fixture := _create_fixture(player_pos, "orbit")
	var system = fixture.get("system")
	var writer: StubShaderWriter = fixture.get("writer")
	assert_not_null(system)
	system.wall_cutout_config = _make_config(0.2, 0.07, 0.1, 0.85)

	system.process_tick(0.1)

	assert_eq(_read_vec3(writer, PARAM_PLAYER_POS), player_pos + Vector3.UP * 0.85,
		"Cutout center should use the player's visual center, not the ground/root origin.")


func test_writes_disc_params_to_globals_on_tick() -> void:
	var fixture := _create_fixture(Vector3.ZERO, "orbit")
	var system = fixture.get("system")
	var writer: StubShaderWriter = fixture.get("writer")
	assert_not_null(system)

	system.process_tick(0.1)

	assert_almost_eq(_read_float(writer, PARAM_DISC_RADIUS), 0.2, 0.0001)
	assert_almost_eq(_read_float(writer, PARAM_DISC_FALLOFF), 0.07, 0.0001)
	assert_almost_eq(_read_float(writer, PARAM_DISC_MIN_ALPHA), 0.1, 0.0001)


func test_dynamic_radius_expands_to_cover_projected_player_height() -> void:
	var system_script := _system_script()
	if system_script == null:
		return
	var system: Variant = system_script.new()
	autofree(system)

	var radius: float = system._resolve_disc_radius_for_estimated_height_px(
		0.12,
		600.0,
		282.0,
		1.35,
		0.5
	)

	assert_gt(radius, 0.30,
		"Projected-player sizing should expand the disc beyond the fixed base radius when the player is large on screen.")
	assert_lte(radius, 0.5,
		"Projected-player sizing must respect the authored max radius clamp.")


func test_disables_cutout_via_sentinel_when_not_orbit_mode() -> void:
	var fixture := _create_fixture(Vector3(0, 1, 0), "fixed")
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
	system.state_store = state_store
	system.debug_wall_cutout_logging = false
	var writer := StubShaderWriter.new()
	system.shader_writer = writer
	# Intentionally leave wall_cutout_config null.
	add_child(system)
	system.configure(ecs_manager)

	system.process_tick(0.1)

	assert_gt(_read_float(writer, PARAM_DISC_RADIUS), 0.0,
		"With null config, system must fall back to default cfg_wall_cutout_config_default.tres so disc_radius is positive.")


func test_wall_cutout_shader_uses_dither_discard_instead_of_alpha_blend() -> void:
	var shader_text := FileAccess.get_file_as_string(SHADER_PATH)
	assert_false(shader_text.is_empty(), "Wall cutout shader should be readable.")
	assert_false(shader_text.contains("blend_mix"),
		"Wall cutout must not use alpha blend; large transparent walls reveal empty space as black artifacts.")
	assert_true(shader_text.contains("discard"),
		"Wall cutout should use the same ordered dither discard pattern as wall visibility.")
	assert_true(shader_text.contains("bayer64"),
		"Wall cutout should use deterministic Bayer dithering for stable wall residue.")
