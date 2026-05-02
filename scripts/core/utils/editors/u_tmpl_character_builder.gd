class_name U_TmplCharacterBuilder
extends RefCounted

const BASE_ECS_ENTITY_SCRIPT := preload("res://scripts/core/ecs/base_ecs_entity.gd")
const MARKER_COMPONENTS_GROUP := preload("res://scripts/core/scene_structure/marker_components_group.gd")
const SPAWN_STATE_SCRIPT := preload("res://scripts/core/ecs/components/c_spawn_state_component.gd")
const CHARACTER_STATE_SCRIPT := preload("res://scripts/core/ecs/components/c_character_state_component.gd")
const MOVEMENT_SCRIPT := preload("res://scripts/core/ecs/components/c_movement_component.gd")
const MOVEMENT_SETTINGS := preload("res://resources/core/base_settings/gameplay/cfg_movement_default.tres")
const JUMP_SCRIPT := preload("res://scripts/core/ecs/components/c_jump_component.gd")
const JUMP_SETTINGS := preload("res://resources/core/base_settings/gameplay/cfg_jump_default.tres")
const ROTATE_SCRIPT := preload("res://scripts/core/ecs/components/c_rotate_to_input_component.gd")
const ROTATE_SETTINGS := preload("res://resources/core/base_settings/gameplay/cfg_rotate_default.tres")
const FLOATING_SCRIPT := preload("res://scripts/core/ecs/components/c_floating_component.gd")
const FLOATING_SETTINGS := preload("res://resources/core/base_settings/gameplay/cfg_floating_default.tres")
const ALIGN_SCRIPT := preload("res://scripts/core/ecs/components/c_align_with_surface_component.gd")
const ALIGN_SETTINGS := preload("res://resources/core/base_settings/gameplay/cfg_align_default.tres")
const LANDING_SCRIPT := preload("res://scripts/core/ecs/components/c_landing_indicator_component.gd")
const LANDING_SETTINGS := preload("res://resources/core/base_settings/gameplay/cfg_landing_indicator_default.tres")
const HEALTH_SCRIPT := preload("res://scripts/core/ecs/components/c_health_component.gd")
const HEALTH_SETTINGS := preload("res://resources/core/base_settings/gameplay/cfg_health_settings.tres")

const HOVER_RAYS := [
	{name = "Center", x = 0.0, z = 0.0},
	{name = "Forward", x = 0.0, z = 0.1},
	{name = "Back", x = 0.0, z = -0.1},
	{name = "Left", x = -0.1, z = 0.0},
	{name = "Right", x = 0.1, z = 0.0},
	{name = "ForwardLeft", x = -0.07, z = 0.07},
	{name = "ForwardRight", x = 0.07, z = 0.07},
	{name = "BackLeft", x = -0.07, z = -0.07},
	{name = "BackRight", x = 0.07, z = -0.07},
]

var _root: Node3D = null

func create_root() -> U_TmplCharacterBuilder:
	var node := Node3D.new()
	node.name = "E_CharacterRoot"
	node.set_script(BASE_ECS_ENTITY_SCRIPT)
	node.tags.assign([&"character"])
	_root = node
	return self

func add_character_body() -> U_TmplCharacterBuilder:
	var body := CharacterBody3D.new()
	body.name = "Player_Body"
	_root.add_child(body)

	var anchor := Node3D.new()
	anchor.name = "CameraFollowAnchor"
	anchor.position = Vector3(0, 0.64, 0)
	body.add_child(anchor)

	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	collision.transform = Transform3D.IDENTITY.translated(Vector3(0, 0.165, 0))
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.12
	capsule.height = 0.33
	collision.shape = capsule
	body.add_child(collision)

	return self

func add_hover_rays() -> U_TmplCharacterBuilder:
	var rays := Node3D.new()
	rays.name = "HoverRays"
	_root.get_node("Player_Body").add_child(rays)

	var target := Vector3(0, -0.28, 0)
	for entry in HOVER_RAYS:
		var ray := RayCast3D.new()
		ray.name = entry.name
		ray.target_position = target
		if entry.x != 0.0 or entry.z != 0.0:
			ray.transform = Transform3D.IDENTITY.translated(Vector3(entry.x, 0, entry.z))
		rays.add_child(ray)

	return self

func add_components() -> U_TmplCharacterBuilder:
	var container := Node.new()
	container.name = "Components"
	container.set_script(MARKER_COMPONENTS_GROUP)
	_root.add_child(container)

	const BODY_PATH := "../../Player_Body"
	_add_component(container, "C_SpawnStateComponent", SPAWN_STATE_SCRIPT, {"character_body_path": BODY_PATH})
	_add_component(container, "C_CharacterStateComponent", CHARACTER_STATE_SCRIPT, {})
	_add_component(container, "C_MovementComponent", MOVEMENT_SCRIPT, {"settings": MOVEMENT_SETTINGS})
	_add_component(container, "C_JumpComponent", JUMP_SCRIPT, {"settings": JUMP_SETTINGS, "character_body_path": BODY_PATH})
	_add_component(container, "C_RotateToInputComponent", ROTATE_SCRIPT, {"settings": ROTATE_SETTINGS, "target_node_path": BODY_PATH})
	_add_component(container, "C_FloatingComponent", FLOATING_SCRIPT, {"settings": FLOATING_SETTINGS, "character_body_path": BODY_PATH, "raycast_root_path": BODY_PATH + "/HoverRays"})
	_add_component(container, "C_AlignWithSurfaceComponent", ALIGN_SCRIPT, {"settings": ALIGN_SETTINGS, "character_body_path": BODY_PATH, "visual_alignment_path": BODY_PATH + "/Body_Mesh"})
	_add_component(container, "C_LandingIndicatorComponent", LANDING_SCRIPT, {"settings": LANDING_SETTINGS, "character_body_path": BODY_PATH, "origin_marker_path": BODY_PATH + "/HoverRays/Center", "landing_marker_path": BODY_PATH + "/Body_Mesh/GroundIndicator"})
	_add_component(container, "C_HealthComponent", HEALTH_SCRIPT, {"settings": HEALTH_SETTINGS, "character_body_path": BODY_PATH})

	return self

func save(path: String) -> bool:
	if _root == null:
		push_error("U_TmplCharacterBuilder: save() called before create_root()")
		return false
	_set_owner_recursive(_root, _root)
	var packed := PackedScene.new()
	var pack_result := packed.pack(_root)
	if pack_result != OK:
		push_error("U_TmplCharacterBuilder: pack() failed with code %d" % pack_result)
		return false
	var save_result := ResourceSaver.save(packed, path)
	if save_result != OK:
		push_error("U_TmplCharacterBuilder: ResourceSaver.save() failed with code %d" % save_result)
		return false
	return true

func build() -> Node3D:
	if _root == null:
		push_error("U_TmplCharacterBuilder: build() called before create_root()")
		return null
	return _root

func _add_component(parent: Node, name_: String, script: Script, props: Dictionary) -> void:
	var node := Node.new()
	node.name = name_
	node.set_script(script)
	for key in props:
		node.set(key, props[key])
	parent.add_child(node)

func _set_owner_recursive(node: Node, owner: Node) -> void:
	if node != owner:
		node.set_owner(owner)
	var scene_path: String = node.get_scene_file_path()
	if not scene_path.is_empty():
		return
	for child in node.get_children():
		_set_owner_recursive(child, owner)
