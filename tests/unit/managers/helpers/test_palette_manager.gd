extends GutTest

const U_PaletteManager := preload("res://scripts/managers/helpers/u_palette_manager.gd")

func test_set_color_blind_mode_loads_correct_palette() -> void:
	var manager := U_PaletteManager.new()
	manager.set_color_blind_mode("deuteranopia")
	var palette := manager.get_active_palette()
	assert_not_null(palette, "Palette should load")
	assert_eq(palette.palette_id, StringName("deuteranopia"), "Should load deuteranopia palette")

func test_set_color_blind_mode_emits_signal() -> void:
	var manager := U_PaletteManager.new()
	var emitted := [false]
	var received: Array = []
	var handler := func(palette) -> void:
		emitted[0] = true
		received.append(palette)
	manager.active_palette_changed.connect(handler)
	manager.set_color_blind_mode("protanopia")
	assert_true(emitted[0], "active_palette_changed should be emitted")
	assert_eq(received.size(), 1, "Signal should emit exactly once")
	manager.active_palette_changed.disconnect(handler)

func test_invalid_mode_falls_back_to_normal() -> void:
	var manager := U_PaletteManager.new()
	manager.set_color_blind_mode("invalid")
	var palette := manager.get_active_palette()
	assert_not_null(palette, "Fallback palette should load")
	assert_eq(palette.palette_id, StringName("normal"), "Invalid mode should fall back to normal")

func test_get_active_palette_returns_current_palette() -> void:
	var manager := U_PaletteManager.new()
	manager.set_color_blind_mode("tritanopia")
	var palette := manager.get_active_palette()
	assert_not_null(palette, "Palette should load")
	assert_eq(palette.palette_id, StringName("tritanopia"), "Active palette should match current mode")

func test_palettes_cached_after_first_load() -> void:
	var manager := U_PaletteManager.new()
	manager.set_color_blind_mode("protanopia")
	var first := manager.get_active_palette()
	manager.set_color_blind_mode("protanopia")
	var second := manager.get_active_palette()
	assert_eq(first, second, "Palette should be reused from cache")

func test_high_contrast_overrides_mode() -> void:
	var manager := U_PaletteManager.new()
	manager.set_color_blind_mode("deuteranopia", true)
	var palette := manager.get_active_palette()
	assert_not_null(palette, "High contrast palette should load")
	assert_eq(palette.palette_id, StringName("high_contrast"), "High contrast should override mode")

func test_palette_updates_on_mode_change() -> void:
	var manager := U_PaletteManager.new()
	manager.set_color_blind_mode("normal")
	var normal_palette := manager.get_active_palette()
	manager.set_color_blind_mode("tritanopia")
	var tri_palette := manager.get_active_palette()
	assert_ne(normal_palette, tri_palette, "Palette should change when mode changes")

func test_normal_mode_loads_normal_palette() -> void:
	var manager := U_PaletteManager.new()
	manager.set_color_blind_mode("normal")
	var palette := manager.get_active_palette()
	assert_not_null(palette, "Normal palette should load")
	assert_eq(palette.palette_id, StringName("normal"), "Normal mode should load normal palette")
