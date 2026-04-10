extends BaseTest

## Integration test for Milestone 15: Player-NPC Interaction Triggers.
## Validates the full pipeline from player proximity detection through
## flag dispatch, ECS event publication, and alarm relay cascading.

const S_AI_DETECTION_SYSTEM_PATH := "res://scripts/ecs/systems/s_ai_detection_system.gd"
const S_AI_DEMO_ALARM_RELAY_SYSTEM_PATH := "res://scripts/ecs/systems/s_ai_demo_alarm_relay_system.gd"

const BASE_ECS_SYSTEM := preload("res://scripts/ecs/base_ecs_system.gd")
const MOCK_ECS_MANAGER := preload("res://tests/mocks/mock_ecs_manager.gd")
const MOCK_STATE_STORE := preload("res://tests/mocks/mock_state_store.gd")

const C_DETECTION_COMPONENT := preload("res://scripts/ecs/components/c_detection_component.gd")
const C_MOVEMENT_COMPONENT := preload("res://scripts/ecs/components/c_movement_component.gd")
const C_PLAYER_TAG_COMPONENT := preload("res://scripts/ecs/components/c_player_tag_component.gd")
const RS_MOVEMENT_SETTINGS := preload("res://scripts/resources/ecs/rs_movement_settings.gd")
const U_GAMEPLAY_ACTIONS := preload("res://scripts/state/actions/u_gameplay_actions.gd")
const U_ECS_EVENT_BUS := preload("res://scripts/events/ecs/u_ecs_event_bus.gd")

class FakeBody extends CharacterBody3D:
	pass

func before_each() -> void:
	U_ECS_EVENT_BUS.reset()

func after_each() -> void:
	U_ECS_EVENT_BUS.reset()

# ---------------------------------------------------------------
# Fixture helpers
# ---------------------------------------------------------------

func _create_entity(root: Node3D, name: String, position: Vector3) -> Dictionary:
	var entity := Node3D.new()
	entity.name = name
	root.add_child(entity)
	autofree(entity)

	var body := FakeBody.new()
	entity.add_child(body)
	autofree(body)
	body.global_position = position

	var movement: C_MovementComponent = C_MOVEMENT_COMPONENT.new()
	movement.settings = RS_MOVEMENT_SETTINGS.new()
	entity.add_child(movement)
	autofree(movement)

	return {
		"entity": entity,
		"body": body,
		"movement": movement,
	}

## Detection-only fixture (no alarm relay) for isolated detection tests.
func _create_detection_fixture() -> Dictionary:
	var detection_script: Script = load(S_AI_DETECTION_SYSTEM_PATH) as Script
	assert_not_null(detection_script)
	if detection_script == null:
		return {}
	var detection_system: BaseECSSystem = detection_script.new() as BaseECSSystem
	autofree(detection_system)

	var root := Node3D.new()
	add_child_autofree(root)

	var ecs_manager := MOCK_ECS_MANAGER.new()
	autofree(ecs_manager)
	var store := MOCK_STATE_STORE.new()
	autofree(store)

	detection_system.ecs_manager = ecs_manager
	detection_system.state_store = store
	root.add_child(detection_system)
	detection_system.configure(ecs_manager)

	# Player entity
	var player_data: Dictionary = _create_entity(root, "E_Player", Vector3.ZERO)
	var player_entity: Node3D = player_data.get("entity") as Node3D
	var player_movement: C_MovementComponent = player_data.get("movement") as C_MovementComponent
	var player_tag: C_PlayerTagComponent = C_PLAYER_TAG_COMPONENT.new()
	player_entity.add_child(player_tag)
	autofree(player_tag)
	ecs_manager.add_component_to_entity(player_entity, player_movement)
	ecs_manager.add_component_to_entity(player_entity, player_tag)

	# NPC with detection (starts far away)
	var npc_data: Dictionary = _create_entity(root, "E_NPC", Vector3(20.0, 0.0, 0.0))
	var npc_entity: Node3D = npc_data.get("entity") as Node3D
	var npc_movement: C_MovementComponent = npc_data.get("movement") as C_MovementComponent
	var detection: C_DetectionComponent = C_DETECTION_COMPONENT.new()
	detection.ai_flag_id = StringName("power_core_proximity")
	detection.detection_radius = 6.0
	detection.enter_event_name = StringName("ai_alarm_triggered")
	detection.enter_event_payload = {"source": StringName("sentry")}
	npc_entity.add_child(detection)
	autofree(detection)
	ecs_manager.add_component_to_entity(npc_entity, npc_movement)
	ecs_manager.add_component_to_entity(npc_entity, detection)

	return {
		"detection_system": detection_system,
		"ecs_manager": ecs_manager,
		"store": store,
		"player": player_data,
		"npc": npc_data,
		"detection": detection,
	}

## Full fixture with both detection and alarm relay for end-to-end tests.
func _create_full_fixture() -> Dictionary:
	var detection_script: Script = load(S_AI_DETECTION_SYSTEM_PATH) as Script
	assert_not_null(detection_script)
	if detection_script == null:
		return {}
	var detection_system: BaseECSSystem = detection_script.new() as BaseECSSystem
	autofree(detection_system)

	var relay_script: Script = load(S_AI_DEMO_ALARM_RELAY_SYSTEM_PATH) as Script
	assert_not_null(relay_script)
	if relay_script == null:
		return {}
	var relay_system: BaseECSSystem = relay_script.new() as BaseECSSystem
	autofree(relay_system)

	var root := Node3D.new()
	add_child_autofree(root)

	var ecs_manager := MOCK_ECS_MANAGER.new()
	autofree(ecs_manager)
	var store := MOCK_STATE_STORE.new()
	autofree(store)

	detection_system.ecs_manager = ecs_manager
	detection_system.state_store = store
	root.add_child(detection_system)
	detection_system.configure(ecs_manager)

	relay_system.ecs_manager = ecs_manager
	relay_system.state_store = store
	root.add_child(relay_system)
	var relay_flags: Array[StringName] = [
		StringName("power_core_activated"),
		StringName("power_core_proximity"),
		StringName("comms_disturbance_heard"),
		StringName("comms_disturbance_proximity"),
	]
	relay_system.relay_flag_ids = relay_flags
	relay_system.configure(ecs_manager)

	# Player entity
	var player_data: Dictionary = _create_entity(root, "E_Player", Vector3.ZERO)
	var player_entity: Node3D = player_data.get("entity") as Node3D
	var player_movement: C_MovementComponent = player_data.get("movement") as C_MovementComponent
	var player_tag: C_PlayerTagComponent = C_PLAYER_TAG_COMPONENT.new()
	player_entity.add_child(player_tag)
	autofree(player_tag)
	ecs_manager.add_component_to_entity(player_entity, player_movement)
	ecs_manager.add_component_to_entity(player_entity, player_tag)

	# NPC with detection (starts far away)
	var npc_data: Dictionary = _create_entity(root, "E_NPC", Vector3(20.0, 0.0, 0.0))
	var npc_entity: Node3D = npc_data.get("entity") as Node3D
	var npc_movement: C_MovementComponent = npc_data.get("movement") as C_MovementComponent
	var detection: C_DetectionComponent = C_DETECTION_COMPONENT.new()
	detection.ai_flag_id = StringName("power_core_proximity")
	detection.detection_radius = 6.0
	detection.enter_event_name = StringName("ai_alarm_triggered")
	detection.enter_event_payload = {"source": StringName("sentry")}
	npc_entity.add_child(detection)
	autofree(detection)
	ecs_manager.add_component_to_entity(npc_entity, npc_movement)
	ecs_manager.add_component_to_entity(npc_entity, detection)

	return {
		"detection_system": detection_system,
		"relay_system": relay_system,
		"ecs_manager": ecs_manager,
		"store": store,
		"player": player_data,
		"npc": npc_data,
		"detection": detection,
	}

# ---------------------------------------------------------------
# Test 1: Proximity detection dispatches flag via state store
# ---------------------------------------------------------------

func test_proximity_dispatches_flag_to_state_store() -> void:
	var fixture: Dictionary = _create_detection_fixture()
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var detection_system: BaseECSSystem = fixture["detection_system"]
	var store: MockStateStore = fixture["store"]
	var npc: Dictionary = fixture["npc"] as Dictionary
	var npc_body: FakeBody = npc.get("body") as FakeBody
	var detection: C_DetectionComponent = fixture["detection"]

	# Move NPC within detection range of the player
	npc_body.global_position = Vector3(4.0, 0.0, 0.0)
	detection_system.process_tick(0.016)
	detection_system.process_tick(0.016)

	assert_true(detection.is_player_in_range, "NPC should detect player in range")

	var flag_actions: Array[Dictionary] = []
	for action in store.get_dispatched_actions():
		if action.get("type", StringName("")) == U_GAMEPLAY_ACTIONS.ACTION_SET_AI_DEMO_FLAG:
			flag_actions.append(action)
	assert_eq(flag_actions.size(), 1, "Expected one flag dispatch on proximity enter")
	assert_eq(flag_actions[0].get("payload", {}).get("flag_id", StringName("")), StringName("power_core_proximity"))
	assert_eq(flag_actions[0].get("payload", {}).get("value", false), true)

# ---------------------------------------------------------------
# Test 2: Proximity exit dispatches false flag when enabled
# ---------------------------------------------------------------

func test_proximity_exit_dispatches_false_flag() -> void:
	var fixture: Dictionary = _create_detection_fixture()
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var detection_system: BaseECSSystem = fixture["detection_system"]
	var store: MockStateStore = fixture["store"]
	var npc: Dictionary = fixture["npc"] as Dictionary
	var npc_body: FakeBody = npc.get("body") as FakeBody
	var detection: C_DetectionComponent = fixture["detection"]

	# Enter range
	npc_body.global_position = Vector3(3.0, 0.0, 0.0)
	detection_system.process_tick(0.016)
	assert_true(detection.is_player_in_range)

	# Exit range
	npc_body.global_position = Vector3(20.0, 0.0, 0.0)
	detection_system.process_tick(0.016)
	assert_false(detection.is_player_in_range)

	var flag_actions: Array[Dictionary] = []
	for action in store.get_dispatched_actions():
		if action.get("type", StringName("")) == U_GAMEPLAY_ACTIONS.ACTION_SET_AI_DEMO_FLAG:
			flag_actions.append(action)
	assert_eq(flag_actions.size(), 2, "Expected enter + exit flag dispatches")
	assert_eq(flag_actions[1].get("payload", {}).get("value", true), false, "Exit flag should be false")

# ---------------------------------------------------------------
# Test 3: Detection enter publishes ECS event with correct payload
# ---------------------------------------------------------------

func test_detection_enter_publishes_ecs_event() -> void:
	var fixture: Dictionary = _create_detection_fixture()
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var detection_system: BaseECSSystem = fixture["detection_system"]
	var npc: Dictionary = fixture["npc"] as Dictionary
	var npc_body: FakeBody = npc.get("body") as FakeBody
	var detection: C_DetectionComponent = fixture["detection"]

	var received_events: Array = []
	var unsubscribe: Callable = U_ECS_EVENT_BUS.subscribe(
		StringName("ai_alarm_triggered"),
		func(payload: Variant) -> void:
			received_events.append(payload)
	)

	# Move into detection range
	npc_body.global_position = Vector3(2.0, 0.0, 0.0)
	detection_system.process_tick(0.016)
	detection_system.process_tick(0.016)

	assert_eq(received_events.size(), 1, "Expected one alarm event on detection enter")
	if received_events.size() < 1:
		if unsubscribe != null and unsubscribe.is_valid():
			unsubscribe.call()
		return

	var event_wrapper: Dictionary = received_events[0] as Dictionary
	# The ECS event bus wraps payloads in {name, payload, timestamp}
	var payload: Dictionary = event_wrapper.get("payload", {}) as Dictionary
	assert_true(payload.has("source_entity_id"), "Event payload should include source_entity_id")
	assert_true(payload.has("detected_player_entity_id"), "Event payload should include detected_player_entity_id")
	assert_eq(payload.get("source", StringName("")), StringName("sentry"), "Event should carry source from enter_event_payload")

	if unsubscribe != null and unsubscribe.is_valid():
		unsubscribe.call()

# ---------------------------------------------------------------
# Test 4: Alarm relay cascades to multiple flag IDs
# ---------------------------------------------------------------

func test_alarm_relay_cascades_flags() -> void:
	var fixture: Dictionary = _create_full_fixture()
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var store: MockStateStore = fixture["store"]

	# Publish an alarm event (simulating sentry detection)
	U_ECS_EVENT_BUS.publish(StringName("ai_alarm_triggered"), {
		"source_entity_id": StringName("E_Sentry"),
	})

	var flag_actions: Array[Dictionary] = []
	for action in store.get_dispatched_actions():
		if action.get("type", StringName("")) == U_GAMEPLAY_ACTIONS.ACTION_SET_AI_DEMO_FLAG:
			flag_actions.append(action)

	assert_eq(flag_actions.size(), 4, "Alarm should relay to four flag IDs")
	var flag_ids: Array[StringName] = [
		flag_actions[0].get("payload", {}).get("flag_id", StringName("")),
		flag_actions[1].get("payload", {}).get("flag_id", StringName("")),
		flag_actions[2].get("payload", {}).get("flag_id", StringName("")),
		flag_actions[3].get("payload", {}).get("flag_id", StringName("")),
	]
	assert_true(
		flag_ids.has(StringName("power_core_activated")),
		"Alarm relay should include power_core_activated"
	)
	assert_true(
		flag_ids.has(StringName("power_core_proximity")),
		"Alarm relay should include power_core_proximity"
	)
	assert_true(
		flag_ids.has(StringName("comms_disturbance_heard")),
		"Alarm relay should include comms_disturbance_heard"
	)
	assert_true(
		flag_ids.has(StringName("comms_disturbance_proximity")),
		"Alarm relay should include comms_disturbance_proximity"
	)
	for action in flag_actions:
		assert_eq(action.get("payload", {}).get("value", false), true, "Relayed flags should be true")

# ---------------------------------------------------------------
# Test 5: End-to-end — detection → flag → alarm event → relay cascade
# ---------------------------------------------------------------

func test_e2e_proximity_triggers_alarm_relay_cascade() -> void:
	var fixture: Dictionary = _create_full_fixture()
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var detection_system: BaseECSSystem = fixture["detection_system"]
	var store: MockStateStore = fixture["store"]
	var npc: Dictionary = fixture["npc"] as Dictionary
	var npc_body: FakeBody = npc.get("body") as FakeBody
	var detection: C_DetectionComponent = fixture["detection"]

	# Track alarm events
	var alarm_events: Array = []
	var unsubscribe: Callable = U_ECS_EVENT_BUS.subscribe(
		StringName("ai_alarm_triggered"),
		func(payload: Variant) -> void:
			alarm_events.append(payload)
	)

	# Step 1: Move NPC within detection range
	npc_body.global_position = Vector3(3.0, 0.0, 0.0)
	detection_system.process_tick(0.016)

	# Verify detection triggers flag dispatch
	assert_true(detection.is_player_in_range, "NPC should detect player")

	# Verify alarm event was published
	assert_eq(alarm_events.size(), 1, "Detection should publish alarm event")

	# Verify relay system cascaded the alarm to multiple flag IDs
	var flag_actions: Array[Dictionary] = []
	for action in store.get_dispatched_actions():
		if action.get("type", StringName("")) == U_GAMEPLAY_ACTIONS.ACTION_SET_AI_DEMO_FLAG:
			flag_actions.append(action)

	# Should have: 1 from detection system + 2 from alarm relay
	assert_eq(flag_actions.size(), 5, "Expected 5 total flag dispatches (1 detection + 4 relay)")

	if unsubscribe != null and unsubscribe.is_valid():
		unsubscribe.call()

# ---------------------------------------------------------------
# Test 6: No players keeps detection false
# ---------------------------------------------------------------

func test_no_players_keeps_detection_false() -> void:
	var fixture: Dictionary = _create_detection_fixture()
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var detection_system: BaseECSSystem = fixture["detection_system"]
	var store: MockStateStore = fixture["store"]
	var ecs_manager: MockECSManager = fixture["ecs_manager"]
	var detection: C_DetectionComponent = fixture["detection"]

	# Remove all player components
	ecs_manager.clear_all_components()
	detection_system.process_tick(0.016)

	assert_false(detection.is_player_in_range)
	assert_eq(store.get_dispatched_actions().size(), 0, "No actions should dispatch without players")

# ---------------------------------------------------------------
# Test 7: Alarm relay ignores empty flag IDs
# ---------------------------------------------------------------

func test_alarm_relay_ignores_empty_flag_ids() -> void:
	var fixture: Dictionary = _create_full_fixture()
	autofree_context(fixture)
	if fixture.is_empty():
		return

	var relay_system: BaseECSSystem = fixture["relay_system"]
	var store: MockStateStore = fixture["store"]

	# Inject empty flag IDs alongside valid ones
	var mixed_flags: Array[StringName] = [
		StringName(""),
		StringName("power_core_proximity"),
	]
	relay_system.relay_flag_ids = mixed_flags

	U_ECS_EVENT_BUS.publish(StringName("ai_alarm_triggered"), {})

	var flag_actions: Array[Dictionary] = []
	for action in store.get_dispatched_actions():
		if action.get("type", StringName("")) == U_GAMEPLAY_ACTIONS.ACTION_SET_AI_DEMO_FLAG:
			flag_actions.append(action)

	assert_eq(flag_actions.size(), 1, "Empty flag IDs should be skipped")
	assert_eq(
		flag_actions[0].get("payload", {}).get("flag_id", StringName("")),
		StringName("power_core_proximity")
	)

# ---------------------------------------------------------------
# Test 8: Y-axis detection respects detect_y_axis setting
# ---------------------------------------------------------------

func test_y_axis_detection_respects_config() -> void:
	var detection_script: Script = load(S_AI_DETECTION_SYSTEM_PATH) as Script
	assert_not_null(detection_script)
	if detection_script == null:
		return

	var root := Node3D.new()
	add_child_autofree(root)

	var ecs_manager := MOCK_ECS_MANAGER.new()
	autofree(ecs_manager)
	var store := MOCK_STATE_STORE.new()
	autofree(store)

	var system: BaseECSSystem = detection_script.new() as BaseECSSystem
	autofree(system)
	system.ecs_manager = ecs_manager
	system.state_store = store
	root.add_child(system)
	system.configure(ecs_manager)

	# Player at origin
	var player_data: Dictionary = _create_entity(root, "E_Player", Vector3.ZERO)
	var player_entity: Node3D = player_data.get("entity") as Node3D
	var player_movement: C_MovementComponent = player_data.get("movement") as C_MovementComponent
	var player_tag: C_PlayerTagComponent = C_PLAYER_TAG_COMPONENT.new()
	player_entity.add_child(player_tag)
	autofree(player_tag)
	ecs_manager.add_component_to_entity(player_entity, player_movement)
	ecs_manager.add_component_to_entity(player_entity, player_tag)

	# NPC directly above player (y=5) — XZ distance is 0
	var npc_data: Dictionary = _create_entity(root, "E_NPC", Vector3(0.0, 5.0, 0.0))
	var npc_entity: Node3D = npc_data.get("entity") as Node3D
	var npc_movement: C_MovementComponent = npc_data.get("movement") as C_MovementComponent

	# detect_y_axis=false: XZ distance = 0, within radius 3.0
	var detection_xz_only: C_DetectionComponent = C_DETECTION_COMPONENT.new()
	detection_xz_only.ai_flag_id = StringName("xz_flag")
	detection_xz_only.detection_radius = 3.0
	detection_xz_only.detect_y_axis = false
	npc_entity.add_child(detection_xz_only)
	autofree(detection_xz_only)
	ecs_manager.add_component_to_entity(npc_entity, npc_movement)
	ecs_manager.add_component_to_entity(npc_entity, detection_xz_only)

	system.process_tick(0.016)

	# XZ distance is 0 (directly above), so detection should trigger
	assert_true(detection_xz_only.is_player_in_range, "XZ-only detection should trigger when NPC is directly above player")

# ---------------------------------------------------------------
# Test 9: Multiple NPCs detect the same player
# ---------------------------------------------------------------

func test_multiple_npcs_detect_same_player() -> void:
	var detection_script: Script = load(S_AI_DETECTION_SYSTEM_PATH) as Script
	assert_not_null(detection_script)
	if detection_script == null:
		return

	var root := Node3D.new()
	add_child_autofree(root)

	var ecs_manager := MOCK_ECS_MANAGER.new()
	autofree(ecs_manager)
	var store := MOCK_STATE_STORE.new()
	autofree(store)

	var system: BaseECSSystem = detection_script.new() as BaseECSSystem
	autofree(system)
	system.ecs_manager = ecs_manager
	system.state_store = store
	root.add_child(system)
	system.configure(ecs_manager)

	# Player
	var player_data: Dictionary = _create_entity(root, "E_Player", Vector3.ZERO)
	var player_entity: Node3D = player_data.get("entity") as Node3D
	var player_movement: C_MovementComponent = player_data.get("movement") as C_MovementComponent
	var player_tag: C_PlayerTagComponent = C_PLAYER_TAG_COMPONENT.new()
	player_entity.add_child(player_tag)
	autofree(player_tag)
	ecs_manager.add_component_to_entity(player_entity, player_movement)
	ecs_manager.add_component_to_entity(player_entity, player_tag)

	# NPC A (close to player)
	var npc_a_data: Dictionary = _create_entity(root, "E_NPCA", Vector3(3.0, 0.0, 0.0))
	var npc_a_entity: Node3D = npc_a_data.get("entity") as Node3D
	var npc_a_movement: C_MovementComponent = npc_a_data.get("movement") as C_MovementComponent
	var detection_a: C_DetectionComponent = C_DETECTION_COMPONENT.new()
	detection_a.ai_flag_id = StringName("npc_a_detected")
	detection_a.detection_radius = 5.0
	npc_a_entity.add_child(detection_a)
	autofree(detection_a)
	ecs_manager.add_component_to_entity(npc_a_entity, npc_a_movement)
	ecs_manager.add_component_to_entity(npc_a_entity, detection_a)

	# NPC B (far from player)
	var npc_b_data: Dictionary = _create_entity(root, "E_NPCB", Vector3(20.0, 0.0, 0.0))
	var npc_b_entity: Node3D = npc_b_data.get("entity") as Node3D
	var npc_b_movement: C_MovementComponent = npc_b_data.get("movement") as C_MovementComponent
	var detection_b: C_DetectionComponent = C_DETECTION_COMPONENT.new()
	detection_b.ai_flag_id = StringName("npc_b_detected")
	detection_b.detection_radius = 5.0
	npc_b_entity.add_child(detection_b)
	autofree(detection_b)
	ecs_manager.add_component_to_entity(npc_b_entity, npc_b_movement)
	ecs_manager.add_component_to_entity(npc_b_entity, detection_b)

	system.process_tick(0.016)

	assert_true(detection_a.is_player_in_range, "NPC A should detect player within 5.0 radius")
	assert_false(detection_b.is_player_in_range, "NPC B should NOT detect player at distance 20.0")

	var flag_actions: Array[Dictionary] = []
	for action in store.get_dispatched_actions():
		if action.get("type", StringName("")) == U_GAMEPLAY_ACTIONS.ACTION_SET_AI_DEMO_FLAG:
			flag_actions.append(action)

	assert_eq(flag_actions.size(), 1, "Only NPC A should dispatch a flag")
	assert_eq(flag_actions[0].get("payload", {}).get("flag_id", StringName("")), StringName("npc_a_detected"))