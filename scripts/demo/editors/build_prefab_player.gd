@tool
extends EditorScript

const OUTPUT_PATH := "res://scenes/core/prefabs/prefab_player.tscn"
const BODY_SCENE_PATH := "res://scenes/core/prefabs/prefab_player_body.tscn"

const _INPUT_COMPONENT := preload("res://scripts/core/ecs/components/c_input_component.gd")
const _GAMEPAD_COMPONENT := preload("res://scripts/core/ecs/components/c_gamepad_component.gd")
const _GAMEPAD_SETTINGS := preload("res://resources/core/input/gamepad_settings/cfg_default_gamepad_settings.tres")
const _PLAYER_TAG_COMPONENT := preload("res://scripts/core/ecs/components/c_player_tag_component.gd")
const _SURFACE_DETECTOR_COMPONENT := preload("res://scripts/core/ecs/components/c_surface_detector_component.gd")
const _SPAWN_RECOVERY_COMPONENT := preload("res://scripts/core/ecs/components/c_spawn_recovery_component.gd")
const _SPAWN_RECOVERY_SETTINGS := preload("res://resources/core/base_settings/gameplay/cfg_spawn_recovery_player_default.tres")

func _run() -> void:
	if not FileAccess.file_exists(BODY_SCENE_PATH):
		printerr("prefab_player_body.tscn not found. Run build_prefab_player_body first.")
		return

	var builder := U_EditorPrefabBuilder.new()
	builder.inherit_from("res://scenes/core/templates/tmpl_character.tscn")
	builder.override_property(".", "name", "E_PlayerRoot")
	builder.override_property(".", "entity_id", &"player")
	builder.override_property(".", "tags", [&"player", &"character"])
	builder.add_child_scene_to("Player_Body", BODY_SCENE_PATH, "Body_Mesh")

	builder.add_ecs_component(_INPUT_COMPONENT)
	var gamepad_component := _build_component("C_GamepadComponent", _GAMEPAD_COMPONENT)
	gamepad_component.settings = _GAMEPAD_SETTINGS
	builder.add_child_to("Components", gamepad_component)
	builder.add_ecs_component(_PLAYER_TAG_COMPONENT)

	var surface_component := _build_component("C_SurfaceDetectorComponent", _SURFACE_DETECTOR_COMPONENT)
	surface_component.character_body_path = NodePath("../../Player_Body")
	builder.add_child_to("Components", surface_component)

	var spawn_recovery_component := _build_component("C_SpawnRecoveryComponent", _SPAWN_RECOVERY_COMPONENT)
	spawn_recovery_component.settings = _SPAWN_RECOVERY_SETTINGS
	builder.add_child_to("Components", spawn_recovery_component)

	if builder.save(OUTPUT_PATH):
		print("prefab_player built: %s" % OUTPUT_PATH)
	else:
		printerr("Failed to build prefab_player")

func _build_component(component_name: String, script: Script) -> Node:
	var component := Node.new()
	component.name = component_name
	component.set_script(script)
	return component
