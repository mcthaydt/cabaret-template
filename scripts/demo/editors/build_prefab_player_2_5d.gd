@tool
extends EditorScript

const OUTPUT_PATH := "res://scenes/core/prefabs/prefab_player_2_5d.tscn"

const _INPUT_COMPONENT := preload("res://scripts/core/ecs/components/c_input_component.gd")
const _GAMEPAD_COMPONENT := preload("res://scripts/core/ecs/components/c_gamepad_component.gd")
const _GAMEPAD_SETTINGS := preload("res://resources/core/input/gamepad_settings/cfg_default_gamepad_settings.tres")
const _PLAYER_TAG_COMPONENT := preload("res://scripts/core/ecs/components/c_player_tag_component.gd")
const _SURFACE_DETECTOR_COMPONENT := preload("res://scripts/core/ecs/components/c_surface_detector_component.gd")
const _SPAWN_RECOVERY_COMPONENT := preload("res://scripts/core/ecs/components/c_spawn_recovery_component.gd")
const _SPAWN_RECOVERY_SETTINGS := preload("res://resources/core/base_settings/gameplay/cfg_spawn_recovery_player_default.tres")

func _run() -> void:
	var body_path := "res://scenes/core/prefabs/prefab_player_body_2_5d.tscn"
	var body_packed: PackedScene = load(body_path) as PackedScene
	if body_packed == null:
		printerr("prefab_player_body_2_5d.tscn not found. Run build_prefab_player_body_2_5d first.")
		return

	var tmpl_packed: PackedScene = load("res://scenes/core/templates/tmpl_character.tscn") as PackedScene
	var root: Node = tmpl_packed.instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	root.name = "E_PlayerRoot"
	root.entity_id = &"player"
	root.tags.assign([&"player", &"character"])

	var body_mesh: Node3D = body_packed.instantiate(PackedScene.GEN_EDIT_STATE_MAIN) as Node3D
	body_mesh.name = "Body_Mesh"
	var player_body: Node = root.get_node_or_null("Player_Body")
	if player_body == null:
		printerr("Player_Body not found in tmpl_character")
		root.free()
		return
	player_body.add_child(body_mesh)

	var components: Node = root.get_node_or_null("Components")
	if components == null:
		printerr("Components not found in tmpl_character")
		root.free()
		return

	_add_component(components, "C_InputComponent", _INPUT_COMPONENT)
	var gamepad_comp: Node = _add_component(components, "C_GamepadComponent", _GAMEPAD_COMPONENT)
	gamepad_comp.settings = _GAMEPAD_SETTINGS
	_add_component(components, "C_PlayerTagComponent", _PLAYER_TAG_COMPONENT)
	var surface_comp: Node = _add_component(components, "C_SurfaceDetectorComponent", _SURFACE_DETECTOR_COMPONENT)
	surface_comp.character_body_path = NodePath("../../Player_Body")
	var recovery_comp: Node = _add_component(components, "C_SpawnRecoveryComponent", _SPAWN_RECOVERY_COMPONENT)
	recovery_comp.settings = _SPAWN_RECOVERY_SETTINGS

	_set_owner_recursive(root, root)

	var packed := PackedScene.new()
	if packed.pack(root) != OK:
		printerr("Failed to pack prefab_player_2_5d")
		return
	if ResourceSaver.save(packed, OUTPUT_PATH) != OK:
		printerr("Failed to save prefab_player_2_5d")
	else:
		print("prefab_player_2_5d built: %s" % OUTPUT_PATH)

func _add_component(parent: Node, comp_name: String, script: Script) -> Node:
	var comp := Node.new()
	comp.name = comp_name
	comp.set_script(script)
	parent.add_child(comp)
	return comp

func _set_owner_recursive(node: Node, owner: Node) -> void:
	if node != owner:
		node.set_owner(owner)
	if not node.get_scene_file_path().is_empty():
		return
	for child in node.get_children():
		_set_owner_recursive(child, owner)
