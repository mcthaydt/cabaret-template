extends CanvasLayer
class_name SC_StateDebugOverlay

## Debug overlay for state store inspection
##
## Displays:
## - Current state (JSON formatted)
## - Action history (last 20 actions)
## - Action detail view (before/after state diff)
##
## Toggled with F3 key via M_StateStore._input()

@onready var state_label: Label = %StateLabel
@onready var history_list: ItemList = %HistoryList
@onready var detail_label: RichTextLabel = %DetailLabel

var _store: M_StateStore
var _history_entries: Array = []

func _ready() -> void:
	# Add to group for test detection
	add_to_group("state_debug_overlay")
	
	# Wait for scene tree to be fully ready
	await get_tree().process_frame
	
	# Find M_StateStore
	_store = U_StateUtils.get_store(self)
	if not _store:
		push_error("SC_StateDebugOverlay: Could not find M_StateStore")
		return
	
	# Subscribe to store signals
	_store.action_dispatched.connect(_on_action_dispatched)
	
	# Initial state display
	_update_state_display()

func _exit_tree() -> void:
	# Unsubscribe to prevent leaks
	if _store and is_instance_valid(_store):
		if _store.action_dispatched.is_connected(_on_action_dispatched):
			_store.action_dispatched.disconnect(_on_action_dispatched)

func _process(_delta: float) -> void:
	# Update state display every frame
	_update_state_display()

func _update_state_display() -> void:
	if not _store or not is_instance_valid(_store):
		return
	
	var state: Dictionary = _store.get_state()
	if state_label:
		state_label.text = JSON.stringify(state, "\t", false)

func _on_action_dispatched(action: Dictionary) -> void:
	# Add to history (limit to 20 entries)
	_history_entries.append(action)
	if _history_entries.size() > 20:
		_history_entries.pop_front()
	
	# Update history list display
	_update_history_list()

func _update_history_list() -> void:
	if not history_list:
		return
	
	history_list.clear()
	for entry in _history_entries:
		var action_type: String = entry.get("type", "unknown")
		history_list.add_item(action_type)

func _on_history_list_item_selected(index: int) -> void:
	if index < 0 or index >= _history_entries.size():
		return
	
	var action: Dictionary = _history_entries[index]
	_display_action_detail(action)

func _display_action_detail(action: Dictionary) -> void:
	if not detail_label:
		return
	
	var detail_text: String = "[b]Action:[/b] %s\n" % action.get("type", "unknown")
	detail_text += "[b]Payload:[/b] %s\n" % JSON.stringify(action.get("payload", {}), "\t", false)
	
	detail_label.text = detail_text
