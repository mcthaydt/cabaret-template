@icon("res://resources/editor_icons/utility.svg")
extends Control
class_name BasePanel

## Shared base class for panel-style UI controls.
##
## Provides common store lookup, focus management, and back-input handling
## so concrete panels only need to implement their domain logic.

const U_StateUtils := preload("res://scripts/state/utils/u_state_utils.gd")

const BACK_ACTION_CANCEL := StringName("ui_cancel")
const BACK_ACTION_PAUSE := StringName("ui_pause")

var _store: I_StateStore = null

func _ready() -> void:
	set_process_input(true)
	set_process_unhandled_input(true)
	set_process_unhandled_key_input(true)
	await _ensure_store_ready()
	_on_panel_ready()
	await _apply_initial_focus()

func get_store() -> I_StateStore:
	return _store

func _ensure_store_ready() -> void:
	if _store != null:
		return
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null:
		return
	await tree.process_frame
	if not is_inside_tree():
		return
	_store = U_StateUtils.get_store(self)
	if _store != null:
		_on_store_ready(_store)

func _apply_initial_focus() -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null:
		return
	await tree.process_frame
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
