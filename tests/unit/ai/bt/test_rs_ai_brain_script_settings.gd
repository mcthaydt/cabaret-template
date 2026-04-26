extends GutTest

const RS_AI_BRAIN_SETTINGS_PATH := "res://scripts/core/resources/ai/brain/rs_ai_brain_settings.gd"
const RS_AI_BRAIN_SCRIPT_SETTINGS_PATH := "res://scripts/core/resources/ai/brain/rs_ai_brain_script_settings.gd"
const RS_BT_NODE_PATH := "res://scripts/core/resources/bt/rs_bt_node.gd"

func _load_script(path: String) -> Script:
	assert_true(FileAccess.file_exists(path), "Expected script to exist: %s" % path)
	if not FileAccess.file_exists(path):
		return null
	var s: Variant = load(path)
	assert_not_null(s, "Expected script to load: %s" % path)
	if s == null or not (s is Script):
		return null
	return s as Script

func _new_instance(path: String) -> Object:
	var script: Script = _load_script(path)
	if script == null:
		return null
	var v: Variant = script.new()
	if v == null or not (v is Object):
		return null
	return v as Object

func _new_bt_node() -> Resource:
	var script: Script = _load_script(RS_BT_NODE_PATH)
	if script == null:
		return null
	var v: Variant = script.new()
	if v == null or not (v is Resource):
		return null
	return v as Resource

func _make_bt_node_build_script() -> Script:
	var gds := GDScript.new()
	gds.source_code = "extends Object\nfunc build() -> Resource:\n\tvar s = load(\"res://scripts/core/resources/bt/rs_bt_node.gd\")\n\tif s == null:\n\t\treturn null\n\treturn s.new()\n"
	var err: int = gds.reload()
	if err != OK:
		return null
	return gds

func _make_no_build_script() -> Script:
	var gds := GDScript.new()
	gds.source_code = "extends Object\n"
	var err: int = gds.reload()
	if err != OK:
		return null
	return gds

func test_base_brain_settings_has_get_root_method() -> void:
	var settings: Object = _new_instance(RS_AI_BRAIN_SETTINGS_PATH)
	if settings == null:
		return
	assert_true(settings.has_method("get_root"), "RS_AIBrainSettings must have get_root() virtual method")

func test_base_brain_settings_get_root_returns_null_for_null_root() -> void:
	var settings: Object = _new_instance(RS_AI_BRAIN_SETTINGS_PATH)
	if settings == null:
		return
	if not settings.has_method("get_root"):
		return
	var result: Variant = settings.call("get_root")
	assert_null(result, "RS_AIBrainSettings.get_root() must return null when root is null")

func test_rs_ai_brain_script_settings_script_exists() -> void:
	assert_true(
		FileAccess.file_exists(RS_AI_BRAIN_SCRIPT_SETTINGS_PATH),
		"rs_ai_brain_script_settings.gd must exist at %s" % RS_AI_BRAIN_SCRIPT_SETTINGS_PATH
	)

func test_rs_ai_brain_script_settings_extends_brain_settings() -> void:
	var script: Script = _load_script(RS_AI_BRAIN_SCRIPT_SETTINGS_PATH)
	if script == null:
		return
	var ancestor: Script = script.get_base_script()
	assert_not_null(ancestor, "RS_AIBrainScriptSettings must have a base script")
	if ancestor == null:
		return
	assert_eq(
		ancestor.get_path(),
		RS_AI_BRAIN_SETTINGS_PATH,
		"RS_AIBrainScriptSettings must extend RS_AIBrainSettings"
	)

func test_rs_ai_brain_script_settings_has_builder_script_export() -> void:
	var settings: Object = _new_instance(RS_AI_BRAIN_SCRIPT_SETTINGS_PATH)
	if settings == null:
		return
	var found: bool = false
	for prop_variant in settings.get_property_list():
		if not (prop_variant is Dictionary):
			continue
		var prop: Dictionary = prop_variant as Dictionary
		if str(prop.get("name", "")) == "builder_script":
			found = true
			break
	assert_true(found, "RS_AIBrainScriptSettings must expose builder_script property")

func test_rs_ai_brain_script_settings_has_get_root_method() -> void:
	var settings: Object = _new_instance(RS_AI_BRAIN_SCRIPT_SETTINGS_PATH)
	if settings == null:
		return
	assert_true(settings.has_method("get_root"), "RS_AIBrainScriptSettings must have get_root() method")

func test_get_root_returns_null_when_no_builder_script() -> void:
	var settings: Object = _new_instance(RS_AI_BRAIN_SCRIPT_SETTINGS_PATH)
	if settings == null:
		return
	if not settings.has_method("get_root"):
		return
	var result: Variant = settings.call("get_root")
	assert_null(result, "get_root() with null builder_script must return null")

func test_get_root_returns_null_when_builder_script_lacks_build() -> void:
	var settings: Object = _new_instance(RS_AI_BRAIN_SCRIPT_SETTINGS_PATH)
	if settings == null:
		return
	if not settings.has_method("get_root"):
		return
	var no_build: Script = _make_no_build_script()
	if no_build == null:
		return
	settings.set("builder_script", no_build)
	var result: Variant = settings.call("get_root")
	assert_null(result, "get_root() with script lacking build() must return null")

func test_get_root_calls_build_and_returns_bt_node() -> void:
	var settings: Object = _new_instance(RS_AI_BRAIN_SCRIPT_SETTINGS_PATH)
	if settings == null:
		return
	if not settings.has_method("get_root"):
		return
	var build_script: Script = _make_bt_node_build_script()
	if build_script == null:
		return
	settings.set("builder_script", build_script)
	var result: Variant = settings.call("get_root")
	assert_not_null(result, "get_root() with valid builder_script must return non-null RS_BTNode")

func test_get_root_caches_built_root_on_second_call() -> void:
	var settings: Object = _new_instance(RS_AI_BRAIN_SCRIPT_SETTINGS_PATH)
	if settings == null:
		return
	if not settings.has_method("get_root"):
		return
	var build_script: Script = _make_bt_node_build_script()
	if build_script == null:
		return
	settings.set("builder_script", build_script)
	var first: Variant = settings.call("get_root")
	var second: Variant = settings.call("get_root")
	if first == null or second == null:
		return
	assert_eq(first, second, "get_root() must cache built root; second call must return same instance")

func test_get_root_returns_preassigned_root_without_building() -> void:
	var settings: Object = _new_instance(RS_AI_BRAIN_SCRIPT_SETTINGS_PATH)
	if settings == null:
		return
	if not settings.has_method("get_root"):
		return
	var bt_node: Resource = _new_bt_node()
	if bt_node == null:
		return
	settings.set("root", bt_node)
	var build_script: Script = _make_bt_node_build_script()
	if build_script == null:
		return
	settings.set("builder_script", build_script)
	var result: Variant = settings.call("get_root")
	assert_eq(result, bt_node, "get_root() must return preassigned root without calling build()")
