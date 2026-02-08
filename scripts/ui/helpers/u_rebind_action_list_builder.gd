extends RefCounted
class_name U_RebindActionListBuilder

const I_REBIND_OVERLAY := preload("res://scripts/interfaces/i_rebind_overlay.gd")

const REPLACE_BUTTON_TEXT := "Replace"
const ADD_BUTTON_TEXT := "Add Binding"
const RESET_BUTTON_TEXT := "Reset"
const ROW_SPACING := 8
const CATEGORY_SPACING := 16

# Action categories for grouping
const ACTION_CATEGORIES := {
	"movement": ["move_left", "move_right", "move_forward", "move_backward", "jump", "crouch", "sprint", "test_jump"],
	"combat": ["attack", "defend", "special_attack"],
	"ui": ["interact", "menu", "inventory", "ui_up", "ui_down", "ui_left", "ui_right"],
	"camera": ["camera_up", "camera_down", "camera_left", "camera_right", "zoom_in", "zoom_out"]
}

# Actions to exclude from the overlay (built-in Godot actions users shouldn't rebind)
const EXCLUDED_ACTIONS := [
	# Built-in UI navigation
	"ui_accept", "ui_select", "ui_cancel", "ui_focus_next", "ui_focus_prev",
	"ui_page_up", "ui_page_down", "ui_home", "ui_end",
	# Text editing
	"ui_text_completion_query", "ui_text_completion_accept", "ui_text_completion_replace",
	"ui_text_newline", "ui_text_newline_blank", "ui_text_newline_above",
	"ui_text_indent", "ui_text_dedent", "ui_text_backspace", "ui_text_backspace_word",
	"ui_text_backspace_word.macos", "ui_text_backspace_all_to_left", "ui_text_backspace_all_to_left.macos",
	"ui_text_delete", "ui_text_delete_word", "ui_text_delete_word.macos",
	"ui_text_delete_all_to_right", "ui_text_delete_all_to_right.macos",
	"ui_text_caret_left", "ui_text_caret_word_left", "ui_text_caret_word_left.macos",
	"ui_text_caret_right", "ui_text_caret_word_right", "ui_text_caret_word_right.macos",
	"ui_text_caret_up", "ui_text_caret_down",
	"ui_text_caret_line_start", "ui_text_caret_line_start.macos",
	"ui_text_caret_line_end", "ui_text_caret_line_end.macos",
	"ui_text_caret_page_up", "ui_text_caret_page_down",
	"ui_text_caret_document_start", "ui_text_caret_document_start.macos",
	"ui_text_caret_document_end", "ui_text_caret_document_end.macos",
	"ui_text_caret_add_below", "ui_text_caret_add_below.macos",
	"ui_text_caret_add_above", "ui_text_caret_add_above.macos",
	"ui_text_scroll_up", "ui_text_scroll_up.macos",
	"ui_text_scroll_down", "ui_text_scroll_down.macos",
	"ui_text_select_all", "ui_text_select_word_under_caret", "ui_text_select_word_under_caret.macos",
	"ui_text_add_selection_for_next_occurrence", "ui_text_skip_selection_for_next_occurrence",
	"ui_text_clear_carets_and_selection", "ui_text_toggle_insert_mode",
	"ui_menu", "ui_text_submit",
	# Copy/paste/undo
	"ui_cut", "ui_copy", "ui_paste", "ui_undo", "ui_redo",
	# Accessibility and other built-ins
	"ui_accessibility_drag_and_drop", "ui_focus_mode", "ui_unicode_start",
	"ui_graph_duplicate", "ui_graph_delete", "ui_graph_follow_left", "ui_graph_follow_left.macos",
	"ui_graph_follow_right", "ui_graph_follow_right.macos",
	"ui_filedialog_up_one_level", "ui_filedialog_refresh", "ui_filedialog_show_hidden",
	"ui_swap_input_direction", "ui_colorpicker_delete_preset",
	# Game-specific excluded actions
	"pause",
	# Editor-specific
	"editor", "editor_forward", "editor_backward"
]

static func build_action_rows(
	overlay: Node,
	action_list: VBoxContainer,
	action_rows: Dictionary,
	focusable_actions: Array[StringName],
	search_filter: String
) -> void:
	if action_list == null:
		return

	var typed_overlay := overlay as I_REBIND_OVERLAY
	if typed_overlay == null:
		push_error("U_RebindActionListBuilder: overlay must be I_RebindOverlay")
		return

	for child in action_list.get_children():
		child.queue_free()
	action_rows.clear()
	focusable_actions.clear()

	var actions := _collect_actions(overlay)
	var categorized_actions := _categorize_actions(actions)

	for category in categorized_actions.keys():
		var category_actions: Array = categorized_actions[category]
		if category_actions.is_empty():
			continue

		var category_header := Label.new()
		category_header.text = category.capitalize()
		category_header.add_theme_font_size_override("font_size", 16)
		category_header.modulate = Color(0.8, 0.8, 1.0, 1.0)
		action_list.add_child(category_header)

		_add_spacer(action_list, CATEGORY_SPACING / 2)

		for action in category_actions:
			if not _matches_search_filter(action, search_filter):
				continue

			focusable_actions.append(action)

			var row := VBoxContainer.new()
			row.name = String(action)
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.focus_mode = Control.FOCUS_ALL

			var label_row := HBoxContainer.new()
			label_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

			var name_label := Label.new()
			name_label.text = format_action_name(action)
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_label.add_theme_font_size_override("font_size", 14)

			var bindings_container := HBoxContainer.new()
			bindings_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bindings_container.alignment = BoxContainer.ALIGNMENT_END
			bindings_container.add_theme_constant_override("separation", 8)

			label_row.add_child(name_label)
			label_row.add_child(bindings_container)

			var button_row := HBoxContainer.new()
			button_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

			var add_button := Button.new()
			add_button.text = ADD_BUTTON_TEXT
			add_button.custom_minimum_size = Vector2(100, 32)
			add_button.tooltip_text = "Add an additional binding for this action"
			add_button.pressed.connect(func() -> void:
				U_UISoundPlayer.play_confirm()
				typed_overlay.begin_capture(action, U_InputActions.REBIND_MODE_ADD)
			)
			button_row.add_child(add_button)

			var replace_button := Button.new()
			replace_button.text = REPLACE_BUTTON_TEXT
			replace_button.custom_minimum_size = Vector2(80, 32)
			replace_button.tooltip_text = "Replace all bindings for this action"
			replace_button.pressed.connect(func() -> void:
				U_UISoundPlayer.play_confirm()
				typed_overlay.begin_capture(action, U_InputActions.REBIND_MODE_REPLACE)
			)
			button_row.add_child(replace_button)

			var reset_button := Button.new()
			reset_button.text = RESET_BUTTON_TEXT
			reset_button.custom_minimum_size = Vector2(60, 32)
			reset_button.tooltip_text = "Reset this action to default binding"
			reset_button.pressed.connect(func() -> void:
				U_UISoundPlayer.play_confirm()
				typed_overlay.reset_single_action(action)
			)
			button_row.add_child(reset_button)

			row.add_child(label_row)
			row.add_child(button_row)

			var separator := HSeparator.new()
			separator.modulate = Color(0.3, 0.3, 0.3, 0.5)
			row.add_child(separator)

			action_list.add_child(row)

			action_rows[action] = {
				"container": row,
				"name_label": name_label,
				"binding_container": bindings_container,
				"add_button": add_button,
				"replace_button": replace_button,
				"reset_button": reset_button,
				"category_header": category_header
			}

			typed_overlay.connect_row_focus_handlers(row, add_button, replace_button, reset_button)

			if typed_overlay.is_reserved(action):
				add_button.disabled = true
				replace_button.disabled = true
				reset_button.disabled = true
				add_button.text = "Reserved"
				replace_button.text = "Reserved"
				reset_button.text = "Reserved"

			_add_spacer(action_list, ROW_SPACING)

	typed_overlay.refresh_bindings()
	typed_overlay.set_reset_button_enabled(overlay._profile_manager != null and not overlay._is_capturing)
	typed_overlay.configure_focus_neighbors()

	if not focusable_actions.is_empty():
		overlay._focused_action_index = 0
		overlay._is_on_bottom_row = false
		overlay._row_button_index = 0
		typed_overlay.apply_focus()
	else:
		overlay._focused_action_index = -1
		overlay._is_on_bottom_row = false

static func refresh_bindings(overlay: Node, action_rows: Dictionary) -> void:
	if overlay == null:
		return

	var typed_overlay := overlay as I_REBIND_OVERLAY
	if typed_overlay == null:
		return

	var device_category: String = typed_overlay.get_active_device_category()
	var device_type_for_registry: int = M_InputDeviceManager.DeviceType.KEYBOARD_MOUSE
	if device_category == "gamepad":
		device_type_for_registry = M_InputDeviceManager.DeviceType.GAMEPAD

	for action in action_rows.keys():
		var data: Dictionary = action_rows[action]
		var binding_container: HBoxContainer = data.get("binding_container")
		var name_label: Label = data.get("name_label")
		if binding_container == null:
			continue

		for child in binding_container.get_children():
			child.queue_free()

		var events := InputMap.action_get_events(action)
		var filtered_events: Array[InputEvent] = []
		for event in events:
			if event is InputEvent:
				var device_type: String = get_event_device_type(event as InputEvent)
				if device_category == "gamepad":
					if device_type == "gamepad":
						filtered_events.append(event)
				else:
					if device_type == "keyboard" or device_type == "mouse" or device_type == "unknown":
						filtered_events.append(event)

		var display_events: Array = filtered_events
		if display_events.is_empty():
			display_events = events

		if display_events.is_empty():
			var unbound_label := Label.new()
			unbound_label.text = "Unbound"
			unbound_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
			binding_container.add_child(unbound_label)
		else:
			_populate_binding_visuals(binding_container, action, display_events, device_type_for_registry)

		var is_custom: bool = typed_overlay.is_binding_custom(action)
		if is_custom and name_label != null:
			name_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4, 1.0))
			binding_container.modulate = Color(1.0, 0.8, 0.4, 1.0)
		elif name_label != null:
			name_label.remove_theme_color_override("font_color")
			binding_container.modulate = Color(1.0, 1.0, 1.0, 1.0)

		var add_button: Button = data.get("add_button")
		var replace_button: Button = data.get("replace_button")
		var reset_button: Button = data.get("reset_button")
		var reserved: bool = typed_overlay.is_reserved(action)

		if add_button != null:
			if reserved:
				add_button.disabled = true
				add_button.text = "Reserved"
			else:
				if overlay._is_capturing:
					if action == overlay._pending_action and overlay._capture_mode == U_InputActions.REBIND_MODE_ADD:
						add_button.text = "Listening..."
					else:
						add_button.text = ADD_BUTTON_TEXT
					add_button.disabled = true
				else:
					add_button.disabled = false
					add_button.text = ADD_BUTTON_TEXT

		if replace_button != null:
			if reserved:
				replace_button.disabled = true
				replace_button.text = "Reserved"
			else:
				if overlay._is_capturing:
					if action == overlay._pending_action and overlay._capture_mode == U_InputActions.REBIND_MODE_REPLACE:
						replace_button.text = "Listening..."
					else:
						replace_button.text = REPLACE_BUTTON_TEXT
					replace_button.disabled = true
				else:
					replace_button.disabled = false
					replace_button.text = REPLACE_BUTTON_TEXT

		if reset_button != null:
			if reserved:
				reset_button.disabled = true
			else:
				reset_button.disabled = overlay._is_capturing

	if not overlay._is_capturing:
		typed_overlay.set_reset_button_enabled(overlay._profile_manager != null)

static func format_action_name(action: StringName) -> String:
	var text := String(action)
	text = text.replace("_", " ")
	if text.is_empty():
		return ""
	var words := text.split(" ", false)
	for i in range(words.size()):
		var word := words[i]
		if word.is_empty():
			continue
		if word.to_lower() == "ui":
			words[i] = "UI"
		else:
			words[i] = word.left(1).to_upper() + word.substr(1).to_lower()
	return " ".join(words)

static func get_event_device_type(event: InputEvent) -> String:
	if event is InputEventKey:
		return "keyboard"
	elif event is InputEventMouseButton or event is InputEventMouseMotion:
		return "mouse"
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return "gamepad"
	else:
		return "unknown"

static func _collect_actions(overlay: Node) -> Array[StringName]:
	var actions: Array[StringName] = []
	var seen: Dictionary = {}

	for action_name in InputMap.get_actions():
		var action := StringName(action_name)
		if String(action) in EXCLUDED_ACTIONS:
			continue
		if not seen.has(action):
			actions.append(action)
			seen[action] = true

	var typed_overlay := overlay as I_REBIND_OVERLAY
	var profile: Object = null
	if typed_overlay != null:
		profile = typed_overlay.get_active_profile()

	if profile != null and "action_mappings" in profile:
		for key in profile.action_mappings.keys():
			var action := StringName(key)
			if String(action) in EXCLUDED_ACTIONS:
				continue
			if not seen.has(action):
				actions.append(action)
				seen[action] = true

	actions.sort_custom(func(a: StringName, b: StringName) -> bool:
		var str_a := String(a)
		var str_b := String(b)
		var lower_a := str_a.to_lower()
		var lower_b := str_b.to_lower()
		if lower_a == lower_b:
			return str_a < str_b
		return lower_a < lower_b
	)
	return actions

static func _categorize_actions(actions: Array[StringName]) -> Dictionary:
	var categorized: Dictionary = {}
	var uncategorized: Array[StringName] = []

	for category in ACTION_CATEGORIES.keys():
		categorized[category] = []

	for action in actions:
		var found := false
		for category in ACTION_CATEGORIES.keys():
			if action in ACTION_CATEGORIES[category]:
				(categorized[category] as Array).append(action)
				found = true
				break
		if not found:
			uncategorized.append(action)

	return categorized

static func _matches_search_filter(action: StringName, search_filter: String) -> bool:
	if search_filter.is_empty():
		return true
	var action_name := format_action_name(action).to_lower()
	return action_name.contains(search_filter.to_lower())

static func _add_spacer(action_list: VBoxContainer, height: int) -> void:
	if action_list == null:
		return
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	action_list.add_child(spacer)

static func _populate_binding_visuals(
	container: HBoxContainer,
	action: StringName,
	events: Array,
	device_type: int
) -> void:
	if container == null:
		return

	for i in range(events.size()):
		var event: InputEvent = events[i]
		if event == null:
			continue

		var texture: Texture2D = U_InputRebindUtils.get_texture_for_event(event)

		if texture != null:
			var texture_rect := TextureRect.new()
			texture_rect.texture = texture
			texture_rect.custom_minimum_size = Vector2(24, 24)
			texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			container.add_child(texture_rect)
		else:
			var event_label := Label.new()
			event_label.text = U_InputRebindUtils.format_event_label(event)
			event_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
			container.add_child(event_label)

		if i < events.size() - 1:
			var separator := Label.new()
			separator.text = ", "
			separator.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1.0))
			container.add_child(separator)
