extends RefCounted
class_name U_SaveSelectors

## Selectors for save-related UI state.
##
## Note: V1 stores save UI state in the menu slice (`available_saves`,
## `selected_save_slot`) to avoid adding a new slice.

enum SlotSelectorMode {
	SAVE = 0,
	LOAD = 1
}

static func get_available_slots(menu_state: Dictionary) -> Array:
	var slots: Variant = menu_state.get("available_saves", [])
	if slots is Array:
		return (slots as Array).duplicate(true)
	return []

static func get_selected_slot_id(menu_state: Dictionary) -> int:
	return int(menu_state.get("selected_save_slot", 1))

static func get_slot_selector_mode(menu_state: Dictionary) -> int:
	return int(menu_state.get("save_slot_selector_mode", SlotSelectorMode.LOAD))

static func has_any_saves(menu_state: Dictionary) -> bool:
	for slot in get_available_slots(menu_state):
		if slot is Dictionary and not bool((slot as Dictionary).get("is_empty", true)):
			return true
	return false

static func get_most_recent_non_empty_slot_id(menu_state: Dictionary) -> int:
	var best_slot_id: int = 0
	var best_timestamp: int = -1
	for slot in get_available_slots(menu_state):
		if not (slot is Dictionary):
			continue
		var slot_dict := slot as Dictionary
		if bool(slot_dict.get("is_empty", true)):
			continue
		var ts: int = int(slot_dict.get("timestamp", 0))
		if ts > best_timestamp:
			best_timestamp = ts
			best_slot_id = int(slot_dict.get("slot_id", 0))
	return best_slot_id

static func get_slot_by_index(menu_state: Dictionary, index: int) -> Dictionary:
	var slots: Array = get_available_slots(menu_state)
	if index < 0 or index >= slots.size():
		return {}
	var entry: Variant = slots[index]
	if entry is Dictionary:
		return (entry as Dictionary).duplicate(true)
	return {}
