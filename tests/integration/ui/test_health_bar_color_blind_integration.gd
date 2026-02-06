extends GutTest

## Integration test: Health bar color adapts to color blind palette.

const UI_HudController := preload("res://scripts/ui/hud/ui_hud_controller.gd")
const M_StateStore := preload("res://scripts/state/m_state_store.gd")
const M_DisplayManager := preload("res://scripts/managers/m_display_manager.gd")
const U_DisplayActions := preload("res://scripts/state/actions/u_display_actions.gd")
const U_GameplayActions := preload("res://scripts/state/actions/u_gameplay_actions.gd")
const U_ServiceLocator := preload("res://scripts/core/u_service_locator.gd")
const RS_StateStoreSettings := preload("res://scripts/resources/state/rs_state_store_settings.gd")
const RS_DisplayInitialState := preload("res://scripts/resources/state/rs_display_initial_state.gd")

var _store: M_StateStore = null
var _hud: UI_HudController = null
var _display_manager: M_DisplayManager = null

func before_each() -> void:
	const U_NavigationActions := preload("res://scripts/state/actions/u_navigation_actions.gd")

	U_ServiceLocator.clear()

	# Create state store with initial state resources
	_store = M_StateStore.new()
	_store.name = "StateStore"
	_store.settings = RS_StateStoreSettings.new()
	_store.settings.enable_persistence = false
	_store.settings.enable_debug_logging = false
	_store.settings.enable_debug_overlay = false
	_store.gameplay_initial_state = load("res://resources/state/cfg_default_gameplay_initial_state.tres")
	_store.display_initial_state = RS_DisplayInitialState.new()
	add_child_autofree(_store)
	await get_tree().process_frame

	# Register with ServiceLocator
	U_ServiceLocator.register(StringName("state_store"), _store)

	# Create and register DisplayManager so HUD can query it for palettes
	_display_manager = M_DisplayManager.new()
	add_child_autofree(_display_manager)
	await get_tree().process_frame

	# Set navigation shell to "gameplay" so health bar is visible
	_store.dispatch(U_NavigationActions.set_shell(StringName("gameplay"), StringName("gameplay_base")))
	await get_tree().process_frame

	# Set initial color blind mode (normal) to ensure display state is initialized
	_store.dispatch(U_DisplayActions.set_color_blind_mode("normal"))
	await get_tree().process_frame

	# Set health to 100 (full) explicitly
	_store.dispatch(U_GameplayActions.heal("player", 100.0))
	await get_tree().process_frame

	# Load HUD scene
	var hud_scene := load("res://scenes/ui/hud/ui_hud_overlay.tscn") as PackedScene
	_hud = hud_scene.instantiate() as UI_HudController
	add_child_autofree(_hud)
	await get_tree().process_frame

	# Wait an additional frame for the HUD to complete initialization
	await get_tree().process_frame

func after_each() -> void:
	U_ServiceLocator.clear()

func test_health_bar_uses_success_color_from_normal_palette() -> void:
	# Arrange: Set normal color blind mode
	_store.dispatch(U_DisplayActions.set_color_blind_mode("normal"))
	await get_tree().process_frame

	# Load the normal palette to get expected color
	var normal_palette := load("res://resources/ui_themes/cfg_palette_normal.tres") as Resource
	var expected_color: Color = normal_palette.success

	# Act: Get the health bar's fill color (check for override first)
	var health_bar: ProgressBar = _hud.health_bar
	assert_not_null(health_bar, "Health bar should exist")

	# Get fill style - check for override first, then fallback to theme
	var fill_style: StyleBoxFlat = null
	if health_bar.has_theme_stylebox_override("fill"):
		fill_style = health_bar.get_theme_stylebox("fill", "") as StyleBoxFlat
	else:
		fill_style = health_bar.get_theme_stylebox("fill") as StyleBoxFlat
	assert_not_null(fill_style, "Fill style should be StyleBoxFlat")

	var actual_color: Color = fill_style.bg_color

	# Assert: Color should match palette's success color
	assert_almost_eq(actual_color.r, expected_color.r, 0.01, "Red channel should match")
	assert_almost_eq(actual_color.g, expected_color.g, 0.01, "Green channel should match")
	assert_almost_eq(actual_color.b, expected_color.b, 0.01, "Blue channel should match")

func test_health_bar_uses_success_color_from_deuteranopia_palette() -> void:
	# Arrange: Set deuteranopia color blind mode
	_store.dispatch(U_DisplayActions.set_color_blind_mode("deuteranopia"))
	await get_tree().process_frame

	# Load the deuteranopia palette to get expected color
	var deut_palette := load("res://resources/ui_themes/cfg_palette_deuteranopia.tres") as Resource
	var expected_color: Color = deut_palette.success

	# Act: Get the health bar's fill color (check for override first)
	var health_bar: ProgressBar = _hud.health_bar
	var fill_style: StyleBoxFlat = null
	if health_bar.has_theme_stylebox_override("fill"):
		fill_style = health_bar.get_theme_stylebox("fill", "") as StyleBoxFlat
	else:
		fill_style = health_bar.get_theme_stylebox("fill") as StyleBoxFlat
	var actual_color: Color = fill_style.bg_color

	# Assert: Color should match palette's success color
	assert_almost_eq(actual_color.r, expected_color.r, 0.01, "Red channel should match deuteranopia palette")
	assert_almost_eq(actual_color.g, expected_color.g, 0.01, "Green channel should match deuteranopia palette")
	assert_almost_eq(actual_color.b, expected_color.b, 0.01, "Blue channel should match deuteranopia palette")

func test_health_bar_uses_warning_color_when_health_is_medium() -> void:
	# Arrange: Set health to 50% (medium range) by taking damage
	_store.dispatch(U_GameplayActions.take_damage("player", 50.0))
	await get_tree().process_frame

	# Load the normal palette to get expected color
	var normal_palette := load("res://resources/ui_themes/cfg_palette_normal.tres") as Resource
	var expected_color: Color = normal_palette.warning

	# Act: Get the health bar's fill color (check for override first)
	var health_bar: ProgressBar = _hud.health_bar
	var fill_style: StyleBoxFlat = null
	if health_bar.has_theme_stylebox_override("fill"):
		fill_style = health_bar.get_theme_stylebox("fill", "") as StyleBoxFlat
	else:
		fill_style = health_bar.get_theme_stylebox("fill") as StyleBoxFlat
	var actual_color: Color = fill_style.bg_color

	# Assert: Color should match palette's warning color
	assert_almost_eq(actual_color.r, expected_color.r, 0.01, "Red channel should match warning")
	assert_almost_eq(actual_color.g, expected_color.g, 0.01, "Green channel should match warning")
	assert_almost_eq(actual_color.b, expected_color.b, 0.01, "Blue channel should match warning")

func test_health_bar_uses_danger_color_when_health_is_low() -> void:
	# Arrange: Set health to 20% (low range) by taking damage
	_store.dispatch(U_GameplayActions.take_damage("player", 80.0))
	await get_tree().process_frame

	# Load the normal palette to get expected color
	var normal_palette := load("res://resources/ui_themes/cfg_palette_normal.tres") as Resource
	var expected_color: Color = normal_palette.danger

	# Act: Get the health bar's fill color (check for override first)
	var health_bar: ProgressBar = _hud.health_bar
	var fill_style: StyleBoxFlat = null
	if health_bar.has_theme_stylebox_override("fill"):
		fill_style = health_bar.get_theme_stylebox("fill", "") as StyleBoxFlat
	else:
		fill_style = health_bar.get_theme_stylebox("fill") as StyleBoxFlat
	var actual_color: Color = fill_style.bg_color

	# Assert: Color should match palette's danger color
	assert_almost_eq(actual_color.r, expected_color.r, 0.01, "Red channel should match danger")
	assert_almost_eq(actual_color.g, expected_color.g, 0.01, "Green channel should match danger")
	assert_almost_eq(actual_color.b, expected_color.b, 0.01, "Blue channel should match danger")

func test_health_bar_color_updates_when_color_blind_mode_changes() -> void:
	# Arrange: Start with normal mode
	_store.dispatch(U_DisplayActions.set_color_blind_mode("normal"))
	await get_tree().process_frame

	var normal_palette := load("res://resources/ui_themes/cfg_palette_normal.tres") as Resource
	var normal_color: Color = normal_palette.success

	var health_bar: ProgressBar = _hud.health_bar
	var fill_style: StyleBoxFlat = null
	if health_bar.has_theme_stylebox_override("fill"):
		fill_style = health_bar.get_theme_stylebox("fill", "") as StyleBoxFlat
	else:
		fill_style = health_bar.get_theme_stylebox("fill") as StyleBoxFlat

	# Verify initial color
	assert_almost_eq(fill_style.bg_color.r, normal_color.r, 0.01, "Should start with normal palette")

	# Act: Change to protanopia mode
	_store.dispatch(U_DisplayActions.set_color_blind_mode("protanopia"))
	await get_tree().process_frame

	var prot_palette := load("res://resources/ui_themes/cfg_palette_protanopia.tres") as Resource
	var prot_color: Color = prot_palette.success

	# Get fill style again after update
	if health_bar.has_theme_stylebox_override("fill"):
		fill_style = health_bar.get_theme_stylebox("fill", "") as StyleBoxFlat
	else:
		fill_style = health_bar.get_theme_stylebox("fill") as StyleBoxFlat

	# Assert: Color should update to protanopia palette
	assert_almost_eq(fill_style.bg_color.r, prot_color.r, 0.01, "Red should match protanopia")
	assert_almost_eq(fill_style.bg_color.g, prot_color.g, 0.01, "Green should match protanopia")
	assert_almost_eq(fill_style.bg_color.b, prot_color.b, 0.01, "Blue should match protanopia")
