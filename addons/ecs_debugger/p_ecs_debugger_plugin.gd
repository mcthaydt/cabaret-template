@tool
extends EditorPlugin

class_name P_ECSDebuggerPlugin

const PANEL_SCRIPT := preload("res://addons/ecs_debugger/t_ecs_debugger_panel.gd")
const DATA_SOURCE_CLASS := preload("res://scripts/utils/u_ecs_debug_data_source.gd")

var _panel: T_ECSDebuggerPanel
var _panel_button: Button

func _enter_tree() -> void:
	_panel = PANEL_SCRIPT.new()
	_panel.set_editor_interface(get_editor_interface())
	_panel.set_data_source(DATA_SOURCE_CLASS.new())
	_panel_button = add_control_to_bottom_panel(_panel, "ECS Debugger")

func _exit_tree() -> void:
	if _panel_button != null:
		remove_control_from_bottom_panel(_panel)
	_panel_button = null

	if _panel != null:
		_panel.queue_free()
	_panel = null

static func create_panel_for_tests(_editor_interface: EditorInterface) -> T_ECSDebuggerPanel:
	var panel: T_ECSDebuggerPanel = PANEL_SCRIPT.new()
	panel.set_editor_interface(_editor_interface)
	panel.set_data_source(DATA_SOURCE_CLASS.new())
	return panel
