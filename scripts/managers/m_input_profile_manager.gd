@icon("res://assets/editor_icons/icn_manager.svg")
extends "res://scripts/interfaces/i_input_profile_manager.gd"
class_name M_InputProfileManager

const U_GlobalSettingsSerialization := preload("res://scripts/utils/u_global_settings_serialization.gd")
const U_InputProfileLoader := preload("res://scripts/managers/helpers/u_input_profile_loader.gd")
const U_InputMapBootstrapper := preload("res://scripts/input/u_input_map_bootstrapper.gd")
const U_StateUtils := preload("res://scripts/state/utils/u_state_utils.gd")
const U_InputActions := preload("res://scripts/state/actions/u_input_actions.gd")
const U_GameplayActions := preload("res://scripts/state/actions/u_gameplay_actions.gd")
const U_InputSelectors := preload("res://scripts/state/selectors/u_input_selectors.gd")
const U_NavigationSelectors := preload("res://scripts/state/selectors/u_navigation_selectors.gd")

signal profile_switched(profile_id: String)
signal bindings_reset()
signal custom_binding_added(action: StringName, event: InputEvent)

var active_profile: RS_InputProfile
var available_profiles: Dictionary = {} # String -> RS_InputProfile
var store_ref: I_StateStore = null

var _state_store: I_StateStore = null
var _unsubscribe: Callable = Callable()
var _profile_loader := U_InputProfileLoader.new()
var _pause_gate_enabled: bool = false
var _current_profile_id: String = ""
var _last_bindings_signature: int = 0
var _tracked_custom_actions: Array[StringName] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	U_InputMapBootstrapper.ensure_required_actions(
		U_InputMapBootstrapper.REQUIRED_ACTIONS,
		U_InputMapBootstrapper.should_patch_missing_actions()
	)
	_load_available_profiles()
	await _initialize_from_store()

func _initialize_from_store() -> void:
	var store := await U_StateUtils.await_store_ready(self)
	if store == null:
		push_error("M_InputProfileManager: Timed out waiting for M_StateStore readiness")
		return

	_state_store = store
	store_ref = store

	if _unsubscribe == Callable() or not _unsubscribe.is_valid():
		_unsubscribe = store.subscribe(_on_store_changed)

	# Apply persisted settings if available; otherwise sync with current store state.
	var loaded_from_disk := load_custom_bindings()
	if not loaded_from_disk:
		_sync_from_state(store.get_state(), true)

func _exit_tree() -> void:
	if _unsubscribe != Callable() and _unsubscribe.is_valid():
		_unsubscribe.call()
	_unsubscribe = Callable()
	_state_store = null

func _ensure_state_store_ready() -> void:
	if _state_store != null and is_instance_valid(_state_store):
		return
	var store := U_StateUtils.get_store(self)
	if store == null or not store.is_ready():
		return
	_state_store = store
	store_ref = store

func _get_state_store() -> I_StateStore:
	if _state_store != null and is_instance_valid(_state_store):
		return _state_store
	return null

func _sync_from_state(state: Dictionary, force_profile_reapply: bool = false) -> void:
	if state == null:
		return

	var input_settings := _get_input_settings_from_state(state)
	var desired_profile_id := _resolve_profile_id(String(input_settings.get("active_profile_id", "")))
	var profile_changed := desired_profile_id != _current_profile_id
	var bindings_variant: Variant = input_settings.get("custom_bindings", {})

	if profile_changed:
		if load_profile(desired_profile_id):
			_current_profile_id = desired_profile_id
		else:
			var fallback_id := _resolve_profile_id("")
			if load_profile(fallback_id):
				_current_profile_id = fallback_id
			else:
				_current_profile_id = desired_profile_id

	if (profile_changed or force_profile_reapply) and active_profile != null:
		_apply_profile_to_input_map(active_profile)
	var new_signature := hash(bindings_variant)
	if profile_changed or force_profile_reapply or new_signature != _last_bindings_signature:
		_apply_custom_bindings_from_state(bindings_variant)
		_last_bindings_signature = new_signature

func _get_input_settings_from_state(state: Dictionary) -> Dictionary:
	if state == null:
		return {}
	var settings_variant: Variant = state.get("settings", {})
	if not (settings_variant is Dictionary):
		return {}
	var settings_dict := (settings_variant as Dictionary).duplicate(true)
	var input_variant: Variant = settings_dict.get("input_settings", {})
	if input_variant is Dictionary:
		return (input_variant as Dictionary).duplicate(true)
	return {}

func _apply_custom_bindings_from_state(bindings_variant: Variant) -> void:
	if bindings_variant == null or not (bindings_variant is Dictionary):
		if not _tracked_custom_actions.is_empty():
			# Restore defaults for ALL device types when clearing custom bindings
			if not available_profiles.is_empty():
				for profile_id in available_profiles.keys():
					var profile: RS_InputProfile = available_profiles[profile_id]
					if profile != null:
						_apply_profile_to_input_map(profile)
			elif active_profile != null:
				_apply_profile_to_input_map(active_profile)
			else:
				for removed in _tracked_custom_actions:
					if InputMap.has_action(removed):
						InputMap.action_erase_events(removed)
		_tracked_custom_actions.clear()
		return

	var bindings_dict := bindings_variant as Dictionary
	var new_actions: Array[StringName] = []
	for action_key in bindings_dict.keys():
		new_actions.append(StringName(action_key))

	var removed_actions: Array[StringName] = []
	for existing_action in _tracked_custom_actions:
		if not new_actions.has(existing_action):
			removed_actions.append(existing_action)

	if not removed_actions.is_empty():
		# Restore defaults for ALL device types for removed actions
		if not available_profiles.is_empty():
			for profile_id in available_profiles.keys():
				var profile: RS_InputProfile = available_profiles[profile_id]
				if profile != null:
					_apply_profile_to_input_map(profile)
		elif active_profile != null:
			_apply_profile_to_input_map(active_profile)
		else:
			for removed in removed_actions:
				if InputMap.has_action(removed):
					InputMap.action_erase_events(removed)

	for action_name in new_actions:
		var events_variant: Variant = bindings_dict.get(action_name, [])
		if not (events_variant is Array):
			continue
		var event_dicts: Array = []
		for entry in (events_variant as Array):
			if entry is Dictionary:
				event_dicts.append((entry as Dictionary).duplicate(true))
		_set_action_events(action_name, event_dicts)

	_tracked_custom_actions = new_actions

func _set_action_events(action: StringName, event_dicts: Array) -> void:
	if action == StringName():
		return
	if not InputMap.has_action(action):
		InputMap.add_action(action)

	InputMap.action_erase_events(action)

	for entry in event_dicts:
		if not (entry is Dictionary):
			continue
		var parsed := U_InputRebindUtils.dict_to_event(entry)
		if parsed == null:
			continue
		var already_present := false
		for existing in InputMap.action_get_events(action):
			if existing is InputEvent and existing.is_match(parsed) and parsed.is_match(existing):
				already_present = true
				break
		if not already_present:
			InputMap.action_add_event(action, parsed)

func _on_store_changed(action: Dictionary, state: Dictionary) -> void:
	if action == null:
		return
	var action_type: StringName = action.get("type", StringName())
	if action_type == U_GameplayActions.ACTION_PAUSE_GAME:
		_pause_gate_enabled = true
	elif action_type == U_GameplayActions.ACTION_UNPAUSE_GAME:
		_pause_gate_enabled = false
	elif action_type == U_GameplayActions.ACTION_RESET_PROGRESS:
		_pause_gate_enabled = false
	elif action_type == U_GameplayActions.ACTION_RESET_AFTER_DEATH:
		_pause_gate_enabled = false

	var force_profile_reapply := action_type == U_InputActions.ACTION_PROFILE_SWITCHED \
		or action_type == U_InputActions.ACTION_LOAD_INPUT_SETTINGS \
		or action_type == U_InputActions.ACTION_RESET_BINDINGS \
		or action_type == U_InputActions.ACTION_REMOVE_ACTION_BINDINGS

	var is_reset_action := action_type == U_InputActions.ACTION_RESET_BINDINGS

	if action_type == U_InputActions.ACTION_REBIND_ACTION:
		var payload: Dictionary = action.get("payload", {})
		var event_dict: Dictionary = payload.get("event", {})
		var event := U_InputRebindUtils.dict_to_event(event_dict)
		if event != null:
			var action_name: StringName = payload.get("action", StringName())
			custom_binding_added.emit(action_name, event)

	if action_type.begins_with("input/") or action_type == U_InputActions.ACTION_PROFILE_SWITCHED:
		_sync_from_state(state, force_profile_reapply)

	# Emit bindings_reset AFTER sync completes so UI sees updated InputMap
	if is_reset_action:
		bindings_reset.emit()

func _load_available_profiles() -> void:
	# Built-in profiles (resources/input/profiles)
	# Note: Use optional chaining; missing files are tolerated in early phases.
	available_profiles = _profile_loader.load_available_profiles()

func get_available_profile_ids() -> Array[String]:
	var ids: Array[String] = []
	for key in available_profiles.keys():
		ids.append(String(key))
	ids.sort()
	return ids

func _get_store_profile_id() -> String:
	var store := _get_state_store()
	if store == null:
		return ""
	var state := store.get_state()
	if state == null:
		return ""
	var settings_id := U_InputSelectors.get_active_profile_id(state)
	if settings_id == null:
		return ""
	var settings_key := String(settings_id)
	return settings_key

func _resolve_profile_id(preferred_id: String) -> String:
	var candidate := String(preferred_id)
	if not candidate.is_empty() and available_profiles.has(candidate):
		return candidate

	# On mobile, never use "default" (keyboard/mouse profile)
	# Instead, prefer touchscreen profiles
	if OS.has_feature("mobile"):
		# Try touchscreen-specific defaults first
		if available_profiles.has("default_touchscreen"):
			return "default_touchscreen"
		# Look for any touchscreen profile
		for key in available_profiles.keys():
			var profile := available_profiles[key] as RS_InputProfile
			if profile != null and profile.device_type == 2:  # TOUCHSCREEN
				return String(key)
		# If no touchscreen profile exists, return first available (but not "default")
		for key in available_profiles.keys():
			if key != "default":
				return String(key)

	# On desktop, prefer "default" (keyboard/mouse)
	if available_profiles.has("default"):
		return "default"

	# Fallback: return any available profile
	for key in available_profiles.keys():
		return String(key)
	return ""

func _get_default_touchscreen_profile() -> RS_InputProfile:
	if available_profiles.has("default_touchscreen"):
		return available_profiles["default_touchscreen"] as RS_InputProfile
	return null

func load_profile(profile_id: String) -> bool:
	if not available_profiles.has(profile_id):
		push_error("Input profile not found: %s" % profile_id)
		return false
	var profile := available_profiles[profile_id] as RS_InputProfile
	if profile == null:
		return false
	active_profile = profile
	_apply_profile_to_input_map(profile)
	return true

func get_active_profile() -> RS_InputProfile:
	return active_profile

func _apply_profile_accessibility(profile_id: String, profile: RS_InputProfile) -> void:
	_ensure_state_store_ready()
	var update_callable := Callable(U_InputActions, "update_accessibility")
	_profile_loader.apply_profile_accessibility(profile_id, profile, _state_store, update_callable)

func get_default_joystick_position() -> Vector2:
	var profile := _get_default_touchscreen_profile()
	if profile == null:
		return Vector2(-1, -1)
	return profile.virtual_joystick_position

func reset_touchscreen_positions() -> Array[Dictionary]:
	var profile := _get_default_touchscreen_profile()
	if profile == null:
		return []

	var result: Array[Dictionary] = []

	# Return profile defaults for visual application
	# The overlay will clear custom positions which triggers persistence
	for button in profile.virtual_buttons:
		result.append(button.duplicate(true))

	return result

func switch_profile(profile_id: String) -> void:
	# Only allow switch when gameplay is paused (per PRD)
	# Fetch store fresh to avoid stale references in test contexts
	_ensure_state_store_ready()
	var store := _get_state_store()
	var gameplay_paused := _is_gameplay_paused(store)
	var tree_paused := get_tree() != null and get_tree().paused

	var allow_by_pause_state := gameplay_paused and _pause_gate_enabled
	var allow_by_menu_shell := _is_in_menu_shell(store)

	if not allow_by_pause_state and not allow_by_menu_shell and not tree_paused:
		return

	if not load_profile(profile_id):
		return

	# Apply accessibility defaults for dedicated accessibility profiles
	# when the player explicitly switches profiles.
	_apply_profile_accessibility(profile_id, active_profile)

	# Clear per-frame input state where appropriate (handled by reducers on next tick)
	if store != null:
		store.dispatch(U_InputActions.profile_switched(profile_id))
	profile_switched.emit(profile_id)

func save_custom_bindings() -> bool:
	var snapshot := _gather_settings_snapshot()
	if snapshot.is_empty():
		return false
	return U_GlobalSettingsSerialization.save_settings({"input_settings": snapshot})

func load_custom_bindings() -> bool:
	var loaded := U_GlobalSettingsSerialization.load_settings()
	var input_variant: Variant = loaded.get("input_settings", {})
	if not (input_variant is Dictionary):
		return false
	var payload := input_variant as Dictionary
	if payload.is_empty():
		return false

	var persisted_profile_id := String(payload.get("active_profile_id", ""))
	if not persisted_profile_id.is_empty() and not available_profiles.has(persisted_profile_id):
		payload["active_profile_id"] = _resolve_profile_id("")

	_ensure_state_store_ready()
	if _state_store == null:
		return false

	_state_store.dispatch(U_InputActions.load_input_settings(payload))
	return true

func reset_to_defaults() -> void:
	_ensure_state_store_ready()
	if _state_store == null:
		return
	_state_store.dispatch(U_InputActions.reset_bindings())

func reset_action(action: StringName) -> void:
	if action == StringName():
		return
	_ensure_state_store_ready()
	if _state_store == null:
		return
	_state_store.dispatch(U_InputActions.remove_action_bindings(action))

func _apply_profile_to_input_map(profile: RS_InputProfile) -> void:
	_profile_loader.apply_profile_to_input_map(profile)

func _gather_settings_snapshot() -> Dictionary:
	var store := _get_state_store()
	if store == null:
		return {}
	var state := store.get_state()
	if state == null:
		return {}
	var settings_variant: Variant = state.get("settings", {})
	if settings_variant is Dictionary:
		var input_variant: Variant = (settings_variant as Dictionary).get("input_settings", {})
		if input_variant is Dictionary:
			return (input_variant as Dictionary).duplicate(true)
	return {}

func _is_gameplay_paused(store: M_StateStore) -> bool:
	if store == null:
		return false
	var gameplay := store.get_slice(StringName("gameplay"))
	if gameplay is Dictionary:
		return bool((gameplay as Dictionary).get("paused", false))
	return false

func _is_in_menu_shell(store: I_StateStore) -> bool:
	if store == null:
		return false
	var state := store.get_state()
	if state == null:
		return false
	var nav_variant: Variant = state.get("navigation", {})
	if not (nav_variant is Dictionary):
		return false
	var shell: StringName = U_NavigationSelectors.get_shell(nav_variant as Dictionary)
	return shell != StringName("gameplay")
