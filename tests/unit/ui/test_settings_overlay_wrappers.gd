extends GutTest

const AUDIO_OVERLAY_SCENE := preload("res://scenes/core/ui/overlays/settings/ui_audio_settings_overlay.tscn")
const DISPLAY_OVERLAY_SCENE := preload("res://scenes/core/ui/overlays/settings/ui_display_settings_overlay.tscn")
const LOCALIZATION_OVERLAY_SCENE := preload("res://scenes/core/ui/overlays/settings/ui_localization_settings_overlay.tscn")
const VFX_OVERLAY_SCENE := preload("res://scenes/core/ui/overlays/settings/ui_vfx_settings_overlay.tscn")
const U_UI_THEME_BUILDER := preload("res://scripts/core/ui/utils/u_ui_theme_builder.gd")
const RS_UI_THEME_CONFIG := preload("res://scripts/core/resources/ui/rs_ui_theme_config.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")

var _store: M_StateStore


func before_each() -> void:
	U_UI_THEME_BUILDER.active_config = null
	U_StateHandoff.clear_all()
	U_SERVICE_LOCATOR.clear()

	_store = M_StateStore.new()
	_store.settings = RS_StateStoreSettings.new()
	_store.settings.enable_persistence = false
	_store.settings.enable_global_settings_persistence = false
	_store.settings.enable_debug_logging = false
	_store.settings.enable_debug_overlay = false
	_store.audio_initial_state = RS_AudioInitialState.new()
	_store.display_initial_state = RS_DisplayInitialState.new()
	_store.localization_initial_state = RS_LocalizationInitialState.new()
	_store.vfx_initial_state = RS_VFXInitialState.new()
	add_child_autofree(_store)
	U_SERVICE_LOCATOR.register(StringName("state_store"), _store)
	await _pump_frames(2)


func after_each() -> void:
	U_UI_THEME_BUILDER.active_config = null
	U_StateHandoff.clear_all()
	U_SERVICE_LOCATOR.clear()
	_store = null


func test_audio_settings_overlay_wrapper_has_motion_and_theme_tokens_when_active_config_set() -> void:
	var overlay := await _spawn_overlay_with_theme(AUDIO_OVERLAY_SCENE)
	_assert_wrapper_theme_and_motion(overlay, "CenterContainer/Panel", "CenterContainer/Panel/VBox", 0.5)

func test_audio_settings_overlay_keeps_panel_vertically_centered_after_enter() -> void:
	var overlay := await _spawn_overlay_with_theme(AUDIO_OVERLAY_SCENE)
	assert_not_null(overlay, "Audio wrapper should instantiate")
	if overlay == null:
		return

	assert_eq(
		overlay.get("motion_target_path"),
		NodePath("CenterContainer/Panel"),
		"Audio wrapper should animate panel target instead of center container"
	)

	await _wait_for_enter_motion_to_complete(overlay)

	var panel := overlay.get_node_or_null("CenterContainer/Panel") as PanelContainer
	assert_not_null(panel, "Audio wrapper panel should exist")
	if panel == null:
		return

	var panel_center_y: float = panel.global_position.y + (panel.size.y * 0.5)
	var expected_center_y: float = overlay.global_position.y + overlay.size.y * 0.5
	assert_almost_eq(
		panel_center_y,
		expected_center_y,
		2.0,
		"Audio wrapper panel should remain vertically centered after enter animation"
	)


func test_display_settings_overlay_wrapper_has_motion_and_theme_tokens_when_active_config_set() -> void:
	var overlay := await _spawn_overlay_with_theme(DISPLAY_OVERLAY_SCENE)
	_assert_wrapper_theme_and_motion(overlay, "CenterContainer/Panel", "CenterContainer/Panel/VBox", 0.5)

func test_display_settings_overlay_keeps_panel_vertically_centered_after_enter() -> void:
	var overlay := await _spawn_overlay_with_theme(DISPLAY_OVERLAY_SCENE)
	assert_not_null(overlay, "Display wrapper should instantiate")
	if overlay == null:
		return

	assert_eq(
		overlay.get("motion_target_path"),
		NodePath("CenterContainer/Panel"),
		"Display wrapper should animate panel target instead of center container"
	)

	await _wait_for_enter_motion_to_complete(overlay)

	var panel := overlay.get_node_or_null("CenterContainer/Panel") as PanelContainer
	assert_not_null(panel, "Display wrapper panel should exist")
	if panel == null:
		return

	var panel_center_y: float = panel.global_position.y + (panel.size.y * 0.5)
	var expected_center_y: float = overlay.global_position.y + overlay.size.y * 0.5
	assert_almost_eq(
		panel_center_y,
		expected_center_y,
		2.0,
		"Display wrapper panel should remain vertically centered after enter animation"
	)


func test_localization_settings_overlay_wrapper_has_motion_and_theme_tokens_when_active_config_set() -> void:
	var overlay := await _spawn_overlay_with_theme(LOCALIZATION_OVERLAY_SCENE)
	_assert_wrapper_theme_and_motion(overlay, "CenterContainer/Panel", "CenterContainer/Panel/VBox", 0.5)

func test_localization_settings_overlay_keeps_panel_vertically_centered_after_enter() -> void:
	var overlay := await _spawn_overlay_with_theme(LOCALIZATION_OVERLAY_SCENE)
	assert_not_null(overlay, "Localization wrapper should instantiate")
	if overlay == null:
		return

	assert_eq(
		overlay.get("motion_target_path"),
		NodePath("CenterContainer/Panel"),
		"Localization wrapper should animate panel target instead of center container"
	)

	await _wait_for_enter_motion_to_complete(overlay)

	var panel := overlay.get_node_or_null("CenterContainer/Panel") as PanelContainer
	assert_not_null(panel, "Localization wrapper panel should exist")
	if panel == null:
		return

	var panel_center_y: float = panel.global_position.y + (panel.size.y * 0.5)
	var expected_center_y: float = overlay.global_position.y + overlay.size.y * 0.5
	assert_almost_eq(
		panel_center_y,
		expected_center_y,
		2.0,
		"Localization wrapper panel should remain vertically centered after enter animation"
	)

func test_vfx_settings_overlay_wrapper_has_motion_and_theme_tokens_when_active_config_set() -> void:
	var overlay := await _spawn_overlay_with_theme(VFX_OVERLAY_SCENE)
	_assert_wrapper_theme_and_motion(overlay, "CenterContainer/Panel", "CenterContainer/Panel/VBox", 0.5)

func test_vfx_settings_overlay_keeps_panel_vertically_centered_after_enter() -> void:
	var overlay := await _spawn_overlay_with_theme(VFX_OVERLAY_SCENE)
	assert_not_null(overlay, "VFX wrapper should instantiate")
	if overlay == null:
		return

	assert_eq(
		overlay.get("motion_target_path"),
		NodePath("CenterContainer/Panel"),
		"VFX wrapper should animate panel target instead of center container"
	)

	await _wait_for_enter_motion_to_complete(overlay)

	var panel := overlay.get_node_or_null("CenterContainer/Panel") as PanelContainer
	assert_not_null(panel, "VFX wrapper panel should exist")
	if panel == null:
		return

	var panel_center_y: float = panel.global_position.y + (panel.size.y * 0.5)
	var expected_center_y: float = overlay.global_position.y + overlay.size.y * 0.5
	assert_almost_eq(
		panel_center_y,
		expected_center_y,
		2.0,
		"VFX wrapper panel should remain vertically centered after enter animation"
	)


func _spawn_overlay_with_theme(scene: PackedScene) -> Control:
	var config := RS_UI_THEME_CONFIG.new()
	config.separation_default = 15
	config.bg_base = Color(0.11, 0.15, 0.22, 1.0)
	U_UI_THEME_BUILDER.active_config = config

	var overlay := scene.instantiate() as Control
	add_child_autofree(overlay)
	await _pump_frames(2)
	return overlay


func _wait_for_enter_motion_to_complete(overlay: Control) -> void:
	var duration := _get_enter_motion_duration(overlay)
	if duration > 0.0:
		await wait_seconds(duration + 0.05)
	await _pump_frames(2)


func _get_enter_motion_duration(overlay: Control) -> float:
	if overlay == null:
		return 0.0

	var motion_set: Variant = overlay.get("motion_set")
	if motion_set == null or not ("enter" in motion_set):
		return 0.0

	var longest := 0.0
	var enter_presets: Array = motion_set.enter
	for preset: Resource in enter_presets:
		if preset == null:
			continue
		var duration := float(preset.get("duration_sec"))
		var delay := float(preset.get("delay_sec"))
		var interval := float(preset.get("interval_sec"))
		longest = maxf(longest, duration + delay + interval)
	return longest


func _assert_wrapper_theme_and_motion(
	overlay: Control,
	panel_path: String,
	content_path: String,
	expected_alpha: float
) -> void:
	assert_not_null(overlay, "Overlay should instantiate")
	if overlay == null:
		return

	var motion_set: Variant = overlay.get("motion_set")
	assert_not_null(motion_set, "Overlay should assign enter/exit motion set")
	if motion_set != null:
		assert_true("enter" in motion_set, "Motion set should expose enter presets")
		assert_true("exit" in motion_set, "Motion set should expose exit presets")

	var panel := overlay.get_node_or_null(panel_path) as PanelContainer
	var content := overlay.get_node_or_null(content_path) as VBoxContainer
	var overlay_background := overlay.get_node_or_null("OverlayBackground") as ColorRect
	var config := U_UI_THEME_BUILDER.active_config as RS_UI_THEME_CONFIG

	assert_not_null(panel, "Wrapper panel should exist")
	assert_not_null(content, "Wrapper content container should exist")
	assert_not_null(overlay_background, "BaseOverlay should provide OverlayBackground")

	if panel != null:
		assert_true(panel.has_theme_stylebox_override(&"panel"), "Wrapper panel should use panel_section style token")
	if content != null and config != null:
		assert_eq(
			content.get_theme_constant(&"separation"),
			config.separation_default,
			"Wrapper content should use separation_default token"
		)
	if overlay_background != null and config != null:
		var expected_dim := config.bg_base
		expected_dim.a = expected_alpha
		assert_true(
			overlay_background.color.is_equal_approx(expected_dim),
			"Wrapper dim should use bg_base with expected alpha"
		)


func _pump_frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame
