@icon("res://assets/editor_icons/icn_manager.svg")
extends Node
class_name M_ScreenshotCache

## Screenshot Cache Manager (Phase 16B)
##
## Caches the last gameplay frame before pause so manual saves can use a
## gameplay thumbnail instead of a paused UI screenshot.

const U_SCREENSHOT_CAPTURE := preload("res://scripts/managers/helpers/u_screenshot_capture.gd")
const U_NAVIGATION_ACTIONS := preload("res://scripts/state/actions/u_navigation_actions.gd")
const I_STATE_STORE := preload("res://scripts/interfaces/i_state_store.gd")

var _state_store: I_StateStore = null
var _cached_image: Image = null
var _capture_helper: U_ScreenshotCapture = null

func _ready() -> void:
	U_ServiceLocator.register(StringName("screenshot_cache"), self)

	await get_tree().process_frame

	_state_store = _get_state_store()
	_capture_helper = U_SCREENSHOT_CAPTURE.new()
	_subscribe_to_store()

func _exit_tree() -> void:
	_unsubscribe_from_store()

func cache_current_frame() -> void:
	if not _is_in_gameplay_shell():
		return

	var viewport := get_viewport()
	var image: Image = _capture_image_from_viewport(viewport)
	if image == null:
		return

	_cached_image = image

func get_cached_screenshot() -> Image:
	return _cached_image

func clear_cache() -> void:
	_cached_image = null

func has_cached_screenshot() -> bool:
	return _cached_image != null

func _get_state_store() -> I_StateStore:
	return U_ServiceLocator.get_service(StringName("state_store")) as I_StateStore

func _subscribe_to_store() -> void:
	if _state_store != null and _state_store.has_signal("action_dispatched"):
		_state_store.action_dispatched.connect(_on_action_dispatched)

func _unsubscribe_from_store() -> void:
	if _state_store != null and _state_store.has_signal("action_dispatched"):
		if _state_store.action_dispatched.is_connected(_on_action_dispatched):
			_state_store.action_dispatched.disconnect(_on_action_dispatched)

func _on_action_dispatched(action: Dictionary) -> void:
	var action_type: StringName = action.get("type", StringName(""))
	if action_type == U_NAVIGATION_ACTIONS.ACTION_OPEN_PAUSE:
		cache_current_frame()

func _is_in_gameplay_shell() -> bool:
	if _state_store == null:
		return false

	var state: Dictionary = _state_store.get_state()
	var navigation: Dictionary = state.get("navigation", {})
	return navigation.get("shell", "") == "gameplay"

func _capture_image_from_viewport(viewport: Viewport) -> Image:
	if _capture_helper == null:
		_capture_helper = U_SCREENSHOT_CAPTURE.new()
	return _capture_helper.capture_viewport(viewport)
