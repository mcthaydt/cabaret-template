@tool
extends Node

## Tool script to generate area transition scene templates
##
## This script creates exterior.tscn and interior_house.tscn for Phase 6 (Area Transitions).
## Run this from the Godot editor to generate the scenes programmatically.
##
## Usage:
## 1. Add this script to a Node in the scene tree (or run via command line)
## 2. Call generate_scenes()
## 3. Scenes will be created in scenes/gameplay/

const U_SCENE_BUILDER := preload("res://scripts/utils/u_scene_builder.gd")

## Generate both area scene templates
func generate_scenes() -> void:
	print("====== Generating Area Transition Scenes ======")

	# Generate exterior.tscn
	var exterior_success: bool = U_SCENE_BUILDER.create_area_scene(
		"exterior",
		StringName("door_to_house"),
		StringName("interior_house"),
		StringName("entrance_from_exterior"),
		StringName("exit_from_house"),
		"res://scenes/gameplay/exterior.tscn"
	)

	if exterior_success:
		print("✅ exterior.tscn created successfully")
	else:
		push_error("❌ Failed to create exterior.tscn")

	# Generate interior_house.tscn
	var interior_success: bool = U_SCENE_BUILDER.create_area_scene(
		"interior_house",
		StringName("door_to_exterior"),
		StringName("exterior"),
		StringName("exit_from_house"),
		StringName("entrance_from_exterior"),
		"res://scenes/gameplay/interior_house.tscn"
	)

	if interior_success:
		print("✅ interior_house.tscn created successfully")
	else:
		push_error("❌ Failed to create interior_house.tscn")

	print("====== Scene Generation Complete ======")

	if exterior_success and interior_success:
		print("All scenes generated successfully!")
	else:
		push_error("Some scenes failed to generate")

## Auto-run when script is loaded in editor
func _ready() -> void:
	if Engine.is_editor_hint():
		call_deferred("generate_scenes")
