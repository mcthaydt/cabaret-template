extends GutTest

const BUILDER_PATH := "res://scripts/core/utils/editors/u_editor_blockout_builder.gd"

func _new_builder() -> Object:
	assert_true(FileAccess.file_exists(BUILDER_PATH), "U_EditorBlockoutBuilder script must exist: %s" % BUILDER_PATH)
	if not FileAccess.file_exists(BUILDER_PATH):
		return null
	var script: Variant = load(BUILDER_PATH)
	assert_not_null(script, "U_EditorBlockoutBuilder script must load")
	if script == null or not (script is Script):
		return null
	var v: Variant = (script as Script).new()
	if v == null or not (v is Object):
		return null
	return v as Object

func test_u_editor_blockout_builder_script_exists_and_loads() -> void:
	var builder: Object = _new_builder()
	assert_not_null(builder, "U_EditorBlockoutBuilder must instantiate")

func test_create_root_produces_node3d() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root", "TestBlockout")
	var root: Variant = builder.call("build")
	assert_not_null(root, "create_root must produce a root that build() returns")
	assert_true(root is Node3D, "create_root must produce Node3D")
	assert_eq((root as Node).name, "TestBlockout", "create_root must set node name")
	if root is Node:
		(root as Node).free()

func test_add_csg_box_adds_csg_box3d() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root", "TestBlockout")
	builder.call("add_csg_box", "Floor", Vector3(10, 1, 10))
	var root: Variant = builder.call("build")
	assert_not_null(root, "build must return root")
	var box: Node = (root as Node).get_node_or_null("Floor")
	assert_not_null(box, "add_csg_box must add child named Floor")
	assert_true(box is CSGBox3D, "Added child must be CSGBox3D")
	assert_eq((box as CSGBox3D).size, Vector3(10, 1, 10), "add_csg_box must set size")
	if root is Node:
		(root as Node).free()

func test_add_csg_sphere_adds_csg_sphere3d() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root", "TestBlockout")
	builder.call("add_csg_sphere", "Orb", 2.0)
	var root: Variant = builder.call("build")
	assert_not_null(root, "build must return root")
	var sphere: Node = (root as Node).get_node_or_null("Orb")
	assert_not_null(sphere, "add_csg_sphere must add child named Orb")
	assert_true(sphere is CSGSphere3D, "Added child must be CSGSphere3D")
	assert_eq((sphere as CSGSphere3D).radius, 2.0, "add_csg_sphere must set radius")
	if root is Node:
		(root as Node).free()

func test_add_spawn_point_adds_marker3d() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root", "TestBlockout")
	builder.call("add_spawn_point", "Spawn_A", Vector3(0, 1, 0))
	var root: Variant = builder.call("build")
	assert_not_null(root, "build must return root")
	var marker: Node = (root as Node).get_node_or_null("Spawn_A")
	assert_not_null(marker, "add_spawn_point must add child named Spawn_A")
	assert_true(marker is Marker3D, "Added child must be Marker3D")
	assert_eq((marker as Marker3D).position, Vector3(0, 1, 0), "add_spawn_point must set position")
	if root is Node:
		(root as Node).free()

func test_execute_custom_runs_callable() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root", "TestBlockout")
	var helper_script: Script = load("res://tests/unit/editors/helpers/callback_helper.gd")
	assert_not_null(helper_script, "Helper script must load")
	var helper: Node = helper_script.new()
	var callback: Callable = Callable(helper, "run")
	builder.call("execute_custom", callback)
	assert_eq(helper.marker, "TestBlockout", "execute_custom must invoke callable and pass root")
	helper.free()
	var root: Variant = builder.call("build")
	if root is Node:
		(root as Node).free()

func test_set_material_changes_color() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root", "TestBlockout")
	builder.call("add_csg_box", "Floor", Vector3(5, 1, 5))
	builder.call("set_material", "Floor", Color.RED)
	var root: Variant = builder.call("build")
	assert_not_null(root, "build must return root")
	var box: Node = (root as Node).get_node_or_null("Floor")
	assert_not_null(box, "Floor must exist")
	assert_true(box is CSGBox3D, "Floor must be CSGBox3D")
	var mat: Material = (box as CSGBox3D).material
	assert_not_null(mat, "set_material must assign a material")
	assert_true(mat is StandardMaterial3D, "Material must be StandardMaterial3D")
	assert_eq((mat as StandardMaterial3D).albedo_color, Color.RED, "Material color must match")
	if root is Node:
		(root as Node).free()

func test_add_directional_light_adds_light3d() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root", "TestBlockout")
	builder.call("add_directional_light", "Sun", Vector3(-1, -1, -1), Color.YELLOW, 2.0)
	var root: Variant = builder.call("build")
	assert_not_null(root, "build must return root")
	var light: Node = (root as Node).get_node_or_null("Sun")
	assert_not_null(light, "add_directional_light must add child named Sun")
	assert_true(light is DirectionalLight3D, "Added light must be DirectionalLight3D")
	assert_eq((light as DirectionalLight3D).position, Vector3(-1, -1, -1), "Light position must match")
	assert_eq((light as DirectionalLight3D).light_color, Color.YELLOW, "Light color must match")
	assert_eq((light as DirectionalLight3D).light_energy, 2.0, "Light energy must match")
	if root is Node:
		(root as Node).free()

func test_add_world_environment_adds_environment() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root", "TestBlockout")
	builder.call("add_world_environment", "WorldEnv")
	var root: Variant = builder.call("build")
	assert_not_null(root, "build must return root")
	var env_node: Node = (root as Node).get_node_or_null("WorldEnv")
	assert_not_null(env_node, "add_world_environment must add child named WorldEnv")
	assert_true(env_node is WorldEnvironment, "Added node must be WorldEnvironment")
	assert_not_null((env_node as WorldEnvironment).environment, "Environment resource must be set")
	if root is Node:
		(root as Node).free()

func test_add_csg_box_at_adds_box_at_position() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root", "TestBlockout")
	builder.call("add_csg_box_at", "Wall", Vector3(0.2, 5, 5), Vector3(-2.5, 2.5, 0))
	var root: Variant = builder.call("build")
	assert_not_null(root, "build must return root")
	var box: Node = (root as Node).get_node_or_null("Wall")
	assert_not_null(box, "add_csg_box_at must add child named Wall")
	assert_true(box is CSGBox3D, "Added child must be CSGBox3D")
	assert_eq((box as CSGBox3D).size, Vector3(0.2, 5, 5), "add_csg_box_at must set size")
	assert_eq((box as CSGBox3D).position, Vector3(-2.5, 2.5, 0), "add_csg_box_at must set position")
	if root is Node:
		(root as Node).free()

func test_set_position_moves_node() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root", "TestBlockout")
	builder.call("add_csg_box", "Floor", Vector3(1, 1, 1))
	builder.call("set_position", "Floor", Vector3(0, 5, 0))
	var root: Variant = builder.call("build")
	assert_not_null(root, "build must return root")
	var box: Node = (root as Node).get_node_or_null("Floor")
	assert_true(box is CSGBox3D, "Floor must be CSGBox3D")
	assert_eq((box as CSGBox3D).position, Vector3(0, 5, 0), "set_position must move node")
	if root is Node:
		(root as Node).free()

func test_set_material_unshaded_texture_applies_texture() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root", "TestBlockout")
	builder.call("add_csg_box", "Floor", Vector3(5, 1, 5))
	var img: Image = Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.5, 0.5, 0.5, 1.0))
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	builder.call("set_material_unshaded_texture", "Floor", tex)
	var root: Variant = builder.call("build")
	assert_not_null(root, "build must return root")
	var box: Node = (root as Node).get_node_or_null("Floor")
	assert_not_null(box, "Floor must exist")
	assert_true(box is CSGBox3D, "Floor must be CSGBox3D")
	var mat: Material = (box as CSGBox3D).material
	assert_not_null(mat, "set_material_unshaded_texture must assign a material")
	assert_true(mat is StandardMaterial3D, "Material must be StandardMaterial3D")
	assert_eq((mat as StandardMaterial3D).shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED, "Material must be unshaded")
	if root is Node:
		(root as Node).free()

func test_save_writes_tscn() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root", "TestBlockout")
	builder.call("add_csg_box", "Ground", Vector3(20, 1, 20))
	var save_path: String = "res://tests/unit/editors/_test_blockout.tscn"
	var result: Variant = builder.call("save", save_path)
	assert_true(result, "save() must return true")
	assert_true(FileAccess.file_exists(save_path), "save() must write .tscn file")
	var packed: PackedScene = load(save_path) as PackedScene
	assert_not_null(packed, "Saved file must load as PackedScene")
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	var root: Variant = builder.call("build")
	if root is Node:
		(root as Node).free()
