extends RefCounted
class_name U_RebindCaptureHandler

const U_InputRebindUtils := preload("res://scripts/utils/input/u_input_rebind_utils.gd")
const U_InputCaptureGuard := preload("res://scripts/utils/input/u_input_capture_guard.gd")
const U_InputActions := preload("res://scripts/state/actions/u_input_actions.gd")
const U_RebindActionListBuilder := preload("res://scripts/ui/helpers/u_rebind_action_list_builder.gd")

static func begin_capture(overlay: Node, action: StringName, mode: String) -> void:
	if overlay._is_capturing:
		return
	if overlay._is_reserved(action):
		overlay._show_error("Cannot rebind reserved action.")
		return

	overlay._is_capturing = true
	overlay._capture_guard_active = true
	U_InputCaptureGuard.begin_capture()
	overlay._pending_action = action
	overlay._pending_event = null
	overlay._pending_conflict = StringName()
	overlay._capture_mode = mode

	for key in overlay._action_rows.keys():
		var row: Dictionary = overlay._action_rows[key]
		var add_button: Button = row.get("add_button")
		var replace_button: Button = row.get("replace_button")
		var is_reserved: bool = overlay._is_reserved(key)
		if add_button != null:
			if is_reserved:
				add_button.text = "Reserved"
			elif key == action and mode == U_InputActions.REBIND_MODE_ADD:
				add_button.text = U_RebindActionListBuilder.ADD_BUTTON_TEXT
			else:
				add_button.text = U_RebindActionListBuilder.ADD_BUTTON_TEXT
			add_button.disabled = true
		if replace_button != null:
			if is_reserved:
				replace_button.text = "Reserved"
			elif key == action and mode == U_InputActions.REBIND_MODE_REPLACE:
				replace_button.text = U_RebindActionListBuilder.REPLACE_BUTTON_TEXT
			else:
				replace_button.text = U_RebindActionListBuilder.REPLACE_BUTTON_TEXT
			replace_button.disabled = true

	overlay._update_status("Press new input for {action} (Esc to cancel).".format({
		"action": U_RebindActionListBuilder.format_action_name(action)
	}))
	overlay._set_reset_button_enabled(false)

static func cancel_capture(overlay: Node, message: String) -> void:
	if overlay._capture_guard_active:
		U_InputCaptureGuard.end_capture()
	overlay._capture_guard_active = false
	overlay._is_capturing = false
	overlay._pending_action = StringName()
	overlay._pending_event = null
	overlay._pending_conflict = StringName()
	overlay._capture_mode = U_InputActions.REBIND_MODE_REPLACE
	overlay._refresh_bindings()
	overlay._update_status(message)
	overlay._set_reset_button_enabled(overlay._profile_manager != null)

static func handle_input(overlay: Node, event: InputEvent) -> void:
	if not overlay._is_capturing:
		return
	if event == null:
		return

	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		if key_event.keycode == Key.KEY_ESCAPE:
			overlay.get_viewport().set_input_as_handled()
			cancel_capture(overlay, "Rebind cancelled.")
			return
		handle_captured_event(overlay, key_event)
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if not mouse_event.pressed:
			return
		handle_captured_event(overlay, mouse_event)
	elif event is InputEventJoypadButton:
		var joy_button := event as InputEventJoypadButton
		if not joy_button.pressed:
			return
		handle_captured_event(overlay, joy_button)
	elif event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if abs(motion.axis_value) < 0.5:
			return
		var motion_copy := motion.duplicate(true) as InputEventJoypadMotion
		motion_copy.axis_value = signf(motion_copy.axis_value)
		handle_captured_event(overlay, motion_copy)

static func handle_captured_event(overlay: Node, event: InputEvent) -> void:
	if not overlay._is_capturing or overlay._pending_action == StringName():
		return
	overlay.get_viewport().set_input_as_handled()
	overlay._is_capturing = false

	var event_copy: InputEvent = event.duplicate(true)
	var replace_existing: bool = (overlay._capture_mode == U_InputActions.REBIND_MODE_REPLACE)
	var validation := U_InputRebindUtils.validate_rebind(
		overlay._pending_action,
		event_copy,
		overlay._rebind_settings,
		replace_existing,
		overlay._get_active_profile(),
		U_RebindActionListBuilder.EXCLUDED_ACTIONS
	)
	if not validation.valid:
		var error_text: String = validation.error if not validation.error.is_empty() else "Rebind failed."
		overlay._show_error(error_text)
		cancel_capture(overlay, "Rebind failed.")
		return

	if validation.conflict_action != StringName():
		overlay._pending_event = event_copy
		overlay._pending_conflict = validation.conflict_action
		var conflict_name: String = U_RebindActionListBuilder.format_action_name(validation.conflict_action)
		var binding_text: String = overlay._format_binding_text([event_copy])
		overlay._conflict_dialog.dialog_text = "{binding} is already bound to {action}. Replace binding?".format({
			"binding": overlay._format_binding_label(binding_text),
			"action": conflict_name
		})
		overlay._conflict_dialog.popup_centered()
	else:
		apply_binding(overlay, event_copy, StringName())

static func apply_binding(overlay: Node, event: InputEvent, conflict_action: StringName) -> void:
	var action: StringName = overlay._pending_action
	var replace_existing: bool = (overlay._capture_mode == U_InputActions.REBIND_MODE_REPLACE)
	var target_existing: Array[InputEvent] = get_action_events(overlay, action)
	var conflict_existing: Array[InputEvent] = []
	if conflict_action != StringName():
		conflict_existing = get_action_events(overlay, conflict_action)

	var final_target: Array[InputEvent] = build_final_target_events(target_existing, event, replace_existing)
	var final_conflict: Array[InputEvent] = []
	if conflict_action != StringName():
		final_conflict = build_final_conflict_events(conflict_existing, target_existing, event, replace_existing)

	overlay._ensure_store_reference()
	if overlay._store == null:
		overlay._show_error("State store not available.")
		cancel_capture(overlay, "Rebind failed.")
		return

	var dispatch_event: InputEvent = event
	if dispatch_event != null:
		dispatch_event = dispatch_event.duplicate(true)

	overlay._store.dispatch(U_InputActions.rebind_action(action, dispatch_event, overlay._capture_mode, final_target))

	if conflict_action != StringName():
		var conflict_event: InputEvent = null
		if not final_conflict.is_empty():
			conflict_event = final_conflict[0].duplicate(true)
		overlay._store.dispatch(
			U_InputActions.rebind_action(conflict_action, conflict_event, U_InputActions.REBIND_MODE_REPLACE, final_conflict)
		)

	await overlay.get_tree().process_frame

	var binding_text: String = overlay._format_binding_text(final_target)
	cancel_capture(overlay, "{action} bound to {binding}.".format({
		"action": U_RebindActionListBuilder.format_action_name(action),
		"binding": overlay._format_binding_label(binding_text)
	}))

static func get_action_events(overlay: Node, action: StringName) -> Array[InputEvent]:
	var results: Array[InputEvent] = []
	if action == StringName():
		return results
	if not InputMap.has_action(action):
		return results
	for existing in InputMap.action_get_events(action):
		if existing is InputEvent:
			var cloned := clone_event(existing)
			if cloned != null:
				results.append(cloned)
	return results

static func build_final_target_events(existing: Array[InputEvent], event: InputEvent, replace_existing: bool) -> Array[InputEvent]:
	var final_events: Array[InputEvent] = []
	if replace_existing:
		if event != null:
			var new_device_type: String = U_RebindActionListBuilder.get_event_device_type(event)
			for existing_event in existing:
				var existing_device_type: String = U_RebindActionListBuilder.get_event_device_type(existing_event)
				if existing_device_type != new_device_type:
					append_unique_event(final_events, existing_event)
			append_unique_event(final_events, event)
		return final_events

	for existing_event in existing:
		append_unique_event(final_events, existing_event)
	append_unique_event(final_events, event)
	return final_events

static func build_final_conflict_events(
	conflict_existing: Array[InputEvent],
	previous_target: Array[InputEvent],
	new_event: InputEvent,
	replace_existing: bool
) -> Array[InputEvent]:
	var final_events: Array[InputEvent] = []
	for conflict_event in conflict_existing:
		if new_event != null and events_match(conflict_event, new_event):
			continue
		append_unique_event(final_events, conflict_event)
	if replace_existing:
		for previous_event in previous_target:
			if new_event != null and events_match(previous_event, new_event):
				continue
			append_unique_event(final_events, previous_event)
	return final_events

static func append_unique_event(events: Array[InputEvent], candidate: InputEvent) -> void:
	if candidate == null:
		return
	for existing in events:
		if events_match(existing, candidate):
			return
	var clone: InputEvent = clone_event(candidate)
	if clone != null:
		events.append(clone)

static func clone_event(source: InputEvent) -> InputEvent:
	if source == null:
		return null
	var dict := U_InputRebindUtils.event_to_dict(source)
	if dict.is_empty():
		return null
	return U_InputRebindUtils.dict_to_event(dict)

static func events_match(a: InputEvent, b: InputEvent) -> bool:
	if a == null or b == null:
		return false
	return a.is_match(b) and b.is_match(a)
