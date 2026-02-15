@icon("res://assets/editor_icons/icn_utility.svg")
extends Node
class_name U_LocalizationRoot

## Registers a UI root node with the localization manager for font cascade.
## Follows the same retry-polling pattern as U_UIScaleRoot.

const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")

const MAX_REGISTER_FRAMES: int = 30

var _registered: bool = false
var _frames_remaining: int = 0
var _skip_first_process: bool = true

func _ready() -> void:
	_frames_remaining = MAX_REGISTER_FRAMES
	_skip_first_process = true
	set_process(true)

func _exit_tree() -> void:
	_unregister()

func _process(_delta: float) -> void:
	if _registered:
		set_process(false)
		return

	if _skip_first_process:
		_skip_first_process = false
		return

	_frames_remaining -= 1
	_register()

	if _registered or _frames_remaining <= 0:
		set_process(false)

func _register() -> void:
	if _registered:
		return
	var target := get_parent()
	if target == null:
		return
	var manager := U_SERVICE_LOCATOR.try_get_service(StringName("localization_manager"))
	if manager == null:
		return
	manager.register_ui_root(target)
	_registered = true

func _unregister() -> void:
	if not _registered:
		return
	var target := get_parent()
	if target != null:
		var manager := U_SERVICE_LOCATOR.try_get_service(StringName("localization_manager"))
		if manager != null:
			manager.unregister_ui_root(target)
	_registered = false
