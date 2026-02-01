@icon("res://assets/editor_icons/icn_utility.svg")
extends Node
class_name U_UIScaleRoot

## Registers a UI root node with the display manager for scaling.

@export var fit_target_path: NodePath

const U_DISPLAY_UTILS := preload("res://scripts/utils/display/u_display_utils.gd")

var _registered: bool = false

func _ready() -> void:
	_register()

func _exit_tree() -> void:
	_unregister()

func _register() -> void:
	if _registered:
		return
	var target := get_parent()
	if target == null:
		return
	_register_fit_target(target)
	var manager := U_DISPLAY_UTILS.get_display_manager()
	if manager == null:
		return
	manager.register_ui_scale_root(target)
	_registered = true

func _register_fit_target(target: Node) -> void:
	if target == null:
		return
	if fit_target_path == NodePath():
		return
	if not (target is Control):
		return
	var fit_target := get_node_or_null(fit_target_path)
	if fit_target == null or not (fit_target is Control):
		return
	target.set_meta(StringName("ui_scale_fit_target"), fit_target)

func _unregister() -> void:
	if not _registered:
		return
	var target := get_parent()
	if target != null:
		var manager := U_DISPLAY_UTILS.get_display_manager()
		if manager != null:
			manager.unregister_ui_scale_root(target)
	_registered = false
