extends RefCounted
class_name U_GlobalSettingsApplier

const U_DISPLAY_ACTIONS := preload("res://scripts/state/actions/u_display_actions.gd")
const U_AUDIO_ACTIONS := preload("res://scripts/state/actions/u_audio_actions.gd")
const U_VFX_ACTIONS := preload("res://scripts/state/actions/u_vfx_actions.gd")
const U_INPUT_ACTIONS := preload("res://scripts/state/actions/u_input_actions.gd")
const U_GAMEPLAY_ACTIONS := preload("res://scripts/state/actions/u_gameplay_actions.gd")
const U_LOCALIZATION_ACTIONS := preload("res://scripts/state/actions/u_localization_actions.gd")

static func apply(store: I_StateStore, settings: Dictionary) -> void:
	if store == null or settings == null:
		return

	var display_variant: Variant = settings.get("display", {})
	if display_variant is Dictionary:
		_apply_display(store, display_variant as Dictionary)

	var audio_variant: Variant = settings.get("audio", {})
	if audio_variant is Dictionary:
		_apply_audio(store, audio_variant as Dictionary)

	var vfx_variant: Variant = settings.get("vfx", {})
	if vfx_variant is Dictionary:
		_apply_vfx(store, vfx_variant as Dictionary)

	var input_variant: Variant = settings.get("input_settings", {})
	if input_variant is Dictionary:
		store.dispatch(U_INPUT_ACTIONS.load_input_settings(input_variant as Dictionary))

	var gameplay_variant: Variant = settings.get("gameplay_preferences", {})
	if gameplay_variant is Dictionary:
		_apply_gameplay_preferences(store, gameplay_variant as Dictionary)

	var localization_variant: Variant = settings.get("localization", {})
	if localization_variant is Dictionary:
		_apply_localization(store, localization_variant as Dictionary)

static func _apply_display(store: I_StateStore, display: Dictionary) -> void:
	if display.has("window_size_preset"):
		store.dispatch(U_DISPLAY_ACTIONS.set_window_size_preset(String(display.get("window_size_preset", ""))))
	if display.has("window_mode"):
		store.dispatch(U_DISPLAY_ACTIONS.set_window_mode(String(display.get("window_mode", ""))))
	if display.has("vsync_enabled"):
		store.dispatch(U_DISPLAY_ACTIONS.set_vsync_enabled(bool(display.get("vsync_enabled", true))))
	if display.has("quality_preset"):
		store.dispatch(U_DISPLAY_ACTIONS.set_quality_preset(String(display.get("quality_preset", ""))))
	if display.has("film_grain_enabled"):
		store.dispatch(U_DISPLAY_ACTIONS.set_film_grain_enabled(bool(display.get("film_grain_enabled", false))))
	if display.has("film_grain_intensity"):
		store.dispatch(U_DISPLAY_ACTIONS.set_film_grain_intensity(float(display.get("film_grain_intensity", 0.1))))
	if display.has("crt_enabled"):
		store.dispatch(U_DISPLAY_ACTIONS.set_crt_enabled(bool(display.get("crt_enabled", false))))
	if display.has("crt_scanline_intensity"):
		store.dispatch(U_DISPLAY_ACTIONS.set_crt_scanline_intensity(float(display.get("crt_scanline_intensity", 0.3))))
	if display.has("crt_curvature"):
		store.dispatch(U_DISPLAY_ACTIONS.set_crt_curvature(float(display.get("crt_curvature", 2.0))))
	if display.has("crt_chromatic_aberration"):
		store.dispatch(U_DISPLAY_ACTIONS.set_crt_chromatic_aberration(float(display.get("crt_chromatic_aberration", 0.002))))
	if display.has("dither_enabled"):
		store.dispatch(U_DISPLAY_ACTIONS.set_dither_enabled(bool(display.get("dither_enabled", false))))
	if display.has("dither_intensity"):
		store.dispatch(U_DISPLAY_ACTIONS.set_dither_intensity(float(display.get("dither_intensity", 0.5))))
	if display.has("dither_pattern"):
		store.dispatch(U_DISPLAY_ACTIONS.set_dither_pattern(String(display.get("dither_pattern", ""))))
	if display.has("ui_scale"):
		store.dispatch(U_DISPLAY_ACTIONS.set_ui_scale(float(display.get("ui_scale", 1.0))))
	if display.has("color_blind_mode"):
		store.dispatch(U_DISPLAY_ACTIONS.set_color_blind_mode(String(display.get("color_blind_mode", "normal"))))
	if display.has("high_contrast_enabled"):
		store.dispatch(U_DISPLAY_ACTIONS.set_high_contrast_enabled(bool(display.get("high_contrast_enabled", false))))
	if display.has("color_blind_shader_enabled"):
		store.dispatch(U_DISPLAY_ACTIONS.set_color_blind_shader_enabled(bool(display.get("color_blind_shader_enabled", false))))

static func _apply_audio(store: I_StateStore, audio: Dictionary) -> void:
	if audio.has("master_volume"):
		store.dispatch(U_AUDIO_ACTIONS.set_master_volume(float(audio.get("master_volume", 1.0))))
	if audio.has("music_volume"):
		store.dispatch(U_AUDIO_ACTIONS.set_music_volume(float(audio.get("music_volume", 1.0))))
	if audio.has("sfx_volume"):
		store.dispatch(U_AUDIO_ACTIONS.set_sfx_volume(float(audio.get("sfx_volume", 1.0))))
	if audio.has("ambient_volume"):
		store.dispatch(U_AUDIO_ACTIONS.set_ambient_volume(float(audio.get("ambient_volume", 1.0))))
	if audio.has("master_muted"):
		store.dispatch(U_AUDIO_ACTIONS.set_master_muted(bool(audio.get("master_muted", false))))
	if audio.has("music_muted"):
		store.dispatch(U_AUDIO_ACTIONS.set_music_muted(bool(audio.get("music_muted", false))))
	if audio.has("sfx_muted"):
		store.dispatch(U_AUDIO_ACTIONS.set_sfx_muted(bool(audio.get("sfx_muted", false))))
	if audio.has("ambient_muted"):
		store.dispatch(U_AUDIO_ACTIONS.set_ambient_muted(bool(audio.get("ambient_muted", false))))
	if audio.has("spatial_audio_enabled"):
		store.dispatch(U_AUDIO_ACTIONS.set_spatial_audio_enabled(bool(audio.get("spatial_audio_enabled", true))))

static func _apply_vfx(store: I_StateStore, vfx: Dictionary) -> void:
	if vfx.has("screen_shake_enabled"):
		store.dispatch(U_VFX_ACTIONS.set_screen_shake_enabled(bool(vfx.get("screen_shake_enabled", true))))
	if vfx.has("screen_shake_intensity"):
		store.dispatch(U_VFX_ACTIONS.set_screen_shake_intensity(float(vfx.get("screen_shake_intensity", 1.0))))
	if vfx.has("damage_flash_enabled"):
		store.dispatch(U_VFX_ACTIONS.set_damage_flash_enabled(bool(vfx.get("damage_flash_enabled", true))))
	if vfx.has("particles_enabled"):
		store.dispatch(U_VFX_ACTIONS.set_particles_enabled(bool(vfx.get("particles_enabled", true))))

static func _apply_localization(store: I_StateStore, settings: Dictionary) -> void:
	if settings.has("current_locale"):
		store.dispatch(U_LOCALIZATION_ACTIONS.set_locale(StringName(settings.get("current_locale", &"en"))))
	if settings.has("dyslexia_font_enabled"):
		store.dispatch(U_LOCALIZATION_ACTIONS.set_dyslexia_font_enabled(bool(settings.get("dyslexia_font_enabled", false))))
	if settings.has("ui_scale_override"):
		store.dispatch(U_LOCALIZATION_ACTIONS.set_ui_scale_override(float(settings.get("ui_scale_override", 1.0))))
	if bool(settings.get("has_selected_language", false)):
		store.dispatch(U_LOCALIZATION_ACTIONS.mark_language_selected())

static func _apply_gameplay_preferences(store: I_StateStore, gameplay: Dictionary) -> void:
	if gameplay.has("show_landing_indicator"):
		store.dispatch(U_GAMEPLAY_ACTIONS.set_show_landing_indicator(bool(gameplay.get("show_landing_indicator", true))))
	if gameplay.has("particle_settings") and gameplay["particle_settings"] is Dictionary:
		store.dispatch(U_GAMEPLAY_ACTIONS.set_particle_settings((gameplay["particle_settings"] as Dictionary).duplicate(true)))
	if gameplay.has("audio_settings") and gameplay["audio_settings"] is Dictionary:
		store.dispatch(U_GAMEPLAY_ACTIONS.set_audio_settings((gameplay["audio_settings"] as Dictionary).duplicate(true)))
