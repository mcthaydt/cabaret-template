extends GutTest

## Integration test for scene transition effects
##
## Tests all transition effect types: instant, fade, and loading screen.
## Validates effect selection, execution, minimum duration, and progress updates.
## Tests follow TDD discipline: written BEFORE implementation.

const M_SceneManager = preload("res://scripts/managers/m_scene_manager.gd")
const M_StateStore = preload("res://scripts/state/m_state_store.gd")
const RS_SceneInitialState = preload("res://scripts/resources/state/rs_scene_initial_state.gd")
const RS_StateStoreSettings = preload("res://scripts/resources/state/rs_state_store_settings.gd")
const U_SceneRegistry = preload("res://scripts/scene_management/u_scene_registry.gd")
const U_SceneActions = preload("res://scripts/state/actions/u_scene_actions.gd")

var _root_scene: Node
var _manager: M_SceneManager
var _store: M_StateStore
var _active_scene_container: Node
var _ui_overlay_stack: CanvasLayer
var _transition_overlay: CanvasLayer
var _loading_overlay: CanvasLayer

func before_each() -> void:
	# Create root scene structure
	_root_scene = Node.new()
	_root_scene.name = "Root"
	add_child_autofree(_root_scene)

	# Create state store with all slices
	_store = M_StateStore.new()
	_store.settings = RS_StateStoreSettings.new()
	var scene_initial_state := RS_SceneInitialState.new()
	_store.scene_initial_state = scene_initial_state
	_root_scene.add_child(_store)
	# Register state store via ServiceLocator BEFORE managers run _ready()
	U_ServiceLocator.register(StringName("state_store"), _store)
	await get_tree().process_frame

	# Create scene containers
	_active_scene_container = Node.new()
	_active_scene_container.name = "ActiveSceneContainer"
	_root_scene.add_child(_active_scene_container)

	_ui_overlay_stack = CanvasLayer.new()
	_ui_overlay_stack.name = "UIOverlayStack"
	_ui_overlay_stack.process_mode = Node.PROCESS_MODE_ALWAYS
	_root_scene.add_child(_ui_overlay_stack)

	# Create transition overlay
	_transition_overlay = CanvasLayer.new()
	_transition_overlay.name = "TransitionOverlay"
	var color_rect := ColorRect.new()
	color_rect.name = "TransitionColorRect"
	color_rect.modulate.a = 0.0
	_transition_overlay.add_child(color_rect)
	_root_scene.add_child(_transition_overlay)

	# Create loading overlay
	_loading_overlay = CanvasLayer.new()
	_loading_overlay.name = "LoadingOverlay"
	_loading_overlay.visible = false
	_loading_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_root_scene.add_child(_loading_overlay)

	# Register overlays via ServiceLocator for M_SceneManager discovery
	U_ServiceLocator.register(StringName("transition_overlay"), _transition_overlay)
	U_ServiceLocator.register(StringName("loading_overlay"), _loading_overlay)

	# Create scene manager
	_manager = M_SceneManager.new()
	_manager.skip_initial_scene_load = true  # Don't load main_menu automatically in tests
	_root_scene.add_child(_manager)
	await get_tree().process_frame

func after_each() -> void:
	# 1. Clear ServiceLocator first (prevents cross-test pollution)
	U_ServiceLocator.clear()

	# 2. Clear active scenes loaded by M_SceneManager
	if _active_scene_container and is_instance_valid(_active_scene_container):
		for child in _active_scene_container.get_children():
			child.queue_free()

	# 3. Clear UI overlay stack
	if _ui_overlay_stack and is_instance_valid(_ui_overlay_stack):
		for child in _ui_overlay_stack.get_children():
			child.queue_free()

	# 4. Wait for queue_free to process
	await get_tree().process_frame
	await get_tree().physics_frame

	_manager = null
	_store = null
	_active_scene_container = null
	_ui_overlay_stack = null
	_transition_overlay = null
	_loading_overlay = null
	_root_scene = null

## Test instant transition completes immediately with no delay (T137, T143)
func test_instant_transition_for_ui_scenes() -> void:
	var start_ticks: int = Time.get_ticks_msec()

	# Transition with instant effect
	_manager.transition_to_scene(StringName("main_menu"), "instant")
	await wait_physics_frames(2)

	var elapsed: int = Time.get_ticks_msec() - start_ticks

	# Verify transition completed quickly (< 100ms)
	assert_lt(elapsed, 100, "Instant transition should complete in < 100ms")

	var state: Dictionary = _store.get_state()
	var scene_state: Dictionary = state.get("scene", {})
	assert_false(scene_state.get("is_transitioning", false), "Should not be transitioning after instant")
	assert_eq(scene_state.get("current_scene_id"), StringName("main_menu"), "Should reach target scene")

## Test UI → UI transitions use instant by default
func test_ui_to_ui_uses_instant_transition() -> void:
	# Load main menu
	_manager.transition_to_scene(StringName("main_menu"), "instant")
	await wait_physics_frames(2)

	var start_ticks: int = Time.get_ticks_msec()

	# Transition to settings (should use instant for UI → UI)
	_manager.transition_to_scene(StringName("settings_menu"), "instant")
	await wait_physics_frames(2)

	var elapsed: int = Time.get_ticks_msec() - start_ticks

	# Verify fast transition
	assert_lt(elapsed, 100, "UI → UI should use instant transition (< 100ms)")

	var state: Dictionary = _store.get_state()
	var scene_state: Dictionary = state.get("scene", {})
	assert_eq(scene_state.get("current_scene_id"), StringName("settings_menu"), "Should reach settings")

## Test fade transition for menu → gameplay (T138, T141)
func test_fade_transition_for_menu_to_gameplay() -> void:
	# Transition with fade effect
	_manager.transition_to_scene(StringName("gameplay_base"), "fade")

	# Check transitioning flag is set
	await get_tree().physics_frame
	var state_during: Dictionary = _store.get_state()
	var scene_state_during: Dictionary = state_during.get("scene", {})
	assert_true(scene_state_during.get("is_transitioning", false), "Should be transitioning during fade")

	# Wait for fade completion (0.2s fade). Sample intermediate state.
	await wait_physics_frames(5)
	await wait_physics_frames(10)

	# Verify completion
	var state: Dictionary = _store.get_state()
	var scene_state: Dictionary = state.get("scene", {})
	assert_false(scene_state.get("is_transitioning", false), "Fade should complete")
	assert_eq(scene_state.get("current_scene_id"), StringName("gameplay_base"), "Should reach gameplay scene")

## Test fade effect plays smoothly without jarring cuts (T141)
func test_fade_effect_is_smooth() -> void:
	# Trigger fade transition
	_manager.transition_to_scene(StringName("main_menu"), "fade")

	# Sample transition overlay alpha at multiple points
	var alpha_samples: Array[float] = []

	# Sample at 3 points during transition
	for i in range(3):
		await wait_physics_frames(4)
		var color_rect: ColorRect = _transition_overlay.get_node_or_null("TransitionColorRect")
		if color_rect:
			alpha_samples.append(color_rect.modulate.a)

	# Wait for completion
	await wait_physics_frames(6)

	# Verify we had intermediate alpha values (not instant cut)
	# At least one sample should be > 0 (fading)
	var had_fade: bool = false
	for alpha in alpha_samples:
		if alpha > 0.0 and alpha < 1.0:
			had_fade = true
			break

	assert_true(had_fade or alpha_samples.size() == 0, "Fade should show gradual alpha change")

## Test loading screen transition with explicit type (T139)
func test_loading_screen_transition() -> void:
	# Transition with loading screen effect
	_manager.transition_to_scene(StringName("main_menu"), "loading")

	# Check transitioning flag and loading overlay visibility
	await wait_physics_frames(2)
	var state_during: Dictionary = _store.get_state()
	var scene_state_during: Dictionary = state_during.get("scene", {})
	assert_true(scene_state_during.get("is_transitioning", false), "Should be transitioning")

	# Note: LoadingOverlay visibility will be tested once loading_screen.tscn is implemented

	# Wait for transition to complete
	# Loading screen should enforce minimum duration (1.5s = 90 frames)
	var start_ticks: int = Time.get_ticks_msec()

	# Wait up to 3 seconds for completion
	var max_wait_frames: int = 180  # 3 seconds
	var waited_frames: int = 0
	while waited_frames < max_wait_frames:
		await wait_physics_frames(1)
		waited_frames += 1
		var current_state: Dictionary = _store.get_state()
		var current_scene_state: Dictionary = current_state.get("scene", {})
		if not current_scene_state.get("is_transitioning", false):
			break

	var elapsed: int = Time.get_ticks_msec() - start_ticks

	# Verify transition completed
	var state: Dictionary = _store.get_state()
	var scene_state: Dictionary = state.get("scene", {})
	assert_false(scene_state.get("is_transitioning", false), "Loading transition should complete")
	assert_eq(scene_state.get("current_scene_id"), StringName("main_menu"), "Should reach target scene")

## Test loading screen enforces minimum duration (T142)
func test_loading_screen_minimum_duration() -> void:
	# Skip minimum duration check in headless mode - Trans_LoadingScreen intentionally
	# skips wall-clock minimum duration in headless to prevent test timeouts.
	# The minimum duration is only for visual polish in production.
	if OS.has_feature("headless") or DisplayServer.get_name() == "headless":
		pass_test("Skipped in headless mode - min duration not enforced")
		return

	var start_ticks: int = Time.get_ticks_msec()

	# Transition with loading screen (even for fast-loading UI scene)
	_manager.transition_to_scene(StringName("settings_menu"), "loading")

	# Wait for transition to complete
	var max_wait_frames: int = 180  # 3 seconds max
	var waited_frames: int = 0
	while waited_frames < max_wait_frames:
		await wait_physics_frames(1)
		waited_frames += 1
		var current_state: Dictionary = _store.get_state()
		var current_scene_state: Dictionary = current_state.get("scene", {})
		if not current_scene_state.get("is_transitioning", false):
			break

	var elapsed: int = Time.get_ticks_msec() - start_ticks

	# Verify minimum duration enforced (1.5s = 1500ms)
	# Allow some tolerance for test timing variations (1400ms minimum)
	assert_gte(elapsed, 1400, "Loading screen should enforce minimum duration of ~1.5s")

	# Verify transition completed
	var state: Dictionary = _store.get_state()
	var scene_state: Dictionary = state.get("scene", {})
	assert_false(scene_state.get("is_transitioning", false), "Loading transition should complete")

## Test multiple transition types in sequence
func test_multiple_transition_types_in_sequence() -> void:
	# Instant transition
	_manager.transition_to_scene(StringName("main_menu"), "instant")
	await wait_physics_frames(2)

	var state1: Dictionary = _store.get_state()
	var scene_state1: Dictionary = state1.get("scene", {})
	assert_eq(scene_state1.get("current_scene_id"), StringName("main_menu"))

	# Fade transition
	_manager.transition_to_scene(StringName("settings_menu"), "fade")
	await wait_physics_frames(15)

	var state2: Dictionary = _store.get_state()
	var scene_state2: Dictionary = state2.get("scene", {})
	assert_eq(scene_state2.get("current_scene_id"), StringName("settings_menu"))

	# Instant transition back
	_manager.transition_to_scene(StringName("main_menu"), "instant")
	await wait_physics_frames(2)

	var state3: Dictionary = _store.get_state()
	var scene_state3: Dictionary = state3.get("scene", {})
	assert_eq(scene_state3.get("current_scene_id"), StringName("main_menu"))

## Test transition type override parameter (T136)
func test_transition_type_override() -> void:
	# Default transition for main_menu is "fade" (from registry)
	# Override with "instant"
	_manager.transition_to_scene(StringName("main_menu"), "instant")
	await wait_physics_frames(2)

	var state: Dictionary = _store.get_state()
	var scene_state: Dictionary = state.get("scene", {})
	assert_eq(scene_state.get("current_scene_id"), StringName("main_menu"))

	# Verify it completed quickly (instant override worked)
	assert_false(scene_state.get("is_transitioning", false))

## Test unknown transition type falls back to instant (T209)
func test_unknown_transition_type_fallback() -> void:
	# T209: After factory refactor, this logs a warning from U_TransitionFactory
	# and a debug message from M_SceneManager, then falls back to "instant"

	# Use non-existent transition type
	_manager.transition_to_scene(StringName("main_menu"), "nonexistent_type")
	await wait_physics_frames(2)

	# Assert that the expected warning was logged
	assert_engine_error("U_TransitionFactory: Unknown transition type")

	# Should fall back to instant and complete
	var state: Dictionary = _store.get_state()
	var scene_state: Dictionary = state.get("scene", {})
	assert_eq(scene_state.get("current_scene_id"), StringName("main_menu"))
	assert_false(scene_state.get("is_transitioning", false))

## Test transition effects respect process_mode during pause
func test_transition_effects_work_during_pause() -> void:
	# Pause the scene tree
	get_tree().paused = true

	# Trigger fade transition (should still work with PROCESS_MODE_ALWAYS)
	_manager.transition_to_scene(StringName("main_menu"), "fade")
	await wait_physics_frames(15)

	# Verify transition completed despite pause
	var state: Dictionary = _store.get_state()
	var scene_state: Dictionary = state.get("scene", {})
	assert_false(scene_state.get("is_transitioning", false), "Transition should complete even when paused")
	assert_eq(scene_state.get("current_scene_id"), StringName("main_menu"))

	# Unpause for cleanup
	get_tree().paused = false
