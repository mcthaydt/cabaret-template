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
		(root as Node).queue_free()

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
		(root as Node).queue_free()

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
		(root as Node).queue_free()

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
		(root as Node).queue_free()

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
		(root as Node).queue_free()

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
		(root as Node).queue_free()

func test_build_without_root_returns_null() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	var root: Variant = builder.call("build")
	assert_push_error("build() called before")
	assert_null(root, "build without create_root/inherit_from must return null")
