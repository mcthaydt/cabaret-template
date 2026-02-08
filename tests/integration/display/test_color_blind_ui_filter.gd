extends GutTest

## Integration test for color blind filter affecting UI elements

const POST_PROCESS_OVERLAY_SCENE := preload("res://scenes/ui/overlays/ui_post_process_overlay.tscn")

var _store: M_StateStore
var _display_manager: M_DisplayManager
var _post_process_overlay: Node

func before_each() -> void:
	U_ServiceLocator.clear()
	_store = M_StateStore.new()
	_store.settings = RS_StateStoreSettings.new()
	_store.settings.enable_persistence = false
	_store.settings.enable_debug_logging = false
	_store.settings.enable_debug_overlay = false
	_store.display_initial_state = RS_DisplayInitialState.new()
	add_child_autofree(_store)
	U_ServiceLocator.register(StringName("state_store"), _store)

	_post_process_overlay = POST_PROCESS_OVERLAY_SCENE.instantiate()
	_post_process_overlay.name = "PostProcessOverlay"
	add_child_autofree(_post_process_overlay)

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

	if ui_color_blind_layer == null:
		pending("UIColorBlindLayer not found in test environment")
		return
	if ui_overlay_stack == null:
		pending("UIOverlayStack not available in test environment (part of root scene)")
		return
	assert_true(ui_color_blind_layer.layer > ui_overlay_stack.layer,
		"UIColorBlindLayer should have higher layer number than UIOverlayStack to render on top")

func test_enabling_color_blind_shader_shows_ui_layer() -> void:
	# GIVEN: Color blind shader is disabled (mode is "normal")
	_store.dispatch(U_DisplayActions.set_color_blind_mode("normal"))
	await get_tree().process_frame

	# WHEN: Enabling color blind shader (setting mode to non-normal)
	_store.dispatch(U_DisplayActions.set_color_blind_mode("deuteranopia"))
	await wait_seconds(0.2)

	# THEN: UI color blind layer should be visible
	var root := get_tree().root
	var ui_color_blind_layer := root.find_child("UIColorBlindLayer", true, false)
	var color_rect := ui_color_blind_layer.find_child("ColorBlindRect", true, false) as ColorRect

	assert_not_null(color_rect, "Should have ColorBlindRect in UIColorBlindLayer")
	assert_true(color_rect.visible, "ColorBlindRect should be visible when mode is not normal")

func test_disabling_color_blind_shader_hides_ui_layer() -> void:
	# GIVEN: Color blind shader is enabled (mode is non-normal)
	_store.dispatch(U_DisplayActions.set_color_blind_mode("deuteranopia"))
	await wait_seconds(0.2)

	# WHEN: Disabling color blind shader (setting mode to "normal")
	_store.dispatch(U_DisplayActions.set_color_blind_mode("normal"))
	await wait_seconds(0.2)

	# THEN: UI color blind layer should be hidden
	var root := get_tree().root
	var ui_color_blind_layer := root.find_child("UIColorBlindLayer", true, false)
	var color_rect := ui_color_blind_layer.find_child("ColorBlindRect", true, false) as ColorRect

	assert_not_null(color_rect, "Should have ColorBlindRect in UIColorBlindLayer")
	assert_false(color_rect.visible, "ColorBlindRect should be hidden when mode is normal")

func test_color_blind_mode_updates_ui_layer_shader() -> void:
	# GIVEN: Starting with normal mode
	_store.dispatch(U_DisplayActions.set_color_blind_mode("normal"))
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
