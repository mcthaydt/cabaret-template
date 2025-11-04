@icon("res://resources/editor_icons/utility.svg")
extends Control

## Settings Menu UI Controller
##
## Handles button interactions for the settings menu.
## Buttons trigger scene transitions via M_SceneManager.

@onready var back_button: Button = $VBoxContainer/BackButton

var _scene_manager: M_SceneManager = null
var _is_overlay: bool = false

func _ready() -> void:
	# Find M_SceneManager via group
	await get_tree().process_frame
	var managers: Array = get_tree().get_nodes_in_group("scene_manager")
	if managers.size() > 0:
		_scene_manager = managers[0] as M_SceneManager
	else:
		push_error("SettingsMenu: No M_SceneManager found in 'scene_manager' group")
		return

	# Connect button signals
	if back_button:
		back_button.pressed.connect(_on_back_pressed)

	# Determine if we're running as an overlay (child of UIOverlayStack CanvasLayer)
	var parent_node := get_parent()
	_is_overlay = parent_node is CanvasLayer

	# Adjust back button label based on context
	if _is_overlay:
		back_button.text = "Back"
	else:
		back_button.text = "Back to Main Menu"

func _on_back_pressed() -> void:
	if _scene_manager == null:
		return

	# If overlay context, use generic overlay return navigation (Phase 6.5)
	# pop_overlay_with_return() will automatically restore the previous overlay
	# (e.g., pause menu) from the return stack
	if _is_overlay and _scene_manager.has_method("pop_overlay_with_return"):
		_scene_manager.pop_overlay_with_return()
		return

	# Otherwise use Scene Manager scene history navigation
	if _scene_manager.has_method("can_go_back") and _scene_manager.can_go_back():
		_scene_manager.go_back()
	else:
		_scene_manager.transition_to_scene(StringName("main_menu"), "instant")
