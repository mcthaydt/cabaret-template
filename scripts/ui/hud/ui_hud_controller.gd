@icon("res://assets/editor_icons/icn_utility.svg")
extends CanvasLayer
class_name UI_HudController


@onready var pause_label: Label = $MarginContainer/VBoxContainer/PauseLabel
@onready var health_bar: ProgressBar = $MarginContainer/VBoxContainer/HealthBar
@onready var health_label: Label = $MarginContainer/VBoxContainer/HealthBar/HealthLabel
@onready var toast_container: Control = $MarginContainer/ToastContainer
@onready var checkpoint_toast: Label = $MarginContainer/ToastContainer/PanelContainer/MarginContainer/CheckpointToast
@onready var autosave_spinner_container: Control = $MarginContainer/AutosaveSpinnerContainer
@onready var autosave_spinner_icon: TextureRect = $MarginContainer/AutosaveSpinnerContainer/PanelContainer/MarginContainer/HBoxContainer/SpinnerIcon
@onready var autosave_spinner_label: Label = $MarginContainer/AutosaveSpinnerContainer/PanelContainer/MarginContainer/HBoxContainer/SpinnerLabel
@onready var signpost_panel_container: Control = $SignpostPanelContainer
@onready var signpost_message_label: Label = $SignpostPanelContainer/PanelContainer/MarginContainer/SignpostMessage
@onready var interact_prompt: UI_ButtonPrompt = $MarginContainer/InteractPrompt

const SIGNPOST_DEFAULT_DURATION_SEC: float = 3.0
const SIGNPOST_MIN_DURATION_SEC: float = 0.05
const SIGNPOST_PANEL_FADE_IN_SEC: float = 0.14
const SIGNPOST_PANEL_FADE_OUT_SEC: float = 0.18
const SIGNPOST_BLOCKER_COOLDOWN_SEC: float = 0.15
const AUTOSAVE_SPINNER_ROTATION_SPEED_DEG: float = 240.0
const AUTOSAVE_SPINNER_MIN_VISIBLE_SEC: float = 0.35

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
var _autosave_spinner_active: bool = false
var _autosave_spinner_visible_since_sec: float = -1.0
var _autosave_spinner_hide_request_id: int = 0
var _signpost_panel_active: bool = false
var _checkpoint_toast_tween: Tween = null
var _signpost_panel_tween: Tween = null
var _health_bar_bg_style: StyleBoxFlat = null
var _health_bar_fill_style: StyleBoxFlat = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_localize_static_labels()
	_store = U_StateUtils.get_store(self)

	if _store == null:
		push_error("HUD: Could not find M_StateStore")
		return

	_player_entity_id = String(_store.get_slice(StringName("gameplay")).get("player_entity_id", "player"))
	_store.slice_updated.connect(_on_slice_updated)

	# Grab direct references to the scene's StyleBoxFlat resources
	if health_bar != null:
		var bg_style := health_bar.get_theme_stylebox("background")
		if bg_style is StyleBoxFlat:
			_health_bar_bg_style = bg_style as StyleBoxFlat
		var fill_style := health_bar.get_theme_stylebox("fill")
		if fill_style is StyleBoxFlat:
			_health_bar_fill_style = fill_style as StyleBoxFlat

	# Defer reparent AND event subscriptions to avoid tree modifications during _ready
	# and to ensure subscriptions happen AFTER reparenting (which triggers _exit_tree)
	call_deferred("_complete_initialization")

func _complete_initialization() -> void:
	# Reparent first
	_reparent_to_root_hud_layer()
	_register_with_scene_manager()

	# Then subscribe to events (after reparenting to avoid unsubscribe in _exit_tree)
	_unsubscribe_checkpoint = U_ECSEventBus.subscribe(StringName("checkpoint_activated"), _on_checkpoint_event)
	_unsubscribe_interact_prompt_show = U_ECSEventBus.subscribe(StringName("interact_prompt_show"), _on_interact_prompt_show)
	_unsubscribe_interact_prompt_hide = U_ECSEventBus.subscribe(StringName("interact_prompt_hide"), _on_interact_prompt_hide)
	_unsubscribe_signpost = U_ECSEventBus.subscribe(StringName("signpost_message"), _on_signpost_message)

	# Subscribe to save events for autosave feedback (Phase 11)
	_unsubscribe_save_started = U_ECSEventBus.subscribe(StringName("save_started"), _on_save_started)
	_unsubscribe_save_completed = U_ECSEventBus.subscribe(StringName("save_completed"), _on_save_completed)
	_unsubscribe_save_failed = U_ECSEventBus.subscribe(StringName("save_failed"), _on_save_failed)
	_update_display(_store.get_state())

func _process(delta: float) -> void:
	if _store == null or not is_instance_valid(_store):
		return
	# Keep HUD visibility in sync even if a slice update arrives between frames.
	_update_display(_store.get_state())
	_update_autosave_spinner_animation(delta)

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
	var scene_manager := U_ServiceLocator.try_get_service(StringName("scene_manager")) as I_SceneManager
	if scene_manager != null:
		scene_manager.register_hud_controller(self)

func _unregister_from_scene_manager() -> void:
	var scene_manager := U_ServiceLocator.try_get_service(StringName("scene_manager")) as I_SceneManager
	if scene_manager != null:
		scene_manager.unregister_hud_controller(self)

func _on_slice_updated(slice_name: StringName, __slice_state: Dictionary) -> void:
	if _store == null:
		return
	if slice_name != StringName("gameplay") \
			and slice_name != StringName("scene") \
			and slice_name != StringName("navigation") \
			and slice_name != StringName("display") \
			and slice_name != StringName("localization"):
		return

	var state := _store.get_state()
	_update_display(state)
	if _is_paused(state):
		if interact_prompt != null:
			interact_prompt.hide_prompt()
		_hide_checkpoint_toast_immediate()
		_hide_autosave_spinner()
		_hide_signpost_panel()
		# Force unblock interact when paused (no interactions possible anyway)
		U_InteractBlocker.force_unblock()

func _on_locale_changed(_locale: StringName) -> void:
	_localize_static_labels()

func _localize_static_labels() -> void:
	if autosave_spinner_label != null:
		autosave_spinner_label.text = U_LocalizationUtils.localize(&"hud.autosave_saving")

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

	# Update health bar colors based on color blind palette and health percentage
	_update_health_bar_colors(state, health, max_health)

## ECS: Show a brief toast when a checkpoint is activated
func _on_checkpoint_event(payload: Variant) -> void:
	var text: String = _build_checkpoint_toast_text(payload)
	_show_checkpoint_toast(text)

func _show_checkpoint_toast(text: String) -> void:
	if checkpoint_toast == null or toast_container == null:
		return
	# Do not show toasts while paused
	if _store != null and _is_paused(_store.get_state()):
		return
	_hide_autosave_spinner()
	_hide_signpost_panel(false)
	_cancel_checkpoint_toast_tween()
	checkpoint_toast.text = text
	toast_container.modulate.a = 0.0
	toast_container.visible = true
	_toast_active = true
	# Block interact input while toast is visible
	U_InteractBlocker.block()
	# Avoid overlap with interact prompt while toast is visible
	if interact_prompt != null:
		interact_prompt.hide_prompt()

	_checkpoint_toast_tween = create_tween()
	_checkpoint_toast_tween.set_trans(Tween.TRANS_CUBIC)
	_checkpoint_toast_tween.set_ease(Tween.EASE_IN_OUT)
	# Fade in
	_checkpoint_toast_tween.tween_property(toast_container, "modulate:a", 1.0, 0.2).from(0.0)
	# Hold
	_checkpoint_toast_tween.tween_interval(1.0)
	# Fade out
	_checkpoint_toast_tween.tween_property(toast_container, "modulate:a", 0.0, 0.3)
	_checkpoint_toast_tween.finished.connect(func() -> void:
		_checkpoint_toast_tween = null
		toast_container.visible = false
		_toast_active = false
		# Unblock interact with cooldown (0.3s default)
		U_InteractBlocker.unblock_with_cooldown(0.3)
		# Restore prompt if still relevant and not paused
		if not _is_paused(_store.get_state()) and _active_prompt_id != 0 and interact_prompt != null:
			interact_prompt.show_prompt(_last_prompt_action, _last_prompt_text)
		)

func _build_checkpoint_toast_text(event_payload: Variant) -> String:
	var default_text: String = U_LocalizationUtils.localize(&"hud.checkpoint_reached")
	var with_label_template: String = U_LocalizationUtils.localize(&"hud.checkpoint_with_label")
	var payload := _extract_event_payload(event_payload)
	if payload.is_empty():
		return default_text

	var explicit_label: String = String(payload.get("checkpoint_label", payload.get("display_name", ""))).strip_edges()
	if not explicit_label.is_empty():
		return with_label_template % explicit_label if with_label_template.contains("%") else "Checkpoint: %s" % explicit_label

	var checkpoint_id_value: Variant = payload.get("checkpoint_id", StringName(""))
	var checkpoint_id: String = String(checkpoint_id_value).strip_edges()
	var readable_name: String = _humanize_checkpoint_id(checkpoint_id)
	if readable_name.is_empty():
		return default_text
	return with_label_template % readable_name if with_label_template.contains("%") else "Checkpoint: %s" % readable_name

func _humanize_checkpoint_id(raw_id: String) -> String:
	var cleaned := raw_id.strip_edges()
	if cleaned.is_empty():
		return ""
	if cleaned.begins_with("cp_"):
		cleaned = cleaned.substr(3)
	cleaned = cleaned.replace("_", " ").replace("-", " ").strip_edges()
	if cleaned.is_empty():
		return ""
	var words: PackedStringArray = cleaned.split(" ", false)
	for i in words.size():
		words[i] = words[i].capitalize()
	return String(" ").join(words)

func _extract_event_payload(event_payload: Variant) -> Dictionary:
	if typeof(event_payload) != TYPE_DICTIONARY:
		return {}
	var event: Dictionary = event_payload
	var nested: Variant = event.get("payload", null)
	if typeof(nested) == TYPE_DICTIONARY:
		return nested as Dictionary
	return event

func _hide_checkpoint_toast_immediate() -> void:
	var was_active: bool = _toast_active
	_cancel_checkpoint_toast_tween()
	if toast_container == null:
		return
	toast_container.visible = false
	_toast_active = false
	if was_active:
		# If toast was interrupted, clear blocker immediately to avoid stale input lock.
		U_InteractBlocker.force_unblock()

func _cancel_checkpoint_toast_tween() -> void:
	if _checkpoint_toast_tween == null:
		return
	if is_instance_valid(_checkpoint_toast_tween):
		_checkpoint_toast_tween.kill()
	_checkpoint_toast_tween = null

func _show_autosave_spinner() -> void:
	if autosave_spinner_container == null:
		return
	if _store != null and _is_paused(_store.get_state()):
		return
	_hide_checkpoint_toast_immediate()
	_hide_signpost_panel(true)
	# Autosave feedback should never block interact input.
	U_InteractBlocker.force_unblock()
	autosave_spinner_container.visible = true
	if autosave_spinner_icon != null:
		autosave_spinner_icon.rotation_degrees = 0.0
	_autosave_spinner_active = true
	_autosave_spinner_visible_since_sec = Time.get_ticks_msec() / 1000.0
	_autosave_spinner_hide_request_id += 1

func _hide_autosave_spinner() -> void:
	_autosave_spinner_hide_request_id += 1
	if autosave_spinner_container == null:
		return
	autosave_spinner_container.visible = false
	if autosave_spinner_icon != null:
		autosave_spinner_icon.rotation_degrees = 0.0
	_autosave_spinner_active = false
	_autosave_spinner_visible_since_sec = -1.0

func _request_hide_autosave_spinner() -> void:
	if not _autosave_spinner_active:
		return

	var now_sec: float = Time.get_ticks_msec() / 1000.0
	var elapsed_sec: float = 0.0
	if _autosave_spinner_visible_since_sec >= 0.0:
		elapsed_sec = maxf(now_sec - _autosave_spinner_visible_since_sec, 0.0)

	if elapsed_sec >= AUTOSAVE_SPINNER_MIN_VISIBLE_SEC:
		_hide_autosave_spinner()
		return

	var tree := get_tree()
	if tree == null:
		_hide_autosave_spinner()
		return

	var remaining_sec: float = maxf(AUTOSAVE_SPINNER_MIN_VISIBLE_SEC - elapsed_sec, 0.0)
	_autosave_spinner_hide_request_id += 1
	var request_id: int = _autosave_spinner_hide_request_id
	var timer := tree.create_timer(remaining_sec, true, false, true)
	timer.timeout.connect(func() -> void:
		if request_id != _autosave_spinner_hide_request_id:
			return
		_hide_autosave_spinner()
	)

func _update_autosave_spinner_animation(delta: float) -> void:
	if not _autosave_spinner_active:
		return
	if autosave_spinner_icon == null:
		return
	autosave_spinner_icon.rotation_degrees = wrapf(
		autosave_spinner_icon.rotation_degrees + AUTOSAVE_SPINNER_ROTATION_SPEED_DEG * delta,
		0.0,
		360.0
	)

func _show_signpost_panel(text: String, duration_sec: float = SIGNPOST_DEFAULT_DURATION_SEC) -> void:
	if signpost_panel_container == null:
		return
	if _store != null and _is_paused(_store.get_state()):
		return
	_hide_checkpoint_toast_immediate()
	_hide_autosave_spinner()
	_hide_signpost_panel(false)
	if signpost_message_label != null:
		signpost_message_label.text = text
	signpost_panel_container.modulate.a = 0.0
	signpost_panel_container.visible = true
	_signpost_panel_active = true
	U_InteractBlocker.block()
	if interact_prompt != null:
		interact_prompt.hide_prompt()

	var effective_duration := maxf(duration_sec, SIGNPOST_MIN_DURATION_SEC)
	_signpost_panel_tween = create_tween()
	_signpost_panel_tween.set_trans(Tween.TRANS_CUBIC)
	_signpost_panel_tween.set_ease(Tween.EASE_OUT)
	_signpost_panel_tween.tween_property(signpost_panel_container, "modulate:a", 1.0, SIGNPOST_PANEL_FADE_IN_SEC).from(0.0)
	_signpost_panel_tween.tween_interval(effective_duration)
	_signpost_panel_tween.set_ease(Tween.EASE_IN)
	_signpost_panel_tween.tween_property(signpost_panel_container, "modulate:a", 0.0, SIGNPOST_PANEL_FADE_OUT_SEC)
	_signpost_panel_tween.finished.connect(_on_signpost_panel_finished)

func _hide_signpost_panel(restore_prompt: bool = false) -> void:
	var was_active: bool = _signpost_panel_active
	_cancel_signpost_panel_tween()
	if signpost_panel_container == null:
		return
	signpost_panel_container.visible = false
	signpost_panel_container.modulate.a = 1.0
	_signpost_panel_active = false
	if was_active:
		U_InteractBlocker.force_unblock()
		if restore_prompt and _store != null and not _is_paused(_store.get_state()) and _active_prompt_id != 0 and interact_prompt != null:
			interact_prompt.show_prompt(_last_prompt_action, _last_prompt_text)

func _cancel_signpost_panel_tween() -> void:
	if _signpost_panel_tween == null:
		return
	if is_instance_valid(_signpost_panel_tween):
		_signpost_panel_tween.kill()
	_signpost_panel_tween = null

func _on_signpost_panel_finished() -> void:
	_signpost_panel_tween = null
	if signpost_panel_container != null:
		signpost_panel_container.visible = false
		signpost_panel_container.modulate.a = 1.0
	var was_active: bool = _signpost_panel_active
	_signpost_panel_active = false
	if not was_active:
		return
	U_InteractBlocker.unblock_with_cooldown(SIGNPOST_BLOCKER_COOLDOWN_SEC)
	if _store != null and not _is_paused(_store.get_state()) and _active_prompt_id != 0 and interact_prompt != null:
		interact_prompt.show_prompt(_last_prompt_action, _last_prompt_text)

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
	var prompt_key: String = String(data.get("prompt", "hud.interact_default"))
	var prompt_text: String = U_LocalizationUtils.localize(StringName(prompt_key))

	_active_prompt_id = controller_id
	_last_prompt_action = action_name
	_last_prompt_text = prompt_text
	# If another feedback surface is currently visible, defer prompt rendering to avoid overlap.
	if _toast_active or _signpost_panel_active:
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

func _reparent_to_root_hud_layer() -> void:
	# Reparent HUD to root HUDLayer to escape SubViewport rendering
	var tree := get_tree()
	if tree == null:
		return

	var root_hud_layer := tree.root.find_child("HUDLayer", true, false)
	if root_hud_layer == null:
		push_warning("HUD: Could not find HUDLayer in root - HUD will render inside viewport")
		return

	var current_parent := get_parent()
	if current_parent == null or current_parent == root_hud_layer:
		return

	# Reparent to root HUD layer
	current_parent.remove_child(self)
	root_hud_layer.add_child(self)

	# Set layer to 6 to render AFTER post-processing (layers 1-5) but BEFORE UI overlays (layer 10)
	# When CanvasLayers are nested, child layer number determines render order, not parent
	layer = 6

func _on_signpost_message(payload: Variant) -> void:
	var data := _extract_event_payload(payload)
	var raw: String = String(data.get("message", ""))
	var text: String = U_LocalizationUtils.localize(StringName(raw))
	var duration_sec: float = _resolve_signpost_duration(data)
	if text.is_empty():
		return
	# Suppress signpost messages while paused
	if _store != null and _is_paused(_store.get_state()):
		return
	_show_signpost_panel(text, duration_sec)

func _resolve_signpost_duration(payload: Dictionary) -> float:
	var duration_variant: Variant = payload.get("message_duration_sec", SIGNPOST_DEFAULT_DURATION_SEC)
	var duration_sec: float = SIGNPOST_DEFAULT_DURATION_SEC
	if duration_variant is float:
		duration_sec = duration_variant
	elif duration_variant is int:
		duration_sec = float(duration_variant)
	if duration_sec <= 0.0:
		return SIGNPOST_DEFAULT_DURATION_SEC
	return duration_sec

## Phase 11: Save event handlers for autosave feedback

func _on_save_started(payload: Variant) -> void:
	# Show autosave spinner only for autosaves (not manual saves from menu)
	if typeof(payload) != TYPE_DICTIONARY:
		return
	var event: Dictionary = payload
	var inner_payload: Variant = event.get("payload", {})
	if typeof(inner_payload) != TYPE_DICTIONARY:
		return
	var data: Dictionary = inner_payload
	var is_autosave: bool = data.get("is_autosave", false)

	if is_autosave:
		_show_autosave_spinner()

func _on_save_completed(payload: Variant) -> void:
	# Hide autosave spinner only for autosaves
	if typeof(payload) != TYPE_DICTIONARY:
		return
	var event: Dictionary = payload
	var inner_payload: Variant = event.get("payload", {})
	if typeof(inner_payload) != TYPE_DICTIONARY:
		return
	var data: Dictionary = inner_payload
	var is_autosave: bool = data.get("is_autosave", false)

	if is_autosave:
		_request_hide_autosave_spinner()

func _on_save_failed(payload: Variant) -> void:
	# Hide autosave spinner on autosave failures.
	if typeof(payload) != TYPE_DICTIONARY:
		return
	var event: Dictionary = payload
	var inner_payload: Variant = event.get("payload", {})
	if typeof(inner_payload) != TYPE_DICTIONARY:
		return
	var data: Dictionary = inner_payload
	var is_autosave: bool = data.get("is_autosave", false)

	if is_autosave:
		_request_hide_autosave_spinner()

func _is_paused(state: Dictionary) -> bool:
	var navigation_state: Dictionary = state.get("navigation", {})
	return U_NavigationSelectors.is_paused(navigation_state)

func _update_health_bar_colors(__state: Dictionary, health: float, max_health: float) -> void:
	if _health_bar_fill_style == null:
		return

	var display_mgr := U_ServiceLocator.try_get_service(StringName("display_manager")) as I_DisplayManager
	if display_mgr == null:
		return
	var active_palette: Resource = display_mgr.get_active_palette()
	if active_palette == null:
		return

	# Determine which color to use based on health percentage
	var health_percent: float = health / max_health if max_health > 0.0 else 0.0
	var target_color: Color

	# Access palette colors via .get() to avoid class_name resolution issues
	if health_percent >= 0.6:
		target_color = active_palette.get("success") as Color
	elif health_percent >= 0.3:
		target_color = active_palette.get("warning") as Color
	else:
		target_color = active_palette.get("danger") as Color

	# Apply the color to the health bar fill
	_health_bar_fill_style.bg_color = target_color
