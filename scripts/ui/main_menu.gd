extends Control

## Main Menu UI Controller
##
## Handles button interactions for the main menu.
## Buttons trigger scene transitions via M_SceneManager.

@onready var play_button: Button = $VBoxContainer/PlayButton
@onready var settings_button: Button = $VBoxContainer/SettingsButton

var _scene_manager: M_SceneManager = null

func _ready() -> void:
	# Find M_SceneManager via group
	await get_tree().process_frame
	var managers: Array = get_tree().get_nodes_in_group("scene_manager")
	if managers.size() > 0:
		_scene_manager = managers[0] as M_SceneManager
	else:
		push_error("MainMenu: No M_SceneManager found in 'scene_manager' group")
		return

	# Connect button signals
	if play_button:
		play_button.pressed.connect(_on_play_pressed)
	if settings_button:
		settings_button.pressed.connect(_on_settings_pressed)

func _on_play_pressed() -> void:
	if _scene_manager:
		_scene_manager.transition_to_scene(StringName("exterior"), "loading")

func _on_settings_pressed() -> void:
	if _scene_manager:
		_scene_manager.transition_to_scene(StringName("settings_menu"), "instant")
