extends RefCounted

## Applies rendering quality presets to the active viewport.

const U_DISPLAY_OPTION_CATALOG := preload("res://scripts/utils/display/u_display_option_catalog.gd")
const U_DISPLAY_SELECTORS := preload("res://scripts/state/selectors/u_display_selectors.gd")

var _owner: Node = null

func initialize(owner: Node) -> void:
	_owner = owner

func apply_settings(display_settings: Dictionary) -> void:
	var state := {"display": display_settings}
	var preset := U_DISPLAY_SELECTORS.get_quality_preset(state)
	apply_quality_preset(preset)

func apply_quality_preset(preset: String) -> void:
	if preset.is_empty():
		return
	if not _is_rendering_available():
		return

	var config := _load_quality_preset(preset)
	if config == null:
		return

	_apply_shadow_quality(String(config.shadow_quality))
	_apply_anti_aliasing(String(config.anti_aliasing))

func _load_quality_preset(preset: String) -> Resource:
	var resource := U_DISPLAY_OPTION_CATALOG.get_quality_preset_by_id(preset)
	if resource == null:
		push_warning("U_DisplayQualityApplier: Unknown quality preset '%s'" % preset)
		return null
	return resource

func _apply_shadow_quality(shadow_quality: String) -> void:
	match shadow_quality:
		"off":
			RenderingServer.directional_shadow_atlas_set_size(0, false)
		"low":
			RenderingServer.directional_shadow_atlas_set_size(1024, false)
		"medium":
			RenderingServer.directional_shadow_atlas_set_size(2048, true)
		"high":
			RenderingServer.directional_shadow_atlas_set_size(4096, true)
		_:
			push_warning("U_DisplayQualityApplier: Unknown shadow quality '%s'" % shadow_quality)

func _apply_anti_aliasing(anti_aliasing: String) -> void:
	var viewport := _get_render_target_viewport()
	if viewport == null:
		return

	match anti_aliasing:
		"none":
			viewport.msaa_3d = Viewport.MSAA_DISABLED
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		"fxaa":
			viewport.msaa_3d = Viewport.MSAA_DISABLED
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
		"msaa_2x":
			viewport.msaa_3d = Viewport.MSAA_2X
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		"msaa_4x":
			viewport.msaa_3d = Viewport.MSAA_4X
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		"msaa_8x":
			viewport.msaa_3d = Viewport.MSAA_8X
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		_:
			push_warning("U_DisplayQualityApplier: Unknown anti-aliasing '%s'" % anti_aliasing)

func _get_render_target_viewport() -> Viewport:
	var tree := _get_tree()
	if tree != null and tree.root != null:
		var game_viewport := tree.root.find_child("GameViewport", true, false)
		if game_viewport is Viewport:
			return game_viewport as Viewport
	if _owner != null:
		return _owner.get_viewport()
	return null

func _is_rendering_available() -> bool:
	return not (OS.has_feature("headless") or OS.has_feature("server"))

func _get_tree() -> SceneTree:
	if _owner != null:
		return _owner.get_tree()
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree:
		return main_loop as SceneTree
	return null
