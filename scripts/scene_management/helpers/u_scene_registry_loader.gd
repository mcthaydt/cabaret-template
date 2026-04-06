extends RefCounted
class_name U_SceneRegistryLoader

const CFG_GAMEPLAY_BASE_ENTRY := preload("res://resources/scene_registry/cfg_gameplay_base_entry.tres")
const CFG_ALLEYWAY_ENTRY := preload("res://resources/scene_registry/cfg_alleyway_entry.tres")
const CFG_INTERIOR_HOUSE_ENTRY := preload("res://resources/scene_registry/cfg_interior_house_entry.tres")
const CFG_INTERIOR_A_ENTRY := preload("res://resources/scene_registry/cfg_interior_a_entry.tres")
const CFG_BAR_ENTRY := preload("res://resources/scene_registry/cfg_bar_entry.tres")
const CFG_POWER_CORE_ENTRY := preload("res://resources/scene_registry/cfg_power_core_entry.tres")
const CFG_COMMS_ARRAY_ENTRY := preload("res://resources/scene_registry/cfg_comms_array_entry.tres")
const CFG_NAV_NEXUS_ENTRY := preload("res://resources/scene_registry/cfg_nav_nexus_entry.tres")
const CFG_AI_SHOWCASE_ENTRY := preload("res://resources/scene_registry/cfg_ai_showcase_entry.tres")
const CFG_UI_GAME_OVER_ENTRY := preload("res://resources/scene_registry/cfg_ui_game_over_entry.tres")
const CFG_UI_VICTORY_ENTRY := preload("res://resources/scene_registry/cfg_ui_victory_entry.tres")
const CFG_UI_CREDITS_ENTRY := preload("res://resources/scene_registry/cfg_ui_credits_entry.tres")
const CFG_UI_GAMEPAD_SETTINGS_ENTRY := preload("res://resources/scene_registry/cfg_ui_gamepad_settings_entry.tres")
const CFG_UI_TOUCHSCREEN_SETTINGS_ENTRY := preload("res://resources/scene_registry/cfg_ui_touchscreen_settings_entry.tres")
const CFG_UI_EDIT_TOUCH_CONTROLS_ENTRY := preload("res://resources/scene_registry/cfg_ui_edit_touch_controls_entry.tres")
const CFG_UI_INPUT_PROFILE_SELECTOR_ENTRY := preload("res://resources/scene_registry/cfg_ui_input_profile_selector_entry.tres")
const CFG_UI_INPUT_REBINDING_ENTRY := preload("res://resources/scene_registry/cfg_ui_input_rebinding_entry.tres")
const CFG_UI_DISPLAY_SETTINGS_ENTRY := preload("res://resources/scene_registry/cfg_ui_display_settings_entry.tres")
const CFG_UI_AUDIO_SETTINGS_ENTRY := preload("res://resources/scene_registry/cfg_ui_audio_settings_entry.tres")
const CFG_UI_LOCALIZATION_SETTINGS_ENTRY := preload("res://resources/scene_registry/cfg_ui_localization_settings_entry.tres")
const CFG_UI_KEYBOARD_MOUSE_SETTINGS_ENTRY := preload("res://resources/scene_registry/cfg_ui_keyboard_mouse_settings_entry.tres")

const PRELOADED_SCENE_REGISTRY_ENTRIES := [
	CFG_GAMEPLAY_BASE_ENTRY,
	CFG_ALLEYWAY_ENTRY,
	CFG_INTERIOR_HOUSE_ENTRY,
	CFG_INTERIOR_A_ENTRY,
	CFG_BAR_ENTRY,
	CFG_POWER_CORE_ENTRY,
	CFG_COMMS_ARRAY_ENTRY,
	CFG_NAV_NEXUS_ENTRY,
	CFG_AI_SHOWCASE_ENTRY,
	CFG_UI_GAME_OVER_ENTRY,
	CFG_UI_VICTORY_ENTRY,
	CFG_UI_CREDITS_ENTRY,
	CFG_UI_GAMEPAD_SETTINGS_ENTRY,
	CFG_UI_TOUCHSCREEN_SETTINGS_ENTRY,
	CFG_UI_EDIT_TOUCH_CONTROLS_ENTRY,
	CFG_UI_INPUT_PROFILE_SELECTOR_ENTRY,
	CFG_UI_INPUT_REBINDING_ENTRY,
	CFG_UI_DISPLAY_SETTINGS_ENTRY,
	CFG_UI_AUDIO_SETTINGS_ENTRY,
	CFG_UI_LOCALIZATION_SETTINGS_ENTRY,
	CFG_UI_KEYBOARD_MOUSE_SETTINGS_ENTRY,
]


func load_resource_entries(scenes: Dictionary, register_scene_callable: Callable) -> void:
	if register_scene_callable == Callable() or not register_scene_callable.is_valid():
		return

	# Mobile/Web-safe baseline: registry resources are preloaded so core scenes remain
	# available even when exported PCKs do not support directory iteration.
	var preloaded_result: Dictionary = _load_entries_from_resources(
		PRELOADED_SCENE_REGISTRY_ENTRIES,
		scenes,
		register_scene_callable
	)

	var res_result: Dictionary = {"loaded": 0, "skipped": 0}
	var test_result: Dictionary = {"loaded": 0, "skipped": 0}
	if _should_scan_registry_dirs():
		# Optional additive scan for dev/headless runs so newly-authored resources can
		# register without code changes. Duplicates from the preload manifest are expected.
		res_result = _load_entries_from_dir(
			"res://resources/scene_registry",
			scenes,
			register_scene_callable,
			true,
			false
		)
		# tests/scene_registry is optional; don't warn if it's missing.
		test_result = _load_entries_from_dir(
			"res://tests/scene_registry",
			scenes,
			register_scene_callable,
			false,
			false
		)

	# Keep totals available for potential debugging, even if unused by callers.
	var _total_loaded: int = (
		int(preloaded_result.get("loaded", 0)) +
		int(res_result.get("loaded", 0)) +
		int(test_result.get("loaded", 0))
	)
	var _total_skipped: int = (
		int(preloaded_result.get("skipped", 0)) +
		int(res_result.get("skipped", 0)) +
		int(test_result.get("skipped", 0))
	)
	_total_loaded = _total_loaded # silence unused variable warning until needed
	_total_skipped = _total_skipped

func backfill_default_gameplay_scenes(scenes: Dictionary, register_scene_callable: Callable) -> void:
	if register_scene_callable == Callable() or not register_scene_callable.is_valid():
		return

	# NOTE: These backfills are a safety net for exports where resource-based registry
	# entries might be excluded by filters. Prefer "loading" for gameplay scenes so
	# missing resources don't silently downgrade large-scene transitions to "fade".
	if not scenes.has(StringName("gameplay_base")):
		register_scene_callable.call(
			StringName("gameplay_base"),
			"res://scenes/gameplay/gameplay_base.tscn",
			U_SceneRegistry.SceneType.GAMEPLAY,
			"loading",
			8
		)

	if not scenes.has(StringName("alleyway")):
		register_scene_callable.call(
			StringName("alleyway"),
			"res://scenes/gameplay/gameplay_alleyway.tscn",
			U_SceneRegistry.SceneType.GAMEPLAY,
			"loading",
			6
		)

	if not scenes.has(StringName("interior_house")):
		register_scene_callable.call(
			StringName("interior_house"),
			"res://scenes/gameplay/gameplay_interior_house.tscn",
			U_SceneRegistry.SceneType.GAMEPLAY,
			"loading",
			6
		)

	if not scenes.has(StringName("bar")):
		register_scene_callable.call(
			StringName("bar"),
			"res://scenes/gameplay/gameplay_bar.tscn",
			U_SceneRegistry.SceneType.GAMEPLAY,
			"loading",
			6
		)

	if not scenes.has(StringName("power_core")):
		register_scene_callable.call(
			StringName("power_core"),
			"res://scenes/gameplay/gameplay_power_core.tscn",
			U_SceneRegistry.SceneType.GAMEPLAY,
			"loading",
			7
		)

	if not scenes.has(StringName("comms_array")):
		register_scene_callable.call(
			StringName("comms_array"),
			"res://scenes/gameplay/gameplay_comms_array.tscn",
			U_SceneRegistry.SceneType.GAMEPLAY,
			"loading",
			6
		)

	if not scenes.has(StringName("nav_nexus")):
		register_scene_callable.call(
			StringName("nav_nexus"),
			"res://scenes/gameplay/gameplay_nav_nexus.tscn",
			U_SceneRegistry.SceneType.GAMEPLAY,
			"loading",
			6
		)

	if not scenes.has(StringName("ai_showcase")):
		register_scene_callable.call(
			StringName("ai_showcase"),
			"res://scenes/gameplay/gameplay_ai_showcase.tscn",
			U_SceneRegistry.SceneType.GAMEPLAY,
			"loading",
			8
		)

	if not scenes.has(StringName("interior_a")):
		register_scene_callable.call(
			StringName("interior_a"),
			"res://scenes/gameplay/gameplay_interior_a.tscn",
			U_SceneRegistry.SceneType.GAMEPLAY,
			"loading",
			6
		)

	if not scenes.has(StringName("gamepad_settings")):
		register_scene_callable.call(
			StringName("gamepad_settings"),
			"res://scenes/ui/overlays/ui_gamepad_settings_overlay.tscn",
			U_SceneRegistry.SceneType.UI,
			"instant",
			5
		)

	if not scenes.has(StringName("touchscreen_settings")):
		register_scene_callable.call(
			StringName("touchscreen_settings"),
			"res://scenes/ui/overlays/ui_touchscreen_settings_overlay.tscn",
			U_SceneRegistry.SceneType.UI,
			"instant",
			5
		)

	if not scenes.has(StringName("vfx_settings")):
		register_scene_callable.call(
			StringName("vfx_settings"),
			"res://scenes/ui/overlays/settings/ui_vfx_settings_overlay.tscn",
			U_SceneRegistry.SceneType.UI,
			"instant",
			5
		)

	if not scenes.has(StringName("display_settings")):
		register_scene_callable.call(
			StringName("display_settings"),
			"res://scenes/ui/overlays/settings/ui_display_settings_overlay.tscn",
			U_SceneRegistry.SceneType.UI,
			"instant",
			5
		)

	if not scenes.has(StringName("audio_settings")):
		register_scene_callable.call(
			StringName("audio_settings"),
			"res://scenes/ui/overlays/settings/ui_audio_settings_overlay.tscn",
			U_SceneRegistry.SceneType.UI,
			"instant",
			5
		)

	if not scenes.has(StringName("localization_settings")):
		register_scene_callable.call(
			StringName("localization_settings"),
			"res://scenes/ui/overlays/settings/ui_localization_settings_overlay.tscn",
			U_SceneRegistry.SceneType.UI,
			"instant",
			5
		)

	if not scenes.has(StringName("edit_touch_controls")):
		register_scene_callable.call(
			StringName("edit_touch_controls"),
			"res://scenes/ui/overlays/ui_edit_touch_controls_overlay.tscn",
			U_SceneRegistry.SceneType.UI,
			"instant",
			5
		)

	if not scenes.has(StringName("input_profile_selector")):
		register_scene_callable.call(
			StringName("input_profile_selector"),
			"res://scenes/ui/overlays/ui_input_profile_selector.tscn",
			U_SceneRegistry.SceneType.UI,
			"instant",
			5
		)

	if not scenes.has(StringName("input_rebinding")):
		register_scene_callable.call(
			StringName("input_rebinding"),
			"res://scenes/ui/overlays/ui_input_rebinding_overlay.tscn",
			U_SceneRegistry.SceneType.UI,
			"instant",
			5
		)

	if not scenes.has(StringName("game_over")):
		register_scene_callable.call(
			StringName("game_over"),
			"res://scenes/ui/menus/ui_game_over.tscn",
			U_SceneRegistry.SceneType.END_GAME,
			"fade",
			8
		)

	if not scenes.has(StringName("victory")):
		register_scene_callable.call(
			StringName("victory"),
			"res://scenes/ui/menus/ui_victory.tscn",
			U_SceneRegistry.SceneType.END_GAME,
			"fade",
			5
		)

	if not scenes.has(StringName("credits")):
		register_scene_callable.call(
			StringName("credits"),
			"res://scenes/ui/menus/ui_credits.tscn",
			U_SceneRegistry.SceneType.END_GAME,
			"fade",
			0
		)

func _load_entries_from_resources(
	resources: Array,
	scenes: Dictionary,
	register_scene_callable: Callable
) -> Dictionary:
	var loaded_count: int = 0
	var skipped_count: int = 0

	for i in range(resources.size()):
		var resource: Resource = resources[i] as Resource
		var source_label: String = "preloaded_scene_registry[%d]" % i
		if _register_loaded_entry(resource, source_label, scenes, register_scene_callable, true):
			loaded_count += 1
		else:
			skipped_count += 1

	return {"loaded": loaded_count, "skipped": skipped_count}

func _load_entries_from_dir(
	dir_path: String,
	scenes: Dictionary,
	register_scene_callable: Callable,
	warn_on_missing_dir: bool = true,
	warn_on_duplicates: bool = true
) -> Dictionary:
	var loaded_count: int = 0
	var skipped_count: int = 0

	var dir := _open_dir(dir_path)
	if dir == null:
		# In exports (especially mobile/web), relying on directory iteration can fail due to
		# path normalization quirks or export filters. Backfill provides a safety net, but
		# warn so missing entries don't silently downgrade transitions (e.g., "loading" → "fade").
		if warn_on_missing_dir and not (OS.has_feature("headless") or DisplayServer.get_name() == "headless"):
			push_warning("U_SceneRegistryLoader: Could not open dir '%s' for scene registry entries" % dir_path)
		return {"loaded": 0, "skipped": 0}

	var file_names: PackedStringArray = _collect_tres_files(dir, dir_path)
	for file_name in file_names:
		var resource_path: String = _join_path(dir_path, file_name)
		var resource: Resource = load(resource_path)
		if _register_loaded_entry(resource, resource_path, scenes, register_scene_callable, warn_on_duplicates):
			loaded_count += 1
		else:
			skipped_count += 1
	if loaded_count == 0 and skipped_count == 0 and warn_on_missing_dir and not (OS.has_feature("headless") or DisplayServer.get_name() == "headless"):
		push_warning("U_SceneRegistryLoader: No .tres entries found under '%s' (exports may be missing resources/scene_registry files)" % dir_path)
	return {"loaded": loaded_count, "skipped": skipped_count}

func _register_loaded_entry(
	resource: Resource,
	resource_path: String,
	scenes: Dictionary,
	register_scene_callable: Callable,
	warn_on_duplicates: bool
) -> bool:
	if resource == null:
		push_warning("U_SceneRegistryLoader: Failed to load scene registry resource at %s, skipping" % resource_path)
		return false

	if not (resource is RS_SceneRegistryEntry):
		push_warning("U_SceneRegistryLoader: Resource at %s is not RS_SceneRegistryEntry (found %s), skipping" % [resource_path, resource.get_class()])
		return false

	var entry := resource as RS_SceneRegistryEntry
	if not entry.is_valid():
		push_warning("U_SceneRegistryLoader: Scene entry in %s is invalid (scene_id or scene_path empty), skipping" % resource_path)
		return false

	if scenes.has(entry.scene_id):
		if warn_on_duplicates:
			push_warning("U_SceneRegistryLoader: Scene '%s' from %s already registered (hardcoded or duplicate), skipping" % [entry.scene_id, resource_path])
		return false

	register_scene_callable.call(
		entry.scene_id,
		entry.scene_path,
		entry.scene_type,
		entry.default_transition,
		entry.preload_priority
	)
	return true

func _should_scan_registry_dirs() -> bool:
	# Mobile/Web exports may block directory iteration in packed resources.
	return not OS.has_feature("mobile") and not OS.has_feature("web")

func _collect_tres_files(dir: DirAccess, dir_path: String) -> PackedStringArray:
	var files: PackedStringArray = PackedStringArray()

	if dir != null:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				files.append(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()

	# Some export targets may not enumerate files via list_dir_begin/get_next even when
	# the directory is accessible. Fallback to static file listing for resiliency.
	if files.is_empty():
		var static_files: PackedStringArray = DirAccess.get_files_at(dir_path.trim_suffix("/"))
		for file_name in static_files:
			if file_name.ends_with(".tres"):
				files.append(file_name)

	files.sort()
	return files

func _open_dir(dir_path: String) -> DirAccess:
	var normalized: String = dir_path.trim_suffix("/")

	var dir := DirAccess.open(normalized)
	if dir != null:
		return dir

	# Some platforms are picky about trailing slashes; try both forms.
	dir = DirAccess.open(normalized + "/")
	return dir

func _join_path(dir_path: String, file_name: String) -> String:
	if dir_path.ends_with("/"):
		return dir_path + file_name
	return dir_path + "/" + file_name
