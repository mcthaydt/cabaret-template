extends GutTest

const GD_DIRECTORIES := [
	"res://scripts/gameplay",
	"res://scripts/ecs",
	"res://scripts/state",
	"res://scripts/ui",
	"res://scripts/managers",
	"res://scripts/core",
	"res://scripts/interfaces",
	"res://scripts/utils",
	"res://scripts/input",
	"res://scripts/scene_management",
	"res://scripts/events",
	"res://scripts/scene_structure",
	"res://scripts/resources/qb",
	"res://scripts/resources/qb/conditions",
	"res://scripts/resources/qb/effects",
	"res://scripts/resources/scene_director",
	"res://scripts/resources/ecs",
	"res://scripts/resources/display",
	"res://scripts/resources/localization",
	"res://scripts/resources/ai",
	"res://scripts/debug",
	"res://tests/unit/interactables",
	"res://tests/unit/input",
	"res://tests/unit/lighting",
	"res://tests/unit/style",
	"res://tests/unit/ui"
]

const TRIGGER_RESOURCE_DIRECTORIES := [
	"res://resources/triggers"
]

const INTERACTION_RESOURCE_DIRECTORIES := [
	"res://resources/interactions"
]

const TRIGGER_RESOURCE_FILES := [
	"res://resources/triggers/cfg_scene_trigger_settings.tres"
]

const INTERACTION_RESOURCE_ALLOWED_SUBDIRS := [
	"doors",
	"checkpoints",
	"hazards",
	"victory",
	"signposts",
	"endgame"
]

const PRODUCTION_PATH_DIRECTORIES := [
	"res://assets",
	"res://scenes",
	"res://scripts",
	"res://resources"
]

const UI_POLISHED_OVERLAY_SCENES := [
	"res://scenes/ui/menus/ui_pause_menu.tscn",
	"res://scenes/ui/menus/ui_settings_menu.tscn",
	"res://scenes/ui/overlays/ui_save_load_menu.tscn",
	"res://scenes/ui/overlays/ui_input_rebinding_overlay.tscn",
	"res://scenes/ui/overlays/ui_input_profile_selector.tscn",
	"res://scenes/ui/overlays/ui_gamepad_settings_overlay.tscn",
	"res://scenes/ui/overlays/ui_touchscreen_settings_overlay.tscn",
	"res://scenes/ui/overlays/ui_edit_touch_controls_overlay.tscn",
	"res://scenes/ui/overlays/settings/ui_audio_settings_overlay.tscn",
	"res://scenes/ui/overlays/settings/ui_display_settings_overlay.tscn",
	"res://scenes/ui/overlays/settings/ui_localization_settings_overlay.tscn",
	"res://scenes/ui/overlays/settings/ui_vfx_settings_overlay.tscn",
]

const UI_THEME_OVERRIDE_ALLOWED_COUNTS := {
	"res://scenes/ui/widgets/ui_virtual_button.tscn": 4,
}

const SCRIPT_FILENAME_EXCEPTIONS := [
	"root.gd" # Root bootstrap script (intentionally unprefixed)
]

const AI_RESOURCE_ALLOWED_SUBDIRECTORIES := [
	"brain",
	"goals",
	"tasks",
	"actions",
]

# Valid prefixes by directory
const SCRIPT_PREFIX_RULES := {
	"res://scripts/core": ["u_"],
	"res://scripts/interfaces": ["i_"],
	"res://scripts/utils": ["u_"],
	"res://scripts/input": ["u_", "i_"],
	"res://scripts/input/sources": [""], # Wildcard: validated by suffix rule (see test_input_source_scripts_follow_suffix_rule)
	"res://scripts/resources/input": ["rs_"],
	"res://scripts/resources/interactions": ["rs_"],
	"res://scripts/resources/lighting": ["rs_"], # Character lighting resources
	"res://scripts/managers": ["m_"],
	"res://scripts/managers/helpers": ["u_"],
	"res://scripts/ecs/systems": ["s_", "base_"], # s_*_system.gd plus base system scripts
	"res://scripts/ecs/systems/helpers": ["u_"], # vCam/system helper utilities
	"res://scripts/ecs/components": ["c_"],
	"res://scripts/ecs/resources": ["rs_"],
	"res://scripts/events/ecs": ["evn_", "base_", "u_"], # evn_ for typed events, base_ for BaseECSEvent, u_ for ECS event bus/names
	"res://scripts/events/state": ["u_"], # u_state_event_bus.gd
	"res://scripts/ecs": ["base_", "u_"], # base_ecs_*.gd files, base_event_vfx_system.gd, u_entity_query.gd
	"res://scripts/ecs/markers": ["marker_"],
	"res://scripts/state/actions": ["u_"],
	"res://scripts/state/reducers": ["u_"],
	"res://scripts/state/selectors": ["u_"],
	"res://scripts/resources/state": ["rs_"], # State initial state resources
	"res://scripts/resources/qb": ["rs_"], # QB base condition/effect/rule resources
	"res://scripts/resources/qb/conditions": ["rs_"], # QB condition resources
	"res://scripts/resources/qb/effects": ["rs_"], # QB effect resources
	"res://scripts/resources/scene_director": ["rs_"], # Scene director beat/objective/directive resources
	"res://scripts/resources/ecs": ["rs_"], # ECS component settings resources
	"res://scripts/resources/display": ["rs_"], # Display preset resources
	"res://scripts/resources/localization": ["rs_"], # Localization resources
	"res://scripts/resources/ai": ["rs_"], # AI resources
	"res://scripts/resources/ai/actions": ["rs_"], # AI action resources
	"res://scripts/debug": ["debug_"], # Debug utility scripts
	"res://scripts/state": ["u_", "m_"], # m_state_store.gd is in root
	"res://scripts/resources/ui": ["rs_"], # UI screen definitions
	"res://scripts/ui/base": ["base_"], # base_*.gd UI base classes
	"res://scripts/ui/utils": ["u_"], # UI utilities
	"res://scripts/ui": ["ui_", "u_"], # ui_ for controllers, u_ for utilities
	"res://scripts/gameplay/helpers": ["u_"], # gameplay helper utilities
	"res://scripts/gameplay": ["e_", "inter_", "base_", "triggered_", "s_"], # e_ for entities, inter_ for interactable controllers, base_ for base controllers, triggered_ for special controllers, s_ for gameplay-scoped ECS systems
	"res://scripts/scene_structure": ["marker_"], # marker_*.gd organizational scripts
	"res://scripts/scene_management/transitions": ["trans_", "base_"], # transition effects
	"res://scripts/resources/scene_management": ["rs_"], # scene registry resources
	"res://scripts/scene_management/handlers": ["h_"], # Scene type handlers (Phase 10B-3)
	"res://scripts/scene_management": ["u_", "sp_"], # u_scene_registry.gd, u_transition_factory.gd, sp_spawn_point.gd
	"res://scripts/events": ["base_"], # base_event_bus.gd
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

func test_interaction_resources_define_script_reference() -> void:
	var missing: Array[String] = []
	for dir_path in INTERACTION_RESOURCE_DIRECTORIES:
		_collect_tres_without_script(dir_path, missing)
	assert_eq(missing.size(), 0,
		"Interaction config resources must include script = ExtResource(). Missing:\n%s" % "\n".join(missing))

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

func _collect_paths_with_spaces(dir_path: String, violations: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var path := "%s/%s" % [dir_path, entry]
		if entry.find(" ") != -1:
			violations.append(path)
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_collect_paths_with_spaces(path, violations)
		entry = dir.get_next()
	dir.list_dir_end()

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

func test_input_source_scripts_follow_suffix_rule() -> void:
	var violations: Array[String] = []

	_check_script_suffix_directory("res://scripts/input/sources", "_source.gd", violations)

	var message := "Input sources must follow documented naming patterns"
	if violations.size() > 0:
		message += ":\n" + "\n".join(violations)
		message += "\n\nSee STYLE_GUIDE.md input sources section."
	else:
		message += " - all input sources compliant!"

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

	# Interaction config instances
	_check_resource_directory("res://resources/interactions", ["cfg_"], violations)

	# Interaction config placement (must be in typed subdirectories)
	_collect_interaction_resource_placement_violations("res://resources/interactions", violations)

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

func test_production_paths_have_no_spaces() -> void:
	var violations: Array[String] = []

	for dir_path in PRODUCTION_PATH_DIRECTORIES:
		_collect_paths_with_spaces(dir_path, violations)

	var message := "Production res:// paths must not include spaces"
	if violations.size() > 0:
		message += ":\n" + "\n".join(violations)
		message += "\n\nRename files/directories to remove spaces."
	else:
		message += " - all paths compliant!"

	assert_eq(violations.size(), 0, message)

func test_polished_overlay_scenes_have_no_inline_theme_overrides() -> void:
	var violations: Array[String] = []

	for scene_path in UI_POLISHED_OVERLAY_SCENES:
		var override_count: int = _count_theme_override_lines(scene_path)
		if override_count > 0:
			violations.append("%s (%d inline theme_override_ lines)" % [scene_path, override_count])

	var message := "Polished overlay scenes should not regress to inline theme_override_* styling"
	if violations.size() > 0:
		message += ":\n" + "\n".join(violations)
		message += "\nUse RS_UIThemeConfig tokens in script/theme builder instead."

	assert_eq(violations.size(), 0, message)

func test_no_inline_theme_overrides_except_semantic() -> void:
	var override_counts: Dictionary = {}
	_collect_scene_theme_override_counts("res://scenes/ui", override_counts)

	var total_override_count: int = 0
	var violations: Array[String] = []
	var scene_paths: Array[String] = []
	for path_variant in override_counts.keys():
		scene_paths.append(str(path_variant))
	scene_paths.sort()

	for scene_path in scene_paths:
		var override_count: int = int(override_counts.get(scene_path, 0))
		total_override_count += override_count
		var allowed_count: int = int(UI_THEME_OVERRIDE_ALLOWED_COUNTS.get(scene_path, 0))
		if override_count > allowed_count:
			violations.append("%s (%d inline theme_override_ lines; allowed %d)" % [scene_path, override_count, allowed_count])

	var violations_message := "UI scenes should avoid inline theme_override_* except semantic exceptions"
	if violations.size() > 0:
		violations_message += ":\n" + "\n".join(violations)
		violations_message += "\nUse RS_UIThemeConfig tokens and script-applied overrides instead."
	assert_eq(violations.size(), 0, violations_message)

	assert_lte(
		total_override_count,
		4,
		"Expected <= 4 total inline theme_override_* lines under scenes/ui (semantic virtual-button overrides only), got %d" % total_override_count
	)

func test_scene_organization_root_structure() -> void:
	var root_scene := load("res://scenes/root.tscn") as PackedScene
	assert_not_null(root_scene, "Root scene must exist")

	# Use PackedScene.get_state() to check node structure without instantiation
	# This avoids runtime initialization issues (M_TimeManager warnings, ServiceLocator conflicts)
	var scene_state := root_scene.get_state()

	var has_managers := false
	var has_state_store := false
	var has_scene_manager := false
	var has_cursor_manager := false
	var has_time_manager := false
	var has_screenshot_cache := false
	var has_character_lighting_manager := false
	var has_active_scene_container := false
	var has_ui_overlay_stack := false

	for i in range(scene_state.get_node_count()):
		var node_name := scene_state.get_node_name(i)
		var node_path := scene_state.get_node_path(i)
		var path_str := str(node_path)

		if node_name == "Managers":
			has_managers = true
		elif node_name == "M_StateStore" and path_str.contains("Managers"):
			has_state_store = true
		elif node_name == "M_SceneManager" and path_str.contains("Managers"):
			has_scene_manager = true
		elif node_name == "M_CursorManager" and path_str.contains("Managers"):
			has_cursor_manager = true
		elif node_name == "M_TimeManager" and path_str.contains("Managers"):
			has_time_manager = true
		elif node_name == "M_ScreenshotCacheManager" and path_str.contains("Managers"):
			has_screenshot_cache = true
		elif node_name == "M_CharacterLightingManager" and path_str.contains("Managers"):
			has_character_lighting_manager = true
		elif node_name == "ActiveSceneContainer":
			has_active_scene_container = true
		elif node_name == "UIOverlayStack":
			has_ui_overlay_stack = true

	assert_true(has_managers, "Root scene must have Managers node")
	assert_true(has_state_store, "Root scene must have M_StateStore in Managers")
	assert_true(has_scene_manager, "Root scene must have M_SceneManager in Managers")
	assert_true(has_cursor_manager, "Root scene must have M_CursorManager in Managers")
	assert_true(has_time_manager, "Root scene must have M_TimeManager in Managers")
	assert_true(has_screenshot_cache, "Root scene must have M_ScreenshotCacheManager in Managers")
	assert_true(has_character_lighting_manager, "Root scene must have M_CharacterLightingManager in Managers")
	assert_true(has_active_scene_container, "Root scene must have ActiveSceneContainer")
	assert_true(has_ui_overlay_stack, "Root scene must have UIOverlayStack")

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
		elif node_name == "SpawnPoints":
			# Check if spawn points are under Entities
			var path_str := str(node_path)
			if path_str.begins_with(entities_node_path + "/") or path_str.contains("Entities/"):
				has_spawn_points_in_entities = true

	assert_true(has_managers, "Gameplay scene must have Managers node")
	assert_true(has_systems, "Gameplay scene must have Systems node")
	assert_true(has_entities, "Gameplay scene must have Entities node")
	assert_true(has_spawn_points_in_entities,
		"Spawn points must be under Entities node per SCENE_ORGANIZATION_GUIDE.md")

func test_character_template_defines_camera_follow_anchor() -> void:
	var character_scene := load("res://scenes/templates/tmpl_character.tscn") as PackedScene
	assert_not_null(character_scene, "Character template scene must exist")

	var character_instance := character_scene.instantiate() as Node
	assert_not_null(character_instance, "Character template must instantiate")
	add_child_autofree(character_instance)

	var follow_anchor := character_instance.get_node_or_null("Player_Body/CameraFollowAnchor") as Node3D
	assert_not_null(
		follow_anchor,
		"tmpl_character.tscn must define Player_Body/CameraFollowAnchor for vCam follow targeting"
	)
	if follow_anchor != null:
		assert_true(
			follow_anchor.transform.origin.is_zero_approx(),
			"CameraFollowAnchor should stay at Player_Body origin unless intentionally authored otherwise"
		)

func test_camera_template_uses_camera_follow_anchor_path() -> void:
	var camera_scene := load("res://scenes/templates/tmpl_camera.tscn") as PackedScene
	assert_not_null(camera_scene, "Camera template scene must exist")

	var camera_instance := camera_scene.instantiate() as Node
	assert_not_null(camera_instance, "Camera template must instantiate")
	add_child_autofree(camera_instance)

	var vcam_component := camera_instance.get_node_or_null("Components/C_VCamComponent")
	assert_not_null(vcam_component, "tmpl_camera.tscn must include Components/C_VCamComponent")
	if vcam_component != null:
		assert_eq(
			vcam_component.follow_target_path,
			NodePath("../../../E_Player/Player_Body/CameraFollowAnchor"),
			"C_VCamComponent.follow_target_path should target CameraFollowAnchor"
		)

func test_prefab_player_inherits_camera_follow_anchor() -> void:
	var player_prefab := load("res://scenes/prefabs/prefab_player.tscn") as PackedScene
	assert_not_null(player_prefab, "Player prefab scene must exist")

	var player_instance := player_prefab.instantiate() as Node
	assert_not_null(player_instance, "Player prefab must instantiate")
	add_child_autofree(player_instance)

	var follow_anchor := player_instance.get_node_or_null("Player_Body/CameraFollowAnchor") as Node3D
	assert_not_null(
		follow_anchor,
		"prefab_player.tscn must include Player_Body/CameraFollowAnchor (inherited from tmpl_character)"
	)
	if follow_anchor != null:
		assert_true(
			follow_anchor.transform.origin.is_zero_approx(),
			"prefab_player CameraFollowAnchor should stay at Player_Body origin unless intentionally authored otherwise"
		)

func test_gameplay_scenes_do_not_embed_hud_instances() -> void:
	var violations: Array[String] = []
	_collect_gameplay_hud_embedding_violations("res://scenes/gameplay", violations)

	var message := "Gameplay scenes must not embed HUD instances (HUD is root-managed by M_SceneManager)"
	if violations.size() > 0:
		message += ":\n" + "\n".join(violations)

	assert_eq(violations.size(), 0, message)

func test_vcam_debug_logging_not_enabled_in_authored_scenes() -> void:
	var violations: Array[String] = []
	_collect_scene_text_match_violations("res://scenes/gameplay", "debug_rotation_logging = true", violations)
	_collect_scene_text_match_violations("res://scenes/templates", "debug_rotation_logging = true", violations)

	var message := "Authored scenes must not enable S_VCamSystem debug_rotation_logging"
	if violations.size() > 0:
		message += ":\n" + "\n".join(violations)

	assert_eq(violations.size(), 0, message)

func test_ai_move_target_magic_strings_not_used_in_ai_scripts() -> void:
	var violations: Array[String] = []
	_collect_gd_literal_occurrences("res://scripts/resources/ai", "\"ai_move_target\"", violations)
	_collect_gd_literal_occurrences("res://scripts/ecs/systems", "\"ai_move_target\"", violations, "s_ai_")

	var message := "AI scripts should not use bare \"ai_move_target\" string literals"
	if violations.size() > 0:
		message += ":\n" + "\n".join(violations)
		message += "\nUse U_AITaskStateKeys constants instead."
	assert_eq(violations.size(), 0, message)

func test_ai_resource_scripts_are_grouped_by_subdirectory() -> void:
	var violations: Array[String] = []
	_collect_ai_resource_layout_violations("res://scripts/resources/ai", violations)

	var message := "AI resource scripts must live under scripts/resources/ai/{brain,goals,tasks,actions}"
	if violations.size() > 0:
		message += ":\n" + "\n".join(violations)
	assert_eq(violations.size(), 0, message)

func test_ecs_system_filenames_do_not_include_demo_marker() -> void:
	var violations: Array[String] = []
	_collect_gd_filename_substring_violations("res://scripts/ecs/systems", "_demo_", violations)

	var message := "ECS system scripts under scripts/ecs/systems must not include '_demo_' in filename"
	if violations.size() > 0:
		message += ":\n" + "\n".join(violations)
	assert_eq(violations.size(), 0, message)

func test_ai_behavior_system_has_no_local_duck_typing_helpers() -> void:
	var behavior_system_path := "res://scripts/ecs/systems/s_ai_behavior_system.gd"
	var forbidden_helpers: Array[String] = [
		"_read_object_property",
		"_read_int_property",
		"_read_bool_property",
		"_read_float_property",
		"_variant_to_string_name",
	]
	var violations: Array[String] = []
	var file := FileAccess.open(behavior_system_path, FileAccess.READ)
	assert_not_null(file, "Unable to open %s" % behavior_system_path)
	if file == null:
		return
	var file_text: String = file.get_as_text()
	file.close()
	for helper_name in forbidden_helpers:
		if file_text.find("func %s(" % helper_name) != -1:
			violations.append("%s defines %s" % [behavior_system_path, helper_name])

	var message := "S_AIBehaviorSystem should not define AI-local duck-typing helper functions"
	if violations.size() > 0:
		message += ":\n" + "\n".join(violations)
	assert_eq(violations.size(), 0, message)

func test_ai_behavior_system_stays_under_two_hundred_lines() -> void:
	var behavior_system_path := "res://scripts/ecs/systems/s_ai_behavior_system.gd"
	var file := FileAccess.open(behavior_system_path, FileAccess.READ)
	assert_not_null(file, "Unable to open %s" % behavior_system_path)
	if file == null:
		return
	var line_count: int = 0
	while not file.eof_reached():
		file.get_line()
		line_count += 1
	file.close()

	assert_lte(
		line_count,
		199,
		"S_AIBehaviorSystem should stay below 200 lines for orchestration-only scope (current=%d)." % line_count
	)

func test_rule_systems_do_not_define_local_rule_pipeline_helpers() -> void:
	var context_builders: Array[String] = [
		"res://scripts/ecs/systems/s_camera_state_system.gd",
		"res://scripts/ecs/systems/s_character_state_system.gd",
		"res://scripts/ecs/systems/s_game_event_system.gd",
		"res://scripts/utils/ai/u_ai_context_builder.gd",
		"res://scripts/managers/m_objectives_manager.gd",
		"res://scripts/managers/m_scene_director_manager.gd",
	]
	var forbidden_methods: Array[String] = [
		"_refresh_active_rules",
		"_get_applicable_rules",
		"_apply_state_gates",
		"_mark_fired_rules",
	]
	var violations: Array[String] = []

	for path in context_builders:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			violations.append("%s (unable to open file)" % path)
			continue
		var file_text: String = file.get_as_text()
		file.close()

		for method_name in forbidden_methods:
			var signature: String = "func %s(" % method_name
			if file_text.find(signature) != -1:
				violations.append("%s defines %s" % [path, method_name])

	var message := "Rule systems should use shared U_RuleEvaluator pipeline helpers"
	if violations.size() > 0:
		message += ":\n" + "\n".join(violations)
	assert_eq(violations.size(), 0, message)

func test_rule_systems_and_helpers_do_not_duplicate_property_readers() -> void:
	var affected_files: Array[String] = [
		"res://scripts/ecs/systems/s_camera_state_system.gd",
		"res://scripts/ecs/systems/s_character_state_system.gd",
		"res://scripts/ecs/systems/s_game_event_system.gd",
		"res://scripts/ecs/systems/helpers/u_vcam_runtime_context.gd",
		"res://scripts/ecs/systems/helpers/u_vcam_landing_impact.gd",
		"res://scripts/utils/qb/u_rule_validator.gd",
		"res://scripts/utils/qb/u_rule_scorer.gd",
		"res://scripts/utils/qb/u_rule_selector.gd",
	]
	var forbidden_methods: Array[String] = [
		"_read_string_property",
		"_read_string_name_property",
		"_read_bool_property",
		"_read_float_property",
		"_read_int_property",
		"_read_array_property",
		"_is_script_instance_of",
		"_object_has_property",
		"_variant_to_string_name",
		"_get_context_value",
		"_extract_event_names_from_rule",
	]
	var violations: Array[String] = []

	for path in affected_files:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			violations.append("%s (unable to open file)" % path)
			continue
		var file_text: String = file.get_as_text()
		file.close()

		for method_name in forbidden_methods:
			var signature: String = "func %s(" % method_name
			if file_text.find(signature) != -1:
				violations.append("%s defines %s" % [path, method_name])

	var message := "Rule systems and helpers should use shared U_RuleUtils property readers"
	if violations.size() > 0:
		message += ":\n" + "\n".join(violations)
	assert_eq(violations.size(), 0, message)

func test_rule_systems_do_not_use_bare_string_context_keys() -> void:
	var context_builders: Array[String] = [
		"res://scripts/ecs/systems/s_camera_state_system.gd",
		"res://scripts/ecs/systems/s_character_state_system.gd",
		"res://scripts/ecs/systems/s_game_event_system.gd",
		"res://scripts/utils/ai/u_ai_context_builder.gd",
		"res://scripts/managers/m_objectives_manager.gd",
		"res://scripts/managers/m_scene_director_manager.gd",
	]
	# Forbidden: context["key"] or context.get("key") with bare string keys
	# Allowed: context[RSRuleContext.KEY_*]
	var forbidden_patterns: Array[String] = [
		'context["',
		"context.get(\"",
		"context.has(\"",
		"context.erase(\"",
	]
	var allowed_patterns: Array[String] = [
		"context[RSRuleContext",
		"context.get(RSRuleContext",
		"context.has(RSRuleContext",
		"context.erase(RSRuleContext",
	]
	var violations: Array[String] = []

	for path in context_builders:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			violations.append("%s (unable to open file)" % path)
			continue
		var line_number: int = 0
		while not file.eof_reached():
			line_number += 1
			var line: String = file.get_line()
			var stripped: String = line.strip_edges()
			if stripped.begins_with("#"):
				continue

			for forbidden in forbidden_patterns:
				if line.find(forbidden) == -1:
					continue
				var is_allowed := false
				for allowed in allowed_patterns:
					if line.find(allowed) != -1:
						is_allowed = true
						break
				if not is_allowed:
					violations.append("%s:%d uses bare string context key: %s" % [path, line_number, stripped])
		file.close()

	var message := "Context builders should use RSRuleContext.KEY_* constants for context access"
	if violations.size() > 0:
		message += ":\n" + "\n".join(violations)
	assert_eq(violations.size(), 0, message)

func test_scene_manager_transition_path_avoids_reflection_and_array_wrapper_captures() -> void:
	var path := "res://scripts/managers/m_scene_manager.gd"
	var file := FileAccess.open(path, FileAccess.READ)
	assert_not_null(file, "Unable to open %s" % path)
	if file == null:
		return
	var text: String = file.get_as_text()
	file.close()

	assert_eq(
		text.find('_camera_manager.get("_camera_blend_tween")'),
		-1,
		"M_SceneManager should query I_CameraManager.is_blend_active() instead of reflecting private tween state."
	)
	assert_eq(
		text.find("var current_progress: Array = ["),
		-1,
		"M_SceneManager transition code should not use Array-wrapper mutable capture for progress state."
	)
	assert_eq(
		text.find("var new_scene_ref: Array = ["),
		-1,
		"M_SceneManager transition code should use typed transition state, not Array-wrapper mutable capture for scene refs."
	)


func test_migrated_files_do_not_duplicate_dependency_resolution_pattern() -> void:
	# Files that have been migrated to use U_DependencyResolution should not
	# contain the old inline cache→export→ServiceLocator pattern in their
	# _resolve_* methods. The shared utility is the single source of truth.
	var affected_files: Array[String] = [
		"res://scripts/ecs/systems/s_camera_state_system.gd",
		"res://scripts/ecs/systems/s_character_state_system.gd",
		"res://scripts/ecs/systems/s_game_event_system.gd",
		"res://scripts/ecs/systems/s_ai_detection_system.gd",
		"res://scripts/ecs/systems/s_ai_behavior_system.gd",
		"res://scripts/ecs/systems/s_wall_visibility_system.gd",
		"res://scripts/ecs/systems/s_region_visibility_system.gd",
		"res://scripts/gameplay/s_demo_alarm_relay_system.gd",
		"res://scripts/managers/m_vcam_manager.gd",
		"res://scripts/managers/m_character_lighting_manager.gd",
		"res://scripts/managers/m_run_coordinator_manager.gd",
		"res://scripts/gameplay/inter_victory_zone.gd",
		"res://scripts/gameplay/inter_ai_demo_guard_barrier.gd",
		"res://scripts/ecs/systems/helpers/u_vcam_runtime_services.gd",
		"res://scripts/gameplay/inter_character_light_zone.gd",
		"res://scripts/gameplay/inter_ai_demo_flag_zone.gd",
		"res://scripts/ecs/base_event_sfx_system.gd",
		"res://scripts/ui/menus/ui_splash_screen.gd",
		"res://scripts/ui/hud/ui_virtual_button.gd",
		"res://scripts/ui/base/base_panel.gd",
		"res://scripts/gameplay/base_interactable_controller.gd",
		"res://scripts/managers/m_vfx_manager.gd",
		"res://scripts/managers/m_audio_manager.gd",
		"res://scripts/managers/m_localization_manager.gd",
		"res://scripts/managers/m_display_manager.gd",
		"res://scripts/utils/scene_director/u_store_action_binder.gd",
	]
	# Forbidden: inline U_STATE_UTILS.try_get_store calls in migrated files
	# that should delegate to U_DependencyResolution
	var dep_res_forbidden_patterns: Array[String] = [
		"U_STATE_UTILS.try_get_store",
		"U_StateUtils.try_get_store",
	]
	var dep_res_violations: Array[String] = []

	for path in affected_files:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			dep_res_violations.append("%s (unable to open file)" % path)
			continue
		var file_text: String = file.get_as_text()
		file.close()

		for pattern in dep_res_forbidden_patterns:
			if file_text.find(pattern) != -1:
				dep_res_violations.append("%s still contains %s (should use U_DependencyResolution)" % [path, pattern])

	var dep_res_message := "Migrated files should use U_DependencyResolution instead of inline U_STATE_UTILS.try_get_store"
	if dep_res_violations.size() > 0:
		dep_res_message += ":\n" + "\n".join(dep_res_violations)
	assert_eq(dep_res_violations.size(), 0, dep_res_message)

func test_ecs_systems_do_not_define_local_get_frame_state_snapshot() -> void:
	# Systems that have been migrated to use BaseECSSystem.get_frame_state_snapshot()
	# should not define their own _get_frame_state_snapshot method.
	var migrated_files: Array[String] = [
		"res://scripts/ecs/systems/s_camera_state_system.gd",
		"res://scripts/ecs/systems/s_character_state_system.gd",
		"res://scripts/ecs/systems/s_vcam_system.gd",
		"res://scripts/ecs/systems/s_wall_visibility_system.gd",
		"res://scripts/ecs/systems/s_ai_behavior_system.gd",
	]
	var forbidden_pattern: String = "func _get_frame_state_snapshot"
	var snapshot_violations: Array[String] = []

	for path in migrated_files:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			snapshot_violations.append("%s (unable to open file)" % path)
			continue
		var file_text: String = file.get_as_text()
		file.close()

		if file_text.find(forbidden_pattern) != -1:
			snapshot_violations.append("%s still defines _get_frame_state_snapshot (should use inherited get_frame_state_snapshot)" % path)

	var snapshot_message := "Migrated systems should not define local _get_frame_state_snapshot"
	if snapshot_violations.size() > 0:
		snapshot_message += ":\n" + "\n".join(snapshot_violations)
	assert_eq(snapshot_violations.size(), 0, snapshot_message)

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
	return filename.begins_with("test_") or filename in SCRIPT_FILENAME_EXCEPTIONS

func _check_script_suffix_directory(dir_path: String, required_suffix: String, violations: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_check_script_suffix_directory("%s/%s" % [dir_path, entry], required_suffix, violations)
		elif entry.ends_with(".gd"):
			if not entry.ends_with(required_suffix):
				violations.append("%s/%s - must end with '%s'" % [
					dir_path, entry, required_suffix
				])
		entry = dir.get_next()
	dir.list_dir_end()

func _check_scene_directory(dir_path: String, required_prefix: String, violations: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_check_scene_directory("%s/%s" % [dir_path, entry], required_prefix, violations)
		elif entry.ends_with(".tscn"):
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

func _collect_interaction_resource_placement_violations(dir_path: String, violations: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var path := "%s/%s" % [dir_path, entry]
		if dir.current_is_dir():
			if not entry.begins_with("."):
				if dir_path == "res://resources/interactions" and not INTERACTION_RESOURCE_ALLOWED_SUBDIRS.has(entry):
					violations.append("%s - invalid interaction config category directory" % path)
				_collect_interaction_resource_placement_violations(path, violations)
		elif entry.ends_with(".tres"):
			if dir_path == "res://resources/interactions":
				violations.append("%s - interaction config instances must live in a category subdirectory" % path)
		entry = dir.get_next()
	dir.list_dir_end()

func _collect_gameplay_hud_embedding_violations(dir_path: String, violations: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var path := "%s/%s" % [dir_path, entry]
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_collect_gameplay_hud_embedding_violations(path, violations)
		elif entry.ends_with(".tscn"):
			if _scene_embeds_hud_overlay(path):
				violations.append("%s embeds ui_hud_overlay.tscn or HUD root node" % path)
		entry = dir.get_next()
	dir.list_dir_end()

func _scene_embeds_hud_overlay(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false

	var has_hud_ext_resource := false
	var has_hud_node := false
	while not file.eof_reached():
		var line := file.get_line()
		if line.find("res://scenes/ui/hud/ui_hud_overlay.tscn") != -1:
			has_hud_ext_resource = true
		if line.begins_with("[node name=\"HUD\""):
			has_hud_node = true
		if has_hud_ext_resource or has_hud_node:
			file.close()
			return true

	file.close()
	return false

func _collect_scene_text_match_violations(
	dir_path: String,
	needle: String,
	violations: Array[String]
) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var path := "%s/%s" % [dir_path, entry]
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_collect_scene_text_match_violations(path, needle, violations)
		elif entry.ends_with(".tscn"):
			var file := FileAccess.open(path, FileAccess.READ)
			if file == null:
				entry = dir.get_next()
				continue
			var found := false
			while not file.eof_reached():
				if file.get_line().find(needle) != -1:
					found = true
					break
			file.close()
			if found:
				violations.append("%s contains '%s'" % [path, needle])
		entry = dir.get_next()
	dir.list_dir_end()

func _collect_gd_literal_occurrences(
	dir_path: String,
	needle: String,
	violations: Array[String],
	filename_prefix_filter: String = ""
) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var path := "%s/%s" % [dir_path, entry]
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_collect_gd_literal_occurrences(path, needle, violations, filename_prefix_filter)
		elif entry.ends_with(".gd"):
			if filename_prefix_filter != "" and not entry.begins_with(filename_prefix_filter):
				entry = dir.get_next()
				continue

			var file := FileAccess.open(path, FileAccess.READ)
			if file == null:
				entry = dir.get_next()
				continue
			var line_number: int = 0
			while not file.eof_reached():
				line_number += 1
				var line: String = file.get_line()
				if line.find(needle) != -1:
					violations.append("%s:%d" % [path, line_number])
			file.close()
		entry = dir.get_next()
	dir.list_dir_end()

func _count_theme_override_lines(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return 0

	var count := 0
	while not file.eof_reached():
		var line := file.get_line()
		if line.find("theme_override_") != -1:
			count += 1

	file.close()
	return count

func _collect_ai_resource_layout_violations(dir_path: String, violations: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var path := "%s/%s" % [dir_path, entry]
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_collect_ai_resource_layout_violations(path, violations)
		elif entry.ends_with(".gd") and entry.begins_with("rs_ai_"):
			var relative_path := path.trim_prefix("res://scripts/resources/ai/")
			var slash_index := relative_path.find("/")
			if slash_index == -1:
				violations.append("%s is in ai root; expected brain/goals/tasks/actions subdirectory" % path)
			else:
				var top_level_dir := relative_path.substr(0, slash_index)
				if not AI_RESOURCE_ALLOWED_SUBDIRECTORIES.has(top_level_dir):
					violations.append("%s is under unexpected ai subdirectory '%s'" % [path, top_level_dir])
		entry = dir.get_next()
	dir.list_dir_end()

func _collect_scene_theme_override_counts(dir_path: String, override_counts: Dictionary) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var path := "%s/%s" % [dir_path, entry]
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_collect_scene_theme_override_counts(path, override_counts)
		elif entry.ends_with(".tscn"):
			var override_count: int = _count_theme_override_lines(path)
			if override_count > 0:
				override_counts[path] = override_count
		entry = dir.get_next()
	dir.list_dir_end()

func _collect_gd_filename_substring_violations(
	dir_path: String,
	needle: String,
	violations: Array[String]
) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var path := "%s/%s" % [dir_path, entry]
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_collect_gd_filename_substring_violations(path, needle, violations)
		elif entry.ends_with(".gd"):
			if entry.find(needle) != -1:
				violations.append(path)
		entry = dir.get_next()
	dir.list_dir_end()


func test_resolve_state_store_naming_consistent() -> void:
	var gd_dirs: Array[String] = [
		"res://scripts/ecs",
		"res://scripts/managers",
		"res://scripts/gameplay",
	]
	var violations: Array[String] = []
	for dir_path in gd_dirs:
		_check_for_method_definition(dir_path, "func _resolve_store()", violations)
	assert_eq(violations.size(), 0, "Found files defining _resolve_store() instead of _resolve_state_store():\n" + "\n".join(violations))


func _check_for_method_definition(dir_path: String, method_signature: String, violations: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var path := "%s/%s" % [dir_path, entry]
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_check_for_method_definition(path, method_signature, violations)
		elif entry.ends_with(".gd"):
			var file := FileAccess.open(path, FileAccess.READ)
			if file != null:
				while not file.eof_reached():
					var line := file.get_line()
					if line.find(method_signature) != -1:
						violations.append(path)
						break
				file.close()
		entry = dir.get_next()
	dir.list_dir_end()

## C7: No direct state.get("objectives", {}) outside selectors and reducers in production code.
func test_objectives_state_access_uses_selectors() -> void:
	var allowed_files: Array[String] = [
		"res://scripts/state/selectors/u_objectives_selectors.gd",
		"res://scripts/state/reducers/u_objectives_reducer.gd",
		"res://scripts/managers/helpers/u_save_migration_engine.gd",
		"res://scripts/utils/scene_director/u_objectives_debug_tracer.gd",
		"res://scripts/ecs/systems/s_victory_handler_system.gd",
		"res://scripts/ui/menus/ui_victory.gd",
	]
	var production_dirs: Array[String] = [
		"res://scripts/ecs",
		"res://scripts/state",
		"res://scripts/ui",
		"res://scripts/managers",
		"res://scripts/core",
		"res://scripts/interfaces",
		"res://scripts/utils",
		"res://scripts/input",
		"res://scripts/scene_management",
		"res://scripts/events",
		"res://scripts/scene_structure",
		"res://scripts/resources",
		"res://scripts/gameplay",
		"res://scripts/debug",
	]
	var violations: Array[String] = []
	var patterns: Array[String] = [
		'state.get("objectives"',
		'state.get(&"objectives"',
		'state["objectives"]',
	]
	for dir_path in production_dirs:
		_check_for_patterns_in_files(dir_path, patterns, allowed_files, violations)
	assert_eq(violations.size(), 0, "Found direct objectives state access outside selectors/reducers:\n" + "\n".join(violations))

## C8: No direct state.get("slice", {}) or state["slice"] in manager/helper files.
## All state reads must go through U_*Selectors.
func test_managers_use_selectors_for_state_access() -> void:
	# Files exempt from this check:
	# - m_state_store.gd: The state store itself owns the state dict
	# - u_save_migration_engine.gd: Operates on save file data, not live Redux state
	var allowed_files: Array[String] = [
		"res://scripts/managers/m_state_store.gd",
		"res://scripts/managers/helpers/u_save_migration_engine.gd",
	]
	var manager_dirs: Array[String] = [
		"res://scripts/managers",
	]
	var violations: Array[String] = []
	var patterns: Array[String] = [
		"state.get(",
		'state["',
		'state[&"',
		"state['",
		"state[&'",
	]
	for dir_path in manager_dirs:
		_check_for_patterns_in_files(dir_path, patterns, allowed_files, violations)
	assert_eq(violations.size(), 0, "Found direct state slice access in manager files (should use selectors):\n" + "\n".join(violations))

## C11: No direct state.get("slice") or state["slice"] in production code scopes covered
## by C8 (managers) and C11 (ECS systems, helpers, interactables, UI targets).
## Files deferred to post-C11 cleanup are explicitly listed below.
func test_all_production_files_use_selectors_for_state_access() -> void:
	var allowed_files: Array[String] = [
		# Core exemptions: own the state dict or operate on save data
		"res://scripts/managers/m_state_store.gd",
		"res://scripts/managers/helpers/u_save_migration_engine.gd",
		# False positives: files that use local dict variables named "state" (not Redux state)
		# u_vcam_orbit_effects and u_vcam_rotation use "state" for per-vcam internal tracking dicts.
		# u_vcam_look_input uses "state" for look-input smoothing state.
		# Renaming these local vars is a larger refactor deferred beyond C11.
		"res://scripts/ecs/systems/helpers/u_vcam_orbit_effects.gd",
		"res://scripts/ecs/systems/helpers/u_vcam_rotation.gd",
		"res://scripts/ecs/systems/helpers/u_vcam_look_input.gd",
		# Generic serializer: uses state.get(slice_name, null) with a variable key (not a string literal).
		"res://scripts/utils/u_global_settings_serialization.gd",
		# Deferred — not in C11 scope; will be migrated post-C11:
		"res://scripts/ecs/systems/s_jump_system.gd",
		"res://scripts/ecs/systems/s_playtime_system.gd",
		"res://scripts/ecs/components/c_scene_trigger_component.gd",
		"res://scripts/gameplay/inter_endgame_goal_zone.gd",
		"res://scripts/ui/hud/ui_hud_controller.gd",
		"res://scripts/ui/hud/ui_mobile_controls.gd",
		"res://scripts/ui/menus/ui_main_menu.gd",
		"res://scripts/ui/overlays/ui_input_rebinding_overlay.gd",
		"res://scripts/ui/overlays/ui_save_load_menu.gd",
		"res://scripts/ui/overlays/ui_touchscreen_settings_overlay.gd",
		"res://scripts/utils/scene_director/u_objectives_debug_tracer.gd",
	]
	var production_dirs: Array[String] = [
		"res://scripts/ecs",
		"res://scripts/gameplay",
		"res://scripts/ui",
		"res://scripts/managers",
		"res://scripts/scene_management",
		"res://scripts/utils",
		"res://scripts/core",
	]
	var violations: Array[String] = []
	var patterns: Array[String] = [
		"state.get(",
		'state["',
		'state[&"',
		"state['",
		"state[&'",
	]
	for dir_path in production_dirs:
		_check_for_patterns_in_files(dir_path, patterns, allowed_files, violations)
	assert_eq(
		violations.size(),
		0,
		"Found direct state slice access in production files (should use selectors):\n" + "\n".join(violations)
	)

func _check_for_patterns_in_files(dir_path: String, patterns: Array[String], allowed_files: Array[String], violations: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var path := "%s/%s" % [dir_path, entry]
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_check_for_patterns_in_files(path, patterns, allowed_files, violations)
		elif entry.ends_with(".gd"):
			if allowed_files.has(path):
				entry = dir.get_next()
				continue
			var file := FileAccess.open(path, FileAccess.READ)
			if file != null:
				var line_number: int = 0
				var found := false
				while not file.eof_reached():
					line_number += 1
					var line := file.get_line()
					var stripped: String = line.strip_edges()
					if stripped.begins_with("#"):
						continue
					if _line_has_disallowed_state_access(line, patterns):
						violations.append("%s:%d %s" % [path, line_number, stripped])
						found = true
					if found:
						break
				file.close()
		entry = dir.get_next()
	dir.list_dir_end()

func _line_has_disallowed_state_access(line: String, patterns: Array[String]) -> bool:
	var normalized_line: String = line.replace(" ", "").replace("\t", "")
	var candidates: Array[String] = [line]
	if normalized_line != line:
		candidates.append(normalized_line)

	for candidate in candidates:
		for pattern in patterns:
			var idx: int = candidate.find(pattern)
			while idx != -1:
				if _is_state_token_boundary(candidate, idx):
					return true
				idx = candidate.find(pattern, idx + pattern.length())
	return false

func _is_state_token_boundary(line: String, state_index: int) -> bool:
	if state_index <= 0:
		return true
	var prev_char: String = line.substr(state_index - 1, 1)
	return not _is_identifier_char(prev_char)

func _is_identifier_char(char: String) -> bool:
	if char.is_empty():
		return false
	if char == "_":
		return true
	var code: int = char.unicode_at(0)
	var is_number: bool = code >= 48 and code <= 57
	var is_upper: bool = code >= 65 and code <= 90
	var is_lower: bool = code >= 97 and code <= 122
	return is_number or is_upper or is_lower
