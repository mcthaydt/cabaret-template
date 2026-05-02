@icon("res://assets/core/editor_icons/icn_utility.svg")
extends "res://scripts/core/ui/base/base_overlay.gd"
class_name BaseSettingsSimpleOverlay

const U_SETTINGS_TAB_BUILDER := preload("res://scripts/core/ui/helpers/u_settings_tab_builder.gd")
const U_UI_THEME_BUILDER := preload("res://scripts/core/ui/utils/u_ui_theme_builder.gd")
const RS_UI_THEME_CONFIG := preload("res://scripts/core/resources/ui/rs_ui_theme_config.gd")

const OVERLAY_SCREEN_MARGIN := 40.0
const MIN_PANEL_HEIGHT := 200.0

@onready var _main_panel: PanelContainer = $CenterContainer/Panel
@onready var _main_panel_content: VBoxContainer = $CenterContainer/Panel/VBox
var _builder: RefCounted = null


func _on_panel_ready() -> void:
	_setup_builder()
	if _builder != null:
		_builder.build()
	_wrap_content_in_scroll()
	_apply_size_guards()
	if get_viewport() != null:
		if not get_viewport().size_changed.is_connected(_apply_size_guards):
			get_viewport().size_changed.connect(_apply_size_guards)
	_apply_overlay_theme()
	play_enter_animation()


func _wrap_content_in_scroll() -> void:
	if _main_panel_content == null:
		return
	var children: Array[Node] = []
	for child in _main_panel_content.get_children():
		children.append(child)
	var scroll := ScrollContainer.new()
	scroll.name = "SettingsScrollContainer"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	_main_panel_content.add_child(scroll)
	for child in children:
		child.reparent(scroll)


func _apply_size_guards() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var center_container := $CenterContainer as CenterContainer
	if center_container != null:
		center_container.anchors_preset = Control.PRESET_FULL_RECT
		center_container.offset_left = OVERLAY_SCREEN_MARGIN
		center_container.offset_top = OVERLAY_SCREEN_MARGIN
		center_container.offset_right = -OVERLAY_SCREEN_MARGIN
		center_container.offset_bottom = -OVERLAY_SCREEN_MARGIN
		center_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
		center_container.grow_vertical = Control.GROW_DIRECTION_BOTH
	if _main_panel != null:
		_main_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_main_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if _main_panel_content != null:
		_main_panel_content.custom_maximum_size.y = maxf(MIN_PANEL_HEIGHT, viewport_size.y - OVERLAY_SCREEN_MARGIN * 2.0)


func _on_back_pressed() -> void:
	U_UISoundPlayer.play_cancel()
	_close_overlay()

func _setup_builder() -> void:
	_builder = U_SETTINGS_TAB_BUILDER.new(self)
	_builder.bind_panel(_main_panel, _main_panel_content)

func _apply_overlay_theme() -> void:
	var config_resource: Resource = U_UI_THEME_BUILDER.active_config
	if not (config_resource is RS_UI_THEME_CONFIG):
		return
	var config := config_resource as RS_UI_THEME_CONFIG

	var dim_color := config.bg_base
	dim_color.a = 0.5
	background_color = dim_color
	var overlay_background := get_node_or_null("OverlayBackground") as ColorRect
	if overlay_background != null:
		overlay_background.color = dim_color

func _close_overlay() -> void:
	var store := get_store()
	if store == null:
		return

	var nav_slice: Dictionary = store.get_state().get("navigation", {})
	var overlay_stack: Array = U_NavigationSelectors.get_overlay_stack(nav_slice)
	var shell: StringName = U_NavigationSelectors.get_shell(nav_slice)

	if not overlay_stack.is_empty():
		store.dispatch(U_NavigationActions.close_top_overlay())
	elif shell == StringName("main_menu"):
		store.dispatch(U_NavigationActions.navigate_to_ui_screen(StringName("settings_menu"), "fade", 2))
	else:
		store.dispatch(U_NavigationActions.set_shell(StringName("main_menu"), StringName("settings_menu")))