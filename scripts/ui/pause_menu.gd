extends Control

## Pause Menu - Overlay menu shown when gameplay is paused
##
## Provides buttons for:
## - Resume: Close pause menu and resume gameplay
## - Settings: Open settings menu overlay
## - Quit: Return to main menu

signal resume_pressed
signal settings_pressed
signal quit_pressed

@onready var resume_button: Button = $VBoxContainer/ResumeButton
@onready var settings_button: Button = $VBoxContainer/SettingsButton
@onready var quit_button: Button = $VBoxContainer/QuitButton

## For Scene Manager integration
var _scene_manager = null

func _ready() -> void:
	# Wait for tree to be ready
	await get_tree().process_frame

	# Find M_SceneManager
	var scene_managers: Array = get_tree().get_nodes_in_group("scene_manager")
	if scene_managers.size() > 0:
		_scene_manager = scene_managers[0]

	# Connect button signals
	resume_button.pressed.connect(_on_resume_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _on_resume_pressed() -> void:
	resume_pressed.emit()

	# Pop pause overlay via Scene Manager
	if _scene_manager != null and _scene_manager.has_method("pop_overlay"):
		_scene_manager.pop_overlay()

func _on_settings_pressed() -> void:
	settings_pressed.emit()

	# Open settings overlay with automatic return to pause (Phase 6.5)
	# Uses generic overlay navigation - when user clicks Back in settings,
	# pop_overlay_with_return() will restore pause menu automatically
	if _scene_manager != null and _scene_manager.has_method("push_overlay_with_return"):
		_scene_manager.push_overlay_with_return(StringName("settings_menu"))

func _on_quit_pressed() -> void:
	quit_pressed.emit()

	# Transition to main menu via Scene Manager
	if _scene_manager != null and _scene_manager.has_method("transition_to_scene"):
		# Pop pause menu first
		if _scene_manager.has_method("pop_overlay"):
			_scene_manager.pop_overlay()

		# Then transition to main menu
		_scene_manager.transition_to_scene(StringName("main_menu"), "fade")
