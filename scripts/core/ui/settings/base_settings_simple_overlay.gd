@icon("res://assets/core/editor_icons/icn_utility.svg")
extends "res://scripts/core/ui/base/base_overlay.gd"
class_name BaseSettingsSimpleOverlay

const U_UI_THEME_BUILDER := preload("res://scripts/core/ui/utils/u_ui_theme_builder.gd")
const RS_UI_THEME_CONFIG := preload("res://scripts/core/resources/ui/rs_ui_theme_config.gd")

@onready var _main_panel: PanelContainer = $CenterContainer/Panel
@onready var _main_panel_content: VBoxContainer = $CenterContainer/Panel/VBox


func _on_panel_ready() -> void:
	_apply_theme_tokens()
	play_enter_animation()


func _on_back_pressed() -> void:
	U_UISoundPlayer.play_cancel()
	_close_overlay()

func _apply_theme_tokens() -> void:
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

	if _main_panel != null and config.panel_section != null:
		_main_panel.add_theme_stylebox_override(&"panel", config.panel_section)
	if _main_panel_content != null:
		_main_panel_content.add_theme_constant_override(&"separation", config.separation_default)

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
