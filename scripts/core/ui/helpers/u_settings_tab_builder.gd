extends RefCounted
class_name U_SettingsTabBuilder

const U_FOCUS_CONFIGURATOR := preload("res://scripts/core/ui/helpers/u_focus_configurator.gd")
const U_LOCALIZATION_UTILS := preload("res://scripts/core/utils/localization/u_localization_utils.gd")
const U_UI_THEME_BUILDER := preload("res://scripts/core/ui/utils/u_ui_theme_builder.gd")
const RS_UI_THEME_CONFIG := preload("res://scripts/core/resources/ui/rs_ui_theme_config.gd")

var _tab: Control = null
var _current_parent: Control = null
var _label_keys: Dictionary = {}
var _theme_map: Array[Dictionary] = []
var _focusable_controls: Array[Control] = []

func _init(tab: Control) -> void:
	_tab = tab
	_current_parent = tab

func set_heading(key: StringName) -> U_SettingsTabBuilder:
	var label := _add_label(key, _tab)
	label.name = "HeadingLabel"
	_theme_map.append({"control": label, "role": &"heading"})
	return self

func bind_heading(label: Label, key: StringName) -> U_SettingsTabBuilder:
	_bind_label(label, key, &"heading")
	return self

func bind_section_header(label: Label, key: StringName) -> U_SettingsTabBuilder:
	_bind_label(label, key, &"section_header")
	return self

func bind_field_label(label: Label, key: StringName) -> U_SettingsTabBuilder:
	_bind_label(label, key, &"field_label")
	return self

func bind_value_label(label: Label, key: StringName = &"") -> U_SettingsTabBuilder:
	_bind_label(label, key, &"value_label")
	return self

func bind_row(row: Control, compact: bool = false) -> U_SettingsTabBuilder:
	if row != null:
		_theme_map.append({"control": row, "role": &"compact_row" if compact else &"default_row"})
	return self

func bind_field_control(control: Control, callback: Callable = Callable()) -> U_SettingsTabBuilder:
	if control == null:
		return self
	_theme_map.append({"control": control, "role": &"field_control"})
	_focusable_controls.append(control)
	_wire_control_callback(control, callback)
	return self

func bind_action_button(button: Button, key: StringName, callback: Callable = Callable()) -> U_SettingsTabBuilder:
	if button == null:
		return self
	_label_keys[button] = key
	_theme_map.append({"control": button, "role": &"action"})
	_focusable_controls.append(button)
	_connect(button.pressed, callback)
	return self

func begin_section(key: StringName) -> U_SettingsTabBuilder:
	var section := VBoxContainer.new()
	section.name = "Section"
	_tab.add_child(section)
	_current_parent = section
	var label := _add_label(key, section)
	label.name = "SectionHeader"
	_theme_map.append({"control": label, "role": &"section_header"})
	return self

func end_section() -> U_SettingsTabBuilder:
	_current_parent = _tab
	return self

func add_dropdown(key: StringName, options: Array[Dictionary], callback: Callable) -> U_SettingsTabBuilder:
	var row := _add_row()
	var label := _add_label(key, row)
	var dropdown := OptionButton.new()
	row.add_child(dropdown)
	for option in options:
		dropdown.add_item(_localize(option.get("label_key", key), str(option.get("id", ""))))
	_connect(dropdown.item_selected, callback)
	_register_field(label, dropdown)
	return self

func add_toggle(key: StringName, callback: Callable) -> U_SettingsTabBuilder:
	var row := _add_row()
	var label := _add_label(key, row)
	var toggle := CheckBox.new()
	row.add_child(toggle)
	_connect(toggle.toggled, callback)
	_register_field(label, toggle)
	return self

func add_slider(
	key: StringName,
	min_val: float,
	max_val: float,
	step: float,
	callback: Callable,
	value_label_key: StringName = &""
) -> U_SettingsTabBuilder:
	var row := _add_row()
	var label := _add_label(key, row)
	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = step
	row.add_child(slider)
	var value_label := _add_label(value_label_key, row)
	_connect(slider.value_changed, callback)
	_register_field(label, slider)
	_theme_map.append({"control": value_label, "role": &"value_label"})
	return self

func add_action_buttons(
	apply_callback: Callable,
	cancel_callback: Callable,
	reset_callback: Callable
) -> U_SettingsTabBuilder:
	var row := HBoxContainer.new()
	row.name = "ActionButtons"
	_current_parent.add_child(row)
	_theme_map.append({"control": row, "role": &"compact_row"})
	_add_button(row, &"common.apply", apply_callback)
	_add_button(row, &"common.cancel", cancel_callback)
	_add_button(row, &"common.reset", reset_callback)
	return self

func build() -> Control:
	apply_theme_tokens(U_UI_THEME_BUILDER.active_config)
	localize_labels()
	if not _focusable_controls.is_empty():
		U_FOCUS_CONFIGURATOR.configure_vertical_focus(_focusable_controls, true)
	return _tab

func localize_labels() -> void:
	for control in _label_keys.keys():
		if control is Label:
			(control as Label).text = _localize(_label_keys[control], str(_label_keys[control]))
		elif control is Button:
			(control as Button).text = _localize(_label_keys[control], str(_label_keys[control]))

func apply_theme_tokens(config: Resource) -> void:
	if not (config is RS_UI_THEME_CONFIG):
		return
	var theme_config := config as RS_UI_THEME_CONFIG
	for entry in _theme_map:
		_apply_theme_entry(entry, theme_config)

func _add_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "SettingRow"
	_current_parent.add_child(row)
	_theme_map.append({"control": row, "role": &"default_row"})
	return row

func _add_label(key: StringName, parent: Control) -> Label:
	var label := Label.new()
	label.text = _localize(key, str(key))
	parent.add_child(label)
	_label_keys[label] = key
	return label

func _add_button(parent: Control, key: StringName, callback: Callable) -> Button:
	var button := Button.new()
	button.text = _localize(key, str(key))
	parent.add_child(button)
	_label_keys[button] = key
	_theme_map.append({"control": button, "role": &"action"})
	_focusable_controls.append(button)
	_connect(button.pressed, callback)
	return button

func _register_field(label: Label, control: Control) -> void:
	_theme_map.append({"control": label, "role": &"field_label"})
	_theme_map.append({"control": control, "role": &"field_control"})
	_focusable_controls.append(control)

func _bind_label(label: Label, key: StringName, role: StringName) -> void:
	if label == null:
		return
	_label_keys[label] = key
	_theme_map.append({"control": label, "role": role})

func _wire_control_callback(control: Control, callback: Callable) -> void:
	if callback == Callable():
		return
	if control is OptionButton:
		_connect((control as OptionButton).item_selected, callback)
	elif control is BaseButton:
		_connect((control as BaseButton).toggled, callback)
	elif control is Range:
		_connect((control as Range).value_changed, callback)

func _connect(signal_ref: Signal, callback: Callable) -> void:
	if callback.is_valid() and not signal_ref.is_connected(callback):
		signal_ref.connect(callback)

func _localize(key: Variant, fallback: String) -> String:
	if key is StringName:
		var localized := U_LOCALIZATION_UTILS.localize(key)
		return fallback if localized.is_empty() else localized
	return fallback

func _apply_theme_entry(entry: Dictionary, config: RS_UI_THEME_CONFIG) -> void:
	var control := entry.get("control") as Control
	if control == null:
		return
	match entry.get("role", &""):
		&"heading":
			control.add_theme_font_size_override(&"font_size", config.heading)
		&"section_header":
			control.add_theme_font_size_override(&"font_size", config.section_header)
			control.add_theme_color_override(&"font_color", config.section_header_color)
		&"field_label":
			control.add_theme_font_size_override(&"font_size", config.body_small)
			control.add_theme_color_override(&"font_color", config.text_secondary)
		&"field_control", &"action":
			control.add_theme_font_size_override(&"font_size", config.section_header)
		&"value_label":
			control.add_theme_font_size_override(&"font_size", config.body_small)
			control.add_theme_color_override(&"font_color", config.text_secondary)
		&"default_row":
			control.add_theme_constant_override(&"separation", config.separation_default)
		&"compact_row":
			control.add_theme_constant_override(&"separation", config.separation_compact)
