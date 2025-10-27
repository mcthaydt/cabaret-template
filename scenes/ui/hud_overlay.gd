extends CanvasLayer

## HUD Overlay - Displays game state from State Store (PoC)
##
## Reads health, score, and pause status from state store and displays them.
## Demonstrates reactive UI pattern: subscribe to state changes, update labels.

@onready var health_label: Label = $MarginContainer/VBoxContainer/HealthLabel
@onready var score_label: Label = $MarginContainer/VBoxContainer/ScoreLabel
@onready var pause_label: Label = $MarginContainer/VBoxContainer/PauseLabel

var _store: M_StateStore = null

func _ready() -> void:
	# Get reference to state store
	_store = U_StateUtils.get_store(self)
	
	if not _store:
		push_error("HUD: Could not find M_StateStore")
		return
	
	# Subscribe to gameplay slice updates
	_store.slice_updated.connect(_on_slice_updated)
	
	# Initial update
	_update_display(_store.get_slice(StringName("gameplay")))

func _exit_tree() -> void:
	# Clean up subscriptions
	if _store and _store.slice_updated.is_connected(_on_slice_updated):
		_store.slice_updated.disconnect(_on_slice_updated)

## Handle state store slice updates
func _on_slice_updated(slice_name: StringName, slice_state: Dictionary) -> void:
	if slice_name != StringName("gameplay"):
		return
	
	_update_display(slice_state)

## Update UI labels from state
func _update_display(gameplay_state: Dictionary) -> void:
	var health: int = GameplaySelectors.get_current_health(gameplay_state)
	var score: int = GameplaySelectors.get_current_score(gameplay_state)
	var is_paused: bool = GameplaySelectors.get_is_paused(gameplay_state)
	
	health_label.text = "Health: %d" % health
	score_label.text = "Score: %d" % score
	
	if is_paused:
		pause_label.text = "[PAUSED]"
		pause_label.modulate = Color.YELLOW
	else:
		pause_label.text = ""
