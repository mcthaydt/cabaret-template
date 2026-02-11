extends BaseTest

const RS_SIGNPOST_INTERACTION_CONFIG := preload("res://scripts/resources/interactions/rs_signpost_interaction_config.gd")
const RS_DOOR_INTERACTION_CONFIG := preload("res://scripts/resources/interactions/rs_door_interaction_config.gd")
const INTERACTION_HINT_TEXTURE := preload("res://assets/textures/tex_icon.svg")

func _pump_frames(count: int = 1) -> void:
	for _i in count:
		await get_tree().process_frame

func _create_signpost() -> Inter_Signpost:
	var signpost := Inter_Signpost.new()
	var config := RS_SIGNPOST_INTERACTION_CONFIG.new()
	config.message = "Hello there"
	config.repeatable = true
	config.interact_prompt = "Read"
	signpost.config = config
	add_child(signpost)
	autofree(signpost)
	await _pump_frames(2)
	return signpost

func test_defaults_to_interact_mode() -> void:
	var signpost := await _create_signpost()
	assert_eq(signpost.trigger_mode, Inter_Signpost.TriggerMode.INTERACT)
	assert_eq(signpost.cooldown_duration, 0.0)

func test_emits_signal_on_activation() -> void:
	U_ECSEventBus.reset()
	var signpost := await _create_signpost()
	var received := {
		"message": "",
		"count": 0
	}
	signpost.signpost_activated.connect(func(message: String, _node: Inter_Signpost) -> void:
		received.message = message
		received.count += 1
	)

	var messages: Array = []
	var unsubscribe := U_ECSEventBus.subscribe(StringName("signpost_message"), func(payload: Variant) -> void:
		messages.append(payload)
	)

	var dummy := _make_dummy_player()
	signpost._on_activated(dummy)

	assert_eq(received.count, 1, "Activation should emit signpost_activated once.")
	assert_eq(received.message, "Hello there")

	assert_eq(messages.size(), 1, "Signpost activation should publish message event.")
	var event := messages[0] as Dictionary
	var payload := event.get("payload", {}) as Dictionary
	assert_eq(String(payload.get("message", "")), "Hello there")
	assert_eq(bool(payload.get("repeatable", true)), true)
	assert_eq(float(payload.get("message_duration_sec", 0.0)), 3.0,
		"Signpost payload should include default message duration for HUD auto-hide")

	if unsubscribe != null and unsubscribe.is_valid():
		unsubscribe.call()

func test_non_repeatable_locks_after_activation() -> void:
	var signpost := await _create_signpost()
	var config := RS_SIGNPOST_INTERACTION_CONFIG.new()
	config.message = "Hello there"
	config.repeatable = false
	config.interact_prompt = "Read"
	signpost.config = config
	await _pump_frames(1)
	var dummy := _make_dummy_player()
	signpost._on_activated(dummy)
	assert_true(signpost.is_locked(), "Non-repeatable signpost should lock after first activation.")

func test_config_resource_overrides_message_repeatable_and_prompt() -> void:
	U_ECSEventBus.reset()
	var signpost := await _create_signpost()
	var config := RS_SIGNPOST_INTERACTION_CONFIG.new()
	config.message = "Config message"
	config.repeatable = false
	config.message_duration_sec = 1.25
	config.interact_prompt = "Inspect"
	signpost.config = config
	await _pump_frames(1)

	assert_eq(signpost.interact_prompt, "Inspect", "Config should override prompt label.")

	var received := {
		"message": ""
	}
	signpost.signpost_activated.connect(func(message: String, _node: Inter_Signpost) -> void:
		received.message = message
	)

	var messages: Array = []
	var unsubscribe := U_ECSEventBus.subscribe(StringName("signpost_message"), func(payload: Variant) -> void:
		messages.append(payload)
	)

	var dummy := _make_dummy_player()
	signpost._on_activated(dummy)

	assert_eq(received.message, "Config message")
	assert_eq(messages.size(), 1)
	var event := messages[0] as Dictionary
	var payload := event.get("payload", {}) as Dictionary
	assert_eq(String(payload.get("message", "")), "Config message")
	assert_eq(bool(payload.get("repeatable", true)), false)
	assert_eq(float(payload.get("message_duration_sec", 0.0)), 1.25,
		"Signpost payload should include configured message duration")
	assert_true(signpost.is_locked(), "Config repeatable=false should lock signpost.")

	if unsubscribe != null and unsubscribe.is_valid():
		unsubscribe.call()

func test_non_matching_config_does_not_override_valid_config() -> void:
	var signpost := await _create_signpost()
	var wrong_config := RS_DOOR_INTERACTION_CONFIG.new()
	signpost.config = wrong_config
	await _pump_frames(1)

	assert_eq(signpost.interact_prompt, "Read", "Prompt should remain from the last valid signpost config.")

	var received := {
		"message": ""
	}
	signpost.signpost_activated.connect(func(message: String, _node: Inter_Signpost) -> void:
		received.message = message
	)

	var dummy := _make_dummy_player()
	signpost._on_activated(dummy)
	assert_eq(received.message, "Hello there", "Invalid config types should not replace valid signpost config values.")

func test_config_resource_applies_world_hint_settings() -> void:
	var signpost := await _create_signpost()
	var config := RS_SIGNPOST_INTERACTION_CONFIG.new()
	config.message = "Hinted message"
	config.interact_prompt = "Inspect"
	config.interaction_hint_enabled = true
	config.interaction_hint_icon = INTERACTION_HINT_TEXTURE
	config.interaction_hint_offset = Vector3(0.0, 1.9, 0.0)
	config.interaction_hint_scale = 0.95

	signpost.config = config
	await _pump_frames(1)

	assert_true(signpost.interaction_hint_enabled, "Signpost should apply world hint enabled flag from config.")
	assert_eq(signpost.interaction_hint_icon, INTERACTION_HINT_TEXTURE, "Signpost should apply world hint texture from config.")
	assert_eq(signpost.interaction_hint_offset, Vector3(0.0, 1.9, 0.0), "Signpost should apply world hint offset from config.")
	assert_eq(signpost.interaction_hint_scale, 0.95, "Signpost should apply world hint scale from config.")

func _make_dummy_player() -> Node3D:
	var node := Node3D.new()
	add_child(node)
	autofree(node)
	return node
