extends GutTest

const U_StatePersistence: Script = preload("res://scripts/state/u_state_persistence.gd")

func test_serialize_state_filters_to_persistable_slices() -> void:
	var state: Dictionary = {
		StringName("game"): {"score": 5, "level": 2},
		StringName("ui"): {"menu": "pause"},
		StringName("session"): {"slot": 1},
	}

	var slices: Array[StringName] = [StringName("game"), StringName("session")]
	var json: String = U_StatePersistence.serialize_state(state, slices)
	var parsed_variant: Variant = JSON.parse_string(json)
	assert_true(typeof(parsed_variant) == TYPE_DICTIONARY)
	var parsed: Dictionary = parsed_variant

	assert_true(parsed.has("checksum"))
	assert_true(parsed.has("version"))
	assert_true(parsed.has("data"))

	var data: Dictionary = parsed["data"]
	assert_true(data.has(StringName("game")))
	assert_true(data.has(StringName("session")))
	assert_false(data.has(StringName("ui")))
	assert_eq(int(data[StringName("game")]["score"]), 5)

func test_deserialize_state_validates_checksum() -> void:
	var state: Dictionary = {
		StringName("game"): {"score": 15},
	}
	var slices: Array[StringName] = [StringName("game")]
	var json: String = U_StatePersistence.serialize_state(state, slices)
	var loaded: Dictionary = U_StatePersistence.deserialize_state(json)

	assert_true(loaded.has(StringName("game")))
	assert_eq(int(loaded[StringName("game")]["score"]), 15)

func test_deserialize_state_returns_null_on_corruption() -> void:
	var state: Dictionary = {
		StringName("game"): {"score": 15},
	}
	var slices: Array[StringName] = [StringName("game")]
	var json: String = U_StatePersistence.serialize_state(state, slices)
	var parsed_variant: Variant = JSON.parse_string(json)
	var parsed: Dictionary = parsed_variant
	parsed["data"][StringName("game")]["score"] = 1
	var tampered: String = JSON.stringify(parsed)

	var result: Dictionary = U_StatePersistence.deserialize_state(tampered)
	assert_eq(result, {})

func test_save_and_load_state_round_trip() -> void:
	var path := "user://state_store_persistence.json"
	var state: Dictionary = {
		StringName("game"): {"score": 7},
		StringName("session"): {"slot": 3},
	}
	var slices: Array[StringName] = [StringName("game"), StringName("session")]
	var err: int = U_StatePersistence.save_to_file(path, state, slices)
	assert_eq(err, OK)

	var loaded: Dictionary = U_StatePersistence.load_from_file(path)
	assert_eq(int(loaded[StringName("game")]["score"]), 7)
	assert_eq(int(loaded[StringName("session")]["slot"]), 3)

	_remove_file(path)

func test_load_from_file_returns_empty_when_missing() -> void:
	var path := "user://nonexistent_state_file.json"
	if FileAccess.file_exists(path):
		_remove_file(path)

	var loaded: Dictionary = U_StatePersistence.load_from_file(path)
	assert_eq(loaded, {})

func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
