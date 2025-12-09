extends GutTest

const GD_DIRECTORIES := [
	"res://scripts/gameplay",
	"res://scripts/ecs",
	"res://scripts/state",
	"res://scripts/ui",
	"res://scripts/managers",
	"res://scripts/scene_structure",
	"res://tests/unit/interactables",
	"res://tests/unit/input",
	"res://tests/unit/style",
	"res://tests/unit/ui"
]

const TRIGGER_RESOURCE_DIRECTORIES := [
	"res://resources/triggers"
]

const TRIGGER_RESOURCE_FILES := [
	"res://resources/rs_scene_trigger_settings.tres"
]

# Documented exceptions from STYLE_GUIDE.md
# Only interface files remain as exceptions (documented pattern)
const INTERFACE_EXCEPTIONS := [
	"i_scene_contract.gd"
]

# Valid prefixes by directory
const SCRIPT_PREFIX_RULES := {
	"res://scripts/managers": ["m_"],
	"res://scripts/ecs/systems": ["s_", "m_"],  # m_ for M_PauseManager
	"res://scripts/ecs/components": ["c_"],
	"res://scripts/ecs/resources": ["rs_"],
	"res://scripts/ecs": ["base_", "u_", "event_"],  # base_ecs_*.gd files, u_ecs_event_bus.gd, u_entity_query.gd, event_vfx_system.gd
	"res://scripts/state/actions": ["u_"],
	"res://scripts/state/reducers": ["u_"],
	"res://scripts/state/selectors": ["u_"],
	"res://scripts/state/resources": ["rs_"],  # State initial state resources
	"res://scripts/state": ["u_", "m_"],  # m_state_store.gd is in root
	"res://scripts/ui/resources": ["rs_"],  # UI screen definitions
	"res://scripts/ui/base": ["base_"],  # base_*.gd UI base classes
	"res://scripts/ui/utils": ["u_"],  # UI utilities
	"res://scripts/ui": ["ui_", "u_"],  # ui_ for controllers, u_ for utilities
	"res://scripts/gameplay": ["e_", "base_", "triggered_"],  # e_ for entities, base_ for base controllers, triggered_ for special controllers
	"res://scripts/scene_structure": ["marker_"],  # marker_*.gd organizational scripts
	"res://scripts/scene_management/transitions": ["trans_", "base_"],  # transition effects
	"res://scripts/events": ["base_"],  # base_event_bus.gd
}

func test_gd_files_use_tab_indentation() -> void:
	var offenses: Array[String] = []
	for dir_path in GD_DIRECTORIES:
		_collect_gd_spacing_offenses(dir_path, offenses)
	assert_eq(offenses.size(), 0,
		"All .gd files should use tab indentation. Offending lines:\n%s" % "\n".join(offenses))

func test_trigger_resources_define_script_reference() -> void:
	var missing: Array[String] = []
	for dir_path in TRIGGER_RESOURCE_DIRECTORIES:
		_collect_tres_without_script(dir_path, missing)
	for file_path in TRIGGER_RESOURCE_FILES:
		if not _resource_has_script_reference(file_path):
			missing.append(file_path)
	assert_eq(missing.size(), 0,
		"Trigger settings resources must include script = ExtResource(). Missing:\n%s" % "\n".join(missing))

func _collect_gd_spacing_offenses(dir_path: String, offenses: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_collect_gd_spacing_offenses("%s/%s" % [dir_path, entry], offenses)
		elif entry.ends_with(".gd"):
			_scan_gd_file("%s/%s" % [dir_path, entry], offenses)
		entry = dir.get_next()
	dir.list_dir_end()

func _scan_gd_file(path: String, offenses: Array[String]) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var line_number := 0
	while not file.eof_reached():
		line_number += 1
		var line := file.get_line()
		if line.begins_with(" ") and not line.strip_edges().is_empty():
			offenses.append("%s:%d" % [path, line_number])
	file.close()

func _collect_tres_without_script(dir_path: String, missing: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_collect_tres_without_script("%s/%s" % [dir_path, entry], missing)
		elif entry.ends_with(".tres"):
			var path := "%s/%s" % [dir_path, entry]
			if not _resource_has_script_reference(path):
				missing.append(path)
		entry = dir.get_next()
	dir.list_dir_end()

func _resource_has_script_reference(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var has_script := false
	while not file.eof_reached():
		if file.get_line().strip_edges().begins_with("script = ExtResource"):
			has_script = true
			break
	file.close()
	return has_script

# ============================================================================
# Phase 4 - Comprehensive Prefix Validation Tests
# ============================================================================

func test_scripts_follow_prefix_conventions() -> void:
	var violations: Array[String] = []

	# Check each directory with prefix rules
	for dir_path in SCRIPT_PREFIX_RULES.keys():
		_check_directory_prefixes(dir_path, SCRIPT_PREFIX_RULES[dir_path], violations)

	var message := "Scripts must follow documented prefix conventions"
	if violations.size() > 0:
		message += ":\n" + "\n".join(violations)
		message += "\n\nSee STYLE_GUIDE.md for complete prefix matrix."
	else:
		message += " - all scripts compliant!"

	assert_eq(violations.size(), 0, message)

func test_scenes_follow_naming_conventions() -> void:
	var violations: Array[String] = []

	# Check gameplay scenes
	_check_scene_directory("res://scenes/gameplay", "gameplay_", violations)

	# Check UI scenes
	_check_scene_directory("res://scenes/ui", "ui_", violations)

	# Check prefab scenes
	_check_scene_directory("res://scenes/prefabs", "prefab_", violations)

	# Check debug scenes
	_check_scene_directory("res://scenes/debug", "debug_", violations)

	var message := "Scene files must follow documented naming patterns"
	if violations.size() > 0:
		message += ":\n" + "\n".join(violations)
		message += "\n\nSee STYLE_GUIDE.md scene naming table."
	else:
		message += " - all scenes compliant!"

	assert_eq(violations.size(), 0, message)

func test_resources_follow_naming_conventions() -> void:
	var violations: Array[String] = []

	# Check UI screen definitions
	_check_resource_directory("res://resources/ui_screens",
		["_screen.tres", "_overlay.tres"], violations)

	# Scene registry entries don't need strict naming - just verify they exist and have scripts
	# (handled by test_trigger_resources_define_script_reference)

	# Check settings resources (non-strict, just informational)
	# Resources can have various naming patterns, so we don't enforce strict rules here

	var message := "Resource files must follow documented naming patterns"
	if violations.size() > 0:
		message += ":\n" + "\n".join(violations)
		message += "\n\nSee STYLE_GUIDE.md resource naming table."
	else:
		message += " - all resources compliant!"

	assert_eq(violations.size(), 0, message)

func test_scene_organization_root_structure() -> void:
	var root_scene := load("res://scenes/root.tscn") as PackedScene
	assert_not_null(root_scene, "Root scene must exist")

	var root := root_scene.instantiate()
	add_child_autofree(root)

	# Check for required managers
	var managers := root.get_node_or_null("Managers")
	assert_not_null(managers, "Root scene must have Managers node")

	# Check for M_StateStore
	var state_store := managers.get_node_or_null("M_StateStore")
	assert_not_null(state_store, "Root scene must have M_StateStore in Managers")

	# Check for M_SceneManager
	var scene_manager := managers.get_node_or_null("M_SceneManager")
	assert_not_null(scene_manager, "Root scene must have M_SceneManager in Managers")

	# Check for M_CursorManager
	var cursor_manager := managers.get_node_or_null("M_CursorManager")
	assert_not_null(cursor_manager, "Root scene must have M_CursorManager in Managers")

	# Check for M_PauseManager (Phase 2)
	var pause_manager := managers.get_node_or_null("M_PauseManager")
	assert_not_null(pause_manager, "Root scene must have M_PauseManager in Managers")

	# Check for scene containers
	assert_not_null(root.get_node_or_null("ActiveSceneContainer"),
		"Root scene must have ActiveSceneContainer")
	assert_not_null(root.get_node_or_null("UIOverlayStack"),
		"Root scene must have UIOverlayStack")

func test_scene_organization_gameplay_structure() -> void:
	var gameplay_base := load("res://scenes/gameplay/gameplay_base.tscn") as PackedScene
	assert_not_null(gameplay_base, "Gameplay base scene must exist")

	# Inspect the packed scene's state directly to avoid runtime initialization issues
	var scene_state := gameplay_base.get_state()

	# Find required nodes by name in the scene tree
	var has_managers := false
	var has_systems := false
	var has_entities := false
	var has_spawn_points_in_entities := false
	var entities_node_path := ""

	for i in range(scene_state.get_node_count()):
		var node_name := scene_state.get_node_name(i)
		var node_path := scene_state.get_node_path(i)

		if node_name == "Managers":
			has_managers = true
		elif node_name == "Systems":
			has_systems = true
		elif node_name == "Entities":
			has_entities = true
			entities_node_path = str(node_path)
		elif node_name == "SP_SpawnPoints":
			# Check if spawn points are under Entities
			var path_str := str(node_path)
			if path_str.begins_with(entities_node_path + "/") or path_str.contains("/Entities/"):
				has_spawn_points_in_entities = true

	assert_true(has_managers, "Gameplay scene must have Managers node")
	assert_true(has_systems, "Gameplay scene must have Systems node")
	assert_true(has_entities, "Gameplay scene must have Entities node")
	assert_true(has_spawn_points_in_entities,
		"Spawn points must be under Entities node per SCENE_ORGANIZATION_GUIDE.md")

# Helper functions for prefix validation

func _check_directory_prefixes(dir_path: String, allowed_prefixes: Array, violations: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			if not entry.begins_with("."):
				var subdir_path := "%s/%s" % [dir_path, entry]
				# Check if there's a specific rule for this subdirectory
				var subdir_prefixes := allowed_prefixes
				if subdir_path in SCRIPT_PREFIX_RULES:
					subdir_prefixes = SCRIPT_PREFIX_RULES[subdir_path]
				_check_directory_prefixes(subdir_path, subdir_prefixes, violations)
		elif entry.ends_with(".gd"):
			if not _is_valid_script_name(entry, allowed_prefixes):
				violations.append("%s/%s - invalid prefix (allowed: %s)" % [
					dir_path, entry, str(allowed_prefixes)
				])
		entry = dir.get_next()
	dir.list_dir_end()

func _is_valid_script_name(filename: String, allowed_prefixes: Array) -> bool:
	# Check if it's a documented exception
	if _is_exception(filename):
		return true

	# If no prefixes specified, all non-exceptions are violations
	if allowed_prefixes.is_empty():
		return false

	# Check if filename starts with any allowed prefix
	for prefix in allowed_prefixes:
		if filename.begins_with(prefix):
			return true

	return false

func _is_exception(filename: String) -> bool:
	return (
		filename in INTERFACE_EXCEPTIONS or
		filename.begins_with("test_")  # Test files are always exceptions
	)

func _check_scene_directory(dir_path: String, required_prefix: String, violations: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(".tscn"):
			if not entry.begins_with(required_prefix):
				violations.append("%s/%s - must start with '%s'" % [
					dir_path, entry, required_prefix
				])
		entry = dir.get_next()
	dir.list_dir_end()

func _check_resource_directory(dir_path: String, required_patterns: Array,
		violations: Array[String], strict: bool = true) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_check_resource_directory("%s/%s" % [dir_path, entry],
					required_patterns, violations, strict)
		elif entry.ends_with(".tres"):
			var matches := false
			for pattern in required_patterns:
				if pattern.begins_with("_") and entry.ends_with(pattern):
					matches = true
					break
				elif not pattern.begins_with("_") and entry.begins_with(pattern):
					matches = true
					break

			if strict and not matches:
				violations.append("%s/%s - must match patterns: %s" % [
					dir_path, entry, str(required_patterns)
				])
		entry = dir.get_next()
	dir.list_dir_end()
