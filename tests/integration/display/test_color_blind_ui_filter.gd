extends GutTest

## Integration test for color blind filter affecting UI elements

const M_StateStore := preload("res://scripts/state/m_state_store.gd")
const M_DisplayManager := preload("res://scripts/managers/m_display_manager.gd")
const U_ServiceLocator := preload("res://scripts/core/u_service_locator.gd")
const U_DisplayActions := preload("res://scripts/state/actions/u_display_actions.gd")

var _store: M_StateStore
var _display_manager: M_DisplayManager

func before_each() -> void:
	_store = M_StateStore.new()
	add_child_autofree(_store)
	U_ServiceLocator.register(StringName("state_store"), _store)

	_display_manager = M_DisplayManager.new()
	_display_manager.name = "DisplayManager"
	add_child_autofree(_display_manager)
	await get_tree().process_frame

func after_each() -> void:
	U_ServiceLocator.clear()

func test_color_blind_shader_exists_for_ui_layer() -> void:
	# GIVEN: Display manager is initialized
	await get_tree().process_frame

	# THEN: Should have a UI color blind layer in the root scene
	var root := get_tree().root
	var ui_color_blind_layer := root.find_child("UIColorBlindLayer", true, false)

	assert_not_null(ui_color_blind_layer, "Should have UIColorBlindLayer in root scene")
	assert_true(ui_color_blind_layer is CanvasLayer, "UIColorBlindLayer should be a CanvasLayer")

func test_ui_color_blind_layer_has_higher_layer_than_ui_overlay() -> void:
	# GIVEN: Display manager is initialized
	await get_tree().process_frame

	# THEN: UIColorBlindLayer should render after UI elements (higher layer number)
	var root := get_tree().root
	var ui_color_blind_layer := root.find_child("UIColorBlindLayer", true, false) as CanvasLayer
	var ui_overlay_stack := root.find_child("UIOverlayStack", true, false) as CanvasLayer

	if ui_color_blind_layer != null and ui_overlay_stack != null:
		assert_true(ui_color_blind_layer.layer > ui_overlay_stack.layer,
			"UIColorBlindLayer should have higher layer number than UIOverlayStack to render on top")

func test_enabling_color_blind_shader_shows_ui_layer() -> void:
	# GIVEN: Color blind shader is disabled
	_store.dispatch(U_DisplayActions.set_color_blind_shader_enabled(false))
	await get_tree().process_frame

	# WHEN: Enabling color blind shader
	_store.dispatch(U_DisplayActions.set_color_blind_shader_enabled(true))
	await wait_seconds(0.2)

	# THEN: UI color blind layer should be visible
	var root := get_tree().root
	var ui_color_blind_layer := root.find_child("UIColorBlindLayer", true, false)
	var color_rect := ui_color_blind_layer.find_child("ColorBlindRect", true, false) as ColorRect

	assert_not_null(color_rect, "Should have ColorBlindRect in UIColorBlindLayer")
	assert_true(color_rect.visible, "ColorBlindRect should be visible when shader is enabled")

func test_disabling_color_blind_shader_hides_ui_layer() -> void:
	# GIVEN: Color blind shader is enabled
	_store.dispatch(U_DisplayActions.set_color_blind_shader_enabled(true))
	await wait_seconds(0.2)

	# WHEN: Disabling color blind shader
	_store.dispatch(U_DisplayActions.set_color_blind_shader_enabled(false))
	await wait_seconds(0.2)

	# THEN: UI color blind layer should be hidden
	var root := get_tree().root
	var ui_color_blind_layer := root.find_child("UIColorBlindLayer", true, false)
	var color_rect := ui_color_blind_layer.find_child("ColorBlindRect", true, false) as ColorRect

	assert_not_null(color_rect, "Should have ColorBlindRect in UIColorBlindLayer")
	assert_false(color_rect.visible, "ColorBlindRect should be hidden when shader is disabled")

func test_color_blind_mode_updates_ui_layer_shader() -> void:
	# GIVEN: Color blind shader is enabled
	_store.dispatch(U_DisplayActions.set_color_blind_shader_enabled(true))
	await get_tree().process_frame

	# WHEN: Setting color blind mode to deuteranopia
	_store.dispatch(U_DisplayActions.set_color_blind_mode("deuteranopia"))
	await wait_seconds(0.2)

	# THEN: UI layer shader should use deuteranopia mode (value 1)
	var root := get_tree().root
	var ui_color_blind_layer := root.find_child("UIColorBlindLayer", true, false)
	var color_rect := ui_color_blind_layer.find_child("ColorBlindRect", true, false) as ColorRect

	assert_not_null(color_rect, "Should have ColorBlindRect")
	var material := color_rect.material as ShaderMaterial
	assert_not_null(material, "ColorBlindRect should have ShaderMaterial")

	var mode: int = material.get_shader_parameter("mode")
	assert_eq(mode, 1, "Shader mode should be 1 for deuteranopia")
