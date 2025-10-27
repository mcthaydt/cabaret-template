extends GutTest

## Tests for state persistence (save/load)

const StateStoreEventBus := preload("res://scripts/state/state_event_bus.gd")

var store: M_StateStore
var test_save_path: String = "user://test_state_save.json"

func before_each() -> void:
	StateStoreEventBus.reset()
	
	store = M_StateStore.new()
	store.gameplay_initial_state = RS_GameplayInitialState.new()
	add_child(store)
	await get_tree().process_frame
	
	# Clean up any existing test save file
	if FileAccess.file_exists(test_save_path):
		DirAccess.remove_absolute(test_save_path)

func after_each() -> void:
	if store and is_instance_valid(store):
		store.queue_free()
	store = null
	
	# Clean up test save file
	if FileAccess.file_exists(test_save_path):
		DirAccess.remove_absolute(test_save_path)
	
	StateStoreEventBus.reset()

func test_save_state_creates_valid_json_file() -> void:
	# Dispatch some actions to create state
	store.dispatch(U_GameplayActions.update_health(75))
	store.dispatch(U_GameplayActions.update_score(250))
	
	# Save state
	var save_result: Error = store.save_state(test_save_path)
	
	assert_eq(save_result, OK, "Save should succeed")
	assert_true(FileAccess.file_exists(test_save_path), "Save file should exist")
	
	# Verify file contains valid JSON
	var file: FileAccess = FileAccess.open(test_save_path, FileAccess.READ)
	assert_not_null(file, "Should be able to open save file")
	
	var json_text: String = file.get_as_text()
	file.close()
	
	var parsed: Variant = JSON.parse_string(json_text)
	assert_true(parsed is Dictionary, "Saved data should be valid JSON dictionary")
	
	var state_dict: Dictionary = parsed as Dictionary
	assert_true(state_dict.has("gameplay"), "Should contain gameplay slice")

func test_load_state_restores_data_correctly() -> void:
	# Set up initial state
	store.dispatch(U_GameplayActions.update_health(80))
	store.dispatch(U_GameplayActions.update_score(300))
	store.dispatch(U_GameplayActions.set_level(5))
	
	# Save state
	var save_result: Error = store.save_state(test_save_path)
	assert_eq(save_result, OK, "Save should succeed")
	
	# Modify state
	store.dispatch(U_GameplayActions.update_health(10))
	store.dispatch(U_GameplayActions.update_score(0))
	
	var before_load: Dictionary = store.get_slice(StringName("gameplay"))
	assert_eq(before_load.get("health"), 10, "State should be modified before load")
	
	# Load saved state
	var load_result: Error = store.load_state(test_save_path)
	assert_eq(load_result, OK, "Load should succeed")
	
	# Verify state was restored
	var after_load: Dictionary = store.get_slice(StringName("gameplay"))
	assert_eq(after_load.get("health"), 80, "Health should be restored")
	assert_eq(after_load.get("score"), 300, "Score should be restored")
	assert_eq(after_load.get("level"), 5, "Level should be restored")

func test_transient_fields_excluded_from_save() -> void:
	# Create a custom slice with transient fields
	var config := StateSliceConfig.new(StringName("test_slice"))
	config.initial_state = {
		"persistent_value": 100,
		"transient_cache": 999
	}
	config.transient_fields = [StringName("transient_cache")]
	config.reducer = Callable()
	
	store.register_slice(config)
	
	# Save state
	var save_result: Error = store.save_state(test_save_path)
	assert_eq(save_result, OK, "Save should succeed")
	
	# Read the saved file and check contents
	var file: FileAccess = FileAccess.open(test_save_path, FileAccess.READ)
	var json_text: String = file.get_as_text()
	file.close()
	
	var parsed: Dictionary = JSON.parse_string(json_text) as Dictionary
	var test_slice: Dictionary = parsed.get("test_slice", {})
	
	assert_true(test_slice.has("persistent_value"), "Persistent field should be saved")
	assert_false(test_slice.has("transient_cache"), "Transient field should be excluded")
	assert_eq(test_slice.get("persistent_value"), 100, "Persistent value should match")

func test_godot_types_serialize_and_deserialize_correctly() -> void:
	# Create a test slice with various Godot types
	var config := StateSliceConfig.new(StringName("types_slice"))
	config.initial_state = {
		"vector2_field": Vector2(10.5, 20.3),
		"vector3_field": Vector3(1.0, 2.0, 3.0),
		"color_field": Color(1.0, 0.5, 0.25, 0.8),
		"string_field": "test string",
		"int_field": 42,
		"float_field": 3.14,
		"bool_field": true,
		"nested_dict": {"inner": "value"}
	}
	config.reducer = Callable()
	
	store.register_slice(config)
	
	# Save state
	var save_result: Error = store.save_state(test_save_path)
	assert_eq(save_result, OK, "Save should succeed")
	
	# Create new store and load
	var new_store := M_StateStore.new()
	new_store.gameplay_initial_state = RS_GameplayInitialState.new()
	new_store.settings = RS_StateStoreSettings.new()  # Prevent warning
	add_child(new_store)
	await get_tree().process_frame
	
	# Register same slice structure in new store
	var new_config := StateSliceConfig.new(StringName("types_slice"))
	new_config.initial_state = {}
	new_config.reducer = Callable()
	new_store.register_slice(new_config)
	
	# Load state
	var load_result: Error = new_store.load_state(test_save_path)
	assert_eq(load_result, OK, "Load should succeed")
	
	# Verify types were preserved
	var loaded_slice: Dictionary = new_store.get_slice(StringName("types_slice"))
	
	# Check Vector2
	var loaded_vec2: Variant = loaded_slice.get("vector2_field")
	if loaded_vec2 is Vector2:
		assert_almost_eq((loaded_vec2 as Vector2).x, 10.5, 0.001, "Vector2.x should match")
		assert_almost_eq((loaded_vec2 as Vector2).y, 20.3, 0.001, "Vector2.y should match")
	
	# Check Vector3
	var loaded_vec3: Variant = loaded_slice.get("vector3_field")
	if loaded_vec3 is Vector3:
		assert_almost_eq((loaded_vec3 as Vector3).x, 1.0, 0.001, "Vector3.x should match")
		assert_almost_eq((loaded_vec3 as Vector3).y, 2.0, 0.001, "Vector3.y should match")
		assert_almost_eq((loaded_vec3 as Vector3).z, 3.0, 0.001, "Vector3.z should match")
	
	# Check Color
	var loaded_color: Variant = loaded_slice.get("color_field")
	if loaded_color is Color:
		assert_almost_eq((loaded_color as Color).r, 1.0, 0.001, "Color.r should match")
		assert_almost_eq((loaded_color as Color).g, 0.5, 0.001, "Color.g should match")
	
	# Check primitive types
	assert_eq(loaded_slice.get("string_field"), "test string", "String should match")
	assert_eq(loaded_slice.get("int_field"), 42, "Int should match")
	assert_almost_eq(loaded_slice.get("float_field", 0.0), 3.14, 0.001, "Float should match")
	assert_eq(loaded_slice.get("bool_field"), true, "Bool should match")
	
	# Check nested dict
	var nested: Dictionary = loaded_slice.get("nested_dict", {})
	assert_eq(nested.get("inner"), "value", "Nested dict should match")
	
	new_store.queue_free()

func test_load_nonexistent_file_returns_error() -> void:
	var result: Error = store.load_state("user://nonexistent_file.json")
	assert_push_error("File does not exist")
	assert_ne(result, OK, "Loading nonexistent file should return error")

func test_save_to_invalid_path_returns_error() -> void:
	var result: Error = store.save_state("/invalid/path/that/does/not/exist/file.json")
	assert_push_error("Failed to open file for writing")
	assert_ne(result, OK, "Saving to invalid path should return error")
