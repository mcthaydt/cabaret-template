extends RefCounted
class_name U_UIMenuBuilder

const U_FOCUS_CONFIGURATOR := preload("res://scripts/core/ui/helpers/u_focus_configurator.gd")
const U_LOCALIZATION_UTILS := preload("res://scripts/core/utils/localization/u_localization_utils.gd")
const U_UI_THEME_ROLE_UTILS := preload("res://scripts/core/ui/helpers/u_ui_theme_role_utils.gd")
const U_UI_THEME_BUILDER := preload("res://scripts/core/ui/utils/u_ui_theme_builder.gd")
const RS_UI_THEME_CONFIG := preload("res://scripts/core/resources/ui/rs_ui_theme_config.gd")

var _menu: Control = null
var _label_keys: Dictionary = {}
var _label_fallbacks: Dictionary = {}
var _theme_map: Array[Dictionary] = []
var _focusable_controls: Array[Control] = []
var _button_column: VBoxContainer = null
var _title_label: Label = null

func _init(menu: Control) -> void:
	_menu = menu

func set_title(key: StringName, fallback: String = "") -> U_UIMenuBuilder:
	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu.add_child(_title_label)
	_bind_label(_title_label, key, &"heading", fallback)
	return self

func bind_title(label: Label, key: StringName, fallback: String = "") -> U_UIMenuBuilder:
	_title_label = label
	if label != null:
		_bind_label(label, key, &"heading", fallback)
	return self

func bind_panel(panel: PanelContainer, padding: MarginContainer = null, content: VBoxContainer = null) -> U_UIMenuBuilder:
	if panel != null:
		_theme_map.append({"control": panel, "role": &"main_panel"})
	if padding != null:
		_theme_map.append({"control": padding, "role": &"panel_padding"})
	if content != null:
		_theme_map.append({"control": content, "role": &"content_vbox"})
	return self

func bind_background(color_rect: ColorRect) -> U_UIMenuBuilder:
	if color_rect != null:
		_theme_map.append({"control": color_rect, "role": &"background_color"})
	return self

func bind_theme_role(control: Control, role: StringName, extras: Dictionary = {}) -> U_UIMenuBuilder:
	if control == null:
		return self
	var entry: Dictionary = {"control": control, "role": role}
	for key in extras.keys():
		entry[key] = extras[key]
	_theme_map.append(entry)
	return self

func add_button(key: StringName, callback: Callable, fallback: String = "") -> U_UIMenuBuilder:
	var button := Button.new()
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button_container().add_child(button)
	_label_keys[button] = key
	if fallback != "":
		_label_fallbacks[button] = fallback
	_theme_map.append({"control": button, "role": &"button"})
	_focusable_controls.append(button)
	_connect(button.pressed, callback)
	return self

func bind_button(button: Button, key: StringName, callback: Callable = Callable(), fallback: String = "") -> U_UIMenuBuilder:
	if button == null:
		return self
	_label_keys[button] = key
	if fallback != "":
		_label_fallbacks[button] = fallback
	_theme_map.append({"control": button, "role": &"button"})
	_focusable_controls.append(button)
	_connect(button.pressed, callback)
	return self

func add_button_group(buttons: Array) -> U_UIMenuBuilder:
	for entry in buttons:
		var key := entry.get("key", &"") as StringName
		var callback := entry.get("callback", Callable()) as Callable
		var fallback := entry.get("fallback", "") as String
		add_button(key, callback, fallback)
	return self

func bind_button_group(buttons: Array) -> U_UIMenuBuilder:
	for entry in buttons:
		var button := entry.get("button", null) as Button
		var key := entry.get("key", &"") as StringName
		var callback := entry.get("callback", Callable()) as Callable
		var fallback := entry.get("fallback", "") as String
		bind_button(button, key, callback, fallback)
	return self

func set_back_button(key: StringName, callback: Callable, fallback: String = "") -> U_UIMenuBuilder:
	var button := Button.new()
	button.name = "BackButton"
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu.add_child(button)
	_label_keys[button] = key
	if fallback != "":
		_label_fallbacks[button] = fallback
	_theme_map.append({"control": button, "role": &"button"})
	_focusable_controls.append(button)
	_connect(button.pressed, callback)
	return self

func set_background_dim(color: Color) -> U_UIMenuBuilder:
	var bg_image := _menu.get_node_or_null("BackgroundImage") as TextureRect
	if bg_image != null:
		var overlay := ColorRect.new()
		overlay.name = "OverlayBackground"
		overlay.color = color
		overlay.anchor_right = 1.0
		overlay.anchor_bottom = 1.0
		var bg_index: int = bg_image.get_index()
		_menu.add_child(overlay)
		_menu.move_child(overlay, bg_index)
		_theme_map.append({"control": overlay, "role": &"background"})
		return self
	var bg := _menu.get_node_or_null("Background") as ColorRect
	if bg == null:
		bg = ColorRect.new()
		bg.name = "Background"
		bg.anchor_right = 1.0
		bg.anchor_bottom = 1.0
		_menu.add_child(bg)
		_menu.move_child(bg, 0)
	bg.color = color
	_theme_map.append({"control": bg, "role": &"background"})
	return self

func build() -> Control:
	apply_theme_tokens(U_UI_THEME_BUILDER.active_config)
	localize_labels()
	if not _focusable_controls.is_empty():
		U_FOCUS_CONFIGURATOR.configure_vertical_focus(_focusable_controls, true)
	return _menu

func localize_labels() -> void:
	for control in _label_keys.keys():
		var fallback: String = _label_fallbacks.get(control, str(_label_keys[control]))
		if control is Label:
			(control as Label).text = _localize(_label_keys[control], fallback)
		elif control is Button:
			(control as Button).text = _localize(_label_keys[control], fallback)

func apply_theme_tokens(config: Resource) -> void:
	if not (config is RS_UI_THEME_CONFIG):
		return
	var theme_config := config as RS_UI_THEME_CONFIG
	for entry in _theme_map:
		_apply_theme_entry(entry, theme_config)

func _button_container() -> VBoxContainer:
	if _button_column != null:
		return _button_column
	_button_column = VBoxContainer.new()
	_button_column.name = "MenuButtons"
	_menu.add_child(_button_column)
	_theme_map.append({"control": _button_column, "role": &"button_column"})
	return _button_column

func _bind_label(label: Label, key: StringName, role: StringName, fallback: String = "") -> void:
	_label_keys[label] = key
	if fallback != "":
		_label_fallbacks[label] = fallback
	_theme_map.append({"control": label, "role": role})

func _connect(signal_ref: Signal, callback: Callable) -> void:
	if callback.is_valid() and not signal_ref.is_connected(callback):
		signal_ref.connect(callback)

func _localize(key: Variant, fallback: String) -> String:
	if key is StringName:
		return U_LOCALIZATION_UTILS.localize_with_fallback(key, fallback)
	return fallback

func _apply_theme_entry(entry: Dictionary, config: RS_UI_THEME_CONFIG) -> void:
	var control := entry.get("control") as Control
	if control == null:
		return
	U_UI_THEME_ROLE_UTILS.apply_menu_role(entry, control, config, _menu)
