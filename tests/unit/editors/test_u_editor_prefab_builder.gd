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
		(root as Node).queue_free()

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
		(root as Node).queue_free()

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
		(root as Node).queue_free()

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
		(root as Node).queue_free()

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
		(root as Node).queue_free()
