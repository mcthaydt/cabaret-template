@icon("res://assets/editor_icons/icn_utility.svg")
extends CanvasLayer
class_name UI_HudController

const U_UI_THEME_BUILDER := preload("res://scripts/core/ui/utils/u_ui_theme_builder.gd")
const RS_UI_THEME_CONFIG := preload("res://scripts/core/resources/ui/rs_ui_theme_config.gd")
const RS_UI_MOTION_SET := preload("res://scripts/core/resources/ui/rs_ui_motion_set.gd")
const RS_UI_MOTION_PRESET := preload("res://scripts/core/resources/ui/rs_ui_motion_preset.gd")
const U_UI_MOTION := preload("res://scripts/core/ui/utils/u_ui_motion.gd")
const U_SAVE_ACTIONS := preload("res://scripts/core/state/actions/u_save_actions.gd")

@export var checkpoint_toast_motion_set: Resource = preload("res://resources/ui/motions/cfg_motion_hud_checkpoint_toast.tres")
@export var signpost_fade_in_preset: Resource = preload("res://resources/ui/motions/cfg_motion_hud_signpost_fade_in.tres")
@export var signpost_fade_out_preset: Resource = preload("res://resources/ui/motions/cfg_motion_hud_signpost_fade_out.tres")

@onready var hud_margin_container: MarginContainer = $MarginContainer
@onready var pause_label: Label = $MarginContainer/VBoxContainer/PauseLabel
@onready var health_container: HBoxContainer = $MarginContainer/VBoxContainer/HealthContainer
@onready var life_label: Label = $MarginContainer/VBoxContainer/HealthContainer/LifeLabel
@onready var health_bar: ProgressBar = $MarginContainer/VBoxContainer/HealthContainer/HealthBar
@onready var health_label: Label = $MarginContainer/VBoxContainer/HealthContainer/HealthBar/HealthLabel
@onready var toast_container: Control = $MarginContainer/ToastContainer
@onready var toast_margin_container: MarginContainer = $MarginContainer/ToastContainer/PanelContainer/MarginContainer
@onready var checkpoint_toast: Label = $MarginContainer/ToastContainer/PanelContainer/MarginContainer/CheckpointToast
@onready var autosave_spinner_container: Control = $MarginContainer/AutosaveSpinnerContainer
@onready var autosave_panel: PanelContainer = $MarginContainer/AutosaveSpinnerContainer/PanelContainer
@onready var autosave_margin_container: MarginContainer = $MarginContainer/AutosaveSpinnerContainer/PanelContainer/MarginContainer
@onready var autosave_hbox: HBoxContainer = $MarginContainer/AutosaveSpinnerContainer/PanelContainer/MarginContainer/HBoxContainer
@onready var autosave_spinner_icon: TextureRect = $MarginContainer/AutosaveSpinnerContainer/PanelContainer/MarginContainer/HBoxContainer/SpinnerIcon
@onready var autosave_spinner_label: Label = $MarginContainer/AutosaveSpinnerContainer/PanelContainer/MarginContainer/HBoxContainer/SpinnerLabel
@onready var signpost_panel_container: Control = $SignpostPanelContainer
@onready var signpost_panel: PanelContainer = $SignpostPanelContainer/PanelContainer
@onready var signpost_margin_container: MarginContainer = $SignpostPanelContainer/PanelContainer/MarginContainer
@onready var signpost_message_label: Label = $SignpostPanelContainer/PanelContainer/MarginContainer/SignpostMessage
@onready var interact_prompt: UI_ButtonPrompt = $MarginContainer/InteractPrompt

const SIGNPOST_DEFAULT_DURATION_SEC: float = 3.0
const SIGNPOST_MIN_DURATION_SEC: float = 0.05
const SIGNPOST_PANEL_FADE_IN_FALLBACK_SEC: float = 0.14
const SIGNPOST_PANEL_FADE_OUT_FALLBACK_SEC: float = 0.18
const SIGNPOST_BLOCKER_COOLDOWN_SEC: float = 0.15
const AUTOSAVE_SPINNER_ROTATION_SPEED_DEG: float = 240.0
const AUTOSAVE_SPINNER_MIN_VISIBLE_SEC: float = 0.35
const CHECKPOINT_TOAST_UNBLOCK_COOLDOWN_SEC: float = 0.3

var _store: I_StateStore = null
var _player_entity_id: String = "player"
var _unsubscribe_checkpoint: Callable
var _unsubscribe_interact_prompt_show: Callable
var _unsubscribe_interact_prompt_hide: Callable
var _unsubscribe_signpost: Callable
var _active_prompt_id: int = 0
var _last_prompt_key: StringName = &"hud.interact_default"
var _last_prompt_action: StringName = StringName("interact")
var _last_prompt_text: String = ""
var _toast_active: bool = false
var _autosave_spinner_active: bool = false
var _autosave_spinner_visible_since_sec: float = -1.0
var _autosave_spinner_hide_request_id: int = 0
var _signpost_panel_active: bool = false
var _checkpoint_toast_tween: Tween = null
var _signpost_panel_tween: Tween = null
var _health_bar_fill_style: StyleBoxFlat = null
var _pending_prompt_localization_refresh: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_theme_tokens()
	_localize_static_labels()
	_store = U_StateUtils.get_store(self)

	if _store == null:
		push_error("HUD: Could not find M_StateStore")
		return

	_player_entity_id = String(_store.get_slice(StringName("gameplay")).get("player_entity_id", "player"))
	_store.slice_updated.connect(_on_slice_updated)

	# Grab direct references to the active ProgressBar style resources.
	if health_bar != null:
		var fill_style := health_bar.get_theme_stylebox("fill")
		if fill_style is StyleBoxFlat:
			_health_bar_fill_style = fill_style as StyleBoxFlat

	# Defer event subscriptions to avoid signal churn during _ready.
	call_deferred("_complete_initialization")

func _complete_initialization() -> void:
	# Subscribe to events after deferred initialization.
	_unsubscribe_checkpoint = U_ECSEventBus.subscribe(StringName("checkpoint_activated"), _on_checkpoint_event)
	_unsubscribe_interact_prompt_show = U_ECSEventBus.subscribe(StringName("interact_prompt_show"), _on_interact_prompt_show)
	_unsubscribe_interact_prompt_hide = U_ECSEventBus.subscribe(StringName("interact_prompt_hide"), _on_interact_prompt_hide)
	_unsubscribe_signpost = U_ECSEventBus.subscribe(StringName("signpost_message"), _on_signpost_message)

	# Subscribe to save actions via Redux (channel taxonomy: managers dispatch to Redux)
	if _store != null and _store.has_signal("action_dispatched"):
		_store.action_dispatched.connect(_on_action_dispatched)
	_update_display(_store.get_state())

func _process(delta: float) -> void:
	if _store == null or not is_instance_valid(_store):
		return
	# Keep HUD visibility in sync even if a slice update arrives between frames.
	_update_display(_store.get_state())
	_update_autosave_spinner_animation(delta)

func _exit_tree() -> void:
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
	if _store != null and _store.has_signal("action_dispatched"):
		if _store.action_dispatched.is_connected(_on_action_dispatched):
			_store.action_dispatched.disconnect(_on_action_dispatched)

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
		return
	if slice_name == StringName("localization"):
		_queue_prompt_localization_refresh()

func _on_locale_changed(_locale: StringName) -> void:
	_localize_static_labels()
	_refresh_active_prompt_localization()

func _localize_static_labels() -> void:
	if autosave_spinner_label != null:
		autosave_spinner_label.text = U_LocalizationUtils.localize(&"hud.autosave_saving")

func _apply_theme_tokens() -> void:
	var config_resource: Resource = U_UI_THEME_BUILDER.active_config
	if not (config_resource is RS_UI_THEME_CONFIG):
		return
	var config := config_resource as RS_UI_THEME_CONFIG

	if hud_margin_container != null:
		hud_margin_container.add_theme_constant_override(&"margin_left", config.margin_outer)
		hud_margin_container.add_theme_constant_override(&"margin_top", config.margin_outer)
		hud_margin_container.add_theme_constant_override(&"margin_right", config.margin_outer)
		hud_margin_container.add_theme_constant_override(&"margin_bottom", config.margin_outer)

	if pause_label != null:
		pause_label.add_theme_font_size_override(&"font_size", config.heading)
	if health_container != null:
		health_container.add_theme_constant_override(&"separation", config.separation_compact)
	if life_label != null:
		life_label.add_theme_color_override(&"font_color", config.accent_primary)
		life_label.add_theme_color_override(&"font_outline_color", config.bg_base)
		life_label.add_theme_constant_override(&"outline_size", 4)
	if health_label != null:
		health_label.add_theme_font_size_override(&"font_size", config.body_small)

	if toast_margin_container != null:
		toast_margin_container.add_theme_constant_override(&"margin_left", config.margin_inner)
		toast_margin_container.add_theme_constant_override(&"margin_top", config.separation_compact)
		toast_margin_container.add_theme_constant_override(&"margin_right", config.margin_inner)
		toast_margin_container.add_theme_constant_override(&"margin_bottom", config.separation_compact)
	if checkpoint_toast != null:
		checkpoint_toast.add_theme_font_size_override(&"font_size", config.body_small)

	if autosave_panel != null:
		# Keep autosave chrome intentionally transparent while removing scene-local subresources.
		autosave_panel.add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
	if autosave_margin_container != null:
		autosave_margin_container.add_theme_constant_override(&"margin_left", 0)
		autosave_margin_container.add_theme_constant_override(&"margin_top", 0)
		autosave_margin_container.add_theme_constant_override(&"margin_right", 0)
		autosave_margin_container.add_theme_constant_override(&"margin_bottom", 0)
	if autosave_hbox != null:
		autosave_hbox.add_theme_constant_override(&"separation", 0)
	if autosave_spinner_label != null:
		autosave_spinner_label.add_theme_font_size_override(&"font_size", config.caption)

	if signpost_panel != null and config.panel_signpost != null:
		signpost_panel.add_theme_stylebox_override(&"panel", config.panel_signpost)
	if signpost_margin_container != null:
		var signpost_horizontal_margin: int = config.margin_outer + config.separation_compact
		var signpost_vertical_margin: int = config.margin_section + int(round(config.separation_compact * 0.25))
		signpost_margin_container.add_theme_constant_override(&"margin_left", signpost_horizontal_margin)
		signpost_margin_container.add_theme_constant_override(&"margin_top", signpost_vertical_margin)
		signpost_margin_container.add_theme_constant_override(&"margin_right", signpost_horizontal_margin)
		signpost_margin_container.add_theme_constant_override(&"margin_bottom", signpost_vertical_margin)
	if signpost_message_label != null:
		signpost_message_label.add_theme_font_size_override(&"font_size", config.body)
		signpost_message_label.add_theme_constant_override(
			&"line_spacing",
			maxi(1, int(round(config.separation_compact * 0.5)))
		)
		signpost_message_label.add_theme_color_override(&"font_color", config.golden)

func _update_display(state: Dictionary) -> void:
	_sync_visibility(state)
	if not visible:
		return
	pause_label.text = ""
	_update_health(state)

func _sync_visibility(state: Dictionary) -> void:
	var should_show: bool = _should_show_hud(state)
	if visible == should_show:
		return

	visible = should_show
	if visible:
		return

	if interact_prompt != null:
		interact_prompt.hide_prompt()
	_hide_checkpoint_toast_immediate()
	_hide_autosave_spinner()
	_hide_signpost_panel()
	U_InteractBlocker.force_unblock()

func _should_show_hud(state: Dictionary) -> bool:
	var scene_state: Dictionary = state.get("scene", {})
	var is_transitioning: bool = scene_state.get("is_transitioning", false)
	if is_transitioning:
		return false

	var navigation_state: Dictionary = state.get("navigation", {})
	var shell: StringName = navigation_state.get("shell", StringName())
	return shell == StringName("gameplay")

func _update_health(state: Dictionary) -> void:
	if health_container == null or health_bar == null:
		return

	# Hide health container when any menu/overlay is open
	if _is_paused(state):
		health_container.visible = false
		return

	# Only show health bar during active gameplay shell
	# Don't show when transitioning to/from gameplay (shell != "gameplay")
	var navigation_state: Dictionary = state.get("navigation", {})
	var shell: StringName = navigation_state.get("shell", StringName())

	if shell != StringName("gameplay"):
		health_container.visible = false
		return

	# Show health bar during active gameplay
	health_container.visible = true

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
	var using_motion_resource: bool = _append_motion_sequence(
		_checkpoint_toast_tween,
		toast_container,
		checkpoint_toast_motion_set,
		&"enter"
	)
	if not using_motion_resource:
		_checkpoint_toast_tween.set_trans(Tween.TRANS_CUBIC)
		_checkpoint_toast_tween.set_ease(Tween.EASE_IN_OUT)
		_checkpoint_toast_tween.tween_property(toast_container, "modulate:a", 1.0, 0.2).from(0.0)
		_checkpoint_toast_tween.tween_interval(1.0)
		_checkpoint_toast_tween.tween_property(toast_container, "modulate:a", 0.0, 0.3)
	_checkpoint_toast_tween.finished.connect(func() -> void:
		_checkpoint_toast_tween = null
		toast_container.visible = false
		_toast_active = false
		# Unblock interact with a short cooldown to avoid immediate re-trigger.
		U_InteractBlocker.unblock_with_cooldown(CHECKPOINT_TOAST_UNBLOCK_COOLDOWN_SEC)
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
	var using_signpost_fade_in: bool = _append_motion_preset_step(
		_signpost_panel_tween,
		signpost_panel_container,
		signpost_fade_in_preset
	)
	if not using_signpost_fade_in:
		_signpost_panel_tween.set_trans(Tween.TRANS_CUBIC)
		_signpost_panel_tween.set_ease(Tween.EASE_OUT)
		_signpost_panel_tween.tween_property(
			signpost_panel_container,
			"modulate:a",
			1.0,
			SIGNPOST_PANEL_FADE_IN_FALLBACK_SEC
		).from(0.0)
	_signpost_panel_tween.tween_interval(effective_duration)
	var using_signpost_fade_out: bool = _append_motion_preset_step(
		_signpost_panel_tween,
		signpost_panel_container,
		signpost_fade_out_preset
	)
	if not using_signpost_fade_out:
		_signpost_panel_tween.set_trans(Tween.TRANS_CUBIC)
		_signpost_panel_tween.set_ease(Tween.EASE_IN)
		_signpost_panel_tween.tween_property(
			signpost_panel_container,
			"modulate:a",
			0.0,
			SIGNPOST_PANEL_FADE_OUT_FALLBACK_SEC
		)
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
	var prompt_key: StringName = StringName(str(data.get("prompt", "hud.interact_default")))
	var prompt_text: String = U_LocalizationUtils.localize(prompt_key)

	_active_prompt_id = controller_id
	_last_prompt_key = prompt_key
	_last_prompt_action = action_name
	_last_prompt_text = prompt_text
	# If another feedback surface is currently visible, defer prompt rendering to avoid overlap.
	if _toast_active or _signpost_panel_active:
		return
	interact_prompt.show_prompt(action_name, prompt_text)

func _queue_prompt_localization_refresh() -> void:
	if _pending_prompt_localization_refresh:
		return
	_pending_prompt_localization_refresh = true
	call_deferred("_apply_prompt_localization_refresh")

func _apply_prompt_localization_refresh() -> void:
	_pending_prompt_localization_refresh = false
	_refresh_active_prompt_localization()

func _refresh_active_prompt_localization() -> void:
	if interact_prompt == null or _active_prompt_id == 0:
		return
	_last_prompt_text = U_LocalizationUtils.localize(_last_prompt_key)
	if _store != null and _is_paused(_store.get_state()):
		interact_prompt.hide_prompt()
		return
	if _toast_active or _signpost_panel_active:
		return
	interact_prompt.show_prompt(_last_prompt_action, _last_prompt_text)

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

func _append_motion_sequence(
	tween: Tween,
	target: Node,
	motion_set_resource: Resource,
	sequence_name: StringName
) -> bool:
	if tween == null or target == null:
		return false
	if not (motion_set_resource is RS_UI_MOTION_SET):
		return false
	var motion_set := motion_set_resource as RS_UI_MOTION_SET
	var presets: Array[Resource] = []
	match sequence_name:
		&"enter":
			presets = motion_set.enter
		&"exit":
			presets = motion_set.exit
		&"hover_in":
			presets = motion_set.hover_in
		&"hover_out":
			presets = motion_set.hover_out
		&"press":
			presets = motion_set.press
		&"focus_in":
			presets = motion_set.focus_in
		&"focus_out":
			presets = motion_set.focus_out
		&"pulse":
			presets = motion_set.pulse
		_:
			return false

	var appended_any: bool = false
	for preset_resource in presets:
		if U_UI_MOTION.append_step(tween, target, preset_resource):
			appended_any = true
	return appended_any

func _append_motion_preset_step(tween: Tween, target: Node, preset_resource: Resource) -> bool:
	return U_UI_MOTION.append_step(tween, target, preset_resource)

## Phase 11: Save event handlers for autosave feedback

## Channel taxonomy: save actions arrive via Redux dispatch (managers dispatch to Redux)
func _on_action_dispatched(action: Dictionary) -> void:
	var action_type: StringName = action.get("type", StringName(""))
	var is_autosave: bool = action.get("is_autosave", false)

	if action_type == U_SAVE_ACTIONS.ACTION_SAVE_STARTED:
		if is_autosave:
			_show_autosave_spinner()
	elif action_type == U_SAVE_ACTIONS.ACTION_SAVE_COMPLETED:
		if is_autosave:
			_request_hide_autosave_spinner()
	elif action_type == U_SAVE_ACTIONS.ACTION_SAVE_FAILED:
		if is_autosave:
			_request_hide_autosave_spinner()

func _is_paused(state: Dictionary) -> bool:
	var navigation_state: Dictionary = state.get("navigation", {})
	return U_NavigationSelectors.is_paused(navigation_state)

func _update_health_bar_colors(__state: Dictionary, health: float, max_health: float) -> void:
	if _health_bar_fill_style == null and health_bar != null:
		var fill_style: StyleBox = health_bar.get_theme_stylebox("fill")
		if fill_style is StyleBoxFlat:
			_health_bar_fill_style = fill_style as StyleBoxFlat
	if _health_bar_fill_style == null:
		return

	var display_mgr_service: Variant = U_ServiceLocator.try_get_service(StringName("display_manager"))
	if display_mgr_service == null:
		return
	if not (display_mgr_service is Object):
		return
	var display_mgr_obj := display_mgr_service as Object
	if not display_mgr_obj.has_method("get_active_palette"):
		return
	var active_palette: Resource = display_mgr_obj.call("get_active_palette")
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
