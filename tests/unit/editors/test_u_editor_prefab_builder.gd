extends GutTest

const BUILDER_PATH := "res://scripts/core/utils/editors/u_editor_prefab_builder.gd"
const TMPL_CHARACTER_PATH := "res://scenes/core/templates/tmpl_character.tscn"

func _new_builder() -> Object:
	assert_true(FileAccess.file_exists(BUILDER_PATH), "U_EditorPrefabBuilder script must exist: %s" % BUILDER_PATH)
	if not FileAccess.file_exists(BUILDER_PATH):
		return null
	var script: Variant = load(BUILDER_PATH)
	assert_not_null(script, "U_EditorPrefabBuilder script must load")
	if script == null or not (script is Script):
		return null
	var v: Variant = (script as Script).new()
	if v == null or not (v is Object):
		return null
	return v as Object

func test_u_editor_prefab_builder_script_exists_and_loads() -> void:
	var builder: Object = _new_builder()
	assert_not_null(builder, "U_EditorPrefabBuilder must instantiate")

func test_create_root_produces_node_of_correct_type_and_name() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root", "Node3D", "TestRoot")
	var root: Variant = builder.call("build")
	assert_not_null(root, "create_root must produce a root that build() returns")
	assert_true(root is Node3D, "create_root must produce Node3D when given 'Node3D'")
	assert_eq((root as Node).name, "TestRoot", "create_root must set node name")
	if root is Node:
		(root as Node).free()

func test_create_root_produces_static_body_3d() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root", "StaticBody3D", "TestStatic")
	var root: Variant = builder.call("build")
	assert_not_null(root, "create_root must produce a root that build() returns")
	assert_true(root is StaticBody3D, "create_root must produce StaticBody3D when given 'StaticBody3D'")
	assert_eq((root as Node).name, "TestStatic", "create_root must set node name")
	if root is Node:
		(root as Node).free()

func test_inherit_from_produces_instanced_scene_with_children() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("inherit_from", TMPL_CHARACTER_PATH)
	var root: Variant = builder.call("build")
	assert_not_null(root, "inherit_from must produce a root that build() returns")
	assert_true(root is Node, "inherit_from must produce a Node")
	var components: Node = (root as Node).get_node_or_null("Components")
	assert_not_null(components, "inherited tmpl_character must have Components child")
	if root is Node:
		(root as Node).free()

func test_set_entity_id_sets_metadata() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root", "Node3D", "TestEntity")
	builder.call("set_entity_id", &"wolf")
	var root: Variant = builder.call("build")
	assert_not_null(root, "build must return root")
	assert_eq((root as Node).get_meta("entity_id"), &"wolf", "set_entity_id must set 'entity_id' metadata")
	if root is Node:
		(root as Node).free()

func test_set_tags_sets_metadata() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root", "Node3D", "TestEntity")
	var tags_input: Array = [&"predator", &"hostile"]
	builder.call("set_tags", tags_input)
	var root: Variant = builder.call("build")
	assert_not_null(root, "build must return root")
	var tags: Variant = (root as Node).get_meta("tags")
	assert_true(tags is Array, "set_tags must store Array in 'tags' metadata")
	assert_eq(tags, tags_input, "set_tags must match input")
	if root is Node:
		(root as Node).free()

func test_fluent_methods_return_self() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	var r1: Variant = builder.call("create_root", "Node3D", "Test")
	assert_eq(r1, builder, "create_root must return self")
	var r2: Variant = builder.call("set_entity_id", &"test")
	assert_eq(r2, builder, "set_entity_id must return self")
	var tags_input: Array = [&"a"]
	var r3: Variant = builder.call("set_tags", tags_input)
	assert_eq(r3, builder, "set_tags must return self")
	var root: Variant = builder.call("build")
	if root is Node:
		(root as Node).free()

func test_build_returns_root_node() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root", "Node3D", "BuiltRoot")
	var root: Variant = builder.call("build")
	assert_not_null(root, "build must return non-null when root is set")
	assert_true(root is Node, "build must return a Node")
	assert_eq((root as Node).name, "BuiltRoot", "build must return the configured root")
	if root is Node:
		(root as Node).free()

func test_build_without_root_returns_null() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	var root: Variant = builder.call("build")
	assert_push_error("build() called before")
	assert_null(root, "build without create_root/inherit_from must return null")

func test_add_ecs_component_adds_node_with_script_attached() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root", "Node3D", "TestEntity")
	var script: Script = load("res://scripts/core/ecs/components/c_spawn_state_component.gd") as Script
	assert_not_null(script, "test script must load")
	builder.call("add_ecs_component", script, null, {})
	var root: Variant = builder.call("build")
	assert_not_null(root, "build must return root")
	var components: Node = (root as Node).get_node_or_null("Components")
	assert_not_null(components, "Components container must exist")
	var component: Node = components.get_node_or_null("C_SpawnStateComponent")
	assert_not_null(component, "Component node must exist under Components")
	assert_eq(component.get_script(), script, "Component must have script attached")
	if root is Node:
		(root as Node).free()

func test_add_ecs_component_assigns_settings_export() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root", "Node3D", "TestEntity")
	var script: Script = load("res://scripts/core/ecs/components/c_health_component.gd") as Script
	assert_not_null(script, "test script must load")
	var settings: Resource = load("res://resources/core/base_settings/gameplay/cfg_health_settings.tres") as Resource
	builder.call("add_ecs_component", script, settings, {})
	var root: Variant = builder.call("build")
	assert_not_null(root, "build must return root")
	var component: Node = (root as Node).get_node_or_null("Components/C_HealthComponent")
	assert_not_null(component, "Component must exist with settings")
	assert_eq(component.get("settings"), settings, "Component settings export must be assigned")
	if root is Node:
		(root as Node).free()

func test_add_ecs_component_sets_inline_properties() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root", "Node3D", "TestEntity")
	var script: Script = load("res://scripts/core/ecs/components/c_spawn_state_component.gd") as Script
	assert_not_null(script, "test script must load")
	var properties: Dictionary = {
		"is_physics_frozen": true,
		"unfreeze_at_frame": 42,
	}
	builder.call("add_ecs_component", script, null, properties)
	var root: Variant = builder.call("build")
	assert_not_null(root, "build must return root")
	var component: Node = (root as Node).get_node_or_null("Components/C_SpawnStateComponent")
	assert_not_null(component, "Component must exist")
	assert_eq(component.get("is_physics_frozen"), true, "Inline bool property must be set")
	assert_eq(component.get("unfreeze_at_frame"), 42, "Inline int property must be set")
	if root is Node:
		(root as Node).free()

func test_add_ecs_component_by_path_loads_and_wires_both() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root", "Node3D", "TestEntity")
	builder.call("add_ecs_component_by_path",
		"res://scripts/core/ecs/components/c_spawn_state_component.gd",
		"",
		{"is_physics_frozen": true})
	var root: Variant = builder.call("build")
	assert_not_null(root, "build must return root")
	var component: Node = (root as Node).get_node_or_null("Components/C_SpawnStateComponent")
	assert_not_null(component, "Component must exist after add_ecs_component_by_path")
	assert_eq(component.get("is_physics_frozen"), true, "Inline property must be set via path method")
	if root is Node:
		(root as Node).free()

func test_multiple_components_added_sequentially_are_all_present() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root", "Node3D", "TestEntity")
	var script_a: Script = load("res://scripts/core/ecs/components/c_spawn_state_component.gd") as Script
	var script_b: Script = load("res://scripts/core/ecs/components/c_character_state_component.gd") as Script
	assert_not_null(script_a, "script_a must load")
	assert_not_null(script_b, "script_b must load")
	builder.call("add_ecs_component", script_a, null, {})
	builder.call("add_ecs_component", script_b, null, {})
	var root: Variant = builder.call("build")
	assert_not_null(root, "build must return root")
	var components: Node = (root as Node).get_node_or_null("Components")
	assert_not_null(components, "Components container must exist")
	assert_eq(components.get_child_count(), 2, "Components must have 2 children")
	var names: Array[String] = []
	for child in components.get_children():
		names.append(child.name)
	assert_true("C_SpawnStateComponent" in names, "First component must exist")
	assert_true("C_CharacterStateComponent" in names, "Second component must exist")
	if root is Node:
		(root as Node).free()

# ── P7.4: Save & EditorScript Adapter ─────────────────────────────────────

func test_save_packs_and_writes_file() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root", "Node3D", "TestSave")
	var save_path: String = "res://tests/unit/editors/_test_saved_prefab.tscn"
	var result: Variant = builder.call("save", save_path)
	assert_true(result, "save() must return true on success")
	assert_true(FileAccess.file_exists(save_path), "save() must write .tscn file")
	var packed: PackedScene = load(save_path) as PackedScene
	assert_not_null(packed, "Saved file must load as PackedScene")
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	var root: Variant = builder.call("build")
	if root is Node:
		(root as Node).free()

func test_save_without_root_returns_false() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	var result: Variant = builder.call("save", "res://tests/unit/editors/_test_fail.tscn")
	assert_false(result, "save() without root must return false")
	assert_push_error("save() called before")

# ── P7.3: Visuals, Collision & Children ─────────────────────────────────────

func test_add_visual_mesh_adds_mesh_instance() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root", "Node3D", "TestRoot")
	builder.call("add_visual_mesh", "TestMesh", null, Vector3(0.5, 1.0, 0.5))
	var root: Variant = builder.call("build")
	assert_not_null(root, "build must return root")
	var mesh: Node = (root as Node).get_node_or_null("TestMesh")
	assert_not_null(mesh, "add_visual_mesh must add MeshInstance3D")
	assert_true(mesh is MeshInstance3D, "Added visual must be MeshInstance3D")
	if root is Node:
		(root as Node).free()

func test_add_collision_capsule_adds_shape() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root", "StaticBody3D", "TestBody")
	builder.call("add_collision_capsule", 1.5, 3.0)
	var root: Variant = builder.call("build")
	assert_not_null(root, "build must return root")
	var shape: Node = (root as Node).get_node_or_null("CollisionShape3D")
	assert_not_null(shape, "add_collision_capsule must add CollisionShape3D")
	assert_true(shape is CollisionShape3D, "Added collision must be CollisionShape3D")
	if root is Node:
		(root as Node).free()

func test_add_marker_adds_marker_3d() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root", "Node3D", "TestRoot")
	builder.call("add_marker", "SpawnPoint")
	var root: Variant = builder.call("build")
	assert_not_null(root, "build must return root")
	var marker: Node = (root as Node).get_node_or_null("SpawnPoint")
	assert_not_null(marker, "add_marker must add Marker3D")
	assert_true(marker is Marker3D, "Added marker must be Marker3D")
	if root is Node:
		(root as Node).free()

func test_override_property_sets_value() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root", "Node3D", "TestRoot")
	builder.call("override_property", ".", "process_mode", PROCESS_MODE_DISABLED)
	var root: Variant = builder.call("build")
	assert_not_null(root, "build must return root")
	assert_eq((root as Node).process_mode, PROCESS_MODE_DISABLED, "override_property must set root process_mode")
	if root is Node:
		(root as Node).free()

func test_add_child_scene_instantiates_scene() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root", "Node3D", "TestRoot")
	builder.call("add_child_scene", TMPL_CHARACTER_PATH, "Body")
	var root: Variant = builder.call("build")
	assert_not_null(root, "build must return root")
	var child: Node = (root as Node).get_node_or_null("Body")
	assert_not_null(child, "add_child_scene must instantiate child scene")
	assert_true(child is Node, "Instantiated child must be a Node")
	if root is Node:
		(root as Node).free()

func test_add_csg_box_adds_csg_box3d_with_material() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root", "Node3D", "TestRoot")
	builder.call("add_csg_box", "Box", Vector3(1.5, 1, 1.5), Color.GRAY)
	var root: Variant = builder.call("build")
	assert_not_null(root, "build must return root")
	var box: Node = (root as Node).get_node_or_null("Box")
	assert_not_null(box, "add_csg_box must add child named Box")
	assert_true(box is CSGBox3D, "Added child must be CSGBox3D")
	assert_eq((box as CSGBox3D).size, Vector3(1.5, 1, 1.5), "add_csg_box must set size")
	assert_not_null((box as CSGBox3D).material, "add_csg_box must assign material")
	assert_eq(((box as CSGBox3D).material as StandardMaterial3D).albedo_color, Color.GRAY, "Material color must match")
	if root is Node:
		(root as Node).free()

func test_add_csg_sphere_adds_csg_sphere3d_with_material() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root", "Node3D", "TestRoot")
	builder.call("add_csg_sphere", "Orb", 0.6, Color.GRAY)
	var root: Variant = builder.call("build")
	assert_not_null(root, "build must return root")
	var sphere: Node = (root as Node).get_node_or_null("Orb")
	assert_not_null(sphere, "add_csg_sphere must add child named Orb")
	assert_true(sphere is CSGSphere3D, "Added child must be CSGSphere3D")
	assert_not_null((sphere as CSGSphere3D).material, "add_csg_sphere must assign material")
	if root is Node:
		(root as Node).free()

func test_add_csg_cylinder_adds_csg_cylinder3d_with_material() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root", "Node3D", "TestRoot")
	builder.call("add_csg_cylinder", "Trunk", 0.3, 3.0, Color.BROWN)
	var root: Variant = builder.call("build")
	assert_not_null(root, "build must return root")
	var cyl: Node = (root as Node).get_node_or_null("Trunk")
	assert_not_null(cyl, "add_csg_cylinder must add child named Trunk")
	assert_true(cyl is CSGCylinder3D, "Added child must be CSGCylinder3D")
	assert_not_null((cyl as CSGCylinder3D).material, "add_csg_cylinder must assign material")
	if root is Node:
		(root as Node).free()

func test_add_collision_box_adds_box_shape() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root", "StaticBody3D", "TestBody")
	builder.call("add_collision_box", "CollisionShape3D", Vector3(1.5, 1, 1.5))
	var root: Variant = builder.call("build")
	assert_not_null(root, "build must return root")
	var shape: Node = (root as Node).get_node_or_null("CollisionShape3D")
	assert_not_null(shape, "add_collision_box must add CollisionShape3D")
	assert_true(shape is CollisionShape3D, "Added collision must be CollisionShape3D")
	var box_shape: BoxShape3D = (shape as CollisionShape3D).shape as BoxShape3D
	assert_not_null(box_shape, "Shape must be BoxShape3D")
	assert_eq(box_shape.size, Vector3(1.5, 1, 1.5), "add_collision_box must set size")
	if root is Node:
		(root as Node).free()

func test_add_child_to_adds_node_under_parent() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root", "Node3D", "TestRoot")
	builder.call("add_visual_mesh", "ParentMesh", null, Vector3.ONE)
	var child: MeshInstance3D = MeshInstance3D.new()
	child.name = "ChildMesh"
	builder.call("add_child_to", "ParentMesh", child)
	var root: Variant = builder.call("build")
	assert_not_null(root, "build must return root")
	var parent_node: Node = (root as Node).get_node_or_null("ParentMesh")
	assert_not_null(parent_node, "ParentMesh must exist")
	var found_child: Node = parent_node.get_node_or_null("ChildMesh")
	assert_not_null(found_child, "add_child_to must add child under specified parent")
	assert_eq(found_child.name, "ChildMesh", "Child name must match")
	if root is Node:
		(root as Node).free()

func test_add_child_scene_to_instantiates_under_parent() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root", "Node3D", "TestRoot")
	builder.call("add_marker", "ParentMarker")
	builder.call("add_child_scene_to", "ParentMarker", TMPL_CHARACTER_PATH, "CharChild")
	var root: Variant = builder.call("build")
	assert_not_null(root, "build must return root")
	var parent_node: Node = (root as Node).get_node_or_null("ParentMarker")
	assert_not_null(parent_node, "ParentMarker must exist")
	var child: Node = parent_node.get_node_or_null("CharChild")
	assert_not_null(child, "add_child_scene_to must instantiate child under parent")
	if root is Node:
		(root as Node).free()
