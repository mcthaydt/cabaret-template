extends GutTest

const M_SCENE_DIRECTOR := preload("res://scripts/managers/m_scene_director.gd")
const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")
const RS_STATE_STORE_SETTINGS := preload("res://scripts/resources/state/rs_state_store_settings.gd")
const CFG_DIRECTIVE_GAMEPLAY_BASE := preload("res://resources/scene_director/directives/cfg_directive_gameplay_base.tres")
const U_SCENE_ACTIONS := preload("res://scripts/state/actions/u_scene_actions.gd")
const U_SCENE_DIRECTOR_SELECTORS := preload("res://scripts/state/selectors/u_scene_director_selectors.gd")
const U_ECS_EVENT_BUS := preload("res://scripts/events/ecs/u_ecs_event_bus.gd")
const U_ECS_EVENT_NAMES := preload("res://scripts/events/ecs/u_ecs_event_names.gd")

const EVENT_BEAT_ONE := StringName("scene_director_intro_beat_1")
const EVENT_BEAT_TWO := StringName("scene_director_intro_beat_2")
const EVENT_SIGNPOST_MESSAGE := StringName("signpost_message")

var _root: Node
var _state_store: M_STATE_STORE
var _scene_director: M_SCENE_DIRECTOR

func before_each() -> void:
	U_ServiceLocator.clear()
	U_ECS_EVENT_BUS.reset()

	_root = Node.new()
	_root.name = "Root"
	add_child_autofree(_root)

	_state_store = M_STATE_STORE.new()
	_state_store.settings = RS_STATE_STORE_SETTINGS.new()
	_state_store.settings.enable_persistence = false
	_root.add_child(_state_store)
	U_ServiceLocator.register(StringName("state_store"), _state_store)

	_scene_director = M_SCENE_DIRECTOR.new()
	_scene_director.state_store = _state_store
	var directive_resource: Resource = (CFG_DIRECTIVE_GAMEPLAY_BASE as Resource).duplicate(true)
	var directives: Array[Resource] = [directive_resource]
	_scene_director.directives = directives
	_root.add_child(_scene_director)
	U_ServiceLocator.register(StringName("scene_director"), _scene_director)

	await get_tree().process_frame
	await wait_physics_frames(1)

func after_each() -> void:
	if _root != null and is_instance_valid(_root):
		_root.queue_free()
		await get_tree().process_frame
		await get_tree().physics_frame

	U_ServiceLocator.clear()
	U_ECS_EVENT_BUS.reset()

	_root = null
	_state_store = null
	_scene_director = null

func test_scene_transition_starts_directive_and_completes_beats_in_order() -> void:
	var started_payloads: Array[Dictionary] = []
	var completed_payloads: Array[Dictionary] = []
	var beat_event_order: Array[StringName] = []
	var beat_advanced_indices: Array[int] = []
	var signpost_messages: Array[String] = []

	var unsub_start: Callable = U_ECS_EVENT_BUS.subscribe(
		U_ECS_EVENT_NAMES.EVENT_DIRECTIVE_STARTED,
		func(event: Dictionary) -> void:
			_append_payload(started_payloads, event)
	)
	var unsub_complete: Callable = U_ECS_EVENT_BUS.subscribe(
		U_ECS_EVENT_NAMES.EVENT_DIRECTIVE_COMPLETED,
		func(event: Dictionary) -> void:
			_append_payload(completed_payloads, event)
	)
	var unsub_beat_advanced: Callable = U_ECS_EVENT_BUS.subscribe(
		U_ECS_EVENT_NAMES.EVENT_BEAT_ADVANCED,
		func(event: Dictionary) -> void:
			var payload: Dictionary = _extract_payload(event)
			beat_advanced_indices.append(int(payload.get("current_beat_index", -1)))
	)
	var unsub_beat_one: Callable = U_ECS_EVENT_BUS.subscribe(
		EVENT_BEAT_ONE,
		func(_event: Dictionary) -> void:
			beat_event_order.append(EVENT_BEAT_ONE)
	)
	var unsub_beat_two: Callable = U_ECS_EVENT_BUS.subscribe(
		EVENT_BEAT_TWO,
		func(_event: Dictionary) -> void:
			beat_event_order.append(EVENT_BEAT_TWO)
	)
	var unsub_signpost: Callable = U_ECS_EVENT_BUS.subscribe(
		EVENT_SIGNPOST_MESSAGE,
		func(event: Dictionary) -> void:
			var payload: Dictionary = _extract_payload(event)
			signpost_messages.append(String(payload.get("message", "")))
	)

	_state_store.dispatch(U_SCENE_ACTIONS.transition_completed(StringName("gameplay_base")))
	await _wait_for_directive_completion(completed_payloads, 90)

	assert_eq(started_payloads.size(), 1, "Expected one directive_started event")
	assert_eq(completed_payloads.size(), 1, "Expected one directive_completed event")
	if started_payloads.size() > 0:
		assert_eq(
			started_payloads[0].get("directive_id", StringName("")),
			StringName("gameplay_base_intro")
		)
	if completed_payloads.size() > 0:
		assert_eq(
			completed_payloads[0].get("directive_id", StringName("")),
			StringName("gameplay_base_intro")
		)

	var expected_beat_events: Array[StringName] = [EVENT_BEAT_ONE, EVENT_BEAT_TWO]
	assert_eq(beat_event_order, expected_beat_events)
	var expected_advance_indices: Array[int] = [1, 2]
	assert_eq(beat_advanced_indices, expected_advance_indices)
	assert_eq(
		signpost_messages,
		["hud.scene_director_intro_beat_1", "hud.scene_director_intro_beat_2"],
		"Intro beats should publish user-facing signpost messages"
	)

	var state: Dictionary = _state_store.get_state()
	assert_eq(U_SCENE_DIRECTOR_SELECTORS.get_director_state(state), "completed")
	assert_eq(
		U_SCENE_DIRECTOR_SELECTORS.get_active_directive_id(state),
		StringName("gameplay_base_intro")
	)

	if unsub_start.is_valid():
		unsub_start.call()
	if unsub_complete.is_valid():
		unsub_complete.call()
	if unsub_beat_advanced.is_valid():
		unsub_beat_advanced.call()
	if unsub_beat_one.is_valid():
		unsub_beat_one.call()
	if unsub_beat_two.is_valid():
		unsub_beat_two.call()
	if unsub_signpost.is_valid():
		unsub_signpost.call()

func _append_payload(target: Array[Dictionary], event: Dictionary) -> void:
	var payload: Dictionary = _extract_payload(event)
	target.append(payload.duplicate(true))

func _extract_payload(event: Dictionary) -> Dictionary:
	var payload_variant: Variant = event.get("payload", {})
	if payload_variant is Dictionary:
		return payload_variant as Dictionary
	return {}

func _wait_for_directive_completion(completed_payloads: Array[Dictionary], max_frames: int) -> void:
	var frames: int = 0
	while completed_payloads.is_empty() and frames < max_frames:
		await wait_physics_frames(1)
		frames += 1
