extends GutTest

# Test suite for M_DisplayManager scaffolding and lifecycle (Phase 1B)

const M_DISPLAY_MANAGER := preload("res://scripts/managers/m_display_manager.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")
const I_DISPLAY_MANAGER := preload("res://scripts/interfaces/i_display_manager.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")

var _manager: Node
var _store: Node

func before_each() -> void:
	U_SERVICE_LOCATOR.clear()
	_manager = null
	_store = null

func after_each() -> void:
	U_SERVICE_LOCATOR.clear()
	_manager = null
	_store = null

func test_manager_extends_interface() -> void:
	_manager = M_DISPLAY_MANAGER.new()
	add_child_autofree(_manager)

	assert_true(_manager is I_DISPLAY_MANAGER, "M_DisplayManager should extend I_DisplayManager")

func test_manager_registers_with_service_locator() -> void:
	_manager = M_DISPLAY_MANAGER.new()
	add_child_autofree(_manager)
	await get_tree().process_frame

	var service := U_SERVICE_LOCATOR.try_get_service(StringName("display_manager"))
	assert_not_null(service, "Display manager should register with ServiceLocator")
	assert_eq(service, _manager, "ServiceLocator should return the display manager instance")

func test_manager_discovers_state_store() -> void:
	await _setup_manager_with_store({"window_mode": "windowed"})

	var resolved_store: Node = _manager.get("_state_store") as Node
	assert_eq(resolved_store, _store, "Manager should discover StateStore via U_StateUtils.try_get_store()")

func test_manager_subscribes_to_slice_updated() -> void:
	await _setup_manager_with_store({"window_mode": "windowed"})

	var handler := Callable(_manager, "_on_slice_updated")
	assert_true(_store.slice_updated.is_connected(handler), "Manager should connect to StateStore slice_updated signal")

func test_manager_applies_settings_on_ready() -> void:
	await _setup_manager_with_store({"window_mode": "windowed", "ui_scale": 1.0})

	assert_eq(int(_manager.get("_apply_count")), 1, "Manager should apply display settings on ready")
	var applied: Dictionary = _manager.get("_last_applied_settings")
	assert_eq(applied.get("window_mode"), "windowed", "Initial apply should read settings from state")

func test_manager_applies_settings_on_slice_change() -> void:
	await _setup_manager_with_store({"window_mode": "windowed"})

	_store.set_slice(StringName("display"), {"window_mode": "fullscreen"})
	_store.slice_updated.emit(StringName("display"), {"window_mode": "fullscreen"})

	assert_eq(int(_manager.get("_apply_count")), 2, "Manager should apply settings on display slice updates")
	var applied: Dictionary = _manager.get("_last_applied_settings")
	assert_eq(applied.get("window_mode"), "fullscreen", "Apply should reflect updated state")

func test_manager_hash_prevents_redundant_applies() -> void:
	await _setup_manager_with_store({"window_mode": "windowed"})

	var apply_count := int(_manager.get("_apply_count"))
	_store.slice_updated.emit(StringName("display"), {"window_mode": "windowed"})

	assert_eq(int(_manager.get("_apply_count")), apply_count, "Hash should prevent redundant apply calls")

func test_preview_sets_flag() -> void:
	await _setup_manager_with_store({"ui_scale": 1.0})

	_manager.set_display_settings_preview({"ui_scale": 1.5})
	assert_true(bool(_manager.get("_display_settings_preview_active")), "Preview should set active flag")

func test_preview_overrides_state() -> void:
	await _setup_manager_with_store({"window_mode": "windowed", "ui_scale": 1.0})

	_manager.set_display_settings_preview({"ui_scale": 1.5})
	var applied: Dictionary = _manager.get("_last_applied_settings")
	assert_eq(applied.get("ui_scale"), 1.5, "Preview should override ui_scale")
	assert_eq(applied.get("window_mode"), "windowed", "Preview should retain base state values")

func test_clear_preview_restores_state_and_clears_flag() -> void:
	await _setup_manager_with_store({"ui_scale": 1.0})

	_manager.set_display_settings_preview({"ui_scale": 1.5})
	_manager.clear_display_settings_preview()

	assert_false(bool(_manager.get("_display_settings_preview_active")), "Clear preview should reset active flag")
	var applied: Dictionary = _manager.get("_last_applied_settings")
	assert_eq(applied.get("ui_scale"), 1.0, "Clear preview should restore ui_scale from state")

func test_set_ui_scale_clamps_to_min() -> void:
	var manager := M_DISPLAY_MANAGER.new()
	add_child_autofree(manager)

	var label := Label.new()
	label.add_theme_font_size_override("font_size", 20)
	add_child_autofree(label)
	manager.register_ui_scale_root(label)

	manager.set_ui_scale(0.1)

	assert_eq(label.get_theme_font_size("font_size"), 16, "UI scale should clamp to minimum")

func test_set_ui_scale_clamps_to_max() -> void:
	var manager := M_DISPLAY_MANAGER.new()
	add_child_autofree(manager)

	var label := Label.new()
	label.add_theme_font_size_override("font_size", 20)
	add_child_autofree(label)
	manager.register_ui_scale_root(label)

	manager.set_ui_scale(5.0)

	assert_eq(label.get_theme_font_size("font_size"), 26, "UI scale should clamp to maximum")

func test_set_ui_scale_applies_font_scale_to_controls() -> void:
	var manager := M_DISPLAY_MANAGER.new()
	add_child_autofree(manager)

	var root := Control.new()
	add_child_autofree(root)
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 20)
	root.add_child(label)
	manager.register_ui_scale_root(root)

	manager.set_ui_scale(1.2)

	assert_eq(label.get_theme_font_size("font_size"), 24, "UI scale should apply to registered controls")

func test_register_ui_scale_root_applies_current_scale() -> void:
	var manager := M_DISPLAY_MANAGER.new()
	add_child_autofree(manager)

	manager.set_ui_scale(1.2)

	var root := Control.new()
	add_child_autofree(root)
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 20)
	root.add_child(label)
	manager.register_ui_scale_root(root)

	assert_eq(label.get_theme_font_size("font_size"), 24, "Registering should apply the current UI scale")

func test_safe_area_padding_sets_offsets_for_full_anchors() -> void:
	var manager := M_DISPLAY_MANAGER.new()
	add_child_autofree(manager)

	var control := Control.new()
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 1.0
	control.anchor_bottom = 1.0
	add_child_autofree(control)

	var viewport_size := Vector2(1000, 800)
	var safe_rect := Rect2(Vector2(50, 30), Vector2(900, 740))
	manager._apply_safe_area_padding(control, viewport_size, safe_rect)

	assert_almost_eq(control.offset_left, 50.0, 0.001, "Safe area left padding should apply")
	assert_almost_eq(control.offset_top, 30.0, 0.001, "Safe area top padding should apply")
	assert_almost_eq(control.offset_right, -50.0, 0.001, "Safe area right padding should apply")
	assert_almost_eq(control.offset_bottom, -30.0, 0.001, "Safe area bottom padding should apply")

func test_apply_window_size_preset_sets_window_size() -> void:
	if _skip_window_tests():
		return

	var manager := M_DISPLAY_MANAGER.new()
	var snapshot := _capture_window_state()

	manager.apply_window_size_preset("1280x720")
	await get_tree().process_frame

	assert_eq(DisplayServer.window_get_size(), Vector2i(1280, 720), "Window size preset should set window size")

	_restore_window_state(snapshot)
	manager.free()

func test_apply_window_size_preset_invalid_is_noop() -> void:
	if _skip_window_tests():
		return

	var manager := M_DISPLAY_MANAGER.new()
	var snapshot := _capture_window_state()

	manager.apply_window_size_preset("not_a_real_preset")
	await get_tree().process_frame

	assert_eq(DisplayServer.window_get_size(), snapshot.get("size"), "Invalid preset should not change window size")

	_restore_window_state(snapshot)
	manager.free()

func test_set_window_mode_fullscreen_calls_display_server() -> void:
	if _skip_window_tests():
		return

	var manager := M_DISPLAY_MANAGER.new()
	var snapshot := _capture_window_state()

	manager.set_window_mode("fullscreen")
	await get_tree().process_frame

	assert_eq(DisplayServer.window_get_mode(), DisplayServer.WINDOW_MODE_FULLSCREEN, "Fullscreen mode should update DisplayServer")

	_restore_window_state(snapshot)
	manager.free()

func test_set_window_mode_windowed_calls_display_server() -> void:
	if _skip_window_tests():
		return

	var manager := M_DISPLAY_MANAGER.new()
	var snapshot := _capture_window_state()

	manager.set_window_mode("windowed")
	await get_tree().process_frame

	assert_eq(DisplayServer.window_get_mode(), DisplayServer.WINDOW_MODE_WINDOWED, "Windowed mode should update DisplayServer")
	assert_false(
		DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS),
		"Windowed mode should clear borderless flag"
	)

	_restore_window_state(snapshot)
	manager.free()

func test_set_window_mode_borderless_calls_display_server() -> void:
	if _skip_window_tests():
		return

	var manager := M_DISPLAY_MANAGER.new()
	var snapshot := _capture_window_state()

	manager.set_window_mode("borderless")
	await get_tree().process_frame

	assert_eq(DisplayServer.window_get_mode(), DisplayServer.WINDOW_MODE_WINDOWED, "Borderless mode should use windowed mode")
	assert_true(
		DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS),
		"Borderless mode should enable borderless flag"
	)

	_restore_window_state(snapshot)
	manager.free()

func test_set_vsync_enabled_calls_display_server() -> void:
	if _skip_window_tests():
		return

	var manager := M_DISPLAY_MANAGER.new()
	var snapshot := _capture_window_state()

	manager.set_vsync_enabled(true)
	await get_tree().process_frame
	assert_eq(
		DisplayServer.window_get_vsync_mode(),
		DisplayServer.VSYNC_ENABLED,
		"VSync enabled should update DisplayServer"
	)

	manager.set_vsync_enabled(false)
	await get_tree().process_frame
	assert_eq(
		DisplayServer.window_get_vsync_mode(),
		DisplayServer.VSYNC_DISABLED,
		"VSync disabled should update DisplayServer"
	)

	_restore_window_state(snapshot)
	manager.free()

func _setup_manager_with_store(display_state: Dictionary) -> void:
	_store = MOCK_STATE_STORE.new()
	_store.set_slice(StringName("display"), display_state)
	add_child_autofree(_store)
	U_SERVICE_LOCATOR.register(StringName("state_store"), _store)

	var game_viewport := SubViewport.new()
	game_viewport.name = "GameViewport"
	add_child_autofree(game_viewport)

	_manager = M_DISPLAY_MANAGER.new()
	add_child_autofree(_manager)
	await get_tree().process_frame

func _skip_window_tests() -> bool:
	var display_name := DisplayServer.get_name().to_lower()
	if OS.has_feature("headless") or OS.has_feature("server") or display_name == "headless" or display_name == "dummy":
		pending("Skipped: DisplayServer window operations unavailable in headless mode")
		return true
	return false

func _capture_window_state() -> Dictionary:
	return {
		"size": DisplayServer.window_get_size(),
		"mode": DisplayServer.window_get_mode(),
		"borderless": DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS),
		"vsync": DisplayServer.window_get_vsync_mode(),
	}

func _restore_window_state(snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		return
	DisplayServer.window_set_size(snapshot.get("size", DisplayServer.window_get_size()))
	DisplayServer.window_set_mode(snapshot.get("mode", DisplayServer.window_get_mode()))
	DisplayServer.window_set_flag(
		DisplayServer.WINDOW_FLAG_BORDERLESS,
		bool(snapshot.get("borderless", false))
	)
	DisplayServer.window_set_vsync_mode(snapshot.get("vsync", DisplayServer.window_get_vsync_mode()))
