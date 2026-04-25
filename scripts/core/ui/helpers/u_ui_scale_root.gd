@icon("res://assets/core/editor_icons/icn_utility.svg")
extends Node
class_name U_UIScaleRoot

## Registers a UI root node with the display manager for scaling.

const U_DISPLAY_UTILS := preload("res://scripts/core/utils/display/u_display_utils.gd")
const U_UI_THEME_DEBUG := preload("res://scripts/core/ui/utils/u_ui_theme_debug.gd")

const MAX_REGISTER_FRAMES: int = 30

var _registered: bool = false
var _frames_remaining: int = 0
var _skip_first_process: bool = true
var _logged_waiting: bool = false
var _logged_timeout: bool = false

func _ready() -> void:
	_frames_remaining = MAX_REGISTER_FRAMES
	_skip_first_process = true
	_logged_waiting = false
	_logged_timeout = false
	_theme_debug_log("ready; waiting for display_manager registration")
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

	if not _registered and _frames_remaining <= 0 and not _logged_timeout:
		_logged_timeout = true
		_theme_debug_log("registration timed out after %d frames" % MAX_REGISTER_FRAMES)

	if _registered or _frames_remaining <= 0:
		set_process(false)

func _register() -> void:
	if _registered:
		return
	var target := get_parent()
	if target == null:
		return
	var manager := U_DISPLAY_UTILS.get_display_manager()
	if manager == null:
		if not _logged_waiting:
			_logged_waiting = true
			_theme_debug_log("display_manager not available yet; frames_remaining=%d" % _frames_remaining)
		return
	if _logged_waiting:
		_theme_debug_log("display_manager became available; registering root")
	manager.register_ui_scale_root(target)
	_registered = true
	_theme_debug_log("registered parent root '%s'" % target.name)

func _unregister() -> void:
	if not _registered:
		return
	var target := get_parent()
	if target != null:
		var manager := U_DISPLAY_UTILS.get_display_manager()
		if manager != null:
			manager.unregister_ui_scale_root(target)
			_theme_debug_log("unregistered parent root '%s'" % target.name)
	_registered = false

func _theme_debug_log(message: String) -> void:
	var parent_name := "<no-parent>"
	var parent := get_parent()
	if parent != null:
		parent_name = parent.name
	U_UI_THEME_DEBUG.log("U_UIScaleRoot:%s" % parent_name, message)
