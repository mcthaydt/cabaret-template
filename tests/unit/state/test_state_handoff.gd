extends GutTest

## Tests for StateHandoff utility
## 
## StateHandoff preserves state across scene changes without autoloads

const StateStoreEventBus := preload("res://scripts/state/state_event_bus.gd")
const StateHandoff := preload("res://scripts/state/utils/u_state_handoff.gd")

func before_each() -> void:
	# Reset state bus between tests
	StateStoreEventBus.reset()
	
	# Clear any preserved state from previous tests
	StateHandoff.clear_all()

func after_each() -> void:
	StateHandoff.clear_all()

func test_preserve_slice_stores_state() -> void:
	var test_state: Dictionary = {
		"health": 75,
		"score": 250,
		"level": 3
	}
	
	StateHandoff.preserve_slice(StringName("gameplay"), test_state)
	
	# Verify state was stored
	var restored_state: Dictionary = StateHandoff.restore_slice(StringName("gameplay"))
	
	assert_eq(restored_state.get("health"), 75, "Should preserve health")
	assert_eq(restored_state.get("score"), 250, "Should preserve score")
	assert_eq(restored_state.get("level"), 3, "Should preserve level")

func test_restore_slice_returns_preserved_state() -> void:
	var original_state: Dictionary = {
		"paused": true,
		"menu_screen": "settings"
	}
	
	StateHandoff.preserve_slice(StringName("menu"), original_state)
	
	var restored_state: Dictionary = StateHandoff.restore_slice(StringName("menu"))
	
	assert_eq(restored_state.get("paused"), true, "Should restore paused state")
	assert_eq(restored_state.get("menu_screen"), "settings", "Should restore menu_screen")

func test_restore_slice_returns_empty_dict_for_unknown_slice() -> void:
	var restored_state: Dictionary = StateHandoff.restore_slice(StringName("nonexistent"))
	
	assert_true(restored_state.is_empty(), "Should return empty dict for unknown slice")

func test_clear_slice_removes_preserved_state() -> void:
	var test_state: Dictionary = {"data": "test"}
	
	StateHandoff.preserve_slice(StringName("test_slice"), test_state)
	
	# Verify it was stored
	var restored: Dictionary = StateHandoff.restore_slice(StringName("test_slice"))
	assert_false(restored.is_empty(), "State should be stored")
	
	# Clear it
	StateHandoff.clear_slice(StringName("test_slice"))
	
	# Verify it's gone
	var after_clear: Dictionary = StateHandoff.restore_slice(StringName("test_slice"))
	assert_true(after_clear.is_empty(), "State should be cleared")

func test_clear_all_removes_all_preserved_state() -> void:
	StateHandoff.preserve_slice(StringName("gameplay"), {"health": 100})
	StateHandoff.preserve_slice(StringName("menu"), {"screen": "main"})
	StateHandoff.preserve_slice(StringName("boot"), {"loading": 0.5})
	
	StateHandoff.clear_all()
	
	assert_true(StateHandoff.restore_slice(StringName("gameplay")).is_empty(), "Gameplay should be cleared")
	assert_true(StateHandoff.restore_slice(StringName("menu")).is_empty(), "Menu should be cleared")
	assert_true(StateHandoff.restore_slice(StringName("boot")).is_empty(), "Boot should be cleared")

func test_preserved_state_is_deep_copy() -> void:
	var original_state: Dictionary = {"nested": {"value": 42}}
	
	StateHandoff.preserve_slice(StringName("test"), original_state)
	
	# Modify original
	original_state["nested"]["value"] = 999
	
	# Restored should not be affected
	var restored: Dictionary = StateHandoff.restore_slice(StringName("test"))
	assert_eq(restored["nested"]["value"], 42, "Preserved state should be deep copy")

func test_multiple_preserve_calls_overwrite() -> void:
	StateHandoff.preserve_slice(StringName("gameplay"), {"health": 100})
	StateHandoff.preserve_slice(StringName("gameplay"), {"health": 50})
	
	var restored: Dictionary = StateHandoff.restore_slice(StringName("gameplay"))
	assert_eq(restored.get("health"), 50, "Second preserve should overwrite first")
