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
		"key": &"occlusion_silhouette_enabled",
		"label_key": &"settings.vfx.label.occlusion_silhouette",
		"tooltip_key": &"settings.vfx.tooltip.occlusion_silhouette",
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
