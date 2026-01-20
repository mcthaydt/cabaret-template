@icon("res://resources/editor_icons/utility.svg")
extends CanvasLayer
class_name UI_HudController

const U_StateUtils := preload("res://scripts/state/utils/u_state_utils.gd")
const U_EntitySelectors := preload("res://scripts/state/selectors/u_entity_selectors.gd")
const U_ECSEventBus := preload("res://scripts/ecs/u_ecs_event_bus.gd")
const UI_ButtonPrompt := preload("res://scripts/ui/ui_button_prompt.gd")
const U_NavigationSelectors := preload("res://scripts/state/selectors/u_navigation_selectors.gd")
const U_InteractBlocker := preload("res://scripts/utils/u_interact_blocker.gd")
const U_ServiceLocator := preload("res://scripts/core/u_service_locator.gd")

@onready var pause_label: Label = $MarginContainer/VBoxContainer/PauseLabel
@onready var health_bar: ProgressBar = $MarginContainer/VBoxContainer/HealthBar
@onready var health_label: Label = $MarginContainer/VBoxContainer/HealthBar/HealthLabel
@onready var toast_container: Control = $MarginContainer/ToastContainer
@onready var checkpoint_toast: Label = $MarginContainer/ToastContainer/PanelContainer/MarginContainer/CheckpointToast
@onready var interact_prompt: UI_ButtonPrompt = $MarginContainer/InteractPrompt

var _store: I_StateStore = null
var _player_entity_id: String = "player"
var _unsubscribe_checkpoint: Callable
var _unsubscribe_interact_prompt_show: Callable
var _unsubscribe_interact_prompt_hide: Callable
var _unsubscribe_signpost: Callable
var _unsubscribe_save_started: Callable
var _unsubscribe_save_completed: Callable
var _unsubscribe_save_failed: Callable
var _active_prompt_id: int = 0
var _last_prompt_action: StringName = StringName("interact")
var _last_prompt_text: String = ""
var _toast_active: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_with_scene_manager()
	_store = U_StateUtils.get_store(self)

	if _store == null:
		push_error("HUD: Could not find M_StateStore")
		return

	_player_entity_id = String(_store.get_slice(StringName("gameplay")).get("player_entity_id", "player"))
	_store.slice_updated.connect(_on_slice_updated)

	# Subscribe to checkpoint events for player feedback
	_unsubscribe_checkpoint = U_ECSEventBus.subscribe(StringName("checkpoint_activated"), _on_checkpoint_event)
	_unsubscribe_interact_prompt_show = U_ECSEventBus.subscribe(StringName("interact_prompt_show"), _on_interact_prompt_show)
	_unsubscribe_interact_prompt_hide = U_ECSEventBus.subscribe(StringName("interact_prompt_hide"), _on_interact_prompt_hide)
	_unsubscribe_signpost = U_ECSEventBus.subscribe(StringName("signpost_message"), _on_signpost_message)

	# Subscribe to save events for autosave feedback (Phase 11)
	_unsubscribe_save_started = U_ECSEventBus.subscribe(StringName("save_started"), _on_save_started)
	_unsubscribe_save_completed = U_ECSEventBus.subscribe(StringName("save_completed"), _on_save_completed)
	_unsubscribe_save_failed = U_ECSEventBus.subscribe(StringName("save_failed"), _on_save_failed)

	_update_display(_store.get_state())

func _process(_delta: float) -> void:
	if _store == null or not is_instance_valid(_store):
		return
	# Keep HUD visibility in sync even if a slice update arrives between frames.
	_update_display(_store.get_state())

func _exit_tree() -> void:
	_unregister_from_scene_manager()
	if _store != null and _store.slice_updated.is_connected(_on_slice_updated):
		_store.slice_updated.disconnect(_on_slice_updated)
	if _unsubscribe_checkpoint != null and _unsubscribe_checkpoint.is_valid():
		_unsubscribe_checkpoint.call()
	if _unsubscribe_interact_prompt_show != null and _unsubscribe_interact_prompt_show.is_valid():
		_unsubscribe_interact_prompt_show.call()
	if _unsubscribe_interact_prompt_hide != null and _unsubscribe_interact_prompt_hide.is_valid():
		_unsubscribe_interact_prompt_hide.call()
	if _unsubscribe_signpost != null and _unsubscribe_signpost.is_valid():
		_unsubscribe_signpost.call()
	if _unsubscribe_save_started != null and _unsubscribe_save_started.is_valid():
		_unsubscribe_save_started.call()
	if _unsubscribe_save_completed != null and _unsubscribe_save_completed.is_valid():
		_unsubscribe_save_completed.call()
	if _unsubscribe_save_failed != null and _unsubscribe_save_failed.is_valid():
		_unsubscribe_save_failed.call()

func _register_with_scene_manager() -> void:
	var scene_manager := U_ServiceLocator.try_get_service(StringName("scene_manager"))
	if scene_manager != null and scene_manager.has_method("register_hud_controller"):
		scene_manager.register_hud_controller(self)

func _unregister_from_scene_manager() -> void:
	var scene_manager := U_ServiceLocator.try_get_service(StringName("scene_manager"))
	if scene_manager != null and scene_manager.has_method("unregister_hud_controller"):
		scene_manager.unregister_hud_controller(self)

func _on_slice_updated(slice_name: StringName, _slice_state: Dictionary) -> void:
	if _store == null:
		return
	if slice_name != StringName("gameplay") \
			and slice_name != StringName("scene") \
			and slice_name != StringName("navigation"):
		return

	var state := _store.get_state()
	_update_display(state)
	if _is_paused(state):
		if interact_prompt != null:
			interact_prompt.hide_prompt()
		if toast_container != null:
			toast_container.visible = false
			_toast_active = false
		# Force unblock interact when paused (no interactions possible anyway)
		U_InteractBlocker.force_unblock()

func _update_display(state: Dictionary) -> void:
	pause_label.text = ""
	_update_health(state)

func _update_health(state: Dictionary) -> void:
	if health_bar == null:
		return

	# Hide health bar when any menu/overlay is open
	if _is_paused(state):
		health_bar.visible = false
		return

	# Only show health bar during active gameplay shell
	# Don't show when transitioning to/from gameplay (shell != "gameplay")
	var navigation_state: Dictionary = state.get("navigation", {})
	var shell: StringName = navigation_state.get("shell", StringName())

	if shell != StringName("gameplay"):
		health_bar.visible = false
		return

	# Show health bar during active gameplay
	health_bar.visible = true

	var health: float = U_EntitySelectors.get_entity_health(state, _player_entity_id)
	var max_health: float = U_EntitySelectors.get_entity_max_health(state, _player_entity_id)

	max_health = max(max_health, 1.0)
	health = clampf(health, 0.0, max_health)

	# Avoid redundant redraws
	if not is_equal_approx(health_bar.max_value, max_health):
		health_bar.max_value = max_health
	if not is_equal_approx(health_bar.value, health):
		health_bar.value = health

	var display_text: String = "%d / %d" % [int(round(health)), int(round(max_health))]
	if health_label != null:
		health_label.text = display_text
	health_bar.tooltip_text = display_text

## ECS: Show a brief toast when a checkpoint is activated
func _on_checkpoint_event(payload: Variant) -> void:
	var text: String = "Checkpoint reached"
	if typeof(payload) == TYPE_DICTIONARY:
		var p: Dictionary = payload
		var cp_id: Variant = p.get("checkpoint_id")
		if cp_id is StringName and String(cp_id) != "":
			text = "Checkpoint: %s" % String(cp_id)

	_show_checkpoint_toast(text)

func _show_checkpoint_toast(text: String) -> void:
	if checkpoint_toast == null or toast_container == null:
		return
	# Do not show toasts while paused
	if _store != null and _is_paused(_store.get_state()):
		return
	checkpoint_toast.text = text
	toast_container.modulate.a = 0.0
	toast_container.visible = true
	_toast_active = true
	# Block interact input while toast is visible
	U_InteractBlocker.block()
	# Avoid overlap with interact prompt while toast is visible
	if interact_prompt != null:
		interact_prompt.hide_prompt()

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	# Fade in
	tween.tween_property(toast_container, "modulate:a", 1.0, 0.2).from(0.0)
	# Hold
	tween.tween_interval(1.0)
	# Fade out
	tween.tween_property(toast_container, "modulate:a", 0.0, 0.3)
	tween.finished.connect(func() -> void:
		toast_container.visible = false
		_toast_active = false
		# Unblock interact with cooldown (0.3s default)
		U_InteractBlocker.unblock_with_cooldown(0.3)
		# Restore prompt if still relevant and not paused
		if not _is_paused(_store.get_state()) and _active_prompt_id != 0 and interact_prompt != null:
			interact_prompt.show_prompt(_last_prompt_action, _last_prompt_text)
	)

func _on_interact_prompt_show(payload: Variant) -> void:
	if interact_prompt == null:
		return
	# Suppress interact prompt while paused (e.g., pause menu open)
	if _store != null and _is_paused(_store.get_state()):
		return
	if typeof(payload) != TYPE_DICTIONARY:
		return
	var event: Dictionary = payload
	var inner_payload: Variant = event.get("payload", {})
	if typeof(inner_payload) != TYPE_DICTIONARY:
		return
	var data: Dictionary = inner_payload
	var controller_id: int = int(data.get("controller_id", 0))
	var action_name: StringName = data.get("action", StringName("interact"))
	var prompt_text: String = String(data.get("prompt", "Interact"))

	_active_prompt_id = controller_id
	_last_prompt_action = action_name
	_last_prompt_text = prompt_text
	# If a toast is currently visible, defer showing the prompt to avoid overlap
	if _toast_active:
		return
	interact_prompt.show_prompt(action_name, prompt_text)

func _on_interact_prompt_hide(payload: Variant) -> void:
	if interact_prompt == null:
		return
	var controller_id: int = 0
	if typeof(payload) == TYPE_DICTIONARY:
		var event: Dictionary = payload
		var inner_payload: Variant = event.get("payload", {})
		if typeof(inner_payload) == TYPE_DICTIONARY:
			controller_id = int((inner_payload as Dictionary).get("controller_id", 0))
	if controller_id != 0 and controller_id != _active_prompt_id:
		return
	_active_prompt_id = 0
	interact_prompt.hide_prompt()

func _on_signpost_message(payload: Variant) -> void:
	var text: String = ""
	if typeof(payload) == TYPE_DICTIONARY:
		var event: Dictionary = payload
		var inner_payload: Variant = event.get("payload", {})
		if typeof(inner_payload) == TYPE_DICTIONARY:
			text = String((inner_payload as Dictionary).get("message", ""))
	else:
		text = String(payload)
	if text.is_empty():
		return
	# Suppress signpost messages while paused
	if _store != null and _is_paused(_store.get_state()):
		return
	_show_checkpoint_toast(text)

## Phase 11: Save event handlers for autosave feedback

func _on_save_started(payload: Variant) -> void:
	# Show "Saving..." toast only for autosaves (not manual saves from menu)
	if typeof(payload) != TYPE_DICTIONARY:
		return
	var event: Dictionary = payload
	var inner_payload: Variant = event.get("payload", {})
	if typeof(inner_payload) != TYPE_DICTIONARY:
		return
	var data: Dictionary = inner_payload
	var is_autosave: bool = data.get("is_autosave", false)

	if is_autosave:
		_show_checkpoint_toast("⏳ Saving...")

func _on_save_completed(payload: Variant) -> void:
	# Show "Game Saved" toast only for autosaves
	if typeof(payload) != TYPE_DICTIONARY:
		return
	var event: Dictionary = payload
	var inner_payload: Variant = event.get("payload", {})
	if typeof(inner_payload) != TYPE_DICTIONARY:
		return
	var data: Dictionary = inner_payload
	var is_autosave: bool = data.get("is_autosave", false)

	if is_autosave:
		_show_checkpoint_toast("Game Saved")

func _on_save_failed(payload: Variant) -> void:
	# Show "Save Failed" toast for all failed saves (autosave or manual)
	if typeof(payload) != TYPE_DICTIONARY:
		return
	var event: Dictionary = payload
	var inner_payload: Variant = event.get("payload", {})
	if typeof(inner_payload) != TYPE_DICTIONARY:
		return
	var data: Dictionary = inner_payload
	var is_autosave: bool = data.get("is_autosave", false)

	if is_autosave:
		_show_checkpoint_toast("Save Failed")

func _format_interact_prompt(action: StringName, prompt_text: String) -> String:
	var action_label := _get_primary_input_label(action)
	if action_label.is_empty():
		action_label = String(action).capitalize()
	var cleaned_prompt := prompt_text
	if cleaned_prompt.is_empty():
		cleaned_prompt = "Interact"
	return "Press [%s] to %s" % [action_label, cleaned_prompt]

func _is_paused(state: Dictionary) -> bool:
	var navigation_state: Dictionary = state.get("navigation", {})
	return U_NavigationSelectors.is_paused(navigation_state)

func _get_primary_input_label(action: StringName) -> String:
	var action_string := String(action)
	if not InputMap.has_action(action_string):
		return ""
	var events := InputMap.action_get_events(action_string)
	for event in events:
		if event is InputEventKey:
			var key_event := event as InputEventKey
			var keycode := key_event.physical_keycode
			if keycode == 0:
				keycode = key_event.keycode
			if keycode != 0:
				return OS.get_keycode_string(keycode)
		elif event is InputEventJoypadButton:
			var joy_event := event as InputEventJoypadButton
			return "GP Btn %d" % joy_event.button_index
		elif event is InputEventMouseButton:
			var mouse_event := event as InputEventMouseButton
			return "Mouse %d" % mouse_event.button_index
	return ""
