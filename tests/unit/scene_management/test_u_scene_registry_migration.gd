extends GutTest

const MANIFEST_PATH := "res://scripts/core/scene_management/u_scene_manifest.gd"

func test_manifest_script_exists() -> void:
	assert_true(FileAccess.file_exists(MANIFEST_PATH), "Scene manifest script must exist: %s" % MANIFEST_PATH)

func test_manifest_builds_all_demo_scenes() -> void:
	if not FileAccess.file_exists(MANIFEST_PATH):
		return
	var script: Script = load(MANIFEST_PATH)
	assert_not_null(script, "Manifest script must load")
	if script == null:
		return
	var manifest: RefCounted = script.new()
	assert_not_null(manifest, "Manifest instance must be created")
	if manifest == null:
		return
	assert_true(manifest.has_method("build"), "Manifest must have build() method")
	if not manifest.has_method("build"):
		return
	var result: Variant = manifest.call("build")
	assert_true(result is Dictionary, "build() must return Dictionary")
	if not (result is Dictionary):
		return
	var scenes: Dictionary = result as Dictionary
	# Verify presence of all demo scenes currently registered via .tres files
	var expected_ids: Array[StringName] = [
		&"gameplay_base", &"alleyway", &"interior_house",
		&"interior_a", &"bar", &"power_core",
		&"comms_array", &"nav_nexus",
		&"ai_showcase", &"ai_woods",
	]
	for scene_id: StringName in expected_ids:
		assert_true(
			scenes.has(scene_id),
			"Manifest must contain scene_id '%s'" % scene_id
		)
		var entry: Dictionary = scenes.get(scene_id, {}) as Dictionary
		assert_true(entry is Dictionary, "Entry for '%s' must be Dictionary" % scene_id)
		if entry is Dictionary:
			assert_true(
				not entry.get("path", "").is_empty(),
				"Entry '%s' must have non-empty path" % scene_id
			)
			var path: String = entry.get("path", "")
			assert_true(path.begins_with("res://"), "Entry '%s' path must begin with 'res://'" % scene_id)
			assert_true(
				entry.get("scene_type") is int,
				"Entry '%s' must have int scene_type" % scene_id
			)
			assert_true(
				entry.get("default_transition") is String,
				"Entry '%s' must have String default_transition" % scene_id
			)
			assert_true(
				entry.get("preload_priority") is int,
				"Entry '%s' must have int preload_priority" % scene_id
			)

func test_manifest_gameplay_base_matches_tres_values() -> void:
	if not FileAccess.file_exists(MANIFEST_PATH):
		return
	var manifest: RefCounted = load(MANIFEST_PATH).new()
	if not manifest.has_method("build"):
		return
	var scenes: Dictionary = manifest.call("build")
	if not scenes.has(&"gameplay_base"):
		return
	var entry: Dictionary = scenes[&"gameplay_base"]
	assert_eq(entry.get("path"), "res://scenes/core/gameplay/gameplay_base.tscn", "gameplay_base path must match")
	assert_eq(entry.get("scene_type"), 1, "gameplay_base type must be GAMEPLAY (1)")
	assert_eq(entry.get("preload_priority"), 8, "gameplay_base priority must be 8")

func test_manifest_bar_matches_tres_values() -> void:
	if not FileAccess.file_exists(MANIFEST_PATH):
		return
	var manifest: RefCounted = load(MANIFEST_PATH).new()
	if not manifest.has_method("build"):
		return
	var scenes: Dictionary = manifest.call("build")
	if not scenes.has(&"bar"):
		return
	var entry: Dictionary = scenes[&"bar"]
	assert_eq(entry.get("path"), "res://scenes/demo/gameplay/gameplay_bar.tscn", "bar path must match")
	assert_eq(entry.get("scene_type"), 1, "bar type must be GAMEPLAY (1)")
	assert_eq(entry.get("preload_priority"), 6, "bar priority must be 6")

func test_manifest_interior_house_matches_tres_values() -> void:
	if not FileAccess.file_exists(MANIFEST_PATH):
		return
	var manifest: RefCounted = load(MANIFEST_PATH).new()
	if not manifest.has_method("build"):
		return
	var scenes: Dictionary = manifest.call("build")
	if not scenes.has(&"interior_house"):
		return
	var entry: Dictionary = scenes[&"interior_house"]
	assert_eq(entry.get("path"), "res://scenes/demo/gameplay/gameplay_interior_house.tscn", "interior_house path must match")
	assert_eq(entry.get("scene_type"), 1, "interior_house type must be GAMEPLAY (1)")
	assert_eq(entry.get("preload_priority"), 6, "interior_house priority must be 6")

func test_manifest_nav_nexus_matches_tres_values() -> void:
	if not FileAccess.file_exists(MANIFEST_PATH):
		return
	var manifest: RefCounted = load(MANIFEST_PATH).new()
	if not manifest.has_method("build"):
		return
	var scenes: Dictionary = manifest.call("build")
	if not scenes.has(&"nav_nexus"):
		return
	var entry: Dictionary = scenes[&"nav_nexus"]
	assert_eq(entry.get("path"), "res://scenes/demo/gameplay/gameplay_nav_nexus.tscn", "nav_nexus path must match")
	assert_eq(entry.get("scene_type"), 1, "nav_nexus type must be GAMEPLAY (1)")
	assert_eq(entry.get("default_transition"), "loading", "nav_nexus transition must be 'loading'")
	assert_eq(entry.get("preload_priority"), 6, "nav_nexus priority must be 6")
