extends GutTest

## Unit tests for M_SceneManager._perform_transition decomposition
##
## Tests the extracted methods: _prepare_transition_context, _execute_scene_swap,
## _finalize_camera_blend. Written BEFORE implementation (TDD RED).
##
## These methods were extracted from the 155-line _perform_transition god method
## as part of cleanup-v7 C6 Commit 4.

const M_SceneManager = preload("res://scripts/core/managers/m_scene_manager.gd")
const M_StateStore = preload("res://scripts/core/state/m_state_store.gd")
const RS_SceneInitialState = preload("res://scripts/core/resources/state/rs_scene_initial_state.gd")
const RS_StateStoreSettings = preload("res://scripts/core/resources/state/rs_state_store_settings.gd")
const U_ServiceLocator = preload("res://scripts/core/u_service_locator.gd")
const MockCameraManager = preload("res://tests/mocks/mock_camera_manager.gd")
const U_TransitionState = preload("res://scripts/core/scene_management/helpers/u_transition_state.gd")

var _manager: M_SceneManager
var _store: M_StateStore
var _active_scene_container: Node
var _transition_overlay: CanvasLayer
var _loading_overlay: CanvasLayer
var _ui_overlay_stack: CanvasLayer

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

# --- _prepare_transition_context tests ---

func test_prepare_context_returns_required_keys() -> void:
	var request := {"scene_id": StringName("test_scene"), "transition_type": "fade"}
	var ctx := _manager._prepare_transition_context(request, "res://test.tscn")
	assert_has(ctx, "use_cached", "context should have use_cached")
	assert_has(ctx, "progress_callback", "context should have progress_callback")
	assert_has(ctx, "transition_state", "context should have transition_state")

func test_prepare_context_use_cached_false_when_not_cached() -> void:
	var request := {"scene_id": StringName("test_scene"), "transition_type": "fade"}
	var ctx := _manager._prepare_transition_context(request, "res://not_cached.tscn")
	assert_eq(bool(ctx.get("use_cached", true)), false, "use_cached should be false for uncached scene")

func test_prepare_context_should_blend_false_without_camera_manager() -> void:
	_manager._camera_manager = null
	var request := {"scene_id": StringName("test_scene"), "transition_type": "fade"}
	var ctx := _manager._prepare_transition_context(request, "res://test.tscn")
	var transition_state: U_TransitionState = ctx.get("transition_state", null)
	assert_not_null(transition_state, "transition_state should be created")
	assert_false(transition_state.should_blend, "should_blend should be false when no camera manager")

func test_prepare_context_should_blend_false_for_instant_transition() -> void:
	# Even if camera manager exists, instant transitions don't blend
	_manager._camera_manager = null  # No camera manager registered
	var request := {"scene_id": StringName("test_scene"), "transition_type": "instant"}
	var ctx := _manager._prepare_transition_context(request, "res://test.tscn")
	var transition_state: U_TransitionState = ctx.get("transition_state", null)
	assert_not_null(transition_state, "transition_state should be created")
	assert_false(transition_state.should_blend, "should_blend should be false for instant transitions")

func test_prepare_context_new_scene_ref_initially_null() -> void:
	var request := {"scene_id": StringName("test_scene"), "transition_type": "fade"}
	var ctx := _manager._prepare_transition_context(request, "res://test.tscn")
	var transition_state: U_TransitionState = ctx.get("transition_state", null)
	assert_not_null(transition_state, "transition_state should be created")
	assert_eq(transition_state.new_scene_ref, null, "new_scene_ref should initially be null")

func test_prepare_context_progress_callback_is_callable() -> void:
	var request := {"scene_id": StringName("test_scene"), "transition_type": "fade"}
	var ctx := _manager._prepare_transition_context(request, "res://test.tscn")
	var progress_cb: Callable = ctx.get("progress_callback", Callable())
	assert_true(progress_cb.is_valid(), "progress_callback should be a valid Callable")

# --- _finalize_camera_blend tests ---

func test_finalize_blend_skips_when_camera_manager_null() -> void:
	_manager._camera_manager = null
	var new_scene := Node3D.new()
	add_child_autofree(new_scene)
	var transition_state := U_TransitionState.new()
	transition_state.new_scene_ref = new_scene
	var transition_ctx := {"transition_state": transition_state}
	_manager._finalize_camera_blend(transition_ctx)
	assert_eq(transition_state.new_scene_ref, new_scene, "Skip path should leave new_scene_ref unchanged when camera manager is null.")

func test_finalize_blend_skips_when_new_scene_ref_null() -> void:
	var mock_camera := MockCameraManager.new()
	autofree(mock_camera)
	_manager._camera_manager = mock_camera
	var transition_state := U_TransitionState.new()
	var transition_ctx := {"transition_state": transition_state}
	_manager._finalize_camera_blend(transition_ctx)
	assert_eq(mock_camera.finalize_blend_calls, 0, "Finalize should be skipped when new_scene_ref is null.")

func test_finalize_blend_skips_when_new_scene_ref_key_missing() -> void:
	var mock_camera := MockCameraManager.new()
	autofree(mock_camera)
	_manager._camera_manager = mock_camera
	var transition_ctx := {}
	_manager._finalize_camera_blend(transition_ctx)
	assert_eq(mock_camera.finalize_blend_calls, 0, "Finalize should be skipped when transition_ctx has no new_scene_ref key.")

func test_finalize_blend_uses_camera_manager_is_blend_active() -> void:
	var mock_camera := MockCameraManager.new()
	autofree(mock_camera)
	_manager._camera_manager = mock_camera
	var new_scene := Node3D.new()
	add_child_autofree(new_scene)
	var transition_state := U_TransitionState.new()
	transition_state.new_scene_ref = new_scene
	var transition_ctx := {"transition_state": transition_state}

	mock_camera.blend_active = true
	_manager._finalize_camera_blend(transition_ctx)
	assert_eq(mock_camera.finalize_blend_calls, 0, "Finalize should not run when camera manager reports active blend.")

	mock_camera.blend_active = false
	_manager._finalize_camera_blend(transition_ctx)
	assert_eq(mock_camera.finalize_blend_calls, 1, "Finalize should run once when no active blend is reported.")

# --- _perform_transition line count test ---

func test_perform_transition_under_40_lines() -> void:
	var script := load("res://scripts/core/managers/m_scene_manager.gd") as GDScript
	var source: String = script.source_code
	var lines := source.split("\n")

	# Find _perform_transition method boundaries
	var start_line: int = -1
	var end_line: int = -1
	for i in range(lines.size()):
		var stripped: String = lines[i].strip_edges(true, false)
		if start_line == -1:
			if stripped.begins_with("func _perform_transition("):
				start_line = i
		elif stripped.begins_with("func ") and not stripped.begins_with("func _perform_transition("):
			# Account for possible blank lines between methods
			# Walk backwards to find the last non-blank, non-comment line
			end_line = i
			# Check backwards for trailing blank lines
			while end_line > start_line and lines[end_line - 1].strip_edges(true, false).is_empty():
				end_line -= 1
			break

	assert_gt(start_line, -1, "_perform_transition method should exist")
	assert_gt(end_line, start_line, "_perform_transition should have an end boundary")

	var method_lines := end_line - start_line
	assert_lt(method_lines, 40, "_perform_transition should be under 40 lines, got %d" % method_lines)
