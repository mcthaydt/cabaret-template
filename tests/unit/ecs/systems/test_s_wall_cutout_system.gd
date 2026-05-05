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
const PARAM_CUTOUT_ENABLED := &"wall_cutout_enabled"


class StubShaderWriter extends RefCounted:
	var values: Dictionary = {}
	var instance_values_by_target_id: Dictionary = {}

	func set_param(param_name: StringName, value: Variant) -> void:
		values[param_name] = value

	func set_instance_param(target: Node3D, param_name: StringName, value: Variant) -> void:
		if target == null:
			return
		if not instance_values_by_target_id.has(target.get_instance_id()):
			instance_values_by_target_id[target.get_instance_id()] = {}
		(instance_values_by_target_id[target.get_instance_id()] as Dictionary)[param_name] = value


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


func _read_instance_float(writer: StubShaderWriter, target: Node3D, name: StringName) -> float:
	if target == null:
		return 0.0
	var values: Dictionary = writer.instance_values_by_target_id.get(target.get_instance_id(), {}) as Dictionary
	var value: Variant = values.get(name, null)
	if value is float or value is int:
		return float(value)
	return 0.0


func _make_wall_target(name_: String, position: Vector3, size: Vector3) -> CSGBox3D:
	var wall := CSGBox3D.new()
	wall.name = name_
	wall.position = position
	wall.size = size
	add_child_autofree(wall)
	return wall


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


func test_invalid_config_defaults_match_one_tile_player_visual() -> void:
	var system_script := _system_script()
	if system_script == null:
		return
	var system: Variant = system_script.new()
	autofree(system)
	system.wall_cutout_config = Resource.new()

	var values: Dictionary = system.call("_resolve_config_values")

	assert_almost_eq(float(values.get("disc_center_height_offset")), 0.5, 0.001,
		"Invalid wall cutout config fallback should aim at the one-tile player center.")
	assert_almost_eq(float(values.get("disc_player_height_meters")), 1.0, 0.001,
		"Invalid wall cutout config fallback should use the one-tile player height.")


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


func test_wall_cutout_shader_has_per_instance_cutout_gate() -> void:
	var shader_text := FileAccess.get_file_as_string(SHADER_PATH)
	assert_true(shader_text.contains("instance uniform float wall_cutout_enabled"),
		"Cutout shader should expose a per-wall gate so adjacent non-occluding walls do not cut out.")


func test_tight_occlusion_segment_enables_intersected_wall_only() -> void:
	var fixture := _create_fixture(Vector3.ZERO, "orbit")
	var system = fixture.get("system")
	var writer: StubShaderWriter = fixture.get("writer")
	assert_not_null(system)

	var intersected_wall := _make_wall_target(
		"IntersectedWall",
		Vector3(0.0, 1.0, 1.0),
		Vector3(4.0, 2.0, 0.1)
	)
	var side_wall := _make_wall_target(
		"SideWall",
		Vector3(-1.0, 1.0, 0.0),
		Vector3(0.1, 2.0, 4.0)
	)

	system._update_cutout_target_gates(
		[intersected_wall, side_wall],
		Vector3(0.0, 1.0, 0.0),
		Vector3(0.0, 1.0, 2.0),
		{"occlusion_segment_margin": 0.05}
	)

	assert_almost_eq(_read_instance_float(writer, intersected_wall, PARAM_CUTOUT_ENABLED), 1.0, 0.0001,
		"Wall whose footprint intersects the camera-player segment should allow cutout.")
	assert_almost_eq(_read_instance_float(writer, side_wall, PARAM_CUTOUT_ENABLED), 0.0, 0.0001,
		"Adjacent wall beside the player should not allow cutout when it does not intersect the camera-player segment.")


func test_collects_material_authored_walls_without_room_fade_components() -> void:
	var fixture := _create_fixture(Vector3.ZERO, "orbit")
	var system = fixture.get("system")
	assert_not_null(system)

	var wall := _make_wall_target(
		"SO_Wall_RuntimeFallback",
		Vector3(0.0, 1.0, 1.0),
		Vector3(4.0, 2.0, 0.1)
	)
	wall.material = load("res://assets/core/materials/mat_wall_cutout.tres")

	var targets: Array = system._collect_cutout_targets()

	assert_true(targets.has(wall),
		"WallCutoutSystem should discover template-authored walls that use the shared cutout material even when legacy RoomFadeGroup components are absent.")


func test_collects_mesh_instance_targets_using_wall_cutout_material_override() -> void:
	var fixture := _create_fixture(Vector3.ZERO, "orbit")
	var system = fixture.get("system")
	assert_not_null(system)

	var wall := MeshInstance3D.new()
	wall.name = "SO_MeshWall_RuntimeFallback"
	wall.mesh = BoxMesh.new()
	wall.material_override = load("res://assets/core/materials/mat_wall_cutout.tres")
	add_child_autofree(wall)

	var targets: Array = system._collect_cutout_targets()

	assert_true(targets.has(wall),
		"WallCutoutSystem should discover MeshInstance3D walls that use the shared cutout material override.")


func test_material_authored_collection_ignores_non_cutout_materials() -> void:
	var fixture := _create_fixture(Vector3.ZERO, "orbit")
	var system = fixture.get("system")
	assert_not_null(system)

	var prop := _make_wall_target(
		"SO_NonCutoutProp",
		Vector3(0.0, 1.0, 1.0),
		Vector3(4.0, 2.0, 0.1)
	)
	prop.material = StandardMaterial3D.new()

	var targets: Array = system._collect_cutout_targets()

	assert_false(targets.has(prop),
		"WallCutoutSystem should not gate unrelated scene geometry that does not use the wall cutout material.")


func test_material_authored_collection_deduplicates_existing_targets() -> void:
	var fixture := _create_fixture(Vector3.ZERO, "orbit")
	var system = fixture.get("system")
	assert_not_null(system)

	var wall := _make_wall_target(
		"SO_Wall_DedupedFallback",
		Vector3(0.0, 1.0, 1.0),
		Vector3(4.0, 2.0, 0.1)
	)
	wall.material = load("res://assets/core/materials/mat_wall_cutout.tres")
	var targets: Array = [wall]
	var seen_target_ids := {wall.get_instance_id(): true}

	system._collect_material_authored_cutout_targets(targets, seen_target_ids)

	assert_eq(targets.count(wall), 1,
		"Material fallback collection should not duplicate targets already discovered through component-authored paths.")
