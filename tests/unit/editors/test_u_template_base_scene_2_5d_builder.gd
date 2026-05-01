extends GutTest

const BUILDER_PATH := "res://scripts/core/utils/editors/u_template_base_scene_2_5d_builder.gd"

func _new_builder() -> Object:
	assert_true(FileAccess.file_exists(BUILDER_PATH), "Builder script must exist: %s" % BUILDER_PATH)
	if not FileAccess.file_exists(BUILDER_PATH):
		return null
	var script: Variant = load(BUILDER_PATH)
	assert_not_null(script, "Builder script must load")
	if script == null or not (script is Script):
		return null
	var v: Variant = (script as Script).new()
	if v == null or not (v is Object):
		return null
	return v as Object

func after_each() -> void:
	var cleanup_paths := [
		"res://tests/unit/editors/_test_tmpl_base_scene_2_5d.tscn",
	]
	for path in cleanup_paths:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

func test_builder_script_exists_and_loads() -> void:
	var builder: Object = _new_builder()
	assert_not_null(builder, "U_TemplateBaseScene2_5dBuilder must instantiate")

func test_create_root_produces_gameplay_root() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root")
	var root: Variant = builder.call("build")
	assert_not_null(root, "build() must return root")
	assert_true(root is Node3D, "Root must be Node3D")
	assert_eq((root as Node).name, "GameplayRoot", "Root must be named GameplayRoot")
	assert_not_null((root as Node).script, "Root must have script attached")

func test_scene_objects_contains_floor_ceiling_and_walls() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root")
	builder.call("build_scene_objects")
	var root: Node = builder.call("build") as Node
	var so: Node = root.get_node_or_null("SceneObjects")
	assert_not_null(so, "SceneObjects group must exist")
	assert_not_null(so.get_node_or_null("SO_Floor"), "Floor must exist")
	assert_not_null(so.get_node_or_null("SO_Ceiling"), "Ceiling must exist")
	assert_not_null(so.get_node_or_null("SO_Wall_West"), "West wall must exist")
	assert_not_null(so.get_node_or_null("SO_Wall_East"), "East wall must exist")
	assert_not_null(so.get_node_or_null("SO_Wall_North"), "North wall must exist")
	assert_not_null(so.get_node_or_null("SO_Wall_South"), "South wall must exist")

func test_floor_is_five_by_five_units() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root")
	builder.call("build_scene_objects")
	var root: Node = builder.call("build") as Node
	var floor_node: Node = root.get_node_or_null("SceneObjects/SO_Floor")
	assert_not_null(floor_node, "Floor must exist")
	assert_true(floor_node is CSGBox3D, "Floor must be CSGBox3D")
	if floor_node is CSGBox3D:
		assert_eq((floor_node as CSGBox3D).size.x, 5.0, "Floor x must be 5 units")
		assert_eq((floor_node as CSGBox3D).size.z, 5.0, "Floor z must be 5 units")

func test_walls_are_three_units_tall() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root")
	builder.call("build_scene_objects")
	var root: Node = builder.call("build") as Node
	for wall_name in ["SO_Wall_West", "SO_Wall_East", "SO_Wall_North", "SO_Wall_South"]:
		var wall: Node = root.get_node_or_null("SceneObjects/%s" % wall_name)
		assert_not_null(wall, "%s must exist" % wall_name)
		assert_true(wall is CSGBox3D, "%s must be CSGBox3D" % wall_name)
		if wall is CSGBox3D:
			assert_eq((wall as CSGBox3D).size.y, 3.0, "%s height must be 3 units" % wall_name)

func test_walls_have_ecs_entity_and_room_fade_component() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root")
	builder.call("build_scene_objects")
	var root: Node = builder.call("build") as Node
	var so: Node = root.get_node_or_null("SceneObjects")
	var wall_west: Node = so.get_node_or_null("SO_Wall_West")
	assert_not_null(wall_west, "West wall must exist")
	assert_not_null(wall_west.get_script(), "Wall must have script")
	assert_eq(wall_west.get("entity_id"), &"wall_west", "entity_id must be set")
	var tags: Array = wall_west.get("tags")
	assert_true(tags.has(&"room_fade_group"), "Wall must have room_fade_group tag")
	var component: Node = wall_west.get_node_or_null("C_RoomFadeGroupComponent")
	assert_not_null(component, "RoomFadeGroupComponent must exist on wall")
	assert_eq(component.get("group_tag"), &"wall_west", "group_tag must match entity_id")

func test_environment_has_world_environment_and_light() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root")
	builder.call("build_environment")
	var root: Node = builder.call("build") as Node
	var env: Node = root.get_node_or_null("Environment")
	assert_not_null(env, "Environment group must exist")
	var we: Node = env.get_node_or_null("Env_WorldEnvironment")
	assert_not_null(we, "WorldEnvironment must exist")
	assert_true(we is WorldEnvironment, "Must be WorldEnvironment type")
	assert_not_null((we as WorldEnvironment).environment, "Environment resource must be set")
	var light: Node = env.get_node_or_null("Env_DirectionalLight3D")
	assert_not_null(light, "DirectionalLight3D must exist")
	assert_true(light is DirectionalLight3D, "Must be DirectionalLight3D type")

func test_systems_have_all_four_groups() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root")
	builder.call("build_systems")
	var root: Node = builder.call("build") as Node
	var systems: Node = root.get_node_or_null("Systems")
	assert_not_null(systems, "Systems group must exist")
	assert_not_null(systems.get_node_or_null("Core"), "Core systems must exist")
	assert_not_null(systems.get_node_or_null("Physics"), "Physics systems must exist")
	assert_not_null(systems.get_node_or_null("Movement"), "Movement systems must exist")
	assert_not_null(systems.get_node_or_null("Feedback"), "Feedback systems must exist")

func test_core_systems_contain_input_vcam_wallcutout() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root")
	builder.call("build_systems")
	var root: Node = builder.call("build") as Node
	var core: Node = root.get_node_or_null("Systems/Core")
	assert_not_null(core, "Core systems must exist")
	assert_not_null(core.get_node_or_null("S_InputSystem"), "InputSystem must exist")
	assert_not_null(core.get_node_or_null("S_VCamSystem"), "VCamSystem must exist")
	assert_not_null(core.get_node_or_null("S_WallCutoutSystem"), "WallCutoutSystem must exist")

func test_movement_systems_contain_all_five() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root")
	builder.call("build_systems")
	var root: Node = builder.call("build") as Node
	var movement: Node = root.get_node_or_null("Systems/Movement")
	assert_not_null(movement, "Movement systems must exist")
	assert_not_null(movement.get_node_or_null("S_MovementSystem"), "MovementSystem must exist")
	assert_not_null(movement.get_node_or_null("S_FloatingSystem"), "FloatingSystem must exist")
	assert_not_null(movement.get_node_or_null("S_SpawnRecoverySystem"), "SpawnRecoverySystem must exist")
	assert_not_null(movement.get_node_or_null("S_RotateToInputSystem"), "RotateToInputSystem must exist")
	assert_not_null(movement.get_node_or_null("S_AlignWithSurfaceSystem"), "AlignWithSurfaceSystem must exist")

func test_managers_contain_ecs_manager() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root")
	builder.call("build_managers")
	var root: Node = builder.call("build") as Node
	var managers: Node = root.get_node_or_null("Managers")
	assert_not_null(managers, "Managers group must exist")
	assert_not_null(managers.get_node_or_null("M_ECSManager"), "ECSManager must exist")

func test_entities_contain_camera_and_spawn_point() -> void:
	const PLAYER_PATH := "res://scenes/core/prefabs/prefab_player_2_5d.tscn"
	if not FileAccess.file_exists(PLAYER_PATH):
		pending("Skipped: prefab_player_2_5d.tscn not yet generated — run build_prefab_player_2_5d in Godot editor")
		return
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root")
	builder.call("build_entities")
	var root: Node = builder.call("build") as Node
	var entities: Node = root.get_node_or_null("Entities")
	assert_not_null(entities, "Entities group must exist")
	assert_not_null(entities.get_node_or_null("E_Player"), "Player entity must exist")
	assert_not_null(entities.get_node_or_null("E_CameraRoot"), "Camera entity must exist")
	var spawn_points: Node = entities.get_node_or_null("SpawnPoints")
	assert_not_null(spawn_points, "SpawnPoints must exist")
	assert_not_null(spawn_points.get_node_or_null("sp_default"), "sp_default must exist")

func test_save_writes_tscn_file() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root")
	builder.call("build_scene_objects")
	builder.call("build_environment")
	builder.call("build_systems")
	builder.call("build_managers")
	var save_path: String = "res://tests/unit/editors/_test_tmpl_base_scene_2_5d.tscn"
	var result: Variant = builder.call("save", save_path)
	assert_true(result, "save() must return true")
	assert_true(FileAccess.file_exists(save_path), "save() must write .tscn file")
	var packed: PackedScene = load(save_path) as PackedScene
	assert_not_null(packed, "Saved file must load as PackedScene")
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
