extends CanvasLayer

const U_StateUtils := preload("res://scripts/state/utils/u_state_utils.gd")
const U_EntitySelectors := preload("res://scripts/state/selectors/u_entity_selectors.gd")
const HUD_GROUP := StringName("hud_layers")

@onready var pause_label: Label = $MarginContainer/VBoxContainer/PauseLabel
@onready var health_bar: ProgressBar = $MarginContainer/VBoxContainer/HealthBar
@onready var health_label: Label = $MarginContainer/VBoxContainer/HealthBar/HealthLabel

var _store: M_StateStore = null
var _player_entity_id: String = "E_Player"

func _ready() -> void:
	add_to_group(HUD_GROUP)
	_store = U_StateUtils.get_store(self)

	if _store == null:
		push_error("HUD: Could not find M_StateStore")
		return

	_player_entity_id = String(_store.get_slice(StringName("gameplay")).get("player_entity_id", "E_Player"))
	_store.slice_updated.connect(_on_slice_updated)

	_update_display(_store.get_state())

func _exit_tree() -> void:
	if is_in_group(HUD_GROUP):
		remove_from_group(HUD_GROUP)
	if _store != null and _store.slice_updated.is_connected(_on_slice_updated):
		_store.slice_updated.disconnect(_on_slice_updated)

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
