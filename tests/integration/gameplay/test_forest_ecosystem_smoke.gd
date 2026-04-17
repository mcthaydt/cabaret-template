extends BaseTest

const M_SCENE_MANAGER := preload("res://scripts/managers/m_scene_manager.gd")
const M_TIME_MANAGER := preload("res://scripts/managers/m_time_manager.gd")
const C_AI_BRAIN_COMPONENT := preload("res://scripts/ecs/components/c_ai_brain_component.gd")
const C_NEEDS_COMPONENT := preload("res://scripts/ecs/components/c_needs_component.gd")
const U_ECS_UTILS := preload("res://scripts/utils/ecs/u_ecs_utils.gd")

const WOLF_PREDATOR_TAG := StringName("predator")
const PREY_TAG := StringName("prey")
const HUNT_LOOP_FEED_EPSILON := 0.05
const HUNT_LOOP_WARMUP_FRAMES := 60
const HUNT_LOOP_POLL_INTERVAL_FRAMES := 30
const HUNT_LOOP_TOTAL_POLL_FRAMES := 900

var _store: M_StateStore
var _active_scene_container: Node
var _ui_overlay_stack: CanvasLayer
var _hud_layer: CanvasLayer
var _transition_overlay: CanvasLayer
var _loading_overlay: CanvasLayer
var _cursor_manager: M_CursorManager
var _spawn_manager: M_SpawnManager
var _camera_manager: M_CameraManager
var _pause_manager: Node

func before_each() -> void:
	super.before_each()

	_active_scene_container = Node.new()
	_active_scene_container.name = "ActiveSceneContainer"
	add_child_autofree(_active_scene_container)
	U_ServiceLocator.register(StringName("active_scene_container"), _active_scene_container)

	_ui_overlay_stack = CanvasLayer.new()
	_ui_overlay_stack.name = "UIOverlayStack"
	add_child_autofree(_ui_overlay_stack)
	U_ServiceLocator.register(StringName("ui_overlay_stack"), _ui_overlay_stack)

	_hud_layer = CanvasLayer.new()
	_hud_layer.name = "HUDLayer"
	add_child_autofree(_hud_layer)
	U_ServiceLocator.register(StringName("hud_layer"), _hud_layer)

	_transition_overlay = CanvasLayer.new()
	_transition_overlay.name = "TransitionOverlay"
	var transition_rect := ColorRect.new()
	transition_rect.name = "TransitionColorRect"
	_transition_overlay.add_child(transition_rect)
	add_child_autofree(_transition_overlay)
	U_ServiceLocator.register(StringName("transition_overlay"), _transition_overlay)

	_loading_overlay = CanvasLayer.new()
	_loading_overlay.name = "LoadingOverlay"
	add_child_autofree(_loading_overlay)
	U_ServiceLocator.register(StringName("loading_overlay"), _loading_overlay)

	_store = M_StateStore.new()
	_store.settings = RS_StateStoreSettings.new()
	_store.settings.enable_persistence = false
	_store.scene_initial_state = RS_SceneInitialState.new()
	add_child_autofree(_store)
	await get_tree().process_frame
	U_ServiceLocator.register(StringName("state_store"), _store)

	_cursor_manager = M_CursorManager.new()
	add_child_autofree(_cursor_manager)
	U_ServiceLocator.register(StringName("cursor_manager"), _cursor_manager)

	_spawn_manager = M_SpawnManager.new()
	add_child_autofree(_spawn_manager)
	U_ServiceLocator.register(StringName("spawn_manager"), _spawn_manager)

	_camera_manager = M_CameraManager.new()
	add_child_autofree(_camera_manager)
	U_ServiceLocator.register(StringName("camera_manager"), _camera_manager)

	_pause_manager = M_TIME_MANAGER.new()
	add_child_autofree(_pause_manager)
	await get_tree().process_frame
	U_ServiceLocator.register(StringName("pause_manager"), _pause_manager)

func after_each() -> void:
	_store = null
	_active_scene_container = null
	_ui_overlay_stack = null
	_hud_layer = null
	_transition_overlay = null
	_loading_overlay = null
	_cursor_manager = null
	_spawn_manager = null
	_camera_manager = null
	_pause_manager = null
	super.after_each()

func test_scene_manager_loads_ai_forest_and_brains_begin_executing() -> void:
	var scene_manager: M_SceneManager = await _spawn_scene_manager()
	scene_manager.transition_to_scene(StringName("ai_forest"), "instant", M_SceneManager.Priority.HIGH)
	await _await_scene(StringName("ai_forest"), 180)

	await get_tree().process_frame
	await get_tree().process_frame
	await wait_physics_frames(60)

	assert_eq(_active_scene_container.get_child_count(), 1, "Expected one active gameplay scene instance.")
	if _active_scene_container.get_child_count() < 1:
		return

	var scene_root: Node = _active_scene_container.get_child(0)
	assert_not_null(
		scene_root.get_node_or_null("Entities/E_PlayerObserver"),
		"ai_forest should include an inert E_Player observer contract node."
	)
	assert_not_null(
		scene_root.get_node_or_null("Entities/SpawnPoints/sp_default"),
		"ai_forest should include a sp_default contract spawn point."
	)

	var ecs_manager: I_ECSManager = scene_root.get_node_or_null("Managers/M_ECSManager") as I_ECSManager
	assert_not_null(ecs_manager, "Expected M_ECSManager in ai_forest scene.")
	if ecs_manager == null:
		return

	var brains: Array = ecs_manager.get_components(C_AIBrainComponent.COMPONENT_TYPE)
	assert_false(brains.is_empty(), "Expected at least one C_AIBrainComponent in ai_forest scene.")
	if brains.is_empty():
		return

	for brain_variant in brains:
		var brain: C_AIBrainComponent = brain_variant as C_AIBrainComponent
		assert_not_null(brain, "Expected typed C_AIBrainComponent entries from ECS manager.")
		if brain == null:
			continue
		assert_ne(brain.get_active_goal_id(), StringName(""), "Brain should have an active goal after warm-up.")
		assert_true(brain.current_task_queue.size() > 0, "Brain should have a non-empty current task queue after warm-up.")

func test_wolves_close_hunt_loop_and_refill_hunger() -> void:
	var scene_manager: M_SceneManager = await _spawn_scene_manager()
	scene_manager.transition_to_scene(StringName("ai_forest"), "instant", M_SceneManager.Priority.HIGH)
	await _await_scene(StringName("ai_forest"), 180)

	await get_tree().process_frame
	await get_tree().process_frame
	await wait_physics_frames(HUNT_LOOP_WARMUP_FRAMES)

	assert_eq(_active_scene_container.get_child_count(), 1, "Expected one active gameplay scene instance.")
	if _active_scene_container.get_child_count() < 1:
		return

	var scene_root: Node = _active_scene_container.get_child(0)
	var ecs_manager: I_ECSManager = scene_root.get_node_or_null("Managers/M_ECSManager") as I_ECSManager
	assert_not_null(ecs_manager, "Expected M_ECSManager in ai_forest scene.")
	if ecs_manager == null:
		return

	var wolf_needs: Array[C_NeedsComponent] = _collect_wolf_needs(ecs_manager)
	assert_false(wolf_needs.is_empty(), "Expected at least one wolf C_NeedsComponent in ai_forest scene.")
	if wolf_needs.is_empty():
		return

	var initial_prey_count: int = _count_prey_entities(ecs_manager)
	assert_gt(initial_prey_count, 0, "Expected at least one prey-tagged entity in ai_forest scene.")
	if initial_prey_count <= 0:
		return

	var prev_hunger_per_wolf: Dictionary = {}
	for needs in wolf_needs:
		prev_hunger_per_wolf[needs.get_instance_id()] = needs.hunger

	var any_wolf_fed: bool = false
	var any_prey_consumed: bool = false
	var elapsed_frames: int = 0
	while elapsed_frames < HUNT_LOOP_TOTAL_POLL_FRAMES and (not any_wolf_fed or not any_prey_consumed):
		await wait_physics_frames(HUNT_LOOP_POLL_INTERVAL_FRAMES)
		elapsed_frames += HUNT_LOOP_POLL_INTERVAL_FRAMES
		for needs in _collect_wolf_needs(ecs_manager):
			var key: int = needs.get_instance_id()
			var prev: float = float(prev_hunger_per_wolf.get(key, needs.hunger))
			if needs.hunger > prev + HUNT_LOOP_FEED_EPSILON:
				any_wolf_fed = true
				break
			prev_hunger_per_wolf[key] = needs.hunger
		var current_prey_count: int = _count_prey_entities(ecs_manager)
		if current_prey_count < initial_prey_count:
			any_prey_consumed = true

	assert_true(
		any_wolf_fed,
		"Expected at least one wolf to feed (hunger to rise above prior tick by %.2f) within %d physics frames; hunt loop is stuck." % [HUNT_LOOP_FEED_EPSILON, HUNT_LOOP_TOTAL_POLL_FRAMES]
	)
	assert_true(
		any_prey_consumed,
		"Expected wolf hunt feed loop to consume at least one prey-tagged entity within %d physics frames." % [HUNT_LOOP_TOTAL_POLL_FRAMES]
	)

func _collect_wolf_needs(ecs_manager: I_ECSManager) -> Array[C_NeedsComponent]:
	var result: Array[C_NeedsComponent] = []
	if ecs_manager == null:
		return result
	for needs_variant in ecs_manager.get_components(C_NEEDS_COMPONENT.COMPONENT_TYPE):
		var needs: C_NeedsComponent = needs_variant as C_NeedsComponent
		if needs == null or not is_instance_valid(needs):
			continue
		var entity_root: Node = U_ECS_UTILS.find_entity_root(needs)
		var entity_typed: BaseECSEntity = entity_root as BaseECSEntity
		if entity_typed == null:
			continue
		if entity_typed.has_tag(WOLF_PREDATOR_TAG):
			result.append(needs)
	return result

func _count_prey_entities(ecs_manager: I_ECSManager) -> int:
	if ecs_manager == null:
		return 0
	var count: int = 0
	for needs_variant in ecs_manager.get_components(C_NEEDS_COMPONENT.COMPONENT_TYPE):
		var needs: C_NeedsComponent = needs_variant as C_NeedsComponent
		if needs == null or not is_instance_valid(needs):
			continue
		var entity_root: Node = U_ECS_UTILS.find_entity_root(needs)
		var entity_typed: BaseECSEntity = entity_root as BaseECSEntity
		if entity_typed == null:
			continue
		if entity_typed.has_tag(PREY_TAG):
			count += 1
	return count

func _spawn_scene_manager() -> M_SceneManager:
	var manager := M_SCENE_MANAGER.new()
	manager.skip_initial_scene_load = true
	add_child_autofree(manager)
	await get_tree().process_frame
	U_ServiceLocator.register(StringName("scene_manager"), manager)
	return manager

func _await_scene(scene_id: StringName, limit_frames: int = 120) -> void:
	for _i in range(limit_frames):
		var state: Dictionary = _store.get_state()
		var scene_state: Dictionary = state.get("scene", {})
		var current_scene_id: StringName = scene_state.get("current_scene_id", StringName(""))
		var is_transitioning: bool = bool(scene_state.get("is_transitioning", false))
		if current_scene_id == scene_id and not is_transitioning:
			return
		await wait_physics_frames(1)
	assert_true(false, "Timed out waiting for scene_id %s" % scene_id)
