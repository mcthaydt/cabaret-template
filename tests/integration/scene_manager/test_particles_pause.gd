extends GutTest

## Integration: Particle nodes should pause/resume via Scene Manager overlay pause

const M_SCENE_MANAGER := preload("res://scripts/managers/m_scene_manager.gd")
const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")
const M_CURSOR_MANAGER := preload("res://scripts/managers/m_cursor_manager.gd")
const S_PAUSE_SYSTEM := preload("res://scripts/managers/m_pause_manager.gd")
const RS_SCENE_INITIAL_STATE := preload("res://scripts/state/resources/rs_scene_initial_state.gd")
const RS_NAVIGATION_INITIAL_STATE := preload("res://scripts/state/resources/rs_navigation_initial_state.gd")
const U_ServiceLocator := preload("res://scripts/core/u_service_locator.gd")

var _root: Node
var _store: M_STATE_STORE
var _scene_manager: M_SCENE_MANAGER
var _cursor: M_CURSOR_MANAGER
var _pause_system: S_PAUSE_SYSTEM
var _active: Node
var _ui_stack: CanvasLayer

func before_each() -> void:
	_root = Node.new()
	add_child_autofree(_root)

	_store = M_STATE_STORE.new()
	_store.scene_initial_state = RS_SCENE_INITIAL_STATE.new()
	_store.navigation_initial_state = RS_NAVIGATION_INITIAL_STATE.new()
	_root.add_child(_store)

	_cursor = M_CURSOR_MANAGER.new()
	_root.add_child(_cursor)

	_active = Node.new()
	_active.name = "ActiveSceneContainer"
	_root.add_child(_active)

	_ui_stack = CanvasLayer.new()
	_ui_stack.name = "UIOverlayStack"
	_ui_stack.process_mode = Node.PROCESS_MODE_ALWAYS
	_root.add_child(_ui_stack)

	var transition_overlay := CanvasLayer.new()
	transition_overlay.name = "TransitionOverlay"
	_root.add_child(transition_overlay)

	_scene_manager = M_SCENE_MANAGER.new()
	_scene_manager.skip_initial_scene_load = true
	_root.add_child(_scene_manager)

	# Create M_PauseManager (Phase 2: T024b - sole authority for pause/cursor)
	_pause_system = S_PAUSE_SYSTEM.new()
	_root.add_child(_pause_system)

	# Register managers with ServiceLocator (Phase 10B-7: T141c)
	U_ServiceLocator.register(StringName("state_store"), _store)
	U_ServiceLocator.register(StringName("scene_manager"), _scene_manager)
	U_ServiceLocator.register(StringName("cursor_manager"), _cursor)
	U_ServiceLocator.register(StringName("pause_manager"), _pause_system)

	await get_tree().process_frame

func after_each() -> void:
	# Clear ServiceLocator to prevent state leakage
	U_ServiceLocator.clear()

func test_gpu_particles_speed_scale_toggles_on_pause_overlay() -> void:
	# Given: A GPUParticles3D in the active scene
	var particles := GPUParticles3D.new()
	particles.speed_scale = 0.5
	_active.add_child(particles)
	await get_tree().process_frame

	# When: Push pause overlay
	_scene_manager.push_overlay(StringName("pause_menu"))
	await get_tree().process_frame

	# Then: Particle speed_scale set to 0.0
	assert_eq(particles.speed_scale, 0.0, "Particles should be paused (speed_scale=0) when paused")

	# When: Pop pause overlay
	_scene_manager.pop_overlay()
	await get_tree().process_frame

	# Then: Particle speed_scale restored to original value
	assert_eq(particles.speed_scale, 0.5, "Particles speed_scale should be restored on resume")

