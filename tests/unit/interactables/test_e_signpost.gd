extends BaseTest


func _pump_frames(count: int = 1) -> void:
	for _i in count:
		await get_tree().process_frame

func _create_signpost() -> Inter_Signpost:
	var signpost := Inter_Signpost.new()
	signpost.message = "Hello there"
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

	if unsubscribe != null and unsubscribe.is_valid():
		unsubscribe.call()

func test_non_repeatable_locks_after_activation() -> void:
	var signpost := await _create_signpost()
	signpost.repeatable = false
	var dummy := _make_dummy_player()
	signpost._on_activated(dummy)
	assert_true(signpost.is_locked(), "Non-repeatable signpost should lock after first activation.")

func _make_dummy_player() -> Node3D:
	var node := Node3D.new()
	add_child(node)
	autofree(node)
	return node
