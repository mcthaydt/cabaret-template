extends GutTest


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

func test_palettes_return_same_preloaded_resource() -> void:
	var manager := U_PaletteManager.new()
	manager.set_color_blind_mode("protanopia")
	var first := manager.get_active_palette()
	var manager2 := U_PaletteManager.new()
	manager2.set_color_blind_mode("protanopia")
	var second := manager2.get_active_palette()
	assert_eq(first, second, "Preloaded palette should be same resource")

func test_high_contrast_combines_with_color_blind_mode() -> void:
	var manager := U_PaletteManager.new()
	manager.set_color_blind_mode("deuteranopia", true)
	var palette := manager.get_active_palette()
	assert_not_null(palette, "High contrast palette should load")
	assert_eq(palette.palette_id, StringName("deuteranopia_high_contrast"), "High contrast should combine with color blind mode")

func test_normal_high_contrast_loads() -> void:
	var manager := U_PaletteManager.new()
	manager.set_color_blind_mode("normal", true)
	var palette := manager.get_active_palette()
	assert_not_null(palette, "Normal high contrast palette should load")
	assert_eq(palette.palette_id, StringName("normal_high_contrast"), "Should load normal_high_contrast")

func test_protanopia_high_contrast_loads() -> void:
	var manager := U_PaletteManager.new()
	manager.set_color_blind_mode("protanopia", true)
	var palette := manager.get_active_palette()
	assert_not_null(palette, "Protanopia high contrast palette should load")
	assert_eq(palette.palette_id, StringName("protanopia_high_contrast"), "Should load protanopia_high_contrast")

func test_tritanopia_high_contrast_loads() -> void:
	var manager := U_PaletteManager.new()
	manager.set_color_blind_mode("tritanopia", true)
	var palette := manager.get_active_palette()
	assert_not_null(palette, "Tritanopia high contrast palette should load")
	assert_eq(palette.palette_id, StringName("tritanopia_high_contrast"), "Should load tritanopia_high_contrast")

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
