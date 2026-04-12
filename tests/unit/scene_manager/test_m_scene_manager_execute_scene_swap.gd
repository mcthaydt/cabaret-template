extends GutTest

## Unit tests for M_SceneManager._execute_scene_swap
##
## Tests the scene swap execution path: cache, sync load, camera blend,
## camera initialize, store dispatch, handler dispatch, and writeback.
## Hybrid approach: real nodes for tree structure, mock camera manager,
## pre-seeded scene cache, stub scene loader.

const M_SceneManager = preload("res://scripts/managers/m_scene_manager.gd")
const M_StateStore = preload("res://scripts/state/m_state_store.gd")
const RS_SceneInitialState = preload("res://scripts/resources/state/rs_scene_initial_state.gd")
const RS_StateStoreSettings = preload("res://scripts/resources/state/rs_state_store_settings.gd")
const U_ServiceLocator = preload("res://scripts/core/u_service_locator.gd")
const U_SceneActions = preload("res://scripts/state/actions/u_scene_actions.gd")
const MockCameraManager = preload("res://tests/mocks/mock_camera_manager.gd")
const U_SceneLoader = preload("res://scripts/scene_management/helpers/u_scene_loader.gd")
const I_SCENE_TYPE_HANDLER = preload("res://scripts/interfaces/i_scene_type_handler.gd")
const U_TransitionState = preload("res://scripts/scene_management/helpers/u_transition_state.gd")

var _manager: M_SceneManager
var _store: M_StateStore
var _active_scene_container: Node
var _ui_overlay_stack: CanvasLayer
var _transition_overlay: CanvasLayer
var _loading_overlay: CanvasLayer

class StubSceneLoader extends U_SceneLoader:
	var loaded_scene: Node = null
	var remove_calls: int = 0
	var add_calls: int = 0

	func load_scene(_scene_path: String) -> Node:
		return loaded_scene

	func load_scene_async(_scene_path: String, _progress_callback: Callable, _background_loads: Dictionary) -> Node:
		return loaded_scene

	func remove_current_scene(container: Node) -> void:
		remove_calls += 1
		if container == null:
			return
		for child in container.get_children():
			child.process_mode = Node.PROCESS_MODE_DISABLED
			container.remove_child(child)
			child.queue_free()

	func add_scene(container: Node, scene: Node) -> void:
		add_calls += 1
		if container == null or scene == null:
			return
		container.add_child(scene)

class StubSceneTypeHandler extends I_SCENE_TYPE_HANDLER:
	var on_load_calls: int = 0
	var last_scene_id: StringName = StringName("")
	var last_managers: Dictionary = {}

	func on_load(scene: Node, scene_id: StringName, managers: Dictionary) -> void:
		on_load_calls += 1
		last_scene_id = scene_id
		last_managers = managers

func before_each() -> void:
	U_ServiceLocator.clear()

	var existing := get_tree().root.find_child("HUDLayer", true, false)
	if existing == null:
		var hud_layer := CanvasLayer.new()
		hud_layer.name = "HUDLayer"
		add_child_autofree(hud_layer)
		U_ServiceLocator.register(StringName("hud_layer"), hud_layer)
	else:
		U_ServiceLocator.register(StringName("hud_layer"), existing)

	_store = M_StateStore.new()
	_store.settings = RS_StateStoreSettings.new()
	_store.settings.enable_persistence = false
	var scene_initial_state := RS_SceneInitialState.new()
	_store.scene_initial_state = scene_initial_state
	add_child_autofree(_store)
	U_ServiceLocator.register(StringName("state_store"), _store)
	await get_tree().process_frame

	_active_scene_container = Node.new()
	_active_scene_container.name = "ActiveSceneContainer"
	add_child_autofree(_active_scene_container)
	U_ServiceLocator.register(StringName("active_scene_container"), _active_scene_container)

	_ui_overlay_stack = CanvasLayer.new()
	_ui_overlay_stack.name = "UIOverlayStack"
	add_child_autofree(_ui_overlay_stack)
	U_ServiceLocator.register(StringName("ui_overlay_stack"), _ui_overlay_stack)

	_transition_overlay = CanvasLayer.new()
	_transition_overlay.name = "TransitionOverlay"
	var color_rect := ColorRect.new()
	color_rect.name = "TransitionColorRect"
	_transition_overlay.add_child(color_rect)
	add_child_autofree(_transition_overlay)
	U_ServiceLocator.register(StringName("transition_overlay"), _transition_overlay)

	_loading_overlay = CanvasLayer.new()
	_loading_overlay.name = "LoadingOverlay"
	add_child_autofree(_loading_overlay)
	U_ServiceLocator.register(StringName("loading_overlay"), _loading_overlay)

	_manager = M_SceneManager.new()
	_manager.skip_initial_scene_load = true
	add_child_autofree(_manager)
	U_ServiceLocator.register(StringName("scene_manager"), _manager)
	await get_tree().process_frame

func after_each() -> void:
	U_ServiceLocator.clear()
	_manager = null
	_store = null
	_active_scene_container = null
	_ui_overlay_stack = null
	_transition_overlay = null
	_loading_overlay = null


func _create_transition_ctx(use_cached: bool, should_blend: bool, old_camera_state: Variant) -> Dictionary:
	var transition_state := U_TransitionState.new()
	transition_state.should_blend = should_blend
	transition_state.old_camera_state = old_camera_state
	return {
		"use_cached": use_cached,
		"progress_callback": func(_p: float): pass,
		"transition_state": transition_state,
	}


# --- _execute_scene_swap tests ---

func test_execute_scene_swap_cached_scene_instantiates() -> void:
	var stub_loader := StubSceneLoader.new()
	_manager._scene_loader = stub_loader

	# Pre-seed the scene cache with a PackedScene
	var cached_packed := PackedScene.new()
	var cache_node := Node3D.new()
	cache_node.name = "CachedSceneNode"
	add_child_autofree(cache_node)
	var pack_result: int = cached_packed.pack(cache_node)
	assert_eq(pack_result, OK, "PackedScene.pack should succeed for cache test.")

	_manager._scene_cache_helper._scene_cache["res://cached_scene.tscn"] = cached_packed
	var request := {"scene_id": StringName("test_cached"), "transition_type": "fade"}
	var ctx := _create_transition_ctx(true, false, null)

	_manager._execute_scene_swap(request, "res://cached_scene.tscn", ctx)
	# The cache path should have been attempted; new_scene_ref should be set
	# (CachedSceneNode from the packed scene, not the stub_loader's scene)
	var transition_state: U_TransitionState = ctx.get("transition_state", null)
	assert_not_null(transition_state, "transition_state should exist")
	assert_ne(transition_state.new_scene_ref, null, "Cached scene should be instantiated and set in transition state new_scene_ref.")

	_manager._scene_cache_helper._scene_cache.clear()


func test_execute_scene_swap_sync_load_path() -> void:
	var stub_loader := StubSceneLoader.new()
	var test_scene := Node3D.new()
	test_scene.name = "LoadedScene"
	stub_loader.loaded_scene = test_scene
	_manager._scene_loader = stub_loader

	var request := {"scene_id": StringName("test_scene"), "transition_type": "fade"}
	var ctx := _create_transition_ctx(false, false, null)

	_manager._execute_scene_swap(request, "res://test_scene.tscn", ctx)
	var transition_state: U_TransitionState = ctx.get("transition_state", null)
	assert_not_null(transition_state, "transition_state should exist")
	assert_eq(transition_state.new_scene_ref, test_scene, "Sync load should set new_scene_ref to loaded scene.")


func test_execute_scene_swap_load_failure_returns_early() -> void:
	var stub_loader := StubSceneLoader.new()
	stub_loader.loaded_scene = null
	_manager._scene_loader = stub_loader

	var request := {"scene_id": StringName("nonexistent_scene"), "transition_type": "fade"}
	var ctx := _create_transition_ctx(false, false, null)

	_manager._execute_scene_swap(request, "res://nonexistent.tscn", ctx)
	assert_push_error("M_SceneManager: Failed to load scene 'res://nonexistent.tscn'")
	var transition_state: U_TransitionState = ctx.get("transition_state", null)
	assert_not_null(transition_state, "transition_state should exist")
	assert_eq(transition_state.new_scene_ref, null, "Load failure should not set new_scene_ref.")


func test_execute_scene_swap_camera_blend_path() -> void:
	var stub_loader := StubSceneLoader.new()
	var test_scene := Node3D.new()
	test_scene.name = "BlendTestScene"
	stub_loader.loaded_scene = test_scene
	_manager._scene_loader = stub_loader

	var mock_camera := MockCameraManager.new()
	autofree(mock_camera)
	mock_camera.main_camera = Camera3D.new()
	add_child_autofree(mock_camera.main_camera)
	_manager._camera_manager = mock_camera

	var request := {"scene_id": StringName("test_blend"), "transition_type": "fade"}
	var old_state := {"position": Vector3.ZERO}
	var ctx := _create_transition_ctx(false, true, old_state)

	_manager._execute_scene_swap(request, "res://test_blend.tscn", ctx)
	assert_eq(mock_camera.blend_cameras_calls, 1, "Camera blend should be called once.")
	assert_eq(mock_camera.blend_cameras_last_args.get("duration"), 0.2, "Blend duration should be 0.2.")
	assert_eq(mock_camera.blend_cameras_last_args.get("old_state"), old_state, "Blend should receive old_camera_state.")


func test_execute_scene_swap_camera_initialize_path() -> void:
	var stub_loader := StubSceneLoader.new()
	var test_scene := Node3D.new()
	test_scene.name = "InitCameraScene"
	stub_loader.loaded_scene = test_scene
	_manager._scene_loader = stub_loader

	var test_camera := Camera3D.new()
	add_child_autofree(test_camera)

	var mock_camera := MockCameraManager.new()
	autofree(mock_camera)
	mock_camera.main_camera = test_camera
	mock_camera.captured_camera_state = null
	_manager._camera_manager = mock_camera

	var request := {"scene_id": StringName("test_init"), "transition_type": "instant"}
	var ctx := _create_transition_ctx(false, false, null)

	_manager._execute_scene_swap(request, "res://test_init.tscn", ctx)
	# When should_blend is false, initialize_scene_camera is called instead of blend_cameras
	# No blend should happen
	assert_eq(mock_camera.blend_cameras_calls, 0, "Camera blend should NOT be called when should_blend is false.")


func test_execute_scene_swap_dispatches_store_action() -> void:
	var stub_loader := StubSceneLoader.new()
	var test_scene := Node3D.new()
	test_scene.name = "StoreActionScene"
	stub_loader.loaded_scene = test_scene
	_manager._scene_loader = stub_loader
	_manager._store = _store

	# Subscribe to state store to detect dispatched actions
	var scene_id_dispatched := [StringName("")]
	var callback_called := [false]
	_store.subscribe(func(action: Dictionary, _state: Dictionary) -> void:
		if action.get("type", StringName("")) == U_SceneActions.ACTION_SCENE_SWAPPED:
			var payload: Dictionary = action.get("payload", {})
			scene_id_dispatched[0] = payload.get("scene_id", StringName(""))
			callback_called[0] = true
	)

	var request := {"scene_id": StringName("test_dispatch"), "transition_type": "fade"}
	var ctx := _create_transition_ctx(false, false, null)

	_manager._execute_scene_swap(request, "res://test_dispatch.tscn", ctx)
	assert_true(callback_called[0], "Store should dispatch scene_swapped action.")
	assert_eq(scene_id_dispatched[0], StringName("test_dispatch"), "Dispatched scene_id should match request.")


func test_execute_scene_swap_calls_scene_type_handler() -> void:
	var stub_loader := StubSceneLoader.new()
	var test_scene := Node3D.new()
	test_scene.name = "HandlerTestScene"
	stub_loader.loaded_scene = test_scene
	_manager._scene_loader = stub_loader

	var stub_handler := StubSceneTypeHandler.new()
	# Use a scene_type that's not in the registry — fallback behavior
	_manager._scene_type_handlers[-1] = stub_handler

	var request := {"scene_id": StringName("test_handler"), "transition_type": "fade"}
	var ctx := _create_transition_ctx(false, false, null)

	_manager._execute_scene_swap(request, "res://test_handler.tscn", ctx)
	# Handler should be called if scene_type matches a registered handler
	assert_eq(stub_handler.on_load_calls, 1, "Scene type handler should be called once.")
	assert_eq(stub_handler.last_scene_id, StringName("test_handler"), "Handler should receive correct scene_id.")

	_manager._scene_type_handlers.erase(-1)


func test_execute_scene_swap_writes_new_scene_ref() -> void:
	var stub_loader := StubSceneLoader.new()
	var test_scene := Node3D.new()
	test_scene.name = "RefWritebackScene"
	stub_loader.loaded_scene = test_scene
	_manager._scene_loader = stub_loader

	var request := {"scene_id": StringName("test_ref"), "transition_type": "fade"}
	var ctx := _create_transition_ctx(false, false, null)

	_manager._execute_scene_swap(request, "res://test_ref.tscn", ctx)
	var transition_state: U_TransitionState = ctx.get("transition_state", null)
	assert_not_null(transition_state, "transition_state should exist")
	assert_eq(transition_state.new_scene_ref, test_scene, "transition_state.new_scene_ref should be set to the loaded scene.")
