## ECS Overlay for Debug Manager
##
## Provides entity browsing, component inspection, and system execution view.
## Toggled via F2 key through M_DebugManager.
class_name SC_DebugECSOverlay
extends CanvasLayer


## UI References - Left Panel (Entity Browser)
@onready var _tag_filter_edit: LineEdit = %TagFilterEdit
@onready var _component_filter_option: OptionButton = %ComponentFilterOption
@onready var _clear_filter_button: Button = %ClearFilterButton
@onready var _entity_list: ItemList = %EntityList
@onready var _prev_page_button: Button = %PrevPageButton
@onready var _page_label: Label = %PageLabel
@onready var _next_page_button: Button = %NextPageButton

## UI References - Center Panel (Component Inspector)
@onready var _selected_entity_label: Label = %SelectedEntityLabel
@onready var _component_details_container: VBoxContainer = %ComponentDetailsContainer

## UI References - Right Panel (System View)
@onready var _system_list: ItemList = %SystemList
@onready var _selected_system_label: Label = %SelectedSystemLabel
@onready var _system_enabled_checkbox: CheckBox = %SystemEnabledCheckbox

## UI References - Header
@onready var _close_button: Button = %CloseButton

## Constants
const ENTITIES_PER_PAGE := 50

## State
var _ecs_manager: M_ECSManager = null
var _selected_entity_id: StringName = StringName()
var _selected_system: BaseECSSystem = null
var _all_entity_ids: Array[StringName] = []
var _filtered_entity_ids: Array[StringName] = []
var _current_page := 0
var _total_pages := 1

## Debouncing for entity list rebuild
var _list_dirty := false
var _rebuild_timer := 0.0
const REBUILD_DEBOUNCE := 0.1  # 100ms

## Component inspector update throttling
var _inspector_update_timer := 0.0
const INSPECTOR_UPDATE_INTERVAL := 0.1  # 100ms

## Active filter state
var _active_tag_filter: String = ""
var _active_component_filter: StringName = StringName()

## Resource expansion state (persists across inspector updates)
## Key: "component_type:property_name", Value: bool (expanded or not)
var _expanded_resources: Dictionary = {}


func _ready() -> void:
	# Get ECS manager from current scene (scene-specific, not in ServiceLocator)
	_ecs_manager = get_tree().get_first_node_in_group("ecs_manager") as M_ECSManager

	# Subscribe to entity registration events for live updates
	if is_instance_valid(_ecs_manager):
		U_ECSEventBus.subscribe(StringName("entity_registered"), _on_entity_registered)
		U_ECSEventBus.subscribe(StringName("entity_unregistered"), _on_entity_unregistered)

	# Initialize component filter dropdown
	_populate_component_filter()

	# Populate system list
	_populate_system_list()

	# Initial population
	_mark_list_dirty()


func _exit_tree() -> void:
	# Clean up event subscriptions (only if we subscribed)
	if is_instance_valid(_ecs_manager):
		U_ECSEventBus.unsubscribe(StringName("entity_registered"), _on_entity_registered)
		U_ECSEventBus.unsubscribe(StringName("entity_unregistered"), _on_entity_unregistered)


func _process(delta: float) -> void:
	# Debounced entity list rebuild
	if _list_dirty:
		_rebuild_timer += delta
		if _rebuild_timer >= REBUILD_DEBOUNCE:
			_rebuild_entity_list()
			_list_dirty = false
			_rebuild_timer = 0.0

	# Throttled component inspector update
	if _selected_entity_id != StringName():
		_inspector_update_timer += delta
		if _inspector_update_timer >= INSPECTOR_UPDATE_INTERVAL:
			_update_component_inspector()
			_inspector_update_timer = 0.0


## Mark entity list as needing rebuild (debounced)
func _mark_list_dirty() -> void:
	_list_dirty = true
	_rebuild_timer = 0.0


## Populate component filter dropdown with all component types
func _populate_component_filter() -> void:
	_component_filter_option.clear()
	_component_filter_option.add_item("(All Components)", 0)

	if not is_instance_valid(_ecs_manager):
		return

	# Get all unique component types from all registered entities
	var component_types: Array[StringName] = []
	var entity_ids := _ecs_manager.get_all_entity_ids()

	for entity_id in entity_ids:
		var entity := _ecs_manager.get_entity_by_id(entity_id)
		if not is_instance_valid(entity):
			continue

		var components_dict := _ecs_manager.get_components_for_entity(entity)
		for comp_type in components_dict.keys():
			if comp_type != StringName() and not component_types.has(comp_type):
				component_types.append(comp_type)

	# Sort and add to dropdown
	component_types.sort()
	for i in range(component_types.size()):
		_component_filter_option.add_item(String(component_types[i]), i + 1)


## Rebuild entity list with current filters and pagination
func _rebuild_entity_list() -> void:
	if not is_instance_valid(_ecs_manager):
		_all_entity_ids = []
		_filtered_entity_ids = []
		_entity_list.clear()
		_page_label.text = "No ECS Manager"
		return

	# Get all entity IDs
	_all_entity_ids = _ecs_manager.get_all_entity_ids()

	# Apply filters
	_filtered_entity_ids = _apply_filters(_all_entity_ids)

	# Calculate pagination
	_total_pages = ceili(float(_filtered_entity_ids.size()) / float(ENTITIES_PER_PAGE))
	if _total_pages == 0:
		_total_pages = 1

	# Clamp current page
	_current_page = clampi(_current_page, 0, _total_pages - 1)

	# Populate current page
	_populate_current_page()

	# Update pagination controls
	_update_pagination_controls()


## Apply active filters to entity list
func _apply_filters(entity_ids: Array[StringName]) -> Array[StringName]:
	var result: Array[StringName] = []

	for entity_id in entity_ids:
		var entity := _ecs_manager.get_entity_by_id(entity_id)
		if not is_instance_valid(entity):
			continue

		# Tag filter
		if _active_tag_filter != "":
			if not entity.has_tag(StringName(_active_tag_filter)):
				continue

		# Component filter
		if _active_component_filter != StringName():
			var components_dict := _ecs_manager.get_components_for_entity(entity)
			# Dictionary maps StringName -> Component (direct instance)
			if not components_dict.has(_active_component_filter):
				continue

		result.append(entity_id)

	return result


## Populate current page of entity list
func _populate_current_page() -> void:
	_entity_list.clear()

	var start_idx := _current_page * ENTITIES_PER_PAGE
	var end_idx := mini(start_idx + ENTITIES_PER_PAGE, _filtered_entity_ids.size())

	for i in range(start_idx, end_idx):
		var entity_id := _filtered_entity_ids[i]
		_entity_list.add_item(String(entity_id))


## Update pagination controls
func _update_pagination_controls() -> void:
	_page_label.text = "Page %d of %d" % [_current_page + 1, _total_pages]
	_prev_page_button.disabled = (_current_page == 0)
	_next_page_button.disabled = (_current_page >= _total_pages - 1)


## Update component inspector for selected entity
func _update_component_inspector() -> void:
	if _selected_entity_id == StringName() or not is_instance_valid(_ecs_manager):
		return

	# Get entity from ID
	var entity := _ecs_manager.get_entity_by_id(_selected_entity_id)
	if not is_instance_valid(entity):
		# Show error in UI
		for child in _component_details_container.get_children():
			child.queue_free()
		var error_label := Label.new()
		error_label.text = "Entity not found: %s" % String(_selected_entity_id)
		_component_details_container.add_child(error_label)
		return

	# Clear existing details
	for child in _component_details_container.get_children():
		child.queue_free()

	# Get components for selected entity (returns Dictionary: StringName -> Component)
	var components_dict := _ecs_manager.get_components_for_entity(entity)

	if components_dict.is_empty():
		var no_components_label := Label.new()
		no_components_label.text = "No components found"
		_component_details_container.add_child(no_components_label)
		return

	# Display each component type
	# NOTE: Dictionary maps StringName -> Component (not Array!)
	for comp_type in components_dict.keys():
		var component = components_dict[comp_type]  # Direct component instance

		if not component is BaseECSComponent:
			continue

		# Component header
		var header := Label.new()
		header.text = String(component.component_type)
		header.add_theme_font_size_override("font_size", 16)
		_component_details_container.add_child(header)

		# Component properties (read-only display - exported only)
		var property_list: Array = component.get_property_list()
		for property in property_list:
			# Skip internal properties
			if property.name.begins_with("_"):
				continue

			# Only show user-exported properties (exclude Node built-ins)
			# PROPERTY_USAGE_EDITOR (4) means it shows in the editor inspector
			if (property.usage & PROPERTY_USAGE_EDITOR) == 0:
				continue

			# Filter out base Node properties and internal ECS properties
			if property.name in [
				"script", "Script Variables",
				"process_mode", "process_priority", "process_physics_priority",
				"process_thread_group", "physics_interpolation_mode",
				"auto_translate_mode", "editor_description",
				"component_type", "ecs_manager",
				"unique_name_in_owner", "scene_file_path", "owner",
				"multiplayer", "name", "transform", "position", "rotation",
				"scale", "quaternion", "basis", "global_transform",
				"global_position", "global_rotation", "top_level", "visibility_parent"
			]:
				continue

			var value = component.get(property.name)

			# If property is a Resource, make it expandable
			if value is Resource and property.name == "settings":
				# Generate unique key for this resource expansion state
				var resource_key: String = "%s:%s" % [comp_type, property.name]

				var container := VBoxContainer.new()
				_component_details_container.add_child(container)

				# Resource header with toggle button
				var header_box := HBoxContainer.new()
				container.add_child(header_box)

				var toggle_button := Button.new()
				toggle_button.toggle_mode = true
				toggle_button.custom_minimum_size = Vector2(30, 0)
				header_box.add_child(toggle_button)

				var resource_label := Label.new()
				resource_label.text = "%s: %s" % [property.name, value.get_class()]
				header_box.add_child(resource_label)

				# Resource properties container
				var resource_props := VBoxContainer.new()
				container.add_child(resource_props)

				# Restore expansion state from previous update (defaults to false)
				var is_expanded: bool = _expanded_resources.get(resource_key, false)
				resource_props.visible = is_expanded
				toggle_button.button_pressed = is_expanded
				toggle_button.text = "▼" if is_expanded else "▶"

				# Get resource properties
				var resource_property_list: Array = value.get_property_list()
				for res_prop in resource_property_list:
					if res_prop.name.begins_with("_"):
						continue
					if (res_prop.usage & PROPERTY_USAGE_EDITOR) == 0:
						continue
					if res_prop.name in ["script", "resource_path", "resource_name", "resource_scene_unique_id", "resource_local_to_scene"]:
						continue

					var res_value = value.get(res_prop.name)
					var res_prop_label := Label.new()
					res_prop_label.text = "    %s: %s" % [res_prop.name, str(res_value)]
					resource_props.add_child(res_prop_label)

				# Connect toggle - update state and UI
				toggle_button.toggled.connect(func(pressed: bool):
					_expanded_resources[resource_key] = pressed
					resource_props.visible = pressed
					toggle_button.text = "▼" if pressed else "▶"
				)
			else:
				# Regular property
				var prop_label := Label.new()
				prop_label.text = "  %s: %s" % [property.name, str(value)]
				_component_details_container.add_child(prop_label)

		# Separator
		var separator := HSeparator.new()
		_component_details_container.add_child(separator)


## Populate system list
func _populate_system_list() -> void:
	_system_list.clear()

	if not is_instance_valid(_ecs_manager):
		return

	var systems := _ecs_manager.get_systems()

	# Sort by priority (lower = earlier execution)
	systems.sort_custom(func(a, b): return a.execution_priority < b.execution_priority)

	for system in systems:
		if system is BaseECSSystem:
			# Get GDScript class name from script (get_class() returns engine class "Node")
			var system_name: String = system.name  # Node name (e.g., "S_InputSystem")
			var priority: int = system.execution_priority
			var enabled: bool = not system.is_debug_disabled()
			var status_icon: String = "✓" if enabled else "✗"
			_system_list.add_item("%s %s (Priority: %d)" % [status_icon, system_name, priority])


## Event Handlers

func _on_entity_registered(_entity: BaseECSEntity) -> void:
	_mark_list_dirty()


func _on_entity_unregistered(_entity_id: StringName) -> void:
	_mark_list_dirty()


func _on_tag_filter_edit_text_changed(new_text: String) -> void:
	_active_tag_filter = new_text.strip_edges()
	_current_page = 0  # Reset to first page
	_mark_list_dirty()


func _on_component_filter_option_item_selected(index: int) -> void:
	if index == 0:
		# "(All Components)" selected
		_active_component_filter = StringName()
	else:
		var selected_text := _component_filter_option.get_item_text(index)
		_active_component_filter = StringName(selected_text)

	_current_page = 0  # Reset to first page
	_mark_list_dirty()


func _on_clear_filter_button_pressed() -> void:
	_active_tag_filter = ""
	_active_component_filter = StringName()
	_tag_filter_edit.text = ""
	_component_filter_option.select(0)
	_current_page = 0
	_mark_list_dirty()


func _on_entity_list_item_selected(index: int) -> void:
	var start_idx := _current_page * ENTITIES_PER_PAGE
	var entity_index := start_idx + index

	if entity_index < 0 or entity_index >= _filtered_entity_ids.size():
		return

	_selected_entity_id = _filtered_entity_ids[entity_index]
	_selected_entity_label.text = "Entity: %s" % String(_selected_entity_id)

	# Clear resource expansion state when switching entities
	_expanded_resources.clear()

	# Immediately update inspector (don't wait for throttle)
	_update_component_inspector()
	_inspector_update_timer = 0.0


func _on_prev_page_button_pressed() -> void:
	if _current_page > 0:
		_current_page -= 1
		_populate_current_page()
		_update_pagination_controls()


func _on_next_page_button_pressed() -> void:
	if _current_page < _total_pages - 1:
		_current_page += 1
		_populate_current_page()
		_update_pagination_controls()


func _on_system_list_item_selected(index: int) -> void:
	if not is_instance_valid(_ecs_manager):
		return

	var systems := _ecs_manager.get_systems()
	systems.sort_custom(func(a, b): return a.execution_priority < b.execution_priority)

	if index < 0 or index >= systems.size():
		return

	_selected_system = systems[index] as BaseECSSystem

	if is_instance_valid(_selected_system):
		# Use node name instead of get_class() which returns "Node"
		_selected_system_label.text = _selected_system.name
		_system_enabled_checkbox.disabled = false
		_system_enabled_checkbox.button_pressed = not _selected_system.is_debug_disabled()
	else:
		_selected_system_label.text = "None"
		_system_enabled_checkbox.disabled = true


func _on_system_enabled_checkbox_toggled(toggled_on: bool) -> void:
	if is_instance_valid(_selected_system):
		_selected_system.set_debug_disabled(not toggled_on)
		# Refresh system list to show updated status
		_populate_system_list()


func _on_close_button_pressed() -> void:
	# Hide overlay (M_DebugManager handles visibility toggle)
	visible = false
