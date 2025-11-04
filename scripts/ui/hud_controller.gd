@icon("res://resources/editor_icons/utility.svg")
extends CanvasLayer

const U_StateUtils := preload("res://scripts/state/utils/u_state_utils.gd")
const U_EntitySelectors := preload("res://scripts/state/selectors/u_entity_selectors.gd")
const U_ECSEventBus := preload("res://scripts/ecs/u_ecs_event_bus.gd")
const HUD_GROUP := StringName("hud_layers")

@onready var pause_label: Label = $MarginContainer/VBoxContainer/PauseLabel
@onready var health_bar: ProgressBar = $MarginContainer/VBoxContainer/HealthBar
@onready var health_label: Label = $MarginContainer/VBoxContainer/HealthBar/HealthLabel
@onready var checkpoint_toast: Label = $MarginContainer/CheckpointToast

var _store: M_StateStore = null
var _player_entity_id: String = "E_Player"
var _unsubscribe_checkpoint: Callable

func _ready() -> void:
	add_to_group(HUD_GROUP)
	_store = U_StateUtils.get_store(self)

	if _store == null:
		push_error("HUD: Could not find M_StateStore")
		return

	_player_entity_id = String(_store.get_slice(StringName("gameplay")).get("player_entity_id", "E_Player"))
	_store.slice_updated.connect(_on_slice_updated)

	# Subscribe to checkpoint events for player feedback
	_unsubscribe_checkpoint = U_ECSEventBus.subscribe(StringName("checkpoint_activated"), _on_checkpoint_event)

	_update_display(_store.get_state())

func _exit_tree() -> void:
	if is_in_group(HUD_GROUP):
		remove_from_group(HUD_GROUP)
	if _store != null and _store.slice_updated.is_connected(_on_slice_updated):
		_store.slice_updated.disconnect(_on_slice_updated)
	if _unsubscribe_checkpoint != null and _unsubscribe_checkpoint.is_valid():
		_unsubscribe_checkpoint.call()

func _on_slice_updated(slice_name: StringName, _slice_state: Dictionary) -> void:
	if slice_name != StringName("gameplay"):
		return
	_update_display(_store.get_state())

func _update_display(state: Dictionary) -> void:
	pause_label.text = ""
	_update_health(state)

func _update_health(state: Dictionary) -> void:
	if health_bar == null:
		return

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
	if checkpoint_toast == null:
		return
	checkpoint_toast.text = text
	checkpoint_toast.modulate.a = 0.0
	checkpoint_toast.visible = true

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	# Fade in
	tween.tween_property(checkpoint_toast, "modulate:a", 1.0, 0.2).from(0.0)
	# Hold
	tween.tween_interval(1.0)
	# Fade out
	tween.tween_property(checkpoint_toast, "modulate:a", 0.0, 0.3)
	tween.finished.connect(func() -> void:
		checkpoint_toast.visible = false
	)
