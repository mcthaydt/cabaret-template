extends Node

## Test script for main.tscn to load gameplay_base.tscn
##
## This is a temporary testing script for Phase 2 validation.
## It loads gameplay_base.tscn into the ActiveSceneContainer to test
## that the scene restructuring works correctly.

const GAMEPLAY_BASE_PATH := "res://scenes/gameplay/gameplay_base.tscn"

@onready var active_scene_container: Node = get_node("../../ActiveSceneContainer")

func _ready() -> void:
	if not active_scene_container:
		push_error("TestRootLoader: Could not find ActiveSceneContainer")
		return

	# Load gameplay_base.tscn
	var gameplay_scene: PackedScene = load(GAMEPLAY_BASE_PATH)
	if not gameplay_scene:
		push_error("TestRootLoader: Could not load gameplay_base.tscn")
		return

	# Instantiate and add to ActiveSceneContainer
	var gameplay_instance: Node = gameplay_scene.instantiate()
	active_scene_container.add_child(gameplay_instance)

	print("TestRootLoader: Successfully loaded gameplay_base.tscn into ActiveSceneContainer")
