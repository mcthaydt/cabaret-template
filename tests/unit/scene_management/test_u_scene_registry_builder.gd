extends GutTest

const BUILDER_PATH := "res://scripts/core/utils/scene/u_scene_registry_builder.gd"

func _new_builder() -> Object:
	assert_true(FileAccess.file_exists(BUILDER_PATH), "U_SceneRegistryBuilder script must exist: %s" % BUILDER_PATH)
	if not FileAccess.file_exists(BUILDER_PATH):
		return null
	var script: Variant = load(BUILDER_PATH)
	assert_not_null(script, "U_SceneRegistryBuilder script must load")
	if script == null or not (script is Script):
		return null
	var v: Variant = (script as Script).new()
	if v == null or not (v is Object):
		return null
	return v as Object

func test_u_scene_registry_builder_script_exists_and_loads() -> void:
	var builder: Object = _new_builder()
	assert_not_null(builder, "U_SceneRegistryBuilder must instantiate")

func test_register_adds_entry_with_gameplay_defaults() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("register", &"test_scene", "res://scenes/test.tscn")
	var result: Variant = builder.call("build")
	assert_true(result is Dictionary, "build() must return a Dictionary")
	var d: Dictionary = result as Dictionary
	assert_true(d.has(&"test_scene"), "build() must contain registered scene_id")
	var entry: Dictionary = d[&"test_scene"]
	assert_eq(entry.get("scene_id"), &"test_scene", "entry must have correct scene_id")
	assert_eq(entry.get("path"), "res://scenes/test.tscn", "entry must have correct path")
	assert_eq(entry.get("scene_type"), 1, "default scene_type must be GAMEPLAY (1)")
	assert_eq(entry.get("default_transition"), "fade", "default transition must be 'fade'")
	assert_eq(entry.get("preload_priority"), 0, "default preload_priority must be 0")

func test_with_type_sets_scene_type_on_last_entry() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("register", &"menu_scene", "res://scenes/menu.tscn")
	builder.call("with_type", 0)
	var result: Dictionary = builder.call("build")
	assert_eq(result[&"menu_scene"].get("scene_type"), 0, "with_type must set scene_type to MENU (0)")

func test_with_transition_sets_transition_on_last_entry() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("register", &"level_scene", "res://scenes/level.tscn")
	builder.call("with_transition", "instant")
	var result: Dictionary = builder.call("build")
	assert_eq(result[&"level_scene"].get("default_transition"), "instant", "with_transition must set transition")

func test_with_preload_sets_priority_on_last_entry() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("register", &"critical_scene", "res://scenes/critical.tscn")
	builder.call("with_preload", 10)
	var result: Dictionary = builder.call("build")
	assert_eq(result[&"critical_scene"].get("preload_priority"), 10, "with_preload must set preload_priority")

func test_all_methods_return_self_for_chaining() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	var b1: Variant = builder.call("register", &"scene_a", "res://scenes/a.tscn")
	assert_eq(b1, builder, "register() must return self")
	var b2: Variant = builder.call("with_type", 2)
	assert_eq(b2, builder, "with_type() must return self")
	var b3: Variant = builder.call("with_transition", "loading")
	assert_eq(b3, builder, "with_transition() must return self")
	var b4: Variant = builder.call("with_preload", 5)
	assert_eq(b4, builder, "with_preload() must return self")

func test_chaining_builds_full_entry() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	var b: Object = builder.call("register", &"hq_scene", "res://scenes/hq.tscn")
	b.call("with_type", 0)
	b.call("with_transition", "loading")
	b.call("with_preload", 5)
	var result: Dictionary = b.call("build")
	assert_true(result.has(&"hq_scene"), "chained entry must be in build output")
	var entry: Dictionary = result[&"hq_scene"]
	assert_eq(entry.get("scene_type"), 0, "chained with_type must apply")
	assert_eq(entry.get("default_transition"), "loading", "chained with_transition must apply")
	assert_eq(entry.get("preload_priority"), 5, "chained with_preload must apply")

func test_multiple_register_calls_create_separate_entries() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("register", &"scene_a", "res://scenes/a.tscn")
	builder.call("register", &"scene_b", "res://scenes/b.tscn")
	var result: Dictionary = builder.call("build")
	assert_eq(result.size(), 2, "build() must contain all registered entries")
	assert_true(result.has(&"scene_a"), "build() must contain scene_a")
	assert_true(result.has(&"scene_b"), "build() must contain scene_b")

func test_with_type_only_affects_last_entry() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("register", &"scene_a", "res://scenes/a.tscn")
	builder.call("register", &"scene_b", "res://scenes/b.tscn")
	builder.call("with_type", 0)
	var result: Dictionary = builder.call("build")
	assert_eq(result[&"scene_a"].get("scene_type"), 1, "with_type must not affect earlier entry (default GAMEPLAY)")
	assert_eq(result[&"scene_b"].get("scene_type"), 0, "with_type must set last entry to MENU")

func test_build_returns_empty_dict_when_no_entries() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	var result: Variant = builder.call("build")
	assert_true(result is Dictionary, "build() must return a Dictionary")
	assert_eq((result as Dictionary).size(), 0, "build() with no entries must return empty Dictionary")
