extends RefCounted
class_name U_UISettingsCatalog

const U_DISPLAY_OPTION_CATALOG := preload("res://scripts/core/utils/display/u_display_option_catalog.gd")

const AUDIO_BUS_NAMES: Array[String] = ["Master", "Music", "SFX", "Ambient"]
const DEFAULT_VOLUME := 0.8
const SPATIAL_AUDIO_DEFAULT := true

const VSYNC_OPTIONS: Array[Dictionary] = [
	{"id": &"enabled", "label_key": &"settings.display.option.vsync.enabled", "value": true},
	{"id": &"disabled", "label_key": &"settings.display.option.vsync.disabled", "value": false},
]

const VFX_TOGGLE_OPTIONS: Array[Dictionary] = [
	{
		"key": &"screen_shake_enabled",
		"label_key": &"settings.vfx.label.screen_shake",
		"tooltip_key": &"settings.vfx.tooltip.screen_shake",
		"default": true,
	},
	{
		"key": &"damage_flash_enabled",
		"label_key": &"settings.vfx.label.damage_flash",
		"tooltip_key": &"settings.vfx.tooltip.damage_flash",
		"default": true,
	},
	{
		"key": &"particles_enabled",
		"label_key": &"settings.vfx.label.particles",
		"tooltip_key": &"settings.vfx.tooltip.particles",
		"default": true,
	},
	{
		"key": &"screen_shake_intensity",
		"label_key": &"settings.vfx.label.shake_intensity",
		"tooltip_key": &"settings.vfx.tooltip.shake_intensity",
		"default": true,
	},
]

static func get_window_sizes() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for entry in U_DISPLAY_OPTION_CATALOG.get_window_size_option_entries():
		var id := StringName(str(entry.get("id", "")))
		entries.append({
			"id": id,
			"label_key": StringName("settings.display.option.window_size.%s" % id),
			"value": _parse_window_size(str(id)),
		})
	return entries

static func get_window_modes() -> Array[Dictionary]:
	return _display_entries_to_options(U_DISPLAY_OPTION_CATALOG.get_window_mode_option_entries())

static func get_vsync_options() -> Array[Dictionary]:
	return VSYNC_OPTIONS.duplicate(true)

static func get_quality_presets() -> Array[Dictionary]:
	return _display_entries_to_options(U_DISPLAY_OPTION_CATALOG.get_quality_option_entries())

static func get_ui_scale_range() -> Dictionary:
	return {"min": 0.8, "max": 1.3, "step": 0.1, "default": 1.0}

static func get_audio_bus_names() -> Array[String]:
	return AUDIO_BUS_NAMES.duplicate()

static func get_volume_range() -> Dictionary:
	return {"min": 0.0, "max": 1.0, "step": 0.01}

static func get_default_volume() -> float:
	return DEFAULT_VOLUME

static func get_spatial_audio_default() -> bool:
	return SPATIAL_AUDIO_DEFAULT

static func get_toggle_options() -> Array[Dictionary]:
	return VFX_TOGGLE_OPTIONS.duplicate(true)

static func get_intensity_range() -> Dictionary:
	return {"min": 0.0, "max": 2.0, "step": 0.1, "default": 1.0}

static func get_language_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	var locales := TranslationServer.get_loaded_locales()
	for locale in locales:
		options.append({
			"id": locale,
			"label_key": &"settings.localization.option.%s" % locale,
			"value": locale,
		})
	return options

static func _display_entries_to_options(entries: Array[Dictionary]) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for entry in entries:
		var id := StringName(str(entry.get("id", "")))
		options.append({
			"id": id,
			"label_key": entry.get("label_key", &""),
			"value": id,
		})
	return options

static func _parse_window_size(id: String) -> Vector2i:
	var parts := id.split("x")
	if parts.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))

static func create_display_builder(
	tab: Control,
	window_size_cb: Callable,
	window_mode_cb: Callable,
	vsync_cb: Callable,
	quality_cb: Callable,
	post_processing_cb: Callable,
	post_processing_preset_cb: Callable,
	ui_scale_cb: Callable,
	color_blind_cb: Callable,
	high_contrast_cb: Callable,
	apply_cb: Callable,
	cancel_cb: Callable,
	reset_cb: Callable
):
	var U_DISPLAY_TAB_BUILDER := preload("res://scripts/core/ui/helpers/u_display_tab_builder.gd")
	var builder := U_DISPLAY_TAB_BUILDER.new(tab)
	return builder.set_callbacks(
		window_size_cb, window_mode_cb, vsync_cb, quality_cb,
		post_processing_cb, post_processing_preset_cb, ui_scale_cb,
		color_blind_cb, high_contrast_cb, apply_cb, cancel_cb, reset_cb
	)

static func create_audio_builder(
	tab: Control,
	master_vol_cb: Callable,
	music_vol_cb: Callable,
	sfx_vol_cb: Callable,
	ambient_vol_cb: Callable,
	master_mute_cb: Callable,
	music_mute_cb: Callable,
	sfx_mute_cb: Callable,
	ambient_mute_cb: Callable,
	spatial_cb: Callable,
	apply_cb: Callable,
	cancel_cb: Callable,
	reset_cb: Callable
):
	var U_AUDIO_TAB_BUILDER := preload("res://scripts/core/ui/helpers/u_audio_tab_builder.gd")
	var builder := U_AUDIO_TAB_BUILDER.new(tab)
	return builder.set_callbacks(
		master_vol_cb, music_vol_cb, sfx_vol_cb, ambient_vol_cb,
		master_mute_cb, music_mute_cb, sfx_mute_cb, ambient_mute_cb,
		spatial_cb, apply_cb, cancel_cb, reset_cb
	)

static func create_localization_builder(
	tab: Control,
	language_cb: Callable,
	dyslexia_cb: Callable = Callable(),
	apply_cb: Callable = Callable(),
	cancel_cb: Callable = Callable(),
	reset_cb: Callable = Callable()
):
	var U_LOCALIZATION_TAB_BUILDER := preload("res://scripts/core/ui/helpers/u_localization_tab_builder.gd")
	var builder := U_LOCALIZATION_TAB_BUILDER.new(tab)
	return builder.set_callbacks(language_cb, dyslexia_cb, apply_cb, cancel_cb, reset_cb)
