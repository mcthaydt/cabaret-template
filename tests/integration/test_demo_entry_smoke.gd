extends BaseTest

const ROOM_PATH := "res://scenes/demo/gameplay/gameplay_demo_room.tscn"
const U_SCENE_MANIFEST := preload("res://scripts/core/scene_management/u_scene_manifest.gd")

func _count_gameplay_scenes() -> int:
	var manifest_script := U_SCENE_MANIFEST.new()
	var scenes: Dictionary = manifest_script.build()
	var count: int = 0
	for scene_id in scenes:
		var data: Dictionary = scenes[scene_id]
		if data.get("scene_type", -1) == U_SceneRegistry.SceneType.GAMEPLAY:
			count += 1
	return count

func _load_scene(path: String) -> Node:
	if path.is_empty():
		return null
	var packed_variant: Variant = load(path)
	if not (packed_variant is PackedScene):
		return null
	var packed: PackedScene = packed_variant as PackedScene
	var root_variant: Variant = packed.instantiate()
	if not (root_variant is Node):
		return null
	var root: Node = root_variant as Node
	add_child_autofree(root)
	return root

func test_smoke_exactly_one_gameplay_scene() -> void:
	assert_eq(_count_gameplay_scenes(), 1, "Scene manifest must have exactly one GAMEPLAY scene after Phase 5 cleanup")

func test_smoke_blockout_room_is_gameplay_entry() -> void:
	var root := _load_scene(ROOM_PATH)
	assert_not_null(root, "Blockout room scene must load without errors: %s" % ROOM_PATH)

func test_smoke_room_has_spawn_default() -> void:
	var root := _load_scene(ROOM_PATH)
	if root == null:
		return
	var spawn := root.find_child("sp_default", true, false)
	assert_not_null(spawn, "Blockout room must contain sp_default spawn point")

func test_smoke_room_has_camera() -> void:
	var root := _load_scene(ROOM_PATH)
	if root == null:
		return
	var cam := root.find_child("E_CameraRoot", true, false)
	assert_not_null(cam, "Blockout room must contain E_CameraRoot")
