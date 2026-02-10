extends GutTest

## Unit tests for U_SpawnRegistry and RS_SpawnMetadata (T083)


func before_each() -> void:
	# Ensure registry starts from a clean state for each test.
	U_SpawnRegistry.reload_registry([])

func test_get_spawn_returns_empty_dictionary_when_missing() -> void:
	var result: Dictionary = U_SpawnRegistry.get_spawn(StringName("unknown_spawn"))
	assert_true(result.is_empty(), "Missing spawn id should return empty dictionary")

func test_get_spawn_returns_metadata_dictionary_for_registered_id() -> void:
	var metadata := RS_SpawnMetadata.new()
	metadata.spawn_id = StringName("sp_default")
	metadata.tags = [StringName("default")]
	metadata.priority = 5

	U_SpawnRegistry.reload_registry([metadata])

	var result: Dictionary = U_SpawnRegistry.get_spawn(StringName("sp_default"))
	assert_false(result.is_empty(), "Registered spawn id should return metadata")
	assert_eq(result.get("spawn_id", StringName("")), StringName("sp_default"))
	assert_eq(result.get("priority", -1), 5)

func test_get_spawns_by_tag_filters_on_tag_presence() -> void:
	var a := RS_SpawnMetadata.new()
	a.spawn_id = StringName("sp_a")
	a.tags = [StringName("checkpoint")]

	var b := RS_SpawnMetadata.new()
	b.spawn_id = StringName("sp_b")
	b.tags = [StringName("door_target")]

	U_SpawnRegistry.reload_registry([a, b])

	var results: Array = U_SpawnRegistry.get_spawns_by_tag(StringName("checkpoint"))
	assert_eq(results.size(), 1, "Only checkpoint-tagged spawns should be returned")
	assert_eq(results[0].get("spawn_id", StringName("")), StringName("sp_a"))

func test_duplicate_spawn_ids_keep_higher_priority_entry() -> void:
	var low := RS_SpawnMetadata.new()
	low.spawn_id = StringName("sp_dup")
	low.priority = 1

	var high := RS_SpawnMetadata.new()
	high.spawn_id = StringName("sp_dup")
	high.priority = 10

	U_SpawnRegistry.reload_registry([low, high])

	var result: Dictionary = U_SpawnRegistry.get_spawn(StringName("sp_dup"))
	assert_eq(result.get("priority", -1), 10, "Higher priority entry should win for duplicate ids")

