extends BaseTest

const SCENE_PATH := "res://scenes/gameplay/gameplay_interior_a.tscn"
const POWER_CORE_SCENE_PATH := "res://scenes/gameplay/gameplay_power_core.tscn"
const TEMPLATE_SCENE_PATH := "res://scenes/templates/tmpl_base_scene.tscn"
const C_ROOM_FADE_GROUP_COMPONENT_SCRIPT := preload(
	"res://scripts/ecs/components/c_room_fade_group_component.gd"
)
const S_ROOM_FADE_SYSTEM_SCRIPT := preload("res://scripts/ecs/systems/s_room_fade_system.gd")

func test_gameplay_interior_room_fade_targets_have_single_group_ownership() -> void:
	var packed_scene := load(SCENE_PATH) as PackedScene
	assert_not_null(packed_scene, "Scene should load: %s" % SCENE_PATH)
	if packed_scene == null:
		return

	var root_variant: Variant = packed_scene.instantiate()
	assert_true(root_variant is Node, "Scene root should be a Node.")
	if not (root_variant is Node):
		return
	var root := root_variant as Node
	add_child(root)
	autofree(root)

	var expected_component_paths: Array[String] = [
		"SceneObjects/BedroomArea/MasterBathroom/Walls/C_RoomFadeGroupComponent",
		"SceneObjects/BedroomArea/MasterBedroom/Walls/C_RoomFadeGroupComponent",
		"SceneObjects/BedroomArea/WalkInCloset/Walls/C_RoomFadeGroupComponent",
		"SceneObjects/EntertainmentArea/Walls/C_RoomFadeGroupComponent",
		"SceneObjects/GymArea/Walls/C_RoomFadeGroupComponent",
		"SceneObjects/OfficeArea/Walls/C_RoomFadeGroupComponent",
	]
	for path in expected_component_paths:
		assert_not_null(
			root.get_node_or_null(NodePath(path)),
			"Expected room-fade group component missing at: %s" % path
		)

	var components: Array = _collect_room_fade_components(root)
	assert_eq(
		components.size(),
		6,
		"Expected 6 room-fade components in gameplay_interior_a.tscn."
	)

	var owner_by_target_id: Dictionary = {}  # int -> Node
	var duplicate_messages: Array[String] = []
	var seen_group_tags: Dictionary = {}  # StringName -> NodePath
	for component_variant in components:
		var component := component_variant as Node
		assert_not_null(component)
		if component == null:
			continue
		assert_true(component.has_method("collect_mesh_targets"))
		if not component.has_method("collect_mesh_targets"):
			continue

		var targets_variant: Variant = component.call("collect_mesh_targets")
		assert_true(
			targets_variant is Array,
			"collect_mesh_targets should return an Array for %s" % _describe_node(component)
		)
		if not (targets_variant is Array):
			continue

		var targets: Array = targets_variant as Array
		assert_false(targets.is_empty(), "Room-fade group should have targets: %s" % _describe_node(component))
		var group_tag_variant: Variant = component.get("group_tag")
		assert_true(
			group_tag_variant is StringName,
			"group_tag should be a StringName for %s" % _describe_node(component)
		)
		if group_tag_variant is StringName:
			var group_tag: StringName = group_tag_variant as StringName
			assert_true(
				not String(group_tag).is_empty(),
				"Room-fade group_tag should be explicitly authored for %s" % _describe_node(component)
			)
			if seen_group_tags.has(group_tag):
				fail_test(
					"Duplicate room-fade group_tag detected: %s at %s and %s"
					% [String(group_tag), str(seen_group_tags[group_tag]), _describe_node(component)]
				)
			else:
				seen_group_tags[group_tag] = component.get_path()

		for target_variant in targets:
			if not (target_variant is Node3D):
				continue
			var target := target_variant as Node3D
			if target == null or not is_instance_valid(target):
				continue

			var target_id: int = target.get_instance_id()
			var owner_variant: Variant = owner_by_target_id.get(target_id, null)
			if owner_variant == null:
				owner_by_target_id[target_id] = component
				continue

			var owner := owner_variant as Node
			duplicate_messages.append(
				"target=%s owner_a=%s owner_b=%s" % [
					_describe_node(target),
					_describe_node(owner),
					_describe_node(component),
				]
			)

	assert_true(
		duplicate_messages.is_empty(),
		"Duplicate room-fade target ownership detected:\n%s" % _join_lines(duplicate_messages)
	)

func test_gameplay_power_core_has_room_fade_system_and_wall_groups() -> void:
	var packed_scene := load(POWER_CORE_SCENE_PATH) as PackedScene
	assert_not_null(packed_scene, "Scene should load: %s" % POWER_CORE_SCENE_PATH)
	if packed_scene == null:
		return

	var root_variant: Variant = packed_scene.instantiate()
	assert_true(root_variant is Node, "Scene root should be a Node.")
	if not (root_variant is Node):
		return
	var root := root_variant as Node
	add_child(root)
	autofree(root)

	var room_fade_system := root.get_node_or_null(NodePath("Systems/Core/S_RoomFadeSystem"))
	assert_not_null(room_fade_system, "Expected Systems/Core/S_RoomFadeSystem in %s" % POWER_CORE_SCENE_PATH)
	if room_fade_system != null:
		assert_eq(room_fade_system.get_script(), S_ROOM_FADE_SYSTEM_SCRIPT)

	var expected_component_paths: Array[String] = [
		"SceneObjects/SO_WallNorth/C_RoomFadeGroupComponent",
		"SceneObjects/SO_WallSouth/C_RoomFadeGroupComponent",
		"SceneObjects/SO_WallEast/C_RoomFadeGroupComponent",
		"SceneObjects/SO_WallWest/C_RoomFadeGroupComponent",
	]
	var seen_group_tags: Dictionary = {}
	for path in expected_component_paths:
		var component := root.get_node_or_null(NodePath(path))
		assert_not_null(component, "Expected room-fade group component missing at: %s" % path)
		if component == null:
			continue
		var group_tag_variant: Variant = component.get("group_tag")
		assert_true(
			group_tag_variant is StringName,
			"group_tag should be a StringName for %s" % _describe_node(component)
		)
		if group_tag_variant is StringName:
			var group_tag: StringName = group_tag_variant as StringName
			assert_true(
				not String(group_tag).is_empty(),
				"Room-fade group_tag should be explicitly authored for %s" % _describe_node(component)
			)
			assert_false(
				seen_group_tags.has(group_tag),
				"Duplicate room-fade group_tag detected in %s: %s" % [POWER_CORE_SCENE_PATH, String(group_tag)]
			)
			seen_group_tags[group_tag] = true

	var components: Array = _collect_room_fade_components(root)
	assert_eq(
		components.size(),
		4,
		"Expected 4 room-fade components in gameplay_power_core.tscn."
	)

func test_tmpl_base_scene_has_room_fade_system_and_default_components() -> void:
	var packed_scene := load(TEMPLATE_SCENE_PATH) as PackedScene
	assert_not_null(packed_scene, "Scene should load: %s" % TEMPLATE_SCENE_PATH)
	if packed_scene == null:
		return

	var root_variant: Variant = packed_scene.instantiate()
	assert_true(root_variant is Node, "Scene root should be a Node.")
	if not (root_variant is Node):
		return
	var root := root_variant as Node
	add_child(root)
	autofree(root)

	var room_fade_system := root.get_node_or_null(NodePath("Systems/Core/S_RoomFadeSystem"))
	assert_not_null(room_fade_system, "Expected Systems/Core/S_RoomFadeSystem in %s" % TEMPLATE_SCENE_PATH)
	if room_fade_system != null:
		assert_eq(room_fade_system.get_script(), S_ROOM_FADE_SYSTEM_SCRIPT)

	var expected_component_paths: Array[String] = [
		"SceneObjects/SO_Block/C_RoomFadeGroupComponent",
		"SceneObjects/SO_Block2/C_RoomFadeGroupComponent",
		"SceneObjects/SO_Block3/C_RoomFadeGroupComponent",
	]
	var seen_group_tags: Dictionary = {}
	for path in expected_component_paths:
		var component := root.get_node_or_null(NodePath(path))
		assert_not_null(component, "Expected template room-fade component missing at: %s" % path)
		if component == null:
			continue
		var group_tag_variant: Variant = component.get("group_tag")
		assert_true(
			group_tag_variant is StringName,
			"group_tag should be a StringName for %s" % _describe_node(component)
		)
		if group_tag_variant is StringName:
			var group_tag: StringName = group_tag_variant as StringName
			assert_true(
				not String(group_tag).is_empty(),
				"Template room-fade group_tag should be explicitly authored for %s" % _describe_node(component)
			)
			assert_false(
				seen_group_tags.has(group_tag),
				"Duplicate template room-fade group_tag detected in %s: %s" % [TEMPLATE_SCENE_PATH, String(group_tag)]
			)
			seen_group_tags[group_tag] = true

	var components: Array = _collect_room_fade_components(root)
	assert_true(
		components.size() >= 3,
		"Expected at least 3 room-fade components in tmpl_base_scene.tscn."
	)

func _collect_room_fade_components(root: Node) -> Array:
	var result: Array = []
	_collect_room_fade_components_recursive(root, result)
	return result

func _collect_room_fade_components_recursive(node: Node, result: Array) -> void:
	if node == null:
		return
	if node.get_script() == C_ROOM_FADE_GROUP_COMPONENT_SCRIPT:
		result.append(node)
	var children: Array = node.get_children()
	for child_variant in children:
		var child := child_variant as Node
		if child == null:
			continue
		_collect_room_fade_components_recursive(child, result)

func _describe_node(node: Node) -> String:
	if node == null or not is_instance_valid(node):
		return "<invalid>"
	return str(node.get_path())

func _join_lines(lines: Array[String]) -> String:
	if lines.is_empty():
		return ""
	var output: String = lines[0]
	for index in range(1, lines.size()):
		output += "\n%s" % lines[index]
	return output
