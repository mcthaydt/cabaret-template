@icon("res://assets/editor_icons/icn_utility.svg")
extends Control
class_name BasePanel

## Shared base class for panel-style UI controls.
##
## Provides common store lookup, focus management, and back-input handling
## so concrete panels only need to implement their domain logic.

const U_StateUtils := preload("res://scripts/state/utils/u_state_utils.gd")
const U_UISoundPlayer := preload("res://scripts/ui/utils/u_ui_sound_player.gd")

const BACK_ACTION_CANCEL := StringName("ui_cancel")
const BACK_ACTION_PAUSE := StringName("ui_pause")

const _FOCUS_SOUND_ARM_WINDOW_MS: int = 250
const _FOCUS_SOUND_ARM_ACTIONS: Array[StringName] = [
	StringName("ui_up"),
	StringName("ui_down"),
	StringName("ui_left"),
	StringName("ui_right"),
	StringName("ui_focus_next"),
	StringName("ui_focus_prev"),
]

var _store: I_StateStore = null
var _focus_sound_armed: bool = false
var _focus_sound_armed_time_ms: int = 0
var _focus_sound_armed_before: Control = null

func _ready() -> void:
	_connect_ui_sound_signals()
	set_process_input(true)
	set_process_unhandled_input(true)
	set_process_unhandled_key_input(true)
	call_deferred("_deferred_panel_ready")

func _deferred_panel_ready() -> void:
	if not is_inside_tree():
		return
	_ensure_store_ready()
	_on_panel_ready()
	_apply_initial_focus()

func _connect_ui_sound_signals() -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	if not viewport.gui_focus_changed.is_connected(_on_gui_focus_changed):
		viewport.gui_focus_changed.connect(_on_gui_focus_changed)

func _input(event: InputEvent) -> void:
	_maybe_arm_focus_sound(event)

func _on_gui_focus_changed(control: Control) -> void:
	if control == null:
		return
	if not is_visible_in_tree():
		_disarm_focus_sound()
		return
	if _focus_sound_armed and (control != self and not is_ancestor_of(control)):
		_disarm_focus_sound()
		return
	if control != self and not is_ancestor_of(control):
		return
	if not control.is_visible_in_tree():
		return
	if not _consume_focus_sound_arm(control):
		return
	U_UISoundPlayer.play_focus()

func _maybe_arm_focus_sound(event: InputEvent) -> void:
	if event == null:
		return
	if not is_visible_in_tree():
		return

	# Do not arm on analog stick motion. Analog navigation is driven by the
	# BaseMenuScreen repeater and should arm at the actual focus move point.
	if event is InputEventJoypadMotion:
		return

	var pressed_action: StringName = StringName("")
	for action in _FOCUS_SOUND_ARM_ACTIONS:
		if event.is_action_pressed(action):
			pressed_action = action
			break
	if pressed_action.is_empty():
		return

	var viewport := get_viewport()
	if viewport == null:
		return
	var focused := viewport.gui_get_focus_owner() as Control
	if focused == null:
		return
	_arm_focus_sound(focused)

func _arm_focus_sound(focused_before: Control) -> void:
	if focused_before == null or not is_instance_valid(focused_before):
		return
	if focused_before != self and not is_ancestor_of(focused_before):
		return
	if not focused_before.is_visible_in_tree():
		return

	_focus_sound_armed = true
	_focus_sound_armed_time_ms = Time.get_ticks_msec()
	_focus_sound_armed_before = focused_before

func _consume_focus_sound_arm(new_focus: Control) -> bool:
	if not _focus_sound_armed:
		return false

	var before := _focus_sound_armed_before
	if before == null or not is_instance_valid(before):
		_disarm_focus_sound()
		return false
	if before != self and not is_ancestor_of(before):
		_disarm_focus_sound()
		return false

	var age_ms: int = Time.get_ticks_msec() - _focus_sound_armed_time_ms
	if age_ms > _FOCUS_SOUND_ARM_WINDOW_MS:
		_disarm_focus_sound()
		return false

	# Only play focus sound for focus moves from an existing focused control
	# inside the panel. Initial/programmatic focus assignment is silent.
	if new_focus == before:
		_disarm_focus_sound()
		return false

	_disarm_focus_sound()
	return true

func _disarm_focus_sound() -> void:
	_focus_sound_armed = false
	_focus_sound_armed_time_ms = 0
	_focus_sound_armed_before = null

func get_store() -> I_StateStore:
	return _store

func _ensure_store_ready() -> void:
	if _store != null:
		return
	if not is_inside_tree():
		return
	_store = U_StateUtils.try_get_store(self)
	if _store != null:
		_on_store_ready(_store)

func _apply_initial_focus() -> void:
	if not is_inside_tree():
		return
	call_deferred("_apply_initial_focus_deferred")

func _apply_initial_focus_deferred() -> void:
	if not is_inside_tree():
		return
	var default_focus: Control = _get_first_focusable()
	if default_focus != null and default_focus.is_inside_tree():
		default_focus.grab_focus()

func _get_first_focusable() -> Control:
	return _find_focusable_in(self)

func _find_focusable_in(root: Node) -> Control:
	for child in root.get_children():
		if not (child is Node):
			continue
		if child is Control:
			var child_control := child as Control
			if child_control != self \
					and child_control.focus_mode != Control.FOCUS_NONE \
					and child_control.is_visible_in_tree():
				return child_control
			var nested_control := _find_focusable_in(child_control)
			if nested_control != null:
				return nested_control
		else:
			var nested := _find_focusable_in(child)
			if nested != null:
				return nested
	return null

func _unhandled_input(event: InputEvent) -> void:
	if _should_handle_back_input(event):
		var viewport := get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
		_on_back_pressed()

func _should_handle_back_input(event: InputEvent) -> bool:
	return event.is_action_pressed(BACK_ACTION_CANCEL) \
		or event.is_action_pressed(BACK_ACTION_PAUSE)

func _on_back_pressed() -> void:
	# Intentionally blank; subclasses override to dispatch navigation actions.
	pass

func _on_store_ready(_store_ref: M_StateStore) -> void:
	# Hook for subclasses that need immediate access once the store is available.
	pass

func _on_panel_ready() -> void:
	# Hook for subclasses to perform extra initialization after store lookup.
	pass
