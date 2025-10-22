@tool
extends PanelContainer

class_name T_ECSDebuggerPanel

const DATA_SOURCE_CLASS := preload("res://scripts/utils/u_ecs_debug_data_source.gd")
const M_MANAGER := preload("res://scripts/managers/m_ecs_manager.gd")

var _editor_interface: EditorInterface
var _data_source: Object
var _cached_manager: M_ECSManager

var _query_status_label: Label
var _query_tree: Tree

var _event_status_label: Label
var _event_filter: LineEdit
var _event_text: TextEdit

var _system_status_label: Label
var _systems_tree: Tree
var _is_updating_systems: bool = false
var _systems_map: Dictionary = {}

var _refresh_timer: Timer

func _ready() -> void:
	if _data_source == null:
		_data_source = DATA_SOURCE_CLASS.new()
	_build_ui()
	_start_refresh_timer()

func set_editor_interface(editor_interface: EditorInterface) -> void:
	_editor_interface = editor_interface

func set_data_source(data_source: Object) -> void:
	_data_source = data_source

func get_data_source() -> Object:
	return _data_source

func refresh_with_manager(manager: M_ECSManager) -> void:
	_refresh_queries(manager)
	_refresh_events()
	_refresh_systems(manager)

func toggle_system_by_instance(manager: M_ECSManager, instance_id: int, enabled: bool) -> void:
	if manager == null:
		return
	var systems: Array = manager.get_systems()
	for system in systems:
		if system == null:
			continue
		if not is_instance_valid(system):
			continue
		if system.get_instance_id() != instance_id:
			continue
		system.set_debug_disabled(not enabled)
		return

func get_query_tree() -> Tree:
	return _query_tree

func _start_refresh_timer() -> void:
	_refresh_timer = Timer.new()
	_refresh_timer.wait_time = 0.5
	_refresh_timer.autostart = true
	_refresh_timer.one_shot = false
	add_child(_refresh_timer)
	_refresh_timer.timeout.connect(_on_refresh_timer_timeout)

func _on_refresh_timer_timeout() -> void:
	var manager := _locate_manager()
	if manager != null:
		refresh_with_manager(manager)
	else:
		_refresh_events()

func _locate_manager() -> M_ECSManager:
	if _cached_manager != null and is_instance_valid(_cached_manager):
		return _cached_manager
	var tree := get_tree()
	if tree == null:
		return null
	var group := tree.get_nodes_in_group("ecs_manager")
	if not group.is_empty():
		_cached_manager = group[0] as M_ECSManager
		return _cached_manager
	return null

func _build_ui() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var main := VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(main)

	var tabs := TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(tabs)

	_build_query_tab(tabs)
	_build_events_tab(tabs)
	_build_systems_tab(tabs)

func _build_query_tab(tabs: TabContainer) -> void:
	var container := VBoxContainer.new()
	container.name = "Queries"
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_child(container)

	_query_status_label = Label.new()
	_query_status_label.text = "Locating ECS manager..."
	container.add_child(_query_status_label)

	_query_tree = Tree.new()
	_query_tree.columns = 6
	_query_tree.set_column_titles_visible(true)
	_query_tree.set_column_title(0, "Query")
	_query_tree.set_column_title(1, "Calls")
	_query_tree.set_column_title(2, "Cache Hits")
	_query_tree.set_column_title(3, "Hit Rate")
	_query_tree.set_column_title(4, "Last Duration (s)")
	_query_tree.set_column_title(5, "Last Count")
	_query_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_query_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(_query_tree)

func _build_events_tab(tabs: TabContainer) -> void:
	var container := VBoxContainer.new()
	container.name = "Events"
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_child(container)

	_event_status_label = Label.new()
	_event_status_label.text = "No events captured."
	container.add_child(_event_status_label)

	var filter_row := HBoxContainer.new()
	filter_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(filter_row)

	var filter_label := Label.new()
	filter_label.text = "Filter:"
	filter_row.add_child(filter_label)

	_event_filter = LineEdit.new()
	_event_filter.placeholder_text = "Event name contains..."
	_event_filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_event_filter.text_changed.connect(_on_event_filter_changed)
	filter_row.add_child(_event_filter)

	var copy_button := Button.new()
	copy_button.text = "Copy JSON"
	copy_button.pressed.connect(_on_copy_events_pressed)
	filter_row.add_child(copy_button)

	_event_text = TextEdit.new()
	_event_text.editable = false
	_event_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_event_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(_event_text)

func _build_systems_tab(tabs: TabContainer) -> void:
	var container := VBoxContainer.new()
	container.name = "System Order"
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_child(container)

	_system_status_label = Label.new()
	_system_status_label.text = "No systems registered."
	container.add_child(_system_status_label)

	_systems_tree = Tree.new()
	_systems_tree.columns = 3
	_systems_tree.set_column_titles_visible(true)
	_systems_tree.set_column_title(0, "Enabled")
	_systems_tree.set_column_title(1, "System")
	_systems_tree.set_column_title(2, "Priority")
	_systems_tree.set_column_expand(0, false)
	_systems_tree.set_column_expand(2, false)
	_systems_tree.set_column_custom_minimum_width(0, 90)
	_systems_tree.set_column_custom_minimum_width(2, 80)
	_systems_tree.item_edited.connect(_on_system_item_edited)
	container.add_child(_systems_tree)

func _refresh_queries(manager: M_ECSManager) -> void:
	if _query_tree == null:
		return
	_query_tree.clear()
	if _data_source == null:
		_query_status_label.text = "No data source configured."
		return

	var metrics: Array = _data_source.get_query_metrics(manager)
	if metrics.is_empty():
		_query_status_label.text = "No query metrics recorded yet."
		_query_tree.create_item()
		return

	_query_status_label.text = "Showing %d cached queries." % metrics.size()
	var root := _query_tree.create_item()
	for metric in metrics:
		var item := _query_tree.create_item(root)
		item.set_text(0, _format_query(metric))
		item.set_text(1, str(metric.get("total_calls", 0)))
		item.set_text(2, str(metric.get("cache_hits", 0)))
		var hit_rate: float = float(metric.get("cache_hit_rate", 0.0))
		item.set_text(3, "%.2f" % hit_rate)
		item.set_text(4, "%.4f" % float(metric.get("last_duration", 0.0)))
		item.set_text(5, str(metric.get("last_result_count", 0)))

func _refresh_events() -> void:
	if _event_text == null or _data_source == null:
		return

	var history: Array = _data_source.get_event_history()
	var filter_text := ""
	if _event_filter != null:
		filter_text = _event_filter.text.strip_edges()

	var filtered: Array = []
	for event_data in history:
		var event_name := String(event_data.get("name", ""))
		if filter_text != "" and event_name.findn(filter_text) == -1:
			continue
		filtered.append(event_data)

	if _event_status_label != null:
		if filtered.is_empty():
			_event_status_label.text = "No events captured."
		else:
			_event_status_label.text = "Displaying %d events." % filtered.size()

	_event_text.text = _format_events_text(filtered)

func _refresh_systems(manager: M_ECSManager) -> void:
	if _systems_tree == null:
		return
	_systems_tree.clear()
	_systems_map.clear()

	if manager == null or _data_source == null:
		_system_status_label.text = "No M_ECSManager found."
		_systems_tree.create_item()
		return

	var overview: Array = _data_source.get_system_overview(manager)
	if overview.is_empty():
		_system_status_label.text = "No systems registered with manager."
		_systems_tree.create_item()
		return

	_system_status_label.text = "%d systems registered." % overview.size()
	var root := _systems_tree.create_item()
	_is_updating_systems = true
	for system_data in overview:
		var instance_id: int = int(system_data.get("instance_id", 0))
		_systems_map[instance_id] = system_data

		var item := _systems_tree.create_item(root)
		item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
		item.set_editable(0, true)
		item.set_checked(0, bool(system_data.get("enabled", true)))
		item.set_metadata(0, instance_id)
		item.set_text(1, "%s (%s)" % [system_data.get("name", ""), system_data.get("class", "")])
		item.set_text(2, str(system_data.get("priority", 0)))
	_is_updating_systems = false

func _on_event_filter_changed(_new_text: String) -> void:
	_refresh_events()

func _on_copy_events_pressed() -> void:
	if _data_source == null:
		return
	var history: Array = _data_source.get_event_history()
	var filter_text := ""
	if _event_filter != null:
		filter_text = _event_filter.text.strip_edges()
	var filtered: Array = []
	for event_data in history:
		var event_name := String(event_data.get("name", ""))
		if filter_text != "" and event_name.findn(filter_text) == -1:
			continue
		filtered.append(event_data)
	var json: String = _data_source.serialize_event_history(filtered)
	DisplayServer.clipboard_set(json)
	if _editor_interface != null:
		_editor_interface.show_toast("ECS Debugger: Event history copied.")

func _on_system_item_edited() -> void:
	if _is_updating_systems:
		return
	var edited_item := _systems_tree.get_edited()
	if edited_item == null:
		return
	var column := _systems_tree.get_edited_column()
	if column != 0:
		return
	var instance_id: int = int(edited_item.get_metadata(0))
	var should_enable := edited_item.is_checked(0)
	var manager := _locate_manager()
	if manager == null:
		return
	toggle_system_by_instance(manager, instance_id, should_enable)

func _format_query(metric: Dictionary) -> String:
	var required: Array = []
	for type_name in metric.get("required", []):
		required.append(String(type_name))
	var optional: Array = []
	for type_name in metric.get("optional", []):
		optional.append(String(type_name))
	var label := "Required: %s" % ", ".join(required)
	if not optional.is_empty():
		label += " | Optional: %s" % ", ".join(optional)
	return label

func _format_events_text(events: Array) -> String:
	if events.is_empty():
		return ""
	var lines: Array = []
	for event_data in events:
		var name := String(event_data.get("name", ""))
		var timestamp := float(event_data.get("timestamp", 0.0))
		var payload_json := JSON.stringify(event_data.get("payload", {}))
		lines.append("%s @ %.3f -> %s" % [name, timestamp, payload_json])
	return "\n".join(lines)
