extends Control

## Settings Menu UI Controller
##
## Handles button interactions for the settings menu.
## Buttons trigger scene transitions via M_SceneManager.

@onready var back_button: Button = $VBoxContainer/BackButton

var _scene_manager: M_SceneManager = null

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

func _on_back_pressed() -> void:
	if _scene_manager:
		_scene_manager.transition_to_scene(StringName("main_menu"), "instant")
